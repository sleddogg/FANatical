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
  ('00000000-0000-0000-0000-000000000000', '71000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'team-color-test-verifier@fanatical.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.staff_roles(user_id, role, permissions, is_active)
values ('71000000-0000-0000-0000-000000000001', 'admin', array[]::text[], true);

insert into public.catalog_actors(actor_key, actor_type, auth_user_id, display_name)
values
  ('team-color-test-agent-a', 'agent', '71000000-0000-0000-0000-000000000002', 'Team Color Test Agent A'),
  ('team-color-test-agent-b', 'agent', '71000000-0000-0000-0000-000000000003', 'Team Color Test Agent B'),
  ('team-color-test-verifier', 'human', '71000000-0000-0000-0000-000000000004', 'Team Color Test Verifier');

insert into public.catalog_teams(team_id, sport_id)
select fixture.team_id, sport.id
from (values
  ('hockey-999991'), ('hockey-999992'), ('hockey-999993'), ('hockey-999994')
) fixture(team_id)
cross join public.catalog_sports sport
where sport.sport_id = 'hockey';

insert into public.team_identity_versions(
  team_id, display_name, short_name, active, record_status
)
select team.id, fixture.display_name, fixture.display_name, true, 'imported_unverified'
from (values
  ('hockey-999991', 'Agent Queue Test One'),
  ('hockey-999992', 'Agent Queue Test Two'),
  ('hockey-999993', 'Agent Version Guard Test'),
  ('hockey-999994', 'Agent Verified Replacement Test')
) fixture(team_id, display_name)
join public.catalog_teams team on team.team_id = fixture.team_id;

insert into public.team_primary_league_versions(team_id, league_id, record_status)
select team.id, league.id, 'imported_unverified'
from public.catalog_teams team
cross join public.catalog_leagues league
where team.team_id like 'hockey-99999%'
  and league.league_id = 'hockey-nhl';

insert into public.team_color_versions(
  team_id, primary_color, secondary_color, tertiary_color,
  record_status, effective_from, effective_from_precision
)
select team.id, fixture.primary_color, fixture.secondary_color, '#FFFFFF',
       fixture.record_status, date '2020-01-01', 'day'
from (values
  ('hockey-999993', '#111111', '#222222', 'imported_unverified'),
  ('hockey-999994', '#333333', '#444444', 'verified')
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
  ('catalog.propose.team_colors')
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
where actor.actor_key = 'team-color-test-verifier';

insert into public.source_independence_groups(group_id, display_name)
values
  ('team-color-test-official-owner', 'Test Official Owner'),
  ('team-color-test-independent-owner', 'Test Independent Owner'),
  ('team-color-test-second-independent-owner', 'Test Second Independent Owner'),
  ('team-color-test-third-owner', 'Test Third Owner');

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
  ('team-color-test-tier-3-conflict', 'Test Conflicting Reference', 'https://conflict.example', 'https://conflict.example/team-colors', 'team-color-test-third-owner')
) fixture(source_id, display_name, base_url, reference_url, group_id)
join public.source_independence_groups independence on independence.group_id = fixture.group_id;

insert into public.source_trust_assignments(source_id, data_type, trust_tier, effective_from, notes)
select source.id, 'team_colors', fixture.trust_tier, current_date, 'Transactional test assignment.'
from (values
  ('team-color-test-tier-1', 1),
  ('team-color-test-tier-3', 3),
  ('team-color-test-tier-3-second', 3),
  ('team-color-test-tier-3-conflict', 3)
) fixture(source_id, trust_tier)
join public.trusted_sources source on source.source_id = fixture.source_id;

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
begin
  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000003', true);
  claim_value := public.claim_next_team_color_work(900);
  perform pg_temp.assert_true(claim_value #>> '{team,team_id}' = 'hockey-999992', 'scoped agent must skip higher-priority out-of-scope teams');
  work_id := (claim_value #>> '{work,work_item_id}')::uuid;
  lease_token_value := (claim_value #>> '{work,lease_token}')::uuid;

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
    perform public.add_catalog_proposal_evidence(
      proposal_id_value, 'team-color-agent-pending-candidate',
      'https://candidate.example/evidence', 'Must not attach before source review.', now(), true
    );
  exception when others then
    pending_source_rejected := true;
  end;
  perform pg_temp.assert_true(pending_source_rejected, 'pending source candidate cannot be attached as proposal evidence');

  perform public.add_catalog_proposal_evidence(
    proposal_id_value, 'team-color-test-tier-3',
    'https://independent.example/team-colors/first',
    'First page from one independent owner supports the palette.', now(), true
  );
  perform public.add_catalog_proposal_evidence(
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
  perform pg_temp.assert_true(independence_rejected, 'two evidence pages from one ownership group must fail source independence');

  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000002', true);
  perform public.add_catalog_proposal_evidence(
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
  perform pg_temp.assert_true(high_trust_rejected, 'independent Tier 3-only evidence must fail the Tier 1/2 minimum');

  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000002', true);
  perform public.add_catalog_proposal_evidence(
    proposal_id_value, 'team-color-test-tier-1',
    'https://official.example/brand.pdf',
    'Official source lists #555555, #666666, and #FFFFFF.', now(), true
  );
  perform public.add_catalog_proposal_evidence(
    proposal_id_value, 'team-color-test-tier-3-conflict',
    'https://conflict.example/team-colors',
    'Conflicting source reports a different secondary color.', now(), false
  );

  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000004', true);
  perform public.review_catalog_proposal(proposal_id_value, 'approved', 'Independent verifier approved the tested palette.');

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
       and evidence_snapshot::text like '%trust_assignment_id%'
    from public.catalog_verification_decisions where proposal_id = proposal_id_value
  ), 'decision must snapshot supporting and conflicting evidence with immutable details');
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
  claim_value := public.claim_next_team_color_work(900);
  perform pg_temp.assert_true((claim_value #>> '{work,work_item_id}')::uuid = work_id, 'expired lease must return work to the retry queue');
  perform pg_temp.assert_true((claim_value #>> '{work,attempt_number}')::integer = 2, 'reclaimed work must retain attempt history');
  lease_token_value := (claim_value #>> '{work,lease_token}')::uuid;
  perform public.finish_team_color_work(
    work_id, lease_token_value, 'retry', 'rate_limited', 'Source temporarily rate limited.',
    now() + interval '5 minutes', '{}'::jsonb
  );
  perform pg_temp.assert_true((
    select status = 'retry_wait' and attempt_count = 2
    from public.team_color_work_items where id = work_id
  ), 'retry outcome must retain the work and its attempts');
  perform pg_temp.assert_true((
    select count(*) = 2 and bool_or(outcome = 'lease_expired') and bool_or(outcome = 'retry')
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
  stale_rejected boolean := false;
  old_version_id uuid;
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
  perform public.add_catalog_proposal_evidence(proposal_id_value, 'team-color-test-tier-1', 'https://official.example/version-guard', 'Official support.', now(), true);
  perform public.add_catalog_proposal_evidence(proposal_id_value, 'team-color-test-tier-3', 'https://independent.example/version-guard', 'Independent support.', now(), true);
  perform public.finish_team_color_work(work_id, lease_token_value, 'submitted_for_verification', null, null, null, '{}'::jsonb);

  update public.team_color_versions
  set is_current = false, effective_to = current_date, superseded_at = now()
  where id = old_version_id;
  insert into public.team_color_versions(team_id, primary_color, secondary_color, record_status)
  values (public.resolve_catalog_team_id('hockey-999993'), '#999999', '#AAAAAA', 'imported_unverified');

  perform set_config('request.jwt.claim.sub', '71000000-0000-0000-0000-000000000004', true);
  begin
    perform public.review_catalog_proposal(proposal_id_value, 'approved', 'Must fail because current version changed.');
  exception when others then
    stale_rejected := true;
  end;
  perform pg_temp.assert_true(stale_rejected, 'approval must fail after the expected current version changes');
end;
$$;

do $$
declare
  policy_record public.verification_policies%rowtype;
begin
  select * into strict policy_record from public.verification_policies
  where data_type = 'team_colors' and is_current and active;
  perform pg_temp.assert_true(policy_record.version = 2, 'Team Color policy v2 must be current');
  perform pg_temp.assert_true(policy_record.require_independent_verifier, 'Team Color policy must require an independent verifier');
  perform pg_temp.assert_true(policy_record.minimum_evidence_count = 2, 'Team Color policy must require two evidence rows');
  perform pg_temp.assert_true(policy_record.require_independent_sources, 'Team Color policy must require independent ownership groups');
  perform pg_temp.assert_true(policy_record.configuration ? 'trust_tier_rubric', 'policy must retain the Tier 1-5 rubric');
  perform pg_temp.assert_true((policy_record.configuration ->> 'minimum_tier_1_or_2_evidence_count')::integer = 1, 'policy must require one Tier 1/2 source');
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

-- Direct grants remain read-only; all mutations are capability-checked RPCs.
do $$
begin
  perform pg_temp.assert_true(not has_table_privilege('authenticated', 'public.team_color_work_items', 'INSERT'), 'authenticated role must not insert queue rows directly');
  perform pg_temp.assert_true(not has_table_privilege('authenticated', 'public.team_color_work_items', 'UPDATE'), 'authenticated role must not update queue rows directly');
  perform pg_temp.assert_true(not has_table_privilege('authenticated', 'public.team_color_source_candidates', 'INSERT'), 'authenticated role must not insert source candidates directly');
end;
$$;

rollback;
