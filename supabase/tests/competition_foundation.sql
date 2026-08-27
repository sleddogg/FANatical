-- Transactional coverage for the additive canonical Competition foundation.
-- All representative Competitions, Editions, relationships, and participation
-- rows below are fixtures and are rolled back at the end of the test.

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
    raise exception 'Competition foundation assertion failed: %', message_value;
  end if;
end;
$$;

create or replace function pg_temp.create_competition(
  competition_public_id text,
  sport_public_id text,
  kind_public_id text,
  competition_display_name text,
  competition_short_name text default null
)
returns uuid
language plpgsql
as $$
declare
  sport_uuid uuid;
  kind_uuid uuid;
  competition_uuid uuid;
begin
  select id into strict sport_uuid
  from public.catalog_sports where sport_id = sport_public_id;

  select id into strict kind_uuid
  from public.competition_kinds where kind_id = kind_public_id;

  insert into public.catalog_competitions(competition_id, sport_id, kind_id)
  values (competition_public_id, sport_uuid, kind_uuid)
  returning id into competition_uuid;

  insert into public.competition_identity_versions(
    competition_id, display_name, short_name, record_status
  ) values (
    competition_uuid, competition_display_name, competition_short_name,
    'imported_unverified'
  );

  return competition_uuid;
end;
$$;

create or replace function pg_temp.create_competition_edition(
  competition_public_id text,
  edition_public_id text,
  edition_display_name text,
  edition_season_label text
)
returns uuid
language plpgsql
as $$
declare
  competition_uuid uuid;
  edition_uuid uuid;
begin
  select id into strict competition_uuid
  from public.catalog_competitions
  where competition_id = competition_public_id;

  insert into public.catalog_competition_editions(
    edition_id, competition_id
  ) values (
    edition_public_id, competition_uuid
  ) returning id into edition_uuid;

  insert into public.competition_edition_versions(
    competition_edition_id, display_name, season_label, record_status
  ) values (
    edition_uuid, edition_display_name, edition_season_label,
    'imported_unverified'
  );

  return edition_uuid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Additive compatibility and unchanged Team/League behavior
-- ---------------------------------------------------------------------------

do $$
declare
  duplicate_primary_rejected boolean := false;
  future_league_uuid uuid;
  future_competition_uuid uuid;
  durable_mapping_rejected boolean := false;
  collision_rejected boolean := false;
begin
  perform pg_temp.assert_true((
    select count(*) = 2
      and bool_and(sport_id in ('golf', 'tennis'))
    from public.catalog_sports
    where sport_id in ('golf', 'tennis')
  ), 'Golf and Tennis must be canonical Sport identities');

  perform pg_temp.assert_true(not exists (
    select 1
    from (values
      ('league'), ('cup'), ('championship'), ('tournament'), ('tour'),
      ('series'), ('other')
    ) required(kind_id)
    left join public.competition_kinds kind
      on kind.kind_id = required.kind_id and kind.active
    where kind.id is null
  ), 'every required initial Competition kind must exist and be active');

  perform pg_temp.assert_true((
    select count(*) = (select count(*) from public.catalog_leagues)
    from public.catalog_league_competition_mappings
  ), 'every existing League must have exactly one compatibility mapping');

  perform pg_temp.assert_true(not exists (
    select 1
    from public.catalog_leagues league
    left join public.catalog_league_competition_mappings mapping
      on mapping.league_id = league.id
    left join public.catalog_competitions competition
      on competition.id = mapping.competition_id
    left join public.competition_kinds kind on kind.id = competition.kind_id
    where mapping.league_id is null
       or competition.competition_id <> league.league_id
       or competition.sport_id <> league.sport_id
       or kind.kind_id <> 'league'
  ), 'League mappings must preserve public ID, Sport, and League meaning');

  perform pg_temp.assert_true(not exists (
    select 1
    from public.catalog_leagues league
    join public.catalog_league_competition_mappings mapping
      on mapping.league_id = league.id
    left join public.competition_identity_versions identity_record
      on identity_record.competition_id = mapping.competition_id
     and identity_record.is_current
    where identity_record.id is null
       or identity_record.display_name <> league.display_name
  ), 'mapped League Competitions must retain current League names');

  perform pg_temp.assert_true(not exists (
    select 1
    from public.catalog_league_identifiers league_identifier
    join public.catalog_league_competition_mappings mapping
      on mapping.league_id = league_identifier.league_id
    left join public.catalog_competition_identifiers competition_identifier
      on competition_identifier.competition_id = mapping.competition_id
     and competition_identifier.namespace = league_identifier.namespace
     and competition_identifier.identifier = league_identifier.identifier
    where competition_identifier.id is null
  ), 'every legacy League identifier must have a Competition counterpart');

  insert into public.catalog_leagues(
    league_id, sport_id, display_name, short_name, seed_status
  )
  select 'hockey-phase1-future-league', sport.id,
         'Phase 1 Future League', 'P1FL', 'verified'
  from public.catalog_sports sport
  where sport.sport_id = 'hockey'
  returning id into future_league_uuid;

  select mapping.competition_id into strict future_competition_uuid
  from public.catalog_league_competition_mappings mapping
  where mapping.league_id = future_league_uuid;

  perform pg_temp.assert_true((
    select competition.competition_id = 'hockey-phase1-future-league'
      and competition.sport_id = league.sport_id
      and kind.kind_id = 'league'
      and identity_record.display_name = league.display_name
      and identity_record.record_status = 'imported_unverified'
      and identity_record.is_current
    from public.catalog_leagues league
    join public.catalog_league_competition_mappings mapping
      on mapping.league_id = league.id
    join public.catalog_competitions competition
      on competition.id = mapping.competition_id
    join public.competition_kinds kind on kind.id = competition.kind_id
    join public.competition_identity_versions identity_record
      on identity_record.competition_id = competition.id
     and identity_record.is_current
    where league.id = future_league_uuid
  ), 'a future League insert must atomically create its unverified league-kind Competition mapping');

  insert into public.catalog_league_identifiers(
    league_id, namespace, identifier
  ) values (
    future_league_uuid, 'phase1-test', 'future-league-provider-id'
  );

  perform pg_temp.assert_true(exists (
    select 1
    from public.catalog_competition_identifiers competition_identifier
    where competition_identifier.competition_id = future_competition_uuid
      and competition_identifier.namespace = 'phase1-test'
      and competition_identifier.identifier = 'future-league-provider-id'
      and competition_identifier.record_status = 'imported_unverified'
  ), 'a future League identifier must atomically receive its Competition counterpart');

  begin
    delete from public.catalog_league_competition_mappings
    where league_id = future_league_uuid;
  exception when others then
    if sqlerrm = 'League-to-Competition mappings are durable and cannot be deleted' then
      durable_mapping_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    durable_mapping_rejected,
    'a durable League-to-Competition mapping must not be removable'
  );

  perform pg_temp.create_competition(
    'hockey-phase1-league-collision', 'hockey', 'cup',
    'Phase 1 League Collision', null
  );
  begin
    insert into public.catalog_leagues(
      league_id, sport_id, display_name, seed_status
    )
    select 'hockey-phase1-league-collision', sport.id,
           'Phase 1 League Collision', 'imported_unverified'
    from public.catalog_sports sport
    where sport.sport_id = 'hockey';
  exception when unique_violation then
    collision_rejected := true;
  end;
  perform pg_temp.assert_true(
    collision_rejected and not exists (
      select 1 from public.catalog_leagues
      where league_id = 'hockey-phase1-league-collision'
    ),
    'League completion failure must roll back the League instead of leaving a half-created record'
  );

  perform pg_temp.assert_true((
    select count(*) = count(distinct team_id)
    from public.team_primary_league_versions
    where is_current
  ), 'team_primary_league must remain singular per Team');

  perform pg_temp.assert_true((
    select league.league_id = 'soccer-eng-premier-league'
    from public.catalog_teams team
    join public.team_primary_league_versions primary_league
      on primary_league.team_id = team.id and primary_league.is_current
    join public.catalog_leagues league on league.id = primary_league.league_id
    where team.team_id = 'soccer-000016'
  ), 'Manchester United primary League/app context must remain Premier League');

  begin
    insert into public.team_primary_league_versions(
      team_id, league_id, record_status
    )
    select team.id, league.id, 'imported_unverified'
    from public.catalog_teams team
    cross join public.catalog_leagues league
    where team.team_id = 'soccer-000016'
      and league.league_id = 'soccer-eng-championship';
  exception when unique_violation then
    duplicate_primary_rejected := true;
  end;
  perform pg_temp.assert_true(
    duplicate_primary_rejected,
    'a second current team_primary_league row must still be rejected'
  );

  perform pg_temp.assert_true(
    public.resolve_catalog_team_id('soccer-000016') = (
      select id from public.catalog_teams where team_id = 'soccer-000016'
    ),
    'existing Team public-ID resolution must remain intact'
  );
  perform pg_temp.assert_true((
    select display_name = 'Manchester United'
      and primary_league_id = 'soccer-eng-premier-league'
    from public.team_catalog_read_model
    where team_id = 'soccer-000016'
  ), 'the existing Team catalog read model must remain intact');
  perform pg_temp.assert_true(
    public.get_team_record('soccer-000016') #>>
      '{current_competition,league_id}' = 'soccer-eng-premier-league',
    'the existing nested Team record must retain primary-League semantics'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Soccer: tiers, cups, continental/national structures, aliases, participation
-- ---------------------------------------------------------------------------

do $$
declare
  manchester_uuid uuid;
  premier_edition_uuid uuid;
  championship_edition_uuid uuid;
  fa_cup_edition_uuid uuid;
  efl_cup_edition_uuid uuid;
  champions_league_edition_uuid uuid;
  ambiguous_resolution_rejected boolean := false;
  immutable_identity_rejected boolean := false;
  immutable_sport_rejected boolean := false;
  immutable_kind_rejected boolean := false;
  edition_non_identity_update_count integer := 0;
  immutable_edition_uuid_rejected boolean := false;
  immutable_edition_id_rejected boolean := false;
  immutable_same_sport_parent_rejected boolean := false;
  immutable_cross_sport_parent_rejected boolean := false;
begin
  perform pg_temp.create_competition(
    'soccer-eng-league-one', 'soccer', 'league', 'EFL League One', null
  );
  perform pg_temp.create_competition(
    'soccer-fa-cup', 'soccer', 'cup', 'FA Cup', null
  );
  perform pg_temp.create_competition(
    'soccer-efl-cup', 'soccer', 'cup', 'EFL Cup', null
  );
  perform pg_temp.create_competition(
    'soccer-uefa-champions-league', 'soccer', 'championship',
    'UEFA Champions League', 'Champions League'
  );
  perform pg_temp.create_competition(
    'soccer-uefa-european-championship', 'soccer', 'championship',
    'UEFA European Championship', 'UEFA Euro'
  );

  premier_edition_uuid := pg_temp.create_competition_edition(
    'soccer-eng-premier-league', 'soccer-eng-premier-league-test-2026-27',
    '2026-27 Premier League', '2026-27'
  );
  championship_edition_uuid := pg_temp.create_competition_edition(
    'soccer-eng-championship', 'soccer-eng-championship-test-2027-28',
    '2027-28 EFL Championship', '2027-28'
  );
  perform pg_temp.create_competition_edition(
    'soccer-eng-league-one', 'soccer-eng-league-one-test-2026-27',
    '2026-27 EFL League One', '2026-27'
  );
  fa_cup_edition_uuid := pg_temp.create_competition_edition(
    'soccer-fa-cup', 'soccer-fa-cup-test-2026-27',
    '2026-27 FA Cup', '2026-27'
  );
  efl_cup_edition_uuid := pg_temp.create_competition_edition(
    'soccer-efl-cup', 'soccer-efl-cup-test-2026-27',
    '2026-27 EFL Cup', '2026-27'
  );
  champions_league_edition_uuid := pg_temp.create_competition_edition(
    'soccer-uefa-champions-league',
    'soccer-uefa-champions-league-test-2026-27',
    '2026-27 UEFA Champions League', '2026-27'
  );
  perform pg_temp.create_competition_edition(
    'soccer-uefa-european-championship',
    'soccer-uefa-european-championship-test-2028',
    'UEFA Euro 2028', '2028'
  );

  select id into strict manchester_uuid
  from public.catalog_teams where team_id = 'soccer-000016';

  insert into public.team_competition_edition_participation_versions(
    team_id, competition_edition_id, record_status
  ) values
    (manchester_uuid, premier_edition_uuid, 'imported_unverified'),
    (manchester_uuid, fa_cup_edition_uuid, 'imported_unverified'),
    (manchester_uuid, efl_cup_edition_uuid, 'imported_unverified'),
    (manchester_uuid, champions_league_edition_uuid, 'imported_unverified');

  perform pg_temp.assert_true((
    select count(*) = 4 and count(distinct participation.team_id) = 1
    from public.team_competition_edition_participation_versions participation
    join public.catalog_competition_editions edition
      on edition.id = participation.competition_edition_id
    join public.catalog_competitions competition
      on competition.id = edition.competition_id
    where participation.team_id = manchester_uuid
      and competition.competition_id in (
        'soccer-eng-premier-league', 'soccer-fa-cup', 'soccer-efl-cup',
        'soccer-uefa-champions-league'
      )
      and participation.is_current and participation.participating
  ), 'one Manchester United identity must participate in four simultaneous Editions');

  -- A later second-tier Edition records changed participation without changing
  -- the Team identity or its existing primary-League compatibility record.
  insert into public.team_competition_edition_participation_versions(
    team_id, competition_edition_id, effective_from,
    effective_from_precision, record_status
  ) values (
    manchester_uuid, championship_edition_uuid, date '2027-08-01',
    'day', 'imported_unverified'
  );

  perform pg_temp.assert_true((
    select count(distinct participation.team_id) = 1
      and bool_and(participation.team_id = manchester_uuid)
    from public.team_competition_edition_participation_versions participation
    join public.catalog_competition_editions edition
      on edition.id = participation.competition_edition_id
    join public.catalog_competitions competition
      on competition.id = edition.competition_id
    where competition.competition_id in (
      'soccer-eng-premier-league', 'soccer-eng-championship'
    ) and participation.team_id = manchester_uuid
  ), 'promotion or relegation must retain one canonical Team identity');

  perform pg_temp.assert_true((
    select count(distinct team.id) = 1
    from public.catalog_teams team
    join public.team_competition_edition_participation_versions participation
      on participation.team_id = team.id
    join public.catalog_competition_editions edition
      on edition.id = participation.competition_edition_id
    join public.catalog_competitions competition
      on competition.id = edition.competition_id
    where team.team_id = 'soccer-000016'
      and competition.competition_id in (
        'soccer-eng-premier-league', 'soccer-uefa-champions-league'
      )
  ), 'domestic and European navigation paths must converge on Manchester United');

  insert into public.competition_alias_versions(
    competition_id, alias, alias_type, record_status
  )
  select competition.id, fixture.alias, fixture.alias_type,
         'imported_unverified'
  from (values
    ('EFL Cup', 'common_name'),
    ('League Cup', 'former_name'),
    ('Carabao Cup', 'sponsored_name')
  ) fixture(alias, alias_type)
  cross join public.catalog_competitions competition
  where competition.competition_id = 'soccer-efl-cup';

  insert into public.catalog_competition_identifiers(
    competition_id, namespace, identifier
  )
  select id, 'phase1-test', 'efl-cup-external'
  from public.catalog_competitions
  where competition_id = 'soccer-efl-cup';

  perform pg_temp.assert_true((
    select bool_and(
      public.resolve_catalog_competition(alias_value, 'soccer') ->> 'status'
        = 'resolved'
      and public.resolve_catalog_competition_id(alias_value, 'soccer') =
        (select id from public.catalog_competitions
         where competition_id = 'soccer-efl-cup')
    )
    from unnest(array['EFL Cup','League Cup','Carabao Cup']) alias_value
  ), 'canonical, former, and sponsored EFL Cup names must resolve together');

  perform pg_temp.assert_true(
    public.resolve_catalog_competition_id(
      'efl-cup-external', 'soccer'
    ) = (
      select id from public.catalog_competitions
      where competition_id = 'soccer-efl-cup'
    ) and public.resolve_catalog_competition(
      'efl-cup-external', 'soccer'
    ) #>> '{matches,0,match_basis}' = 'external_identifier',
    'namespaced external Competition identifiers must resolve'
  );

  insert into public.competition_alias_versions(
    competition_id, alias, alias_type, record_status
  )
  select id, 'National Championship', 'common_name', 'imported_unverified'
  from public.catalog_competitions
  where competition_id in (
    'soccer-uefa-champions-league',
    'soccer-uefa-european-championship'
  );

  perform pg_temp.assert_true(
    public.resolve_catalog_competition(
      'National Championship', 'soccer'
    ) ->> 'status' = 'ambiguous',
    'a genuinely ambiguous alias must be reported as ambiguous'
  );

  begin
    perform public.resolve_catalog_competition_id(
      'National Championship', 'soccer'
    );
  exception when others then
    if sqlerrm like 'Ambiguous Competition identifier:%' then
      ambiguous_resolution_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    ambiguous_resolution_rejected,
    'the convenience resolver must reject rather than guess an ambiguous alias'
  );

  begin
    update public.catalog_competitions
    set competition_id = 'soccer-efl-cup-rewritten'
    where competition_id = 'soccer-efl-cup';
  exception when others then
    if sqlerrm = 'Catalog Competition identity, Sport, and kind are immutable' then
      immutable_identity_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    immutable_identity_rejected,
    'canonical Competition public identities must be immutable'
  );

  begin
    update public.catalog_competitions
    set sport_id = (
      select id from public.catalog_sports where sport_id = 'hockey'
    )
    where competition_id = 'soccer-efl-cup';
  exception when others then
    if sqlerrm = 'Catalog Competition identity, Sport, and kind are immutable' then
      immutable_sport_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    immutable_sport_rejected,
    'a canonical Competition Sport must be immutable'
  );

  begin
    update public.catalog_competitions
    set kind_id = (
      select id from public.competition_kinds where kind_id = 'league'
    )
    where competition_id = 'soccer-efl-cup';
  exception when others then
    if sqlerrm = 'Catalog Competition identity, Sport, and kind are immutable' then
      immutable_kind_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    immutable_kind_rejected,
    'a canonical Competition kind must be immutable'
  );

  update public.catalog_competition_editions
  set updated_at = clock_timestamp()
  where id = efl_cup_edition_uuid;
  get diagnostics edition_non_identity_update_count = row_count;
  perform pg_temp.assert_true(
    edition_non_identity_update_count = 1 and (
      select edition.edition_id = 'soccer-efl-cup-test-2026-27'
        and competition.competition_id = 'soccer-efl-cup'
      from public.catalog_competition_editions edition
      join public.catalog_competitions competition
        on competition.id = edition.competition_id
      where edition.id = efl_cup_edition_uuid
    ),
    'non-identity Competition Edition bookkeeping updates must remain allowed'
  );

  begin
    update public.catalog_competition_editions
    set id = gen_random_uuid()
    where id = efl_cup_edition_uuid;
  exception when others then
    if sqlerrm = 'Catalog Competition Edition identity and parent Competition are immutable' then
      immutable_edition_uuid_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    immutable_edition_uuid_rejected,
    'a Competition Edition internal UUID must be immutable'
  );

  begin
    update public.catalog_competition_editions
    set edition_id = 'soccer-efl-cup-test-2026-27-rewritten'
    where id = efl_cup_edition_uuid;
  exception when others then
    if sqlerrm = 'Catalog Competition Edition identity and parent Competition are immutable' then
      immutable_edition_id_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    immutable_edition_id_rejected,
    'a Competition Edition permanent public ID must be immutable'
  );

  begin
    update public.catalog_competition_editions
    set competition_id = (
      select id from public.catalog_competitions
      where competition_id = 'soccer-fa-cup'
    )
    where id = efl_cup_edition_uuid;
  exception when others then
    if sqlerrm = 'Catalog Competition Edition identity and parent Competition are immutable' then
      immutable_same_sport_parent_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    immutable_same_sport_parent_rejected,
    'a Competition Edition must not move to another same-Sport Competition'
  );

  begin
    update public.catalog_competition_editions
    set competition_id = (
      select id from public.catalog_competitions
      where competition_id = 'hockey-nhl'
    )
    where id = efl_cup_edition_uuid;
  exception when others then
    if sqlerrm = 'Catalog Competition Edition identity and parent Competition are immutable' then
      immutable_cross_sport_parent_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    immutable_cross_sport_parent_rejected and (
      select competition.competition_id = 'soccer-efl-cup'
      from public.catalog_competition_editions edition
      join public.catalog_competitions competition
        on competition.id = edition.competition_id
      where edition.id = efl_cup_edition_uuid
    ),
    'a Competition Edition must not move cross-Sport and must retain its parent'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Hockey: pro, junior, international, distinct national-Team identities
-- ---------------------------------------------------------------------------

do $$
declare
  senior_team_uuid uuid;
  under_20_team_uuid uuid;
  oilers_team_uuid uuid;
  oil_kings_team_uuid uuid;
  nhl_edition_uuid uuid;
  whl_edition_uuid uuid;
  world_championship_edition_uuid uuid;
  world_juniors_edition_uuid uuid;
begin
  perform pg_temp.assert_true((
    select count(*) = 6 and bool_and(kind.kind_id = 'league')
    from public.catalog_competitions competition
    join public.competition_kinds kind on kind.id = competition.kind_id
    where competition.competition_id in (
      'hockey-nhl', 'hockey-ahl', 'hockey-echl',
      'hockey-whl', 'hockey-ohl', 'hockey-qmjhl'
    )
  ), 'NHL/AHL/ECHL and WHL/OHL/QMJHL must map as League Competitions');

  perform pg_temp.create_competition(
    'hockey-world-championship', 'hockey', 'championship',
    'IIHF World Championship', 'World Championship'
  );
  perform pg_temp.create_competition(
    'hockey-world-juniors', 'hockey', 'championship',
    'IIHF World Junior Championship', 'World Juniors'
  );
  perform pg_temp.create_competition(
    'hockey-womens-world-championship', 'hockey', 'championship',
    'IIHF Women''s World Championship', 'Women''s World Championship'
  );
  perform pg_temp.create_competition(
    'hockey-olympic-hockey', 'hockey', 'tournament',
    'Olympic Hockey', null
  );

  nhl_edition_uuid := pg_temp.create_competition_edition(
    'hockey-nhl', 'hockey-nhl-test-2026-27',
    '2026-27 NHL', '2026-27'
  );
  whl_edition_uuid := pg_temp.create_competition_edition(
    'hockey-whl', 'hockey-whl-test-2026-27',
    '2026-27 WHL', '2026-27'
  );
  world_championship_edition_uuid := pg_temp.create_competition_edition(
    'hockey-world-championship', 'hockey-world-championship-test-2027',
    '2027 IIHF World Championship', '2027'
  );
  world_juniors_edition_uuid := pg_temp.create_competition_edition(
    'hockey-world-juniors', 'hockey-world-juniors-test-2027',
    '2027 IIHF World Junior Championship', '2027'
  );
  perform pg_temp.create_competition_edition(
    'hockey-womens-world-championship',
    'hockey-womens-world-championship-test-2027',
    '2027 IIHF Women''s World Championship', '2027'
  );
  perform pg_temp.create_competition_edition(
    'hockey-olympic-hockey', 'hockey-olympic-hockey-test-2030',
    '2030 Olympic Hockey', '2030'
  );

  select id into strict oilers_team_uuid
  from public.catalog_teams where team_id = 'hockey-000027';
  select id into strict oil_kings_team_uuid
  from public.catalog_teams where team_id = 'hockey-000274';

  insert into public.team_competition_edition_participation_versions(
    team_id, competition_edition_id, record_status
  ) values
    (oilers_team_uuid, nhl_edition_uuid, 'imported_unverified'),
    (oil_kings_team_uuid, whl_edition_uuid, 'imported_unverified');

  perform pg_temp.assert_true((
    select count(*) = 2 and bool_and(
      (team.team_id = 'hockey-000027'
        and competition.competition_id = 'hockey-nhl')
      or (team.team_id = 'hockey-000274'
        and competition.competition_id = 'hockey-whl')
    )
    from public.team_competition_edition_participation_versions participation
    join public.catalog_teams team on team.id = participation.team_id
    join public.catalog_competition_editions edition
      on edition.id = participation.competition_edition_id
    join public.catalog_competitions competition
      on competition.id = edition.competition_id
    where team.team_id in ('hockey-000027', 'hockey-000274')
  ), 'Edmonton Oilers and Edmonton Oil Kings must remain distinct NHL/WHL Teams');

  insert into public.catalog_teams(team_id, sport_id)
  select fixture.team_id, sport.id
  from (values ('hockey-990001'), ('hockey-990002')) fixture(team_id)
  cross join public.catalog_sports sport
  where sport.sport_id = 'hockey';

  insert into public.team_identity_versions(
    team_id, display_name, short_name, active, record_status
  )
  select team.id, fixture.display_name, fixture.short_name, true,
         'imported_unverified'
  from (values
    ('hockey-990001', 'Canada Senior Men', 'Canada Men'),
    ('hockey-990002', 'Canada Men''s U20', 'Canada U20')
  ) fixture(team_id, display_name, short_name)
  join public.catalog_teams team on team.team_id = fixture.team_id;

  select id into strict senior_team_uuid
  from public.catalog_teams where team_id = 'hockey-990001';
  select id into strict under_20_team_uuid
  from public.catalog_teams where team_id = 'hockey-990002';

  insert into public.team_competition_edition_participation_versions(
    team_id, competition_edition_id, record_status
  ) values
    (senior_team_uuid, world_championship_edition_uuid,
      'imported_unverified'),
    (under_20_team_uuid, world_juniors_edition_uuid,
      'imported_unverified');

  perform pg_temp.assert_true((
    select count(distinct team.id) = 2
      and count(distinct competition.id) = 2
      and bool_and(
        (team.team_id = 'hockey-990001'
          and competition.competition_id = 'hockey-world-championship')
        or (team.team_id = 'hockey-990002'
          and competition.competition_id = 'hockey-world-juniors')
      )
    from public.team_competition_edition_participation_versions participation
    join public.catalog_teams team on team.id = participation.team_id
    join public.catalog_competition_editions edition
      on edition.id = participation.competition_edition_id
    join public.catalog_competitions competition
      on competition.id = edition.competition_id
    where team.team_id in ('hockey-990001', 'hockey-990002')
  ), 'Canada Senior Men and Canada Men U20 must be distinct canonical Teams');

  perform pg_temp.assert_true((
    select count(*) = 4
    from public.competition_edition_catalog_read_model
    where competition_id in (
      'hockey-world-championship', 'hockey-world-juniors',
      'hockey-womens-world-championship', 'hockey-olympic-hockey'
    )
  ), 'all four representative international Hockey structures need Editions');
end;
$$;

-- ---------------------------------------------------------------------------
-- Golf and Tennis: Tour/Tournament graphs, including a joint ATP/WTA Edition
-- ---------------------------------------------------------------------------

do $$
declare
  pga_tour_uuid uuid;
  golf_tournament_uuid uuid;
  pga_tour_edition_uuid uuid;
  golf_tournament_edition_uuid uuid;
  atp_tour_uuid uuid;
  wta_tour_uuid uuid;
  wimbledon_uuid uuid;
  joint_tournament_uuid uuid;
  atp_edition_uuid uuid;
  wta_edition_uuid uuid;
  wimbledon_edition_uuid uuid;
  joint_edition_uuid uuid;
  cross_sport_relationship_rejected boolean := false;
  cross_sport_edition_relationship_rejected boolean := false;
begin
  pga_tour_uuid := pg_temp.create_competition(
    'golf-pga-tour', 'golf', 'tour', 'PGA Tour', null
  );
  golf_tournament_uuid := pg_temp.create_competition(
    'golf-foundation-open', 'golf', 'tournament',
    'Foundation Open', null
  );
  pga_tour_edition_uuid := pg_temp.create_competition_edition(
    'golf-pga-tour', 'golf-pga-tour-test-2027', '2027 PGA Tour', '2027'
  );
  golf_tournament_edition_uuid := pg_temp.create_competition_edition(
    'golf-foundation-open', 'golf-foundation-open-test-2027',
    '2027 Foundation Open', '2027'
  );

  insert into public.competition_relationship_versions(
    source_competition_id, target_competition_id,
    relationship_type, record_status
  ) values (
    golf_tournament_uuid, pga_tour_uuid,
    'tour-event', 'imported_unverified'
  );
  insert into public.competition_edition_relationship_versions(
    source_competition_edition_id, target_competition_edition_id,
    relationship_type, record_status
  ) values (
    golf_tournament_edition_uuid, pga_tour_edition_uuid,
    'tour-event', 'imported_unverified'
  );

  perform pg_temp.assert_true((
    select count(*) = 1
    from public.competition_relationship_versions relationship
    where relationship.source_competition_id = golf_tournament_uuid
      and relationship.target_competition_id = pga_tour_uuid
      and relationship.relationship_type = 'tour-event'
      and relationship.is_current
  ), 'a Golf Tournament must relate to its Tour without becoming a League');

  atp_tour_uuid := pg_temp.create_competition(
    'tennis-atp-tour', 'tennis', 'tour', 'ATP Tour', 'ATP'
  );
  wta_tour_uuid := pg_temp.create_competition(
    'tennis-wta-tour', 'tennis', 'tour', 'WTA Tour', 'WTA'
  );
  wimbledon_uuid := pg_temp.create_competition(
    'tennis-wimbledon', 'tennis', 'tournament', 'Wimbledon', null
  );
  joint_tournament_uuid := pg_temp.create_competition(
    'tennis-joint-open', 'tennis', 'tournament', 'Joint Open', null
  );

  atp_edition_uuid := pg_temp.create_competition_edition(
    'tennis-atp-tour', 'tennis-atp-tour-test-2027',
    '2027 ATP Tour', '2027'
  );
  wta_edition_uuid := pg_temp.create_competition_edition(
    'tennis-wta-tour', 'tennis-wta-tour-test-2027',
    '2027 WTA Tour', '2027'
  );
  wimbledon_edition_uuid := pg_temp.create_competition_edition(
    'tennis-wimbledon', 'tennis-wimbledon-test-2027',
    'Wimbledon 2027', '2027'
  );
  joint_edition_uuid := pg_temp.create_competition_edition(
    'tennis-joint-open', 'tennis-joint-open-test-2027',
    'Joint Open 2027', '2027'
  );

  insert into public.competition_relationship_versions(
    source_competition_id, target_competition_id,
    relationship_type, record_status
  ) values
    (wimbledon_uuid, atp_tour_uuid, 'tour-event', 'imported_unverified'),
    (joint_tournament_uuid, atp_tour_uuid, 'tour-event', 'imported_unverified'),
    (joint_tournament_uuid, wta_tour_uuid, 'tour-event', 'imported_unverified');

  insert into public.competition_edition_relationship_versions(
    source_competition_edition_id, target_competition_edition_id,
    relationship_type, record_status
  ) values
    (wimbledon_edition_uuid, atp_edition_uuid,
      'tour-event', 'imported_unverified'),
    (joint_edition_uuid, atp_edition_uuid,
      'tour-event', 'imported_unverified'),
    (joint_edition_uuid, wta_edition_uuid,
      'tour-event', 'imported_unverified');

  perform pg_temp.assert_true((
    select count(*) = 2 and count(distinct target_competition_id) = 2
    from public.competition_relationship_versions
    where source_competition_id = joint_tournament_uuid
      and relationship_type = 'tour-event' and is_current
  ), 'one joint Tennis Tournament must relate to both ATP and WTA Tours');

  perform pg_temp.assert_true((
    select count(*) = 2
      and count(distinct target_competition_edition_id) = 2
    from public.competition_edition_relationship_versions
    where source_competition_edition_id = joint_edition_uuid
      and relationship_type = 'tour-event' and is_current
  ), 'one Tournament Edition must relate to two Tour Editions');

  perform pg_temp.assert_true((
    select count(distinct source_competition_id) = 2
    from public.competition_relationship_versions
    where target_competition_id = atp_tour_uuid
      and relationship_type = 'tour-event' and is_current
  ), 'one Tour must relate to multiple canonical Tournaments');

  begin
    insert into public.competition_relationship_versions(
      source_competition_id, target_competition_id,
      relationship_type, record_status
    ) values (
      golf_tournament_uuid, atp_tour_uuid,
      'tour-event', 'imported_unverified'
    );
  exception when others then
    if sqlerrm = 'Competition relationship source and target must belong to the same Sport' then
      cross_sport_relationship_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    cross_sport_relationship_rejected,
    'a factual Competition relationship must reject different Sports'
  );

  begin
    insert into public.competition_edition_relationship_versions(
      source_competition_edition_id, target_competition_edition_id,
      relationship_type, record_status
    ) values (
      golf_tournament_edition_uuid, atp_edition_uuid,
      'tour-event', 'imported_unverified'
    );
  exception when others then
    if sqlerrm = 'Competition Edition relationship source and target must belong to the same Sport' then
      cross_sport_edition_relationship_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    cross_sport_edition_relationship_rejected,
    'a factual Competition Edition relationship must reject different Sports'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Presentation filter groups reference real Competitions only
-- ---------------------------------------------------------------------------

do $$
declare
  filter_group_uuid uuid;
  cross_sport_filter_group_uuid uuid;
  scope_transition_group_uuid uuid;
  historical_soccer_membership_uuid uuid;
  cross_sport_membership_rejected boolean := false;
  cross_sport_scope_assignment_rejected boolean := false;
  cross_sport_participation_rejected boolean := false;
begin
  insert into public.catalog_competition_filter_groups(
    filter_group_id, sport_id
  )
  select 'hockey-junior', id
  from public.catalog_sports where sport_id = 'hockey'
  returning id into filter_group_uuid;

  insert into public.competition_filter_group_versions(
    filter_group_id, display_name, description, record_status
  ) values (
    filter_group_uuid, 'Junior Hockey',
    'Presentation-only representative Phase 1 fixture.',
    'imported_unverified'
  );

  insert into public.competition_filter_group_membership_versions(
    filter_group_id, competition_id, sort_order, record_status
  )
  select filter_group_uuid, competition.id, fixture.sort_order,
         'imported_unverified'
  from (values
    ('hockey-whl', 10), ('hockey-ohl', 20), ('hockey-qmjhl', 30)
  ) fixture(competition_id, sort_order)
  join public.catalog_competitions competition
    on competition.competition_id = fixture.competition_id;

  perform pg_temp.assert_true((
    select sport.sport_id = 'hockey'
    from public.catalog_competition_filter_groups filter_group
    join public.catalog_sports sport on sport.id = filter_group.sport_id
    where filter_group.filter_group_id = 'hockey-junior'
  ), 'Junior Hockey must remain explicitly Hockey-scoped');

  perform pg_temp.assert_true((
    select count(*) = 3
      and bool_and(group_sport_id = 'hockey')
      and bool_and(competition_sport_id = 'hockey')
      and array_agg(competition_id order by sort_order) =
        array['hockey-whl','hockey-ohl','hockey-qmjhl']
    from public.competition_filter_group_read_model
    where filter_group_id = 'hockey-junior'
  ), 'Junior Hockey must present WHL/OHL/QMJHL through their real IDs');

  perform pg_temp.assert_true(not exists (
    select 1 from public.catalog_competitions
    where competition_id = 'hockey-junior'
  ), 'a presentation filter group must not become a factual Competition');

  begin
    insert into public.competition_filter_group_membership_versions(
      filter_group_id, competition_id, record_status
    )
    select filter_group_uuid, competition.id, 'imported_unverified'
    from public.catalog_competitions competition
    where competition.competition_id = 'soccer-fa-cup';
  exception when others then
    if sqlerrm = 'Filter group and Competition must belong to the same Sport' then
      cross_sport_membership_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    cross_sport_membership_rejected,
    'a Sport filter group must reject a Competition from another Sport'
  );

  insert into public.catalog_competition_filter_groups(filter_group_id)
  values ('multi-sport-sample')
  returning id into cross_sport_filter_group_uuid;

  insert into public.competition_filter_group_versions(
    filter_group_id, display_name, description, record_status
  ) values (
    cross_sport_filter_group_uuid, 'Multi-Sport Sample',
    'Presentation-only cross-Sport Phase 1 fixture.',
    'imported_unverified'
  );

  insert into public.competition_filter_group_membership_versions(
    filter_group_id, competition_id, sort_order, record_status
  )
  select cross_sport_filter_group_uuid, competition.id,
         fixture.sort_order, 'imported_unverified'
  from (values
    ('hockey-olympic-hockey', 10), ('soccer-fa-cup', 20)
  ) fixture(competition_id, sort_order)
  join public.catalog_competitions competition
    on competition.competition_id = fixture.competition_id;

  perform pg_temp.assert_true((
    select sport_id is null
    from public.catalog_competition_filter_groups
    where filter_group_id = 'multi-sport-sample'
  ), 'a cross-Sport presentation group must have no Sport scope');

  perform pg_temp.assert_true((
    select count(*) = 2 and bool_and(group_sport_id is null)
      and array_agg(competition_id order by sort_order) =
        array['hockey-olympic-hockey','soccer-fa-cup']
      and array_agg(competition_sport_id order by sort_order) =
        array['hockey','soccer']
    from public.competition_filter_group_read_model
    where filter_group_id = 'multi-sport-sample'
  ), 'the filter-group read model must expose both cross-Sport members');

  perform pg_temp.assert_true((
    select count(distinct competition.sport_id) = 2
    from public.competition_filter_group_membership_versions membership
    join public.catalog_competitions competition
      on competition.id = membership.competition_id
    where membership.filter_group_id = cross_sport_filter_group_uuid
      and membership.is_current
  ), 'an unscoped presentation group must accept two different Sports');

  begin
    update public.catalog_competition_filter_groups
    set sport_id = (
      select id from public.catalog_sports where sport_id = 'hockey'
    )
    where id = cross_sport_filter_group_uuid;
  exception when others then
    if sqlerrm = 'Filter group Sport scope conflicts with an existing Competition member' then
      cross_sport_scope_assignment_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    cross_sport_scope_assignment_rejected,
    'a cross-Sport group cannot later receive a conflicting Sport scope'
  );

  perform pg_temp.assert_true(not exists (
    select 1 from public.catalog_competitions
    where competition_id = 'multi-sport-sample'
  ), 'a cross-Sport filter group must not become a factual Competition');

  insert into public.catalog_competition_filter_groups(filter_group_id)
  values ('scope-transition-sample')
  returning id into scope_transition_group_uuid;

  insert into public.competition_filter_group_versions(
    filter_group_id, display_name, record_status
  ) values (
    scope_transition_group_uuid, 'Scope Transition Sample',
    'imported_unverified'
  );

  insert into public.competition_filter_group_membership_versions(
    filter_group_id, competition_id, sort_order, record_status
  )
  select scope_transition_group_uuid, competition.id, 10,
         'imported_unverified'
  from public.catalog_competitions competition
  where competition.competition_id = 'soccer-fa-cup'
  returning id into historical_soccer_membership_uuid;

  update public.competition_filter_group_membership_versions
  set is_current = false,
      effective_to = date '2027-01-01',
      superseded_at = now()
  where id = historical_soccer_membership_uuid;

  insert into public.competition_filter_group_membership_versions(
    filter_group_id, competition_id, sort_order, effective_from,
    effective_from_precision, record_status
  )
  select scope_transition_group_uuid, competition.id, 10,
         date '2027-01-01', 'day', 'imported_unverified'
  from public.catalog_competitions competition
  where competition.competition_id = 'hockey-whl';

  update public.catalog_competition_filter_groups
  set sport_id = (
    select id from public.catalog_sports where sport_id = 'hockey'
  )
  where id = scope_transition_group_uuid;

  perform pg_temp.assert_true((
    select count(*) = 2
      and count(*) filter (where membership.is_current) = 1
      and count(*) filter (
        where not membership.is_current
          and competition.competition_id = 'soccer-fa-cup'
      ) = 1
      and count(*) filter (
        where membership.is_current
          and competition.competition_id = 'hockey-whl'
      ) = 1
    from public.competition_filter_group_membership_versions membership
    join public.catalog_competitions competition
      on competition.id = membership.competition_id
    where membership.filter_group_id = scope_transition_group_uuid
  ) and (
    select sport.sport_id = 'hockey'
    from public.catalog_competition_filter_groups filter_group
    join public.catalog_sports sport on sport.id = filter_group.sport_id
    where filter_group.id = scope_transition_group_uuid
  ), 'historical cross-Sport membership must not block a new current Sport scope');

  begin
    insert into public.team_competition_edition_participation_versions(
      team_id, competition_edition_id, record_status
    )
    select team.id, edition.id, 'imported_unverified'
    from public.catalog_teams team
    cross join public.catalog_competition_editions edition
    where team.team_id = 'hockey-000027'
      and edition.edition_id = 'soccer-fa-cup-test-2026-27';
  exception when others then
    if sqlerrm = 'Team and Competition Edition must belong to the same Sport' then
      cross_sport_participation_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    cross_sport_participation_rejected,
    'Team participation must reject a Competition Edition from another Sport'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Append-only supersession lifecycle across every Competition version family
-- ---------------------------------------------------------------------------

do $$
declare
  lifecycle_competition_uuid uuid;
  lifecycle_edition_uuid uuid;
  target_competition_uuid uuid;
  target_edition_uuid uuid;
  lifecycle_team_uuid uuid;
  lifecycle_group_uuid uuid;
  verified_identity_uuid uuid;
  verified_edit_rejected boolean := false;
  verified_history_edit_rejected boolean := false;
  verified_history_delete_rejected boolean := false;
begin
  lifecycle_competition_uuid := pg_temp.create_competition(
    'hockey-lifecycle-cup', 'hockey', 'cup',
    'Lifecycle Cup', 'Lifecycle'
  );

  insert into public.competition_alias_versions(
    competition_id, alias, alias_type, record_status
  ) values (
    lifecycle_competition_uuid, 'Lifecycle Cup', 'common_name',
    'imported_unverified'
  );

  lifecycle_edition_uuid := pg_temp.create_competition_edition(
    'hockey-lifecycle-cup', 'hockey-lifecycle-cup-test-2027',
    '2027 Lifecycle Cup', '2027'
  );

  select id into strict target_competition_uuid
  from public.catalog_competitions where competition_id = 'hockey-nhl';
  select id into strict target_edition_uuid
  from public.catalog_competition_editions
  where edition_id = 'hockey-nhl-test-2026-27';
  select id into strict lifecycle_team_uuid
  from public.catalog_teams where team_id = 'hockey-000027';

  insert into public.competition_relationship_versions(
    source_competition_id, target_competition_id,
    relationship_type, record_status
  ) values (
    lifecycle_competition_uuid, target_competition_uuid,
    'qualification-path', 'imported_unverified'
  );

  insert into public.competition_edition_relationship_versions(
    source_competition_edition_id, target_competition_edition_id,
    relationship_type, record_status
  ) values (
    lifecycle_edition_uuid, target_edition_uuid,
    'qualification-path', 'imported_unverified'
  );

  insert into public.team_competition_edition_participation_versions(
    team_id, competition_edition_id, record_status
  ) values (
    lifecycle_team_uuid, lifecycle_edition_uuid, 'imported_unverified'
  );

  insert into public.catalog_competition_filter_groups(
    filter_group_id, sport_id
  )
  select 'hockey-lifecycle-group', sport.id
  from public.catalog_sports sport where sport.sport_id = 'hockey'
  returning id into lifecycle_group_uuid;

  insert into public.competition_filter_group_versions(
    filter_group_id, display_name, record_status
  ) values (
    lifecycle_group_uuid, 'Lifecycle Group', 'imported_unverified'
  );

  insert into public.competition_filter_group_membership_versions(
    filter_group_id, competition_id, sort_order, record_status
  ) values (
    lifecycle_group_uuid, lifecycle_competition_uuid, 10,
    'imported_unverified'
  );

  -- This is the same current-to-superseded update shape used by the existing
  -- governed Team approval workflow before it inserts a successor row.
  update public.competition_identity_versions
  set is_current = false, effective_to = date '2027-01-01',
      superseded_at = now()
  where competition_id = lifecycle_competition_uuid and is_current;
  update public.competition_alias_versions
  set is_current = false, effective_to = date '2027-01-01',
      superseded_at = now()
  where competition_id = lifecycle_competition_uuid
    and normalized_alias = 'lifecycle cup' and is_current;
  update public.competition_edition_versions
  set is_current = false, effective_to = date '2027-01-01',
      superseded_at = now()
  where competition_edition_id = lifecycle_edition_uuid and is_current;
  update public.competition_relationship_versions
  set is_current = false, effective_to = date '2027-01-01',
      superseded_at = now()
  where source_competition_id = lifecycle_competition_uuid
    and target_competition_id = target_competition_uuid
    and relationship_type = 'qualification-path' and is_current;
  update public.competition_edition_relationship_versions
  set is_current = false, effective_to = date '2027-01-01',
      superseded_at = now()
  where source_competition_edition_id = lifecycle_edition_uuid
    and target_competition_edition_id = target_edition_uuid
    and relationship_type = 'qualification-path' and is_current;
  update public.team_competition_edition_participation_versions
  set is_current = false, effective_to = date '2027-01-01',
      superseded_at = now()
  where team_id = lifecycle_team_uuid
    and competition_edition_id = lifecycle_edition_uuid
    and participation_role = 'participant' and is_current;
  update public.competition_filter_group_versions
  set is_current = false, effective_to = date '2027-01-01',
      superseded_at = now()
  where filter_group_id = lifecycle_group_uuid and is_current;
  update public.competition_filter_group_membership_versions
  set is_current = false, effective_to = date '2027-01-01',
      superseded_at = now()
  where filter_group_id = lifecycle_group_uuid
    and competition_id = lifecycle_competition_uuid and is_current;

  -- The verified identity row is a transactional protection fixture. Phase 1
  -- intentionally does not expose a casual Competition verification path.
  insert into public.competition_identity_versions(
    competition_id, display_name, short_name, effective_from,
    effective_from_precision, record_status
  ) values (
    lifecycle_competition_uuid, 'Lifecycle Cup Updated', 'Lifecycle',
    date '2027-01-01', 'day', 'verified'
  ) returning id into verified_identity_uuid;
  insert into public.competition_alias_versions(
    competition_id, alias, alias_type, effective_from,
    effective_from_precision, record_status
  ) values (
    lifecycle_competition_uuid, 'Lifecycle Cup', 'common_name',
    date '2027-01-01', 'day', 'imported_unverified'
  );
  insert into public.competition_edition_versions(
    competition_edition_id, display_name, season_label, effective_from,
    effective_from_precision, record_status
  ) values (
    lifecycle_edition_uuid, '2027 Lifecycle Cup Updated', '2027',
    date '2027-01-01', 'day', 'imported_unverified'
  );
  insert into public.competition_relationship_versions(
    source_competition_id, target_competition_id, relationship_type,
    effective_from, effective_from_precision, record_status
  ) values (
    lifecycle_competition_uuid, target_competition_uuid,
    'qualification-path', date '2027-01-01', 'day',
    'imported_unverified'
  );
  insert into public.competition_edition_relationship_versions(
    source_competition_edition_id, target_competition_edition_id,
    relationship_type, effective_from, effective_from_precision,
    record_status
  ) values (
    lifecycle_edition_uuid, target_edition_uuid, 'qualification-path',
    date '2027-01-01', 'day', 'imported_unverified'
  );
  insert into public.team_competition_edition_participation_versions(
    team_id, competition_edition_id, participation_role, participating,
    effective_from, effective_from_precision, record_status
  ) values (
    lifecycle_team_uuid, lifecycle_edition_uuid, 'participant', true,
    date '2027-01-01', 'day', 'imported_unverified'
  );
  insert into public.competition_filter_group_versions(
    filter_group_id, display_name, effective_from,
    effective_from_precision, record_status
  ) values (
    lifecycle_group_uuid, 'Lifecycle Group Updated',
    date '2027-01-01', 'day', 'imported_unverified'
  );
  insert into public.competition_filter_group_membership_versions(
    filter_group_id, competition_id, sort_order, effective_from,
    effective_from_precision, record_status
  ) values (
    lifecycle_group_uuid, lifecycle_competition_uuid, 20,
    date '2027-01-01', 'day', 'imported_unverified'
  );

  perform pg_temp.assert_true((
    select bool_and(version_counts.total_count = 2
      and version_counts.current_count = 1
      and version_counts.historical_count = 1)
    from (
      select count(*) as total_count,
             count(*) filter (where is_current) as current_count,
             count(*) filter (where not is_current) as historical_count
      from public.competition_identity_versions
      where competition_id = lifecycle_competition_uuid
      union all
      select count(*), count(*) filter (where is_current),
             count(*) filter (where not is_current)
      from public.competition_alias_versions
      where competition_id = lifecycle_competition_uuid
        and normalized_alias = 'lifecycle cup'
      union all
      select count(*), count(*) filter (where is_current),
             count(*) filter (where not is_current)
      from public.competition_edition_versions
      where competition_edition_id = lifecycle_edition_uuid
      union all
      select count(*), count(*) filter (where is_current),
             count(*) filter (where not is_current)
      from public.competition_relationship_versions
      where source_competition_id = lifecycle_competition_uuid
        and target_competition_id = target_competition_uuid
        and relationship_type = 'qualification-path'
      union all
      select count(*), count(*) filter (where is_current),
             count(*) filter (where not is_current)
      from public.competition_edition_relationship_versions
      where source_competition_edition_id = lifecycle_edition_uuid
        and target_competition_edition_id = target_edition_uuid
        and relationship_type = 'qualification-path'
      union all
      select count(*), count(*) filter (where is_current),
             count(*) filter (where not is_current)
      from public.team_competition_edition_participation_versions
      where team_id = lifecycle_team_uuid
        and competition_edition_id = lifecycle_edition_uuid
        and participation_role = 'participant'
      union all
      select count(*), count(*) filter (where is_current),
             count(*) filter (where not is_current)
      from public.competition_filter_group_versions
      where filter_group_id = lifecycle_group_uuid
      union all
      select count(*), count(*) filter (where is_current),
             count(*) filter (where not is_current)
      from public.competition_filter_group_membership_versions
      where filter_group_id = lifecycle_group_uuid
        and competition_id = lifecycle_competition_uuid
    ) version_counts
  ), 'all eight Competition version families must retain one historical row and one current successor');

  perform pg_temp.assert_true((
    select count(distinct relation.relname) = 8
    from pg_catalog.pg_trigger trigger_record
    join pg_catalog.pg_class relation
      on relation.oid = trigger_record.tgrelid
    join pg_catalog.pg_namespace namespace_record
      on namespace_record.oid = relation.relnamespace
    where namespace_record.nspname = 'public'
      and trigger_record.tgname = 'protect_verified_version'
      and not trigger_record.tgisinternal
      and relation.relname in (
        'competition_identity_versions', 'competition_alias_versions',
        'competition_edition_versions', 'competition_relationship_versions',
        'competition_edition_relationship_versions',
        'team_competition_edition_participation_versions',
        'competition_filter_group_versions',
        'competition_filter_group_membership_versions'
      )
  ), 'every Competition version family must use verified-history protection');

  begin
    update public.competition_identity_versions
    set display_name = 'Illegal Current Rewrite'
    where id = verified_identity_uuid;
  exception when others then
    if sqlerrm = 'Verified catalog values cannot be overwritten' then
      verified_edit_rejected := true;
    else
      raise;
    end if;
  end;
  perform pg_temp.assert_true(
    verified_edit_rejected,
    'a verified current Competition fact must not be overwritten'
  );

  update public.competition_identity_versions
  set is_current = false, effective_to = date '2028-01-01',
      superseded_at = now()
  where id = verified_identity_uuid;
  insert into public.competition_identity_versions(
    competition_id, display_name, short_name, effective_from,
    effective_from_precision, record_status
  ) values (
    lifecycle_competition_uuid, 'Lifecycle Cup Final', 'Lifecycle',
    date '2028-01-01', 'day', 'verified'
  );

  begin
    update public.competition_identity_versions
    set display_name = 'Illegal Historical Rewrite'
    where id = verified_identity_uuid;
  exception when others then
    if sqlerrm = 'Verified catalog values cannot be overwritten' then
      verified_history_edit_rejected := true;
    else
      raise;
    end if;
  end;
  begin
    delete from public.competition_identity_versions
    where id = verified_identity_uuid;
  exception when others then
    if sqlerrm = 'Verified catalog facts cannot be deleted' then
      verified_history_delete_rejected := true;
    else
      raise;
    end if;
  end;

  perform pg_temp.assert_true(
    verified_history_edit_rejected and verified_history_delete_rejected
      and (
        select count(*) = 3
          and count(*) filter (where is_current) = 1
          and count(*) filter (
            where id = verified_identity_uuid and not is_current
              and superseded_at is not null
          ) = 1
        from public.competition_identity_versions
        where competition_id = lifecycle_competition_uuid
      ),
    'verified history must remain protected while governed supersession creates one current successor'
  );
end;
$$;

-- Public catalog access remains read-only for browser roles.
do $$
begin
  perform pg_temp.assert_true(
    has_table_privilege(
      'anon', 'public.catalog_competitions', 'SELECT'
    ) and has_table_privilege(
      'authenticated', 'public.competition_catalog_read_model', 'SELECT'
    ),
    'anonymous and authenticated readers need the Competition catalog'
  );
  perform pg_temp.assert_true(
    not has_table_privilege(
      'anon', 'public.catalog_competitions', 'INSERT'
    ) and not has_table_privilege(
      'authenticated',
      'public.team_competition_edition_participation_versions', 'UPDATE'
    ) and not has_table_privilege(
      'authenticated',
      'public.competition_filter_group_membership_versions', 'DELETE'
    ),
    'browser roles must not mutate canonical Competition records directly'
  );
  perform pg_temp.assert_true(
    has_function_privilege(
      'anon', 'public.resolve_catalog_competition(text,text)', 'EXECUTE'
    ),
    'anonymous readers need the ambiguity-safe Competition resolver'
  );
end;
$$;

rollback;
