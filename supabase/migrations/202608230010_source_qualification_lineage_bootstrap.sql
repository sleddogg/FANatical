-- Allow factual-source qualification work to wait durably for governed
-- information-lineage resolution before becoming claimable.

begin;

alter table public.source_qualification_work_items
  alter column information_lineage_version_id drop not null;

alter table public.information_lineage_resolution_work_items
  drop constraint information_lineage_resolution_work_items_evidence_kind_check;
alter table public.information_lineage_resolution_work_items
  add constraint information_lineage_resolution_work_items_evidence_kind_check
  check (evidence_kind in (
    'proposal_evidence','verifier_evidence','source_qualification_work'
  ));

alter table public.catalog_evidence_lineage_assignments
  drop constraint catalog_evidence_lineage_assignments_evidence_kind_check;
alter table public.catalog_evidence_lineage_assignments
  add constraint catalog_evidence_lineage_assignments_evidence_kind_check
  check (evidence_kind in (
    'proposal_evidence','verifier_evidence','source_qualification_work'
  ));

create or replace function public.source_qualification_lineage_is_ready(
  work_item_uuid uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.source_qualification_work_items work
    where work.id = work_item_uuid
      and work.information_lineage_version_id is not null
      and public.current_information_lineage_root(
            work.information_lineage_version_id
          ) is not null
  );
$$;

create or replace function public.emit_source_qualification_work_wake()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('queued','retry_wait')
     and public.source_qualification_lineage_is_ready(new.id)
     and (
       tg_op = 'INSERT'
       or old.status is distinct from new.status
       or old.available_at is distinct from new.available_at
       or old.information_lineage_version_id is distinct from
          new.information_lineage_version_id
     ) then
    perform public.emit_agent_work_wake(
      'source_qualification.' || new.data_type, new.id,
      'work_ready', new.available_at,
      new.status || ':' || extract(epoch from new.available_at)::text
    );
  elsif new.status = 'claimed' then
    update public.agent_work_wake_outbox
    set status = 'acknowledged', acknowledged_at = now(),
        acknowledged_by_actor_id = new.claimed_by_actor_id
    where queue_name = 'source_qualification.' || new.data_type
      and work_item_id = new.id and status = 'pending';
  elsif new.status in ('completed','failed','cancelled') then
    update public.agent_work_wake_outbox set status = 'cancelled'
    where queue_name = 'source_qualification.' || new.data_type
      and work_item_id = new.id and status = 'pending';
  end if;
  return new;
end;
$$;

drop trigger emit_source_qualification_work_wake
on public.source_qualification_work_items;
create trigger emit_source_qualification_work_wake
after insert or update of status, available_at, information_lineage_version_id
on public.source_qualification_work_items
for each row execute function public.emit_source_qualification_work_wake();

create or replace function public.enqueue_source_qualification_work(
  enrollment_uuid uuid,
  subject_type_value text,
  subject_id_value text,
  assigned_source_location_value text,
  information_lineage_key_value text,
  priority_value integer default 0,
  available_at_value timestamptz default now()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  enrollment_record public.source_qualification_enrollments%rowtype;
  source_record public.trusted_sources%rowtype;
  applicability_record public.source_applicability_versions%rowtype;
  adapter_record public.catalog_domain_adapters%rowtype;
  context_value jsonb;
  resolved_source_uuid uuid;
  top_specificity integer;
  top_source_count integer;
  lineage_version_uuid uuid;
  work_uuid uuid;
  applicability_version_uuid uuid;
  stored_lineage_version_uuid uuid;
begin
  select * into strict enrollment_record
  from public.source_qualification_enrollments
  where id = enrollment_uuid for update;
  select * into strict source_record from public.trusted_sources
  where id = enrollment_record.source_id;
  if source_record.review_status <> 'approved'
     or source_record.superseded_by_source_id is not null then
    raise exception 'A current approved canonical source is required';
  end if;
  select * into strict adapter_record from public.catalog_domain_adapters
  where data_type = enrollment_record.data_type and active;
  if adapter_record.build_source_qualification_context_function is null
     or adapter_record.normalize_source_qualification_result_function is null
     or adapter_record.compare_source_qualification_result_function is null
     or adapter_record.resolve_source_qualification_reference_function is null then
    raise exception 'The data type has no source-qualification adapter';
  end if;
  execute format('select %s($1,$2)',
    adapter_record.build_source_qualification_context_function::regproc)
    using subject_type_value, subject_id_value into context_value;
  if context_value is null or context_value -> 'subject' is null
     or context_value -> 'capability_scope' is null then
    raise exception 'The source-qualification subject is invalid';
  end if;
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
     and not public.has_catalog_capability(
       'source.qualification.work.enqueue',
       nullif(context_value #>> '{capability_scope,sport_id}','')::uuid,
       nullif(context_value #>> '{capability_scope,league_id}','')::uuid,
       nullif(context_value #>> '{capability_scope,team_id}','')::uuid,
       nullif(context_value #>> '{capability_scope,venue_id}','')::uuid
     ) then
    raise exception 'Source qualification enqueue capability is required';
  end if;
  applicability_version_uuid := public.applicable_source_version_for_subject(
    enrollment_record.source_id, enrollment_record.data_type,
    context_value -> 'capability_scope'
  );
  if applicability_version_uuid is null then
    raise exception 'Current approved source applicability is required for this subject';
  end if;
  select * into strict applicability_record
  from public.source_applicability_versions
  where id = applicability_version_uuid;

  select max(match.specificity) into top_specificity
  from public.trusted_source_url_matches(assigned_source_location_value) match;
  if top_specificity is null then
    raise exception 'Assigned source location is outside every approved URL scope';
  end if;
  select count(distinct match.canonical_source_id),
         (array_agg(distinct match.canonical_source_id))[1]
    into top_source_count, resolved_source_uuid
  from public.trusted_source_url_matches(assigned_source_location_value) match
  where match.specificity = top_specificity;
  if top_source_count <> 1
     or resolved_source_uuid <> enrollment_record.source_id then
    raise exception 'Assigned source location does not resolve uniquely to the enrolled source';
  end if;

  if nullif(btrim(information_lineage_key_value), '') is not null then
    if not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
       and not public.has_catalog_capability('information_lineage.resolve')
       and not public.has_catalog_capability('information_lineage.review') then
      raise exception 'Information-lineage resolver or reviewer authority is required to assign a known lineage';
    end if;
    lineage_version_uuid := public.current_approved_information_lineage_version(
      btrim(information_lineage_key_value), enrollment_record.data_type
    );
    if lineage_version_uuid is null
       or public.current_information_lineage_root(lineage_version_uuid) is null then
      raise exception 'A current approved information lineage is required';
    end if;
  end if;

  insert into public.source_qualification_work_items(
    enrollment_id, data_type, subject_type, subject_id, capability_scope,
    applicability_version_id,
    assigned_source_location, information_lineage_version_id,
    priority, available_at
  ) values (
    enrollment_record.id, enrollment_record.data_type,
    subject_type_value, subject_id_value,
    context_value -> 'capability_scope', applicability_version_uuid,
    assigned_source_location_value,
    lineage_version_uuid, priority_value, coalesce(available_at_value, now())
  )
  on conflict (enrollment_id, subject_type, subject_id)
  do update set enrollment_id = excluded.enrollment_id
  returning id, information_lineage_version_id
    into work_uuid, stored_lineage_version_uuid;

  insert into public.source_qualification_work_events(
    work_item_id, actor_id, event_type, details
  )
  select work_uuid, actor_uuid, 'queued', jsonb_strip_nulls(jsonb_build_object(
    'data_type', enrollment_record.data_type,
    'subject_type', subject_type_value,
    'subject_id', subject_id_value,
    'source_id', source_record.source_id,
    'applicability_version_id', applicability_version_uuid,
    'information_lineage_version_id', stored_lineage_version_uuid
  ))
  where not exists (
    select 1 from public.source_qualification_work_events event
    where event.work_item_id = work_uuid and event.event_type = 'queued'
  );

  if stored_lineage_version_uuid is null then
    perform public.enqueue_information_lineage_resolution_work(
      'source_qualification_work', work_uuid,
      enrollment_record.data_type, subject_type_value, subject_id_value
    );
    insert into public.source_qualification_work_events(
      work_item_id, actor_id, event_type, details
    )
    select work_uuid, actor_uuid, 'waiting_on_information_lineage',
           jsonb_build_object(
             'data_type', enrollment_record.data_type,
             'source_id', source_record.source_id
           )
    where not exists (
      select 1 from public.source_qualification_work_events event
      where event.work_item_id = work_uuid
        and event.event_type = 'waiting_on_information_lineage'
    );
  end if;
  return work_uuid;
end;
$$;

create or replace function public.claim_next_source_qualification_work(
  data_type_value text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.source_qualification_work_items%rowtype;
  adapter_record public.catalog_domain_adapters%rowtype;
  runtime_policy public.agent_job_runtime_policies%rowtype;
  lease_uuid uuid := gen_random_uuid();
begin
  if actor_uuid is null then raise exception 'An active catalog actor is required'; end if;
  select work.* into work_record
  from public.source_qualification_work_items work
  join public.catalog_domain_adapters adapter
    on adapter.data_type = work.data_type and adapter.active
  where work.status in ('queued','retry_wait')
    and work.available_at <= now()
    and public.source_qualification_lineage_is_ready(work.id)
    and (data_type_value is null or work.data_type = data_type_value)
    and adapter.specialist_job_type is not null
    and exists (
      select 1 from public.agent_job_runtime_policies policy
      where policy.job_type = adapter.specialist_job_type
        and policy.is_current and policy.active and policy.lease_seconds is not null
    )
    and public.has_catalog_capability(
      'source.qualification.work',
      nullif(work.capability_scope ->> 'sport_id','')::uuid,
      nullif(work.capability_scope ->> 'league_id','')::uuid,
      nullif(work.capability_scope ->> 'team_id','')::uuid,
      nullif(work.capability_scope ->> 'venue_id','')::uuid
    )
  order by work.priority desc, work.available_at, work.created_at, work.id
  for update of work skip locked
  limit 1;
  if not found then return null; end if;
  select * into strict adapter_record from public.catalog_domain_adapters
  where data_type = work_record.data_type and active;
  select * into strict runtime_policy
  from public.current_agent_job_runtime_policy(adapter_record.specialist_job_type);
  update public.source_qualification_work_items
  set status = 'claimed', claimed_by_actor_id = actor_uuid,
      lease_token = lease_uuid,
      lease_expires_at = now() + make_interval(secs => runtime_policy.lease_seconds),
      attempt_count = attempt_count + 1,
      failure_category = null, failure_reason = null, updated_at = now()
  where id = work_record.id
  returning * into work_record;
  insert into public.source_qualification_attempts(
    work_item_id, attempt_number, actor_id, lease_token, lease_expires_at
  ) values (
    work_record.id, work_record.attempt_count, actor_uuid,
    lease_uuid, work_record.lease_expires_at
  );
  insert into public.source_qualification_work_events(
    work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    work_record.id, work_record.attempt_count, actor_uuid, 'claimed',
    jsonb_build_object(
      'lease_expires_at', work_record.lease_expires_at,
      'runtime_policy_id', runtime_policy.id,
      'runtime_job_type', adapter_record.specialist_job_type
    )
  );
  return public.get_my_source_qualification_work(work_record.id, lease_uuid);
end;
$$;

create or replace function public.reconcile_source_qualification_wakes(
  data_type_value text default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare reconciled_count integer;
begin
  insert into public.agent_work_wake_outbox(
    queue_name, work_item_id, event_kind, eligibility_key, available_at
  )
  select 'source_qualification.' || work.data_type, work.id, 'work_ready',
         work.status || ':' || extract(epoch from work.available_at)::text,
         work.available_at
  from public.source_qualification_work_items work
  where work.status in ('queued','retry_wait') and work.available_at <= now()
    and public.source_qualification_lineage_is_ready(work.id)
    and (data_type_value is null or work.data_type = data_type_value)
  on conflict (queue_name, work_item_id, event_kind, eligibility_key)
  do update set status = 'pending', acknowledged_at = null,
                acknowledged_by_actor_id = null;
  get diagnostics reconciled_count = row_count;
  return reconciled_count;
end;
$$;

create or replace function public.get_my_information_lineage_resolution_work(
  work_item_uuid uuid,
  lease_token_value uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.information_lineage_resolution_work_items%rowtype;
  evidence_value jsonb;
  candidates_value jsonb;
begin
  select * into strict work_record
  from public.information_lineage_resolution_work_items
  where id = work_item_uuid;

  if actor_uuid is null
     or not public.has_catalog_capability('information_lineage.resolve')
     or work_record.status <> 'claimed'
     or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value
     or work_record.lease_expires_at <= now() then
    raise exception 'An active lineage-resolution lease owned by a resolver is required';
  end if;

  if work_record.evidence_kind = 'proposal_evidence' then
    select jsonb_strip_nulls(jsonb_build_object(
      'evidence_kind', work_record.evidence_kind,
      'evidence_id', evidence.id,
      'submitted_source', jsonb_build_object(
        'source_id', submitted_source.source_id,
        'display_name', submitted_source.display_name
      ),
      'current_canonical_source', jsonb_build_object(
        'source_id', canonical_source.source_id,
        'display_name', canonical_source.display_name
      ),
      'evidence_location', evidence.evidence_url,
      'observed_at', evidence.observed_at
    )) into evidence_value
    from public.catalog_proposal_evidence evidence
    join public.catalog_change_proposals proposal
      on proposal.id = evidence.proposal_id
    join public.trusted_sources submitted_source on submitted_source.id = evidence.source_id
    join public.trusted_sources canonical_source
      on canonical_source.id = public.canonical_trusted_source_id(evidence.source_id)
    where evidence.id = work_record.evidence_id
      and proposal.fact_type = work_record.data_type;
  elsif work_record.evidence_kind = 'verifier_evidence' then
    select jsonb_strip_nulls(jsonb_build_object(
      'evidence_kind', work_record.evidence_kind,
      'evidence_id', evidence.id,
      'submitted_source', jsonb_build_object(
        'source_id', submitted_source.source_id,
        'display_name', submitted_source.display_name
      ),
      'current_canonical_source', jsonb_build_object(
        'source_id', canonical_source.source_id,
        'display_name', canonical_source.display_name
      ),
      'evidence_location', evidence.evidence_url,
      'observed_at', evidence.observed_at
    )) into evidence_value
    from public.catalog_verifier_evidence evidence
    join public.catalog_verification_work_items verification_work
      on verification_work.id = evidence.verification_work_item_id
    join public.trusted_sources submitted_source on submitted_source.id = evidence.source_id
    join public.trusted_sources canonical_source
      on canonical_source.id = public.canonical_trusted_source_id(evidence.source_id)
    where evidence.id = work_record.evidence_id
      and verification_work.data_type = work_record.data_type;
  elsif work_record.evidence_kind = 'source_qualification_work' then
    select jsonb_build_object(
      'evidence_kind', work_record.evidence_kind,
      'evidence_id', qualification_work.id,
      'submitted_source', jsonb_build_object(
        'source_id', source.source_id,
        'display_name', source.display_name
      ),
      'current_canonical_source', jsonb_build_object(
        'source_id', canonical_source.source_id,
        'display_name', canonical_source.display_name
      ),
      'evidence_location', qualification_work.assigned_source_location
    ) into evidence_value
    from public.source_qualification_work_items qualification_work
    join public.source_qualification_enrollments enrollment
      on enrollment.id = qualification_work.enrollment_id
    join public.trusted_sources source on source.id = enrollment.source_id
    join public.trusted_sources canonical_source
      on canonical_source.id = public.canonical_trusted_source_id(source.id)
    where qualification_work.id = work_record.evidence_id
      and qualification_work.data_type = work_record.data_type
      and qualification_work.subject_type = work_record.subject_type
      and qualification_work.subject_id = work_record.subject_id;
  end if;

  if evidence_value is null then
    raise exception 'The lineage-resolution evidence record was not found';
  end if;

  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
    'lineage_key', lineage.lineage_key,
    'display_name', version.display_name,
    'origin_url', version.origin_url
  )) order by lineage.lineage_key), '[]'::jsonb)
  into candidates_value
  from public.information_lineages lineage
  join public.information_lineage_versions version
    on version.lineage_id = lineage.id and version.is_current
  where lineage.data_type = work_record.data_type
    and version.review_status = 'approved'
    and public.current_information_lineage_root(version.id) = lineage.id;

  return jsonb_build_object(
    'work', jsonb_build_object(
      'work_item_id', work_record.id,
      'data_type', work_record.data_type,
      'subject_type', work_record.subject_type,
      'subject_id', work_record.subject_id,
      'attempt_number', work_record.attempt_count,
      'lease_token', work_record.lease_token,
      'lease_expires_at', work_record.lease_expires_at
    ),
    'evidence', evidence_value,
    'approved_lineage_candidates', candidates_value
  );
end;
$$;

create or replace function public.attach_resolved_source_qualification_lineage(
  qualification_work_uuid uuid,
  lineage_version_uuid uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  work_record public.source_qualification_work_items%rowtype;
  lineage_data_type text;
begin
  select * into strict work_record
  from public.source_qualification_work_items
  where id = qualification_work_uuid for update;
  select lineage.data_type into lineage_data_type
  from public.information_lineage_versions version
  join public.information_lineages lineage on lineage.id = version.lineage_id
  where version.id = lineage_version_uuid
    and public.current_information_lineage_root(version.id) is not null;
  if lineage_data_type is null or lineage_data_type <> work_record.data_type then
    raise exception 'Resolved information lineage must match the qualification data type';
  end if;
  if work_record.information_lineage_version_id is not null then
    return work_record.information_lineage_version_id = lineage_version_uuid;
  end if;
  update public.source_qualification_work_items
  set information_lineage_version_id = lineage_version_uuid,
      updated_at = now()
  where id = work_record.id;
  insert into public.source_qualification_work_events(
    work_item_id, event_type, details
  )
  select work_record.id, 'information_lineage_ready',
         jsonb_build_object('information_lineage_version_id', lineage_version_uuid)
  where not exists (
    select 1 from public.source_qualification_work_events event
    where event.work_item_id = work_record.id
      and event.event_type = 'information_lineage_ready'
  );
  return true;
end;
$$;

create or replace function public.resume_catalog_verification_after_lineage_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.evidence_kind = 'source_qualification_work' then
    perform public.attach_resolved_source_qualification_lineage(
      new.evidence_id, new.information_lineage_version_id
    );
  else
    perform public.reconcile_catalog_verification_comparison_wake_for_evidence(
      new.evidence_kind, new.evidence_id
    );
  end if;
  return new;
end;
$$;

create or replace function public.run_agent_backend_recovery()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  verifier_expired integer := 0;
  lineage_expired integer := 0;
  comparisons_processed integer := 0;
  wakes_reconciled integer := 0;
  verifier_wakes_reconciled integer := 0;
  lineage_wakes_reconciled integer := 0;
  comparison_wakes_reconciled integer := 0;
  qualification_wakes_reconciled integer := 0;
  domain_recovery jsonb := '{}'::jsonb;
  adapter_record public.catalog_domain_adapters%rowtype;
  adapter_recovery jsonb;
  adapter_wakes integer;
  stranded record;
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
     and not public.has_catalog_capability('agent.watchdog.run') then
    raise exception 'Agent watchdog capability is required';
  end if;
  if not pg_try_advisory_xact_lock(hashtextextended('fanatical-agent-backend-recovery', 0)) then
    return jsonb_build_object('status', 'already_running');
  end if;
  verifier_expired := public.expire_catalog_verification_work_leases();
  lineage_expired := public.expire_information_lineage_resolution_work_leases();

  for adapter_record in
    select * from public.catalog_domain_adapters where active order by data_type
  loop
    if adapter_record.recover_domain_function is not null then
      execute format('select %s()', adapter_record.recover_domain_function::regproc)
        into adapter_recovery;
      domain_recovery := domain_recovery || jsonb_build_object(
        adapter_record.data_type, coalesce(adapter_recovery, '{}'::jsonb)
      );
    end if;
    if adapter_record.reconcile_wakes_function is not null then
      execute format('select %s()', adapter_record.reconcile_wakes_function::regproc)
        into adapter_wakes;
      wakes_reconciled := wakes_reconciled + coalesce(adapter_wakes, 0);
    end if;
  end loop;

  comparison_wakes_reconciled :=
    public.reconcile_catalog_verification_comparison_wakes();
  wakes_reconciled := wakes_reconciled + comparison_wakes_reconciled;

  for stranded in
    select result.id
    from public.catalog_verifier_results result
    join public.catalog_verification_work_items work
      on work.id = result.verification_work_item_id
    where work.status = 'result_submitted'
      and work.accepted_result_id = result.id
      and not exists (
        select 1 from public.catalog_verification_comparisons comparison
        where comparison.verifier_result_id = result.id
      )
      and coalesce((
        public.catalog_verification_lineage_readiness(result.id) ->> 'ready'
      )::boolean, false)
    for update of work skip locked
  loop
    begin
      perform public.process_catalog_verification_result(stranded.id);
      comparisons_processed := comparisons_processed + 1;
    exception when others then
      update public.catalog_verification_work_items
      set status = 'needs_review', failure_category = 'comparison_error',
          failure_reason = sqlerrm
      where accepted_result_id = stranded.id and status = 'result_submitted';
      insert into public.catalog_verification_work_events(
        verification_work_item_id, actor_id, event_type, details
      )
      select result.verification_work_item_id, actor_uuid, 'comparison_error',
             jsonb_build_object('verifier_result_id', stranded.id, 'error', sqlerrm)
      from public.catalog_verifier_results result where result.id = stranded.id;
    end;
  end loop;

  insert into public.agent_work_wake_outbox(
    queue_name, work_item_id, event_kind, eligibility_key, available_at
  )
  select 'catalog_verifier.' || work.data_type, work.id, 'work_ready',
         work.status || ':' || extract(epoch from work.available_at)::text,
         work.available_at
  from public.catalog_verification_work_items work
  where work.status in ('queued','retry_wait') and work.available_at <= now()
  on conflict (queue_name, work_item_id, event_kind, eligibility_key)
  do update set status = 'pending', acknowledged_at = null,
                acknowledged_by_actor_id = null;
  get diagnostics verifier_wakes_reconciled = row_count;
  wakes_reconciled := wakes_reconciled + verifier_wakes_reconciled;
  lineage_wakes_reconciled := public.reconcile_information_lineage_resolution_wakes();
  wakes_reconciled := wakes_reconciled + lineage_wakes_reconciled;
  qualification_wakes_reconciled := public.reconcile_source_qualification_wakes();
  wakes_reconciled := wakes_reconciled + qualification_wakes_reconciled;

  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, details
  ) values (
    actor_uuid, auth.uid(), 'agent_backend.recovery_run', 'agent_backend',
    jsonb_build_object(
      'verifier_expired', verifier_expired,
      'lineage_expired', lineage_expired,
      'domain_recovery', domain_recovery,
      'comparisons_processed', comparisons_processed,
      'comparison_wakes_reconciled', comparison_wakes_reconciled,
      'qualification_wakes_reconciled', qualification_wakes_reconciled,
      'wakes_reconciled', wakes_reconciled
    )
  );
  return jsonb_build_object(
    'status', 'completed',
    'verifier_expired', verifier_expired,
    'lineage_expired', lineage_expired,
    'domain_recovery', domain_recovery,
    'comparisons_processed', comparisons_processed,
    'comparison_wakes_reconciled', comparison_wakes_reconciled,
    'qualification_wakes_reconciled', qualification_wakes_reconciled,
    'wakes_reconciled', wakes_reconciled
  );
end;
$$;

comment on function public.get_my_information_lineage_resolution_work(uuid,uuid) is
  'Returns only leased work metadata, the assigned evidence location/source identity, and approved lineage candidates. Qualification targets use their durable work row and expose no source claim or reference answer.';

revoke all on function public.source_qualification_lineage_is_ready(uuid)
from public, anon, authenticated;
revoke all on function public.attach_resolved_source_qualification_lineage(uuid,uuid)
from public, anon, authenticated;

commit;
