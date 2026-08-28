-- Keep operational catalog identities out of the fan handle namespace while
-- preserving their Auth, catalog-actor, capability, audit, and provenance IDs.

-- Exact operational identifiers may contain punctuation that is not legal in
-- a fan handle. Retain the canonical actor_key verbatim apart from the same
-- case normalization used by handle resolution; do not derive a second name.
alter table private.profile_handle_reservations
drop constraint profile_handle_reservations_normalized_value_check;

alter table private.profile_handle_reservations
add constraint profile_handle_reservations_normalized_value_check check (
  normalized_value <> ''
  and normalized_value = lower(normalized_value)
);

alter table private.profile_handle_reservations
add column reservation_source text not null default 'manual'
  check (reservation_source in ('manual', 'catalog_actor'));

alter table private.profile_handle_reservations
add column catalog_actor_id uuid
  references public.catalog_actors(id) on delete restrict;

alter table private.profile_handle_reservations
add constraint profile_handle_reservations_source_check check (
  (reservation_source = 'manual' and catalog_actor_id is null)
  or (
    reservation_source = 'catalog_actor'
    and reservation_type = 'exact'
    and catalog_actor_id is not null
  )
);

create index profile_handle_reservations_catalog_actor_idx
on private.profile_handle_reservations(catalog_actor_id)
where catalog_actor_id is not null;

-- These legacy generated fan-handle forms are not canonical actor_keys, but
-- they remain reserved after being released from the operational profiles.
insert into private.profile_handle_reservations (
  reservation_type,
  normalized_value,
  reason
)
values
  ('exact', 'informationlineageresolver', 'Legacy operational agent handle'),
  ('exact', 'informationlineagereviewer', 'Legacy operational agent handle'),
  ('exact', 'sourcequalificationagent', 'Legacy operational agent handle'),
  ('exact', 'teamcoloragent', 'Legacy operational agent handle')
on conflict (reservation_type, normalized_value) do nothing;

-- Serialize handle claims and reservation changes through one small namespace
-- lock. This closes the cross-table race between claiming a handle and
-- activating an operational actor with the same case-normalized identifier.
create or replace function private.lock_profile_handle_namespace()
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('fanatical:profile-handle-namespace', 0)
  );
$$;

revoke all on function private.lock_profile_handle_namespace()
from public, anon, authenticated;

create or replace function private.enforce_profile_handle_reservation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.lock_profile_handle_namespace();

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
  perform private.lock_profile_handle_namespace();

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

-- Agent and service actor types remain operational identities even when they
-- are inactive. Retirement can release a reservation, but does not silently
-- turn the same Auth account into a fan identity.
create or replace view private.fan_profile_population
with (security_barrier = true)
as
select profile.user_id
from public.profiles profile
where not exists (
  select 1
  from public.catalog_actors actor
  where actor.auth_user_id = profile.user_id
    and actor.actor_type in ('agent', 'service')
);

revoke all on table private.fan_profile_population
from public, anon, authenticated;

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
    join private.fan_profile_population fan_profile
      on fan_profile.user_id = profile.user_id
    where profile.user_id = profile_user_id
      and (
        profile.user_id = (select auth.uid())
        or profile.visibility = 'public'
      )
  );
$$;

revoke all on function private.can_view_profile(uuid)
from public, anon, authenticated;
grant execute on function private.can_view_profile(uuid)
to anon, authenticated;

create or replace function private.enforce_profile_handle_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.handle <> '' and exists (
    select 1
    from public.catalog_actors actor
    where actor.auth_user_id = new.user_id
      and actor.actor_type in ('agent', 'service')
  ) then
    raise exception 'Operational agent/service identities cannot claim public fan handles';
  end if;

  perform private.validate_profile_handle(new.handle);
  return new;
end;
$$;

revoke all on function private.enforce_profile_handle_integrity()
from public, anon, authenticated;

-- Refuse to install over an operational profile that still has a handle. The
-- approved hosted data cleanup is separate and this migration never rewrites
-- profile data.
do $$
declare
  violating_user_id uuid;
begin
  select profile.user_id
  into violating_user_id
  from public.profiles profile
  join public.catalog_actors actor on actor.auth_user_id = profile.user_id
  where actor.actor_type in ('agent', 'service')
    and profile.handle <> ''
  limit 1;

  if violating_user_id is not null then
    raise exception
      'Operational profile % still has a public fan handle; clear it before applying this migration',
      violating_user_id;
  end if;
end;
$$;

create or replace function private.protect_active_catalog_actor_reservation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  protects_active_identifier boolean;
begin
  if old.reservation_source <> 'catalog_actor' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  select exists (
    select 1
    from public.catalog_actors actor
    where actor.id = old.catalog_actor_id
      and actor.actor_type in ('agent', 'service')
      and actor.active
      and lower(actor.actor_key) = old.normalized_value
  ) into protects_active_identifier;

  if protects_active_identifier then
    if tg_op = 'DELETE' then
      raise exception 'An active operational identity reservation cannot be removed';
    end if;

    if row(
      new.reservation_type,
      new.normalized_value,
      new.reservation_source,
      new.catalog_actor_id
    ) is distinct from row(
      old.reservation_type,
      old.normalized_value,
      old.reservation_source,
      old.catalog_actor_id
    ) then
      raise exception 'An active operational identity reservation cannot be reassigned';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function private.protect_active_catalog_actor_reservation()
from public, anon, authenticated;

create trigger profile_handle_reservations_protect_active_catalog_actor
before update or delete on private.profile_handle_reservations
for each row execute function private.protect_active_catalog_actor_reservation();

create or replace function private.reserve_catalog_actor_identifier(
  actor_id_value uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_record record;
  reservation_record record;
  normalized_identifier text;
begin
  select
    actor.id,
    actor.actor_key,
    actor.actor_type,
    actor.auth_user_id,
    actor.active
  into actor_record
  from public.catalog_actors actor
  where actor.id = actor_id_value;

  if not found or actor_record.actor_type not in ('agent', 'service') then
    return;
  end if;

  if actor_record.actor_key = '' then
    raise exception 'An operational catalog actor must have a nonblank canonical identifier';
  end if;

  if actor_record.auth_user_id is not null and exists (
    select 1
    from public.profiles profile
    where profile.user_id = actor_record.auth_user_id
      and profile.handle <> ''
  ) then
    raise exception
      'Operational catalog actor % is linked to a profile with a public fan handle',
      actor_record.actor_key;
  end if;

  normalized_identifier := lower(actor_record.actor_key);
  perform private.lock_profile_handle_namespace();

  select
    reservation.reservation_source,
    reservation.catalog_actor_id
  into reservation_record
  from private.profile_handle_reservations reservation
  where reservation.reservation_type = 'exact'
    and reservation.normalized_value = normalized_identifier
  for update;

  if not found then
    insert into private.profile_handle_reservations (
      reservation_type,
      normalized_value,
      reason,
      reservation_source,
      catalog_actor_id
    ) values (
      'exact',
      normalized_identifier,
      pg_catalog.format(
        'Canonical %s actor identifier: %s',
        actor_record.actor_type,
        actor_record.actor_key
      ),
      'catalog_actor',
      actor_record.id
    );
  elsif reservation_record.reservation_source = 'manual' then
    update private.profile_handle_reservations
    set
      reason = pg_catalog.format(
        'Canonical %s actor identifier: %s',
        actor_record.actor_type,
        actor_record.actor_key
      ),
      reservation_source = 'catalog_actor',
      catalog_actor_id = actor_record.id
    where reservation_type = 'exact'
      and normalized_value = normalized_identifier;
  elsif reservation_record.catalog_actor_id = actor_record.id then
    update private.profile_handle_reservations
    set reason = pg_catalog.format(
      'Canonical %s actor identifier: %s',
      actor_record.actor_type,
      actor_record.actor_key
    )
    where reservation_type = 'exact'
      and normalized_value = normalized_identifier;
  else
    raise exception
      'Operational identifier % is already reserved for another catalog actor',
      actor_record.actor_key;
  end if;
end;
$$;

revoke all on function private.reserve_catalog_actor_identifier(uuid)
from public, anon, authenticated;

create or replace function private.reserve_catalog_actor_identifier_on_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.reserve_catalog_actor_identifier(new.id);
  return new;
end;
$$;

revoke all on function private.reserve_catalog_actor_identifier_on_write()
from public, anon, authenticated;

create trigger catalog_actors_reserve_fan_handle_identifier
after insert or update of actor_key, actor_type, auth_user_id, active
on public.catalog_actors
for each row execute function private.reserve_catalog_actor_identifier_on_write();

-- Backfill every existing agent/service actor, active or retired. A retired or
-- renamed identity's automatic reservation is removable; active current
-- identifiers are protected by the trigger above.
do $$
declare
  actor_id_value uuid;
begin
  for actor_id_value in
    select actor.id
    from public.catalog_actors actor
    where actor.actor_type in ('agent', 'service')
    order by actor.id
  loop
    perform private.reserve_catalog_actor_identifier(actor_id_value);
  end loop;
end;
$$;

comment on table private.profile_handle_reservations is
  'Central case-normalized handle namespace. Manual reservations are removable; catalog_actor reservations bind canonical operational identifiers and are protected while current and active.';
comment on column private.profile_handle_reservations.reservation_source is
  'manual for administrator-maintained namespace entries; catalog_actor for reservations created from catalog_actors.actor_key.';
comment on column private.profile_handle_reservations.catalog_actor_id is
  'The permanent catalog actor whose canonical actor_key produced an automatic reservation; null for manual entries.';
comment on view private.fan_profile_population is
  'Canonical fan-only profile population. Profiles linked to agent/service catalog actors are excluded even when the actor is inactive.';
comment on function private.reserve_catalog_actor_identifier(uuid) is
  'Reserves the unchanged, case-normalized catalog_actors.actor_key in the fan handle namespace and rejects operational links to claimed fan handles.';
comment on function private.can_view_profile(uuid) is
  'Fan-facing profile visibility boundary. Operational agent/service profiles are never viewable as fans.';
comment on function private.validate_profile_handle(text) is
  'Authoritative claimed-handle format and reservation validator, serialized with reservation writes through the handle-namespace transaction lock.';
