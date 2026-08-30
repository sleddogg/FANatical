-- BL-027 regression proof. The migration assertion also runs while rebuilding
-- the schema; this test keeps the guard visible in the normal SQL suite.

begin;

select private.assert_news_domain_mutation_registry();

do $$
declare
  registered_count integer;
  expected_count integer;
  governed_count integer;
  read_only_count integer;
begin
  select
    count(*),
    count(*) filter (where mutation_mode = 'governed'),
    count(*) filter (where mutation_mode = 'read_only')
  into registered_count, governed_count, read_only_count
  from private.news_domain_mutation_registry();

  select count(*)
  into expected_count
  from pg_catalog.pg_class relation
  join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
  where namespace.nspname = 'public'
    and relation.relkind in ('r', 'p')
    and (
      relation.relname like 'news\_%' escape '\'
      or relation.relname like 'podcast\_%' escape '\'
      or relation.relname like 'user\_news\_%' escape '\'
      or relation.relname in (
        'catalog_people', 'person_identity_versions',
        'person_alias_versions', 'person_identifiers'
      )
    );

  if registered_count <> expected_count then
    raise exception 'BL-027 registry expected % current News-domain tables, found %',
      expected_count, registered_count;
  end if;
  if governed_count = 0 or read_only_count = 0 then
    raise exception 'BL-027 registry must prove both governed and explicitly read-only table classes';
  end if;
end;
$$;

rollback;
