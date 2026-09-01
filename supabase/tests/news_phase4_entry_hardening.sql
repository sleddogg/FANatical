-- Transactional proof for the Phase 4 entry gate. Fixtures are synthetic and
-- roll back. Canonical identity/content foundations are set up directly here;
-- their governed writer behavior is already proved by the Phase 2/3 suites.
-- Every Phase 4 operation and access-boundary assertion uses its real role.

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
    raise exception 'News Phase 4 entry assertion failed: %', message_value;
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
    raise exception 'News Phase 4 entry assertion failed: % (unexpected error: %)',
      message_value, sqlerrm;
  end;
  raise exception 'News Phase 4 entry assertion failed: % (statement unexpectedly succeeded)',
    message_value;
end;
$$;

create temporary table phase4_ids (
  key text primary key,
  value uuid not null
);
grant select, insert, update, delete on pg_temp.phase4_ids to authenticated;

create or replace function pg_temp.remember(key_value text, id_value uuid)
returns uuid
language plpgsql
as $$
begin
  insert into pg_temp.phase4_ids(key, value) values (key_value, id_value)
  on conflict (key) do update set value = excluded.value;
  return id_value;
end;
$$;

create or replace function pg_temp.id(key_value text)
returns uuid
language sql
stable
as $$
  select value from pg_temp.phase4_ids where key = key_value;
$$;

-- ---------------------------------------------------------------------------
-- Synthetic users, staff actor, publisher, and public News identities
-- ---------------------------------------------------------------------------

insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '90000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'phase4-admin@fanatical.invalid', '', now(),
    '{}'::jsonb, '{"display_name":"Phase 4 Admin"}'::jsonb, now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '90000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'phase4-fan@fanatical.invalid', '', now(),
    '{}'::jsonb, '{"display_name":"Phase 4 Fan"}'::jsonb, now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '90000000-0000-0000-0000-000000000003',
    'authenticated', 'authenticated', 'phase4-other@fanatical.invalid', '', now(),
    '{}'::jsonb, '{"display_name":"Phase 4 Other Fan"}'::jsonb, now(), now()
  );

insert into public.staff_roles(user_id, role, permissions, is_active)
values (
  '90000000-0000-0000-0000-000000000001',
  'content_admin', array[]::text[], true
);

insert into public.catalog_actors(
  id, actor_key, actor_type, auth_user_id, display_name, active
)
values (
  '90010000-0000-0000-0000-000000000001',
  'phase4-entry-admin', 'human',
  '90000000-0000-0000-0000-000000000001',
  'Phase 4 Entry Admin', true
);

insert into public.trusted_sources(
  id, source_id, display_name, base_url, review_status
)
values (
  '90100000-0000-0000-0000-000000000001',
  'phase4-wire-publisher', 'Phase 4 Wire Publisher',
  'https://phase4.example', 'suspended'
);

insert into public.trusted_source_url_scope_versions(
  id, source_id, hostname, include_subdomains, path_prefix,
  path_match, scope_kind, review_status
)
values (
  '90110000-0000-0000-0000-000000000001',
  '90100000-0000-0000-0000-000000000001',
  'phase4.example', false, '/', 'prefix', 'publisher', 'approved'
);

insert into public.catalog_people(id, person_id)
values
  (
    '90200000-0000-0000-0000-000000000001',
    'person-20000000000000000000000000000001'
  ),
  (
    '90200000-0000-0000-0000-000000000002',
    'person-20000000000000000000000000000002'
  ),
  (
    '90200000-0000-0000-0000-000000000003',
    'person-20000000000000000000000000000003'
  );

insert into public.person_identity_versions(person_id, public_name)
values
  ('90200000-0000-0000-0000-000000000001', 'Alex Original'),
  ('90200000-0000-0000-0000-000000000002', 'Alex Canonical'),
  ('90200000-0000-0000-0000-000000000003', 'Unfollowed Writer');

insert into public.news_author_profiles(id, author_id, person_id)
values
  (
    '90210000-0000-0000-0000-000000000001',
    'author-20000000000000000000000000000001',
    '90200000-0000-0000-0000-000000000001'
  ),
  (
    '90210000-0000-0000-0000-000000000002',
    'author-20000000000000000000000000000002',
    '90200000-0000-0000-0000-000000000002'
  ),
  (
    '90210000-0000-0000-0000-000000000003',
    'author-20000000000000000000000000000003',
    '90200000-0000-0000-0000-000000000003'
  );

insert into public.news_organizational_contributors(id, contributor_id)
values (
  '90300000-0000-0000-0000-000000000001',
  'organization-30000000000000000000000000000001'
);
insert into public.news_organizational_contributor_versions(
  organizational_contributor_id, display_name
)
values (
  '90300000-0000-0000-0000-000000000001',
  'Phase 4 Wire Service'
);

insert into public.news_official_team_publication_versions(
  id, publisher_source_id, team_id, organizational_contributor_id,
  relationship_type, effective_from, notes
)
select
  '90310000-0000-0000-0000-000000000001',
  '90100000-0000-0000-0000-000000000001', team.id,
  '90300000-0000-0000-0000-000000000001',
  'official_newsroom', '2026-08-01 00:00:00+00',
  'Synthetic current official Team newsroom relationship.'
from public.catalog_teams team where team.team_id = 'hockey-000027';

insert into public.podcast_shows(id, show_id)
values (
  '90400000-0000-0000-0000-000000000001',
  'show-40000000000000000000000000000001'
);
insert into public.podcast_show_identity_versions(show_id, display_name)
values (
  '90400000-0000-0000-0000-000000000001',
  'Phase 4 Hockey Show'
);

-- A suspended publisher policy exists deliberately. It must affect neither
-- individual followability nor feed eligibility.
insert into public.news_publisher_policy_versions(
  publisher_source_id, news_status, notes
)
values (
  '90100000-0000-0000-0000-000000000001',
  'suspended', 'Synthetic proof that publisher policy is not feed eligibility.'
);

insert into public.news_content_decisions(
  id, action, decision_origin, decided_by_user_id, decided_by_actor_id,
  source_publisher_id, notes
)
values (
  '90500000-0000-0000-0000-000000000001',
  'create_item', 'staff',
  '90000000-0000-0000-0000-000000000001',
  '90010000-0000-0000-0000-000000000001',
  '90100000-0000-0000-0000-000000000001',
  'Synthetic Phase 4 fixture decision.'
);

insert into public.news_content_evidence(
  id, evidence_kind, evidence_url, publisher_source_id,
  source_url_scope_version_id, evidence_summary, observed_at,
  recorded_by_decision_id
)
values (
  '90510000-0000-0000-0000-000000000001',
  'source_publication_time',
  'https://phase4.example/evidence',
  '90100000-0000-0000-0000-000000000001',
  '90110000-0000-0000-0000-000000000001',
  'Synthetic visible News evidence.',
  '2026-08-01 00:00:00+00',
  '90500000-0000-0000-0000-000000000001'
);

create or replace function pg_temp.create_phase4_item(
  item_key_value text,
  item_id_value uuid,
  item_public_id_value text,
  item_kind_value text,
  headline_value text,
  publication_time_value timestamptz,
  person_id_value uuid,
  organization_id_value uuid,
  show_id_value uuid,
  classification_type_value text
)
returns void
language plpgsql
as $$
declare
  manifestation_uuid uuid := gen_random_uuid();
  manifestation_url_uuid uuid := gen_random_uuid();
  mention_uuid uuid;
  ordinal_value integer := 0;
  classification_uuid uuid;
  sport_uuid uuid;
  competition_uuid uuid;
  team_uuid uuid;
begin
  insert into public.news_items(
    id, news_item_id, item_kind, created_by_decision_id
  ) values (
    item_id_value, item_public_id_value, item_kind_value,
    '90500000-0000-0000-0000-000000000001'
  );
  insert into public.news_item_versions(
    news_item_id, version_number, headline, summary, publication_state,
    publication_time, publication_time_evidence_id, recorded_from, decision_id
  ) values (
    item_id_value, 1, headline_value, 'Synthetic fan-safe summary.', 'published',
    publication_time_value, '90510000-0000-0000-0000-000000000001',
    publication_time_value, '90500000-0000-0000-0000-000000000001'
  );
  if item_kind_value = 'podcast_episode' then
    insert into public.news_podcast_episodes(
      news_item_id, show_id, episode_identifier, created_by_decision_id
    ) values (
      item_id_value, show_id_value, 'episode-' || item_key_value,
      '90500000-0000-0000-0000-000000000001'
    );
  end if;
  insert into public.news_manifestations(
    id, publisher_source_id, manifestation_kind, first_observed_at,
    source_reference, primary_evidence_id, created_by_decision_id
  ) values (
    manifestation_uuid,
    '90100000-0000-0000-0000-000000000001',
    case when item_kind_value = 'podcast_episode'
      then 'podcast_episode_page' else 'written_article' end,
    publication_time_value, item_key_value,
    '90510000-0000-0000-0000-000000000001',
    '90500000-0000-0000-0000-000000000001'
  );
  insert into public.news_manifestation_urls(
    id, manifestation_id, url_kind, url, normalized_url,
    is_public_destination, primary_evidence_id, created_by_decision_id
  ) values (
    manifestation_url_uuid, manifestation_uuid, 'canonical',
    'https://phase4.example/' || item_key_value,
    'https://phase4.example/' || item_key_value,
    true, '90510000-0000-0000-0000-000000000001',
    '90500000-0000-0000-0000-000000000001'
  );
  insert into public.news_manifestation_assignment_versions(
    manifestation_id, news_item_id, recorded_from,
    primary_evidence_id, decision_id
  ) values (
    manifestation_uuid, item_id_value, publication_time_value,
    '90510000-0000-0000-0000-000000000001',
    '90500000-0000-0000-0000-000000000001'
  );
  insert into public.news_representative_destination_versions(
    news_item_id, manifestation_id, manifestation_url_id, recorded_from,
    primary_evidence_id, decision_id
  ) values (
    item_id_value, manifestation_uuid, manifestation_url_uuid,
    publication_time_value, '90510000-0000-0000-0000-000000000001',
    '90500000-0000-0000-0000-000000000001'
  );

  if person_id_value is not null then
    ordinal_value := ordinal_value + 1;
    mention_uuid := gen_random_uuid();
    insert into public.news_byline_mentions(
      id, manifestation_id, ordinal, raw_attribution,
      primary_evidence_id, created_by_decision_id
    ) values (
      mention_uuid, manifestation_uuid, ordinal_value, 'Alex Original',
      '90510000-0000-0000-0000-000000000001',
      '90500000-0000-0000-0000-000000000001'
    );
    insert into public.news_byline_resolution_versions(
      byline_mention_id, target_identity_type, person_id,
      resolution_basis, recorded_from, decision_id
    ) values (
      mention_uuid, 'person', person_id_value,
      'visible_public_attribution', publication_time_value,
      '90500000-0000-0000-0000-000000000001'
    );
    perform pg_temp.remember('byline_person_' || item_key_value, mention_uuid);
  end if;
  if organization_id_value is not null then
    ordinal_value := ordinal_value + 1;
    mention_uuid := gen_random_uuid();
    insert into public.news_byline_mentions(
      id, manifestation_id, ordinal, raw_attribution,
      primary_evidence_id, created_by_decision_id
    ) values (
      mention_uuid, manifestation_uuid, ordinal_value, 'Phase 4 Wire Service',
      '90510000-0000-0000-0000-000000000001',
      '90500000-0000-0000-0000-000000000001'
    );
    insert into public.news_byline_resolution_versions(
      byline_mention_id, target_identity_type,
      organizational_contributor_id, resolution_basis,
      recorded_from, decision_id
    ) values (
      mention_uuid, 'organization', organization_id_value,
      'visible_public_attribution', publication_time_value,
      '90500000-0000-0000-0000-000000000001'
    );
    perform pg_temp.remember('byline_org_' || item_key_value, mention_uuid);
  end if;
  if show_id_value is not null then
    ordinal_value := ordinal_value + 1;
    mention_uuid := gen_random_uuid();
    insert into public.news_byline_mentions(
      id, manifestation_id, ordinal, raw_attribution,
      primary_evidence_id, created_by_decision_id
    ) values (
      mention_uuid, manifestation_uuid, ordinal_value, 'Phase 4 Hockey Show',
      '90510000-0000-0000-0000-000000000001',
      '90500000-0000-0000-0000-000000000001'
    );
    insert into public.news_byline_resolution_versions(
      byline_mention_id, target_identity_type, show_id,
      resolution_basis, recorded_from, decision_id
    ) values (
      mention_uuid, 'show', show_id_value,
      'visible_public_attribution', publication_time_value,
      '90500000-0000-0000-0000-000000000001'
    );
    perform pg_temp.remember('byline_show_' || item_key_value, mention_uuid);
  end if;

  if classification_type_value is not null then
    select id into sport_uuid from public.catalog_sports where sport_id = 'hockey';
    select id into competition_uuid from public.catalog_competitions
    where competition_id = 'hockey-nhl';
    select id into team_uuid from public.catalog_teams where team_id = 'hockey-000027';
    classification_uuid := gen_random_uuid();
    insert into public.news_item_classifications(
      id, news_item_id, created_by_decision_id
    ) values (
      classification_uuid, item_id_value,
      '90500000-0000-0000-0000-000000000001'
    );
    insert into public.news_item_classification_versions(
      classification_id, target_type, sport_id, competition_id, team_id,
      recorded_from, primary_evidence_id, decision_id
    ) values (
      classification_uuid, classification_type_value,
      case when classification_type_value = 'sport' then sport_uuid end,
      case when classification_type_value = 'competition' then competition_uuid end,
      case when classification_type_value = 'team' then team_uuid end,
      publication_time_value, '90510000-0000-0000-0000-000000000001',
      '90500000-0000-0000-0000-000000000001'
    );
  end if;

  perform pg_temp.remember('item_' || item_key_value, item_id_value);
  perform pg_temp.remember('manifestation_' || item_key_value, manifestation_uuid);
end;
$$;

select pg_temp.create_phase4_item(
  'shared', '90600000-0000-0000-0000-000000000001',
  'news-item-60000000000000000000000000000001', 'written',
  'Shared Author and Wire Story', '2026-08-04 12:00:00+00',
  '90200000-0000-0000-0000-000000000001',
  '90300000-0000-0000-0000-000000000001', null, 'team'
);
select pg_temp.create_phase4_item(
  'person', '90600000-0000-0000-0000-000000000002',
  'news-item-60000000000000000000000000000002', 'written',
  'Author Only Story', '2026-08-03 12:00:00+00',
  '90200000-0000-0000-0000-000000000001', null, null, 'sport'
);
select pg_temp.create_phase4_item(
  'wire', '90600000-0000-0000-0000-000000000003',
  'news-item-60000000000000000000000000000003', 'written',
  'Wire Only Story', '2026-08-03 12:00:00+00',
  null, '90300000-0000-0000-0000-000000000001', null, 'competition'
);
select pg_temp.create_phase4_item(
  'unclassified', '90600000-0000-0000-0000-000000000004',
  'news-item-60000000000000000000000000000004', 'written',
  'Later Classified Story', '2026-08-02 18:00:00+00',
  '90200000-0000-0000-0000-000000000001', null, null, null
);
select pg_temp.create_phase4_item(
  'podcast', '90600000-0000-0000-0000-000000000005',
  'news-item-60000000000000000000000000000005', 'podcast_episode',
  'Real Podcast Variant', '2026-08-02 12:00:00+00',
  null, null, '90400000-0000-0000-0000-000000000001', 'sport'
);
select pg_temp.create_phase4_item(
  'unfollowed', '90600000-0000-0000-0000-000000000006',
  'news-item-60000000000000000000000000000006', 'written',
  'Unfollowed Writer Story', '2026-08-05 12:00:00+00',
  '90200000-0000-0000-0000-000000000003', null, null, 'sport'
);

insert into public.news_remote_preview_references(
  id, manifestation_id, preview_kind, remote_url, alt_text,
  created_by_decision_id
)
values (
  '90620000-0000-0000-0000-000000000001',
  pg_temp.id('manifestation_shared'), 'image',
  'https://phase4.example/previews/shared.jpg',
  'Players gathering beside the rink before practice.',
  '90500000-0000-0000-0000-000000000001'
);
insert into public.news_remote_preview_policy_versions(
  id, preview_reference_id, publisher_policy_state, primary_evidence_id,
  recorded_from, decision_id
)
values (
  '90630000-0000-0000-0000-000000000001',
  '90620000-0000-0000-0000-000000000001', 'approved',
  '90510000-0000-0000-0000-000000000001',
  '2026-08-04 12:00:00+00',
  '90500000-0000-0000-0000-000000000001'
);

-- ---------------------------------------------------------------------------
-- BL-027 and staff-governed Phase 4 configuration under the real role
-- ---------------------------------------------------------------------------

select private.assert_news_domain_mutation_registry();

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001', true
);
set local role authenticated;
select public.admin_set_news_identity_followability(
  'author', 'author-20000000000000000000000000000001', true,
  'Synthetic Phase 4 Author is approved for follow testing.'
);
select public.admin_set_news_identity_followability(
  'author', 'author-20000000000000000000000000000002', true,
  'Synthetic canonical Author is approved for merge testing.'
);
select public.admin_set_news_identity_followability(
  'organization', 'organization-30000000000000000000000000000001', true,
  'Synthetic wire organization is approved for follow testing.'
);
select public.admin_set_news_identity_followability(
  'show', 'show-40000000000000000000000000000001', true,
  'Synthetic Show is approved for follow testing.'
);
select public.admin_set_news_demo_universe(
  '[
    {"target_type":"organization","target_id":"organization-30000000000000000000000000000001"},
    {"target_type":"show","target_id":"show-40000000000000000000000000000001"}
  ]'::jsonb,
  'Synthetic bounded Phase 4 Demo universe.'
);
reset role;

select pg_temp.assert_true(
  (select count(*) = 64 from private.news_domain_mutation_registry()),
  'BL-027 must retain all Phase 4 tables and register all three Phase 5A Request tables'
);

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000003', true
);
set local role authenticated;
select pg_temp.assert_true(
  (
    select count(*) = 1
      and max(headline) = 'Shared Author and Wire Story'
    from public.get_my_news_zero_follow_example(
      'hockey-nhl-edmonton-oilers'
    )
  ),
  'a zero-follow fan must receive at most the latest usable real Item from a current followable official Team newsroom identity'
);
select pg_temp.assert_true(
  pg_get_functiondef(
    'public.get_my_news_zero_follow_example(text)'::regprocedure
  ) ~ $$relationship\.relationship_type\s*=\s*'official_newsroom'$$,
  'the zero-follow EXAMPLE must not substitute an official publication or Team-site relationship for the canonical official newsroom organization'
);
reset role;

-- ---------------------------------------------------------------------------
-- Individual-only follows, scope OR behavior, chronology, filters, and wire
-- eligibility independent from publisher policy
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000002', true
);
set local role authenticated;
select pg_temp.remember('follow_author', public.follow_news_identity(
  'author', 'author-20000000000000000000000000000001',
  array['hockey'], array[]::text[]
));
select pg_temp.remember('follow_wire', public.follow_news_identity(
  'organization', 'organization-30000000000000000000000000000001'
));
select pg_temp.remember('follow_show', public.follow_news_identity(
  'show', 'show-40000000000000000000000000000001'
));
select pg_temp.assert_statement_rejected(
  $$select * from public.get_my_news_zero_follow_example(
    'hockey-000027'
  )$$,
  'zero follows',
  'the EXAMPLE read path must refuse a fan after the first actual follow exists'
);
select pg_temp.assert_statement_rejected(
  $$select public.follow_news_identity('publisher', 'phase4-wire-publisher')$$,
  'author, organization, or show',
  'publishers must never become follow targets'
);
select pg_temp.assert_true(
  (
    select array_agg(feed.news_item_id order by feed.publication_time desc, feed.news_item_id)
      = array[
        'news-item-60000000000000000000000000000001',
        'news-item-60000000000000000000000000000002',
        'news-item-60000000000000000000000000000003',
        'news-item-60000000000000000000000000000005'
      ]::text[]
    from public.get_my_news_feed('all', null, null, null, 20) feed
  ),
  'feed eligibility must use individual follows, scope intersection, stable ties, and strict original chronology'
);
select pg_temp.assert_true(
  (
    select preview_url = 'https://phase4.example/previews/shared.jpg'
      and preview_kind = 'image'
      and preview_alt_text = 'Players gathering beside the rink before practice.'
    from public.get_my_news_feed('all', null, null, null)
    where news_item_id = 'news-item-60000000000000000000000000000001'
  ),
  'the fan-safe feed must expose only an approved governed preview and its alt text'
);
select pg_temp.assert_true(
  (
    select display_name = 'Alex Original'
      and sport_scope_ids = array['hockey']::text[]
      and team_scope_ids = array[]::text[]
    from public.get_my_news_following()
    where target_type = 'author'
  ),
  'Following must expose owner-safe identity names and durable Sport/Team scope state'
);
select pg_temp.assert_true(
  (
    select array_agg(display_name order by display_name) = array[
      'Alex Canonical', 'Alex Original',
      'Phase 4 Hockey Show', 'Phase 4 Wire Service'
    ]::text[]
    from public.search_news_follow_targets()
    where display_name in (
      'Alex Canonical', 'Alex Original',
      'Phase 4 Hockey Show', 'Phase 4 Wire Service'
    )
  ),
  'unsearched Add to Feed discovery must be alphabetical and individual-only'
);
select pg_temp.assert_true(
  not exists (
    select 1
    from public.search_news_follow_targets() target
    where not (
      (target.target_type = 'author'
        and target.target_id ~ '^author-[0-9a-f]{32}$')
      or (target.target_type = 'organization'
        and target.target_id ~ '^organization-[0-9a-f]{32}$')
      or (target.target_type = 'show'
        and target.target_id ~ '^show-[0-9a-f]{32}$')
    )
  ),
  'the complete Add to Feed RPC contract must never expose a publication, publisher-follow, Follow All, or other aggregate target shape'
);
select pg_temp.assert_true(
  (
    select array_agg(display_name order by display_name) = array[
      'Phase 4 Hockey Show', 'Phase 4 Wire Service'
    ]::text[]
    from public.search_news_follow_targets('phase 4')
  ),
  'searched Add to Feed results must use relevant name matches with alphabetical ties'
);
select pg_temp.assert_true(
  (
    select array_agg(target_type || ':' || display_name order by display_name) = array[
      'author:Alex Original', 'organization:Phase 4 Wire Service'
    ]::text[]
    from public.search_news_follow_targets(
      null, 'hockey-nhl-edmonton-oilers'
    )
    where display_name in ('Alex Original', 'Phase 4 Wire Service')
  ),
  'Team discovery must resolve legacy Team IDs and list credited identities individually without Follow All'
);
select pg_temp.assert_true(
  (
    select count(*) = 1
    from public.get_my_news_feed('competition', 'hockey-nhl', null, null, 20)
    where news_item_id = 'news-item-60000000000000000000000000000003'
  ),
  'a temporary Competition filter must select the wire Item without becoming eligibility'
);
select pg_temp.assert_true(
  (
    select count(*) = 1
    from public.get_my_news_feed('team', 'hockey-000027', null, null, 20)
    where news_item_id = 'news-item-60000000000000000000000000000001'
  ),
  'a temporary Team filter must constrain already-eligible Items only'
);
select pg_temp.assert_true(
  (
    select count(*) = 1
    from public.get_my_news_feed(
      'team', 'hockey-nhl-edmonton-oilers', null, null
    )
    where news_item_id = 'news-item-60000000000000000000000000000001'
  ),
  'temporary Team filters must normalize an existing legacy frontend Team identifier without mutating global state'
);
select pg_temp.assert_true(
  (
    select count(*) = 1 and max(item_kind) = 'podcast_episode'
    from public.get_my_news_feed('all', null, null, null, 20)
    where news_item_id = 'news-item-60000000000000000000000000000005'
  ),
  'the production feed contract must carry a real podcast-episode variant'
);
select pg_temp.assert_true(
  position('news_publisher_policy' in lower(pg_get_functiondef(
    'private.get_news_feed_for_targets(uuid,jsonb,text,text,timestamptz,text,integer)'::regprocedure
  ))) = 0,
  'publisher News policy must not participate in the authoritative eligibility function'
);
select pg_temp.assert_true(
  position('user_settings' in lower(pg_get_functiondef(
    'private.get_news_feed_for_targets(uuid,jsonb,text,text,timestamptz,text,integer)'::regprocedure
  ))) = 0,
  'temporary News filtering must not read or mutate global Team settings'
);
reset role;

-- A factual classification correction makes the Item eligible at its original
-- publication position, never at the top.
insert into public.news_item_classifications(
  id, news_item_id, created_by_decision_id
)
values (
  '90610000-0000-0000-0000-000000000004',
  pg_temp.id('item_unclassified'),
  '90500000-0000-0000-0000-000000000001'
);
insert into public.news_item_classification_versions(
  classification_id, target_type, team_id, recorded_from,
  primary_evidence_id, decision_id
)
select
  '90610000-0000-0000-0000-000000000004', 'team', team.id,
  statement_timestamp(), '90510000-0000-0000-0000-000000000001',
  '90500000-0000-0000-0000-000000000001'
from public.catalog_teams team where team.team_id = 'hockey-000027';

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000002', true
);
set local role authenticated;
select pg_temp.assert_true(
  (
    select array_position(
      array_agg(feed.news_item_id order by feed.publication_time desc, feed.news_item_id),
      'news-item-60000000000000000000000000000004'
    ) = 4
    from public.get_my_news_feed('all', null, null, null, 20) feed
  ),
  'classification correction must restore the Item at original chronology rather than boost it'
);
select pg_temp.assert_true(
  (
    select array_agg(feed.news_item_id order by feed.publication_time desc, feed.news_item_id)
      = array[
        'news-item-60000000000000000000000000000003',
        'news-item-60000000000000000000000000000004',
        'news-item-60000000000000000000000000000005'
      ]::text[]
    from public.get_my_news_feed(
      'all', null, '2026-08-03 12:00:00+00',
      'news-item-60000000000000000000000000000002', 20
    ) feed
  ),
  'feed cursor must preserve deterministic tie handling and original chronology'
);
reset role;

-- ---------------------------------------------------------------------------
-- BL-023: existing follows redirect, raw wording stays historical, links use
-- canonical identity, and canonical merging cannot create a duplicate follow
-- or duplicate card.
-- ---------------------------------------------------------------------------

insert into public.news_identity_resolution_cases(
  id, case_kind, proposed_identity_type, proposed_name,
  subject_person_id, unresolved_question, status,
  created_by_user_id
)
values (
  '90700000-0000-0000-0000-000000000001',
  'person_merge', 'human', 'Alex Canonical',
  '90200000-0000-0000-0000-000000000001',
  'Synthetic governed pair merge for Phase 4 feed integration.',
  'resolved_manual', '90000000-0000-0000-0000-000000000001'
);
insert into public.news_identity_resolution_decisions(
  id, case_id, action, decision_origin, result_identity_type,
  result_person_id, question_snapshot, action_payload_snapshot,
  notes, decided_by_user_id, decided_by_actor_id
)
values (
  '90710000-0000-0000-0000-000000000001',
  '90700000-0000-0000-0000-000000000001',
  'merge', 'staff', 'human',
  '90200000-0000-0000-0000-000000000002',
  'Synthetic governed pair merge for Phase 4 feed integration.',
  '{"identity_type":"human"}'::jsonb,
  'Existing Phase 2 proof establishes the governed merge boundary.',
  '90000000-0000-0000-0000-000000000001',
  '90010000-0000-0000-0000-000000000001'
);
update public.news_identity_resolution_cases
set opened_by_decision_id = '90710000-0000-0000-0000-000000000001'
where id = '90700000-0000-0000-0000-000000000001';
select private.set_news_person_pair_state(
  '90200000-0000-0000-0000-000000000001',
  '90200000-0000-0000-0000-000000000002',
  'merged', '90200000-0000-0000-0000-000000000002',
  '90710000-0000-0000-0000-000000000001'
);

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000002', true
);
set local role authenticated;
select pg_temp.assert_true(
  (
    select count(*) = 1
    from public.get_my_news_following()
    where target_type = 'author'
      and target_id = 'author-20000000000000000000000000000002'
  ),
  'an existing Author follow must resolve as one effective canonical follow after merge'
);
select pg_temp.assert_true(
  (
    select target_id = 'author-20000000000000000000000000000002'
      and display_name = 'Alex Canonical'
    from public.get_news_identity_profile(
      'author', 'author-20000000000000000000000000000001'
    )
  ),
  'an old Author profile target must resolve to the current canonical fan profile'
);
select pg_temp.assert_true(
  (
    select count(*) = 3
    from public.get_news_identity_items(
      'author', 'author-20000000000000000000000000000001'
    )
  ),
  'canonical contributor profiles must use the shared fan-safe target feed without Dismiss suppression'
);
select pg_temp.assert_statement_rejected(
  $$select public.follow_news_identity(
    'author', 'author-20000000000000000000000000000002'
  )$$,
  'already follows the current canonical author',
  'a merge must not permit a second effective follow of the canonical Author'
);
select pg_temp.assert_true(
  (
    select count(*) = 1
      and bool_and(bylines @> '[{"raw_attribution":"Alex Original","target_type":"author","target_id":"author-20000000000000000000000000000002"}]'::jsonb)
    from public.get_my_news_feed('all', null, null, null, 20)
    where news_item_id = 'news-item-60000000000000000000000000000001'
  ),
  'published wording must remain historical while the fan link resolves to the current canonical Author'
);
select pg_temp.assert_true(
  (
    select count(*) = 1
    from public.get_my_news_feed('all', null, null, null, 20)
    where news_item_id = 'news-item-60000000000000000000000000000001'
  ),
  'multiple qualifying identities and a person merge must still return one canonical card'
);
reset role;

select pg_temp.assert_true(
  (
    select raw_attribution = 'Alex Original'
    from public.news_byline_mentions
    where id = pg_temp.id('byline_person_shared')
  ),
  'governed person merge must not rewrite stored historical raw attribution'
);

-- The other fan follows only the canonical Author. This isolates disputed
-- identity eligibility from the undisputed organizational coauthor.
select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000003', true
);
set local role authenticated;
select pg_temp.remember('other_follow_author', public.follow_news_identity(
  'author', 'author-20000000000000000000000000000002'
));
reset role;

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001', true
);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_open_news_content_review_case(%L,%L::uuid,%L::uuid,%L,%L::jsonb,%L)',
    'attribution', pg_temp.id('item_shared')::text,
    pg_temp.id('manifestation_shared')::text,
    'Unstructured attribution review must fail.', '{}', 'Synthetic invalid path.'
  ),
  'structured byline identity subject',
  'freeform attribution context alone must never create a review case'
);
select pg_temp.remember('attribution_case',
  public.admin_open_news_attribution_review_case(
    pg_temp.id('item_shared'), pg_temp.id('manifestation_shared'),
    pg_temp.id('byline_person_shared'), 'person',
    '90200000-0000-0000-0000-000000000001',
    'Does this historical byline resolve to the intended person?',
    '{}'::jsonb, 'Synthetic subject-specific attribution review.'
  )
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000003', true
);
set local role authenticated;
select pg_temp.assert_true(
  not exists (
    select 1 from public.get_my_news_feed('all', null, null, null, 20)
    where news_item_id = 'news-item-60000000000000000000000000000001'
  ),
  'an open subject-specific attribution review must prevent eligibility through the disputed identity'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000002', true
);
set local role authenticated;
select pg_temp.assert_true(
  (
    select count(*) = 1
      and bool_and(
        bylines @> '[{"raw_attribution":"Alex Original","target_type":null,"target_id":null}]'::jsonb
      )
      and bool_and(
        bylines @> '[{"raw_attribution":"Phase 4 Wire Service","target_type":"organization"}]'::jsonb
      )
    from public.get_my_news_feed('all', null, null, null, 20)
    where news_item_id = 'news-item-60000000000000000000000000000001'
  ),
  'the Item must stay published through an undisputed coauthor while only the disputed link/control is removed'
);
select pg_temp.assert_true(
  not exists (
    select 1
    from public.get_my_news_feed('all', null, null, null, 20) feed,
      lateral jsonb_array_elements(feed.bylines) byline
    where byline ? 'unresolved_question' or byline ? 'review_case_id'
  ),
  'fan-safe feed rows must expose no review details'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001', true
);
set local role authenticated;
select public.admin_review_news_content_case(
  pg_temp.id('attribution_case'), 'resolve',
  '{"confirmed":true}'::jsonb,
  'Governed review confirms the historical identity relationship.'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000003', true
);
set local role authenticated;
select pg_temp.assert_true(
  exists (
    select 1 from public.get_my_news_feed('all', null, null, null, 20)
    where news_item_id = 'news-item-60000000000000000000000000000001'
  ),
  'governed attribution confirmation must restore canonical linking and eligibility'
);
reset role;

-- ---------------------------------------------------------------------------
-- Database-time mute, alternate-follow qualification, automatic expiry,
-- Dismiss/Undo, and per-fan isolation
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000002', true
);
set local role authenticated;
select public.mute_my_news_follow(pg_temp.id('follow_author'), '7_days');
select pg_temp.assert_true(
  (
    select muted_until between statement_timestamp() + interval '6 days 23 hours 59 minutes'
      and statement_timestamp() + interval '7 days 1 minute'
    from public.get_my_news_following()
    where follow_ids @> array[pg_temp.id('follow_author')]
  ),
  '7-day mute must be calculated from database statement time'
);
select pg_temp.assert_true(
  not exists (
    select 1 from public.get_my_news_feed('all', null, null, null, 20)
    where news_item_id = 'news-item-60000000000000000000000000000002'
  ) and exists (
    select 1 from public.get_my_news_feed('all', null, null, null, 20)
    where news_item_id = 'news-item-60000000000000000000000000000001'
  ),
  'mute must exclude the identity while another unmuted followed identity may still qualify the same Item'
);
reset role;

-- Simulate database-time passage; no recovery job runs.
update public.user_news_identity_follows
set muted_until = statement_timestamp() - interval '1 second'
where id = pg_temp.id('follow_author');

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000002', true
);
set local role authenticated;
select pg_temp.assert_true(
  exists (
    select 1 from public.get_my_news_feed('all', null, null, null, 20)
    where news_item_id = 'news-item-60000000000000000000000000000002'
  ),
  'expired mute must resume automatically without a background job'
);
select public.mute_my_news_follow(pg_temp.id('follow_author'), '30_days');
select pg_temp.assert_true(
  (
    select muted_until between statement_timestamp() + interval '29 days 23 hours 59 minutes'
      and statement_timestamp() + interval '30 days 1 minute'
    from public.get_my_news_following()
    where follow_ids @> array[pg_temp.id('follow_author')]
  ),
  '30-day mute must be calculated from database statement time'
);
select public.unmute_my_news_follow(pg_temp.id('follow_author'));
select pg_temp.assert_true(
  (select muted_until is null from public.get_my_news_following()
   where follow_ids @> array[pg_temp.id('follow_author')]),
  'Unmute now must preserve the follow while clearing mute state'
);
select public.dismiss_news_item('news-item-60000000000000000000000000000001');
select pg_temp.assert_true(
  not exists (
    select 1 from public.get_my_news_feed('all', null, null, null, 20)
    where news_item_id = 'news-item-60000000000000000000000000000001'
  ),
  'Dismiss must hide one canonical Item only for its fan'
);
select public.undo_news_item_dismissal('news-item-60000000000000000000000000000001');
select pg_temp.assert_true(
  (
    select (array_agg(news_item_id order by publication_time desc, news_item_id))[1]
      = 'news-item-60000000000000000000000000000001'
    from public.get_my_news_feed('all', null, null, null, 20)
  ),
  'Undo must restore the Item at its original chronological position'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000003', true
);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  format('select public.mute_my_news_follow(%L::uuid,%L)',
    pg_temp.id('follow_author')::text, '7_days'),
  '',
  'another fan must not mutate someone else''s follow'
);
select pg_temp.assert_true(
  exists (
    select 1 from public.get_my_news_feed('all', null, null, null, 20)
    where news_item_id = 'news-item-60000000000000000000000000000001'
  ),
  'one fan''s Dismiss state must not leak to another fan'
);
reset role;

-- ---------------------------------------------------------------------------
-- Legacy merge-graph recovery. A synthetic pre-guard conflict is inserted by
-- the test owner only after the governed writer has been proved elsewhere.
-- Browser roles must keep the exact original follow manageable without ever
-- asserting either conflicting target as canonical.
-- ---------------------------------------------------------------------------

insert into public.catalog_people(id, person_id)
values
  (
    '90200000-0000-0000-0000-000000000010',
    'person-20000000000000000000000000000010'
  ),
  (
    '90200000-0000-0000-0000-000000000011',
    'person-20000000000000000000000000000011'
  ),
  (
    '90200000-0000-0000-0000-000000000012',
    'person-20000000000000000000000000000012'
  );
insert into public.person_identity_versions(person_id, public_name)
values
  ('90200000-0000-0000-0000-000000000010', 'Legacy Original'),
  ('90200000-0000-0000-0000-000000000011', 'Legacy Candidate One'),
  ('90200000-0000-0000-0000-000000000012', 'Legacy Candidate Two');
insert into public.news_author_profiles(id, author_id, person_id)
values
  (
    '90210000-0000-0000-0000-000000000010',
    'author-20000000000000000000000000000010',
    '90200000-0000-0000-0000-000000000010'
  ),
  (
    '90210000-0000-0000-0000-000000000011',
    'author-20000000000000000000000000000011',
    '90200000-0000-0000-0000-000000000011'
  ),
  (
    '90210000-0000-0000-0000-000000000012',
    'author-20000000000000000000000000000012',
    '90200000-0000-0000-0000-000000000012'
  );

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001', true
);
set local role authenticated;
select public.admin_set_news_identity_followability(
  'author', 'author-20000000000000000000000000000010', true,
  'Synthetic identity is enabled before the legacy-corruption recovery proof.'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000002', true
);
set local role authenticated;
select pg_temp.remember('legacy_corrupt_follow', public.follow_news_identity(
  'author', 'author-20000000000000000000000000000010'
));
reset role;

insert into public.news_identity_resolution_cases(
  id, case_kind, proposed_identity_type, proposed_name,
  subject_person_id, unresolved_question, status, created_by_user_id
)
values
  (
    '90700000-0000-0000-0000-000000000010',
    'person_merge', 'human', 'Legacy Candidate One',
    '90200000-0000-0000-0000-000000000010',
    'Synthetic legacy graph conflict one.', 'resolved_manual',
    '90000000-0000-0000-0000-000000000001'
  ),
  (
    '90700000-0000-0000-0000-000000000011',
    'person_merge', 'human', 'Legacy Candidate Two',
    '90200000-0000-0000-0000-000000000010',
    'Synthetic legacy graph conflict two.', 'resolved_manual',
    '90000000-0000-0000-0000-000000000001'
  );
insert into public.news_identity_resolution_decisions(
  id, case_id, action, decision_origin, result_identity_type,
  result_person_id, question_snapshot, action_payload_snapshot,
  notes, decided_by_user_id, decided_by_actor_id
)
values
  (
    '90710000-0000-0000-0000-000000000010',
    '90700000-0000-0000-0000-000000000010',
    'merge', 'staff', 'human',
    '90200000-0000-0000-0000-000000000011',
    'Synthetic legacy graph conflict one.', '{"identity_type":"human"}'::jsonb,
    'Synthetic pre-guard legacy row.',
    '90000000-0000-0000-0000-000000000001',
    '90010000-0000-0000-0000-000000000001'
  ),
  (
    '90710000-0000-0000-0000-000000000011',
    '90700000-0000-0000-0000-000000000011',
    'merge', 'staff', 'human',
    '90200000-0000-0000-0000-000000000012',
    'Synthetic legacy graph conflict two.', '{"identity_type":"human"}'::jsonb,
    'Synthetic pre-guard legacy row.',
    '90000000-0000-0000-0000-000000000001',
    '90010000-0000-0000-0000-000000000001'
  );
update public.news_identity_resolution_cases resolution_case
set opened_by_decision_id = case resolution_case.id
  when '90700000-0000-0000-0000-000000000010'::uuid
    then '90710000-0000-0000-0000-000000000010'::uuid
  else '90710000-0000-0000-0000-000000000011'::uuid
end
where resolution_case.id in (
  '90700000-0000-0000-0000-000000000010',
  '90700000-0000-0000-0000-000000000011'
);

-- Direct owner inserts simulate rows predating the shared writer guard. The
-- ordinary browser roles proved below retain no base-table write privilege.
insert into public.news_person_pair_state_periods(
  person_a_id, person_b_id, state, canonical_person_id,
  effective_from, opened_by_decision_id
)
values
  (
    '90200000-0000-0000-0000-000000000010',
    '90200000-0000-0000-0000-000000000011',
    'merged', '90200000-0000-0000-0000-000000000011',
    '2026-08-29T10:10:00Z',
    '90710000-0000-0000-0000-000000000010'
  ),
  (
    '90200000-0000-0000-0000-000000000010',
    '90200000-0000-0000-0000-000000000012',
    'merged', '90200000-0000-0000-0000-000000000012',
    '2026-08-29T10:11:00Z',
    '90710000-0000-0000-0000-000000000011'
  );

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000001', true
);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  $$select public.resolve_news_canonical_person(
    '90200000-0000-0000-0000-000000000010'
  )$$,
  'conflicting canonical identities',
  'the raising resolver must retain staff diagnostics for malformed legacy graphs'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000002', true
);
set local role authenticated;
select pg_temp.assert_true(
  (
    select count(*) = 1
      and bool_and(target_id = 'author-20000000000000000000000000000010')
      and bool_and(display_name = 'Legacy Original')
      and bool_and(needs_reselection)
      and bool_and(follow_ids = array[pg_temp.id('legacy_corrupt_follow')])
    from public.get_my_news_following()
    where follow_ids @> array[pg_temp.id('legacy_corrupt_follow')]
  )
  and exists (
    select 1
    from public.get_my_news_following()
    where target_type = 'organization'
      and target_id = 'organization-30000000000000000000000000000001'
  ),
  'Following must retain the exact corrupt original without a false canonical identity while other follows still load'
);
select pg_temp.assert_true(
  exists (
    select 1 from public.get_my_news_feed('all', null, null, null, 20)
    where news_item_id = 'news-item-60000000000000000000000000000003'
  )
  and exists (
    select 1 from public.search_news_follow_targets(null, null)
    where target_type = 'organization'
      and target_id = 'organization-30000000000000000000000000000001'
  ),
  'one unresolvable follow must not abort valid feed Items or Add to Feed discovery'
);
select public.mute_my_news_follow(pg_temp.id('legacy_corrupt_follow'), '7_days');
select pg_temp.assert_true(
  (
    select muted_until is not null
    from public.get_my_news_following()
    where follow_ids @> array[pg_temp.id('legacy_corrupt_follow')]
  ),
  'the exact fan-owned corrupt follow must remain mutable without canonical Resolution'
);
select pg_temp.assert_statement_rejected(
  format(
    'update public.user_news_identity_follows set muted_until = null where id = %L::uuid',
    pg_temp.id('legacy_corrupt_follow')::text
  ),
  'permission denied',
  'browser roles must retain no direct follow-table write path during recovery'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000003', true
);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  format(
    'select public.unmute_my_news_follow(%L::uuid)',
    pg_temp.id('legacy_corrupt_follow')::text
  ),
  '',
  'another fan must not use exact-ID legacy recovery to unmute someone else''s follow'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.unfollow_news_identity(%L::uuid)',
    pg_temp.id('legacy_corrupt_follow')::text
  ),
  '',
  'another fan must not use exact-ID legacy recovery to unfollow someone else''s identity'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000002', true
);
set local role authenticated;
select public.unmute_my_news_follow(pg_temp.id('legacy_corrupt_follow'));
select public.unfollow_news_identity(pg_temp.id('legacy_corrupt_follow'));
select pg_temp.assert_true(
  not exists (
    select 1 from public.get_my_news_following()
    where follow_ids @> array[pg_temp.id('legacy_corrupt_follow')]
  )
  and exists (
    select 1 from public.get_my_news_feed('all', null, null, null, 20)
    where news_item_id = 'news-item-60000000000000000000000000000003'
  ),
  'the owner must be able to remove the exact corrupt follow while valid follows and feed Items continue'
);
reset role;

-- Exercise the service-only legacy destination diagnostic with a row that is
-- preserved by a transactional drop/re-add of the NOT VALID check. New bad
-- rows remain rejected after the check is restored.
alter table public.news_manifestation_urls
  drop constraint news_manifestation_public_destination_kind_check;
insert into public.news_manifestation_urls(
  id, manifestation_id, url_kind, url, normalized_url,
  is_public_destination, primary_evidence_id, created_by_decision_id
)
values (
  '90520000-0000-0000-0000-000000000010',
  pg_temp.id('manifestation_shared'), 'wrapper',
  'https://phase4.example/legacy-wrapper',
  'https://phase4.example/legacy-wrapper', true,
  '90510000-0000-0000-0000-000000000001',
  '90500000-0000-0000-0000-000000000001'
);
alter table public.news_manifestation_urls
  add constraint news_manifestation_public_destination_kind_check
  check (
    not is_public_destination
    or url_kind in ('canonical', 'alternate')
  ) not valid;

set local role service_role;
select pg_temp.assert_true(
  (
    select count(*) = 1
    from private.news_manifestation_public_destination_kind_violations
    where id = '90520000-0000-0000-0000-000000000010'
      and url_kind = 'wrapper'
      and is_public_destination
  ),
  'the service-only diagnostic must identify each preserved legacy public wrapper row'
);
reset role;
select pg_temp.assert_statement_rejected(
  $$insert into public.news_manifestation_urls(
    id, manifestation_id, url_kind, url, normalized_url,
    is_public_destination, primary_evidence_id, created_by_decision_id
  ) values (
    '90520000-0000-0000-0000-000000000011',
    pg_temp.id('manifestation_shared'), 'redirect',
    'https://phase4.example/new-invalid-redirect',
    'https://phase4.example/new-invalid-redirect', true,
    '90510000-0000-0000-0000-000000000001',
    '90500000-0000-0000-0000-000000000001'
  )$$,
  'news_manifestation_public_destination_kind_check',
  'the NOT VALID caveat must preserve only legacy rows while rejecting every new bad destination'
);

-- ---------------------------------------------------------------------------
-- Safe anonymous Demo universe and real-role least-privilege boundaries
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', '', true);
set local role anon;
select pg_temp.assert_true(
  (select count(*) = 2 from public.get_news_demo_universe()),
  'anonymous Demo discovery must expose only the two governed configured identities'
);
select pg_temp.assert_true(
  exists (
    select 1 from public.get_news_navigation()
    where filter_type = 'team' and target_id = 'hockey-000027'
      and display_name = 'Edmonton Oilers'
  ),
  'anonymous filters must use fan-safe canonical Sport/Competition/Team navigation'
);
select pg_temp.assert_true(
  (
    select target_id = 'author-20000000000000000000000000000002'
    from public.get_news_identity_profile(
      'author', 'author-20000000000000000000000000000001'
    )
  ),
  'anonymous profile reads may expose the current canonical fan-safe identity only'
);
select pg_temp.assert_statement_rejected(
  $$select * from public.search_news_follow_targets()$$,
  'permission denied',
  'anonymous visitors must not enumerate the signed-in Add to Feed catalog'
);
select pg_temp.assert_true(
  (
    select count(*) = 2
    from public.get_news_demo_feed(
      '[{"target_type":"organization","target_id":"organization-30000000000000000000000000000001"}]'::jsonb,
      'all', null, null, null, 20
    )
  ),
  'anonymous Demo feed must use real published Items from a locally selected configured identity'
);
select pg_temp.assert_statement_rejected(
  $$select * from public.get_news_demo_feed(
    '[{"target_type":"author","target_id":"author-20000000000000000000000000000001"}]'::jsonb,
    'all', null, null, null, 20
  )$$,
  'configured universe',
  'anonymous callers must not widen Demo with an arbitrary identity'
);
select public.record_news_outbound_open(
  'news-item-60000000000000000000000000000001',
  'https://phase4.example/shared'
);
select pg_temp.assert_statement_rejected(
  $$select public.record_news_outbound_open(
    'news-item-60000000000000000000000000000001',
    'https://phase4.example/not-the-representative-destination'
  )$$,
  'query returned no rows',
  'outbound-open recording must revalidate the exact current representative destination'
);
select pg_temp.assert_statement_rejected(
  $$select public.follow_news_identity(
    'organization', 'organization-30000000000000000000000000000001'
  )$$,
  'permission denied',
  'anonymous Demo visitors must not create durable follows'
);
select pg_temp.assert_statement_rejected(
  $$select count(*) from public.user_news_identity_follows$$,
  'permission denied',
  'anonymous visitors must not read account-owned follow state'
);
select pg_temp.assert_statement_rejected(
  $$select count(*) from public.news_outbound_open_events$$,
  'permission denied',
  'anonymous visitors must not read outbound-open event history'
);
select pg_temp.assert_statement_rejected(
  $$select * from public.get_my_news_feed('all',null,null,null,20)$$,
  'permission denied',
  'anonymous visitors must not invoke the signed-in personal feed'
);
select pg_temp.assert_statement_rejected(
  $$select * from public.get_my_news_zero_follow_example('hockey-000027')$$,
  'permission denied',
  'anonymous visitors must not invoke the signed-in zero-follow EXAMPLE path'
);
reset role;

select pg_temp.assert_true(
  (
    select count(*) = 4
    from public.user_news_identity_follows
    where is_current
      and user_id in (
        '90000000-0000-0000-0000-000000000001',
        '90000000-0000-0000-0000-000000000002',
        '90000000-0000-0000-0000-000000000003'
      )
  ),
  'Demo follow/filter choices must write no durable account follow state'
);
select pg_temp.assert_true(
  (
    select count(*) = 1 and bool_and(viewer_user_id is null)
    from public.news_outbound_open_events
  ),
  'anonymous direct opening may append only a non-account outbound-open event'
);

select set_config(
  'request.jwt.claim.sub',
  '90000000-0000-0000-0000-000000000002', true
);
set local role authenticated;
select pg_temp.assert_statement_rejected(
  $$select count(*) from public.user_news_identity_follows$$,
  'permission denied',
  'ordinary fans must not bypass owner-scoped follow reads through the base table'
);
select public.record_news_outbound_open(
  'news-item-60000000000000000000000000000001',
  'https://phase4.example/shared'
);
select pg_temp.assert_statement_rejected(
  $$select count(*) from public.news_outbound_open_events$$,
  'permission denied',
  'ordinary fans must not read outbound-open event history'
);
select pg_temp.assert_statement_rejected(
  $$select public.admin_set_news_demo_universe('[]'::jsonb, 'Fan attempt')$$,
  'staff access',
  'ordinary fans must not change the governed Demo universe'
);
reset role;

select pg_temp.assert_true(
  (
    select count(*) = 2
      and count(*) filter (
        where viewer_user_id = '90000000-0000-0000-0000-000000000002'
      ) = 1
    from public.news_outbound_open_events
  ),
  'best-effort outbound-open events must retain anonymous versus signed-in provenance without becoming publisher views'
);
select pg_temp.assert_statement_rejected(
  $$update public.news_outbound_open_events set opened_at = statement_timestamp()$$,
  'immutable',
  'outbound-open event history must be immutable'
);

select pg_temp.assert_true(
  not has_function_privilege(
    'anon',
    'public.admin_open_news_attribution_review_case(uuid,uuid,uuid,text,uuid,text,jsonb,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.admin_set_news_identity_followability(text,text,boolean,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'anon',
    'public.get_news_demo_feed(jsonb,text,text,timestamptz,text,integer)',
    'EXECUTE'
  ),
  'real role grants must separate anonymous Demo reads from staff configuration and review writes'
);

rollback;
