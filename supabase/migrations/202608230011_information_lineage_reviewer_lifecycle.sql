-- Activate the durable information-lineage reviewer lifecycle for resolver
-- proposals that require separate governance. This reuses FANatical's
-- existing runtime-policy, lease, wake, recovery, audit, and lineage-
-- assignment infrastructure.

-- ---------------------------------------------------------------------------
-- Durable reviewer work, attempts, events, and immutable decisions
-- ---------------------------------------------------------------------------

create table public.information_lineage_review_work_items (
  id uuid primary key default gen_random_uuid(),
  resolution_result_id uuid not null unique
    references public.information_lineage_resolution_results(id),
  data_type text not null check (length(btrim(data_type)) > 0),
  status text not null default 'queued' check (status in (
    'queued','claimed','retry_wait','completed','rejected',
    'needs_review','failed','cancelled'
  )),
  available_at timestamptz not null default now(),
  claimed_by_actor_id uuid references public.catalog_actors(id),
  lease_token uuid,
  lease_expires_at timestamptz,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  failure_category text,
  failure_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  check (
    (status = 'claimed' and claimed_by_actor_id is not null
      and lease_token is not null and lease_expires_at is not null)
    or (status <> 'claimed' and claimed_by_actor_id is null
      and lease_token is null and lease_expires_at is null)
  )
);

create index information_lineage_review_work_claim_idx
on public.information_lineage_review_work_items(
  available_at, created_at, id
)
where status in ('queued','retry_wait');

create table public.information_lineage_review_attempts (
  id uuid primary key default gen_random_uuid(),
  work_item_id uuid not null
    references public.information_lineage_review_work_items(id),
  attempt_number integer not null check (attempt_number > 0),
  actor_id uuid not null references public.catalog_actors(id),
  lease_token uuid not null unique,
  claimed_at timestamptz not null default now(),
  last_heartbeat_at timestamptz not null default now(),
  lease_expires_at timestamptz not null,
  ended_at timestamptz,
  outcome text check (outcome in (
    'retry','completed','rejected','needs_review','failed','cancelled'
  )),
  failure_category text,
  failure_reason text,
  unique (work_item_id, attempt_number)
);

create table public.information_lineage_review_work_events (
  id bigint generated always as identity primary key,
  work_item_id uuid not null
    references public.information_lineage_review_work_items(id),
  attempt_number integer,
  actor_id uuid references public.catalog_actors(id),
  event_type text not null check (length(btrim(event_type)) > 0),
  details jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index information_lineage_review_work_events_idx
on public.information_lineage_review_work_events(
  work_item_id, occurred_at, id
);

create table public.information_lineage_review_decisions (
  id uuid primary key default gen_random_uuid(),
  work_item_id uuid not null unique
    references public.information_lineage_review_work_items(id),
  attempt_id uuid not null unique
    references public.information_lineage_review_attempts(id),
  reviewed_by_actor_id uuid not null references public.catalog_actors(id),
  disposition text not null check (disposition in (
    'approve_new','map_existing','reject'
  )),
  applied_lineage_key text,
  new_lineage_display_name text,
  new_lineage_origin_url text check (
    new_lineage_origin_url is null
    or new_lineage_origin_url ~* '^https?://[^[:space:]]+$'
  ),
  applied_lineage_version_id uuid
    references public.information_lineage_versions(id),
  review_basis text not null check (length(btrim(review_basis)) > 0),
  terminal_exception_code text,
  terminal_exception_reason text,
  provenance jsonb not null default '{}'::jsonb,
  decided_at timestamptz not null default now(),
  check (
    (disposition = 'approve_new'
      and applied_lineage_key is not null
      and new_lineage_display_name is not null
      and applied_lineage_version_id is not null
      and terminal_exception_code is null
      and terminal_exception_reason is null)
    or (disposition = 'map_existing'
      and applied_lineage_key is not null
      and new_lineage_display_name is null
      and new_lineage_origin_url is null
      and applied_lineage_version_id is not null
      and terminal_exception_code is null
      and terminal_exception_reason is null)
    or (disposition = 'reject'
      and applied_lineage_key is null
      and new_lineage_display_name is null
      and new_lineage_origin_url is null
      and applied_lineage_version_id is null
      and terminal_exception_code is not null
      and terminal_exception_reason is not null)
  )
);

create trigger information_lineage_review_work_set_updated_at
before update on public.information_lineage_review_work_items
for each row execute function public.set_updated_at();

create trigger information_lineage_review_events_append_only
before update or delete on public.information_lineage_review_work_events
for each row execute function public.protect_agent_backend_history();

create trigger information_lineage_review_decisions_append_only
before update or delete on public.information_lineage_review_decisions
for each row execute function public.protect_agent_backend_history();

comment on table public.information_lineage_review_work_items is
  'Durable separately authorized review work for a resolver proposal that requires information-lineage governance.';
comment on table public.information_lineage_review_decisions is
  'Immutable reviewer disposition. Approval and mapping apply through the governed lineage-assignment path; rejection records a terminal exception without assigning a lineage.';

-- Team Color reviewer work shares the already approved lineage-resolver
-- runtime values and verifier worker pool. This introduces no numeric policy.
do $$
declare
  approved_runtime public.agent_job_runtime_policies%rowtype;
begin
  select * into strict approved_runtime
  from public.current_agent_job_runtime_policy(
    'information_lineage_resolver.team_colors'
  );
  insert into public.agent_job_runtime_policies(
    policy_key, version, job_type, lease_seconds,
    retryable_failure_categories, permanent_failure_categories,
    retry_delay_seconds, maximum_attempts, exhaustion_status,
    permanent_failure_status, configuration
  ) values (
    'team-color-information-lineage-reviewer-runtime', 1,
    'information_lineage_reviewer.team_colors',
    approved_runtime.lease_seconds,
    approved_runtime.retryable_failure_categories,
    approved_runtime.permanent_failure_categories,
    approved_runtime.retry_delay_seconds,
    approved_runtime.maximum_attempts,
    approved_runtime.exhaustion_status,
    approved_runtime.permanent_failure_status,
    approved_runtime.configuration || jsonb_build_object(
      'approved_runtime_source_policy_id', approved_runtime.id,
      'worker_pool', 'catalog_verifier',
      'review_capability', 'information_lineage.review'
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Work creation and idempotent wake signalling
-- ---------------------------------------------------------------------------

create or replace function public.emit_information_lineage_review_work_wake()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('queued','retry_wait') then
    perform public.emit_agent_work_wake(
      'information_lineage_reviewer.' || new.data_type,
      new.id, 'work_ready', new.available_at,
      new.status || ':' || extract(epoch from new.available_at)::text
    );
  else
    update public.agent_work_wake_outbox
    set status = 'cancelled'
    where queue_name = 'information_lineage_reviewer.' || new.data_type
      and work_item_id = new.id and status = 'pending';
  end if;
  return new;
end;
$$;

create trigger emit_information_lineage_review_work_wake
after insert or update of status, available_at
on public.information_lineage_review_work_items
for each row execute function public.emit_information_lineage_review_work_wake();

create or replace function public.enqueue_information_lineage_review_work(
  resolution_result_uuid uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  result_record public.information_lineage_resolution_results%rowtype;
  resolution_work_record public.information_lineage_resolution_work_items%rowtype;
  review_work_uuid uuid;
begin
  select * into strict result_record
  from public.information_lineage_resolution_results
  where id = resolution_result_uuid;
  select * into strict resolution_work_record
  from public.information_lineage_resolution_work_items
  where id = result_record.work_item_id;
  if result_record.resolution_action <> 'propose_new'
     or result_record.disposition <> 'pending_governance' then
    raise exception 'Only a pending new-lineage proposal may create reviewer work';
  end if;
  insert into public.information_lineage_review_work_items(
    resolution_result_id, data_type
  ) values (
    result_record.id, resolution_work_record.data_type
  )
  on conflict (resolution_result_id) do update
    set resolution_result_id = excluded.resolution_result_id
  returning id into review_work_uuid;
  insert into public.information_lineage_review_work_events(
    work_item_id, actor_id, event_type, details
  )
  select review_work_uuid, public.current_catalog_actor_id(), 'review_queued',
         jsonb_build_object(
           'resolution_result_id', result_record.id,
           'resolution_work_item_id', resolution_work_record.id
         )
  where not exists (
    select 1 from public.information_lineage_review_work_events event
    where event.work_item_id = review_work_uuid
      and event.event_type = 'review_queued'
  );
  return review_work_uuid;
end;
$$;

create or replace function public.enqueue_pending_information_lineage_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.resolution_action = 'propose_new'
     and new.disposition = 'pending_governance' then
    perform public.enqueue_information_lineage_review_work(new.id);
  end if;
  return new;
end;
$$;

create trigger enqueue_pending_information_lineage_review
after insert on public.information_lineage_resolution_results
for each row execute function public.enqueue_pending_information_lineage_review();

create or replace function public.reconcile_information_lineage_review_work_items()
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
    select result.id
    from public.information_lineage_resolution_results result
    join public.information_lineage_resolution_work_items resolution_work
      on resolution_work.id = result.work_item_id
    where result.resolution_action = 'propose_new'
      and result.disposition = 'pending_governance'
      and resolution_work.status = 'needs_review'
      and not exists (
        select 1
        from public.information_lineage_review_work_items review_work
        where review_work.resolution_result_id = result.id
      )
    order by result.submitted_at, result.id
  loop
    perform public.enqueue_information_lineage_review_work(candidate.id);
    reconciled_count := reconciled_count + 1;
  end loop;
  return reconciled_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Narrow reviewer context and leased lifecycle RPCs
-- ---------------------------------------------------------------------------

create or replace function public.get_my_information_lineage_review_work(
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
  review_work_record public.information_lineage_review_work_items%rowtype;
  result_record public.information_lineage_resolution_results%rowtype;
  resolution_work_record public.information_lineage_resolution_work_items%rowtype;
  evidence_value jsonb;
  candidates_value jsonb;
begin
  select * into strict review_work_record
  from public.information_lineage_review_work_items
  where id = work_item_uuid;
  if actor_uuid is null
     or not public.has_catalog_capability('information_lineage.review')
     or review_work_record.status <> 'claimed'
     or review_work_record.claimed_by_actor_id <> actor_uuid
     or review_work_record.lease_token <> lease_token_value
     or review_work_record.lease_expires_at <= now() then
    raise exception 'An active lineage-review lease owned by a reviewer is required';
  end if;
  select * into strict result_record
  from public.information_lineage_resolution_results
  where id = review_work_record.resolution_result_id;
  select * into strict resolution_work_record
  from public.information_lineage_resolution_work_items
  where id = result_record.work_item_id;

  if resolution_work_record.evidence_kind = 'proposal_evidence' then
    select jsonb_strip_nulls(jsonb_build_object(
      'evidence_kind', resolution_work_record.evidence_kind,
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
    join public.trusted_sources submitted_source
      on submitted_source.id = evidence.source_id
    join public.trusted_sources canonical_source
      on canonical_source.id = public.canonical_trusted_source_id(evidence.source_id)
    where evidence.id = resolution_work_record.evidence_id
      and proposal.fact_type = resolution_work_record.data_type;
  elsif resolution_work_record.evidence_kind = 'verifier_evidence' then
    select jsonb_strip_nulls(jsonb_build_object(
      'evidence_kind', resolution_work_record.evidence_kind,
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
    join public.trusted_sources submitted_source
      on submitted_source.id = evidence.source_id
    join public.trusted_sources canonical_source
      on canonical_source.id = public.canonical_trusted_source_id(evidence.source_id)
    where evidence.id = resolution_work_record.evidence_id
      and verification_work.data_type = resolution_work_record.data_type;
  elsif resolution_work_record.evidence_kind = 'source_qualification_work' then
    select jsonb_build_object(
      'evidence_kind', resolution_work_record.evidence_kind,
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
    where qualification_work.id = resolution_work_record.evidence_id
      and qualification_work.data_type = resolution_work_record.data_type
      and qualification_work.subject_type = resolution_work_record.subject_type
      and qualification_work.subject_id = resolution_work_record.subject_id;
  end if;
  if evidence_value is null then
    raise exception 'The lineage-review evidence record was not found';
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
  where lineage.data_type = resolution_work_record.data_type
    and version.review_status = 'approved'
    and public.current_information_lineage_root(version.id) = lineage.id;

  return jsonb_build_object(
    'work', jsonb_build_object(
      'work_item_id', review_work_record.id,
      'data_type', review_work_record.data_type,
      'subject_type', resolution_work_record.subject_type,
      'subject_id', resolution_work_record.subject_id,
      'attempt_number', review_work_record.attempt_count,
      'lease_token', review_work_record.lease_token,
      'lease_expires_at', review_work_record.lease_expires_at
    ),
    'proposal', jsonb_build_object(
      'resolution_result_id', result_record.id,
      'proposed_lineage_key', result_record.proposed_lineage_key,
      'resolution_basis', result_record.resolution_basis,
      'provenance', result_record.provenance,
      'submitted_at', result_record.submitted_at
    ),
    'evidence', evidence_value,
    'approved_lineage_candidates', candidates_value
  );
end;
$$;

create or replace function public.claim_next_information_lineage_review_work(
  data_type_value text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  review_work_record public.information_lineage_review_work_items%rowtype;
  runtime_policy public.agent_job_runtime_policies%rowtype;
  lease_uuid uuid := gen_random_uuid();
begin
  if actor_uuid is null
     or not public.has_catalog_capability('information_lineage.review') then
    raise exception 'Information-lineage review capability is required';
  end if;
  select review_work.* into review_work_record
  from public.information_lineage_review_work_items review_work
  join public.information_lineage_resolution_results result
    on result.id = review_work.resolution_result_id
  join public.information_lineage_resolution_work_items resolution_work
    on resolution_work.id = result.work_item_id
  where review_work.status in ('queued','retry_wait')
    and review_work.available_at <= now()
    and resolution_work.status = 'needs_review'
    and result.resolution_action = 'propose_new'
    and result.disposition = 'pending_governance'
    and (data_type_value is null or review_work.data_type = data_type_value)
    and exists (
      select 1 from public.agent_job_runtime_policies policy
      where policy.job_type =
            'information_lineage_reviewer.' || review_work.data_type
        and policy.is_current and policy.active
        and policy.lease_seconds is not null
    )
  order by review_work.available_at, review_work.created_at, review_work.id
  for update of review_work skip locked limit 1;
  if not found then return null; end if;
  select * into strict runtime_policy
  from public.current_agent_job_runtime_policy(
    'information_lineage_reviewer.' || review_work_record.data_type
  );
  update public.information_lineage_review_work_items
  set status = 'claimed', claimed_by_actor_id = actor_uuid,
      lease_token = lease_uuid,
      lease_expires_at = now() + make_interval(secs => runtime_policy.lease_seconds),
      attempt_count = attempt_count + 1,
      failure_category = null, failure_reason = null,
      updated_at = now()
  where id = review_work_record.id
  returning * into review_work_record;
  insert into public.information_lineage_review_attempts(
    work_item_id, attempt_number, actor_id, lease_token, lease_expires_at
  ) values (
    review_work_record.id, review_work_record.attempt_count, actor_uuid,
    lease_uuid, review_work_record.lease_expires_at
  );
  update public.agent_work_wake_outbox
  set status = 'acknowledged', acknowledged_at = now(),
      acknowledged_by_actor_id = actor_uuid
  where queue_name =
        'information_lineage_reviewer.' || review_work_record.data_type
    and work_item_id = review_work_record.id and status = 'pending';
  insert into public.information_lineage_review_work_events(
    work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    review_work_record.id, review_work_record.attempt_count, actor_uuid,
    'claimed', jsonb_build_object(
      'lease_expires_at', review_work_record.lease_expires_at
    )
  );
  return public.get_my_information_lineage_review_work(
    review_work_record.id, review_work_record.lease_token
  );
end;
$$;

create or replace function public.renew_information_lineage_review_work_lease(
  work_item_uuid uuid,
  lease_token_value uuid
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  review_work_record public.information_lineage_review_work_items%rowtype;
  runtime_policy public.agent_job_runtime_policies%rowtype;
  renewed_until timestamptz;
begin
  select * into strict review_work_record
  from public.information_lineage_review_work_items
  where id = work_item_uuid for update;
  if review_work_record.status <> 'claimed'
     or review_work_record.claimed_by_actor_id <> actor_uuid
     or review_work_record.lease_token <> lease_token_value
     or review_work_record.lease_expires_at <= now()
     or not public.has_catalog_capability('information_lineage.review') then
    raise exception 'An active lineage-review lease and capability are required';
  end if;
  select * into strict runtime_policy
  from public.current_agent_job_runtime_policy(
    'information_lineage_reviewer.' || review_work_record.data_type
  );
  renewed_until := now() + make_interval(secs => runtime_policy.lease_seconds);
  update public.information_lineage_review_work_items
  set lease_expires_at = renewed_until, updated_at = now()
  where id = review_work_record.id;
  update public.information_lineage_review_attempts
  set last_heartbeat_at = now(), lease_expires_at = renewed_until
  where work_item_id = review_work_record.id
    and attempt_number = review_work_record.attempt_count
    and ended_at is null;
  return renewed_until;
end;
$$;

create or replace function public.transition_information_lineage_review_by_runtime_policy(
  work_item_uuid uuid,
  failure_category_value text,
  failure_reason_value text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  review_work_record public.information_lineage_review_work_items%rowtype;
  runtime_policy public.agent_job_runtime_policies%rowtype;
  next_status text;
  next_available_at timestamptz;
begin
  select * into strict review_work_record
  from public.information_lineage_review_work_items
  where id = work_item_uuid for update;
  if review_work_record.status <> 'claimed' then
    return review_work_record.status;
  end if;
  select * into strict runtime_policy
  from public.current_agent_job_runtime_policy(
    'information_lineage_reviewer.' || review_work_record.data_type
  );
  if failure_category_value = any(runtime_policy.permanent_failure_categories) then
    next_status := runtime_policy.permanent_failure_status;
  elsif failure_category_value = any(runtime_policy.retryable_failure_categories)
        and review_work_record.attempt_count < runtime_policy.maximum_attempts then
    next_status := 'retry_wait';
    next_available_at := now() + make_interval(secs =>
      runtime_policy.retry_delay_seconds[least(
        review_work_record.attempt_count,
        cardinality(runtime_policy.retry_delay_seconds)
      )]
    );
  elsif failure_category_value = any(runtime_policy.retryable_failure_categories) then
    next_status := runtime_policy.exhaustion_status;
  else
    next_status := 'needs_review';
  end if;
  update public.information_lineage_review_attempts
  set ended_at = now(),
      outcome = case when next_status = 'retry_wait' then 'retry' else next_status end,
      failure_category = failure_category_value,
      failure_reason = failure_reason_value
  where work_item_id = review_work_record.id
    and attempt_number = review_work_record.attempt_count
    and ended_at is null;
  update public.information_lineage_review_work_items
  set status = next_status,
      available_at = coalesce(next_available_at, available_at),
      claimed_by_actor_id = null, lease_token = null, lease_expires_at = null,
      failure_category = failure_category_value,
      failure_reason = failure_reason_value,
      completed_at = case when next_status in ('failed','cancelled')
                          then now() else null end,
      updated_at = now()
  where id = review_work_record.id;
  insert into public.information_lineage_review_work_events(
    work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    review_work_record.id, review_work_record.attempt_count,
    review_work_record.claimed_by_actor_id, 'execution_failed',
    jsonb_build_object(
      'failure_category', failure_category_value,
      'failure_reason', failure_reason_value,
      'next_status', next_status,
      'next_available_at', next_available_at
    )
  );
  return next_status;
end;
$$;

create or replace function public.report_information_lineage_review_failure(
  work_item_uuid uuid,
  lease_token_value uuid,
  failure_category_value text,
  failure_reason_value text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  review_work_record public.information_lineage_review_work_items%rowtype;
begin
  select * into strict review_work_record
  from public.information_lineage_review_work_items
  where id = work_item_uuid for update;
  if review_work_record.status <> 'claimed'
     or review_work_record.claimed_by_actor_id <> actor_uuid
     or review_work_record.lease_token <> lease_token_value
     or review_work_record.lease_expires_at <= now()
     or not public.has_catalog_capability('information_lineage.review') then
    raise exception 'An active lineage-review lease and capability are required';
  end if;
  if nullif(btrim(failure_category_value), '') is null
     or nullif(btrim(failure_reason_value), '') is null then
    raise exception 'Failure category and reason are required';
  end if;
  return public.transition_information_lineage_review_by_runtime_policy(
    review_work_record.id,
    btrim(failure_category_value), btrim(failure_reason_value)
  );
end;
$$;

create or replace function public.expire_information_lineage_review_work_leases()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  expired record;
  expired_count integer := 0;
begin
  for expired in
    select work.id
    from public.information_lineage_review_work_items work
    where work.status = 'claimed' and work.lease_expires_at <= now()
    for update skip locked
  loop
    perform public.transition_information_lineage_review_by_runtime_policy(
      expired.id, 'lease_expired',
      'Information-lineage reviewer lease expired.'
    );
    expired_count := expired_count + 1;
  end loop;
  return expired_count;
end;
$$;

create or replace function public.reconcile_information_lineage_review_wakes()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  reconciled_count integer;
begin
  insert into public.agent_work_wake_outbox(
    queue_name, work_item_id, event_kind, eligibility_key, available_at
  )
  select 'information_lineage_reviewer.' || review_work.data_type,
         review_work.id, 'work_ready',
         review_work.status || ':' ||
           extract(epoch from review_work.available_at)::text,
         review_work.available_at
  from public.information_lineage_review_work_items review_work
  join public.information_lineage_resolution_results result
    on result.id = review_work.resolution_result_id
  join public.information_lineage_resolution_work_items resolution_work
    on resolution_work.id = result.work_item_id
  where review_work.status in ('queued','retry_wait')
    and review_work.available_at <= now()
    and resolution_work.status = 'needs_review'
    and result.resolution_action = 'propose_new'
    and result.disposition = 'pending_governance'
  on conflict (queue_name, work_item_id, event_kind, eligibility_key)
  do update set status = 'pending', acknowledged_at = null,
                acknowledged_by_actor_id = null;
  get diagnostics reconciled_count = row_count;
  return reconciled_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Controlled reviewer dispositions
-- ---------------------------------------------------------------------------

create or replace function public.submit_information_lineage_review(
  work_item_uuid uuid,
  lease_token_value uuid,
  disposition_value text,
  existing_lineage_key_value text default null,
  new_lineage_display_name_value text default null,
  new_lineage_origin_url_value text default null,
  review_basis_value text default null,
  terminal_exception_code_value text default null,
  terminal_exception_reason_value text default null,
  provenance_value jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  review_work_record public.information_lineage_review_work_items%rowtype;
  result_record public.information_lineage_resolution_results%rowtype;
  resolution_work_record public.information_lineage_resolution_work_items%rowtype;
  attempt_record public.information_lineage_review_attempts%rowtype;
  existing_decision public.information_lineage_review_decisions%rowtype;
  normalized_existing_key text := nullif(btrim(existing_lineage_key_value), '');
  normalized_display_name text := nullif(btrim(new_lineage_display_name_value), '');
  normalized_origin_url text := nullif(btrim(new_lineage_origin_url_value), '');
  normalized_basis text := nullif(btrim(review_basis_value), '');
  normalized_exception_code text := nullif(btrim(terminal_exception_code_value), '');
  normalized_exception_reason text := nullif(btrim(terminal_exception_reason_value), '');
  applied_lineage_key_value text;
  lineage_version_uuid uuid;
  assignment_uuid uuid;
  decision_uuid uuid;
begin
  if actor_uuid is null
     or not public.has_catalog_capability('information_lineage.review') then
    raise exception 'Information-lineage review capability is required';
  end if;
  select * into strict review_work_record
  from public.information_lineage_review_work_items
  where id = work_item_uuid for update;
  select * into result_record
  from public.information_lineage_resolution_results
  where id = review_work_record.resolution_result_id;
  select * into resolution_work_record
  from public.information_lineage_resolution_work_items
  where id = result_record.work_item_id for update;
  if result_record.id is null or resolution_work_record.id is null then
    raise exception 'The governed lineage proposal was not found';
  end if;

  applied_lineage_key_value := case disposition_value
    when 'approve_new' then nullif(btrim(result_record.proposed_lineage_key), '')
    when 'map_existing' then normalized_existing_key
    else null
  end;

  select * into existing_decision
  from public.information_lineage_review_decisions
  where work_item_id = review_work_record.id;
  if existing_decision.id is not null then
    select * into strict attempt_record
    from public.information_lineage_review_attempts
    where id = existing_decision.attempt_id;
    if attempt_record.lease_token = lease_token_value
       and existing_decision.reviewed_by_actor_id = actor_uuid
       and existing_decision.disposition = disposition_value
       and existing_decision.applied_lineage_key
           is not distinct from applied_lineage_key_value
       and existing_decision.new_lineage_display_name
           is not distinct from normalized_display_name
       and existing_decision.new_lineage_origin_url
           is not distinct from normalized_origin_url
       and existing_decision.review_basis = normalized_basis
       and existing_decision.terminal_exception_code
           is not distinct from normalized_exception_code
       and existing_decision.terminal_exception_reason
           is not distinct from normalized_exception_reason
       and existing_decision.provenance = coalesce(provenance_value, '{}'::jsonb) then
      return existing_decision.id;
    end if;
    raise exception 'The lineage-review work item already has a different terminal decision';
  end if;

  if review_work_record.status <> 'claimed'
     or review_work_record.claimed_by_actor_id <> actor_uuid
     or review_work_record.lease_token <> lease_token_value
     or review_work_record.lease_expires_at <= now() then
    raise exception 'An active lineage-review lease and capability are required';
  end if;
  if disposition_value not in ('approve_new','map_existing','reject')
     or normalized_basis is null then
    raise exception 'A valid reviewer disposition and review basis are required';
  end if;
  if result_record.resolution_action <> 'propose_new'
     or result_record.disposition <> 'pending_governance'
     or resolution_work_record.status <> 'needs_review' then
    raise exception 'Only a pending new-lineage proposal may be reviewed';
  end if;
  select * into strict attempt_record
  from public.information_lineage_review_attempts
  where work_item_id = review_work_record.id
    and attempt_number = review_work_record.attempt_count
    and actor_id = actor_uuid and lease_token = lease_token_value
    and ended_at is null;

  if disposition_value = 'approve_new' then
    if applied_lineage_key_value is null or normalized_display_name is null
       or normalized_existing_key is not null
       or normalized_exception_code is not null
       or normalized_exception_reason is not null then
      raise exception 'Approval requires the proposed key and a display name, without mapping or rejection fields';
    end if;
    if public.current_approved_information_lineage_version(
         applied_lineage_key_value, resolution_work_record.data_type
       ) is not null then
      raise exception 'The proposed lineage already resolves to an approved lineage; use map_existing';
    end if;
    lineage_version_uuid := public.admin_review_information_lineage(
      applied_lineage_key_value, resolution_work_record.data_type,
      normalized_display_name, normalized_origin_url, 'approved', null,
      normalized_basis,
      jsonb_build_object(
        'review_work_item_id', review_work_record.id,
        'resolution_result_id', result_record.id,
        'reviewer_provenance', coalesce(provenance_value, '{}'::jsonb)
      )
    );
    assignment_uuid := public.apply_information_lineage_resolution_result(
      result_record.id, applied_lineage_key_value, normalized_basis,
      coalesce(provenance_value, '{}'::jsonb)
    );
  elsif disposition_value = 'map_existing' then
    if normalized_existing_key is null
       or normalized_display_name is not null
       or normalized_origin_url is not null
       or normalized_exception_code is not null
       or normalized_exception_reason is not null then
      raise exception 'Mapping requires only an existing approved lineage key and review basis';
    end if;
    lineage_version_uuid := public.current_approved_information_lineage_version(
      normalized_existing_key, resolution_work_record.data_type
    );
    if lineage_version_uuid is null then
      raise exception 'Mapping requires an existing current approved lineage for this data type';
    end if;
    assignment_uuid := public.apply_information_lineage_resolution_result(
      result_record.id, normalized_existing_key, normalized_basis,
      coalesce(provenance_value, '{}'::jsonb)
    );
  else
    if normalized_existing_key is not null
       or normalized_display_name is not null
       or normalized_origin_url is not null
       or normalized_exception_code is null
       or normalized_exception_reason is null then
      raise exception 'Rejection requires an explicit terminal exception code and reason without lineage fields';
    end if;
    update public.information_lineage_resolution_work_items
    set status = 'failed',
        failure_category = 'lineage_proposal_rejected',
        failure_reason = normalized_exception_code || ': ' ||
                         normalized_exception_reason,
        claimed_by_actor_id = null, lease_token = null,
        lease_expires_at = null, completed_at = now(), updated_at = now()
    where id = resolution_work_record.id;
  end if;

  insert into public.information_lineage_review_decisions(
    work_item_id, attempt_id, reviewed_by_actor_id, disposition,
    applied_lineage_key, new_lineage_display_name,
    new_lineage_origin_url, applied_lineage_version_id,
    review_basis, terminal_exception_code, terminal_exception_reason,
    provenance
  ) values (
    review_work_record.id, attempt_record.id, actor_uuid, disposition_value,
    applied_lineage_key_value,
    case when disposition_value = 'approve_new' then normalized_display_name end,
    case when disposition_value = 'approve_new' then normalized_origin_url end,
    lineage_version_uuid, normalized_basis,
    normalized_exception_code, normalized_exception_reason,
    coalesce(provenance_value, '{}'::jsonb)
  ) returning id into decision_uuid;

  update public.information_lineage_review_attempts
  set ended_at = now(),
      outcome = case when disposition_value = 'reject'
                     then 'rejected' else 'completed' end
  where id = attempt_record.id;
  update public.information_lineage_review_work_items
  set status = case when disposition_value = 'reject'
                    then 'rejected' else 'completed' end,
      claimed_by_actor_id = null, lease_token = null,
      lease_expires_at = null,
      failure_category = case when disposition_value = 'reject'
                              then 'lineage_proposal_rejected' end,
      failure_reason = case when disposition_value = 'reject'
                            then normalized_exception_code || ': ' ||
                                 normalized_exception_reason end,
      completed_at = now(), updated_at = now()
  where id = review_work_record.id;
  insert into public.information_lineage_review_work_events(
    work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    review_work_record.id, review_work_record.attempt_count, actor_uuid,
    'review_submitted', jsonb_strip_nulls(jsonb_build_object(
      'decision_id', decision_uuid,
      'disposition', disposition_value,
      'applied_lineage_key', applied_lineage_key_value,
      'applied_lineage_version_id', lineage_version_uuid,
      'assignment_id', assignment_uuid,
      'terminal_exception_code', normalized_exception_code
    ))
  );
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'information_lineage.review_completed',
    'information_lineage_review_work', review_work_record.id::text,
    jsonb_strip_nulls(jsonb_build_object(
      'decision_id', decision_uuid,
      'resolution_result_id', result_record.id,
      'resolution_work_item_id', resolution_work_record.id,
      'disposition', disposition_value,
      'applied_lineage_key', applied_lineage_key_value,
      'applied_lineage_version_id', lineage_version_uuid,
      'assignment_id', assignment_uuid,
      'terminal_exception_code', normalized_exception_code,
      'terminal_exception_reason', normalized_exception_reason,
      'review_basis', normalized_basis,
      'provenance', coalesce(provenance_value, '{}'::jsonb)
    ))
  );
  return decision_uuid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Existing worker-pool enforcement and watchdog recovery integration
-- ---------------------------------------------------------------------------

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
  elsif tg_table_name in (
    'information_lineage_resolution_work_items',
    'information_lineage_review_work_items'
  ) then
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
       join public.catalog_domain_adapters adapter
         on adapter.data_type = work.data_type
       where work.status = 'claimed'
         and adapter.specialist_job_type = 'team_color_specialist')
    into pool_claimed;
  elsif pool_name = 'catalog_verifier' then
    select
      (select count(*) from public.catalog_verification_work_items
       where status = 'claimed')
      +
      (select count(*) from public.information_lineage_resolution_work_items
       where status = 'claimed')
      +
      (select count(*) from public.information_lineage_review_work_items
       where status = 'claimed')
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
    (select count(*) from public.catalog_verification_work_items
     where status = 'claimed')
    +
    (select count(*) from public.source_qualification_work_items
     where status = 'claimed')
    +
    (select count(*) from public.information_lineage_resolution_work_items
     where status = 'claimed')
    +
    (select count(*) from public.information_lineage_review_work_items
     where status = 'claimed')
  into globally_claimed;
  if globally_claimed >= operating_policy.maximum_concurrent_operational_workers then
    raise exception 'The global operational-worker concurrency limit of % is already reached',
      operating_policy.maximum_concurrent_operational_workers;
  end if;
  return new;
end;
$$;

create trigger enforce_information_lineage_review_concurrency
before insert or update of status
on public.information_lineage_review_work_items
for each row execute function public.enforce_agent_worker_concurrency();

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
  lineage_review_expired integer := 0;
  lineage_review_work_reconciled integer := 0;
  comparisons_processed integer := 0;
  wakes_reconciled integer := 0;
  verifier_wakes_reconciled integer := 0;
  lineage_wakes_reconciled integer := 0;
  lineage_review_wakes_reconciled integer := 0;
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
  if not pg_try_advisory_xact_lock(
    hashtextextended('fanatical-agent-backend-recovery', 0)
  ) then
    return jsonb_build_object('status', 'already_running');
  end if;
  verifier_expired := public.expire_catalog_verification_work_leases();
  lineage_expired := public.expire_information_lineage_resolution_work_leases();
  lineage_review_expired :=
    public.expire_information_lineage_review_work_leases();
  lineage_review_work_reconciled :=
    public.reconcile_information_lineage_review_work_items();

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
             jsonb_build_object(
               'verifier_result_id', stranded.id, 'error', sqlerrm
             )
      from public.catalog_verifier_results result
      where result.id = stranded.id;
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
  lineage_wakes_reconciled :=
    public.reconcile_information_lineage_resolution_wakes();
  wakes_reconciled := wakes_reconciled + lineage_wakes_reconciled;
  lineage_review_wakes_reconciled :=
    public.reconcile_information_lineage_review_wakes();
  wakes_reconciled := wakes_reconciled + lineage_review_wakes_reconciled;
  qualification_wakes_reconciled :=
    public.reconcile_source_qualification_wakes();
  wakes_reconciled := wakes_reconciled + qualification_wakes_reconciled;

  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, details
  ) values (
    actor_uuid, auth.uid(), 'agent_backend.recovery_run', 'agent_backend',
    jsonb_build_object(
      'verifier_expired', verifier_expired,
      'lineage_expired', lineage_expired,
      'lineage_review_expired', lineage_review_expired,
      'lineage_review_work_reconciled', lineage_review_work_reconciled,
      'domain_recovery', domain_recovery,
      'comparisons_processed', comparisons_processed,
      'comparison_wakes_reconciled', comparison_wakes_reconciled,
      'qualification_wakes_reconciled', qualification_wakes_reconciled,
      'lineage_review_wakes_reconciled', lineage_review_wakes_reconciled,
      'wakes_reconciled', wakes_reconciled
    )
  );
  return jsonb_build_object(
    'status', 'completed',
    'verifier_expired', verifier_expired,
    'lineage_expired', lineage_expired,
    'lineage_review_expired', lineage_review_expired,
    'lineage_review_work_reconciled', lineage_review_work_reconciled,
    'domain_recovery', domain_recovery,
    'comparisons_processed', comparisons_processed,
    'comparison_wakes_reconciled', comparison_wakes_reconciled,
    'qualification_wakes_reconciled', qualification_wakes_reconciled,
    'lineage_review_wakes_reconciled', lineage_review_wakes_reconciled,
    'wakes_reconciled', wakes_reconciled
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Security boundary: tables remain backend-only; workers receive only narrow
-- capability-checked RPCs.
-- ---------------------------------------------------------------------------

alter table public.information_lineage_review_work_items enable row level security;
alter table public.information_lineage_review_attempts enable row level security;
alter table public.information_lineage_review_work_events enable row level security;
alter table public.information_lineage_review_decisions enable row level security;

revoke all on public.information_lineage_review_work_items
from public, anon, authenticated;
revoke all on public.information_lineage_review_attempts
from public, anon, authenticated;
revoke all on public.information_lineage_review_work_events
from public, anon, authenticated;
revoke all on public.information_lineage_review_decisions
from public, anon, authenticated;

grant select, insert, update, delete
on public.information_lineage_review_work_items,
   public.information_lineage_review_attempts,
   public.information_lineage_review_work_events,
   public.information_lineage_review_decisions
to service_role;

revoke all on function public.emit_information_lineage_review_work_wake()
from public, anon, authenticated;
revoke all on function public.enqueue_information_lineage_review_work(uuid)
from public, anon, authenticated;
revoke all on function public.enqueue_pending_information_lineage_review()
from public, anon, authenticated;
revoke all on function public.reconcile_information_lineage_review_work_items()
from public, anon, authenticated;
revoke all on function public.transition_information_lineage_review_by_runtime_policy(uuid,text,text)
from public, anon, authenticated;
revoke all on function public.expire_information_lineage_review_work_leases()
from public, anon, authenticated;
revoke all on function public.reconcile_information_lineage_review_wakes()
from public, anon, authenticated;

revoke all on function public.get_my_information_lineage_review_work(uuid,uuid)
from public, anon;
grant execute on function public.get_my_information_lineage_review_work(uuid,uuid)
to authenticated;
revoke all on function public.claim_next_information_lineage_review_work(text)
from public, anon;
grant execute on function public.claim_next_information_lineage_review_work(text)
to authenticated;
revoke all on function public.renew_information_lineage_review_work_lease(uuid,uuid)
from public, anon;
grant execute on function public.renew_information_lineage_review_work_lease(uuid,uuid)
to authenticated;
revoke all on function public.report_information_lineage_review_failure(uuid,uuid,text,text)
from public, anon;
grant execute on function public.report_information_lineage_review_failure(uuid,uuid,text,text)
to authenticated;
revoke all on function public.submit_information_lineage_review(uuid,uuid,text,text,text,text,text,text,text,jsonb)
from public, anon;
grant execute on function public.submit_information_lineage_review(uuid,uuid,text,text,text,text,text,text,text,jsonb)
to authenticated;

comment on function public.get_my_information_lineage_review_work(uuid,uuid) is
  'Returns only leased reviewer metadata, the resolver lineage proposal, assigned source/evidence location, and approved lineage candidates. Factual answers, qualification scores, and unrelated governance data are excluded.';

