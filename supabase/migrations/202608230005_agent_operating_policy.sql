-- Approved initial operating policy for FANatical's Team Color specialist and
-- generic determinate verifier backend. This migration configures the generic
-- architecture introduced by 202608230004; it does not launch any workers.

-- Immediate retry is an approved policy value. Preserve the requirement for a
-- delay entry while allowing zero seconds as the smallest safe schema change.
alter table public.agent_job_runtime_policies
  drop constraint agent_job_runtime_policies_check;
alter table public.agent_job_runtime_policies
  add constraint agent_job_runtime_policies_retry_configuration_check
  check (
    cardinality(retryable_failure_categories) = 0
    or (
      lease_seconds is not null
      and maximum_attempts is not null
      and cardinality(retry_delay_seconds) > 0
      and 0 <= all(retry_delay_seconds)
    )
  );

-- Versioned backend cadence and concurrency policy. Astro may consume the same
-- values later, while database claim transitions enforce the limits now.
create table public.agent_backend_operating_policies (
  id uuid primary key default gen_random_uuid(),
  policy_key text not null,
  version integer not null check (version > 0),
  watchdog_interval interval not null check (watchdog_interval > interval '0 seconds'),
  maximum_concurrent_operational_workers integer not null
    check (maximum_concurrent_operational_workers > 0),
  configuration jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  is_current boolean not null default true,
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  unique (policy_key, version)
);

create unique index agent_backend_operating_policy_current_idx
on public.agent_backend_operating_policies((is_current))
where is_current and active;

create table public.agent_worker_pool_concurrency_policies (
  id uuid primary key default gen_random_uuid(),
  operating_policy_id uuid not null
    references public.agent_backend_operating_policies(id),
  worker_pool text not null check (length(btrim(worker_pool)) > 0),
  maximum_concurrent_workers integer not null check (maximum_concurrent_workers > 0),
  created_at timestamptz not null default now(),
  unique (operating_policy_id, worker_pool)
);

create or replace function public.current_agent_backend_operating_policy()
returns public.agent_backend_operating_policies
language sql
stable
security definer
set search_path = ''
as $$
  select policy.*
  from public.agent_backend_operating_policies policy
  where policy.is_current and policy.active
  order by policy.version desc
  limit 1;
$$;

create or replace function public.current_agent_worker_pool_limit(
  worker_pool_value text
)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select pool.maximum_concurrent_workers
  from public.agent_backend_operating_policies policy
  join public.agent_worker_pool_concurrency_policies pool
    on pool.operating_policy_id = policy.id
  where policy.is_current and policy.active
    and pool.worker_pool = worker_pool_value
  order by policy.version desc
  limit 1;
$$;

create or replace function public.enforce_agent_worker_concurrency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  pool_name text := tg_argv[0];
  operating_policy public.agent_backend_operating_policies%rowtype;
  pool_limit integer;
  pool_claimed integer;
  globally_claimed integer;
begin
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
    select count(*) into pool_claimed
    from public.team_color_work_items work where work.status = 'claimed';
  elsif pool_name = 'catalog_verifier' then
    select count(*) into pool_claimed
    from public.catalog_verification_work_items work where work.status = 'claimed';
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
  into globally_claimed;
  if globally_claimed >= operating_policy.maximum_concurrent_operational_workers then
    raise exception 'The global operational-worker concurrency limit of % is already reached',
      operating_policy.maximum_concurrent_operational_workers;
  end if;
  return new;
end;
$$;

create trigger enforce_team_color_specialist_concurrency
before insert or update of status on public.team_color_work_items
for each row execute function public.enforce_agent_worker_concurrency(
  'team_color_specialist'
);

create trigger enforce_catalog_verifier_concurrency
before insert or update of status on public.catalog_verification_work_items
for each row execute function public.enforce_agent_worker_concurrency(
  'catalog_verifier'
);

insert into public.agent_backend_operating_policies(
  policy_key, version, watchdog_interval,
  maximum_concurrent_operational_workers, configuration
) values (
  'initial-agent-backend-operating-policy', 1, interval '15 minutes', 2,
  jsonb_build_object(
    'scope', 'team_color_specialist_and_determinate_verifier',
    'watchdog_purpose', 'recover_stalled_backend_work',
    'stale_worker_worst_case_accepted', 'approximately_30_minutes'
  )
);

insert into public.agent_worker_pool_concurrency_policies(
  operating_policy_id, worker_pool, maximum_concurrent_workers
)
select policy.id, pool.worker_pool, pool.maximum_concurrent_workers
from public.agent_backend_operating_policies policy
cross join (values
  ('team_color_specialist', 1),
  ('catalog_verifier', 1)
) pool(worker_pool, maximum_concurrent_workers)
where policy.policy_key = 'initial-agent-backend-operating-policy'
  and policy.version = 1;

insert into public.agent_job_runtime_policies(
  policy_key, version, job_type, lease_seconds,
  retryable_failure_categories, permanent_failure_categories,
  retry_delay_seconds, maximum_attempts, exhaustion_status,
  permanent_failure_status, configuration
)
values
  (
    'team-color-specialist-production-runtime', 1,
    'team_color_specialist', 900,
    array[
      'transient','temporary_network_failure','temporary_api_failure',
      'temporary_source_outage','rate_limited','worker_interrupted','lease_expired'
    ],
    array[
      'authorization_denied','invalid_permissions','invalid_schema',
      'invalid_input','missing_required_policy','impossible_assignment'
    ],
    array[0], 2, 'needs_review', 'needs_review',
    jsonb_build_object(
      'retry_semantics', 'execution_failure_only',
      'factual_disagreement_uses', 'verifier_consensus'
    )
  ),
  (
    'determinate-verifier-production-runtime', 1,
    'catalog_verifier.team_colors', 900,
    array[
      'transient','temporary_network_failure','temporary_api_failure',
      'temporary_source_outage','rate_limited','worker_interrupted','lease_expired'
    ],
    array[
      'authorization_denied','invalid_permissions','invalid_schema',
      'invalid_input','missing_required_policy','impossible_assignment'
    ],
    array[0], 2, 'needs_review', 'needs_review',
    jsonb_build_object(
      'retry_semantics', 'execution_failure_only',
      'factual_disagreement_uses', 'verifier_consensus'
    )
  );

do $$
declare
  current_policy public.verification_policies%rowtype;
  next_version integer;
  approved_policy_uuid uuid;
  approved_configuration jsonb;
begin
  select * into strict current_policy
  from public.verification_policies
  where data_type = 'team_colors' and is_current and active
  for update;
  select coalesce(max(version), 0) + 1 into next_version
  from public.verification_policies
  where policy_key = current_policy.policy_key;
  approved_configuration := current_policy.configuration || jsonb_build_object(
    'automated_adjudication', jsonb_build_object(
      'maximum_verifier_rounds', 2,
      'required_matching_verifier_results', 2,
      'consensus_strategy', 'specialist_match_or_verifier_consensus',
      'all_distinct_resolution', 'evidence_quality_order_then_needs_review'
    ),
    'normal_minimum_independent_information_lineages', 3,
    'escalated_minimum_independent_information_lineages', 4,
    'evidence_quality_order', jsonb_build_array(
      'information_lineage_independence',
      'governance_tier_1_then_2_then_3',
      'empirical_source_reliability',
      'target_applicability',
      'recent_contradictions_or_reliability_drift'
    ),
    'source_overlap_rule',
      'Independently rediscovered strong applicable sources remain permitted.'
  );
  update public.verification_policies
  set is_current = false, active = false, superseded_at = now()
  where id = current_policy.id;
  insert into public.verification_policies(
    policy_key, version, data_type, minimum_evidence_count,
    allowed_trust_tiers, require_independent_sources,
    require_independent_verifier, configuration, is_current, active
  ) values (
    current_policy.policy_key, next_version, current_policy.data_type, 3,
    current_policy.allowed_trust_tiers, true, true,
    approved_configuration, true, true
  ) returning id into approved_policy_uuid;
  insert into public.catalog_verification_round_policies(
    verification_policy_id, verification_round, minimum_evidence_count,
    minimum_independent_ownership_groups,
    minimum_independent_information_lineages,
    minimum_high_trust_evidence_count, source_selection_policy
  ) values
    (
      approved_policy_uuid, 1, 3, 3, 3, 1,
      jsonb_build_object(
        'permit_independently_rediscovered_source_overlap', true,
        'evidence_quality_order', approved_configuration -> 'evidence_quality_order'
      )
    ),
    (
      approved_policy_uuid, 2, 4, 3, 4, 1,
      jsonb_build_object(
        'prefer_strongest_applicable_evidence', true,
        'permit_independently_rediscovered_source_overlap', true,
        'evidence_quality_order', approved_configuration -> 'evidence_quality_order'
      )
    );
end;
$$;

insert into public.catalog_revalidation_policies(
  policy_key, version, data_type, review_cadence, configuration
) values (
  'team-color-six-month-revalidation', 1, 'team_colors', interval '6 months',
  jsonb_build_object(
    'age_alone_invalidates_verified_data', false,
    'event_triggered_rechecks_remain_permitted', true
  )
);

update public.catalog_fact_revalidation_state state
set cadence_policy_id = policy.id,
    next_review_at = state.last_verified_at + policy.review_cadence,
    updated_at = now()
from public.catalog_revalidation_policies policy
where policy.policy_key = 'team-color-six-month-revalidation'
  and policy.version = 1
  and state.data_type = 'team_colors';

alter table public.agent_backend_operating_policies enable row level security;
alter table public.agent_worker_pool_concurrency_policies enable row level security;
revoke all on public.agent_backend_operating_policies from public, anon, authenticated;
revoke all on public.agent_worker_pool_concurrency_policies from public, anon, authenticated;

create policy "Authorized staff read agent backend operating policies"
on public.agent_backend_operating_policies for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
create policy "Authorized staff read agent worker pool concurrency policies"
on public.agent_worker_pool_concurrency_policies for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
grant select on public.agent_backend_operating_policies to authenticated;
grant select on public.agent_worker_pool_concurrency_policies to authenticated;

create trigger agent_backend_operating_policy_history_protected
before update or delete on public.agent_backend_operating_policies
for each row execute function public.protect_versioned_agent_policy_history();
create trigger agent_worker_pool_concurrency_policy_history_protected
before update or delete on public.agent_worker_pool_concurrency_policies
for each row execute function public.protect_agent_backend_history();

revoke all on function public.current_agent_backend_operating_policy()
from public, anon, authenticated;
revoke all on function public.current_agent_worker_pool_limit(text)
from public, anon, authenticated;
revoke all on function public.enforce_agent_worker_concurrency()
from public, anon, authenticated;

comment on table public.agent_backend_operating_policies is
  'Versioned backend watchdog cadence and total operational-worker concurrency policy.';
comment on table public.agent_worker_pool_concurrency_policies is
  'Per-pool concurrency limits belonging to one versioned backend operating policy.';
