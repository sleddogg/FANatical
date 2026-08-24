-- Transactional coverage for generic empirical factual-source qualification.

begin;

create or replace function pg_temp.assert_true(value boolean, message text)
returns void language plpgsql as $$
begin
  if not coalesce(value, false) then
    raise exception 'Source qualification assertion failed: %', message;
  end if;
end;
$$;

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000','73000000-0000-0000-0000-000000000001','authenticated','authenticated','source-qualification-admin@fanatical.invalid','',now(),'{}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','73000000-0000-0000-0000-000000000002','authenticated','authenticated','source-qualification-worker@fanatical.invalid','',now(),'{}','{}',now(),now());

insert into public.staff_roles(user_id,role,permissions,is_active)
values ('73000000-0000-0000-0000-000000000001','admin',array[]::text[],true);

insert into public.catalog_actors(actor_key,actor_type,auth_user_id,display_name)
values
  ('source-qualification-test-admin','human','73000000-0000-0000-0000-000000000001','Source Qualification Test Admin'),
  ('source-qualification-test-worker','agent','73000000-0000-0000-0000-000000000002','Source Qualification Test Worker');

insert into public.catalog_actor_capabilities(actor_id,capability)
select id,'source.qualification.work' from public.catalog_actors
where actor_key = 'source-qualification-test-worker';

insert into public.catalog_teams(team_id,sport_id)
select fixture.team_id,sport.id
from (values
  ('hockey-997001'),('hockey-997002'),('hockey-997003'),('hockey-997004')
) fixture(team_id)
cross join public.catalog_sports sport where sport.sport_id = 'hockey';
insert into public.team_identity_versions(team_id,display_name,short_name,active,record_status)
select team.id,fixture.name,fixture.name,true,'imported_unverified'
from (values
  ('hockey-997001','Qualification Team One'),
  ('hockey-997002','Qualification Team Two'),
  ('hockey-997003','Qualification Team Three'),
  ('hockey-997004','Qualification Team Four')
) fixture(team_id,name)
join public.catalog_teams team on team.team_id = fixture.team_id;
insert into public.team_primary_league_versions(team_id,league_id,record_status)
select team.id,league.id,'imported_unverified'
from public.catalog_teams team
join public.catalog_leagues league on league.league_id = 'hockey-nhl'
where team.team_id like 'hockey-99700%';

insert into public.source_independence_groups(group_id,display_name)
select 'sq-owner-' || suffix,'SQ Owner ' || upper(suffix)
from unnest(array['a','b','c','d','e','f']) suffix;

insert into public.trusted_sources(
  source_id,display_name,base_url,reference_url,independence_group_id,review_status
)
select 'sq-source-' || suffix,'SQ Source ' || upper(suffix),
       'https://sq-' || suffix || '.example','https://sq-' || suffix || '.example',
       ownership.id,'approved'
from unnest(array['a','b','c','d','e','f']) suffix
join public.source_independence_groups ownership
  on ownership.group_id = 'sq-owner-' || suffix;

insert into public.source_independence_group_assignment_versions(
  source_id,independence_group_id,review_status,notes
)
select source.id,source.independence_group_id,'approved','Qualification test ownership.'
from public.trusted_sources source where source.source_id like 'sq-source-%';

insert into public.trusted_source_url_scope_versions(
  source_id,hostname,include_subdomains,path_prefix,path_match,scope_kind,review_status
)
select source.id,'sq-' || right(source.source_id,1) || '.example',false,
       '/','prefix','publisher','approved'
from public.trusted_sources source where source.source_id like 'sq-source-%';

insert into public.source_trust_assignments(
  source_id,data_type,trust_tier,effective_from,notes
)
select source.id,'team_colors',3,current_date,'Governance tier is not qualification.'
from public.trusted_sources source where source.source_id like 'sq-source-%';

insert into public.information_lineages(lineage_key,data_type)
select 'sq-lineage-' || right(source.source_id,1),'team_colors'
from public.trusted_sources source where source.source_id like 'sq-source-%';
insert into public.information_lineage_versions(
  lineage_id,version,display_name,review_status,notes
)
select lineage.id,1,'SQ Lineage ' || upper(right(lineage.lineage_key,1)),
       'approved','Qualification test lineage.'
from public.information_lineages lineage
where lineage.lineage_key like 'sq-lineage-%';

insert into public.source_applicability_versions(
  source_id,data_type,applicability_kind,review_status,notes
)
select source.id,'team_colors','global','approved','Qualification test global scope.'
from public.trusted_sources source where source.source_id like 'sq-source-%';

insert into public.source_applicability_versions(
  source_id,data_type,applicability_kind,team_id,review_status,notes
)
select source.id,'team_colors','team',team.id,'approved',
       'A narrower governed scope must not create a second qualification profile.'
from public.trusted_sources source
cross join public.catalog_teams team
where source.source_id = 'sq-source-a'
  and team.team_id = 'hockey-997001';

do $$
begin
  perform pg_temp.assert_true((
    select count(*) = 6 and bool_and(qualification_status = 'probationary')
      and bool_and(assessed_case_count = 0)
    from public.source_qualification_enrollments enrollment
    join public.trusted_sources source on source.id = enrollment.source_id
    where source.source_id like 'sq-source-%'
  ), 'every governed source/data-type profile must start empirically probationary');
  perform pg_temp.assert_true((
    select count(*) = 1
    from public.source_qualification_enrollments enrollment
    join public.trusted_sources source on source.id = enrollment.source_id
    where source.source_id = 'sq-source-a'
      and enrollment.data_type = 'team_colors'
  ), 'multiple applicability scopes must share one source/data-type qualification profile');
  perform pg_temp.assert_true((
    select first_rating_case_count = 10
       and first_decision_case_count = 20
       and reassessment_case_interval = 10
       and qualification_rate = 0.95
       and probationary_rate = 0.80
       and minimum_reference_information_lineages = 3
    from public.source_qualification_policies
    where data_type = 'team_colors' and is_current and active
  ), 'the locked rating, decision, threshold, and reference policy must be versioned');
  perform pg_temp.assert_true((
    select build_source_qualification_context_function is not null
       and normalize_source_qualification_result_function is not null
       and compare_source_qualification_result_function is not null
       and resolve_source_qualification_reference_function is not null
       and record_adjudication_source_contributions_function is not null
    from public.catalog_domain_adapters where data_type = 'team_colors'
  ), 'the domain adapter must own context, normalization, comparison, verified-reference resolution, and contribution capture');
end;
$$;

-- Four sealed source claims produce non-production holdout references only
-- after three other lineages match. The worker sees no prior-answer context.
do $$
declare
  source_suffix text;
  work_context jsonb;
  work_uuid uuid;
  lease_uuid uuid;
  team_uuid uuid := public.resolve_catalog_team_id('hockey-997001');
begin
  perform set_config('request.jwt.claim.sub','73000000-0000-0000-0000-000000000001',true);
  foreach source_suffix in array array['a','b','c','d'] loop
    perform public.enqueue_source_qualification_work(
      (select enrollment.id
       from public.source_qualification_enrollments enrollment
       join public.trusted_sources source on source.id = enrollment.source_id
       where source.source_id = 'sq-source-' || source_suffix),
      'catalog_team',team_uuid::text,
      'https://sq-' || source_suffix || '.example/team-one',
      'sq-lineage-' || source_suffix
    );
  end loop;
  perform set_config('request.jwt.claim.sub','73000000-0000-0000-0000-000000000002',true);
  for source_suffix in select unnest(array['a','b','c','d']) loop
    work_context := public.claim_next_source_qualification_work('team_colors');
    work_uuid := (work_context #>> '{work,work_item_id}')::uuid;
    lease_uuid := (work_context #>> '{work,lease_token}')::uuid;
    perform pg_temp.assert_true(
      (select array_agg(key order by key) = array['assignment','subject','work']::text[]
       from jsonb_object_keys(work_context) key),
      'qualification context must expose only work metadata, neutral subject, and assignment'
    );
    perform pg_temp.assert_true(
      (select array_agg(key order by key) =
        array['league_id','league_name','sport_id','sport_name','team_id','team_name']::text[]
       from jsonb_object_keys(work_context -> 'subject') key),
      'Team Color subject context must contain only neutral team, league, and sport fields'
    );
    perform pg_temp.assert_true(
      (select array_agg(key order by key) =
        array['source_location']::text[]
       from jsonb_object_keys(work_context -> 'assignment') key),
      'Team Color assignment must contain only the assigned source location'
    );
    perform pg_temp.assert_true(
      work_context::text !~ 'current_colors|proposal|evidence|reasoning|notes|aliases',
      'qualification context must not leak prior colors or arbitrary research context'
    );
    perform public.submit_source_qualification_result(
      work_uuid,lease_uuid,'determinate',
      jsonb_build_object(
        'classification','current_canonical',
        'palette',jsonb_build_array('#112233','#445566')
      ),
      'Sealed assigned-source claim.'
    );
  end loop;
  perform pg_temp.assert_true((
    select count(*) = 4 and bool_and(non_production)
      and bool_and(reference_kind = 'bootstrap_consensus')
      and bool_and(authoritative_adjudication_id is null)
      and bool_and(contributing_information_lineage_count = 3)
    from public.source_qualification_references
    where subject_id = team_uuid::text
  ), 'four matching claims must create four three-lineage non-production holdout references');
  perform pg_temp.assert_true(not exists (
    select 1
    from public.source_qualification_references reference
    join public.source_qualification_reference_contributions contribution
      on contribution.reference_id = reference.id
    where reference.subject_id = team_uuid::text
      and (
        contribution.source_id = reference.tested_source_id
        or contribution.information_lineage_root_id =
           reference.tested_information_lineage_root_id
      )
  ), 'a tested source and its entire lineage must be absent from its reference');
  perform pg_temp.assert_true((
    select count(*) = 4
       and count(distinct work.enrollment_id) = 4
       and count(*) filter (
         where source.source_id = 'sq-source-a'
           and applicability.applicability_kind = 'team'
       ) = 1
    from public.source_qualification_work_items work
    join public.source_qualification_enrollments enrollment
      on enrollment.id = work.enrollment_id
    join public.trusted_sources source on source.id = enrollment.source_id
    join public.source_applicability_versions applicability
      on applicability.id = work.applicability_version_id
    where work.subject_id = team_uuid::text
  ), 'one source/data-type profile must aggregate cases while each work item retains its exact applicable scope');
end;
$$;

-- Sharing the tested lineage leaves only two independent peers and cannot
-- produce a clean observation.
do $$
declare
  source_suffix text;
  work_context jsonb;
  team_uuid uuid := public.resolve_catalog_team_id('hockey-997002');
begin
  perform set_config('request.jwt.claim.sub','73000000-0000-0000-0000-000000000001',true);
  foreach source_suffix in array array['a','b','c','d'] loop
    perform public.enqueue_source_qualification_work(
      (select enrollment.id
       from public.source_qualification_enrollments enrollment
       join public.trusted_sources source on source.id = enrollment.source_id
       where source.source_id = 'sq-source-' || source_suffix),
      'catalog_team',team_uuid::text,
      'https://sq-' || source_suffix || '.example/team-two',
      case when source_suffix = 'd' then 'sq-lineage-a'
           else 'sq-lineage-' || source_suffix end
    );
  end loop;
  perform set_config('request.jwt.claim.sub','73000000-0000-0000-0000-000000000002',true);
  for source_suffix in select unnest(array['a','b','c','d']) loop
    work_context := public.claim_next_source_qualification_work('team_colors');
    perform public.submit_source_qualification_result(
      (work_context #>> '{work,work_item_id}')::uuid,
      (work_context #>> '{work,lease_token}')::uuid,
      'determinate',jsonb_build_object(
        'classification','current_canonical',
        'palette',jsonb_build_array('#112233','#445566')
      ),'Shared-lineage exclusion fixture.'
    );
  end loop;
  perform pg_temp.assert_true(not exists (
    select 1 from public.source_qualification_observations
    where subject_id = team_uuid::text
  ), 'three publisher records spanning only two peer lineage roots must not count');
end;
$$;

-- Directly create fully linked clean observations for threshold-transition
-- coverage without weakening or exposing a production force-qualification API.
create or replace function pg_temp.add_qualification_observation(
  enrollment_uuid uuid,
  ordinal_value integer,
  outcome_value text,
  subject_uuid_value uuid default null
)
returns void language plpgsql as $$
declare
  target_enrollment public.source_qualification_enrollments%rowtype;
  target_source public.trusted_sources%rowtype;
  policy_uuid uuid;
  target_lineage_version uuid;
  target_root uuid;
  target_applicability_version uuid;
  actor_uuid uuid;
  subject_value text := coalesce(
    subject_uuid_value::text,
    enrollment_uuid::text || '-case-' || ordinal_value::text
  );
  reference_result jsonb := jsonb_build_object(
    'classification','current_canonical',
    'palette',jsonb_build_array('#112233','#445566')
  );
  target_normalized jsonb;
  work_uuid uuid;
  attempt_uuid uuid;
  result_uuid uuid;
  reference_uuid uuid;
  peer record;
  peer_work_uuid uuid;
  peer_attempt_uuid uuid;
  peer_result_uuid uuid;
begin
  select * into strict target_enrollment
  from public.source_qualification_enrollments where id = enrollment_uuid;
  select * into strict target_source from public.trusted_sources
  where id = target_enrollment.source_id;
  select id into strict policy_uuid from public.source_qualification_policies
  where data_type = target_enrollment.data_type and is_current and active;
  select version.id into strict target_lineage_version
  from public.information_lineages lineage
  join public.information_lineage_versions version
    on version.lineage_id = lineage.id and version.is_current
  where lineage.lineage_key = 'sq-lineage-' || right(target_source.source_id,1);
  target_root := public.current_information_lineage_root(target_lineage_version);
  if subject_uuid_value is null then
    select applicability.id into strict target_applicability_version
    from public.source_applicability_versions applicability
    where applicability.source_id = target_enrollment.source_id
      and applicability.data_type = target_enrollment.data_type
      and applicability.is_current and applicability.review_status = 'approved'
    order by applicability.created_at, applicability.id
    limit 1;
  else
    target_applicability_version :=
      public.applicable_source_applicability_version(
        target_enrollment.source_id,
        target_enrollment.data_type,
        subject_uuid_value
      );
    if target_applicability_version is null then
      raise exception 'The qualification test subject is outside approved applicability';
    end if;
  end if;
  select id into strict actor_uuid from public.catalog_actors
  where actor_key = 'source-qualification-test-worker';
  target_normalized := case when outcome_value = 'match' then reference_result
    else jsonb_build_object(
      'classification','current_canonical',
      'palette',jsonb_build_array('#778899','#AABBCC')
    ) end;

  insert into public.source_qualification_work_items(
    enrollment_id,data_type,subject_type,subject_id,applicability_version_id,
    assigned_source_location,
    information_lineage_version_id,status,completed_at
  ) values (
    target_enrollment.id,target_enrollment.data_type,'catalog_team',subject_value,
    target_applicability_version,
    target_source.base_url || '/case/' || ordinal_value::text,
    target_lineage_version,'completed',now()
  ) returning id into work_uuid;
  insert into public.source_qualification_attempts(
    work_item_id,attempt_number,actor_id,lease_token,lease_expires_at,
    ended_at,outcome
  ) values (
    work_uuid,1,actor_uuid,gen_random_uuid(),now(),now(),'completed'
  ) returning id into attempt_uuid;
  insert into public.source_qualification_results(
    work_item_id,attempt_id,submitted_by_actor_id,result_kind,
    result_payload,normalized_result,source_id,applicability_version_id,
    source_location,information_lineage_version_id
  ) values (
    work_uuid,attempt_uuid,actor_uuid,'determinate',target_normalized,
    target_normalized,target_enrollment.source_id,
    target_applicability_version,
    target_source.base_url || '/case/' || ordinal_value::text,
    target_lineage_version
  ) returning id into result_uuid;
  update public.source_qualification_work_items
  set accepted_result_id = result_uuid where id = work_uuid;
  insert into public.source_qualification_references(
    tested_result_id,reference_kind,data_type,subject_type,subject_id,
    normalized_reference_result,tested_source_id,
    tested_information_lineage_root_id,
    contributing_information_lineage_count,policy_id
  ) values (
    result_uuid,'bootstrap_consensus',target_enrollment.data_type,
    'catalog_team',subject_value,
    reference_result,target_enrollment.source_id,target_root,3,policy_uuid
  ) returning id into reference_uuid;

  for peer in
    select peer_enrollment.*,source.base_url,
           applicability.id as applicability_version_id,
           version.id as lineage_version_id,
           public.current_information_lineage_root(version.id) as lineage_root
    from public.source_qualification_enrollments peer_enrollment
    join public.trusted_sources source on source.id = peer_enrollment.source_id
    join public.information_lineages lineage
      on lineage.lineage_key = 'sq-lineage-' || right(source.source_id,1)
    join public.source_applicability_versions applicability
      on applicability.source_id = source.id
     and applicability.data_type = peer_enrollment.data_type
     and applicability.is_current and applicability.review_status = 'approved'
     and applicability.applicability_kind = 'global'
    join public.information_lineage_versions version
      on version.lineage_id = lineage.id and version.is_current
    where peer_enrollment.data_type = target_enrollment.data_type
      and peer_enrollment.source_id <> target_enrollment.source_id
      and source.source_id like 'sq-source-%'
    order by source.source_id
    limit 3
  loop
    insert into public.source_qualification_work_items(
      enrollment_id,data_type,subject_type,subject_id,applicability_version_id,
      assigned_source_location,
      information_lineage_version_id,status,completed_at
    ) values (
      peer.id,peer.data_type,'catalog_team',subject_value,
      peer.applicability_version_id,
      peer.base_url || '/case/' || ordinal_value::text,
      peer.lineage_version_id,'completed',now()
    )
    on conflict (enrollment_id,subject_type,subject_id)
    do update set enrollment_id = excluded.enrollment_id
    returning id,accepted_result_id into peer_work_uuid,peer_result_uuid;
    if peer_result_uuid is null then
      insert into public.source_qualification_attempts(
        work_item_id,attempt_number,actor_id,lease_token,lease_expires_at,
        ended_at,outcome
      ) values (
        peer_work_uuid,1,actor_uuid,gen_random_uuid(),now(),now(),'completed'
      ) returning id into peer_attempt_uuid;
      insert into public.source_qualification_results(
        work_item_id,attempt_id,submitted_by_actor_id,result_kind,
        result_payload,normalized_result,source_id,applicability_version_id,
        source_location,information_lineage_version_id
      ) values (
        peer_work_uuid,peer_attempt_uuid,actor_uuid,'determinate',reference_result,
        reference_result,peer.source_id,peer.applicability_version_id,
        peer.base_url || '/case/' || ordinal_value::text,peer.lineage_version_id
      ) returning id into peer_result_uuid;
      update public.source_qualification_work_items
      set accepted_result_id = peer_result_uuid where id = peer_work_uuid;
    end if;
    insert into public.source_qualification_reference_contributions(
      reference_id,result_id,source_id,information_lineage_version_id,
      information_lineage_root_id
    ) values (
      reference_uuid,peer_result_uuid,peer.source_id,peer.lineage_version_id,
      peer.lineage_root
    );
  end loop;
  insert into public.source_qualification_observations(
    enrollment_id,tested_result_id,reference_id,subject_type,subject_id,outcome,
    tested_claim_snapshot,reference_result_snapshot,tested_source_id,
    tested_applicability_version_id,tested_information_lineage_version_id,
    tested_information_lineage_root_id
  ) values (
    target_enrollment.id,result_uuid,reference_uuid,'catalog_team',subject_value,
    outcome_value,target_normalized,reference_result,target_enrollment.source_id,
    target_applicability_version,target_lineage_version,target_root
  );
  perform public.evaluate_source_qualification(target_enrollment.id);
end;
$$;

do $$
declare
  qualification_enrollment uuid;
  recovery_enrollment uuid;
  ordinal_value integer;
  proposal_uuid uuid;
  team_work_uuid uuid;
  actor_uuid uuid;
  source_record public.trusted_sources%rowtype;
  applicability_uuid uuid;
  scope_uuid uuid;
  trust_uuid uuid;
  ownership_uuid uuid;
  lineage_uuid uuid;
  rejected boolean;
begin
  select enrollment.id into strict qualification_enrollment
  from public.source_qualification_enrollments enrollment
  join public.trusted_sources source on source.id = enrollment.source_id
  where source.source_id = 'sq-source-e';
  select enrollment.id into strict recovery_enrollment
  from public.source_qualification_enrollments enrollment
  join public.trusted_sources source on source.id = enrollment.source_id
  where source.source_id = 'sq-source-f';

  for ordinal_value in 1..10 loop
    perform pg_temp.add_qualification_observation(
      qualification_enrollment,ordinal_value,'match'
    );
  end loop;
  perform pg_temp.assert_true((
    select qualification_status = 'probationary'
       and assessed_case_count = 10 and raw_match_rate = 1
       and (select evaluation_kind = 'rating'
            from public.source_qualification_evaluations evaluation
            where evaluation.id = enrollment.latest_evaluation_id)
    from public.source_qualification_enrollments enrollment
    where id = qualification_enrollment
  ), '10 clean cases must create a rating without a qualification decision');

  select * into strict source_record from public.trusted_sources
  where source_id = 'sq-source-e';
  select applicability.id into strict applicability_uuid
  from public.source_applicability_versions applicability
  where applicability.source_id = source_record.id
    and applicability.data_type = 'team_colors'
    and applicability.is_current and applicability.review_status = 'approved';
  select id into strict scope_uuid from public.trusted_source_url_scope_versions
  where source_id = source_record.id and is_current and review_status = 'approved';
  select id into strict trust_uuid from public.source_trust_assignments
  where source_id = source_record.id and data_type = 'team_colors' and is_current;
  select id into strict ownership_uuid
  from public.source_independence_group_assignment_versions
  where source_id = source_record.id and is_current and review_status = 'approved';
  select version.id into strict lineage_uuid
  from public.information_lineages lineage
  join public.information_lineage_versions version
    on version.lineage_id = lineage.id and version.is_current
  where lineage.lineage_key = 'sq-lineage-e';
  select id into strict actor_uuid from public.catalog_actors
  where actor_key = 'source-qualification-test-worker';
  insert into public.team_color_work_items(
    team_id,work_kind,request_reason,status,created_by_actor_id
  ) values (
    public.resolve_catalog_team_id('hockey-997003'),
    'fill_missing_or_unverified','Qualification gate fixture.','completed',actor_uuid
  ) returning id into team_work_uuid;
  insert into public.catalog_change_proposals(
    fact_type,operation,target_team_id,payload,status,proposed_by_actor_id,
    team_color_work_item_id,team_color_change_kind,proposal_reason
  ) values (
    'team_colors','replace',public.resolve_catalog_team_id('hockey-997003'),
    jsonb_build_object('primary','#112233','secondary','#445566'),
    'pending',actor_uuid,team_work_uuid,'fill_missing_or_unverified',
    'Qualification gate fixture.'
  ) returning id into proposal_uuid;
  rejected := false;
  begin
    insert into public.catalog_proposal_evidence(
      proposal_id,source_id,evidence_url,evidence_summary,observed_at,
      supports_proposal,submitted_by_actor_id,source_url_scope_version_id,
      source_trust_assignment_id,source_independence_assignment_id,
      source_applicability_version_id,structured_claim,
      information_lineage_version_id,information_lineage_basis
    ) values (
      proposal_uuid,source_record.id,'https://sq-e.example/before-qualified',
      'Must be rejected while only rated.',now(),true,actor_uuid,scope_uuid,
      trust_uuid,ownership_uuid,applicability_uuid,
      jsonb_build_object('classification','current_canonical',
        'palette',jsonb_build_array('#112233','#445566')),
      lineage_uuid,'Qualification test lineage.'
    );
  exception when others then
    rejected := sqlerrm like '%not currently qualified%';
  end;
  perform pg_temp.assert_true(rejected,
    'a rated but probationary source must be blocked from production evidence');

  for ordinal_value in 11..19 loop
    perform pg_temp.add_qualification_observation(
      qualification_enrollment,ordinal_value,'match'
    );
  end loop;
  perform pg_temp.add_qualification_observation(
    qualification_enrollment,20,'contradiction'
  );
  perform pg_temp.assert_true((
    select qualification_status = 'qualified'
       and assessed_case_count = 20 and raw_match_rate = 0.95
    from public.source_qualification_enrollments where id = qualification_enrollment
  ), '19 of 20 clean cases must qualify at the exact 95 percent boundary');
  insert into public.catalog_proposal_evidence(
    proposal_id,source_id,evidence_url,evidence_summary,observed_at,
    supports_proposal,submitted_by_actor_id,source_url_scope_version_id,
    source_trust_assignment_id,source_independence_assignment_id,
    source_applicability_version_id,structured_claim,
    information_lineage_version_id,information_lineage_basis
  ) values (
    proposal_uuid,source_record.id,'https://sq-e.example/qualified',
    'Qualified production evidence.',now(),true,actor_uuid,scope_uuid,
    trust_uuid,ownership_uuid,applicability_uuid,
    jsonb_build_object('classification','current_canonical',
      'palette',jsonb_build_array('#112233','#445566')),
    lineage_uuid,'Qualification test lineage.'
  );
  perform pg_temp.assert_true((
    select source_qualification_snapshot ->> 'qualification_status' = 'qualified'
       and source_qualification_evaluation_id is not null
    from public.catalog_proposal_evidence
    where proposal_id = proposal_uuid and evidence_url like '%/qualified'
  ), 'production evidence must snapshot the exact qualifying evaluation');

  for ordinal_value in 21..25 loop
    perform pg_temp.add_qualification_observation(
      qualification_enrollment,ordinal_value,'match'
    );
  end loop;
  for ordinal_value in 26..30 loop
    perform pg_temp.add_qualification_observation(
      qualification_enrollment,ordinal_value,'contradiction'
    );
  end loop;
  perform pg_temp.assert_true((
    select qualification_status = 'probationary'
       and assessed_case_count = 30 and raw_match_rate = 0.80
    from public.source_qualification_enrollments where id = qualification_enrollment
  ), '24 of 30 cases must downgrade a qualified source to probationary at 80 percent');
  rejected := false;
  begin
    insert into public.catalog_proposal_evidence(
      proposal_id,source_id,evidence_url,evidence_summary,observed_at,
      supports_proposal,submitted_by_actor_id,source_url_scope_version_id,
      source_trust_assignment_id,source_independence_assignment_id,
      source_applicability_version_id,structured_claim,
      information_lineage_version_id,information_lineage_basis
    ) values (
      proposal_uuid,source_record.id,'https://sq-e.example/after-downgrade',
      'Must be rejected after downgrade.',now(),true,actor_uuid,scope_uuid,
      trust_uuid,ownership_uuid,applicability_uuid,
      jsonb_build_object('classification','current_canonical',
        'palette',jsonb_build_array('#112233','#445566')),
      lineage_uuid,'Qualification test lineage.'
    );
  exception when others then
    rejected := sqlerrm like '%not currently qualified%';
  end;
  perform pg_temp.assert_true(rejected,
    'a downgraded source must immediately lose production evidence eligibility');

  for ordinal_value in 1..15 loop
    perform pg_temp.add_qualification_observation(
      recovery_enrollment,ordinal_value,'match'
    );
  end loop;
  for ordinal_value in 16..20 loop
    perform pg_temp.add_qualification_observation(
      recovery_enrollment,ordinal_value,'contradiction'
    );
  end loop;
  perform pg_temp.assert_true((
    select qualification_status = 'rejected' and raw_match_rate = 0.75
    from public.source_qualification_enrollments where id = recovery_enrollment
  ), 'a source below 80 percent at 20 cases must be rejected');
  for ordinal_value in 21..30 loop
    perform pg_temp.add_qualification_observation(
      recovery_enrollment,ordinal_value,'match'
    );
  end loop;
  perform pg_temp.assert_true((
    select qualification_status = 'probationary'
       and assessed_case_count = 30 and raw_match_rate > 0.83
    from public.source_qualification_enrollments where id = recovery_enrollment
  ), 'a rejected source must recover to probationary on a later ten-case reassessment');
end;
$$;

-- A source whose entire approved Team Color universe has fewer than twenty
-- teams may decide at exhaustive distinct-team coverage, but never below ten.
insert into public.catalog_teams(team_id,sport_id)
select 'hockey-' || (fixture.base_value + ordinal_value)::text,sport.id
from (values (996100),(996200),(996300),(996400)) fixture(base_value)
cross join generate_series(1,21) ordinal_value
cross join public.catalog_sports sport
where sport.sport_id = 'hockey';

insert into public.team_identity_versions(
  team_id,display_name,short_name,active,record_status
)
select team.id,'Narrow Qualification ' || team.team_id,
       'Narrow Qualification ' || team.team_id,true,'imported_unverified'
from public.catalog_teams team
where team.team_id ~ '^hockey-996[1-4][0-9]{2}$';

insert into public.team_primary_league_versions(team_id,league_id,record_status)
select team.id,league.id,'imported_unverified'
from public.catalog_teams team
join public.catalog_leagues league on league.league_id = 'hockey-nhl'
where team.team_id ~ '^hockey-996[1-4][0-9]{2}$';

insert into public.source_independence_groups(group_id,display_name)
select 'sq-owner-' || suffix,'SQ Owner ' || upper(suffix)
from unnest(array['g','h','i','j']) suffix;

insert into public.trusted_sources(
  source_id,display_name,base_url,reference_url,
  independence_group_id,review_status
)
select 'sq-source-' || suffix,'SQ Source ' || upper(suffix),
       'https://sq-' || suffix || '.example',
       'https://sq-' || suffix || '.example',ownership.id,'approved'
from unnest(array['g','h','i','j']) suffix
join public.source_independence_groups ownership
  on ownership.group_id = 'sq-owner-' || suffix;

insert into public.source_independence_group_assignment_versions(
  source_id,independence_group_id,review_status,notes
)
select source.id,source.independence_group_id,'approved',
       'Narrow qualification test ownership.'
from public.trusted_sources source
where source.source_id in (
  'sq-source-g','sq-source-h','sq-source-i','sq-source-j'
);

insert into public.trusted_source_url_scope_versions(
  source_id,hostname,include_subdomains,path_prefix,path_match,
  scope_kind,review_status
)
select source.id,'sq-' || right(source.source_id,1) || '.example',false,
       '/','prefix','publisher','approved'
from public.trusted_sources source
where source.source_id in (
  'sq-source-g','sq-source-h','sq-source-i','sq-source-j'
);

insert into public.source_trust_assignments(
  source_id,data_type,trust_tier,effective_from,notes
)
select source.id,'team_colors',3,current_date,
       'Governance tier is not narrow-source qualification.'
from public.trusted_sources source
where source.source_id in (
  'sq-source-g','sq-source-h','sq-source-i','sq-source-j'
);

insert into public.information_lineages(lineage_key,data_type)
select 'sq-lineage-' || suffix,'team_colors'
from unnest(array['g','h','i','j']) suffix;

insert into public.information_lineage_versions(
  lineage_id,version,display_name,review_status,notes
)
select lineage.id,1,'SQ Lineage ' || upper(right(lineage.lineage_key,1)),
       'approved','Narrow qualification test lineage.'
from public.information_lineages lineage
where lineage.lineage_key in (
  'sq-lineage-g','sq-lineage-h','sq-lineage-i','sq-lineage-j'
);

insert into public.source_applicability_versions(
  source_id,data_type,applicability_kind,team_id,review_status,notes
)
select source.id,'team_colors','team',team.id,'approved',
       'Exact narrow-source Team Color universe fixture.'
from public.trusted_sources source
join public.catalog_teams team on (
  (source.source_id = 'sq-source-g'
    and team.team_id between 'hockey-996101' and 'hockey-996112')
  or (source.source_id = 'sq-source-h'
    and team.team_id between 'hockey-996201' and 'hockey-996215')
  or (source.source_id = 'sq-source-i'
    and team.team_id between 'hockey-996301' and 'hockey-996303')
  or (source.source_id = 'sq-source-j'
    and team.team_id between 'hockey-996401' and 'hockey-996421')
)
where source.source_id in (
  'sq-source-g','sq-source-h','sq-source-i','sq-source-j'
);

do $$
declare
  narrow_twelve_enrollment uuid;
  narrow_fifteen_enrollment uuid;
  narrow_three_enrollment uuid;
  normal_universe_enrollment uuid;
  team_record record;
  duplicate_work_one uuid;
  duplicate_work_two uuid;
  source_uuid uuid;
  applicability_uuid uuid;
begin
  select enrollment.id into strict narrow_twelve_enrollment
  from public.source_qualification_enrollments enrollment
  join public.trusted_sources source on source.id = enrollment.source_id
  where source.source_id = 'sq-source-g';
  select enrollment.id into strict narrow_fifteen_enrollment
  from public.source_qualification_enrollments enrollment
  join public.trusted_sources source on source.id = enrollment.source_id
  where source.source_id = 'sq-source-h';
  select enrollment.id into strict narrow_three_enrollment
  from public.source_qualification_enrollments enrollment
  join public.trusted_sources source on source.id = enrollment.source_id
  where source.source_id = 'sq-source-i';
  select enrollment.id into strict normal_universe_enrollment
  from public.source_qualification_enrollments enrollment
  join public.trusted_sources source on source.id = enrollment.source_id
  where source.source_id = 'sq-source-j';

  for team_record in
    select team.id,row_number() over (order by team.team_id) as ordinal_value
    from public.catalog_teams team
    where team.team_id between 'hockey-996101' and 'hockey-996112'
  loop
    perform pg_temp.add_qualification_observation(
      narrow_twelve_enrollment,team_record.ordinal_value::integer,
      'match',team_record.id
    );
  end loop;
  perform pg_temp.assert_true((
    select enrollment.qualification_status = 'qualified'
       and enrollment.assessed_case_count = 12
       and enrollment.raw_match_rate = 1
       and evaluation.evaluation_kind = 'decision'
       and evaluation.decision_basis = 'narrow_exhaustive_coverage'
       and evaluation.applicable_subject_count = 12
       and evaluation.tested_applicable_subject_count = 12
    from public.source_qualification_enrollments enrollment
    join public.source_qualification_evaluations evaluation
      on evaluation.id = enrollment.latest_evaluation_id
    where enrollment.id = narrow_twelve_enrollment
  ), 'a 12-team source must qualify after matching all 12 applicable teams');

  for team_record in
    select team.id,row_number() over (order by team.team_id) as ordinal_value
    from public.catalog_teams team
    where team.team_id between 'hockey-996201' and 'hockey-996215'
  loop
    perform pg_temp.add_qualification_observation(
      narrow_fifteen_enrollment,team_record.ordinal_value::integer,
      case when team_record.ordinal_value = 15 then 'contradiction' else 'match' end,
      team_record.id
    );
  end loop;
  perform pg_temp.assert_true((
    select enrollment.qualification_status = 'probationary'
       and enrollment.assessed_case_count = 15
       and enrollment.match_count = 14
       and enrollment.raw_match_rate < 0.95
       and evaluation.decision_basis = 'narrow_exhaustive_coverage'
    from public.source_qualification_enrollments enrollment
    join public.source_qualification_evaluations evaluation
      on evaluation.id = enrollment.latest_evaluation_id
    where enrollment.id = narrow_fifteen_enrollment
  ), '14 of 15 exhaustive narrow-source cases must not qualify');

  for team_record in
    select team.id,row_number() over (order by team.team_id) as ordinal_value
    from public.catalog_teams team
    where team.team_id between 'hockey-996301' and 'hockey-996303'
  loop
    perform pg_temp.add_qualification_observation(
      narrow_three_enrollment,team_record.ordinal_value::integer,
      'match',team_record.id
    );
  end loop;
  perform pg_temp.assert_true((
    select qualification_status = 'probationary'
       and assessed_case_count = 3
       and raw_match_rate = 1
       and latest_evaluation_id is null
    from public.source_qualification_enrollments
    where id = narrow_three_enrollment
  ), '3 of 3 must remain probationary below the ten-case minimum');

  for team_record in
    select team.id,row_number() over (order by team.team_id) as ordinal_value
    from public.catalog_teams team
    where team.team_id between 'hockey-996401' and 'hockey-996419'
  loop
    perform pg_temp.add_qualification_observation(
      normal_universe_enrollment,team_record.ordinal_value::integer,
      'match',team_record.id
    );
  end loop;
  perform pg_temp.assert_true((
    select enrollment.qualification_status = 'probationary'
       and enrollment.assessed_case_count = 19
       and evaluation.evaluation_kind = 'rating'
       and evaluation.decision_basis = 'standard_case_threshold'
       and not exists (
         select 1
         from public.source_qualification_evaluations narrow_evaluation
         where narrow_evaluation.enrollment_id = enrollment.id
           and narrow_evaluation.decision_basis = 'narrow_exhaustive_coverage'
       )
    from public.source_qualification_enrollments enrollment
    join public.source_qualification_evaluations evaluation
      on evaluation.id = enrollment.latest_evaluation_id
    where enrollment.id = normal_universe_enrollment
  ), 'a source applicable to 21 teams must not use the narrow-source exception');

  select source.id into strict source_uuid
  from public.trusted_sources source where source.source_id = 'sq-source-g';
  select public.applicable_source_applicability_version(
    source_uuid,'team_colors',public.resolve_catalog_team_id('hockey-996101')
  ) into strict applicability_uuid;
  perform pg_temp.assert_true(
    (public.current_source_qualification_snapshot(
      source_uuid,'team_colors',applicability_uuid
    ) ->> 'production_evidence_eligible')::boolean,
    'an exhaustive 12 of 12 narrow decision must be production eligible'
  );

  perform set_config(
    'request.jwt.claim.sub','73000000-0000-0000-0000-000000000001',true
  );
  duplicate_work_one := public.enqueue_source_qualification_work(
    narrow_twelve_enrollment,'catalog_team',
    public.resolve_catalog_team_id('hockey-996101')::text,
    'https://sq-g.example/duplicate-one','sq-lineage-g'
  );
  duplicate_work_two := public.enqueue_source_qualification_work(
    narrow_twelve_enrollment,'catalog_team',
    public.resolve_catalog_team_id('hockey-996101')::text,
    'https://sq-g.example/duplicate-two','sq-lineage-g'
  );
  perform pg_temp.assert_true(
    duplicate_work_one = duplicate_work_two
    and (select count(*) = 12
         from public.source_qualification_observations observation
         where observation.enrollment_id = narrow_twelve_enrollment)
    and (select coverage.tested_applicable_team_count = 12
         from public.team_color_source_qualification_coverage(
           narrow_twelve_enrollment
         ) coverage),
    'repeated assignment of the same team must not inflate narrow coverage'
  );
end;
$$;

-- Later canonical-source redirects retain both historical profiles while the
-- target profile is reevaluated from one distinct clean case per subject.
insert into public.catalog_teams(team_id,sport_id)
select 'hockey-' || (995000 + ordinal_value)::text,sport.id
from generate_series(1,22) ordinal_value
cross join public.catalog_sports sport
where sport.sport_id = 'hockey';

insert into public.team_identity_versions(
  team_id,display_name,short_name,active,record_status
)
select team.id,'Qualification Merge ' || team.team_id,
       'Qualification Merge ' || team.team_id,true,'imported_unverified'
from public.catalog_teams team
where team.team_id between 'hockey-995001' and 'hockey-995022';

insert into public.team_primary_league_versions(team_id,league_id,record_status)
select team.id,league.id,'imported_unverified'
from public.catalog_teams team
join public.catalog_leagues league on league.league_id = 'hockey-nhl'
where team.team_id between 'hockey-995001' and 'hockey-995022';

insert into public.source_independence_groups(group_id,display_name)
values ('sq-merge-owner','SQ Merge Owner');

insert into public.trusted_sources(
  source_id,display_name,base_url,reference_url,
  independence_group_id,review_status
)
select fixture.source_id,fixture.display_name,fixture.base_url,
       fixture.base_url,ownership.id,'approved'
from (values
  ('sq-merge-a','SQ Merge Canonical','https://sq-merge-a.example'),
  ('sq-merge-b','SQ Merge Redirected','https://sq-merge-b.example')
) fixture(source_id,display_name,base_url)
cross join public.source_independence_groups ownership
where ownership.group_id = 'sq-merge-owner';

insert into public.source_independence_group_assignment_versions(
  source_id,independence_group_id,review_status,notes
)
select source.id,source.independence_group_id,'approved',
       'Canonical-source qualification merge fixture.'
from public.trusted_sources source
where source.source_id in ('sq-merge-a','sq-merge-b');

insert into public.trusted_source_url_scope_versions(
  source_id,hostname,include_subdomains,path_prefix,path_match,
  scope_kind,review_status
)
select source.id,
       case source.source_id
         when 'sq-merge-a' then 'sq-merge-a.example'
         else 'sq-merge-b.example'
       end,
       false,'/','prefix','publisher','approved'
from public.trusted_sources source
where source.source_id in ('sq-merge-a','sq-merge-b');

insert into public.source_trust_assignments(
  source_id,data_type,trust_tier,effective_from,notes
)
select source.id,'team_colors',3,current_date,
       'Matching governance tier for a reviewed source redirect.'
from public.trusted_sources source
where source.source_id in ('sq-merge-a','sq-merge-b');

insert into public.source_applicability_versions(
  source_id,data_type,applicability_kind,review_status,notes
)
select source.id,'team_colors','global','approved',
       'Global applicability keeps the merge fixture on the normal 20-case path.'
from public.trusted_sources source
where source.source_id in ('sq-merge-a','sq-merge-b');

do $$
declare
  source_a_uuid uuid;
  source_b_uuid uuid;
  enrollment_a_uuid uuid;
  enrollment_b_uuid uuid;
  applicability_a_uuid uuid;
  team_record record;
  b_observations_before jsonb;
  b_enrollment_before jsonb;
  canonical_evaluation_uuid uuid;
  clean_case_count integer;
begin
  select id into strict source_a_uuid
  from public.trusted_sources where source_id = 'sq-merge-a';
  select id into strict source_b_uuid
  from public.trusted_sources where source_id = 'sq-merge-b';
  select id into strict enrollment_a_uuid
  from public.source_qualification_enrollments
  where source_id = source_a_uuid and data_type = 'team_colors';
  select id into strict enrollment_b_uuid
  from public.source_qualification_enrollments
  where source_id = source_b_uuid and data_type = 'team_colors';

  for team_record in
    select team.id,row_number() over (order by team.team_id) as ordinal_value
    from public.catalog_teams team
    where team.team_id between 'hockey-995001' and 'hockey-995010'
  loop
    perform pg_temp.add_qualification_observation(
      enrollment_a_uuid,team_record.ordinal_value::integer,
      'match',team_record.id
    );
  end loop;
  for team_record in
    select team.id,row_number() over (order by team.team_id) as ordinal_value
    from public.catalog_teams team
    where team.team_id between 'hockey-995010' and 'hockey-995022'
  loop
    perform pg_temp.add_qualification_observation(
      enrollment_b_uuid,team_record.ordinal_value::integer,
      case when team_record.ordinal_value = 1
        then 'contradiction' else 'match' end,
      team_record.id
    );
  end loop;

  perform pg_temp.assert_true((
    select qualification_status = 'probationary'
       and assessed_case_count = 10
    from public.source_qualification_enrollments
    where id = enrollment_a_uuid
  ), 'the canonical source must be only rated before the redirect');
  perform pg_temp.assert_true((
    select qualification_status = 'probationary'
       and assessed_case_count = 13
    from public.source_qualification_enrollments
    where id = enrollment_b_uuid
  ), 'the source being redirected must retain its separate pre-merge profile');

  select coalesce(jsonb_agg(to_jsonb(observation) order by observation.id),'[]')
    into b_observations_before
  from public.source_qualification_observations observation
  where observation.enrollment_id = enrollment_b_uuid;
  select to_jsonb(enrollment) into strict b_enrollment_before
  from public.source_qualification_enrollments enrollment
  where enrollment.id = enrollment_b_uuid;

  perform set_config(
    'request.jwt.claim.sub','73000000-0000-0000-0000-000000000001',true
  );
  perform public.redirect_trusted_source(
    'sq-merge-b','sq-merge-a',
    'The two qualification fixtures are one canonical publisher.'
  );

  perform pg_temp.assert_true(
    public.canonical_trusted_source_id(source_b_uuid) = source_a_uuid,
    'the reviewed redirect must resolve the historical source to the canonical source'
  );
  perform pg_temp.assert_true((
    select to_jsonb(enrollment) = b_enrollment_before
    from public.source_qualification_enrollments enrollment
    where enrollment.id = enrollment_b_uuid
  ), 'redirect reconciliation must not rewrite the historical qualification profile');
  perform pg_temp.assert_true((
    select coalesce(jsonb_agg(to_jsonb(observation) order by observation.id),'[]')
             = b_observations_before
    from public.source_qualification_observations observation
    where observation.enrollment_id = enrollment_b_uuid
  ), 'redirect reconciliation must not rewrite historical observations');

  select count(*) into strict clean_case_count
  from public.canonical_source_qualification_clean_cases(enrollment_a_uuid);
  perform pg_temp.assert_true(
    clean_case_count = 21,
    'the duplicate team must count once and conflicting alias outcomes must not be a clean case'
  );
  perform pg_temp.assert_true((
    select not exists (
      select 1
      from public.canonical_source_qualification_clean_cases(enrollment_a_uuid) clean_case
      where clean_case.subject_id =
        public.resolve_catalog_team_id('hockey-995010')::text
    )
  ), 'conflicting outcomes for the same merged source/team must be excluded');

  select latest_evaluation_id into strict canonical_evaluation_uuid
  from public.source_qualification_enrollments where id = enrollment_a_uuid;
  perform pg_temp.assert_true((
    select enrollment.qualification_status = 'qualified'
       and enrollment.assessed_case_count = 21
       and enrollment.match_count = 21
       and enrollment.contradiction_count = 0
       and enrollment.raw_match_rate = 1
       and evaluation.evaluation_kind = 'decision'
       and evaluation.decision_basis = 'canonical_merge_reassessment'
       and evaluation.assessed_case_count = 21
    from public.source_qualification_enrollments enrollment
    join public.source_qualification_evaluations evaluation
      on evaluation.id = enrollment.latest_evaluation_id
    where enrollment.id = enrollment_a_uuid
  ), 'redirected histories must produce one current canonical merge decision above 20 cases');
  perform pg_temp.assert_true((
    select count(*) = 2
       and count(distinct evaluation_input_key) = 2
    from public.source_qualification_evaluations
    where enrollment_id = enrollment_a_uuid
  ), 'the canonical merge must append a new evaluation without replacing the earlier rating');
  perform pg_temp.assert_true(
    public.reconcile_canonical_source_qualification(
      source_b_uuid,'team_colors',true
    )
      = canonical_evaluation_uuid,
    'reconciling a historical source must idempotently resolve to the canonical profile'
  );

  select id into strict applicability_a_uuid
  from public.source_applicability_versions
  where source_id = source_a_uuid and data_type = 'team_colors'
    and applicability_kind = 'global' and is_current
    and review_status = 'approved';
  perform pg_temp.assert_true((
    select snapshot ->> 'enrollment_id' = enrollment_a_uuid::text
       and snapshot ->> 'source_id' = source_a_uuid::text
       and (snapshot ->> 'production_evidence_eligible')::boolean
    from (select public.current_source_qualification_snapshot(
      source_b_uuid,'team_colors',applicability_a_uuid
    ) snapshot) resolved
  ), 'historical source lookups must use the qualified canonical profile');
end;
$$;

-- A redirect must also downgrade a previously qualified canonical source when
-- conflicting alias history reduces the merged clean projection below twenty.
insert into public.source_independence_groups(group_id,display_name)
values ('sq-drop-owner','SQ Merge Downgrade Owner');

insert into public.trusted_sources(
  source_id,display_name,base_url,reference_url,
  independence_group_id,review_status
)
select fixture.source_id,fixture.display_name,fixture.base_url,
       fixture.base_url,ownership.id,'approved'
from (values
  ('sq-drop-a','SQ Qualified Canonical','https://sq-drop-a.example'),
  ('sq-drop-b','SQ Conflicting Redirect','https://sq-drop-b.example')
) fixture(source_id,display_name,base_url)
cross join public.source_independence_groups ownership
where ownership.group_id = 'sq-drop-owner';

insert into public.source_independence_group_assignment_versions(
  source_id,independence_group_id,review_status,notes
)
select source.id,source.independence_group_id,'approved',
       'Canonical merge downgrade fixture.'
from public.trusted_sources source
where source.source_id in ('sq-drop-a','sq-drop-b');

insert into public.trusted_source_url_scope_versions(
  source_id,hostname,include_subdomains,path_prefix,path_match,
  scope_kind,review_status
)
select source.id,
       case source.source_id
         when 'sq-drop-a' then 'sq-drop-a.example'
         else 'sq-drop-b.example'
       end,
       false,'/','prefix','publisher','approved'
from public.trusted_sources source
where source.source_id in ('sq-drop-a','sq-drop-b');

insert into public.source_trust_assignments(
  source_id,data_type,trust_tier,effective_from,notes
)
select source.id,'team_colors',3,current_date,
       'Matching governance tier for merge downgrade coverage.'
from public.trusted_sources source
where source.source_id in ('sq-drop-a','sq-drop-b');

insert into public.source_applicability_versions(
  source_id,data_type,applicability_kind,review_status,notes
)
select source.id,'team_colors','global','approved',
       'Global scope prevents use of the narrow-source exception.'
from public.trusted_sources source
where source.source_id in ('sq-drop-a','sq-drop-b');

do $$
declare
  source_a_uuid uuid;
  source_b_uuid uuid;
  enrollment_a_uuid uuid;
  enrollment_b_uuid uuid;
  applicability_a_uuid uuid;
  team_record record;
  b_observations_before jsonb;
begin
  select id into strict source_a_uuid
  from public.trusted_sources where source_id = 'sq-drop-a';
  select id into strict source_b_uuid
  from public.trusted_sources where source_id = 'sq-drop-b';
  select id into strict enrollment_a_uuid
  from public.source_qualification_enrollments
  where source_id = source_a_uuid and data_type = 'team_colors';
  select id into strict enrollment_b_uuid
  from public.source_qualification_enrollments
  where source_id = source_b_uuid and data_type = 'team_colors';

  for team_record in
    select team.id,row_number() over (order by team.team_id) as ordinal_value
    from public.catalog_teams team
    where team.team_id between 'hockey-995001' and 'hockey-995020'
  loop
    perform pg_temp.add_qualification_observation(
      enrollment_a_uuid,team_record.ordinal_value::integer,
      'match',team_record.id
    );
  end loop;
  perform pg_temp.add_qualification_observation(
    enrollment_b_uuid,1,'contradiction',
    public.resolve_catalog_team_id('hockey-995020')
  );
  perform pg_temp.assert_true((
    select qualification_status = 'qualified'
       and assessed_case_count = 20
       and match_count = 20
    from public.source_qualification_enrollments
    where id = enrollment_a_uuid
  ), 'the canonical source must be qualified at 20 clean cases before merge');

  select coalesce(jsonb_agg(to_jsonb(observation) order by observation.id),'[]')
    into b_observations_before
  from public.source_qualification_observations observation
  where observation.enrollment_id = enrollment_b_uuid;
  perform set_config(
    'request.jwt.claim.sub','73000000-0000-0000-0000-000000000001',true
  );
  perform public.redirect_trusted_source(
    'sq-drop-b','sq-drop-a',
    'Conflicting historical alias merged into the qualified canonical source.'
  );

  perform pg_temp.assert_true((
    select count(*) = 19
    from public.canonical_source_qualification_clean_cases(enrollment_a_uuid)
  ), 'the conflicting duplicate team must reduce canonical clean coverage to 19');
  perform pg_temp.assert_true((
    select enrollment.qualification_status = 'probationary'
       and enrollment.assessed_case_count = 19
       and enrollment.match_count = 19
       and enrollment.contradiction_count = 0
       and evaluation.assessed_case_count = 19
       and evaluation.evaluation_kind = 'reconciliation'
       and evaluation.decision_basis = 'canonical_merge_reassessment'
       and evaluation.resulting_status = 'probationary'
    from public.source_qualification_enrollments enrollment
    join public.source_qualification_evaluations evaluation
      on evaluation.id = enrollment.latest_evaluation_id
    where enrollment.id = enrollment_a_uuid
  ), 'a merged 19-case canonical source outside narrow coverage must downgrade to probationary');
  perform pg_temp.assert_true((
    select coalesce(jsonb_agg(to_jsonb(observation) order by observation.id),'[]')
             = b_observations_before
    from public.source_qualification_observations observation
    where observation.enrollment_id = enrollment_b_uuid
  ), 'merge downgrade reconciliation must preserve historical observations');

  select id into strict applicability_a_uuid
  from public.source_applicability_versions
  where source_id = source_a_uuid and data_type = 'team_colors'
    and applicability_kind = 'global' and is_current
    and review_status = 'approved';
  perform pg_temp.assert_true(
    not (public.current_source_qualification_snapshot(
      source_b_uuid,'team_colors',applicability_a_uuid
    ) ->> 'production_evidence_eligible')::boolean,
    'the downgraded merged source must immediately lose production eligibility'
  );
end;
$$;

-- The generic qualification queue uses the Team Color specialist runtime
-- policy, normal attempts, lease expiry recovery, retry exhaustion, and wakes.
do $$
declare
  enrollment_uuid uuid;
  team_uuid uuid := public.resolve_catalog_team_id('hockey-997003');
  work_context jsonb;
  work_uuid uuid;
  lease_uuid uuid;
begin
  select enrollment.id into strict enrollment_uuid
  from public.source_qualification_enrollments enrollment
  join public.trusted_sources source on source.id = enrollment.source_id
  where source.source_id = 'sq-source-a';
  perform set_config('request.jwt.claim.sub','73000000-0000-0000-0000-000000000001',true);
  perform public.enqueue_source_qualification_work(
    enrollment_uuid,'catalog_team',team_uuid::text,
    'https://sq-a.example/retry-case','sq-lineage-a'
  );
  perform set_config('request.jwt.claim.sub','73000000-0000-0000-0000-000000000002',true);
  work_context := public.claim_next_source_qualification_work('team_colors');
  work_uuid := (work_context #>> '{work,work_item_id}')::uuid;
  update public.source_qualification_work_items
  set lease_expires_at = now() - interval '1 second' where id = work_uuid;
  update public.source_qualification_attempts
  set lease_expires_at = now() - interval '1 second'
  where work_item_id = work_uuid and ended_at is null;
  perform public.recover_team_color_domain();
  perform pg_temp.assert_true((
    select status = 'retry_wait' and attempt_count = 1
    from public.source_qualification_work_items where id = work_uuid
  ), 'watchdog recovery must move an expired qualification lease to retry_wait');
  perform pg_temp.assert_true(exists (
    select 1 from public.agent_work_wake_outbox
    where queue_name = 'source_qualification.team_colors'
      and work_item_id = work_uuid and status = 'pending'
  ), 'retryable qualification work must use the shared durable wake outbox');
  work_context := public.claim_next_source_qualification_work('team_colors');
  lease_uuid := (work_context #>> '{work,lease_token}')::uuid;
  perform pg_temp.assert_true(
    public.report_source_qualification_work_failure(
      work_uuid,lease_uuid,'temporary_network_failure','Second transient failure.'
    ) = 'needs_review',
    'the shared two-attempt Team Color runtime policy must govern qualification exhaustion'
  );
  perform pg_temp.assert_true((
    select status = 'needs_review' and attempt_count = 2
      and (select count(*) = 2 from public.source_qualification_attempts attempt
           where attempt.work_item_id = work.id)
    from public.source_qualification_work_items work where id = work_uuid
  ), 'qualification work must retain both durable attempts after exhaustion');
end;
$$;

-- Later lineage corrections preserve immutable historical observations while
-- current roots govern all new qualification references.
do $$
declare
  historical_team_uuid uuid := public.resolve_catalog_team_id('hockey-997001');
  future_team_uuid uuid := public.resolve_catalog_team_id('hockey-997004');
  historical_observation_count integer;
  source_suffix text;
  lineage_key_value text;
  work_context jsonb;
begin
  select count(*) into historical_observation_count
  from public.source_qualification_observations
  where subject_id = historical_team_uuid::text;
  perform set_config('request.jwt.claim.sub','73000000-0000-0000-0000-000000000001',true);
  perform public.admin_review_information_lineage(
    'sq-lineage-b','team_colors','SQ Lineage B merged into A',null,
    'merged','sq-lineage-a','Later evidence established a shared origin.',
    jsonb_build_object('test','prospective-lineage-correction')
  );
  perform pg_temp.assert_true((
    select count(*) = historical_observation_count
    from public.source_qualification_observations
    where subject_id = historical_team_uuid::text
  ), 'a later lineage merge must not rewrite historical qualification observations');

  foreach source_suffix in array array['a','b','c','d'] loop
    lineage_key_value := case when source_suffix = 'b' then 'sq-lineage-a'
      else 'sq-lineage-' || source_suffix end;
    perform public.enqueue_source_qualification_work(
      (select enrollment.id
       from public.source_qualification_enrollments enrollment
       join public.trusted_sources source on source.id = enrollment.source_id
       where source.source_id = 'sq-source-' || source_suffix),
      'catalog_team',future_team_uuid::text,
      'https://sq-' || source_suffix || '.example/team-four',
      lineage_key_value
    );
  end loop;
  perform set_config('request.jwt.claim.sub','73000000-0000-0000-0000-000000000002',true);
  for source_suffix in select unnest(array['a','b','c','d']) loop
    work_context := public.claim_next_source_qualification_work('team_colors');
    perform public.submit_source_qualification_result(
      (work_context #>> '{work,work_item_id}')::uuid,
      (work_context #>> '{work,lease_token}')::uuid,
      'determinate',jsonb_build_object(
        'classification','current_canonical',
        'palette',jsonb_build_array('#112233','#445566')
      ),'Post-merge prospective-lineage fixture.'
    );
  end loop;
  perform pg_temp.assert_true(not exists (
    select 1 from public.source_qualification_observations
    where subject_id = future_team_uuid::text
  ), 'merged lineages must count as one for every future qualification reference');
end;
$$;

rollback;
