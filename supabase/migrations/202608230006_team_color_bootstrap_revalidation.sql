-- Reset Team Color factual/result state and add the approved one-time rollout
-- bootstrap revalidation policy. Generic agent infrastructure and source
-- governance remain unchanged.

-- ---------------------------------------------------------------------------
-- Approved factual/result reset
-- ---------------------------------------------------------------------------

create temporary table team_color_reset_proposals as
select id from public.catalog_change_proposals where fact_type = 'team_colors';

create temporary table team_color_reset_work as
select id from public.team_color_work_items;

create temporary table team_color_reset_verification_work as
select id from public.catalog_verification_work_items where data_type = 'team_colors';

create temporary table team_color_reset_proposal_evidence as
select id from public.catalog_proposal_evidence
where proposal_id in (select id from team_color_reset_proposals);

create temporary table team_color_reset_verifier_evidence as
select evidence.id
from public.catalog_verifier_evidence evidence
where evidence.verification_work_item_id in (
  select id from team_color_reset_verification_work
);

create temporary table team_color_reset_lineage_work as
select work.id
from public.information_lineage_resolution_work_items work
where (work.evidence_kind = 'proposal_evidence'
       and work.evidence_id in (select id from team_color_reset_proposal_evidence))
   or (work.evidence_kind = 'verifier_evidence'
       and work.evidence_id in (select id from team_color_reset_verifier_evidence));

create temporary table team_color_reset_decisions as
select id from public.catalog_verification_decisions
where proposal_id in (select id from team_color_reset_proposals);

alter table public.catalog_audit_events disable trigger catalog_audit_append_only;
alter table public.team_color_work_events disable trigger team_color_work_events_append_only;
alter table public.team_color_source_reliability_observations
  disable trigger team_color_source_reliability_append_only;
alter table public.catalog_verification_work_events
  disable trigger catalog_verification_work_events_append_only;
alter table public.catalog_verifier_evidence
  disable trigger catalog_verifier_evidence_append_only;
alter table public.catalog_verifier_results
  disable trigger catalog_verifier_results_append_only;
alter table public.catalog_verification_comparisons
  disable trigger catalog_verification_comparisons_append_only;
alter table public.catalog_determinate_adjudications
  disable trigger catalog_determinate_adjudications_append_only;
alter table public.information_lineage_resolution_results
  disable trigger information_lineage_resolution_results_append_only;
alter table public.catalog_evidence_lineage_assignments
  disable trigger catalog_evidence_lineage_assignments_append_only;
alter table public.team_color_versions disable trigger protect_verified_version;

delete from public.agent_work_wake_outbox
where work_item_id in (select id from team_color_reset_work)
   or work_item_id in (select id from team_color_reset_verification_work)
   or work_item_id in (select id from team_color_reset_lineage_work);

delete from public.catalog_evidence_lineage_assignments assignment
where (assignment.evidence_kind = 'proposal_evidence'
       and assignment.evidence_id in (select id from team_color_reset_proposal_evidence))
   or (assignment.evidence_kind = 'verifier_evidence'
       and assignment.evidence_id in (select id from team_color_reset_verifier_evidence));

delete from public.information_lineage_resolution_attempts
where work_item_id in (select id from team_color_reset_lineage_work);
delete from public.information_lineage_resolution_results
where work_item_id in (select id from team_color_reset_lineage_work);
delete from public.information_lineage_resolution_work_items
where id in (select id from team_color_reset_lineage_work);

delete from public.team_color_source_reliability_observations;
delete from public.catalog_verification_comparisons
where verification_work_item_id in (select id from team_color_reset_verification_work)
   or proposal_id in (select id from team_color_reset_proposals);
delete from public.catalog_determinate_adjudications
where data_type = 'team_colors'
   or catalog_verification_decision_id in (select id from team_color_reset_decisions);

update public.catalog_verification_work_items
set accepted_result_id = null
where id in (select id from team_color_reset_verification_work);
delete from public.catalog_verifier_results
where verification_work_item_id in (select id from team_color_reset_verification_work);
delete from public.catalog_verifier_evidence
where verification_work_item_id in (select id from team_color_reset_verification_work);
delete from public.catalog_verification_attempts
where verification_work_item_id in (select id from team_color_reset_verification_work);
delete from public.catalog_verification_work_events
where verification_work_item_id in (select id from team_color_reset_verification_work);
delete from public.catalog_verification_work_items
where id in (select id from team_color_reset_verification_work);

delete from public.catalog_audit_events
where proposal_id in (select id from team_color_reset_proposals)
   or entity_type = 'team_colors'
   or (
     action = 'source.candidate_submitted'
     and details ->> 'work_item_id' in (
       select id::text from team_color_reset_work
     )
   );
delete from public.catalog_fact_revalidation_state where data_type = 'team_colors';

update public.catalog_change_proposals
set team_color_work_item_id = null,
    expected_current_color_version_id = null
where id in (select id from team_color_reset_proposals);
update public.team_color_work_items
set proposal_id = null,
    expected_current_color_version_id = null
where id in (select id from team_color_reset_work);
delete from public.team_color_work_items
where id in (select id from team_color_reset_work);

delete from public.team_color_versions;
delete from public.catalog_verification_decisions
where id in (select id from team_color_reset_decisions);
delete from public.catalog_change_proposals
where id in (select id from team_color_reset_proposals);

alter table public.catalog_audit_events enable trigger catalog_audit_append_only;
alter table public.team_color_work_events enable trigger team_color_work_events_append_only;
alter table public.team_color_source_reliability_observations
  enable trigger team_color_source_reliability_append_only;
alter table public.catalog_verification_work_events
  enable trigger catalog_verification_work_events_append_only;
alter table public.catalog_verifier_evidence
  enable trigger catalog_verifier_evidence_append_only;
alter table public.catalog_verifier_results
  enable trigger catalog_verifier_results_append_only;
alter table public.catalog_verification_comparisons
  enable trigger catalog_verification_comparisons_append_only;
alter table public.catalog_determinate_adjudications
  enable trigger catalog_determinate_adjudications_append_only;
alter table public.information_lineage_resolution_results
  enable trigger information_lineage_resolution_results_append_only;
alter table public.catalog_evidence_lineage_assignments
  enable trigger catalog_evidence_lineage_assignments_append_only;
alter table public.team_color_versions enable trigger protect_verified_version;

-- ---------------------------------------------------------------------------
-- Controlled Team Color bootstrap recheck vocabulary and policy snapshot
-- ---------------------------------------------------------------------------

alter table public.team_color_work_items
  drop constraint team_color_work_items_recheck_trigger_check;
alter table public.team_color_work_items
  add constraint team_color_work_items_recheck_trigger_check
  check (recheck_trigger in (
    'scheduled_review', 'known_real_world_event',
    'detected_conflict_or_mismatch', 'manual_request',
    'bootstrap_revalidation'
  ));

alter table public.catalog_change_proposals
  drop constraint catalog_team_color_recheck_trigger_check;
alter table public.catalog_change_proposals
  add constraint catalog_team_color_recheck_trigger_check
  check (recheck_trigger is null or recheck_trigger in (
    'scheduled_review', 'known_real_world_event',
    'detected_conflict_or_mismatch', 'manual_request',
    'bootstrap_revalidation'
  ));

do $$
declare
  prior_policy public.verification_policies%rowtype;
  next_policy_uuid uuid;
  next_version integer;
begin
  select * into strict prior_policy
  from public.verification_policies
  where data_type = 'team_colors' and is_current and active
  for update;
  select coalesce(max(version), 0) + 1 into next_version
  from public.verification_policies
  where policy_key = prior_policy.policy_key;
  update public.verification_policies
  set is_current = false, active = false, superseded_at = now()
  where id = prior_policy.id;
  insert into public.verification_policies(
    policy_key, version, data_type, minimum_evidence_count,
    allowed_trust_tiers, require_independent_sources,
    require_independent_verifier, configuration, is_current, active
  ) values (
    prior_policy.policy_key, next_version, prior_policy.data_type,
    prior_policy.minimum_evidence_count, prior_policy.allowed_trust_tiers,
    prior_policy.require_independent_sources,
    prior_policy.require_independent_verifier,
    jsonb_set(
      prior_policy.configuration,
      '{recheck_triggers}',
      coalesce(prior_policy.configuration -> 'recheck_triggers', '[]'::jsonb)
        || jsonb_build_array('bootstrap_revalidation')
    ),
    true, true
  ) returning id into next_policy_uuid;
  insert into public.catalog_verification_round_policies(
    verification_policy_id, verification_round, minimum_evidence_count,
    minimum_independent_ownership_groups,
    minimum_independent_information_lineages,
    minimum_high_trust_evidence_count, source_selection_policy
  )
  select next_policy_uuid, verification_round, minimum_evidence_count,
         minimum_independent_ownership_groups,
         minimum_independent_information_lineages,
         minimum_high_trust_evidence_count, source_selection_policy
  from public.catalog_verification_round_policies
  where verification_policy_id = prior_policy.id;
end;
$$;

create table public.team_color_bootstrap_rollout_policies (
  id uuid primary key default gen_random_uuid(),
  policy_key text not null,
  version integer not null check (version > 0),
  cohort_size integer not null check (cohort_size > 0),
  trigger_fresh_team_count integer not null
    check (trigger_fresh_team_count >= cohort_size),
  recheck_trigger text not null check (recheck_trigger = 'bootstrap_revalidation'),
  active boolean not null default true,
  is_current boolean not null default true,
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  unique (policy_key, version)
);

create unique index team_color_bootstrap_policy_current_idx
on public.team_color_bootstrap_rollout_policies((is_current))
where is_current and active;

create table public.team_color_bootstrap_rollout_state (
  id uuid primary key default gen_random_uuid(),
  rollout_policy_id uuid not null unique
    references public.team_color_bootstrap_rollout_policies(id),
  fresh_verified_team_count integer not null default 0
    check (fresh_verified_team_count >= 0),
  threshold_reached_at timestamptz,
  threshold_decision_id uuid references public.catalog_verification_decisions(id),
  updated_at timestamptz not null default now(),
  check ((threshold_reached_at is null) = (threshold_decision_id is null))
);

create table public.team_color_bootstrap_verified_teams (
  id uuid primary key default gen_random_uuid(),
  rollout_policy_id uuid not null
    references public.team_color_bootstrap_rollout_policies(id),
  team_id uuid not null references public.catalog_teams(id),
  enrollment_ordinal integer not null check (enrollment_ordinal > 0),
  is_bootstrap_cohort boolean not null,
  first_verification_decision_id uuid not null
    references public.catalog_verification_decisions(id),
  first_verified_version_id uuid not null references public.team_color_versions(id),
  enrolled_at timestamptz not null default now(),
  bootstrap_due_at timestamptz,
  bootstrap_work_item_id uuid references public.team_color_work_items(id),
  bootstrap_queued_at timestamptz,
  unique (rollout_policy_id, team_id),
  unique (rollout_policy_id, enrollment_ordinal),
  unique (bootstrap_work_item_id),
  check ((bootstrap_work_item_id is null) = (bootstrap_queued_at is null)),
  check (not is_bootstrap_cohort or enrollment_ordinal > 0)
);

insert into public.team_color_bootstrap_rollout_policies(
  policy_key, version, cohort_size, trigger_fresh_team_count, recheck_trigger
) values (
  'initial-team-color-bootstrap', 1, 20, 100, 'bootstrap_revalidation'
);

insert into public.team_color_bootstrap_rollout_state(rollout_policy_id)
select id from public.team_color_bootstrap_rollout_policies
where policy_key = 'initial-team-color-bootstrap' and version = 1;

create or replace function public.enqueue_team_color_bootstrap_revalidation(
  cohort_member_uuid uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  member_record public.team_color_bootstrap_verified_teams%rowtype;
  policy_record public.team_color_bootstrap_rollout_policies%rowtype;
  revalidation_record public.catalog_fact_revalidation_state%rowtype;
  decision_actor_uuid uuid;
  work_uuid uuid;
begin
  select * into strict member_record
  from public.team_color_bootstrap_verified_teams
  where id = cohort_member_uuid for update;
  if not member_record.is_bootstrap_cohort
     or member_record.bootstrap_due_at is null
     or member_record.bootstrap_work_item_id is not null then
    return member_record.bootstrap_work_item_id;
  end if;
  select * into strict policy_record
  from public.team_color_bootstrap_rollout_policies
  where id = member_record.rollout_policy_id;
  select * into revalidation_record
  from public.catalog_fact_revalidation_state
  where data_type = 'team_colors'
    and subject_type = 'catalog_team'
    and subject_id = member_record.team_id::text
  for update;
  if revalidation_record.id is null
     or not exists (
       select 1 from public.team_color_versions colors
       where colors.id = revalidation_record.current_fact_version_id
         and colors.team_id = member_record.team_id
         and colors.is_current and colors.record_status = 'verified'
     )
     or exists (
       select 1 from public.team_color_work_items work
       where work.team_id = member_record.team_id
         and work.status in (
           'queued','claimed','retry_wait','pending_verification',
           'blocked','needs_review'
         )
     ) then
    return null;
  end if;
  select decision.decided_by_actor_id into decision_actor_uuid
  from public.catalog_verification_decisions decision
  where decision.id = member_record.first_verification_decision_id;
  begin
    insert into public.team_color_work_items(
      team_id, work_kind, recheck_trigger, request_reason,
      expected_current_color_version_id, created_by_actor_id,
      created_by_auth_user_id
    ) values (
      member_record.team_id, 'verified_recheck', policy_record.recheck_trigger,
      'One-time bootstrap revalidation after 100 distinct fresh Team Color verifications.',
      revalidation_record.current_fact_version_id, decision_actor_uuid, auth.uid()
    ) returning id into work_uuid;
  exception when unique_violation then
    return null;
  end;
  insert into public.team_color_work_events(work_item_id, actor_id, event_type, details)
  values (
    work_uuid, decision_actor_uuid, 'queued',
    jsonb_build_object(
      'work_kind', 'verified_recheck',
      'recheck_trigger', policy_record.recheck_trigger,
      'bootstrap_rollout_policy_id', policy_record.id,
      'bootstrap_cohort_member_id', member_record.id
    )
  );
  update public.catalog_fact_revalidation_state
  set active_job_type = 'team_color_specialist', active_job_id = work_uuid,
      last_review_trigger = policy_record.recheck_trigger,
      last_review_reason = 'The approved Team Color bootstrap threshold was reached.',
      updated_at = now()
  where id = revalidation_record.id;
  update public.team_color_bootstrap_verified_teams
  set bootstrap_work_item_id = work_uuid, bootstrap_queued_at = now()
  where id = member_record.id and bootstrap_work_item_id is null;
  return work_uuid;
end;
$$;

create or replace function public.dispatch_pending_team_color_bootstrap_revalidations()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare pending_member record; work_uuid uuid; queued_count integer := 0;
begin
  for pending_member in
    select member.id
    from public.team_color_bootstrap_verified_teams member
    join public.team_color_bootstrap_rollout_policies policy
      on policy.id = member.rollout_policy_id
    where policy.is_current and policy.active
      and member.is_bootstrap_cohort
      and member.bootstrap_due_at is not null
      and member.bootstrap_work_item_id is null
    order by member.enrollment_ordinal
    for update of member skip locked
  loop
    work_uuid := public.enqueue_team_color_bootstrap_revalidation(pending_member.id);
    if work_uuid is not null then queued_count := queued_count + 1; end if;
  end loop;
  return queued_count;
end;
$$;

create or replace function public.record_team_color_bootstrap_completion(
  proposal_uuid uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  proposal_record public.catalog_change_proposals%rowtype;
  policy_record public.team_color_bootstrap_rollout_policies%rowtype;
  state_record public.team_color_bootstrap_rollout_state%rowtype;
  decision_uuid uuid;
  version_uuid uuid;
  next_ordinal integer;
  inserted_member_uuid uuid;
begin
  select * into strict proposal_record
  from public.catalog_change_proposals where id = proposal_uuid;
  if proposal_record.fact_type <> 'team_colors'
     or proposal_record.status <> 'approved'
     or proposal_record.recheck_trigger is not null then
    return false;
  end if;
  select decision.id into decision_uuid
  from public.catalog_verification_decisions decision
  where decision.proposal_id = proposal_record.id and decision.decision = 'approved';
  select colors.id into version_uuid
  from public.team_color_versions colors
  where colors.team_id = proposal_record.target_team_id
    and colors.verification_decision_id = decision_uuid
    and colors.is_current and colors.record_status = 'verified';
  if decision_uuid is null or version_uuid is null then return false; end if;

  select * into strict policy_record
  from public.team_color_bootstrap_rollout_policies
  where is_current and active;
  select * into strict state_record
  from public.team_color_bootstrap_rollout_state
  where rollout_policy_id = policy_record.id
  for update;
  if exists (
    select 1 from public.team_color_bootstrap_verified_teams
    where rollout_policy_id = policy_record.id
      and team_id = proposal_record.target_team_id
  ) then
    return false;
  end if;
  next_ordinal := state_record.fresh_verified_team_count + 1;
  insert into public.team_color_bootstrap_verified_teams(
    rollout_policy_id, team_id, enrollment_ordinal, is_bootstrap_cohort,
    first_verification_decision_id, first_verified_version_id
  ) values (
    policy_record.id, proposal_record.target_team_id, next_ordinal,
    next_ordinal <= policy_record.cohort_size, decision_uuid, version_uuid
  )
  returning id into inserted_member_uuid;
  update public.team_color_bootstrap_rollout_state
  set fresh_verified_team_count = next_ordinal,
      threshold_reached_at = case
        when next_ordinal = policy_record.trigger_fresh_team_count
             and threshold_reached_at is null then now()
        else threshold_reached_at end,
      threshold_decision_id = case
        when next_ordinal = policy_record.trigger_fresh_team_count
             and threshold_decision_id is null then decision_uuid
        else threshold_decision_id end,
      updated_at = now()
  where id = state_record.id;
  if next_ordinal = policy_record.trigger_fresh_team_count
     and state_record.threshold_reached_at is null then
    update public.team_color_bootstrap_verified_teams
    set bootstrap_due_at = now()
    where rollout_policy_id = policy_record.id
      and is_bootstrap_cohort and bootstrap_due_at is null;
    perform public.dispatch_pending_team_color_bootstrap_revalidations();
  end if;
  return true;
end;
$$;

create or replace function public.enroll_team_color_bootstrap_after_finalization()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status is distinct from new.status
     and new.status = 'approved'
     and new.fact_type = 'team_colors'
     and new.recheck_trigger is null then
    perform public.record_team_color_bootstrap_completion(new.id);
  end if;
  return new;
end;
$$;

create trigger enroll_team_color_bootstrap_after_finalization
after update of status on public.catalog_change_proposals
for each row execute function public.enroll_team_color_bootstrap_after_finalization();

create or replace function public.retry_team_color_bootstrap_after_work_completion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status in ('queued','claimed','retry_wait','pending_verification','blocked','needs_review')
     and new.status in ('completed','failed','cancelled') then
    perform public.dispatch_pending_team_color_bootstrap_revalidations();
  end if;
  return new;
end;
$$;

create trigger retry_team_color_bootstrap_after_work_completion
after update of status on public.team_color_work_items
for each row execute function public.retry_team_color_bootstrap_after_work_completion();

create or replace function public.recover_team_color_domain()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  expired_count integer := 0;
  repaired_count integer := 0;
  bootstrap_queued_count integer := 0;
  stranded record;
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
  bootstrap_queued_count := public.dispatch_pending_team_color_bootstrap_revalidations();
  return jsonb_build_object(
    'expired_specialist_leases', expired_count,
    'verification_jobs_repaired', repaired_count,
    'bootstrap_revalidations_queued', bootstrap_queued_count
  );
end;
$$;

alter table public.team_color_bootstrap_rollout_policies enable row level security;
alter table public.team_color_bootstrap_rollout_state enable row level security;
alter table public.team_color_bootstrap_verified_teams enable row level security;
revoke all on public.team_color_bootstrap_rollout_policies from public, anon, authenticated;
revoke all on public.team_color_bootstrap_rollout_state from public, anon, authenticated;
revoke all on public.team_color_bootstrap_verified_teams from public, anon, authenticated;

create policy "Authorized staff read Team Color bootstrap policy"
on public.team_color_bootstrap_rollout_policies for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
create policy "Authorized staff read Team Color bootstrap state"
on public.team_color_bootstrap_rollout_state for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
create policy "Authorized staff read Team Color bootstrap cohort"
on public.team_color_bootstrap_verified_teams for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
grant select on public.team_color_bootstrap_rollout_policies to authenticated;
grant select on public.team_color_bootstrap_rollout_state to authenticated;
grant select on public.team_color_bootstrap_verified_teams to authenticated;

revoke all on function public.enqueue_team_color_bootstrap_revalidation(uuid)
from public, anon, authenticated;
revoke all on function public.dispatch_pending_team_color_bootstrap_revalidations()
from public, anon, authenticated;
revoke all on function public.record_team_color_bootstrap_completion(uuid)
from public, anon, authenticated;
revoke all on function public.enroll_team_color_bootstrap_after_finalization()
from public, anon, authenticated;
revoke all on function public.retry_team_color_bootstrap_after_work_completion()
from public, anon, authenticated;

comment on table public.team_color_bootstrap_rollout_policies is
  'Versioned one-time Team Color rollout policy; separate from recurring cadence.';
comment on table public.team_color_bootstrap_rollout_state is
  'Concurrency-serialized fresh-team progress and threshold state for one rollout policy.';
comment on table public.team_color_bootstrap_verified_teams is
  'Durable distinct-team enrollment, first-20 cohort membership, and at-most-once bootstrap dispatch.';
