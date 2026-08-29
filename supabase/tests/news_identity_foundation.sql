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
  ('86100000-0000-0000-0000-000000000005', 'phase2-ambiguous-b', 'Phase 2 Ambiguous Owner B', 'https://ambiguous-evidence.example', 'approved');

insert into public.trusted_source_url_scope_versions(
  id, source_id, hostname, include_subdomains, path_prefix,
  path_match, scope_kind, review_status
)
values
  ('86110000-0000-0000-0000-000000000001', '86100000-0000-0000-0000-000000000001', 'publisher-a.example', false, '/', 'prefix', 'publisher', 'approved'),
  ('86110000-0000-0000-0000-000000000002', '86100000-0000-0000-0000-000000000002', 'publisher-b.example', false, '/', 'prefix', 'publisher', 'approved'),
  ('86110000-0000-0000-0000-000000000003', '86100000-0000-0000-0000-000000000003', 'network.example', false, '/', 'prefix', 'publisher', 'approved'),
  ('86110000-0000-0000-0000-000000000004', '86100000-0000-0000-0000-000000000004', 'ambiguous-evidence.example', false, '/', 'prefix', 'publisher', 'approved'),
  ('86110000-0000-0000-0000-000000000005', '86100000-0000-0000-0000-000000000005', 'ambiguous-evidence.example', false, '/', 'prefix', 'publisher', 'approved');

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

insert into public.news_publisher_contributor_profiles(
  id, contributor_profile_id, publisher_source_id
)
values
  (
    '86500000-0000-0000-0000-000000000001',
    'contributor-profile-00000000000000000000000000000001',
    '86100000-0000-0000-0000-000000000001'
  ),
  (
    '86500000-0000-0000-0000-000000000002',
    'contributor-profile-00000000000000000000000000000002',
    '86100000-0000-0000-0000-000000000001'
  ),
  (
    '86500000-0000-0000-0000-000000000003',
    'contributor-profile-00000000000000000000000000000003',
    '86100000-0000-0000-0000-000000000001'
  ),
  (
    '86500000-0000-0000-0000-000000000004',
    'contributor-profile-00000000000000000000000000000004',
    '86100000-0000-0000-0000-000000000001'
  ),
  (
    '86500000-0000-0000-0000-000000000005',
    'contributor-profile-00000000000000000000000000000005',
    '86100000-0000-0000-0000-000000000001'
  );

insert into public.news_publisher_contributor_profile_versions(
  id, contributor_profile_id, display_name, profile_url,
  person_id, organizational_contributor_id,
  effective_from, effective_to
)
values
  (
    '86510000-0000-0000-0000-000000000001',
    '86500000-0000-0000-0000-000000000001',
    'Phase 2 Staff', 'https://publisher-a.example/staff', null,
    '86300000-0000-0000-0000-000000000001',
    '2020-01-01', null
  ),
  (
    '86510000-0000-0000-0000-000000000002',
    '86500000-0000-0000-0000-000000000002',
    'Alex Rivers', 'https://publisher-a.example/authors/alex-rivers-two',
    '86200000-0000-0000-0000-000000000001', null,
    '2019-02-01', '2020-11-30'
  );

select pg_temp.assert_statement_rejected(
  $statement$
    insert into public.news_publisher_contributor_profile_versions(
      contributor_profile_id, display_name, person_id,
      organizational_contributor_id
    ) values (
      '86500000-0000-0000-0000-000000000002', 'Invalid Hybrid',
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
insert into public.podcast_show_contributor_versions(
  show_id, person_id, contributor_role, effective_from, effective_to, is_current
)
values
  ('86400000-0000-0000-0000-000000000001', '86200000-0000-0000-0000-000000000005', 'host', '2021-01-01', '2023-01-01', false),
  ('86400000-0000-0000-0000-000000000001', '86200000-0000-0000-0000-000000000006', 'host', '2023-01-01', null, true);
insert into public.podcast_show_publisher_relationship_versions(
  show_id, publisher_source_id, relationship_type,
  effective_from, effective_to, is_current
)
values
  ('86400000-0000-0000-0000-000000000001', '86100000-0000-0000-0000-000000000001', 'network', '2021-01-01', '2024-01-01', false),
  ('86400000-0000-0000-0000-000000000001', '86100000-0000-0000-0000-000000000003', 'network', '2024-01-01', null, true);

select pg_temp.assert_true(
  (
    select show.show_id = 'show-00000000000000000000000000000001'
      and (select count(*) from public.podcast_show_contributor_versions contributor where contributor.show_id = show.id) = 2
      and (select count(*) from public.podcast_show_publisher_relationship_versions publisher where publisher.show_id = show.id) = 2
    from public.podcast_shows show
    where show.id = '86400000-0000-0000-0000-000000000001'
  ),
  'Show identity must survive host and network changes with history retained'
);

-- Name alone produces review and an explicit point-in-time ambiguity record.
insert into public.news_identity_resolution_cases(
  id, case_id, case_kind, proposed_identity_type, proposed_name,
  subject_person_id, unresolved_question
)
values (
  '86600000-0000-0000-0000-000000000001',
  'news-identity-case-00000000000000000000000000000001',
  'person_merge', 'human', 'Alex Rivers',
  '86200000-0000-0000-0000-000000000001',
  'Are these two same-name people actually one person?'
);
insert into public.news_identity_resolution_candidates(
  id, case_id, candidate_kind, identity_type, person_id, display_name
)
values (
  '86700000-0000-0000-0000-000000000001',
  '86600000-0000-0000-0000-000000000001',
  'merge_target', 'human',
  '86200000-0000-0000-0000-000000000002', 'Alex Rivers'
);

select pg_temp.assert_true(
  (
    select status = 'needs_review'
      and resolution_stop_reason = 'missing_identity_bridge'
    from public.news_identity_resolution_cases
    where id = '86600000-0000-0000-0000-000000000001'
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
  '86600000-0000-0000-0000-000000000001',
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
      '86600000-0000-0000-0000-000000000001',
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
insert into public.news_identity_resolution_cases(
  id, case_id, case_kind, proposed_identity_type, proposed_name,
  publisher_source_id, unresolved_question
)
values (
  '86600000-0000-0000-0000-000000000002',
  'news-identity-case-00000000000000000000000000000002',
  'identity', 'human', 'Jordan North',
  '86100000-0000-0000-0000-000000000001',
  'Which persistent person owns this public Author profile?'
);
insert into public.news_identity_resolution_candidates(
  id, case_id, candidate_kind, identity_type, person_id, display_name
)
values (
  '86700000-0000-0000-0000-000000000002',
  '86600000-0000-0000-0000-000000000002',
  'existing_identity', 'human',
  '86200000-0000-0000-0000-000000000003', 'Jordan North'
);
insert into public.news_identity_resolution_evidence(
  id, case_id, candidate_id, evidence_kind, publisher_source_id,
  evidence_url, visibility, evidence_summary
)
values (
  '86800000-0000-0000-0000-000000000001',
  '86600000-0000-0000-0000-000000000002',
  '86700000-0000-0000-0000-000000000002',
  'publisher_author_profile', '86100000-0000-0000-0000-000000000001',
  'https://publisher-a.example/authors/jordan-north', 'public_profile',
  'The publisher profile explicitly identifies this professional person.'
);

select pg_temp.assert_true(
  (
    select status = 'resolved_automatic'
      and automatic_resolution_result = 'automatic_link'
    from public.news_identity_resolution_cases
    where id = '86600000-0000-0000-0000-000000000002'
  ),
  'clean public explicit evidence must resolve automatically'
);
select pg_temp.assert_true(
  exists (
    select 1
    from public.news_identity_resolution_decisions decision
    join public.news_identity_decision_evidence snapshot
      on snapshot.decision_id = decision.id
    where decision.case_id = '86600000-0000-0000-0000-000000000002'
      and decision.action = 'automatic_link'
      and decision.automatic_rule_key = 'explicit_public_non_conflicting'
      and snapshot.evidence_id = '86800000-0000-0000-0000-000000000001'
  ),
  'automatic Resolution must retain its rule and evidence provenance'
);
select pg_temp.assert_true(
  (
    select evidence.source_url_scope_version_id =
      '86110000-0000-0000-0000-000000000001'::uuid
    from public.news_identity_resolution_evidence evidence
    where evidence.id = '86800000-0000-0000-0000-000000000001'
  ),
  'owned first-party evidence must retain the exact trusted URL-scope provenance used to resolve it'
);

select pg_temp.assert_statement_rejected(
  $statement$
    insert into public.news_identity_resolution_evidence(
      id, case_id, candidate_id, evidence_kind, evidence_url,
      visibility, evidence_summary
    ) values (
      '86800000-0000-0000-0000-000000000011',
      '86600000-0000-0000-0000-000000000002',
      '86700000-0000-0000-0000-000000000002',
      'official_show_profile', 'https://publisher-a.example/not-a-show',
      'public_profile', 'This governed Show evidence kind cannot establish a human candidate.'
    )
  $statement$,
  'does not apply',
  'a governed evidence kind must apply to its candidate or Resolution case subject'
);

-- Claimed first-party evidence cannot bypass canonical URL ownership,
-- redirects, or ambiguity-safe publisher Resolution.
insert into public.news_identity_resolution_cases(
  id, case_id, case_kind, proposed_identity_type, proposed_name,
  publisher_source_id, unresolved_question
)
values (
  '86600000-0000-0000-0000-000000000015',
  'news-identity-case-00000000000000000000000000000015',
  'identity', 'human', 'URL Ownership Candidate',
  '86100000-0000-0000-0000-000000000001',
  'Does publisher-owned public evidence establish this candidate?'
);
insert into public.news_identity_resolution_candidates(
  id, case_id, candidate_kind, identity_type, person_id, display_name
)
values (
  '86700000-0000-0000-0000-000000000015',
  '86600000-0000-0000-0000-000000000015',
  'existing_identity', 'human',
  '86200000-0000-0000-0000-000000000003', 'URL Ownership Candidate'
);

select pg_temp.assert_statement_rejected(
  $statement$
    insert into public.news_identity_resolution_evidence(
      id, case_id, candidate_id, evidence_kind, publisher_source_id,
      evidence_url, visibility, evidence_summary
    ) values (
      '86800000-0000-0000-0000-000000000020',
      '86600000-0000-0000-0000-000000000015',
      '86700000-0000-0000-0000-000000000015',
      'publisher_author_profile',
      '86100000-0000-0000-0000-000000000001',
      'https://publisher-b.example/authors/url-owner',
      'public_profile', 'The URL belongs to a different publisher.'
    )
  $statement$,
  'does not belong to the claimed publisher',
  'a mismatched publisher URL cannot become explicit Resolution evidence'
);
select pg_temp.assert_statement_rejected(
  $statement$
    insert into public.news_identity_resolution_evidence(
      id, case_id, candidate_id, evidence_kind, publisher_source_id,
      evidence_url, visibility, evidence_summary
    ) values (
      '86800000-0000-0000-0000-000000000020',
      '86600000-0000-0000-0000-000000000015',
      '86700000-0000-0000-0000-000000000015',
      'publisher_author_profile',
      '86100000-0000-0000-0000-000000000002',
      'https://publisher-b.example/authors/url-owner',
      'public_profile', 'The URL and evidence row claim Publisher B inside a Publisher A case.'
    )
  $statement$,
  'does not match the Resolution case publisher',
  'ordinary first-party evidence from another publisher cannot drive this publisher case'
);
select pg_temp.assert_statement_rejected(
  $statement$
    insert into public.news_identity_resolution_evidence(
      id, case_id, candidate_id, evidence_kind, publisher_source_id,
      evidence_url, visibility, evidence_summary
    ) values (
      '86800000-0000-0000-0000-000000000020',
      '86600000-0000-0000-0000-000000000015',
      '86700000-0000-0000-0000-000000000015',
      'publisher_author_profile',
      '86100000-0000-0000-0000-000000000001',
      'https://unowned-evidence.example/authors/url-owner',
      'public_profile', 'No trusted publisher owns this URL.'
    )
  $statement$,
  'is not owned by a trusted publisher',
  'an unowned URL cannot become explicit Resolution evidence'
);
select pg_temp.assert_statement_rejected(
  $statement$
    insert into public.news_identity_resolution_evidence(
      id, case_id, candidate_id, evidence_kind, publisher_source_id,
      evidence_url, visibility, evidence_summary
    ) values (
      '86800000-0000-0000-0000-000000000020',
      '86600000-0000-0000-0000-000000000015',
      '86700000-0000-0000-0000-000000000015',
      'publisher_author_profile',
      '86100000-0000-0000-0000-000000000001',
      'https://ambiguous-evidence.example/authors/url-owner',
      'public_profile', 'Two equally specific publishers claim this URL.'
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
    where id = '86600000-0000-0000-0000-000000000015'
  ) and not exists (
    select 1
    from public.news_identity_resolution_evidence
    where case_id = '86600000-0000-0000-0000-000000000015'
  ),
  'mismatched, unowned, and ambiguous URLs must leave the identity unresolved for review'
);

-- Supporting evidence alone cannot merge people.
insert into public.news_identity_resolution_cases(
  id, case_id, case_kind, proposed_identity_type, proposed_name,
  subject_person_id, unresolved_question
)
values (
  '86600000-0000-0000-0000-000000000003',
  'news-identity-case-00000000000000000000000000000003',
  'person_merge', 'human', 'Jordan North',
  '86200000-0000-0000-0000-000000000003',
  'Does matching name text prove these are one person?'
);
insert into public.news_identity_resolution_candidates(
  id, case_id, candidate_kind, identity_type, person_id, display_name
)
values (
  '86700000-0000-0000-0000-000000000003',
  '86600000-0000-0000-0000-000000000003',
  'merge_target', 'human',
  '86200000-0000-0000-0000-000000000004', 'Jordan North'
);
insert into public.news_identity_resolution_evidence(
  id, case_id, candidate_id, evidence_kind, visibility, evidence_summary
)
values (
  '86800000-0000-0000-0000-000000000002',
  '86600000-0000-0000-0000-000000000003',
  '86700000-0000-0000-0000-000000000003',
  'name_match', 'visible_public', 'The public name text matches.'
);

select pg_temp.assert_true(
  (
    select status = 'needs_review'
      and resolution_stop_reason = 'missing_identity_bridge'
    from public.news_identity_resolution_cases
    where id = '86600000-0000-0000-0000-000000000003'
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
insert into public.news_identity_resolution_cases(
  id, case_id, case_kind, proposed_identity_type, proposed_name,
  unresolved_question
)
values (
  '86600000-0000-0000-0000-000000000004',
  'news-identity-case-00000000000000000000000000000004',
  'identity', 'human', 'Alex Rivers',
  'Which same-name person is established by the public evidence?'
);
insert into public.news_identity_resolution_candidates(
  id, case_id, candidate_kind, identity_type, person_id, display_name
)
values
  (
    '86700000-0000-0000-0000-000000000004',
    '86600000-0000-0000-0000-000000000004',
    'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000001', 'Alex Rivers'
  ),
  (
    '86700000-0000-0000-0000-000000000005',
    '86600000-0000-0000-0000-000000000004',
    'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000002', 'Alex Rivers'
  );
insert into public.news_identity_resolution_evidence(
  id, case_id, candidate_id, evidence_kind, publisher_source_id, evidence_url,
  visibility, evidence_summary
)
values (
  '86800000-0000-0000-0000-000000000003',
  '86600000-0000-0000-0000-000000000004',
  '86700000-0000-0000-0000-000000000004',
  'publisher_author_profile', '86100000-0000-0000-0000-000000000001',
  'https://publisher-a.example/authors/alex-one',
  'public_profile', 'One official profile supports the first person.'
);
insert into public.news_identity_resolution_evidence(
  id, case_id, candidate_id, evidence_kind, publisher_source_id, evidence_url,
  visibility, evidence_summary
)
values (
  '86800000-0000-0000-0000-000000000004',
  '86600000-0000-0000-0000-000000000004',
  '86700000-0000-0000-0000-000000000005',
  'publisher_author_profile', '86100000-0000-0000-0000-000000000002',
  'https://publisher-b.example/authors/alex-two',
  'public_profile', 'Another official profile supports the second person.'
);

select pg_temp.assert_true(
  (
    select status = 'needs_review'
      and resolution_stop_reason = 'ambiguous_explicit_evidence'
    from public.news_identity_resolution_cases
    where id = '86600000-0000-0000-0000-000000000004'
  ),
  'ambiguous explicit candidates must supersede automatic Resolution and route to review'
);
select pg_temp.assert_true(
  exists (
    select 1
    from public.news_identity_resolution_decisions later_decision
    join public.news_identity_resolution_decisions earlier_decision
      on earlier_decision.id = later_decision.supersedes_decision_id
    where later_decision.case_id = '86600000-0000-0000-0000-000000000004'
      and later_decision.action = 'automatic_review_required'
      and earlier_decision.action = 'automatic_link'
  ),
  'a later automatic review outcome must retain which automatic Resolution it superseded'
);

insert into public.news_identity_resolution_cases(
  id, case_id, case_kind, proposed_identity_type, proposed_name,
  unresolved_question
)
values (
  '86600000-0000-0000-0000-000000000005',
  'news-identity-case-00000000000000000000000000000005',
  'identity', 'human', 'Morgan Lane',
  'Does conflicting visible evidence block Resolution?'
);
insert into public.news_identity_resolution_candidates(
  id, case_id, candidate_kind, identity_type, person_id, display_name
)
values
  (
    '86700000-0000-0000-0000-000000000006',
    '86600000-0000-0000-0000-000000000005',
    'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000005', 'Morgan Lane'
  ),
  (
    '86700000-0000-0000-0000-000000000007',
    '86600000-0000-0000-0000-000000000005',
    'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000006', 'Morgan Lane'
  );
insert into public.news_identity_resolution_evidence(
  id, case_id, candidate_id, evidence_kind, publisher_source_id, evidence_url,
  visibility, is_conflicting, evidence_summary
)
values
  (
    '86800000-0000-0000-0000-000000000005',
    '86600000-0000-0000-0000-000000000005',
    '86700000-0000-0000-0000-000000000006',
    'visible_byline_profile', '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/morgan',
    'visible_public', false, 'Visible public attribution supports one person.'
  ),
  (
    '86800000-0000-0000-0000-000000000006',
    '86600000-0000-0000-0000-000000000005',
    '86700000-0000-0000-0000-000000000007',
    'publisher_author_profile', '86100000-0000-0000-0000-000000000002',
    'https://publisher-b.example/morgan',
    'visible_public', true, 'Conflicting visible public attribution names another person.'
  );

select pg_temp.assert_true(
  (
    select status = 'needs_review'
      and resolution_stop_reason = 'conflicting_public_evidence'
    from public.news_identity_resolution_cases
    where id = '86600000-0000-0000-0000-000000000005'
  ),
  'conflicting visible public evidence must route to review'
);

-- Visible public evidence outranks contradictory hidden supporting metadata.
insert into public.news_identity_resolution_cases(
  id, case_id, case_kind, proposed_identity_type, proposed_name,
  unresolved_question
)
values (
  '86600000-0000-0000-0000-000000000006',
  'news-identity-case-00000000000000000000000000000006',
  'identity', 'human', 'Morgan Lane',
  'Which identity does the visible attribution establish?'
);
insert into public.news_identity_resolution_candidates(
  id, case_id, candidate_kind, identity_type, person_id, display_name
)
values
  (
    '86700000-0000-0000-0000-000000000008',
    '86600000-0000-0000-0000-000000000006',
    'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000005', 'Morgan Lane'
  ),
  (
    '86700000-0000-0000-0000-000000000009',
    '86600000-0000-0000-0000-000000000006',
    'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000006', 'Morgan Lane'
  );
insert into public.news_identity_resolution_evidence(
  id, case_id, candidate_id, evidence_kind, publisher_source_id, evidence_url,
  visibility, is_conflicting, evidence_summary
)
values
  (
    '86800000-0000-0000-0000-000000000007',
    '86600000-0000-0000-0000-000000000006',
    '86700000-0000-0000-0000-000000000009',
    'hidden_metadata', null, 'https://publisher-a.example/hidden-metadata',
    'hidden_metadata', true, 'Hidden metadata points elsewhere.'
  ),
  (
    '86800000-0000-0000-0000-000000000008',
    '86600000-0000-0000-0000-000000000006',
    '86700000-0000-0000-0000-000000000008',
    'visible_byline_profile', '86100000-0000-0000-0000-000000000001',
    'https://publisher-a.example/visible-profile',
    'visible_public', false, 'Visible attribution explicitly identifies the person.'
  );

select pg_temp.assert_true(
  (
    select status = 'resolved_automatic'
      and automatic_resolution_result = 'automatic_link'
    from public.news_identity_resolution_cases
    where id = '86600000-0000-0000-0000-000000000006'
  ),
  'contradictory hidden metadata must not override explicit visible public attribution'
);

-- Explicit non-bridging evidence is still insufficient for a cross-identity
-- merge; only a governed bridge kind can authorize it.
insert into public.news_identity_resolution_cases(
  id, case_id, case_kind, proposed_identity_type, proposed_name,
  subject_person_id, unresolved_question
)
values (
  '86600000-0000-0000-0000-000000000007',
  'news-identity-case-00000000000000000000000000000007',
  'person_merge', 'human', 'Casey Bridge',
  '86200000-0000-0000-0000-000000000007',
  'Does the evidence explicitly bridge these identities?'
);
insert into public.news_identity_resolution_candidates(
  id, case_id, candidate_kind, identity_type, person_id, display_name
)
values (
  '86700000-0000-0000-0000-000000000010',
  '86600000-0000-0000-0000-000000000007',
  'merge_target', 'human',
  '86200000-0000-0000-0000-000000000008', 'Casey Bridge'
);
insert into public.news_identity_resolution_evidence(
  id, case_id, candidate_id, evidence_kind, publisher_source_id, evidence_url,
  visibility, evidence_summary
)
values (
  '86800000-0000-0000-0000-000000000009',
  '86600000-0000-0000-0000-000000000007',
  '86700000-0000-0000-0000-000000000010',
  'publisher_author_profile', '86100000-0000-0000-0000-000000000001',
  'https://publisher-a.example/casey',
  'public_profile', 'The profile establishes one identity but does not bridge two identities.'
);

select pg_temp.assert_true(
  (
    select status = 'needs_review'
      and resolution_stop_reason = 'missing_identity_bridge'
    from public.news_identity_resolution_cases
    where id = '86600000-0000-0000-0000-000000000007'
  ),
  'cross-identity linking without explicit bridge evidence must go to review'
);

-- A governed explicit bridge merges automatically. Reversal retains the
-- ambiguous, merged, and distinct periods with direct point-in-time answers.
insert into public.news_identity_resolution_evidence(
  id, case_id, candidate_id, evidence_kind, publisher_source_id,
  bridge_from_publisher_source_id, bridge_to_publisher_source_id, evidence_url,
  visibility, evidence_summary
)
values (
  '86800000-0000-0000-0000-000000000010',
  '86600000-0000-0000-0000-000000000007',
  '86700000-0000-0000-0000-000000000010',
  'first_party_cross_publisher_bridge', '86100000-0000-0000-0000-000000000001',
  '86100000-0000-0000-0000-000000000001',
  '86100000-0000-0000-0000-000000000002',
  'https://publisher-a.example/casey-moved',
  'visible_public',
  'A first-party profile explicitly states this is the same person after moving publishers.'
);

select pg_temp.assert_true(
  (
    select status = 'resolved_automatic'
      and automatic_resolution_result = 'automatic_merge'
    from public.news_identity_resolution_cases
    where id = '86600000-0000-0000-0000-000000000007'
  ),
  'explicit public non-conflicting bridge evidence must permit automatic merge Resolution'
);

select pg_sleep(0.01);
select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select public.admin_review_news_identity_case(
  '86600000-0000-0000-0000-000000000007',
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
insert into public.news_identity_resolution_cases(
  id, case_id, case_kind, proposed_identity_type, proposed_name,
  publisher_source_id, subject_contributor_profile_id, profile_url,
  unresolved_question
)
values
  (
    '86600000-0000-0000-0000-000000000012',
    'news-identity-case-00000000000000000000000000000012',
    'publisher_profile', 'human', 'Morgan Lane',
    '86100000-0000-0000-0000-000000000001',
    '86500000-0000-0000-0000-000000000003',
    'https://publisher-a.example/authors/morgan-lane',
    'Does this Publisher A profile belong to the person established at Publisher B?'
  ),
  (
    '86600000-0000-0000-0000-000000000013',
    'news-identity-case-00000000000000000000000000000013',
    'publisher_profile', 'human', 'Morgan Lane',
    '86100000-0000-0000-0000-000000000001',
    '86500000-0000-0000-0000-000000000004',
    'https://publisher-a.example/authors/morgan-lane-moved',
    'Does first-party evidence bridge this Publisher A profile to the Publisher B person?'
  ),
  (
    '86600000-0000-0000-0000-000000000014',
    'news-identity-case-00000000000000000000000000000014',
    'publisher_profile', 'human', 'Casey Bridge',
    '86100000-0000-0000-0000-000000000001',
    '86500000-0000-0000-0000-000000000005',
    'https://publisher-a.example/authors/casey-bridge',
    'Does conflicting bridge evidence permit this cross-publisher link?'
  );

insert into public.news_identity_resolution_candidates(
  id, case_id, candidate_kind, identity_type, person_id, display_name
)
values
  (
    '86700000-0000-0000-0000-000000000012',
    '86600000-0000-0000-0000-000000000012',
    'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000005', 'Morgan Lane'
  ),
  (
    '86700000-0000-0000-0000-000000000013',
    '86600000-0000-0000-0000-000000000013',
    'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000006', 'Morgan Lane'
  ),
  (
    '86700000-0000-0000-0000-000000000014',
    '86600000-0000-0000-0000-000000000014',
    'existing_identity', 'human',
    '86200000-0000-0000-0000-000000000008', 'Casey Bridge'
  );

insert into public.news_identity_resolution_evidence(
  id, case_id, candidate_id, evidence_kind, publisher_source_id,
  evidence_url, visibility, evidence_summary
)
values (
  '86800000-0000-0000-0000-000000000021',
  '86600000-0000-0000-0000-000000000012',
  '86700000-0000-0000-0000-000000000012',
  'publisher_author_profile', '86100000-0000-0000-0000-000000000001',
  'https://publisher-a.example/authors/morgan-lane', 'public_profile',
  'Publisher A establishes its profile but does not connect it to Publisher B.'
);
select pg_temp.assert_true(
  (
    select status = 'needs_review'
      and resolution_stop_reason = 'missing_cross_publisher_identity_bridge'
    from public.news_identity_resolution_cases
    where id = '86600000-0000-0000-0000-000000000012'
  ) and not exists (
    select 1
    from public.news_publisher_contributor_profile_versions
    where contributor_profile_id = '86500000-0000-0000-0000-000000000003'
  ),
  'ordinary explicit evidence without the cross-publisher bridge must route to review'
);

insert into public.news_identity_resolution_evidence(
  id, case_id, candidate_id, evidence_kind, publisher_source_id,
  bridge_from_publisher_source_id, bridge_to_publisher_source_id,
  evidence_url, visibility, evidence_summary
)
values (
  '86800000-0000-0000-0000-000000000022',
  '86600000-0000-0000-0000-000000000013',
  '86700000-0000-0000-0000-000000000013',
  'first_party_cross_publisher_bridge',
  '86100000-0000-0000-0000-000000000001',
  '86100000-0000-0000-0000-000000000001',
  '86100000-0000-0000-0000-000000000002',
  'https://publisher-a.example/authors/morgan-lane-moved',
  'public_profile',
  'Publisher A explicitly connects its profile to the same person at Publisher B.'
);
select pg_temp.assert_true(
  (
    select status = 'resolved_automatic'
      and automatic_resolution_result = 'automatic_link'
    from public.news_identity_resolution_cases
    where id = '86600000-0000-0000-0000-000000000013'
  ) and exists (
    select 1
    from public.news_publisher_contributor_profile_versions version
    join public.news_identity_resolution_decisions decision
      on decision.id = version.resolution_decision_id
    where version.contributor_profile_id = '86500000-0000-0000-0000-000000000004'
      and version.person_id = '86200000-0000-0000-0000-000000000006'
      and version.is_current
      and decision.automatic_rule_key = 'explicit_public_identity_bridge'
  ),
  'a valid explicit bridge between the actual publisher identities may link automatically'
);

insert into public.news_identity_resolution_evidence(
  id, case_id, candidate_id, evidence_kind, publisher_source_id,
  evidence_url, visibility, evidence_summary
)
values (
  '86800000-0000-0000-0000-000000000023',
  '86600000-0000-0000-0000-000000000014',
  '86700000-0000-0000-0000-000000000014',
  'publisher_author_profile', '86100000-0000-0000-0000-000000000001',
  'https://publisher-a.example/authors/casey-bridge', 'public_profile',
  'Publisher A establishes only its own contributor profile.'
);
insert into public.news_identity_resolution_evidence(
  id, case_id, candidate_id, evidence_kind, publisher_source_id,
  bridge_from_publisher_source_id, bridge_to_publisher_source_id,
  evidence_url, visibility, is_conflicting, evidence_summary
)
values (
  '86800000-0000-0000-0000-000000000024',
  '86600000-0000-0000-0000-000000000014',
  '86700000-0000-0000-0000-000000000014',
  'first_party_cross_publisher_bridge',
  '86100000-0000-0000-0000-000000000001',
  '86100000-0000-0000-0000-000000000001',
  '86100000-0000-0000-0000-000000000002',
  'https://publisher-a.example/authors/casey-bridge-conflict',
  'public_profile', true,
  'First-party evidence contradicts the proposed cross-publisher connection.'
);
select pg_temp.assert_true(
  (
    select status = 'needs_review'
      and resolution_stop_reason = 'conflicting_public_evidence'
    from public.news_identity_resolution_cases
    where id = '86600000-0000-0000-0000-000000000014'
  ) and not exists (
    select 1
    from public.news_publisher_contributor_profile_versions
    where contributor_profile_id = '86500000-0000-0000-0000-000000000005'
  ),
  'a conflicting cross-publisher bridge must route to review and create no link'
);

-- Correcting a record version must not replace the factual period with the
-- date FANatical learned about or recorded the correction.
insert into public.news_identity_resolution_cases(
  id, case_id, case_kind, proposed_identity_type, proposed_name,
  publisher_source_id, subject_person_id, unresolved_question
)
values (
  '86600000-0000-0000-0000-000000000016',
  'news-identity-case-00000000000000000000000000000016',
  'affiliation', 'human', 'Morgan Lane',
  '86100000-0000-0000-0000-000000000002',
  '86200000-0000-0000-0000-000000000005',
  'What was the factual Publisher B relationship during the recorded period?'
);

select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select public.admin_review_news_identity_case(
  '86600000-0000-0000-0000-000000000016',
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
insert into public.news_identity_resolution_cases(
  id, case_id, case_kind, proposed_identity_type, proposed_name,
  unresolved_question
)
values
  (
    '86600000-0000-0000-0000-000000000008',
    'news-identity-case-00000000000000000000000000000008',
    'identity', 'unknown', 'Weekly Roundup',
    'Is this text actually a contributor identity?'
  ),
  (
    '86600000-0000-0000-0000-000000000009',
    'news-identity-case-00000000000000000000000000000009',
    'identity', 'human', 'Unresolved Writer',
    'Is there enough public evidence to establish this person?'
  ),
  (
    '86600000-0000-0000-0000-000000000010',
    'news-identity-case-00000000000000000000000000000010',
    'identity', 'human', 'Synthetic New Writer',
    'Should a new persistent human identity be created?'
  );

select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select public.admin_review_news_identity_case(
  '86600000-0000-0000-0000-000000000008',
  'not_identity', null, '{}'::jsonb,
  'This is a section label, not a published contributor identity.'
);
select public.admin_review_news_identity_case(
  '86600000-0000-0000-0000-000000000009',
  'insufficient_evidence', null, '{}'::jsonb,
  'No public profile or other explicit evidence is available yet.'
);
select public.admin_review_news_identity_case(
  '86600000-0000-0000-0000-000000000010',
  'confirm_create', null,
  '{"identity_type":"human","display_name":"Synthetic New Writer","name_kind":"professional_name"}'::jsonb,
  'The reviewed public evidence establishes a new professional identity.'
);
reset role;

select pg_temp.assert_true(
  (
    select count(*) = 2
    from public.news_identity_resolution_cases
    where (id = '86600000-0000-0000-0000-000000000008' and status = 'not_identity')
       or (id = '86600000-0000-0000-0000-000000000009' and status = 'insufficient_evidence')
  ),
  'not-an-identity and insufficient-evidence must remain distinct terminal outcomes'
);
select pg_temp.assert_true(
  exists (
    select 1
    from public.news_identity_resolution_decisions decision
    join public.catalog_people person on person.id = decision.result_person_id
    join public.news_author_profiles author on author.person_id = person.id
    where decision.case_id = '86600000-0000-0000-0000-000000000010'
      and decision.action = 'confirm_create'
      and decision.decision_origin = 'staff'
  ),
  'authorized Admin confirm/create must atomically create a person and Author role with decision provenance'
);

insert into public.news_identity_resolution_cases(
  id, case_id, case_kind, proposed_identity_type, proposed_name,
  publisher_source_id, subject_contributor_profile_id, raw_byline,
  profile_url, unresolved_question
)
values (
  '86600000-0000-0000-0000-000000000011',
  'news-identity-case-00000000000000000000000000000011',
  'publisher_profile', 'human', 'Alex Rivers',
  '86100000-0000-0000-0000-000000000001',
  '86500000-0000-0000-0000-000000000002',
  'By Alex Rivers', 'https://publisher-a.example/authors/alex-rivers-two',
  'Which existing person owns this publisher contributor profile?'
);

select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select public.admin_review_news_identity_case(
  '86600000-0000-0000-0000-000000000011',
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
    where profile_version.contributor_profile_id = '86500000-0000-0000-0000-000000000002'
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
    where id = '86800000-0000-0000-0000-000000000001'
  $statement$,
  'append-only',
  'identity evidence must be immutable'
);
select pg_temp.assert_statement_rejected(
  $statement$
    delete from public.news_identity_resolution_decisions
    where case_id = '86600000-0000-0000-0000-000000000002'
  $statement$,
  'append-only',
  'identity decisions must be immutable'
);

-- The real staff RPC supports all three create populations. Organization and
-- Show cases remain open until the real-role authorization proof below.
insert into public.news_identity_resolution_cases(
  id, case_id, case_kind, proposed_identity_type, proposed_name,
  publisher_source_id, unresolved_question
)
values
  (
    '86600000-0000-0000-0000-000000000017',
    'news-identity-case-00000000000000000000000000000017',
    'identity', 'organization', 'Synthetic Wire Desk',
    '86100000-0000-0000-0000-000000000001',
    'Should this reviewed staff/wire identity be created as an organization?'
  ),
  (
    '86600000-0000-0000-0000-000000000018',
    'news-identity-case-00000000000000000000000000000018',
    'identity', 'show', 'Synthetic Matchday Show',
    '86100000-0000-0000-0000-000000000003',
    'Should this reviewed podcast identity be created as a Show?'
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
      '86600000-0000-0000-0000-000000000009',
      'reopen', null, '{}'::jsonb, 'Unauthorized fan attempt'
    )
  $statement$,
  'review access is required',
  'ordinary authenticated fans must not mutate identity review state'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_review_news_identity_case(
      '86600000-0000-0000-0000-000000000017',
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
      '86600000-0000-0000-0000-000000000018',
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
    where id = '86600000-0000-0000-0000-000000000009'
  $statement$,
  'permission denied',
  'ordinary authenticated fans must not directly mutate review tables'
);
reset role;

select set_config('request.jwt.claim.sub', '86000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.assert_true(
  (select count(*) >= 10 from public.news_identity_review_read_model),
  'authorized staff must read the information-dense identity review model under real RLS'
);
select public.admin_review_news_identity_case(
  '86600000-0000-0000-0000-000000000009',
  'reopen', null, '{}'::jsonb,
  'New public evidence can now be collected.'
);
select public.admin_review_news_identity_case(
  '86600000-0000-0000-0000-000000000017',
  'confirm_create', null,
  '{"identity_type":"organization","display_name":"Synthetic Wire Desk"}'::jsonb,
  'Reviewed public evidence establishes an organizational contributor.'
);
select public.admin_review_news_identity_case(
  '86600000-0000-0000-0000-000000000018',
  'confirm_create', null,
  '{"identity_type":"show","display_name":"Synthetic Matchday Show"}'::jsonb,
  'Reviewed public evidence establishes a podcast Show.'
);
select pg_temp.assert_true(
  (
    select status = 'reopened'
    from public.news_identity_resolution_cases
    where id = '86600000-0000-0000-0000-000000000009'
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
    where decision.case_id = '86600000-0000-0000-0000-000000000017'
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
    where decision.case_id = '86600000-0000-0000-0000-000000000018'
      and decision.action = 'confirm_create'
      and decision.decision_origin = 'staff'
      and decision.decided_by_user_id = '86000000-0000-0000-0000-000000000001'
      and version.display_name = 'Synthetic Matchday Show'
      and version.is_current
  ),
  'authorized staff must create a Show through the actual review RPC with decision provenance'
);

rollback;
