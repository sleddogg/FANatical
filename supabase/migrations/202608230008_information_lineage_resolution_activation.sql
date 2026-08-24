-- Activate the generic information-lineage resolution path already introduced
-- by 202608230004. This migration adds no second queue or lifecycle engine.

-- ---------------------------------------------------------------------------
-- Canonical lineage lookup and narrow leased-worker context
-- ---------------------------------------------------------------------------

create or replace function public.current_approved_information_lineage_version(
  lineage_key_value text,
  data_type_value text
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  with requested as (
    select version.id
    from public.information_lineages lineage
    join public.information_lineage_versions version
      on version.lineage_id = lineage.id and version.is_current
    where lineage.lineage_key = lineage_key_value
      and lineage.data_type = data_type_value
      and version.review_status in ('approved','merged')
  ), canonical as (
    select public.current_information_lineage_root(requested.id) as lineage_id
    from requested
  )
  select version.id
  from canonical
  join public.information_lineage_versions version
    on version.lineage_id = canonical.lineage_id and version.is_current
  where version.review_status = 'approved';
$$;

comment on function public.current_approved_information_lineage_version(text,text) is
  'Resolves an approved lineage key or prospectively merged lineage key to the current approved canonical lineage version.';

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

comment on function public.get_my_information_lineage_resolution_work(uuid,uuid) is
  'Returns only leased work metadata, the assigned evidence location/source identity, and approved lineage candidates. It excludes factual answers, reasoning, other evidence, ownership, trust, applicability, and reliability context.';

create or replace function public.claim_next_information_lineage_resolution_work(
  data_type_value text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.information_lineage_resolution_work_items%rowtype;
  runtime_policy public.agent_job_runtime_policies%rowtype;
  lease_uuid uuid := gen_random_uuid();
begin
  if actor_uuid is null or not public.has_catalog_capability('information_lineage.resolve') then
    raise exception 'Information-lineage resolver capability is required';
  end if;
  select work.* into work_record
  from public.information_lineage_resolution_work_items work
  where work.status in ('queued','retry_wait') and work.available_at <= now()
    and (data_type_value is null or work.data_type = data_type_value)
    and exists (
      select 1 from public.agent_job_runtime_policies policy
      where policy.job_type = 'information_lineage_resolver.' || work.data_type
        and policy.is_current and policy.active and policy.lease_seconds is not null
    )
  order by work.available_at, work.created_at, work.id
  for update skip locked limit 1;
  if not found then return null; end if;
  select * into strict runtime_policy from public.current_agent_job_runtime_policy(
    'information_lineage_resolver.' || work_record.data_type
  );
  update public.information_lineage_resolution_work_items
  set status = 'claimed', claimed_by_actor_id = actor_uuid,
      lease_token = lease_uuid,
      lease_expires_at = now() + make_interval(secs => runtime_policy.lease_seconds),
      attempt_count = attempt_count + 1,
      updated_at = now()
  where id = work_record.id returning * into work_record;
  insert into public.information_lineage_resolution_attempts(
    work_item_id, attempt_number, actor_id, lease_token, lease_expires_at
  ) values (
    work_record.id, work_record.attempt_count, actor_uuid,
    lease_uuid, work_record.lease_expires_at
  );
  update public.agent_work_wake_outbox set status = 'acknowledged',
    acknowledged_at = now(), acknowledged_by_actor_id = actor_uuid
  where queue_name = 'information_lineage_resolver.' || work_record.data_type
    and work_item_id = work_record.id and status = 'pending';
  return public.get_my_information_lineage_resolution_work(
    work_record.id, work_record.lease_token
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Generic factual-comparison lineage barrier and resume path
-- ---------------------------------------------------------------------------

create or replace function public.catalog_verification_lineage_readiness(
  verifier_result_uuid uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result_record public.catalog_verifier_results%rowtype;
  work_record public.catalog_verification_work_items%rowtype;
  attempt_number_value integer;
  proposal_evidence_count integer := 0;
  unresolved_proposal_evidence_count integer := 0;
  verifier_evidence_count integer := 0;
  unresolved_verifier_evidence_count integer := 0;
begin
  select * into strict result_record
  from public.catalog_verifier_results where id = verifier_result_uuid;
  select * into strict work_record
  from public.catalog_verification_work_items
  where id = result_record.verification_work_item_id;
  select attempt_number into strict attempt_number_value
  from public.catalog_verification_attempts
  where id = result_record.verification_attempt_id;

  if work_record.specialist_result_kind = 'catalog_proposal' then
    select count(*), count(*) filter (
      where public.current_information_lineage_root(coalesce(
        evidence.information_lineage_version_id,
        assignment.information_lineage_version_id
      )) is null
    )
    into proposal_evidence_count, unresolved_proposal_evidence_count
    from public.catalog_proposal_evidence evidence
    left join public.catalog_evidence_lineage_assignments assignment
      on assignment.evidence_kind = 'proposal_evidence'
     and assignment.evidence_id = evidence.id
     and assignment.is_current
    where evidence.proposal_id = work_record.specialist_result_id;
  end if;

  select count(*), count(*) filter (
    where public.current_information_lineage_root(coalesce(
      evidence.information_lineage_version_id,
      assignment.information_lineage_version_id
    )) is null
  )
  into verifier_evidence_count, unresolved_verifier_evidence_count
  from public.catalog_verifier_evidence evidence
  left join public.catalog_evidence_lineage_assignments assignment
    on assignment.evidence_kind = 'verifier_evidence'
   and assignment.evidence_id = evidence.id
   and assignment.is_current
  where evidence.verification_work_item_id = work_record.id
    and evidence.attempt_number = attempt_number_value;

  return jsonb_build_object(
    'ready', unresolved_proposal_evidence_count = 0
      and unresolved_verifier_evidence_count = 0,
    'proposal_evidence_count', proposal_evidence_count,
    'unresolved_proposal_evidence_count', unresolved_proposal_evidence_count,
    'verifier_evidence_count', verifier_evidence_count,
    'unresolved_verifier_evidence_count', unresolved_verifier_evidence_count
  );
end;
$$;

comment on function public.catalog_verification_lineage_readiness(uuid) is
  'Generic pre-comparison barrier state for all proposal evidence and all evidence belonging to the accepted verifier attempt.';

create or replace function public.reconcile_catalog_verification_comparison_wake_for_evidence(
  evidence_kind_value text,
  evidence_uuid uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidate record;
  readiness_value jsonb;
  reconciled_count integer := 0;
begin
  if evidence_kind_value not in ('proposal_evidence','verifier_evidence') then
    raise exception 'Unsupported lineage-resolution evidence kind';
  end if;
  for candidate in
    select distinct work.id as work_item_id, result.id as verifier_result_id
    from public.catalog_verification_work_items work
    join public.catalog_verifier_results result
      on result.id = work.accepted_result_id
    where work.status = 'result_submitted'
      and not exists (
        select 1 from public.catalog_verification_comparisons comparison
        where comparison.verifier_result_id = result.id
      )
      and (
        (evidence_kind_value = 'proposal_evidence' and exists (
          select 1
          from public.catalog_proposal_evidence evidence
          where evidence.id = evidence_uuid
            and work.specialist_result_kind = 'catalog_proposal'
            and work.specialist_result_id = evidence.proposal_id
        ))
        or
        (evidence_kind_value = 'verifier_evidence' and exists (
          select 1
          from public.catalog_verifier_evidence evidence
          join public.catalog_verification_attempts attempt
            on attempt.id = result.verification_attempt_id
          where evidence.id = evidence_uuid
            and evidence.verification_work_item_id = work.id
            and evidence.attempt_number = attempt.attempt_number
        ))
      )
  loop
    readiness_value := public.catalog_verification_lineage_readiness(
      candidate.verifier_result_id
    );
    if coalesce((readiness_value ->> 'ready')::boolean, false) then
      perform public.emit_agent_work_wake(
        'catalog_verification_comparison', candidate.work_item_id,
        'result_ready', now(), candidate.verifier_result_id::text
      );
      insert into public.catalog_verification_work_events(
        verification_work_item_id, event_type, details
      )
      select candidate.work_item_id, 'information_lineage_ready',
             jsonb_build_object(
               'verifier_result_id', candidate.verifier_result_id,
               'lineage_readiness', readiness_value
             )
      where not exists (
        select 1 from public.catalog_verification_work_events event
        where event.verification_work_item_id = candidate.work_item_id
          and event.event_type = 'information_lineage_ready'
          and event.details ->> 'verifier_result_id' = candidate.verifier_result_id::text
      );
      reconciled_count := reconciled_count + 1;
    end if;
  end loop;
  return reconciled_count;
end;
$$;

create or replace function public.reconcile_catalog_verification_comparison_wakes()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidate record;
  reconciled_count integer := 0;
begin
  for candidate in
    select work.id as work_item_id, result.id as verifier_result_id
    from public.catalog_verification_work_items work
    join public.catalog_verifier_results result
      on result.id = work.accepted_result_id
    where work.status = 'result_submitted'
      and not exists (
        select 1 from public.catalog_verification_comparisons comparison
        where comparison.verifier_result_id = result.id
      )
      and coalesce((
        public.catalog_verification_lineage_readiness(result.id) ->> 'ready'
      )::boolean, false)
    order by work.created_at, work.id
  loop
    perform public.emit_agent_work_wake(
      'catalog_verification_comparison', candidate.work_item_id,
      'result_ready', now(), candidate.verifier_result_id::text
    );
    reconciled_count := reconciled_count + 1;
  end loop;
  return reconciled_count;
end;
$$;

create or replace function public.resume_catalog_verification_after_lineage_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.reconcile_catalog_verification_comparison_wake_for_evidence(
    new.evidence_kind, new.evidence_id
  );
  return new;
end;
$$;

create trigger resume_catalog_verification_after_lineage_assignment
after insert on public.catalog_evidence_lineage_assignments
for each row execute function public.resume_catalog_verification_after_lineage_assignment();

create or replace function public.complete_lineage_resolution_after_governed_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.information_lineage_version_id is null
     or new.information_lineage_version_id is not distinct from old.information_lineage_version_id then
    return new;
  end if;
  update public.information_lineage_resolution_attempts attempt
  set ended_at = now(), outcome = 'completed_elsewhere'
  from public.information_lineage_resolution_work_items work
  where work.evidence_kind = 'proposal_evidence'
    and work.evidence_id = new.id
    and attempt.work_item_id = work.id and attempt.ended_at is null;
  update public.information_lineage_resolution_work_items
  set status = 'completed', claimed_by_actor_id = null,
      lease_token = null, lease_expires_at = null,
      failure_category = null, failure_reason = null,
      completed_at = now(), updated_at = now()
  where evidence_kind = 'proposal_evidence' and evidence_id = new.id
    and status not in ('completed','cancelled');
  perform public.reconcile_catalog_verification_comparison_wake_for_evidence(
    'proposal_evidence', new.id
  );
  return new;
end;
$$;

create or replace function public.process_catalog_verification_result(
  verifier_result_uuid uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.catalog_verification_work_items%rowtype;
  adapter_record public.catalog_domain_adapters%rowtype;
  readiness_value jsonb;
  outcome_value text;
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
     and not public.has_catalog_capability('agent.comparison.run')
     and not public.has_catalog_capability('agent.watchdog.run') then
    raise exception 'Agent comparison-run capability is required';
  end if;
  select work.* into strict work_record
  from public.catalog_verifier_results result
  join public.catalog_verification_work_items work
    on work.id = result.verification_work_item_id
  where result.id = verifier_result_uuid;
  select * into strict adapter_record from public.catalog_domain_adapters
  where data_type = work_record.data_type and active;

  if not exists (
    select 1 from public.catalog_verification_comparisons comparison
    where comparison.verifier_result_id = verifier_result_uuid
  ) and work_record.status = 'result_submitted'
    and work_record.accepted_result_id = verifier_result_uuid then
    readiness_value := public.catalog_verification_lineage_readiness(
      verifier_result_uuid
    );
    if not coalesce((readiness_value ->> 'ready')::boolean, false) then
      insert into public.catalog_verification_work_events(
        verification_work_item_id, actor_id, event_type, details
      )
      select work_record.id, actor_uuid, 'waiting_on_information_lineage',
             jsonb_build_object(
               'verifier_result_id', verifier_result_uuid,
               'lineage_readiness', readiness_value
             )
      where not exists (
        select 1 from public.catalog_verification_work_events event
        where event.verification_work_item_id = work_record.id
          and event.event_type = 'waiting_on_information_lineage'
          and event.details ->> 'verifier_result_id' = verifier_result_uuid::text
      );
      update public.agent_work_wake_outbox
      set status = 'acknowledged', acknowledged_at = now(),
          acknowledged_by_actor_id = actor_uuid
      where queue_name = 'catalog_verification_comparison'
        and work_item_id = work_record.id
        and event_kind = 'result_ready'
        and eligibility_key = verifier_result_uuid::text
        and status = 'pending';
      return 'waiting_on_information_lineage';
    end if;
  end if;

  execute format('select %s($1)', adapter_record.compare_result_function::regproc)
    using verifier_result_uuid into outcome_value;
  return outcome_value;
end;
$$;

-- ---------------------------------------------------------------------------
-- Result application through existing lineage governance
-- ---------------------------------------------------------------------------

create or replace function public.submit_information_lineage_resolution_result(
  work_item_uuid uuid,
  lease_token_value uuid,
  resolution_action_value text,
  proposed_lineage_key_value text,
  resolution_basis_value text,
  provenance_value jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.information_lineage_resolution_work_items%rowtype;
  policy_record public.information_lineage_resolution_policies%rowtype;
  lineage_version_uuid uuid;
  disposition_value text;
  result_uuid uuid;
begin
  select * into strict work_record from public.information_lineage_resolution_work_items
  where id = work_item_uuid for update;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now()
     or not public.has_catalog_capability('information_lineage.resolve') then
    raise exception 'An active lineage-resolution lease and capability are required';
  end if;
  if resolution_action_value not in ('assign_existing','propose_new','unresolved')
     or nullif(btrim(resolution_basis_value), '') is null then
    raise exception 'A valid structured lineage resolution and basis are required';
  end if;
  if resolution_action_value in ('assign_existing','propose_new')
     and nullif(btrim(proposed_lineage_key_value), '') is null then
    raise exception 'A proposed lineage key is required for this resolution action';
  end if;
  select * into policy_record from public.information_lineage_resolution_policies
  where data_type = work_record.data_type and is_current and active;
  if resolution_action_value = 'assign_existing'
     and policy_record.id is not null
     and resolution_action_value = any(policy_record.automatically_permitted_actions) then
    lineage_version_uuid := public.current_approved_information_lineage_version(
      btrim(proposed_lineage_key_value), work_record.data_type
    );
    if lineage_version_uuid is null then
      raise exception 'Automatic assignment requires an existing current approved lineage';
    end if;
    disposition_value := 'automatically_applied';
  elsif resolution_action_value = 'unresolved' then
    disposition_value := 'unresolved';
  else
    disposition_value := 'pending_governance';
  end if;
  insert into public.information_lineage_resolution_results(
    work_item_id, submitted_by_actor_id, resolution_action,
    proposed_lineage_key, resolution_basis, provenance, policy_id, disposition
  ) values (
    work_record.id, actor_uuid, resolution_action_value,
    nullif(btrim(proposed_lineage_key_value), ''), btrim(resolution_basis_value),
    coalesce(provenance_value, '{}'::jsonb), policy_record.id, disposition_value
  ) returning id into result_uuid;
  if disposition_value = 'automatically_applied' then
    insert into public.catalog_evidence_lineage_assignments(
      evidence_kind, evidence_id, information_lineage_version_id,
      assignment_basis, resolution_result_id, assigned_by_actor_id
    ) values (
      work_record.evidence_kind, work_record.evidence_id, lineage_version_uuid,
      btrim(resolution_basis_value), result_uuid, actor_uuid
    );
  end if;
  update public.information_lineage_resolution_attempts
  set ended_at = now(), outcome = disposition_value
  where work_item_id = work_record.id
    and attempt_number = work_record.attempt_count and ended_at is null;
  update public.information_lineage_resolution_work_items
  set status = case disposition_value
        when 'automatically_applied' then 'completed'
        when 'unresolved' then 'unresolved'
        else 'needs_review' end,
      claimed_by_actor_id = null, lease_token = null, lease_expires_at = null,
      completed_at = case when disposition_value = 'automatically_applied' then now() else null end,
      updated_at = now()
  where id = work_record.id;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'information_lineage.resolution_submitted',
    'information_lineage_resolution_work', work_record.id::text,
    jsonb_build_object(
      'result_id', result_uuid,
      'resolution_action', resolution_action_value,
      'disposition', disposition_value,
      'policy_id', policy_record.id,
      'lineage_version_id', lineage_version_uuid,
      'evidence_kind', work_record.evidence_kind,
      'evidence_id', work_record.evidence_id
    )
  );
  return result_uuid;
end;
$$;

create or replace function public.apply_information_lineage_resolution_result(
  resolution_result_uuid uuid,
  approved_lineage_key_value text,
  application_basis_value text,
  provenance_value jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  result_record public.information_lineage_resolution_results%rowtype;
  work_record public.information_lineage_resolution_work_items%rowtype;
  lineage_version_uuid uuid;
  assignment_uuid uuid;
begin
  if actor_uuid is null
     or (
       not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
       and not public.has_catalog_capability('information_lineage.review')
     ) then
    raise exception 'Information-lineage review capability is required';
  end if;
  if nullif(btrim(application_basis_value), '') is null then
    raise exception 'A governance application basis is required';
  end if;
  select * into strict result_record
  from public.information_lineage_resolution_results
  where id = resolution_result_uuid;
  select * into strict work_record
  from public.information_lineage_resolution_work_items
  where id = result_record.work_item_id for update;
  if result_record.disposition <> 'pending_governance'
     or work_record.status <> 'needs_review' then
    raise exception 'Only a pending lineage-resolution proposal may be governed';
  end if;
  lineage_version_uuid := public.current_approved_information_lineage_version(
    btrim(approved_lineage_key_value), work_record.data_type
  );
  if lineage_version_uuid is null then
    raise exception 'A current approved information lineage for this data type is required';
  end if;
  insert into public.catalog_evidence_lineage_assignments(
    evidence_kind, evidence_id, information_lineage_version_id,
    assignment_basis, resolution_result_id, assigned_by_actor_id
  ) values (
    work_record.evidence_kind, work_record.evidence_id, lineage_version_uuid,
    btrim(application_basis_value), result_record.id, actor_uuid
  ) returning id into assignment_uuid;
  update public.information_lineage_resolution_work_items
  set status = 'completed', completed_at = now(), updated_at = now(),
      failure_category = null, failure_reason = null
  where id = work_record.id;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'information_lineage.resolution_applied',
    'information_lineage_resolution_work', work_record.id::text,
    jsonb_build_object(
      'assignment_id', assignment_uuid,
      'result_id', result_record.id,
      'lineage_version_id', lineage_version_uuid,
      'evidence_kind', work_record.evidence_kind,
      'evidence_id', work_record.evidence_id,
      'provenance', coalesce(provenance_value, '{}'::jsonb)
    )
  );
  return assignment_uuid;
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
    'wakes_reconciled', wakes_reconciled
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Approved Team Color activation and shared runtime controls
-- ---------------------------------------------------------------------------

insert into public.information_lineage_resolution_policies(
  policy_key, version, data_type, automatically_permitted_actions,
  configuration, active, is_current
) values (
  'team-color-information-lineage-resolution', 1, 'team_colors',
  array['assign_existing']::text[],
  jsonb_build_object(
    'new_lineage_requires_governance', true,
    'lineage_merge_requires_governance', true,
    'unresolved_work_remains_durable', true,
    'source_ownership_is_separate', true
  ), true, true
);

do $$
declare
  approved_runtime public.agent_job_runtime_policies%rowtype;
begin
  select * into strict approved_runtime
  from public.current_agent_job_runtime_policy('catalog_verifier.team_colors');
  insert into public.agent_job_runtime_policies(
    policy_key, version, job_type, lease_seconds,
    retryable_failure_categories, permanent_failure_categories,
    retry_delay_seconds, maximum_attempts, exhaustion_status,
    permanent_failure_status, configuration
  ) values (
    'team-color-information-lineage-resolver-runtime', 1,
    'information_lineage_resolver.team_colors', approved_runtime.lease_seconds,
    approved_runtime.retryable_failure_categories,
    approved_runtime.permanent_failure_categories,
    approved_runtime.retry_delay_seconds, approved_runtime.maximum_attempts,
    approved_runtime.exhaustion_status, approved_runtime.permanent_failure_status,
    approved_runtime.configuration || jsonb_build_object(
      'approved_runtime_source_policy_id', approved_runtime.id,
      'worker_pool', 'catalog_verifier',
      'resolver_capability', 'information_lineage.resolve',
      'governance_capability', 'information_lineage.review'
    )
  );
end;
$$;

-- Lineage resolution shares the existing verifier worker-pool and global
-- budgets. This reuses the approved limits instead of introducing a resolver
-- concurrency number.
create or replace function public.enforce_agent_worker_concurrency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  pool_name text;
  operating_policy public.agent_backend_operating_policies%rowtype;
  pool_limit integer;
  pool_claimed integer;
  globally_claimed integer;
begin
  if tg_table_name = 'source_qualification_work_items' then
    execute 'select specialist_job_type from public.catalog_domain_adapters where data_type = $1 and active'
      using to_jsonb(new) ->> 'data_type' into pool_name;
  elsif tg_table_name = 'information_lineage_resolution_work_items' then
    pool_name := 'catalog_verifier';
  else
    pool_name := tg_argv[0];
  end if;
  if new.status <> 'claimed'
     or (tg_op = 'UPDATE' and old.status = 'claimed') then
    return new;
  end if;
  perform pg_advisory_xact_lock(
    hashtextextended('fanatical-agent-operational-concurrency', 0)
  );
  select * into operating_policy
  from public.current_agent_backend_operating_policy();
  if operating_policy.id is null then
    raise exception 'The active agent backend operating policy is not configured';
  end if;
  pool_limit := public.current_agent_worker_pool_limit(pool_name);
  if pool_limit is null then
    raise exception 'Worker-pool concurrency policy is not configured for %', pool_name;
  end if;
  if pool_name = 'team_color_specialist' then
    select
      (select count(*) from public.team_color_work_items where status = 'claimed')
      +
      (select count(*)
       from public.source_qualification_work_items work
       join public.catalog_domain_adapters adapter on adapter.data_type = work.data_type
       where work.status = 'claimed'
         and adapter.specialist_job_type = 'team_color_specialist')
    into pool_claimed;
  elsif pool_name = 'catalog_verifier' then
    select
      (select count(*) from public.catalog_verification_work_items where status = 'claimed')
      +
      (select count(*) from public.information_lineage_resolution_work_items where status = 'claimed')
    into pool_claimed;
  else
    raise exception 'Unsupported operational worker pool %', pool_name;
  end if;
  if pool_claimed >= pool_limit then
    raise exception 'The % worker-pool concurrency limit of % is already reached',
      pool_name, pool_limit;
  end if;
  select
    (select count(*) from public.team_color_work_items where status = 'claimed')
    +
    (select count(*) from public.catalog_verification_work_items where status = 'claimed')
    +
    (select count(*) from public.source_qualification_work_items where status = 'claimed')
    +
    (select count(*) from public.information_lineage_resolution_work_items where status = 'claimed')
  into globally_claimed;
  if globally_claimed >= operating_policy.maximum_concurrent_operational_workers then
    raise exception 'The global operational-worker concurrency limit of % is already reached',
      operating_policy.maximum_concurrent_operational_workers;
  end if;
  return new;
end;
$$;

create trigger enforce_information_lineage_resolution_concurrency
before insert or update of status on public.information_lineage_resolution_work_items
for each row execute function public.enforce_agent_worker_concurrency();

-- ---------------------------------------------------------------------------
-- Narrow RPC exposure
-- ---------------------------------------------------------------------------

revoke all on function public.catalog_verification_lineage_readiness(uuid)
from public, anon, authenticated;
revoke all on function public.reconcile_catalog_verification_comparison_wake_for_evidence(text,uuid)
from public, anon, authenticated;
revoke all on function public.reconcile_catalog_verification_comparison_wakes()
from public, anon, authenticated;
revoke all on function public.resume_catalog_verification_after_lineage_assignment()
from public, anon, authenticated;
revoke all on function public.current_approved_information_lineage_version(text,text)
from public, anon, authenticated;
revoke all on function public.get_my_information_lineage_resolution_work(uuid,uuid)
from public, anon;
grant execute on function public.get_my_information_lineage_resolution_work(uuid,uuid)
to authenticated;
revoke all on function public.claim_next_information_lineage_resolution_work(text)
from public, anon;
grant execute on function public.claim_next_information_lineage_resolution_work(text)
to authenticated;
revoke all on function public.submit_information_lineage_resolution_result(uuid,uuid,text,text,text,jsonb)
from public, anon;
grant execute on function public.submit_information_lineage_resolution_result(uuid,uuid,text,text,text,jsonb)
to authenticated;
revoke all on function public.apply_information_lineage_resolution_result(uuid,text,text,jsonb)
from public, anon;
grant execute on function public.apply_information_lineage_resolution_result(uuid,text,text,jsonb)
to authenticated;
