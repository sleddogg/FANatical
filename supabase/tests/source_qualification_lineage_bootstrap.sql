-- Focused transactional coverage for source-qualification lineage bootstrap.

begin;

create or replace function pg_temp.assert_true(value boolean, message text)
returns void language plpgsql as $$
begin
  if not coalesce(value, false) then
    raise exception 'Source qualification lineage bootstrap assertion failed: %', message;
  end if;
end;
$$;

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000','74000000-0000-0000-0000-000000000001','authenticated','authenticated','qualification-lineage-admin@fanatical.invalid','',now(),'{}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','74000000-0000-0000-0000-000000000002','authenticated','authenticated','qualification-lineage-worker@fanatical.invalid','',now(),'{}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','74000000-0000-0000-0000-000000000003','authenticated','authenticated','qualification-lineage-resolver@fanatical.invalid','',now(),'{}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','74000000-0000-0000-0000-000000000004','authenticated','authenticated','qualification-lineage-reviewer@fanatical.invalid','',now(),'{}','{}',now(),now());

insert into public.staff_roles(user_id,role,permissions,is_active)
values ('74000000-0000-0000-0000-000000000001','admin',array[]::text[],true);

insert into public.catalog_actors(actor_key,actor_type,auth_user_id,display_name)
values
  ('qualification-lineage-admin','human','74000000-0000-0000-0000-000000000001','Qualification Lineage Admin'),
  ('qualification-lineage-worker','agent','74000000-0000-0000-0000-000000000002','Qualification Lineage Worker'),
  ('qualification-lineage-resolver','agent','74000000-0000-0000-0000-000000000003','Qualification Lineage Resolver'),
  ('qualification-lineage-reviewer','agent','74000000-0000-0000-0000-000000000004','Qualification Lineage Reviewer');

insert into public.catalog_actor_capabilities(actor_id,capability)
select id,'source.qualification.work' from public.catalog_actors
where actor_key = 'qualification-lineage-worker';
insert into public.catalog_actor_capabilities(actor_id,capability)
select id,'information_lineage.resolve' from public.catalog_actors
where actor_key = 'qualification-lineage-resolver';
insert into public.catalog_actor_capabilities(actor_id,capability)
select id,'information_lineage.review' from public.catalog_actors
where actor_key = 'qualification-lineage-reviewer';

insert into public.catalog_teams(team_id,sport_id)
select 'hockey-998101',sport.id
from public.catalog_sports sport where sport.sport_id = 'hockey';
insert into public.team_identity_versions(
  team_id,display_name,short_name,active,record_status
)
select id,'Lineage Bootstrap Team','Bootstrap Team',true,'imported_unverified'
from public.catalog_teams where team_id = 'hockey-998101';
insert into public.team_primary_league_versions(team_id,league_id,record_status)
select team.id,league.id,'imported_unverified'
from public.catalog_teams team
join public.catalog_leagues league on league.league_id = 'hockey-nhl'
where team.team_id = 'hockey-998101';

insert into public.source_independence_groups(group_id,display_name)
select 'qualification-lineage-owner-' || suffix,
       'Qualification Lineage Owner ' || upper(suffix)
from unnest(array['a','b','c','target']) suffix;

insert into public.trusted_sources(
  source_id,display_name,base_url,reference_url,
  independence_group_id,review_status
)
select 'qualification-lineage-source-' || suffix,
       'Qualification Lineage Source ' || upper(suffix),
       'https://qualification-lineage-' || suffix || '.example',
       'https://qualification-lineage-' || suffix || '.example/about',
       ownership.id,'approved'
from unnest(array['a','b','c','target']) suffix
join public.source_independence_groups ownership
  on ownership.group_id = 'qualification-lineage-owner-' || suffix;

insert into public.source_independence_group_assignment_versions(
  source_id,independence_group_id,review_status,notes
)
select source.id,source.independence_group_id,'approved',
       'Qualification lineage bootstrap fixture.'
from public.trusted_sources source
where source.source_id like 'qualification-lineage-source-%';

insert into public.trusted_source_url_scope_versions(
  source_id,hostname,include_subdomains,path_prefix,path_match,
  scope_kind,review_status
)
select source.id,
       replace(source.source_id,'qualification-lineage-source-',
               'qualification-lineage-') || '.example',
       false,'/','prefix','publisher','approved'
from public.trusted_sources source
where source.source_id like 'qualification-lineage-source-%';

insert into public.source_trust_assignments(
  source_id,data_type,trust_tier,effective_from,notes
)
select source.id,'team_colors',2,current_date,
       'Governance tier does not imply empirical qualification.'
from public.trusted_sources source
where source.source_id like 'qualification-lineage-source-%';

insert into public.source_applicability_versions(
  source_id,data_type,applicability_kind,league_id,review_status,notes
)
select source.id,'team_colors','league',league.id,'approved',
       'Seed-like approved Team Color applicability.'
from public.trusted_sources source
cross join public.catalog_leagues league
where source.source_id like 'qualification-lineage-source-%'
  and league.league_id = 'hockey-nhl';

do $$
declare suffix text;
begin
  perform set_config('request.jwt.claim.sub','74000000-0000-0000-0000-000000000004',true);
  foreach suffix in array array['a','b','c'] loop
    perform public.admin_review_information_lineage(
      'qualification-lineage-' || suffix,'team_colors',
      'Qualification Lineage ' || upper(suffix),
      'https://qualification-lineage-' || suffix || '.example/origin',
      'approved',null,'Independent bootstrap reference lineage.','{}'::jsonb
    );
  end loop;
end;
$$;

-- Establish three independent sealed peer claims. They are non-production and
-- serve only as the bootstrap reference once the target claim is collected.
do $$
declare
  suffix text;
  team_uuid uuid := public.resolve_catalog_team_id('hockey-998101');
  claim_value jsonb;
begin
  perform set_config('request.jwt.claim.sub','74000000-0000-0000-0000-000000000001',true);
  foreach suffix in array array['a','b','c'] loop
    perform public.enqueue_source_qualification_work(
      (select enrollment.id
       from public.source_qualification_enrollments enrollment
       join public.trusted_sources source on source.id = enrollment.source_id
       where source.source_id = 'qualification-lineage-source-' || suffix
         and enrollment.data_type = 'team_colors'),
      'catalog_team',team_uuid::text,
      'https://qualification-lineage-' || suffix || '.example/team',
      'qualification-lineage-' || suffix
    );
  end loop;
  perform set_config('request.jwt.claim.sub','74000000-0000-0000-0000-000000000002',true);
  for suffix in select unnest(array['a','b','c']) loop
    claim_value := public.claim_next_source_qualification_work('team_colors');
    perform public.submit_source_qualification_result(
      (claim_value #>> '{work,work_item_id}')::uuid,
      (claim_value #>> '{work,lease_token}')::uuid,
      'determinate',jsonb_build_object(
        'classification','current_canonical',
        'palette',jsonb_build_array('#123456','#ABCDEF')
      ),'Independent sealed peer claim.'
    );
  end loop;
end;
$$;

-- A seeded-like probationary source with no lineage creates durable resolver
-- work, remains unclaimable, and emits no qualification wake.
do $$
declare
  team_uuid uuid := public.resolve_catalog_team_id('hockey-998101');
  enrollment_uuid uuid;
  qualification_work_uuid uuid;
  lineage_work_uuid uuid;
  denied boolean := false;
begin
  select enrollment.id into strict enrollment_uuid
  from public.source_qualification_enrollments enrollment
  join public.trusted_sources source on source.id = enrollment.source_id
  where source.source_id = 'qualification-lineage-source-target'
    and enrollment.data_type = 'team_colors';
  perform pg_temp.assert_true((
    select qualification_status = 'probationary'
       and assessed_case_count = 0
    from public.source_qualification_enrollments
    where id = enrollment_uuid
  ),'the no-lineage source must begin probationary and unrated');

  perform set_config('request.jwt.claim.sub','74000000-0000-0000-0000-000000000001',true);
  qualification_work_uuid := public.enqueue_source_qualification_work(
    enrollment_uuid,'catalog_team',team_uuid::text,
    'https://qualification-lineage-target.example/team',null
  );
  select id into strict lineage_work_uuid
  from public.information_lineage_resolution_work_items
  where evidence_kind = 'source_qualification_work'
    and evidence_id = qualification_work_uuid;
  perform set_config('qualification_lineage_test.qualification_work_id',
                     qualification_work_uuid::text,true);
  perform set_config('qualification_lineage_test.lineage_work_id',
                     lineage_work_uuid::text,true);
  perform pg_temp.assert_true(
    (select status = 'queued' and information_lineage_version_id is null
     from public.source_qualification_work_items
     where id = qualification_work_uuid)
    and not exists (
      select 1 from public.agent_work_wake_outbox wake
      where wake.queue_name = 'source_qualification.team_colors'
        and wake.work_item_id = qualification_work_uuid
        and wake.status = 'pending'
    )
    and exists (
      select 1 from public.agent_work_wake_outbox wake
      where wake.queue_name = 'information_lineage_resolver.team_colors'
        and wake.work_item_id = lineage_work_uuid
        and wake.status = 'pending'
    ),'unknown lineage must create resolver work without waking qualification');

  perform set_config('request.jwt.claim.sub','74000000-0000-0000-0000-000000000002',true);
  perform pg_temp.assert_true(
    public.claim_next_source_qualification_work('team_colors') is null,
    'lineage-unready qualification work must be unclaimable'
  );
  begin
    perform public.claim_next_information_lineage_resolution_work('team_colors');
  exception when others then
    denied := sqlerrm like '%Information-lineage resolver capability is required%';
  end;
  perform pg_temp.assert_true(denied,
    'qualification capability must not confer lineage resolver authority');
end;
$$;

-- The resolver proposes a new lineage; the separately authorized reviewer
-- establishes and applies it through the existing governed path.
do $$
declare
  qualification_work_uuid uuid :=
    current_setting('qualification_lineage_test.qualification_work_id')::uuid;
  lineage_work_uuid uuid :=
    current_setting('qualification_lineage_test.lineage_work_id')::uuid;
  resolver_claim jsonb;
  resolution_result_uuid uuid;
  recovery_value jsonb;
begin
  perform set_config('request.jwt.claim.sub','74000000-0000-0000-0000-000000000003',true);
  resolver_claim := public.claim_next_information_lineage_resolution_work('team_colors');
  perform pg_temp.assert_true(
    (resolver_claim #>> '{work,work_item_id}')::uuid = lineage_work_uuid
    and resolver_claim #>> '{evidence,evidence_kind}' = 'source_qualification_work'
    and resolver_claim #>> '{evidence,evidence_id}' = qualification_work_uuid::text
    and resolver_claim #>> '{evidence,evidence_location}' =
      'https://qualification-lineage-target.example/team'
    and resolver_claim #>> '{evidence,current_canonical_source,source_id}' =
      'qualification-lineage-source-target'
    and resolver_claim::text not like '%palette%'
    and resolver_claim::text not like '%reference%'
    and resolver_claim::text not like '%result_payload%',
    'resolver context must be qualification-target specific and exclude factual answers'
  );
  resolution_result_uuid := public.submit_information_lineage_resolution_result(
    lineage_work_uuid,
    (resolver_claim #>> '{work,lease_token}')::uuid,
    'propose_new','qualification-lineage-target',
    'The assigned publisher page is a distinct originating information lineage.',
    jsonb_build_object('test','qualification bootstrap')
  );
  perform pg_temp.assert_true((
    select status = 'needs_review'
    from public.information_lineage_resolution_work_items
    where id = lineage_work_uuid
  ),'new lineage proposals must remain under separate governance');

  perform set_config('request.jwt.claim.sub','74000000-0000-0000-0000-000000000004',true);
  perform public.admin_review_information_lineage(
    'qualification-lineage-target','team_colors','Qualification Target Origin',
    'https://qualification-lineage-target.example/origin','approved',null,
    'Reviewer confirmed a distinct originating lineage.',
    jsonb_build_object('resolution_result_id',resolution_result_uuid)
  );
  perform public.apply_information_lineage_resolution_result(
    resolution_result_uuid,'qualification-lineage-target',
    'Reviewer applied the confirmed lineage to qualification work.','{}'::jsonb
  );
  perform pg_temp.assert_true(
    public.source_qualification_lineage_is_ready(qualification_work_uuid)
    and exists (
      select 1 from public.agent_work_wake_outbox wake
      where wake.queue_name = 'source_qualification.team_colors'
        and wake.work_item_id = qualification_work_uuid
        and wake.status = 'pending'
    ),'governed lineage assignment must snapshot lineage and wake qualification');

  update public.agent_work_wake_outbox
  set status = 'cancelled'
  where queue_name = 'source_qualification.team_colors'
    and work_item_id = qualification_work_uuid and status = 'pending';
  perform set_config('request.jwt.claim.sub','74000000-0000-0000-0000-000000000001',true);
  recovery_value := public.run_agent_backend_recovery();
  perform pg_temp.assert_true(
    (recovery_value ->> 'qualification_wakes_reconciled')::integer >= 1
    and exists (
      select 1 from public.agent_work_wake_outbox wake
      where wake.queue_name = 'source_qualification.team_colors'
        and wake.work_item_id = qualification_work_uuid
        and wake.status = 'pending'
    ),'generic recovery must restore a missed lineage-ready qualification wake');
end;
$$;

-- After lineage readiness, the existing claim, result, independent reference,
-- observation, and scoring path runs unchanged.
do $$
declare
  qualification_work_uuid uuid :=
    current_setting('qualification_lineage_test.qualification_work_id')::uuid;
  claim_value jsonb;
  result_uuid uuid;
begin
  perform set_config('request.jwt.claim.sub','74000000-0000-0000-0000-000000000002',true);
  claim_value := public.claim_next_source_qualification_work('team_colors');
  perform pg_temp.assert_true(
    (claim_value #>> '{work,work_item_id}')::uuid = qualification_work_uuid,
    'the qualification worker must claim the work after lineage readiness'
  );
  result_uuid := public.submit_source_qualification_result(
    qualification_work_uuid,(claim_value #>> '{work,lease_token}')::uuid,
    'determinate',jsonb_build_object(
      'classification','current_canonical',
      'palette',jsonb_build_array('#123456','#ABCDEF')
    ),'Sealed target claim collected after lineage resolution.'
  );
  perform pg_temp.assert_true(
    exists (
      select 1
      from public.source_qualification_results result
      join public.source_qualification_observations observation
        on observation.tested_result_id = result.id
      join public.source_qualification_references reference
        on reference.id = observation.reference_id
      where result.id = result_uuid
        and result.information_lineage_version_id is not null
        and observation.outcome = 'match'
        and reference.reference_kind = 'bootstrap_consensus'
        and reference.contributing_information_lineage_count = 3
        and reference.non_production
    )
    and exists (
      select 1
      from public.source_qualification_enrollments enrollment
      join public.trusted_sources source on source.id = enrollment.source_id
      where source.source_id = 'qualification-lineage-source-target'
        and enrollment.assessed_case_count = 1
        and enrollment.qualification_status = 'probationary'
    ),'lineage-ready source claims must use unchanged adjudication and scoring');
end;
$$;

-- Minimal non-Team-Color factual adapter proving the same resolver target,
-- readiness barrier, wake, and recovery path is generic.
create or replace function pg_temp.quiz_build_verifier_context(text,uuid,integer)
returns jsonb language sql stable as $$ select '{}'::jsonb; $$;
create or replace function pg_temp.quiz_compare_verifier(uuid)
returns text language sql stable as $$ select 'unresolved'::text; $$;
create or replace function pg_temp.quiz_finalize(text,uuid,uuid,jsonb,text)
returns uuid language sql stable as $$ select null::uuid; $$;
create or replace function pg_temp.quiz_build_qualification_context(text,text)
returns jsonb language sql stable as $$
  select case when $1 = 'quiz_question' then jsonb_build_object(
    'subject',jsonb_build_object('question_id',$2),
    'capability_scope','{}'::jsonb
  ) end;
$$;
create or replace function pg_temp.quiz_normalize_qualification(jsonb)
returns jsonb language sql immutable as $$
  select case when jsonb_typeof($1 -> 'answer') = 'string'
    then jsonb_build_object('answer',$1 -> 'answer') end;
$$;
create or replace function pg_temp.quiz_compare_qualification(jsonb,jsonb)
returns text language sql immutable as $$
  select case when $1 = $2 then 'match' else 'contradiction' end;
$$;
create or replace function pg_temp.quiz_resolve_qualification_reference(text,text,uuid,uuid)
returns jsonb language sql stable as $$ select null::jsonb; $$;
create or replace function pg_temp.quiz_record_contributions(uuid)
returns integer language sql as $$ select 0; $$;

do $$
declare
  approved_runtime public.agent_job_runtime_policies%rowtype;
  target_source_uuid uuid;
  enrollment_uuid uuid;
  qualification_work_uuid uuid;
  lineage_work_uuid uuid;
  resolver_claim jsonb;
  qualification_claim jsonb;
  recovery_value jsonb;
begin
  perform set_config('request.jwt.claim.sub','74000000-0000-0000-0000-000000000001',true);
  select * into strict approved_runtime
  from public.current_agent_job_runtime_policy('team_color_specialist');
  insert into public.agent_job_runtime_policies(
    policy_key,version,job_type,lease_seconds,
    retryable_failure_categories,permanent_failure_categories,
    retry_delay_seconds,maximum_attempts,exhaustion_status,
    permanent_failure_status,configuration
  ) values (
    'quiz-qualification-lineage-runtime-test',1,
    'information_lineage_resolver.quiz_answers',approved_runtime.lease_seconds,
    approved_runtime.retryable_failure_categories,
    approved_runtime.permanent_failure_categories,
    approved_runtime.retry_delay_seconds,approved_runtime.maximum_attempts,
    approved_runtime.exhaustion_status,approved_runtime.permanent_failure_status,
    jsonb_build_object('test_adapter',true)
  );
  insert into public.information_lineage_resolution_policies(
    policy_key,version,data_type,automatically_permitted_actions,
    configuration,active,is_current
  ) values (
    'quiz-qualification-lineage-policy-test',1,'quiz_answers',
    array['assign_existing']::text[],
    jsonb_build_object('new_lineage_requires_governance',true),true,true
  );
  insert into public.source_qualification_policies(
    policy_key,version,data_type,first_rating_case_count,
    first_decision_case_count,reassessment_case_interval,
    qualification_rate,probationary_rate,
    minimum_reference_information_lineages,configuration
  ) values (
    'quiz-qualification-policy-test',1,'quiz_answers',10,20,10,
    0.95,0.80,3,jsonb_build_object('test_adapter',true)
  );
  perform public.admin_register_catalog_domain_adapter(
    'quiz_answers','quiz_question','team_color_specialist',
    'catalog_verifier.quiz_answers','catalog.verify.quiz_answers',
    'pg_temp.quiz_build_verifier_context'::regproc,
    'pg_temp.quiz_compare_verifier'::regproc,
    'pg_temp.quiz_finalize'::regproc,
    null,null,null,jsonb_build_object('test_adapter',true),true
  );
  perform public.admin_register_source_qualification_adapter(
    'quiz_answers','pg_temp.quiz_build_qualification_context'::regproc,
    'pg_temp.quiz_normalize_qualification'::regproc,
    'pg_temp.quiz_compare_qualification'::regproc,
    'pg_temp.quiz_resolve_qualification_reference'::regproc,
    'pg_temp.quiz_record_contributions'::regproc
  );
  select id into strict target_source_uuid
  from public.trusted_sources
  where source_id = 'qualification-lineage-source-target';
  insert into public.source_applicability_versions(
    source_id,data_type,applicability_kind,review_status,notes
  ) values (
    target_source_uuid,'quiz_answers','global','approved',
    'Generic qualification-lineage bootstrap fixture.'
  );
  select id into strict enrollment_uuid
  from public.source_qualification_enrollments
  where source_id = target_source_uuid and data_type = 'quiz_answers';
  qualification_work_uuid := public.enqueue_source_qualification_work(
    enrollment_uuid,'quiz_question','quiz-bootstrap-1',
    'https://qualification-lineage-target.example/quiz',null
  );
  select id into strict lineage_work_uuid
  from public.information_lineage_resolution_work_items
  where evidence_kind = 'source_qualification_work'
    and evidence_id = qualification_work_uuid;
  perform pg_temp.assert_true(
    not public.source_qualification_lineage_is_ready(qualification_work_uuid)
    and not exists (
      select 1 from public.agent_work_wake_outbox wake
      where wake.queue_name = 'source_qualification.quiz_answers'
        and wake.work_item_id = qualification_work_uuid
        and wake.status = 'pending'
    ),'non-Team qualification work must use the same lineage barrier');

  perform set_config('request.jwt.claim.sub','74000000-0000-0000-0000-000000000004',true);
  perform public.admin_review_information_lineage(
    'quiz-qualification-origin','quiz_answers','Quiz Qualification Origin',
    'https://qualification-lineage-target.example/quiz-origin','approved',null,
    'Approved non-Team factual origin.','{}'::jsonb
  );
  perform set_config('request.jwt.claim.sub','74000000-0000-0000-0000-000000000003',true);
  resolver_claim := public.claim_next_information_lineage_resolution_work('quiz_answers');
  perform public.submit_information_lineage_resolution_result(
    lineage_work_uuid,(resolver_claim #>> '{work,lease_token}')::uuid,
    'assign_existing','quiz-qualification-origin',
    'Resolver matched the qualification location to the approved Quiz origin.',
    '{}'::jsonb
  );
  perform pg_temp.assert_true(
    public.source_qualification_lineage_is_ready(qualification_work_uuid)
    and exists (
      select 1 from public.agent_work_wake_outbox wake
      where wake.queue_name = 'source_qualification.quiz_answers'
        and wake.work_item_id = qualification_work_uuid
        and wake.status = 'pending'
    ),'non-Team governed assignment must use the same qualification wake');

  update public.agent_work_wake_outbox set status = 'cancelled'
  where queue_name = 'source_qualification.quiz_answers'
    and work_item_id = qualification_work_uuid and status = 'pending';
  perform set_config('request.jwt.claim.sub','74000000-0000-0000-0000-000000000001',true);
  recovery_value := public.run_agent_backend_recovery();
  perform pg_temp.assert_true(
    (recovery_value ->> 'qualification_wakes_reconciled')::integer >= 1
    and exists (
      select 1 from public.agent_work_wake_outbox wake
      where wake.queue_name = 'source_qualification.quiz_answers'
        and wake.work_item_id = qualification_work_uuid
        and wake.status = 'pending'
    ),'generic recovery must restore non-Team qualification wakes');

  perform set_config('request.jwt.claim.sub','74000000-0000-0000-0000-000000000002',true);
  qualification_claim := public.claim_next_source_qualification_work('quiz_answers');
  perform pg_temp.assert_true(
    (qualification_claim #>> '{work,work_item_id}')::uuid = qualification_work_uuid
    and qualification_claim #>> '{work,data_type}' = 'quiz_answers'
    and qualification_claim #>> '{subject,question_id}' = 'quiz-bootstrap-1',
    'the non-Team factual qualification work must become normally claimable'
  );
  perform public.submit_source_qualification_result(
    qualification_work_uuid,
    (qualification_claim #>> '{work,lease_token}')::uuid,
    'unresolved','{}'::jsonb,
    'Generic adapter claim completed without a reference fixture.'
  );
end;
$$;

rollback;
