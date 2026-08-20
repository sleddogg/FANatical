-- Small owned Profile Photo library. Existing profiles.avatar_path and
-- avatar_customization remain the active-photo compatibility projection.

create table if not exists public.profile_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  source_path text not null unique,
  display_path text not null unique,
  source_filename text not null,
  source_media_type text not null check (source_media_type in ('image/jpeg', 'image/png', 'image/webp')),
  source_width integer not null check (source_width > 0),
  source_height integer not null check (source_height > 0),
  focal_x double precision not null default 0.5 check (focal_x between 0 and 1),
  focal_y double precision not null default 0.5 check (focal_y between 0 and 1),
  zoom double precision not null default 1 check (zoom between 1 and 4),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profile_photos_user_created_idx on public.profile_photos(user_id, created_at desc);

alter table public.profiles add column if not exists active_profile_photo_id uuid references public.profile_photos(id) on delete set null;

create or replace function public.enforce_profile_photo_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.user_id::text, 0));
  if (select count(*) from public.profile_photos where user_id = new.user_id) >= 3 then
    raise exception 'A profile can keep no more than three saved photos';
  end if;
  return new;
end;
$$;

drop trigger if exists profile_photos_limit on public.profile_photos;
create trigger profile_photos_limit before insert on public.profile_photos
for each row execute function public.enforce_profile_photo_limit();

create or replace function public.validate_active_profile_photo_owner()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.active_profile_photo_id is not null and not exists (
    select 1 from public.profile_photos photo
    where photo.id = new.active_profile_photo_id and photo.user_id = new.user_id
  ) then
    raise exception 'Active profile photo must belong to the profile owner';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_validate_active_profile_photo on public.profiles;
create trigger profiles_validate_active_profile_photo
before insert or update of active_profile_photo_id on public.profiles
for each row execute function public.validate_active_profile_photo_owner();

drop trigger if exists profile_photos_set_updated_at on public.profile_photos;
create trigger profile_photos_set_updated_at before update on public.profile_photos
for each row execute function public.set_updated_at();

insert into public.profile_photos (
  user_id, source_path, display_path, source_filename, source_media_type,
  source_width, source_height, focal_x, focal_y, zoom, updated_at
)
select
  profile.user_id,
  profile.avatar_customization ->> 'sourcePath',
  coalesce(nullif(profile.avatar_path, ''), profile.avatar_customization ->> 'displayPath'),
  coalesce(nullif(profile.avatar_customization ->> 'sourceFilename', ''), 'Profile photo'),
  case when profile.avatar_customization ->> 'sourceMediaType' in ('image/jpeg', 'image/png', 'image/webp')
    then profile.avatar_customization ->> 'sourceMediaType' else 'image/jpeg' end,
  case when profile.avatar_customization ->> 'sourceWidth' ~ '^[0-9]+$'
    then greatest(1, (profile.avatar_customization ->> 'sourceWidth')::integer) else 1 end,
  case when profile.avatar_customization ->> 'sourceHeight' ~ '^[0-9]+$'
    then greatest(1, (profile.avatar_customization ->> 'sourceHeight')::integer) else 1 end,
  case when profile.avatar_customization ->> 'focalX' ~ '^[0-9]+([.][0-9]+)?$'
    then least(1, greatest(0, (profile.avatar_customization ->> 'focalX')::double precision)) else 0.5 end,
  case when profile.avatar_customization ->> 'focalY' ~ '^[0-9]+([.][0-9]+)?$'
    then least(1, greatest(0, (profile.avatar_customization ->> 'focalY')::double precision)) else 0.5 end,
  case when profile.avatar_customization ->> 'zoom' ~ '^[0-9]+([.][0-9]+)?$'
    then least(4, greatest(1, (profile.avatar_customization ->> 'zoom')::double precision)) else 1 end,
  profile.updated_at
from public.profiles profile
where nullif(profile.avatar_customization ->> 'sourcePath', '') is not null
  and coalesce(nullif(profile.avatar_path, ''), nullif(profile.avatar_customization ->> 'displayPath', '')) is not null
on conflict (display_path) do nothing;

update public.profiles profile
set active_profile_photo_id = photo.id
from public.profile_photos photo
where photo.user_id = profile.user_id
  and photo.display_path = coalesce(nullif(profile.avatar_path, ''), profile.avatar_customization ->> 'displayPath')
  and profile.active_profile_photo_id is null;

create or replace function public.activate_my_profile_photo(
  photo_id_value uuid,
  focal_x_value double precision,
  focal_y_value double precision,
  zoom_value double precision
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
  photo public.profile_photos%rowtype;
begin
  if owner_id is null then raise exception 'Authentication is required'; end if;
  if focal_x_value not between 0 and 1 or focal_y_value not between 0 and 1 or zoom_value not between 1 and 4 then
    raise exception 'Profile photo positioning is invalid';
  end if;

  update public.profile_photos
  set focal_x = focal_x_value, focal_y = focal_y_value, zoom = zoom_value
  where id = photo_id_value and user_id = owner_id
  returning * into photo;
  if not found then raise exception 'Profile photo was not found'; end if;

  update public.profiles
  set active_profile_photo_id = photo.id,
      avatar_path = photo.display_path,
      avatar_customization = jsonb_build_object(
        'sourcePath', photo.source_path,
        'displayPath', photo.display_path,
        'sourceFilename', photo.source_filename,
        'sourceMediaType', photo.source_media_type,
        'sourceWidth', photo.source_width,
        'sourceHeight', photo.source_height,
        'focalX', focal_x_value,
        'focalY', focal_y_value,
        'zoom', zoom_value
      )
  where user_id = owner_id;
end;
$$;

create or replace function public.remove_my_profile_photo(photo_id_value uuid)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
  removed public.profile_photos%rowtype;
  fallback public.profile_photos%rowtype;
  was_active boolean;
begin
  if owner_id is null then raise exception 'Authentication is required'; end if;
  select profile.active_profile_photo_id = photo_id_value into was_active
  from public.profiles profile where profile.user_id = owner_id;

  delete from public.profile_photos
  where id = photo_id_value and user_id = owner_id
  returning * into removed;
  if not found then raise exception 'Profile photo was not found'; end if;

  if coalesce(was_active, false) then
    select * into fallback from public.profile_photos
    where user_id = owner_id order by created_at desc, id desc limit 1;
    if found then
      update public.profiles
      set active_profile_photo_id = fallback.id,
          avatar_path = fallback.display_path,
          avatar_customization = jsonb_build_object(
            'sourcePath', fallback.source_path,
            'displayPath', fallback.display_path,
            'sourceFilename', fallback.source_filename,
            'sourceMediaType', fallback.source_media_type,
            'sourceWidth', fallback.source_width,
            'sourceHeight', fallback.source_height,
            'focalX', fallback.focal_x,
            'focalY', fallback.focal_y,
            'zoom', fallback.zoom
          )
      where user_id = owner_id;
    else
      update public.profiles
      set active_profile_photo_id = null, avatar_path = null, avatar_customization = '{}'::jsonb
      where user_id = owner_id;
    end if;
  end if;

  return jsonb_build_object('sourcePath', removed.source_path, 'displayPath', removed.display_path);
end;
$$;

alter table public.profile_photos enable row level security;

create policy "Users read their own profile photos"
on public.profile_photos for select using (auth.uid() = user_id);
create policy "Users insert their own profile photos"
on public.profile_photos for insert with check (auth.uid() = user_id);
create policy "Users update their own profile photos"
on public.profile_photos for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users delete their own profile photos"
on public.profile_photos for delete using (auth.uid() = user_id);

grant select, insert, update, delete on public.profile_photos to authenticated;
revoke all on function public.enforce_profile_photo_limit() from public, anon, authenticated;
revoke all on function public.validate_active_profile_photo_owner() from public, anon, authenticated;
revoke all on function public.activate_my_profile_photo(uuid, double precision, double precision, double precision) from public, anon;
grant execute on function public.activate_my_profile_photo(uuid, double precision, double precision, double precision) to authenticated;
revoke all on function public.remove_my_profile_photo(uuid) from public, anon;
grant execute on function public.remove_my_profile_photo(uuid) to authenticated;

alter table public.profile_photos replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.profile_photos;
exception when duplicate_object then null;
end $$;
