-- Transactional integration coverage for reusable publisher governance,
-- independently applicable Team Color evidence and corroborated reliability.

begin;

create or replace function pg_temp.assert_true(value boolean, message text)
returns void language plpgsql as $$
begin
  if not coalesce(value, false) then
    raise exception 'Trusted Source integration assertion failed: %', message;
  end if;
end;
$$;

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000','72000000-0000-0000-0000-000000000001','authenticated','authenticated','publisher-test-admin@fanatical.invalid','',now(),'{}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','72000000-0000-0000-0000-000000000002','authenticated','authenticated','publisher-test-agent@fanatical.invalid','',now(),'{}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','72000000-0000-0000-0000-000000000003','authenticated','authenticated','publisher-test-verifier@fanatical.invalid','',now(),'{}','{}',now(),now());

insert into public.staff_roles(user_id,role,permissions,is_active)
values ('72000000-0000-0000-0000-000000000001','admin',array[]::text[],true);

insert into public.catalog_actors(actor_key,actor_type,auth_user_id,display_name)
values
  ('publisher-test-admin','human','72000000-0000-0000-0000-000000000001','Publisher Test Admin'),
  ('publisher-test-agent','agent','72000000-0000-0000-0000-000000000002','Publisher Test Agent'),
  ('publisher-test-verifier','human','72000000-0000-0000-0000-000000000003','Publisher Test Verifier');

insert into public.catalog_actor_capabilities(actor_id,capability)
select actor.id, capability
from public.catalog_actors actor
cross join unnest(array[
  'team_colors.work.claim','team_colors.work.read','team_colors.work.update',
  'team_colors.source_candidates.submit','catalog.propose.team_colors'
]) capability
where actor.actor_key = 'publisher-test-agent';
insert into public.catalog_actor_capabilities(actor_id,capability)
select id,'catalog.verify.team_colors' from public.catalog_actors
where actor_key = 'publisher-test-verifier';

insert into public.catalog_teams(team_id,sport_id)
select fixture.team_id,sport.id
from (values ('hockey-999981'),('hockey-999982'),('hockey-999983')) fixture(team_id)
cross join public.catalog_sports sport where sport.sport_id = 'hockey';
insert into public.team_identity_versions(team_id,display_name,short_name,active,record_status)
select team.id,fixture.name,fixture.name,true,'imported_unverified'
from (values
  ('hockey-999981','Publisher Scope Team A'),
  ('hockey-999982','Publisher Scope Team B'),
  ('hockey-999983','Publisher Scope Team C')
) fixture(team_id,name)
join public.catalog_teams team on team.team_id = fixture.team_id;
insert into public.team_primary_league_versions(team_id,league_id,record_status)
select team.id,league.id,'imported_unverified'
from public.catalog_teams team
join public.catalog_leagues league on league.league_id = case
  when team.team_id = 'hockey-999983' then 'hockey-ahl' else 'hockey-nhl' end
where team.team_id in ('hockey-999981','hockey-999982','hockey-999983');

insert into public.source_independence_groups(group_id,display_name)
values
  ('publisher-test-global-owner','Global Publisher Owner'),
  ('publisher-test-sport-owner','Sport Publisher Owner'),
  ('publisher-test-league-owner','League Publisher Owner'),
  ('publisher-test-team-owner','Team Publisher Owner'),
  ('publisher-test-other-team-owner','Other Team Publisher Owner'),
  ('publisher-test-conflict-owner','Conflict Publisher Owner'),
  ('publisher-test-special-owner','Special Publisher Owner'),
  ('publisher-test-path-owner','Path Publisher Owner'),
  ('publisher-test-ambiguous-a','Ambiguous Publisher A'),
  ('publisher-test-ambiguous-b','Ambiguous Publisher B');

insert into public.trusted_sources(
  source_id,display_name,base_url,reference_url,independence_group_id,review_status
)
select fixture.source_id,fixture.display_name,fixture.base_url,fixture.base_url,
       independence.id,'approved'
from (values
  ('publisher-test-global','Global Test Publisher','https://publisher.example','publisher-test-global-owner'),
  ('publisher-test-global-canonical','Global Test Publisher Canonical','https://canonical.example','publisher-test-global-owner'),
  ('publisher-test-sport','Sport Test Publisher','https://sport.example','publisher-test-sport-owner'),
  ('publisher-test-league','League Test Publisher','https://league.example','publisher-test-league-owner'),
  ('publisher-test-team','Team Test Publisher','https://team.example','publisher-test-team-owner'),
  ('publisher-test-other-team','Other Team Test Publisher','https://other-team.example','publisher-test-other-team-owner'),
  ('publisher-test-conflict','Conflict Test Publisher','https://conflict.example','publisher-test-conflict-owner'),
  ('publisher-test-special','Special Test Publisher','https://special.example','publisher-test-special-owner'),
  ('publisher-test-path','Path Test Publisher','https://shared.example/teams/a','publisher-test-path-owner'),
  ('publisher-test-ambiguous-a','Ambiguous Test Publisher A','https://ambiguous.example','publisher-test-ambiguous-a'),
  ('publisher-test-ambiguous-b','Ambiguous Test Publisher B','https://ambiguous.example','publisher-test-ambiguous-b')
) fixture(source_id,display_name,base_url,group_id)
join public.source_independence_groups independence
  on independence.group_id = fixture.group_id;

insert into public.source_independence_group_assignment_versions(
  source_id,independence_group_id,review_status,notes
)
select source.id,source.independence_group_id,'approved','Transactional ownership fixture.'
from public.trusted_sources source where source.source_id like 'publisher-test-%';

insert into public.trusted_source_alias_versions(source_id,alias,alias_type,notes)
select id,'Global Publisher Alias','publisher_name','Hostname alias fixture.'
from public.trusted_sources where source_id = 'publisher-test-global';

insert into public.trusted_source_url_scope_versions(
  source_id,hostname,include_subdomains,path_prefix,path_match,scope_kind,review_status
)
select source.id,fixture.hostname,fixture.subdomains,fixture.path_prefix,
       fixture.path_match,fixture.scope_kind,'approved'
from (values
  ('publisher-test-global','publisher.example',true,'/','prefix','publisher'),
  ('publisher-test-global','alias.example',false,'/','prefix','hostname_alias'),
  ('publisher-test-global','cdn.example',false,'/brand-assets','prefix','cdn'),
  ('publisher-test-global-canonical','canonical.example',false,'/','prefix','publisher'),
  ('publisher-test-sport','sport.example',false,'/','prefix','publisher'),
  ('publisher-test-league','league.example',false,'/','prefix','publisher'),
  ('publisher-test-team','team.example',false,'/','prefix','publisher'),
  ('publisher-test-other-team','other-team.example',false,'/','prefix','publisher'),
  ('publisher-test-conflict','conflict.example',false,'/','prefix','publisher'),
  ('publisher-test-special','special.example',false,'/','prefix','publisher'),
  ('publisher-test-path','shared.example',false,'/teams/a','prefix','path_owner'),
  ('publisher-test-ambiguous-a','ambiguous.example',false,'/','prefix','publisher'),
  ('publisher-test-ambiguous-b','ambiguous.example',false,'/','prefix','publisher')
) fixture(source_id,hostname,subdomains,path_prefix,path_match,scope_kind)
join public.trusted_sources source on source.source_id = fixture.source_id;

insert into public.source_trust_assignments(
  source_id,data_type,trust_tier,effective_from,notes
)
select source.id,'team_colors',fixture.tier,current_date,
       'Transactional publisher/data-type trust fixture.'
from (values
  ('publisher-test-global',3),
  ('publisher-test-sport',3),
  ('publisher-test-league',3),
  ('publisher-test-team',1),
  ('publisher-test-other-team',1),
  ('publisher-test-conflict',3),
  ('publisher-test-special',3)
) fixture(source_id,tier)
join public.trusted_sources source on source.source_id = fixture.source_id;

insert into public.source_applicability_versions(
  source_id,data_type,applicability_kind,sport_id,league_id,team_id,
  review_status,notes
)
select source.id,'team_colors',fixture.scope_kind,
       case when fixture.scope_kind = 'sport' then sport.id end,
       case when fixture.scope_kind = 'league' then league.id end,
       case when fixture.scope_kind = 'team' then team.id end,
       'approved','Transactional applicability fixture.'
from (values
  ('publisher-test-global',3,'global',null),
  ('publisher-test-sport',3,'sport','hockey'),
  ('publisher-test-league',3,'league','hockey-nhl'),
  ('publisher-test-team',1,'team','hockey-999981'),
  ('publisher-test-other-team',1,'team','hockey-999982'),
  ('publisher-test-conflict',3,'global',null),
  ('publisher-test-special',3,'global',null)
) fixture(source_id,tier,scope_kind,scope_identifier)
join public.trusted_sources source on source.source_id = fixture.source_id
left join public.catalog_sports sport on fixture.scope_kind = 'sport'
  and sport.sport_id = fixture.scope_identifier
left join public.catalog_leagues league on fixture.scope_kind = 'league'
  and league.league_id = fixture.scope_identifier
left join public.catalog_teams team on fixture.scope_kind = 'team'
  and team.team_id = fixture.scope_identifier;

insert into public.information_lineages(lineage_key,data_type)
select 'lineage-' || source.source_id,'team_colors'
from public.trusted_sources source
where source.source_id in (
  'publisher-test-global','publisher-test-sport','publisher-test-league',
  'publisher-test-team','publisher-test-other-team','publisher-test-conflict',
  'publisher-test-special'
);
insert into public.information_lineage_versions(
  lineage_id,version,display_name,review_status,notes
)
select lineage.id,1,'Lineage for ' || source.display_name,'approved',
       'Transactional source-governance lineage fixture.'
from public.information_lineages lineage
join public.trusted_sources source
  on lineage.lineage_key = 'lineage-' || source.source_id
where lineage.data_type = 'team_colors';

-- URL normalization, aliases, subdomains, paths, CDN scopes, and ambiguity.
do $$
declare result jsonb;
begin
  perform pg_temp.assert_true(
    public.normalize_source_url('HTTPS://Publisher.Example:443/a//b/?q=1#x') =
      'https://publisher.example/a/b',
    'URL normalization must lower host, strip port/query/fragment, and normalize path'
  );
  perform set_config('request.jwt.claim.sub','72000000-0000-0000-0000-000000000002',true);
  result := public.resolve_trusted_source_url('https://news.publisher.example/colors');
  perform pg_temp.assert_true(result ->> 'status' = 'resolved'
    and result #>> '{matches,0,source_id}' = 'publisher-test-global',
    'permitted subdomain must resolve to the publisher');
  result := public.resolve_trusted_source_url('https://alias.example/colors');
  perform pg_temp.assert_true(result #>> '{matches,0,source_id}' = 'publisher-test-global',
    'hostname alias must resolve to the canonical publisher');
  result := public.resolve_trusted_source_url('https://cdn.example/brand-assets/team/logo.svg');
  perform pg_temp.assert_true(result #>> '{matches,0,source_id}' = 'publisher-test-global',
    'approved CDN/document path must resolve');
  result := public.resolve_trusted_source_url('https://shared.example/teams/a/colors');
  perform pg_temp.assert_true(result #>> '{matches,0,source_id}' = 'publisher-test-path',
    'path-scoped publisher ownership must resolve');
  result := public.resolve_trusted_source_url('https://shared.example/teams/ab/colors');
  perform pg_temp.assert_true(result ->> 'status' = 'none',
    'path prefix matching must respect path boundaries');
  result := public.resolve_trusted_source_url('https://ambiguous.example/colors');
  perform pg_temp.assert_true(result ->> 'status' = 'ambiguous'
    and jsonb_array_length(result -> 'matches') = 2,
    'overlapping equally specific publishers must remain ambiguous');
  perform pg_temp.assert_true(exists (
    select 1 from public.trusted_source_alias_versions
    where normalized_alias = 'global publisher alias' and is_current
  ), 'publisher aliases must be normalized and reusable');
end;
$$;

-- Global/sport/league/team applicability is independent from publisher tier.
do $$
declare team_a uuid := public.resolve_catalog_team_id('hockey-999981');
declare team_b uuid := public.resolve_catalog_team_id('hockey-999982');
declare team_c uuid := public.resolve_catalog_team_id('hockey-999983');
begin
  perform pg_temp.assert_true(public.applicable_source_applicability_version(
    (select id from public.trusted_sources where source_id='publisher-test-global'),'team_colors',team_c
  ) is not null,'global applicability must apply across teams');
  perform pg_temp.assert_true(public.applicable_source_applicability_version(
    (select id from public.trusted_sources where source_id='publisher-test-sport'),'team_colors',team_c
  ) is not null,'sport applicability must apply across leagues in the sport');
  perform pg_temp.assert_true(public.applicable_source_applicability_version(
    (select id from public.trusted_sources where source_id='publisher-test-league'),'team_colors',team_a
  ) is not null,'league applicability must apply inside the league');
  perform pg_temp.assert_true(public.applicable_source_applicability_version(
    (select id from public.trusted_sources where source_id='publisher-test-league'),'team_colors',team_c
  ) is null,'league applicability must not cross leagues');
  perform pg_temp.assert_true(public.applicable_source_applicability_version(
    (select id from public.trusted_sources where source_id='publisher-test-team'),'team_colors',team_a
  ) is not null,'team applicability must apply to its team');
  perform pg_temp.assert_true(public.applicable_source_applicability_version(
    (select id from public.trusted_sources where source_id='publisher-test-team'),'team_colors',team_b
  ) is null,'team applicability must not cross teams');
end;
$$;

-- Tier and applicability are structurally and behaviorally independent.
do $$
declare
  source_uuid uuid := (
    select id from public.trusted_sources where source_id = 'publisher-test-sport'
  );
  team_a uuid := public.resolve_catalog_team_id('hockey-999981');
  team_c uuid := public.resolve_catalog_team_id('hockey-999983');
  tier_before uuid;
  applicability_before uuid[];
  applicability_after uuid[];
  duplicate_rejected boolean := false;
begin
  perform pg_temp.assert_true(not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'source_trust_assignments'
      and column_name in ('sport_id','league_id','team_id')
  ),'publisher/data-type trust tiers must not contain target scope columns');
  perform pg_temp.assert_true(not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'source_applicability_versions'
      and column_name = 'trust_tier'
  ),'applicability versions must not be able to carry a tier');

  begin
    insert into public.source_trust_assignments(
      source_id,data_type,trust_tier,effective_from,notes
    ) values (source_uuid,'team_colors',4,current_date,'Must violate one-current-tier invariant.');
  exception when unique_violation then duplicate_rejected := true; end;
  perform pg_temp.assert_true(duplicate_rejected,
    'one publisher/data type must have only one current trust tier');

  select public.current_source_trust_tier_assignment(source_uuid,'team_colors')
    into tier_before;
  perform set_config('request.jwt.claim.sub','72000000-0000-0000-0000-000000000001',true);
  perform public.review_source_applicability(
    'publisher-test-sport','team_colors','team',null,null,'hockey-999981',
    'approved','Add a more-specific applicability without touching tier.'
  );
  perform pg_temp.assert_true(
    public.current_source_trust_tier_assignment(source_uuid,'team_colors') = tier_before,
    'changing applicability must not create or change a trust-tier version'
  );
  perform pg_temp.assert_true((
    select applicability_kind = 'team'
    from public.source_applicability_versions
    where id = public.applicable_source_applicability_version(
      source_uuid,'team_colors',team_a
    )
  ),'most-specific team applicability may win without changing publisher tier');
  perform pg_temp.assert_true((
    select applicability_kind = 'sport'
    from public.source_applicability_versions
    where id = public.applicable_source_applicability_version(
      source_uuid,'team_colors',team_c
    )
  ),'sport applicability must remain independently selectable for another team');

  select array_agg(id order by id) into applicability_before
  from public.source_applicability_versions
  where source_id = source_uuid and data_type = 'team_colors' and is_current;
  perform public.admin_set_source_trust_tier(
    'publisher-test-sport','team_colors',2::smallint,'Change tier without touching applicability.'
  );
  select array_agg(id order by id) into applicability_after
  from public.source_applicability_versions
  where source_id = source_uuid and data_type = 'team_colors' and is_current;
  perform pg_temp.assert_true(applicability_after = applicability_before,
    'changing tier must not create, retire, or change applicability versions');
  perform pg_temp.assert_true((
    select count(*) = 1 and bool_and(trust_tier = 2)
    from public.source_trust_assignments
    where source_id = source_uuid and data_type = 'team_colors' and is_current
  ),'tier change must leave exactly one current publisher/data-type tier');
end;
$$;

-- Candidate reuse, evidence ownership/applicability, structured claims, and
-- independently verified reliability outcomes.
select set_config('request.jwt.claim.sub','72000000-0000-0000-0000-000000000001',true);
select public.enqueue_team_color_work('hockey-999981',500,null,'Publisher governance integration.',now());

do $$
declare
  claim jsonb;
  work_id uuid;
  lease uuid;
  proposal uuid;
  verifier_claim jsonb;
  verification_work_id uuid;
  verifier_lease uuid;
  verifier_result_id uuid;
  denied boolean;
  palette jsonb := jsonb_build_array('#112233','#445566','#FFFFFF');
begin
  perform set_config('request.jwt.claim.sub','72000000-0000-0000-0000-000000000002',true);
  claim := public.claim_next_team_color_work(900);
  work_id := (claim #>> '{work,work_item_id}')::uuid;
  lease := (claim #>> '{work,lease_token}')::uuid;

  denied := false;
  begin
    perform public.submit_team_color_source_candidate(
      work_id,lease,'duplicate-by-url','Duplicate URL Publisher',
      'https://publisher.example','https://publisher.example/reference',
      'https://publisher.example/team/colors','Must reuse an existing publisher.',now()
    );
  exception when others then denied := true; end;
  perform pg_temp.assert_true(denied,'candidate intake must reject a URL that resolves to an existing publisher');

  denied := false;
  begin
    perform public.submit_team_color_source_candidate(
      work_id,lease,'duplicate-by-name','Global Test Publisher',
      'https://new-name.example','https://new-name.example/reference',
      'https://new-name.example/colors','Potential name duplicate.',now()
    );
  exception when others then denied := true; end;
  perform pg_temp.assert_true(denied,'candidate intake must detect equivalent publisher names');

  denied := false;
  begin
    perform public.submit_team_color_source_candidate(
      work_id,lease,'ambiguous-reuse','Ambiguous Reuse',
      'https://ambiguous.example','https://ambiguous.example/reference',
      'https://ambiguous.example/colors','Ambiguous source must be reviewed.',now()
    );
  exception when others then denied := true; end;
  perform pg_temp.assert_true(denied,'candidate intake must not guess across ambiguous matches');

  perform pg_temp.assert_true(public.submit_team_color_source_candidate(
    work_id,lease,'publisher-test-new-candidate','New Candidate Publisher',
    'https://new-candidate.example','https://new-candidate.example/reference',
    'https://new-candidate.example/colors','No existing publisher resolves.',now()
  ) is not null,'unresolved URLs may create a pending candidate');

  proposal := public.submit_team_color_proposal(
    work_id,lease,jsonb_build_object(
      'primary','#112233','secondary','#445566','tertiary','#FFFFFF',
      'effective_from_precision','unknown'
    ),'Structured publisher-governance proposal.'
  );

  denied := false;
  begin
    perform public.add_team_color_proposal_evidence(
      proposal,'publisher-test-team','https://publisher.example/colors','Wrong domain.',now(),true,
      jsonb_build_object('classification','current_canonical','palette',palette)
    );
  exception when others then denied := true; end;
  perform pg_temp.assert_true(denied,'selected publisher must reject wrong-domain evidence');

  denied := false;
  begin
    perform public.add_team_color_proposal_evidence(
      proposal,'publisher-test-other-team','https://other-team.example/colors','Wrong team.',now(),true,
      jsonb_build_object('classification','current_canonical','palette',palette)
    );
  exception when others then denied := true; end;
  perform pg_temp.assert_true(denied,'team-scoped trust must reject evidence for another team');

  denied := false;
  begin
    perform public.add_team_color_proposal_evidence(
      proposal,'publisher-test-ambiguous-a','https://ambiguous.example/colors','Ambiguous ownership.',now(),true,
      jsonb_build_object('classification','current_canonical','palette',palette)
    );
  exception when others then denied := true; end;
  perform pg_temp.assert_true(denied,'ambiguous URL ownership must reject evidence');

  perform public.add_team_color_proposal_evidence(
    proposal,'publisher-test-team','https://team.example/colors','Team official palette.',now(),true,
    jsonb_build_object('classification','current_canonical','palette',palette)
  );
  perform public.add_team_color_proposal_evidence(
    proposal,'publisher-test-global','https://publisher.example/colors','Publisher page one.',now(),true,
    jsonb_build_object('classification','current_canonical','palette',palette)
  );
  perform public.add_team_color_proposal_evidence(
    proposal,'publisher-test-global','https://alias.example/colors','Publisher alias page two.',now(),true,
    jsonb_build_object('classification','current_canonical','palette',palette)
  );
  perform public.add_team_color_proposal_evidence(
    proposal,'publisher-test-sport','https://sport.example/colors','Applicable sport publisher evidence.',now(),true,
    jsonb_build_object('classification','current_canonical','palette',palette)
  );
  perform public.add_team_color_proposal_evidence(
    proposal,'publisher-test-conflict','https://conflict.example/colors','Conflicting current palette.',now(),false,
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#AABBCC','#DDEEFF'))
  );
  perform public.add_team_color_proposal_evidence(
    proposal,'publisher-test-special','https://special.example/heritage','Special treatment is not canonical.',now(),false,
    jsonb_build_object('classification','special_treatment','palette',palette)
  );
  update public.catalog_proposal_evidence evidence
  set information_lineage_version_id = lineage_version.id,
      information_lineage_basis = 'Transactional source-specific lineage fixture.'
  from public.trusted_sources source
  join public.information_lineages lineage
    on lineage.lineage_key = 'lineage-' || source.source_id
  join public.information_lineage_versions lineage_version
    on lineage_version.lineage_id = lineage.id and lineage_version.is_current
  where evidence.proposal_id = proposal and evidence.source_id = source.id;
  perform public.finish_team_color_work(work_id,lease,'submitted_for_verification',null,null,null,'{}');

  perform set_config('request.jwt.claim.sub','72000000-0000-0000-0000-000000000003',true);
  update public.source_trust_assignments
  set is_current = false, effective_to = current_date, superseded_at = now()
  where source_id = (select id from public.trusted_sources where source_id = 'publisher-test-team')
    and data_type = 'team_colors' and is_current;
  perform pg_temp.assert_true(
    public.current_source_trust_tier_assignment(
      (select id from public.trusted_sources where source_id = 'publisher-test-team'),
      'team_colors'
    ) is null,
    'qualification must reject evidence whose exact trust assignment is no longer current'
  );
  update public.source_trust_assignments
  set is_current = true, effective_to = null, superseded_at = null
  where source_id = (select id from public.trusted_sources where source_id = 'publisher-test-team')
    and data_type = 'team_colors' and not is_current;

  verifier_claim := public.claim_next_catalog_verification_work('team_colors');
  verification_work_id := (verifier_claim #>> '{work,verification_work_item_id}')::uuid;
  verifier_lease := (verifier_claim #>> '{work,lease_token}')::uuid;
  perform public.add_team_color_verifier_evidence(
    verification_work_id,verifier_lease,'publisher-test-team',
    'https://team.example/verifier-colors','Verifier independently found the official palette.',now(),
    jsonb_build_object('classification','current_canonical','palette',palette),
    'lineage-publisher-test-team','Official team lineage.'
  );
  perform public.add_team_color_verifier_evidence(
    verification_work_id,verifier_lease,'publisher-test-global',
    'https://publisher.example/verifier-colors','Verifier independently found corroborating evidence.',now(),
    jsonb_build_object('classification','current_canonical','palette',palette),
    'lineage-publisher-test-global','Independent publisher lineage.'
  );
  perform public.add_team_color_verifier_evidence(
    verification_work_id,verifier_lease,'publisher-test-sport',
    'https://sport.example/verifier-colors','Verifier independently found applicable sport evidence.',now(),
    jsonb_build_object('classification','current_canonical','palette',palette),
    'lineage-publisher-test-sport','Independent sport publisher lineage.'
  );
  verifier_result_id := public.submit_team_color_verifier_result(
    verification_work_id,verifier_lease,'determinate',
    jsonb_build_object('classification','current_canonical','palette',palette),
    'Independent verifier matched the specialist palette.'
  );
  perform set_config('request.jwt.claim.sub','72000000-0000-0000-0000-000000000001',true);
  perform pg_temp.assert_true(
    public.process_catalog_verification_result(verifier_result_id) = 'promoted',
    'Team Color reliability observations require the protected independent-verification finalization path'
  );

  perform pg_temp.assert_true(not exists (
    select 1
    from public.catalog_verification_decisions decision,
         jsonb_array_elements(decision.evidence_snapshot) entry
    where decision.proposal_id = proposal
      and (not entry ? 'trust_tier_version_id'
        or not entry ? 'applicability_version_id')
  ),'verification evidence must snapshot tier and applicability versions independently');

  perform pg_temp.assert_true((
    select count(distinct (entry ->> 'independence_group_id')) = 5
    from public.catalog_verification_decisions decision,
         jsonb_array_elements(decision.evidence_snapshot) entry
    where decision.proposal_id = proposal
  ),'multiple URLs from one publisher must retain one independence group');
  perform pg_temp.assert_true((
    select count(*) = 2 and bool_and(independent_corroborating_group_count > 0)
    from public.team_color_source_reliability_observations observation
    join public.trusted_sources source on source.id = observation.source_id
    where source.source_id = 'publisher-test-global' and outcome = 'match'
  ),'same-publisher URLs may create observations but only with outside-group corroboration');
  perform pg_temp.assert_true((
    select count(*) = 1 from public.team_color_source_reliability_observations observation
    join public.trusted_sources source on source.id = observation.source_id
    where source.source_id = 'publisher-test-conflict' and outcome = 'contradiction'
      and independent_corroborating_group_count >= 2
  ),'contradiction requires independent final-palette corroboration');
  perform pg_temp.assert_true((
    select count(*) = 1 from public.team_color_source_reliability_observations observation
    join public.trusted_sources source on source.id = observation.source_id
    where source.source_id = 'publisher-test-special' and outcome = 'not_assessable'
  ),'historical/alternate/special claims must not become reliability matches');
  perform pg_temp.assert_true(not exists (
    select 1 from public.team_color_source_reliability_observations
    where outcome in ('match','contradiction')
      and independent_corroborating_group_count = 0
  ),'circular reliability credit must be impossible');
end;
$$;

-- Rejected verification is retained as unresolved, not a contradiction.
select set_config('request.jwt.claim.sub','72000000-0000-0000-0000-000000000001',true);
select public.enqueue_team_color_work('hockey-999982',400,null,'Rejected reliability outcome.',now());
do $$
declare claim jsonb; work_id uuid; lease uuid; proposal uuid;
begin
  perform set_config('request.jwt.claim.sub','72000000-0000-0000-0000-000000000002',true);
  claim := public.claim_next_team_color_work(900);
  work_id := (claim #>> '{work,work_item_id}')::uuid;
  lease := (claim #>> '{work,lease_token}')::uuid;
  proposal := public.submit_team_color_proposal(
    work_id,lease,jsonb_build_object('primary','#778899','secondary','#AABBCC'),
    'Rejected outcome fixture.'
  );
  perform public.add_team_color_proposal_evidence(
    proposal,'publisher-test-other-team','https://other-team.example/colors','Single unconfirmed claim.',now(),true,
    jsonb_build_object('classification','current_canonical','palette',jsonb_build_array('#778899','#AABBCC'))
  );
  update public.catalog_proposal_evidence evidence
  set information_lineage_version_id = lineage_version.id,
      information_lineage_basis = 'Transactional source-specific lineage fixture.'
  from public.trusted_sources source
  join public.information_lineages lineage
    on lineage.lineage_key = 'lineage-' || source.source_id
  join public.information_lineage_versions lineage_version
    on lineage_version.lineage_id = lineage.id and lineage_version.is_current
  where evidence.proposal_id = proposal and evidence.source_id = source.id;
  perform public.finish_team_color_work(work_id,lease,'submitted_for_verification',null,null,null,'{}');
  perform set_config('request.jwt.claim.sub','72000000-0000-0000-0000-000000000003',true);
  perform public.review_catalog_proposal_pre_independent_verification(
    proposal,'rejected','Insufficient corroboration.'
  );
  perform pg_temp.assert_true((
    select count(*) = 1 and bool_and(outcome = 'unresolved')
    from public.team_color_source_reliability_observations where proposal_id = proposal
  ),'rejection must produce unresolved rather than contradiction');
end;
$$;

-- Versioning, controlled redirects, history preservation, sample-size readout,
-- broad-upsert restriction, and direct-write denial.
do $$
declare
  evidence_count integer;
  observation_count integer;
  denied boolean;
begin
  perform set_config('request.jwt.claim.sub','72000000-0000-0000-0000-000000000001',true);
  perform public.review_trusted_source(
    'publisher-test-global','publisher-test-global-owner','approved',
    'Exercise versioned ownership reassessment.'
  );
  perform pg_temp.assert_true((
    select count(*) = 2 and count(*) filter (where is_current) = 1
    from public.source_independence_group_assignment_versions assignment
    join public.trusted_sources source on source.id = assignment.source_id
    where source.source_id = 'publisher-test-global'
  ),'independence reassessment must retain exactly one historical and one current version');

  select count(*) into evidence_count from public.catalog_proposal_evidence evidence
  join public.trusted_sources source on source.id = evidence.source_id
  where source.source_id = 'publisher-test-global';
  select count(*) into observation_count from public.team_color_source_reliability_observations observation
  join public.trusted_sources source on source.id = observation.source_id
  where source.source_id = 'publisher-test-global';
  perform public.redirect_trusted_source(
    'publisher-test-global','publisher-test-global-canonical',
    'Transactional equivalent-publisher redirect.'
  );
  perform pg_temp.assert_true((
    select count(*) = evidence_count from public.catalog_proposal_evidence evidence
    join public.trusted_sources source on source.id = evidence.source_id
    where source.source_id = 'publisher-test-global'
  ),'redirect must not rewrite historical evidence source foreign keys');
  perform pg_temp.assert_true((
    select count(*) = observation_count from public.team_color_source_reliability_observations observation
    join public.trusted_sources source on source.id = observation.source_id
    where source.source_id = 'publisher-test-global'
  ),'redirect must not rewrite append-only reliability observations');
  perform pg_temp.assert_true((
    select matches = 2 and assessed_sample_size = 2
      and raw_match_rate = 1 and conservative_match_rate < raw_match_rate
      and team_breadth = 1 and most_recent_outcome_at is not null
    from public.team_color_source_reliability_read_model
    where source_id = 'publisher-test-global-canonical'
  ),'aggregate must preserve redirected history and expose sample-size-aware conservative reliability');
  perform pg_temp.assert_true((
    public.resolve_trusted_source_url('https://publisher.example/after-redirect')
      #>> '{matches,0,source_id}' = 'publisher-test-global-canonical'
  ),'redirected URL scopes must resolve to the canonical publisher');

  denied := false;
  begin
    perform public.admin_upsert_trusted_source(
      'publisher-test-team','Overwrite Attempt','https://overwrite.example',
      'https://overwrite.example/reference',null,'pending_review',null,'{}'
    );
  exception when others then denied := true; end;
  perform pg_temp.assert_true(denied,'broad admin upsert must not overwrite an existing publisher');
  perform pg_temp.assert_true(not has_table_privilege(
    'authenticated','public.trusted_source_url_scope_versions','INSERT'
  ),'authenticated users must not directly insert URL governance');
  perform pg_temp.assert_true(not has_table_privilege(
    'authenticated','public.team_color_source_reliability_observations','INSERT'
  ),'authenticated users must not directly insert empirical reliability');
  perform pg_temp.assert_true(not has_table_privilege(
    'authenticated','public.source_applicability_versions','INSERT'
  ),'authenticated users must not directly insert source applicability');
  perform pg_temp.assert_true(not has_function_privilege(
    'authenticated',
    'public.add_catalog_proposal_evidence_governed(uuid,text,text,text,timestamptz,boolean,jsonb)',
    'EXECUTE'
  ),'internal evidence writer must not be callable directly');
  perform pg_temp.assert_true(exists (
    select 1 from public.trusted_source_duplicate_candidates_read_model
    where reason = 'url_scope_overlap'
      and left_source_id in ('publisher-test-ambiguous-a','publisher-test-ambiguous-b')
      and right_source_id in ('publisher-test-ambiguous-a','publisher-test-ambiguous-b')
  ),'reviewer duplicate detector must surface ambiguous overlapping publisher scopes');
  perform pg_temp.assert_true(exists (
    select 1 from public.catalog_verification_decisions
    where evidence_snapshot::text like '%brand-color-code-edmonton-oilers%'
      and evidence_snapshot::text like '%edmonton-oilers-brand-book%'
  ),'historical Edmonton verification snapshot must remain unchanged');
  perform pg_temp.assert_true(exists (
    select 1 from public.catalog_proposal_evidence evidence
    join public.trusted_sources source on source.id = evidence.source_id
    where source.source_id in ('brand-color-code-edmonton-oilers','edmonton-oilers-brand-book')
  ),'historical Edmonton evidence must retain its original source records');
end;
$$;

rollback;
