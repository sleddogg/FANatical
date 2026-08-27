-- Transactional proof for ambiguity-safe canonical Team resolution.
-- Every fixture is rolled back at the end of the test.

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
    raise exception 'Team resolution assertion failed: %', message_value;
  end if;
end;
$$;

do $$
declare
  sport_uuid uuid;
  first_team_uuid uuid;
  second_team_uuid uuid;
  result jsonb;
  strict_ambiguity_rejected boolean := false;
begin
  select id into strict sport_uuid
  from public.catalog_sports
  where sport_id = 'hockey';

  insert into public.catalog_teams(team_id, sport_id)
  values ('hockey-989901', sport_uuid)
  returning id into first_team_uuid;

  insert into public.catalog_teams(team_id, sport_id)
  values ('hockey-989902', sport_uuid)
  returning id into second_team_uuid;

  insert into public.team_identity_versions(
    team_id, display_name, short_name, record_status
  ) values
    (first_team_uuid, 'Resolver Fixture One', 'Fixture One',
      'imported_unverified'),
    (second_team_uuid, 'Resolver Fixture Two', 'Fixture Two',
      'imported_unverified');

  -- An external identifier that happens to equal another Team's canonical
  -- public ID must never make that canonical ID ambiguous.
  insert into public.catalog_team_identifiers(
    team_id, namespace, identifier
  ) values (
    second_team_uuid, 'resolver-canonical-collision', 'hockey-989901'
  );

  result := public.resolve_catalog_team('hockey-989901');
  perform pg_temp.assert_true(
    result ->> 'status' = 'resolved'
      and jsonb_array_length(result -> 'matches') = 1
      and (result #>> '{matches,0,id}')::uuid = first_team_uuid
      and result #>> '{matches,0,match_basis}' = 'team_id'
      and public.resolve_catalog_team_id('hockey-989901') = first_team_uuid,
    'an exact canonical Team public ID must resolve deterministically'
  );

  insert into public.catalog_team_identifiers(
    team_id, namespace, identifier
  ) values (
    first_team_uuid, 'resolver-unique', 'resolver-unique-external'
  );

  result := public.resolve_catalog_team('resolver-unique-external');
  perform pg_temp.assert_true(
    result ->> 'status' = 'resolved'
      and jsonb_array_length(result -> 'matches') = 1
      and (result #>> '{matches,0,id}')::uuid = first_team_uuid
      and result #>> '{matches,0,match_basis}' = 'external_identifier'
      and public.resolve_catalog_team_id(
        'resolver-unique-external'
      ) = first_team_uuid,
    'one unambiguous external Team identifier must resolve normally'
  );

  insert into public.catalog_team_identifiers(
    team_id, namespace, identifier
  ) values
    (first_team_uuid, 'resolver-shared-a', 'resolver-shared-external'),
    (second_team_uuid, 'resolver-shared-b', 'resolver-shared-external');

  result := public.resolve_catalog_team('resolver-shared-external');
  perform pg_temp.assert_true(
    result ->> 'status' = 'ambiguous'
      and jsonb_array_length(result -> 'matches') = 2
      and (
        select array_agg(candidate ->> 'team_id' order by candidate ->> 'team_id')
        from jsonb_array_elements(result -> 'matches') candidate
      ) = array['hockey-989901', 'hockey-989902'],
    'one bare external identifier in two namespaces must report ambiguity'
  );

  begin
    perform public.resolve_catalog_team_id('resolver-shared-external');
  exception when others then
    if sqlerrm =
      'Ambiguous Team identifier: resolver-shared-external' then
      strict_ambiguity_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    strict_ambiguity_rejected,
    'the strict Team resolver must raise instead of choosing a candidate'
  );

  perform pg_temp.assert_true(
    public.resolve_catalog_team_id('hockey-000027') = (
      select id from public.catalog_teams where team_id = 'hockey-000027'
    )
      and public.resolve_catalog_team_id(
        'hockey-nhl-edmonton-oilers'
      ) = (
        select id from public.catalog_teams where team_id = 'hockey-000027'
      )
      and public.get_team_record(
        'hockey-nhl-edmonton-oilers'
      ) ->> 'team_id' = 'hockey-000027',
    'existing canonical, legacy-identifier, and Team-read behavior must remain intact'
  );
end;
$$;

rollback;
