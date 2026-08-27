-- Bind every profile-media metadata path to the owning profile's Storage
-- namespace. Existing rows are preserved for explicit review and cleanup.

create or replace function private.profile_media_path_belongs_to_user(
  profile_user_id uuid,
  object_name text
)
returns boolean
language sql
immutable
parallel safe
strict
set search_path = ''
as $$
  select object_name like profile_user_id::text || '/%';
$$;

revoke all on function private.profile_media_path_belongs_to_user(uuid, text)
from public, anon, authenticated;
grant execute on function private.profile_media_path_belongs_to_user(uuid, text)
to authenticated, service_role;

-- NOT VALID deliberately avoids scanning or rewriting hosted legacy rows while
-- still enforcing the ownership invariant for every new or updated row. The
-- private diagnostic view below identifies rows that must be cleaned before a
-- later migration validates these constraints.
alter table public.profiles
add constraint profiles_owned_media_paths_check
check (
  (
    avatar_path is null
    or private.profile_media_path_belongs_to_user(user_id, avatar_path)
  )
  and (
    avatar_customization ->> 'sourcePath' is null
    or private.profile_media_path_belongs_to_user(
      user_id,
      avatar_customization ->> 'sourcePath'
    )
  )
  and (
    avatar_customization ->> 'displayPath' is null
    or private.profile_media_path_belongs_to_user(
      user_id,
      avatar_customization ->> 'displayPath'
    )
  )
) not valid;

alter table public.profile_photos
add constraint profile_photos_owned_media_paths_check
check (
  private.profile_media_path_belongs_to_user(user_id, source_path)
  and private.profile_media_path_belongs_to_user(user_id, display_path)
) not valid;

alter table public.profile_visual_images
add constraint profile_visual_images_owned_media_paths_check
check (
  private.profile_media_path_belongs_to_user(user_id, source_path)
  and private.profile_media_path_belongs_to_user(user_id, display_path)
) not valid;

alter table public.profile_visuals
add constraint profile_visuals_owned_media_paths_check
check (
  private.profile_media_path_belongs_to_user(user_id, source_path)
  and private.profile_media_path_belongs_to_user(user_id, display_path)
) not valid;

comment on constraint profiles_owned_media_paths_check on public.profiles is
  'NOT VALID preserves legacy rows. New profile-media paths must use the profile owner UUID as their first Storage path segment.';
comment on constraint profile_photos_owned_media_paths_check on public.profile_photos is
  'NOT VALID preserves legacy rows. New source and display paths must use the row owner UUID as their first Storage path segment.';
comment on constraint profile_visual_images_owned_media_paths_check on public.profile_visual_images is
  'NOT VALID preserves legacy rows. New source and display paths must use the row owner UUID as their first Storage path segment.';
comment on constraint profile_visuals_owned_media_paths_check on public.profile_visuals is
  'NOT VALID preserves legacy rows. New source and display paths must use the row owner UUID as their first Storage path segment.';

create or replace view private.profile_media_path_ownership_violations
with (security_invoker = true)
as
select
  'profiles'::text as table_name,
  profile.user_id,
  profile.user_id::text as record_id,
  'avatar_path'::text as column_name,
  profile.avatar_path as media_path
from public.profiles profile
where profile.avatar_path is not null
  and not private.profile_media_path_belongs_to_user(
    profile.user_id,
    profile.avatar_path
  )
union all
select
  'profiles',
  profile.user_id,
  profile.user_id::text,
  'avatar_customization.sourcePath',
  profile.avatar_customization ->> 'sourcePath'
from public.profiles profile
where profile.avatar_customization ->> 'sourcePath' is not null
  and not private.profile_media_path_belongs_to_user(
    profile.user_id,
    profile.avatar_customization ->> 'sourcePath'
  )
union all
select
  'profiles',
  profile.user_id,
  profile.user_id::text,
  'avatar_customization.displayPath',
  profile.avatar_customization ->> 'displayPath'
from public.profiles profile
where profile.avatar_customization ->> 'displayPath' is not null
  and not private.profile_media_path_belongs_to_user(
    profile.user_id,
    profile.avatar_customization ->> 'displayPath'
  )
union all
select
  'profile_photos',
  photo.user_id,
  photo.id::text,
  path.column_name,
  path.media_path
from public.profile_photos photo
cross join lateral (
  values
    ('source_path'::text, photo.source_path),
    ('display_path'::text, photo.display_path)
) path(column_name, media_path)
where not private.profile_media_path_belongs_to_user(
  photo.user_id,
  path.media_path
)
union all
select
  'profile_visual_images',
  image.user_id,
  image.id::text,
  path.column_name,
  path.media_path
from public.profile_visual_images image
cross join lateral (
  values
    ('source_path'::text, image.source_path),
    ('display_path'::text, image.display_path)
) path(column_name, media_path)
where not private.profile_media_path_belongs_to_user(
  image.user_id,
  path.media_path
)
union all
select
  'profile_visuals',
  visual.user_id,
  visual.user_id::text || ':' || visual.variant,
  path.column_name,
  path.media_path
from public.profile_visuals visual
cross join lateral (
  values
    ('source_path'::text, visual.source_path),
    ('display_path'::text, visual.display_path)
) path(column_name, media_path)
where not private.profile_media_path_belongs_to_user(
  visual.user_id,
  path.media_path
);

revoke all on private.profile_media_path_ownership_violations
from public, anon, authenticated;
grant usage on schema private to service_role;
grant select on private.profile_media_path_ownership_violations to service_role;

comment on view private.profile_media_path_ownership_violations is
  'Administrative inventory of legacy profile-media metadata outside its row owner Storage namespace. Rows require explicit cleanup before constraint validation.';

create or replace function private.profile_media_path_is_visible(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    -- Only owner-bound metadata is authoritative. A malformed legacy record
    -- cannot classify an object in another user's namespace as either source
    -- or display media.
    not exists (
      select 1
      from (
        select photo.user_id, photo.source_path as media_path
        from public.profile_photos photo
        union all
        select image.user_id, image.source_path
        from public.profile_visual_images image
        union all
        select visual.user_id, visual.source_path
        from public.profile_visuals visual
        union all
        select profile.user_id, profile.avatar_customization ->> 'sourcePath'
        from public.profiles profile
        where profile.avatar_customization ->> 'sourcePath' is not null
      ) source_media
      where source_media.media_path = object_name
        and private.profile_media_path_belongs_to_user(
          source_media.user_id,
          source_media.media_path
        )
    )
    and exists (
      select 1
      from (
        select photo.user_id, photo.display_path as media_path
        from public.profile_photos photo
        union all
        select image.user_id, image.display_path
        from public.profile_visual_images image
        union all
        select visual.user_id, visual.display_path
        from public.profile_visuals visual
        union all
        select profile.user_id, profile.avatar_path
        from public.profiles profile
        where profile.avatar_path is not null
      ) display_media
      where display_media.media_path = object_name
        and private.profile_media_path_belongs_to_user(
          display_media.user_id,
          display_media.media_path
        )
        and private.can_view_profile(display_media.user_id)
    );
$$;

revoke all on function private.profile_media_path_is_visible(text)
from public, anon, authenticated;
grant execute on function private.profile_media_path_is_visible(text)
to anon, authenticated;

comment on function private.profile_media_path_is_visible(text) is
  'Storage authorization helper: non-owner access requires owner-bound canonical display metadata and a viewable profile; malformed cross-namespace metadata is ignored.';
