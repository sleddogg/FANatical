-- Transactional integration coverage for 202608220001_profile_privacy.sql.
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
  when '81000000-0000-0000-0000-000000000001' then 'public'
  when '81000000-0000-0000-0000-000000000002' then 'private'
  else 'public'
end;

insert into public.profile_photos(
  id, user_id, source_path, display_path, source_filename, source_media_type,
  source_width, source_height
)
values
  ('81100000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001/avatar/public-source.jpg', '81000000-0000-0000-0000-000000000001/avatar/public-display.webp', 'public.jpg', 'image/jpeg', 100, 100),
  ('81100000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000002/avatar/private-source.jpg', '81000000-0000-0000-0000-000000000002/avatar/private-display.webp', 'private.jpg', 'image/jpeg', 100, 100);

update public.profiles
set active_profile_photo_id = case user_id
    when '81000000-0000-0000-0000-000000000001' then '81100000-0000-0000-0000-000000000001'::uuid
    when '81000000-0000-0000-0000-000000000002' then '81100000-0000-0000-0000-000000000002'::uuid
  end,
  avatar_path = case user_id
    when '81000000-0000-0000-0000-000000000001' then '81000000-0000-0000-0000-000000000001/avatar/public-display.webp'
    when '81000000-0000-0000-0000-000000000002' then '81000000-0000-0000-0000-000000000002/avatar/private-display.webp'
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
  ('profile-media', '81000000-0000-0000-0000-000000000001/avatar/public-display.webp', '81000000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('profile-media', '81000000-0000-0000-0000-000000000001/profile-visual/wide/public-source.jpg', '81000000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('profile-media', '81000000-0000-0000-0000-000000000001/profile-visual/wide/public-display.webp', '81000000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('profile-media', '81000000-0000-0000-0000-000000000002/avatar/private-source.jpg', '81000000-0000-0000-0000-000000000002', '{}'::jsonb),
  ('profile-media', '81000000-0000-0000-0000-000000000002/avatar/private-display.webp', '81000000-0000-0000-0000-000000000002', '{}'::jsonb),
  ('profile-media', '81000000-0000-0000-0000-000000000002/profile-visual/wide/private-source.jpg', '81000000-0000-0000-0000-000000000002', '{}'::jsonb),
  ('profile-media', '81000000-0000-0000-0000-000000000002/profile-visual/wide/private-display.webp', '81000000-0000-0000-0000-000000000002', '{}'::jsonb);

-- Public-profile owner: full profile/media metadata and both object classes.
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select pg_temp.assert_true((select count(*) = 1 from public.profiles where user_id = '81000000-0000-0000-0000-000000000001'), 'owner must read own public profile');
select pg_temp.assert_true((select count(*) = 1 from public.profile_photos where source_path like '%public-source.jpg'), 'owner editing must retain original metadata');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/public-source.jpg'), 'owner must read original avatar object');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/public-display.webp'), 'owner must read display avatar object');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name like '%/wide/public-source.jpg'), 'owner must read original visual object');
reset role;

-- Authenticated non-owner: safe public RPC and display objects only.
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000003', true);
set local role authenticated;
select pg_temp.assert_true(public.get_profile_for_viewer('81000000-0000-0000-0000-000000000001') is not null, 'viewer must read public profile through safe RPC');
select pg_temp.assert_true(public.get_profile_for_viewer('81000000-0000-0000-0000-000000000001')::text not like '%source_path%', 'safe public profile must omit source_path');
select pg_temp.assert_true(public.get_profile_for_viewer('81000000-0000-0000-0000-000000000001')::text not like '%source_filename%', 'safe public profile must omit source filename metadata');
select pg_temp.assert_true((select count(*) = 0 from public.profiles where user_id = '81000000-0000-0000-0000-000000000001'), 'non-owner must not bypass safe profile boundary with direct table reads');
select pg_temp.assert_true((select count(*) = 0 from public.profile_visuals where user_id = '81000000-0000-0000-0000-000000000001'), 'non-owner must not read source-bearing visual table');
select pg_temp.assert_true((select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/public-source.jpg'), 'non-owner must not read public-profile avatar original');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/public-display.webp'), 'non-owner must read public-profile avatar display');
select pg_temp.assert_true((select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name like '%/wide/public-source.jpg'), 'non-owner must not read public-profile visual original');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name like '%/wide/public-display.webp'), 'non-owner must read public-profile visual display');
select pg_temp.assert_true(public.get_profile_for_viewer('81000000-0000-0000-0000-000000000002') is null, 'viewer must not read private profile');
select pg_temp.assert_true((select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/private-display.webp'), 'viewer must not read private-profile display');
reset role;

-- Anonymous viewers receive the same public display boundary and no private data.
select set_config('request.jwt.claim.sub', '', true);
set local role anon;
select pg_temp.assert_true(public.get_profile_for_viewer('81000000-0000-0000-0000-000000000001') is not null, 'anonymous viewer must read public profile');
select pg_temp.assert_true(public.get_profile_for_viewer('81000000-0000-0000-0000-000000000002') is null, 'anonymous viewer must not read private profile');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/public-display.webp'), 'anonymous viewer must read public display');
select pg_temp.assert_true((select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/public-source.jpg'), 'anonymous viewer must not read public original');
select pg_temp.assert_true((select count(*) = 0 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/private-display.webp'), 'anonymous viewer must not read private display');
reset role;

-- Private owner retains full access and can change visibility both directions.
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000002', true);
set local role authenticated;
select pg_temp.assert_true((select count(*) = 1 from public.profiles where user_id = '81000000-0000-0000-0000-000000000002'), 'private owner must read own profile');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/private-source.jpg'), 'private owner must read own original');
select pg_temp.assert_true((select count(*) = 1 from storage.objects where bucket_id = 'profile-media' and name like '%/avatar/private-display.webp'), 'private owner must read own display');
select public.save_my_profile(
  '{"display_name":"Private Owner","handle":"@privateowner","featured_fan_photo_category":"Fan Cave","visibility":"public"}'::jsonb,
  '{}'::jsonb,
  '[]'::jsonb
);
select pg_temp.assert_true((select visibility = 'public' from public.profiles where user_id = '81000000-0000-0000-0000-000000000002'), 'Private to Public must persist');
select public.save_my_profile(
  '{"display_name":"Private Owner","handle":"@privateowner","featured_fan_photo_category":"Fan Cave","visibility":"private"}'::jsonb,
  '{}'::jsonb,
  '[]'::jsonb
);
select pg_temp.assert_true((select visibility = 'private' from public.profiles where user_id = '81000000-0000-0000-0000-000000000002'), 'Public to Private must persist');
reset role;

-- Existing library records and active projections remain intact.
select pg_temp.assert_true((select count(*) = 2 from public.profile_photos where user_id in ('81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002')), 'profile photo fixture records must remain intact');
select pg_temp.assert_true((select count(*) = 2 from public.profile_visual_images where user_id in ('81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002')), 'profile visual library fixture records must remain intact');
select pg_temp.assert_true((select count(*) = 2 from public.profile_visuals where user_id in ('81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002')), 'active profile visual fixture records must remain intact');

rollback;
