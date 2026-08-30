-- Phase 4 fan-facing support contracts: individual-identity discovery,
-- contributor profiles, canonical filter navigation, and best-effort outbound
-- open provenance. No crawler, ingestion runtime, discussion, rating,
-- reaction, request, notification, or popularity behavior is introduced.

-- Extend BL-027 before adding the outbound-open event table.
alter function private.news_domain_mutation_registry()
rename to news_domain_mutation_registry_through_phase4_feed;

create or replace function private.news_domain_mutation_registry()
returns table (
  table_schema text,
  table_name text,
  mutation_mode text,
  canonical_operations text[],
  rationale text
)
language sql
stable
security definer
set search_path = ''
as $$
  select * from private.news_domain_mutation_registry_through_phase4_feed()
  union all
  select *
  from (values
    (
      'public',
      'news_outbound_open_events',
      'governed',
      array['public.record_news_outbound_open(text,text)'],
      'Immutable best-effort events are appended only after the fan-facing Item and representative destination are revalidated.'
    )
  ) registry(table_schema, table_name, mutation_mode, canonical_operations, rationale);
$$;

revoke all on function private.news_domain_mutation_registry_through_phase4_feed()
from public, anon, authenticated;
revoke all on function private.news_domain_mutation_registry()
from public, anon, authenticated;

create table public.news_outbound_open_events (
  id uuid primary key default gen_random_uuid(),
  outbound_open_id text not null unique default (
    'news-outbound-open-' || replace(gen_random_uuid()::text, '-', '')
  ) check (outbound_open_id ~ '^news-outbound-open-[0-9a-f]{32}$'),
  news_item_id uuid not null references public.news_items(id),
  representative_destination_version_id uuid not null
    references public.news_representative_destination_versions(id),
  manifestation_url_id uuid not null references public.news_manifestation_urls(id),
  viewer_user_id uuid references public.profiles(user_id) on delete set null,
  opened_at timestamptz not null default statement_timestamp()
);

create index news_outbound_open_item_time_idx
on public.news_outbound_open_events(news_item_id, opened_at desc, id);

alter table public.news_outbound_open_events enable row level security;
revoke all on table public.news_outbound_open_events
from public, anon, authenticated;

create or replace function public.protect_news_outbound_open_event()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'News outbound-open events are immutable';
end;
$$;

create trigger protect_news_outbound_open_events
before update or delete on public.news_outbound_open_events
for each row execute function public.protect_news_outbound_open_event();

-- Current fan-facing identities. Author followability follows the current
-- canonical person. If both sides of a later merge have explicit current
-- configuration, the canonical person's own version takes precedence.
create or replace function private.current_news_followable_identities()
returns table (
  target_type text,
  target_id text,
  display_name text,
  person_id uuid,
  organizational_contributor_id uuid,
  show_id uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  with author_states as (
    select
      followability.*,
      private.try_resolve_news_canonical_person(followability.person_id)
        as canonical_person_id
    from public.news_followable_identity_versions followability
    where followability.is_current and followability.target_type = 'author'
  ), selected_author_states as (
    select distinct on (author_states.canonical_person_id)
      author_states.*
    from author_states
    order by
      author_states.canonical_person_id,
      (author_states.person_id = author_states.canonical_person_id) desc,
      author_states.recorded_from desc,
      author_states.id desc
  )
  select
    'author'::text,
    author_profile.author_id,
    identity.public_name,
    selected_author_states.canonical_person_id,
    null::uuid,
    null::uuid
  from selected_author_states
  join public.news_author_profiles author_profile
    on author_profile.person_id = selected_author_states.canonical_person_id
  join public.person_identity_versions identity
    on identity.person_id = selected_author_states.canonical_person_id
   and identity.is_current and identity.active
  where selected_author_states.followable
  union all
  select
    'organization'::text,
    contributor.contributor_id,
    identity.display_name,
    null::uuid,
    contributor.id,
    null::uuid
  from public.news_followable_identity_versions followability
  join public.news_organizational_contributors contributor
    on contributor.id = followability.organizational_contributor_id
  join public.news_organizational_contributor_versions identity
    on identity.organizational_contributor_id = contributor.id
   and identity.is_current and identity.active
  where followability.is_current and followability.followable
    and followability.target_type = 'organization'
  union all
  select
    'show'::text,
    show_record.show_id,
    identity.display_name,
    null::uuid,
    null::uuid,
    show_record.id
  from public.news_followable_identity_versions followability
  join public.podcast_shows show_record on show_record.id = followability.show_id
  join public.podcast_show_identity_versions identity
    on identity.show_id = show_record.id
   and identity.is_current and identity.active
  where followability.is_current and followability.followable
    and followability.target_type = 'show';
$$;

-- Current undisputed credits on already-published Items. This helper exposes no
-- review record or question; it only removes the disputed relationship.
create or replace function private.current_news_published_identity_credits()
returns table (
  news_item_id uuid,
  target_type text,
  person_id uuid,
  organizational_contributor_id uuid,
  show_id uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  with resolved_byline as (
    select
      ready.id as news_item_id,
      mention.id as byline_mention_id,
      coalesce(resolution.person_id, profile_version.person_id) as source_person_id,
      coalesce(
        resolution.organizational_contributor_id,
        profile_version.organizational_contributor_id
      ) as organizational_contributor_id,
      resolution.show_id
    from public.news_ready_item_read_model ready
    join public.news_byline_mentions mention
      on mention.manifestation_id = ready.manifestation_id
    join public.news_byline_resolution_versions resolution
      on resolution.byline_mention_id = mention.id and resolution.is_current
    left join public.news_publisher_contributor_profile_versions profile_version
      on profile_version.contributor_profile_id = resolution.contributor_profile_id
     and profile_version.is_current
    where ready.publication_state = 'published'
      and ready.publication_time <= statement_timestamp()
      and ready.destination_url_kind in ('canonical', 'alternate')
  )
  select
    byline.news_item_id,
    case
      when byline.source_person_id is not null then 'author'
      when byline.organizational_contributor_id is not null then 'organization'
      when byline.show_id is not null then 'show'
    end,
    private.try_resolve_news_canonical_person(byline.source_person_id),
    byline.organizational_contributor_id,
    byline.show_id
  from resolved_byline byline
  where not exists (
    select 1
    from public.news_content_review_cases review_case
    where review_case.case_type = 'attribution'
      and review_case.status in ('open', 'insufficient_evidence')
      and review_case.subject_byline_mention_id = byline.byline_mention_id
      and (
        (review_case.subject_identity_type = 'person'
          and review_case.subject_person_id = byline.source_person_id)
        or (review_case.subject_identity_type = 'organization'
          and review_case.subject_organizational_contributor_id
            = byline.organizational_contributor_id)
        or (review_case.subject_identity_type = 'show'
          and review_case.subject_show_id = byline.show_id)
      )
  )
  union
  select
    ready.id,
    'show'::text,
    null::uuid,
    null::uuid,
    ready.show_id
  from public.news_ready_item_read_model ready
  where ready.publication_state = 'published'
    and ready.publication_time <= statement_timestamp()
    and ready.destination_url_kind in ('canonical', 'alternate')
    and ready.show_id is not null;
$$;

create or replace function public.search_news_follow_targets(
  query_value text default null,
  team_public_id_value text default null
)
returns table (
  target_type text,
  target_id text,
  display_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_query_value text := lower(
    regexp_replace(btrim(coalesce(query_value, '')), '\s+', ' ', 'g')
  );
  team_uuid uuid;
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  if team_public_id_value is not null then
    team_uuid := public.resolve_catalog_team_id(team_public_id_value);
  end if;

  return query
  select identity.target_type, identity.target_id, identity.display_name
  from private.current_news_followable_identities() identity
  where (
    normalized_query_value = ''
    or position(normalized_query_value in lower(
      regexp_replace(btrim(identity.display_name), '\s+', ' ', 'g')
    )) > 0
  )
    and (
      team_uuid is null
      or exists (
        select 1
        from private.current_news_published_identity_credits() credit
        join public.news_item_classifications classification
          on classification.news_item_id = credit.news_item_id
        join public.news_item_classification_versions version
          on version.classification_id = classification.id and version.is_current
        where version.team_id = team_uuid
          and (
            (identity.target_type = 'author' and credit.target_type = 'author'
              and credit.person_id = identity.person_id)
            or (identity.target_type = 'organization'
              and credit.target_type = 'organization'
              and credit.organizational_contributor_id
                = identity.organizational_contributor_id)
            or (identity.target_type = 'show' and credit.target_type = 'show'
              and credit.show_id = identity.show_id)
          )
      )
    )
  order by
    case
      when normalized_query_value = '' then 0
      when lower(identity.display_name) = normalized_query_value then 0
      when lower(identity.display_name) like normalized_query_value || '%' then 1
      else 2
    end,
    lower(identity.display_name),
    identity.target_type,
    identity.target_id;
end;
$$;

create or replace function public.get_news_identity_profile(
  target_type_value text,
  target_public_id_value text
)
returns table (
  target_type text,
  target_id text,
  display_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare resolved_target record;
begin
  select * into strict resolved_target
  from private.resolve_news_follow_target(target_type_value, target_public_id_value);

  return query
  select identity.target_type, identity.target_id, identity.display_name
  from private.current_news_followable_identities() identity
  where (
    resolved_target.target_type = 'author'
      and identity.target_type = 'author'
      and identity.person_id = resolved_target.person_id
  ) or (
    resolved_target.target_type = 'organization'
      and identity.target_type = 'organization'
      and identity.organizational_contributor_id
        = resolved_target.organizational_contributor_id
  ) or (
    resolved_target.target_type = 'show'
      and identity.target_type = 'show'
      and identity.show_id = resolved_target.show_id
  );
end;
$$;

create or replace function public.get_news_identity_items(
  target_type_value text,
  target_public_id_value text,
  cursor_publication_time_value timestamptz default null,
  cursor_news_item_id_value text default null,
  page_size_value integer default null
)
returns table (
  news_item_id text,
  item_kind text,
  headline text,
  summary text,
  publication_time timestamptz,
  server_time timestamptz,
  destination_url text,
  publisher_id text,
  publisher_name text,
  show_id text,
  show_name text,
  preview_url text,
  preview_kind text,
  preview_alt_text text,
  bylines jsonb,
  classifications jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare profile_record record;
begin
  select * into profile_record
  from public.get_news_identity_profile(target_type_value, target_public_id_value);
  if not found then
    raise exception 'News identity is not currently available for a fan profile';
  end if;
  perform private.validate_news_feed_request(
    'all', null, cursor_publication_time_value, cursor_news_item_id_value,
    page_size_value
  );
  return query
  select * from private.get_news_feed_for_targets(
    null,
    jsonb_build_array(jsonb_build_object(
      'target_type', profile_record.target_type,
      'target_id', profile_record.target_id
    )),
    'all', null, cursor_publication_time_value, cursor_news_item_id_value,
    page_size_value
  );
end;
$$;

create or replace function public.get_news_navigation()
returns table (
  filter_type text,
  target_id text,
  display_name text,
  sport_id text
)
language sql
stable
security definer
set search_path = ''
as $$
  select navigation.*
  from (
    select 'sport'::text as filter_type, sport.sport_id as target_id,
      sport.display_name, sport.sport_id
    from public.catalog_sports sport
    where sport.active
    union all
    select
      'competition'::text,
      competition.competition_id,
      identity.display_name,
      sport.sport_id
    from public.catalog_competitions competition
    join public.catalog_sports sport on sport.id = competition.sport_id
    join public.competition_identity_versions identity
      on identity.competition_id = competition.id
     and identity.is_current and identity.active
    union all
    select
      'team'::text,
      team.team_id,
      identity.display_name,
      sport.sport_id
    from public.catalog_teams team
    join public.catalog_sports sport on sport.id = team.sport_id
    join public.team_identity_versions identity
      on identity.team_id = team.id and identity.is_current and identity.active
  ) navigation
  order by navigation.filter_type, lower(navigation.display_name),
    navigation.target_id;
$$;

-- The zero-follow EXAMPLE is outside personal-feed eligibility. When a current,
-- followable official Team newsroom identity has usable published work, return
-- its latest Team Item; otherwise the frontend uses the controlled static
-- example authorized by FAN-NEWS-13.
create or replace function public.get_my_news_zero_follow_example(
  team_public_id_value text
)
returns table (
  news_item_id text,
  item_kind text,
  headline text,
  summary text,
  publication_time timestamptz,
  server_time timestamptz,
  destination_url text,
  publisher_id text,
  publisher_name text,
  show_id text,
  show_name text,
  preview_url text,
  preview_kind text,
  preview_alt_text text,
  bylines jsonb,
  classifications jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  team_uuid uuid;
  canonical_team_public_id text;
begin
  if auth.uid() is null then raise exception 'Authentication is required'; end if;
  if exists (
    select 1 from public.user_news_identity_follows follow
    where follow.user_id = auth.uid() and follow.is_current
  ) then
    raise exception 'The News EXAMPLE is available only when the fan has zero follows';
  end if;

  team_uuid := public.resolve_catalog_team_id(team_public_id_value);
  select team.team_id into strict canonical_team_public_id
  from public.catalog_teams team where team.id = team_uuid;

  return query
  with official_identity as (
    select
      contributor.contributor_id as contributor_public_id,
      relationship.publisher_source_id
    from public.news_official_team_publication_versions relationship
    join public.news_organizational_contributors contributor
      on contributor.id = relationship.organizational_contributor_id
    join public.news_followable_identity_versions followability
      on followability.target_type = 'organization'
     and followability.organizational_contributor_id = contributor.id
     and followability.is_current and followability.followable
    where relationship.team_id = team_uuid
      and relationship.is_current
      and relationship.relationship_type = 'official_newsroom'
      and (relationship.effective_from is null
        or relationship.effective_from <= statement_timestamp())
      and (relationship.effective_to is null
        or statement_timestamp() < relationship.effective_to)
  ), candidate as (
    select feed.*
    from official_identity
    cross join lateral private.get_news_feed_for_targets(
      null,
      jsonb_build_array(jsonb_build_object(
        'target_type', 'organization',
        'target_id', official_identity.contributor_public_id
      )),
      'team', canonical_team_public_id, null, null, null
    ) feed
    join public.news_ready_item_read_model ready
      on ready.news_item_id = feed.news_item_id
     and ready.publisher_source_id = official_identity.publisher_source_id
  )
  select
    candidate.news_item_id,
    candidate.item_kind,
    candidate.headline,
    candidate.summary,
    candidate.publication_time,
    candidate.server_time,
    candidate.destination_url,
    candidate.publisher_id,
    candidate.publisher_name,
    candidate.show_id,
    candidate.show_name,
    candidate.preview_url,
    candidate.preview_kind,
    candidate.preview_alt_text,
    candidate.bylines,
    candidate.classifications
  from candidate
  order by candidate.publication_time desc, candidate.news_item_id
  limit 1;
end;
$$;

create or replace function public.record_news_outbound_open(
  news_item_public_id_value text,
  destination_url_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_uuid uuid := gen_random_uuid();
  item_uuid uuid;
  destination_version_uuid uuid;
  manifestation_url_uuid uuid;
begin
  select
    ready.id,
    ready.representative_destination_version_id,
    ready.manifestation_url_id
  into strict item_uuid, destination_version_uuid, manifestation_url_uuid
  from public.news_ready_item_read_model ready
  where ready.news_item_id = news_item_public_id_value
    and ready.publication_state = 'published'
    and ready.publication_time <= statement_timestamp()
    and ready.destination_url_kind in ('canonical', 'alternate')
    and ready.destination_url = destination_url_value;

  insert into public.news_outbound_open_events(
    id, news_item_id, representative_destination_version_id,
    manifestation_url_id, viewer_user_id
  ) values (
    event_uuid, item_uuid, destination_version_uuid,
    manifestation_url_uuid, auth.uid()
  );
  return event_uuid;
end;
$$;

revoke all on function public.search_news_follow_targets(text,text)
from public, anon;
grant execute on function public.search_news_follow_targets(text,text)
to authenticated;

revoke all on function public.get_news_identity_profile(text,text) from public;
grant execute on function public.get_news_identity_profile(text,text)
to anon, authenticated;
revoke all on function public.get_news_identity_items(
  text,text,timestamptz,text,integer
) from public;
grant execute on function public.get_news_identity_items(
  text,text,timestamptz,text,integer
) to anon, authenticated;
revoke all on function public.get_news_navigation() from public;
grant execute on function public.get_news_navigation() to anon, authenticated;
revoke all on function public.get_my_news_zero_follow_example(text)
from public, anon;
grant execute on function public.get_my_news_zero_follow_example(text)
to authenticated;
revoke all on function public.record_news_outbound_open(text,text) from public;
grant execute on function public.record_news_outbound_open(text,text)
to anon, authenticated;

revoke all on function private.current_news_followable_identities()
from public, anon, authenticated;
revoke all on function private.current_news_published_identity_credits()
from public, anon, authenticated;
revoke all on function public.protect_news_outbound_open_event()
from public, anon, authenticated;

comment on table public.news_outbound_open_events is
  'Immutable best-effort records of FANatical-initiated outbound opens. These are not publisher views and never delay navigation.';
comment on function public.search_news_follow_targets(text,text) is
  'Authenticated Add to Feed discovery over currently followable individual Authors, organizations, and Shows; optional Team context lists identities individually and never provides Follow All.';
comment on function public.get_news_identity_items(
  text,text,timestamptz,text,integer
) is
  'Fan-safe profile Items using the same target-based publication, attribution-review, destination, preview, and chronology contract as personal and Demo feeds.';
comment on function public.get_my_news_zero_follow_example(text) is
  'Returns at most one real current official-Team newsroom Item only for an authenticated fan with zero actual News follows; it creates no follow or eligibility.';
comment on function public.record_news_outbound_open(text,text) is
  'Best-effort append after revalidating the currently published Item and representative destination; the caller must not await it before navigation.';

select private.assert_news_domain_mutation_registry();
