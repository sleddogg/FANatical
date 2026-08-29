-- Transactional proof for FANatical News Phase 2 identities, Resolution,
-- history, and real-role Admin access. Every fixture is synthetic and rolls
-- back at the end.

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
    raise exception 'News identity foundation assertion failed: %', message_value;
  end if;
end;
$$;

create or replace function pg_temp.assert_statement_rejected(
  statement_value text,
  expected_message_fragment text,
  message_value text
)
returns void
language plpgsql
as $$
begin
  begin
    execute statement_value;
  exception when others then
    if expected_message_fragment = ''
       or position(lower(expected_message_fragment) in lower(sqlerrm)) > 0 then
      return;
    end if;
    raise exception 'News identity foundation assertion failed: % (unexpected error: %)',
      message_value, sqlerrm;
  end;
  raise exception 'News identity foundation assertion failed: % (statement unexpectedly succeeded)',
    message_value;
end;
$$;

create temporary table phase2_ids (
  key text primary key,
  value uuid not null
);
grant select, insert, update, delete on pg_temp.phase2_ids to authenticated;

create or replace function pg_temp.remember(key_value text, id_value uuid)
returns uuid
language plpgsql
as $$
begin
  insert into pg_temp.phase2_ids(key, value) values (key_value, id_value);
  return id_value;
end;
$$;

create or replace function pg_temp.id(key_value text)
returns uuid
language sql
stable
as $$
  select value from pg_temp.phase2_ids where key = key_value;
$$;

-- Synthetic staff and ordinary fan identities. Auth profile bootstrap is also
-- used to prove that fan-handle text and professional-name text are separate.
insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '86000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'phase2-admin@fanatical.invalid', '', now(),
    '{}'::jsonb, '{"display_name":"Phase 2 Admin"}'::jsonb, now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '86000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'phase2-fan@fanatical.invalid', '', now(),
    '{}'::jsonb, '{"display_name":"Phase 2 Fan"}'::jsonb, now(), now()
  );

insert into public.staff_roles(user_id, role, permissions, is_active)
values ('86000000-0000-0000-0000-000000000001', 'content_admin', array[]::text[], true);

insert into public.catalog_actors(
  id, actor_key, actor_type, auth_user_id, display_name, active
)
values
  (
    '86010000-0000-0000-0000-000000000001',
    'phase2-identity-admin', 'human',
    '86000000-0000-0000-0000-000000000001',
    'Phase 2 Identity Admin', true
  ),
  (
    '86010000-0000-0000-0000-000000000002',
    'phase2-governed-automation', 'service', null,
    'Phase 2 Governed Automation', true
  );

update public.profiles
set handle = 'AlexRivers'
where user_id = '86000000-0000-0000-0000-000000000002';

insert into public.trusted_sources(
  id, source_id, display_name, base_url, review_status
)
values
  ('86100000-0000-0000-0000-000000000001', 'phase2-publisher-a', 'Phase 2 Publisher A', 'https://publisher-a.example', 'approved'),
  ('86100000-0000-0000-0000-000000000002', 'phase2-publisher-b', 'Phase 2 Publisher B', 'https://publisher-b.example', 'approved'),
  ('86100000-0000-0000-0000-000000000003', 'phase2-network', 'Phase 2 Podcast Network', 'https://network.example', 'pending_review'),
  ('86100000-0000-0000-0000-000000000004', 'phase2-ambiguous-a', 'Phase 2 Ambiguous Owner A', 'https://ambiguous-evidence.example', 'approved'),
  ('86100000-0000-0000-0000-000000000005', 'phase2-ambiguous-b', 'Phase 2 Ambiguous Owner B', 'https://ambiguous-evidence.example', 'approved'),
  ('86100000-0000-0000-0000-000000000006', 'phase2-broad-nhl-analogue', 'Phase 2 Broad NHL Analogue', 'https://phase2-overlap.example', 'approved'),
  ('86100000-0000-0000-0000-000000000007', 'phase2-narrow-oilers-analogue', 'Phase 2 Narrow Oilers Analogue', 'https://phase2-overlap.example/oilers', 'approved');

insert into public.trusted_source_url_scope_versions(
  id, source_id, hostname, include_subdomains, path_prefix,
  path_match, scope_kind, review_status
)
values
  ('86110000-0000-0000-0000-000000000001', '86100000-0000-0000-0000-000000000001', 'publisher-a.example', false, '/', 'prefix', 'publisher', 'approved'),
  ('86110000-0000-0000-0000-000000000002', '86100000-0000-0000-0000-000000000002', 'publisher-b.example', false, '/', 'prefix', 'publisher', 'approved'),
  ('86110000-0000-0000-0000-000000000003', '86100000-0000-0000-0000-000000000003', 'network.example', false, '/', 'prefix', 'publisher', 'approved'),
  ('86110000-0000-0000-0000-000000000004', '86100000-0000-0000-0000-000000000004', 'ambiguous-evidence.example', false, '/', 'prefix', 'publisher', 'approved'),
  ('86110000-0000-0000-0000-000000000005', '86100000-0000-0000-0000-000000000005', 'ambiguous-evidence.example', false, '/', 'prefix', 'publisher', 'approved'),
  ('86110000-0000-0000-0000-000000000006', '86100000-0000-0000-0000-000000000006', 'phase2-overlap.example', false, '/', 'prefix', 'publisher', 'approved'),
  ('86110000-0000-0000-0000-000000000007', '86100000-0000-0000-0000-000000000007', 'phase2-overlap.example', false, '/oilers', 'prefix', 'path_owner', 'approved');

select pg_temp.assert_true(
  (
    with matches as (
      select *
      from public.trusted_source_url_matches(
        'https://phase2-overlap.example/oilers/news/example-story'
      )
    ), top_match as (
      select * from matches
      where specificity = (select max(specificity) from matches)
    )
    select count(distinct canonical_source_id) = 1
      and min(canonical_source_id::text)::uuid =
        '86100000-0000-0000-0000-000000000007'::uuid
    from top_match
  ),
  'a more-specific /oilers publisher path must win over the broader host root without ambiguity'
);

insert into public.source_trust_assignments(
  source_id, data_type, trust_tier, is_current
)
values ('86100000-0000-0000-0000-000000000001', 'phase2-proof', 1, true);

-- Two people may share the exact public name, and the same text may also be a
-- fan handle without namespace collision.
insert into public.catalog_people(id, person_id)
values
  ('86200000-0000-0000-0000-000000000001', 'person-00000000000000000000000000000001'),
  ('86200000-0000-0000-0000-000000000002', 'person-00000000000000000000000000000002'),
  ('86200000-0000-0000-0000-000000000003', 'person-00000000000000000000000000000003'),
  ('86200000-0000-0000-0000-000000000004', 'person-00000000000000000000000000000004'),
  ('86200000-0000-0000-0000-000000000005', 'person-00000000000000000000000000000005'),
  ('86200000-0000-0000-0000-000000000006', 'person-00000000000000000000000000000006'),
  ('86200000-0000-0000-0000-000000000007', 'person-00000000000000000000000000000007'),
  ('86200000-0000-0000-0000-000000000008', 'person-00000000000000000000000000000008');

insert into public.person_identity_versions(person_id, public_name, name_kind)
values
  ('86200000-0000-0000-0000-000000000001', 'Alex Rivers', 'professional_name'),
  ('86200000-0000-0000-0000-000000000002', 'Alex Rivers', 'professional_name'),
  ('86200000-0000-0000-0000-000000000003', 'Jordan North', 'pen_name'),
  ('86200000-0000-0000-0000-000000000004', 'Jordan North', 'professional_name'),
  ('86200000-0000-0000-0000-000000000005', 'Morgan Lane', 'professional_name'),
  ('86200000-0000-0000-0000-000000000006', 'Morgan Lane', 'professional_name'),
  ('86200000-0000-0000-0000-000000000007', 'Casey Bridge', 'professional_name'),
  ('86200000-0000-0000-0000-000000000008', 'Casey Bridge', 'professional_name');

insert into public.news_author_profiles(person_id)
select id from public.catalog_people;

insert into public.catalog_people(id, person_id)
values (
  '86200000-0000-0000-0000-000000000009',
  'person-00000000000000000000000000000009'
);
select pg_temp.assert_statement_rejected(
  $statement$
    delete from public.catalog_people
    where id = '86200000-0000-0000-0000-000000000009'
  $statement$,
  'persistent news identities cannot be deleted',
  'a persistent person identity must not be destructively removed'
);

select pg_temp.assert_true(
  (
    select count(*) = 2
    from public.person_identity_versions
    where normalized_name = 'alex rivers' and is_current
  ),
  'two different people with the same public name must remain distinct'
);
select pg_temp.assert_true(
  (
    select profile.handle = 'AlexRivers'
    from public.profiles profile
    where profile.user_id = '86000000-0000-0000-0000-000000000002'
  ),
  'a fan handle may use the same text as a professional name without collision'
);
select pg_temp.assert_true(
  (
    select identity.name_kind = 'pen_name'
    from public.person_identity_versions identity
    where identity.person_id = '86200000-0000-0000-0000-000000000003'
      and identity.is_current
  ),
  'a public pen name must be a valid professional identity without a legal name'
);

-- Historical affiliation remains after the person moves publishers. Unknown
-- is governed and valid; employment is never inferred.
insert into public.news_person_publisher_relationship_versions(
  id, person_id, publisher_source_id, relationship_type,
  effective_from, effective_to, is_current
)
values
  (
    '86900000-0000-0000-0000-000000000001',
    '86200000-0000-0000-0000-000000000001',
    '86100000-0000-0000-0000-000000000001',
    'unknown', '2020-01-01', '2022-07-01', false
  ),
  (
    '86900000-0000-0000-0000-000000000002',
    '86200000-0000-0000-0000-000000000001',
    '86100000-0000-0000-0000-000000000002',
    'freelance', '2022-07-01', null, true
  ),
  (
    '86900000-0000-0000-0000-000000000003',
    '86200000-0000-0000-0000-000000000004',
    '86100000-0000-0000-0000-000000000002',
    'contributor', '2021-01-01', null, true
  ),
  (
    '86900000-0000-0000-0000-000000000004',
    '86200000-0000-0000-0000-000000000005',
    '86100000-0000-0000-0000-000000000002',
    'contract', '2018-01-01', '2020-06-30', true
  ),
  (
    '86900000-0000-0000-0000-000000000005',
    '86200000-0000-0000-0000-000000000006',
    '86100000-0000-0000-0000-000000000002',
    'contributor', '2022-01-01', null, true
  ),
  (
    '86900000-0000-0000-0000-000000000006',
    '86200000-0000-0000-0000-000000000007',
    '86100000-0000-0000-0000-000000000001',
    'contributor', '2019-01-01', null, true
  ),
  (
    '86900000-0000-0000-0000-000000000007',
    '86200000-0000-0000-0000-000000000008',
    '86100000-0000-0000-0000-000000000002',
    'contributor', '2023-01-01', null, true
  );

select pg_temp.assert_true(
  (
    select count(*) = 2
      and count(*) filter (where is_current) = 1
      and count(*) filter (where relationship_type = 'unknown') = 1
    from public.news_person_publisher_relationship_versions
    where person_id = '86200000-0000-0000-0000-000000000001'
  ),
  'historical affiliation and its non-employment relationship type must survive a publisher move'
);

-- Organizational contributor identity is separate from people and a
-- publisher profile can resolve to exactly one human or organization, never
-- both and never a fabricated human conversion.
insert into public.news_organizational_contributors(id, contributor_id)
values (
  '86300000-0000-0000-0000-000000000001',
  'organization-00000000000000000000000000000001'
);
insert into public.news_organizational_contributor_versions(
  organizational_contributor_id, display_name
)
values ('86300000-0000-0000-0000-000000000001', 'Phase 2 Staff');

-- Publisher contributor-profile identities are now created through the same
-- staff intake path a real operator can use. The resulting cases are reused
-- by the Resolution scenarios below rather than hidden behind table inserts.
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('case_profile_1', public.admin_open_news_identity_case(
  'publisher_profile', 'organization', 'Phase 2 Staff',
  '86100000-0000-0000-0000-000000000001',
  null, null, null, null, 'Phase 2 Staff',
  'https://publisher-a.example/staff',
  'Which organizational identity owns this publisher contributor profile?',
  '{}'::jsonb, 'Synthetic governed publisher-profile intake.'
));
select pg_temp.remember('profile_1',
  public.admin_create_news_publisher_contributor_profile(
    pg_temp.id('case_profile_1'), 'Create the unresolved publisher profile.'
  )
);
select pg_temp.remember('candidate_profile_1',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_profile_1'), 'existing_identity', 'organization',
    '86300000-0000-0000-0000-000000000001', 'Phase 2 Staff',
    '{}'::jsonb, 'Record the established organizational candidate.'
  )
);
select pg_temp.remember('evidence_profile_1',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_profile_1'), pg_temp.id('candidate_profile_1'),
    'official_organizational_profile',
    '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/staff', null, null,
    'public_profile', false,
    'The publisher-owned staff page establishes the organizational profile.',
    '{}'::jsonb, '2026-08-29T09:00:00Z',
    'Synthetic governed public evidence.'
  )
);

select pg_temp.remember('case_profile_2', public.admin_open_news_identity_case(
  'publisher_profile', 'human', 'Alex Rivers',
  '86100000-0000-0000-0000-000000000001',
  null, null, null, null, 'By Alex Rivers',
  'https://publisher-a.example/authors/alex-rivers-two',
  'Which existing person owns this publisher contributor profile?',
  '{}'::jsonb, 'Synthetic governed publisher-profile intake.'
));
select pg_temp.remember('profile_2',
  public.admin_create_news_publisher_contributor_profile(
    pg_temp.id('case_profile_2'), 'Create the unresolved publisher profile.'
  )
);
select pg_temp.remember('case_profile_3', public.admin_open_news_identity_case(
  'publisher_profile', 'human', 'Morgan Lane',
  '86100000-0000-0000-0000-000000000001',
  null, null, null, null, 'Morgan Lane',
  'https://publisher-a.example/authors/morgan-lane',
  'Does this Publisher A profile belong to the person established at Publisher B?',
  '{}'::jsonb, 'Synthetic governed cross-publisher profile intake.'
));
select pg_temp.remember('profile_3',
  public.admin_create_news_publisher_contributor_profile(
    pg_temp.id('case_profile_3'), 'Create the unresolved publisher profile.'
  )
);
select pg_temp.remember('case_profile_4', public.admin_open_news_identity_case(
  'publisher_profile', 'human', 'Morgan Lane',
  '86100000-0000-0000-0000-000000000001',
  null, null, null, null, 'Morgan Lane',
  'https://publisher-a.example/authors/morgan-lane-moved',
  'Does first-party evidence bridge this Publisher A profile to the Publisher B person?',
  '{}'::jsonb, 'Synthetic governed cross-publisher profile intake.'
));
select pg_temp.remember('profile_4',
  public.admin_create_news_publisher_contributor_profile(
    pg_temp.id('case_profile_4'), 'Create the unresolved publisher profile.'
  )
);
select pg_temp.remember('case_profile_5', public.admin_open_news_identity_case(
  'publisher_profile', 'human', 'Casey Bridge',
  '86100000-0000-0000-0000-000000000001',
  null, null, null, null, 'Casey Bridge',
  'https://publisher-a.example/authors/casey-bridge',
  'Does conflicting bridge evidence permit this cross-publisher link?',
  '{}'::jsonb, 'Synthetic governed cross-publisher profile intake.'
));
select pg_temp.remember('profile_5',
  public.admin_create_news_publisher_contributor_profile(
    pg_temp.id('case_profile_5'), 'Create the unresolved publisher profile.'
  )
);
reset role;

insert into public.news_publisher_contributor_profile_versions(
  id, contributor_profile_id, display_name, profile_url,
  person_id, organizational_contributor_id,
  effective_from, effective_to
)
values
  (
    '86510000-0000-0000-0000-000000000002',
    pg_temp.id('profile_2'),
    'Alex Rivers', 'https://publisher-a.example/authors/alex-rivers-two',
    '86200000-0000-0000-0000-000000000001', null,
    '2019-02-01', '2020-11-30'
  );

select pg_temp.assert_true(
  (
    select count(*) = 5
      and bool_and(decision.action = 'create_publisher_contributor_profile')
      and bool_and(decision.decision_origin = 'staff')
      and bool_and(decision.automatic_rule_key is null)
      and bool_and(
        decision.decided_by_user_id = '86000000-0000-0000-0000-000000000001'
      )
      and bool_and(
        decision.decided_by_actor_id = '86010000-0000-0000-0000-000000000001'
      )
    from public.news_publisher_contributor_profiles profile
    join public.news_identity_resolution_decisions decision
      on decision.id = profile.created_by_decision_id
    where profile.id in (
      pg_temp.id('profile_1'), pg_temp.id('profile_2'),
      pg_temp.id('profile_3'), pg_temp.id('profile_4'),
      pg_temp.id('profile_5')
    )
  ) and exists (
    select 1
    from public.news_publisher_contributor_profile_versions version
    where version.contributor_profile_id = pg_temp.id('profile_1')
      and version.organizational_contributor_id =
        '86300000-0000-0000-0000-000000000001'
      and version.is_current
      and version.resolution_decision_id is not null
  ),
  'staff intake must create publisher profiles with provenance and let governed evidence resolve an organizational profile'
);

select pg_temp.assert_statement_rejected(
  $statement$
    insert into public.news_publisher_contributor_profile_versions(
      contributor_profile_id, display_name, person_id,
      organizational_contributor_id
    ) values (
      pg_temp.id('profile_2'), 'Invalid Hybrid',
      '86200000-0000-0000-0000-000000000001',
      '86300000-0000-0000-0000-000000000001'
    )
  $statement$,
  'check constraint',
  'an organizational contributor profile must not also become a human profile'
);
select pg_temp.assert_true(
  not exists (
    select 1 from public.catalog_people
    where id = '86300000-0000-0000-0000-000000000001'
  ),
  'an organizational contributor must not be stored as a person'
);

-- One Show survives both host and network changes.
insert into public.podcast_shows(id, show_id)
values (
  '86400000-0000-0000-0000-000000000001',
  'show-00000000000000000000000000000001'
);
insert into public.podcast_show_identity_versions(show_id, display_name)
values ('86400000-0000-0000-0000-000000000001', 'The Phase 2 Show');
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('case_existing_show_contributors',
  public.admin_open_news_identity_case(
    'show_contributor', 'show', 'The Phase 2 Show',
    '86100000-0000-0000-0000-000000000003',
    null, null, '86400000-0000-0000-0000-000000000001', null,
    null, 'https://network.example/shows/phase-2-show',
    'Who hosted this existing Show during each factual period?',
    '{}'::jsonb, 'Synthetic governed existing-Show contributor intake.'
  )
);
select pg_temp.remember('case_existing_show_publishers',
  public.admin_open_news_identity_case(
    'show_publisher', 'show', 'The Phase 2 Show', null,
    null, null, '86400000-0000-0000-0000-000000000001', null,
    null, 'https://network.example/shows/phase-2-show',
    'Which networks carried this existing Show during each factual period?',
    '{}'::jsonb, 'Synthetic governed existing-Show publisher intake.'
  )
);
select public.admin_record_podcast_show_contributor(
  pg_temp.id('case_existing_show_contributors'),
  '86200000-0000-0000-0000-000000000005', 'host',
  '2021-01-01T00:00:00Z', '2023-01-01T00:00:00Z', null,
  'Establish the former host factual period.'
);
select public.admin_record_podcast_show_contributor(
  pg_temp.id('case_existing_show_contributors'),
  '86200000-0000-0000-0000-000000000006', 'host',
  '2023-01-01T00:00:00Z', null, null,
  'Establish the current host factual period.'
);
select public.admin_record_podcast_show_publisher(
  pg_temp.id('case_existing_show_publishers'),
  '86100000-0000-0000-0000-000000000001', 'network',
  '2021-01-01T00:00:00Z', '2024-01-01T00:00:00Z', null,
  'Establish the former network factual period.'
);
select public.admin_record_podcast_show_publisher(
  pg_temp.id('case_existing_show_publishers'),
  '86100000-0000-0000-0000-000000000003', 'network',
  '2024-01-01T00:00:00Z', null, null,
  'Establish the current network factual period.'
);
reset role;

select pg_temp.assert_true(
  (
    select show.show_id = 'show-00000000000000000000000000000001'
      and (select count(*) from public.podcast_show_contributor_versions contributor where contributor.show_id = show.id) = 2
      and (select count(*) from public.podcast_show_contributor_versions contributor where contributor.show_id = show.id and contributor.resolution_decision_id is not null) = 2
      and (select count(*) from public.podcast_show_publisher_relationship_versions publisher where publisher.show_id = show.id) = 2
      and (select count(*) from public.podcast_show_publisher_relationship_versions publisher where publisher.show_id = show.id and publisher.resolution_decision_id is not null) = 2
    from public.podcast_shows show
    where show.id = '86400000-0000-0000-0000-000000000001'
  ),
  'Show identity must survive host and network changes with history retained'
);

-- Name alone produces review and an explicit point-in-time ambiguity record.
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('case_name_only', public.admin_open_news_identity_case(
  'person_merge', 'human', 'Alex Rivers', null,
  '86200000-0000-0000-0000-000000000001', null, null, null,
  null, null, 'Are these two same-name people actually one person?',
  '{}'::jsonb, 'Synthetic governed same-name review intake.'
));
select pg_temp.remember('candidate_name_only',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_name_only'), 'merge_target', 'human',
    '86200000-0000-0000-0000-000000000002', 'Alex Rivers',
    '{}'::jsonb, 'Record the possible same-name merge target.'
  )
);
reset role;

select pg_temp.assert_true(
  (
    select status = 'needs_review'
      and resolution_stop_reason = 'missing_identity_bridge'
    from public.news_identity_resolution_cases
    where id = pg_temp.id('case_name_only')
  ),
  'name-only same-person Resolution must stop rather than guess'
);
select pg_temp.assert_true(
  exists (
    select 1 from public.news_person_pair_state_periods
    where person_a_id in (
        '86200000-0000-0000-0000-000000000001',
        '86200000-0000-0000-0000-000000000002'
      )
      and person_b_id in (
        '86200000-0000-0000-0000-000000000001',
        '86200000-0000-0000-0000-000000000002'
      )
      and state = 'ambiguous' and is_current
  ),
  'same-name ambiguity must be recorded as a durable person-pair period'
);

select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select public.admin_review_news_identity_case(
  pg_temp.id('case_name_only'),
  'keep_separate',
  '86200000-0000-0000-0000-000000000002',
  '{"identity_type":"human"}'::jsonb,
  'The matching public names refer to two different professional identities.'
);
reset role;

select pg_temp.assert_true(
  exists (
    select 1
    from public.news_person_pair_state_periods period
    where period.person_a_id in (
        '86200000-0000-0000-0000-000000000001',
        '86200000-0000-0000-0000-000000000002'
      )
      and period.person_b_id in (
        '86200000-0000-0000-0000-000000000001',
        '86200000-0000-0000-0000-000000000002'
      )
      and period.state = 'distinct'
      and period.is_current
  ),
  'authorized review must be able to record that same-name people stay separate'
);

select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_review_news_identity_case(
      pg_temp.id('case_name_only'),
      'correct_affiliation',
      '86200000-0000-0000-0000-000000000002',
      '{"publisher_source_id":"86100000-0000-0000-0000-000000000002","relationship_type":"unknown","relationship_id":"86900000-0000-0000-0000-000000000001"}'::jsonb,
      'Synthetic wrong-person correction attempt.'
    )
  $statement$,
  'for this person',
  'an affiliation correction must not close another person''s relationship'
);
reset role;

-- Clean explicit public evidence resolves an existing candidate automatically.
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('case_explicit_link', public.admin_open_news_identity_case(
  'identity', 'human', 'Jordan North',
  '86100000-0000-0000-0000-000000000001',
  null, null, null, null, null,
  'https://publisher-a.example/authors/jordan-north',
  'Which persistent person owns this public Author profile?',
  '{}'::jsonb, 'Synthetic governed explicit-link intake.'
));
select pg_temp.remember('candidate_explicit_link',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_explicit_link'), 'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000003', 'Jordan North',
    '{}'::jsonb, 'Record the existing professional identity candidate.'
  )
);
select pg_temp.remember('evidence_explicit_link',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_explicit_link'), pg_temp.id('candidate_explicit_link'),
    'publisher_author_profile',
    '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/authors/jordan-north', null, null,
    'public_profile', false,
    'The publisher profile explicitly identifies this professional person.',
    '{}'::jsonb, '2026-08-29T09:01:00Z',
    'Synthetic governed explicit public evidence.'
  )
);
reset role;

select pg_temp.assert_true(
  (
    select status = 'resolved_automatic'
      and automatic_resolution_result = 'automatic_link'
    from public.news_identity_resolution_cases
    where id = pg_temp.id('case_explicit_link')
  ),
  'clean public explicit evidence must resolve automatically'
);
select pg_temp.assert_true(
  exists (
    select 1
    from public.news_identity_resolution_decisions decision
    join public.news_identity_decision_evidence snapshot
      on snapshot.decision_id = decision.id
    where decision.case_id = pg_temp.id('case_explicit_link')
      and decision.action = 'automatic_link'
      and decision.automatic_rule_key = 'explicit_public_non_conflicting'
      and snapshot.evidence_id = pg_temp.id('evidence_explicit_link')
  ),
  'automatic Resolution must retain its rule and evidence provenance'
);
select pg_temp.assert_true(
  (
    select evidence.source_url_scope_version_id =
      '86110000-0000-0000-0000-000000000001'::uuid
    from public.news_identity_resolution_evidence evidence
    where evidence.id = pg_temp.id('evidence_explicit_link')
  ),
  'owned first-party evidence must retain the exact trusted URL-scope provenance used to resolve it'
);

select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_record_news_identity_evidence(
      pg_temp.id('case_explicit_link'), pg_temp.id('candidate_explicit_link'),
      'official_show_profile', null,
      'https://publisher-a.example/not-a-show', null, null,
      'public_profile', false,
      'This governed Show evidence kind cannot establish a human candidate.',
      '{}'::jsonb, null, null
    )
  $statement$,
  'does not apply',
  'a governed evidence kind must apply to its candidate or Resolution case subject'
);
reset role;

-- Claimed first-party evidence cannot bypass canonical URL ownership,
-- redirects, or ambiguity-safe publisher Resolution.
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('case_url_ownership', public.admin_open_news_identity_case(
  'identity', 'human', 'URL Ownership Candidate',
  '86100000-0000-0000-0000-000000000001',
  null, null, null, null, null, null,
  'Does publisher-owned public evidence establish this candidate?',
  '{}'::jsonb, 'Synthetic governed URL-ownership intake.'
));
select pg_temp.remember('candidate_url_ownership',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_url_ownership'), 'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000003',
    'URL Ownership Candidate', '{}'::jsonb,
    'Record the identity candidate for URL ownership checks.'
  )
);

select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_record_news_identity_evidence(
      pg_temp.id('case_url_ownership'), pg_temp.id('candidate_url_ownership'),
      'publisher_author_profile',
      '86100000-0000-0000-0000-000000000001',
      'https://publisher-b.example/authors/url-owner', null, null,
      'public_profile', false, 'The URL belongs to a different publisher.',
      '{}'::jsonb, null, null
    )
  $statement$,
  'does not belong to the claimed publisher',
  'a mismatched publisher URL cannot become explicit Resolution evidence'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_record_news_identity_evidence(
      pg_temp.id('case_url_ownership'), pg_temp.id('candidate_url_ownership'),
      'publisher_author_profile',
      '86100000-0000-0000-0000-000000000002',
      'https://publisher-b.example/authors/url-owner', null, null,
      'public_profile', false,
      'The URL and evidence row claim Publisher B inside a Publisher A case.',
      '{}'::jsonb, null, null
    )
  $statement$,
  'does not match the Resolution case publisher',
  'ordinary first-party evidence from another publisher cannot drive this publisher case'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_record_news_identity_evidence(
      pg_temp.id('case_url_ownership'), pg_temp.id('candidate_url_ownership'),
      'publisher_author_profile',
      '86100000-0000-0000-0000-000000000001',
      'https://unowned-evidence.example/authors/url-owner', null, null,
      'public_profile', false, 'No trusted publisher owns this URL.',
      '{}'::jsonb, null, null
    )
  $statement$,
  'is not owned by a trusted publisher',
  'an unowned URL cannot become explicit Resolution evidence'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_record_news_identity_evidence(
      pg_temp.id('case_url_ownership'), pg_temp.id('candidate_url_ownership'),
      'publisher_author_profile',
      '86100000-0000-0000-0000-000000000001',
      'https://ambiguous-evidence.example/authors/url-owner', null, null,
      'public_profile', false, 'Two equally specific publishers claim this URL.',
      '{}'::jsonb, null, null
    )
  $statement$,
  'ambiguous trusted publisher ownership',
  'an ambiguous URL cannot become explicit Resolution evidence'
);
select pg_temp.assert_true(
  (
    select status = 'needs_review'
      and automatic_resolution_result = 'review_required'
    from public.news_identity_resolution_cases
    where id = pg_temp.id('case_url_ownership')
  ) and not exists (
    select 1
    from public.news_identity_resolution_evidence
    where case_id = pg_temp.id('case_url_ownership')
  ),
  'mismatched, unowned, and ambiguous URLs must leave the identity unresolved for review'
);
reset role;

-- Supporting evidence alone cannot merge people.
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('case_supporting_only', public.admin_open_news_identity_case(
  'person_merge', 'human', 'Jordan North', null,
  '86200000-0000-0000-0000-000000000003', null, null, null,
  null, null, 'Does matching name text prove these are one person?',
  '{}'::jsonb, 'Synthetic governed supporting-evidence intake.'
));
select pg_temp.remember('candidate_supporting_only',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_supporting_only'), 'merge_target', 'human',
    '86200000-0000-0000-0000-000000000004', 'Jordan North',
    '{}'::jsonb, 'Record the possible merge target.'
  )
);
select pg_temp.remember('evidence_supporting_only',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_supporting_only'), pg_temp.id('candidate_supporting_only'),
    'name_match', null, null, null, null, 'visible_public', false,
    'The public name text matches.', '{}'::jsonb,
    '2026-08-29T09:02:00Z', 'Synthetic governed supporting evidence.'
  )
);
reset role;

select pg_temp.assert_true(
  (
    select status = 'needs_review'
      and resolution_stop_reason = 'missing_identity_bridge'
    from public.news_identity_resolution_cases
    where id = pg_temp.id('case_supporting_only')
  ) and not exists (
    select 1 from public.news_person_pair_state_periods
    where state = 'merged' and is_current
      and person_a_id in (
        '86200000-0000-0000-0000-000000000003',
        '86200000-0000-0000-0000-000000000004'
      )
      and person_b_id in (
        '86200000-0000-0000-0000-000000000003',
        '86200000-0000-0000-0000-000000000004'
      )
  ),
  'supporting name evidence alone must not authorize a destructive merge'
);

-- Two explicit candidates and a visible conflict both supersede an earlier
-- clean automatic result and route the case to review.
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('case_ambiguous_explicit', public.admin_open_news_identity_case(
  'identity', 'human', 'Alex Rivers', null,
  null, null, null, null, null, null,
  'Which same-name person is established by the public evidence?',
  '{}'::jsonb, 'Synthetic governed ambiguous-evidence intake.'
));
select pg_temp.remember('candidate_ambiguous_first',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_ambiguous_explicit'), 'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000001', 'Alex Rivers',
    '{}'::jsonb, 'Record the first same-name identity candidate.'
  )
);
select pg_temp.remember('candidate_ambiguous_second',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_ambiguous_explicit'), 'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000002', 'Alex Rivers',
    '{}'::jsonb, 'Record the second same-name identity candidate.'
  )
);
select pg_temp.remember('evidence_ambiguous_first',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_ambiguous_explicit'), pg_temp.id('candidate_ambiguous_first'),
    'publisher_author_profile',
    '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/authors/alex-one', null, null,
    'public_profile', false,
    'One official profile supports the first person.', '{}'::jsonb,
    '2026-08-29T09:03:00Z', 'Synthetic governed explicit evidence.'
  )
);
select pg_temp.remember('evidence_ambiguous_second',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_ambiguous_explicit'), pg_temp.id('candidate_ambiguous_second'),
    'publisher_author_profile',
    '86100000-0000-0000-0000-000000000002',
    'https://publisher-b.example/authors/alex-two', null, null,
    'public_profile', false,
    'Another official profile supports the second person.', '{}'::jsonb,
    '2026-08-29T09:04:00Z', 'Synthetic governed competing evidence.'
  )
);
reset role;

select pg_temp.assert_true(
  (
    select status = 'needs_review'
      and resolution_stop_reason = 'ambiguous_explicit_evidence'
    from public.news_identity_resolution_cases
    where id = pg_temp.id('case_ambiguous_explicit')
  ),
  'ambiguous explicit candidates must supersede automatic Resolution and route to review'
);
select pg_temp.assert_true(
  exists (
    select 1
    from public.news_identity_resolution_decisions later_decision
    join public.news_identity_resolution_decisions earlier_decision
      on earlier_decision.id = later_decision.supersedes_decision_id
    where later_decision.case_id = pg_temp.id('case_ambiguous_explicit')
      and later_decision.action = 'automatic_review_required'
      and earlier_decision.action = 'automatic_link'
  ),
  'a later automatic review outcome must retain which automatic Resolution it superseded'
);

select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('case_visible_conflict', public.admin_open_news_identity_case(
  'identity', 'human', 'Morgan Lane', null,
  null, null, null, null, null, null,
  'Does conflicting visible evidence block Resolution?',
  '{}'::jsonb, 'Synthetic governed conflicting-evidence intake.'
));
select pg_temp.remember('candidate_visible_conflict_first',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_visible_conflict'), 'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000005', 'Morgan Lane',
    '{}'::jsonb, 'Record the first visible identity candidate.'
  )
);
select pg_temp.remember('candidate_visible_conflict_second',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_visible_conflict'), 'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000006', 'Morgan Lane',
    '{}'::jsonb, 'Record the conflicting visible identity candidate.'
  )
);
select pg_temp.remember('evidence_visible_conflict_first',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_visible_conflict'),
    pg_temp.id('candidate_visible_conflict_first'),
    'visible_byline_profile',
    '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/morgan', null, null,
    'visible_public', false,
    'Visible public attribution supports one person.', '{}'::jsonb,
    '2026-08-29T09:05:00Z', 'Synthetic governed visible evidence.'
  )
);
select pg_temp.remember('evidence_visible_conflict_second',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_visible_conflict'),
    pg_temp.id('candidate_visible_conflict_second'),
    'publisher_author_profile',
    '86100000-0000-0000-0000-000000000002',
    'https://publisher-b.example/morgan', null, null,
    'visible_public', true,
    'Conflicting visible public attribution names another person.',
    '{}'::jsonb, '2026-08-29T09:06:00Z',
    'Synthetic governed conflicting public evidence.'
  )
);
reset role;

select pg_temp.assert_true(
  (
    select status = 'needs_review'
      and resolution_stop_reason = 'conflicting_public_evidence'
    from public.news_identity_resolution_cases
    where id = pg_temp.id('case_visible_conflict')
  ),
  'conflicting visible public evidence must route to review'
);

-- Visible public evidence outranks contradictory hidden supporting metadata.
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('case_visible_over_hidden', public.admin_open_news_identity_case(
  'identity', 'human', 'Morgan Lane', null,
  null, null, null, null, null, null,
  'Which identity does the visible attribution establish?',
  '{}'::jsonb, 'Synthetic governed visibility-precedence intake.'
));
select pg_temp.remember('candidate_visible_primary',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_visible_over_hidden'), 'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000005', 'Morgan Lane',
    '{}'::jsonb, 'Record the visibly attributed candidate.'
  )
);
select pg_temp.remember('candidate_hidden_conflict',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_visible_over_hidden'), 'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000006', 'Morgan Lane',
    '{}'::jsonb, 'Record the hidden-metadata candidate.'
  )
);
select pg_temp.remember('evidence_hidden_conflict',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_visible_over_hidden'),
    pg_temp.id('candidate_hidden_conflict'), 'hidden_metadata', null,
    'https://publisher-a.example/hidden-metadata', null, null,
    'hidden_metadata', true, 'Hidden metadata points elsewhere.',
    '{}'::jsonb, '2026-08-29T09:07:00Z',
    'Synthetic governed hidden metadata.'
  )
);
select pg_temp.remember('evidence_visible_primary',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_visible_over_hidden'),
    pg_temp.id('candidate_visible_primary'), 'visible_byline_profile',
    '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/visible-profile', null, null,
    'visible_public', false,
    'Visible attribution explicitly identifies the person.', '{}'::jsonb,
    '2026-08-29T09:08:00Z', 'Synthetic governed visible attribution.'
  )
);
reset role;

select pg_temp.assert_true(
  (
    select status = 'resolved_automatic'
      and automatic_resolution_result = 'automatic_link'
    from public.news_identity_resolution_cases
    where id = pg_temp.id('case_visible_over_hidden')
  ),
  'contradictory hidden metadata must not override explicit visible public attribution'
);

-- Explicit non-bridging evidence is still insufficient for a cross-identity
-- merge; only a governed bridge kind can authorize it.
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('case_person_bridge', public.admin_open_news_identity_case(
  'person_merge', 'human', 'Casey Bridge',
  '86100000-0000-0000-0000-000000000001',
  '86200000-0000-0000-0000-000000000007', null, null, null,
  null, null, 'Does the evidence explicitly bridge these identities?',
  '{}'::jsonb, 'Synthetic governed person-bridge intake.'
));
select pg_temp.remember('candidate_person_bridge',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_person_bridge'), 'merge_target', 'human',
    '86200000-0000-0000-0000-000000000008', 'Casey Bridge',
    '{}'::jsonb, 'Record the possible cross-identity merge target.'
  )
);
select pg_temp.remember('evidence_person_non_bridge',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_person_bridge'), pg_temp.id('candidate_person_bridge'),
    'publisher_author_profile',
    '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/casey', null, null,
    'public_profile', false,
    'The profile establishes one identity but does not bridge two identities.',
    '{}'::jsonb, '2026-08-29T09:09:00Z',
    'Synthetic governed non-bridge evidence.'
  )
);
reset role;

select pg_temp.assert_true(
  (
    select status = 'needs_review'
      and resolution_stop_reason = 'missing_identity_bridge'
    from public.news_identity_resolution_cases
    where id = pg_temp.id('case_person_bridge')
  ),
  'cross-identity linking without explicit bridge evidence must go to review'
);

-- A governed explicit bridge merges automatically. Reversal retains the
-- ambiguous, merged, and distinct periods with direct point-in-time answers.
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('evidence_person_bridge',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_person_bridge'), pg_temp.id('candidate_person_bridge'),
    'first_party_cross_publisher_bridge',
    '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/casey-moved',
    '86100000-0000-0000-0000-000000000001',
    '86100000-0000-0000-0000-000000000002',
    'visible_public', false,
    'A first-party profile explicitly states this is the same person after moving publishers.',
    '{}'::jsonb, '2026-08-29T09:10:00Z',
    'Synthetic governed cross-publisher bridge evidence.'
  )
);
reset role;

select pg_temp.assert_true(
  (
    select status = 'resolved_automatic'
      and automatic_resolution_result = 'automatic_merge'
    from public.news_identity_resolution_cases
    where id = pg_temp.id('case_person_bridge')
  ),
  'explicit public non-conflicting bridge evidence must permit automatic merge Resolution'
);

select pg_sleep(0.01);
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select public.admin_review_news_identity_case(
  pg_temp.id('case_person_bridge'),
  'reverse_merge',
  '86200000-0000-0000-0000-000000000008',
  '{"identity_type":"human"}'::jsonb,
  'The first-party bridge was later shown to conflate two professional identities.'
);
reset role;

select pg_temp.assert_true(
  (
    select count(*) >= 3
      and count(*) filter (where state = 'ambiguous') >= 1
      and count(*) filter (where state = 'merged') = 1
      and count(*) filter (where state = 'distinct' and is_current) = 1
      and bool_and(opened_by_decision_id is not null)
      and bool_and(closed_by_decision_id is not null) filter (where not is_current)
    from public.news_person_pair_state_periods
    where person_a_id in (
        '86200000-0000-0000-0000-000000000007',
        '86200000-0000-0000-0000-000000000008'
      )
      and person_b_id in (
        '86200000-0000-0000-0000-000000000007',
        '86200000-0000-0000-0000-000000000008'
      )
  ),
  'merge reversal must retain ambiguity, canonical merge, and restored distinct periods'
);

select pg_temp.assert_true(
  not exists (
    select 1
    from public.news_person_pair_state_periods period
    left join lateral public.get_news_person_pair_state_at(
      period.person_a_id,
      period.person_b_id,
      period.effective_from + case
        when period.effective_to is null then interval '1 microsecond'
        else (period.effective_to - period.effective_from) / 2
      end
    ) answer on true
    where period.person_a_id in (
        '86200000-0000-0000-0000-000000000007',
        '86200000-0000-0000-0000-000000000008'
      )
      and period.person_b_id in (
        '86200000-0000-0000-0000-000000000007',
        '86200000-0000-0000-0000-000000000008'
      )
      and (
        answer.state is distinct from period.state
        or answer.canonical_person_id is distinct from period.canonical_person_id
      )
  ),
  'point-in-time pair reads must directly return the recorded canonical and ambiguity state without inference'
);

-- A publisher-specific contributor profile cannot attach automatically to a
-- person established only at another publisher unless explicit evidence
-- bridges the exact publisher identities involved.
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('candidate_profile_3',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_profile_3'), 'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000005', 'Morgan Lane',
    '{}'::jsonb, 'Record the Publisher B person candidate.'
  )
);
select pg_temp.remember('candidate_profile_4',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_profile_4'), 'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000006', 'Morgan Lane',
    '{}'::jsonb, 'Record the Publisher B person candidate.'
  )
);
select pg_temp.remember('candidate_profile_5',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_profile_5'), 'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000008', 'Casey Bridge',
    '{}'::jsonb, 'Record the Publisher B person candidate.'
  )
);
select pg_temp.remember('evidence_profile_3',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_profile_3'), pg_temp.id('candidate_profile_3'),
    'publisher_author_profile',
    '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/authors/morgan-lane', null, null,
    'public_profile', false,
    'Publisher A establishes its profile but does not connect it to Publisher B.',
    '{}'::jsonb, '2026-08-29T09:10:00Z',
    'Synthetic governed non-bridge evidence.'
  )
);
reset role;
select pg_temp.assert_true(
  (
    select status = 'needs_review'
      and resolution_stop_reason = 'missing_cross_publisher_identity_bridge'
    from public.news_identity_resolution_cases
    where id = pg_temp.id('case_profile_3')
  ) and not exists (
    select 1
    from public.news_publisher_contributor_profile_versions
    where contributor_profile_id = pg_temp.id('profile_3')
  ),
  'ordinary explicit evidence without the cross-publisher bridge must route to review'
);

select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('evidence_profile_4',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_profile_4'), pg_temp.id('candidate_profile_4'),
    'first_party_cross_publisher_bridge',
    '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/authors/morgan-lane-moved',
    '86100000-0000-0000-0000-000000000001',
    '86100000-0000-0000-0000-000000000002',
    'public_profile', false,
    'Publisher A explicitly connects its profile to the same person at Publisher B.',
    '{}'::jsonb, '2026-08-29T09:11:00Z',
    'Synthetic governed bridge evidence.'
  )
);
reset role;
select pg_temp.assert_true(
  (
    select status = 'resolved_automatic'
      and automatic_resolution_result = 'automatic_link'
    from public.news_identity_resolution_cases
    where id = pg_temp.id('case_profile_4')
  ) and exists (
    select 1
    from public.news_publisher_contributor_profile_versions version
    join public.news_identity_resolution_decisions decision
      on decision.id = version.resolution_decision_id
    where version.contributor_profile_id = pg_temp.id('profile_4')
      and version.person_id = '86200000-0000-0000-0000-000000000006'
      and version.is_current
      and decision.automatic_rule_key = 'explicit_public_identity_bridge'
  ),
  'a valid explicit bridge between the actual publisher identities may link automatically'
);

select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('evidence_profile_5_public',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_profile_5'), pg_temp.id('candidate_profile_5'),
    'publisher_author_profile',
    '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/authors/casey-bridge', null, null,
    'public_profile', false,
    'Publisher A establishes only its own contributor profile.',
    '{}'::jsonb, '2026-08-29T09:12:00Z',
    'Synthetic governed profile evidence.'
  )
);
select pg_temp.remember('evidence_profile_5_conflict',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_profile_5'), pg_temp.id('candidate_profile_5'),
    'first_party_cross_publisher_bridge',
    '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/authors/casey-bridge-conflict',
    '86100000-0000-0000-0000-000000000001',
    '86100000-0000-0000-0000-000000000002',
    'public_profile', true,
    'First-party evidence contradicts the proposed cross-publisher connection.',
    '{}'::jsonb, '2026-08-29T09:13:00Z',
    'Synthetic governed conflicting bridge evidence.'
  )
);
reset role;
select pg_temp.assert_true(
  (
    select status = 'needs_review'
      and resolution_stop_reason = 'conflicting_public_evidence'
    from public.news_identity_resolution_cases
    where id = pg_temp.id('case_profile_5')
  ) and not exists (
    select 1
    from public.news_publisher_contributor_profile_versions
    where contributor_profile_id = pg_temp.id('profile_5')
  ),
  'a conflicting cross-publisher bridge must route to review and create no link'
);

-- Correcting a record version must not replace the factual period with the
-- date FANatical learned about or recorded the correction.
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('case_affiliation_correction', public.admin_open_news_identity_case(
  'affiliation', 'human', 'Morgan Lane',
  '86100000-0000-0000-0000-000000000002',
  '86200000-0000-0000-0000-000000000005', null, null, null,
  null, null,
  'What was the factual Publisher B relationship during the recorded period?',
  '{}'::jsonb, 'Synthetic governed affiliation-correction intake.'
));
select public.admin_review_news_identity_case(
  pg_temp.id('case_affiliation_correction'),
  'correct_affiliation',
  '86200000-0000-0000-0000-000000000005',
  '{"publisher_source_id":"86100000-0000-0000-0000-000000000002","relationship_type":"freelance","relationship_id":"86900000-0000-0000-0000-000000000004","effective_from":"2018-01-01T00:00:00Z","effective_to":"2020-06-30T00:00:00Z"}'::jsonb,
  'The factual period was correct; only the relationship classification required correction.'
);
reset role;

select pg_temp.assert_true(
  (
    select relationship.effective_from = '2018-01-01T00:00:00Z'::timestamptz
      and relationship.effective_to = '2020-06-30T00:00:00Z'::timestamptz
      and not relationship.is_current
      and relationship.superseded_at > relationship.effective_to
      and relationship.closed_by_decision_id is not null
    from public.news_person_publisher_relationship_versions relationship
    where relationship.id = '86900000-0000-0000-0000-000000000004'
  ) and exists (
    select 1
    from public.news_person_publisher_relationship_versions relationship
    join public.news_identity_resolution_decisions decision
      on decision.id = relationship.resolution_decision_id
    where relationship.person_id = '86200000-0000-0000-0000-000000000005'
      and relationship.publisher_source_id = '86100000-0000-0000-0000-000000000002'
      and relationship.relationship_type = 'freelance'
      and relationship.effective_from = '2018-01-01T00:00:00Z'::timestamptz
      and relationship.effective_to = '2020-06-30T00:00:00Z'::timestamptz
      and relationship.is_current
      and decision.action = 'correct_affiliation'
  ),
  'a later affiliation correction must preserve the original factual period exactly while recording supersession separately'
);

-- "Not an identity" and "not enough evidence" are distinct durable outcomes.
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('case_not_identity', public.admin_open_news_identity_case(
  'identity', 'unknown', 'Weekly Roundup', null,
  null, null, null, null, null, null,
  'Is this text actually a contributor identity?', '{}'::jsonb,
  'Synthetic governed non-identity intake.'
));
select pg_temp.remember('case_insufficient_evidence', public.admin_open_news_identity_case(
  'identity', 'human', 'Unresolved Writer', null,
  null, null, null, null, null, null,
  'Is there enough public evidence to establish this person?', '{}'::jsonb,
  'Synthetic governed insufficient-evidence intake.'
));
select pg_temp.remember('case_create_human', public.admin_open_news_identity_case(
  'identity', 'human', 'Synthetic New Writer',
  '86100000-0000-0000-0000-000000000001',
  null, null, null, null, null,
  'https://publisher-a.example/authors/synthetic-new-writer',
  'Should a new persistent human identity be created?',
  '{}'::jsonb, 'Synthetic governed human intake.'
));
select pg_temp.remember('candidate_create_human',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_create_human'), 'proposed_identity', 'human', null,
    'Synthetic New Writer', '{}'::jsonb,
    'Record a proposed human identity.'
  )
);
select pg_temp.remember('evidence_create_human',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_create_human'), pg_temp.id('candidate_create_human'),
    'publisher_author_profile',
    '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/authors/synthetic-new-writer',
    null, null, 'public_profile', false,
    'The publisher-owned public Author profile establishes a new professional identity.',
    '{}'::jsonb, '2026-08-29T09:20:00Z',
    'Synthetic governed public evidence.'
  )
);
select public.admin_review_news_identity_case(
  pg_temp.id('case_not_identity'),
  'not_identity', null, '{}'::jsonb,
  'This is a section label, not a published contributor identity.'
);
select public.admin_review_news_identity_case(
  pg_temp.id('case_insufficient_evidence'),
  'insufficient_evidence', null, '{}'::jsonb,
  'No public profile or other explicit evidence is available yet.'
);
select public.admin_review_news_identity_case(
  pg_temp.id('case_create_human'),
  'confirm_create', null,
  '{"identity_type":"human","display_name":"Synthetic New Writer","name_kind":"professional_name"}'::jsonb,
  'The reviewed public evidence establishes a new professional identity.'
);
reset role;

select pg_temp.assert_true(
  (
    select count(*) = 2
    from public.news_identity_resolution_cases
    where (id = pg_temp.id('case_not_identity') and status = 'not_identity')
       or (id = pg_temp.id('case_insufficient_evidence') and status = 'insufficient_evidence')
  ),
  'not-an-identity and insufficient-evidence must remain distinct terminal outcomes'
);
select pg_temp.assert_true(
  exists (
    select 1
    from public.news_identity_resolution_decisions decision
    join public.catalog_people person on person.id = decision.result_person_id
    join public.news_author_profiles author on author.person_id = person.id
    where decision.case_id = pg_temp.id('case_create_human')
      and decision.action = 'confirm_create'
      and decision.decision_origin = 'staff'
  ),
  'authorized Admin confirm/create must atomically create a person and Author role with decision provenance'
);

select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select public.admin_review_news_identity_case(
  pg_temp.id('case_profile_2'),
  'link_existing',
  '86200000-0000-0000-0000-000000000002',
  '{"identity_type":"human","display_name":"Alex Rivers"}'::jsonb,
  'The reviewed publisher profile belongs to this existing persistent person.'
);
reset role;

select pg_temp.assert_true(
  exists (
    select 1
    from public.news_publisher_contributor_profile_versions profile_version
    join public.news_identity_resolution_decisions decision
      on decision.id = profile_version.resolution_decision_id
    where profile_version.contributor_profile_id = pg_temp.id('profile_2')
      and profile_version.person_id = '86200000-0000-0000-0000-000000000002'
      and profile_version.is_current
      and decision.action = 'link_existing'
  ),
  'authorized review must link a publisher profile to an existing persistent person with provenance'
);
select pg_temp.assert_true(
  (
    select version.effective_from = '2019-02-01T00:00:00Z'::timestamptz
      and version.effective_to = '2020-11-30T00:00:00Z'::timestamptz
      and not version.is_current
      and version.superseded_at > version.effective_to
      and version.closed_by_decision_id is not null
    from public.news_publisher_contributor_profile_versions version
    where version.id = '86510000-0000-0000-0000-000000000002'
  ),
  'correcting a publisher-profile version must preserve its factual effective period and record correction time separately'
);

-- Publisher factual-governance values never become News policy. Even an
-- explicit News policy remains whatever News recorded, independent of Tier 1.
select pg_temp.assert_true(
  (
    select news_status = 'unreviewed'
    from public.news_publisher_policy_read_model
    where publisher_source_id = '86100000-0000-0000-0000-000000000001'
  ),
  'approved factual publisher and Tier 1 assignment must not create News status'
);
insert into public.news_publisher_policy_versions(
  publisher_source_id, news_status, notes
)
values (
  '86100000-0000-0000-0000-000000000001',
  'pending_review',
  'Synthetic independent News-policy proof.'
);
select pg_temp.assert_true(
  (
    select news_status = 'pending_review'
    from public.news_publisher_policy_read_model
    where publisher_source_id = '86100000-0000-0000-0000-000000000001'
  ),
  'News policy must remain pending despite approved factual governance and Tier 1'
);

-- Official publication facts use the canonical Team FK.
insert into public.news_official_team_publication_versions(
  publisher_source_id, team_id, organizational_contributor_id,
  relationship_type
)
select
  '86100000-0000-0000-0000-000000000001',
  team.id,
  '86300000-0000-0000-0000-000000000001',
  'official_newsroom'
from public.catalog_teams team
order by team.team_id
limit 1;

select pg_temp.assert_statement_rejected(
  $statement$
    insert into public.news_official_team_publication_versions(
      publisher_source_id, team_id, relationship_type
    ) values (
      '86100000-0000-0000-0000-000000000001',
      'ffffffff-ffff-ffff-ffff-ffffffffffff',
      'official_publication'
    )
  $statement$,
  'foreign key constraint',
  'official Team/publication relationship must reject a noncanonical Team ID'
);

-- Evidence and decision history cannot be edited after the fact.
select pg_temp.assert_statement_rejected(
  $statement$
    update public.news_identity_resolution_evidence
    set evidence_summary = 'Rewritten evidence'
    where id = pg_temp.id('evidence_explicit_link')
  $statement$,
  'append-only',
  'identity evidence must be immutable'
);
select pg_temp.assert_statement_rejected(
  $statement$
    delete from public.news_identity_resolution_decisions
    where case_id = pg_temp.id('case_explicit_link')
  $statement$,
  'append-only',
  'identity decisions must be immutable'
);

-- The real staff RPC supports all three create populations. Organization and
-- Show cases remain open until the real-role authorization proof below.
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('case_create_org', public.admin_open_news_identity_case(
  'identity', 'organization', 'Synthetic Wire Desk',
  '86100000-0000-0000-0000-000000000001',
  null, null, null, null, null,
  'https://publisher-a.example/wire-desk',
  'Should this reviewed staff/wire identity be created as an organization?',
  '{}'::jsonb, 'Synthetic governed organization intake.'
));
select pg_temp.remember('candidate_create_org',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_create_org'), 'proposed_identity', 'organization', null,
    'Synthetic Wire Desk', '{}'::jsonb,
    'Record a proposed organizational identity.'
  )
);
select pg_temp.remember('evidence_create_org',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_create_org'), pg_temp.id('candidate_create_org'),
    'official_organizational_profile',
    '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/wire-desk', null, null,
    'public_profile', false,
    'The publisher-owned page establishes a real organizational contributor.',
    '{}'::jsonb, '2026-08-29T09:21:00Z',
    'Synthetic governed organizational evidence.'
  )
);
select pg_temp.remember('case_create_show', public.admin_open_news_identity_case(
  'identity', 'show', 'Synthetic Matchday Show',
  '86100000-0000-0000-0000-000000000003',
  null, null, null, null, null,
  'https://network.example/shows/matchday',
  'Should this reviewed podcast identity be created as a Show?',
  '{}'::jsonb, 'Synthetic governed Show intake.'
));
select pg_temp.remember('candidate_create_show',
  public.admin_record_news_identity_candidate(
    pg_temp.id('case_create_show'), 'proposed_identity', 'show', null,
    'Synthetic Matchday Show', '{}'::jsonb,
    'Record a proposed Show identity.'
  )
);
select pg_temp.remember('evidence_create_show',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_create_show'), pg_temp.id('candidate_create_show'),
    'official_show_profile',
    '86100000-0000-0000-0000-000000000003',
    'https://network.example/shows/matchday', null, null,
    'public_profile', false,
    'The network-owned public page establishes a persistent podcast Show.',
    '{}'::jsonb, '2026-08-29T09:22:00Z',
    'Synthetic governed Show evidence.'
  )
);
reset role;

select pg_temp.assert_true(
  exists (
    select 1
    from public.news_identity_resolution_cases identity_case
    join public.news_identity_resolution_decisions open_decision
      on open_decision.id = identity_case.opened_by_decision_id
    join public.news_identity_resolution_candidates candidate
      on candidate.case_id = identity_case.id
     and candidate.id = pg_temp.id('candidate_create_org')
    join public.news_identity_resolution_decisions candidate_decision
      on candidate_decision.id = candidate.recorded_by_decision_id
    join public.news_identity_resolution_evidence evidence
      on evidence.case_id = identity_case.id
     and evidence.id = pg_temp.id('evidence_create_org')
    join public.news_identity_resolution_decisions evidence_decision
      on evidence_decision.id = evidence.recorded_by_decision_id
    where identity_case.id = pg_temp.id('case_create_org')
      and open_decision.action = 'open_case'
      and candidate_decision.action = 'record_candidate'
      and evidence_decision.action = 'record_evidence'
      and open_decision.decision_origin = 'staff'
      and candidate_decision.decision_origin = 'staff'
      and evidence_decision.decision_origin = 'staff'
      and open_decision.decided_by_user_id =
        '86000000-0000-0000-0000-000000000001'
      and candidate_decision.decided_by_user_id =
        '86000000-0000-0000-0000-000000000001'
      and evidence_decision.decided_by_user_id =
        '86000000-0000-0000-0000-000000000001'
      and open_decision.decided_by_actor_id =
        '86010000-0000-0000-0000-000000000001'
      and candidate_decision.decided_by_actor_id =
        '86010000-0000-0000-0000-000000000001'
      and evidence_decision.decided_by_actor_id =
        '86010000-0000-0000-0000-000000000001'
  ),
  'staff case, candidate, and evidence intake must retain immutable user and actor provenance'
);

-- Actual database roles: anon cannot read the review view, an ordinary fan
-- sees no review rows and cannot mutate, and authorized staff can read and act.
select set_config('request.jwt.claim.sub', '', true);
set local role anon;
select pg_temp.assert_statement_rejected(
  'select count(*) from public.news_identity_review_read_model',
  'permission denied',
  'anonymous users must not read private identity review state'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_open_news_identity_case(
      'identity', 'human', 'Anonymous Candidate', null,
      null, null, null, null, null, null,
      'Anonymous users must not open this case.', '{}'::jsonb, null
    )
  $statement$,
  'permission denied',
  'anonymous users must not execute the identity intake RPCs'
);
reset role;

select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000002', true);
set local role authenticated;
select pg_temp.assert_true(
  (select count(*) = 0 from public.news_identity_review_read_model),
  'ordinary authenticated fans must see no private identity review rows under real RLS'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_review_news_identity_case(
      pg_temp.id('case_insufficient_evidence'),
      'reopen', null, '{}'::jsonb, 'Unauthorized fan attempt'
    )
  $statement$,
  'review access is required',
  'ordinary authenticated fans must not mutate identity review state'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_open_news_identity_case(
      'identity', 'human', 'Unauthorized Candidate', null,
      null, null, null, null, null, null,
      'Ordinary fans must not open this case.', '{}'::jsonb, null
    )
  $statement$,
  'intake access is required',
  'ordinary authenticated fans must not open identity cases'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_record_news_identity_candidate(
      pg_temp.id('case_create_org'), 'proposed_identity', 'organization',
      null, 'Unauthorized Organization', '{}'::jsonb, null
    )
  $statement$,
  'intake access is required',
  'ordinary authenticated fans must not record identity candidates'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_record_news_identity_evidence(
      pg_temp.id('case_create_org'), pg_temp.id('candidate_create_org'),
      'name_match', null, null, null, null, 'visible_public', false,
      'Unauthorized evidence.', '{}'::jsonb, null, null
    )
  $statement$,
  'intake access is required',
  'ordinary authenticated fans must not record identity evidence'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_create_news_publisher_contributor_profile(
      pg_temp.id('case_profile_3'), 'Unauthorized profile creation.'
    )
  $statement$,
  'intake access is required',
  'ordinary authenticated fans must not create publisher contributor profiles'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select private.open_news_identity_case_canonical(
      'identity', 'human', 'Private bypass', null,
      null, null, null, null, null, null,
      'Browser roles must not call private canonical intake.', '{}'::jsonb,
      'automation', null,
      '86010000-0000-0000-0000-000000000002', null
    )
  $statement$,
  'permission denied',
  'browser roles must not call private canonical identity mutations'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_review_news_identity_case(
      pg_temp.id('case_create_org'),
      'confirm_create', null,
      '{"identity_type":"organization","display_name":"Synthetic Wire Desk"}'::jsonb,
      'Unauthorized organization creation attempt.'
    )
  $statement$,
  'review access is required',
  'ordinary authenticated fans must not create organizational contributors through the review RPC'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_review_news_identity_case(
      pg_temp.id('case_create_show'),
      'confirm_create', null,
      '{"identity_type":"show","display_name":"Synthetic Matchday Show"}'::jsonb,
      'Unauthorized Show creation attempt.'
    )
  $statement$,
  'review access is required',
  'ordinary authenticated fans must not create Shows through the review RPC'
);
select pg_temp.assert_statement_rejected(
  $statement$
    update public.news_identity_resolution_cases
    set status = 'open'
    where id = pg_temp.id('case_insufficient_evidence')
  $statement$,
  'permission denied',
  'ordinary authenticated fans must not directly mutate review tables'
);
reset role;

select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  $statement$
    insert into public.news_identity_resolution_cases(
      case_kind, proposed_identity_type, proposed_name, unresolved_question
    ) values (
      'identity', 'human', 'Staff direct-table bypass',
      'Authorized staff must still use the governed intake RPC.'
    )
  $statement$,
  'permission denied',
  'authorized staff browser sessions must not receive a direct-table intake shortcut'
);
select pg_temp.assert_true(
  (select count(*) >= 10 from public.news_identity_review_read_model),
  'authorized staff must read the information-dense identity review model under real RLS'
);
select public.admin_review_news_identity_case(
  pg_temp.id('case_insufficient_evidence'),
  'reopen', null, '{}'::jsonb,
  'New public evidence can now be collected.'
);
select public.admin_review_news_identity_case(
  pg_temp.id('case_create_org'),
  'confirm_create', null,
  '{"identity_type":"organization","display_name":"Synthetic Wire Desk"}'::jsonb,
  'Reviewed public evidence establishes an organizational contributor.'
);
select public.admin_review_news_identity_case(
  pg_temp.id('case_create_show'),
  'confirm_create', null,
  '{"identity_type":"show","display_name":"Synthetic Matchday Show"}'::jsonb,
  'Reviewed public evidence establishes a podcast Show.'
);
select pg_temp.assert_true(
  (
    select status = 'reopened'
    from public.news_identity_resolution_cases
    where id = pg_temp.id('case_insufficient_evidence')
  ),
  'authorized staff must perform intended review actions under the real authenticated role'
);
reset role;

select pg_temp.assert_true(
  exists (
    select 1
    from public.news_identity_resolution_decisions decision
    join public.news_organizational_contributors organization
      on organization.id = decision.result_organizational_contributor_id
    join public.news_organizational_contributor_versions version
      on version.organizational_contributor_id = organization.id
     and version.resolution_decision_id = decision.id
    where decision.case_id = pg_temp.id('case_create_org')
      and decision.action = 'confirm_create'
      and decision.decision_origin = 'staff'
      and decision.decided_by_user_id = '86000000-0000-0000-0000-000000000001'
      and version.display_name = 'Synthetic Wire Desk'
      and version.is_current
  ),
  'authorized staff must create an organizational contributor through the actual review RPC with decision provenance'
);
select pg_temp.assert_true(
  exists (
    select 1
    from public.news_identity_resolution_decisions decision
    join public.podcast_shows show
      on show.id = decision.result_show_id
    join public.podcast_show_identity_versions version
      on version.show_id = show.id
     and version.resolution_decision_id = decision.id
    where decision.case_id = pg_temp.id('case_create_show')
      and decision.action = 'confirm_create'
      and decision.decision_origin = 'staff'
      and decision.decided_by_user_id = '86000000-0000-0000-0000-000000000001'
      and version.display_name = 'Synthetic Matchday Show'
      and version.is_current
  ),
  'authorized staff must create a Show through the actual review RPC with decision provenance'
);

select pg_temp.remember(
  'created_org',
  (
    select decision.result_organizational_contributor_id
    from public.news_identity_resolution_decisions decision
    where decision.case_id = pg_temp.id('case_create_org')
      and decision.action = 'confirm_create'
    order by decision.decided_at desc, decision.id desc
    limit 1
  )
);
select pg_temp.remember(
  'created_show',
  (
    select decision.result_show_id
    from public.news_identity_resolution_decisions decision
    where decision.case_id = pg_temp.id('case_create_show')
      and decision.action = 'confirm_create'
    order by decision.decided_at desc, decision.id desc
    limit 1
  )
);

-- The newly established Show receives historical host/contributor and
-- publisher/network facts only through the governed relationship operations.
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('case_show_contributor', public.admin_open_news_identity_case(
  'show_contributor', 'show', 'Synthetic Matchday Show',
  '86100000-0000-0000-0000-000000000003',
  null, null, pg_temp.id('created_show'), null, null,
  'https://network.example/shows/matchday',
  'Who hosted this Show during each factual period?',
  '{}'::jsonb, 'Synthetic governed Show contributor intake.'
));
select pg_temp.remember('evidence_show_contributor',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_show_contributor'), null, 'official_show_profile',
    '86100000-0000-0000-0000-000000000003',
    'https://network.example/shows/matchday', null, null,
    'public_profile', false,
    'The network-owned Show page publicly identifies the Show and its hosts.',
    '{}'::jsonb, '2026-08-29T09:30:00Z',
    'Synthetic governed Show relationship evidence.'
  )
);
select pg_temp.remember('case_show_publisher', public.admin_open_news_identity_case(
  'show_publisher', 'show', 'Synthetic Matchday Show',
  null, null, null, pg_temp.id('created_show'), null, null,
  'https://network.example/shows/matchday',
  'Which publisher or network carried this Show during each factual period?',
  '{}'::jsonb, 'Synthetic governed Show publisher intake.'
));
select pg_temp.remember('evidence_show_publisher_a',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_show_publisher'), null, 'official_show_profile',
    '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/shows/matchday', null, null,
    'public_profile', false,
    'The former publisher-owned Show page establishes the earlier network fact.',
    '{}'::jsonb, '2026-08-29T09:31:00Z',
    'Synthetic former-network evidence.'
  )
);
select pg_temp.remember('evidence_show_publisher_network',
  public.admin_record_news_identity_evidence(
    pg_temp.id('case_show_publisher'), null, 'official_show_profile',
    '86100000-0000-0000-0000-000000000003',
    'https://network.example/shows/matchday', null, null,
    'public_profile', false,
    'The current network-owned Show page establishes the later network fact.',
    '{}'::jsonb, '2026-08-29T09:32:00Z',
    'Synthetic current-network evidence.'
  )
);
reset role;

select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000002', true);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_record_podcast_show_contributor(
      pg_temp.id('case_show_contributor'),
      '86200000-0000-0000-0000-000000000005', 'host',
      '2021-01-01T00:00:00Z', null, null, 'Unauthorized host mutation.'
    )
  $statement$,
  'intake access is required',
  'ordinary authenticated fans must not establish Show/person relationships'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_record_podcast_show_publisher(
      pg_temp.id('case_show_publisher'),
      '86100000-0000-0000-0000-000000000001', 'network',
      '2021-01-01T00:00:00Z', null, null, 'Unauthorized network mutation.'
    )
  $statement$,
  'intake access is required',
  'ordinary authenticated fans must not establish Show/publisher relationships'
);
reset role;

select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.remember('show_host_initial',
  public.admin_record_podcast_show_contributor(
    pg_temp.id('case_show_contributor'),
    '86200000-0000-0000-0000-000000000005', 'host',
    '2021-01-01T00:00:00Z', null, null,
    'Establish the first host with an open-ended factual period.'
  )
);
select pg_temp.remember('show_host_initial_corrected',
  public.admin_record_podcast_show_contributor(
    pg_temp.id('case_show_contributor'),
    '86200000-0000-0000-0000-000000000005', 'host',
    '2021-01-01T00:00:00Z', '2023-01-01T00:00:00Z',
    pg_temp.id('show_host_initial'),
    'Correct the factual end while retaining record supersession time.'
  )
);
select pg_temp.remember('show_host_current',
  public.admin_record_podcast_show_contributor(
    pg_temp.id('case_show_contributor'),
    '86200000-0000-0000-0000-000000000006', 'host',
    '2023-01-01T00:00:00Z', null, null,
    'Establish the later host without replacing Show identity.'
  )
);
select pg_temp.remember('show_network_initial',
  public.admin_record_podcast_show_publisher(
    pg_temp.id('case_show_publisher'),
    '86100000-0000-0000-0000-000000000001', 'network',
    '2021-01-01T00:00:00Z', null, null,
    'Establish the former network.'
  )
);
select pg_temp.remember('show_network_initial_corrected',
  public.admin_record_podcast_show_publisher(
    pg_temp.id('case_show_publisher'),
    '86100000-0000-0000-0000-000000000001', 'network',
    '2021-01-01T00:00:00Z', '2024-01-01T00:00:00Z',
    pg_temp.id('show_network_initial'),
    'Correct the former network factual end date.'
  )
);
select pg_temp.remember('show_network_current',
  public.admin_record_podcast_show_publisher(
    pg_temp.id('case_show_publisher'),
    '86100000-0000-0000-0000-000000000003', 'network',
    '2024-01-01T00:00:00Z', null, null,
    'Establish the later network without replacing Show identity.'
  )
);
reset role;

select pg_temp.assert_true(
  (
    select count(*) = 3
      and count(*) filter (where is_current) = 2
      and bool_or(
        id = pg_temp.id('show_host_initial')
        and not is_current
        and effective_from = '2021-01-01T00:00:00Z'::timestamptz
        and effective_to is null
        and superseded_at is not null
        and closed_by_decision_id is not null
      )
      and bool_or(
        id = pg_temp.id('show_host_initial_corrected')
        and is_current
        and effective_from = '2021-01-01T00:00:00Z'::timestamptz
        and effective_to = '2023-01-01T00:00:00Z'::timestamptz
      )
      and bool_or(
        id = pg_temp.id('show_host_current')
        and is_current
        and effective_from = '2023-01-01T00:00:00Z'::timestamptz
        and effective_to is null
      )
    from public.podcast_show_contributor_versions
    where show_id = pg_temp.id('created_show')
  ),
  'governed Show/person changes must preserve version history and exact factual periods'
);
select pg_temp.assert_true(
  (
    select count(*) = 3
      and count(*) filter (where is_current) = 2
      and bool_or(
        id = pg_temp.id('show_network_initial')
        and not is_current
        and effective_from = '2021-01-01T00:00:00Z'::timestamptz
        and effective_to is null
        and superseded_at is not null
        and closed_by_decision_id is not null
      )
      and bool_or(
        id = pg_temp.id('show_network_initial_corrected')
        and is_current
        and effective_from = '2021-01-01T00:00:00Z'::timestamptz
        and effective_to = '2024-01-01T00:00:00Z'::timestamptz
      )
      and bool_or(
        id = pg_temp.id('show_network_current')
        and is_current
        and effective_from = '2024-01-01T00:00:00Z'::timestamptz
        and effective_to is null
      )
    from public.podcast_show_publisher_relationship_versions
    where show_id = pg_temp.id('created_show')
  ),
  'governed Show/publisher changes must preserve version history and exact factual periods'
);
select pg_temp.assert_true(
  exists (
    select 1
    from public.podcast_show_contributor_versions relationship
    join public.news_identity_resolution_decisions decision
      on decision.id = relationship.resolution_decision_id
    where relationship.id = pg_temp.id('show_host_initial_corrected')
      and decision.action = 'correct_show_contributor'
      and decision.action_payload_snapshot ->> 'relationship_id' =
        relationship.id::text
      and decision.action_payload_snapshot ->> 'supersedes_relationship_id' =
        pg_temp.id('show_host_initial')::text
  ) and exists (
    select 1
    from public.podcast_show_publisher_relationship_versions relationship
    join public.news_identity_resolution_decisions decision
      on decision.id = relationship.resolution_decision_id
    where relationship.id = pg_temp.id('show_network_initial_corrected')
      and decision.action = 'correct_show_publisher'
      and decision.action_payload_snapshot ->> 'relationship_id' =
        relationship.id::text
      and decision.action_payload_snapshot ->> 'supersedes_relationship_id' =
        pg_temp.id('show_network_initial')::text
  ),
  'Show relationship decisions must identify both the new version and the version they supersede'
);

-- A future authorized automation wrapper can reuse the same private intake
-- operations with actor provenance. No runtime or public automation wrapper
-- is introduced by this proof.
select pg_temp.remember('case_automation', private.open_news_identity_case_canonical(
  'identity', 'human', 'Automation Review Candidate',
  '86100000-0000-0000-0000-000000000001',
  null, null, null, null, null, null,
  'Does this automation-discovered clue establish an existing identity?',
  '{}'::jsonb, 'automation', null,
  '86010000-0000-0000-0000-000000000002',
  'Synthetic shared canonical-operation proof.'
));
select pg_temp.remember('candidate_automation',
  private.record_news_identity_candidate_canonical(
    pg_temp.id('case_automation'), 'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000003',
    'Automation Review Candidate', '{}'::jsonb,
    'automation', null,
    '86010000-0000-0000-0000-000000000002', null
  )
);
select pg_temp.remember('evidence_automation',
  private.record_news_identity_evidence_canonical(
    pg_temp.id('case_automation'), pg_temp.id('candidate_automation'),
    'name_match', null, null, null, null,
    'visible_public', false, 'Name text is only a supporting clue.',
    '{}'::jsonb, '2026-08-29T09:40:00Z',
    'automation', null,
    '86010000-0000-0000-0000-000000000002', null
  )
);

select pg_temp.assert_true(
  (
    select count(*) = 3
      and bool_and(decision_origin = 'automation')
      and bool_and(automatic_rule_key is null)
      and bool_and(decided_by_user_id is null)
      and bool_and(
        decided_by_actor_id = '86010000-0000-0000-0000-000000000002'
      )
    from public.news_identity_resolution_decisions
    where case_id = pg_temp.id('case_automation')
      and action in ('open_case', 'record_candidate', 'record_evidence')
  ) and (
    select status = 'needs_review'
      and resolution_stop_reason = 'supporting_evidence_only'
    from public.news_identity_resolution_cases
    where id = pg_temp.id('case_automation')
  ),
  'shared canonical intake must retain automation provenance while preserving review-safe Resolution behavior'
);
select pg_temp.assert_true(
  position(
    'private.open_news_identity_case_canonical'
    in pg_get_functiondef(
      'public.admin_open_news_identity_case(text,text,text,uuid,uuid,uuid,uuid,uuid,text,text,text,jsonb,text)'::regprocedure
    )
  ) > 0
  and position(
    'private.record_news_identity_candidate_canonical'
    in pg_get_functiondef(
      'public.admin_record_news_identity_candidate(uuid,text,text,uuid,text,jsonb,text)'::regprocedure
    )
  ) > 0
  and position(
    'private.record_news_identity_evidence_canonical'
    in pg_get_functiondef(
      'public.admin_record_news_identity_evidence(uuid,uuid,text,uuid,text,uuid,uuid,text,boolean,text,jsonb,timestamptz,text)'::regprocedure
    )
  ) > 0
  and position(
    'private.record_podcast_show_contributor_canonical'
    in pg_get_functiondef(
      'public.admin_record_podcast_show_contributor(uuid,uuid,text,timestamptz,timestamptz,uuid,text)'::regprocedure
    )
  ) > 0
  and position(
    'private.record_podcast_show_publisher_canonical'
    in pg_get_functiondef(
      'public.admin_record_podcast_show_publisher(uuid,uuid,text,timestamptz,timestamptz,uuid,text)'::regprocedure
    )
  ) > 0,
  'all staff intake wrappers must remain thin callers of the shared private canonical operations'
);

rollback;
