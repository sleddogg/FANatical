-- FANatical claimed-handle integrity. A handle is stored without presentation
-- punctuation (for example, "Brad", rendered as "@Brad" by a client). The
-- entered casing is retained while ownership and resolution are normalized.

create table private.profile_handle_reservations (
  reservation_type text not null
    check (reservation_type in ('exact', 'prefix')),
  normalized_value text not null,
  reason text not null default 'Reserved by FANatical',
  created_at timestamptz not null default now(),
  primary key (reservation_type, normalized_value),
  constraint profile_handle_reservations_normalized_value_check check (
    normalized_value <> ''
    and normalized_value = lower(normalized_value)
    and (normalized_value collate "C") ~ '^[a-z0-9_]+$'
    and char_length(normalized_value) <= 30
  )
);

revoke all on table private.profile_handle_reservations
from public, anon, authenticated;

create or replace function private.enforce_profile_handle_reservation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.profiles profile
    where profile.handle <> ''
      and (
        (new.reservation_type = 'exact'
          and lower(profile.handle) = new.normalized_value)
        or (new.reservation_type = 'prefix'
          and left(lower(profile.handle), char_length(new.normalized_value)) = new.normalized_value)
      )
  ) then
    raise exception 'Handle reservation conflicts with an existing claimed handle';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_profile_handle_reservation()
from public, anon, authenticated;

create trigger profile_handle_reservations_enforce_existing_claims
before insert or update on private.profile_handle_reservations
for each row execute function private.enforce_profile_handle_reservation();

insert into private.profile_handle_reservations (
  reservation_type,
  normalized_value,
  reason
)
values
  ('exact', 'admin', 'Administrative identity'),
  ('exact', 'administrator', 'Administrative identity'),
  ('exact', 'moderator', 'Moderation identity'),
  ('exact', 'mod', 'Moderation identity'),
  ('exact', 'support', 'Support identity'),
  ('exact', 'help', 'Support identity'),
  ('exact', 'staff', 'Staff identity'),
  ('exact', 'system', 'System identity'),
  ('exact', 'official', 'Official identity'),
  ('exact', 'security', 'Security identity'),
  ('exact', 'billing', 'Billing identity'),
  ('exact', 'account', 'Account-management identity'),
  ('exact', 'accounts', 'Account-management identity'),
  ('exact', 'root', 'System identity'),
  ('exact', 'fanatical', 'FANatical identity'),
  ('exact', 'fanaticalpeople', 'FANatical identity'),
  ('prefix', 'fanatical_', 'FANatical namespace');

create or replace function private.validate_profile_handle(handle_value text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_handle text;
begin
  if handle_value is null then
    raise exception 'Handle cannot be null';
  end if;

  -- The empty string is the canonical unclaimed state.
  if handle_value = '' then
    return;
  end if;

  if char_length(handle_value) < 3 or char_length(handle_value) > 30 then
    raise exception 'Handle must be between 3 and 30 characters';
  end if;

  if (handle_value collate "C") !~ '^[A-Za-z0-9_]+$' then
    raise exception 'Handle may contain only letters, numbers, and underscores';
  end if;

  if (handle_value collate "C") !~ '^[A-Za-z0-9]'
    or (handle_value collate "C") !~ '[A-Za-z0-9]$' then
    raise exception 'Handle cannot begin or end with an underscore';
  end if;

  normalized_handle := lower(handle_value);

  if exists (
    select 1
    from private.profile_handle_reservations reservation
    where (
      reservation.reservation_type = 'exact'
      and reservation.normalized_value = normalized_handle
    ) or (
      reservation.reservation_type = 'prefix'
      and left(normalized_handle, char_length(reservation.normalized_value)) = reservation.normalized_value
    )
  ) then
    raise exception 'Handle is reserved';
  end if;
end;
$$;

revoke all on function private.validate_profile_handle(text)
from public, anon, authenticated;

-- Refuse to install the contract over invalid or ambiguous existing data.
-- This migration deliberately never rewrites a claimed handle.
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

  if exists (
    select 1
    from public.profiles profile
    where profile.handle <> ''
    group by lower(profile.handle)
    having count(*) > 1
  ) then
    raise exception 'Existing profile handles contain a case-insensitive ownership collision';
  end if;
end;
$$;

create unique index profiles_handle_normalized_unique_idx
on public.profiles ((lower(handle)))
where handle <> '';

create or replace function private.enforce_profile_handle_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.validate_profile_handle(new.handle);
  return new;
end;
$$;

revoke all on function private.enforce_profile_handle_integrity()
from public, anon, authenticated;

create trigger profiles_enforce_handle_integrity
before insert or update of handle on public.profiles
for each row execute function private.enforce_profile_handle_integrity();

-- A new fan starts without a claimed handle. Signup must not manufacture a
-- collision-prone identity from the display name.
create or replace function public.handle_new_fanatical_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  initial_display_name text;
begin
  initial_display_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
    split_part(new.email, '@', 1),
    'Fan'
  );

  insert into public.profiles (user_id, display_name)
  values (new.id, initial_display_name)
  on conflict (user_id) do nothing;

  insert into public.fan_identities (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

revoke all on function public.handle_new_fanatical_user()
from public, anon, authenticated;

-- Keep the existing profile transaction intact while making a collision from
-- the normalized unique index a clear profile-write error.
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
  violated_constraint_name text;
begin
  if owner_id is null then raise exception 'Authentication is required'; end if;

  select profile.visibility into requested_visibility
  from public.profiles profile
  where profile.user_id = owner_id;
  requested_visibility := coalesce(
    nullif(profile_data ->> 'visibility', ''),
    requested_visibility,
    'public'
  );
  if requested_visibility not in ('public', 'private') then
    raise exception 'Profile visibility must be public or private';
  end if;

  begin
    insert into public.profiles (
      user_id, display_name, handle, fanatical_name, given_name, nickname, tagline,
      birthplace, jersey_number, height, weight, featured_fan_photo_category, visibility
    ) values (
      owner_id,
      coalesce(profile_data ->> 'display_name', ''),
      requested_handle,
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
  exception
    when unique_violation then
      get stacked diagnostics violated_constraint_name = CONSTRAINT_NAME;
      if violated_constraint_name = 'profiles_handle_normalized_unique_idx' then
        raise exception using
          errcode = '23505',
          message = 'Handle is already claimed';
      end if;
      raise;
  end;

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

comment on table private.profile_handle_reservations is
  'Central case-normalized exact-name and prefix reservations for claimed profile handles.';
comment on column public.profiles.handle is
  'Claimed handle without presentation @. Empty means unclaimed; entered casing is preserved and ownership is unique on lower(handle).';
comment on function private.validate_profile_handle(text) is
  'Authoritative claimed-handle format and reservation validator used by the profiles write trigger.';
