-- Permanent regression proof for FAN-AGT-11 / BL-015.
-- Every application-owned SECURITY DEFINER must pin the approved empty
-- search_path and must not retain EXECUTE for PostgreSQL PUBLIC.

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
    raise exception 'SECURITY DEFINER hygiene assertion failed: %', message_value;
  end if;
end;
$$;

select pg_temp.assert_true(
  not exists (
    select 1
    from pg_catalog.pg_proc function_record
    join pg_catalog.pg_namespace namespace_record
      on namespace_record.oid = function_record.pronamespace
    where function_record.prosecdef
      and namespace_record.nspname in ('public', 'private')
      and not coalesce(
        function_record.proconfig @> array['search_path=""']::text[],
        false
      )
  ),
  'every public/private SECURITY DEFINER must use the approved empty search_path'
);

select pg_temp.assert_true(
  not exists (
    select 1
    from pg_catalog.pg_proc function_record
    join pg_catalog.pg_namespace namespace_record
      on namespace_record.oid = function_record.pronamespace
    where function_record.prosecdef
      and namespace_record.nspname in ('public', 'private')
      and has_function_privilege('public', function_record.oid, 'execute')
  ),
  'PostgreSQL PUBLIC must not execute any public/private SECURITY DEFINER'
);

rollback;
