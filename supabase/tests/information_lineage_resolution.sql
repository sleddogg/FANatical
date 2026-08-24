-- Focused transactional coverage for the operational generic information-
-- lineage resolution path. All fixtures roll back.

begin;

create or replace function pg_temp.assert_true(
  condition_value boolean,
  message_value text
)
returns void
language plpgsql
as $$
begin
  if not coalesce(condition_value, false) then
    raise exception 'Information-lineage resolution assertion failed: %', message_value;
  end if;
end;
$$;

insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('00000000-0000-0000-0000-000000000000', '72000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'lineage-admin@fanatical.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '72000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'lineage-specialist@fanatical.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '72000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'lineage-resolver@fanatical.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '72000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'lineage-reviewer@fanatical.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.staff_roles(user_id, role, permissions, is_active)
values ('72000000-0000-0000-0000-000000000001', 'admin', array[]::text[], true);

insert into public.catalog_actors(actor_key, actor_type, auth_user_id, display_name)
values
  ('lineage-test-specialist', 'agent', '72000000-0000-0000-0000-000000000002', 'Lineage Test Specialist'),
  ('lineage-test-resolver', 'agent', '72000000-0000-0000-0000-000000000003', 'Lineage Test Resolver'),
  ('lineage-test-reviewer', 'human', '72000000-0000-0000-0000-000000000004', 'Lineage Test Reviewer');

insert into public.catalog_actor_capabilities(actor_id, capability)
select id, 'information_lineage.resolve'
from public.catalog_actors where actor_key = 'lineage-test-resolver';
insert into public.catalog_actor_capabilities(actor_id, capability)
select id, 'information_lineage.review'
from public.catalog_actors where actor_key = 'lineage-test-reviewer';

do $$
declare
  team_runtime public.agent_job_runtime_policies%rowtype;
  verifier_runtime public.agent_job_runtime_policies%rowtype;
begin
  select * into strict team_runtime
  from public.current_agent_job_runtime_policy(
    'information_lineage_resolver.team_colors'
  );
  select * into strict verifier_runtime
  from public.current_agent_job_runtime_policy('catalog_verifier.team_colors');
  perform pg_temp.assert_true(
    exists (
      select 1
      from public.information_lineage_resolution_policies policy
      where policy.data_type = 'team_colors'
        and policy.policy_key = 'team-color-information-lineage-resolution'
        and policy.version = 1 and policy.is_current and policy.active
        and policy.automatically_permitted_actions = array['assign_existing']::text[]
        and (policy.configuration ->> 'new_lineage_requires_governance')::boolean
        and (policy.configuration ->> 'lineage_merge_requires_governance')::boolean
    ),
    'Team Color must have an active versioned resolution policy'
  );
  perform pg_temp.assert_true(
    team_runtime.lease_seconds = verifier_runtime.lease_seconds
    and team_runtime.retryable_failure_categories = verifier_runtime.retryable_failure_categories
    and team_runtime.permanent_failure_categories = verifier_runtime.permanent_failure_categories
    and team_runtime.retry_delay_seconds = verifier_runtime.retry_delay_seconds
    and team_runtime.maximum_attempts = verifier_runtime.maximum_attempts
    and team_runtime.exhaustion_status = verifier_runtime.exhaustion_status
    and team_runtime.permanent_failure_status = verifier_runtime.permanent_failure_status,
    'Team Color lineage resolution must reuse the approved determinate-verifier runtime values'
  );
end;
$$;

-- Configure a Team Data determinate fact type through the same generic
-- policy/runtime records. No domain-specific lineage tables or functions are
-- introduced.
do $$
declare
  approved_runtime public.agent_job_runtime_policies%rowtype;
begin
  perform set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000001', true);
  perform public.admin_create_information_lineage_resolution_policy(
    'team-identity-lineage-resolution-test', 1, 'team_identity',
    array['assign_existing']::text[],
    jsonb_build_object(
      'new_lineage_requires_governance', true,
      'lineage_merge_requires_governance', true,
      'test_domain', 'quiz'
    ), true
  );
  select * into strict approved_runtime
  from public.current_agent_job_runtime_policy(
    'information_lineage_resolver.team_colors'
  );
  perform public.admin_create_agent_job_runtime_policy(
    'team-identity-lineage-resolver-runtime-test', 1,
    'information_lineage_resolver.team_identity',
    approved_runtime.lease_seconds,
    approved_runtime.retryable_failure_categories,
    approved_runtime.permanent_failure_categories,
    approved_runtime.retry_delay_seconds,
    approved_runtime.maximum_attempts,
    approved_runtime.exhaustion_status,
    approved_runtime.permanent_failure_status,
    jsonb_build_object('test_domain', 'quiz'), true
  );
end;
$$;

insert into public.source_independence_groups(group_id, display_name)
values ('lineage-resolution-test-owner', 'Lineage Resolution Test Owner');

insert into public.trusted_sources(
  source_id, display_name, base_url, reference_url,
  independence_group_id, review_status
)
select
  'lineage-resolution-test-source', 'Lineage Resolution Test Source',
  'https://lineage-test.example', 'https://lineage-test.example/about',
  ownership.id, 'approved'
from public.source_independence_groups ownership
where ownership.group_id = 'lineage-resolution-test-owner';

insert into public.trusted_source_url_scope_versions(
  source_id, hostname, include_subdomains, path_prefix, path_match,
  scope_kind, review_status
)
select id, 'lineage-test.example', false, '/', 'prefix', 'publisher', 'approved'
from public.trusted_sources where source_id = 'lineage-resolution-test-source';

insert into public.source_independence_group_assignment_versions(
  source_id, independence_group_id, review_status
)
select source.id, source.independence_group_id, 'approved'
from public.trusted_sources source
where source.source_id = 'lineage-resolution-test-source';

insert into public.source_trust_assignments(
  source_id, data_type, trust_tier, is_current
)
select id, 'team_identity', 3, true
from public.trusted_sources where source_id = 'lineage-resolution-test-source';

insert into public.source_applicability_versions(
  source_id, data_type, applicability_kind, review_status, is_current
)
select id, 'team_identity', 'global', 'approved', true
from public.trusted_sources where source_id = 'lineage-resolution-test-source';

do $$
declare
  specialist_actor_uuid uuid;
  proposal_uuid uuid;
begin
  select id into strict specialist_actor_uuid
  from public.catalog_actors where actor_key = 'lineage-test-specialist';
  insert into public.catalog_change_proposals(
    fact_type, operation, proposed_public_id, payload, proposed_by_actor_id
  ) values (
    'team_identity', 'create', 'team-identity-lineage-test',
    jsonb_build_object(
      'question', 'Which team won the fictional test final?',
      'answer', 'The answer must never enter resolver context.'
    ), specialist_actor_uuid
  ) returning id into proposal_uuid;
  perform set_config('lineage_test.proposal_id', proposal_uuid::text, true);
end;
$$;

-- Existing lineages and prospective merge history are governed separately
-- from source ownership.
do $$
declare
  lineage_a_version uuid;
begin
  perform set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000004', true);
  lineage_a_version := public.admin_review_information_lineage(
    'quiz-origin-a', 'team_identity', 'Quiz Origin A',
    'https://origin-a.example/data', 'approved', null,
    'Independent lineage review.', jsonb_build_object('test', true)
  );
  perform pg_temp.assert_true(lineage_a_version is not null,
    'reviewer must be able to create an approved lineage without resolver capability');
end;
$$;

-- Unknown evidence automatically becomes durable generic lineage work.
do $$
declare
  proposal_uuid uuid := current_setting('lineage_test.proposal_id')::uuid;
  evidence_uuid uuid;
  work_uuid uuid;
  denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000002', true);
  evidence_uuid := public.add_catalog_proposal_evidence(
    proposal_uuid, 'lineage-resolution-test-source',
    'https://lineage-test.example/reports/quiz-one',
    'This arbitrary factual summary must not be sent to the lineage resolver.',
    now(), true
  );
  select id into strict work_uuid
  from public.information_lineage_resolution_work_items
  where evidence_kind = 'proposal_evidence' and evidence_id = evidence_uuid;
  perform set_config('lineage_test.first_evidence_id', evidence_uuid::text, true);
  perform set_config('lineage_test.first_work_id', work_uuid::text, true);
  perform pg_temp.assert_true(exists (
    select 1 from public.agent_work_wake_outbox wake
    where wake.queue_name = 'information_lineage_resolver.team_identity'
      and wake.work_item_id = work_uuid and wake.status = 'pending'
  ), 'unknown Team Data evidence must emit durable generic lineage-resolution work');
  begin
    perform public.claim_next_information_lineage_resolution_work('team_identity');
  exception when others then
    denied := sqlerrm like '%Information-lineage resolver capability is required%';
  end;
  perform pg_temp.assert_true(denied,
    'a factual specialist must not acquire resolver authority by submitting evidence');
end;
$$;

do $$
declare
  claim_value jsonb;
  work_uuid uuid := current_setting('lineage_test.first_work_id')::uuid;
  evidence_uuid uuid := current_setting('lineage_test.first_evidence_id')::uuid;
  lease_uuid uuid;
  result_uuid uuid;
  denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000003', true);
  claim_value := public.claim_next_information_lineage_resolution_work('team_identity');
  lease_uuid := (claim_value #>> '{work,lease_token}')::uuid;
  perform pg_temp.assert_true(
    (claim_value #>> '{work,work_item_id}')::uuid = work_uuid
    and claim_value #>> '{work,data_type}' = 'team_identity'
    and (claim_value #>> '{evidence,evidence_id}')::uuid = evidence_uuid
    and claim_value #>> '{evidence,evidence_location}' =
      'https://lineage-test.example/reports/quiz-one'
    and claim_value #>> '{evidence,current_canonical_source,source_id}' =
      'lineage-resolution-test-source',
    'resolver claim must return the assigned evidence identity and location'
  );
  perform pg_temp.assert_true(
    claim_value::text not like '%answer%'
    and claim_value::text not like '%arbitrary factual summary%'
    and claim_value::text not like '%structured_claim%'
    and claim_value::text not like '%trust_tier%'
    and claim_value::text not like '%reliability%'
    and claim_value::text not like '%independence_group%'
    and claim_value::text not like '%ownership%'
    and claim_value::text not like '%notes%',
    'resolver context must exclude factual answers, reasoning, other evidence, and unrelated governance context'
  );
  perform pg_temp.assert_true(
    claim_value -> 'approved_lineage_candidates' @>
      jsonb_build_array(jsonb_build_object('lineage_key', 'quiz-origin-a')),
    'resolver context must expose only the approved candidate lineage catalog needed for assignment'
  );
  begin
    perform public.admin_review_information_lineage(
      'resolver-must-not-govern', 'team_identity', 'Forbidden Resolver Lineage',
      null, 'approved', null, 'Forbidden.', '{}'::jsonb
    );
  exception when others then
    denied := sqlerrm like '%Information-lineage review capability is required%';
  end;
  perform pg_temp.assert_true(denied,
    'resolver capability must not confer lineage-governance authority');
  result_uuid := public.submit_information_lineage_resolution_result(
    work_uuid, lease_uuid, 'assign_existing', 'quiz-origin-a',
    'The assigned document originates from the approved Quiz Origin A dataset.',
    jsonb_build_object('research_method', 'publisher attribution')
  );
  perform pg_temp.assert_true(exists (
    select 1
    from public.information_lineage_resolution_results result
    join public.catalog_evidence_lineage_assignments assignment
      on assignment.resolution_result_id = result.id and assignment.is_current
    join public.information_lineage_versions version
      on version.id = assignment.information_lineage_version_id
    join public.information_lineages lineage on lineage.id = version.lineage_id
    where result.id = result_uuid
      and result.disposition = 'automatically_applied'
      and lineage.lineage_key = 'quiz-origin-a'
  ) and exists (
    select 1 from public.information_lineage_resolution_work_items
    where id = work_uuid and status = 'completed'
      and claimed_by_actor_id is null and lease_token is null
  ) and (
    select information_lineage_version_id is null
    from public.catalog_proposal_evidence where id = evidence_uuid
  ), 'existing-lineage resolution must apply through an auditable overlay without rewriting historical evidence');
end;
$$;

-- A resolver may propose a new lineage, but only the separate reviewer can
-- create/approve it and apply the result.
do $$
declare
  proposal_uuid uuid := current_setting('lineage_test.proposal_id')::uuid;
  evidence_uuid uuid;
  work_uuid uuid;
  claim_value jsonb;
  result_uuid uuid;
  denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000002', true);
  evidence_uuid := public.add_catalog_proposal_evidence(
    proposal_uuid, 'lineage-resolution-test-source',
    'https://lineage-test.example/reports/quiz-two', null, now(), true
  );
  select id into strict work_uuid
  from public.information_lineage_resolution_work_items
  where evidence_kind = 'proposal_evidence' and evidence_id = evidence_uuid;
  perform set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000003', true);
  claim_value := public.claim_next_information_lineage_resolution_work('team_identity');
  result_uuid := public.submit_information_lineage_resolution_result(
    work_uuid, (claim_value #>> '{work,lease_token}')::uuid,
    'propose_new', 'quiz-origin-new',
    'The document identifies a distinct originating dataset.',
    jsonb_build_object('publisher_statement', 'independent dataset')
  );
  begin
    perform public.apply_information_lineage_resolution_result(
      result_uuid, 'quiz-origin-a', 'Resolver must not apply its own proposal.', '{}'::jsonb
    );
  exception when others then
    denied := sqlerrm like '%Information-lineage review capability is required%';
  end;
  perform pg_temp.assert_true(denied and exists (
    select 1 from public.information_lineage_resolution_work_items
    where id = work_uuid and status = 'needs_review'
  ), 'new-lineage proposals must wait durably for separate governance');

  perform set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000004', true);
  perform public.admin_review_information_lineage(
    'quiz-origin-new', 'team_identity', 'Quiz Origin New',
    'https://origin-new.example/data', 'approved', null,
    'Reviewer confirmed a distinct origin.', jsonb_build_object('reviewed_result_id', result_uuid)
  );
  perform public.apply_information_lineage_resolution_result(
    result_uuid, 'quiz-origin-new',
    'Reviewer confirmed and applied the proposed lineage.',
    jsonb_build_object('reviewed_against', 'origin documentation')
  );
  perform pg_temp.assert_true(exists (
    select 1
    from public.catalog_evidence_lineage_assignments assignment
    join public.information_lineage_versions version
      on version.id = assignment.information_lineage_version_id
    join public.information_lineages lineage on lineage.id = version.lineage_id
    where assignment.resolution_result_id = result_uuid
      and lineage.lineage_key = 'quiz-origin-new'
  ) and exists (
    select 1 from public.information_lineage_resolution_work_items
    where id = work_uuid and status = 'completed'
  ), 'reviewed new-lineage proposals must apply through the controlled generic backend function');
end;
$$;

-- Later discovery that two lineages share one origin creates a new merged
-- lineage version. Historical versions/assignments remain; current root lookup
-- applies the correction prospectively.
do $$
declare
  old_alias_version uuid;
  merged_alias_version uuid;
  proposal_uuid uuid := current_setting('lineage_test.proposal_id')::uuid;
  evidence_uuid uuid;
  work_uuid uuid;
  claim_value jsonb;
  canonical_version_uuid uuid;
begin
  perform set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000004', true);
  old_alias_version := public.admin_review_information_lineage(
    'quiz-origin-alias', 'team_identity', 'Apparently Separate Quiz Origin',
    'https://origin-alias.example/data', 'approved', null,
    'Initially reviewed as distinct.', jsonb_build_object('initial_review', true)
  );
  merged_alias_version := public.admin_review_information_lineage(
    'quiz-origin-alias', 'team_identity', 'Apparently Separate Quiz Origin',
    'https://origin-alias.example/data', 'merged', 'quiz-origin-a',
    'Later evidence established the shared origin.', jsonb_build_object('prospective_correction', true)
  );
  perform pg_temp.assert_true(
    old_alias_version <> merged_alias_version
    and (select not is_current from public.information_lineage_versions where id = old_alias_version)
    and (select is_current and review_status = 'merged'
         from public.information_lineage_versions where id = merged_alias_version),
    'lineage merge must preserve the historical approved version and append a prospective correction'
  );

  perform set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000002', true);
  evidence_uuid := public.add_catalog_proposal_evidence(
    proposal_uuid, 'lineage-resolution-test-source',
    'https://lineage-test.example/reports/quiz-three', null, now(), true
  );
  select id into strict work_uuid
  from public.information_lineage_resolution_work_items
  where evidence_kind = 'proposal_evidence' and evidence_id = evidence_uuid;
  perform set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000003', true);
  claim_value := public.claim_next_information_lineage_resolution_work('team_identity');
  perform public.submit_information_lineage_resolution_result(
    work_uuid, (claim_value #>> '{work,lease_token}')::uuid,
    'assign_existing', 'quiz-origin-alias',
    'Research found the evidence under the formerly separate lineage name.', '{}'::jsonb
  );
  canonical_version_uuid := public.current_approved_information_lineage_version(
    'quiz-origin-a', 'team_identity'
  );
  perform pg_temp.assert_true((
    select assignment.information_lineage_version_id = canonical_version_uuid
    from public.catalog_evidence_lineage_assignments assignment
    where assignment.evidence_kind = 'proposal_evidence'
      and assignment.evidence_id = evidence_uuid and assignment.is_current
  ), 'assigning a merged lineage key must resolve to its current canonical root');
end;
$$;

-- Unknown remains explicit durable work, and wake reconciliation is idempotent
-- through the existing recovery path.
do $$
declare
  proposal_uuid uuid := current_setting('lineage_test.proposal_id')::uuid;
  evidence_uuid uuid;
  work_uuid uuid;
  claim_value jsonb;
  first_recovery jsonb;
  second_recovery jsonb;
begin
  perform set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000002', true);
  evidence_uuid := public.add_catalog_proposal_evidence(
    proposal_uuid, 'lineage-resolution-test-source',
    'https://lineage-test.example/reports/quiz-unresolved', null, now(), true
  );
  select id into strict work_uuid
  from public.information_lineage_resolution_work_items
  where evidence_kind = 'proposal_evidence' and evidence_id = evidence_uuid;
  perform set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000001', true);
  first_recovery := public.run_agent_backend_recovery();
  second_recovery := public.run_agent_backend_recovery();
  perform pg_temp.assert_true(
    first_recovery ->> 'status' = 'completed'
    and second_recovery ->> 'status' = 'completed'
    and (first_recovery ->> 'wakes_reconciled')::integer >= 1
    and (second_recovery ->> 'wakes_reconciled')::integer >= 1
    and (
      select count(*) = 1 from public.agent_work_wake_outbox wake
      where wake.queue_name = 'information_lineage_resolver.team_identity'
        and wake.work_item_id = work_uuid
        and wake.event_kind = 'work_ready'
        and wake.eligibility_key like 'queued:%'
    ), 'repeated generic recovery must reconcile one idempotent eligibility wake'
  );
  perform set_config('request.jwt.claim.sub', '72000000-0000-0000-0000-000000000003', true);
  claim_value := public.claim_next_information_lineage_resolution_work('team_identity');
  perform public.submit_information_lineage_resolution_result(
    work_uuid, (claim_value #>> '{work,lease_token}')::uuid,
    'unresolved', null,
    'Available attribution is insufficient; no lineage was guessed.',
    jsonb_build_object('follow_up_needed', true)
  );
  perform pg_temp.assert_true(exists (
    select 1
    from public.information_lineage_resolution_work_items work
    join public.information_lineage_resolution_results result
      on result.work_item_id = work.id
    where work.id = work_uuid and work.status = 'unresolved'
      and result.disposition = 'unresolved'
      and result.resolution_action = 'unresolved'
  ), 'an unknown lineage must remain durable unresolved work instead of being guessed');
end;
$$;

do $$
begin
  perform pg_temp.assert_true(
    not has_table_privilege(
      'authenticated', 'public.catalog_evidence_lineage_assignments', 'INSERT'
    ),
    'lineage assignments must be writable only through controlled backend functions'
  );
end;
$$;

rollback;
