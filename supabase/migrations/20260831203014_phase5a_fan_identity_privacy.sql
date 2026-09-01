-- Phase 5A fan identity and profile privacy.
--
-- Rollback compatibility:
--   * legacy profile columns remain;
--   * the old `public` visibility token remains constraint-valid for an older
--     frontend, but the new reader never treats it as owner consent;
--   * the unused UUID-shaped viewer RPC is removed; the signed-in current-name
--     reader is the only fan-facing profile lookup.

-- The old public default was not an explicit owner selection. Convert it to the
-- ratified safe state before making Members-visible available.
update public.profiles
set visibility = 'private'
where visibility = 'public';

alter table public.profiles
  alter column visibility set default 'private';

alter table public.profiles
  drop constraint profiles_visibility_check;

alter table public.profiles
  add constraint profiles_visibility_check
  check (visibility in ('public', 'private', 'members_visible'));

create or replace function private.profile_personal_field_visibility_is_valid(
  visibility_value jsonb
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(visibility_value) = 'object'
    and not exists (
      select 1
      from jsonb_each(visibility_value) field(key, value)
      where field.key not in (
        'given_name', 'nickname', 'birthplace',
        'height', 'weight', 'jersey_number'
      )
        or jsonb_typeof(field.value) <> 'boolean'
    );
$$;

revoke all on function private.profile_personal_field_visibility_is_valid(jsonb)
from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.profile_personal_field_visibility_is_valid(jsonb)
to authenticated;

alter table public.profiles
  add column personal_field_visibility jsonb not null default '{}'::jsonb;

-- Display derivatives use a random, account-opaque namespace. Owner originals
-- may retain the UUID-prefixed path, but a fan-safe payload must never expose
-- that Auth identifier. Existing UUID-prefixed display objects remain
-- owner-visible and fall back to the generic avatar for other fans until the
-- owner next saves a derivative in this namespace.
alter table public.profiles
  add column media_namespace text not null default (
    'fan-media-' || replace(gen_random_uuid()::text, '-', '')
  );

alter table public.profiles
  add constraint profiles_media_namespace_format_check
  check (media_namespace ~ '^fan-media-[0-9a-f]{32}$');

create unique index profiles_media_namespace_unique_idx
on public.profiles(media_namespace);

create or replace function private.profile_media_path_belongs_to_user(
  profile_user_id uuid,
  object_name text
)
returns boolean
language sql
stable
security definer
strict
set search_path = ''
as $$
  select object_name like profile_user_id::text || '/%'
    or exists (
      select 1
      from public.profiles profile
      where profile.user_id = profile_user_id
        and object_name like profile.media_namespace || '/%'
    );
$$;

revoke all on function private.profile_media_path_belongs_to_user(uuid, text)
from public, anon, authenticated;
grant execute on function private.profile_media_path_belongs_to_user(uuid, text)
to authenticated, service_role;

create or replace function private.profile_avatar_path_is_fan_safe(
  profile_user_id uuid,
  object_name text
)
returns boolean
language sql
stable
security definer
strict
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles profile
    join public.profile_photos photo
      on photo.id = profile.active_profile_photo_id
     and photo.user_id = profile.user_id
    where profile.user_id = profile_user_id
      and photo.display_path = object_name
      and object_name like profile.media_namespace || '/avatar/%'
      and not exists (
        select 1
        from (
          select source_photo.source_path
          from public.profile_photos source_photo
          union all
          select source_image.source_path
          from public.profile_visual_images source_image
          union all
          select source_visual.source_path
          from public.profile_visuals source_visual
          union all
          select source_profile.avatar_customization ->> 'sourcePath'
          from public.profiles source_profile
          where source_profile.avatar_customization ->> 'sourcePath' is not null
        ) source_media(source_path)
        where source_media.source_path = object_name
      )
  );
$$;

revoke all on function private.profile_avatar_path_is_fan_safe(uuid, text)
from public, anon, authenticated;

create or replace function private.protect_profile_media_namespace()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.media_namespace is distinct from old.media_namespace then
    raise exception 'Profile media namespace is immutable';
  end if;
  return new;
end;
$$;

revoke all on function private.protect_profile_media_namespace()
from public, anon, authenticated;

create trigger protect_profile_media_namespace
before update of media_namespace on public.profiles
for each row execute function private.protect_profile_media_namespace();

drop policy if exists "Users upload media into their own folder"
on storage.objects;
drop policy if exists "Users update media in their own folder"
on storage.objects;
drop policy if exists "Users delete media in their own folder"
on storage.objects;
drop policy if exists "Owners and permitted viewers read profile media"
on storage.objects;

create policy "Owners and permitted viewers read profile media"
on storage.objects for select to authenticated
using (
  bucket_id = 'profile-media'
  and (
    private.profile_media_path_belongs_to_user(
      (select auth.uid()),
      name
    )
    or private.profile_media_path_is_visible(name)
  )
);

create policy "Users upload owned profile media"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'profile-media'
  and private.profile_media_path_belongs_to_user(
    (select auth.uid()),
    name
  )
);

create policy "Users update owned profile media"
on storage.objects for update to authenticated
using (
  bucket_id = 'profile-media'
  and private.profile_media_path_belongs_to_user(
    (select auth.uid()),
    name
  )
)
with check (
  bucket_id = 'profile-media'
  and private.profile_media_path_belongs_to_user(
    (select auth.uid()),
    name
  )
);

create policy "Users delete owned profile media"
on storage.objects for delete to authenticated
using (
  bucket_id = 'profile-media'
  and private.profile_media_path_belongs_to_user(
    (select auth.uid()),
    name
  )
);

alter table public.profiles
  add constraint profiles_personal_field_visibility_check
  check (
    private.profile_personal_field_visibility_is_valid(
      personal_field_visibility
    )
  );

-- Tighten the existing authoritative Fanatical Name validator. The preflight
-- and this migration both refuse, rather than rewrite or grandfather, an
-- existing 21-30 character claim.
create or replace function private.validate_profile_handle(handle_value text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  normalized_handle text;
begin
  if handle_value is null then
    raise exception 'Fanatical Name cannot be null';
  end if;

  if handle_value = '' then
    return;
  end if;

  if (handle_value collate "C") !~ '^[A-Za-z0-9_]+$' then
    raise exception 'Fanatical Name may contain only letters, numbers, and underscores';
  end if;

  if (handle_value collate "C") !~ '^[A-Za-z0-9]'
    or (handle_value collate "C") !~ '[A-Za-z0-9]$' then
    raise exception 'Fanatical Name cannot begin or end with an underscore';
  end if;

  normalized_handle := lower(handle_value);
  perform private.lock_profile_handle_namespace();

  if exists (
    select 1
    from private.profile_handle_reservations reservation
    where (
      reservation.reservation_type = 'exact'
      and reservation.normalized_value = normalized_handle
    ) or (
      reservation.reservation_type = 'prefix'
      and left(
        normalized_handle,
        char_length(reservation.normalized_value)
      ) = reservation.normalized_value
    )
  ) then
    raise exception 'Fanatical Name is reserved';
  end if;

  if char_length(handle_value) < 3 or char_length(handle_value) > 20 then
    raise exception 'Fanatical Name must be between 3 and 20 characters';
  end if;
end;
$$;

revoke all on function private.validate_profile_handle(text)
from public, anon, authenticated;

do $$
declare
  existing_handle text;
begin
  for existing_handle in
    select profile.handle
    from public.profiles profile
    where profile.handle <> ''
  loop
    perform private.validate_profile_handle(existing_handle);
  end loop;
end;
$$;

-- Owner reads stay available to the existing profile editor. Other account
-- detail tables no longer have a broad viewer policy; the fan-safe RPC below is
-- the only Phase 5A visitor boundary.
drop policy if exists "Viewable fan identity is readable"
on public.fan_identities;
drop policy if exists "Viewable sports played are readable"
on public.sports_played;
drop policy if exists "Viewable followed teams are readable"
on public.user_followed_teams;

create policy "Users read their own fan identity"
on public.fan_identities for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Users read their own sports played"
on public.sports_played for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Users read their own followed teams"
on public.user_followed_teams for select to authenticated
using ((select auth.uid()) = user_id);

revoke all on table public.profiles, public.fan_identities,
  public.sports_played, public.user_followed_teams,
  public.profile_visuals
from anon;

create or replace function private.can_view_profile(profile_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from private.fan_profile_population viewer
      where viewer.user_id = (select auth.uid())
    )
    and exists (
      select 1
      from public.profiles profile
      join private.fan_profile_population fan_profile
        on fan_profile.user_id = profile.user_id
      where profile.user_id = profile_user_id
        and (
          profile.user_id = (select auth.uid())
          or profile.visibility = 'members_visible'
        )
    );
$$;

revoke all on function private.can_view_profile(uuid)
from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.can_view_profile(uuid) to authenticated;

-- A comment may display only the active avatar derivative, even when the
-- author's full profile is Private. Phase 5A's Community migration replaces
-- this function with the same rule plus reciprocal-Hide enforcement.
create or replace function private.profile_avatar_path_is_attributable(
  object_name text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from private.fan_profile_population viewer
      where viewer.user_id = (select auth.uid())
    )
    and exists (
      select 1
      from public.profiles profile
      join private.fan_profile_population fan_profile
        on fan_profile.user_id = profile.user_id
      join public.profile_photos photo
        on photo.id = profile.active_profile_photo_id
       and photo.user_id = profile.user_id
      where photo.display_path = object_name
        and private.profile_media_path_belongs_to_user(
          profile.user_id,
          object_name
        )
        and private.profile_avatar_path_is_fan_safe(
          profile.user_id,
          object_name
        )
    );
$$;

revoke all on function private.profile_avatar_path_is_attributable(text)
from public, anon, authenticated;

create or replace function private.profile_media_path_is_visible(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.profile_avatar_path_is_attributable(object_name);
$$;

revoke all on function private.profile_media_path_is_visible(text)
from public, anon, authenticated;
grant execute on function private.profile_media_path_is_visible(text)
to anon, authenticated;

create or replace function private.profile_payload_for_viewer(
  profile_user_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  profile_record public.profiles%rowtype;
  avatar_payload jsonb;
  personal_payload jsonb := '{}'::jsonb;
  result_payload jsonb;
  include_member_fields boolean;
begin
  if (select auth.uid()) is null then
    return null;
  end if;

  select profile.*
  into profile_record
  from public.profiles profile
  join private.fan_profile_population fan_profile
    on fan_profile.user_id = profile.user_id
  where profile.user_id = profile_user_id;

  if not found or not exists (
    select 1
    from private.fan_profile_population viewer
    where viewer.user_id = (select auth.uid())
  ) then
    return null;
  end if;

  select jsonb_build_object(
    'display_path', photo.display_path,
    'width', photo.source_width,
    'height', photo.source_height,
    'focal_x', photo.focal_x,
    'focal_y', photo.focal_y,
    'zoom', photo.zoom
  )
  into avatar_payload
  from public.profile_photos photo
  where photo.id = profile_record.active_profile_photo_id
    and photo.user_id = profile_record.user_id
    and private.profile_avatar_path_is_fan_safe(
      photo.user_id,
      photo.display_path
    );

  include_member_fields :=
    profile_record.user_id = (select auth.uid())
    or profile_record.visibility = 'members_visible';

  result_payload := jsonb_build_object(
    'fanatical_name', profile_record.handle,
    'visibility', case when profile_record.visibility = 'members_visible'
      then 'members_visible' else 'private' end,
    'is_private', profile_record.visibility <> 'members_visible',
    'avatar', avatar_payload
  );

  if not include_member_fields then
    return result_payload;
  end if;

  if coalesce(
    (profile_record.personal_field_visibility ->> 'given_name')::boolean,
    false
  ) then
    personal_payload := personal_payload || jsonb_strip_nulls(
      jsonb_build_object('given_name', profile_record.given_name)
    );
  end if;
  if coalesce(
    (profile_record.personal_field_visibility ->> 'nickname')::boolean,
    false
  ) then
    personal_payload := personal_payload || jsonb_strip_nulls(
      jsonb_build_object('nickname', profile_record.nickname)
    );
  end if;
  if coalesce(
    (profile_record.personal_field_visibility ->> 'birthplace')::boolean,
    false
  ) then
    personal_payload := personal_payload || jsonb_strip_nulls(
      jsonb_build_object('birthplace', profile_record.birthplace)
    );
  end if;
  if coalesce(
    (profile_record.personal_field_visibility ->> 'height')::boolean,
    false
  ) then
    personal_payload := personal_payload || jsonb_strip_nulls(
      jsonb_build_object('height', profile_record.height)
    );
  end if;
  if coalesce(
    (profile_record.personal_field_visibility ->> 'weight')::boolean,
    false
  ) then
    personal_payload := personal_payload || jsonb_strip_nulls(
      jsonb_build_object('weight', profile_record.weight)
    );
  end if;
  if coalesce(
    (profile_record.personal_field_visibility ->> 'jersey_number')::boolean,
    false
  ) then
    personal_payload := personal_payload || jsonb_strip_nulls(
      jsonb_build_object(
        'jersey_number', profile_record.jersey_number
      )
    );
  end if;

  result_payload := result_payload || jsonb_strip_nulls(
    jsonb_build_object(
      'display_name', nullif(profile_record.display_name, ''),
      'tagline', profile_record.tagline
    )
  );

  if personal_payload <> '{}'::jsonb then
    result_payload := result_payload
      || jsonb_build_object('personal_fields', personal_payload);
  end if;

  return result_payload;
end;
$$;

revoke all on function private.profile_payload_for_viewer(uuid)
from public, anon, authenticated;

create or replace function public.get_member_profile_by_fanatical_name(
  fanatical_name_value text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  target_user_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication is required';
  end if;

  select profile.user_id
  into target_user_id
  from public.profiles profile
  join private.fan_profile_population fan_profile
    on fan_profile.user_id = profile.user_id
  where profile.handle <> ''
    and lower(profile.handle) = lower(btrim(fanatical_name_value));

  if target_user_id is null then
    return null;
  end if;

  return private.profile_payload_for_viewer(target_user_id);
end;
$$;

revoke all on function public.get_member_profile_by_fanatical_name(text)
from public, anon, authenticated;
grant execute on function public.get_member_profile_by_fanatical_name(text)
to authenticated;

-- Phase 5A replaces the UUID-shaped viewer boundary with current-name lookup.
drop function public.get_profile_for_viewer(uuid);

create or replace function public.set_my_fanatical_name(
  fanatical_name_value text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
  requested_name text := btrim(coalesce(fanatical_name_value, ''));
  violated_constraint_name text;
begin
  if owner_id is null then
    raise exception 'Authentication is required';
  end if;

  if not exists (
    select 1
    from private.fan_profile_population fan_profile
    where fan_profile.user_id = owner_id
  ) then
    raise exception 'Only fan profiles may claim a Fanatical Name';
  end if;

  begin
    update public.profiles
    set handle = requested_name
    where user_id = owner_id;
  exception
    when unique_violation then
      get stacked diagnostics violated_constraint_name = CONSTRAINT_NAME;
      if violated_constraint_name = 'profiles_handle_normalized_unique_idx' then
        raise exception using
          errcode = '23505',
          message = 'Fanatical Name is already claimed';
      end if;
      raise;
  end;

  if not found then
    raise exception 'Fan profile was not found';
  end if;

  return jsonb_build_object('fanatical_name', requested_name);
end;
$$;

revoke all on function public.set_my_fanatical_name(text)
from public, anon, authenticated;
grant execute on function public.set_my_fanatical_name(text)
to authenticated;

create or replace function public.set_my_profile_privacy(
  visibility_value text,
  personal_field_visibility_value jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
begin
  if owner_id is null then
    raise exception 'Authentication is required';
  end if;
  if visibility_value not in ('private', 'members_visible') then
    raise exception 'Profile visibility must be Private or Members-visible';
  end if;
  if not private.profile_personal_field_visibility_is_valid(
    personal_field_visibility_value
  ) then
    raise exception 'Personal field visibility is invalid';
  end if;

  update public.profiles
  set visibility = visibility_value,
      personal_field_visibility = personal_field_visibility_value
  where user_id = owner_id;

  if not found then
    raise exception 'Fan profile was not found';
  end if;

  return jsonb_build_object(
    'visibility', visibility_value,
    'personal_field_visibility', personal_field_visibility_value
  );
end;
$$;

revoke all on function public.set_my_profile_privacy(text, jsonb)
from public, anon, authenticated;
grant execute on function public.set_my_profile_privacy(text, jsonb)
to authenticated;

-- Keep the existing owner transaction and legacy fields, but make the old
-- frontend's `public` request conservative and preserve the new per-field map.
create or replace function public.save_my_profile(
  profile_data jsonb,
  identity_data jsonb,
  sports_data jsonb
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
  requested_visibility text;
  requested_handle text := coalesce(profile_data ->> 'handle', '');
  requested_field_visibility jsonb;
  existing_legacy_fanatical_name text;
  violated_constraint_name text;
begin
  if owner_id is null then raise exception 'Authentication is required'; end if;

  select profile.visibility, profile.personal_field_visibility,
    profile.fanatical_name
  into requested_visibility, requested_field_visibility,
    existing_legacy_fanatical_name
  from public.profiles profile
  where profile.user_id = owner_id;

  requested_visibility := coalesce(
    nullif(profile_data ->> 'visibility', ''),
    requested_visibility,
    'private'
  );
  if requested_visibility = 'public' then
    requested_visibility := 'private';
  end if;
  if requested_visibility not in ('private', 'members_visible') then
    raise exception 'Profile visibility must be Private or Members-visible';
  end if;

  requested_field_visibility := coalesce(
    profile_data -> 'personal_field_visibility',
    requested_field_visibility,
    '{}'::jsonb
  );
  if not private.profile_personal_field_visibility_is_valid(
    requested_field_visibility
  ) then
    raise exception 'Personal field visibility is invalid';
  end if;

  begin
    insert into public.profiles (
      user_id, display_name, handle, fanatical_name, given_name, nickname,
      tagline, birthplace, jersey_number, height, weight,
      featured_fan_photo_category, visibility, personal_field_visibility
    ) values (
      owner_id,
      coalesce(profile_data ->> 'display_name', ''),
      requested_handle,
      case when profile_data ? 'fanatical_name'
        then nullif(profile_data ->> 'fanatical_name', '')
        else existing_legacy_fanatical_name end,
      nullif(profile_data ->> 'given_name', ''),
      nullif(profile_data ->> 'nickname', ''),
      nullif(profile_data ->> 'tagline', ''),
      nullif(profile_data ->> 'birthplace', ''),
      nullif(profile_data ->> 'jersey_number', ''),
      nullif(profile_data ->> 'height', ''),
      nullif(profile_data ->> 'weight', ''),
      coalesce(profile_data ->> 'featured_fan_photo_category', 'Fan Cave'),
      requested_visibility,
      requested_field_visibility
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
      visibility = excluded.visibility,
      personal_field_visibility = excluded.personal_field_visibility;
  exception
    when unique_violation then
      get stacked diagnostics violated_constraint_name = CONSTRAINT_NAME;
      if violated_constraint_name = 'profiles_handle_normalized_unique_idx' then
        raise exception using
          errcode = '23505',
          message = 'Fanatical Name is already claimed';
      end if;
      raise;
  end;

  insert into public.fan_identities (
    user_id, fan_since, favorite_players, game_day_ritual, superstition,
    additional_identity
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
  insert into public.sports_played (
    user_id, client_key, sport, position, level, years, highlight, sort_order
  )
  select
    owner_id,
    item.value ->> 'client_key',
    coalesce(item.value ->> 'sport', ''),
    nullif(item.value ->> 'position', ''),
    nullif(item.value ->> 'level', ''),
    nullif(item.value ->> 'years', ''),
    nullif(item.value ->> 'highlight', ''),
    item.ordinality - 1
  from jsonb_array_elements(coalesce(sports_data, '[]'::jsonb))
    with ordinality as item(value, ordinality);
end;
$$;

revoke all on function public.save_my_profile(jsonb, jsonb, jsonb)
from public, anon;
grant execute on function public.save_my_profile(jsonb, jsonb, jsonb)
to authenticated;

comment on column public.profiles.handle is
  'Phase 5A Fanatical Name. Empty means unclaimed; 3-20 ASCII letters, numbers, or underscores; current ownership is unique on lower(handle).';
comment on column public.profiles.visibility is
  'Phase 5A uses private or members_visible. Legacy public remains accepted only for rollback compatibility and is treated as private by fan-safe readers.';
comment on column public.profiles.personal_field_visibility is
  'Owner-selected per-field member visibility; every optional field defaults hidden.';
comment on function public.get_member_profile_by_fanatical_name(text) is
  'Signed-in, fan-population, current-name profile reader with a server-side allowlist and no Auth UUID or protected account fields.';
