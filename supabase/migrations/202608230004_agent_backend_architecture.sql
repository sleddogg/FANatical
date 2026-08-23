-- Reusable autonomous-agent backend foundations required by AGENT_ARCHITECTURE.md.
--
-- This is an additive compatibility migration. It preserves the deployed Team
-- Color specialist queue and catalog proposal/version machinery while adding
-- durable blinded verification, backend-owned retry policy, information
-- lineage, orchestration wakes, recovery, and domain-level revalidation.

-- ---------------------------------------------------------------------------
-- Versioned runtime policy. No production numeric policy is seeded here.
-- ---------------------------------------------------------------------------

create table public.agent_job_runtime_policies (
  id uuid primary key default gen_random_uuid(),
  policy_key text not null,
  version integer not null check (version > 0),
  job_type text not null check (length(btrim(job_type)) > 0),
  lease_seconds integer check (lease_seconds is null or lease_seconds > 0),
  retryable_failure_categories text[] not null default '{}'::text[],
  permanent_failure_categories text[] not null default '{}'::text[],
  retry_delay_seconds integer[] not null default '{}'::integer[],
  maximum_attempts integer check (maximum_attempts is null or maximum_attempts > 0),
  exhaustion_status text not null default 'needs_review'
    check (exhaustion_status in ('needs_review', 'failed')),
  permanent_failure_status text not null default 'failed'
    check (permanent_failure_status in ('needs_review', 'failed')),
  configuration jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  is_current boolean not null default true,
  created_by_actor_id uuid references public.catalog_actors(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  unique (policy_key, version),
  check (
    cardinality(retryable_failure_categories) = 0
    or (
      lease_seconds is not null
      and maximum_attempts is not null
      and cardinality(retry_delay_seconds) > 0
      and 0 < all(retry_delay_seconds)
    )
  ),
  check (not (retryable_failure_categories && permanent_failure_categories))
);

create unique index agent_job_runtime_policy_current_idx
on public.agent_job_runtime_policies(job_type)
where is_current and active;

create or replace function public.current_agent_job_runtime_policy(job_type_value text)
returns public.agent_job_runtime_policies
language sql
stable
security definer
set search_path = ''
as $$
  select policy.*
  from public.agent_job_runtime_policies policy
  where policy.job_type = job_type_value and policy.is_current and policy.active
  order by policy.version desc
  limit 1;
$$;

alter table public.verification_policies
  add column maximum_verifier_rounds integer
    check (maximum_verifier_rounds is null or maximum_verifier_rounds > 0),
  add column required_matching_verifier_results integer
    check (required_matching_verifier_results is null or required_matching_verifier_results > 0),
  add column consensus_strategy text
    check (consensus_strategy is null or consensus_strategy in (
      'specialist_match_or_verifier_consensus','unanimous_verifiers','domain_adapter'
    ));

alter table public.catalog_verification_decisions
  add column authoritative_result_payload jsonb,
  add column verification_resolution_snapshot jsonb not null default '{}'::jsonb;

create table public.catalog_verification_round_policies (
  id uuid primary key default gen_random_uuid(),
  verification_policy_id uuid not null references public.verification_policies(id),
  verification_round integer not null check (verification_round > 0),
  minimum_evidence_count integer check (minimum_evidence_count is null or minimum_evidence_count >= 0),
  allowed_trust_tiers smallint[] check (
    allowed_trust_tiers is null or allowed_trust_tiers <@ array[1,2,3,4,5]::smallint[]
  ),
  minimum_independent_ownership_groups integer
    check (minimum_independent_ownership_groups is null or minimum_independent_ownership_groups >= 0),
  minimum_independent_information_lineages integer
    check (minimum_independent_information_lineages is null or minimum_independent_information_lineages >= 0),
  minimum_high_trust_evidence_count integer
    check (minimum_high_trust_evidence_count is null or minimum_high_trust_evidence_count >= 0),
  source_selection_policy jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (verification_policy_id, verification_round)
);

comment on table public.catalog_verification_round_policies is
  'Optional policy-owned requirements for each blinded verifier round. Rows may strengthen evidence requirements without banning independently rediscovered source overlap.';

-- ---------------------------------------------------------------------------
-- Information lineage, distinct from publisher ownership.
-- ---------------------------------------------------------------------------

create table public.information_lineages (
  id uuid primary key default gen_random_uuid(),
  lineage_key text not null unique check (lineage_key ~ '^[a-z0-9][a-z0-9._-]*$'),
  data_type text not null check (length(btrim(data_type)) > 0),
  created_at timestamptz not null default now()
);

create table public.information_lineage_versions (
  id uuid primary key default gen_random_uuid(),
  lineage_id uuid not null references public.information_lineages(id),
  version integer not null check (version > 0),
  display_name text not null check (length(btrim(display_name)) > 0),
  origin_url text check (origin_url is null or origin_url ~* '^https?://[^[:space:]]+$'),
  review_status text not null check (review_status in ('pending_review', 'approved', 'rejected', 'merged')),
  canonical_lineage_id uuid references public.information_lineages(id),
  provenance jsonb not null default '{}'::jsonb,
  notes text,
  is_current boolean not null default true,
  reviewed_by_actor_id uuid references public.catalog_actors(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  unique (lineage_id, version),
  check (
    (review_status = 'merged' and canonical_lineage_id is not null and canonical_lineage_id <> lineage_id)
    or (review_status <> 'merged' and canonical_lineage_id is null)
  )
);

create unique index information_lineage_current_idx
on public.information_lineage_versions(lineage_id)
where is_current;

alter table public.catalog_proposal_evidence
  add column information_lineage_version_id uuid
    references public.information_lineage_versions(id),
  add column information_lineage_basis text;

comment on column public.catalog_proposal_evidence.information_lineage_version_id is
  'Exact reviewed information-lineage version used at adjudication time; NULL means lineage remains unknown and cannot prove independence.';

create or replace function public.current_information_lineage_root(
  lineage_version_uuid uuid
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  with recursive lineage_path as (
    select lineage.id, current_version.canonical_lineage_id, 1 as depth,
           array[lineage.id]::uuid[] as visited
    from public.information_lineage_versions referenced_version
    join public.information_lineages lineage on lineage.id = referenced_version.lineage_id
    join public.information_lineage_versions current_version
      on current_version.lineage_id = lineage.id and current_version.is_current
    where referenced_version.id = lineage_version_uuid
      and current_version.review_status in ('approved', 'merged')
    union all
    select next_lineage.id, next_version.canonical_lineage_id,
           lineage_path.depth + 1, lineage_path.visited || next_lineage.id
    from lineage_path
    join public.information_lineages next_lineage
      on next_lineage.id = lineage_path.canonical_lineage_id
    join public.information_lineage_versions next_version
      on next_version.lineage_id = next_lineage.id and next_version.is_current
    where lineage_path.canonical_lineage_id is not null
      and not next_lineage.id = any(lineage_path.visited)
  )
  select id
  from lineage_path
  order by depth desc
  limit 1;
$$;

create or replace function public.admin_review_information_lineage(
  lineage_key_value text,
  data_type_value text,
  display_name_value text,
  origin_url_value text,
  review_status_value text,
  canonical_lineage_key_value text default null,
  notes_value text default null,
  provenance_value jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  lineage_uuid uuid;
  canonical_uuid uuid;
  next_version integer;
  result_uuid uuid;
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
     and not public.has_catalog_capability('information_lineage.review') then
    raise exception 'Information-lineage review capability is required';
  end if;
  if review_status_value not in ('pending_review','approved','rejected','merged') then
    raise exception 'Invalid information-lineage review status';
  end if;
  insert into public.information_lineages(lineage_key, data_type)
  values (lineage_key_value, data_type_value)
  on conflict (lineage_key) do update set lineage_key = excluded.lineage_key
  returning id into lineage_uuid;
  if (select data_type from public.information_lineages where id = lineage_uuid) <> data_type_value then
    raise exception 'Information lineage data type cannot be changed';
  end if;
  if canonical_lineage_key_value is not null then
    select id into canonical_uuid from public.information_lineages
    where lineage_key = canonical_lineage_key_value and data_type = data_type_value;
    if canonical_uuid is null then raise exception 'Canonical information lineage was not found'; end if;
    if exists (
      select 1 from public.information_lineage_versions canonical_version
      where canonical_version.lineage_id = canonical_uuid and canonical_version.is_current
        and public.current_information_lineage_root(canonical_version.id) = lineage_uuid
    ) then
      raise exception 'Information-lineage merge would create a cycle';
    end if;
  end if;
  perform pg_advisory_xact_lock(hashtextextended(lineage_uuid::text, 0));
  select coalesce(max(version), 0) + 1 into next_version
  from public.information_lineage_versions where lineage_id = lineage_uuid;
  update public.information_lineage_versions
  set is_current = false, superseded_at = now()
  where lineage_id = lineage_uuid and is_current;
  insert into public.information_lineage_versions(
    lineage_id, version, display_name, origin_url, review_status,
    canonical_lineage_id, provenance, notes, reviewed_by_actor_id
  ) values (
    lineage_uuid, next_version, btrim(display_name_value), origin_url_value,
    review_status_value, canonical_uuid, coalesce(provenance_value, '{}'::jsonb),
    notes_value, actor_uuid
  ) returning id into result_uuid;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'information_lineage.reviewed', 'information_lineage',
    lineage_key_value, jsonb_build_object(
      'lineage_version_id', result_uuid, 'version', next_version,
      'review_status', review_status_value,
      'canonical_lineage_key', canonical_lineage_key_value,
      'notes', notes_value, 'provenance', coalesce(provenance_value, '{}'::jsonb)
    )
  );
  return result_uuid;
end;
$$;

create or replace function public.assign_catalog_evidence_information_lineage(
  evidence_uuid uuid,
  lineage_key_value text,
  basis_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  evidence_record public.catalog_proposal_evidence%rowtype;
  proposal_record public.catalog_change_proposals%rowtype;
  lineage_version_uuid uuid;
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
     and not public.has_catalog_capability('information_lineage.review') then
    raise exception 'Information-lineage review capability is required';
  end if;
  if nullif(btrim(basis_value), '') is null then raise exception 'A lineage-assignment basis is required'; end if;
  select * into strict evidence_record from public.catalog_proposal_evidence where id = evidence_uuid for update;
  select * into strict proposal_record from public.catalog_change_proposals where id = evidence_record.proposal_id;
  if proposal_record.status <> 'pending' then
    raise exception 'Resolved proposal evidence lineage is immutable';
  end if;
  select version.id into lineage_version_uuid
  from public.information_lineages lineage
  join public.information_lineage_versions version
    on version.lineage_id = lineage.id and version.is_current
  where lineage.lineage_key = lineage_key_value
    and lineage.data_type = proposal_record.fact_type
    and version.review_status = 'approved';
  if lineage_version_uuid is null then raise exception 'A current approved information lineage is required'; end if;
  update public.catalog_proposal_evidence
  set information_lineage_version_id = lineage_version_uuid,
      information_lineage_basis = btrim(basis_value)
  where id = evidence_uuid;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, proposal_id, details
  ) values (
    actor_uuid, auth.uid(), 'proposal.evidence_lineage_assigned', 'catalog_proposal_evidence',
    evidence_uuid::text, proposal_record.id, jsonb_build_object(
      'information_lineage_version_id', lineage_version_uuid,
      'basis', btrim(basis_value)
    )
  );
  return lineage_version_uuid;
end;
$$;

create table public.information_lineage_resolution_policies (
  id uuid primary key default gen_random_uuid(),
  policy_key text not null,
  version integer not null check (version > 0),
  data_type text not null,
  automatically_permitted_actions text[] not null default '{}'::text[],
  configuration jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  is_current boolean not null default true,
  created_by_actor_id uuid references public.catalog_actors(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  unique (policy_key, version),
  check (automatically_permitted_actions <@ array['assign_existing']::text[])
);

create unique index information_lineage_resolution_policy_current_idx
on public.information_lineage_resolution_policies(data_type)
where is_current and active;

create table public.information_lineage_resolution_work_items (
  id uuid primary key default gen_random_uuid(),
  data_type text not null,
  evidence_kind text not null check (evidence_kind in ('proposal_evidence','verifier_evidence')),
  evidence_id uuid not null,
  subject_type text not null,
  subject_id text not null,
  status text not null default 'queued' check (status in (
    'queued','claimed','retry_wait','result_submitted','completed',
    'unresolved','needs_review','failed','cancelled'
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
  unique (evidence_kind, evidence_id),
  check (
    (status = 'claimed' and claimed_by_actor_id is not null and lease_token is not null and lease_expires_at is not null)
    or (status <> 'claimed' and claimed_by_actor_id is null and lease_token is null and lease_expires_at is null)
  )
);

create table public.information_lineage_resolution_results (
  id uuid primary key default gen_random_uuid(),
  work_item_id uuid not null unique references public.information_lineage_resolution_work_items(id),
  submitted_by_actor_id uuid not null references public.catalog_actors(id),
  result_schema_version integer not null default 1 check (result_schema_version > 0),
  resolution_action text not null check (resolution_action in ('assign_existing','propose_new','unresolved')),
  proposed_lineage_key text,
  resolution_basis text not null check (length(btrim(resolution_basis)) > 0),
  provenance jsonb not null default '{}'::jsonb,
  policy_id uuid references public.information_lineage_resolution_policies(id),
  disposition text not null check (disposition in ('automatically_applied','pending_governance','unresolved')),
  submitted_at timestamptz not null default now()
);

create table public.information_lineage_resolution_attempts (
  id uuid primary key default gen_random_uuid(),
  work_item_id uuid not null references public.information_lineage_resolution_work_items(id),
  attempt_number integer not null check (attempt_number > 0),
  actor_id uuid not null references public.catalog_actors(id),
  lease_token uuid not null unique,
  claimed_at timestamptz not null default now(),
  last_heartbeat_at timestamptz not null default now(),
  lease_expires_at timestamptz not null,
  ended_at timestamptz,
  outcome text,
  failure_category text,
  failure_reason text,
  unique (work_item_id, attempt_number)
);

create table public.catalog_evidence_lineage_assignments (
  id uuid primary key default gen_random_uuid(),
  evidence_kind text not null check (evidence_kind in ('proposal_evidence','verifier_evidence')),
  evidence_id uuid not null,
  information_lineage_version_id uuid not null references public.information_lineage_versions(id),
  assignment_basis text not null check (length(btrim(assignment_basis)) > 0),
  resolution_result_id uuid references public.information_lineage_resolution_results(id),
  assigned_by_actor_id uuid references public.catalog_actors(id),
  created_at timestamptz not null default now(),
  is_current boolean not null default true,
  superseded_at timestamptz
);

create unique index catalog_evidence_lineage_assignment_current_idx
on public.catalog_evidence_lineage_assignments(evidence_kind, evidence_id)
where is_current;

comment on table public.information_lineage_resolution_work_items is
  'Durable autonomous work created when factual evidence has unknown information lineage. Unknown remains non-independent until a governed result is applied.';

-- ---------------------------------------------------------------------------
-- Durable generic verifier queue, attempts, evidence, results, and comparison.
-- ---------------------------------------------------------------------------

create table public.catalog_domain_adapters (
  data_type text primary key check (length(btrim(data_type)) > 0),
  subject_type text not null check (length(btrim(subject_type)) > 0),
  specialist_job_type text,
  verification_job_type text not null check (length(btrim(verification_job_type)) > 0),
  verification_capability text not null check (length(btrim(verification_capability)) > 0),
  build_verifier_context_function regproc not null,
  compare_result_function regproc not null,
  finalize_authoritative_function regproc not null,
  enqueue_revalidation_function regproc,
  recover_domain_function regproc,
  reconcile_wakes_function regproc,
  active boolean not null default true,
  configuration jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.catalog_domain_adapters is
  'Controlled backend registry connecting generic agent infrastructure to domain-specific context, comparison, authoritative finalization, revalidation, and recovery primitives.';

create table public.agent_specialist_results (
  id uuid primary key default gen_random_uuid(),
  data_type text not null check (length(btrim(data_type)) > 0),
  job_type text not null check (length(btrim(job_type)) > 0),
  originating_job_id uuid,
  subject_type text not null check (length(btrim(subject_type)) > 0),
  subject_id text not null check (length(btrim(subject_id)) > 0),
  subject_reference jsonb not null default '{}'::jsonb,
  result_schema_version integer not null default 1 check (result_schema_version > 0),
  result_kind text not null check (result_kind in ('determinate','no_change','incomplete','unresolved')),
  result_payload jsonb not null,
  evidence_snapshot jsonb not null default '[]'::jsonb,
  provenance_summary text,
  expected_authoritative_version_id uuid,
  submitted_by_actor_id uuid not null references public.catalog_actors(id),
  submitted_at timestamptz not null default now()
);

comment on table public.agent_specialist_results is
  'Generic immutable specialist-result envelope for determinate domains that do not use catalog_change_proposals. Domain adapters validate payloads and perform authoritative transitions.';

create table public.catalog_verification_work_items (
  id uuid primary key default gen_random_uuid(),
  data_type text not null check (length(btrim(data_type)) > 0),
  subject_type text not null check (length(btrim(subject_type)) > 0),
  subject_id text not null check (length(btrim(subject_id)) > 0),
  subject_reference jsonb not null default '{}'::jsonb,
  capability_scope jsonb not null default '{}'::jsonb,
  verifier_context jsonb not null default '{}'::jsonb,
  specialist_result_kind text not null
    check (specialist_result_kind in ('catalog_proposal','agent_specialist_result')),
  specialist_result_id uuid not null,
  proposal_id uuid references public.catalog_change_proposals(id),
  originating_job_type text,
  originating_job_id uuid,
  expected_current_version_id uuid,
  verification_policy_id uuid not null references public.verification_policies(id),
  verification_round integer not null default 1 check (verification_round > 0),
  parent_verification_work_item_id uuid references public.catalog_verification_work_items(id),
  round_requirement_snapshot jsonb not null default '{}'::jsonb,
  priority integer not null default 0,
  status text not null default 'queued' check (status in (
    'queued','claimed','retry_wait','result_submitted','completed',
    'contradiction','blocked','needs_review','failed','cancelled'
  )),
  available_at timestamptz not null default now(),
  claimed_by_actor_id uuid references public.catalog_actors(id),
  lease_token uuid,
  lease_expires_at timestamptz,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  accepted_result_id uuid,
  failure_category text,
  failure_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  check (
    (status = 'claimed' and claimed_by_actor_id is not null and lease_token is not null and lease_expires_at is not null)
    or (status <> 'claimed' and claimed_by_actor_id is null and lease_token is null and lease_expires_at is null)
  ),
  check (
    (specialist_result_kind = 'catalog_proposal' and proposal_id = specialist_result_id)
    or (specialist_result_kind = 'agent_specialist_result' and proposal_id is null)
  ),
  unique (specialist_result_kind, specialist_result_id, verification_round)
);

create index catalog_verification_work_claim_idx
on public.catalog_verification_work_items(priority desc, available_at, created_at, id)
where status in ('queued','retry_wait');

create table public.catalog_verification_attempts (
  id uuid primary key default gen_random_uuid(),
  verification_work_item_id uuid not null references public.catalog_verification_work_items(id),
  attempt_number integer not null check (attempt_number > 0),
  actor_id uuid not null references public.catalog_actors(id),
  lease_token uuid not null unique,
  claimed_at timestamptz not null default now(),
  last_heartbeat_at timestamptz not null default now(),
  lease_expires_at timestamptz not null,
  ended_at timestamptz,
  outcome text check (outcome in (
    'released','retry','result_submitted','completed','contradiction',
    'blocked','needs_review','failed','lease_expired'
  )),
  failure_category text,
  failure_reason text,
  unique (verification_work_item_id, attempt_number)
);

create table public.catalog_verification_work_events (
  id bigint generated always as identity primary key,
  verification_work_item_id uuid not null references public.catalog_verification_work_items(id),
  attempt_number integer,
  actor_id uuid references public.catalog_actors(id),
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index catalog_verification_work_events_idx
on public.catalog_verification_work_events(verification_work_item_id, occurred_at, id);

create table public.catalog_verifier_evidence (
  id uuid primary key default gen_random_uuid(),
  verification_work_item_id uuid not null references public.catalog_verification_work_items(id),
  attempt_number integer not null,
  submitted_by_actor_id uuid not null references public.catalog_actors(id),
  source_id uuid not null references public.trusted_sources(id),
  evidence_url text not null,
  evidence_summary text,
  observed_at timestamptz,
  source_url_scope_version_id uuid not null references public.trusted_source_url_scope_versions(id),
  source_trust_assignment_id uuid not null references public.source_trust_assignments(id),
  source_applicability_version_id uuid not null references public.source_applicability_versions(id),
  source_independence_assignment_id uuid not null references public.source_independence_group_assignment_versions(id),
  information_lineage_version_id uuid references public.information_lineage_versions(id),
  information_lineage_basis text,
  source_reliability_snapshot jsonb not null default '{}'::jsonb,
  source_qualification_snapshot jsonb not null default '{}'::jsonb,
  structured_claim jsonb not null,
  created_at timestamptz not null default now(),
  unique (verification_work_item_id, attempt_number, source_id, evidence_url)
);

create table public.catalog_verifier_results (
  id uuid primary key default gen_random_uuid(),
  verification_work_item_id uuid not null references public.catalog_verification_work_items(id),
  verification_attempt_id uuid not null unique references public.catalog_verification_attempts(id),
  verifier_actor_id uuid not null references public.catalog_actors(id),
  result_schema_version integer not null default 1 check (result_schema_version > 0),
  result_kind text not null check (result_kind in ('determinate','incomplete','unresolved')),
  result_payload jsonb not null,
  provenance_summary text,
  evidence_snapshot jsonb not null default '[]'::jsonb,
  submitted_at timestamptz not null default now()
);

alter table public.catalog_verification_work_items
  add constraint catalog_verification_work_result_fk
  foreign key (accepted_result_id) references public.catalog_verifier_results(id);

create table public.catalog_determinate_adjudications (
  id uuid primary key default gen_random_uuid(),
  data_type text not null,
  subject_type text not null,
  subject_id text not null,
  specialist_result_kind text not null,
  specialist_result_id uuid not null,
  verification_policy_id uuid not null references public.verification_policies(id),
  resolving_verifier_result_id uuid not null references public.catalog_verifier_results(id),
  outcome text not null check (outcome in ('promoted','confirmed_no_change','rejected','unresolved')),
  authoritative_result_payload jsonb,
  resolution_snapshot jsonb not null default '{}'::jsonb,
  catalog_verification_decision_id uuid references public.catalog_verification_decisions(id),
  decided_by_actor_id uuid not null references public.catalog_actors(id),
  decided_at timestamptz not null default now(),
  unique (specialist_result_kind, specialist_result_id)
);

create table public.catalog_verification_comparisons (
  id uuid primary key default gen_random_uuid(),
  verification_work_item_id uuid not null references public.catalog_verification_work_items(id),
  proposal_id uuid references public.catalog_change_proposals(id),
  specialist_result_kind text not null,
  specialist_result_id uuid not null,
  verification_round integer not null,
  verifier_result_id uuid not null unique references public.catalog_verifier_results(id),
  policy_id uuid references public.verification_policies(id),
  comparison_outcome text not null check (comparison_outcome in (
    'promoted','confirmed_no_change','contradiction','incomplete',
    'insufficient_evidence','unresolved','stale_expected_version','invalid',
    'additional_verifier_queued','automation_exhausted'
  )),
  normalized_specialist_result jsonb,
  normalized_verifier_result jsonb,
  adjudication_id uuid references public.catalog_determinate_adjudications(id),
  verification_decision_id uuid references public.catalog_verification_decisions(id),
  details jsonb not null default '{}'::jsonb,
  compared_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Durable orchestration wake/outbox records.
-- ---------------------------------------------------------------------------

create table public.agent_work_wake_outbox (
  id uuid primary key default gen_random_uuid(),
  queue_name text not null,
  work_item_id uuid not null,
  event_kind text not null,
  eligibility_key text not null,
  available_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending','acknowledged','cancelled')),
  created_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  acknowledged_by_actor_id uuid references public.catalog_actors(id),
  unique (queue_name, work_item_id, event_kind, eligibility_key)
);

create index agent_work_wake_pending_idx
on public.agent_work_wake_outbox(available_at, created_at, id)
where status = 'pending';

create or replace function public.emit_agent_work_wake(
  queue_name_value text,
  work_item_id_value uuid,
  event_kind_value text,
  available_at_value timestamptz,
  eligibility_key_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare result_uuid uuid;
begin
  insert into public.agent_work_wake_outbox(
    queue_name, work_item_id, event_kind, available_at, eligibility_key
  ) values (
    queue_name_value, work_item_id_value, event_kind_value,
    available_at_value, eligibility_key_value
  )
  on conflict (queue_name, work_item_id, event_kind, eligibility_key)
  do update set available_at = excluded.available_at,
                status = 'pending',
                acknowledged_at = null,
                acknowledged_by_actor_id = null
  returning id into result_uuid;
  return result_uuid;
end;
$$;

create or replace function public.emit_team_color_work_wake()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('queued','retry_wait')
     and (tg_op = 'INSERT' or old.status is distinct from new.status or old.available_at is distinct from new.available_at) then
    perform public.emit_agent_work_wake(
      'team_color_specialist', new.id, 'work_ready', new.available_at,
      new.status || ':' || extract(epoch from new.available_at)::text
    );
  elsif new.status = 'claimed' then
    update public.agent_work_wake_outbox
    set status = 'acknowledged', acknowledged_at = now(),
        acknowledged_by_actor_id = new.claimed_by_actor_id
    where queue_name = 'team_color_specialist' and work_item_id = new.id and status = 'pending';
  elsif new.status in ('completed','failed','cancelled') then
    update public.agent_work_wake_outbox set status = 'cancelled'
    where queue_name = 'team_color_specialist' and work_item_id = new.id and status = 'pending';
  end if;
  return new;
end;
$$;

create trigger emit_team_color_work_wake
after insert or update of status, available_at on public.team_color_work_items
for each row execute function public.emit_team_color_work_wake();

create or replace function public.emit_catalog_verification_work_wake()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('queued','retry_wait')
     and (tg_op = 'INSERT' or old.status is distinct from new.status or old.available_at is distinct from new.available_at) then
    perform public.emit_agent_work_wake(
      'catalog_verifier.' || new.data_type, new.id, 'work_ready', new.available_at,
      new.status || ':' || extract(epoch from new.available_at)::text
    );
  elsif new.status = 'claimed' then
    update public.agent_work_wake_outbox
    set status = 'acknowledged', acknowledged_at = now(),
        acknowledged_by_actor_id = new.claimed_by_actor_id
    where queue_name = 'catalog_verifier.' || new.data_type
      and work_item_id = new.id and status = 'pending';
  elsif new.status in ('completed','failed','cancelled') then
    update public.agent_work_wake_outbox set status = 'cancelled'
    where queue_name = 'catalog_verifier.' || new.data_type
      and work_item_id = new.id and status = 'pending';
  end if;
  return new;
end;
$$;

create trigger emit_catalog_verification_work_wake
after insert or update of status, available_at on public.catalog_verification_work_items
for each row execute function public.emit_catalog_verification_work_wake();

-- ---------------------------------------------------------------------------
-- Domain-level periodic revalidation. Team Color cadence remains unconfigured.
-- ---------------------------------------------------------------------------

create table public.catalog_revalidation_policies (
  id uuid primary key default gen_random_uuid(),
  policy_key text not null,
  version integer not null check (version > 0),
  data_type text not null,
  review_cadence interval not null check (review_cadence > interval '0 seconds'),
  configuration jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  is_current boolean not null default true,
  created_by_actor_id uuid references public.catalog_actors(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  unique (policy_key, version)
);

create unique index catalog_revalidation_policy_current_idx
on public.catalog_revalidation_policies(data_type)
where is_current and active;

create table public.catalog_fact_revalidation_state (
  id uuid primary key default gen_random_uuid(),
  data_type text not null,
  subject_type text not null check (length(btrim(subject_type)) > 0),
  subject_id text not null check (length(btrim(subject_id)) > 0),
  subject_reference jsonb not null default '{}'::jsonb,
  current_fact_version_id uuid not null,
  cadence_policy_id uuid references public.catalog_revalidation_policies(id),
  last_verified_at timestamptz not null,
  next_review_at timestamptz,
  last_review_trigger text,
  last_review_reason text,
  last_review_outcome text,
  last_verification_decision_id uuid references public.catalog_verification_decisions(id),
  active_job_type text,
  active_job_id uuid,
  updated_at timestamptz not null default now(),
  unique (data_type, subject_type, subject_id),
  check ((active_job_type is null) = (active_job_id is null))
);

insert into public.catalog_fact_revalidation_state(
  data_type, subject_type, subject_id, subject_reference, current_fact_version_id,
  last_verified_at, last_review_outcome, last_verification_decision_id
)
select 'team_colors', 'catalog_team', colors.team_id::text,
       jsonb_build_object('team_uuid', colors.team_id), colors.id,
       coalesce(decision.decided_at, colors.created_at),
       'verified', colors.verification_decision_id
from public.team_color_versions colors
left join public.catalog_verification_decisions decision
  on decision.id = colors.verification_decision_id
where colors.is_current and colors.record_status = 'verified'
on conflict (data_type, subject_type, subject_id) do nothing;

comment on table public.catalog_revalidation_policies is
  'Versioned data-type cadence policy. No Team Color cadence is seeded until Brad approves it.';

-- Remaining functions, policy enforcement, recovery, and grants follow below.

create trigger catalog_verification_work_set_updated_at
before update on public.catalog_verification_work_items
for each row execute function public.set_updated_at();

create or replace function public.protect_agent_backend_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Autonomous-agent result and event history is append-only';
end;
$$;

create trigger catalog_verification_work_events_append_only
before update or delete on public.catalog_verification_work_events
for each row execute function public.protect_agent_backend_history();
create trigger catalog_verifier_evidence_append_only
before update or delete on public.catalog_verifier_evidence
for each row execute function public.protect_agent_backend_history();
create trigger catalog_verifier_results_append_only
before update or delete on public.catalog_verifier_results
for each row execute function public.protect_agent_backend_history();
create trigger catalog_verification_comparisons_append_only
before update or delete on public.catalog_verification_comparisons
for each row execute function public.protect_agent_backend_history();

create or replace function public.build_team_color_verifier_context(
  specialist_result_kind_value text,
  specialist_result_uuid uuid,
  verification_round_value integer
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'subject_type', 'catalog_team',
    'subject_id', team.id::text,
    'subject_reference', jsonb_build_object(
      'team_uuid', team.id, 'team_id', team.team_id,
      'display_name', identity_record.display_name,
      'short_name', identity_record.short_name,
      'abbreviation', identity_record.abbreviation,
      'sport_id', sport.sport_id,
      'sport_name', sport.display_name,
      'league_id', league.league_id,
      'league_name', league.display_name,
      'league_short_name', league.short_name,
      'aliases', coalesce((
        select jsonb_agg(jsonb_build_object(
          'value', alias.alias, 'type', alias.alias_type,
          'locale', alias.locale, 'status', alias.record_status
        ) order by alias.alias_type, alias.alias)
        from public.team_alias_versions alias
        where alias.team_id = team.id and alias.is_current
      ), '[]'::jsonb)
    ),
    'capability_scope', jsonb_build_object(
      'sport_id', team.sport_id,
      'league_id', membership.league_id,
      'team_id', team.id
    ),
    'verifier_context', jsonb_build_object(
      'question', 'Determine the current canonical ordered team-color palette.',
      'verification_round', verification_round_value,
      'target', jsonb_build_object(
        'team_id', team.team_id,
        'display_name', identity_record.display_name,
        'short_name', identity_record.short_name,
        'abbreviation', identity_record.abbreviation,
        'sport_id', sport.sport_id,
        'sport_name', sport.display_name,
        'league_id', league.league_id,
        'league_name', league.display_name,
        'league_short_name', league.short_name,
        'aliases', coalesce((
          select jsonb_agg(jsonb_build_object(
            'value', alias.alias, 'type', alias.alias_type,
            'locale', alias.locale, 'status', alias.record_status
          ) order by alias.alias_type, alias.alias)
          from public.team_alias_versions alias
          where alias.team_id = team.id and alias.is_current
        ), '[]'::jsonb)
      )
    )
  )
  from public.catalog_change_proposals proposal
  join public.catalog_teams team on team.id = proposal.target_team_id
  join public.catalog_sports sport on sport.id = team.sport_id
  left join public.team_identity_versions identity_record
    on identity_record.team_id = team.id and identity_record.is_current
  left join public.team_primary_league_versions membership
    on membership.team_id = team.id and membership.is_current
  left join public.catalog_leagues league on league.id = membership.league_id
  where specialist_result_kind_value = 'catalog_proposal'
    and proposal.id = specialist_result_uuid
    and proposal.fact_type = 'team_colors';
$$;

create or replace function public.ensure_catalog_verification_work_for_result(
  specialist_result_kind_value text,
  specialist_result_uuid uuid,
  verification_round_value integer default 1,
  parent_verification_work_item_uuid uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  proposal_record public.catalog_change_proposals%rowtype;
  specialist_record public.agent_specialist_results%rowtype;
  adapter_record public.catalog_domain_adapters%rowtype;
  policy_record public.verification_policies%rowtype;
  context_value jsonb;
  requirement_value jsonb;
  data_type_value text;
  proposal_uuid uuid;
  originating_job_type_value text;
  originating_job_uuid uuid;
  expected_version_uuid uuid;
  work_priority integer := 0;
  result_uuid uuid;
begin
  if verification_round_value <= 0 then raise exception 'Verification round must be positive'; end if;
  if specialist_result_kind_value = 'catalog_proposal' then
    select * into strict proposal_record
    from public.catalog_change_proposals where id = specialist_result_uuid for update;
    if proposal_record.status <> 'pending' then
      raise exception 'Verification work requires a pending proposal';
    end if;
    data_type_value := proposal_record.fact_type;
    proposal_uuid := proposal_record.id;
    expected_version_uuid := proposal_record.expected_current_color_version_id;
    if proposal_record.team_color_work_item_id is not null then
      originating_job_type_value := 'team_color_specialist';
      originating_job_uuid := proposal_record.team_color_work_item_id;
      select priority into work_priority from public.team_color_work_items
      where id = proposal_record.team_color_work_item_id;
    end if;
  elsif specialist_result_kind_value = 'agent_specialist_result' then
    select * into strict specialist_record
    from public.agent_specialist_results where id = specialist_result_uuid;
    data_type_value := specialist_record.data_type;
    originating_job_type_value := specialist_record.job_type;
    originating_job_uuid := specialist_record.originating_job_id;
    expected_version_uuid := specialist_record.expected_authoritative_version_id;
  else
    raise exception 'Unsupported specialist result kind';
  end if;

  select * into strict adapter_record from public.catalog_domain_adapters
  where data_type = data_type_value and active;
  select * into strict policy_record from public.verification_policies
  where data_type = data_type_value and is_current and active;
  if verification_round_value > 1 then
    if parent_verification_work_item_uuid is null or not exists (
      select 1 from public.catalog_verification_work_items parent
      where parent.id = parent_verification_work_item_uuid
        and parent.specialist_result_kind = specialist_result_kind_value
        and parent.specialist_result_id = specialist_result_uuid
        and parent.verification_round = verification_round_value - 1
    ) then
      raise exception 'Additional verifier work requires the immediately preceding round';
    end if;
  end if;

  execute format('select %s($1,$2,$3)', adapter_record.build_verifier_context_function::regproc)
    using specialist_result_kind_value, specialist_result_uuid, verification_round_value
    into context_value;
  if context_value is null
     or nullif(context_value ->> 'subject_type', '') is null
     or nullif(context_value ->> 'subject_id', '') is null then
    raise exception 'Domain adapter did not return a valid blinded subject context';
  end if;
  select jsonb_strip_nulls(jsonb_build_object(
    'verification_policy_id', policy_record.id,
    'policy_key', policy_record.policy_key,
    'policy_version', policy_record.version,
    'verification_round', verification_round_value,
    'minimum_evidence_count', coalesce(round_policy.minimum_evidence_count, policy_record.minimum_evidence_count),
    'allowed_trust_tiers', coalesce(round_policy.allowed_trust_tiers, policy_record.allowed_trust_tiers),
    'minimum_independent_ownership_groups', coalesce(
      round_policy.minimum_independent_ownership_groups,
      case when policy_record.require_independent_sources then policy_record.minimum_evidence_count else 0 end
    ),
    'minimum_independent_information_lineages', coalesce(
      round_policy.minimum_independent_information_lineages,
      case when policy_record.require_independent_sources then policy_record.minimum_evidence_count else 0 end
    ),
    'minimum_high_trust_evidence_count', coalesce(
      round_policy.minimum_high_trust_evidence_count,
      (policy_record.configuration ->> 'minimum_tier_1_or_2_evidence_count')::integer,
      0
    ),
    'source_selection_policy', coalesce(round_policy.source_selection_policy, '{}'::jsonb),
    'maximum_verifier_rounds', policy_record.maximum_verifier_rounds,
    'required_matching_verifier_results', policy_record.required_matching_verifier_results,
    'consensus_strategy', policy_record.consensus_strategy
  )) into requirement_value
  from (select 1) seed
  left join public.catalog_verification_round_policies round_policy
    on round_policy.verification_policy_id = policy_record.id
   and round_policy.verification_round = verification_round_value;

  insert into public.catalog_verification_work_items(
    data_type, subject_type, subject_id, subject_reference, capability_scope,
    verifier_context, specialist_result_kind, specialist_result_id, proposal_id,
    originating_job_type, originating_job_id, expected_current_version_id,
    verification_policy_id, verification_round, parent_verification_work_item_id,
    round_requirement_snapshot, priority
  ) values (
    data_type_value, context_value ->> 'subject_type', context_value ->> 'subject_id',
    coalesce(context_value -> 'subject_reference', '{}'::jsonb),
    coalesce(context_value -> 'capability_scope', '{}'::jsonb),
    coalesce(context_value -> 'verifier_context', '{}'::jsonb),
    specialist_result_kind_value, specialist_result_uuid, proposal_uuid,
    originating_job_type_value, originating_job_uuid, expected_version_uuid,
    policy_record.id, verification_round_value, parent_verification_work_item_uuid,
    requirement_value, coalesce(work_priority, 0)
  )
  on conflict (specialist_result_kind, specialist_result_id, verification_round)
  do update set specialist_result_id = excluded.specialist_result_id
  returning id into result_uuid;
  insert into public.catalog_verification_work_events(
    verification_work_item_id, event_type, details
  )
  select result_uuid, 'queued', jsonb_build_object(
    'data_type', data_type_value,
    'specialist_result_kind', specialist_result_kind_value,
    'specialist_result_id', specialist_result_uuid,
    'originating_job_type', originating_job_type_value,
    'originating_job_id', originating_job_uuid,
    'verification_round', verification_round_value,
    'parent_verification_work_item_id', parent_verification_work_item_uuid,
    'round_requirement_snapshot', requirement_value
  )
  where not exists (
    select 1 from public.catalog_verification_work_events event
    where event.verification_work_item_id = result_uuid and event.event_type = 'queued'
  );
  return result_uuid;
end;
$$;

create or replace function public.ensure_catalog_verification_work(proposal_uuid uuid)
returns uuid
language sql
security definer
set search_path = ''
as $$
  select public.ensure_catalog_verification_work_for_result(
    'catalog_proposal', proposal_uuid, 1, null
  );
$$;

create or replace function public.ensure_team_color_verification_work()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'pending_verification'
     and new.proposal_id is not null
     and (tg_op = 'INSERT' or old.status is distinct from new.status or old.proposal_id is distinct from new.proposal_id) then
    perform public.ensure_catalog_verification_work(new.proposal_id);
  end if;
  return new;
end;
$$;

create trigger ensure_team_color_verification_work
after insert or update of status, proposal_id on public.team_color_work_items
for each row execute function public.ensure_team_color_verification_work();

create or replace function public.has_catalog_verification_capability(
  data_type_value text,
  capability_scope_value jsonb
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_catalog_capability(
    adapter.verification_capability,
    nullif(capability_scope_value ->> 'sport_id', '')::uuid,
    nullif(capability_scope_value ->> 'league_id', '')::uuid,
    nullif(capability_scope_value ->> 'team_id', '')::uuid,
    nullif(capability_scope_value ->> 'venue_id', '')::uuid
  )
  from public.catalog_domain_adapters adapter
  where adapter.data_type = data_type_value and adapter.active;
$$;

create or replace function public.get_my_catalog_verification_work(
  verification_work_item_uuid uuid,
  lease_token_value uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.catalog_verification_work_items%rowtype;
  result_value jsonb;
  capability_allowed boolean := false;
begin
  select * into strict work_record
  from public.catalog_verification_work_items where id = verification_work_item_uuid;
  if actor_uuid is null or work_record.status <> 'claimed'
     or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value
     or work_record.lease_expires_at <= now() then
    raise exception 'An active verification lease owned by this actor is required';
  end if;
  capability_allowed := public.has_catalog_verification_capability(
    work_record.data_type, work_record.capability_scope
  );
  if not coalesce(capability_allowed, false) then
    raise exception 'Scoped catalog verification capability is required';
  end if;

  select jsonb_build_object(
    'work', jsonb_build_object(
      'verification_work_item_id', work.id,
      'data_type', work.data_type,
      'subject_type', work.subject_type,
      'subject_id', work.subject_id,
      'verification_round', work.verification_round,
      'status', work.status,
      'attempt_number', work.attempt_count,
      'lease_token', work.lease_token,
      'lease_expires_at', work.lease_expires_at,
      'expected_current_version_id', work.expected_current_version_id
    ),
    'subject', work.subject_reference,
    'assignment', work.verifier_context,
    'verification_policy', work.round_requirement_snapshot
  ) into result_value
  from public.catalog_verification_work_items work
  where work.id = verification_work_item_uuid;
  return result_value;
end;
$$;

create or replace function public.claim_next_catalog_verification_work(
  data_type_value text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  selected_work public.catalog_verification_work_items%rowtype;
  runtime_policy public.agent_job_runtime_policies%rowtype;
  lease_uuid uuid := gen_random_uuid();
begin
  if actor_uuid is null then raise exception 'An active catalog actor is required'; end if;
  select work.* into selected_work
  from public.catalog_verification_work_items work
  left join public.catalog_change_proposals proposal
    on work.specialist_result_kind = 'catalog_proposal' and proposal.id = work.specialist_result_id
  left join public.agent_specialist_results specialist
    on work.specialist_result_kind = 'agent_specialist_result' and specialist.id = work.specialist_result_id
  where work.status in ('queued','retry_wait')
    and work.available_at <= now()
    and (data_type_value is null or work.data_type = data_type_value)
    and (proposal.id is null or proposal.status = 'pending')
    and coalesce(proposal.proposed_by_actor_id, specialist.submitted_by_actor_id) <> actor_uuid
    and not exists (
      select 1
      from public.catalog_verifier_results prior_result
      join public.catalog_verification_work_items prior_work
        on prior_work.id = prior_result.verification_work_item_id
      where prior_work.specialist_result_kind = work.specialist_result_kind
        and prior_work.specialist_result_id = work.specialist_result_id
        and prior_result.verifier_actor_id = actor_uuid
    )
    and public.has_catalog_verification_capability(
      work.data_type, work.capability_scope
    )
    and exists (
      select 1 from public.agent_job_runtime_policies policy
      where policy.job_type = 'catalog_verifier.' || work.data_type
        and policy.is_current and policy.active and policy.lease_seconds is not null
    )
  order by work.priority desc, work.available_at, work.created_at, work.id
  for update of work skip locked
  limit 1;
  if not found then return null; end if;
  select * into strict runtime_policy
  from public.current_agent_job_runtime_policy('catalog_verifier.' || selected_work.data_type);
  update public.catalog_verification_work_items
  set status = 'claimed', claimed_by_actor_id = actor_uuid,
      lease_token = lease_uuid,
      lease_expires_at = now() + make_interval(secs => runtime_policy.lease_seconds),
      attempt_count = attempt_count + 1,
      failure_category = null, failure_reason = null
  where id = selected_work.id
  returning * into selected_work;
  insert into public.catalog_verification_attempts(
    verification_work_item_id, attempt_number, actor_id, lease_token, lease_expires_at
  ) values (
    selected_work.id, selected_work.attempt_count, actor_uuid,
    lease_uuid, selected_work.lease_expires_at
  );
  insert into public.catalog_verification_work_events(
    verification_work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    selected_work.id, selected_work.attempt_count, actor_uuid, 'claimed',
    jsonb_build_object(
      'lease_expires_at', selected_work.lease_expires_at,
      'verification_round', selected_work.verification_round,
      'runtime_policy_id', runtime_policy.id
    )
  );
  return public.get_my_catalog_verification_work(selected_work.id, lease_uuid);
end;
$$;

create or replace function public.renew_catalog_verification_work_lease(
  verification_work_item_uuid uuid,
  lease_token_value uuid
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.catalog_verification_work_items%rowtype;
  runtime_policy public.agent_job_runtime_policies%rowtype;
begin
  select * into strict work_record
  from public.catalog_verification_work_items where id = verification_work_item_uuid for update;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now() then
    raise exception 'An unexpired verification lease owned by this actor is required';
  end if;
  if not public.has_catalog_verification_capability(
    work_record.data_type, work_record.capability_scope
  ) then
    raise exception 'Catalog verification capability is required';
  end if;
  select * into strict runtime_policy
  from public.current_agent_job_runtime_policy('catalog_verifier.' || work_record.data_type);
  update public.catalog_verification_work_items
  set lease_expires_at = now() + make_interval(secs => runtime_policy.lease_seconds)
  where id = verification_work_item_uuid returning * into work_record;
  update public.catalog_verification_attempts
  set last_heartbeat_at = now(), lease_expires_at = work_record.lease_expires_at
  where verification_work_item_id = work_record.id
    and attempt_number = work_record.attempt_count and ended_at is null;
  return work_record.lease_expires_at;
end;
$$;

create or replace function public.applicable_source_version_for_subject(
  source_uuid uuid,
  data_type_value text,
  capability_scope_value jsonb
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select applicability.id
  from public.source_applicability_versions applicability
  where applicability.source_id = source_uuid
    and applicability.data_type = data_type_value
    and applicability.is_current
    and applicability.review_status = 'approved'
    and (
      applicability.applicability_kind = 'global'
      or (
        applicability.applicability_kind = 'sport'
        and applicability.sport_id = nullif(capability_scope_value ->> 'sport_id', '')::uuid
      )
      or (
        applicability.applicability_kind = 'league'
        and applicability.league_id = nullif(capability_scope_value ->> 'league_id', '')::uuid
      )
      or (
        applicability.applicability_kind = 'team'
        and applicability.team_id = nullif(capability_scope_value ->> 'team_id', '')::uuid
      )
    )
  order by case applicability.applicability_kind
    when 'team' then 4 when 'league' then 3 when 'sport' then 2 else 1 end desc,
    applicability.created_at desc, applicability.id
  limit 1;
$$;

create or replace function public.catalog_source_evaluation_snapshot(
  source_uuid uuid,
  data_type_value text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare snapshot_value jsonb := jsonb_build_object(
  'data_type', data_type_value,
  'empirical_reliability_status', 'unrated'
);
begin
  if data_type_value = 'team_colors' then
    select snapshot_value || jsonb_build_object(
      'empirical_reliability_status', case
        when reliability.assessed_sample_size > 0 then 'rated' else 'unrated' end,
      'matches', reliability.matches,
      'contradictions', reliability.contradictions,
      'unresolved', reliability.unresolved,
      'not_assessable', reliability.not_assessable,
      'assessed_sample_size', reliability.assessed_sample_size,
      'raw_match_rate', reliability.raw_match_rate,
      'conservative_match_rate', reliability.conservative_match_rate,
      'team_breadth', reliability.team_breadth,
      'league_breadth', reliability.league_breadth,
      'sport_breadth', reliability.sport_breadth,
      'most_recent_outcome_at', reliability.most_recent_outcome_at
    ) into snapshot_value
    from public.trusted_sources source
    left join public.team_color_source_reliability_read_model reliability
      on reliability.source_id = source.source_id
    where source.id = source_uuid;
  end if;
  return coalesce(snapshot_value, '{}'::jsonb);
end;
$$;

create or replace function public.resolve_catalog_verification_source(
  verification_work_item_uuid uuid,
  lease_token_value uuid,
  evidence_url_value text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.catalog_verification_work_items%rowtype;
  resolution jsonb;
  source_uuid uuid;
  tier_uuid uuid;
  applicability_uuid uuid;
  tier_value smallint;
begin
  select * into strict work_record
  from public.catalog_verification_work_items where id = verification_work_item_uuid;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now() then
    raise exception 'An active verification lease owned by this actor is required';
  end if;
  if not public.has_catalog_verification_capability(
    work_record.data_type, work_record.capability_scope
  ) then
    raise exception 'Catalog verification capability is required';
  end if;
  resolution := public.resolve_trusted_source_url(evidence_url_value);
  if resolution ->> 'status' <> 'resolved' then return resolution; end if;
  select source.id into source_uuid from public.trusted_sources source
  where source.source_id = resolution #>> '{matches,0,source_id}';
  tier_uuid := public.current_source_trust_tier_assignment(source_uuid, work_record.data_type);
  applicability_uuid := public.applicable_source_version_for_subject(
    source_uuid, work_record.data_type, work_record.capability_scope
  );
  select trust_tier into tier_value
  from public.source_trust_assignments where id = tier_uuid;
  return resolution || jsonb_build_object(
    'trust_tier_version_id', tier_uuid,
    'trust_tier', tier_value,
    'applicability_version_id', applicability_uuid,
    'applicability', case when applicability_uuid is null then 'not_applicable' else 'applicable' end,
    'source_reliability', public.catalog_source_evaluation_snapshot(source_uuid, work_record.data_type),
    'source_qualification', jsonb_build_object(
      'publisher_review_status', (
        select review_status from public.trusted_sources where id = source_uuid
      ),
      'production_evidence_eligible', tier_uuid is not null and applicability_uuid is not null,
      'governance_trust_is_distinct_from_reliability', true
    )
  );
end;
$$;

create or replace function public.add_team_color_verifier_evidence(
  verification_work_item_uuid uuid,
  lease_token_value uuid,
  source_registry_id text,
  evidence_url_value text,
  evidence_summary_value text,
  observed_at_value timestamptz,
  structured_claim_value jsonb,
  information_lineage_key_value text default null,
  information_lineage_basis_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.catalog_verification_work_items%rowtype;
  requested_source_uuid uuid;
  source_uuid uuid;
  source_record public.trusted_sources%rowtype;
  url_scope_uuid uuid;
  tier_uuid uuid;
  applicability_uuid uuid;
  independence_uuid uuid;
  lineage_version_uuid uuid;
  top_specificity integer;
  top_source_count integer;
  result_uuid uuid;
begin
  select * into strict work_record
  from public.catalog_verification_work_items where id = verification_work_item_uuid for update;
  if work_record.data_type <> 'team_colors' then raise exception 'This RPC accepts only Team Color verifier evidence'; end if;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now() then
    raise exception 'An active Team Color verification lease owned by this actor is required';
  end if;
  if not public.has_catalog_verification_capability(work_record.data_type, work_record.capability_scope) then
    raise exception 'Team Color verification capability is required';
  end if;
  if not public.validate_team_color_claim(structured_claim_value) then
    raise exception 'A valid structured Team Color claim is required';
  end if;

  select id into requested_source_uuid from public.trusted_sources
  where source_id = source_registry_id;
  if requested_source_uuid is null then raise exception 'Unknown Trusted Source Registry ID'; end if;
  source_uuid := public.canonical_trusted_source_id(requested_source_uuid);
  select * into strict source_record from public.trusted_sources where id = source_uuid;
  if source_record.review_status <> 'approved' or source_record.independence_group_id is null then
    raise exception 'Publisher ownership and independence review is not approved';
  end if;
  select max(match.specificity) into top_specificity
  from public.trusted_source_url_matches(evidence_url_value) match;
  if top_specificity is null then raise exception 'Evidence URL is outside every permitted publisher URL scope'; end if;
  select count(distinct match.canonical_source_id) into top_source_count
  from public.trusted_source_url_matches(evidence_url_value) match
  where match.specificity = top_specificity;
  if top_source_count <> 1 then raise exception 'Evidence URL ownership is ambiguous'; end if;
  select match.url_scope_version_id into url_scope_uuid
  from public.trusted_source_url_matches(evidence_url_value) match
  join public.trusted_source_url_scope_versions scope on scope.id = match.url_scope_version_id
  where match.specificity = top_specificity
    and match.canonical_source_id = source_uuid
    and scope.review_status = 'approved'
  order by match.url_scope_version_id limit 1;
  if url_scope_uuid is null then raise exception 'Evidence URL does not belong to the selected publisher'; end if;

  tier_uuid := public.current_source_trust_tier_assignment(source_uuid, 'team_colors');
  applicability_uuid := public.applicable_source_version_for_subject(
    source_uuid, 'team_colors', work_record.capability_scope
  );
  if tier_uuid is null or applicability_uuid is null then
    raise exception 'Publisher lacks current Team Color trust or target applicability';
  end if;
  select assignment.id into independence_uuid
  from public.source_independence_group_assignment_versions assignment
  where assignment.source_id = source_uuid and assignment.is_current
    and assignment.review_status = 'approved'
    and assignment.independence_group_id = source_record.independence_group_id;
  if independence_uuid is null then raise exception 'Current approved independence assignment is required'; end if;

  if information_lineage_key_value is not null then
    if nullif(btrim(information_lineage_basis_value), '') is null then
      raise exception 'Known information lineage requires an assignment basis';
    end if;
    select version.id into lineage_version_uuid
    from public.information_lineages lineage
    join public.information_lineage_versions version
      on version.lineage_id = lineage.id and version.is_current
    where lineage.lineage_key = information_lineage_key_value
      and lineage.data_type = 'team_colors'
      and version.review_status = 'approved';
    if lineage_version_uuid is null then raise exception 'A current approved information lineage is required'; end if;
  end if;

  insert into public.catalog_verifier_evidence(
    verification_work_item_id, attempt_number, submitted_by_actor_id,
    source_id, evidence_url, evidence_summary, observed_at,
    source_url_scope_version_id, source_trust_assignment_id,
    source_applicability_version_id, source_independence_assignment_id,
    information_lineage_version_id, information_lineage_basis,
    source_reliability_snapshot, source_qualification_snapshot, structured_claim
  ) values (
    work_record.id, work_record.attempt_count, actor_uuid,
    source_uuid, evidence_url_value, evidence_summary_value, observed_at_value,
    url_scope_uuid, tier_uuid, applicability_uuid, independence_uuid,
    lineage_version_uuid, information_lineage_basis_value,
    public.catalog_source_evaluation_snapshot(source_uuid, 'team_colors'),
    jsonb_build_object(
      'publisher_review_status', source_record.review_status,
      'production_evidence_eligible', true,
      'governance_trust_is_distinct_from_reliability', true
    ),
    structured_claim_value
  ) returning id into result_uuid;
  insert into public.catalog_verification_work_events(
    verification_work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    work_record.id, work_record.attempt_count, actor_uuid, 'verifier_evidence_added',
    jsonb_build_object(
      'evidence_id', result_uuid, 'source_id', source_record.source_id,
      'information_lineage_version_id', lineage_version_uuid,
      'lineage_status', case when lineage_version_uuid is null then 'unknown' else 'known' end
    )
  );
  return result_uuid;
end;
$$;

-- Direct caller-selected Team Color approval is retired. Other catalog domains
-- retain the established review RPC until they adopt durable verification.
alter function public.review_catalog_proposal(uuid,text,text)
rename to review_catalog_proposal_pre_independent_verification;

revoke all on function public.review_catalog_proposal_pre_independent_verification(uuid,text,text)
from public, anon, authenticated;

create or replace function public.review_catalog_proposal(
  proposal_id_value uuid,
  decision_value text,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare fact_type_value text;
begin
  select fact_type into strict fact_type_value
  from public.catalog_change_proposals where id = proposal_id_value;
  if fact_type_value = 'team_colors' then
    raise exception 'Team Color proposals are decided only by durable independent verification and backend comparison';
  end if;
  return public.review_catalog_proposal_pre_independent_verification(
    proposal_id_value, decision_value, notes_value
  );
end;
$$;

create or replace function public.submit_team_color_verifier_result(
  verification_work_item_uuid uuid,
  lease_token_value uuid,
  result_kind_value text,
  result_payload_value jsonb,
  provenance_summary_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.catalog_verification_work_items%rowtype;
  proposal_record public.catalog_change_proposals%rowtype;
  attempt_uuid uuid;
  result_uuid uuid;
  evidence_snapshot_value jsonb;
begin
  select * into strict work_record
  from public.catalog_verification_work_items where id = verification_work_item_uuid for update;
  select * into strict proposal_record
  from public.catalog_change_proposals where id = work_record.proposal_id;
  if work_record.data_type <> 'team_colors'
     or work_record.specialist_result_kind <> 'catalog_proposal' then
    raise exception 'This RPC accepts only Team Color verifier results';
  end if;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now() then
    raise exception 'An active Team Color verification lease owned by this actor is required';
  end if;
  if proposal_record.proposed_by_actor_id = actor_uuid then
    raise exception 'A proposer cannot verify its own Team Color proposal';
  end if;
  if not public.has_catalog_verification_capability(work_record.data_type, work_record.capability_scope) then
    raise exception 'Team Color verification capability is required';
  end if;
  if result_kind_value not in ('determinate','incomplete','unresolved') then
    raise exception 'Invalid verifier result kind';
  end if;
  if result_kind_value = 'determinate' and (
    not public.validate_team_color_claim(result_payload_value)
    or result_payload_value ->> 'classification' <> 'current_canonical'
  ) then
    raise exception 'A determinate Team Color verifier result requires a valid current_canonical palette';
  end if;
  if result_kind_value <> 'determinate' and nullif(btrim(provenance_summary_value), '') is null then
    raise exception 'Incomplete or unresolved verifier results require an explanation';
  end if;
  select id into strict attempt_uuid
  from public.catalog_verification_attempts
  where verification_work_item_id = work_record.id
    and attempt_number = work_record.attempt_count
    and actor_id = actor_uuid and ended_at is null;

  select coalesce(jsonb_agg(jsonb_build_object(
    'evidence_id', evidence.id,
    'source_id', source.source_id,
    'evidence_url', evidence.evidence_url,
    'evidence_summary', evidence.evidence_summary,
    'observed_at', evidence.observed_at,
    'structured_claim', evidence.structured_claim,
    'url_scope_version_id', evidence.source_url_scope_version_id,
    'trust_tier_version_id', evidence.source_trust_assignment_id,
    'trust_tier', trust.trust_tier,
    'applicability_version_id', evidence.source_applicability_version_id,
    'independence_assignment_id', evidence.source_independence_assignment_id,
    'independence_group_id', ownership.independence_group_id,
    'information_lineage_version_id', evidence.information_lineage_version_id,
    'resolved_information_lineage_id', public.current_information_lineage_root(evidence.information_lineage_version_id),
    'information_lineage_basis', evidence.information_lineage_basis,
    'lineage_status', case when evidence.information_lineage_version_id is null then 'unknown' else 'known' end,
    'source_reliability', evidence.source_reliability_snapshot,
    'source_qualification', evidence.source_qualification_snapshot
  ) order by evidence.created_at, evidence.id), '[]'::jsonb)
  into evidence_snapshot_value
  from public.catalog_verifier_evidence evidence
  join public.trusted_sources source on source.id = evidence.source_id
  join public.source_trust_assignments trust on trust.id = evidence.source_trust_assignment_id
  join public.source_independence_group_assignment_versions ownership
    on ownership.id = evidence.source_independence_assignment_id
  where evidence.verification_work_item_id = work_record.id
    and evidence.attempt_number = work_record.attempt_count;

  insert into public.catalog_verifier_results(
    verification_work_item_id, verification_attempt_id, verifier_actor_id,
    result_kind, result_payload, provenance_summary, evidence_snapshot
  ) values (
    work_record.id, attempt_uuid, actor_uuid, result_kind_value,
    coalesce(result_payload_value, '{}'::jsonb), provenance_summary_value,
    evidence_snapshot_value
  ) returning id into result_uuid;
  update public.catalog_verification_attempts
  set ended_at = now(), outcome = 'result_submitted'
  where id = attempt_uuid;
  update public.catalog_verification_work_items
  set status = 'result_submitted', accepted_result_id = result_uuid,
      claimed_by_actor_id = null, lease_token = null, lease_expires_at = null
  where id = work_record.id;
  insert into public.catalog_verification_work_events(
    verification_work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    work_record.id, work_record.attempt_count, actor_uuid, 'result_submitted',
    jsonb_build_object(
      'verifier_result_id', result_uuid,
      'result_kind', result_kind_value,
      'verification_round', work_record.verification_round
    )
  );
  perform public.emit_agent_work_wake(
    'catalog_verification_comparison', work_record.id, 'result_ready', now(), result_uuid::text
  );
  return result_uuid;
end;
$$;

create or replace function public.submit_catalog_verifier_result(
  verification_work_item_uuid uuid,
  lease_token_value uuid,
  result_kind_value text,
  result_payload_value jsonb,
  provenance_summary_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.catalog_verification_work_items%rowtype;
  proposer_uuid uuid;
  attempt_uuid uuid;
  result_uuid uuid;
  evidence_snapshot_value jsonb;
begin
  select * into strict work_record
  from public.catalog_verification_work_items where id = verification_work_item_uuid for update;
  if work_record.data_type = 'team_colors' then
    return public.submit_team_color_verifier_result(
      verification_work_item_uuid, lease_token_value, result_kind_value,
      result_payload_value, provenance_summary_value
    );
  end if;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now() then
    raise exception 'An active verification lease owned by this actor is required';
  end if;
  if not public.has_catalog_verification_capability(work_record.data_type, work_record.capability_scope) then
    raise exception 'Scoped catalog verification capability is required';
  end if;
  if result_kind_value not in ('determinate','incomplete','unresolved') then
    raise exception 'Invalid verifier result kind';
  end if;
  if result_kind_value <> 'determinate' and nullif(btrim(provenance_summary_value), '') is null then
    raise exception 'Incomplete or unresolved verifier results require an explanation';
  end if;
  if work_record.specialist_result_kind = 'catalog_proposal' then
    select proposed_by_actor_id into strict proposer_uuid
    from public.catalog_change_proposals where id = work_record.specialist_result_id;
  else
    select submitted_by_actor_id into strict proposer_uuid
    from public.agent_specialist_results where id = work_record.specialist_result_id;
  end if;
  if proposer_uuid = actor_uuid then raise exception 'A proposer cannot verify its own result'; end if;
  select id into strict attempt_uuid from public.catalog_verification_attempts
  where verification_work_item_id = work_record.id
    and attempt_number = work_record.attempt_count
    and actor_id = actor_uuid and ended_at is null;
  select coalesce(jsonb_agg(jsonb_build_object(
    'evidence_id', evidence.id,
    'source_id', source.source_id,
    'evidence_url', evidence.evidence_url,
    'structured_claim', evidence.structured_claim,
    'trust_tier_version_id', evidence.source_trust_assignment_id,
    'applicability_version_id', evidence.source_applicability_version_id,
    'independence_assignment_id', evidence.source_independence_assignment_id,
    'information_lineage_version_id', evidence.information_lineage_version_id,
    'resolved_information_lineage_id', public.current_information_lineage_root(evidence.information_lineage_version_id),
    'source_reliability', evidence.source_reliability_snapshot,
    'source_qualification', evidence.source_qualification_snapshot
  ) order by evidence.created_at, evidence.id), '[]'::jsonb)
  into evidence_snapshot_value
  from public.catalog_verifier_evidence evidence
  join public.trusted_sources source on source.id = evidence.source_id
  where evidence.verification_work_item_id = work_record.id
    and evidence.attempt_number = work_record.attempt_count;
  insert into public.catalog_verifier_results(
    verification_work_item_id, verification_attempt_id, verifier_actor_id,
    result_kind, result_payload, provenance_summary, evidence_snapshot
  ) values (
    work_record.id, attempt_uuid, actor_uuid, result_kind_value,
    coalesce(result_payload_value, '{}'::jsonb), provenance_summary_value,
    evidence_snapshot_value
  ) returning id into result_uuid;
  update public.catalog_verification_attempts
  set ended_at = now(), outcome = 'result_submitted' where id = attempt_uuid;
  update public.catalog_verification_work_items
  set status = 'result_submitted', accepted_result_id = result_uuid,
      claimed_by_actor_id = null, lease_token = null, lease_expires_at = null
  where id = work_record.id;
  insert into public.catalog_verification_work_events(
    verification_work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    work_record.id, work_record.attempt_count, actor_uuid, 'result_submitted',
    jsonb_build_object(
      'verifier_result_id', result_uuid,
      'result_kind', result_kind_value,
      'verification_round', work_record.verification_round
    )
  );
  perform public.emit_agent_work_wake(
    'catalog_verification_comparison', work_record.id, 'result_ready', now(), result_uuid::text
  );
  return result_uuid;
end;
$$;

create or replace function public.team_color_authoritative_payload_from_palette(
  palette_value jsonb,
  proposal_payload_value jsonb
)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'primary', palette_value ->> 0,
    'secondary', palette_value ->> 1,
    'tertiary', nullif(palette_value ->> 2, ''),
    'quaternary', nullif(palette_value ->> 3, ''),
    'quinary', nullif(palette_value ->> 4, ''),
    'effective_from', proposal_payload_value ->> 'effective_from',
    'effective_from_precision', proposal_payload_value ->> 'effective_from_precision'
  ));
$$;

create or replace function public.finalize_team_color_authoritative_result(
  specialist_result_kind_value text,
  specialist_result_uuid uuid,
  adjudication_uuid uuid,
  authoritative_payload_value jsonb,
  finalization_outcome_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  proposal_record public.catalog_change_proposals%rowtype;
  adjudication_record public.catalog_determinate_adjudications%rowtype;
  current_color public.team_color_versions%rowtype;
  verification_decision_uuid uuid;
  resulting_version_uuid uuid;
  effective_date date;
begin
  if specialist_result_kind_value <> 'catalog_proposal' then
    raise exception 'Team Color finalization requires a catalog proposal';
  end if;
  if finalization_outcome_value not in ('promoted','confirmed_no_change') then
    raise exception 'Unsupported Team Color authoritative finalization outcome';
  end if;
  select * into strict proposal_record from public.catalog_change_proposals
  where id = specialist_result_uuid for update;
  if proposal_record.fact_type <> 'team_colors' or proposal_record.status <> 'pending' then
    raise exception 'A pending Team Color proposal is required';
  end if;
  select * into strict adjudication_record
  from public.catalog_determinate_adjudications
  where id = adjudication_uuid
    and data_type = 'team_colors'
    and specialist_result_kind = specialist_result_kind_value
    and specialist_result_id = specialist_result_uuid
    and authoritative_result_payload = authoritative_payload_value
    and outcome = finalization_outcome_value;
  verification_decision_uuid := adjudication_record.catalog_verification_decision_id;
  if verification_decision_uuid is null or not exists (
    select 1 from public.catalog_verification_decisions decision
    where decision.id = verification_decision_uuid
      and decision.proposal_id = proposal_record.id and decision.decision = 'approved'
  ) then
    raise exception 'Authoritative finalization requires its approved deterministic decision';
  end if;
  select * into current_color from public.team_color_versions
  where team_id = proposal_record.target_team_id and is_current for update;
  if current_color.id is distinct from proposal_record.expected_current_color_version_id then
    raise exception 'The current Team Color version changed before authoritative finalization';
  end if;

  if finalization_outcome_value = 'confirmed_no_change' then
    if not found or current_color.record_status <> 'verified'
       or public.team_color_palette_from_payload(authoritative_payload_value) <>
          public.team_color_palette_from_payload(jsonb_build_object(
            'primary', current_color.primary_color,
            'secondary', current_color.secondary_color,
            'tertiary', current_color.tertiary_color,
            'quaternary', current_color.quaternary_color,
            'quinary', current_color.quinary_color
          )) then
      raise exception 'No-change finalization must preserve the exact current verified palette';
    end if;
    resulting_version_uuid := current_color.id;
  else
    if not public.validate_team_color_claim(jsonb_build_object(
      'classification', 'current_canonical',
      'palette', public.team_color_palette_from_payload(authoritative_payload_value)
    )) then
      raise exception 'Authoritative Team Color payload is invalid';
    end if;
    effective_date := nullif(authoritative_payload_value ->> 'effective_from', '')::date;
    update public.team_color_versions
    set is_current = false, effective_to = effective_date, superseded_at = now()
    where team_id = proposal_record.target_team_id and is_current;
    insert into public.team_color_versions(
      team_id, primary_color, secondary_color, tertiary_color, quaternary_color,
      quinary_color, effective_from, effective_from_precision, record_status,
      verification_decision_id
    ) values (
      proposal_record.target_team_id,
      upper(authoritative_payload_value ->> 'primary'),
      upper(authoritative_payload_value ->> 'secondary'),
      upper(nullif(authoritative_payload_value ->> 'tertiary', '')),
      upper(nullif(authoritative_payload_value ->> 'quaternary', '')),
      upper(nullif(authoritative_payload_value ->> 'quinary', '')),
      effective_date,
      coalesce(nullif(authoritative_payload_value ->> 'effective_from_precision', ''), 'unknown'),
      'verified', verification_decision_uuid
    ) returning id into resulting_version_uuid;
  end if;

  update public.catalog_change_proposals
  set status = 'approved', resolved_at = now(),
      resolution_notes = case finalization_outcome_value
        when 'confirmed_no_change' then 'Independent revalidation confirmed no change.'
        else 'Deterministic independent verification selected and promoted the authoritative palette.' end
  where id = proposal_record.id;
  update public.team_color_work_items
  set status = 'completed', completed_at = now(),
      failure_category = null, failure_reason = null
  where id = proposal_record.team_color_work_item_id
    and status = 'pending_verification';
  perform public.record_team_color_revalidation_state(
    proposal_record.target_team_id, resulting_version_uuid, verification_decision_uuid,
    finalization_outcome_value, proposal_record.recheck_trigger,
    proposal_record.proposal_reason
  );
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, proposal_id, details
  )
  select decision.decided_by_actor_id, auth.uid(),
         'authoritative_result.finalized', 'team_colors',
         proposal_record.target_team_id::text, proposal_record.id,
         jsonb_build_object(
           'decision_id', verification_decision_uuid,
           'adjudication_id', adjudication_uuid,
           'authoritative_version_id', resulting_version_uuid,
           'outcome', finalization_outcome_value,
           'single_domain_finalization_primitive', true
         )
  from public.catalog_verification_decisions decision
  where decision.id = verification_decision_uuid;
  return resulting_version_uuid;
end;
$$;

create or replace function public.finalize_catalog_authoritative_result(
  data_type_value text,
  specialist_result_kind_value text,
  specialist_result_uuid uuid,
  verification_decision_uuid uuid,
  authoritative_payload_value jsonb,
  finalization_outcome_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare adapter_record public.catalog_domain_adapters%rowtype; result_uuid uuid;
begin
  select * into strict adapter_record from public.catalog_domain_adapters
  where data_type = data_type_value and active for share;
  execute format('select %s($1,$2,$3,$4,$5)', adapter_record.finalize_authoritative_function::regproc)
    using specialist_result_kind_value, specialist_result_uuid,
          verification_decision_uuid, authoritative_payload_value,
          finalization_outcome_value
    into result_uuid;
  return result_uuid;
end;
$$;

create or replace function public.schedule_additional_catalog_verification_round(
  completed_verification_work_item_uuid uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  work_record public.catalog_verification_work_items%rowtype;
  policy_record public.verification_policies%rowtype;
begin
  select * into strict work_record from public.catalog_verification_work_items
  where id = completed_verification_work_item_uuid for update;
  select * into strict policy_record from public.verification_policies
  where id = work_record.verification_policy_id;
  if policy_record.maximum_verifier_rounds is null then return null; end if;
  if work_record.verification_round >= policy_record.maximum_verifier_rounds then return null; end if;
  return public.ensure_catalog_verification_work_for_result(
    work_record.specialist_result_kind, work_record.specialist_result_id,
    work_record.verification_round + 1, work_record.id
  );
end;
$$;

create or replace function public.compare_team_color_verifier_result(
  verifier_result_uuid uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  result_record public.catalog_verifier_results%rowtype;
  work_record public.catalog_verification_work_items%rowtype;
  proposal_record public.catalog_change_proposals%rowtype;
  policy_record public.verification_policies%rowtype;
  current_color public.team_color_versions%rowtype;
  specialist_palette jsonb;
  verifier_palette jsonb;
  authoritative_payload_value jsonb;
  specialist_count integer;
  specialist_owner_count integer;
  specialist_lineage_count integer;
  specialist_high_trust_count integer;
  verifier_count integer;
  verifier_owner_count integer;
  verifier_lineage_count integer;
  verifier_high_trust_count integer;
  verifier_consensus_count integer := 0;
  verifier_minimum integer;
  verifier_owner_minimum integer;
  verifier_lineage_minimum integer;
  verifier_high_trust_minimum integer;
  allowed_tiers smallint[];
  specialist_evidence_qualifies boolean := false;
  verifier_evidence_qualifies boolean := false;
  evidence_qualifies boolean := false;
  exact_specialist_match boolean := false;
  outcome_value text;
  finalization_outcome_value text;
  decision_uuid uuid;
  adjudication_uuid uuid;
  comparison_uuid uuid;
  next_work_uuid uuid;
begin
  select * into strict result_record
  from public.catalog_verifier_results where id = verifier_result_uuid;
  select * into strict work_record
  from public.catalog_verification_work_items
  where id = result_record.verification_work_item_id for update;
  if exists (
    select 1 from public.catalog_verification_comparisons
    where verifier_result_id = verifier_result_uuid
  ) then
    select comparison_outcome into outcome_value
    from public.catalog_verification_comparisons where verifier_result_id = verifier_result_uuid;
    return outcome_value;
  end if;
  if work_record.data_type <> 'team_colors'
     or work_record.specialist_result_kind <> 'catalog_proposal' then
    raise exception 'Team Color comparison received a different domain result';
  end if;
  if work_record.status <> 'result_submitted' or work_record.accepted_result_id <> result_record.id then
    raise exception 'Verifier result is not awaiting comparison';
  end if;
  select * into strict proposal_record from public.catalog_change_proposals
  where id = work_record.specialist_result_id for update;
  select * into strict policy_record from public.verification_policies
  where id = work_record.verification_policy_id;
  specialist_palette := public.team_color_palette_from_payload(proposal_record.payload);
  verifier_palette := result_record.result_payload -> 'palette';
  verifier_minimum := coalesce((work_record.round_requirement_snapshot ->> 'minimum_evidence_count')::integer, 0);
  verifier_owner_minimum := coalesce((work_record.round_requirement_snapshot ->> 'minimum_independent_ownership_groups')::integer, 0);
  verifier_lineage_minimum := coalesce((work_record.round_requirement_snapshot ->> 'minimum_independent_information_lineages')::integer, 0);
  verifier_high_trust_minimum := coalesce((work_record.round_requirement_snapshot ->> 'minimum_high_trust_evidence_count')::integer, 0);
  select coalesce(array_agg(value::smallint), '{}'::smallint[]) into allowed_tiers
  from jsonb_array_elements_text(coalesce(work_record.round_requirement_snapshot -> 'allowed_trust_tiers', '[]'::jsonb));

  select count(distinct evidence.id),
         count(distinct ownership.independence_group_id),
         count(distinct public.current_information_lineage_root(coalesce(
           evidence.information_lineage_version_id,
           specialist_lineage_assignment.information_lineage_version_id
         ))),
         count(distinct evidence.id) filter (where trust.trust_tier in (1,2))
  into specialist_count, specialist_owner_count, specialist_lineage_count, specialist_high_trust_count
  from public.catalog_proposal_evidence evidence
  join public.trusted_sources source on source.id = evidence.source_id
    and source.review_status = 'approved' and source.superseded_by_source_id is null
  join public.source_trust_assignments trust on trust.id = evidence.source_trust_assignment_id
    and trust.is_current
  join public.source_applicability_versions applicability
    on applicability.id = evidence.source_applicability_version_id
    and applicability.is_current and applicability.review_status = 'approved'
  join public.source_independence_group_assignment_versions ownership
    on ownership.id = evidence.source_independence_assignment_id
    and ownership.is_current and ownership.review_status = 'approved'
  left join public.catalog_evidence_lineage_assignments specialist_lineage_assignment
    on specialist_lineage_assignment.evidence_kind = 'proposal_evidence'
   and specialist_lineage_assignment.evidence_id = evidence.id
   and specialist_lineage_assignment.is_current
  where evidence.proposal_id = proposal_record.id
    and evidence.supports_proposal
    and evidence.structured_claim ->> 'classification' = 'current_canonical'
    and evidence.structured_claim -> 'palette' = specialist_palette
    and trust.trust_tier = any(policy_record.allowed_trust_tiers)
    and trust.id = public.current_source_trust_tier_assignment(source.id, 'team_colors')
    and applicability.id = public.applicable_source_applicability_version(
      source.id, 'team_colors', proposal_record.target_team_id
    )
    and public.current_information_lineage_root(coalesce(
      evidence.information_lineage_version_id,
      specialist_lineage_assignment.information_lineage_version_id
    )) is not null;

  select count(distinct evidence.id),
         count(distinct ownership.independence_group_id),
         count(distinct public.current_information_lineage_root(coalesce(
           evidence.information_lineage_version_id,
           verifier_lineage_assignment.information_lineage_version_id
         ))),
         count(distinct evidence.id) filter (where trust.trust_tier in (1,2))
  into verifier_count, verifier_owner_count, verifier_lineage_count, verifier_high_trust_count
  from public.catalog_verifier_evidence evidence
  join public.trusted_sources source on source.id = evidence.source_id
    and source.review_status = 'approved' and source.superseded_by_source_id is null
  join public.source_trust_assignments trust on trust.id = evidence.source_trust_assignment_id
    and trust.is_current
  join public.source_applicability_versions applicability
    on applicability.id = evidence.source_applicability_version_id
    and applicability.is_current and applicability.review_status = 'approved'
  join public.source_independence_group_assignment_versions ownership
    on ownership.id = evidence.source_independence_assignment_id
    and ownership.is_current and ownership.review_status = 'approved'
  left join public.catalog_evidence_lineage_assignments verifier_lineage_assignment
    on verifier_lineage_assignment.evidence_kind = 'verifier_evidence'
   and verifier_lineage_assignment.evidence_id = evidence.id
   and verifier_lineage_assignment.is_current
  where evidence.verification_work_item_id = work_record.id
    and evidence.attempt_number = (
      select attempt_number from public.catalog_verification_attempts
      where id = result_record.verification_attempt_id
    )
    and evidence.structured_claim ->> 'classification' = 'current_canonical'
    and evidence.structured_claim -> 'palette' = verifier_palette
    and trust.trust_tier = any(allowed_tiers)
    and trust.id = public.current_source_trust_tier_assignment(source.id, 'team_colors')
    and applicability.id = public.applicable_source_applicability_version(
      source.id, 'team_colors', proposal_record.target_team_id
    )
    and public.current_information_lineage_root(coalesce(
      evidence.information_lineage_version_id,
      verifier_lineage_assignment.information_lineage_version_id
    )) is not null;

  specialist_evidence_qualifies :=
    specialist_count >= policy_record.minimum_evidence_count
    and specialist_owner_count >= case when policy_record.require_independent_sources
      then policy_record.minimum_evidence_count else 0 end
    and specialist_lineage_count >= case when policy_record.require_independent_sources
      then policy_record.minimum_evidence_count else 0 end
    and specialist_high_trust_count >= coalesce(
      (policy_record.configuration ->> 'minimum_tier_1_or_2_evidence_count')::integer, 0
    );
  verifier_evidence_qualifies :=
    verifier_count >= verifier_minimum
    and verifier_owner_count >= verifier_owner_minimum
    and verifier_lineage_count >= verifier_lineage_minimum
    and verifier_high_trust_count >= verifier_high_trust_minimum;
  evidence_qualifies := specialist_evidence_qualifies and verifier_evidence_qualifies;
  exact_specialist_match := result_record.result_kind = 'determinate'
    and public.validate_team_color_claim(result_record.result_payload)
    and result_record.result_payload ->> 'classification' = 'current_canonical'
    and verifier_palette = specialist_palette;

  if result_record.result_kind = 'determinate'
     and public.validate_team_color_claim(result_record.result_payload) then
    select count(*) + 1 into verifier_consensus_count
    from public.catalog_verification_comparisons comparison
    join public.catalog_verification_work_items prior_work
      on prior_work.id = comparison.verification_work_item_id
    where prior_work.specialist_result_kind = work_record.specialist_result_kind
      and prior_work.specialist_result_id = work_record.specialist_result_id
      and comparison.normalized_verifier_result = verifier_palette
      and comparison.comparison_outcome = 'additional_verifier_queued'
      and coalesce(
        (comparison.details ->> 'verifier_evidence_qualifies')::boolean,
        false
      );
  end if;

  select * into current_color from public.team_color_versions
  where team_id = proposal_record.target_team_id and is_current for update;
  if current_color.id is distinct from proposal_record.expected_current_color_version_id then
    outcome_value := 'stale_expected_version';
  elsif not specialist_evidence_qualifies then
    -- A later verifier cannot repair the specialist's own unqualified evidence.
    -- Preserve the failure explicitly instead of consuming autonomous rounds.
    outcome_value := 'insufficient_evidence';
  elsif evidence_qualifies and exact_specialist_match then
    authoritative_payload_value := proposal_record.payload;
    finalization_outcome_value := case
      when proposal_record.team_color_change_kind = 'no_change_recheck'
        then 'confirmed_no_change' else 'promoted' end;
    outcome_value := finalization_outcome_value;
  elsif evidence_qualifies
     and policy_record.consensus_strategy = 'specialist_match_or_verifier_consensus'
     and policy_record.required_matching_verifier_results is not null
     and verifier_consensus_count >= policy_record.required_matching_verifier_results then
    authoritative_payload_value := public.team_color_authoritative_payload_from_palette(
      verifier_palette, proposal_record.payload
    );
    finalization_outcome_value := 'promoted';
    outcome_value := 'promoted';
  else
    next_work_uuid := public.schedule_additional_catalog_verification_round(work_record.id);
    outcome_value := case when next_work_uuid is null
      then 'automation_exhausted' else 'additional_verifier_queued' end;
  end if;

  if outcome_value in ('promoted','confirmed_no_change') then
    insert into public.catalog_verification_decisions(
      proposal_id, decision, policy_id, decided_by_actor_id,
      policy_snapshot, authoritative_result_payload,
      verification_resolution_snapshot, notes
    ) values (
      proposal_record.id, 'approved', policy_record.id,
      result_record.verifier_actor_id,
      jsonb_build_object(
        'policy_key', policy_record.policy_key,
        'version', policy_record.version,
        'deterministic_comparison', true,
        'consensus_strategy', policy_record.consensus_strategy,
        'maximum_verifier_rounds', policy_record.maximum_verifier_rounds,
        'required_matching_verifier_results', policy_record.required_matching_verifier_results
      ),
      authoritative_payload_value,
      jsonb_build_object(
        'resolving_verifier_result_id', result_record.id,
        'resolving_verification_round', work_record.verification_round,
        'verifier_consensus_count', verifier_consensus_count,
        'finalization_outcome', finalization_outcome_value,
        'specialist_result_kind', work_record.specialist_result_kind,
        'specialist_result_id', work_record.specialist_result_id
      ),
      'Backend policy deterministically resolved independently researched results.'
    ) returning id into decision_uuid;
    insert into public.catalog_determinate_adjudications(
      data_type, subject_type, subject_id, specialist_result_kind,
      specialist_result_id, verification_policy_id,
      resolving_verifier_result_id, outcome, authoritative_result_payload,
      resolution_snapshot, catalog_verification_decision_id,
      decided_by_actor_id
    ) values (
      work_record.data_type, work_record.subject_type, work_record.subject_id,
      work_record.specialist_result_kind, work_record.specialist_result_id,
      policy_record.id, result_record.id, finalization_outcome_value,
      authoritative_payload_value,
      jsonb_build_object(
        'verification_round', work_record.verification_round,
        'verifier_consensus_count', verifier_consensus_count,
        'deterministic_domain_adapter', true
      ),
      decision_uuid, result_record.verifier_actor_id
    ) returning id into adjudication_uuid;
    perform public.finalize_catalog_authoritative_result(
      work_record.data_type, work_record.specialist_result_kind,
      work_record.specialist_result_id, adjudication_uuid,
      authoritative_payload_value, finalization_outcome_value
    );
  end if;

  insert into public.catalog_verification_comparisons(
    verification_work_item_id, proposal_id, specialist_result_kind,
    specialist_result_id, verification_round, verifier_result_id, policy_id,
    comparison_outcome, normalized_specialist_result, normalized_verifier_result,
    adjudication_id, verification_decision_id, details
  ) values (
    work_record.id, proposal_record.id, work_record.specialist_result_kind,
    work_record.specialist_result_id, work_record.verification_round,
    result_record.id, policy_record.id, outcome_value,
    specialist_palette, verifier_palette, adjudication_uuid, decision_uuid,
    jsonb_build_object(
      'specialist_evidence_count', specialist_count,
      'specialist_ownership_group_count', specialist_owner_count,
      'specialist_information_lineage_count', specialist_lineage_count,
      'verifier_evidence_count', verifier_count,
      'verifier_ownership_group_count', verifier_owner_count,
      'verifier_information_lineage_count', verifier_lineage_count,
      'specialist_evidence_qualifies', specialist_evidence_qualifies,
      'verifier_evidence_qualifies', verifier_evidence_qualifies,
      'verifier_consensus_count', verifier_consensus_count,
      'additional_verification_work_item_id', next_work_uuid,
      'source_overlap_permitted', true,
      'lineage_independence_counted_separately', true,
      'round_requirement_snapshot', work_record.round_requirement_snapshot
    )
  ) returning id into comparison_uuid;

  update public.catalog_verification_work_items
  set status = case
        when outcome_value in ('promoted','confirmed_no_change','additional_verifier_queued') then 'completed'
        else 'needs_review' end,
      failure_category = case
        when outcome_value in ('promoted','confirmed_no_change','additional_verifier_queued') then null
        else outcome_value end,
      failure_reason = case
        when outcome_value = 'automation_exhausted'
          then 'The versioned automated verifier policy reached its configured limit without resolution.'
        when outcome_value in ('promoted','confirmed_no_change','additional_verifier_queued') then null
        else 'Deterministic verification could not safely resolve this result.' end,
      completed_at = case
        when outcome_value in ('promoted','confirmed_no_change','additional_verifier_queued') then now()
        else null end
  where id = work_record.id;
  update public.catalog_verification_attempts
  set outcome = case
        when outcome_value in ('promoted','confirmed_no_change','additional_verifier_queued') then 'completed'
        else 'needs_review' end,
      failure_category = case
        when outcome_value in ('promoted','confirmed_no_change','additional_verifier_queued') then null
        else outcome_value end
  where id = result_record.verification_attempt_id;
  if outcome_value not in ('promoted','confirmed_no_change','additional_verifier_queued')
     and work_record.originating_job_type = 'team_color_specialist' then
    update public.team_color_work_items
    set status = 'needs_review', failure_category = outcome_value,
        failure_reason = 'Automated independent verification reached a genuine exception state.'
    where id = work_record.originating_job_id and status = 'pending_verification';
  end if;
  insert into public.catalog_verification_work_events(
    verification_work_item_id, actor_id, event_type, details
  ) values (
    work_record.id, result_record.verifier_actor_id, 'comparison_' || outcome_value,
    jsonb_build_object(
      'comparison_id', comparison_uuid,
      'verifier_result_id', result_record.id,
      'verification_decision_id', decision_uuid,
      'adjudication_id', adjudication_uuid,
      'additional_verification_work_item_id', next_work_uuid
    )
  );
  update public.agent_work_wake_outbox
  set status = 'acknowledged', acknowledged_at = now()
  where queue_name = 'catalog_verification_comparison'
    and work_item_id = work_record.id and status = 'pending';
  return outcome_value;
end;
$$;

-- ---------------------------------------------------------------------------
-- Team Color compatibility adapters: no-change becomes a proposal and retry
-- timing/classification is selected exclusively by backend runtime policy.
-- ---------------------------------------------------------------------------

alter table public.catalog_change_proposals
  drop constraint catalog_change_proposals_operation_check;
alter table public.catalog_change_proposals
  add constraint catalog_change_proposals_operation_check
  check (operation in ('create','replace','retire','revalidate'));

alter table public.catalog_change_proposals
  drop constraint catalog_team_color_change_kind_check;
alter table public.catalog_change_proposals
  add constraint catalog_team_color_change_kind_check
  check (team_color_change_kind is null or team_color_change_kind in (
    'fill_missing_or_unverified','verified_replacement','no_change_recheck'
  ));

alter function public.submit_team_color_proposal(uuid,uuid,jsonb,text)
rename to submit_team_color_proposal_pre_independent_verification;
revoke all on function public.submit_team_color_proposal_pre_independent_verification(uuid,uuid,jsonb,text)
from public, anon, authenticated;

create or replace function public.submit_team_color_proposal(
  work_item_id_value uuid,
  lease_token_value uuid,
  payload_value jsonb,
  reason_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.team_color_work_items%rowtype;
  current_color public.team_color_versions%rowtype;
  result_uuid uuid;
begin
  select * into strict work_record
  from public.team_color_work_items where id = work_item_id_value for update;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now() then
    raise exception 'An unexpired Team Color work lease owned by this actor is required';
  end if;
  select * into current_color from public.team_color_versions
  where team_id = work_record.team_id and is_current for update;
  if found and current_color.record_status = 'verified'
     and current_color.id is not distinct from work_record.expected_current_color_version_id
     and public.team_color_palette_from_payload(payload_value) =
         public.team_color_palette_from_payload(jsonb_build_object(
           'primary', current_color.primary_color,
           'secondary', current_color.secondary_color,
           'tertiary', current_color.tertiary_color,
           'quaternary', current_color.quaternary_color,
           'quinary', current_color.quinary_color
         )) then
    if work_record.work_kind <> 'verified_recheck' or work_record.recheck_trigger is null then
      raise exception 'No-change results require authorized verified recheck work';
    end if;
    if not public.has_team_color_capability('catalog.propose.team_colors', work_record.team_id) then
      raise exception 'Team Color proposal capability is required';
    end if;
    if nullif(btrim(reason_value), '') is null then raise exception 'A proposal reason is required'; end if;
    if work_record.proposal_id is not null then raise exception 'This work item already has a proposal'; end if;
    insert into public.catalog_change_proposals(
      fact_type, operation, target_team_id, payload, status,
      proposed_by_actor_id, team_color_work_item_id,
      expected_current_color_version_id, team_color_change_kind,
      proposal_reason, recheck_trigger
    ) values (
      'team_colors', 'revalidate', work_record.team_id, payload_value, 'pending',
      actor_uuid, work_record.id, work_record.expected_current_color_version_id,
      'no_change_recheck', btrim(reason_value), work_record.recheck_trigger
    ) returning id into result_uuid;
    update public.team_color_work_items set proposal_id = result_uuid where id = work_record.id;
    insert into public.catalog_audit_events(
      actor_id, auth_user_id, action, entity_type, entity_id, proposal_id, details
    ) values (
      actor_uuid, auth.uid(), 'proposal.submitted', 'team_colors',
      work_record.team_id::text, result_uuid, jsonb_build_object(
        'work_item_id', work_record.id,
        'change_kind', 'no_change_recheck',
        'expected_current_color_version_id', work_record.expected_current_color_version_id,
        'reason', btrim(reason_value)
      )
    );
    return result_uuid;
  end if;
  return public.submit_team_color_proposal_pre_independent_verification(
    work_item_id_value, lease_token_value, payload_value, reason_value
  );
end;
$$;

-- Preserve the deployed RPC signatures for existing workers, but make the
-- versioned backend policy authoritative. The legacy lease argument is accepted
-- only for wire compatibility and is never used to select lease duration.
create or replace function public.claim_next_team_color_work(
  lease_seconds_value integer default 900
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  selected_work public.team_color_work_items%rowtype;
  runtime_policy public.agent_job_runtime_policies%rowtype;
  lease_token_result uuid := gen_random_uuid();
begin
  if actor_uuid is null then raise exception 'An active catalog actor is required'; end if;
  select * into strict runtime_policy
  from public.current_agent_job_runtime_policy('team_color_specialist');
  if runtime_policy.lease_seconds is null then
    raise exception 'The current Team Color specialist runtime policy has no approved lease duration';
  end if;

  -- Claim-time recovery remains a useful fast path, but the independent
  -- watchdog operation is the authoritative continuous recovery interface.
  perform public.expire_team_color_work_leases();
  update public.team_color_work_items work
  set status = 'needs_review',
      failure_category = 'current_version_changed',
      failure_reason = 'The current team-color version changed before this work was claimed.'
  where work.status in ('queued', 'retry_wait')
    and work.expected_current_color_version_id is distinct from (
      select colors.id from public.team_color_versions colors
      where colors.team_id = work.team_id and colors.is_current
    );

  select work.* into selected_work
  from public.team_color_work_items work
  join public.catalog_teams team on team.id = work.team_id
  left join public.team_primary_league_versions membership
    on membership.team_id = team.id and membership.is_current
  where work.status in ('queued', 'retry_wait')
    and work.available_at <= now()
    and public.has_catalog_capability(
      'team_colors.work.claim', team.sport_id, membership.league_id, team.id, null
    )
    and not exists (
      select 1 from public.catalog_change_proposals proposal
      where proposal.target_team_id = work.team_id
        and proposal.fact_type = 'team_colors' and proposal.status = 'pending'
    )
  order by work.priority desc, work.available_at, work.created_at, work.id
  for update of work skip locked
  limit 1;
  if not found then return null; end if;

  update public.team_color_work_items
  set status = 'claimed', claimed_by_actor_id = actor_uuid,
      lease_token = lease_token_result,
      lease_expires_at = now() + make_interval(secs => runtime_policy.lease_seconds),
      attempt_count = attempt_count + 1, claimed_at = now(),
      failure_category = null, failure_reason = null
  where id = selected_work.id
  returning * into selected_work;
  insert into public.team_color_work_attempts(
    work_item_id, attempt_number, actor_id, lease_token, lease_expires_at
  ) values (
    selected_work.id, selected_work.attempt_count, actor_uuid,
    lease_token_result, selected_work.lease_expires_at
  );
  insert into public.team_color_work_events(
    work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    selected_work.id, selected_work.attempt_count, actor_uuid, 'claimed',
    jsonb_build_object(
      'lease_expires_at', selected_work.lease_expires_at,
      'runtime_policy_id', runtime_policy.id,
      'backend_selected_lease', true,
      'legacy_requested_lease_seconds_ignored', lease_seconds_value
    )
  );
  return public.get_my_team_color_work(selected_work.id, lease_token_result);
end;
$$;

create or replace function public.renew_team_color_work_lease(
  work_item_id_value uuid,
  lease_token_value uuid,
  lease_seconds_value integer default 900
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.team_color_work_items%rowtype;
  runtime_policy public.agent_job_runtime_policies%rowtype;
begin
  select * into strict work_record
  from public.team_color_work_items where id = work_item_id_value for update;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now() then
    raise exception 'An unexpired Team Color work lease owned by this actor is required';
  end if;
  if not public.has_team_color_capability('team_colors.work.update', work_record.team_id) then
    raise exception 'Team Color work-update capability is required';
  end if;
  select * into strict runtime_policy
  from public.current_agent_job_runtime_policy('team_color_specialist');
  if runtime_policy.lease_seconds is null then
    raise exception 'The current Team Color specialist runtime policy has no approved lease duration';
  end if;
  update public.team_color_work_items
  set lease_expires_at = now() + make_interval(secs => runtime_policy.lease_seconds)
  where id = work_item_id_value
  returning * into work_record;
  update public.team_color_work_attempts
  set last_heartbeat_at = now(), lease_expires_at = work_record.lease_expires_at
  where work_item_id = work_item_id_value
    and attempt_number = work_record.attempt_count and ended_at is null;
  insert into public.team_color_work_events(
    work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    work_record.id, work_record.attempt_count, actor_uuid, 'lease_renewed',
    jsonb_build_object(
      'lease_expires_at', work_record.lease_expires_at,
      'runtime_policy_id', runtime_policy.id,
      'backend_selected_lease', true,
      'legacy_requested_lease_seconds_ignored', lease_seconds_value
    )
  );
  return work_record.lease_expires_at;
end;
$$;

create or replace function public.transition_team_color_work_by_runtime_policy(
  work_item_uuid uuid,
  failure_category_value text,
  failure_reason_value text,
  summary_value jsonb,
  require_live_lease boolean default true,
  lease_actor_uuid uuid default null,
  lease_token_value uuid default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  work_record public.team_color_work_items%rowtype;
  runtime_policy public.agent_job_runtime_policies%rowtype;
  next_status text;
  next_available_at timestamptz;
  delay_index integer;
begin
  select * into strict work_record
  from public.team_color_work_items where id = work_item_uuid for update;
  if require_live_lease and (
    work_record.status <> 'claimed'
    or work_record.claimed_by_actor_id <> lease_actor_uuid
    or work_record.lease_token <> lease_token_value
    or work_record.lease_expires_at <= now()
  ) then
    raise exception 'An unexpired Team Color work lease owned by this actor is required';
  end if;
  if work_record.status <> 'claimed' then raise exception 'Only claimed Team Color work may transition by failure policy'; end if;
  select * into runtime_policy
  from public.current_agent_job_runtime_policy('team_color_specialist');
  if not found then
    next_status := 'needs_review';
    failure_category_value := 'retry_policy_unconfigured';
    failure_reason_value := coalesce(failure_reason_value,
      'Team Color runtime retry policy is not configured.');
  elsif failure_category_value = any(runtime_policy.retryable_failure_categories) then
    if work_record.attempt_count >= runtime_policy.maximum_attempts then
      next_status := runtime_policy.exhaustion_status;
      failure_reason_value := coalesce(failure_reason_value, 'Approved retry policy is exhausted.');
    else
      next_status := 'retry_wait';
      delay_index := least(work_record.attempt_count, cardinality(runtime_policy.retry_delay_seconds));
      next_available_at := now() + make_interval(secs => runtime_policy.retry_delay_seconds[delay_index]);
    end if;
  elsif failure_category_value = any(runtime_policy.permanent_failure_categories) then
    next_status := runtime_policy.permanent_failure_status;
  else
    next_status := 'needs_review';
    failure_reason_value := coalesce(failure_reason_value,
      'Failure category is not covered by the current backend runtime policy.');
  end if;
  update public.team_color_work_attempts
  set ended_at = now(),
      outcome = case
        when failure_category_value = 'lease_expired' then 'lease_expired'
        when next_status = 'retry_wait' then 'retry'
        else next_status end,
      failure_category = failure_category_value,
      failure_reason = failure_reason_value,
      summary = coalesce(summary_value, '{}'::jsonb)
  where work_item_id = work_record.id
    and attempt_number = work_record.attempt_count and ended_at is null;
  update public.team_color_work_items
  set status = next_status,
      available_at = coalesce(next_available_at, available_at),
      claimed_by_actor_id = null, lease_token = null, lease_expires_at = null,
      failure_category = failure_category_value,
      failure_reason = failure_reason_value,
      outcome_summary = coalesce(summary_value, '{}'::jsonb),
      completed_at = null
  where id = work_record.id;
  insert into public.team_color_work_events(
    work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    work_record.id, work_record.attempt_count, work_record.claimed_by_actor_id,
    next_status, jsonb_build_object(
      'category', failure_category_value,
      'reason', failure_reason_value,
      'available_at', next_available_at,
      'runtime_policy_id', runtime_policy.id,
      'backend_selected_transition', true
    )
  );
  return next_status;
end;
$$;

create or replace function public.report_team_color_work_failure(
  work_item_id_value uuid,
  lease_token_value uuid,
  category_value text,
  reason_value text,
  summary_value jsonb default '{}'::jsonb
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare actor_uuid uuid := public.current_catalog_actor_id(); work_record public.team_color_work_items%rowtype;
begin
  select * into strict work_record from public.team_color_work_items where id = work_item_id_value;
  if not public.has_team_color_capability('team_colors.work.update', work_record.team_id) then
    raise exception 'Team Color work-update capability is required';
  end if;
  if nullif(btrim(category_value), '') is null or nullif(btrim(reason_value), '') is null then
    raise exception 'Structured failure category and reason are required';
  end if;
  return public.transition_team_color_work_by_runtime_policy(
    work_item_id_value, category_value, reason_value, summary_value,
    true, actor_uuid, lease_token_value
  );
end;
$$;

alter function public.release_team_color_work(uuid,uuid,timestamptz,text,text)
rename to release_team_color_work_pre_backend_retry_policy;
revoke all on function public.release_team_color_work_pre_backend_retry_policy(uuid,uuid,timestamptz,text,text)
from public, anon, authenticated;

create or replace function public.release_team_color_work(
  work_item_id_value uuid,
  lease_token_value uuid,
  retry_at_value timestamptz default null,
  category_value text default null,
  reason_value text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if retry_at_value is not null then
    perform public.report_team_color_work_failure(
      work_item_id_value, lease_token_value,
      coalesce(nullif(category_value, ''), 'unclassified_failure'),
      coalesce(nullif(reason_value, ''), 'Worker reported a failure.'), '{}'::jsonb
    );
  else
    perform public.release_team_color_work_pre_backend_retry_policy(
      work_item_id_value, lease_token_value, null, category_value, reason_value
    );
  end if;
end;
$$;

alter function public.finish_team_color_work(uuid,uuid,text,text,text,timestamptz,jsonb)
rename to finish_team_color_work_pre_independent_verification;
revoke all on function public.finish_team_color_work_pre_independent_verification(uuid,uuid,text,text,text,timestamptz,jsonb)
from public, anon, authenticated;

create or replace function public.finish_team_color_work(
  work_item_id_value uuid,
  lease_token_value uuid,
  outcome_value text,
  category_value text default null,
  reason_value text default null,
  retry_at_value timestamptz default null,
  summary_value jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  work_record public.team_color_work_items%rowtype;
  current_color public.team_color_versions%rowtype;
  proposal_uuid uuid;
begin
  if outcome_value in ('retry','failed') then
    perform public.report_team_color_work_failure(
      work_item_id_value, lease_token_value,
      coalesce(nullif(category_value, ''), 'unclassified_failure'),
      coalesce(nullif(reason_value, ''), 'Worker reported a failure.'), summary_value
    );
    return;
  end if;
  if retry_at_value is not null then
    raise exception 'Caller-selected retry timestamps are not accepted';
  end if;
  if outcome_value = 'no_change' then
    select * into strict work_record
    from public.team_color_work_items where id = work_item_id_value;
    if work_record.proposal_id is null then
      select * into strict current_color from public.team_color_versions
      where team_id = work_record.team_id and is_current;
      proposal_uuid := public.submit_team_color_proposal(
        work_item_id_value, lease_token_value,
        jsonb_build_object(
          'primary', current_color.primary_color,
          'secondary', current_color.secondary_color,
          'tertiary', current_color.tertiary_color,
          'quaternary', current_color.quaternary_color,
          'quinary', current_color.quinary_color,
          'effective_from', current_color.effective_from,
          'effective_from_precision', current_color.effective_from_precision
        ),
        coalesce(nullif(reason_value, ''), 'Specialist reports the verified palette remains current.')
      );
    end if;
    perform public.finish_team_color_work_pre_independent_verification(
      work_item_id_value, lease_token_value, 'submitted_for_verification',
      category_value, reason_value, null, summary_value
    );
    return;
  end if;
  perform public.finish_team_color_work_pre_independent_verification(
    work_item_id_value, lease_token_value, outcome_value,
    category_value, reason_value, null, summary_value
  );
end;
$$;

-- Extend the existing decision guard with the new no-change revalidation kind.
-- All prior governance, payload, expected-version, and venue checks are retained.
create or replace function public.enforce_catalog_verification_policy_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  proposal_record public.catalog_change_proposals%rowtype;
  policy_record public.verification_policies%rowtype;
  current_color public.team_color_versions%rowtype;
  minimum_high_trust_count integer;
  high_trust_count integer;
  color_key text;
begin
  if new.decision <> 'approved' then return new; end if;
  select * into strict proposal_record
  from public.catalog_change_proposals where id = new.proposal_id;
  select * into strict policy_record
  from public.verification_policies where id = new.policy_id;
  minimum_high_trust_count := coalesce(
    (policy_record.configuration ->> 'minimum_tier_1_or_2_evidence_count')::integer, 0
  );

  if proposal_record.fact_type = 'team_colors' then
    if new.authoritative_result_payload is null then
      raise exception 'Team Color decisions require the deterministically resolved authoritative payload';
    end if;
    if not exists (
      select 1
      from public.catalog_verifier_results verifier_result
      join public.catalog_verification_work_items verification_work
        on verification_work.id = verifier_result.verification_work_item_id
      where verification_work.specialist_result_kind = 'catalog_proposal'
        and verification_work.specialist_result_id = proposal_record.id
        and verification_work.verification_policy_id = new.policy_id
        and verification_work.status = 'result_submitted'
        and verification_work.accepted_result_id = verifier_result.id
        and verifier_result.verifier_actor_id = new.decided_by_actor_id
        and new.verification_resolution_snapshot ->> 'resolving_verifier_result_id' = verifier_result.id::text
    ) then
      raise exception 'Team Color decisions require a durable blinded verifier result awaiting deterministic finalization';
    end if;
    if proposal_record.team_color_work_item_id is null
       or proposal_record.team_color_change_kind is null
       or nullif(btrim(proposal_record.proposal_reason), '') is null then
      raise exception 'Team Color approval requires autonomous-work safety metadata';
    end if;
    if not exists (
      select 1 from public.team_color_work_items work
      where work.id = proposal_record.team_color_work_item_id
        and work.proposal_id = proposal_record.id
        and work.status = 'pending_verification'
    ) then
      raise exception 'Team Color work must be submitted for verification before approval';
    end if;
    if proposal_record.proposed_by_actor_id = new.decided_by_actor_id then
      raise exception 'Team Color proposal builder and verifier must be different actors';
    end if;
    select * into current_color from public.team_color_versions
    where team_id = proposal_record.target_team_id and is_current for update;
    if current_color.id is distinct from proposal_record.expected_current_color_version_id then
      raise exception 'The current team-color version changed after research began';
    end if;
    if proposal_record.team_color_change_kind = 'verified_replacement' then
      if not found or current_color.record_status <> 'verified'
         or proposal_record.recheck_trigger is null
         or proposal_record.operation <> 'replace' then
        raise exception 'Verified replacement requires the expected verified version and a recheck trigger';
      end if;
    elsif proposal_record.team_color_change_kind = 'no_change_recheck' then
      if not found or current_color.record_status <> 'verified'
         or proposal_record.recheck_trigger is null
         or proposal_record.operation <> 'revalidate' then
        raise exception 'No-change revalidation requires its expected verified version and recheck trigger';
      end if;
      if new.verification_resolution_snapshot ->> 'finalization_outcome' = 'confirmed_no_change'
         and public.team_color_palette_from_payload(new.authoritative_result_payload) <>
             public.team_color_palette_from_payload(jsonb_build_object(
               'primary', current_color.primary_color,
               'secondary', current_color.secondary_color,
               'tertiary', current_color.tertiary_color,
               'quaternary', current_color.quaternary_color,
               'quinary', current_color.quinary_color
             )) then
        raise exception 'Confirmed no-change adjudication must preserve the expected verified palette';
      elsif new.verification_resolution_snapshot ->> 'finalization_outcome' not in (
        'confirmed_no_change','promoted'
      ) then
        raise exception 'No-change revalidation requires an explicit deterministic finalization outcome';
      end if;
    elsif found and current_color.record_status = 'verified' then
      raise exception 'A fill proposal cannot replace verified team colors';
    end if;
    foreach color_key in array array['primary','secondary'] loop
      if coalesce(new.authoritative_result_payload ->> color_key, '') !~ '^#[0-9A-F]{6}$' then
        raise exception 'Team color % must be uppercase six-digit HEX (#RRGGBB)', color_key;
      end if;
    end loop;
    foreach color_key in array array['tertiary','quaternary','quinary'] loop
      if nullif(new.authoritative_result_payload ->> color_key, '') is not null
         and new.authoritative_result_payload ->> color_key !~ '^#[0-9A-F]{6}$' then
        raise exception 'Team color % must be uppercase six-digit HEX (#RRGGBB)', color_key;
      end if;
    end loop;
    select coalesce(jsonb_agg(jsonb_build_object(
      'evidence_id', evidence.id,
      'source_id', source.source_id,
      'source_display_name', source.display_name,
      'source_review_status', source.review_status,
      'independence_group_id', source_group.group_id,
      'independence_assignment_id', evidence.source_independence_assignment_id,
      'evidence_url', evidence.evidence_url,
      'url_scope_version_id', evidence.source_url_scope_version_id,
      'evidence_summary', evidence.evidence_summary,
      'structured_claim', evidence.structured_claim,
      'observed_at', evidence.observed_at,
      'evidence_created_at', evidence.created_at,
      'supports_proposal', evidence.supports_proposal,
      'trust_tier_version_id', evidence.source_trust_assignment_id,
      'trust_tier', trust.trust_tier,
      'trust_effective_from', trust.effective_from,
      'trust_notes', trust.notes,
      'applicability_version_id', evidence.source_applicability_version_id,
      'applicability_kind', applicability.applicability_kind,
      'applicability_scope', jsonb_build_object(
        'sport_id', applicability_sport.sport_id,
        'league_id', applicability_league.league_id,
        'team_id', applicability_team.team_id
      ),
      'applicability_notes', applicability.notes
    ) order by evidence.created_at, evidence.id), '[]'::jsonb)
    into new.evidence_snapshot
    from public.catalog_proposal_evidence evidence
    join public.trusted_sources source on source.id = evidence.source_id
    join public.source_trust_assignments trust
      on trust.id = evidence.source_trust_assignment_id
    join public.source_applicability_versions applicability
      on applicability.id = evidence.source_applicability_version_id
    join public.source_independence_group_assignment_versions independence
      on independence.id = evidence.source_independence_assignment_id
    join public.source_independence_groups source_group
      on source_group.id = independence.independence_group_id
    left join public.catalog_sports applicability_sport on applicability_sport.id = applicability.sport_id
    left join public.catalog_leagues applicability_league on applicability_league.id = applicability.league_id
    left join public.catalog_teams applicability_team on applicability_team.id = applicability.team_id
    where evidence.proposal_id = proposal_record.id;
  elsif minimum_high_trust_count > 0 then
    select count(distinct evidence.id) into high_trust_count
    from public.catalog_proposal_evidence evidence
    join public.source_trust_assignments trust
      on trust.id = evidence.source_trust_assignment_id and trust.is_current
    where evidence.proposal_id = proposal_record.id
      and evidence.supports_proposal and trust.trust_tier in (1,2);
    if high_trust_count < minimum_high_trust_count then
      raise exception 'Policy requires at least % Tier 1 or Tier 2 evidence row(s)',
        minimum_high_trust_count;
    end if;
  end if;

  if proposal_record.fact_type = 'team_venue_relationship'
     and policy_record.configuration ->> 'relationship_type' = 'primary'
     and proposal_record.payload ->> 'relationship_type' <> 'primary' then
    raise exception 'The active team venue policy applies only to primary venue relationships';
  end if;
  if proposal_record.fact_type = 'venue_mapping' then
    if proposal_record.proposed_by_actor_id = new.decided_by_actor_id then
      raise exception 'Venue mapping builder and verifier must be different actors';
    end if;
    if not public.has_catalog_capability(
      'venue.mapping.verify', null, null, null, proposal_record.target_venue_id
    ) then
      raise exception 'venue.mapping.verify capability is required';
    end if;
  end if;
  new.policy_snapshot := new.policy_snapshot || jsonb_build_object(
    'minimum_tier_1_or_2_evidence_count', minimum_high_trust_count,
    'required_verifier_capability', policy_record.configuration ->> 'required_verifier_capability',
    'trust_tier_rubric', policy_record.configuration -> 'trust_tier_rubric',
    'independent_trust_and_applicability_versions', true,
    'durable_independent_verifier_result_required', proposal_record.fact_type = 'team_colors',
    'single_authoritative_finalization_path', proposal_record.fact_type = 'team_colors'
  );
  return new;
end;
$$;

-- Every new Team Color decision must prove information-lineage independence in
-- addition to publisher ownership independence. Historical decisions are not
-- revisited or rewritten.
create or replace function public.enforce_team_color_information_lineage_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  proposal_record public.catalog_change_proposals%rowtype;
  policy_record public.verification_policies%rowtype;
  lineage_count integer;
begin
  if new.decision <> 'approved' then return new; end if;
  select * into strict proposal_record
  from public.catalog_change_proposals where id = new.proposal_id;
  if proposal_record.fact_type <> 'team_colors' then return new; end if;
  select * into strict policy_record
  from public.verification_policies where id = new.policy_id;
  select count(distinct qualifying.lineage_root) into lineage_count
  from (
    select public.current_information_lineage_root(coalesce(
             evidence.information_lineage_version_id,
             lineage_assignment.information_lineage_version_id
           )) as lineage_root
    from public.catalog_proposal_evidence evidence
    left join public.catalog_evidence_lineage_assignments lineage_assignment
      on lineage_assignment.evidence_kind = 'proposal_evidence'
     and lineage_assignment.evidence_id = evidence.id and lineage_assignment.is_current
    where evidence.proposal_id = proposal_record.id
      and evidence.supports_proposal
      and evidence.structured_claim ->> 'classification' = 'current_canonical'
      and evidence.structured_claim -> 'palette' =
          public.team_color_palette_from_payload(new.authoritative_result_payload)
    union all
    select public.current_information_lineage_root(coalesce(
             evidence.information_lineage_version_id,
             lineage_assignment.information_lineage_version_id
           )) as lineage_root
    from public.catalog_verifier_evidence evidence
    join public.catalog_verification_work_items work
      on work.id = evidence.verification_work_item_id
    left join public.catalog_evidence_lineage_assignments lineage_assignment
      on lineage_assignment.evidence_kind = 'verifier_evidence'
     and lineage_assignment.evidence_id = evidence.id and lineage_assignment.is_current
    where work.specialist_result_kind = 'catalog_proposal'
      and work.specialist_result_id = proposal_record.id
      and evidence.structured_claim ->> 'classification' = 'current_canonical'
      and evidence.structured_claim -> 'palette' =
          public.team_color_palette_from_payload(new.authoritative_result_payload)
  ) qualifying
  where qualifying.lineage_root is not null;
  if policy_record.require_independent_sources
     and lineage_count < policy_record.minimum_evidence_count then
    raise exception 'Proposal does not have enough independently reviewed information lineages';
  end if;
  select coalesce(jsonb_agg(
    snapshot_item || jsonb_build_object(
      'information_lineage_version_id', evidence.information_lineage_version_id,
      'resolved_information_lineage_id', public.current_information_lineage_root(evidence.information_lineage_version_id),
      'information_lineage_basis', evidence.information_lineage_basis,
      'information_lineage_status', case when evidence.information_lineage_version_id is null then 'unknown' else 'known' end
    ) order by snapshot_ordinality
  ), '[]'::jsonb)
  into new.evidence_snapshot
  from jsonb_array_elements(new.evidence_snapshot) with ordinality snapshot(snapshot_item, snapshot_ordinality)
  left join public.catalog_proposal_evidence evidence
    on evidence.id = (snapshot_item ->> 'evidence_id')::uuid;
  new.policy_snapshot := new.policy_snapshot || jsonb_build_object(
    'require_independent_information_lineages', policy_record.require_independent_sources,
    'information_lineage_count', lineage_count
  );
  new.verification_resolution_snapshot := new.verification_resolution_snapshot || jsonb_build_object(
    'verifier_results', coalesce((
      select jsonb_agg(jsonb_build_object(
        'verification_work_item_id', work.id,
        'verification_round', work.verification_round,
        'verifier_result_id', verifier_result.id,
        'verifier_actor_id', verifier_result.verifier_actor_id,
        'result_kind', verifier_result.result_kind,
        'result_payload', verifier_result.result_payload,
        'evidence_snapshot', verifier_result.evidence_snapshot,
        'submitted_at', verifier_result.submitted_at
      ) order by work.verification_round)
      from public.catalog_verification_work_items work
      join public.catalog_verifier_results verifier_result
        on verifier_result.verification_work_item_id = work.id
      where work.specialist_result_kind = 'catalog_proposal'
        and work.specialist_result_id = proposal_record.id
    ), '[]'::jsonb)
  );
  return new;
end;
$$;

create trigger zz_enforce_team_color_information_lineage_decision
before insert on public.catalog_verification_decisions
for each row execute function public.enforce_team_color_information_lineage_decision();

create or replace function public.admin_create_agent_job_runtime_policy(
  policy_key_value text,
  version_value integer,
  job_type_value text,
  lease_seconds_value integer,
  retryable_failure_categories_value text[],
  permanent_failure_categories_value text[],
  retry_delay_seconds_value integer[],
  maximum_attempts_value integer,
  exhaustion_status_value text,
  permanent_failure_status_value text,
  configuration_value jsonb default '{}'::jsonb,
  activate_value boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare actor_uuid uuid := public.current_catalog_actor_id(); result_uuid uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null) then
    raise exception 'Administrator access is required to configure agent runtime policy';
  end if;
  if activate_value then
    update public.agent_job_runtime_policies
    set is_current = false, active = false, superseded_at = now()
    where job_type = job_type_value and is_current and active;
  end if;
  insert into public.agent_job_runtime_policies(
    policy_key, version, job_type, lease_seconds,
    retryable_failure_categories, permanent_failure_categories,
    retry_delay_seconds, maximum_attempts, exhaustion_status,
    permanent_failure_status, configuration, active, is_current,
    created_by_actor_id
  ) values (
    policy_key_value, version_value, job_type_value, lease_seconds_value,
    coalesce(retryable_failure_categories_value, '{}'::text[]),
    coalesce(permanent_failure_categories_value, '{}'::text[]),
    coalesce(retry_delay_seconds_value, '{}'::integer[]), maximum_attempts_value,
    exhaustion_status_value, permanent_failure_status_value,
    coalesce(configuration_value, '{}'::jsonb), activate_value, activate_value,
    actor_uuid
  ) returning id into result_uuid;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'agent_runtime_policy.created', 'agent_job_runtime_policy',
    result_uuid::text, jsonb_build_object(
      'policy_key', policy_key_value, 'version', version_value,
      'job_type', job_type_value, 'activated', activate_value
    )
  );
  return result_uuid;
end;
$$;

create or replace function public.admin_create_catalog_revalidation_policy(
  policy_key_value text,
  version_value integer,
  data_type_value text,
  review_cadence_value interval,
  configuration_value jsonb default '{}'::jsonb,
  activate_value boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare actor_uuid uuid := public.current_catalog_actor_id(); result_uuid uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null) then
    raise exception 'Administrator access is required to configure revalidation policy';
  end if;
  if activate_value then
    update public.catalog_revalidation_policies
    set is_current = false, active = false, superseded_at = now()
    where data_type = data_type_value and is_current and active;
  end if;
  insert into public.catalog_revalidation_policies(
    policy_key, version, data_type, review_cadence, configuration,
    active, is_current, created_by_actor_id
  ) values (
    policy_key_value, version_value, data_type_value, review_cadence_value,
    coalesce(configuration_value, '{}'::jsonb), activate_value, activate_value,
    actor_uuid
  ) returning id into result_uuid;
  update public.catalog_fact_revalidation_state state
  set cadence_policy_id = result_uuid,
      next_review_at = state.last_verified_at + review_cadence_value,
      updated_at = now()
  where state.data_type = data_type_value;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'revalidation_policy.created', 'catalog_revalidation_policy',
    result_uuid::text, jsonb_build_object(
      'policy_key', policy_key_value, 'version', version_value,
      'data_type', data_type_value, 'activated', activate_value
    )
  );
  return result_uuid;
end;
$$;

create or replace function public.record_team_color_revalidation_state(
  team_uuid uuid,
  fact_version_uuid uuid,
  decision_uuid uuid,
  outcome_value text,
  trigger_value text,
  reason_value text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare policy_record public.catalog_revalidation_policies%rowtype;
begin
  select * into policy_record from public.catalog_revalidation_policies
  where data_type = 'team_colors' and is_current and active;
  insert into public.catalog_fact_revalidation_state(
    data_type, subject_type, subject_id, subject_reference,
    current_fact_version_id, cadence_policy_id,
    last_verified_at, next_review_at, last_review_trigger, last_review_reason,
    last_review_outcome, last_verification_decision_id,
    active_job_type, active_job_id
  ) values (
    'team_colors', 'catalog_team', team_uuid::text,
    jsonb_build_object('team_uuid', team_uuid), fact_version_uuid, policy_record.id,
    now(), case when policy_record.id is null then null else now() + policy_record.review_cadence end,
    trigger_value, reason_value, outcome_value, decision_uuid, null, null
  )
  on conflict (data_type, subject_type, subject_id) do update
  set current_fact_version_id = excluded.current_fact_version_id,
      cadence_policy_id = excluded.cadence_policy_id,
      last_verified_at = excluded.last_verified_at,
      next_review_at = excluded.next_review_at,
      last_review_trigger = excluded.last_review_trigger,
      last_review_reason = excluded.last_review_reason,
      last_review_outcome = excluded.last_review_outcome,
      last_verification_decision_id = excluded.last_verification_decision_id,
      active_job_type = null,
      active_job_id = null,
      updated_at = now();
end;
$$;

create or replace function public.sync_team_color_revalidation_on_version()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.is_current and new.record_status = 'verified' then
    perform public.record_team_color_revalidation_state(
      new.team_id, new.id, new.verification_decision_id,
      'verified_replacement', null, 'A new verified Team Color version was promoted.'
    );
  end if;
  return new;
end;
$$;

create trigger sync_team_color_revalidation_on_version
after insert on public.team_color_versions
for each row execute function public.sync_team_color_revalidation_on_version();

create or replace function public.enqueue_team_color_revalidation(
  revalidation_state_uuid uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  state_record public.catalog_fact_revalidation_state%rowtype;
  team_uuid uuid;
  actor_uuid uuid := public.current_catalog_actor_id();
  work_uuid uuid;
begin
  select * into strict state_record from public.catalog_fact_revalidation_state
  where id = revalidation_state_uuid for update;
  if state_record.data_type <> 'team_colors'
     or state_record.subject_type <> 'catalog_team' then
    raise exception 'Team Color revalidation adapter received a different subject';
  end if;
  team_uuid := state_record.subject_id::uuid;
  select work.id into work_uuid from public.team_color_work_items work
  where work.team_id = team_uuid
    and work.status in ('queued','claimed','retry_wait','pending_verification','blocked','needs_review')
  order by work.created_at, work.id limit 1;
  if work_uuid is null then
    insert into public.team_color_work_items(
      team_id, work_kind, recheck_trigger, request_reason,
      expected_current_color_version_id, created_by_actor_id, created_by_auth_user_id
    ) values (
      team_uuid, 'verified_recheck', 'scheduled_review',
      'The current Team Color cadence policy made this verified palette due for revalidation.',
      state_record.current_fact_version_id, actor_uuid, auth.uid()
    ) returning id into work_uuid;
    insert into public.team_color_work_events(work_item_id, actor_id, event_type, details)
    values (work_uuid, actor_uuid, 'queued', jsonb_build_object(
      'work_kind', 'verified_recheck', 'recheck_trigger', 'scheduled_review',
      'cadence_policy_id', state_record.cadence_policy_id,
      'generic_revalidation_state_id', state_record.id
    ));
  end if;
  update public.catalog_fact_revalidation_state
  set active_job_type = 'team_color_specialist', active_job_id = work_uuid,
      last_review_trigger = 'scheduled_review',
      last_review_reason = 'Domain cadence made this fact due.', updated_at = now()
  where id = state_record.id;
  return work_uuid;
end;
$$;

create or replace function public.enqueue_due_catalog_revalidations(
  data_type_value text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  adapter_record public.catalog_domain_adapters%rowtype;
  due record;
  inserted_count integer := 0;
  work_uuid uuid;
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
     and not public.has_catalog_capability('catalog.revalidation.schedule') then
    raise exception 'Catalog revalidation scheduling capability is required';
  end if;
  select * into strict adapter_record from public.catalog_domain_adapters
  where data_type = data_type_value and active
    and enqueue_revalidation_function is not null;
  for due in
    select state.* from public.catalog_fact_revalidation_state state
    join public.catalog_revalidation_policies policy
      on policy.id = state.cadence_policy_id and policy.is_current and policy.active
    where state.data_type = data_type_value
      and state.next_review_at is not null and state.next_review_at <= now()
      and state.active_job_id is null
    order by state.next_review_at, state.id
    for update of state skip locked
  loop
    execute format('select %s($1)', adapter_record.enqueue_revalidation_function::regproc)
      using due.id into work_uuid;
    if work_uuid is not null then
      inserted_count := inserted_count + 1;
    end if;
  end loop;
  return inserted_count;
end;
$$;

create or replace function public.transition_catalog_verification_by_runtime_policy(
  verification_work_item_uuid uuid,
  failure_category_value text,
  failure_reason_value text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  work_record public.catalog_verification_work_items%rowtype;
  runtime_policy public.agent_job_runtime_policies%rowtype;
  next_status text;
  next_available_at timestamptz;
  delay_index integer;
begin
  select * into strict work_record
  from public.catalog_verification_work_items where id = verification_work_item_uuid for update;
  if work_record.status <> 'claimed' then raise exception 'Only claimed verification work may transition by failure policy'; end if;
  select * into runtime_policy
  from public.current_agent_job_runtime_policy('catalog_verifier.' || work_record.data_type);
  if not found then
    next_status := 'needs_review';
    failure_category_value := 'retry_policy_unconfigured';
    failure_reason_value := coalesce(failure_reason_value,
      'Verifier runtime retry policy is not configured.');
  elsif failure_category_value = any(runtime_policy.retryable_failure_categories) then
    if work_record.attempt_count >= runtime_policy.maximum_attempts then
      next_status := runtime_policy.exhaustion_status;
    else
      next_status := 'retry_wait';
      delay_index := least(work_record.attempt_count, cardinality(runtime_policy.retry_delay_seconds));
      next_available_at := now() + make_interval(secs => runtime_policy.retry_delay_seconds[delay_index]);
    end if;
  elsif failure_category_value = any(runtime_policy.permanent_failure_categories) then
    next_status := runtime_policy.permanent_failure_status;
  else
    next_status := 'needs_review';
    failure_reason_value := coalesce(failure_reason_value,
      'Failure category is not covered by the current verifier runtime policy.');
  end if;
  update public.catalog_verification_attempts
  set ended_at = now(),
      outcome = case
        when failure_category_value = 'lease_expired' then 'lease_expired'
        when next_status = 'retry_wait' then 'retry'
        else next_status end,
      failure_category = failure_category_value,
      failure_reason = failure_reason_value
  where verification_work_item_id = work_record.id
    and attempt_number = work_record.attempt_count and ended_at is null;
  update public.catalog_verification_work_items
  set status = next_status,
      available_at = coalesce(next_available_at, available_at),
      claimed_by_actor_id = null, lease_token = null, lease_expires_at = null,
      failure_category = failure_category_value,
      failure_reason = failure_reason_value
  where id = work_record.id;
  if next_status in ('needs_review','failed') and work_record.originating_job_type = 'team_color_specialist' then
    update public.team_color_work_items
    set status = 'needs_review', failure_category = failure_category_value,
        failure_reason = failure_reason_value
    where id = work_record.originating_job_id and status = 'pending_verification';
  end if;
  insert into public.catalog_verification_work_events(
    verification_work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    work_record.id, work_record.attempt_count, work_record.claimed_by_actor_id,
    next_status, jsonb_build_object(
      'category', failure_category_value, 'reason', failure_reason_value,
      'available_at', next_available_at, 'runtime_policy_id', runtime_policy.id,
      'backend_selected_transition', true
    )
  );
  return next_status;
end;
$$;

create or replace function public.report_catalog_verification_failure(
  verification_work_item_uuid uuid,
  lease_token_value uuid,
  category_value text,
  reason_value text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare actor_uuid uuid := public.current_catalog_actor_id(); work_record public.catalog_verification_work_items%rowtype;
begin
  select * into strict work_record
  from public.catalog_verification_work_items where id = verification_work_item_uuid;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now() then
    raise exception 'An unexpired verification lease owned by this actor is required';
  end if;
  if not public.has_catalog_verification_capability(
    work_record.data_type, work_record.capability_scope
  ) then
    raise exception 'Scoped catalog verification capability is required';
  end if;
  if nullif(btrim(category_value), '') is null or nullif(btrim(reason_value), '') is null then
    raise exception 'Structured failure category and reason are required';
  end if;
  return public.transition_catalog_verification_by_runtime_policy(
    verification_work_item_uuid, category_value, reason_value
  );
end;
$$;

create or replace function public.expire_team_color_work_leases()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare expired record; expired_count integer := 0;
begin
  for expired in
    select id from public.team_color_work_items
    where status = 'claimed' and lease_expires_at <= now()
    for update skip locked
  loop
    perform public.transition_team_color_work_by_runtime_policy(
      expired.id, 'lease_expired',
      'The agent lease expired before the work was finished.', '{}'::jsonb,
      false, null, null
    );
    expired_count := expired_count + 1;
  end loop;
  return expired_count;
end;
$$;

create or replace function public.expire_catalog_verification_work_leases()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare expired record; expired_count integer := 0;
begin
  for expired in
    select id from public.catalog_verification_work_items
    where status = 'claimed' and lease_expires_at <= now()
    for update skip locked
  loop
    perform public.transition_catalog_verification_by_runtime_policy(
      expired.id, 'lease_expired',
      'The verifier lease expired before a result was submitted.'
    );
    expired_count := expired_count + 1;
  end loop;
  return expired_count;
end;
$$;

create or replace function public.get_agent_work_wakes(
  limit_value integer,
  queue_name_value text default null
)
returns table (
  wake_id uuid,
  queue_name text,
  work_item_id uuid,
  event_kind text,
  available_at timestamptz,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
     and not public.has_catalog_capability('agent.orchestration.read') then
    raise exception 'Agent orchestration-read capability is required';
  end if;
  if limit_value is null or limit_value <= 0 then
    raise exception 'An explicitly approved positive wake-read limit is required';
  end if;
  return query
  select wake.id, wake.queue_name, wake.work_item_id, wake.event_kind,
         wake.available_at, wake.created_at
  from public.agent_work_wake_outbox wake
  where wake.status = 'pending' and wake.available_at <= now()
    and (queue_name_value is null or wake.queue_name = queue_name_value)
  order by wake.available_at, wake.created_at, wake.id
  limit limit_value;
end;
$$;

create or replace function public.acknowledge_agent_work_wake(
  wake_uuid uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare actor_uuid uuid := public.current_catalog_actor_id();
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
     and not public.has_catalog_capability('agent.orchestration.update') then
    raise exception 'Agent orchestration-update capability is required';
  end if;
  update public.agent_work_wake_outbox
  set status = 'acknowledged', acknowledged_at = now(),
      acknowledged_by_actor_id = actor_uuid
  where id = wake_uuid and status = 'pending';
end;
$$;

create or replace function public.recover_team_color_domain()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare expired_count integer := 0; repaired_count integer := 0; stranded record;
begin
  expired_count := public.expire_team_color_work_leases();
  for stranded in
    select work.proposal_id
    from public.team_color_work_items work
    join public.catalog_change_proposals proposal on proposal.id = work.proposal_id
    where work.status = 'pending_verification' and proposal.status = 'pending'
      and not exists (
        select 1 from public.catalog_verification_work_items verification
        where verification.specialist_result_kind = 'catalog_proposal'
          and verification.specialist_result_id = work.proposal_id
          and verification.verification_round = 1
      )
    for update of work skip locked
  loop
    perform public.ensure_catalog_verification_work(stranded.proposal_id);
    repaired_count := repaired_count + 1;
  end loop;
  return jsonb_build_object(
    'expired_specialist_leases', expired_count,
    'verification_jobs_repaired', repaired_count
  );
end;
$$;

create or replace function public.reconcile_team_color_wakes()
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
  select 'team_color_specialist', work.id, 'work_ready',
         work.status || ':' || extract(epoch from work.available_at)::text,
         work.available_at
  from public.team_color_work_items work
  where work.status in ('queued','retry_wait') and work.available_at <= now()
  on conflict (queue_name, work_item_id, event_kind, eligibility_key)
  do update set status = 'pending', acknowledged_at = null,
                acknowledged_by_actor_id = null;
  get diagnostics reconciled_count = row_count;
  return reconciled_count;
end;
$$;

create or replace function public.transition_information_lineage_resolution_by_runtime_policy(
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
  work_record public.information_lineage_resolution_work_items%rowtype;
  runtime_policy public.agent_job_runtime_policies%rowtype;
  next_status text;
  next_available_at timestamptz;
begin
  select * into strict work_record
  from public.information_lineage_resolution_work_items
  where id = work_item_uuid for update;
  if work_record.status <> 'claimed' then return work_record.status; end if;
  select * into strict runtime_policy
  from public.current_agent_job_runtime_policy(
    'information_lineage_resolver.' || work_record.data_type
  );
  if failure_category_value = any(runtime_policy.permanent_failure_categories) then
    next_status := runtime_policy.permanent_failure_status;
  elsif failure_category_value = any(runtime_policy.retryable_failure_categories)
        and work_record.attempt_count < runtime_policy.maximum_attempts then
    next_status := 'retry_wait';
    next_available_at := now() + make_interval(secs =>
      runtime_policy.retry_delay_seconds[least(
        work_record.attempt_count,
        cardinality(runtime_policy.retry_delay_seconds)
      )]
    );
  elsif failure_category_value = any(runtime_policy.retryable_failure_categories) then
    next_status := runtime_policy.exhaustion_status;
  else
    next_status := 'needs_review';
  end if;
  update public.information_lineage_resolution_attempts
  set ended_at = now(), outcome = case when next_status = 'retry_wait' then 'retry' else next_status end,
      failure_category = failure_category_value, failure_reason = failure_reason_value
  where work_item_id = work_record.id
    and attempt_number = work_record.attempt_count and ended_at is null;
  update public.information_lineage_resolution_work_items
  set status = next_status,
      available_at = coalesce(next_available_at, available_at),
      claimed_by_actor_id = null, lease_token = null, lease_expires_at = null,
      failure_category = failure_category_value,
      failure_reason = failure_reason_value,
      completed_at = case when next_status in ('failed','cancelled') then now() else null end,
      updated_at = now()
  where id = work_record.id;
  if next_status = 'retry_wait' then
    perform public.emit_agent_work_wake(
      'information_lineage_resolver.' || work_record.data_type,
      work_record.id, 'work_ready', next_available_at,
      next_status || ':' || extract(epoch from next_available_at)::text
    );
  end if;
  return next_status;
end;
$$;

create or replace function public.expire_information_lineage_resolution_work_leases()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare expired record; expired_count integer := 0;
begin
  for expired in
    select work.id
    from public.information_lineage_resolution_work_items work
    where work.status = 'claimed' and work.lease_expires_at <= now()
    for update skip locked
  loop
    perform public.transition_information_lineage_resolution_by_runtime_policy(
      expired.id, 'lease_expired', 'Information-lineage resolver lease expired.'
    );
    expired_count := expired_count + 1;
  end loop;
  return expired_count;
end;
$$;

create or replace function public.reconcile_information_lineage_resolution_wakes()
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
  select 'information_lineage_resolver.' || work.data_type,
         work.id, 'work_ready',
         work.status || ':' || extract(epoch from work.available_at)::text,
         work.available_at
  from public.information_lineage_resolution_work_items work
  where work.status in ('queued','retry_wait') and work.available_at <= now()
  on conflict (queue_name, work_item_id, event_kind, eligibility_key)
  do update set status = 'pending', acknowledged_at = null,
                acknowledged_by_actor_id = null;
  get diagnostics reconciled_count = row_count;
  return reconciled_count;
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
      'wakes_reconciled', wakes_reconciled
    )
  );
  return jsonb_build_object(
    'status', 'completed',
    'verifier_expired', verifier_expired,
    'lineage_expired', lineage_expired,
    'domain_recovery', domain_recovery,
    'comparisons_processed', comparisons_processed,
    'wakes_reconciled', wakes_reconciled
  );
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
  data_type_value text;
  adapter_record public.catalog_domain_adapters%rowtype;
  outcome_value text;
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
     and not public.has_catalog_capability('agent.comparison.run')
     and not public.has_catalog_capability('agent.watchdog.run') then
    raise exception 'Agent comparison-run capability is required';
  end if;
  select work.data_type into strict data_type_value
  from public.catalog_verifier_results result
  join public.catalog_verification_work_items work
    on work.id = result.verification_work_item_id
  where result.id = verifier_result_uuid;
  select * into strict adapter_record from public.catalog_domain_adapters
  where data_type = data_type_value and active;
  execute format('select %s($1)', adapter_record.compare_result_function::regproc)
    using verifier_result_uuid into outcome_value;
  return outcome_value;
end;
$$;

create or replace function public.admin_register_catalog_domain_adapter(
  data_type_value text,
  subject_type_value text,
  specialist_job_type_value text,
  verification_job_type_value text,
  verification_capability_value text,
  build_verifier_context_function_value regproc,
  compare_result_function_value regproc,
  finalize_authoritative_function_value regproc,
  enqueue_revalidation_function_value regproc default null,
  recover_domain_function_value regproc default null,
  reconcile_wakes_function_value regproc default null,
  configuration_value jsonb default '{}'::jsonb,
  active_value boolean default true
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare actor_uuid uuid := public.current_catalog_actor_id();
begin
  if not public.has_staff_access(array['admin']::text[], null) then
    raise exception 'Administrator access is required to register a catalog domain adapter';
  end if;
  insert into public.catalog_domain_adapters(
    data_type, subject_type, specialist_job_type, verification_job_type,
    verification_capability, build_verifier_context_function,
    compare_result_function, finalize_authoritative_function,
    enqueue_revalidation_function, recover_domain_function,
    reconcile_wakes_function, configuration, active
  ) values (
    data_type_value, subject_type_value, specialist_job_type_value,
    verification_job_type_value, verification_capability_value,
    build_verifier_context_function_value, compare_result_function_value,
    finalize_authoritative_function_value, enqueue_revalidation_function_value,
    recover_domain_function_value, reconcile_wakes_function_value,
    coalesce(configuration_value, '{}'::jsonb), active_value
  )
  on conflict (data_type) do update set
    subject_type = excluded.subject_type,
    specialist_job_type = excluded.specialist_job_type,
    verification_job_type = excluded.verification_job_type,
    verification_capability = excluded.verification_capability,
    build_verifier_context_function = excluded.build_verifier_context_function,
    compare_result_function = excluded.compare_result_function,
    finalize_authoritative_function = excluded.finalize_authoritative_function,
    enqueue_revalidation_function = excluded.enqueue_revalidation_function,
    recover_domain_function = excluded.recover_domain_function,
    reconcile_wakes_function = excluded.reconcile_wakes_function,
    configuration = excluded.configuration,
    active = excluded.active,
    updated_at = now();
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'catalog_domain_adapter.registered',
    'catalog_domain_adapter', data_type_value,
    jsonb_build_object(
      'subject_type', subject_type_value,
      'verification_job_type', verification_job_type_value,
      'verification_capability', verification_capability_value,
      'active', active_value
    )
  );
  return data_type_value;
end;
$$;

insert into public.catalog_domain_adapters(
  data_type, subject_type, specialist_job_type, verification_job_type,
  verification_capability, build_verifier_context_function,
  compare_result_function, finalize_authoritative_function,
  enqueue_revalidation_function, recover_domain_function,
  reconcile_wakes_function, configuration
) values (
  'team_colors', 'catalog_team', 'team_color_specialist',
  'catalog_verifier.team_colors', 'catalog.verify.team_colors',
  'public.build_team_color_verifier_context'::regproc,
  'public.compare_team_color_verifier_result'::regproc,
  'public.finalize_team_color_authoritative_result'::regproc,
  'public.enqueue_team_color_revalidation'::regproc,
  'public.recover_team_color_domain'::regproc,
  'public.reconcile_team_color_wakes'::regproc,
  jsonb_build_object('authoritative_version_table', 'team_color_versions')
);

do $$
declare pending_proposal uuid;
begin
  for pending_proposal in
    select work.proposal_id
    from public.team_color_work_items work
    join public.catalog_change_proposals proposal on proposal.id = work.proposal_id
    where work.status = 'pending_verification' and proposal.status = 'pending'
  loop
    perform public.ensure_catalog_verification_work(pending_proposal);
  end loop;
end;
$$;

create or replace function public.enqueue_information_lineage_resolution_work(
  evidence_kind_value text,
  evidence_uuid uuid,
  data_type_value text,
  subject_type_value text,
  subject_id_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare result_uuid uuid;
begin
  insert into public.information_lineage_resolution_work_items(
    data_type, evidence_kind, evidence_id, subject_type, subject_id
  ) values (
    data_type_value, evidence_kind_value, evidence_uuid,
    subject_type_value, subject_id_value
  )
  on conflict (evidence_kind, evidence_id) do update set evidence_id = excluded.evidence_id
  returning id into result_uuid;
  perform public.emit_agent_work_wake(
    'information_lineage_resolver.' || data_type_value,
    result_uuid, 'lineage_resolution_ready', now(), 'queued'
  );
  return result_uuid;
end;
$$;

create or replace function public.enqueue_unknown_proposal_evidence_lineage()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare proposal_record public.catalog_change_proposals%rowtype;
begin
  if new.information_lineage_version_id is not null then return new; end if;
  select * into strict proposal_record from public.catalog_change_proposals
  where id = new.proposal_id;
  perform public.enqueue_information_lineage_resolution_work(
    'proposal_evidence', new.id, proposal_record.fact_type,
    case when proposal_record.target_team_id is not null then 'catalog_team'
         when proposal_record.target_venue_id is not null then 'catalog_venue'
         when proposal_record.target_league_id is not null then 'catalog_league'
         else 'catalog_subject' end,
    coalesce(proposal_record.target_team_id, proposal_record.target_venue_id,
             proposal_record.target_league_id, proposal_record.id)::text
  );
  return new;
end;
$$;

create trigger enqueue_unknown_proposal_evidence_lineage
after insert on public.catalog_proposal_evidence
for each row execute function public.enqueue_unknown_proposal_evidence_lineage();

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
  return new;
end;
$$;

create trigger complete_lineage_resolution_after_governed_assignment
after update of information_lineage_version_id on public.catalog_proposal_evidence
for each row execute function public.complete_lineage_resolution_after_governed_assignment();

create or replace function public.enqueue_unknown_verifier_evidence_lineage()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare work_record public.catalog_verification_work_items%rowtype;
begin
  if new.information_lineage_version_id is not null then return new; end if;
  select * into strict work_record from public.catalog_verification_work_items
  where id = new.verification_work_item_id;
  perform public.enqueue_information_lineage_resolution_work(
    'verifier_evidence', new.id, work_record.data_type,
    work_record.subject_type, work_record.subject_id
  );
  return new;
end;
$$;

create trigger enqueue_unknown_verifier_evidence_lineage
after insert on public.catalog_verifier_evidence
for each row execute function public.enqueue_unknown_verifier_evidence_lineage();

insert into public.information_lineage_resolution_work_items(
  data_type, evidence_kind, evidence_id, subject_type, subject_id
)
select proposal.fact_type, 'proposal_evidence', evidence.id,
       case when proposal.target_team_id is not null then 'catalog_team'
            when proposal.target_venue_id is not null then 'catalog_venue'
            when proposal.target_league_id is not null then 'catalog_league'
            else 'catalog_subject' end,
       coalesce(proposal.target_team_id, proposal.target_venue_id,
                proposal.target_league_id, proposal.id)::text
from public.catalog_proposal_evidence evidence
join public.catalog_change_proposals proposal on proposal.id = evidence.proposal_id
where evidence.information_lineage_version_id is null
on conflict (evidence_kind, evidence_id) do nothing;

create or replace function public.admin_create_information_lineage_resolution_policy(
  policy_key_value text,
  version_value integer,
  data_type_value text,
  automatically_permitted_actions_value text[],
  configuration_value jsonb default '{}'::jsonb,
  activate_value boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare actor_uuid uuid := public.current_catalog_actor_id(); result_uuid uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null) then
    raise exception 'Administrator access is required to configure lineage-resolution policy';
  end if;
  if activate_value then
    update public.information_lineage_resolution_policies
    set is_current = false, active = false, superseded_at = now()
    where data_type = data_type_value and is_current and active;
  end if;
  insert into public.information_lineage_resolution_policies(
    policy_key, version, data_type, automatically_permitted_actions,
    configuration, active, is_current, created_by_actor_id
  ) values (
    policy_key_value, version_value, data_type_value,
    coalesce(automatically_permitted_actions_value, '{}'::text[]),
    coalesce(configuration_value, '{}'::jsonb), activate_value, activate_value,
    actor_uuid
  ) returning id into result_uuid;
  return result_uuid;
end;
$$;

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
      attempt_count = attempt_count + 1
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
  return jsonb_build_object(
    'work_item_id', work_record.id,
    'data_type', work_record.data_type,
    'subject_type', work_record.subject_type,
    'subject_id', work_record.subject_id,
    'evidence_kind', work_record.evidence_kind,
    'evidence_id', work_record.evidence_id,
    'attempt_number', work_record.attempt_count,
    'lease_token', work_record.lease_token,
    'lease_expires_at', work_record.lease_expires_at
  );
end;
$$;

create or replace function public.renew_information_lineage_resolution_work_lease(
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
  work_record public.information_lineage_resolution_work_items%rowtype;
  runtime_policy public.agent_job_runtime_policies%rowtype;
  renewed_until timestamptz;
begin
  select * into strict work_record
  from public.information_lineage_resolution_work_items
  where id = work_item_uuid for update;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now()
     or not public.has_catalog_capability('information_lineage.resolve') then
    raise exception 'An active lineage-resolution lease and capability are required';
  end if;
  select * into strict runtime_policy
  from public.current_agent_job_runtime_policy(
    'information_lineage_resolver.' || work_record.data_type
  );
  renewed_until := now() + make_interval(secs => runtime_policy.lease_seconds);
  update public.information_lineage_resolution_work_items
  set lease_expires_at = renewed_until, updated_at = now()
  where id = work_record.id;
  update public.information_lineage_resolution_attempts
  set last_heartbeat_at = now(), lease_expires_at = renewed_until
  where work_item_id = work_record.id
    and attempt_number = work_record.attempt_count and ended_at is null;
  return renewed_until;
end;
$$;

create or replace function public.report_information_lineage_resolution_failure(
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
  work_record public.information_lineage_resolution_work_items%rowtype;
begin
  select * into strict work_record
  from public.information_lineage_resolution_work_items
  where id = work_item_uuid for update;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now()
     or not public.has_catalog_capability('information_lineage.resolve') then
    raise exception 'An active lineage-resolution lease and capability are required';
  end if;
  if nullif(btrim(failure_category_value), '') is null
     or nullif(btrim(failure_reason_value), '') is null then
    raise exception 'Failure category and reason are required';
  end if;
  return public.transition_information_lineage_resolution_by_runtime_policy(
    work_record.id, btrim(failure_category_value), btrim(failure_reason_value)
  );
end;
$$;

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
    select version.id into lineage_version_uuid
    from public.information_lineages lineage
    join public.information_lineage_versions version
      on version.lineage_id = lineage.id and version.is_current
    where lineage.lineage_key = proposed_lineage_key_value
      and lineage.data_type = work_record.data_type
      and version.review_status = 'approved';
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
    proposed_lineage_key_value, btrim(resolution_basis_value),
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
      completed_at = case when disposition_value = 'automatically_applied' then now() else null end
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
      'lineage_version_id', lineage_version_uuid
    )
  );
  return result_uuid;
end;
$$;

create or replace function public.sync_catalog_verification_automation_policy()
returns trigger
language plpgsql
set search_path = ''
as $$
declare automation jsonb := new.configuration -> 'automated_adjudication';
begin
  if automation is not null then
    new.maximum_verifier_rounds := nullif(automation ->> 'maximum_verifier_rounds', '')::integer;
    new.required_matching_verifier_results := nullif(automation ->> 'required_matching_verifier_results', '')::integer;
    new.consensus_strategy := nullif(automation ->> 'consensus_strategy', '');
  end if;
  return new;
end;
$$;

create trigger sync_catalog_verification_automation_policy
before insert or update of configuration on public.verification_policies
for each row execute function public.sync_catalog_verification_automation_policy();

create or replace function public.admin_create_catalog_verification_round_policy(
  verification_policy_uuid uuid,
  verification_round_value integer,
  minimum_evidence_count_value integer default null,
  allowed_trust_tiers_value smallint[] default null,
  minimum_independent_ownership_groups_value integer default null,
  minimum_independent_information_lineages_value integer default null,
  minimum_high_trust_evidence_count_value integer default null,
  source_selection_policy_value jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare actor_uuid uuid := public.current_catalog_actor_id(); result_uuid uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null) then
    raise exception 'Administrator access is required to configure verifier rounds';
  end if;
  insert into public.catalog_verification_round_policies(
    verification_policy_id, verification_round, minimum_evidence_count,
    allowed_trust_tiers, minimum_independent_ownership_groups,
    minimum_independent_information_lineages,
    minimum_high_trust_evidence_count, source_selection_policy
  ) values (
    verification_policy_uuid, verification_round_value,
    minimum_evidence_count_value, allowed_trust_tiers_value,
    minimum_independent_ownership_groups_value,
    minimum_independent_information_lineages_value,
    minimum_high_trust_evidence_count_value,
    coalesce(source_selection_policy_value, '{}'::jsonb)
  ) returning id into result_uuid;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'verification_round_policy.created',
    'catalog_verification_round_policy', result_uuid::text,
    jsonb_build_object(
      'verification_policy_id', verification_policy_uuid,
      'verification_round', verification_round_value
    )
  );
  return result_uuid;
end;
$$;

create or replace function public.protect_versioned_agent_policy_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then raise exception 'Versioned agent policy and lineage history cannot be deleted'; end if;
  if (to_jsonb(old) - 'is_current' - 'active' - 'superseded_at')
     is distinct from (to_jsonb(new) - 'is_current' - 'active' - 'superseded_at') then
    raise exception 'Versioned agent policy and lineage content is immutable';
  end if;
  return new;
end;
$$;

create trigger agent_job_runtime_policy_history_protected
before update or delete on public.agent_job_runtime_policies
for each row execute function public.protect_versioned_agent_policy_history();
create trigger catalog_revalidation_policy_history_protected
before update or delete on public.catalog_revalidation_policies
for each row execute function public.protect_versioned_agent_policy_history();
create trigger catalog_verification_round_policy_history_protected
before update or delete on public.catalog_verification_round_policies
for each row execute function public.protect_versioned_agent_policy_history();
create trigger information_lineage_resolution_policy_history_protected
before update or delete on public.information_lineage_resolution_policies
for each row execute function public.protect_versioned_agent_policy_history();
create trigger agent_specialist_results_append_only
before update or delete on public.agent_specialist_results
for each row execute function public.protect_agent_backend_history();
create trigger catalog_determinate_adjudications_append_only
before update or delete on public.catalog_determinate_adjudications
for each row execute function public.protect_agent_backend_history();
create trigger information_lineage_resolution_results_append_only
before update or delete on public.information_lineage_resolution_results
for each row execute function public.protect_agent_backend_history();
create trigger catalog_evidence_lineage_assignments_append_only
before update or delete on public.catalog_evidence_lineage_assignments
for each row execute function public.protect_versioned_agent_policy_history();

create or replace function public.protect_information_lineage_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then raise exception 'Information-lineage history cannot be deleted'; end if;
  if (to_jsonb(old) - 'is_current' - 'superseded_at')
     is distinct from (to_jsonb(new) - 'is_current' - 'superseded_at') then
    raise exception 'Information-lineage version content is immutable';
  end if;
  return new;
end;
$$;

create trigger information_lineage_version_history_protected
before update or delete on public.information_lineage_versions
for each row execute function public.protect_information_lineage_history();

-- ---------------------------------------------------------------------------
-- RLS and narrow RPC grants.
-- ---------------------------------------------------------------------------

alter table public.agent_job_runtime_policies enable row level security;
alter table public.catalog_verification_round_policies enable row level security;
alter table public.catalog_domain_adapters enable row level security;
alter table public.agent_specialist_results enable row level security;
alter table public.catalog_determinate_adjudications enable row level security;
alter table public.information_lineages enable row level security;
alter table public.information_lineage_versions enable row level security;
alter table public.information_lineage_resolution_policies enable row level security;
alter table public.information_lineage_resolution_work_items enable row level security;
alter table public.information_lineage_resolution_attempts enable row level security;
alter table public.information_lineage_resolution_results enable row level security;
alter table public.catalog_evidence_lineage_assignments enable row level security;
alter table public.catalog_verification_work_items enable row level security;
alter table public.catalog_verification_attempts enable row level security;
alter table public.catalog_verification_work_events enable row level security;
alter table public.catalog_verifier_evidence enable row level security;
alter table public.catalog_verifier_results enable row level security;
alter table public.catalog_verification_comparisons enable row level security;
alter table public.agent_work_wake_outbox enable row level security;
alter table public.catalog_revalidation_policies enable row level security;
alter table public.catalog_fact_revalidation_state enable row level security;

revoke all on public.agent_job_runtime_policies from public, anon, authenticated;
revoke all on public.catalog_verification_round_policies from public, anon, authenticated;
revoke all on public.catalog_domain_adapters from public, anon, authenticated;
revoke all on public.agent_specialist_results from public, anon, authenticated;
revoke all on public.catalog_determinate_adjudications from public, anon, authenticated;
revoke all on public.information_lineages from public, anon, authenticated;
revoke all on public.information_lineage_versions from public, anon, authenticated;
revoke all on public.information_lineage_resolution_policies from public, anon, authenticated;
revoke all on public.information_lineage_resolution_work_items from public, anon, authenticated;
revoke all on public.information_lineage_resolution_attempts from public, anon, authenticated;
revoke all on public.information_lineage_resolution_results from public, anon, authenticated;
revoke all on public.catalog_evidence_lineage_assignments from public, anon, authenticated;
revoke all on public.catalog_verification_work_items from public, anon, authenticated;
revoke all on public.catalog_verification_attempts from public, anon, authenticated;
revoke all on public.catalog_verification_work_events from public, anon, authenticated;
revoke all on public.catalog_verifier_evidence from public, anon, authenticated;
revoke all on public.catalog_verifier_results from public, anon, authenticated;
revoke all on public.catalog_verification_comparisons from public, anon, authenticated;
revoke all on public.agent_work_wake_outbox from public, anon, authenticated;
revoke all on public.catalog_revalidation_policies from public, anon, authenticated;
revoke all on public.catalog_fact_revalidation_state from public, anon, authenticated;

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'agent_job_runtime_policies','catalog_verification_round_policies',
    'catalog_domain_adapters','agent_specialist_results',
    'catalog_determinate_adjudications',
    'information_lineages','information_lineage_versions',
    'information_lineage_resolution_policies',
    'information_lineage_resolution_work_items',
    'information_lineage_resolution_attempts',
    'information_lineage_resolution_results','catalog_evidence_lineage_assignments',
    'catalog_verification_work_items','catalog_verification_attempts',
    'catalog_verification_work_events','catalog_verifier_evidence',
    'catalog_verifier_results','catalog_verification_comparisons',
    'agent_work_wake_outbox','catalog_revalidation_policies',
    'catalog_fact_revalidation_state'
  ] loop
    execute format(
      'create policy "Authorized staff read %1$s" on public.%1$I for select to authenticated using (public.has_catalog_capability(''catalog.read_internal'') or public.has_staff_access(array[''admin'',''staff'',''content_admin'']::text[], null))',
      table_name
    );
    execute format('grant select on table public.%I to authenticated', table_name);
  end loop;
end $$;

revoke all on function public.current_agent_job_runtime_policy(text) from public, anon, authenticated;
revoke all on function public.has_catalog_verification_capability(text,jsonb) from public, anon, authenticated;
revoke all on function public.current_information_lineage_root(uuid) from public, anon, authenticated;
revoke all on function public.applicable_source_version_for_subject(uuid,text,jsonb) from public, anon, authenticated;
revoke all on function public.catalog_source_evaluation_snapshot(uuid,text) from public, anon, authenticated;
revoke all on function public.emit_agent_work_wake(text,uuid,text,timestamptz,text) from public, anon, authenticated;
revoke all on function public.emit_team_color_work_wake() from public, anon, authenticated;
revoke all on function public.emit_catalog_verification_work_wake() from public, anon, authenticated;
revoke all on function public.ensure_catalog_verification_work(uuid) from public, anon, authenticated;
revoke all on function public.ensure_catalog_verification_work_for_result(text,uuid,integer,uuid) from public, anon, authenticated;
revoke all on function public.ensure_team_color_verification_work() from public, anon, authenticated;
revoke all on function public.compare_team_color_verifier_result(uuid) from public, anon, authenticated;
revoke all on function public.build_team_color_verifier_context(text,uuid,integer) from public, anon, authenticated;
revoke all on function public.team_color_authoritative_payload_from_palette(jsonb,jsonb) from public, anon, authenticated;
revoke all on function public.finalize_team_color_authoritative_result(text,uuid,uuid,jsonb,text) from public, anon, authenticated;
revoke all on function public.finalize_catalog_authoritative_result(text,text,uuid,uuid,jsonb,text) from public, anon, authenticated;
revoke all on function public.schedule_additional_catalog_verification_round(uuid) from public, anon, authenticated;
revoke all on function public.transition_team_color_work_by_runtime_policy(uuid,text,text,jsonb,boolean,uuid,uuid) from public, anon, authenticated;
revoke all on function public.transition_catalog_verification_by_runtime_policy(uuid,text,text) from public, anon, authenticated;
revoke all on function public.expire_catalog_verification_work_leases() from public, anon, authenticated;
revoke all on function public.expire_team_color_work_leases() from public, anon, authenticated;
revoke all on function public.record_team_color_revalidation_state(uuid,uuid,uuid,text,text,text) from public, anon, authenticated;
revoke all on function public.sync_team_color_revalidation_on_version() from public, anon, authenticated;
revoke all on function public.protect_agent_backend_history() from public, anon, authenticated;
revoke all on function public.protect_versioned_agent_policy_history() from public, anon, authenticated;
revoke all on function public.protect_information_lineage_history() from public, anon, authenticated;
revoke all on function public.enforce_team_color_information_lineage_decision() from public, anon, authenticated;
revoke all on function public.recover_team_color_domain() from public, anon, authenticated;
revoke all on function public.reconcile_team_color_wakes() from public, anon, authenticated;
revoke all on function public.enqueue_team_color_revalidation(uuid) from public, anon, authenticated;
revoke all on function public.enqueue_information_lineage_resolution_work(text,uuid,text,text,text) from public, anon, authenticated;
revoke all on function public.enqueue_unknown_proposal_evidence_lineage() from public, anon, authenticated;
revoke all on function public.enqueue_unknown_verifier_evidence_lineage() from public, anon, authenticated;
revoke all on function public.complete_lineage_resolution_after_governed_assignment() from public, anon, authenticated;
revoke all on function public.transition_information_lineage_resolution_by_runtime_policy(uuid,text,text) from public, anon, authenticated;
revoke all on function public.expire_information_lineage_resolution_work_leases() from public, anon, authenticated;
revoke all on function public.reconcile_information_lineage_resolution_wakes() from public, anon, authenticated;
revoke all on function public.sync_catalog_verification_automation_policy() from public, anon, authenticated;

revoke all on function public.admin_review_information_lineage(text,text,text,text,text,text,text,jsonb) from public, anon;
grant execute on function public.admin_review_information_lineage(text,text,text,text,text,text,text,jsonb) to authenticated;
revoke all on function public.assign_catalog_evidence_information_lineage(uuid,text,text) from public, anon;
grant execute on function public.assign_catalog_evidence_information_lineage(uuid,text,text) to authenticated;
revoke all on function public.admin_create_agent_job_runtime_policy(text,integer,text,integer,text[],text[],integer[],integer,text,text,jsonb,boolean) from public, anon;
grant execute on function public.admin_create_agent_job_runtime_policy(text,integer,text,integer,text[],text[],integer[],integer,text,text,jsonb,boolean) to authenticated;
revoke all on function public.admin_create_catalog_revalidation_policy(text,integer,text,interval,jsonb,boolean) from public, anon;
grant execute on function public.admin_create_catalog_revalidation_policy(text,integer,text,interval,jsonb,boolean) to authenticated;
revoke all on function public.admin_create_catalog_verification_round_policy(uuid,integer,integer,smallint[],integer,integer,integer,jsonb) from public, anon;
grant execute on function public.admin_create_catalog_verification_round_policy(uuid,integer,integer,smallint[],integer,integer,integer,jsonb) to authenticated;
revoke all on function public.admin_register_catalog_domain_adapter(text,text,text,text,text,regproc,regproc,regproc,regproc,regproc,regproc,jsonb,boolean) from public, anon;
grant execute on function public.admin_register_catalog_domain_adapter(text,text,text,text,text,regproc,regproc,regproc,regproc,regproc,regproc,jsonb,boolean) to authenticated;
revoke all on function public.admin_create_information_lineage_resolution_policy(text,integer,text,text[],jsonb,boolean) from public, anon;
grant execute on function public.admin_create_information_lineage_resolution_policy(text,integer,text,text[],jsonb,boolean) to authenticated;
revoke all on function public.enqueue_due_catalog_revalidations(text) from public, anon;
grant execute on function public.enqueue_due_catalog_revalidations(text) to authenticated;

revoke all on function public.get_my_catalog_verification_work(uuid,uuid) from public, anon;
grant execute on function public.get_my_catalog_verification_work(uuid,uuid) to authenticated;
revoke all on function public.claim_next_catalog_verification_work(text) from public, anon;
grant execute on function public.claim_next_catalog_verification_work(text) to authenticated;
revoke all on function public.renew_catalog_verification_work_lease(uuid,uuid) from public, anon;
grant execute on function public.renew_catalog_verification_work_lease(uuid,uuid) to authenticated;
revoke all on function public.resolve_catalog_verification_source(uuid,uuid,text) from public, anon;
grant execute on function public.resolve_catalog_verification_source(uuid,uuid,text) to authenticated;
revoke all on function public.add_team_color_verifier_evidence(uuid,uuid,text,text,text,timestamptz,jsonb,text,text) from public, anon;
grant execute on function public.add_team_color_verifier_evidence(uuid,uuid,text,text,text,timestamptz,jsonb,text,text) to authenticated;
revoke all on function public.submit_team_color_verifier_result(uuid,uuid,text,jsonb,text) from public, anon;
grant execute on function public.submit_team_color_verifier_result(uuid,uuid,text,jsonb,text) to authenticated;
revoke all on function public.submit_catalog_verifier_result(uuid,uuid,text,jsonb,text) from public, anon;
grant execute on function public.submit_catalog_verifier_result(uuid,uuid,text,jsonb,text) to authenticated;
revoke all on function public.report_catalog_verification_failure(uuid,uuid,text,text) from public, anon;
grant execute on function public.report_catalog_verification_failure(uuid,uuid,text,text) to authenticated;
revoke all on function public.claim_next_information_lineage_resolution_work(text) from public, anon;
grant execute on function public.claim_next_information_lineage_resolution_work(text) to authenticated;
revoke all on function public.renew_information_lineage_resolution_work_lease(uuid,uuid) from public, anon;
grant execute on function public.renew_information_lineage_resolution_work_lease(uuid,uuid) to authenticated;
revoke all on function public.report_information_lineage_resolution_failure(uuid,uuid,text,text) from public, anon;
grant execute on function public.report_information_lineage_resolution_failure(uuid,uuid,text,text) to authenticated;
revoke all on function public.submit_information_lineage_resolution_result(uuid,uuid,text,text,text,jsonb) from public, anon;
grant execute on function public.submit_information_lineage_resolution_result(uuid,uuid,text,text,text,jsonb) to authenticated;

revoke all on function public.submit_team_color_proposal(uuid,uuid,jsonb,text) from public, anon;
grant execute on function public.submit_team_color_proposal(uuid,uuid,jsonb,text) to authenticated;
revoke all on function public.finish_team_color_work(uuid,uuid,text,text,text,timestamptz,jsonb) from public, anon;
grant execute on function public.finish_team_color_work(uuid,uuid,text,text,text,timestamptz,jsonb) to authenticated;
revoke all on function public.release_team_color_work(uuid,uuid,timestamptz,text,text) from public, anon;
grant execute on function public.release_team_color_work(uuid,uuid,timestamptz,text,text) to authenticated;
revoke all on function public.report_team_color_work_failure(uuid,uuid,text,text,jsonb) from public, anon;
grant execute on function public.report_team_color_work_failure(uuid,uuid,text,text,jsonb) to authenticated;
revoke all on function public.review_catalog_proposal(uuid,text,text) from public, anon;
grant execute on function public.review_catalog_proposal(uuid,text,text) to authenticated;

revoke all on function public.get_agent_work_wakes(integer,text) from public, anon;
grant execute on function public.get_agent_work_wakes(integer,text) to authenticated;
revoke all on function public.acknowledge_agent_work_wake(uuid) from public, anon;
grant execute on function public.acknowledge_agent_work_wake(uuid) to authenticated;
revoke all on function public.process_catalog_verification_result(uuid) from public, anon;
grant execute on function public.process_catalog_verification_result(uuid) to authenticated;
revoke all on function public.run_agent_backend_recovery() from public, anon;
grant execute on function public.run_agent_backend_recovery() to authenticated;

comment on table public.catalog_verification_work_items is
  'Reusable durable blinded-verification queue correlated to a generic specialist result and optional originating domain job.';
comment on table public.catalog_verifier_results is
  'Immutable independently researched verifier result, durably stored before backend comparison.';
comment on table public.catalog_verification_comparisons is
  'Immutable deterministic comparison outcome; distinct from both verifier research and final catalog decision.';
comment on table public.agent_work_wake_outbox is
  'At-least-once durable orchestration signal. Queue claiming remains the duplicate-execution authority.';
comment on function public.get_my_catalog_verification_work(uuid,uuid) is
  'Lease-scoped blinded verifier context. It intentionally excludes proposal payload, specialist evidence, reasoning, and confidence.';
comment on function public.run_agent_backend_recovery() is
  'Scheduling-compatible idempotent recovery operation. No execution interval is defined by this migration.';
