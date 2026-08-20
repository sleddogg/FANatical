-- Small owned libraries for Mobile Visual and Wide Visual images. The existing
-- profile_visuals table remains the active-image compatibility projection.

create table if not exists public.profile_visual_images (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  variant text not null check (variant in ('mobile', 'wide')),
  source_path text not null unique,
  display_path text not null unique,
  source_filename text not null,
  source_media_type text not null check (source_media_type in ('image/jpeg', 'image/png', 'image/webp')),
  source_width integer not null check (source_width > 0),
  source_height integer not null check (source_height > 0),
  focal_x double precision not null default 0.5 check (focal_x between 0 and 1),
  focal_y double precision not null default 0.5 check (focal_y between 0 and 1),
  zoom double precision not null default 1 check (zoom between 1 and 3),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profile_visual_images_user_variant_created_idx
on public.profile_visual_images(user_id, variant, created_at desc);

create or replace function public.enforce_profile_visual_image_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.user_id::text || ':' || new.variant, 0)
  );
  if (
    select count(*) from public.profile_visual_images
    where user_id = new.user_id and variant = new.variant
  ) >= 3 then
    raise exception 'A profile can keep no more than three saved images for each visual role';
  end if;
  return new;
end;
$$;

drop trigger if exists profile_visual_images_limit on public.profile_visual_images;
create trigger profile_visual_images_limit before insert on public.profile_visual_images
for each row execute function public.enforce_profile_visual_image_limit();

drop trigger if exists profile_visual_images_set_updated_at on public.profile_visual_images;
create trigger profile_visual_images_set_updated_at before update on public.profile_visual_images
for each row execute function public.set_updated_at();

insert into public.profile_visual_images (
  user_id, variant, source_path, display_path, source_filename, source_media_type,
  source_width, source_height, focal_x, focal_y, zoom, created_at, updated_at
)
select
  visual.user_id, visual.variant, visual.source_path, visual.display_path,
  visual.source_filename, visual.source_media_type, visual.source_width,
  visual.source_height, visual.focal_x, visual.focal_y, visual.zoom,
  visual.created_at, visual.updated_at
from public.profile_visuals visual
on conflict (display_path) do nothing;

create or replace function public.activate_my_profile_visual(
  image_id_value uuid,
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
  image public.profile_visual_images%rowtype;
begin
  if owner_id is null then raise exception 'Authentication is required'; end if;
  if focal_x_value not between 0 and 1
    or focal_y_value not between 0 and 1
    or zoom_value not between 1 and 3 then
    raise exception 'Profile visual positioning is invalid';
  end if;

  update public.profile_visual_images
  set focal_x = focal_x_value, focal_y = focal_y_value, zoom = zoom_value
  where id = image_id_value and user_id = owner_id
  returning * into image;
  if not found then raise exception 'Profile visual image was not found'; end if;

  insert into public.profile_visuals (
    user_id, variant, source_path, display_path, source_filename,
    source_media_type, source_width, source_height, focal_x, focal_y, zoom
  ) values (
    owner_id, image.variant, image.source_path, image.display_path,
    image.source_filename, image.source_media_type, image.source_width,
    image.source_height, image.focal_x, image.focal_y, image.zoom
  )
  on conflict (user_id, variant) do update set
    source_path = excluded.source_path,
    display_path = excluded.display_path,
    source_filename = excluded.source_filename,
    source_media_type = excluded.source_media_type,
    source_width = excluded.source_width,
    source_height = excluded.source_height,
    focal_x = excluded.focal_x,
    focal_y = excluded.focal_y,
    zoom = excluded.zoom;
end;
$$;

create or replace function public.remove_my_profile_visual(image_id_value uuid)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
  removed public.profile_visual_images%rowtype;
  fallback public.profile_visual_images%rowtype;
  was_active boolean;
begin
  if owner_id is null then raise exception 'Authentication is required'; end if;

  select exists (
    select 1 from public.profile_visuals visual
    join public.profile_visual_images image
      on image.user_id = visual.user_id
      and image.variant = visual.variant
      and image.display_path = visual.display_path
    where visual.user_id = owner_id and image.id = image_id_value
  ) into was_active;

  delete from public.profile_visual_images
  where id = image_id_value and user_id = owner_id
  returning * into removed;
  if not found then raise exception 'Profile visual image was not found'; end if;

  if was_active then
    select * into fallback from public.profile_visual_images
    where user_id = owner_id and variant = removed.variant
    order by created_at desc, id desc
    limit 1;

    if found then
      insert into public.profile_visuals (
        user_id, variant, source_path, display_path, source_filename,
        source_media_type, source_width, source_height, focal_x, focal_y, zoom
      ) values (
        owner_id, fallback.variant, fallback.source_path, fallback.display_path,
        fallback.source_filename, fallback.source_media_type, fallback.source_width,
        fallback.source_height, fallback.focal_x, fallback.focal_y, fallback.zoom
      )
      on conflict (user_id, variant) do update set
        source_path = excluded.source_path,
        display_path = excluded.display_path,
        source_filename = excluded.source_filename,
        source_media_type = excluded.source_media_type,
        source_width = excluded.source_width,
        source_height = excluded.source_height,
        focal_x = excluded.focal_x,
        focal_y = excluded.focal_y,
        zoom = excluded.zoom;
    else
      delete from public.profile_visuals
      where user_id = owner_id and variant = removed.variant;
    end if;
  end if;

  return jsonb_build_object(
    'sourcePath', removed.source_path,
    'displayPath', removed.display_path
  );
end;
$$;

alter table public.profile_visual_images enable row level security;

create policy "Users read their own profile visual images"
on public.profile_visual_images for select using (auth.uid() = user_id);
create policy "Users insert their own profile visual images"
on public.profile_visual_images for insert with check (auth.uid() = user_id);
create policy "Users update their own profile visual images"
on public.profile_visual_images for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users delete their own profile visual images"
on public.profile_visual_images for delete using (auth.uid() = user_id);

grant select, insert, update, delete on public.profile_visual_images to authenticated;
revoke all on function public.enforce_profile_visual_image_limit() from public, anon, authenticated;
revoke all on function public.activate_my_profile_visual(uuid, double precision, double precision, double precision) from public, anon;
grant execute on function public.activate_my_profile_visual(uuid, double precision, double precision, double precision) to authenticated;
revoke all on function public.remove_my_profile_visual(uuid) from public, anon;
grant execute on function public.remove_my_profile_visual(uuid) to authenticated;

alter table public.profile_visual_images replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.profile_visual_images;
exception when duplicate_object then null;
end $$;
