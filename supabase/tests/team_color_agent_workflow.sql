-- Transactional integration coverage for 202608210001_team_color_agent_interface.sql.
-- Run against a disposable/local Supabase database after all migrations:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
--     -f supabase/tests/team_color_agent_workflow.sql
-- The transaction always rolls back its fixture users, teams, sources, and work.

begin;

create or replace function pg_temp.assert_true(condition_value boolean, message_value text)
returns void
language plpgsql
as $$
begin
  if not coalesce(condition_value, false) then
    raise exception 'Team Color Agent integration assertion failed: %', message_value;
  end if;
end;
$$;

create or replace function pg_temp.add_team_color_evidence(
  proposal_id_value uuid,
  source_registry_id text,
  evidence_url_value text,
  evidence_summary_value text,
  observed_at_value timestamptz,
  supports_proposal_value boolean
)
returns uuid
language plpgsql
as $$
declare
  palette_value jsonb;
  result_id uuid;
  lineage_version_id uuid;
begin
  if supports_proposal_value then
    select public.team_color_palette_from_payload(payload) into palette_value
    from public.catalog_change_proposals where id = proposal_id_value;
  else
    palette_value := jsonb_build_array('#010101', '#020202');
  end if;
  result_id := public.add_team_color_proposal_evidence(
    proposal_id_value, source_registry_id, evidence_url_value,
    evidence_summary_value, observed_at_value, supports_proposal_value,
    jsonb_build_object(
      'classification', 'current_canonical',
      'palette', palette_value
    )
  );
  select version.id into strict lineage_version_id
  from public.information_lineages lineage
  join public.information_lineage_versions version
    on version.lineage_id = lineage.id and version.is_current
  where lineage.lineage_key = 'lineage-' || source_registry_id;
  update public.catalog_proposal_evidence
  set information_lineage_version_id = lineage_version_id,
      information_lineage_basis = 'Transactional source-specific lineage fixture.'
  where id = result_id;
  return result_id;
end;
$$;

create or replace function pg_temp.add_team_color_verifier_evidence_pair(
  verification_work_id uuid,
  lease_token_value uuid,
  palette_value jsonb,
  url_suffix text
)
returns void
language plpgsql
as $$
begin
  perform public.add_team_color_verifier_evidence(
    verification_work_id, lease_token_value, 'team-color-test-tier-1',
    'https://official.example/' || url_suffix || '-official',
    'Verifier independently found official evidence.', now(),
    jsonb_build_object('classification','current_canonical','palette',palette_value),
    'lineage-team-color-test-tier-1', 'Official document lineage.'
  );
  perform public.add_team_color_verifier_evidence(
    verification_work_id, lease_token_value, 'team-color-test-tier-3-second',
    'https://second-independent.example/' || url_suffix || '-independent',
    'Verifier independently found corroborating evidence.', now(),
    jsonb_build_object('classification','current_canonical','palette',palette_value),
    'lineage-team-color-test-tier-3-second', 'Independent reference lineage.'
  );
  perform public.add_team_color_verifier_evidence(
    verification_work_id, lease_token_value, 'team-color-test-tier-3',
    'https://independent.example/' || url_suffix || '-additional',
    'Verifier independently found additional corroborating evidence.', now(),
    jsonb_build_object('classification','current_canonical','palette',palette_value),
    'lineage-team-color-test-tier-3', 'Additional independent reference lineage.'
  );
  perform public.add_team_color_verifier_evidence(
    verification_work_id, lease_token_value, 'team-color-test-tier-3-conflict',
    'https://conflict.example/' || url_suffix || '-strongest-applicable',
    'Verifier independently reassessed another applicable source.', now(),
    jsonb_build_object('classification','current_canonical','palette',palette_value),
    'lineage-team-color-test-tier-3-conflict', 'Separately originating reference lineage.'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Isolated auth principals, actors, catalog records, and approved test sources
-- ---------------------------------------------------------------------------

insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'team-color-test-admin@fanatical.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'team-color-test-agent-a@fanatical.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'team-color-test-agent-b@fanatical.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'team-color-test-verifier@fanatical.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'team-color-test-verifier-2@fanatical.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.staff_roles(user_id, role, permissions, is_active)
values ('71000000-0000-0000-0000-000000000001', 'admin', array[]::text[], true);

insert into public.catalog_actors(actor_key, actor_type, auth_user_id, display_name)
values
  ('team-color-test-agent-a', 'agent', '71000000-0000-0000-0000-000000000002', 'Team Color Test Agent A'),
  ('team-color-test-agent-b', 'agent', '71000000-0000-0000-0000-000000000003', 'Team Color Test Agent B'),
  ('team-color-test-verifier', 'human', '71000000-0000-0000-0000-000000000004', 'Team Color Test Verifier'),
  ('team-color-test-verifier-2', 'human', '71000000-0000-0000-0000-000000000005', 'Team Color Test Verifier 2');

insert into public.catalog_teams(team_id, sport_id)
select fixture.team_id, sport.id
from (values
  ('hockey-999988'), ('hockey-999989'), ('hockey-999990'),
  ('hockey-999991'), ('hockey-999992'), ('hockey-999993'), ('hockey-999994'),
  ('hockey-999995'), ('hockey-999996'), ('hockey-999997'), ('hockey-999998'),
  ('hockey-999999')
) fixture(team_id)
cross join public.catalog_sports sport
where sport.sport_id = 'hockey';

insert into public.team_identity_versions(
  team_id, display_name, short_name, active, record_status
)
select team.id, fixture.display_name, fixture.display_name, true, 'imported_unverified'
from (values
  ('hockey-999988', 'Agent Lineage Barrier Test'),
  ('hockey-999989', 'Agent Unresolved Consensus Test'),
  ('hockey-999990', 'Agent Permanent Failure Test'),
  ('hockey-999991', 'Agent Queue Test One'),
  ('hockey-999992', 'Agent Queue Test Two'),
  ('hockey-999993', 'Agent Version Guard Test'),
  ('hockey-999994', 'Agent Verified Replacement Test'),
  ('hockey-999995', 'Agent Contradiction Test'),
  ('hockey-999996', 'Agent No Change Test'),
  ('hockey-999997', 'Agent Lineage Collision Test'),
  ('hockey-999998', 'Agent Wake Recovery Test'),
  ('hockey-999999', 'Agent Revalidation Test')
) fixture(team_id, display_name)
join public.catalog_teams team on team.team_id = fixture.team_id;

insert into public.team_primary_league_versions(team_id, league_id, record_status)
select team.id, league.id, 'imported_unverified'
from public.catalog_teams team
cross join public.catalog_leagues league
where (team.team_id like 'hockey-99999%' or team.team_id = 'hockey-999988')
  and league.league_id = 'hockey-nhl';

insert into public.team_color_versions(
  team_id, primary_color, secondary_color, tertiary_color,
  record_status, effective_from, effective_from_precision
)
select team.id, fixture.primary_color, fixture.secondary_color, '#FFFFFF',
       fixture.record_status, date '2020-01-01', 'day'
from (values
  ('hockey-999993', '#111111', '#222222', 'imported_unverified'),
  ('hockey-999994', '#333333', '#444444', 'verified'),
  ('hockey-999996', '#0A0A0A', '#0B0B0B', 'verified'),
  ('hockey-999999', '#0C0C0C', '#0D0D0D', 'verified')
) fixture(team_id, primary_color, secondary_color, record_status)
join public.catalog_teams team on team.team_id = fixture.team_id;

insert into public.catalog_actor_capabilities(actor_id, capability)
select actor.id, capability.capability
from public.catalog_actors actor
cross join (values
  ('team_colors.work.claim'),
  ('team_colors.work.read'),
  ('team_colors.work.update'),
  ('team_colors.source_candidates.submit'),
  ('catalog.propose.team_colors'),
  ('source.qualification.work')
) capability(capability)
where actor.actor_key = 'team-color-test-agent-a';

-- Agent B is intentionally scoped to one team to exercise scope enforcement.
insert into public.catalog_actor_capabilities(actor_id, capability, team_id)
select actor.id, capability.capability, team.id
from public.catalog_actors actor
cross join (values
  ('team_colors.work.claim'),
  ('team_colors.work.read'),
  ('team_colors.work.update'),
  ('catalog.propose.team_colors')
) capability(capability)
cross join public.catalog_teams team
where actor.actor_key = 'team-color-test-agent-b'
  and team.team_id = 'hockey-999992';

insert into public.catalog_actor_capabilities(actor_id, capability)
select actor.id, 'catalog.verify.team_colors'
from public.catalog_actors actor
where actor.actor_key in ('team-color-test-verifier','team-color-test-verifier-2');

insert into public.catalog_actor_capabilities(actor_id, capability)
select actor.id, 'information_lineage.resolve'
from public.catalog_actors actor
where actor.actor_key = 'team-color-test-verifier-2';

insert into public.source_independence_groups(group_id, display_name)
values
  ('team-color-test-official-owner', 'Test Official Owner'),
  ('team-color-test-independent-owner', 'Test Independent Owner'),
  ('team-color-test-second-independent-owner', 'Test Second Independent Owner'),
  ('team-color-test-third-owner', 'Test Third Owner'),
  ('team-color-test-holdout-owner', 'Test Holdout Owner'),
  ('team-color-test-shared-holdout-owner', 'Test Shared-Lineage Holdout Owner');

insert into public.trusted_sources(
  source_id, display_name, base_url, reference_url,
  independence_group_id, review_status, notes
)
select fixture.source_id, fixture.display_name, fixture.base_url, fixture.reference_url,
       independence.id, 'approved', 'Transactional Team Color Agent test source.'
from (values
  ('team-color-test-tier-1', 'Test Official Brand Guide', 'https://official.example', 'https://official.example/brand.pdf', 'team-color-test-official-owner'),
  ('team-color-test-tier-3', 'Test Independent Color Reference', 'https://independent.example', 'https://independent.example/team-colors', 'team-color-test-independent-owner'),
  ('team-color-test-tier-3-second', 'Test Second Independent Reference', 'https://second-independent.example', 'https://second-independent.example/team-colors', 'team-color-test-second-independent-owner'),
  ('team-color-test-tier-3-conflict', 'Test Conflicting Reference', 'https://conflict.example', 'https://conflict.example/team-colors', 'team-color-test-third-owner'),
  ('team-color-test-holdout', 'Test Qualification Holdout', 'https://holdout.example', 'https://holdout.example/team-colors', 'team-color-test-holdout-owner'),
  ('team-color-test-shared-holdout', 'Test Shared-Lineage Qualification Holdout', 'https://shared-holdout.example', 'https://shared-holdout.example/team-colors', 'team-color-test-shared-holdout-owner')
) fixture(source_id, display_name, base_url, reference_url, group_id)
join public.source_independence_groups independence on independence.group_id = fixture.group_id;

insert into public.source_trust_assignments(source_id, data_type, trust_tier, effective_from, notes)
select source.id, 'team_colors', fixture.trust_tier, current_date, 'Transactional test assignment.'
from (values
  ('team-color-test-tier-1', 1),
  ('team-color-test-tier-3', 3),
  ('team-color-test-tier-3-second', 3),
  ('team-color-test-tier-3-conflict', 3),
  ('team-color-test-holdout', 3),
  ('team-color-test-shared-holdout', 3)
) fixture(source_id, trust_tier)
join public.trusted_sources source on source.source_id = fixture.source_id;

insert into public.source_applicability_versions(
  source_id, data_type, applicability_kind, review_status, notes
)
select source.id, 'team_colors', 'global', 'approved',
       'Transactional Team Color Agent global applicability.'
from public.trusted_sources source
where source.source_id like 'team-color-test-%';

insert into public.source_independence_group_assignment_versions(
  source_id, independence_group_id, review_status, notes
)
select source.id, source.independence_group_id, 'approved',
       'Transactional test ownership assignment.'
from public.trusted_sources source
where source.source_id like 'team-color-test-%';

insert into public.trusted_source_url_scope_versions(
  source_id, hostname, include_subdomains, path_prefix, path_match,
  scope_kind, review_status, review_notes
)
select source.id, fixture.hostname, false, '/', 'prefix',
       'publisher', 'approved', 'Transactional test URL scope.'
from (values
  ('team-color-test-tier-1', 'official.example'),
  ('team-color-test-tier-3', 'independent.example'),
  ('team-color-test-tier-3-second', 'second-independent.example'),
  ('team-color-test-tier-3-conflict', 'conflict.example'),
  ('team-color-test-holdout', 'holdout.example'),
  ('team-color-test-shared-holdout', 'shared-holdout.example')
) fixture(source_id, hostname)
join public.trusted_sources source on source.source_id = fixture.source_id;

insert into public.information_lineages(lineage_key, data_type)
select 'lineage-' || source.source_id, 'team_colors'
from public.trusted_sources source
where source.source_id like 'team-color-test-%';

insert into public.information_lineage_versions(
  lineage_id, version, display_name, review_status, notes
)
select lineage.id, 1, 'Lineage for ' || source.display_name, 'approved',
       'Transactional information-lineage fixture.'
from public.information_lineages lineage
join public.trusted_sources source
  on lineage.lineage_key = 'lineage-' || source.source_id
where source.source_id like 'team-color-test-%';

-- These fixtures represent sources that completed qualification before the
-- production workflow being exercised. Governance setup alone is deliberately
-- insufficient.
with created as (
  insert into public.source_qualification_evaluations(
    enrollment_id,policy_id,
    assessed_case_count,match_count,contradiction_count,raw_match_rate,
    evaluation_kind,decision_basis,resulting_status,prior_status
  )
  select enrollment.id,enrollment.current_policy_id,
         20,20,0,1,'decision','standard_case_threshold',
         'qualified','probationary'
  from public.source_qualification_enrollments enrollment
  join public.trusted_sources source on source.id = enrollment.source_id
  where source.source_id like 'team-color-test-tier-%'
  returning id,enrollment_id
)
update public.source_qualification_enrollments enrollment
set qualification_status = 'qualified', assessed_case_count = 20,
    match_count = 20, contradiction_count = 0, raw_match_rate = 1,
    latest_evaluation_id = created.id, updated_at = now()
from created where enrollment.id = created.enrollment_id;

do $$
declare specialist_policy public.agent_job_runtime_policies%rowtype;
  verifier_policy public.agent_job_runtime_policies%rowtype;
begin
  select * into strict specialist_policy
  from public.current_agent_job_runtime_policy('team_color_specialist');
  select * into strict verifier_policy
  from public.current_agent_job_runtime_policy('catalog_verifier.team_colors');
  perform pg_temp.assert_true(
    specialist_policy.lease_seconds = 900
    and verifier_policy.lease_seconds = 900,
    'specialist and verifier leases must use the approved 15-minute duration'
  );
  perform pg_temp.assert_true(
    specialist_policy.retry_delay_seconds = array[0]
    and verifier_policy.retry_delay_seconds = array[0]
    and specialist_policy.maximum_attempts = 2
    and verifier_policy.maximum_attempts = 2
    and specialist_policy.exhaustion_status = 'needs_review'
    and verifier_policy.exhaustion_status = 'needs_review',
    'execution retry must be immediate and exhaust after two total attempts'
  );
  perform pg_temp.assert_true(
    'lease_expired' = any(specialist_policy.retryable_failure_categories)
    and 'rate_limited' = any(verifier_policy.retryable_failure_categories)
    and 'invalid_schema' = any(specialist_policy.permanent_failure_categories)
    and not ('invalid_schema' = any(specialist_policy.retryable_failure_categories)),
    'transient and permanent execution failures must be classified separately'
  );
  perform pg_temp.assert_true((
    select watchdog_interval = interval '15 minutes'
       and maximum_concurrent_operational_workers = 2
    from public.agent_backend_operating_policies
    where is_current and active
  ), 'watchdog cadence and global concurrency must match approved policy');
  perform pg_temp.assert_true((
    select count(*) = 2
       and bool_and(maximum_concurrent_workers = 1)
    from public.agent_worker_pool_concurrency_policies pool
    join public.agent_backend_operating_policies policy
      on policy.id = pool.operating_policy_id
    where policy.is_current and policy.active
      and pool.worker_pool in ('team_color_specialist','catalog_verifier')
  ), 'specialist and verifier worker pools must each be limited to one');
end;
$$;

-- ---------------------------------------------------------------------------
-- Queue ordering, scoped claims, candidate-source restrictions, and retries
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000001', true);
select public.enqueue_team_color_work('hockey-999991', 300, null, 'Highest-priority missing palette.', now());
select public.enqueue_team_color_work('hockey-999992', 200, null, 'Scoped-agent queue test.', now());
select public.enqueue_team_color_work('hockey-999993', 100, null, 'Expected-version guard test.', now());
select public.enqueue_team_color_work('hockey-999994', 400, 'manual_request', 'Verified replacement and history test.', now());

do $$
declare
  claim_value jsonb;
  work_id uuid;
  lease_token_value uuid;
  candidate_id uuid;
  denied boolean := false;
  second_specialist_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000003', true);
  claim_value := public.claim_next_team_color_work(60);
  perform pg_temp.assert_true(claim_value #>> '{team,team_id}' = 'hockey-999992', 'scoped agent must skip higher-priority out-of-scope teams');
  work_id := (claim_value #>> '{work,work_item_id}')::uuid;
  lease_token_value := (claim_value #>> '{work,lease_token}')::uuid;
  perform pg_temp.assert_true((
    select work.lease_expires_at = work.claimed_at
      + make_interval(secs => policy.lease_seconds)
    from public.team_color_work_items work
    join public.agent_job_runtime_policies policy
      on policy.job_type = 'team_color_specialist' and policy.is_current and policy.active
    where work.id = work_id
  ), 'specialist claim must ignore the legacy caller duration and use backend runtime policy');
  perform public.renew_team_color_work_lease(work_id, lease_token_value, 60);
  perform pg_temp.assert_true((
    select event.details ->> 'backend_selected_lease' = 'true'
       and event.details ->> 'legacy_requested_lease_seconds_ignored' = '60'
       and event.details ->> 'runtime_policy_id' is not null
    from public.team_color_work_events event
    where event.work_item_id = work_id and event.event_type = 'lease_renewed'
    order by event.id desc limit 1
  ), 'specialist heartbeat must record that backend policy selected the lease');

  begin
    perform public.submit_team_color_source_candidate(
      work_id, lease_token_value, 'agent-b-must-not-submit-source', 'Denied Source',
      'https://denied.example', 'https://denied.example/reference',
      'https://denied.example/evidence', 'Agent B lacks source-candidate capability.', now()
    );
  exception when others then
    denied := true;
  end;
  perform pg_temp.assert_true(denied, 'source-candidate submission must require its narrow capability');
  perform public.release_team_color_work(work_id, lease_token_value, now() + interval '5 minutes', 'transient', 'Exercise retry release.');
  perform pg_temp.assert_true((
    select status = 'retry_wait' and available_at <= clock_timestamp()
    from public.team_color_work_items where id = work_id
  ), 'specialist transient execution failure must ignore caller delay and retry immediately');
  update public.team_color_work_items
  set priority = 50
  where id = work_id;

  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000002', true);
  claim_value := public.claim_next_team_color_work(900);
  perform pg_temp.assert_true(claim_value #>> '{team,team_id}' = 'hockey-999994', 'claim order must be deterministic by descending priority');
  work_id := (claim_value #>> '{work,work_item_id}')::uuid;
  lease_token_value := (claim_value #>> '{work,lease_token}')::uuid;

  candidate_id := public.submit_team_color_source_candidate(
    work_id, lease_token_value, 'team-color-agent-pending-candidate', 'Pending Agent Candidate',
    'https://candidate.example', 'https://candidate.example/reference',
    'https://candidate.example/evidence', 'New candidate retained for source review.', now()
  );
  perform pg_temp.assert_true(candidate_id is not null, 'agent must be able to retain a source candidate');
  perform pg_temp.assert_true((
    select source.review_status = 'pending_review'
       and source.independence_group_id is null
       and not exists (select 1 from public.source_trust_assignments trust where trust.source_id = source.id)
    from public.trusted_sources source
    where source.source_id = 'team-color-agent-pending-candidate'
  ), 'agent candidate must remain unapproved, ungrouped, and untrusted');

  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000003', true);
  begin
    perform public.claim_next_team_color_work(900);
  exception when others then
    second_specialist_denied := true;
  end;
  perform pg_temp.assert_true(
    second_specialist_denied,
    'backend claims must enforce one concurrent Team Color specialist'
  );

end;
$$;

-- ---------------------------------------------------------------------------
-- Verified replacement: payload validation, evidence, verifier separation,
-- conflicting evidence retention, and immutable-history supersession
-- ---------------------------------------------------------------------------

do $$
declare
  claim_value jsonb;
  work_id uuid;
  lease_token_value uuid;
  proposal_id_value uuid;
  invalid_rejected boolean := false;
  self_verify_rejected boolean := false;
  duplicate_rejected boolean := false;
  pending_source_rejected boolean := false;
  independence_rejected boolean := false;
  high_trust_rejected boolean := false;
  old_version_id uuid;
  verifier_claim jsonb;
  verifier_work_id uuid;
  verifier_lease_token uuid;
  verifier_result_uuid uuid;
  extra_specialist_result_uuid uuid;
  extra_verification_work_uuid uuid;
  second_verifier_denied boolean := false;
  retry_verifier_claim jsonb;
  retry_verifier_lease uuid;
begin
  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000002', true);
  claim_value := public.get_my_team_color_work(
    (select id from public.team_color_work_items where team_id = public.resolve_catalog_team_id('hockey-999994')),
    (select lease_token from public.team_color_work_items where team_id = public.resolve_catalog_team_id('hockey-999994'))
  );
  work_id := (claim_value #>> '{work,work_item_id}')::uuid;
  lease_token_value := (claim_value #>> '{work,lease_token}')::uuid;
  old_version_id := (claim_value #>> '{current_colors,version_id}')::uuid;

  begin
    perform public.submit_team_color_proposal(
      work_id, lease_token_value,
      jsonb_build_object('primary', '#abcdef', 'secondary', '#123456'),
      'Lowercase payload must fail.'
    );
  exception when others then
    invalid_rejected := true;
  end;
  perform pg_temp.assert_true(invalid_rejected, 'invalid lowercase color payload must be rejected before submission');

  proposal_id_value := public.submit_team_color_proposal(
    work_id, lease_token_value,
    jsonb_build_object(
      'primary', '#555555', 'secondary', '#666666', 'tertiary', '#FFFFFF',
      'effective_from', '2026-01-01', 'effective_from_precision', 'day'
    ),
    'Manual recheck found a changed official palette.'
  );

  begin
    insert into public.catalog_change_proposals(
      fact_type, operation, target_team_id, payload, status, proposed_by_actor_id,
      team_color_work_item_id, expected_current_color_version_id,
      team_color_change_kind, proposal_reason, recheck_trigger
    )
    select 'team_colors', 'replace', target_team_id, payload, 'pending', proposed_by_actor_id,
           team_color_work_item_id, expected_current_color_version_id,
           team_color_change_kind, proposal_reason, recheck_trigger
    from public.catalog_change_proposals where id = proposal_id_value;
  exception when unique_violation or foreign_key_violation then
    duplicate_rejected := true;
  end;
  perform pg_temp.assert_true(duplicate_rejected, 'database must reject a duplicate pending proposal for one team');

  begin
    perform pg_temp.add_team_color_evidence(
      proposal_id_value, 'team-color-agent-pending-candidate',
      'https://candidate.example/evidence', 'Must not attach before source review.', now(), true
    );
  exception when others then
    pending_source_rejected := true;
  end;
  perform pg_temp.assert_true(pending_source_rejected, 'pending source candidate cannot be attached as proposal evidence');

  perform pg_temp.add_team_color_evidence(
    proposal_id_value, 'team-color-test-tier-3',
    'https://independent.example/team-colors/first',
    'First page from one independent owner supports the palette.', now(), true
  );
  perform pg_temp.add_team_color_evidence(
    proposal_id_value, 'team-color-test-tier-3',
    'https://independent.example/team-colors/second',
    'Second page under the same ownership group also supports the palette.', now(), true
  );

  begin
    perform public.review_catalog_proposal(proposal_id_value, 'approved', 'Agent must not self-verify.');
  exception when others then
    self_verify_rejected := true;
  end;
  perform pg_temp.assert_true(self_verify_rejected, 'Team Color Agent must be denied verification');

  perform public.finish_team_color_work(
    work_id, lease_token_value, 'submitted_for_verification', null, null, null,
    jsonb_build_object('initial_supporting_sources', 1)
  );

  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000004', true);
  begin
    perform public.review_catalog_proposal(proposal_id_value, 'approved', 'Same-owner pages must not satisfy independence.');
  exception when others then
    independence_rejected := true;
  end;
  perform pg_temp.assert_true(independence_rejected, 'direct Team Color approval must remain unavailable even to a verifier actor');

  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000002', true);
  perform pg_temp.add_team_color_evidence(
    proposal_id_value, 'team-color-test-tier-3-second',
    'https://second-independent.example/team-colors',
    'A second independent Tier 3 source corroborates the palette.', now(), true
  );

  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000004', true);
  begin
    perform public.review_catalog_proposal(proposal_id_value, 'approved', 'Tier 3-only evidence must not satisfy the high-trust minimum.');
  exception when others then
    high_trust_rejected := true;
  end;
  perform pg_temp.assert_true(high_trust_rejected, 'a verifier cannot replace backend comparison with a direct approval decision');

  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000002', true);
  perform pg_temp.add_team_color_evidence(
    proposal_id_value, 'team-color-test-tier-1',
    'https://official.example/brand.pdf',
    'Official source lists #555555, #666666, and #FFFFFF.', now(), true
  );
  perform pg_temp.add_team_color_evidence(
    proposal_id_value, 'team-color-test-tier-3-conflict',
    'https://conflict.example/team-colors',
    'Conflicting source reports a different secondary color.', now(), false
  );

  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000004', true);
  verifier_claim := public.claim_next_catalog_verification_work('team_colors');
  verifier_work_id := (verifier_claim #>> '{work,verification_work_item_id}')::uuid;
  verifier_lease_token := (verifier_claim #>> '{work,lease_token}')::uuid;
  perform pg_temp.assert_true((
    select work.lease_expires_at = attempt.claimed_at + interval '15 minutes'
    from public.catalog_verification_work_items work
    join public.catalog_verification_attempts attempt
      on attempt.verification_work_item_id = work.id
     and attempt.attempt_number = work.attempt_count
    where work.id = verifier_work_id
  ), 'verifier claims must use the approved renewable 15-minute lease');
  insert into public.agent_specialist_results(
    data_type,job_type,subject_type,subject_id,subject_reference,
    result_kind,result_payload,submitted_by_actor_id
  ) values (
    'team_colors','team_color_specialist','catalog_team',
    public.resolve_catalog_team_id('hockey-999991')::text,
    jsonb_build_object('team_id','hockey-999991'),
    'determinate',jsonb_build_object('palette',jsonb_build_array('#010101','#020202')),
    (select id from public.catalog_actors where actor_key = 'team-color-test-agent-a')
  ) returning id into extra_specialist_result_uuid;
  insert into public.catalog_verification_work_items(
    data_type,subject_type,subject_id,subject_reference,capability_scope,
    verifier_context,specialist_result_kind,specialist_result_id,
    verification_policy_id,verification_round,round_requirement_snapshot
  ) select
    'team_colors','catalog_team',public.resolve_catalog_team_id('hockey-999991')::text,
    jsonb_build_object('team_id','hockey-999991'),
    jsonb_build_object('team_id',public.resolve_catalog_team_id('hockey-999991')),
    jsonb_build_object('question','Concurrency guard fixture.'),
    'agent_specialist_result',extra_specialist_result_uuid,
    policy.id,1,'{}'::jsonb
  from public.verification_policies policy
  where policy.data_type = 'team_colors' and policy.is_current and policy.active
  returning id into extra_verification_work_uuid;
  begin
    update public.catalog_verification_work_items
    set status = 'claimed',
        claimed_by_actor_id = (
          select id from public.catalog_actors
          where actor_key = 'team-color-test-verifier-2'
        ),
        lease_token = gen_random_uuid(),
        lease_expires_at = now() + interval '15 minutes'
    where id = extra_verification_work_uuid;
  exception when others then
    second_verifier_denied := true;
  end;
  perform pg_temp.assert_true(
    second_verifier_denied,
    'backend claims must enforce one concurrent determinate verifier'
  );
  perform pg_temp.assert_true(
    verifier_claim::text not like '%#555555%'
    and verifier_claim::text not like '%official.example%'
    and verifier_claim::text not like '%' || proposal_id_value::text || '%',
    'blinded verifier context must not expose specialist palette, evidence, or proposal ID'
  );
  perform public.add_team_color_verifier_evidence(
    verifier_work_id, verifier_lease_token, 'team-color-test-tier-1',
    'https://official.example/verifier-brand.pdf', 'Verifier independently found the official palette.', now(),
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#555555','#666666','#FFFFFF')),
    'lineage-team-color-test-tier-1', 'Verifier identified the official brand document lineage.'
  );
  perform public.add_team_color_verifier_evidence(
    verifier_work_id, verifier_lease_token, 'team-color-test-tier-3-second',
    'https://second-independent.example/verifier-colors', 'Verifier independently corroborated the palette.', now(),
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#555555','#666666','#FFFFFF')),
    'lineage-team-color-test-tier-3-second', 'Verifier identified the independent reference lineage.'
  );
  perform public.add_team_color_verifier_evidence(
    verifier_work_id, verifier_lease_token, 'team-color-test-tier-3',
    'https://independent.example/verifier-additional-colors',
    'Verifier independently found a third supporting lineage.', now(),
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#555555','#666666','#FFFFFF')),
    'lineage-team-color-test-tier-3', 'Additional independent reference lineage.'
  );
  verifier_result_uuid := public.submit_team_color_verifier_result(
    verifier_work_id, verifier_lease_token, 'determinate',
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#555555','#666666','#FFFFFF')),
    'Independent verifier research completed.'
  );
  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000005', true);
  retry_verifier_claim := public.claim_next_catalog_verification_work('team_colors');
  retry_verifier_lease := (retry_verifier_claim #>> '{work,lease_token}')::uuid;
  perform pg_temp.assert_true(
    (retry_verifier_claim #>> '{work,verification_work_item_id}')::uuid = extra_verification_work_uuid
    and public.report_catalog_verification_failure(
      extra_verification_work_uuid,retry_verifier_lease,
      'temporary_network_failure','Temporary verifier network failure.'
    ) = 'retry_wait',
    'first transient verifier execution failure must retry immediately'
  );
  perform pg_temp.assert_true((
    select available_at <= clock_timestamp()
    from public.catalog_verification_work_items
    where id = extra_verification_work_uuid and status = 'retry_wait'
  ), 'verifier retry delay must be zero');
  retry_verifier_claim := public.claim_next_catalog_verification_work('team_colors');
  retry_verifier_lease := (retry_verifier_claim #>> '{work,lease_token}')::uuid;
  perform pg_temp.assert_true(
    public.report_catalog_verification_failure(
      extra_verification_work_uuid,retry_verifier_lease,
      'temporary_api_failure','Second transient verifier execution failure.'
    ) = 'needs_review',
    'second verifier execution failure must exhaust into human exception'
  );
  perform pg_temp.assert_true((
    select work.status = 'needs_review' and work.attempt_count = 2
       and count(attempt.id) = 2
    from public.catalog_verification_work_items work
    join public.catalog_verification_attempts attempt
      on attempt.verification_work_item_id = work.id
    where work.id = extra_verification_work_uuid
    group by work.status,work.attempt_count
  ), 'verifier retry exhaustion must preserve both attempts');
  perform pg_temp.assert_true(not exists (
    select 1 from public.catalog_verification_comparisons comparison
    where comparison.verifier_result_id = verifier_result_uuid
  ), 'verifier result must be durable before a separate comparison step');
  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000001', true);
  perform pg_temp.assert_true(
    public.process_catalog_verification_result(verifier_result_uuid) = 'promoted',
    'matching specialist and verifier palettes must promote deterministically'
  );

  perform pg_temp.assert_true((
    select status = 'completed' from public.team_color_work_items where id = work_id
  ), 'approved proposal must complete its pending-verification work item');
  perform pg_temp.assert_true((
    select not is_current and superseded_at is not null
    from public.team_color_versions where id = old_version_id
  ), 'old verified version must be retained and superseded');
  perform pg_temp.assert_true((
    select primary_color = '#555555' and secondary_color = '#666666'
       and tertiary_color = '#FFFFFF' and record_status = 'verified' and is_current
    from public.team_color_versions
    where team_id = public.resolve_catalog_team_id('hockey-999994') and is_current
  ), 'approved successor must be the verified current palette');
  perform pg_temp.assert_true((
    select jsonb_array_length(evidence_snapshot) = 5
       and evidence_snapshot::text like '%evidence_summary%'
       and evidence_snapshot::text like '%trust_tier_version_id%'
       and evidence_snapshot::text like '%applicability_version_id%'
    from public.catalog_verification_decisions where proposal_id = proposal_id_value
  ), 'decision must snapshot supporting and conflicting evidence with immutable details');
end;
$$;

-- A current verified fact is the preferred qualification reference when the
-- tested source and current lineage were absent from the complete decision
-- provenance. Direct and shared-lineage contributors cannot use that fact to
-- grade themselves.
do $$
declare
  team_uuid uuid := public.resolve_catalog_team_id('hockey-999994');
  adjudication_uuid uuid;
  enrollment_uuid uuid;
  claim_value jsonb;
  result_uuid uuid;
begin
  select adjudication.id into strict adjudication_uuid
  from public.catalog_determinate_adjudications adjudication
  where adjudication.data_type = 'team_colors'
    and adjudication.subject_id = team_uuid::text
    and adjudication.outcome = 'promoted'
  order by adjudication.decided_at desc limit 1;
  perform pg_temp.assert_true((
    select count(*) = 8
       and count(distinct public.current_information_lineage_root(
             contribution.information_lineage_version_id
           )) = 4
       and count(*) filter (where contribution.supports_authoritative_result) = 7
       and count(distinct public.current_information_lineage_root(
             contribution.information_lineage_version_id
           )) filter (where contribution.supports_authoritative_result) = 3
       and bool_and(contribution.information_lineage_version_id is not null)
    from public.catalog_adjudication_source_contributions contribution
    where contribution.adjudication_id = adjudication_uuid
  ), 'authoritative adjudication must retain every specialist and contributing-verifier source lineage');

  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  select enrollment.id into strict enrollment_uuid
  from public.source_qualification_enrollments enrollment
  join public.trusted_sources source on source.id = enrollment.source_id
  where source.source_id = 'team-color-test-holdout'
    and enrollment.data_type = 'team_colors';
  perform public.enqueue_source_qualification_work(
    enrollment_uuid,'catalog_team',team_uuid::text,
    'https://holdout.example/team-999994','lineage-team-color-test-holdout'
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
  claim_value := public.claim_next_source_qualification_work('team_colors');
  result_uuid := public.submit_source_qualification_result(
    (claim_value #>> '{work,work_item_id}')::uuid,
    (claim_value #>> '{work,lease_token}')::uuid,
    'determinate',jsonb_build_object(
      'classification','current_canonical',
      'palette',jsonb_build_array('#555555','#666666','#FFFFFF')
    ),'Blinded holdout claim against an existing verified fact.'
  );
  perform pg_temp.assert_true((
    select reference.reference_kind = 'verified_fact'
       and reference.authoritative_adjudication_id = adjudication_uuid
       and reference.non_production
       and reference.contributing_information_lineage_count = 3
       and observation.outcome = 'match'
    from public.source_qualification_references reference
    join public.source_qualification_observations observation
      on observation.reference_id = reference.id
    where reference.tested_result_id = result_uuid
  ), 'an independent holdout source must be graded directly from the existing verified fact');

  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  select enrollment.id into strict enrollment_uuid
  from public.source_qualification_enrollments enrollment
  join public.trusted_sources source on source.id = enrollment.source_id
  where source.source_id = 'team-color-test-tier-1'
    and enrollment.data_type = 'team_colors';
  perform public.enqueue_source_qualification_work(
    enrollment_uuid,'catalog_team',team_uuid::text,
    'https://official.example/qualification-self-check',
    'lineage-team-color-test-tier-1'
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
  claim_value := public.claim_next_source_qualification_work('team_colors');
  result_uuid := public.submit_source_qualification_result(
    (claim_value #>> '{work,work_item_id}')::uuid,
    (claim_value #>> '{work,lease_token}')::uuid,
    'determinate',jsonb_build_object(
      'classification','current_canonical',
      'palette',jsonb_build_array('#555555','#666666','#FFFFFF')
    ),'Direct-contributor exclusion claim.'
  );
  perform pg_temp.assert_true(not exists (
    select 1 from public.source_qualification_references
    where tested_result_id = result_uuid
  ), 'a source that contributed to the specialist or verifier must not use that verified fact');

  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  select enrollment.id into strict enrollment_uuid
  from public.source_qualification_enrollments enrollment
  join public.trusted_sources source on source.id = enrollment.source_id
  where source.source_id = 'team-color-test-shared-holdout'
    and enrollment.data_type = 'team_colors';
  perform public.enqueue_source_qualification_work(
    enrollment_uuid,'catalog_team',team_uuid::text,
    'https://shared-holdout.example/team-999994',
    'lineage-team-color-test-tier-1'
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
  claim_value := public.claim_next_source_qualification_work('team_colors');
  result_uuid := public.submit_source_qualification_result(
    (claim_value #>> '{work,work_item_id}')::uuid,
    (claim_value #>> '{work,lease_token}')::uuid,
    'determinate',jsonb_build_object(
      'classification','current_canonical',
      'palette',jsonb_build_array('#555555','#666666','#FFFFFF')
    ),'Shared-lineage exclusion claim.'
  );
  perform pg_temp.assert_true(not exists (
    select 1 from public.source_qualification_references
    where tested_result_id = result_uuid
  ), 'a source sharing any contributing lineage must not use that verified fact');
end;
$$;

-- ---------------------------------------------------------------------------
-- Lease expiry, retry/blocked attempts, expected-current-version protection,
-- trust independence, Tier 1/2 minimum, and verifier separation policy
-- ---------------------------------------------------------------------------

do $$
declare
  claim_value jsonb;
  work_id uuid;
  lease_token_value uuid;
begin
  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000002', true);
  claim_value := public.claim_next_team_color_work(900);
  perform pg_temp.assert_true(claim_value #>> '{team,team_id}' = 'hockey-999991', 'next eligible queue item must be the highest remaining priority');
  work_id := (claim_value #>> '{work,work_item_id}')::uuid;
  lease_token_value := (claim_value #>> '{work,lease_token}')::uuid;

  update public.team_color_work_items set lease_expires_at = now() - interval '1 second' where id = work_id;
  update public.team_color_work_attempts set lease_expires_at = now() - interval '1 second' where work_item_id = work_id and ended_at is null;
  perform public.expire_team_color_work_leases();
  perform pg_temp.assert_true((
    select status = 'retry_wait' and available_at <= clock_timestamp()
    from public.team_color_work_items where id = work_id
  ), 'expired lease must become immediately retryable under backend policy');
  claim_value := public.claim_next_team_color_work(900);
  perform pg_temp.assert_true((claim_value #>> '{work,work_item_id}')::uuid = work_id, 'expired lease must return work to the retry queue');
  perform pg_temp.assert_true((claim_value #>> '{work,attempt_number}')::integer = 2, 'reclaimed work must retain attempt history');
  lease_token_value := (claim_value #>> '{work,lease_token}')::uuid;
  perform public.finish_team_color_work(
    work_id, lease_token_value, 'retry', 'rate_limited', 'Source temporarily rate limited.',
    now() + interval '5 minutes', '{}'::jsonb
  );
  perform pg_temp.assert_true((
    select status = 'needs_review' and attempt_count = 2
    from public.team_color_work_items where id = work_id
  ), 'the second transient execution failure must exhaust into needs_review');
  perform pg_temp.assert_true((
    select count(*) = 2 and bool_or(outcome = 'lease_expired') and bool_or(outcome = 'needs_review')
    from public.team_color_work_attempts where work_item_id = work_id
  ), 'attempt history must retain lease expiry and retry outcomes');
end;
$$;

do $$
declare
  claim_value jsonb;
  work_id uuid;
  lease_token_value uuid;
  proposal_id_value uuid;
  old_version_id uuid;
  verifier_claim jsonb;
  verifier_work_id uuid;
  verifier_lease_token uuid;
  verifier_result_uuid uuid;
begin
  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000002', true);
  claim_value := public.claim_next_team_color_work(900);
  perform pg_temp.assert_true(claim_value #>> '{team,team_id}' = 'hockey-999993', 'version-guard work must be claimable');
  work_id := (claim_value #>> '{work,work_item_id}')::uuid;
  lease_token_value := (claim_value #>> '{work,lease_token}')::uuid;
  old_version_id := (claim_value #>> '{current_colors,version_id}')::uuid;
  proposal_id_value := public.submit_team_color_proposal(
    work_id, lease_token_value,
    jsonb_build_object('primary', '#777777', 'secondary', '#888888'),
    'Expected-current-version test proposal.'
  );
  perform pg_temp.add_team_color_evidence(proposal_id_value, 'team-color-test-tier-1', 'https://official.example/version-guard', 'Official support.', now(), true);
  perform pg_temp.add_team_color_evidence(proposal_id_value, 'team-color-test-tier-3', 'https://independent.example/version-guard', 'Independent support.', now(), true);
  perform pg_temp.add_team_color_evidence(proposal_id_value, 'team-color-test-tier-3-second', 'https://second-independent.example/version-guard', 'Second independent support.', now(), true);
  perform public.finish_team_color_work(work_id, lease_token_value, 'submitted_for_verification', null, null, null, '{}'::jsonb);

  update public.team_color_versions
  set is_current = false, effective_to = current_date, superseded_at = now()
  where id = old_version_id;
  insert into public.team_color_versions(team_id, primary_color, secondary_color, record_status)
  values (public.resolve_catalog_team_id('hockey-999993'), '#999999', '#AAAAAA', 'imported_unverified');

  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000004', true);
  verifier_claim := public.claim_next_catalog_verification_work('team_colors');
  verifier_work_id := (verifier_claim #>> '{work,verification_work_item_id}')::uuid;
  verifier_lease_token := (verifier_claim #>> '{work,lease_token}')::uuid;
  perform public.add_team_color_verifier_evidence(
    verifier_work_id, verifier_lease_token, 'team-color-test-tier-1',
    'https://official.example/version-guard-verifier', 'Verifier official support.', now(),
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#777777','#888888')),
    'lineage-team-color-test-tier-1', 'Official document lineage.'
  );
  perform public.add_team_color_verifier_evidence(
    verifier_work_id, verifier_lease_token, 'team-color-test-tier-3',
    'https://independent.example/version-guard-verifier', 'Verifier independent support.', now(),
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#777777','#888888')),
    'lineage-team-color-test-tier-3', 'Independent reference lineage.'
  );
  perform public.add_team_color_verifier_evidence(
    verifier_work_id, verifier_lease_token, 'team-color-test-tier-3-second',
    'https://second-independent.example/version-guard-verifier',
    'Verifier second independent support.', now(),
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#777777','#888888')),
    'lineage-team-color-test-tier-3-second', 'Second independent reference lineage.'
  );
  verifier_result_uuid := public.submit_team_color_verifier_result(
    verifier_work_id, verifier_lease_token, 'determinate',
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#777777','#888888')),
    'Independent verifier result for stale-version guard.'
  );
  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000001', true);
  perform pg_temp.assert_true(
    public.process_catalog_verification_result(verifier_result_uuid) = 'stale_expected_version',
    'backend comparison must reject a stale expected-current version'
  );
end;
$$;

do $$
declare
  policy_record public.verification_policies%rowtype;
begin
  select * into strict policy_record from public.verification_policies
  where data_type = 'team_colors' and is_current and active;
  perform pg_temp.assert_true(policy_record.version = 4, 'approved Team Color policy v4 must be current');
  perform pg_temp.assert_true(policy_record.require_independent_verifier, 'Team Color policy must require an independent verifier');
  perform pg_temp.assert_true(policy_record.minimum_evidence_count = 3, 'normal Team Color research must require three independent lineages');
  perform pg_temp.assert_true(policy_record.require_independent_sources, 'Team Color policy must require independent ownership groups');
  perform pg_temp.assert_true(policy_record.configuration ? 'trust_tier_rubric', 'policy must retain the Tier 1-5 rubric');
  perform pg_temp.assert_true((policy_record.configuration ->> 'minimum_tier_1_or_2_evidence_count')::integer = 1, 'policy must require one Tier 1/2 source');
  perform pg_temp.assert_true(
    policy_record.configuration -> 'recheck_triggers' @> '["bootstrap_revalidation"]'::jsonb,
    'Team Color policy must recognize the one-time bootstrap revalidation trigger'
  );
  perform pg_temp.assert_true(
    policy_record.maximum_verifier_rounds = 2
    and policy_record.required_matching_verifier_results = 2
    and policy_record.consensus_strategy = 'specialist_match_or_verifier_consensus',
    'Team Color disagreement policy must implement two verifier rounds and 2-of-3 resolution'
  );
  perform pg_temp.assert_true((
    select count(*) = 2
       and max(minimum_independent_information_lineages)
           filter (where verification_round = 1) = 3
       and max(minimum_independent_information_lineages)
           filter (where verification_round = 2) = 4
    from public.catalog_verification_round_policies
    where verification_policy_id = policy_record.id
  ), 'Verifier 1 must require three lineages and Verifier 2 four lineages');
end;
$$;

do $$
declare
  claim_value jsonb;
  work_id uuid;
  lease_token_value uuid;
begin
  -- Make the scoped agent's prior retry eligible, then let the full-scope agent
  -- record a durable blocked outcome with its reason/category.
  update public.team_color_work_items
  set available_at = now()
  where team_id = public.resolve_catalog_team_id('hockey-999992')
    and status = 'retry_wait';
  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000002', true);
  claim_value := public.claim_next_team_color_work(900);
  perform pg_temp.assert_true(claim_value #>> '{team,team_id}' = 'hockey-999992', 'released retry work must become claimable when available');
  work_id := (claim_value #>> '{work,work_item_id}')::uuid;
  lease_token_value := (claim_value #>> '{work,lease_token}')::uuid;
  perform public.finish_team_color_work(
    work_id, lease_token_value, 'blocked', 'single_credible_source',
    'Only one qualifying independent source is currently available.', null,
    jsonb_build_object('credible_source_count', 1)
  );
  perform pg_temp.assert_true((
    select status = 'blocked'
       and failure_category = 'single_credible_source'
       and failure_reason like 'Only one qualifying%'
    from public.team_color_work_items where id = work_id
  ), 'blocked work must retain its category and plain-language reason');
end;
$$;

-- ---------------------------------------------------------------------------
-- Canonical backend architecture: exhaustion, contradiction, no-change,
-- lineage independence, wake recovery, late-worker safety, and revalidation.
-- These cases exercise the approved production operating policy transactionally.
-- ---------------------------------------------------------------------------

do $$
declare claim_value jsonb; work_id uuid; lease_token_value uuid;
begin
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  work_id := public.enqueue_team_color_work(
    'hockey-999990',1100,null,'Permanent failure classification fixture.',now()
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
  claim_value := public.claim_next_team_color_work(900);
  lease_token_value := (claim_value #>> '{work,lease_token}')::uuid;
  perform pg_temp.assert_true(
    public.report_team_color_work_failure(
      work_id, lease_token_value, 'invalid_schema',
      'The worker returned an invalid structured payload.', '{}'
    ) = 'needs_review',
    'permanent/configuration failures must not be blindly retried'
  );
  perform pg_temp.assert_true((
    select status = 'needs_review' and attempt_count = 1
      and failure_category = 'invalid_schema'
    from public.team_color_work_items where id = work_id
  ), 'permanent failure must preserve its single attempt in human exception state');
end;
$$;

do $$
declare
  work_id uuid; claim_value jsonb; lease_token_value uuid; proposal_uuid uuid;
  verifier_claim jsonb; verification_job_uuid uuid; verifier_lease uuid;
  verifier_result_uuid uuid;
begin
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  work_id := public.enqueue_team_color_work(
    'hockey-999989',1050,null,'Unresolved two-round disagreement fixture.',now()
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
  claim_value := public.claim_next_team_color_work(900);
  lease_token_value := (claim_value #>> '{work,lease_token}')::uuid;
  proposal_uuid := public.submit_team_color_proposal(
    work_id,lease_token_value,
    jsonb_build_object('primary','#101010','secondary','#202020'),
    'Specialist selected the first of three conflicting palettes.'
  );
  perform pg_temp.add_team_color_evidence(
    proposal_uuid,'team-color-test-tier-1','https://official.example/all-distinct-specialist',
    'Specialist official evidence.',now(),true
  );
  perform pg_temp.add_team_color_evidence(
    proposal_uuid,'team-color-test-tier-3','https://independent.example/all-distinct-specialist',
    'Specialist independent evidence.',now(),true
  );
  perform pg_temp.add_team_color_evidence(
    proposal_uuid,'team-color-test-tier-3-second','https://second-independent.example/all-distinct-specialist',
    'Specialist second independent evidence.',now(),true
  );
  perform public.finish_team_color_work(
    work_id,lease_token_value,'submitted_for_verification',null,null,null,'{}'
  );

  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000004',true);
  verifier_claim := public.claim_next_catalog_verification_work('team_colors');
  verification_job_uuid := (verifier_claim #>> '{work,verification_work_item_id}')::uuid;
  verifier_lease := (verifier_claim #>> '{work,lease_token}')::uuid;
  perform pg_temp.add_team_color_verifier_evidence_pair(
    verification_job_uuid,verifier_lease,jsonb_build_array('#303030','#404040'),'all-distinct-v1'
  );
  verifier_result_uuid := public.submit_team_color_verifier_result(
    verification_job_uuid,verifier_lease,'determinate',
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#303030','#404040')),
    'Verifier 1 independently selected a second palette.'
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  perform pg_temp.assert_true(
    public.process_catalog_verification_result(verifier_result_uuid) = 'additional_verifier_queued',
    'first disagreement must create Verifier 2 before human exception'
  );

  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000005',true);
  verifier_claim := public.claim_next_catalog_verification_work('team_colors');
  verification_job_uuid := (verifier_claim #>> '{work,verification_work_item_id}')::uuid;
  verifier_lease := (verifier_claim #>> '{work,lease_token}')::uuid;
  perform pg_temp.add_team_color_verifier_evidence_pair(
    verification_job_uuid,verifier_lease,jsonb_build_array('#505050','#606060'),'all-distinct-v2'
  );
  verifier_result_uuid := public.submit_team_color_verifier_result(
    verification_job_uuid,verifier_lease,'determinate',
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#505050','#606060')),
    'Verifier 2 independently selected a third palette with equally ranked evidence.'
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  perform pg_temp.assert_true(
    public.process_catalog_verification_result(verifier_result_uuid) = 'automation_exhausted',
    'an unresolved two-round disagreement must enter human exception'
  );
  perform pg_temp.assert_true((
    select work.status = 'needs_review'
       and count(comparison.id) = 2
       and not exists (
         select 1 from public.catalog_verification_work_items round_three
         where round_three.specialist_result_kind = 'catalog_proposal'
           and round_three.specialist_result_id = proposal_uuid
           and round_three.verification_round > 2
       )
    from public.team_color_work_items work
    join public.catalog_verification_work_items verification
      on verification.originating_job_id = work.id
    join public.catalog_verification_comparisons comparison
      on comparison.verification_work_item_id = verification.id
    where work.id = work_id
    group by work.status
  ), 'two verifier rounds are the hard approved limit and preserve comparison history');
end;
$$;

-- Generic comparison barrier, proposal side: unresolved evidence must pause,
-- then resume through lineage assignment and recovery without consuming a
-- verifier round or creating an exception comparison. The verifier side is
-- exercised below by the non-Team determinate adapter.
do $$
declare
  work_uuid uuid;
  specialist_claim jsonb;
  specialist_lease_uuid uuid;
  proposal_uuid uuid;
  unresolved_proposal_evidence_uuid uuid;
  unresolved_proposal_lineage_work_uuid uuid;
  verification_work_uuid uuid;
  verifier_claim jsonb;
  verifier_lease_uuid uuid;
  verifier_result_uuid uuid;
  lineage_claim jsonb;
  recovery_value jsonb;
begin
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  work_uuid := public.enqueue_team_color_work(
    'hockey-999988',1200,null,'Information-lineage comparison barrier fixture.',now()
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
  specialist_claim := public.claim_next_team_color_work(900);
  specialist_lease_uuid := (specialist_claim #>> '{work,lease_token}')::uuid;
  proposal_uuid := public.submit_team_color_proposal(
    work_uuid,specialist_lease_uuid,
    jsonb_build_object('primary','#717171','secondary','#818181'),
    'Specialist proposal with one lineage awaiting resolution.'
  );
  perform pg_temp.add_team_color_evidence(
    proposal_uuid,'team-color-test-tier-1',
    'https://official.example/lineage-barrier-specialist',
    'Known official specialist lineage.',now(),true
  );
  perform pg_temp.add_team_color_evidence(
    proposal_uuid,'team-color-test-tier-3',
    'https://independent.example/lineage-barrier-specialist',
    'Known independent specialist lineage.',now(),true
  );
  unresolved_proposal_evidence_uuid := public.add_team_color_proposal_evidence(
    proposal_uuid,'team-color-test-tier-3-second',
    'https://second-independent.example/lineage-barrier-specialist',
    'Specialist evidence whose origin still requires resolution.',now(),true,
    jsonb_build_object(
      'classification','current_canonical',
      'palette',jsonb_build_array('#717171','#818181')
    )
  );
  select id into strict unresolved_proposal_lineage_work_uuid
  from public.information_lineage_resolution_work_items
  where evidence_kind = 'proposal_evidence'
    and evidence_id = unresolved_proposal_evidence_uuid;
  perform public.finish_team_color_work(
    work_uuid,specialist_lease_uuid,'submitted_for_verification',
    null,null,null,'{}'
  );

  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000004',true);
  verifier_claim := public.claim_next_catalog_verification_work('team_colors');
  verification_work_uuid :=
    (verifier_claim #>> '{work,verification_work_item_id}')::uuid;
  verifier_lease_uuid := (verifier_claim #>> '{work,lease_token}')::uuid;
  perform public.add_team_color_verifier_evidence(
    verification_work_uuid,verifier_lease_uuid,'team-color-test-tier-1',
    'https://official.example/lineage-barrier-verifier',
    'Known official verifier lineage.',now(),
    jsonb_build_object(
      'classification','current_canonical',
      'palette',jsonb_build_array('#717171','#818181')
    ),
    'lineage-team-color-test-tier-1','Known official origin.'
  );
  perform public.add_team_color_verifier_evidence(
    verification_work_uuid,verifier_lease_uuid,'team-color-test-tier-3',
    'https://independent.example/lineage-barrier-verifier',
    'Known independent verifier lineage.',now(),
    jsonb_build_object(
      'classification','current_canonical',
      'palette',jsonb_build_array('#717171','#818181')
    ),
    'lineage-team-color-test-tier-3','Known independent origin.'
  );
  perform public.add_team_color_verifier_evidence(
    verification_work_uuid,verifier_lease_uuid,'team-color-test-tier-3-second',
    'https://second-independent.example/lineage-barrier-verifier',
    'Known second independent verifier lineage.',now(),
    jsonb_build_object(
      'classification','current_canonical',
      'palette',jsonb_build_array('#717171','#818181')
    ), 'lineage-team-color-test-tier-3-second','Known second independent origin.'
  );
  verifier_result_uuid := public.submit_team_color_verifier_result(
    verification_work_uuid,verifier_lease_uuid,'determinate',
    jsonb_build_object(
      'classification','current_canonical',
      'palette',jsonb_build_array('#717171','#818181')
    ),
    'Verifier independently matched the specialist while lineage resolution remained pending.'
  );

  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  perform pg_temp.assert_true(
    public.process_catalog_verification_result(verifier_result_uuid)
      = 'waiting_on_information_lineage',
    'unresolved proposal evidence must prevent deterministic comparison'
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.catalog_verification_comparisons
      where verifier_result_id = verifier_result_uuid
    )
    and exists (
      select 1 from public.catalog_verification_work_items
      where id = verification_work_uuid and status = 'result_submitted'
        and failure_category is null
    )
    and exists (
      select 1 from public.team_color_work_items
      where id = work_uuid and status = 'pending_verification'
    )
    and not exists (
      select 1 from public.catalog_verification_work_items
      where specialist_result_kind = 'catalog_proposal'
        and specialist_result_id = proposal_uuid and verification_round > 1
    )
    and exists (
      select 1 from public.catalog_verification_work_events
      where verification_work_item_id = verification_work_uuid
        and event_type = 'waiting_on_information_lineage'
    ),
    'lineage waiting must not create insufficient evidence, escalation, or needs-review state'
  );

  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000005',true);
  lineage_claim := public.claim_next_information_lineage_resolution_work('team_colors');
  perform pg_temp.assert_true(
    (lineage_claim #>> '{work,work_item_id}')::uuid
      = unresolved_proposal_lineage_work_uuid,
    'proposal lineage work must remain independently claimable'
  );
  perform public.submit_information_lineage_resolution_result(
    unresolved_proposal_lineage_work_uuid,
    (lineage_claim #>> '{work,lease_token}')::uuid,
    'assign_existing','lineage-team-color-test-tier-3-second',
    'Resolver established the proposal evidence origin.', '{}'
  );
  perform pg_temp.assert_true((
    select count(*) = 1 and bool_and(status = 'pending')
    from public.agent_work_wake_outbox
    where queue_name = 'catalog_verification_comparison'
      and work_item_id = verification_work_uuid
      and eligibility_key = verifier_result_uuid::text
  ), 'final required lineage assignment must automatically emit one idempotent comparison wake');

  -- Model lost delivery after the automatic resume wake. Generic recovery must
  -- restore the same wake and safely process it.
  update public.agent_work_wake_outbox
  set status = 'cancelled'
  where queue_name = 'catalog_verification_comparison'
    and work_item_id = verification_work_uuid
    and eligibility_key = verifier_result_uuid::text;
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  recovery_value := public.run_agent_backend_recovery();
  perform pg_temp.assert_true(
    (recovery_value ->> 'comparison_wakes_reconciled')::integer >= 1
    and exists (
      select 1 from public.catalog_verification_comparisons
      where verifier_result_id = verifier_result_uuid
        and comparison_outcome = 'promoted'
    )
    and exists (
      select 1 from public.catalog_verification_work_items
      where id = verification_work_uuid and status = 'completed'
    )
    and exists (
      select 1 from public.team_color_work_items
      where id = work_uuid and status = 'completed'
    )
    and not exists (
      select 1 from public.catalog_verification_work_items
      where specialist_result_kind = 'catalog_proposal'
        and specialist_result_id = proposal_uuid and verification_round > 1
    ),
    'recovery must restore a missed ready comparison wake without premature escalation or review'
  );
end;
$$;

do $$
declare
  claim_value jsonb; work_id uuid; lease_token_value uuid; proposal_uuid uuid;
  verification_job_uuid uuid; verifier_claim jsonb; verifier_lease uuid;
  verifier_result_uuid uuid; proposer_claim jsonb;
begin
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  work_id := public.enqueue_team_color_work(
    'hockey-999995',1000,null,'Durable verifier contradiction fixture.',now()
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
  claim_value := public.claim_next_team_color_work(900);
  lease_token_value := (claim_value #>> '{work,lease_token}')::uuid;
  proposal_uuid := public.submit_team_color_proposal(
    work_id,lease_token_value,
    jsonb_build_object('primary','#121212','secondary','#343434'),
    'Specialist contradiction fixture.'
  );
  perform pg_temp.add_team_color_evidence(
    proposal_uuid,'team-color-test-tier-1','https://official.example/contradiction-specialist',
    'Specialist official evidence.',now(),true
  );
  perform pg_temp.add_team_color_evidence(
    proposal_uuid,'team-color-test-tier-3','https://independent.example/contradiction-specialist',
    'Specialist independent evidence.',now(),true
  );
  perform pg_temp.add_team_color_evidence(
    proposal_uuid,'team-color-test-tier-3-second','https://second-independent.example/contradiction-specialist',
    'Specialist second independent evidence.',now(),true
  );
  -- Suppress trigger delivery only inside this rollback-only fixture to model a
  -- lost transition between durable proposal submission and verifier-job creation.
  execute 'alter table public.team_color_work_items disable trigger ensure_team_color_verification_work';
  perform public.finish_team_color_work(
    work_id,lease_token_value,'submitted_for_verification',null,null,null,'{}'
  );
  execute 'alter table public.team_color_work_items enable trigger ensure_team_color_verification_work';
  perform pg_temp.assert_true(not exists (
    select 1 from public.catalog_verification_work_items where proposal_id = proposal_uuid
  ), 'fixture must begin with a stranded durable proposal and no verifier job');
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  perform public.run_agent_backend_recovery();
  perform pg_temp.assert_true((
    select count(*) = 1 from public.catalog_verification_work_items
    where proposal_id = proposal_uuid and status = 'queued'
  ), 'watchdog recovery must recreate a stranded proposal verifier job idempotently');

  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
  proposer_claim := public.claim_next_catalog_verification_work('team_colors');
  perform pg_temp.assert_true(proposer_claim is null,
    'proposal builder must be unable to claim its own verifier job');

  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000004',true);
  verifier_claim := public.claim_next_catalog_verification_work('team_colors');
  verification_job_uuid := (verifier_claim #>> '{work,verification_work_item_id}')::uuid;
  verifier_lease := (verifier_claim #>> '{work,lease_token}')::uuid;
  perform pg_temp.add_team_color_verifier_evidence_pair(
    verification_job_uuid,verifier_lease,jsonb_build_array('#565656','#787878'),'contradiction'
  );
  verifier_result_uuid := public.submit_team_color_verifier_result(
    verification_job_uuid,verifier_lease,'determinate',
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#565656','#787878')),
    'Verifier independently found a contradictory palette.'
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  perform pg_temp.assert_true(
    public.process_catalog_verification_result(verifier_result_uuid) = 'additional_verifier_queued',
    'ordinary disagreement must automatically queue another blinded verifier round'
  );
  perform pg_temp.assert_true((
    select work.status = 'pending_verification'
       and comparison.comparison_outcome = 'additional_verifier_queued'
       and next_verification.status = 'queued'
       and next_verification.verification_round = 2
    from public.team_color_work_items work
    join public.catalog_verification_work_items verification
      on verification.originating_job_id = work.id
     and verification.verification_round = 1
    join public.catalog_verification_comparisons comparison
      on comparison.verification_work_item_id = verification.id
    join public.catalog_verification_work_items next_verification
      on next_verification.parent_verification_work_item_id = verification.id
    where work.id = work_id
  ), 'disagreement escalation must remain autonomous rather than entering human review');

  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000005',true);
  verifier_claim := public.claim_next_catalog_verification_work('team_colors');
  verification_job_uuid := (verifier_claim #>> '{work,verification_work_item_id}')::uuid;
  verifier_lease := (verifier_claim #>> '{work,lease_token}')::uuid;
  perform pg_temp.add_team_color_verifier_evidence_pair(
    verification_job_uuid,verifier_lease,jsonb_build_array('#121212','#343434'),'contradiction'
  );
  perform pg_temp.assert_true((
    select count(*) = 4
       and bool_and(source_reliability_snapshot ? 'empirical_reliability_status')
       and bool_and(source_qualification_snapshot ->> 'production_evidence_eligible' = 'true')
    from public.catalog_verifier_evidence
    where verification_work_item_id = verification_job_uuid
  ), 'later rounds may independently rediscover strong sources and retain reliability/qualification context');
  perform pg_temp.assert_true((
    select (round_requirement_snapshot ->> 'minimum_independent_information_lineages')::integer = 4
       and round_requirement_snapshot #>> '{source_selection_policy,permit_independently_rediscovered_source_overlap}' = 'true'
    from public.catalog_verification_work_items
    where id = verification_job_uuid and verification_round = 2
  ), 'Verifier 2 must require four lineages while permitting independently rediscovered strong-source overlap');
  verifier_result_uuid := public.submit_team_color_verifier_result(
    verification_job_uuid,verifier_lease,'determinate',
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#121212','#343434')),
    'Second verifier independently matched the specialist after the first disagreement.'
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  perform pg_temp.assert_true(
    public.process_catalog_verification_result(verifier_result_uuid) = 'promoted',
    'a later independently researched match must resolve the disagreement automatically'
  );
  perform pg_temp.assert_true((
    select work.status = 'completed'
       and count(comparison.id) = 2
       and count(comparison.id) filter (
         where comparison.comparison_outcome = 'additional_verifier_queued'
       ) = 1
       and count(comparison.id) filter (
         where comparison.comparison_outcome = 'promoted'
       ) = 1
    from public.team_color_work_items work
    join public.catalog_verification_work_items verification
      on verification.originating_job_id = work.id
    join public.catalog_verification_comparisons comparison
      on comparison.verification_work_item_id = verification.id
    where work.id = work_id
    group by work.status
  ), 'multi-round verification must finish through deterministic backend adjudication');
end;
$$;

do $$
declare
  claim_value jsonb; work_id uuid; lease_token_value uuid; proposal_uuid uuid;
  old_version_uuid uuid; verifier_claim jsonb; verification_job_uuid uuid;
  verifier_lease uuid; verifier_result_uuid uuid;
begin
  select id into old_version_uuid from public.team_color_versions
  where team_id = public.resolve_catalog_team_id('hockey-999996') and is_current;
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  work_id := public.enqueue_team_color_work(
    'hockey-999996',1000,'manual_request','No-change verification fixture.',now()
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
  claim_value := public.claim_next_team_color_work(900);
  lease_token_value := (claim_value #>> '{work,lease_token}')::uuid;
  proposal_uuid := public.submit_team_color_proposal(
    work_id,lease_token_value,
    jsonb_build_object('primary','#0A0A0A','secondary','#0B0B0B','tertiary','#FFFFFF'),
    'Specialist independently found no change.'
  );
  perform pg_temp.add_team_color_evidence(
    proposal_uuid,'team-color-test-tier-1','https://official.example/no-change-specialist',
    'Fresh official recheck evidence.',now(),true
  );
  perform pg_temp.add_team_color_evidence(
    proposal_uuid,'team-color-test-tier-3','https://independent.example/no-change-specialist',
    'Fresh independent recheck evidence.',now(),true
  );
  perform pg_temp.add_team_color_evidence(
    proposal_uuid,'team-color-test-tier-3-second','https://second-independent.example/no-change-specialist',
    'Fresh second independent recheck evidence.',now(),true
  );
  perform public.finish_team_color_work(
    work_id,lease_token_value,'submitted_for_verification',null,null,null,'{}'
  );
  perform pg_temp.assert_true((
    select status = 'pending_verification' and completed_at is null
    from public.team_color_work_items where id = work_id
  ), 'specialist no-change result must remain pending independent verification');
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000004',true);
  verifier_claim := public.claim_next_catalog_verification_work('team_colors');
  verification_job_uuid := (verifier_claim #>> '{work,verification_work_item_id}')::uuid;
  verifier_lease := (verifier_claim #>> '{work,lease_token}')::uuid;
  perform pg_temp.add_team_color_verifier_evidence_pair(
    verification_job_uuid,verifier_lease,
    jsonb_build_array('#0A0A0A','#0B0B0B','#FFFFFF'),'no-change'
  );
  verifier_result_uuid := public.submit_team_color_verifier_result(
    verification_job_uuid,verifier_lease,'determinate',
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#0A0A0A','#0B0B0B','#FFFFFF')),
    'Verifier independently confirmed the current palette.'
  );
  perform pg_temp.assert_true((
    select status = 'result_submitted' from public.catalog_verification_work_items
    where id = verification_job_uuid
  ), 'submitted verifier result must remain durable before watchdog comparison');
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  perform public.run_agent_backend_recovery();
  perform pg_temp.assert_true((
    select work.status = 'completed'
       and comparison.comparison_outcome = 'confirmed_no_change'
    from public.team_color_work_items work
    join public.catalog_verification_work_items verification
      on verification.originating_job_id = work.id
    join public.catalog_verification_comparisons comparison
      on comparison.verification_work_item_id = verification.id
    where work.id = work_id
  ), 'watchdog must process a stranded verifier result into confirmed no-change');
  perform pg_temp.assert_true((
    select id = old_version_uuid and is_current and record_status = 'verified'
    from public.team_color_versions
    where team_id = public.resolve_catalog_team_id('hockey-999996') and is_current
  ), 'confirmed no-change must retain the existing verified version');
end;
$$;

do $$
declare
  claim_value jsonb; work_id uuid; lease_token_value uuid; proposal_uuid uuid;
  second_evidence_uuid uuid; first_lineage_uuid uuid;
  verifier_claim jsonb; verification_job_uuid uuid; verifier_lease uuid;
  verifier_result_uuid uuid;
begin
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  work_id := public.enqueue_team_color_work(
    'hockey-999997',1000,null,'Information-lineage collision fixture.',now()
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
  claim_value := public.claim_next_team_color_work(900);
  lease_token_value := (claim_value #>> '{work,lease_token}')::uuid;
  proposal_uuid := public.submit_team_color_proposal(
    work_id,lease_token_value,
    jsonb_build_object('primary','#ABABAB','secondary','#CDCDCD'),
    'Two publishers repeat one originating lineage.'
  );
  perform pg_temp.add_team_color_evidence(
    proposal_uuid,'team-color-test-tier-1','https://official.example/lineage-specialist',
    'First publisher evidence.',now(),true
  );
  second_evidence_uuid := pg_temp.add_team_color_evidence(
    proposal_uuid,'team-color-test-tier-3','https://independent.example/lineage-specialist',
    'Second publisher repeats the same originating information.',now(),true
  );
  select version.id into first_lineage_uuid
  from public.information_lineages lineage
  join public.information_lineage_versions version
    on version.lineage_id = lineage.id and version.is_current
  where lineage.lineage_key = 'lineage-team-color-test-tier-1';
  update public.catalog_proposal_evidence
  set information_lineage_version_id = first_lineage_uuid,
      information_lineage_basis = 'Both pages derive from one originating document.'
  where id = second_evidence_uuid;
  perform public.finish_team_color_work(
    work_id,lease_token_value,'submitted_for_verification',null,null,null,'{}'
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000004',true);
  verifier_claim := public.claim_next_catalog_verification_work('team_colors');
  verification_job_uuid := (verifier_claim #>> '{work,verification_work_item_id}')::uuid;
  verifier_lease := (verifier_claim #>> '{work,lease_token}')::uuid;
  perform pg_temp.add_team_color_verifier_evidence_pair(
    verification_job_uuid,verifier_lease,jsonb_build_array('#ABABAB','#CDCDCD'),'lineage-collision'
  );
  verifier_result_uuid := public.submit_team_color_verifier_result(
    verification_job_uuid,verifier_lease,'determinate',
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#ABABAB','#CDCDCD')),
    'Verifier result has independent lineage support.'
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  perform pg_temp.assert_true(
    public.process_catalog_verification_result(verifier_result_uuid) = 'insufficient_evidence',
    'different owners sharing one information lineage must not satisfy independence'
  );
end;
$$;

do $$
declare work_uuid uuid; claim_value jsonb; lease_token_value uuid; recovery_one jsonb; recovery_two jsonb; late_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  work_uuid := public.enqueue_team_color_work(
    'hockey-999998',1000,null,'Wake and late-worker recovery fixture.',now()
  );
  recovery_one := public.run_agent_backend_recovery();
  recovery_two := public.run_agent_backend_recovery();
  perform pg_temp.assert_true((
    select count(*) = 1 and bool_and(status = 'pending')
    from public.agent_work_wake_outbox
    where queue_name = 'team_color_specialist' and work_item_id = work_uuid
  ), 'at-least-once wake reconciliation must remain idempotent per eligibility state');
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
  claim_value := public.claim_next_team_color_work(900);
  lease_token_value := (claim_value #>> '{work,lease_token}')::uuid;
  update public.team_color_work_items set lease_expires_at = now() - interval '1 second' where id = work_uuid;
  update public.team_color_work_attempts set lease_expires_at = now() - interval '1 second'
  where work_item_id = work_uuid and ended_at is null;
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  perform public.run_agent_backend_recovery();
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
  begin
    perform public.renew_team_color_work_lease(work_uuid,lease_token_value,900);
  exception when others then late_denied := true; end;
  perform pg_temp.assert_true(late_denied,
    'late worker must be denied after watchdog expires and requeues its lease');
end;
$$;

do $$
declare policy_uuid uuid; inserted_count integer;
begin
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  perform pg_temp.assert_true((
    select policy.review_cadence = interval '6 months'
       and policy.configuration ->> 'age_alone_invalidates_verified_data' = 'false'
    from public.catalog_revalidation_policies policy
    where policy.data_type = 'team_colors' and policy.is_current and policy.active
  ), 'Team Color scheduled revalidation must use the approved six-month cadence without age invalidation');
  perform pg_temp.assert_true(not exists (
    select 1 from public.catalog_fact_revalidation_state state
    join public.catalog_revalidation_policies policy
      on policy.id = state.cadence_policy_id
    where state.data_type = 'team_colors'
      and state.next_review_at is distinct from state.last_verified_at + interval '6 months'
  ), 'existing Team Color revalidation state must inherit the six-month policy');
  policy_uuid := public.admin_create_catalog_revalidation_policy(
    'test-team-color-cadence',1,'team_colors',interval '1 day','{}',true
  );
  update public.catalog_fact_revalidation_state
  set next_review_at = now() - interval '1 second'
  where data_type = 'team_colors'
    and subject_type = 'catalog_team'
    and subject_id = public.resolve_catalog_team_id('hockey-999999')::text;
  inserted_count := public.enqueue_due_catalog_revalidations('team_colors');
  perform pg_temp.assert_true(inserted_count >= 1 and exists (
    select 1 from public.team_color_work_items work
    where work.team_id = public.resolve_catalog_team_id('hockey-999999')
      and work.work_kind = 'verified_recheck'
      and work.recheck_trigger = 'scheduled_review'
      and work.expected_current_color_version_id = (
        select current_fact_version_id from public.catalog_fact_revalidation_state
        where data_type = 'team_colors'
          and subject_type = 'catalog_team'
          and subject_id = public.resolve_catalog_team_id('hockey-999999')::text
      )
  ), 'domain cadence policy must create due Team Color recheck work without un-verifying the fact');
end;
$$;

-- ---------------------------------------------------------------------------
-- Minimal non-Team-Color determinate adapter proving genericity for Quiz/Seat.
-- This entire adapter and its authoritative table are transaction-local.
-- ---------------------------------------------------------------------------

create temporary table mock_determinate_authoritative_versions (
  id uuid primary key default gen_random_uuid(),
  subject_id text not null,
  payload jsonb not null,
  is_current boolean not null default true,
  adjudication_id uuid not null,
  created_at timestamptz not null default now(),
  superseded_at timestamptz
);
create unique index mock_determinate_authoritative_current_idx
on mock_determinate_authoritative_versions(subject_id) where is_current;

create temporary table mock_domain_recovery_calls (
  id bigint generated always as identity primary key,
  called_at timestamptz not null default now()
);

create or replace function pg_temp.mock_determinate_build_context(
  specialist_result_kind_value text,
  specialist_result_uuid uuid,
  verification_round_value integer
)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'subject_type', result.subject_type,
    'subject_id', result.subject_id,
    'subject_reference', result.subject_reference,
    'capability_scope', '{}'::jsonb,
    'verifier_context', jsonb_build_object(
      'question', 'Independently determine the mock factual answer.',
      'verification_round', verification_round_value,
      'subject', result.subject_reference
    )
  )
  from public.agent_specialist_results result
  where specialist_result_kind_value = 'agent_specialist_result'
    and result.id = specialist_result_uuid;
$$;

create or replace function pg_temp.mock_determinate_finalize(
  specialist_result_kind_value text,
  specialist_result_uuid uuid,
  adjudication_uuid uuid,
  authoritative_payload_value jsonb,
  finalization_outcome_value text
)
returns uuid language plpgsql as $$
declare specialist_record public.agent_specialist_results%rowtype; version_uuid uuid;
begin
  select * into strict specialist_record from public.agent_specialist_results
  where id = specialist_result_uuid
    and specialist_result_kind_value = 'agent_specialist_result';
  if finalization_outcome_value <> 'promoted' or not exists (
    select 1 from public.catalog_determinate_adjudications adjudication
    where adjudication.id = adjudication_uuid
      and adjudication.specialist_result_id = specialist_result_uuid
      and adjudication.authoritative_result_payload = authoritative_payload_value
  ) then
    raise exception 'Mock finalizer requires its deterministic adjudication';
  end if;
  update mock_determinate_authoritative_versions
  set is_current = false, superseded_at = now()
  where subject_id = specialist_record.subject_id and is_current;
  insert into mock_determinate_authoritative_versions(
    subject_id,payload,adjudication_id
  ) values (
    specialist_record.subject_id,authoritative_payload_value,adjudication_uuid
  ) returning id into version_uuid;
  return version_uuid;
end;
$$;

create or replace function pg_temp.mock_determinate_compare(verifier_result_uuid uuid)
returns text language plpgsql as $$
declare
  result_record public.catalog_verifier_results%rowtype;
  work_record public.catalog_verification_work_items%rowtype;
  specialist_record public.agent_specialist_results%rowtype;
  adjudication_uuid uuid;
begin
  select * into strict result_record from public.catalog_verifier_results
  where id = verifier_result_uuid;
  select * into strict work_record from public.catalog_verification_work_items
  where id = result_record.verification_work_item_id for update;
  select * into strict specialist_record from public.agent_specialist_results
  where id = work_record.specialist_result_id;
  if work_record.status <> 'result_submitted'
     or result_record.result_kind <> 'determinate'
     or result_record.result_payload <> specialist_record.result_payload then
    raise exception 'Mock deterministic results did not match';
  end if;
  insert into public.catalog_determinate_adjudications(
    data_type,subject_type,subject_id,specialist_result_kind,
    specialist_result_id,verification_policy_id,resolving_verifier_result_id,
    outcome,authoritative_result_payload,resolution_snapshot,decided_by_actor_id
  ) values (
    work_record.data_type,work_record.subject_type,work_record.subject_id,
    work_record.specialist_result_kind,work_record.specialist_result_id,
    work_record.verification_policy_id,result_record.id,'promoted',
    result_record.result_payload,jsonb_build_object('mock_adapter',true),
    result_record.verifier_actor_id
  ) returning id into adjudication_uuid;
  perform public.finalize_catalog_authoritative_result(
    work_record.data_type,work_record.specialist_result_kind,
    work_record.specialist_result_id,adjudication_uuid,
    result_record.result_payload,'promoted'
  );
  insert into public.catalog_verification_comparisons(
    verification_work_item_id,proposal_id,specialist_result_kind,
    specialist_result_id,verification_round,verifier_result_id,policy_id,
    comparison_outcome,normalized_specialist_result,normalized_verifier_result,
    adjudication_id,details
  ) values (
    work_record.id,null,work_record.specialist_result_kind,
    work_record.specialist_result_id,work_record.verification_round,
    result_record.id,work_record.verification_policy_id,'promoted',
    specialist_record.result_payload,result_record.result_payload,
    adjudication_uuid,jsonb_build_object('mock_adapter',true)
  );
  update public.catalog_verification_work_items
  set status = 'completed',completed_at = now()
  where id = work_record.id;
  return 'promoted';
end;
$$;

create or replace function pg_temp.mock_determinate_enqueue_revalidation(state_uuid uuid)
returns uuid language plpgsql as $$
declare job_uuid uuid := gen_random_uuid();
begin
  update public.catalog_fact_revalidation_state
  set active_job_type = 'mock_determinate_specialist',active_job_id = job_uuid,
      updated_at = now()
  where id = state_uuid;
  return job_uuid;
end;
$$;

create or replace function pg_temp.mock_determinate_recover()
returns jsonb language plpgsql as $$
begin
  insert into mock_domain_recovery_calls default values;
  return jsonb_build_object('mock_recovery_called',true);
end;
$$;

create or replace function pg_temp.mock_determinate_reconcile_wakes()
returns integer language sql as $$ select 0; $$;

do $$
declare
  specialist_actor_uuid uuid;
  policy_uuid uuid;
  specialist_result_uuid uuid;
  verification_work_uuid uuid;
  claim_value jsonb;
  lease_uuid uuid;
  verifier_result_uuid uuid;
  authoritative_version_uuid uuid;
  revalidation_state_uuid uuid;
  revalidation_enqueued_count integer;
  lineage_evidence_uuid uuid;
  lineage_work_uuid uuid;
  lineage_claim jsonb;
  lineage_lease_uuid uuid;
  recovery_result jsonb;
  comparison_outcome text;
begin
  select id into specialist_actor_uuid from public.catalog_actors
  where actor_key = 'team-color-test-agent-a';
  insert into public.catalog_actor_capabilities(actor_id,capability)
  select id,'catalog.verify.mock_determinate' from public.catalog_actors
  where actor_key = 'team-color-test-verifier';
  insert into public.verification_policies(
    policy_key,version,data_type,minimum_evidence_count,allowed_trust_tiers,
    require_independent_sources,require_independent_verifier,configuration,
    is_current,active
  ) values (
    'mock-determinate-policy',1,'mock_determinate',0,'{}'::smallint[],
    false,true,jsonb_build_object(
      'automated_adjudication',jsonb_build_object(
        'maximum_verifier_rounds',2,
        'required_matching_verifier_results',2,
        'consensus_strategy','specialist_match_or_verifier_consensus'
      )
    ),true,true
  ) returning id into policy_uuid;
  insert into public.agent_job_runtime_policies(
    policy_key,version,job_type,lease_seconds,retryable_failure_categories,
    permanent_failure_categories,retry_delay_seconds,maximum_attempts,
    exhaustion_status,permanent_failure_status
  ) values (
    'mock-determinate-verifier-runtime',1,'catalog_verifier.mock_determinate',900,
    array['transient'],array['authorization_denied'],array[300],2,
    'needs_review','failed'
  );
  insert into public.agent_job_runtime_policies(
    policy_key,version,job_type,lease_seconds,retryable_failure_categories,
    permanent_failure_categories,retry_delay_seconds,maximum_attempts,
    exhaustion_status,permanent_failure_status
  ) values (
    'mock-determinate-lineage-runtime',1,
    'information_lineage_resolver.mock_determinate',900,
    array['lease_expired'],array['authorization_denied'],array[300],2,
    'needs_review','failed'
  );
  insert into public.information_lineage_resolution_policies(
    policy_key,version,data_type,automatically_permitted_actions,
    configuration,active,is_current
  ) values (
    'mock-determinate-lineage-policy',1,'mock_determinate',
    array['assign_existing']::text[],
    jsonb_build_object(
      'new_lineage_requires_governance',true,
      'lineage_merge_requires_governance',true,
      'test_adapter',true
    ),true,true
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  perform public.admin_register_catalog_domain_adapter(
    'mock_determinate','quiz_question','mock_determinate_specialist',
    'catalog_verifier.mock_determinate','catalog.verify.mock_determinate',
    'pg_temp.mock_determinate_build_context'::regproc,
    'pg_temp.mock_determinate_compare'::regproc,
    'pg_temp.mock_determinate_finalize'::regproc,
    'pg_temp.mock_determinate_enqueue_revalidation'::regproc,
    'pg_temp.mock_determinate_recover'::regproc,
    'pg_temp.mock_determinate_reconcile_wakes'::regproc,
    jsonb_build_object('test_adapter',true),true
  );
  insert into public.agent_specialist_results(
    data_type,job_type,subject_type,subject_id,subject_reference,
    result_kind,result_payload,provenance_summary,submitted_by_actor_id
  ) values (
    'mock_determinate','mock_determinate_specialist','quiz_question','quiz-test-1',
    jsonb_build_object('question_id','quiz-test-1','prompt','Which answer is canonical?'),
    'determinate',jsonb_build_object('answer','A'),
    'Mock specialist independently researched the answer.',specialist_actor_uuid
  ) returning id into specialist_result_uuid;
  verification_work_uuid := public.ensure_catalog_verification_work_for_result(
    'agent_specialist_result',specialist_result_uuid,1,null
  );
  perform pg_temp.assert_true((
    select subject_type = 'quiz_question'
       and proposal_id is null
       and originating_job_type = 'mock_determinate_specialist'
    from public.catalog_verification_work_items where id = verification_work_uuid
  ), 'generic verifier work must not require Team Color, a catalog team, or a catalog proposal');
  insert into public.source_trust_assignments(
    source_id,data_type,trust_tier,is_current
  ) select id,'mock_determinate',3,true
    from public.trusted_sources where source_id = 'team-color-test-tier-1';
  insert into public.source_applicability_versions(
    source_id,data_type,applicability_kind,review_status,is_current
  ) select id,'mock_determinate','global','approved',true
    from public.trusted_sources where source_id = 'team-color-test-tier-1';
  perform public.admin_review_information_lineage(
    'mock-determinate-origin','mock_determinate','Mock determinate origin',
    'https://official.example/mock-determinate-origin','approved',null,
    'Approved mock lineage for the generic comparison barrier test.',
    jsonb_build_object('test',true)
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000004',true);
  claim_value := public.claim_next_catalog_verification_work('mock_determinate');
  lease_uuid := (claim_value #>> '{work,lease_token}')::uuid;
  perform pg_temp.assert_true(
    claim_value #>> '{subject,question_id}' = 'quiz-test-1'
    and claim_value::text not like '%"answer": "A"%',
    'generic verifier context must remain blinded while supporting a Quiz-shaped subject'
  );
  insert into public.catalog_verifier_evidence(
    verification_work_item_id,attempt_number,submitted_by_actor_id,
    source_id,evidence_url,evidence_summary,observed_at,
    source_url_scope_version_id,source_trust_assignment_id,
    source_applicability_version_id,source_independence_assignment_id,
    structured_claim
  )
  select verification_work_uuid,1,actor.id,source.id,
         'https://official.example/mock-determinate-barrier',
         'Mock determinate evidence whose lineage is initially unresolved.',now(),
         scope.id,trust.id,applicability.id,ownership.id,
         jsonb_build_object('answer','A')
  from public.trusted_sources source
  join public.catalog_actors actor
    on actor.actor_key = 'team-color-test-verifier'
  join public.trusted_source_url_scope_versions scope
    on scope.source_id = source.id and scope.is_current
       and scope.review_status = 'approved'
  join public.source_trust_assignments trust
    on trust.source_id = source.id and trust.data_type = 'mock_determinate'
       and trust.is_current
  join public.source_applicability_versions applicability
    on applicability.source_id = source.id
       and applicability.data_type = 'mock_determinate'
       and applicability.is_current and applicability.review_status = 'approved'
  join public.source_independence_group_assignment_versions ownership
    on ownership.source_id = source.id and ownership.is_current
       and ownership.review_status = 'approved'
  where source.source_id = 'team-color-test-tier-1'
  order by scope.created_at desc, ownership.created_at desc
  limit 1
  returning id into lineage_evidence_uuid;
  select id into strict lineage_work_uuid
  from public.information_lineage_resolution_work_items
  where evidence_kind = 'verifier_evidence'
    and evidence_id = lineage_evidence_uuid;
  verifier_result_uuid := public.submit_catalog_verifier_result(
    verification_work_uuid,lease_uuid,'determinate',jsonb_build_object('answer','A'),
    'Mock verifier independently determined the same answer.'
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  comparison_outcome := public.process_catalog_verification_result(
    verifier_result_uuid
  );
  perform pg_temp.assert_true(
    comparison_outcome = 'waiting_on_information_lineage'
    and not exists (
      select 1 from public.catalog_verification_comparisons
      where verifier_result_id = verifier_result_uuid
    )
    and not exists (
      select 1 from public.catalog_determinate_adjudications
      where resolving_verifier_result_id = verifier_result_uuid
    )
    and exists (
      select 1 from public.catalog_verification_work_items
      where id = verification_work_uuid and status = 'result_submitted'
        and failure_category is null
    )
    and exists (
      select 1 from public.catalog_verification_work_events
      where verification_work_item_id = verification_work_uuid
        and event_type = 'waiting_on_information_lineage'
    ),
    'unresolved verifier evidence must generically pause Quiz-shaped determinate comparison without adjudication or escalation'
  );
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000005',true);
  lineage_claim := public.claim_next_information_lineage_resolution_work('mock_determinate');
  perform pg_temp.assert_true(
    (lineage_claim #>> '{work,work_item_id}')::uuid = lineage_work_uuid,
    'generic mock verifier evidence must use normal lineage resolver work'
  );
  perform public.submit_information_lineage_resolution_result(
    lineage_work_uuid,(lineage_claim #>> '{work,lease_token}')::uuid,
    'assign_existing','mock-determinate-origin',
    'Resolver established the mock verifier evidence origin.','{}'
  );
  perform pg_temp.assert_true((
    select count(*) = 1 and bool_and(status = 'pending')
    from public.agent_work_wake_outbox
    where queue_name = 'catalog_verification_comparison'
      and work_item_id = verification_work_uuid
      and eligibility_key = verifier_result_uuid::text
  ), 'generic lineage completion must resume the same non-Team comparison path');
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  perform pg_temp.assert_true(
    public.process_catalog_verification_result(verifier_result_uuid) = 'promoted',
    'lineage-ready non-Team domain comparison adapter must process generically'
  );
  select id into authoritative_version_uuid
  from mock_determinate_authoritative_versions
  where subject_id = 'quiz-test-1' and is_current;
  perform pg_temp.assert_true(authoritative_version_uuid is not null and (
    select count(*) = 1 from mock_determinate_authoritative_versions
    where subject_id = 'quiz-test-1' and is_current
  ), 'domain finalizer must leave exactly one current authoritative fact');
  insert into public.catalog_revalidation_policies(
    policy_key,version,data_type,review_cadence,is_current,active
  ) values ('mock-determinate-cadence',1,'mock_determinate',interval '1 day',true,true);
  insert into public.catalog_fact_revalidation_state(
    data_type,subject_type,subject_id,subject_reference,current_fact_version_id,
    cadence_policy_id,last_verified_at,next_review_at,last_review_outcome
  ) select 'mock_determinate','quiz_question','quiz-test-1',
           jsonb_build_object('question_id','quiz-test-1'),authoritative_version_uuid,
           policy.id,now() - interval '2 days',now() - interval '1 day','verified'
    from public.catalog_revalidation_policies policy
    where policy.data_type = 'mock_determinate' and policy.is_current
  returning id into revalidation_state_uuid;
  revalidation_enqueued_count := public.enqueue_due_catalog_revalidations('mock_determinate');
  perform pg_temp.assert_true(
    revalidation_enqueued_count = 1 and exists (
      select 1 from public.catalog_fact_revalidation_state
      where id = revalidation_state_uuid
        and active_job_type = 'mock_determinate_specialist'
        and active_job_id is not null
    ), 'generic revalidation must dispatch through its registered adapter without Team Color work');
  insert into public.catalog_verifier_evidence(
    verification_work_item_id,attempt_number,submitted_by_actor_id,
    source_id,evidence_url,evidence_summary,observed_at,
    source_url_scope_version_id,source_trust_assignment_id,
    source_applicability_version_id,source_independence_assignment_id,
    structured_claim
  )
  select verification_work_uuid,1,actor.id,source.id,
         'https://official.example/mock-determinate-recovery-lineage',
         'Mock determinate evidence requiring lineage resolution.',now(),
         scope.id,trust.id,applicability.id,ownership.id,
         jsonb_build_object('answer','A')
  from public.trusted_sources source
  join public.catalog_actors actor
    on actor.actor_key = 'team-color-test-verifier'
  join public.trusted_source_url_scope_versions scope
    on scope.source_id = source.id and scope.is_current
       and scope.review_status = 'approved'
  join public.source_trust_assignments trust
    on trust.source_id = source.id and trust.data_type = 'mock_determinate'
       and trust.is_current
  join public.source_applicability_versions applicability
    on applicability.source_id = source.id
       and applicability.data_type = 'mock_determinate'
       and applicability.is_current and applicability.review_status = 'approved'
  join public.source_independence_group_assignment_versions ownership
    on ownership.source_id = source.id and ownership.is_current
       and ownership.review_status = 'approved'
  where source.source_id = 'team-color-test-tier-1'
  order by scope.created_at desc, ownership.created_at desc
  limit 1
  returning id into lineage_evidence_uuid;
  select id into strict lineage_work_uuid
  from public.information_lineage_resolution_work_items
  where evidence_kind = 'verifier_evidence'
    and evidence_id = lineage_evidence_uuid;
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000005',true);
  lineage_claim := public.claim_next_information_lineage_resolution_work('mock_determinate');
  lineage_lease_uuid := (lineage_claim #>> '{work,lease_token}')::uuid;
  perform pg_temp.assert_true(
    (lineage_claim #>> '{work,work_item_id}')::uuid = lineage_work_uuid
    and (lineage_claim #>> '{evidence,evidence_id}')::uuid = lineage_evidence_uuid
    and public.renew_information_lineage_resolution_work_lease(
      lineage_work_uuid,lineage_lease_uuid
    ) > now(),
    'lineage-resolution work must support a durable renewable lease'
  );
  update public.information_lineage_resolution_work_items
  set lease_expires_at = now() - interval '1 second'
  where id = lineage_work_uuid;
  update public.information_lineage_resolution_attempts
  set lease_expires_at = now() - interval '1 second'
  where work_item_id = lineage_work_uuid and ended_at is null;
  perform set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
  recovery_result := public.run_agent_backend_recovery();
  perform pg_temp.assert_true(
    (recovery_result ->> 'lineage_expired')::integer = 1 and exists (
      select 1 from public.information_lineage_resolution_work_items
      where id = lineage_work_uuid and status = 'retry_wait'
        and claimed_by_actor_id is null and lease_token is null
    ), 'generic watchdog must recover an expired lineage-resolution worker through backend policy');
  perform pg_temp.assert_true((select count(*) > 0 from mock_domain_recovery_calls),
    'generic watchdog must invoke registered domain recovery adapters');
  perform pg_temp.assert_true(not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'catalog_fact_revalidation_state'
      and column_name in ('target_team_id','active_work_item_id')
  ), 'generic revalidation state must contain no Team Color structural dependency');
end;
$$;

-- Direct grants remain read-only; all mutations are capability-checked RPCs.
do $$
begin
  perform pg_temp.assert_true(not has_table_privilege('authenticated', 'public.team_color_work_items', 'INSERT'), 'authenticated role must not insert queue rows directly');
  perform pg_temp.assert_true(not has_table_privilege('authenticated', 'public.team_color_work_items', 'UPDATE'), 'authenticated role must not update queue rows directly');
  perform pg_temp.assert_true(not has_table_privilege('authenticated', 'public.team_color_source_candidates', 'INSERT'), 'authenticated role must not insert source candidates directly');
  perform pg_temp.assert_true(not has_table_privilege('authenticated', 'public.catalog_verification_work_items', 'INSERT'), 'authenticated role must not insert verifier jobs directly');
  perform pg_temp.assert_true(not has_table_privilege('authenticated', 'public.catalog_verifier_results', 'INSERT'), 'authenticated role must not insert verifier results directly');
  perform pg_temp.assert_true(not has_table_privilege('authenticated', 'public.catalog_verification_comparisons', 'INSERT'), 'authenticated role must not insert comparison outcomes directly');
  perform pg_temp.assert_true(not has_table_privilege('authenticated', 'public.agent_work_wake_outbox', 'UPDATE'), 'authenticated role must not mutate wake records directly');
  perform pg_temp.assert_true(not has_table_privilege('authenticated', 'public.information_lineage_versions', 'UPDATE'), 'authenticated role must not mutate lineage governance directly');
end;
$$;

rollback;
