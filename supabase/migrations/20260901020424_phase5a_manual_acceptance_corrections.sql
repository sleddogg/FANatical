-- Phase 5A manual-acceptance corrections.
--
-- This migration is additive to the local-only Phase 5A foundation. It keeps
-- the canonical Competition and Community models intact while correcting
-- effective Sport routing, report idempotency, tombstone attribution,
-- restriction reversal, navigation presentation metadata, and the production
-- Team FANbase discussion read path.

-- ---------------------------------------------------------------------------
-- One fan may report a given durable comment at most once.
-- ---------------------------------------------------------------------------

create unique index community_reports_reporter_comment_unique_idx
on public.community_reports(reporting_user_id, comment_id);

-- ---------------------------------------------------------------------------
-- Append-only restriction reversal. The original restriction is retained.
-- ---------------------------------------------------------------------------

create table public.community_posting_restriction_lifts (
  id uuid primary key default gen_random_uuid(),
  lift_id text not null unique default (
    'community-restriction-lift-' || replace(gen_random_uuid()::text, '-', '')
  ) check (lift_id ~ '^community-restriction-lift-[0-9a-f]{32}$'),
  restriction_id uuid not null unique
    references public.community_posting_restrictions(id) on delete restrict,
  lifted_by_staff_user_id uuid not null
    references auth.users(id) on delete restrict,
  reason text not null check (length(btrim(reason)) > 0),
  lifted_at timestamptz not null default statement_timestamp()
);

create index community_posting_restriction_lifts_time_idx
on public.community_posting_restriction_lifts(lifted_at desc, id);

alter table public.community_posting_restriction_lifts enable row level security;
revoke all on table public.community_posting_restriction_lifts
from public, anon, authenticated;

create trigger protect_community_posting_restriction_lifts
before update or delete on public.community_posting_restriction_lifts
for each row execute function private.protect_community_immutable_row();

-- A successful lift gets one account-owned moderation notice. Keep the source
-- explicit so lift restoration never enters the social notification system.
alter table public.community_moderation_notices
  alter column moderation_action_id drop not null,
  add column restriction_lift_id uuid
    references public.community_posting_restriction_lifts(id) on delete restrict,
  drop constraint community_moderation_notices_notice_type_check,
  add constraint community_moderation_notices_notice_type_check check (
    notice_type in (
      'comment_removed', 'posting_restricted', 'posting_restored'
    )
  ),
  add constraint community_moderation_notices_source_check check (
    (
      notice_type in ('comment_removed', 'posting_restricted')
      and moderation_action_id is not null
      and restriction_lift_id is null
    )
    or (
      notice_type = 'posting_restored'
      and moderation_action_id is null
      and restriction_lift_id is not null
    )
  ),
  add constraint community_moderation_notices_restriction_lift_id_key
    unique (restriction_lift_id);

-- ---------------------------------------------------------------------------
-- News navigation exposes governed Competition kind and followed-Team state.
-- League remains a Competition kind and every filter still uses the canonical
-- Competition identity/context underneath.
-- ---------------------------------------------------------------------------

drop function public.get_news_navigation();

create function public.get_news_navigation()
returns table (
  filter_type text,
  target_id text,
  display_name text,
  sport_id text,
  competition_kind_id text,
  is_followed boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select navigation.*
  from (
    select
      'sport'::text as filter_type,
      sport.sport_id as target_id,
      sport.display_name,
      sport.sport_id,
      null::text as competition_kind_id,
      false as is_followed
    from public.catalog_sports sport
    where sport.active

    union all

    select
      'competition'::text,
      competition.competition_id,
      identity.display_name,
      sport.sport_id,
      kind.kind_id,
      false
    from public.catalog_competitions competition
    join public.catalog_sports sport on sport.id = competition.sport_id
    join public.competition_kinds kind on kind.id = competition.kind_id
    join public.competition_identity_versions identity
      on identity.competition_id = competition.id
     and identity.is_current
     and identity.active
    where kind.active

    union all

    select
      'team'::text,
      team.team_id,
      identity.display_name,
      sport.sport_id,
      null::text,
      private.community_context_is_accessible(
        (select auth.uid()),
        'team',
        team.id
      )
    from public.catalog_teams team
    join public.catalog_sports sport on sport.id = team.sport_id
    join public.team_identity_versions identity
      on identity.team_id = team.id
     and identity.is_current
     and identity.active
  ) navigation
  order by navigation.filter_type,
    lower(navigation.display_name),
    navigation.target_id;
$$;

revoke all on function public.get_news_navigation() from public;
grant execute on function public.get_news_navigation() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Effective Sport scope matches the production News feed roll-up exactly.
-- ---------------------------------------------------------------------------

create or replace function private.news_item_has_effective_sport_context(
  news_item_uuid uuid,
  sport_uuid uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.news_item_classifications classification
    join public.news_item_classification_versions version
      on version.classification_id = classification.id
     and version.is_current
    left join public.catalog_competitions competition
      on competition.id = version.competition_id
    left join public.catalog_competition_editions edition
      on edition.id = version.competition_edition_id
    left join public.catalog_competitions edition_competition
      on edition_competition.id = edition.competition_id
    left join public.catalog_teams team on team.id = version.team_id
    where classification.news_item_id = news_item_uuid
      and coalesce(
        version.sport_id,
        competition.sport_id,
        edition_competition.sport_id,
        team.sport_id
      ) = sport_uuid
  );
$$;

revoke all on function private.news_item_has_effective_sport_context(uuid, uuid)
from public, anon, authenticated;

create or replace function private.community_context_display_kind(
  context_kind_value text,
  context_uuid_value uuid
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case context_kind_value
    when 'team' then 'Team'
    when 'sport' then 'Sport'
    when 'competition' then case when exists (
      select 1
      from public.catalog_competitions competition
      join public.competition_kinds kind on kind.id = competition.kind_id
      where competition.id = context_uuid_value
        and kind.kind_id = 'league'
    ) then 'League' else 'Competition' end
    else 'News'
  end;
$$;

revoke all on function private.community_context_display_kind(text, uuid)
from public, anon, authenticated;

create or replace function private.resolve_news_discussion_context(
  news_item_public_id_value text,
  origin_context_kind_value text default null,
  origin_context_public_id_value text default null
)
returns table (
  news_item_uuid uuid,
  news_item_public_id text,
  context_kind text,
  context_uuid uuid,
  context_public_id text,
  context_display_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  item_uuid uuid;
  context_record record;
  normalized_kind text := lower(nullif(btrim(origin_context_kind_value), ''));
  competition_count integer;
  sport_count integer;
begin
  select item.id
  into item_uuid
  from public.news_items item
  join public.news_item_versions item_version
    on item_version.news_item_id = item.id
   and item_version.is_current
   and item_version.publication_state = 'published'
   and item_version.publication_time <= statement_timestamp()
  where item.news_item_id = news_item_public_id_value;

  if item_uuid is null then
    return;
  end if;

  if normalized_kind is not null then
    if normalized_kind not in ('team', 'competition', 'sport')
      or nullif(btrim(origin_context_public_id_value), '') is null then
      return;
    end if;

    if normalized_kind = 'team' then
      select team.id, team.team_id as public_id, identity.display_name
      into context_record
      from public.news_item_classifications classification
      join public.news_item_classification_versions version
        on version.classification_id = classification.id
       and version.is_current
       and version.target_type = 'team'
      join public.catalog_teams team on team.id = version.team_id
      left join public.team_identity_versions identity
        on identity.team_id = team.id and identity.is_current
      where classification.news_item_id = item_uuid
        and team.id = public.resolve_catalog_team_id(
          origin_context_public_id_value
        )
      limit 1;
    elsif normalized_kind = 'competition' then
      select competition.id, competition.competition_id as public_id,
        identity.display_name
      into context_record
      from public.news_item_classifications classification
      join public.news_item_classification_versions version
        on version.classification_id = classification.id
       and version.is_current
       and version.target_type = 'competition'
      join public.catalog_competitions competition
        on competition.id = version.competition_id
      left join public.competition_identity_versions identity
        on identity.competition_id = competition.id and identity.is_current
      where classification.news_item_id = item_uuid
        and competition.competition_id = origin_context_public_id_value
      limit 1;
    else
      select sport.id, sport.sport_id as public_id, sport.display_name
      into context_record
      from public.catalog_sports sport
      where sport.sport_id = origin_context_public_id_value
        and private.news_item_has_effective_sport_context(
          item_uuid,
          sport.id
        )
      limit 1;
    end if;

    if context_record.id is null then
      return;
    end if;

    return query select
      item_uuid,
      news_item_public_id_value,
      normalized_kind,
      context_record.id,
      context_record.public_id,
      coalesce(context_record.display_name, context_record.public_id);
    return;
  end if;

  select count(distinct version.competition_id)
  into competition_count
  from public.news_item_classifications classification
  join public.news_item_classification_versions version
    on version.classification_id = classification.id
   and version.is_current
   and version.target_type = 'competition'
  where classification.news_item_id = item_uuid;

  if competition_count = 1 then
    select competition.id, competition.competition_id as public_id,
      identity.display_name
    into context_record
    from public.news_item_classifications classification
    join public.news_item_classification_versions version
      on version.classification_id = classification.id
     and version.is_current
     and version.target_type = 'competition'
    join public.catalog_competitions competition
      on competition.id = version.competition_id
    left join public.competition_identity_versions identity
      on identity.competition_id = competition.id and identity.is_current
    where classification.news_item_id = item_uuid
    limit 1;

    return query select
      item_uuid,
      news_item_public_id_value,
      'competition'::text,
      context_record.id,
      context_record.public_id,
      coalesce(context_record.display_name, context_record.public_id);
    return;
  end if;

  select count(distinct version.sport_id)
  into sport_count
  from public.news_item_classifications classification
  join public.news_item_classification_versions version
    on version.classification_id = classification.id
   and version.is_current
   and version.target_type = 'sport'
  where classification.news_item_id = item_uuid;

  if sport_count = 1 then
    select sport.id, sport.sport_id as public_id, sport.display_name
    into context_record
    from public.news_item_classifications classification
    join public.news_item_classification_versions version
      on version.classification_id = classification.id
     and version.is_current
     and version.target_type = 'sport'
    join public.catalog_sports sport on sport.id = version.sport_id
    where classification.news_item_id = item_uuid
    limit 1;

    return query select
      item_uuid,
      news_item_public_id_value,
      'sport'::text,
      context_record.id,
      context_record.public_id,
      context_record.display_name;
  end if;
end;
$$;

revoke all on function private.resolve_news_discussion_context(text, text, text)
from public, anon, authenticated;

create or replace function private.community_discussion_context_is_current(
  discussion_uuid uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.community_discussions discussion
    where discussion.id = discussion_uuid
      and (
        (
          discussion.context_kind = 'team'
          and exists (
            select 1
            from public.news_item_classifications classification
            join public.news_item_classification_versions version
              on version.classification_id = classification.id
             and version.is_current
             and version.target_type = 'team'
             and version.team_id = discussion.team_id
            where classification.news_item_id = discussion.news_item_id
          )
        )
        or (
          discussion.context_kind = 'competition'
          and exists (
            select 1
            from public.news_item_classifications classification
            join public.news_item_classification_versions version
              on version.classification_id = classification.id
             and version.is_current
             and version.target_type = 'competition'
             and version.competition_id = discussion.competition_id
            where classification.news_item_id = discussion.news_item_id
          )
        )
        or (
          discussion.context_kind = 'sport'
          and private.news_item_has_effective_sport_context(
            discussion.news_item_id,
            discussion.sport_id
          )
        )
      )
  );
$$;

revoke all on function private.community_discussion_context_is_current(uuid)
from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Fan-safe article reference shared by News and FANbase discussion routes.
-- ---------------------------------------------------------------------------

create or replace function private.news_discussion_article_payload(
  news_item_uuid uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'news_item_id', ready.news_item_id,
    'item_kind', ready.item_kind,
    'headline', ready.headline,
    'publication_time', ready.publication_time,
    'destination_url', ready.destination_url,
    'publisher_name', ready.publisher_name,
    'show_name', ready.show_name,
    'preview_url', ready.preview_url,
    'preview_kind', ready.preview_kind,
    'preview_alt_text', preview.alt_text,
    'bylines', coalesce(byline_rows.items, '[]'::jsonb)
  )
  from public.news_ready_item_read_model ready
  left join lateral (
    select remote.alt_text
    from public.news_remote_preview_references remote
    join public.news_remote_preview_policy_versions policy
      on policy.preview_reference_id = remote.id
     and policy.is_current
     and policy.publisher_policy_state = 'approved'
    where remote.manifestation_id = ready.manifestation_id
      and remote.remote_url = ready.preview_url
    limit 1
  ) preview on true
  left join lateral (
    select jsonb_agg(
      byline.value ->> 'raw_attribution'
      order by byline.ordinality
    ) filter (
      where nullif(btrim(byline.value ->> 'raw_attribution'), '') is not null
    ) as items
    from jsonb_array_elements(ready.bylines)
      with ordinality as byline(value, ordinality)
  ) byline_rows on true
  where ready.id = news_item_uuid
    and ready.publication_state = 'published'
    and ready.publication_time <= statement_timestamp()
    and ready.destination_url_kind in ('canonical', 'alternate');
$$;

revoke all on function private.news_discussion_article_payload(uuid)
from public, anon, authenticated;

create or replace function public.get_news_discussion_teaser(
  news_item_public_id_value text,
  origin_context_kind_value text default null,
  origin_context_public_id_value text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  resolved record;
  discussion_record record;
begin
  select * into resolved
  from private.resolve_news_discussion_context(
    news_item_public_id_value,
    origin_context_kind_value,
    origin_context_public_id_value
  );

  if resolved.news_item_uuid is null then
    return jsonb_build_object(
      'available', false,
      'requires_auth', (select auth.uid()) is null,
      'viewer_can_access', case when (select auth.uid()) is null
        then null else false end,
      'comment_count', 0
    );
  end if;

  select discussion.discussion_id, discussion.comment_count
  into discussion_record
  from public.community_discussions discussion
  where discussion.news_item_id = resolved.news_item_uuid
    and discussion.context_kind = resolved.context_kind
    and coalesce(
      discussion.team_id,
      discussion.competition_id,
      discussion.sport_id
    ) = resolved.context_uuid;

  return jsonb_build_object(
    'available', true,
    'requires_auth', (select auth.uid()) is null,
    'viewer_can_access', case when (select auth.uid()) is null then null
      else exists (
        select 1
        from private.fan_profile_population fan_profile
        where fan_profile.user_id = (select auth.uid())
      ) and private.community_context_is_accessible(
          (select auth.uid()),
          resolved.context_kind,
          resolved.context_uuid
        ) end,
    'news_item_id', resolved.news_item_public_id,
    'context_kind', resolved.context_kind,
    'context_display_kind', private.community_context_display_kind(
      resolved.context_kind,
      resolved.context_uuid
    ),
    'context_id', resolved.context_public_id,
    'context_name', resolved.context_display_name,
    'discussion_id', discussion_record.discussion_id,
    'comment_count', coalesce(discussion_record.comment_count, 0),
    'article', private.news_discussion_article_payload(
      resolved.news_item_uuid
    )
  );
end;
$$;

revoke all on function public.get_news_discussion_teaser(text, text, text)
from public, anon, authenticated;
grant execute on function public.get_news_discussion_teaser(text, text, text)
to anon, authenticated;

-- ---------------------------------------------------------------------------
-- One fan-wide suspension boundary governs every Community participation RPC.
-- Lifted rows no longer contribute to its effective database-time window.
-- ---------------------------------------------------------------------------

create or replace function private.community_active_suspension_end(
  fan_user_id uuid
)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select max(restriction.ends_at)
  from public.community_posting_restrictions restriction
  where restriction.user_id = fan_user_id
    and restriction.starts_at <= statement_timestamp()
    and restriction.ends_at > statement_timestamp()
    and not exists (
      select 1
      from public.community_posting_restriction_lifts lift
      where lift.restriction_id = restriction.id
        and lift.lifted_at <= statement_timestamp()
    );
$$;

revoke all on function private.community_active_suspension_end(uuid)
from public, anon, authenticated;

create or replace function public.get_community_discussion(
  discussion_public_id_value text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  viewer_id uuid := auth.uid();
  discussion_record record;
  comments_payload jsonb;
  restricted_until timestamptz;
  viewer_handle text;
begin
  perform private.assert_community_fan(viewer_id, false);

  select
    discussion.id,
    discussion.discussion_id,
    discussion.context_kind,
    coalesce(discussion.team_id, discussion.competition_id, discussion.sport_id)
      as context_uuid,
    discussion.comment_count,
    private.community_discussion_context_is_current(discussion.id)
      as context_is_current,
    item.id as news_item_uuid,
    item.news_item_id,
    coalesce(team.team_id, competition.competition_id, sport.sport_id)
      as context_public_id,
    coalesce(
      team_identity.display_name,
      competition_identity.display_name,
      sport.display_name,
      team.team_id,
      competition.competition_id,
      sport.sport_id
    ) as context_display_name
  into discussion_record
  from public.community_discussions discussion
  join public.news_items item on item.id = discussion.news_item_id
  left join public.catalog_teams team on team.id = discussion.team_id
  left join public.team_identity_versions team_identity
    on team_identity.team_id = team.id and team_identity.is_current
  left join public.catalog_competitions competition
    on competition.id = discussion.competition_id
  left join public.competition_identity_versions competition_identity
    on competition_identity.competition_id = competition.id
   and competition_identity.is_current
  left join public.catalog_sports sport on sport.id = discussion.sport_id
  where discussion.discussion_id = discussion_public_id_value;

  if discussion_record.id is null then
    return null;
  end if;

  if not private.community_context_is_accessible(
    viewer_id,
    discussion_record.context_kind,
    discussion_record.context_uuid
  ) then
    raise exception 'Follow this Team to access its FANbase discussion';
  end if;

  select profile.handle
  into viewer_handle
  from public.profiles profile
  where profile.user_id = viewer_id;

  restricted_until := private.community_active_suspension_end(viewer_id);

  with recursive descendants(root_id, descendant_id) as (
    select comment.id, comment.id
    from public.community_comments comment
    where comment.discussion_id = discussion_record.id
    union all
    select descendants.root_id, child.id
    from descendants
    join public.community_comments child
      on child.parent_comment_id = descendants.descendant_id
     and child.discussion_id = discussion_record.id
  ), descendant_counts as (
    select root_id, count(*) - 1 as reply_count
    from descendants
    group by root_id
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'comment_id', comment.comment_id,
        'parent_comment_id', parent.comment_id,
        'body', case
          when comment.status = 'deleted' then 'Comment deleted'
          when comment.status = 'moderated' then 'Content removed'
          when visibility.users_are_separated then 'Content unavailable'
          else comment.body
        end,
        'status', case
          when comment.status = 'deleted' then 'deleted'
          when comment.status = 'moderated' then 'moderated'
          when visibility.users_are_separated then 'unavailable'
          else 'active'
        end,
        'author_hidden', visibility.users_are_separated,
        'fanatical_name', case
          when visibility.users_are_separated then null
          else author_profile.handle
        end,
        'avatar', case
          when visibility.users_are_separated then null
          else (
            select jsonb_build_object(
              'display_path', photo.display_path,
              'width', photo.source_width,
              'height', photo.source_height,
              'focal_x', photo.focal_x,
              'focal_y', photo.focal_y,
              'zoom', photo.zoom
            )
            from public.profile_photos photo
            where photo.id = author_profile.active_profile_photo_id
              and photo.user_id = author_profile.user_id
              and private.profile_avatar_path_is_fan_safe(
                photo.user_id,
                photo.display_path
              )
          )
        end,
        'created_at', comment.created_at,
        'edited', comment.edited_at is not null,
        'reply_count', coalesce(descendant_counts.reply_count, 0),
        'can_reply', comment.status = 'active'
          and discussion_record.context_is_current
          and viewer_handle <> ''
          and restricted_until is null
          and not visibility.users_are_separated,
        'can_edit', comment.status = 'active'
          and comment.author_user_id = viewer_id
          and restricted_until is null
          and statement_timestamp() <= comment.created_at + interval '7 days',
        'can_delete', comment.status = 'active'
          and comment.author_user_id = viewer_id
          and restricted_until is null,
        'viewer_has_reported', report_state.viewer_has_reported,
        'can_report', comment.status = 'active'
          and comment.author_user_id <> viewer_id
          and not visibility.users_are_separated
          and not report_state.viewer_has_reported,
        'can_hide', comment.status = 'active'
          and comment.author_user_id <> viewer_id
          and not exists (
            select 1
            from public.community_hide_intents intent
            where intent.hider_id = viewer_id
              and intent.hidden_id = comment.author_user_id
          ),
        'my_hide_intent_id', (
          select intent.hide_intent_id
          from public.community_hide_intents intent
          where intent.hider_id = viewer_id
            and intent.hidden_id = comment.author_user_id
        ),
        'can_unhide', exists (
          select 1
          from public.community_hide_intents intent
          where intent.hider_id = viewer_id
            and intent.hidden_id = comment.author_user_id
        )
      ) order by comment.created_at, comment.id
    ),
    '[]'::jsonb
  )
  into comments_payload
  from public.community_comments comment
  left join public.community_comments parent
    on parent.id = comment.parent_comment_id
  join public.profiles author_profile
    on author_profile.user_id = comment.author_user_id
  left join descendant_counts on descendant_counts.root_id = comment.id
  cross join lateral (
    select private.community_users_are_separated(
      viewer_id,
      comment.author_user_id
    ) as users_are_separated
  ) visibility
  cross join lateral (
    select exists (
      select 1
      from public.community_reports report
      where report.comment_id = comment.id
        and report.reporting_user_id = viewer_id
    ) as viewer_has_reported
  ) report_state
  where comment.discussion_id = discussion_record.id;

  return jsonb_build_object(
    'discussion_id', discussion_record.discussion_id,
    'news_item_id', discussion_record.news_item_id,
    'context_kind', discussion_record.context_kind,
    'context_display_kind', private.community_context_display_kind(
      discussion_record.context_kind,
      discussion_record.context_uuid
    ),
    'context_id', discussion_record.context_public_id,
    'context_name', discussion_record.context_display_name,
    'comment_count', discussion_record.comment_count,
    'context_is_current', discussion_record.context_is_current,
    'viewer_has_fanatical_name', viewer_handle <> '',
    'posting_restricted_until', restricted_until,
    'article', private.news_discussion_article_payload(
      discussion_record.news_item_uuid
    ),
    'comments', comments_payload
  );
end;
$$;

revoke all on function public.get_community_discussion(text)
from public, anon, authenticated;
grant execute on function public.get_community_discussion(text)
to authenticated;

create or replace function public.report_community_comment(
  comment_public_id_value text,
  reason_value text,
  explanation_value text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
  comment_record record;
  inserted_report_id text;
  existing_report_id text;
  reported_version_number_value integer;
  normalized_reason text := lower(btrim(coalesce(reason_value, '')));
  normalized_explanation text := nullif(btrim(explanation_value), '');
begin
  perform private.assert_community_fan(owner_id, false);

  if normalized_reason not in ('spam', 'harassment', 'hate', 'threats') then
    raise exception 'Report reason must be Spam, Harassment, Hate, or Threats';
  end if;

  select comment.id,
    comment.author_user_id,
    comment.status,
    comment.body,
    comment.edited_at,
    discussion.context_kind,
    coalesce(
      discussion.team_id,
      discussion.competition_id,
      discussion.sport_id
    ) as context_uuid
  into comment_record
  from public.community_comments comment
  join public.community_discussions discussion
    on discussion.id = comment.discussion_id
  where comment.comment_id = comment_public_id_value
  for share of comment;

  select max(version.version_number)
  into reported_version_number_value
  from public.community_comment_versions version
  where version.comment_id = comment_record.id;

  if comment_record.id is null or comment_record.status <> 'active' then
    raise exception 'Comment is unavailable for reporting';
  end if;
  if comment_record.author_user_id = owner_id then
    raise exception 'A fan cannot report their own comment';
  end if;
  if not private.community_context_is_accessible(
    owner_id,
    comment_record.context_kind,
    comment_record.context_uuid
  ) then
    raise exception 'Follow this Team to access its FANbase discussion';
  end if;
  if private.community_users_are_separated(
    owner_id,
    comment_record.author_user_id
  ) then
    raise exception 'Content unavailable between hidden fans cannot be reported';
  end if;

  insert into public.community_reports (
    comment_id,
    reporting_user_id,
    reason,
    explanation,
    reported_body,
    reported_edited_at,
    reported_version_number
  ) values (
    comment_record.id,
    owner_id,
    normalized_reason,
    normalized_explanation,
    comment_record.body,
    comment_record.edited_at,
    reported_version_number_value
  )
  on conflict (reporting_user_id, comment_id) do nothing
  returning report_id into inserted_report_id;

  if inserted_report_id is null then
    select report.report_id
    into existing_report_id
    from public.community_reports report
    where report.reporting_user_id = owner_id
      and report.comment_id = comment_record.id;
  end if;

  return jsonb_build_object(
    'report_id', coalesce(inserted_report_id, existing_report_id),
    'already_reported', inserted_report_id is null
  );
end;
$$;

revoke all on function public.report_community_comment(text, text, text)
from public, anon, authenticated;
grant execute on function public.report_community_comment(text, text, text)
to authenticated;

create or replace function public.get_active_community_posting_restrictions()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  restrictions_payload jsonb;
begin
  if not public.has_staff_access(null, 'community_moderate') then
    raise exception 'Community moderation permission is required';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'restriction_id', restriction.restriction_id,
        'fanatical_name', profile.handle,
        'ordinal', restriction.ordinal,
        'starts_at', restriction.starts_at,
        'ends_at', restriction.ends_at,
        'reason', restriction.reason,
        'created_at', restriction.created_at
      ) order by restriction.ends_at, restriction.id
    ),
    '[]'::jsonb
  )
  into restrictions_payload
  from public.community_posting_restrictions restriction
  join public.profiles profile on profile.user_id = restriction.user_id
  where restriction.starts_at <= statement_timestamp()
    and restriction.ends_at > statement_timestamp()
    and not exists (
      select 1
      from public.community_posting_restriction_lifts lift
      where lift.restriction_id = restriction.id
        and lift.lifted_at <= statement_timestamp()
    );

  return restrictions_payload;
end;
$$;

revoke all on function public.get_active_community_posting_restrictions()
from public, anon, authenticated;
grant execute on function public.get_active_community_posting_restrictions()
to authenticated;

create or replace function public.admin_lift_community_posting_restriction(
  restriction_public_id_value text,
  reason_value text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  staff_user_id uuid := auth.uid();
  normalized_reason text := btrim(coalesce(reason_value, ''));
  restriction_record record;
  inserted_lift_uuid uuid;
  inserted_lift_id text;
  lifted_at_value timestamptz;
begin
  if not public.has_staff_access(null, 'community_moderate') then
    raise exception 'Community moderation permission is required';
  end if;
  if normalized_reason = '' then
    raise exception 'A lift reason is required';
  end if;

  select restriction.id,
    restriction.user_id,
    restriction.restriction_id
  into restriction_record
  from public.community_posting_restrictions restriction
  where restriction.restriction_id = restriction_public_id_value
    and restriction.starts_at <= statement_timestamp()
    and restriction.ends_at > statement_timestamp()
    and not exists (
      select 1
      from public.community_posting_restriction_lifts lift
      where lift.restriction_id = restriction.id
    )
  for update of restriction;

  if restriction_record.id is null then
    raise exception 'An active posting restriction was not found';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'fanatical:community-restriction:'
      || restriction_record.user_id::text,
      0
    )
  );

  insert into public.community_posting_restriction_lifts (
    restriction_id,
    lifted_by_staff_user_id,
    reason
  ) values (
    restriction_record.id,
    staff_user_id,
    normalized_reason
  )
  returning id, lift_id, lifted_at
  into inserted_lift_uuid, inserted_lift_id, lifted_at_value;

  insert into public.community_moderation_notices (
    user_id,
    moderation_action_id,
    restriction_lift_id,
    notice_type,
    message
  ) values (
    restriction_record.user_id,
    null,
    inserted_lift_uuid,
    'posting_restored',
    'Your Community suspension was lifted. You may participate again under the normal Community rules.'
  )
  on conflict (restriction_lift_id) do nothing;

  return jsonb_build_object(
    'lift_id', inserted_lift_id,
    'restriction_id', restriction_record.restriction_id,
    'lifted_at', lifted_at_value
  );
end;
$$;

revoke all on function public.admin_lift_community_posting_restriction(text, text)
from public, anon, authenticated;
grant execute on function public.admin_lift_community_posting_restriction(text, text)
to authenticated;

create or replace function public.admin_moderate_community_report(
  report_public_id_value text,
  action_value text,
  reason_value text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  staff_user_id uuid := auth.uid();
  normalized_action text := lower(btrim(coalesce(action_value, '')));
  normalized_reason text := btrim(coalesce(reason_value, ''));
  report_record record;
  comment_record record;
  restriction_uuid uuid;
  restriction_public_id text;
  restriction_ordinal integer;
  restriction_start timestamptz;
  restriction_end timestamptz;
  moderation_action_uuid uuid;
  moderation_action_public_id text;
  next_version integer;
begin
  if not public.has_staff_access(null, 'community_moderate') then
    raise exception 'Community moderation permission is required';
  end if;
  if normalized_action not in ('dismiss', 'tombstone', 'restrict') then
    raise exception 'Moderation action must be dismiss, tombstone, or restrict';
  end if;
  if normalized_reason = '' then
    raise exception 'A moderation reason is required';
  end if;

  select report.*
  into report_record
  from public.community_reports report
  where report.report_id = report_public_id_value
  for update;

  if report_record.id is null or report_record.status <> 'pending' then
    raise exception 'Pending community report was not found';
  end if;

  select comment.*
  into comment_record
  from public.community_comments comment
  where comment.id = report_record.comment_id
  for update;

  if normalized_action = 'tombstone' and comment_record.status <> 'active' then
    raise exception 'Only an active comment can be removed';
  end if;

  if normalized_action = 'tombstone' then
    select coalesce(max(version.version_number), 0) + 1
    into next_version
    from public.community_comment_versions version
    where version.comment_id = comment_record.id;

    update public.community_comments
    set body = null,
        status = 'moderated',
        tombstoned_at = statement_timestamp()
    where id = comment_record.id;

    insert into public.community_comment_versions (
      comment_id,
      version_number,
      change_kind,
      body,
      changed_by_user_id
    ) values (
      comment_record.id,
      next_version,
      'moderator_tombstoned',
      null,
      staff_user_id
    );
  elsif normalized_action = 'restrict' then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        'fanatical:community-restriction:'
        || comment_record.author_user_id::text,
        0
      )
    );

    select coalesce(max(restriction.ordinal), 0) + 1,
      greatest(
        statement_timestamp(),
        coalesce(
          max(restriction.ends_at) filter (where lift.id is null),
          statement_timestamp()
        )
      )
    into restriction_ordinal, restriction_start
    from public.community_posting_restrictions restriction
    left join public.community_posting_restriction_lifts lift
      on lift.restriction_id = restriction.id
    where restriction.user_id = comment_record.author_user_id;

    restriction_end := restriction_start + case
      when restriction_ordinal <= 2 then interval '7 days'
      else interval '14 days'
    end;

    insert into public.community_posting_restrictions (
      user_id,
      ordinal,
      starts_at,
      ends_at,
      originating_report_id,
      applied_by_staff_user_id,
      reason
    ) values (
      comment_record.author_user_id,
      restriction_ordinal,
      restriction_start,
      restriction_end,
      report_record.id,
      staff_user_id,
      normalized_reason
    )
    returning id, restriction_id
    into restriction_uuid, restriction_public_id;
  end if;

  insert into public.community_moderation_actions (
    report_id,
    comment_id,
    target_user_id,
    action_type,
    restriction_id,
    staff_user_id,
    reason
  ) values (
    report_record.id,
    comment_record.id,
    comment_record.author_user_id,
    normalized_action,
    restriction_uuid,
    staff_user_id,
    normalized_reason
  )
  returning id, action_id
  into moderation_action_uuid, moderation_action_public_id;

  update public.community_reports
  set status = case when normalized_action = 'dismiss'
        then 'dismissed' else 'actioned' end,
      resolved_at = statement_timestamp()
  where id = report_record.id;

  if normalized_action = 'tombstone' then
    insert into public.community_moderation_notices (
      user_id,
      moderation_action_id,
      notice_type,
      message
    ) values (
      comment_record.author_user_id,
      moderation_action_uuid,
      'comment_removed',
      'A community moderator removed one of your comments.'
    );
  elsif normalized_action = 'restrict' then
    insert into public.community_moderation_notices (
      user_id,
      moderation_action_id,
      notice_type,
      message
    ) values (
      comment_record.author_user_id,
      moderation_action_uuid,
      'posting_restricted',
      pg_catalog.format(
        'Community participation is suspended until %s. You may continue reading Community content.',
        restriction_end
      )
    );
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'action_id', moderation_action_public_id,
    'action', normalized_action,
    'restriction_id', restriction_public_id,
    'restricted_until', restriction_end
  ));
end;
$$;

revoke all on function public.admin_moderate_community_report(text, text, text)
from public, anon, authenticated;
grant execute on function public.admin_moderate_community_report(text, text, text)
to authenticated;

-- ---------------------------------------------------------------------------
-- Production Team FANbase read path for the same durable contextual threads.
-- ---------------------------------------------------------------------------

create or replace function public.get_team_news_discussions(
  team_public_id_value text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  viewer_id uuid := auth.uid();
  team_record record;
  discussions_payload jsonb;
begin
  perform private.assert_community_fan(viewer_id, false);

  select team.id,
    team.team_id,
    coalesce(identity.display_name, team.team_id) as display_name
  into team_record
  from public.catalog_teams team
  left join public.team_identity_versions identity
    on identity.team_id = team.id and identity.is_current
  where team.id = public.resolve_catalog_team_id(team_public_id_value);

  if team_record.id is null then
    raise exception 'Team was not found';
  end if;

  if not private.community_context_is_accessible(
    viewer_id,
    'team',
    team_record.id
  ) then
    raise exception 'Follow this Team to access its FANbase discussion';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'discussion_id', discussion.discussion_id,
        'news_item_id', ready.news_item_id,
        'context_kind', 'team',
        'context_id', team_record.team_id,
        'context_name', team_record.display_name,
        'comment_count', discussion.comment_count,
        'created_at', discussion.created_at,
        'article', private.news_discussion_article_payload(
          discussion.news_item_id
        )
      ) order by ready.publication_time desc, ready.news_item_id
    ),
    '[]'::jsonb
  )
  into discussions_payload
  from public.community_discussions discussion
  join public.news_ready_item_read_model ready
    on ready.id = discussion.news_item_id
   and ready.publication_state = 'published'
   and ready.publication_time <= statement_timestamp()
   and ready.destination_url_kind in ('canonical', 'alternate')
  where discussion.context_kind = 'team'
    and discussion.team_id = team_record.id
    and private.community_discussion_context_is_current(discussion.id);

  return discussions_payload;
end;
$$;

revoke all on function public.get_team_news_discussions(text)
from public, anon, authenticated;
grant execute on function public.get_team_news_discussions(text)
to authenticated;

-- ---------------------------------------------------------------------------
-- Refresh mechanical Community mutation governance for the new lift event.
-- ---------------------------------------------------------------------------

create or replace function private.community_domain_mutation_registry()
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
  select *
  from (values
    ('public', 'community_discussions', 'governed', array['public.post_news_discussion_comment(text,text,text,text)','public.post_existing_community_discussion_comment(text,text)','public.reply_to_community_comment(text,text,text)'], 'A contextual News discussion is materialized with its first governed comment and its count advances for every governed root or reply.'),
    ('public', 'community_comments', 'governed', array['public.post_news_discussion_comment(text,text,text,text)','public.post_existing_community_discussion_comment(text,text)','public.reply_to_community_comment(text,text,text)','public.edit_my_community_comment(text,text)','public.delete_my_community_comment(text)','public.admin_moderate_community_report(text,text,text)'], 'Comments use owner/staff RPCs; no browser role mutates rows directly.'),
    ('public', 'community_comment_versions', 'governed', array['public.post_news_discussion_comment(text,text,text,text)','public.post_existing_community_discussion_comment(text,text)','public.reply_to_community_comment(text,text,text)','public.edit_my_community_comment(text,text)','public.delete_my_community_comment(text)','public.admin_moderate_community_report(text,text,text)'], 'Internal comment history is appended only with the corresponding governed comment mutation.'),
    ('public', 'community_hide_intents', 'governed', array['public.hide_community_user(text)','public.hide_community_comment_author(text)','public.unhide_community_user(text)','public.unhide_community_intent(text)'], 'Each fan creates or removes only their directed Hide intent; an opaque intent ID keeps owner-controlled removal possible after a name is released.'),
    ('public', 'community_reports', 'governed', array['public.report_community_comment(text,text,text)','public.admin_moderate_community_report(text,text,text)'], 'Fans submit at most one report per durable comment and exact-permission staff resolve reports through bounded operations.'),
    ('public', 'community_posting_restrictions', 'governed', array['public.admin_moderate_community_report(text,text,text)'], 'Database-timed community-only restrictions are appended by exact-permission staff moderation.'),
    ('public', 'community_posting_restriction_lifts', 'governed', array['public.admin_lift_community_posting_restriction(text,text)'], 'Exact-permission staff may append one immediate reversal without mutating or deleting the original restriction.'),
    ('public', 'community_moderation_actions', 'governed', array['public.admin_moderate_community_report(text,text,text)'], 'Report moderation history is append-only.'),
    ('public', 'community_moderation_notices', 'governed', array['public.admin_moderate_community_report(text,text,text)','public.admin_lift_community_posting_restriction(text,text)','public.mark_my_community_moderation_notices_read(text[])'], 'Moderation notices are separate from the social inbox, including exactly-once posting-restoration notices.'),
    ('public', 'community_notifications', 'governed', array['private.insert_community_notification(uuid,text,uuid,uuid,uuid,jsonb)','public.mark_my_community_notifications_read(text[])'], 'Typed social notifications are inserted idempotently by governed domain operations and marked read only by their owner.')
  ) registry(table_schema, table_name, mutation_mode, canonical_operations, rationale);
$$;

revoke all on function private.community_domain_mutation_registry()
from public, anon, authenticated;

comment on table public.community_posting_restriction_lifts is
  'Append-only staff reversal of an auditable Community posting restriction.';
comment on function private.news_item_has_effective_sport_context(uuid, uuid) is
  'Uses the same direct/Competition/Edition/Team Sport roll-up as News feed eligibility.';
comment on function public.get_team_news_discussions(text) is
  'Lists current real Team-context News discussions for an authorized FANbase member.';

select private.assert_community_domain_mutation_registry();
