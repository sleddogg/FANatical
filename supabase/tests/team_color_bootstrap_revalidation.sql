-- Focused transactional coverage for the one-time Team Color bootstrap
-- revalidation rollout. All fixtures roll back.

begin;

create or replace function pg_temp.assert_true(value boolean, message text)
returns void
language plpgsql
as $$
begin
  if not coalesce(value, false) then
    raise exception 'Team Color bootstrap assertion failed: %', message;
  end if;
end;
$$;

-- The rollout begins from no Team Color factual or transactional result data.
do $$
begin
  perform pg_temp.assert_true(not exists (select 1 from public.team_color_versions),
    'Team Color versions must be empty after the rollout reset');
  perform pg_temp.assert_true(not exists (
    select 1 from public.catalog_change_proposals where fact_type = 'team_colors'
  ), 'Team Color proposals must be empty after the rollout reset');
  perform pg_temp.assert_true(not exists (select 1 from public.team_color_work_items),
    'Team Color specialist work must be empty after the rollout reset');
  perform pg_temp.assert_true(not exists (
    select 1 from public.catalog_verification_work_items where data_type = 'team_colors'
  ), 'Team Color verifier work must be empty after the rollout reset');
  perform pg_temp.assert_true(not exists (
    select 1 from public.catalog_fact_revalidation_state where data_type = 'team_colors'
  ), 'Team Color revalidation state must be empty after the rollout reset');
  perform pg_temp.assert_true(not exists (
    select 1 from public.team_color_source_reliability_observations
  ), 'Team Color reliability outcomes must be empty after the rollout reset');
end;
$$;

insert into public.catalog_actors(actor_key, actor_type, display_name)
values ('team-color-bootstrap-test-verifier', 'human', 'Bootstrap Test Verifier');

insert into public.catalog_teams(team_id, sport_id)
select 'hockey-' || (880000 + series)::text, sport.id
from generate_series(1, 101) series
cross join public.catalog_sports sport
where sport.sport_id = 'hockey';

-- These enforcement triggers are unrelated to enrollment and require the full
-- evidence/verifier workflow. The helper below creates already-authoritative
-- completions so this test can isolate the 20/100 transition itself.
alter table public.catalog_verification_decisions
  disable trigger enforce_catalog_verification_policy_decision;
alter table public.catalog_verification_decisions
  disable trigger enforce_current_team_color_evidence_decision;
alter table public.catalog_verification_decisions
  disable trigger zz_enforce_team_color_information_lineage_decision;

create or replace function pg_temp.complete_team_color_verification(
  public_team_id text,
  recheck_trigger_value text default null
)
returns uuid
language plpgsql
as $$
declare
  team_uuid uuid;
  actor_uuid uuid;
  policy_uuid uuid;
  proposal_uuid uuid;
  decision_uuid uuid;
begin
  select id into strict team_uuid
  from public.catalog_teams where team_id = public_team_id;
  select id into strict actor_uuid
  from public.catalog_actors where actor_key = 'team-color-bootstrap-test-verifier';
  select id into strict policy_uuid
  from public.verification_policies
  where data_type = 'team_colors' and is_current and active;

  insert into public.catalog_change_proposals(
    fact_type, operation, target_team_id, payload, status,
    proposed_by_actor_id, team_color_change_kind, proposal_reason,
    recheck_trigger
  ) values (
    'team_colors', 'replace', team_uuid,
    jsonb_build_object('primary', '#112233', 'secondary', '#445566'),
    'rejected', actor_uuid, 'fill_missing_or_unverified',
    'Bootstrap enrollment test fixture.', recheck_trigger_value
  ) returning id into proposal_uuid;

  insert into public.catalog_verification_decisions(
    proposal_id, decision, policy_id, decided_by_actor_id, notes
  ) values (
    proposal_uuid, 'approved', policy_uuid, actor_uuid,
    'Authoritative completion fixture for bootstrap transition testing.'
  ) returning id into decision_uuid;

  insert into public.team_color_versions(
    team_id, primary_color, secondary_color, record_status,
    verification_decision_id
  ) values (
    team_uuid, '#112233', '#445566', 'verified', decision_uuid
  );

  update public.catalog_change_proposals
  set status = 'approved', resolved_at = now()
  where id = proposal_uuid;
  return proposal_uuid;
end;
$$;

-- Rechecks do not enroll or increment the fresh-team total.
select pg_temp.complete_team_color_verification(
  'hockey-880101', 'manual_request'
);
do $$
begin
  perform pg_temp.assert_true((
    select fresh_verified_team_count = 0
    from public.team_color_bootstrap_rollout_state
  ), 'a recheck must not count as a fresh verified team');
  perform pg_temp.assert_true(not exists (
    select 1 from public.team_color_bootstrap_verified_teams
  ), 'a recheck must not enroll in the bootstrap rollout');
end;
$$;

-- The first 20 distinct fresh completions become the durable cohort.
do $$
declare series integer;
begin
  for series in 1..20 loop
    perform pg_temp.complete_team_color_verification(
      'hockey-' || (880000 + series)::text
    );
  end loop;
  perform pg_temp.assert_true((
    select fresh_verified_team_count = 20 and threshold_reached_at is null
    from public.team_color_bootstrap_rollout_state
  ), 'the first 20 fresh teams must enroll without firing the threshold');
  perform pg_temp.assert_true((
    select count(*) = 20 and bool_and(is_bootstrap_cohort)
      and min(enrollment_ordinal) = 1 and max(enrollment_ordinal) = 20
    from public.team_color_bootstrap_verified_teams
  ), 'exactly the first 20 distinct teams must form the bootstrap cohort');
  perform pg_temp.assert_true(not exists (
    select 1 from public.team_color_work_items
    where recheck_trigger = 'bootstrap_revalidation'
  ), 'bootstrap work must not queue before 100 fresh teams');
end;
$$;

-- Replaying a completion is idempotent and cannot consume another ordinal.
do $$
declare proposal_uuid uuid;
begin
  select first_verification_decision_id into strict proposal_uuid
  from public.team_color_bootstrap_verified_teams
  where enrollment_ordinal = 1;
  select proposal_id into strict proposal_uuid
  from public.catalog_verification_decisions where id = proposal_uuid;
  perform pg_temp.assert_true(
    not public.record_team_color_bootstrap_completion(proposal_uuid),
    'replaying an already-enrolled completion must return false'
  );
  perform pg_temp.assert_true((
    select fresh_verified_team_count = 20
    from public.team_color_bootstrap_rollout_state
  ), 'replaying a completion must not increment the total');
end;
$$;

do $$
declare series integer;
begin
  for series in 21..99 loop
    perform pg_temp.complete_team_color_verification(
      'hockey-' || (880000 + series)::text
    );
  end loop;
  perform pg_temp.assert_true((
    select fresh_verified_team_count = 99 and threshold_reached_at is null
    from public.team_color_bootstrap_rollout_state
  ), '99 fresh teams must remain below the trigger');
  perform pg_temp.assert_true(not exists (
    select 1 from public.team_color_work_items
    where recheck_trigger = 'bootstrap_revalidation'
  ), '99 fresh teams must not queue bootstrap work');
end;
$$;

-- The 100th distinct fresh completion atomically marks the threshold and queues
-- each original cohort member exactly once, without changing verified facts.
select pg_temp.complete_team_color_verification('hockey-880100');
do $$
begin
  perform pg_temp.assert_true((
    select fresh_verified_team_count = 100
      and threshold_reached_at is not null
      and threshold_decision_id is not null
    from public.team_color_bootstrap_rollout_state
  ), 'the 100th fresh team must durably record the threshold');
  perform pg_temp.assert_true((
    select count(*) = 20
      and bool_and(bootstrap_due_at is not null)
      and bool_and(bootstrap_work_item_id is not null)
      and bool_and(bootstrap_queued_at is not null)
    from public.team_color_bootstrap_verified_teams
    where is_bootstrap_cohort
  ), 'all 20 original cohort members must be durably dispatched');
  perform pg_temp.assert_true((
    select count(*) = 20 and count(distinct team_id) = 20
    from public.team_color_work_items
    where work_kind = 'verified_recheck'
      and recheck_trigger = 'bootstrap_revalidation'
  ), 'each bootstrap team must receive exactly one revalidation job');
  perform pg_temp.assert_true((
    select count(*) = 100 and count(*) filter (
      where is_current and record_status = 'verified'
    ) = 100
    from public.team_color_versions colors
    join public.team_color_bootstrap_verified_teams enrolled
      on enrolled.first_verified_version_id = colors.id
  ), 'queued bootstrap revalidation must preserve all existing verified values');
end;
$$;

-- Repeat dispatch and post-threshold completions prove one-time behavior.
do $$
declare queued_count integer;
begin
  queued_count := public.dispatch_pending_team_color_bootstrap_revalidations();
  perform pg_temp.assert_true(queued_count = 0,
    'repeated dispatch must not create duplicate bootstrap jobs');
  perform pg_temp.assert_true((
    select count(*) = 20 from public.team_color_work_items
    where recheck_trigger = 'bootstrap_revalidation'
  ), 'repeated dispatch must leave the bootstrap job count at 20');
end;
$$;

-- A confirmed bootstrap result re-enters the already-approved six-month
-- lifecycle through the same canonical revalidation-state writer.
do $$
declare
  cohort_member public.team_color_bootstrap_verified_teams%rowtype;
begin
  select * into strict cohort_member
  from public.team_color_bootstrap_verified_teams
  where enrollment_ordinal = 1;
  perform public.record_team_color_revalidation_state(
    cohort_member.team_id,
    cohort_member.first_verified_version_id,
    cohort_member.first_verification_decision_id,
    'confirmed_no_change',
    'bootstrap_revalidation',
    'Bootstrap confirmation test fixture.'
  );
  perform pg_temp.assert_true((
    select next_review_at = last_verified_at + interval '6 months'
      and last_review_outcome = 'confirmed_no_change'
      and last_review_trigger = 'bootstrap_revalidation'
      and active_job_type is null and active_job_id is null
    from public.catalog_fact_revalidation_state
    where data_type = 'team_colors'
      and subject_type = 'catalog_team'
      and subject_id = cohort_member.team_id::text
  ), 'a confirmed bootstrap result must return to the normal six-month lifecycle');
end;
$$;

-- Structural assertions cover the race boundary: concurrent completions lock
-- the same rollout-state row, while distinct-team, ordinal, and job uniqueness
-- constraints reject any duplicate winner.
do $$
declare completion_definition text;
begin
  select pg_get_functiondef(
    'public.record_team_color_bootstrap_completion(uuid)'::regprocedure
  ) into completion_definition;
  perform pg_temp.assert_true(
    completion_definition ilike '%team_color_bootstrap_rollout_state%for update%',
    'fresh-completion registration must serialize on the rollout-state row'
  );
  perform pg_temp.assert_true((
    select count(*) >= 3
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'team_color_bootstrap_verified_teams'
      and indexdef ilike '%unique%'
  ), 'database uniqueness must protect team, ordinal, and work-item races');
end;
$$;

alter table public.catalog_verification_decisions
  enable trigger enforce_catalog_verification_policy_decision;
alter table public.catalog_verification_decisions
  enable trigger enforce_current_team_color_evidence_decision;
alter table public.catalog_verification_decisions
  enable trigger zz_enforce_team_color_information_lineage_decision;

rollback;
