#!/usr/bin/env bash
set -euo pipefail

database_container="supabase_db_fanatical-local"
database_command=(docker exec -i "$database_container" psql -U postgres -d postgres -v ON_ERROR_STOP=1)
proposal_a="88000000-0000-0000-0000-000000000001"
proposal_b="88000000-0000-0000-0000-000000000002"

cleanup() {
  "${database_command[@]}" >/dev/null <<'SQL'
alter table public.team_color_versions disable trigger protect_verified_version;
delete from public.team_color_bootstrap_verified_teams
where team_id in (
  select id from public.catalog_teams where team_id in ('hockey-889991','hockey-889992')
);
update public.team_color_bootstrap_rollout_state
set fresh_verified_team_count = 0,
    threshold_reached_at = null,
    threshold_decision_id = null,
    updated_at = now();
delete from public.catalog_fact_revalidation_state
where data_type = 'team_colors'
  and subject_id in (
    select id::text from public.catalog_teams
    where team_id in ('hockey-889991','hockey-889992')
  );
delete from public.team_color_versions
where team_id in (
  select id from public.catalog_teams where team_id in ('hockey-889991','hockey-889992')
);
alter table public.team_color_versions enable trigger protect_verified_version;
delete from public.catalog_verification_decisions
where proposal_id in (
  '88000000-0000-0000-0000-000000000001'::uuid,
  '88000000-0000-0000-0000-000000000002'::uuid
);
delete from public.catalog_change_proposals
where id in (
  '88000000-0000-0000-0000-000000000001'::uuid,
  '88000000-0000-0000-0000-000000000002'::uuid
);
delete from public.catalog_teams where team_id in ('hockey-889991','hockey-889992');
delete from public.catalog_actors where actor_key = 'team-color-bootstrap-concurrency-test';
SQL
}

trap cleanup EXIT
cleanup

"${database_command[@]}" >/dev/null <<'SQL'
insert into public.catalog_actors(actor_key, actor_type, display_name)
values (
  'team-color-bootstrap-concurrency-test', 'human',
  'Team Color Bootstrap Concurrency Test'
);
insert into public.catalog_teams(team_id, sport_id)
select fixture.team_id, sport.id
from (values ('hockey-889991'), ('hockey-889992')) fixture(team_id)
cross join public.catalog_sports sport
where sport.sport_id = 'hockey';

insert into public.catalog_change_proposals(
  id, fact_type, operation, target_team_id, payload, status,
  proposed_by_actor_id, team_color_change_kind, proposal_reason
)
select fixture.proposal_id, 'team_colors', 'replace', team.id,
       jsonb_build_object('primary', '#112233', 'secondary', '#445566'),
       'approved', actor.id, 'fill_missing_or_unverified',
       'Concurrent threshold fixture.'
from (values
  ('88000000-0000-0000-0000-000000000001'::uuid, 'hockey-889991'),
  ('88000000-0000-0000-0000-000000000002'::uuid, 'hockey-889992')
) fixture(proposal_id, team_public_id)
join public.catalog_teams team on team.team_id = fixture.team_public_id
cross join public.catalog_actors actor
where actor.actor_key = 'team-color-bootstrap-concurrency-test';

alter table public.catalog_verification_decisions
  disable trigger enforce_catalog_verification_policy_decision;
alter table public.catalog_verification_decisions
  disable trigger enforce_current_team_color_evidence_decision;
alter table public.catalog_verification_decisions
  disable trigger zz_enforce_team_color_information_lineage_decision;
insert into public.catalog_verification_decisions(
  proposal_id, decision, policy_id, decided_by_actor_id, notes
)
select proposal.id, 'approved', policy.id, actor.id,
       'Concurrent threshold fixture.'
from public.catalog_change_proposals proposal
cross join public.verification_policies policy
cross join public.catalog_actors actor
where proposal.id in (
    '88000000-0000-0000-0000-000000000001'::uuid,
    '88000000-0000-0000-0000-000000000002'::uuid
  )
  and policy.data_type = 'team_colors' and policy.is_current and policy.active
  and actor.actor_key = 'team-color-bootstrap-concurrency-test';
alter table public.catalog_verification_decisions
  enable trigger enforce_catalog_verification_policy_decision;
alter table public.catalog_verification_decisions
  enable trigger enforce_current_team_color_evidence_decision;
alter table public.catalog_verification_decisions
  enable trigger zz_enforce_team_color_information_lineage_decision;

insert into public.team_color_versions(
  team_id, primary_color, secondary_color, record_status,
  verification_decision_id
)
select proposal.target_team_id, '#112233', '#445566', 'verified', decision.id
from public.catalog_change_proposals proposal
join public.catalog_verification_decisions decision
  on decision.proposal_id = proposal.id
where proposal.id in (
  '88000000-0000-0000-0000-000000000001'::uuid,
  '88000000-0000-0000-0000-000000000002'::uuid
);

update public.team_color_bootstrap_rollout_state
set fresh_verified_team_count = 99,
    threshold_reached_at = null,
    threshold_decision_id = null,
    updated_at = now();
SQL

"${database_command[@]}" >/dev/null <<SQL &
begin;
select id from public.team_color_bootstrap_rollout_state for update;
select pg_sleep(0.4);
select public.record_team_color_bootstrap_completion('$proposal_a'::uuid);
commit;
SQL
first_pid=$!
sleep 0.1
"${database_command[@]}" >/dev/null <<SQL &
select public.record_team_color_bootstrap_completion('$proposal_b'::uuid);
SQL
second_pid=$!
wait "$first_pid"
wait "$second_pid"

"${database_command[@]}" >/dev/null <<'SQL'
do $$
declare threshold_decision uuid;
begin
  select state.threshold_decision_id into strict threshold_decision
  from public.team_color_bootstrap_rollout_state state;
  if not exists (
    select 1 from public.team_color_bootstrap_rollout_state
    where fresh_verified_team_count = 101
      and threshold_reached_at is not null
      and threshold_decision_id is not null
  ) then
    raise exception 'Concurrent completions did not serialize to one 100-team threshold';
  end if;
  if not exists (
    select 1
    from public.team_color_bootstrap_verified_teams enrolled
    where enrolled.enrollment_ordinal = 100
      and enrolled.first_verification_decision_id = threshold_decision
  ) then
    raise exception 'Threshold decision does not belong to ordinal 100';
  end if;
  if (select count(*) from public.team_color_bootstrap_verified_teams
      where enrollment_ordinal in (100, 101)) <> 2 then
    raise exception 'Concurrent completions did not receive distinct ordinals';
  end if;
end;
$$;
SQL

echo "Passed Team Color bootstrap two-session threshold concurrency test."
