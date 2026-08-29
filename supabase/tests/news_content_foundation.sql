-- Transactional proof for FANatical News Phase 3 canonical content,
-- chronology, history, dedupe, classification, and real-role staff access.
-- Every identity and content record created here is synthetic and rolls back.

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
    raise exception 'News content foundation assertion failed: %', message_value;
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
    raise exception 'News content foundation assertion failed: % (unexpected error: %)',
      message_value, sqlerrm;
  end;
  raise exception 'News content foundation assertion failed: % (statement unexpectedly succeeded)',
    message_value;
end;
$$;

create temporary table phase3_ids (
  key text primary key,
  value uuid not null
);
grant select, insert, update, delete on pg_temp.phase3_ids to authenticated;

create or replace function pg_temp.remember(key_value text, id_value uuid)
returns uuid
language plpgsql
as $$
begin
  insert into pg_temp.phase3_ids(key, value) values (key_value, id_value);
  return id_value;
end;
$$;

create or replace function pg_temp.id(key_value text)
returns uuid
language sql
stable
as $$
  select value from pg_temp.phase3_ids where key = key_value;
$$;

-- The helper calls the actual governed RPCs. It only removes repetitive
-- fixture plumbing; no canonical table write bypasses the real staff path.
create or replace function pg_temp.create_delivery(
  manifestation_key text,
  url_key text,
  item_id_value uuid,
  publisher_source_id_value uuid,
  manifestation_kind_value text,
  first_observed_at_value timestamptz,
  source_reference_value text,
  public_url_value text,
  manifestation_evidence_id_value uuid,
  destination_evidence_id_value uuid,
  choose_destination_value boolean default true
)
returns void
language plpgsql
as $$
declare manifestation_uuid uuid; url_uuid uuid;
begin
  manifestation_uuid := public.admin_create_news_manifestation(
    publisher_source_id_value,
    manifestation_kind_value,
    first_observed_at_value,
    source_reference_value,
    manifestation_evidence_id_value,
    'Synthetic Phase 3 manifestation fixture.'
  );
  perform pg_temp.remember(manifestation_key, manifestation_uuid);
  url_uuid := public.admin_add_news_manifestation_url(
    manifestation_uuid,
    'canonical',
    public_url_value,
    true,
    manifestation_evidence_id_value,
    'Synthetic Phase 3 canonical URL fixture.'
  );
  perform pg_temp.remember(url_key, url_uuid);
  if item_id_value is not null then
    perform public.admin_assign_news_manifestation(
      manifestation_uuid,
      item_id_value,
      manifestation_evidence_id_value,
      'Synthetic Phase 3 initial assignment.'
    );
    if choose_destination_value then
      perform public.admin_set_news_representative_destination(
        item_id_value,
        url_uuid,
        destination_evidence_id_value,
        'Synthetic Phase 3 initial representative destination.'
      );
    end if;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Synthetic security, publisher, Phase 2 identity, and canonical facts
-- ---------------------------------------------------------------------------

insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '88000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'phase3-admin@fanatical.invalid', '', now(),
    '{}'::jsonb, '{"display_name":"Phase 3 Admin"}'::jsonb, now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '88000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'phase3-fan@fanatical.invalid', '', now(),
    '{}'::jsonb, '{"display_name":"Phase 3 Fan"}'::jsonb, now(), now()
  );

insert into public.staff_roles(user_id, role, permissions, is_active)
values (
  '88000000-0000-0000-0000-000000000001',
  'content_admin', array[]::text[], true
);

insert into public.catalog_actors(
  id, actor_key, actor_type, auth_user_id, display_name, active
)
values
  (
    '88010000-0000-0000-0000-000000000001',
    'phase3-content-admin', 'human',
    '88000000-0000-0000-0000-000000000001',
    'Phase 3 Content Admin', true
  ),
  (
    '88010000-0000-0000-0000-000000000002',
    'phase3-governed-automation', 'service', null,
    'Phase 3 Governed Automation', true
  );

insert into public.trusted_sources(
  id, source_id, display_name, base_url, review_status
)
values
  (
    '88100000-0000-0000-0000-000000000001',
    'phase3-publisher-a', 'Phase 3 Publisher A',
    'https://phase3-a.example', 'approved'
  ),
  (
    '88100000-0000-0000-0000-000000000002',
    'phase3-wire-b', 'Phase 3 Wire B',
    'https://phase3-b.example', 'pending_review'
  ),
  (
    '88100000-0000-0000-0000-000000000003',
    'phase3-podcast-network', 'Phase 3 Podcast Network',
    'https://phase3-network.example', 'approved'
  );

insert into public.trusted_source_url_scope_versions(
  id, source_id, hostname, include_subdomains, path_prefix,
  path_match, scope_kind, review_status
)
values
  (
    '88110000-0000-0000-0000-000000000001',
    '88100000-0000-0000-0000-000000000001',
    'phase3-a.example', true, '/', 'prefix', 'publisher', 'approved'
  ),
  (
    '88110000-0000-0000-0000-000000000002',
    '88100000-0000-0000-0000-000000000002',
    'phase3-b.example', true, '/', 'prefix', 'publisher', 'approved'
  ),
  (
    '88110000-0000-0000-0000-000000000003',
    '88100000-0000-0000-0000-000000000003',
    'phase3-network.example', true, '/', 'prefix', 'publisher', 'approved'
  );

insert into public.source_trust_assignments(
  source_id, data_type, trust_tier, is_current
)
values (
  '88100000-0000-0000-0000-000000000001',
  'phase3-unrelated-factual-trust', 1, true
);

insert into public.catalog_people(id, person_id)
values (
  '88200000-0000-0000-0000-000000000001',
  'person-10000000000000000000000000000001'
);
insert into public.person_identity_versions(
  id, person_id, public_name, name_kind
)
values (
  '88210000-0000-0000-0000-000000000001',
  '88200000-0000-0000-0000-000000000001',
  'Alex Writer', 'professional_name'
);
insert into public.news_author_profiles(id, author_id, person_id)
values (
  '88220000-0000-0000-0000-000000000001',
  'author-10000000000000000000000000000001',
  '88200000-0000-0000-0000-000000000001'
);

insert into public.news_organizational_contributors(id, contributor_id)
values (
  '88230000-0000-0000-0000-000000000001',
  'organization-10000000000000000000000000000001'
);
insert into public.news_organizational_contributor_versions(
  organizational_contributor_id, display_name
)
values (
  '88230000-0000-0000-0000-000000000001',
  'Phase 3 Staff'
);

insert into public.podcast_shows(id, show_id)
values (
  '88240000-0000-0000-0000-000000000001',
  'show-10000000000000000000000000000001'
);
insert into public.podcast_show_identity_versions(show_id, display_name)
values (
  '88240000-0000-0000-0000-000000000001',
  'The Phase 3 Show'
);

insert into public.news_publisher_contributor_profiles(
  id, contributor_profile_id, publisher_source_id
)
values (
  '88250000-0000-0000-0000-000000000001',
  'contributor-profile-10000000000000000000000000000001',
  '88100000-0000-0000-0000-000000000001'
);
insert into public.news_publisher_contributor_profile_versions(
  contributor_profile_id, display_name, profile_url, person_id
)
values (
  '88250000-0000-0000-0000-000000000001',
  'Alex Writer', 'https://phase3-a.example/authors/alex-writer',
  '88200000-0000-0000-0000-000000000001'
);

-- Competition Edition and presentation group are controlled synthetic facts.
insert into public.catalog_competition_editions(
  id, edition_id, competition_id
)
values (
  '88300000-0000-0000-0000-000000000001',
  'phase3-nhl-2025-26',
  (select id from public.catalog_competitions where competition_id = 'hockey-nhl')
);
insert into public.competition_edition_versions(
  competition_edition_id, display_name, season_label,
  starts_on, ends_on, record_status
)
values (
  '88300000-0000-0000-0000-000000000001',
  'Phase 3 NHL 2025-26', '2025-26',
  '2025-10-01', '2026-06-30', 'verified'
);
insert into public.catalog_competition_filter_groups(
  id, filter_group_id, sport_id
)
values (
  '88310000-0000-0000-0000-000000000001',
  'phase3-presentation-only',
  (select id from public.catalog_sports where sport_id = 'hockey')
);

-- ---------------------------------------------------------------------------
-- Real-role denial before any staff write
-- ---------------------------------------------------------------------------

set local role anon;
select pg_temp.assert_statement_rejected(
  $statement$
    insert into public.news_items(item_kind, created_by_decision_id)
    values ('written', '00000000-0000-0000-0000-000000000001')
  $statement$,
  '',
  'anon must not insert canonical News Items'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_get_news_published_items_at('2100-01-01'::timestamptz)
  $statement$,
  '',
  'anon must not call the deterministic publication-time helper'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '88000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  (select count(*) = 0 from public.news_items),
  'ordinary authenticated fans must see no staff-only canonical News rows'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_record_news_content_evidence(
      'manifestation_identity',
      'https://phase3-a.example/ordinary-denied',
      '88100000-0000-0000-0000-000000000001',
      'Ordinary fan must not record this.',
      '2026-08-29'::timestamptz,
      null
    )
  $statement$,
  'staff access is required',
  'ordinary authenticated fans must not use the governed content write path'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_get_news_published_items_at('2100-01-01'::timestamptz)
  $statement$,
  'staff access is required',
  'ordinary authenticated fans must not call the deterministic publication-time helper'
);
reset role;

-- ---------------------------------------------------------------------------
-- Controlled records created only through the authorized staff path
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claim.sub',
  '88000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select pg_temp.assert_statement_rejected(
  $statement$
    insert into public.news_items(item_kind, created_by_decision_id)
    values ('written', '00000000-0000-0000-0000-000000000001')
  $statement$,
  '',
  'authorized staff must still use governed RPCs rather than direct table writes'
);

-- Evidence is URL-ownership validated but remains independent from trust tier,
-- review_status, applicability, and independence governance.
select pg_temp.remember('ev_pub_a', public.admin_record_news_content_evidence(
  'source_publication_time',
  'https://phase3-a.example/articles/source-times',
  '88100000-0000-0000-0000-000000000001',
  'Visible publisher timestamps for synthetic Phase 3 items.',
  '2026-08-29 10:00:00+00', null
));
select pg_temp.remember('ev_pub_b', public.admin_record_news_content_evidence(
  'source_publication_time',
  'https://phase3-b.example/wire/source-time',
  '88100000-0000-0000-0000-000000000002',
  'Visible wire timestamp for a synthetic manifestation.',
  '2026-08-29 10:01:00+00', null
));
select pg_temp.remember('ev_pub_network', public.admin_record_news_content_evidence(
  'source_publication_time',
  'https://phase3-network.example/episodes/source-time',
  '88100000-0000-0000-0000-000000000003',
  'Visible network timestamp for a synthetic podcast episode.',
  '2026-08-29 10:02:00+00', null
));
select pg_temp.remember('ev_manifest_a', public.admin_record_news_content_evidence(
  'manifestation_identity',
  'https://phase3-a.example/articles/manifestations',
  '88100000-0000-0000-0000-000000000001',
  'Publisher pages establishing synthetic manifestations and visible bylines.',
  '2026-08-29 10:03:00+00', null
));
select pg_temp.remember('ev_manifest_b', public.admin_record_news_content_evidence(
  'manifestation_identity',
  'https://phase3-b.example/wire/manifestations',
  '88100000-0000-0000-0000-000000000002',
  'Wire pages establishing synthetic manifestations.',
  '2026-08-29 10:04:00+00', null
));
select pg_temp.remember('ev_manifest_network', public.admin_record_news_content_evidence(
  'manifestation_identity',
  'https://phase3-network.example/episodes/manifestations',
  '88100000-0000-0000-0000-000000000003',
  'Network pages establishing a synthetic podcast manifestation.',
  '2026-08-29 10:05:00+00', null
));
select pg_temp.remember('ev_class', public.admin_record_news_content_evidence(
  'factual_classification',
  'https://phase3-a.example/articles/classification-evidence',
  '88100000-0000-0000-0000-000000000001',
  'Visible factual support for Hockey, NHL, Edition, and Edmonton classifications.',
  '2026-08-29 10:06:00+00', null
));
select pg_temp.remember('ev_dedupe_same', public.admin_record_news_content_evidence(
  'dedupe_relationship',
  'https://phase3-b.example/wire/syndication-evidence',
  '88100000-0000-0000-0000-000000000002',
  'Explicit wire attribution establishes a syndicated copy.',
  '2026-08-29 10:07:00+00', null
));
select pg_temp.remember('ev_dedupe_reverse', public.admin_record_news_content_evidence(
  'dedupe_relationship',
  'https://phase3-a.example/articles/correction-evidence',
  '88100000-0000-0000-0000-000000000001',
  'Later evidence establishes that a mistaken same-work assignment must be reversed.',
  '2026-08-29 10:08:00+00', null
));
select pg_temp.remember('ev_rep_a', public.admin_record_news_content_evidence(
  'representative_destination',
  'https://phase3-a.example/articles/destination-evidence',
  '88100000-0000-0000-0000-000000000001',
  'Staff-selected public destination on Publisher A.',
  '2026-08-29 10:09:00+00', null
));
select pg_temp.remember('ev_rep_b', public.admin_record_news_content_evidence(
  'representative_destination',
  'https://phase3-b.example/wire/destination-evidence',
  '88100000-0000-0000-0000-000000000002',
  'Staff-selected public destination on Wire B.',
  '2026-08-29 10:10:00+00', null
));
select pg_temp.remember('ev_rep_network', public.admin_record_news_content_evidence(
  'representative_destination',
  'https://phase3-network.example/episodes/destination-evidence',
  '88100000-0000-0000-0000-000000000003',
  'Staff-selected public podcast destination on the synthetic network.',
  '2026-08-29 10:10:30+00', null
));
select pg_temp.remember('ev_preview', public.admin_record_news_content_evidence(
  'remote_preview_reference',
  'https://phase3-a.example/articles/preview-evidence',
  '88100000-0000-0000-0000-000000000001',
  'Publisher page exposes a remote social preview reference.',
  '2026-08-29 10:11:00+00', null
));
select pg_temp.remember('ev_preview_block', public.admin_record_news_content_evidence(
  'remote_preview_reference',
  'https://phase3-a.example/articles/preview-takedown-evidence',
  '88100000-0000-0000-0000-000000000001',
  'Publisher policy evidence requires the previously approved preview to be blocked.',
  '2026-08-29 10:12:00+00', null
));

select pg_temp.assert_statement_rejected(
  $statement$
    select public.admin_record_news_content_evidence(
      'manifestation_identity',
      'https://phase3-b.example/wire/not-owned-by-a',
      '88100000-0000-0000-0000-000000000001',
      'Mismatched publisher evidence must fail.',
      '2026-08-29'::timestamptz,
      null
    )
  $statement$,
  'does not belong to the claimed publisher',
  'content evidence must mechanically prove publisher URL ownership'
);

-- Written, podcast, future, policy-state, eligibility-restoration, and
-- unresolved-destination Items all use one canonical creation path.
select pg_temp.remember('item_wire', public.admin_create_news_item(
  'written', 'Shared Event Story', 'Synthetic wire work.', 'published',
  '1985-01-01 12:00:00+00', pg_temp.id('ev_pub_a'),
  '88100000-0000-0000-0000-000000000001', null, null,
  'Staff-created old News Item.'
));
select pg_temp.remember('item_independent', public.admin_create_news_item(
  'written', 'Shared Event Story', 'Independent reporting on the same event.', 'published',
  '1985-01-01 12:00:00+00', pg_temp.id('ev_pub_a'),
  '88100000-0000-0000-0000-000000000001', null, null,
  'Independent journalism remains its own work.'
));
select pg_temp.remember('item_org', public.admin_create_news_item(
  'written', 'Organization-only Story', null, 'published',
  '2005-01-01 09:00:00+00', pg_temp.id('ev_pub_a'),
  '88100000-0000-0000-0000-000000000001', null, null,
  'Organizational contributor only.'
));
select pg_temp.remember('item_podcast', public.admin_create_news_item(
  'podcast_episode', 'Phase 3 Podcast Episode', 'Synthetic episode.', 'published',
  '2015-01-01 09:00:00+00', pg_temp.id('ev_pub_network'),
  '88100000-0000-0000-0000-000000000003',
  '88240000-0000-0000-0000-000000000001', 'episode-phase-3',
  'Show-linked podcast episode.'
));
select pg_temp.remember('item_future', public.admin_create_news_item(
  'written', 'Future Source Timestamp', null, 'published',
  '2099-01-01 00:00:00+00', pg_temp.id('ev_pub_b'),
  '88100000-0000-0000-0000-000000000002', null, null,
  'Confident future timestamp is valid.'
));
select pg_temp.remember('item_draft', public.admin_create_news_item(
  'written', 'Draft Story', null, 'draft',
  '2020-01-01 00:00:00+00', pg_temp.id('ev_pub_a'),
  '88100000-0000-0000-0000-000000000001', null, null, null
));
select pg_temp.remember('item_excluded', public.admin_create_news_item(
  'written', 'Excluded Story', null, 'excluded',
  '2020-01-02 00:00:00+00', pg_temp.id('ev_pub_a'),
  '88100000-0000-0000-0000-000000000001', null, null, null
));
select pg_temp.remember('item_suppressed', public.admin_create_news_item(
  'written', 'Suppressed Story', null, 'suppressed',
  '2020-01-03 00:00:00+00', pg_temp.id('ev_pub_a'),
  '88100000-0000-0000-0000-000000000001', null, null, null
));
select pg_temp.remember('item_review', public.admin_create_news_item(
  'written', 'Publication Time Needs Review', null, 'needs_review',
  null, null,
  '88100000-0000-0000-0000-000000000001', null, null,
  'Conflicting source time remains unresolved.'
));
select pg_temp.remember('item_eligibility', public.admin_create_news_item(
  'written', 'Eligibility Restoration Story', null, 'published',
  '2010-01-01 00:00:00+00', pg_temp.id('ev_pub_a'),
  '88100000-0000-0000-0000-000000000001', null, null, null
));
select pg_temp.remember('item_no_destination', public.admin_create_news_item(
  'written', 'Published Without Destination', null, 'published',
  '2024-01-01 00:00:00+00', pg_temp.id('ev_pub_a'),
  '88100000-0000-0000-0000-000000000001', null, null, null
));

select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_create_news_manifestation(%L::uuid, %L, %L::timestamptz, %L, %L::uuid, null)',
    '88100000-0000-0000-0000-000000000002',
    'written_article',
    '2026-08-29 10:30:00+00',
    'wrong-publisher-evidence',
    pg_temp.id('ev_manifest_a')::text
  ),
  'evidence publisher does not match this action source',
  'a manifestation must not use evidence owned by a different publisher'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_record_news_classification(%L::uuid, null, %L, %L::uuid, %L::uuid, null)',
    pg_temp.id('item_wire')::text,
    'sport',
    (select id::text from public.catalog_sports where sport_id = 'hockey'),
    pg_temp.id('ev_dedupe_same')::text
  ),
  'evidence kind does not support this action',
  'a governed action must reject the wrong evidence kind'
);

-- Primary wire manifestation and sticky first destination.
select pg_temp.create_delivery(
  'm_wire_a', 'url_wire_a', pg_temp.id('item_wire'),
  '88100000-0000-0000-0000-000000000001', 'written_article',
  '2026-08-29 11:00:00+00', 'wire-a-primary',
  'https://phase3-a.example/articles/shared-event',
  pg_temp.id('ev_manifest_a'), pg_temp.id('ev_rep_a'), true
);
select pg_temp.remember('url_wire_a_alt', public.admin_add_news_manifestation_url(
  pg_temp.id('m_wire_a'), 'alternate',
  'https://phase3-a.example/alternate/shared-event',
  true, pg_temp.id('ev_manifest_a'), 'Explicit alternate URL.'
));

-- A second manifestation exists first, is deduped explicitly, and is then
-- assigned to the same work. Adding it does not change the representative.
select pg_temp.create_delivery(
  'm_wire_b', 'url_wire_b', null,
  '88100000-0000-0000-0000-000000000002', 'syndicated_article',
  '2026-08-29 11:01:00+00', 'wire-b-syndicated',
  'https://phase3-b.example/wire/shared-event',
  pg_temp.id('ev_manifest_b'), pg_temp.id('ev_rep_b'), false
);
select pg_temp.remember('dedupe_wire', public.admin_record_news_deduplication(
  pg_temp.id('m_wire_a'), pg_temp.id('m_wire_b'), 'syndicated_copy',
  pg_temp.id('ev_dedupe_same'),
  'Visible wire credit establishes one underlying work.', null
));
select public.admin_assign_news_manifestation(
  pg_temp.id('m_wire_b'), pg_temp.id('item_wire'),
  pg_temp.id('ev_dedupe_same'), 'Assign explicit syndicated copy.'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_assign_news_manifestation(%L::uuid, %L::uuid, %L::uuid, %L)',
    pg_temp.id('m_wire_b')::text,
    pg_temp.id('item_independent')::text,
    pg_temp.id('ev_dedupe_reverse')::text,
    'A syndicated copy cannot be reassigned as a different work.'
  ),
  'syndicated-copy manifestations cannot be assigned to different news items',
  'assignment changes must not contradict a current syndicated-copy decision'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_record_news_deduplication(%L::uuid, %L::uuid, %L, %L::uuid, %L, null)',
    pg_temp.id('m_wire_a')::text,
    pg_temp.id('m_wire_b')::text,
    'independent_journalism',
    pg_temp.id('ev_dedupe_reverse')::text,
    'A non-atomic outcome change would contradict current assignments.'
  ),
  'independent-journalism manifestations cannot be assigned to the same news item',
  'a dedupe change must not contradict existing same-work assignments'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_record_news_deduplication(%L::uuid, %L::uuid, %L, %L::uuid, %L, null)',
    pg_temp.id('m_wire_a')::text,
    pg_temp.id('m_wire_b')::text,
    'needs_review',
    pg_temp.id('ev_dedupe_reverse')::text,
    'Review status cannot silently retain a same-work conclusion.'
  ),
  'needs-review manifestations cannot be assigned to the same news item',
  'needs-review must not silently establish a canonical same-work assignment'
);

select pg_temp.assert_true(
  (
    select manifestation_url_id = pg_temp.id('url_wire_a')
    from public.news_representative_destination_versions
    where news_item_id = pg_temp.id('item_wire') and is_current
  ),
  'adding a manifestation and URL must not automatically replace the sticky destination'
);
select pg_temp.remember('rep_wire_b', public.admin_set_news_representative_destination(
  pg_temp.id('item_wire'), pg_temp.id('url_wire_b'),
  pg_temp.id('ev_rep_b'), 'Governed representative change to the wire copy.'
));
select pg_temp.assert_true(
  (
    select count(*) = 2
      and count(*) filter (where is_current) = 1
      and bool_or(is_current and manifestation_url_id = pg_temp.id('url_wire_b'))
    from public.news_representative_destination_versions
    where news_item_id = pg_temp.id('item_wire')
  ),
  'a governed destination change must preserve the prior choice and select one new current destination'
);
select pg_temp.remember('rep_wire_a_restored', public.admin_set_news_representative_destination(
  pg_temp.id('item_wire'), pg_temp.id('url_wire_a'),
  pg_temp.id('ev_rep_a'), 'Governed representative restoration to the primary copy.'
));

-- Independent journalism with the same headline/event/time remains a separate
-- News Item and manifestation.
select pg_temp.create_delivery(
  'm_independent', 'url_independent', pg_temp.id('item_independent'),
  '88100000-0000-0000-0000-000000000001', 'written_article',
  '2026-08-29 11:02:00+00', 'independent-report',
  'https://phase3-a.example/articles/independent-shared-event',
  pg_temp.id('ev_manifest_a'), pg_temp.id('ev_rep_a'), true
);
select pg_temp.remember('dedupe_independent', public.admin_record_news_deduplication(
  pg_temp.id('m_wire_a'), pg_temp.id('m_independent'), 'independent_journalism',
  pg_temp.id('ev_dedupe_reverse'),
  'Separate reporting and sourcing establish independent journalism.', null
));
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_record_news_deduplication(%L::uuid, %L::uuid, %L, %L::uuid, %L, null)',
    pg_temp.id('m_wire_a')::text,
    pg_temp.id('m_independent')::text,
    'syndicated_copy',
    pg_temp.id('ev_dedupe_same')::text,
    'A syndicated conclusion cannot retain different-work assignments.'
  ),
  'syndicated-copy manifestations cannot be assigned to different news items',
  'a syndicated-copy decision must not contradict existing different-work assignments'
);

-- Remaining controlled delivery fixtures.
select pg_temp.create_delivery(
  'm_org', 'url_org', pg_temp.id('item_org'),
  '88100000-0000-0000-0000-000000000001', 'written_article',
  '2026-08-29 11:03:00+00', 'organization-only',
  'https://phase3-a.example/articles/organization-only',
  pg_temp.id('ev_manifest_a'), pg_temp.id('ev_rep_a'), true
);
select pg_temp.create_delivery(
  'm_podcast', 'url_podcast', pg_temp.id('item_podcast'),
  '88100000-0000-0000-0000-000000000003', 'podcast_episode_page',
  '2026-08-29 11:04:00+00', 'podcast-episode',
  'https://phase3-network.example/episodes/phase-3',
  pg_temp.id('ev_manifest_network'), pg_temp.id('ev_rep_network'), true
);
select pg_temp.create_delivery(
  'm_future', 'url_future', pg_temp.id('item_future'),
  '88100000-0000-0000-0000-000000000002', 'written_article',
  '2026-08-29 11:05:00+00', 'future-story',
  'https://phase3-b.example/wire/future-story',
  pg_temp.id('ev_manifest_b'), pg_temp.id('ev_rep_b'), true
);
select pg_temp.create_delivery(
  'm_draft', 'url_draft', pg_temp.id('item_draft'),
  '88100000-0000-0000-0000-000000000001', 'written_article',
  '2026-08-29 11:06:00+00', 'draft-story',
  'https://phase3-a.example/articles/draft-story',
  pg_temp.id('ev_manifest_a'), pg_temp.id('ev_rep_a'), true
);
select pg_temp.create_delivery(
  'm_excluded', 'url_excluded', pg_temp.id('item_excluded'),
  '88100000-0000-0000-0000-000000000001', 'written_article',
  '2026-08-29 11:07:00+00', 'excluded-story',
  'https://phase3-a.example/articles/excluded-story',
  pg_temp.id('ev_manifest_a'), pg_temp.id('ev_rep_a'), true
);
select pg_temp.create_delivery(
  'm_suppressed', 'url_suppressed', pg_temp.id('item_suppressed'),
  '88100000-0000-0000-0000-000000000001', 'written_article',
  '2026-08-29 11:08:00+00', 'suppressed-story',
  'https://phase3-a.example/articles/suppressed-story',
  pg_temp.id('ev_manifest_a'), pg_temp.id('ev_rep_a'), true
);
select pg_temp.create_delivery(
  'm_review', 'url_review', pg_temp.id('item_review'),
  '88100000-0000-0000-0000-000000000001', 'written_article',
  '2026-08-29 11:09:00+00', 'review-story',
  'https://phase3-a.example/articles/review-story',
  pg_temp.id('ev_manifest_a'), pg_temp.id('ev_rep_a'), true
);
select pg_temp.create_delivery(
  'm_eligibility', 'url_eligibility', pg_temp.id('item_eligibility'),
  '88100000-0000-0000-0000-000000000001', 'written_article',
  '2026-08-29 11:10:00+00', 'eligibility-story',
  'https://phase3-a.example/articles/eligibility-story',
  pg_temp.id('ev_manifest_a'), pg_temp.id('ev_rep_a'), true
);
select pg_temp.create_delivery(
  'm_unresolved', 'url_unresolved', null,
  '88100000-0000-0000-0000-000000000001', 'written_article',
  '2026-08-29 11:11:00+00', 'unresolved-manifestation',
  'https://phase3-a.example/articles/unresolved-manifestation',
  pg_temp.id('ev_manifest_a'), pg_temp.id('ev_rep_a'), false
);

-- Visible ordered attribution resolves directly to Phase 2 stable identity
-- populations. No per-article identity case is opened.
select pg_temp.remember('byline_person', public.admin_record_news_byline(
  pg_temp.id('m_wire_a'), 1, 'Alex Writer',
  'https://phase3-a.example/authors/alex-writer',
  pg_temp.id('ev_manifest_a'), 'Visible public human byline.'
));
select pg_temp.remember('byline_profile', public.admin_record_news_byline(
  pg_temp.id('m_wire_a'), 2, 'Alex Writer — Phase 3 Publisher A',
  'https://phase3-a.example/authors/alex-writer',
  pg_temp.id('ev_manifest_a'), 'Visible publisher-profile byline.'
));
select public.admin_resolve_news_byline(
  pg_temp.id('byline_person'), 'person',
  '88200000-0000-0000-0000-000000000001',
  'visible_public_attribution', null,
  'Resolve to the existing Phase 2 person.'
);
select public.admin_resolve_news_byline(
  pg_temp.id('byline_profile'), 'publisher_profile',
  '88250000-0000-0000-0000-000000000001',
  'visible_public_attribution', null,
  'Resolve to the existing Phase 2 publisher contributor profile.'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_resolve_news_byline(%L::uuid, %L, %L::uuid, %L, null, null)',
    pg_temp.id('byline_person')::text,
    'person',
    '88200000-0000-0000-0000-000000000001',
    'hidden_metadata'
  ),
  'visible public attribution or identity review is required',
  'hidden metadata must not override visible public attribution'
);
select pg_temp.remember('byline_org', public.admin_record_news_byline(
  pg_temp.id('m_org'), 1, 'Phase 3 Staff', null,
  pg_temp.id('ev_manifest_a'), 'Visible organizational byline.'
));
select public.admin_resolve_news_byline(
  pg_temp.id('byline_org'), 'organization',
  '88230000-0000-0000-0000-000000000001',
  'visible_public_attribution', null,
  'Resolve to the existing Phase 2 organizational contributor.'
);
select pg_temp.remember('byline_show', public.admin_record_news_byline(
  pg_temp.id('m_podcast'), 1, 'The Phase 3 Show', null,
  pg_temp.id('ev_manifest_network'), 'Visible Show attribution.'
));
select public.admin_resolve_news_byline(
  pg_temp.id('byline_show'), 'show',
  '88240000-0000-0000-0000-000000000001',
  'visible_public_attribution', null,
  'Resolve to the existing Phase 2 Show.'
);

-- Four factual classification types coexist. Team classification does not
-- infer Competition, and presentation groups cannot be accepted as targets.
select pg_temp.remember('class_wire_sport', public.admin_record_news_classification(
  pg_temp.id('item_wire'), null, 'sport',
  (select id from public.catalog_sports where sport_id = 'hockey'),
  pg_temp.id('ev_class'), 'Explicit Hockey classification.'
));
select pg_temp.remember('class_wire_competition', public.admin_record_news_classification(
  pg_temp.id('item_wire'), null, 'competition',
  (select id from public.catalog_competitions where competition_id = 'hockey-nhl'),
  pg_temp.id('ev_class'), 'Explicit NHL classification.'
));
select pg_temp.remember('class_wire_edition', public.admin_record_news_classification(
  pg_temp.id('item_wire'), null, 'competition_edition',
  '88300000-0000-0000-0000-000000000001',
  pg_temp.id('ev_class'), 'Explicit NHL Edition classification.'
));
select pg_temp.remember('class_wire_team', public.admin_record_news_classification(
  pg_temp.id('item_wire'), null, 'team',
  (select team.id
   from public.catalog_teams team
   join public.team_identity_versions identity_record
     on identity_record.team_id = team.id and identity_record.is_current
   where identity_record.display_name = 'Edmonton Oilers'),
  pg_temp.id('ev_class'), 'Explicit Edmonton Oilers classification.'
));

select pg_temp.remember('class_independent', public.admin_record_news_classification(
  pg_temp.id('item_independent'), null, 'team',
  (select team.id
   from public.catalog_teams team
   join public.team_identity_versions identity_record
     on identity_record.team_id = team.id and identity_record.is_current
   where identity_record.display_name = 'Edmonton Oilers'),
  pg_temp.id('ev_class'), 'Team-only evidence stops at Team.'
));
select pg_temp.assert_true(
  not exists (
    select 1
    from public.news_item_classifications classification
    join public.news_item_classification_versions version
      on version.classification_id = classification.id and version.is_current
    where classification.news_item_id = pg_temp.id('item_independent')
      and version.target_type = 'competition'
  ),
  'Team classification must not fabricate a Competition classification'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_record_news_classification(%L::uuid, null, %L, %L::uuid, %L::uuid, %L)',
    pg_temp.id('item_wire')::text,
    'filter_group',
    '88310000-0000-0000-0000-000000000001',
    pg_temp.id('ev_class')::text,
    'Presentation groups are not factual targets.'
  ),
  'classification target must be sport, competition, competition edition, or team',
  'a presentation/filter group must not be storable as factual News classification'
);

-- Remote reference only; no copied media or article body.
select pg_temp.remember('preview_wire', public.admin_record_news_remote_preview(
  pg_temp.id('m_wire_a'), 'image',
  'https://cdn.phase3-a.example/previews/shared-event.jpg',
  'approved', 'Synthetic remote preview', pg_temp.id('ev_preview'),
  'Remote reference governed by publisher policy.'
));
select pg_temp.assert_true(
  exists (
    select 1
    from public.admin_get_news_published_items_at('2100-01-01')
    where id = pg_temp.id('item_wire')
      and preview_url = 'https://cdn.phase3-a.example/previews/shared-event.jpg'
      and preview_kind = 'image'
  ),
  'a current approved remote preview must be exposed by the canonical read'
);
select pg_temp.remember(
  'preview_wire_block',
  public.admin_set_news_remote_preview_policy(
    pg_temp.id('preview_wire'), 'blocked', pg_temp.id('ev_preview_block'),
    'Governed publisher-policy takedown; preserve the former approval.'
  )
);
select pg_temp.assert_true(
  exists (
    select 1
    from public.admin_get_news_published_items_at('2100-01-01')
    where id = pg_temp.id('item_wire')
      and preview_url is null
      and preview_kind is null
  )
  and (
    select count(*) = 2
      and count(*) filter (where is_current) = 1
      and bool_or(
        not is_current
        and publisher_policy_state = 'approved'
        and primary_evidence_id = pg_temp.id('ev_preview')
      )
      and bool_or(
        is_current
        and publisher_policy_state = 'blocked'
        and primary_evidence_id = pg_temp.id('ev_preview_block')
        and supersedes_policy_version_id is not null
      )
    from public.news_remote_preview_policy_versions
    where preview_reference_id = pg_temp.id('preview_wire')
  ),
  'governed takedown must hide the preview while preserving approval and block history'
);

-- Content review cases remain typed and separate from identity Resolution.
create temporary table phase3_counts as
select count(*)::bigint as identity_case_count
from public.news_identity_resolution_cases;
grant select on pg_temp.phase3_counts to authenticated;

select pg_temp.remember('dedupe_review', public.admin_record_news_deduplication(
  pg_temp.id('m_unresolved'), pg_temp.id('m_review'), 'needs_review',
  pg_temp.id('ev_dedupe_reverse'),
  'Available evidence does not establish whether these manifestations share a work.',
  'Ambiguous dedupe remains unresolved.'
));
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_assign_news_manifestation(%L::uuid, %L::uuid, %L::uuid, %L)',
    pg_temp.id('m_unresolved')::text,
    pg_temp.id('item_review')::text,
    pg_temp.id('ev_dedupe_reverse')::text,
    'Do not convert review into an implicit same-work assignment.'
  ),
  'needs-review manifestations cannot be assigned to the same news item',
  'assignment changes must not turn needs-review into a same-work conclusion'
);
select pg_temp.remember('case_dedupe', public.admin_open_news_content_review_case(
  'dedupe', null, pg_temp.id('m_unresolved'),
  'Do these two manifestations represent the same underlying work?',
  jsonb_build_object('deduplication_case_id', pg_temp.id('dedupe_review')),
  'Typed content review case.'
));
select pg_temp.remember('case_publication', public.admin_open_news_content_review_case(
  'publication_time', pg_temp.id('item_review'), pg_temp.id('m_review'),
  'Which conflicting visible timestamp is the source publication time?',
  '{"conflict":"synthetic"}'::jsonb,
  'Typed publication-time review case.'
));
select public.admin_review_news_content_case(
  pg_temp.id('case_publication'), 'insufficient_evidence',
  '{"next_step":"retain needs_review state"}'::jsonb,
  'No reliable timestamp can currently be selected.'
);

select pg_temp.assert_true(
  (select count(*) from public.news_identity_resolution_cases)
    = (select identity_case_count from pg_temp.phase3_counts),
  'content questions must not create Phase 2 identity Resolution cases'
);

-- ---------------------------------------------------------------------------
-- Publication, chronology, cardinality, and provenance assertions
-- ---------------------------------------------------------------------------

select pg_temp.assert_true(
  exists (
    select 1 from public.news_published_item_read_model
    where id = pg_temp.id('item_wire')
  ),
  'a confidently established old publication time must publish at its actual historical position'
);
select pg_temp.assert_true(
  not exists (
    select 1 from public.news_published_item_read_model
    where id in (
      pg_temp.id('item_draft'), pg_temp.id('item_excluded'),
      pg_temp.id('item_suppressed'), pg_temp.id('item_review')
    )
  ),
  'draft, excluded, suppressed, and needs-review Items must stay out of the published read'
);
select pg_temp.assert_true(
  not exists (
    select 1 from public.news_published_item_read_model
    where id = pg_temp.id('item_no_destination')
  ),
  'an Item without a valid representative destination must stay out of the published read'
);
select pg_temp.assert_true(
  (
    select count(*) = 1
    from public.news_manifestations manifestation
    where manifestation.id = pg_temp.id('m_unresolved')
      and not exists (
        select 1 from public.news_manifestation_assignment_versions assignment
        where assignment.manifestation_id = manifestation.id and assignment.is_current
      )
  )
  and not exists (
    select 1 from public.news_ready_item_read_model
    where manifestation_id = pg_temp.id('m_unresolved')
  ),
  'an unresolved manifestation may exist but must not enter the canonical read'
);

select pg_temp.assert_true(
  not exists (
    select 1 from public.news_published_item_read_model
    where id = pg_temp.id('item_future')
  )
  and exists (
    select 1 from public.news_awaiting_publication_read_model
    where id = pg_temp.id('item_future')
      and publication_time = '2099-01-01 00:00:00+00'::timestamptz
  ),
  'future-dated published Items must be excluded now and derived into the staff awaiting list'
);
select pg_temp.assert_true(
  not exists (
    select 1 from public.admin_get_news_published_items_at('2098-12-31 23:59:59+00')
    where id = pg_temp.id('item_future')
  )
  and exists (
    select 1 from public.admin_get_news_published_items_at('2099-01-01 00:00:01+00')
    where id = pg_temp.id('item_future')
  )
  and (
    select count(*) = 1
    from public.news_item_versions
    where news_item_id = pg_temp.id('item_future')
  ),
  'the same unchanged future Item must qualify automatically once controlled database time passes'
);

select pg_temp.assert_true(
  (
    select count(*) = 1
      and max(jsonb_array_length(bylines)) = 2
      and max(jsonb_array_length(classifications)) = 4
    from public.admin_get_news_published_items_at('2100-01-01')
    where id = pg_temp.id('item_wire')
  )
  and (
    select count(*) = 2
    from public.news_manifestation_assignment_versions
    where news_item_id = pg_temp.id('item_wire') and is_current
  )
  and (
    select count(*) = 2
    from public.news_manifestation_urls
    where manifestation_id = pg_temp.id('m_wire_a')
  ),
  'the read must return one row per Item regardless of manifestations, URLs, bylines, or classifications'
);

select pg_temp.assert_true(
  exists (
    select 1 from public.admin_get_news_published_items_at('2100-01-01')
    where id = pg_temp.id('item_org')
      and jsonb_array_length(bylines) = 1
      and bylines -> 0 ->> 'target_identity_type' = 'organization'
  ),
  'an organizational-contributor-only written Item must publish'
);
select pg_temp.assert_true(
  exists (
    select 1 from public.admin_get_news_published_items_at('2100-01-01')
    where id = pg_temp.id('item_podcast')
      and show_id = '88240000-0000-0000-0000-000000000001'
      and jsonb_array_length(bylines) = 1
      and bylines -> 0 ->> 'target_identity_type' = 'show'
  ),
  'a Phase 2 Show-only podcast episode must publish through the same governed path'
);

select pg_temp.assert_true(
  (
    select decision.decision_origin = 'staff'
      and decision.decided_by_user_id = '88000000-0000-0000-0000-000000000001'
      and decision.decided_by_actor_id = '88010000-0000-0000-0000-000000000001'
      and decision.source_publisher_id = '88100000-0000-0000-0000-000000000001'
    from public.news_items item
    join public.news_content_decisions decision
      on decision.id = item.created_by_decision_id
    where item.id = pg_temp.id('item_wire')
  ),
  'staff-created Item provenance must retain origin, user, actor, and source publisher'
);
select pg_temp.assert_true(
  exists (
    select 1
    from public.admin_get_news_published_items_at('2100-01-01')
    where id = pg_temp.id('item_future')
      and publisher_source_id = '88100000-0000-0000-0000-000000000002'
  )
  and not exists (
    select 1 from public.news_publisher_policy_versions
    where publisher_source_id = '88100000-0000-0000-0000-000000000002'
  ),
  'explicit Item publication state must not inherit factual source review or trust governance'
);

select pg_temp.assert_true(
  (
    with result as (
      select row_number() over () as sequence_number, publication_time, news_item_id
      from public.admin_get_news_published_items_at('2100-01-01')
    )
    select not exists (
      select 1
      from result previous
      join result current
        on current.sequence_number = previous.sequence_number + 1
      where previous.publication_time < current.publication_time
         or (
           previous.publication_time = current.publication_time
           and previous.news_item_id > current.news_item_id
         )
    )
  ),
  'canonical order must be source publication time descending with permanent-ID tie-breaker'
);
select pg_temp.assert_true(
  position(
    'order by ready.publication_time desc, ready.news_item_id'
    in lower(pg_get_functiondef(
      'public.admin_get_news_published_items_at(timestamptz)'::regprocedure
    ))
  ) > 0
  and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name in ('news_items', 'news_item_versions')
      and column_name ~ '(rank|score|weight|priority)'
  ),
  'no ranking field may reorder the canonical chronological read'
);

-- Classification correction changes only classification history.
select public.admin_record_news_classification(
  pg_temp.id('item_independent'), pg_temp.id('class_independent'), 'sport',
  (select id from public.catalog_sports where sport_id = 'hockey'),
  pg_temp.id('ev_class'), 'Correct specificity to explicit Sport evidence.'
);
select pg_temp.assert_true(
  (
    select count(*) = 1
      and max(publication_time) = '1985-01-01 12:00:00+00'::timestamptz
    from public.news_item_versions
    where news_item_id = pg_temp.id('item_independent')
  )
  and (
    select count(*) = 2 and count(*) filter (where is_current) = 1
    from public.news_item_classification_versions
    where classification_id = pg_temp.id('class_independent')
  ),
  'classification correction must preserve publication chronology and classification history'
);

-- A correction to the source publication fact creates Item-version history and
-- moves only that same stable Item to its corrected position.
select public.admin_record_news_item_version(
  pg_temp.id('item_independent'),
  'Shared Event Story', 'Independent reporting on the same event.', 'published',
  '1975-01-01 12:00:00+00', pg_temp.id('ev_pub_a'),
  '88100000-0000-0000-0000-000000000001',
  'Correct the source publication timestamp with better evidence.'
);
select pg_temp.assert_true(
  (
    select count(*) = 2
      and count(*) filter (where is_current) = 1
      and bool_or(not is_current and publication_time = '1985-01-01 12:00:00+00')
      and bool_or(is_current and publication_time = '1975-01-01 12:00:00+00')
    from public.news_item_versions
    where news_item_id = pg_temp.id('item_independent')
  )
  and (
    select publication_time = '1975-01-01 12:00:00+00'::timestamptz
    from public.admin_get_news_published_items_at('2100-01-01')
    where id = pg_temp.id('item_independent')
  ),
  'publication-time correction must preserve the former timestamp and move the same Item'
);
select pg_temp.assert_true(
  (
    with ordered as (
      select
        id,
        row_number() over (order by publication_time desc, news_item_id) as position
      from public.admin_get_news_published_items_at('2100-01-01')
    )
    select independent.position > wire.position
    from ordered independent
    cross join ordered wire
    where independent.id = pg_temp.id('item_independent')
      and wire.id = pg_temp.id('item_wire')
  ),
  'a corrected earlier publication time must move the Item behind the later source timestamp'
);

-- Losing and regaining publication eligibility never replaces the Item or its
-- source chronology.
select pg_temp.assert_true(
  exists (
    select 1 from public.news_published_item_read_model
    where id = pg_temp.id('item_eligibility')
  ),
  'published eligibility fixture must initially appear'
);
select public.admin_record_news_item_version(
  pg_temp.id('item_eligibility'), 'Eligibility Restoration Story', null,
  'suppressed', '2010-01-01 00:00:00+00', pg_temp.id('ev_pub_a'),
  '88100000-0000-0000-0000-000000000001',
  'Governed suppression.'
);
select pg_temp.assert_true(
  not exists (
    select 1 from public.news_published_item_read_model
    where id = pg_temp.id('item_eligibility')
  ),
  'a later suppression must remove the Item without deleting it'
);
select public.admin_record_news_item_version(
  pg_temp.id('item_eligibility'), 'Eligibility Restoration Story', null,
  'published', '2010-01-01 00:00:00+00', pg_temp.id('ev_pub_a'),
  '88100000-0000-0000-0000-000000000001',
  'Governed restoration.'
);
select pg_temp.assert_true(
  exists (
    select 1 from public.news_published_item_read_model
    where id = pg_temp.id('item_eligibility')
      and publication_time = '2010-01-01 00:00:00+00'::timestamptz
  )
  and (
    select count(*) = 3 and count(*) filter (where is_current) = 1
    from public.news_item_versions
    where news_item_id = pg_temp.id('item_eligibility')
  ),
  'regaining eligibility must restore the same Item at the exact source chronology position'
);

-- Dedupe reversal and assignment reconciliation are one governed operation.
-- A failed reconciliation rolls back the dedupe revision; the successful
-- reversal makes the non-representative copy unresolved atomically.
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_record_news_deduplication(%L::uuid, %L::uuid, %L, %L::uuid, %L, %L, %L::uuid, null::uuid)',
    pg_temp.id('m_wire_a')::text,
    pg_temp.id('m_wire_b')::text,
    'independent_journalism',
    pg_temp.id('ev_dedupe_reverse')::text,
    'Attempt a reversal whose required assignment step will fail.',
    'The representative manifestation cannot be unassigned.',
    pg_temp.id('m_wire_a')::text
  ),
  'change the representative destination before reassigning its manifestation',
  'a failed assignment reconciliation must roll back the dedupe revision'
);
select pg_temp.assert_true(
  (
    select outcome = 'syndicated_copy'
    from public.news_deduplication_decision_versions
    where deduplication_case_id = pg_temp.id('dedupe_wire') and is_current
  )
  and (
    select count(*) = 2
      and count(distinct news_item_id) = 1
    from public.news_manifestation_assignment_versions
    where manifestation_id in (pg_temp.id('m_wire_a'), pg_temp.id('m_wire_b'))
      and is_current
  ),
  'failed atomic reversal must leave both current dedupe and assignment state unchanged'
);
select public.admin_record_news_deduplication(
  pg_temp.id('m_wire_a'), pg_temp.id('m_wire_b'), 'independent_journalism',
  pg_temp.id('ev_dedupe_reverse'),
  'Better evidence establishes that the second manifestation is independent journalism.',
  'Reverse the mistaken dedupe and assignment without deleting history.',
  pg_temp.id('m_wire_b'), null
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_assign_news_manifestation(%L::uuid, %L::uuid, %L::uuid, %L)',
    pg_temp.id('m_wire_b')::text,
    pg_temp.id('item_wire')::text,
    pg_temp.id('ev_dedupe_same')::text,
    'Independent journalism cannot be reassigned to the same work.'
  ),
  'independent-journalism manifestations cannot be assigned to the same news item',
  'assignment changes must not contradict a current independent-journalism decision'
);

select pg_temp.assert_true(
  (
    select count(*) = 2
      and count(*) filter (where is_current) = 1
      and bool_or(not is_current and outcome = 'syndicated_copy')
      and bool_or(is_current and outcome = 'independent_journalism')
    from public.news_deduplication_decision_versions
    where deduplication_case_id = pg_temp.id('dedupe_wire')
  )
  and (
    select count(distinct version.primary_evidence_id) = 2
    from public.news_deduplication_decision_versions version
    where version.deduplication_case_id = pg_temp.id('dedupe_wire')
  ),
  'dedupe reversal must retain both outcomes and their distinct evidence'
);
select pg_temp.assert_true(
  (
    select public.get_news_manifestation_item_at(
      pg_temp.id('m_wire_b'), assignment.recorded_from
    ) = pg_temp.id('item_wire')
    from public.news_manifestation_assignment_versions assignment
    where assignment.manifestation_id = pg_temp.id('m_wire_b')
      and not assignment.is_current
    order by assignment.recorded_from
    limit 1
  )
  and (
    select public.get_news_manifestation_item_at(
      pg_temp.id('m_wire_b'), assignment.recorded_to
    ) is null
    from public.news_manifestation_assignment_versions assignment
    where assignment.manifestation_id = pg_temp.id('m_wire_b')
      and not assignment.is_current
    order by assignment.recorded_from
    limit 1
  ),
  'point-in-time assignment must answer the former Item and later unresolved interval directly'
);
select pg_temp.assert_true(
  (
    select count(*) = 3 and count(*) filter (where is_current) = 1
      and bool_or(is_current and manifestation_url_id = pg_temp.id('url_wire_a'))
    from public.news_representative_destination_versions
    where news_item_id = pg_temp.id('item_wire')
  ),
  'representative changes must remain fully historical with one sticky current destination'
);

reset role;

-- ---------------------------------------------------------------------------
-- A later Phase 2 affiliation correction cannot rewrite publication history
-- ---------------------------------------------------------------------------

insert into public.news_identity_resolution_cases(
  id, case_id, case_kind, proposed_identity_type, proposed_name,
  publisher_source_id, subject_person_id, unresolved_question, created_by_user_id
)
values (
  '88400000-0000-0000-0000-000000000001',
  'news-identity-case-10000000000000000000000000000001',
  'affiliation', 'human', 'Alex Writer',
  '88100000-0000-0000-0000-000000000001',
  '88200000-0000-0000-0000-000000000001',
  'Record and later correct a synthetic publisher affiliation.',
  '88000000-0000-0000-0000-000000000001'
);

select set_config(
  'request.jwt.claim.sub',
  '88000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select public.admin_review_news_identity_case(
  '88400000-0000-0000-0000-000000000001',
  'establish_affiliation',
  '88200000-0000-0000-0000-000000000001',
  jsonb_build_object(
    'publisher_source_id', '88100000-0000-0000-0000-000000000001',
    'relationship_type', 'contributor',
    'effective_from', '2020-01-01T00:00:00+00',
    'effective_to', '2024-12-31T00:00:00+00'
  ),
  'Synthetic governed affiliation history proof.'
);
reset role;

select pg_temp.remember(
  'affiliation_initial',
  (
    select id
    from public.news_person_publisher_relationship_versions
    where person_id = '88200000-0000-0000-0000-000000000001'
      and publisher_source_id = '88100000-0000-0000-0000-000000000001'
      and is_current
  )
);

select set_config(
  'request.jwt.claim.sub',
  '88000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select public.admin_review_news_identity_case(
  '88400000-0000-0000-0000-000000000001',
  'correct_affiliation',
  '88200000-0000-0000-0000-000000000001',
  jsonb_build_object(
    'publisher_source_id', '88100000-0000-0000-0000-000000000001',
    'relationship_type', 'columnist',
    'relationship_id', pg_temp.id('affiliation_initial'),
    'effective_from', '2020-01-01T00:00:00+00',
    'effective_to', '2024-12-31T00:00:00+00'
  ),
  'Correct relationship type without changing its factual period.'
);
reset role;

select pg_temp.assert_true(
  (
    select mention.raw_attribution = 'Alex Writer'
      and resolution.person_id = '88200000-0000-0000-0000-000000000001'
    from public.news_byline_mentions mention
    join public.news_byline_resolution_versions resolution
      on resolution.byline_mention_id = mention.id and resolution.is_current
    where mention.id = pg_temp.id('byline_person')
  )
  and (
    select count(*) = 2
      and count(*) filter (where is_current) = 1
      and bool_or(not is_current and relationship_type = 'contributor')
      and bool_or(is_current and relationship_type = 'columnist')
      and bool_and(effective_from = '2020-01-01 00:00:00+00'::timestamptz)
      and bool_and(effective_to = '2024-12-31 00:00:00+00'::timestamptz)
    from public.news_person_publisher_relationship_versions
    where person_id = '88200000-0000-0000-0000-000000000001'
      and publisher_source_id = '88100000-0000-0000-0000-000000000001'
  ),
  'historical visible attribution must survive a later affiliation correction with factual dates intact'
);

-- ---------------------------------------------------------------------------
-- Shared canonical mutation path with automation provenance
-- ---------------------------------------------------------------------------

select pg_temp.remember('ev_auto_manifest', private.record_news_content_evidence_canonical(
  'manifestation_identity',
  'https://phase3-a.example/automation/manifestation-evidence',
  '88100000-0000-0000-0000-000000000001',
  'Synthetic evidence recorded through the shared canonical path.',
  '2026-08-29 12:00:00+00',
  'automation', null, '88010000-0000-0000-0000-000000000002', null
));
select pg_temp.remember('ev_auto_class', private.record_news_content_evidence_canonical(
  'factual_classification',
  'https://phase3-a.example/automation/classification-evidence',
  '88100000-0000-0000-0000-000000000001',
  'Synthetic classification evidence for the shared canonical path.',
  '2026-08-29 12:01:00+00',
  'automation', null, '88010000-0000-0000-0000-000000000002', null
));
select pg_temp.remember('ev_auto_dedupe', private.record_news_content_evidence_canonical(
  'dedupe_relationship',
  'https://phase3-a.example/automation/dedupe-evidence',
  '88100000-0000-0000-0000-000000000001',
  'Synthetic dedupe evidence for the shared canonical path.',
  '2026-08-29 12:02:00+00',
  'automation', null, '88010000-0000-0000-0000-000000000002', null
));
select pg_temp.remember('item_auto', private.create_news_item_canonical(
  'written', 'Automation Draft', null, 'draft', null, null,
  '88100000-0000-0000-0000-000000000001', null, null,
  'automation', null, '88010000-0000-0000-0000-000000000002',
  'Synthetic authorized automation caller proof.'
));
select private.record_news_item_version_canonical(
  pg_temp.id('item_auto'), 'Automation Draft Revised', null, 'draft',
  null, null, '88100000-0000-0000-0000-000000000001',
  'automation', null, '88010000-0000-0000-0000-000000000002',
  'Shared Item version mutation.'
);
select pg_temp.remember('m_auto_a', private.create_news_manifestation_canonical(
  '88100000-0000-0000-0000-000000000001', 'written_article',
  '2026-08-29 12:03:00+00', 'automation-copy-a',
  pg_temp.id('ev_auto_manifest'),
  'automation', null, '88010000-0000-0000-0000-000000000002', null
));
select pg_temp.remember('m_auto_b', private.create_news_manifestation_canonical(
  '88100000-0000-0000-0000-000000000001', 'syndicated_article',
  '2026-08-29 12:04:00+00', 'automation-copy-b',
  pg_temp.id('ev_auto_manifest'),
  'automation', null, '88010000-0000-0000-0000-000000000002', null
));
select private.add_news_manifestation_url_canonical(
  pg_temp.id('m_auto_a'), 'canonical',
  'https://phase3-a.example/automation/story-a', true,
  pg_temp.id('ev_auto_manifest'),
  'automation', null, '88010000-0000-0000-0000-000000000002', null
);
select private.assign_news_manifestation_canonical(
  pg_temp.id('m_auto_a'), pg_temp.id('item_auto'),
  pg_temp.id('ev_auto_manifest'),
  'automation', null, '88010000-0000-0000-0000-000000000002', null
);
select private.assign_news_manifestation_canonical(
  pg_temp.id('m_auto_b'), pg_temp.id('item_auto'),
  pg_temp.id('ev_auto_manifest'),
  'automation', null, '88010000-0000-0000-0000-000000000002', null
);
select private.record_news_classification_canonical(
  pg_temp.id('item_auto'), null, 'sport',
  (select id from public.catalog_sports where sport_id = 'hockey'),
  pg_temp.id('ev_auto_class'),
  'automation', null, '88010000-0000-0000-0000-000000000002', null
);
select private.record_news_deduplication_canonical(
  pg_temp.id('m_auto_a'), pg_temp.id('m_auto_b'), 'syndicated_copy',
  pg_temp.id('ev_auto_dedupe'),
  'Synthetic explicit same-work evidence.', null, null,
  'automation', null, '88010000-0000-0000-0000-000000000002', null
);

select pg_temp.assert_true(
  (
    select count(distinct action) >= 8
      and bool_and(decision_origin = 'automation')
      and bool_and(decided_by_user_id is null)
      and bool_and(
        decided_by_actor_id = '88010000-0000-0000-0000-000000000002'
      )
    from public.news_content_decisions
    where decided_by_actor_id = '88010000-0000-0000-0000-000000000002'
      and action in (
        'record_evidence', 'create_item', 'revise_item',
        'create_manifestation', 'add_manifestation_url',
        'assign_manifestation', 'record_classification', 'record_dedupe'
      )
  )
  and (
    select count(*) = 2 and count(*) filter (where is_current) = 1
    from public.news_item_versions
    where news_item_id = pg_temp.id('item_auto')
  )
  and (
    select count(*) = 2 and count(distinct news_item_id) = 1
    from public.news_manifestation_assignment_versions
    where manifestation_id in (pg_temp.id('m_auto_a'), pg_temp.id('m_auto_b'))
      and is_current
  ),
  'one private canonical path must support governed automation provenance without duplicating mutations'
);
select pg_temp.assert_true(
  position(
    'private.create_news_item_canonical'
    in pg_get_functiondef(
      'public.admin_create_news_item(text,text,text,text,timestamptz,uuid,uuid,uuid,text,text)'::regprocedure
    )
  ) > 0
  and position(
    'private.create_news_manifestation_canonical'
    in pg_get_functiondef(
      'public.admin_create_news_manifestation(uuid,text,timestamptz,text,uuid,text)'::regprocedure
    )
  ) > 0
  and position(
    'private.assign_news_manifestation_canonical'
    in pg_get_functiondef(
      'public.admin_assign_news_manifestation(uuid,uuid,uuid,text)'::regprocedure
    )
  ) > 0
  and position(
    'private.record_news_classification_canonical'
    in pg_get_functiondef(
      'public.admin_record_news_classification(uuid,uuid,text,uuid,uuid,text)'::regprocedure
    )
  ) > 0
  and position(
    'private.record_news_deduplication_canonical'
    in pg_get_functiondef(
      'public.admin_record_news_deduplication(uuid,uuid,text,uuid,text,text,uuid,uuid)'::regprocedure
    )
  ) > 0,
  'staff RPCs must remain authorized wrappers over the same private canonical mutations'
);

-- ---------------------------------------------------------------------------
-- Final real-role access, structure, and explicit Phase boundary proofs
-- ---------------------------------------------------------------------------

select set_config(
  'request.jwt.claim.sub',
  '88000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  (select count(*) = 0 from public.news_items)
  and (select count(*) = 0 from public.news_content_review_read_model),
  'ordinary authenticated fans must not read canonical or content-review state'
);
select pg_temp.assert_statement_rejected(
  format(
    'update public.news_item_versions set headline = %L where news_item_id = %L::uuid and is_current',
    'Browser mutation denied', pg_temp.id('item_wire')::text
  ),
  '',
  'ordinary authenticated fans must not mutate canonical News history'
);
select pg_temp.assert_statement_rejected(
  format(
    'select public.admin_review_news_content_case(%L::uuid, %L, %L::jsonb, null)',
    pg_temp.id('case_dedupe')::text, 'resolve', '{}'
  ),
  'staff access is required',
  'ordinary authenticated fans must not use the content-review action'
);
select pg_temp.assert_statement_rejected(
  $statement$
    select private.create_news_item_canonical(
      'written', 'Unauthorized private call', null, 'draft', null, null,
      '88100000-0000-0000-0000-000000000001', null, null,
      'automation', null,
      '88010000-0000-0000-0000-000000000002', null
    )
  $statement$,
  'permission denied',
  'browser roles must not call private canonical mutations directly'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '88000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;
select pg_temp.assert_true(
  (select count(*) > 0 from public.news_items)
  and exists (
    select 1 from public.news_content_review_read_model
    where id = pg_temp.id('case_dedupe') and status = 'open'
  ),
  'authorized staff must read canonical state and typed content review cases'
);
select public.admin_review_news_content_case(
  pg_temp.id('case_dedupe'), 'resolve',
  '{"result":"remain independent"}'::jsonb,
  'Authorized staff resolves the typed content question.'
);
select pg_temp.assert_true(
  exists (
    select 1 from public.news_content_review_read_model
    where id = pg_temp.id('case_dedupe')
      and status = 'resolved'
      and jsonb_array_length(decision_history) = 1
  ),
  'authorized staff review must preserve decision provenance in the question-oriented read model'
);
reset role;

select pg_temp.assert_true(
  (
    select preview.remote_url ~* '^https://'
      and policy.publisher_policy_state = 'blocked'
      and policy.is_current
    from public.news_remote_preview_references preview
    join public.news_remote_preview_policy_versions policy
      on policy.preview_reference_id = preview.id
    where preview.id = pg_temp.id('preview_wire')
      and policy.is_current
  )
  and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name like 'news_%'
      and column_name in (
        'body', 'article_body', 'article_content', 'content_html',
        'full_text', 'copied_image_path', 'canonical_image_path'
      )
  ),
  'preview media must remain remote-referenced and no third-party article-body storage may exist'
);

select pg_temp.assert_true(
  not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'news_item_classification_versions'
      and column_name like '%filter_group%'
  )
  and not exists (
    select 1
    from information_schema.table_constraints constraint_record
    join information_schema.constraint_column_usage usage_record
      on usage_record.constraint_schema = constraint_record.constraint_schema
     and usage_record.constraint_name = constraint_record.constraint_name
    where constraint_record.table_schema = 'public'
      and constraint_record.table_name = 'news_item_classification_versions'
      and usage_record.table_name = 'catalog_competition_filter_groups'
  ),
  'presentation filter groups must have no factual classification storage path'
);

select pg_temp.assert_true(
  not exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_type = 'BASE TABLE'
      and table_name ~ '^news_.*(monitor|worker|queue|fetch|follow|feed|discussion|rating|reaction|poll|notification)'
  ),
  'Phase 3 must not add monitoring, runtime, follows, personalized feeds, discussion, engagement, or notification tables'
);

select pg_temp.assert_true(
  (
    select count(*) = 2
      and bool_and(trigger_record.tgdeferrable)
      and bool_and(trigger_record.tginitdeferred)
    from pg_trigger trigger_record
    where trigger_record.tgname in (
      'validate_news_assignment_dedupe_consistency',
      'validate_news_dedupe_assignment_consistency'
    )
      and not trigger_record.tgisinternal
  )
  and position(
    'private.lock_news_manifestation_dedupe_scope'
    in pg_get_functiondef(
      'private.assign_news_manifestation_canonical(uuid,uuid,uuid,text,uuid,uuid,text)'::regprocedure
    )
  ) > 0
  and position(
    'private.lock_news_manifestation_pair'
    in pg_get_functiondef(
      'private.record_news_deduplication_canonical(uuid,uuid,text,uuid,text,uuid,uuid,text,uuid,uuid,text)'::regprocedure
    )
  ) > 0,
  'deferred constraints and ordered manifestation locks must guard dedupe and assignment consistency in both directions'
);

select pg_temp.assert_true(
  exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'news_items'
      and roles = array['authenticated']::name[]
      and cmd = 'SELECT'
  )
  and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename like 'news_%'
      and cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL')
  ),
  'Phase 3 table access must be real-role staff-read with no browser mutation policy'
);

rollback;
