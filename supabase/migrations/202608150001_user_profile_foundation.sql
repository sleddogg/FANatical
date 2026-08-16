-- FANatical account/profile foundation. Standard PostgreSQL tables are kept
-- separate from Supabase Auth and Storage so they can move to self-hosting.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  handle text not null default '',
  fanatical_name text,
  given_name text,
  nickname text,
  avatar_path text,
  tagline text,
  birthplace text,
  jersey_number text,
  height text,
  weight text,
  featured_fan_photo_category text not null default 'Fan Cave'
    check (featured_fan_photo_category in ('Game Face', 'Fan Cave', 'Memorabilia')),
  is_public boolean not null default true,
  primary_profile_text text,
  secondary_profile_text text,
  profile_text_position jsonb not null default '{}'::jsonb,
  avatar_customization jsonb not null default '{}'::jsonb,
  personalization jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.fan_identities (
  user_id uuid primary key references public.profiles(user_id) on delete cascade,
  fan_since text,
  favorite_players text,
  game_day_ritual text,
  superstition text,
  additional_identity jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.sports_played (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  client_key text not null,
  sport text not null default '',
  position text,
  level text,
  years text,
  highlight text,
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists sports_played_user_client_key_idx on public.sports_played(user_id, client_key);
create index if not exists sports_played_user_sort_idx on public.sports_played(user_id, sort_order);

create table if not exists public.user_followed_teams (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  team_id text not null,
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  primary key (user_id, team_id)
);

comment on column public.user_followed_teams.team_id is
  'Stable canonical team ID from FANatical officialSportsDatabase. A catalog FK can be added when the catalog ingestion service moves into PostgreSQL.';

create index if not exists followed_teams_user_sort_idx on public.user_followed_teams(user_id, sort_order);

create table if not exists public.user_settings (
  user_id uuid primary key references public.profiles(user_id) on delete cascade,
  navigation_side text not null default 'left' check (navigation_side in ('left', 'right')),
  selected_team_id text,
  preferences jsonb not null default '{}'::jsonb,
  prototype_migration_version integer not null default 0 check (prototype_migration_version >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.profile_visuals (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  variant text not null check (variant in ('mobile', 'wide')),
  source_path text not null,
  display_path text not null,
  source_filename text not null,
  source_media_type text not null,
  source_width integer not null check (source_width > 0),
  source_height integer not null check (source_height > 0),
  focal_x double precision not null default 0.5 check (focal_x between 0 and 1),
  focal_y double precision not null default 0.5 check (focal_y between 0 and 1),
  zoom double precision not null default 1 check (zoom between 1 and 3),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, variant)
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
drop trigger if exists fan_identities_set_updated_at on public.fan_identities;
create trigger fan_identities_set_updated_at before update on public.fan_identities for each row execute function public.set_updated_at();
drop trigger if exists sports_played_set_updated_at on public.sports_played;
create trigger sports_played_set_updated_at before update on public.sports_played for each row execute function public.set_updated_at();
drop trigger if exists user_settings_set_updated_at on public.user_settings;
create trigger user_settings_set_updated_at before update on public.user_settings for each row execute function public.set_updated_at();
drop trigger if exists profile_visuals_set_updated_at on public.profile_visuals;
create trigger profile_visuals_set_updated_at before update on public.profile_visuals for each row execute function public.set_updated_at();

create or replace function public.handle_new_fanatical_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  initial_display_name text;
begin
  initial_display_name := coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), split_part(new.email, '@', 1), 'Fan');
  insert into public.profiles (user_id, display_name, handle)
  values (new.id, initial_display_name, '@' || regexp_replace(lower(initial_display_name), '[^a-z0-9]+', '', 'g'))
  on conflict (user_id) do nothing;
  insert into public.fan_identities (user_id) values (new.id) on conflict (user_id) do nothing;
  insert into public.user_settings (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_fanatical_user();

create or replace function public.save_my_profile(profile_data jsonb, identity_data jsonb, sports_data jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
begin
  if owner_id is null then raise exception 'Authentication is required'; end if;

  insert into public.profiles (
    user_id, display_name, handle, fanatical_name, given_name, nickname, tagline,
    birthplace, jersey_number, height, weight, featured_fan_photo_category
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
    coalesce(profile_data ->> 'featured_fan_photo_category', 'Fan Cave')
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
    featured_fan_photo_category = excluded.featured_fan_photo_category;

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

create or replace function public.replace_my_followed_teams(team_ids text[])
returns void
language plpgsql
set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
begin
  if owner_id is null then raise exception 'Authentication is required'; end if;
  delete from public.user_followed_teams where user_id = owner_id;
  insert into public.user_followed_teams (user_id, team_id, sort_order)
  select owner_id, item.team_id, item.ordinality - 1
  from unnest(coalesce(team_ids, array[]::text[])) with ordinality as item(team_id, ordinality)
  on conflict (user_id, team_id) do update set sort_order = excluded.sort_order;
end;
$$;

revoke all on function public.replace_my_followed_teams(text[]) from public, anon;
grant execute on function public.replace_my_followed_teams(text[]) to authenticated;

alter table public.profiles enable row level security;
alter table public.fan_identities enable row level security;
alter table public.sports_played enable row level security;
alter table public.user_followed_teams enable row level security;
alter table public.user_settings enable row level security;
alter table public.profile_visuals enable row level security;

create policy "Public profiles are readable"
on public.profiles for select
using (is_public or auth.uid() = user_id);
create policy "Users create their own profile"
on public.profiles for insert
with check (auth.uid() = user_id);
create policy "Users update their own profile"
on public.profiles for update
using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Public fan identity is readable"
on public.fan_identities for select
using (auth.uid() = user_id or exists (select 1 from public.profiles p where p.user_id = fan_identities.user_id and p.is_public));
create policy "Users insert their own fan identity"
on public.fan_identities for insert with check (auth.uid() = user_id);
create policy "Users update their own fan identity"
on public.fan_identities for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Public sports played are readable"
on public.sports_played for select
using (auth.uid() = user_id or exists (select 1 from public.profiles p where p.user_id = sports_played.user_id and p.is_public));
create policy "Users insert their own sports played"
on public.sports_played for insert with check (auth.uid() = user_id);
create policy "Users update their own sports played"
on public.sports_played for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users delete their own sports played"
on public.sports_played for delete using (auth.uid() = user_id);

create policy "Public followed teams are readable"
on public.user_followed_teams for select
using (auth.uid() = user_id or exists (select 1 from public.profiles p where p.user_id = user_followed_teams.user_id and p.is_public));
create policy "Users follow teams for themselves"
on public.user_followed_teams for insert with check (auth.uid() = user_id);
create policy "Users update their followed team order"
on public.user_followed_teams for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users unfollow teams for themselves"
on public.user_followed_teams for delete using (auth.uid() = user_id);

create policy "Users read their own settings"
on public.user_settings for select using (auth.uid() = user_id);
create policy "Users insert their own settings"
on public.user_settings for insert with check (auth.uid() = user_id);
create policy "Users update their own settings"
on public.user_settings for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Public profile visual metadata is readable"
on public.profile_visuals for select
using (auth.uid() = user_id or exists (select 1 from public.profiles p where p.user_id = profile_visuals.user_id and p.is_public));
create policy "Users insert their own profile visuals"
on public.profile_visuals for insert with check (auth.uid() = user_id);
create policy "Users update their own profile visuals"
on public.profile_visuals for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users delete their own profile visuals"
on public.profile_visuals for delete using (auth.uid() = user_id);

grant select on public.profiles, public.fan_identities, public.sports_played, public.user_followed_teams, public.profile_visuals to anon, authenticated;
grant insert, update on public.profiles to authenticated;
grant insert, update on public.fan_identities to authenticated;
grant insert, update, delete on public.sports_played to authenticated;
grant insert, update, delete on public.user_followed_teams to authenticated;
grant select, insert, update on public.user_settings to authenticated;
grant insert, update, delete on public.profile_visuals to authenticated;

revoke all on function public.handle_new_fanatical_user() from public, anon, authenticated;
revoke all on function public.set_updated_at() from public, anon, authenticated;

alter table public.profiles replica identity full;
alter table public.fan_identities replica identity full;
alter table public.sports_played replica identity full;
alter table public.user_followed_teams replica identity full;
alter table public.user_settings replica identity full;
alter table public.profile_visuals replica identity full;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-media', 'profile-media', false, 26214400, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy "Users upload media into their own folder"
on storage.objects for insert to authenticated
with check (bucket_id = 'profile-media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Users update media in their own folder"
on storage.objects for update to authenticated
using (bucket_id = 'profile-media' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'profile-media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Users delete media in their own folder"
on storage.objects for delete to authenticated
using (bucket_id = 'profile-media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Owners and public profile viewers read profile media"
on storage.objects for select
using (
  bucket_id = 'profile-media'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or exists (
      select 1 from public.profiles p
      where p.user_id::text = (storage.foldername(name))[1] and p.is_public
    )
  )
);

do $$
begin
  alter publication supabase_realtime add table public.profiles;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.fan_identities;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.sports_played;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.user_followed_teams;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.user_settings;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.profile_visuals;
exception when duplicate_object then null;
end $$;
