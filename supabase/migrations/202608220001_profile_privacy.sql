-- Durable profile visibility and record-backed profile-media authorization.
-- Existing media remains in place in the private profile-media bucket.

create schema if not exists private;
revoke all on schema private from public;

alter table public.profiles add column visibility text;
update public.profiles
set visibility = case when is_public then 'public' else 'private' end
where visibility is null;
alter table public.profiles alter column visibility set default 'public';
alter table public.profiles alter column visibility set not null;
alter table public.profiles add constraint profiles_visibility_check
check (visibility in ('public', 'private'));

drop policy if exists "Public profiles are readable" on public.profiles;
drop policy if exists "Public fan identity is readable" on public.fan_identities;
drop policy if exists "Public sports played are readable" on public.sports_played;
drop policy if exists "Public followed teams are readable" on public.user_followed_teams;
drop policy if exists "Public profile visual metadata is readable" on public.profile_visuals;
drop policy if exists "Owners and public profile viewers read profile media" on storage.objects;

-- visibility is the single canonical value. The former boolean cannot drift
-- away from future visibility states.
alter table public.profiles drop column is_public;

alter table public.profile_photos add constraint profile_photos_distinct_media_paths
check (source_path <> display_path);
alter table public.profile_visual_images add constraint profile_visual_images_distinct_media_paths
check (source_path <> display_path);
alter table public.profile_visuals add constraint profile_visuals_distinct_media_paths
check (source_path <> display_path);

create index if not exists profiles_avatar_path_idx
on public.profiles(avatar_path) where avatar_path is not null;
create index if not exists profile_visuals_source_path_idx on public.profile_visuals(source_path);
create index if not exists profile_visuals_display_path_idx on public.profile_visuals(display_path);

create or replace function private.can_view_profile(profile_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles profile
    where profile.user_id = profile_user_id
      and (
        profile.user_id = (select auth.uid())
        or profile.visibility = 'public'
      )
  );
$$;

revoke all on function private.can_view_profile(uuid) from public, anon, authenticated;
grant usage on schema private to anon, authenticated;
grant execute on function private.can_view_profile(uuid) to anon, authenticated;

create policy "Users read their own profile"
on public.profiles for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Viewable fan identity is readable"
on public.fan_identities for select to anon, authenticated
using ((select private.can_view_profile(user_id)));

create policy "Viewable sports played are readable"
on public.sports_played for select to anon, authenticated
using ((select private.can_view_profile(user_id)));

create policy "Viewable followed teams are readable"
on public.user_followed_teams for select to anon, authenticated
using ((select private.can_view_profile(user_id)));

-- The active compatibility table contains source metadata, so direct reads are
-- owner-only. Public display metadata is exposed only through the safe RPC below.
create policy "Users read their own profile visual metadata"
on public.profile_visuals for select to authenticated
using ((select auth.uid()) = user_id);

create or replace function public.get_profile_for_viewer(profile_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when not private.can_view_profile(profile_user_id) then null
    else (
      select jsonb_build_object(
        'profile', jsonb_build_object(
          'user_id', profile.user_id,
          'display_name', profile.display_name,
          'handle', profile.handle,
          'fanatical_name', profile.fanatical_name,
          'given_name', profile.given_name,
          'nickname', profile.nickname,
          'tagline', profile.tagline,
          'birthplace', profile.birthplace,
          'jersey_number', profile.jersey_number,
          'height', profile.height,
          'weight', profile.weight,
          'featured_fan_photo_category', profile.featured_fan_photo_category,
          'primary_profile_text', profile.primary_profile_text,
          'secondary_profile_text', profile.secondary_profile_text,
          'profile_text_position', profile.profile_text_position,
          'visibility', profile.visibility,
          'updated_at', profile.updated_at
        ),
        'fan_identity', coalesce((
          select jsonb_build_object(
            'fan_since', identity.fan_since,
            'favorite_players', identity.favorite_players,
            'game_day_ritual', identity.game_day_ritual,
            'superstition', identity.superstition,
            'primary_team', identity.additional_identity ->> 'primary-team',
            'secondary_teams', identity.additional_identity ->> 'secondary-teams'
          )
          from public.fan_identities identity
          where identity.user_id = profile.user_id
        ), '{}'::jsonb),
        'sports_played', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', sport.id,
            'client_key', sport.client_key,
            'sport', sport.sport,
            'position', sport.position,
            'level', sport.level,
            'years', sport.years,
            'highlight', sport.highlight,
            'sort_order', sport.sort_order
          ) order by sport.sort_order)
          from public.sports_played sport
          where sport.user_id = profile.user_id
        ), '[]'::jsonb),
        'followed_team_ids', coalesce((
          select jsonb_agg(followed.team_id order by followed.sort_order)
          from public.user_followed_teams followed
          where followed.user_id = profile.user_id
        ), '[]'::jsonb),
        'avatar', coalesce((
          select jsonb_build_object(
            'id', photo.id,
            'display_path', photo.display_path,
            'width', photo.source_width,
            'height', photo.source_height,
            'focal_x', photo.focal_x,
            'focal_y', photo.focal_y,
            'zoom', photo.zoom,
            'updated_at', photo.updated_at
          )
          from public.profile_photos photo
          where photo.id = profile.active_profile_photo_id
            and photo.user_id = profile.user_id
        ), case when profile.avatar_path is not null then jsonb_build_object(
          'display_path', profile.avatar_path,
          'updated_at', profile.updated_at
        ) else null end),
        'visuals', coalesce((
          select jsonb_agg(jsonb_build_object(
            'variant', visual.variant,
            'display_path', visual.display_path,
            'width', visual.source_width,
            'height', visual.source_height,
            'focal_x', visual.focal_x,
            'focal_y', visual.focal_y,
            'zoom', visual.zoom,
            'updated_at', visual.updated_at
          ) order by visual.variant)
          from public.profile_visuals visual
          where visual.user_id = profile.user_id
        ), '[]'::jsonb)
      )
      from public.profiles profile
      where profile.user_id = profile_user_id
    )
  end;
$$;

revoke all on function public.get_profile_for_viewer(uuid) from public, anon, authenticated;
grant execute on function public.get_profile_for_viewer(uuid) to anon, authenticated;

create or replace function private.profile_media_path_is_visible(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    -- A recorded original is always private, even if a bad record also tries
    -- to reference that same object as a display path.
    not exists (
      select 1 from public.profile_photos photo where photo.source_path = object_name
      union all
      select 1 from public.profile_visual_images image where image.source_path = object_name
      union all
      select 1 from public.profile_visuals visual where visual.source_path = object_name
      union all
      select 1 from public.profiles profile where profile.avatar_customization ->> 'sourcePath' = object_name
    )
    and exists (
      select 1
      from (
        select photo.user_id, photo.display_path
        from public.profile_photos photo
        union all
        select image.user_id, image.display_path
        from public.profile_visual_images image
        union all
        select visual.user_id, visual.display_path
        from public.profile_visuals visual
        union all
        select profile.user_id, profile.avatar_path as display_path
        from public.profiles profile
        where profile.avatar_path is not null
      ) display_media
      where display_media.display_path = object_name
        and private.can_view_profile(display_media.user_id)
    );
$$;

revoke all on function private.profile_media_path_is_visible(text) from public, anon, authenticated;
grant execute on function private.profile_media_path_is_visible(text) to anon, authenticated;

create policy "Owners and permitted viewers read profile media"
on storage.objects for select to anon, authenticated
using (
  bucket_id = 'profile-media'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or (select private.profile_media_path_is_visible(name))
  )
);

-- Keep profile identity edits and visibility changes in one transaction.
create or replace function public.save_my_profile(profile_data jsonb, identity_data jsonb, sports_data jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
  requested_visibility text;
begin
  if owner_id is null then raise exception 'Authentication is required'; end if;

  select profile.visibility into requested_visibility
  from public.profiles profile
  where profile.user_id = owner_id;
  requested_visibility := coalesce(nullif(profile_data ->> 'visibility', ''), requested_visibility, 'public');
  if requested_visibility not in ('public', 'private') then
    raise exception 'Profile visibility must be public or private';
  end if;

  insert into public.profiles (
    user_id, display_name, handle, fanatical_name, given_name, nickname, tagline,
    birthplace, jersey_number, height, weight, featured_fan_photo_category, visibility
  ) values (
    owner_id,
    coalesce(profile_data ->> 'display_name', ''),
    coalesce(profile_data ->> 'handle', ''),
    nullif(profile_data ->> 'fanatical_name', ''),
    nullif(profile_data ->> 'given_name', ''),
    nullif(profile_data ->> 'nickname', ''),
    nullif(profile_data ->> 'tagline', ''),
    nullif(profile_data ->> 'birthplace', ''),
    nullif(profile_data ->> 'jersey_number', ''),
    nullif(profile_data ->> 'height', ''),
    nullif(profile_data ->> 'weight', ''),
    coalesce(profile_data ->> 'featured_fan_photo_category', 'Fan Cave'),
    requested_visibility
  )
  on conflict (user_id) do update set
    display_name = excluded.display_name,
    handle = excluded.handle,
    fanatical_name = excluded.fanatical_name,
    given_name = excluded.given_name,
    nickname = excluded.nickname,
    tagline = excluded.tagline,
    birthplace = excluded.birthplace,
    jersey_number = excluded.jersey_number,
    height = excluded.height,
    weight = excluded.weight,
    featured_fan_photo_category = excluded.featured_fan_photo_category,
    visibility = excluded.visibility;

  insert into public.fan_identities (
    user_id, fan_since, favorite_players, game_day_ritual, superstition, additional_identity
  ) values (
    owner_id,
    nullif(identity_data ->> 'fan_since', ''),
    nullif(identity_data ->> 'favorite_players', ''),
    nullif(identity_data ->> 'game_day_ritual', ''),
    nullif(identity_data ->> 'superstition', ''),
    coalesce(identity_data -> 'additional_identity', '{}'::jsonb)
  )
  on conflict (user_id) do update set
    fan_since = excluded.fan_since,
    favorite_players = excluded.favorite_players,
    game_day_ritual = excluded.game_day_ritual,
    superstition = excluded.superstition,
    additional_identity = excluded.additional_identity;

  delete from public.sports_played where user_id = owner_id;
  insert into public.sports_played (user_id, client_key, sport, position, level, years, highlight, sort_order)
  select
    owner_id,
    item.value ->> 'client_key',
    coalesce(item.value ->> 'sport', ''),
    nullif(item.value ->> 'position', ''),
    nullif(item.value ->> 'level', ''),
    nullif(item.value ->> 'years', ''),
    nullif(item.value ->> 'highlight', ''),
    item.ordinality - 1
  from jsonb_array_elements(coalesce(sports_data, '[]'::jsonb)) with ordinality as item(value, ordinality);
end;
$$;

revoke all on function public.save_my_profile(jsonb, jsonb, jsonb) from public, anon;
grant execute on function public.save_my_profile(jsonb, jsonb, jsonb) to authenticated;

comment on column public.profiles.visibility is
  'Canonical profile audience. Current values are public and private; relationship-based audiences can be added by migration.';
comment on function public.get_profile_for_viewer(uuid) is
  'Safe public profile boundary. Returns display-only media metadata and no original paths or source file metadata.';
comment on function private.profile_media_path_is_visible(text) is
  'Storage authorization helper: owners are handled by policy; non-owner access requires a canonical display record and a viewable profile.';
