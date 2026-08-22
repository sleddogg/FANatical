-- Read-only hosted verification for the FANatical profile privacy boundary.
select jsonb_build_object(
  'visibility_column', (
    select jsonb_build_object(
      'data_type', column_name_info.data_type,
      'default', column_name_info.column_default,
      'nullable', column_name_info.is_nullable
    )
    from information_schema.columns column_name_info
    where column_name_info.table_schema = 'public'
      and column_name_info.table_name = 'profiles'
      and column_name_info.column_name = 'visibility'
  ),
  'legacy_is_public_exists', exists (
    select 1 from information_schema.columns column_name_info
    where column_name_info.table_schema = 'public'
      and column_name_info.table_name = 'profiles'
      and column_name_info.column_name = 'is_public'
  ),
  'visibility_values', (
    select jsonb_object_agg(profile.visibility, profile.count_value)
    from (
      select visibility, count(*) as count_value
      from public.profiles
      group by visibility
    ) profile
  ),
  'profile_media_bucket_private', (
    select not bucket.public from storage.buckets bucket where bucket.id = 'profile-media'
  ),
  'existing_record_counts', jsonb_build_object(
    'profiles', (select count(*) from public.profiles),
    'profile_photos', (select count(*) from public.profile_photos),
    'profile_visual_images', (select count(*) from public.profile_visual_images),
    'profile_visuals', (select count(*) from public.profile_visuals)
  ),
  'fixture_residue', jsonb_build_object(
    'auth_users', (select count(*) from auth.users where id::text like '81000000-0000-0000-0000-%'),
    'storage_objects', (select count(*) from storage.objects where name like '81000000-0000-0000-0000-%')
  ),
  'path_integrity', jsonb_build_object(
    'profile_photos_distinct', not exists (
      select 1 from public.profile_photos where source_path = display_path
    ),
    'profile_visual_images_distinct', not exists (
      select 1 from public.profile_visual_images where source_path = display_path
    ),
    'profile_visuals_distinct', not exists (
      select 1 from public.profile_visuals where source_path = display_path
    )
  ),
  'expected_functions', (
    select jsonb_agg(jsonb_build_object(
      'schema', namespace.nspname,
      'name', procedure.proname,
      'security_definer', procedure.prosecdef,
      'configuration', procedure.proconfig
    ) order by namespace.nspname, procedure.proname)
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where (namespace.nspname, procedure.proname) in (
      ('private', 'can_view_profile'),
      ('private', 'profile_media_path_is_visible'),
      ('public', 'get_profile_for_viewer'),
      ('public', 'save_my_profile')
    )
  ),
  'relevant_policies', (
    select jsonb_agg(jsonb_build_object(
      'schema', policy.schemaname,
      'table', policy.tablename,
      'name', policy.policyname,
      'roles', policy.roles,
      'command', policy.cmd,
      'using', policy.qual
    ) order by policy.schemaname, policy.tablename, policy.policyname)
    from pg_catalog.pg_policies policy
    where (policy.schemaname = 'public' and policy.tablename in (
      'profiles', 'fan_identities', 'sports_played', 'user_followed_teams',
      'profile_photos', 'profile_visuals', 'profile_visual_images'
    )) or (policy.schemaname = 'storage' and policy.tablename = 'objects'
      and policy.policyname = 'Owners and permitted viewers read profile media')
  )
) as profile_privacy_verification;
