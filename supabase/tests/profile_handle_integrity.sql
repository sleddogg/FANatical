-- Transactional proof for claimed profile-handle integrity.
-- Run after every migration against a disposable/local Supabase database.

begin;

create or replace function pg_temp.assert_true(
  condition_value boolean,
  message_value text
)
returns void
language plpgsql
as $$
begin
  if not coalesce(condition_value, false) then
    raise exception 'Profile handle assertion failed: %', message_value;
  end if;
end;
$$;

create or replace function pg_temp.assert_handle_rejected(
  profile_user_id uuid,
  candidate_handle text,
  expected_message_fragment text,
  message_value text
)
returns void
language plpgsql
as $$
begin
  begin
    update public.profiles
    set handle = candidate_handle
    where user_id = profile_user_id;
  exception
    when others then
      if position(lower(expected_message_fragment) in lower(sqlerrm)) = 0 then
        raise exception 'Profile handle assertion failed: % (unexpected error: %)',
          message_value,
          sqlerrm;
      end if;
      return;
  end;

  raise exception 'Profile handle assertion failed: % (write unexpectedly succeeded)',
    message_value;
end;
$$;

create or replace function pg_temp.assert_profile_save_rejected(
  candidate_handle text,
  expected_message_fragment text,
  message_value text
)
returns void
language plpgsql
as $$
begin
  begin
    perform public.save_my_profile(
      jsonb_build_object(
        'display_name', 'Handle Owner',
        'handle', candidate_handle,
        'featured_fan_photo_category', 'Fan Cave',
        'visibility', 'public'
      ),
      '{}'::jsonb,
      '[]'::jsonb
    );
  exception
    when others then
      if position(lower(expected_message_fragment) in lower(sqlerrm)) = 0 then
        raise exception 'Profile handle assertion failed: % (unexpected error: %)',
          message_value,
          sqlerrm;
      end if;
      return;
  end;

  raise exception 'Profile handle assertion failed: % (profile save unexpectedly succeeded)',
    message_value;
end;
$$;

insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('00000000-0000-0000-0000-000000000000', '83000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'handle-owner@fanatical.invalid', '', now(), '{}'::jsonb, '{"display_name":"Handle Owner"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '83000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'handle-collision@fanatical.invalid', '', now(), '{}'::jsonb, '{"display_name":"Handle Collision"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '83000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'handle-blank-one@fanatical.invalid', '', now(), '{}'::jsonb, '{"display_name":"Blank One"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '83000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'handle-blank-two@fanatical.invalid', '', now(), '{}'::jsonb, '{"display_name":"Blank Two"}'::jsonb, now(), now());

select pg_temp.assert_true(
  (
    select count(*) = 20
    from private.profile_handle_reservations reservation
    where reservation.reservation_type = 'exact'
      and reservation.normalized_value = any(array[
        'admin', 'administrator', 'moderator', 'mod', 'support', 'help',
        'staff', 'system', 'official', 'security', 'billing', 'account',
        'accounts', 'root', 'fanatical', 'fanaticalpeople',
        'informationlineageresolver', 'informationlineagereviewer',
        'sourcequalificationagent', 'teamcoloragent'
      ])
  ),
  'all product and legacy operational exact reservations must exist centrally'
);

select pg_temp.assert_true(
  exists (
    select 1
    from private.profile_handle_reservations reservation
    where reservation.reservation_type = 'prefix'
      and reservation.normalized_value = 'fanatical_'
  ),
  'the fanatical_ namespace reservation must exist centrally'
);

select pg_temp.assert_true(
  (
    select count(*) = 4
    from public.profiles profile
    where profile.user_id::text like '83000000-0000-0000-0000-%'
      and profile.handle = ''
  ),
  'multiple new profiles must remain unclaimed instead of receiving generated handles'
);

update public.profiles
set handle = 'lowercasefan'
where user_id = '83000000-0000-0000-0000-000000000001';
select pg_temp.assert_true(
  (select handle = 'lowercasefan' from public.profiles where user_id = '83000000-0000-0000-0000-000000000001'),
  'a valid lowercase handle must be accepted'
);

update public.profiles
set handle = 'Brad'
where user_id = '83000000-0000-0000-0000-000000000001';
select pg_temp.assert_true(
  (select handle = 'Brad' from public.profiles where user_id = '83000000-0000-0000-0000-000000000001'),
  'a valid mixed-case handle must retain its entered display casing'
);

select pg_temp.assert_handle_rejected(
  '83000000-0000-0000-0000-000000000002',
  '@LegacyFan',
  'only letters, numbers, and underscores',
  'a legacy stored handle with a leading presentation @ must be rejected'
);
update public.profiles
set handle = 'LegacyFan'
where user_id = '83000000-0000-0000-0000-000000000002';
select pg_temp.assert_true(
  (select handle = 'LegacyFan' from public.profiles where user_id = '83000000-0000-0000-0000-000000000002'),
  'the same synthetic handle without the presentation @ must be accepted'
);
update public.profiles
set handle = ''
where user_id = '83000000-0000-0000-0000-000000000002';

select pg_temp.assert_handle_rejected(
  '83000000-0000-0000-0000-000000000002',
  'brad',
  'profiles_handle_normalized_unique_idx',
  'Brad and brad must collide case-insensitively'
);

update public.profiles
set handle = 'Ab3'
where user_id = '83000000-0000-0000-0000-000000000001';
select pg_temp.assert_true(
  (select handle = 'Ab3' from public.profiles where user_id = '83000000-0000-0000-0000-000000000001'),
  'three characters must be accepted as the minimum length'
);

update public.profiles
set handle = repeat('A', 30)
where user_id = '83000000-0000-0000-0000-000000000001';
select pg_temp.assert_true(
  (select char_length(handle) = 30 from public.profiles where user_id = '83000000-0000-0000-0000-000000000001'),
  'thirty characters must be accepted as the maximum length'
);

select pg_temp.assert_handle_rejected(
  '83000000-0000-0000-0000-000000000002',
  'Ab',
  'between 3 and 30',
  'a handle shorter than three characters must be rejected'
);
select pg_temp.assert_handle_rejected(
  '83000000-0000-0000-0000-000000000002',
  repeat('A', 31),
  'between 3 and 30',
  'a handle longer than thirty characters must be rejected'
);

update public.profiles
set handle = '7thFan'
where user_id = '83000000-0000-0000-0000-000000000001';
select pg_temp.assert_true(
  (select handle = '7thFan' from public.profiles where user_id = '83000000-0000-0000-0000-000000000001'),
  'a number-first handle must be accepted'
);

update public.profiles
set handle = 'fan__club'
where user_id = '83000000-0000-0000-0000-000000000001';
select pg_temp.assert_true(
  (select handle = 'fan__club' from public.profiles where user_id = '83000000-0000-0000-0000-000000000001'),
  'consecutive underscores must be accepted'
);

select pg_temp.assert_handle_rejected(
  '83000000-0000-0000-0000-000000000002',
  '_fan',
  'begin or end',
  'a leading underscore must be rejected'
);
select pg_temp.assert_handle_rejected(
  '83000000-0000-0000-0000-000000000002',
  'fan_',
  'begin or end',
  'a trailing underscore must be rejected'
);
select pg_temp.assert_handle_rejected(
  '83000000-0000-0000-0000-000000000002',
  'fan club',
  'only letters, numbers, and underscores',
  'spaces must be rejected'
);
select pg_temp.assert_handle_rejected(
  '83000000-0000-0000-0000-000000000002',
  'fan-club',
  'only letters, numbers, and underscores',
  'punctuation other than underscore must be rejected'
);
select pg_temp.assert_handle_rejected(
  '83000000-0000-0000-0000-000000000002',
  'Brád',
  'only letters, numbers, and underscores',
  'letters outside ASCII A-Z and a-z must be rejected'
);

do $$
declare
  reserved_name text;
begin
  foreach reserved_name in array array[
    'admin', 'administrator', 'moderator', 'mod', 'support', 'help',
    'staff', 'system', 'official', 'security', 'billing', 'account',
    'accounts', 'root', 'fanatical', 'fanaticalpeople',
    'informationlineageresolver', 'informationlineagereviewer',
    'sourcequalificationagent', 'teamcoloragent'
  ]
  loop
    perform pg_temp.assert_handle_rejected(
      '83000000-0000-0000-0000-000000000002',
      upper(reserved_name),
      'reserved',
      format('reserved handle %s must be rejected case-insensitively', reserved_name)
    );
  end loop;
end;
$$;

select pg_temp.assert_handle_rejected(
  '83000000-0000-0000-0000-000000000002',
  'FaNaTiCaL_Support',
  'reserved',
  'the fanatical_ prefix must be rejected case-insensitively'
);

-- Reserve a distinct claimed handle for the RPC collision proof.
update public.profiles
set handle = 'TakenHandle'
where user_id = '83000000-0000-0000-0000-000000000002';

select set_config('request.jwt.claim.sub', '83000000-0000-0000-0000-000000000001', true);
set local role authenticated;

select public.save_my_profile(
  '{"display_name":"Handle Owner","handle":"OwnerOne","featured_fan_photo_category":"Fan Cave","visibility":"public"}'::jsonb,
  '{}'::jsonb,
  '[]'::jsonb
);
select public.save_my_profile(
  '{"display_name":"Handle Owner","handle":"OwnerTwo","featured_fan_photo_category":"Fan Cave","visibility":"public"}'::jsonb,
  '{}'::jsonb,
  '[]'::jsonb
);
select pg_temp.assert_true(
  (select handle = 'OwnerTwo' from public.profiles where user_id = '83000000-0000-0000-0000-000000000001'),
  'an owner must be able to change to another available valid handle with casing preserved'
);

select pg_temp.assert_profile_save_rejected(
  'takenhandle',
  'Handle is already claimed',
  'save_my_profile must report a normalized ownership collision clearly'
);
select pg_temp.assert_profile_save_rejected(
  'ADMIN',
  'Handle is reserved',
  'save_my_profile must report a reserved handle clearly'
);
select pg_temp.assert_profile_save_rejected(
  'bad handle',
  'only letters, numbers, and underscores',
  'save_my_profile must report an invalid format clearly'
);
select pg_temp.assert_true(
  (select handle = 'OwnerTwo' from public.profiles where user_id = '83000000-0000-0000-0000-000000000001'),
  'rejected profile saves must leave the existing handle unchanged'
);

reset role;

select pg_temp.assert_true(
  (
    select count(*) = 2
    from public.profiles profile
    where profile.user_id in (
      '83000000-0000-0000-0000-000000000003',
      '83000000-0000-0000-0000-000000000004'
    )
      and profile.handle = ''
  ),
  'more than one profile must be allowed to remain blank and unclaimed'
);

rollback;
