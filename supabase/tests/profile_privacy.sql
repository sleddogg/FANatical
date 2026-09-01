-- Transactional integration coverage for profile privacy and profile-media
-- ownership migrations through 202608270001.
-- Run against a disposable/local Supabase database after all migrations:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
--     -f supabase/tests/profile_privacy.sql
-- The transaction rolls back every fixture profile and storage row.

begin;

create or replace function pg_temp.assert_true(condition_value boolean, message_value text)
returns void
language plpgsql
as $$
begin
  if not coalesce(condition_value, false) then
    raise exception 'Profile privacy integration assertion failed: %', message_value;
  end if;
end;
$$;

create or replace function pg_temp.assert_check_violation(
  statement_value text,
  message_value text
)
returns void
language plpgsql
as $$
begin
  begin
    execute statement_value;
  exception
    when check_violation then return;
  end;
  raise exception 'Profile privacy integration assertion failed: %', message_value;
end;
$$;

insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'privacy-public-owner@fanatical.invalid', '', now(), '{}'::jsonb, '{"display_name":"Public Owner"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'privacy-private-owner@fanatical.invalid', '', now(), '{}'::jsonb, '{"display_name":"Private Owner"}'::jsonb, now(), now()),
  ('00000000-0000-0000-0000-000000000000', '81000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'privacy-viewer@fanatical.invalid', '', now(), '{}'::jsonb, '{"display_name":"Viewer"}'::jsonb, now(), now());

update public.profiles
set visibility = case user_id
    when '81000000-0000-0000-0000-000000000001'
      then 'members_visible'
    else 'private'
  end,
  handle = case user_id
    when '81000000-0000-0000-0000-000000000001' then 'MemberOwner'
    when '81000000-0000-0000-0000-000000000002' then 'PrivateOwner'
    else 'PrivacyViewer'
  end,
  given_name = case user_id
    when '81000000-0000-0000-0000-000000000001' then 'AllowedGiven'
    else null
  end,
  nickname = case user_id
    when '81000000-0000-0000-0000-000000000001' then 'HiddenNickname'
    else null
  end,
  personal_field_visibility = case user_id
    when '81000000-0000-0000-0000-000000000001'
      then '{"given_name":true,"nickname":false}'::jsonb
    else '{}'::jsonb
  end
where user_id in (
  '81000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000002',
  '81000000-0000-0000-0000-000000000003'
);

select set_config(
  'test.profile_privacy.member_namespace',
  (select media_namespace from public.profiles
   where user_id = '81000000-0000-0000-0000-000000000001'),
  true
);
select set_config(
  'test.profile_privacy.private_namespace',
  (select media_namespace from public.profiles
   where user_id = '81000000-0000-0000-0000-000000000002'),
  true
);

insert into public.profile_photos(
  id, user_id, source_path, display_path, source_filename, source_media_type,
  source_width, source_height
)
values
  ('81100000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001/avatar/public-source.jpg', current_setting('test.profile_privacy.member_namespace') || '/avatar/public-display.webp', 'public.jpg', 'image/jpeg', 100, 100),
  ('81100000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000002/avatar/private-source.jpg', current_setting('test.profile_privacy.private_namespace') || '/avatar/private-display.webp', 'private.jpg', 'image/jpeg', 100, 100),
  ('81100000-0000-0000-0000-000000000004', '81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001/avatar/inactive-source.jpg', current_setting('test.profile_privacy.member_namespace') || '/avatar/inactive-display.webp', 'inactive.jpg', 'image/jpeg', 100, 100);

update public.profiles
set active_profile_photo_id = case user_id
    when '81000000-0000-0000-0000-000000000001' then '81100000-0000-0000-0000-000000000001'::uuid
    when '81000000-0000-0000-0000-000000000002' then '81100000-0000-0000-0000-000000000002'::uuid
  end,
  avatar_path = case user_id
    when '81000000-0000-0000-0000-000000000001' then current_setting('test.profile_privacy.member_namespace') || '/avatar/public-display.webp'
    when '81000000-0000-0000-0000-000000000002' then current_setting('test.profile_privacy.private_namespace') || '/avatar/private-display.webp'
  end,
  avatar_customization = case user_id
    when '81000000-0000-0000-0000-000000000001' then '{"sourcePath":"81000000-0000-0000-0000-000000000001/avatar/public-source.jpg"}'::jsonb
    when '81000000-0000-0000-0000-000000000002' then '{"sourcePath":"81000000-0000-0000-0000-000000000002/avatar/private-source.jpg"}'::jsonb
  end
where user_id in ('81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002');

insert into public.profile_visual_images(
  id, user_id, variant, source_path, display_path, source_filename,
  source_media_type, source_width, source_height
)
values
  ('81200000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', 'wide', '81000000-0000-0000-0000-000000000001/profile-visual/wide/public-source.jpg', '81000000-0000-0000-0000-000000000001/profile-visual/wide/public-display.webp', 'public-wide.jpg', 'image/jpeg', 1600, 900),
  ('81200000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000002', 'wide', '81000000-0000-0000-0000-000000000002/profile-visual/wide/private-source.jpg', '81000000-0000-0000-0000-000000000002/profile-visual/wide/private-display.webp', 'private-wide.jpg', 'image/jpeg', 1600, 900);

insert into public.profile_visuals(
  user_id, variant, source_path, display_path, source_filename,
  source_media_type, source_width, source_height
)
select user_id, variant, source_path, display_path, source_filename,
       source_media_type, source_width, source_height
from public.profile_visual_images
where user_id in ('81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002');

insert into storage.objects(bucket_id, name, owner_id, metadata)
values
  ('profile-media', '81000000-0000-0000-0000-000000000001/avatar/public-source.jpg', '81000000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('profile-media', current_setting('test.profile_privacy.member_namespace') || '/avatar/public-display.webp', '81000000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('profile-media', '81000000-0000-0000-0000-000000000001/avatar/public-display.webp', '81000000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('profile-media', current_setting('test.profile_privacy.member_namespace') || '/avatar/inactive-display.webp', '81000000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('profile-media', '81000000-0000-0000-0000-000000000001/profile-visual/wide/public-source.jpg', '81000000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('profile-media', '81000000-0000-0000-0000-000000000001/profile-visual/wide/public-display.webp', '81000000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('profile-media', '81000000-0000-0000-0000-000000000002/avatar/private-source.jpg', '81000000-0000-0000-0000-000000000002', '{}'::jsonb),
  ('profile-media', current_setting('test.profile_privacy.private_namespace') || '/avatar/private-display.webp', '81000000-0000-0000-0000-000000000002', '{}'::jsonb),
  ('profile-media', '81000000-0000-0000-0000-000000000002/avatar/private-display.webp', '81000000-0000-0000-0000-000000000002', '{}'::jsonb),
  ('profile-media', '81000000-0000-0000-0000-000000000002/profile-visual/wide/private-source.jpg', '81000000-0000-0000-0000-000000000002', '{}'::jsonb),
  ('profile-media', '81000000-0000-0000-0000-000000000002/profile-visual/wide/private-display.webp', '81000000-0000-0000-0000-000000000002', '{}'::jsonb);

select pg_temp.assert_true(
  (
    select count(*) = 4 and bool_and(not constraint_record.convalidated)
    from pg_catalog.pg_constraint constraint_record
    where constraint_record.conname = any(array[
      'profiles_owned_media_paths_check',
      'profile_photos_owned_media_paths_check',
      'profile_visual_images_owned_media_paths_check',
      'profile_visuals_owned_media_paths_check'
    ])
  ),
  'ownership checks must be present and migration-safe for unreviewed legacy rows'
);
select pg_temp.assert_true(
  (select count(*) = 0 from private.profile_media_path_ownership_violations),
  'valid owner-bound fixtures must not appear in the legacy cleanup inventory'
);

-- Members-visible owner: full owner metadata and both object classes.
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.assert_true((select count(*) = 1 from public.profiles where user_id = '81000000-0000-0000-0000-000000000001'), 'owner must read own Members-visible profile');
select pg_temp.assert_true((select count(*) = 1 from public.profile_photos where source_path like '%public-source.jpg'), 'owner editing must retain original metadata');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/public-source.jpg'), 'owner must read original avatar object');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name = current_setting('test.profile_privacy.member_namespace') || '/avatar/public-display.webp'), 'owner must read active opaque display avatar object');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name = current_setting('test.profile_privacy.member_namespace') || '/avatar/inactive-display.webp'), 'owner must retain inactive opaque avatar library access');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name like '%/wide/public-source.jpg'), 'owner must read original visual object');
reset role;

-- Authenticated ordinary fan: server-allowlisted Members-visible data, private
-- attribution state, active avatar derivatives, and no protected/profile-media
-- originals.
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000003', true);
set local role authenticated;
select pg_temp.assert_true(public.get_member_profile_by_fanatical_name('memberowner') is not null, 'viewer must resolve current Fanatical Name case-insensitively');
select pg_temp.assert_true(not (public.get_member_profile_by_fanatical_name('MemberOwner') ? 'user_id'), 'safe profile must omit Auth UUID');
select pg_temp.assert_true(not (public.get_member_profile_by_fanatical_name('MemberOwner') ? 'email'), 'safe profile must omit email');
select pg_temp.assert_true(not (public.get_member_profile_by_fanatical_name('MemberOwner') ? 'phone'), 'safe profile must omit phone');
select pg_temp.assert_true(not (public.get_member_profile_by_fanatical_name('MemberOwner') ? 'date_of_birth'), 'safe profile must omit exact DOB');
select pg_temp.assert_true(public.get_member_profile_by_fanatical_name('MemberOwner')::text not like '%source_path%', 'safe member profile must omit source_path');
select pg_temp.assert_true(public.get_member_profile_by_fanatical_name('MemberOwner')::text not like '%source_filename%', 'safe member profile must omit source filename metadata');
select pg_temp.assert_true(
  public.get_member_profile_by_fanatical_name('MemberOwner')::text
    not like '%81000000-0000-0000-0000-000000000001%'
  and public.get_member_profile_by_fanatical_name('MemberOwner')::text
    not like '%81000000-0000-0000-0000-000000000003%',
  'fan-safe payload must recursively omit both subject and viewer Auth UUIDs'
);
select pg_temp.assert_true(public.get_member_profile_by_fanatical_name('MemberOwner') #>> '{personal_fields,given_name}' = 'AllowedGiven', 'owner-opted Given Name must be returned');
select pg_temp.assert_true(not ((public.get_member_profile_by_fanatical_name('MemberOwner') -> 'personal_fields') ? 'nickname'), 'hidden optional fields must be absent, not null');
select pg_temp.assert_true((select count(*) = 0 from public.profiles where user_id = '81000000-0000-0000-0000-000000000001'), 'non-owner must not bypass safe profile boundary with direct table reads');
select pg_temp.assert_true((select count(*) = 0 from public.profile_visuals where user_id = '81000000-0000-0000-0000-000000000001'), 'non-owner must not read source-bearing visual table');
select pg_temp.assert_true((select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/public-source.jpg'), 'non-owner must not read member-profile avatar original');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/public-display.webp'), 'non-owner must read member-profile avatar display');
select pg_temp.assert_true((select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name = '81000000-0000-0000-0000-000000000001/avatar/public-display.webp'), 'legacy UUID display paths must remain owner-only');
select pg_temp.assert_true((select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/inactive-display.webp'), 'non-owner must not read inactive avatar-library derivatives');
select pg_temp.assert_true((select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name like '%/wide/public-source.jpg'), 'non-owner must not read member-profile visual original');
select pg_temp.assert_true((select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name like '%/wide/public-display.webp'), 'non-owner member profile does not expose legacy UUID visual paths');
select pg_temp.assert_true(public.get_member_profile_by_fanatical_name('PrivateOwner') ->> 'visibility' = 'private', 'private profile must return approved private attribution state');
select pg_temp.assert_true(not (public.get_member_profile_by_fanatical_name('PrivateOwner') ? 'display_name'), 'private profile must omit member fields');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/private-display.webp'), 'authenticated fan may read only the active private comment-attribution avatar derivative');
select pg_temp.assert_true((select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name like '%/wide/private-display.webp'), 'private non-attribution visuals must remain unavailable');
select pg_temp.assert_check_violation(
  $statement$
    update public.profiles
    set avatar_path = '81000000-0000-0000-0000-000000000002/avatar/private-display.webp'
    where user_id = '81000000-0000-0000-0000-000000000003'
  $statement$,
  'an authenticated user must not bind avatar_path to another user namespace'
);
select pg_temp.assert_check_violation(
  $statement$
    update public.profiles
    set avatar_customization = '{"sourcePath":"81000000-0000-0000-0000-000000000002/avatar/rebound-source.jpg"}'::jsonb
    where user_id = '81000000-0000-0000-0000-000000000003'
  $statement$,
  'an authenticated user must not bind avatar source metadata to another user namespace'
);
select pg_temp.assert_check_violation(
  $statement$
    update public.profiles
    set avatar_customization = '{"displayPath":"81000000-0000-0000-0000-000000000002/avatar/rebound-display.webp"}'::jsonb
    where user_id = '81000000-0000-0000-0000-000000000003'
  $statement$,
  'an authenticated user must not bind avatar display metadata to another user namespace'
);
select pg_temp.assert_check_violation(
  $statement$
    insert into public.profile_photos(
      id, user_id, source_path, display_path, source_filename,
      source_media_type, source_width, source_height
    ) values (
      '81100000-0000-0000-0000-000000000003',
      '81000000-0000-0000-0000-000000000003',
      '81000000-0000-0000-0000-000000000002/avatar/rebound-source.jpg',
      '81000000-0000-0000-0000-000000000003/avatar/rebound-display.webp',
      'rebound.jpg', 'image/jpeg', 100, 100
    )
  $statement$,
  'profile photo source paths must be owner-bound'
);
select pg_temp.assert_check_violation(
  $statement$
    insert into public.profile_photos(
      id, user_id, source_path, display_path, source_filename,
      source_media_type, source_width, source_height
    ) values (
      '81100000-0000-0000-0000-000000000003',
      '81000000-0000-0000-0000-000000000003',
      '81000000-0000-0000-0000-000000000003/avatar/rebound-source.jpg',
      '81000000-0000-0000-0000-000000000002/avatar/rebound-display.webp',
      'rebound.jpg', 'image/jpeg', 100, 100
    )
  $statement$,
  'profile photo display paths must be owner-bound'
);
select pg_temp.assert_check_violation(
  $statement$
    insert into public.profile_visual_images(
      id, user_id, variant, source_path, display_path, source_filename,
      source_media_type, source_width, source_height
    ) values (
      '81200000-0000-0000-0000-000000000003',
      '81000000-0000-0000-0000-000000000003', 'wide',
      '81000000-0000-0000-0000-000000000002/profile-visual/wide/rebound-source.jpg',
      '81000000-0000-0000-0000-000000000003/profile-visual/wide/rebound-display.webp',
      'rebound-wide.jpg', 'image/jpeg', 1600, 900
    )
  $statement$,
  'profile visual library source paths must be owner-bound'
);
select pg_temp.assert_check_violation(
  $statement$
    insert into public.profile_visual_images(
      id, user_id, variant, source_path, display_path, source_filename,
      source_media_type, source_width, source_height
    ) values (
      '81200000-0000-0000-0000-000000000003',
      '81000000-0000-0000-0000-000000000003', 'wide',
      '81000000-0000-0000-0000-000000000003/profile-visual/wide/rebound-source.jpg',
      '81000000-0000-0000-0000-000000000002/profile-visual/wide/rebound-display.webp',
      'rebound-wide.jpg', 'image/jpeg', 1600, 900
    )
  $statement$,
  'profile visual library display paths must be owner-bound'
);
select pg_temp.assert_check_violation(
  $statement$
    insert into public.profile_visuals(
      user_id, variant, source_path, display_path, source_filename,
      source_media_type, source_width, source_height
    ) values (
      '81000000-0000-0000-0000-000000000003', 'mobile',
      '81000000-0000-0000-0000-000000000002/profile-visual/mobile/rebound-source.jpg',
      '81000000-0000-0000-0000-000000000003/profile-visual/mobile/rebound-display.webp',
      'rebound-mobile.jpg', 'image/jpeg', 900, 1600
    )
  $statement$,
  'active profile visual source paths must be owner-bound'
);
select pg_temp.assert_check_violation(
  $statement$
    insert into public.profile_visuals(
      user_id, variant, source_path, display_path, source_filename,
      source_media_type, source_width, source_height
    ) values (
      '81000000-0000-0000-0000-000000000003', 'mobile',
      '81000000-0000-0000-0000-000000000003/profile-visual/mobile/rebound-source.jpg',
      '81000000-0000-0000-0000-000000000002/profile-visual/mobile/rebound-display.webp',
      'rebound-mobile.jpg', 'image/jpeg', 900, 1600
    )
  $statement$,
  'active profile visual display paths must be owner-bound'
);
select pg_temp.assert_true(
  (select avatar_path is null and avatar_customization = '{}'::jsonb
   from public.profiles
   where user_id = '81000000-0000-0000-0000-000000000003'),
  'rejected cross-user metadata writes must leave the attacker profile unchanged'
);
update public.profiles
set avatar_path = media_namespace || '/avatar/unrecorded-original.jpg'
where user_id = '81000000-0000-0000-0000-000000000003';
select pg_temp.assert_true(
  public.get_member_profile_by_fanatical_name('PrivacyViewer')
    -> 'avatar' = 'null'::jsonb,
  'an opaque naked avatar_path cannot launder an unrecorded original into a fan payload'
);
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/private-display.webp'), 'the legitimate active-avatar attribution exception remains available without accepting the rejected metadata rebind');
reset role;

-- Anonymous profile/viewer access is removed, including all display media.
select set_config('request.jwt.claim.sub', '', true);
set local role anon;
select pg_temp.assert_true(
  to_regprocedure('public.get_profile_for_viewer(uuid)') is null,
  'the UUID-shaped profile reader must be removed'
);
select pg_temp.assert_true(
  not has_function_privilege(
    'anon',
    'public.get_member_profile_by_fanatical_name(text)',
    'EXECUTE'
  ),
  'anonymous role must not execute the current-name profile reader'
);
select pg_temp.assert_true((select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/public-display.webp'), 'anonymous viewer must not read Members-visible display media');
select pg_temp.assert_true((select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/public-source.jpg'), 'anonymous viewer must not read original media');
select pg_temp.assert_true((select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/private-display.webp'), 'anonymous viewer must not read private attribution media');
reset role;

-- Private owner retains full access; legacy Public requests stay conservative,
-- while the explicit Phase 5A control selects Members-visible.
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000002', true);
set local role authenticated;
select pg_temp.assert_true((select count(*) = 1 from public.profiles where user_id = '81000000-0000-0000-0000-000000000002'), 'private owner must read own profile');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/private-source.jpg'), 'private owner must read own original');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name = current_setting('test.profile_privacy.private_namespace') || '/avatar/private-display.webp'), 'private owner must read own active opaque display');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name = '81000000-0000-0000-0000-000000000002/avatar/private-display.webp'), 'private owner must retain owner-only access to a legacy UUID display');
select public.save_my_profile(
  '{"display_name":"Private Owner","handle":"PrivateOwner","featured_fan_photo_category":"Fan Cave","visibility":"public"}'::jsonb,
  '{}'::jsonb,
  '[]'::jsonb
);
select pg_temp.assert_true((select visibility = 'private' from public.profiles where user_id = '81000000-0000-0000-0000-000000000002'), 'legacy Public must not become owner consent');
select public.set_my_profile_privacy(
  'members_visible',
  '{"given_name":true}'::jsonb
);
select pg_temp.assert_true((select visibility = 'members_visible' and personal_field_visibility = '{"given_name":true}'::jsonb from public.profiles where user_id = '81000000-0000-0000-0000-000000000002'), 'explicit Members-visible and field visibility must persist');
select public.set_my_profile_privacy('private', '{}'::jsonb);
select pg_temp.assert_true((select visibility = 'private' from public.profiles where user_id = '81000000-0000-0000-0000-000000000002'), 'Members-visible to Private must persist');
reset role;

-- Existing library records and active projections remain intact.
select pg_temp.assert_true((select count(*) = 3 from public.profile_photos where user_id in ('81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002')), 'profile photo fixture records must remain intact');
select pg_temp.assert_true((select count(*) = 2 from public.profile_visual_images where user_id in ('81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002')), 'profile visual library fixture records must remain intact');
select pg_temp.assert_true((select count(*) = 2 from public.profile_visuals where user_id in ('81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002')), 'active profile visual fixture records must remain intact');

-- Defense in depth: simulate a pre-migration legacy row that bypassed the new
-- write constraint. Authorization must ignore the attacker's cross-namespace
-- metadata even when the malformed value already exists.
create temporary table profile_path_constraint_definition(
  definition text not null
) on commit drop;
insert into profile_path_constraint_definition(definition)
select pg_catalog.pg_get_constraintdef(constraint_record.oid, true)
from pg_catalog.pg_constraint constraint_record
where constraint_record.conname = 'profiles_owned_media_paths_check'
  and constraint_record.conrelid = 'public.profiles'::regclass;
alter table public.profiles drop constraint profiles_owned_media_paths_check;
update public.profiles
set avatar_path = '81000000-0000-0000-0000-000000000002/avatar/private-display.webp'
where user_id = '81000000-0000-0000-0000-000000000003';
do $migration_safety$
declare
  constraint_definition text;
begin
  select definition into strict constraint_definition
  from profile_path_constraint_definition;
  execute pg_catalog.format(
    'alter table public.profiles add constraint profiles_owned_media_paths_check %s',
    constraint_definition
  );
end;
$migration_safety$;
select pg_temp.assert_true(
  (
    select not constraint_record.convalidated
    from pg_catalog.pg_constraint constraint_record
    where constraint_record.conname = 'profiles_owned_media_paths_check'
      and constraint_record.conrelid = 'public.profiles'::regclass
  ),
  'NOT VALID ownership enforcement must install without scanning a malformed legacy row'
);
select pg_temp.assert_true(
  (
    select count(*) = 1
    from private.profile_media_path_ownership_violations violation
    where violation.table_name = 'profiles'
      and violation.user_id = '81000000-0000-0000-0000-000000000003'
      and violation.column_name = 'avatar_path'
      and violation.media_path = '81000000-0000-0000-0000-000000000002/avatar/private-display.webp'
  ),
  'the cleanup inventory must identify a persisted legacy cross-user avatar path'
);

select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000003', true);
set local role authenticated;
select pg_temp.assert_true(
  not private.profile_media_path_is_visible('81000000-0000-0000-0000-000000000002/profile-visual/wide/private-display.webp'),
  'malformed avatar metadata must not authorize unrelated private visual media'
);
select pg_temp.assert_true(
  (select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name = '81000000-0000-0000-0000-000000000002/avatar/private-display.webp'),
  'a UUID-prefixed legacy display must not be exposed through malformed metadata'
);
reset role;

select set_config('request.jwt.claim.sub', '', true);
set local role anon;
select pg_temp.assert_true(
  (select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name = '81000000-0000-0000-0000-000000000002/avatar/private-display.webp'),
  'a public attacker profile with a malformed rebind must not expose the victim display anonymously'
);
reset role;

select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000002', true);
set local role authenticated;
select pg_temp.assert_true(
  (select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name = '81000000-0000-0000-0000-000000000002/avatar/private-display.webp'),
  'the victim must retain legitimate owner access after the exact rebind sequence'
);
reset role;

rollback;
