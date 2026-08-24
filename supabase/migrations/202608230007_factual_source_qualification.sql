-- Generic empirical factual-source qualification.
--
-- Governance approval identifies and scopes a source. It never makes that
-- source empirically qualified. Qualification is earned only from clean,
-- independently adjudicated shadow cases and is enforced separately at every
-- production-evidence boundary.

-- ---------------------------------------------------------------------------
-- Versioned qualification policy and source/data-type qualification profile
-- ---------------------------------------------------------------------------

create table public.source_qualification_policies (
  id uuid primary key default gen_random_uuid(),
  policy_key text not null,
  version integer not null check (version > 0),
  data_type text not null check (length(btrim(data_type)) > 0),
  first_rating_case_count integer not null check (first_rating_case_count > 0),
  first_decision_case_count integer not null
    check (first_decision_case_count > first_rating_case_count),
  reassessment_case_interval integer not null check (reassessment_case_interval > 0),
  qualification_rate numeric(7,6) not null
    check (qualification_rate > 0 and qualification_rate <= 1),
  probationary_rate numeric(7,6) not null
    check (probationary_rate >= 0 and probationary_rate < qualification_rate),
  minimum_reference_information_lineages integer not null
    check (minimum_reference_information_lineages >= 1),
  configuration jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  is_current boolean not null default true,
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  unique (policy_key, version),
  check (
    (first_decision_case_count - first_rating_case_count)
      % reassessment_case_interval = 0
  )
);

create unique index source_qualification_policy_current_idx
on public.source_qualification_policies(data_type)
where is_current and active;

create table public.source_qualification_enrollments (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.trusted_sources(id),
  data_type text not null check (length(btrim(data_type)) > 0),
  current_policy_id uuid not null references public.source_qualification_policies(id),
  qualification_status text not null default 'probationary' check (
    qualification_status in ('probationary','qualified','rejected')
  ),
  assessed_case_count integer not null default 0 check (assessed_case_count >= 0),
  match_count integer not null default 0 check (match_count >= 0),
  contradiction_count integer not null default 0 check (contradiction_count >= 0),
  raw_match_rate numeric,
  latest_evaluation_id uuid,
  enrolled_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (match_count + contradiction_count = assessed_case_count),
  check (
    (assessed_case_count = 0 and raw_match_rate is null)
    or (assessed_case_count > 0 and raw_match_rate between 0 and 1)
  )
);

create unique index source_qualification_enrollment_source_type_idx
on public.source_qualification_enrollments(source_id, data_type);

create table public.source_qualification_evaluations (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.source_qualification_enrollments(id),
  policy_id uuid not null references public.source_qualification_policies(id),
  assessed_case_count integer not null check (assessed_case_count >= 0),
  match_count integer not null check (match_count >= 0),
  contradiction_count integer not null check (contradiction_count >= 0),
  raw_match_rate numeric(7,6),
  evaluation_kind text not null check (evaluation_kind in (
    'rating','decision','reassessment','reconciliation'
  )),
  decision_basis text not null check (decision_basis in (
    'standard_case_threshold','narrow_exhaustive_coverage',
    'canonical_merge_reassessment'
  )),
  applicable_subject_count integer check (applicable_subject_count >= 0),
  tested_applicable_subject_count integer check (
    tested_applicable_subject_count >= 0
  ),
  evaluation_input_key text not null default gen_random_uuid()::text
    check (length(btrim(evaluation_input_key)) > 0),
  resulting_status text not null check (
    resulting_status in ('probationary','qualified','rejected')
  ),
  prior_status text not null check (
    prior_status in ('probationary','qualified','rejected')
  ),
  evaluated_at timestamptz not null default now(),
  unique (enrollment_id, evaluation_input_key),
  check (match_count + contradiction_count = assessed_case_count),
  check (
    (assessed_case_count = 0 and raw_match_rate is null)
    or (assessed_case_count > 0 and raw_match_rate between 0 and 1)
  ),
  check (
    (decision_basis in (
        'standard_case_threshold','canonical_merge_reassessment'
      )
      and applicable_subject_count is null
      and tested_applicable_subject_count is null)
    or
    (decision_basis = 'narrow_exhaustive_coverage'
      and applicable_subject_count is not null
      and tested_applicable_subject_count is not null
      and tested_applicable_subject_count = applicable_subject_count)
  )
);

alter table public.source_qualification_enrollments
  add constraint source_qualification_latest_evaluation_fk
  foreign key (latest_evaluation_id) references public.source_qualification_evaluations(id);

insert into public.source_qualification_policies(
  policy_key, version, data_type,
  first_rating_case_count, first_decision_case_count,
  reassessment_case_interval, qualification_rate, probationary_rate,
  minimum_reference_information_lineages, configuration
) values (
  'team-color-factual-source-qualification', 1, 'team_colors',
  10, 20, 10, 0.95, 0.80, 3,
  jsonb_build_object(
    'rating_metric', 'raw_match_rate',
    'bootstrap_reference', 'non_production_holdout',
    'production_fact_created', false,
    'tested_source_and_lineage_excluded', true,
    'narrow_source_exception', jsonb_build_object(
      'minimum_clean_cases', 10,
      'applicable_universe_below', 20,
      'requires_exhaustive_distinct_team_coverage', true
    )
  )
);

create or replace function public.ensure_source_qualification_enrollment(
  source_uuid uuid,
  data_type_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  policy_record public.source_qualification_policies%rowtype;
  canonical_source_uuid uuid;
  enrollment_uuid uuid;
begin
  select * into policy_record
  from public.source_qualification_policies
  where data_type = data_type_value and is_current and active;
  if policy_record.id is null then return null; end if;
  canonical_source_uuid := public.canonical_trusted_source_id(source_uuid);
  if not exists (
    select 1
    from public.source_applicability_versions applicability
    where public.canonical_trusted_source_id(applicability.source_id) = canonical_source_uuid
      and applicability.data_type = data_type_value
      and applicability.is_current and applicability.review_status = 'approved'
  ) then return null; end if;
  insert into public.source_qualification_enrollments(
    source_id, data_type, current_policy_id
  ) values (
    canonical_source_uuid, data_type_value, policy_record.id
  )
  on conflict (source_id, data_type) do update set
    current_policy_id = excluded.current_policy_id, updated_at = now()
  returning id into enrollment_uuid;
  return enrollment_uuid;
end;
$$;

create or replace function public.enroll_approved_source_applicability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  enrollment_uuid uuid;
begin
  if new.is_current and new.review_status = 'approved' then
    enrollment_uuid := public.ensure_source_qualification_enrollment(
      new.source_id, new.data_type
    );
    if enrollment_uuid is not null then
      perform public.reconcile_canonical_source_qualification(
        new.source_id, new.data_type, false
      );
    end if;
  end if;
  if tg_op = 'UPDATE'
     and old.is_current and old.review_status = 'approved'
     and (not new.is_current or new.review_status <> 'approved') then
    perform public.reconcile_canonical_source_qualification(
      old.source_id, old.data_type,
      public.canonical_trusted_source_id(old.source_id) <> old.source_id
    );
  end if;
  return new;
end;
$$;

create trigger enroll_approved_source_applicability
after insert or update of is_current, review_status
on public.source_applicability_versions
for each row execute function public.enroll_approved_source_applicability();

select public.ensure_source_qualification_enrollment(
  applicability.source_id, applicability.data_type
)
from public.source_applicability_versions applicability
where applicability.is_current and applicability.review_status = 'approved';

-- ---------------------------------------------------------------------------
-- Generic durable source-claim work and immutable result records
-- ---------------------------------------------------------------------------

alter table public.catalog_domain_adapters
  add column build_source_qualification_context_function regproc,
  add column normalize_source_qualification_result_function regproc,
  add column compare_source_qualification_result_function regproc,
  add column resolve_source_qualification_reference_function regproc,
  add column record_adjudication_source_contributions_function regproc;

create table public.source_qualification_work_items (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.source_qualification_enrollments(id),
  data_type text not null check (length(btrim(data_type)) > 0),
  subject_type text not null check (length(btrim(subject_type)) > 0),
  subject_id text not null check (length(btrim(subject_id)) > 0),
  capability_scope jsonb not null default '{}'::jsonb,
  applicability_version_id uuid not null
    references public.source_applicability_versions(id),
  assigned_source_location text not null
    check (assigned_source_location ~* '^https?://[^[:space:]]+$'),
  information_lineage_version_id uuid not null
    references public.information_lineage_versions(id),
  priority integer not null default 0,
  status text not null default 'queued' check (status in (
    'queued','claimed','retry_wait','completed','blocked',
    'needs_review','failed','cancelled'
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
  unique (enrollment_id, subject_type, subject_id),
  check (
    (status = 'claimed' and claimed_by_actor_id is not null
      and lease_token is not null and lease_expires_at is not null)
    or (status <> 'claimed' and claimed_by_actor_id is null
      and lease_token is null and lease_expires_at is null)
  )
);

create index source_qualification_work_claim_idx
on public.source_qualification_work_items(priority desc, available_at, created_at, id)
where status in ('queued','retry_wait');

create table public.source_qualification_attempts (
  id uuid primary key default gen_random_uuid(),
  work_item_id uuid not null references public.source_qualification_work_items(id),
  attempt_number integer not null check (attempt_number > 0),
  actor_id uuid not null references public.catalog_actors(id),
  lease_token uuid not null unique,
  claimed_at timestamptz not null default now(),
  last_heartbeat_at timestamptz not null default now(),
  lease_expires_at timestamptz not null,
  ended_at timestamptz,
  outcome text check (outcome in (
    'retry','completed','unresolved','blocked','needs_review',
    'failed','lease_expired'
  )),
  failure_category text,
  failure_reason text,
  unique (work_item_id, attempt_number)
);

create table public.source_qualification_work_events (
  id bigint generated always as identity primary key,
  work_item_id uuid not null references public.source_qualification_work_items(id),
  attempt_number integer,
  actor_id uuid references public.catalog_actors(id),
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index source_qualification_work_events_idx
on public.source_qualification_work_events(work_item_id, occurred_at, id);

create table public.source_qualification_results (
  id uuid primary key default gen_random_uuid(),
  work_item_id uuid not null unique references public.source_qualification_work_items(id),
  attempt_id uuid not null unique references public.source_qualification_attempts(id),
  submitted_by_actor_id uuid not null references public.catalog_actors(id),
  result_schema_version integer not null default 1 check (result_schema_version > 0),
  result_kind text not null check (result_kind in ('determinate','unresolved')),
  result_payload jsonb not null,
  normalized_result jsonb,
  source_id uuid not null references public.trusted_sources(id),
  applicability_version_id uuid not null references public.source_applicability_versions(id),
  source_location text not null,
  information_lineage_version_id uuid not null
    references public.information_lineage_versions(id),
  provenance_summary text,
  submitted_at timestamptz not null default now(),
  check (
    (result_kind = 'determinate' and normalized_result is not null)
    or (result_kind = 'unresolved' and normalized_result is null)
  )
);

alter table public.source_qualification_work_items
  add constraint source_qualification_work_result_fk
  foreign key (accepted_result_id) references public.source_qualification_results(id);

create table public.catalog_adjudication_source_contributions (
  id uuid primary key default gen_random_uuid(),
  adjudication_id uuid not null
    references public.catalog_determinate_adjudications(id),
  contribution_role text not null check (
    contribution_role in ('specialist','verifier')
  ),
  evidence_kind text not null check (length(btrim(evidence_kind)) > 0),
  evidence_id text not null check (length(btrim(evidence_id)) > 0),
  supports_authoritative_result boolean not null,
  source_id uuid not null references public.trusted_sources(id),
  information_lineage_version_id uuid
    references public.information_lineage_versions(id),
  information_lineage_root_id uuid
    references public.information_lineages(id),
  created_at timestamptz not null default now(),
  unique (adjudication_id, evidence_kind, evidence_id)
);

create table public.source_qualification_references (
  id uuid primary key default gen_random_uuid(),
  tested_result_id uuid not null unique references public.source_qualification_results(id),
  reference_kind text not null check (
    reference_kind in ('verified_fact','bootstrap_consensus')
  ),
  authoritative_adjudication_id uuid
    references public.catalog_determinate_adjudications(id),
  data_type text not null,
  subject_type text not null,
  subject_id text not null,
  normalized_reference_result jsonb not null,
  tested_source_id uuid not null references public.trusted_sources(id),
  tested_information_lineage_root_id uuid not null references public.information_lineages(id),
  contributing_information_lineage_count integer not null
    check (contributing_information_lineage_count >= 1),
  policy_id uuid not null references public.source_qualification_policies(id),
  non_production boolean not null default true check (non_production),
  created_at timestamptz not null default now(),
  check (
    (reference_kind = 'verified_fact' and authoritative_adjudication_id is not null)
    or
    (reference_kind = 'bootstrap_consensus' and authoritative_adjudication_id is null)
  )
);

create table public.source_qualification_reference_contributions (
  id uuid primary key default gen_random_uuid(),
  reference_id uuid not null references public.source_qualification_references(id),
  result_id uuid references public.source_qualification_results(id),
  adjudication_source_contribution_id uuid
    references public.catalog_adjudication_source_contributions(id),
  source_id uuid not null references public.trusted_sources(id),
  information_lineage_version_id uuid not null
    references public.information_lineage_versions(id),
  information_lineage_root_id uuid not null references public.information_lineages(id),
  created_at timestamptz not null default now(),
  unique (reference_id, information_lineage_root_id),
  check (num_nonnulls(result_id, adjudication_source_contribution_id) = 1)
);

create table public.source_qualification_observations (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.source_qualification_enrollments(id),
  tested_result_id uuid not null unique references public.source_qualification_results(id),
  reference_id uuid not null unique references public.source_qualification_references(id),
  subject_type text not null,
  subject_id text not null,
  outcome text not null check (outcome in ('match','contradiction')),
  tested_claim_snapshot jsonb not null,
  reference_result_snapshot jsonb not null,
  tested_source_id uuid not null references public.trusted_sources(id),
  tested_applicability_version_id uuid not null
    references public.source_applicability_versions(id),
  tested_information_lineage_version_id uuid not null
    references public.information_lineage_versions(id),
  tested_information_lineage_root_id uuid not null references public.information_lineages(id),
  observed_at timestamptz not null default now(),
  unique (enrollment_id, subject_type, subject_id)
);

-- ---------------------------------------------------------------------------
-- Team Color domain adapter: no prior colors, evidence, notes, or open context
-- ---------------------------------------------------------------------------

create or replace function public.build_team_color_source_qualification_context(
  subject_type_value text,
  subject_id_value text
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'subject', jsonb_strip_nulls(jsonb_build_object(
      'team_id', team.team_id,
      'team_name', identity_record.display_name,
      'sport_id', sport.sport_id,
      'sport_name', sport.display_name,
      'league_id', league.league_id,
      'league_name', league.display_name
    )),
    'capability_scope', jsonb_strip_nulls(jsonb_build_object(
      'sport_id', team.sport_id,
      'league_id', membership.league_id,
      'team_id', team.id
    ))
  )
  from public.catalog_teams team
  join public.catalog_sports sport on sport.id = team.sport_id
  left join public.team_identity_versions identity_record
    on identity_record.team_id = team.id and identity_record.is_current
  left join public.team_primary_league_versions membership
    on membership.team_id = team.id and membership.is_current
  left join public.catalog_leagues league on league.id = membership.league_id
  where subject_type_value = 'catalog_team'
    and team.id::text = subject_id_value;
$$;

create or replace function public.normalize_team_color_source_qualification_result(
  result_payload_value jsonb
)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case
    when public.validate_team_color_claim(result_payload_value)
      and result_payload_value ->> 'classification' = 'current_canonical'
    then jsonb_build_object(
      'classification', 'current_canonical',
      'palette', result_payload_value -> 'palette'
    )
    else null
  end;
$$;

create or replace function public.compare_team_color_source_qualification_result(
  normalized_claim_value jsonb,
  normalized_reference_value jsonb
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when normalized_claim_value = normalized_reference_value then 'match'
    else 'contradiction'
  end;
$$;

create or replace function public.record_team_color_adjudication_source_contributions(
  adjudication_uuid uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  adjudication_record public.catalog_determinate_adjudications%rowtype;
  authoritative_palette jsonb;
  inserted_count integer := 0;
  affected_count integer := 0;
begin
  select * into strict adjudication_record
  from public.catalog_determinate_adjudications
  where id = adjudication_uuid;
  if adjudication_record.data_type <> 'team_colors'
     or adjudication_record.specialist_result_kind <> 'catalog_proposal'
     or adjudication_record.outcome not in ('promoted','confirmed_no_change') then
    return 0;
  end if;
  authoritative_palette := public.team_color_palette_from_payload(
    adjudication_record.authoritative_result_payload
  );

  insert into public.catalog_adjudication_source_contributions(
    adjudication_id, contribution_role, evidence_kind, evidence_id,
    supports_authoritative_result,
    source_id, information_lineage_version_id,
    information_lineage_root_id
  )
  select adjudication_record.id, 'specialist', 'proposal_evidence', evidence.id::text,
         evidence.supports_proposal
           and evidence.structured_claim ->> 'classification' = 'current_canonical'
           and evidence.structured_claim -> 'palette' = authoritative_palette,
         public.canonical_trusted_source_id(evidence.source_id),
         coalesce(evidence.information_lineage_version_id,
                  lineage_assignment.information_lineage_version_id),
         public.current_information_lineage_root(coalesce(
           evidence.information_lineage_version_id,
           lineage_assignment.information_lineage_version_id
         ))
  from public.catalog_proposal_evidence evidence
  left join public.catalog_evidence_lineage_assignments lineage_assignment
    on lineage_assignment.evidence_kind = 'proposal_evidence'
   and lineage_assignment.evidence_id = evidence.id
   and lineage_assignment.is_current
  where evidence.proposal_id = adjudication_record.specialist_result_id
  on conflict (adjudication_id, evidence_kind, evidence_id) do nothing;
  get diagnostics affected_count = row_count;
  inserted_count := inserted_count + affected_count;

  insert into public.catalog_adjudication_source_contributions(
    adjudication_id, contribution_role, evidence_kind, evidence_id,
    supports_authoritative_result,
    source_id, information_lineage_version_id,
    information_lineage_root_id
  )
  select adjudication_record.id, 'verifier', 'verifier_evidence', evidence.id::text,
         evidence.structured_claim ->> 'classification' = 'current_canonical'
           and evidence.structured_claim -> 'palette' = authoritative_palette,
         public.canonical_trusted_source_id(evidence.source_id),
         coalesce(evidence.information_lineage_version_id,
                  lineage_assignment.information_lineage_version_id),
         public.current_information_lineage_root(coalesce(
           evidence.information_lineage_version_id,
           lineage_assignment.information_lineage_version_id
         ))
  from public.catalog_verification_work_items work
  join public.catalog_verifier_results verifier_result
    on verifier_result.verification_work_item_id = work.id
   and work.accepted_result_id = verifier_result.id
   and verifier_result.result_kind = 'determinate'
  join public.catalog_verification_attempts attempt
    on attempt.id = verifier_result.verification_attempt_id
  join public.catalog_verifier_evidence evidence
    on evidence.verification_work_item_id = work.id
   and evidence.attempt_number = attempt.attempt_number
  left join public.catalog_evidence_lineage_assignments lineage_assignment
    on lineage_assignment.evidence_kind = 'verifier_evidence'
   and lineage_assignment.evidence_id = evidence.id
   and lineage_assignment.is_current
  where work.specialist_result_kind = 'catalog_proposal'
    and work.specialist_result_id = adjudication_record.specialist_result_id
    and verifier_result.result_payload -> 'palette' = authoritative_palette
  on conflict (adjudication_id, evidence_kind, evidence_id) do nothing;
  get diagnostics affected_count = row_count;
  return inserted_count + affected_count;
end;
$$;

create or replace function public.resolve_team_color_source_qualification_reference(
  subject_type_value text,
  subject_id_value text,
  tested_source_uuid uuid,
  tested_lineage_version_uuid uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  adjudication_record public.catalog_determinate_adjudications%rowtype;
  canonical_tested_source_uuid uuid :=
    public.canonical_trusted_source_id(tested_source_uuid);
  tested_root_uuid uuid :=
    public.current_information_lineage_root(tested_lineage_version_uuid);
  required_lineage_count integer;
  current_lineage_count integer;
begin
  if subject_type_value <> 'catalog_team' or tested_root_uuid is null then
    return null;
  end if;
  select adjudication.* into adjudication_record
  from public.team_color_versions version
  join public.catalog_determinate_adjudications adjudication
    on adjudication.data_type = 'team_colors'
   and adjudication.subject_type = subject_type_value
   and adjudication.subject_id = subject_id_value
   and public.team_color_palette_from_payload(
         adjudication.authoritative_result_payload
       ) = public.team_color_palette_from_payload(jsonb_build_object(
         'primary', version.primary_color,
         'secondary', version.secondary_color,
         'tertiary', version.tertiary_color,
         'quaternary', version.quaternary_color,
         'quinary', version.quinary_color
       ))
  where version.team_id = subject_id_value::uuid
    and version.is_current and version.record_status = 'verified'
    and adjudication.outcome in ('promoted','confirmed_no_change')
  order by adjudication.decided_at desc, adjudication.id desc
  limit 1;
  if adjudication_record.id is null then return null; end if;

  if exists (
    select 1
    from public.catalog_adjudication_source_contributions contribution
    where contribution.adjudication_id = adjudication_record.id
      and public.canonical_trusted_source_id(contribution.source_id)
          = canonical_tested_source_uuid
  ) then return null; end if;
  if exists (
    select 1
    from public.catalog_adjudication_source_contributions contribution
    where contribution.adjudication_id = adjudication_record.id
      and public.current_information_lineage_root(
            contribution.information_lineage_version_id
          ) = tested_root_uuid
  ) then return null; end if;
  if exists (
    select 1
    from public.catalog_adjudication_source_contributions contribution
    where contribution.adjudication_id = adjudication_record.id
      and public.current_information_lineage_root(
            contribution.information_lineage_version_id
          ) is null
  ) then return null; end if;

  select policy.minimum_reference_information_lineages
    into strict required_lineage_count
  from public.source_qualification_policies policy
  where policy.data_type = 'team_colors' and policy.is_current and policy.active;
  select count(distinct public.current_information_lineage_root(
           contribution.information_lineage_version_id
         ))
    into current_lineage_count
  from public.catalog_adjudication_source_contributions contribution
  where contribution.adjudication_id = adjudication_record.id
    and contribution.supports_authoritative_result;
  if current_lineage_count < required_lineage_count then return null; end if;

  return jsonb_build_object(
    'reference_kind', 'verified_fact',
    'authoritative_adjudication_id', adjudication_record.id,
    'normalized_reference_result', jsonb_build_object(
      'classification', 'current_canonical',
      'palette', public.team_color_palette_from_payload(
        adjudication_record.authoritative_result_payload
      )
    ),
    'contributing_information_lineage_count', current_lineage_count
  );
end;
$$;

update public.catalog_domain_adapters
set build_source_qualification_context_function =
      'public.build_team_color_source_qualification_context'::regproc,
    normalize_source_qualification_result_function =
      'public.normalize_team_color_source_qualification_result'::regproc,
    compare_source_qualification_result_function =
      'public.compare_team_color_source_qualification_result'::regproc,
    resolve_source_qualification_reference_function =
      'public.resolve_team_color_source_qualification_reference'::regproc,
    record_adjudication_source_contributions_function =
      'public.record_team_color_adjudication_source_contributions'::regproc,
    updated_at = now()
where data_type = 'team_colors';

create or replace function public.capture_catalog_adjudication_source_contributions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare adapter_function regproc;
begin
  select adapter.record_adjudication_source_contributions_function
    into adapter_function
  from public.catalog_domain_adapters adapter
  where adapter.data_type = new.data_type and adapter.active;
  if adapter_function is not null then
    execute format('select %s($1)', adapter_function::regproc)
      using new.id;
  end if;
  return new;
end;
$$;

create trigger capture_catalog_adjudication_source_contributions
after insert on public.catalog_determinate_adjudications
for each row execute function public.capture_catalog_adjudication_source_contributions();

select public.record_team_color_adjudication_source_contributions(adjudication.id)
from public.catalog_determinate_adjudications adjudication
where adjudication.data_type = 'team_colors';

create or replace function public.admin_register_source_qualification_adapter(
  data_type_value text,
  build_context_function_value regproc,
  normalize_result_function_value regproc,
  compare_result_function_value regproc,
  resolve_reference_function_value regproc,
  record_contributions_function_value regproc
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare adjudication_uuid uuid;
  applicability_record record;
begin
  if not public.has_staff_access(array['admin']::text[], null) then
    raise exception 'Administrator access is required to register a source-qualification adapter';
  end if;
  if num_nonnulls(
       build_context_function_value, normalize_result_function_value,
       compare_result_function_value, resolve_reference_function_value,
       record_contributions_function_value
     ) <> 5 then
    raise exception 'Every source-qualification adapter function is required';
  end if;
  update public.catalog_domain_adapters
  set build_source_qualification_context_function = build_context_function_value,
      normalize_source_qualification_result_function = normalize_result_function_value,
      compare_source_qualification_result_function = compare_result_function_value,
      resolve_source_qualification_reference_function = resolve_reference_function_value,
      record_adjudication_source_contributions_function = record_contributions_function_value,
      updated_at = now()
  where data_type = data_type_value;
  if not found then
    raise exception 'Register the catalog domain adapter before its source-qualification adapter';
  end if;
  for applicability_record in
    select distinct applicability.source_id, applicability.data_type
    from public.source_applicability_versions applicability
    where applicability.data_type = data_type_value
      and applicability.is_current and applicability.review_status = 'approved'
  loop
    perform public.ensure_source_qualification_enrollment(
      applicability_record.source_id, applicability_record.data_type
    );
  end loop;
  for adjudication_uuid in
    select adjudication.id
    from public.catalog_determinate_adjudications adjudication
    where adjudication.data_type = data_type_value
  loop
    execute format('select %s($1)', record_contributions_function_value::regproc)
      using adjudication_uuid;
  end loop;
  return data_type_value;
end;
$$;

-- ---------------------------------------------------------------------------
-- Controlled enqueue, claim, lease, result, retry, wake, and recovery APIs
-- ---------------------------------------------------------------------------

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
  select version.id into lineage_version_uuid
  from public.information_lineages lineage
  join public.information_lineage_versions version
    on version.lineage_id = lineage.id and version.is_current
  where lineage.lineage_key = information_lineage_key_value
    and lineage.data_type = enrollment_record.data_type
    and version.review_status = 'approved';
  if lineage_version_uuid is null
     or public.current_information_lineage_root(lineage_version_uuid) is null then
    raise exception 'A current approved information lineage is required';
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
  returning id into work_uuid;
  insert into public.source_qualification_work_events(
    work_item_id, actor_id, event_type, details
  )
  select work_uuid, actor_uuid, 'queued', jsonb_build_object(
    'data_type', enrollment_record.data_type,
    'subject_type', subject_type_value,
    'subject_id', subject_id_value,
    'source_id', source_record.source_id,
    'applicability_version_id', applicability_version_uuid,
    'information_lineage_version_id', lineage_version_uuid
  )
  where not exists (
    select 1 from public.source_qualification_work_events event
    where event.work_item_id = work_uuid and event.event_type = 'queued'
  );
  return work_uuid;
end;
$$;

create or replace function public.get_my_source_qualification_work(
  work_item_uuid uuid,
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
  work_record public.source_qualification_work_items%rowtype;
  adapter_record public.catalog_domain_adapters%rowtype;
  context_value jsonb;
begin
  select * into strict work_record
  from public.source_qualification_work_items where id = work_item_uuid;
  if actor_uuid is null or work_record.status <> 'claimed'
     or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value
     or work_record.lease_expires_at <= now() then
    raise exception 'An active source-qualification lease owned by this actor is required';
  end if;
  if not public.has_catalog_capability(
    'source.qualification.work',
    nullif(work_record.capability_scope ->> 'sport_id','')::uuid,
    nullif(work_record.capability_scope ->> 'league_id','')::uuid,
    nullif(work_record.capability_scope ->> 'team_id','')::uuid,
    nullif(work_record.capability_scope ->> 'venue_id','')::uuid
  ) then
    raise exception 'Scoped source-qualification work capability is required';
  end if;
  select * into strict adapter_record from public.catalog_domain_adapters
  where data_type = work_record.data_type and active;
  execute format('select %s($1,$2)',
    adapter_record.build_source_qualification_context_function::regproc)
    using work_record.subject_type, work_record.subject_id into context_value;
  return jsonb_build_object(
    'work', jsonb_build_object(
      'work_item_id', work_record.id,
      'data_type', work_record.data_type,
      'attempt_number', work_record.attempt_count,
      'lease_token', work_record.lease_token,
      'lease_expires_at', work_record.lease_expires_at
    ),
    'subject', context_value -> 'subject',
    'assignment', jsonb_build_object(
      'source_location', work_record.assigned_source_location
    )
  );
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

create or replace function public.renew_source_qualification_work_lease(
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
  work_record public.source_qualification_work_items%rowtype;
  adapter_record public.catalog_domain_adapters%rowtype;
  runtime_policy public.agent_job_runtime_policies%rowtype;
  renewed_until timestamptz;
begin
  select * into strict work_record
  from public.source_qualification_work_items where id = work_item_uuid for update;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value
     or work_record.lease_expires_at <= now() then
    raise exception 'An unexpired source-qualification lease owned by this actor is required';
  end if;
  if not public.has_catalog_capability(
    'source.qualification.work',
    nullif(work_record.capability_scope ->> 'sport_id','')::uuid,
    nullif(work_record.capability_scope ->> 'league_id','')::uuid,
    nullif(work_record.capability_scope ->> 'team_id','')::uuid,
    nullif(work_record.capability_scope ->> 'venue_id','')::uuid
  ) then
    raise exception 'Scoped source-qualification work capability is required';
  end if;
  select * into strict adapter_record from public.catalog_domain_adapters
  where data_type = work_record.data_type and active;
  select * into strict runtime_policy
  from public.current_agent_job_runtime_policy(adapter_record.specialist_job_type);
  renewed_until := now() + make_interval(secs => runtime_policy.lease_seconds);
  update public.source_qualification_work_items
  set lease_expires_at = renewed_until, updated_at = now()
  where id = work_record.id;
  update public.source_qualification_attempts
  set lease_expires_at = renewed_until, last_heartbeat_at = now()
  where work_item_id = work_record.id
    and attempt_number = work_record.attempt_count and ended_at is null;
  insert into public.source_qualification_work_events(
    work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    work_record.id, work_record.attempt_count, actor_uuid, 'lease_renewed',
    jsonb_build_object('lease_expires_at', renewed_until)
  );
  return renewed_until;
end;
$$;

create or replace function public.transition_source_qualification_work_by_runtime_policy(
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
  work_record public.source_qualification_work_items%rowtype;
  adapter_record public.catalog_domain_adapters%rowtype;
  runtime_policy public.agent_job_runtime_policies%rowtype;
  next_status text;
  next_available_at timestamptz;
begin
  select * into strict work_record
  from public.source_qualification_work_items
  where id = work_item_uuid for update;
  if work_record.status <> 'claimed' then return work_record.status; end if;
  select * into strict adapter_record from public.catalog_domain_adapters
  where data_type = work_record.data_type and active;
  select * into strict runtime_policy
  from public.current_agent_job_runtime_policy(adapter_record.specialist_job_type);
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
  update public.source_qualification_attempts
  set ended_at = now(),
      outcome = case when next_status = 'retry_wait' then 'retry' else next_status end,
      failure_category = failure_category_value,
      failure_reason = failure_reason_value
  where work_item_id = work_record.id
    and attempt_number = work_record.attempt_count and ended_at is null;
  update public.source_qualification_work_items
  set status = next_status,
      available_at = coalesce(next_available_at, available_at),
      claimed_by_actor_id = null, lease_token = null, lease_expires_at = null,
      failure_category = failure_category_value,
      failure_reason = failure_reason_value,
      completed_at = case when next_status = 'failed' then now() else null end,
      updated_at = now()
  where id = work_record.id;
  insert into public.source_qualification_work_events(
    work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    work_record.id, work_record.attempt_count, work_record.claimed_by_actor_id,
    next_status, jsonb_build_object(
      'failure_category', failure_category_value,
      'failure_reason', failure_reason_value,
      'available_at', next_available_at,
      'runtime_policy_id', runtime_policy.id
    )
  );
  return next_status;
end;
$$;

create or replace function public.report_source_qualification_work_failure(
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
  work_record public.source_qualification_work_items%rowtype;
begin
  select * into strict work_record
  from public.source_qualification_work_items where id = work_item_uuid;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value
     or work_record.lease_expires_at <= now() then
    raise exception 'An active source-qualification lease owned by this actor is required';
  end if;
  return public.transition_source_qualification_work_by_runtime_policy(
    work_item_uuid, failure_category_value, failure_reason_value
  );
end;
$$;

create or replace function public.canonical_source_qualification_clean_cases(
  enrollment_uuid uuid
)
returns table (
  subject_type text,
  subject_id text,
  outcome text
)
language sql
stable
security definer
set search_path = ''
as $$
  with target_profile as (
    select public.canonical_trusted_source_id(enrollment.source_id)
             as canonical_source_id,
           enrollment.data_type
    from public.source_qualification_enrollments enrollment
    where enrollment.id = enrollment_uuid
  )
  select observation.subject_type, observation.subject_id,
         min(observation.outcome) as outcome
  from target_profile target
  join public.source_qualification_enrollments enrollment
    on enrollment.data_type = target.data_type
   and public.canonical_trusted_source_id(enrollment.source_id)
       = target.canonical_source_id
  join public.source_qualification_observations observation
    on observation.enrollment_id = enrollment.id
  group by observation.subject_type, observation.subject_id
  having count(distinct observation.outcome) = 1;
$$;

create or replace function public.team_color_source_qualification_coverage(
  enrollment_uuid uuid
)
returns table (
  applicable_team_count integer,
  tested_applicable_team_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  with target_enrollment as (
    select public.canonical_trusted_source_id(enrollment.source_id) as source_id,
           enrollment.data_type
    from public.source_qualification_enrollments enrollment
    where enrollment.id = enrollment_uuid
      and enrollment.data_type = 'team_colors'
  ), applicable_teams as (
    select distinct team.id
    from target_enrollment enrollment
    join public.catalog_teams team on true
    left join public.team_primary_league_versions membership
      on membership.team_id = team.id and membership.is_current
    where exists (
      select 1
      from public.source_applicability_versions applicability
      where public.canonical_trusted_source_id(applicability.source_id)
              = enrollment.source_id
        and applicability.data_type = enrollment.data_type
        and applicability.is_current
        and applicability.review_status = 'approved'
        and applicability.effective_from <= now()
        and (applicability.effective_to is null
          or applicability.effective_to >= now())
        and (
          applicability.applicability_kind = 'global'
          or (applicability.applicability_kind = 'sport'
            and applicability.sport_id = team.sport_id)
          or (applicability.applicability_kind = 'league'
            and applicability.league_id = membership.league_id)
          or (applicability.applicability_kind = 'team'
            and applicability.team_id = team.id)
        )
    )
  ), tested_teams as (
    select distinct team.id
    from applicable_teams team
    join public.canonical_source_qualification_clean_cases(enrollment_uuid) clean_case
      on clean_case.subject_type = 'catalog_team'
     and clean_case.subject_id = team.id::text
  )
  select
    (select count(*)::integer from applicable_teams),
    (select count(*)::integer from tested_teams);
$$;

create or replace function public.evaluate_source_qualification(
  enrollment_uuid uuid,
  force_canonical_merge_evaluation boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_enrollment public.source_qualification_enrollments%rowtype;
  enrollment_record public.source_qualification_enrollments%rowtype;
  policy_record public.source_qualification_policies%rowtype;
  canonical_source_uuid uuid;
  canonical_enrollment_uuid uuid;
  assessed_count integer;
  matches_count integer;
  contradictions_count integer;
  rate_value numeric;
  evaluation_kind_value text;
  decision_basis_value text := 'standard_case_threshold';
  applicable_count integer;
  tested_applicable_count integer;
  narrow_decision_ready boolean := false;
  case_projection_key text;
  evaluation_input_key_value text;
  next_status text;
  evaluation_uuid uuid;
begin
  select * into strict requested_enrollment
  from public.source_qualification_enrollments
  where id = enrollment_uuid;
  canonical_source_uuid := public.canonical_trusted_source_id(
    requested_enrollment.source_id
  );
  select enrollment.id into canonical_enrollment_uuid
  from public.source_qualification_enrollments enrollment
  where enrollment.source_id = canonical_source_uuid
    and enrollment.data_type = requested_enrollment.data_type;
  if canonical_enrollment_uuid is null then
    canonical_enrollment_uuid := public.ensure_source_qualification_enrollment(
      canonical_source_uuid, requested_enrollment.data_type
    );
  end if;
  if canonical_enrollment_uuid is null then return null; end if;
  select * into strict enrollment_record
  from public.source_qualification_enrollments
  where id = canonical_enrollment_uuid for update;
  select * into strict policy_record
  from public.source_qualification_policies
  where id = enrollment_record.current_policy_id;
  select count(*)::integer,
         count(*) filter (where outcome = 'match')::integer,
         count(*) filter (where outcome = 'contradiction')::integer,
         md5(coalesce(jsonb_agg(
           jsonb_build_array(subject_type, subject_id, outcome)
           order by subject_type, subject_id
         )::text, '[]'))
    into assessed_count, matches_count, contradictions_count,
         case_projection_key
  from public.canonical_source_qualification_clean_cases(
    enrollment_record.id
  );
  rate_value := case when assessed_count = 0 then null
    else matches_count::numeric / assessed_count end;
  update public.source_qualification_enrollments
  set assessed_case_count = assessed_count,
      match_count = matches_count,
      contradiction_count = contradictions_count,
      raw_match_rate = rate_value,
      updated_at = now()
  where id = enrollment_record.id;

  if enrollment_record.data_type = 'team_colors' then
    select coverage.applicable_team_count,
           coverage.tested_applicable_team_count
      into applicable_count, tested_applicable_count
    from public.team_color_source_qualification_coverage(
      enrollment_record.id
    ) coverage;
    narrow_decision_ready :=
      applicable_count >= policy_record.first_rating_case_count
      and applicable_count < policy_record.first_decision_case_count
      and tested_applicable_count = applicable_count;
  end if;

  if force_canonical_merge_evaluation then
    evaluation_kind_value := case
      when assessed_count < policy_record.first_decision_case_count
           and not narrow_decision_ready then 'reconciliation'
      when exists (
        select 1
        from public.source_qualification_evaluations prior_evaluation
        where prior_evaluation.id = enrollment_record.latest_evaluation_id
          and prior_evaluation.evaluation_kind in ('decision','reassessment')
      ) then 'reassessment'
      else 'decision'
    end;
    decision_basis_value := case
      when narrow_decision_ready then 'narrow_exhaustive_coverage'
      else 'canonical_merge_reassessment'
    end;
    next_status := case
      when assessed_count >= policy_record.first_decision_case_count
        and rate_value >= policy_record.qualification_rate then 'qualified'
      when assessed_count >= policy_record.first_decision_case_count
        and rate_value >= policy_record.probationary_rate then 'probationary'
      when assessed_count >= policy_record.first_decision_case_count
        then 'rejected'
      when narrow_decision_ready
        and rate_value >= policy_record.qualification_rate then 'qualified'
      else 'probationary'
    end;
  elsif narrow_decision_ready then
    evaluation_kind_value := case
      when exists (
        select 1
        from public.source_qualification_evaluations prior_evaluation
        where prior_evaluation.id = enrollment_record.latest_evaluation_id
          and prior_evaluation.evaluation_kind in ('decision','reassessment')
      ) then 'reassessment'
      else 'decision'
    end;
    decision_basis_value := 'narrow_exhaustive_coverage';
    next_status := case
      when rate_value >= policy_record.qualification_rate then 'qualified'
      when rate_value >= policy_record.probationary_rate then 'probationary'
      else 'rejected'
    end;
  elsif assessed_count = policy_record.first_rating_case_count then
    evaluation_kind_value := 'rating';
    next_status := 'probationary';
  elsif assessed_count >= policy_record.first_decision_case_count
        and (assessed_count - policy_record.first_decision_case_count)
          % policy_record.reassessment_case_interval = 0 then
    evaluation_kind_value := case
      when assessed_count = policy_record.first_decision_case_count
        then 'decision' else 'reassessment' end;
    next_status := case
      when rate_value >= policy_record.qualification_rate then 'qualified'
      when rate_value >= policy_record.probationary_rate then 'probationary'
      else 'rejected'
    end;
  else
    return null;
  end if;
  evaluation_input_key_value := md5(concat_ws(':',
    policy_record.id::text,
    case_projection_key,
    decision_basis_value,
    case when narrow_decision_ready then applicable_count::text end,
    case when narrow_decision_ready then tested_applicable_count::text end
  ));
  insert into public.source_qualification_evaluations(
    enrollment_id, policy_id,
    assessed_case_count, match_count, contradiction_count, raw_match_rate,
    evaluation_kind, decision_basis,
    applicable_subject_count, tested_applicable_subject_count,
    evaluation_input_key, resulting_status, prior_status
  ) values (
    enrollment_record.id, policy_record.id,
    assessed_count, matches_count, contradictions_count, rate_value,
    evaluation_kind_value, decision_basis_value,
    case when narrow_decision_ready then applicable_count end,
    case when narrow_decision_ready then tested_applicable_count end,
    evaluation_input_key_value,
    next_status, enrollment_record.qualification_status
  )
  on conflict (enrollment_id, evaluation_input_key) do nothing
  returning id into evaluation_uuid;
  if evaluation_uuid is null then
    select id into strict evaluation_uuid
    from public.source_qualification_evaluations
    where enrollment_id = enrollment_record.id
      and evaluation_input_key = evaluation_input_key_value;
  end if;
  update public.source_qualification_enrollments
  set qualification_status = next_status,
      latest_evaluation_id = evaluation_uuid,
      updated_at = now()
  where id = enrollment_record.id;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    public.current_catalog_actor_id(), auth.uid(),
    'source.qualification_evaluated', 'source_qualification_enrollment',
    enrollment_record.id::text, jsonb_build_object(
      'source_id', enrollment_record.source_id,
      'requested_enrollment_id', requested_enrollment.id,
      'data_type', enrollment_record.data_type,
      'assessed_case_count', assessed_count,
      'match_count', matches_count,
      'contradiction_count', contradictions_count,
      'raw_match_rate', rate_value,
      'evaluation_kind', evaluation_kind_value,
      'decision_basis', decision_basis_value,
      'evaluation_input_key', evaluation_input_key_value,
      'applicable_subject_count',
        case when narrow_decision_ready then applicable_count end,
      'tested_applicable_subject_count',
        case when narrow_decision_ready then tested_applicable_count end,
      'prior_status', enrollment_record.qualification_status,
      'resulting_status', next_status,
      'policy_id', policy_record.id
    )
  );
  return evaluation_uuid;
end;
$$;

create or replace function public.reconcile_canonical_source_qualification(
  source_uuid uuid,
  data_type_value text,
  force_canonical_merge_evaluation boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  canonical_source_uuid uuid := public.canonical_trusted_source_id(source_uuid);
  canonical_enrollment_uuid uuid;
begin
  canonical_enrollment_uuid := public.ensure_source_qualification_enrollment(
    canonical_source_uuid, data_type_value
  );
  if canonical_enrollment_uuid is null then return null; end if;
  return public.evaluate_source_qualification(
    canonical_enrollment_uuid, force_canonical_merge_evaluation
  );
end;
$$;

create or replace function public.adjudicate_source_qualification_subject(
  data_type_value text,
  subject_type_value text,
  subject_id_value text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_record record;
  policy_record public.source_qualification_policies%rowtype;
  adapter_record public.catalog_domain_adapters%rowtype;
  target_root_uuid uuid;
  reference_kind_value text;
  authoritative_adjudication_uuid uuid;
  resolved_reference jsonb;
  candidate_result jsonb;
  candidate_count integer;
  reference_uuid uuid;
  contribution_record record;
  contribution_count integer;
  outcome_value text;
  observed_count integer := 0;
begin
  perform pg_advisory_xact_lock(hashtextextended(
    data_type_value || ':' || subject_type_value || ':' || subject_id_value, 0
  ));
  select * into strict policy_record
  from public.source_qualification_policies
  where data_type = data_type_value and is_current and active;
  select * into strict adapter_record
  from public.catalog_domain_adapters
  where data_type = data_type_value and active;
  for target_record in
    select result.id as result_id, result.normalized_result,
           result.result_payload, result.source_id,
           result.applicability_version_id,
           result.information_lineage_version_id,
           work.enrollment_id, work.subject_type, work.subject_id
    from public.source_qualification_results result
    join public.source_qualification_work_items work on work.id = result.work_item_id
    where work.data_type = data_type_value
      and work.subject_type = subject_type_value
      and work.subject_id = subject_id_value
      and result.result_kind = 'determinate'
      and not exists (
        select 1 from public.source_qualification_observations observation
        where observation.tested_result_id = result.id
      )
    order by result.submitted_at, result.id
  loop
    target_root_uuid := public.current_information_lineage_root(
      target_record.information_lineage_version_id
    );
    if target_root_uuid is null then continue; end if;
    reference_kind_value := null;
    authoritative_adjudication_uuid := null;
    resolved_reference := null;
    candidate_result := null;
    contribution_count := 0;

    if adapter_record.resolve_source_qualification_reference_function is not null then
      execute format('select %s($1,$2,$3,$4)',
        adapter_record.resolve_source_qualification_reference_function::regproc)
        using subject_type_value, subject_id_value, target_record.source_id,
              target_record.information_lineage_version_id
        into resolved_reference;
    end if;
    if resolved_reference is not null
       and resolved_reference ->> 'reference_kind' = 'verified_fact' then
      authoritative_adjudication_uuid :=
        (resolved_reference ->> 'authoritative_adjudication_id')::uuid;
      candidate_result := resolved_reference -> 'normalized_reference_result';
      select count(distinct public.current_information_lineage_root(
               contribution.information_lineage_version_id
             ))
        into contribution_count
      from public.catalog_adjudication_source_contributions contribution
      join public.catalog_determinate_adjudications adjudication
        on adjudication.id = contribution.adjudication_id
      where contribution.adjudication_id = authoritative_adjudication_uuid
        and contribution.supports_authoritative_result
        and adjudication.data_type = data_type_value
        and adjudication.subject_type = subject_type_value
        and adjudication.subject_id = subject_id_value
        and contribution.information_lineage_version_id is not null
        and public.current_information_lineage_root(
              contribution.information_lineage_version_id
            ) is not null;
      if candidate_result is not null
         and contribution_count >= policy_record.minimum_reference_information_lineages
         and not exists (
           select 1
           from public.catalog_adjudication_source_contributions contribution
           where contribution.adjudication_id = authoritative_adjudication_uuid
             and (
               public.canonical_trusted_source_id(contribution.source_id)
                 = target_record.source_id
               or contribution.information_lineage_version_id is null
               or public.current_information_lineage_root(
                    contribution.information_lineage_version_id
                  ) is null
               or public.current_information_lineage_root(
                    contribution.information_lineage_version_id
                  ) = target_root_uuid
             )
         ) then
        reference_kind_value := 'verified_fact';
      else
        authoritative_adjudication_uuid := null;
        candidate_result := null;
        contribution_count := 0;
      end if;
    end if;

    if reference_kind_value is null then
      select count(*), (jsonb_agg(candidate.normalized_result) -> 0)
        into candidate_count, candidate_result
      from (
        select peer.normalized_result
        from public.source_qualification_results peer
        join public.source_qualification_work_items peer_work
          on peer_work.id = peer.work_item_id
        join public.information_lineage_versions peer_lineage
          on peer_lineage.id = peer.information_lineage_version_id
        where peer_work.data_type = data_type_value
          and peer_work.subject_type = subject_type_value
          and peer_work.subject_id = subject_id_value
          and peer.result_kind = 'determinate'
          and peer.source_id <> target_record.source_id
          and peer_lineage.is_current
          and peer_lineage.review_status = 'approved'
          and public.current_information_lineage_root(
            peer.information_lineage_version_id
          ) is not null
          and public.current_information_lineage_root(
            peer.information_lineage_version_id
          ) <> target_root_uuid
        group by peer.normalized_result
        having count(distinct public.current_information_lineage_root(
          peer.information_lineage_version_id
        )) >= policy_record.minimum_reference_information_lineages
      ) candidate;
      if candidate_count <> 1 then continue; end if;
      reference_kind_value := 'bootstrap_consensus';
      contribution_count := policy_record.minimum_reference_information_lineages;
    end if;

    insert into public.source_qualification_references(
      tested_result_id, reference_kind, authoritative_adjudication_id,
      data_type, subject_type, subject_id,
      normalized_reference_result, tested_source_id,
      tested_information_lineage_root_id,
      contributing_information_lineage_count, policy_id
    ) values (
      target_record.result_id, reference_kind_value,
      authoritative_adjudication_uuid, data_type_value, subject_type_value,
      subject_id_value, candidate_result, target_record.source_id,
      target_root_uuid, contribution_count,
      policy_record.id
    )
    on conflict (tested_result_id) do nothing
    returning id into reference_uuid;
    if reference_uuid is null then continue; end if;

    contribution_count := 0;
    if reference_kind_value = 'verified_fact' then
      for contribution_record in
        select distinct on (current_root.lineage_root)
               contribution.id as adjudication_source_contribution_id,
               contribution.source_id,
               contribution.information_lineage_version_id,
               current_root.lineage_root
        from public.catalog_adjudication_source_contributions contribution
        cross join lateral (
          select public.current_information_lineage_root(
            contribution.information_lineage_version_id
          ) as lineage_root
        ) current_root
        where contribution.adjudication_id = authoritative_adjudication_uuid
          and contribution.supports_authoritative_result
          and current_root.lineage_root is not null
        order by current_root.lineage_root, contribution.created_at, contribution.id
      loop
        insert into public.source_qualification_reference_contributions(
          reference_id, adjudication_source_contribution_id, source_id,
          information_lineage_version_id, information_lineage_root_id
        ) values (
          reference_uuid,
          contribution_record.adjudication_source_contribution_id,
          contribution_record.source_id,
          contribution_record.information_lineage_version_id,
          contribution_record.lineage_root
        );
        contribution_count := contribution_count + 1;
      end loop;
    else
      for contribution_record in
        select distinct on (peer_root.lineage_root)
               peer.id as result_id, peer.source_id,
               peer.information_lineage_version_id,
               peer_root.lineage_root
        from public.source_qualification_results peer
        join public.source_qualification_work_items peer_work
          on peer_work.id = peer.work_item_id
        join public.information_lineage_versions peer_lineage
          on peer_lineage.id = peer.information_lineage_version_id
        cross join lateral (
          select public.current_information_lineage_root(
            peer.information_lineage_version_id
          ) as lineage_root
        ) peer_root
        where peer_work.data_type = data_type_value
          and peer_work.subject_type = subject_type_value
          and peer_work.subject_id = subject_id_value
          and peer.result_kind = 'determinate'
          and peer.normalized_result = candidate_result
          and peer.source_id <> target_record.source_id
          and peer_lineage.is_current
          and peer_lineage.review_status = 'approved'
          and peer_root.lineage_root is not null
          and peer_root.lineage_root <> target_root_uuid
        order by peer_root.lineage_root, peer.submitted_at, peer.id
        limit policy_record.minimum_reference_information_lineages
      loop
        insert into public.source_qualification_reference_contributions(
          reference_id, result_id, source_id,
          information_lineage_version_id, information_lineage_root_id
        ) values (
          reference_uuid, contribution_record.result_id,
          contribution_record.source_id,
          contribution_record.information_lineage_version_id,
          contribution_record.lineage_root
        );
        contribution_count := contribution_count + 1;
      end loop;
    end if;
    if contribution_count < policy_record.minimum_reference_information_lineages then
      raise exception 'Qualification reference lost required independent lineages';
    end if;
    if adapter_record.compare_source_qualification_result_function is null then
      raise exception 'The data type has no source-qualification comparator';
    end if;
    execute format('select %s($1,$2)',
      adapter_record.compare_source_qualification_result_function::regproc)
      using target_record.normalized_result, candidate_result
      into outcome_value;
    if outcome_value not in ('match','contradiction') then
      raise exception 'The source-qualification comparator returned an invalid outcome';
    end if;
    insert into public.source_qualification_observations(
      enrollment_id, tested_result_id, reference_id,
      subject_type, subject_id, outcome,
      tested_claim_snapshot, reference_result_snapshot,
      tested_source_id, tested_applicability_version_id,
      tested_information_lineage_version_id,
      tested_information_lineage_root_id
    ) values (
      target_record.enrollment_id, target_record.result_id, reference_uuid,
      subject_type_value, subject_id_value, outcome_value,
      target_record.result_payload, candidate_result,
      target_record.source_id, target_record.applicability_version_id,
      target_record.information_lineage_version_id,
      target_root_uuid
    );
    perform public.evaluate_source_qualification(target_record.enrollment_id);
    observed_count := observed_count + 1;
  end loop;
  return observed_count;
end;
$$;

create or replace function public.submit_source_qualification_result(
  work_item_uuid uuid,
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
  work_record public.source_qualification_work_items%rowtype;
  enrollment_record public.source_qualification_enrollments%rowtype;
  adapter_record public.catalog_domain_adapters%rowtype;
  attempt_uuid uuid;
  result_uuid uuid;
  normalized_value jsonb;
begin
  select * into strict work_record
  from public.source_qualification_work_items where id = work_item_uuid for update;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value
     or work_record.lease_expires_at <= now() then
    raise exception 'An active source-qualification lease owned by this actor is required';
  end if;
  if not public.has_catalog_capability(
    'source.qualification.work',
    nullif(work_record.capability_scope ->> 'sport_id','')::uuid,
    nullif(work_record.capability_scope ->> 'league_id','')::uuid,
    nullif(work_record.capability_scope ->> 'team_id','')::uuid,
    nullif(work_record.capability_scope ->> 'venue_id','')::uuid
  ) then
    raise exception 'Scoped source-qualification work capability is required';
  end if;
  if result_kind_value not in ('determinate','unresolved') then
    raise exception 'Invalid source-qualification result kind';
  end if;
  if result_kind_value = 'unresolved'
     and nullif(btrim(provenance_summary_value), '') is null then
    raise exception 'An unresolved result requires an explanation';
  end if;
  select * into strict adapter_record from public.catalog_domain_adapters
  where data_type = work_record.data_type and active;
  if result_kind_value = 'determinate' then
    execute format('select %s($1)',
      adapter_record.normalize_source_qualification_result_function::regproc)
      using result_payload_value into normalized_value;
    if normalized_value is null then
      raise exception 'The source claim does not satisfy the domain result contract';
    end if;
  end if;
  select * into strict enrollment_record
  from public.source_qualification_enrollments
  where id = work_record.enrollment_id;
  select id into strict attempt_uuid
  from public.source_qualification_attempts
  where work_item_id = work_record.id
    and attempt_number = work_record.attempt_count
    and actor_id = actor_uuid and ended_at is null;
  insert into public.source_qualification_results(
    work_item_id, attempt_id, submitted_by_actor_id,
    result_kind, result_payload, normalized_result,
    source_id, applicability_version_id, source_location,
    information_lineage_version_id, provenance_summary
  ) values (
    work_record.id, attempt_uuid, actor_uuid,
    result_kind_value, coalesce(result_payload_value, '{}'::jsonb), normalized_value,
    enrollment_record.source_id,
    work_record.applicability_version_id,
    work_record.assigned_source_location,
    work_record.information_lineage_version_id,
    provenance_summary_value
  ) returning id into result_uuid;
  update public.source_qualification_attempts
  set ended_at = now(), outcome = case
    when result_kind_value = 'determinate' then 'completed' else 'unresolved' end
  where id = attempt_uuid;
  update public.source_qualification_work_items
  set status = 'completed', accepted_result_id = result_uuid,
      claimed_by_actor_id = null, lease_token = null, lease_expires_at = null,
      completed_at = now(), updated_at = now()
  where id = work_record.id;
  insert into public.source_qualification_work_events(
    work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    work_record.id, work_record.attempt_count, actor_uuid, 'result_submitted',
    jsonb_build_object('result_id', result_uuid, 'result_kind', result_kind_value)
  );
  if result_kind_value = 'determinate' then
    perform public.adjudicate_source_qualification_subject(
      work_record.data_type, work_record.subject_type, work_record.subject_id
    );
  end if;
  return result_uuid;
end;
$$;

create or replace function public.emit_source_qualification_work_wake()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('queued','retry_wait')
     and (tg_op = 'INSERT' or old.status is distinct from new.status
       or old.available_at is distinct from new.available_at) then
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

create trigger emit_source_qualification_work_wake
after insert or update of status, available_at
on public.source_qualification_work_items
for each row execute function public.emit_source_qualification_work_wake();

create or replace function public.expire_source_qualification_work_leases(
  data_type_value text default null
)
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
    from public.source_qualification_work_items work
    where work.status = 'claimed' and work.lease_expires_at <= now()
      and (data_type_value is null or work.data_type = data_type_value)
    for update skip locked
  loop
    perform public.transition_source_qualification_work_by_runtime_policy(
      expired.id, 'lease_expired', 'Source-qualification work lease expired.'
    );
    expired_count := expired_count + 1;
  end loop;
  return expired_count;
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
    and (data_type_value is null or work.data_type = data_type_value)
  on conflict (queue_name, work_item_id, event_kind, eligibility_key)
  do update set status = 'pending', acknowledged_at = null,
                acknowledged_by_actor_id = null;
  get diagnostics reconciled_count = row_count;
  return reconciled_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Production evidence gate and exact qualification snapshots
-- ---------------------------------------------------------------------------

alter table public.catalog_proposal_evidence
  add column source_qualification_evaluation_id uuid
    references public.source_qualification_evaluations(id),
  add column source_qualification_snapshot jsonb not null default '{}'::jsonb;

alter table public.catalog_verifier_evidence
  add column source_qualification_evaluation_id uuid
    references public.source_qualification_evaluations(id);

create or replace function public.current_source_qualification_snapshot(
  source_uuid uuid,
  data_type_value text,
  applicability_version_uuid uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  canonical_source_uuid uuid := public.canonical_trusted_source_id(source_uuid);
  applicability_record public.source_applicability_versions%rowtype;
  enrollment_record public.source_qualification_enrollments%rowtype;
  evaluation_record public.source_qualification_evaluations%rowtype;
  evaluation_policy_record public.source_qualification_policies%rowtype;
  current_applicable_count integer;
  current_tested_applicable_count integer;
  narrow_coverage_is_current boolean := true;
begin
  select * into applicability_record
  from public.source_applicability_versions
  where id = applicability_version_uuid;
  if applicability_record.id is null
     or applicability_record.data_type <> data_type_value
     or public.canonical_trusted_source_id(applicability_record.source_id)
        <> canonical_source_uuid then
    return jsonb_build_object(
      'data_type', data_type_value,
      'qualification_status', 'probationary',
      'production_evidence_eligible', false,
      'reason', 'missing_applicability'
    );
  end if;
  select * into enrollment_record
  from public.source_qualification_enrollments enrollment
  where enrollment.source_id = canonical_source_uuid
    and enrollment.data_type = data_type_value;
  if enrollment_record.id is null then
    return jsonb_build_object(
      'data_type', data_type_value,
      'qualification_status', 'probationary',
      'production_evidence_eligible', false,
      'reason', 'not_enrolled'
    );
  end if;
  if enrollment_record.latest_evaluation_id is not null then
    select * into evaluation_record
    from public.source_qualification_evaluations
    where id = enrollment_record.latest_evaluation_id;
  end if;
  if evaluation_record.decision_basis = 'narrow_exhaustive_coverage' then
    select * into strict evaluation_policy_record
    from public.source_qualification_policies
    where id = evaluation_record.policy_id;
    select coverage.applicable_team_count,
           coverage.tested_applicable_team_count
      into current_applicable_count, current_tested_applicable_count
    from public.team_color_source_qualification_coverage(
      enrollment_record.id
    ) coverage;
    narrow_coverage_is_current :=
      current_applicable_count >= evaluation_policy_record.first_rating_case_count
      and current_applicable_count
        < evaluation_policy_record.first_decision_case_count
      and current_tested_applicable_count = current_applicable_count;
  end if;
  return jsonb_strip_nulls(jsonb_build_object(
    'enrollment_id', enrollment_record.id,
    'source_id', canonical_source_uuid,
    'data_type', data_type_value,
    'applicability_kind', applicability_record.applicability_kind,
    'applicability_version_id', applicability_version_uuid,
    'policy_id', enrollment_record.current_policy_id,
    'qualification_status', enrollment_record.qualification_status,
    'assessed_case_count', enrollment_record.assessed_case_count,
    'match_count', enrollment_record.match_count,
    'contradiction_count', enrollment_record.contradiction_count,
    'raw_match_rate', enrollment_record.raw_match_rate,
    'evaluation_id', evaluation_record.id,
    'evaluation_kind', evaluation_record.evaluation_kind,
    'decision_basis', evaluation_record.decision_basis,
    'applicable_subject_count', case
      when evaluation_record.decision_basis = 'narrow_exhaustive_coverage'
        then current_applicable_count
    end,
    'tested_applicable_subject_count', case
      when evaluation_record.decision_basis = 'narrow_exhaustive_coverage'
        then current_tested_applicable_count
    end,
    'production_evidence_eligible',
      enrollment_record.qualification_status = 'qualified'
      and evaluation_record.id is not null
      and evaluation_record.resulting_status = 'qualified'
      and narrow_coverage_is_current
      and applicability_record.is_current
      and applicability_record.review_status = 'approved'
  ));
end;
$$;

create or replace function public.enforce_factual_source_qualification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  data_type_value text;
  snapshot_value jsonb;
begin
  if tg_table_name = 'catalog_proposal_evidence' then
    select proposal.fact_type into strict data_type_value
    from public.catalog_change_proposals proposal where proposal.id = new.proposal_id;
  else
    select work.data_type into strict data_type_value
    from public.catalog_verification_work_items work
    where work.id = new.verification_work_item_id;
  end if;
  if not exists (
    select 1 from public.source_qualification_policies policy
    where policy.data_type = data_type_value and policy.is_current and policy.active
  ) then
    return new;
  end if;
  snapshot_value := public.current_source_qualification_snapshot(
    new.source_id, data_type_value, new.source_applicability_version_id
  );
  if not coalesce((snapshot_value ->> 'production_evidence_eligible')::boolean, false) then
    raise exception 'Source is not currently qualified for production % evidence', data_type_value;
  end if;
  new.source_qualification_evaluation_id :=
    (snapshot_value ->> 'evaluation_id')::uuid;
  new.source_qualification_snapshot := snapshot_value;
  return new;
end;
$$;

create trigger enforce_proposal_source_qualification
before insert on public.catalog_proposal_evidence
for each row execute function public.enforce_factual_source_qualification();

create trigger enforce_verifier_source_qualification
before insert on public.catalog_verifier_evidence
for each row execute function public.enforce_factual_source_qualification();

create or replace function public.enforce_current_factual_source_qualification_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  proposal_record public.catalog_change_proposals%rowtype;
  authoritative_palette jsonb;
begin
  if new.decision <> 'approved' then return new; end if;
  select * into strict proposal_record
  from public.catalog_change_proposals where id = new.proposal_id;
  if not exists (
    select 1 from public.source_qualification_policies policy
    where policy.data_type = proposal_record.fact_type
      and policy.is_current and policy.active
  ) then
    return new;
  end if;
  if proposal_record.fact_type = 'team_colors' then
    authoritative_palette := public.team_color_palette_from_payload(
      coalesce(new.authoritative_result_payload, proposal_record.payload)
    );
    if exists (
      select 1
      from public.catalog_proposal_evidence evidence
      where evidence.proposal_id = proposal_record.id
        and evidence.supports_proposal
        and evidence.structured_claim ->> 'classification' = 'current_canonical'
        and evidence.structured_claim -> 'palette' = authoritative_palette
        and not coalesce((public.current_source_qualification_snapshot(
          evidence.source_id, proposal_record.fact_type,
          evidence.source_applicability_version_id
        ) ->> 'production_evidence_eligible')::boolean, false)
    ) then
      raise exception 'An unqualified source contributes to the Team Color proposal';
    end if;
    if exists (
      select 1
      from public.catalog_verifier_evidence evidence
      join public.catalog_verification_work_items work
        on work.id = evidence.verification_work_item_id
      where work.specialist_result_kind = 'catalog_proposal'
        and work.specialist_result_id = proposal_record.id
        and not coalesce((public.current_source_qualification_snapshot(
          evidence.source_id, proposal_record.fact_type,
          evidence.source_applicability_version_id
        ) ->> 'production_evidence_eligible')::boolean, false)
    ) then
      raise exception 'An unqualified source contributes to Team Color verification';
    end if;
  end if;
  new.policy_snapshot := new.policy_snapshot || jsonb_build_object(
    'empirical_source_qualification_required', true,
    'probationary_or_rejected_production_evidence_permitted', false
  );
  return new;
end;
$$;

create trigger zz_enforce_current_factual_source_qualification_decision
before insert on public.catalog_verification_decisions
for each row execute function public.enforce_current_factual_source_qualification_decision();

-- ---------------------------------------------------------------------------
-- Shared worker-pool concurrency and watchdog integration
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
    +
    (select count(*) from public.source_qualification_work_items where status = 'claimed')
  into globally_claimed;
  if globally_claimed >= operating_policy.maximum_concurrent_operational_workers then
    raise exception 'The global operational-worker concurrency limit of % is already reached',
      operating_policy.maximum_concurrent_operational_workers;
  end if;
  return new;
end;
$$;

create trigger enforce_source_qualification_concurrency
before insert or update of status on public.source_qualification_work_items
for each row execute function public.enforce_agent_worker_concurrency();

create or replace function public.recover_team_color_domain()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  expired_count integer := 0;
  qualification_expired_count integer := 0;
  qualification_wakes_reconciled integer := 0;
  repaired_count integer := 0;
  bootstrap_queued_count integer := 0;
  stranded record;
begin
  expired_count := public.expire_team_color_work_leases();
  qualification_expired_count :=
    public.expire_source_qualification_work_leases('team_colors');
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
  bootstrap_queued_count := public.dispatch_pending_team_color_bootstrap_revalidations();
  qualification_wakes_reconciled :=
    public.reconcile_source_qualification_wakes('team_colors');
  return jsonb_build_object(
    'expired_specialist_leases', expired_count,
    'expired_source_qualification_leases', qualification_expired_count,
    'verification_jobs_repaired', repaired_count,
    'bootstrap_revalidations_queued', bootstrap_queued_count,
    'source_qualification_wakes_reconciled', qualification_wakes_reconciled
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- History protection, permissions, and worker-facing grants
-- ---------------------------------------------------------------------------

create trigger source_qualification_policy_history_protected
before update or delete on public.source_qualification_policies
for each row execute function public.protect_versioned_agent_policy_history();

create trigger source_qualification_evaluations_append_only
before update or delete on public.source_qualification_evaluations
for each row execute function public.protect_agent_backend_history();

create trigger source_qualification_results_append_only
before update or delete on public.source_qualification_results
for each row execute function public.protect_agent_backend_history();

create trigger catalog_adjudication_source_contributions_append_only
before update or delete on public.catalog_adjudication_source_contributions
for each row execute function public.protect_agent_backend_history();

create trigger source_qualification_references_append_only
before update or delete on public.source_qualification_references
for each row execute function public.protect_agent_backend_history();

create trigger source_qualification_reference_contributions_append_only
before update or delete on public.source_qualification_reference_contributions
for each row execute function public.protect_agent_backend_history();

create trigger source_qualification_observations_append_only
before update or delete on public.source_qualification_observations
for each row execute function public.protect_agent_backend_history();

create trigger source_qualification_work_events_append_only
before update or delete on public.source_qualification_work_events
for each row execute function public.protect_agent_backend_history();

alter table public.source_qualification_policies enable row level security;
alter table public.source_qualification_enrollments enable row level security;
alter table public.source_qualification_evaluations enable row level security;
alter table public.source_qualification_work_items enable row level security;
alter table public.source_qualification_attempts enable row level security;
alter table public.source_qualification_work_events enable row level security;
alter table public.source_qualification_results enable row level security;
alter table public.catalog_adjudication_source_contributions enable row level security;
alter table public.source_qualification_references enable row level security;
alter table public.source_qualification_reference_contributions enable row level security;
alter table public.source_qualification_observations enable row level security;

revoke all on public.source_qualification_policies from public, anon, authenticated;
revoke all on public.source_qualification_enrollments from public, anon, authenticated;
revoke all on public.source_qualification_evaluations from public, anon, authenticated;
revoke all on public.source_qualification_work_items from public, anon, authenticated;
revoke all on public.source_qualification_attempts from public, anon, authenticated;
revoke all on public.source_qualification_work_events from public, anon, authenticated;
revoke all on public.source_qualification_results from public, anon, authenticated;
revoke all on public.catalog_adjudication_source_contributions from public, anon, authenticated;
revoke all on public.source_qualification_references from public, anon, authenticated;
revoke all on public.source_qualification_reference_contributions from public, anon, authenticated;
revoke all on public.source_qualification_observations from public, anon, authenticated;

create policy "Authorized staff read source qualification policies"
on public.source_qualification_policies for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
create policy "Authorized staff read source qualification enrollments"
on public.source_qualification_enrollments for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
create policy "Authorized staff read source qualification evaluations"
on public.source_qualification_evaluations for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
create policy "Authorized staff read source qualification work"
on public.source_qualification_work_items for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
create policy "Authorized staff read source qualification attempts"
on public.source_qualification_attempts for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
create policy "Authorized staff read source qualification events"
on public.source_qualification_work_events for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
create policy "Authorized staff read source qualification results"
on public.source_qualification_results for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
create policy "Authorized staff read adjudication source contributions"
on public.catalog_adjudication_source_contributions for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
create policy "Authorized staff read source qualification references"
on public.source_qualification_references for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
create policy "Authorized staff read source qualification contributions"
on public.source_qualification_reference_contributions for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
create policy "Authorized staff read source qualification observations"
on public.source_qualification_observations for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);

grant select on
  public.source_qualification_policies,
  public.source_qualification_enrollments,
  public.source_qualification_evaluations,
  public.source_qualification_work_items,
  public.source_qualification_attempts,
  public.source_qualification_work_events,
  public.source_qualification_results,
  public.catalog_adjudication_source_contributions,
  public.source_qualification_references,
  public.source_qualification_reference_contributions,
  public.source_qualification_observations
to authenticated;

revoke all on function public.ensure_source_qualification_enrollment(uuid,text)
from public, anon, authenticated;
revoke all on function public.enroll_approved_source_applicability()
from public, anon, authenticated;
revoke all on function public.build_team_color_source_qualification_context(text,text)
from public, anon, authenticated;
revoke all on function public.normalize_team_color_source_qualification_result(jsonb)
from public, anon, authenticated;
revoke all on function public.compare_team_color_source_qualification_result(jsonb,jsonb)
from public, anon, authenticated;
revoke all on function public.record_team_color_adjudication_source_contributions(uuid)
from public, anon, authenticated;
revoke all on function public.resolve_team_color_source_qualification_reference(text,text,uuid,uuid)
from public, anon, authenticated;
revoke all on function public.capture_catalog_adjudication_source_contributions()
from public, anon, authenticated;
revoke all on function public.admin_register_source_qualification_adapter(text,regproc,regproc,regproc,regproc,regproc)
from public, anon;
grant execute on function public.admin_register_source_qualification_adapter(text,regproc,regproc,regproc,regproc,regproc)
to authenticated;
revoke all on function public.enqueue_source_qualification_work(uuid,text,text,text,text,integer,timestamptz)
from public, anon;
grant execute on function public.enqueue_source_qualification_work(uuid,text,text,text,text,integer,timestamptz)
to authenticated;
revoke all on function public.get_my_source_qualification_work(uuid,uuid)
from public, anon;
grant execute on function public.get_my_source_qualification_work(uuid,uuid)
to authenticated;
revoke all on function public.claim_next_source_qualification_work(text)
from public, anon;
grant execute on function public.claim_next_source_qualification_work(text)
to authenticated;
revoke all on function public.renew_source_qualification_work_lease(uuid,uuid)
from public, anon;
grant execute on function public.renew_source_qualification_work_lease(uuid,uuid)
to authenticated;
revoke all on function public.report_source_qualification_work_failure(uuid,uuid,text,text)
from public, anon;
grant execute on function public.report_source_qualification_work_failure(uuid,uuid,text,text)
to authenticated;
revoke all on function public.submit_source_qualification_result(uuid,uuid,text,jsonb,text)
from public, anon;
grant execute on function public.submit_source_qualification_result(uuid,uuid,text,jsonb,text)
to authenticated;
revoke all on function public.transition_source_qualification_work_by_runtime_policy(uuid,text,text)
from public, anon, authenticated;
revoke all on function public.canonical_source_qualification_clean_cases(uuid)
from public, anon, authenticated;
revoke all on function public.team_color_source_qualification_coverage(uuid)
from public, anon, authenticated;
revoke all on function public.evaluate_source_qualification(uuid,boolean)
from public, anon, authenticated;
revoke all on function public.reconcile_canonical_source_qualification(uuid,text,boolean)
from public, anon, authenticated;
revoke all on function public.adjudicate_source_qualification_subject(text,text,text)
from public, anon, authenticated;
revoke all on function public.expire_source_qualification_work_leases(text)
from public, anon, authenticated;
revoke all on function public.reconcile_source_qualification_wakes(text)
from public, anon, authenticated;
revoke all on function public.current_source_qualification_snapshot(uuid,text,uuid)
from public, anon, authenticated;
revoke all on function public.enforce_factual_source_qualification()
from public, anon, authenticated;
revoke all on function public.enforce_current_factual_source_qualification_decision()
from public, anon, authenticated;
revoke all on function public.emit_source_qualification_work_wake()
from public, anon, authenticated;

comment on table public.source_qualification_enrollments is
  'Current empirical qualification state scoped only by canonical source and factual data type; applicability remains per-case governance metadata.';
comment on table public.source_qualification_work_items is
  'Generic durable blinded source-claim queue using registered domain context and result adapters.';
comment on table public.source_qualification_references is
  'Non-production qualification references using an eligible verified fact when independent, otherwise at least three matching bootstrap lineages.';
comment on table public.source_qualification_observations is
  'Immutable clean match or contradiction used by deterministic source-qualification evaluations.';
comment on function public.canonical_source_qualification_clean_cases(uuid) is
  'Current canonical source/data-type clean-case projection. Duplicate alias observations count once; conflicting outcomes for one subject are excluded without rewriting history.';
comment on function public.team_color_source_qualification_coverage(uuid) is
  'Backend-derived distinct tested-team coverage of the current approved Team Color applicability universe for the narrow-source exception.';
