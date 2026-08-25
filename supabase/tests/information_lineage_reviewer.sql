-- Focused transactional coverage for the durable information-lineage reviewer
-- lifecycle. All fixtures and decisions roll back.

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
    raise exception 'Information-lineage reviewer assertion failed: %', message_value;
  end if;
end;
$$;

insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('00000000-0000-0000-0000-000000000000', '75000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'lineage-review-admin@fanatical.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '75000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'lineage-review-specialist@fanatical.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '75000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'lineage-review-resolver@fanatical.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '75000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'lineage-review-reviewer@fanatical.invalid', '', now(), '{}'::jsonb, '{}'::jsonb, now(), now());

insert into public.staff_roles(user_id, role, permissions, is_active)
values ('75000000-0000-0000-0000-000000000001', 'admin', array[]::text[], true);

insert into public.catalog_actors(
  actor_key, actor_type, auth_user_id, display_name
)
values
  ('lineage-review-test-specialist', 'agent', '75000000-0000-0000-0000-000000000002', 'Lineage Review Test Specialist'),
  ('lineage-review-test-resolver', 'agent', '75000000-0000-0000-0000-000000000003', 'Lineage Review Test Resolver'),
  ('lineage-review-test-reviewer', 'agent', '75000000-0000-0000-0000-000000000004', 'Lineage Review Test Reviewer');

insert into public.catalog_actor_capabilities(actor_id, capability)
select id, 'information_lineage.resolve'
from public.catalog_actors where actor_key = 'lineage-review-test-resolver';
insert into public.catalog_actor_capabilities(actor_id, capability)
select id, 'information_lineage.review'
from public.catalog_actors where actor_key = 'lineage-review-test-reviewer';

insert into public.catalog_teams(team_id, sport_id)
select 'hockey-998201', sport.id
from public.catalog_sports sport where sport.sport_id = 'hockey';
insert into public.team_identity_versions(
  team_id, display_name, short_name, active, record_status
)
select id, 'Lineage Reviewer Team', 'Reviewer Team', true,
       'imported_unverified'
from public.catalog_teams where team_id = 'hockey-998201';
insert into public.team_primary_league_versions(
  team_id, league_id, record_status
)
select team.id, league.id, 'imported_unverified'
from public.catalog_teams team
join public.catalog_leagues league on league.league_id = 'hockey-nhl'
where team.team_id = 'hockey-998201';

-- A non-Team-Color determinate factual type uses the same resolver/reviewer
-- lifecycle by registering ordinary versioned runtime and resolution policy.
do $$
declare
  resolver_runtime public.agent_job_runtime_policies%rowtype;
begin
  select * into strict resolver_runtime
  from public.current_agent_job_runtime_policy(
    'information_lineage_resolver.team_colors'
  );
  insert into public.agent_job_runtime_policies(
    policy_key, version, job_type, lease_seconds,
    retryable_failure_categories, permanent_failure_categories,
    retry_delay_seconds, maximum_attempts, exhaustion_status,
    permanent_failure_status, configuration
  ) values
  (
    'team-identity-lineage-resolver-review-test', 1,
    'information_lineage_resolver.team_identity',
    resolver_runtime.lease_seconds,
    resolver_runtime.retryable_failure_categories,
    resolver_runtime.permanent_failure_categories,
    resolver_runtime.retry_delay_seconds,
    resolver_runtime.maximum_attempts,
    resolver_runtime.exhaustion_status,
    resolver_runtime.permanent_failure_status,
    jsonb_build_object('test_domain', 'team_data')
  ),
  (
    'team-identity-lineage-reviewer-test', 1,
    'information_lineage_reviewer.team_identity',
    resolver_runtime.lease_seconds,
    resolver_runtime.retryable_failure_categories,
    resolver_runtime.permanent_failure_categories,
    resolver_runtime.retry_delay_seconds,
    resolver_runtime.maximum_attempts,
    resolver_runtime.exhaustion_status,
    resolver_runtime.permanent_failure_status,
    jsonb_build_object('test_domain', 'team_data')
  );
  insert into public.information_lineage_resolution_policies(
    policy_key, version, data_type, automatically_permitted_actions,
    configuration, active, is_current
  ) values (
    'team-identity-lineage-review-policy-test', 1, 'team_identity',
    array['assign_existing']::text[],
    jsonb_build_object('new_lineage_requires_governance', true),
    true, true
  );
end;
$$;

insert into public.source_independence_groups(group_id, display_name)
values
  ('lineage-review-team-color-owner', 'Lineage Review Team Color Owner'),
  ('lineage-review-generic-owner', 'Lineage Review Generic Owner');

insert into public.trusted_sources(
  source_id, display_name, base_url, reference_url,
  independence_group_id, review_status
)
select
  'lineage-review-team-color-source', 'Lineage Review Team Color Source',
  'https://lineage-review-colors.example',
  'https://lineage-review-colors.example/about', ownership.id, 'approved'
from public.source_independence_groups ownership
where ownership.group_id = 'lineage-review-team-color-owner'
union all
select
  'lineage-review-generic-source', 'Lineage Review Generic Source',
  'https://lineage-review-generic.example',
  'https://lineage-review-generic.example/about', ownership.id, 'approved'
from public.source_independence_groups ownership
where ownership.group_id = 'lineage-review-generic-owner';

insert into public.trusted_source_url_scope_versions(
  source_id, hostname, include_subdomains, path_prefix, path_match,
  scope_kind, review_status
)
select id,
       case source_id
         when 'lineage-review-team-color-source'
           then 'lineage-review-colors.example'
         else 'lineage-review-generic.example'
       end,
       false, '/', 'prefix', 'publisher', 'approved'
from public.trusted_sources
where source_id in (
  'lineage-review-team-color-source','lineage-review-generic-source'
);

insert into public.source_independence_group_assignment_versions(
  source_id, independence_group_id, review_status
)
select id, independence_group_id, 'approved'
from public.trusted_sources
where source_id in (
  'lineage-review-team-color-source','lineage-review-generic-source'
);

insert into public.source_trust_assignments(
  source_id, data_type, trust_tier, is_current
)
select id, 'team_colors', 1, true
from public.trusted_sources
where source_id = 'lineage-review-team-color-source';

insert into public.source_trust_assignments(
  source_id, data_type, trust_tier, is_current
)
select id, 'team_identity', 3, true
from public.trusted_sources
where source_id = 'lineage-review-generic-source';

insert into public.source_applicability_versions(
  source_id, data_type, applicability_kind, review_status, notes
)
select id, 'team_colors', 'global', 'approved',
       'Lineage reviewer downstream-wake fixture.'
from public.trusted_sources
where source_id = 'lineage-review-team-color-source';

insert into public.source_applicability_versions(
  source_id, data_type, applicability_kind, review_status, notes
)
select id, 'team_identity', 'global', 'approved',
       'Generic Team Data lineage reviewer fixture.'
from public.trusted_sources
where source_id = 'lineage-review-generic-source';

do $$
begin
  perform set_config(
    'request.jwt.claim.sub', '75000000-0000-0000-0000-000000000004', true
  );
  perform public.admin_review_information_lineage(
    'lineage-review-existing-team-colors', 'team_colors',
    'Existing Team Color Origin',
    'https://lineage-review-existing.example/colors', 'approved', null,
    'Existing approved Team Color lineage.', '{}'::jsonb
  );
  perform public.admin_review_information_lineage(
    'lineage-review-existing-team-identity', 'team_identity',
    'Existing Team Identity Origin',
    'https://lineage-review-existing.example/team-data', 'approved', null,
    'Existing approved Team Data lineage.', '{}'::jsonb
  );
end;
$$;

-- Helper creates a real generic proposal/evidence record, lets the resolver
-- propose a new lineage, and returns the immutable resolver result ID.
create or replace function pg_temp.create_team_identity_lineage_proposal(
  case_key text
)
returns uuid
language plpgsql
as $$
declare
  specialist_actor_uuid uuid;
  source_uuid uuid;
  proposal_uuid uuid;
  evidence_uuid uuid;
  resolution_work_uuid uuid;
  resolver_claim jsonb;
  resolution_result_uuid uuid;
begin
  select id into strict specialist_actor_uuid
  from public.catalog_actors
  where actor_key = 'lineage-review-test-specialist';
  select id into strict source_uuid
  from public.trusted_sources
  where source_id = 'lineage-review-generic-source';
  insert into public.catalog_change_proposals(
    fact_type, operation, proposed_public_id, payload, proposed_by_actor_id
  ) values (
    'team_identity', 'create', 'lineage-review-' || case_key,
    jsonb_build_object(
      'private_factual_answer', 'must-never-enter-reviewer-context-' || case_key
    ), specialist_actor_uuid
  ) returning id into proposal_uuid;
  perform set_config(
    'request.jwt.claim.sub', '75000000-0000-0000-0000-000000000002', true
  );
  evidence_uuid := public.add_catalog_proposal_evidence(
    proposal_uuid, 'lineage-review-generic-source',
    'https://lineage-review-generic.example/' || case_key,
    'private-evidence-summary-' || case_key,
    now(), true
  );
  select id into strict resolution_work_uuid
  from public.information_lineage_resolution_work_items
  where evidence_kind = 'proposal_evidence' and evidence_id = evidence_uuid;
  perform set_config(
    'request.jwt.claim.sub', '75000000-0000-0000-0000-000000000003', true
  );
  resolver_claim :=
    public.claim_next_information_lineage_resolution_work('team_identity');
  perform pg_temp.assert_true(
    (resolver_claim #>> '{work,work_item_id}')::uuid = resolution_work_uuid,
    'the generic resolver must claim the expected proposal evidence'
  );
  resolution_result_uuid := public.submit_information_lineage_resolution_result(
    resolution_work_uuid,
    (resolver_claim #>> '{work,lease_token}')::uuid,
    'propose_new', 'lineage-review-proposed-' || case_key,
    'Resolver found a potentially distinct Team Data origin for ' || case_key || '.',
    jsonb_build_object('research_case', case_key)
  );
  return resolution_result_uuid;
end;
$$;

-- Approving a genuinely new Team Color lineage uses the existing governed
-- assignment trigger to unblock source qualification and emit its normal wake.
do $$
declare
  enrollment_uuid uuid;
  qualification_work_uuid uuid;
  resolution_work_uuid uuid;
  resolution_result_uuid uuid;
  review_work_uuid uuid;
  resolver_claim jsonb;
  reviewer_claim jsonb;
  lease_uuid uuid;
  decision_uuid uuid;
  repeated_decision_uuid uuid;
  reviewer_context_text text;
begin
  select enrollment.id into strict enrollment_uuid
  from public.source_qualification_enrollments enrollment
  join public.trusted_sources source on source.id = enrollment.source_id
  where source.source_id = 'lineage-review-team-color-source'
    and enrollment.data_type = 'team_colors';
  perform set_config(
    'request.jwt.claim.sub', '75000000-0000-0000-0000-000000000001', true
  );
  qualification_work_uuid := public.enqueue_source_qualification_work(
    enrollment_uuid, 'catalog_team',
    public.resolve_catalog_team_id('hockey-998201')::text,
    'https://lineage-review-colors.example/team', null
  );
  select id into strict resolution_work_uuid
  from public.information_lineage_resolution_work_items
  where evidence_kind = 'source_qualification_work'
    and evidence_id = qualification_work_uuid;
  perform pg_temp.assert_true(
    not public.source_qualification_lineage_is_ready(qualification_work_uuid)
    and not exists (
      select 1 from public.agent_work_wake_outbox wake
      where wake.queue_name = 'source_qualification.team_colors'
        and wake.work_item_id = qualification_work_uuid
        and wake.status = 'pending'
    ),
    'qualification must remain blocked before resolver/reviewer governance'
  );

  perform set_config(
    'request.jwt.claim.sub', '75000000-0000-0000-0000-000000000003', true
  );
  resolver_claim :=
    public.claim_next_information_lineage_resolution_work('team_colors');
  resolution_result_uuid := public.submit_information_lineage_resolution_result(
    resolution_work_uuid,
    (resolver_claim #>> '{work,lease_token}')::uuid,
    'propose_new', 'lineage-review-approved-new-colors',
    'Resolver found an original Team Color publication.',
    jsonb_build_object('method', 'publisher attribution')
  );
  select id into strict review_work_uuid
  from public.information_lineage_review_work_items
  where resolution_result_id = resolution_result_uuid;
  perform pg_temp.assert_true(
    exists (
      select 1 from public.agent_work_wake_outbox wake
      where wake.queue_name = 'information_lineage_reviewer.team_colors'
        and wake.work_item_id = review_work_uuid
        and wake.status = 'pending'
    ),
    'a propose_new result must create and wake durable reviewer work'
  );

  perform set_config(
    'request.jwt.claim.sub', '75000000-0000-0000-0000-000000000004', true
  );
  reviewer_claim :=
    public.claim_next_information_lineage_review_work('team_colors');
  lease_uuid := (reviewer_claim #>> '{work,lease_token}')::uuid;
  reviewer_context_text := reviewer_claim::text;
  perform pg_temp.assert_true(
    (reviewer_claim #>> '{work,work_item_id}')::uuid = review_work_uuid
    and reviewer_claim #>> '{proposal,proposed_lineage_key}' =
        'lineage-review-approved-new-colors'
    and reviewer_claim #>> '{evidence,evidence_location}' =
        'https://lineage-review-colors.example/team'
    and reviewer_context_text not like '%structured_claim%'
    and reviewer_context_text not like '%reference_payload%'
    and reviewer_context_text not like '%raw_match_rate%'
    and reviewer_context_text not like '%assessed_case_count%'
    and reviewer_context_text not like '%qualification_status%'
    and reviewer_context_text not like '%trust_tier%'
    and reviewer_context_text not like '%private_factual_answer%',
    'reviewer context must contain lineage research context but no factual answers or qualification scoring'
  );
  decision_uuid := public.submit_information_lineage_review(
    review_work_uuid, lease_uuid, 'approve_new', null,
    'Approved New Team Color Origin',
    'https://lineage-review-approved.example/colors',
    'Reviewer confirmed the proposal is a genuinely new origin.',
    null, null, jsonb_build_object('review_method', 'origin documentation')
  );
  repeated_decision_uuid := public.submit_information_lineage_review(
    review_work_uuid, lease_uuid, 'approve_new', null,
    'Approved New Team Color Origin',
    'https://lineage-review-approved.example/colors',
    'Reviewer confirmed the proposal is a genuinely new origin.',
    null, null, jsonb_build_object('review_method', 'origin documentation')
  );
  perform pg_temp.assert_true(
    decision_uuid = repeated_decision_uuid
    and (select status = 'completed'
         from public.information_lineage_review_work_items
         where id = review_work_uuid)
    and (select status = 'completed'
         from public.information_lineage_resolution_work_items
         where id = resolution_work_uuid)
    and public.source_qualification_lineage_is_ready(qualification_work_uuid)
    and exists (
      select 1 from public.agent_work_wake_outbox wake
      where wake.queue_name = 'source_qualification.team_colors'
        and wake.work_item_id = qualification_work_uuid
        and wake.status = 'pending'
    )
    and exists (
      select 1
      from public.information_lineage_review_decisions decision
      join public.information_lineage_versions version
        on version.id = decision.applied_lineage_version_id
      join public.information_lineages lineage on lineage.id = version.lineage_id
      where decision.id = decision_uuid
        and decision.disposition = 'approve_new'
        and lineage.lineage_key = 'lineage-review-approved-new-colors'
        and version.review_status = 'approved'
    ),
    'approval must be idempotent, governed, and resume qualification through its existing wake path'
  );
end;
$$;

-- A non-Team-Color proposal can be mapped to an existing lineage with the
-- same generic reviewer contract, and hidden factual content stays excluded.
do $$
declare
  resolution_result_uuid uuid;
  review_work_uuid uuid;
  reviewer_claim jsonb;
  resolution_work_uuid uuid;
  evidence_uuid uuid;
begin
  resolution_result_uuid :=
    pg_temp.create_team_identity_lineage_proposal('map-existing');
  select id into strict review_work_uuid
  from public.information_lineage_review_work_items
  where resolution_result_id = resolution_result_uuid;
  select result.work_item_id, resolution_work.evidence_id
  into strict resolution_work_uuid, evidence_uuid
  from public.information_lineage_resolution_results result
  join public.information_lineage_resolution_work_items resolution_work
    on resolution_work.id = result.work_item_id
  where result.id = resolution_result_uuid;
  perform set_config(
    'request.jwt.claim.sub', '75000000-0000-0000-0000-000000000004', true
  );
  reviewer_claim :=
    public.claim_next_information_lineage_review_work('team_identity');
  perform pg_temp.assert_true(
    reviewer_claim::text not like '%must-never-enter-reviewer-context%'
    and reviewer_claim::text not like '%private-evidence-summary%'
    and reviewer_claim -> 'approved_lineage_candidates' @>
      jsonb_build_array(jsonb_build_object(
        'lineage_key', 'lineage-review-existing-team-identity'
      )),
    'generic reviewer context must expose candidates but not proposal answers or evidence summaries'
  );
  perform public.submit_information_lineage_review(
    review_work_uuid,
    (reviewer_claim #>> '{work,lease_token}')::uuid,
    'map_existing', 'lineage-review-existing-team-identity',
    null, null,
    'Reviewer determined the proposed origin is the existing Team Data lineage.',
    null, null, jsonb_build_object('test_domain', 'team_data')
  );
  perform pg_temp.assert_true(
    (select status = 'completed'
     from public.information_lineage_resolution_work_items
     where id = resolution_work_uuid)
    and exists (
      select 1
      from public.catalog_evidence_lineage_assignments assignment
      join public.information_lineage_versions version
        on version.id = assignment.information_lineage_version_id
      join public.information_lineages lineage on lineage.id = version.lineage_id
      where assignment.evidence_kind = 'proposal_evidence'
        and assignment.evidence_id = evidence_uuid
        and assignment.is_current
        and lineage.lineage_key = 'lineage-review-existing-team-identity'
    ),
    'mapping must complete the originating generic resolution through the governed assignment path'
  );
end;
$$;

-- Rejection is an explicit terminal exception. It assigns no lineage and the
-- dependent factual work remains safely blocked on unresolved lineage.
do $$
declare
  resolution_result_uuid uuid;
  review_work_uuid uuid;
  resolution_work_uuid uuid;
  evidence_uuid uuid;
  reviewer_claim jsonb;
begin
  resolution_result_uuid :=
    pg_temp.create_team_identity_lineage_proposal('reject');
  select review_work.id, resolution_work.id, resolution_work.evidence_id
  into strict review_work_uuid, resolution_work_uuid, evidence_uuid
  from public.information_lineage_review_work_items review_work
  join public.information_lineage_resolution_results result
    on result.id = review_work.resolution_result_id
  join public.information_lineage_resolution_work_items resolution_work
    on resolution_work.id = result.work_item_id
  where review_work.resolution_result_id = resolution_result_uuid;
  perform set_config(
    'request.jwt.claim.sub', '75000000-0000-0000-0000-000000000004', true
  );
  reviewer_claim :=
    public.claim_next_information_lineage_review_work('team_identity');
  perform public.submit_information_lineage_review(
    review_work_uuid,
    (reviewer_claim #>> '{work,lease_token}')::uuid,
    'reject', null, null, null,
    'Reviewer found the proposed lineage identity unsupported.',
    'unsupported_origin_claim',
    'The available provenance does not establish the proposed origin.',
    jsonb_build_object('reviewed', true)
  );
  perform pg_temp.assert_true(
    (select status = 'rejected'
       and failure_category = 'lineage_proposal_rejected'
     from public.information_lineage_review_work_items
     where id = review_work_uuid)
    and (select status = 'failed'
          and failure_category = 'lineage_proposal_rejected'
          and failure_reason like 'unsupported_origin_claim:%'
         from public.information_lineage_resolution_work_items
         where id = resolution_work_uuid)
    and exists (
      select 1 from public.information_lineage_review_decisions decision
      where decision.work_item_id = review_work_uuid
        and decision.disposition = 'reject'
        and decision.terminal_exception_code = 'unsupported_origin_claim'
        and decision.terminal_exception_reason =
            'The available provenance does not establish the proposed origin.'
    )
    and not exists (
      select 1 from public.catalog_evidence_lineage_assignments assignment
      where assignment.evidence_kind = 'proposal_evidence'
        and assignment.evidence_id = evidence_uuid and assignment.is_current
    )
    and (select information_lineage_version_id is null
         from public.catalog_proposal_evidence where id = evidence_uuid),
    'rejection must terminate review visibly while leaving dependent evidence unresolved and blocked'
  );
end;
$$;

-- Retry, renewal, expiry, and missed wake recovery use the approved inherited
-- runtime and the existing backend watchdog entry point.
do $$
declare
  resolution_result_uuid uuid;
  review_work_uuid uuid;
  first_claim jsonb;
  second_claim jsonb;
  renewed_until timestamptz;
  transition_status text;
  recovery_value jsonb;
begin
  resolution_result_uuid :=
    pg_temp.create_team_identity_lineage_proposal('retry-recovery');
  select id into strict review_work_uuid
  from public.information_lineage_review_work_items
  where resolution_result_id = resolution_result_uuid;
  perform set_config(
    'request.jwt.claim.sub', '75000000-0000-0000-0000-000000000004', true
  );
  first_claim :=
    public.claim_next_information_lineage_review_work('team_identity');
  renewed_until := public.renew_information_lineage_review_work_lease(
    review_work_uuid, (first_claim #>> '{work,lease_token}')::uuid
  );
  transition_status := public.report_information_lineage_review_failure(
    review_work_uuid, (first_claim #>> '{work,lease_token}')::uuid,
    'rate_limited', 'Temporary source access limit.'
  );
  perform pg_temp.assert_true(
    renewed_until > now() and transition_status = 'retry_wait'
    and exists (
      select 1 from public.agent_work_wake_outbox wake
      where wake.queue_name = 'information_lineage_reviewer.team_identity'
        and wake.work_item_id = review_work_uuid and wake.status = 'pending'
    ),
    'classified transient reviewer failure must follow the inherited retry policy and re-wake'
  );
  second_claim :=
    public.claim_next_information_lineage_review_work('team_identity');
  update public.information_lineage_review_work_items
  set lease_expires_at = now() - interval '1 second'
  where id = review_work_uuid;
  update public.information_lineage_review_attempts
  set lease_expires_at = now() - interval '1 second'
  where work_item_id = review_work_uuid and ended_at is null;
  perform set_config(
    'request.jwt.claim.sub', '75000000-0000-0000-0000-000000000001', true
  );
  recovery_value := public.run_agent_backend_recovery();
  perform pg_temp.assert_true(
    (recovery_value ->> 'lineage_review_expired')::integer >= 1
    and (select status = 'needs_review' and attempt_count = 2
         from public.information_lineage_review_work_items
         where id = review_work_uuid)
    and (select count(*) = 2
         from public.information_lineage_review_attempts
         where work_item_id = review_work_uuid and ended_at is not null)
    and (select status = 'needs_review'
         from public.information_lineage_resolution_work_items
         where id = (
           select work_item_id
           from public.information_lineage_resolution_results
           where id = resolution_result_uuid
         )),
    'watchdog recovery must expire the reviewer lease through the inherited attempt policy without altering the unresolved origin'
  );
end;
$$;

-- Recovery repairs both a lost reviewer wake and a missed reviewer-work
-- creation without duplicating either durable record.
do $$
declare
  wake_result_uuid uuid;
  wake_review_work_uuid uuid;
  missed_result_uuid uuid;
  missed_review_work_uuid uuid;
  first_recovery jsonb;
  second_recovery jsonb;
begin
  wake_result_uuid :=
    pg_temp.create_team_identity_lineage_proposal('missed-wake');
  select id into strict wake_review_work_uuid
  from public.information_lineage_review_work_items
  where resolution_result_id = wake_result_uuid;
  update public.agent_work_wake_outbox
  set status = 'cancelled'
  where queue_name = 'information_lineage_reviewer.team_identity'
    and work_item_id = wake_review_work_uuid and status = 'pending';

  alter table public.information_lineage_resolution_results
    disable trigger enqueue_pending_information_lineage_review;
  missed_result_uuid :=
    pg_temp.create_team_identity_lineage_proposal('missed-review-work');
  alter table public.information_lineage_resolution_results
    enable trigger enqueue_pending_information_lineage_review;
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.information_lineage_review_work_items
      where resolution_result_id = missed_result_uuid
    ),
    'the recovery fixture must begin with reviewer work missing'
  );

  perform set_config(
    'request.jwt.claim.sub', '75000000-0000-0000-0000-000000000001', true
  );
  first_recovery := public.run_agent_backend_recovery();
  second_recovery := public.run_agent_backend_recovery();
  select id into strict missed_review_work_uuid
  from public.information_lineage_review_work_items
  where resolution_result_id = missed_result_uuid;
  perform pg_temp.assert_true(
    (first_recovery ->> 'lineage_review_work_reconciled')::integer = 1
    and (first_recovery ->> 'lineage_review_wakes_reconciled')::integer >= 1
    and (second_recovery ->> 'lineage_review_work_reconciled')::integer = 0
    and (select count(*) = 1
         from public.information_lineage_review_work_items
         where resolution_result_id = missed_result_uuid)
    and exists (
      select 1 from public.agent_work_wake_outbox wake
      where wake.queue_name = 'information_lineage_reviewer.team_identity'
        and wake.work_item_id = wake_review_work_uuid
        and wake.status = 'pending'
    )
    and exists (
      select 1 from public.agent_work_wake_outbox wake
      where wake.queue_name = 'information_lineage_reviewer.team_identity'
        and wake.work_item_id = missed_review_work_uuid
        and wake.status = 'pending'
    ),
    'generic recovery must idempotently restore missed reviewer work and wakes'
  );
end;
$$;

-- Resolver and reviewer authority remain separate, and direct table access is
-- not granted to ordinary authenticated users.
do $$
declare
  denied boolean := false;
begin
  perform set_config(
    'request.jwt.claim.sub', '75000000-0000-0000-0000-000000000003', true
  );
  begin
    perform public.claim_next_information_lineage_review_work(null);
  exception when others then
    denied := sqlerrm like '%Information-lineage review capability is required%';
  end;
  perform pg_temp.assert_true(
    denied
    and not has_table_privilege(
      'authenticated', 'public.information_lineage_review_work_items', 'SELECT'
    )
    and not has_table_privilege(
      'authenticated', 'public.information_lineage_review_decisions', 'INSERT'
    ),
    'resolver authority must not confer reviewer authority or direct reviewer-table access'
  );
end;
$$;

rollback;
