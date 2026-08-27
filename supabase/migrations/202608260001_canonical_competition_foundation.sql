-- Additive canonical Competition foundation for FANatical News.
--
-- Design rules:
--   * Existing Sport, League, Team, and team_primary_league records keep their
--     identities and meaning.
--   * A Competition is a stable identity; mutable names and descriptive facts
--     live in append-only version rows.
--   * Competition Editions are distinct identities, never bare year strings.
--   * Team participation is Edition-aware and many-to-many.
--   * Competition and Edition relationships are graphs, not parent trees.
--   * Filter groups are presentation records that reference Competitions; they
--     are never factual Competition identities.

begin;

-- ---------------------------------------------------------------------------
-- Required Sport coverage and controlled/extensible Competition kinds
-- ---------------------------------------------------------------------------

do $$
declare conflict_record record;
begin
  select supplied.sport_id, existing.display_name as existing_name,
         supplied.display_name as supplied_name
  into conflict_record
  from (values ('golf', 'Golf'), ('tennis', 'Tennis'))
       supplied(sport_id, display_name)
  join public.catalog_sports existing on existing.sport_id = supplied.sport_id
  where existing.display_name <> supplied.display_name
  limit 1;

  if found then
    raise exception 'Permanent Sport ID conflict for %: existing %, supplied %',
      conflict_record.sport_id, conflict_record.existing_name,
      conflict_record.supplied_name;
  end if;
end;
$$;

insert into public.catalog_sports(sport_id, display_name)
values ('golf', 'Golf'), ('tennis', 'Tennis')
on conflict (sport_id) do nothing;

create table public.competition_kinds (
  id uuid primary key default gen_random_uuid(),
  kind_id text not null unique
    check (kind_id ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  display_name text not null check (length(btrim(display_name)) > 0),
  description text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.competition_kinds(kind_id, display_name, description)
values
  ('league', 'League', 'Recurring league Competition.'),
  ('cup', 'Cup', 'Cup Competition.'),
  ('championship', 'Championship', 'Championship Competition.'),
  ('tournament', 'Tournament', 'Tournament Competition.'),
  ('tour', 'Tour', 'Tour Competition.'),
  ('series', 'Series', 'Series Competition.'),
  ('other', 'Other', 'Controlled fallback for a factual Competition kind not yet modeled.')
on conflict (kind_id) do nothing;

-- ---------------------------------------------------------------------------
-- Stable Competition identities and versioned facts
-- ---------------------------------------------------------------------------

create table public.catalog_competitions (
  id uuid primary key default gen_random_uuid(),
  competition_id text not null unique
    check (competition_id ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  sport_id uuid not null references public.catalog_sports(id),
  kind_id uuid not null references public.competition_kinds(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index catalog_competitions_sport_kind_idx
on public.catalog_competitions(sport_id, kind_id, competition_id);

create table public.competition_identity_versions (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null
    references public.catalog_competitions(id) on delete cascade,
  display_name text not null check (length(btrim(display_name)) > 0),
  short_name text,
  country_region text,
  primary_languages text[] not null default array[]::text[],
  active boolean not null default true,
  effective_from date,
  effective_from_precision text not null default 'unknown'
    check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null
    check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid
    references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (short_name is null or length(btrim(short_name)) > 0),
  check (effective_to is null or effective_from is null
    or effective_to >= effective_from)
);

create unique index competition_identity_current_idx
on public.competition_identity_versions(competition_id) where is_current;

create index competition_identity_name_lookup_idx
on public.competition_identity_versions(
  lower(regexp_replace(btrim(display_name), '\s+', ' ', 'g'))
) where is_current;

create table public.competition_alias_versions (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null
    references public.catalog_competitions(id) on delete cascade,
  alias text not null check (length(btrim(alias)) > 0),
  normalized_alias text generated always as (
    lower(regexp_replace(btrim(alias), '\s+', ' ', 'g'))
  ) stored,
  alias_type text not null check (alias_type in (
    'common_name', 'short_name', 'abbreviation', 'sponsored_name',
    'former_name', 'other'
  )),
  locale text,
  effective_from date,
  effective_from_precision text not null default 'unknown'
    check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null
    check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid
    references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (effective_to is null or effective_from is null
    or effective_to >= effective_from)
);

create index competition_alias_lookup_idx
on public.competition_alias_versions(normalized_alias) where is_current;

create unique index competition_alias_current_unique_idx
on public.competition_alias_versions(
  competition_id, normalized_alias, alias_type, coalesce(locale, '')
) where is_current;

create table public.catalog_competition_identifiers (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null
    references public.catalog_competitions(id) on delete cascade,
  namespace text not null check (length(btrim(namespace)) > 0),
  identifier text not null check (length(btrim(identifier)) > 0),
  record_status text not null default 'imported_unverified'
    check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid
    references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  unique (namespace, identifier),
  unique (competition_id, namespace, identifier)
);

-- ---------------------------------------------------------------------------
-- Explicit compatibility mapping from existing Leagues to Competitions
-- ---------------------------------------------------------------------------

create table public.catalog_league_competition_mappings (
  league_id uuid primary key references public.catalog_leagues(id),
  competition_id uuid not null unique references public.catalog_competitions(id),
  created_at timestamptz not null default now()
);

create or replace function public.validate_league_competition_mapping()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  league_sport_uuid uuid;
  league_public_id text;
  competition_sport_uuid uuid;
  competition_public_id text;
  competition_kind text;
begin
  if tg_op = 'DELETE' then
    raise exception 'League-to-Competition mappings are durable and cannot be deleted';
  end if;

  select league.sport_id, league.league_id
  into strict league_sport_uuid, league_public_id
  from public.catalog_leagues league where league.id = new.league_id;

  select competition.sport_id, competition.competition_id, kind.kind_id
  into strict competition_sport_uuid, competition_public_id, competition_kind
  from public.catalog_competitions competition
  join public.competition_kinds kind on kind.id = competition.kind_id
  where competition.id = new.competition_id;

  if league_sport_uuid <> competition_sport_uuid then
    raise exception 'League and mapped Competition must belong to the same Sport';
  end if;
  if competition_kind <> 'league' then
    raise exception 'An existing League may map only to a league-kind Competition';
  end if;
  if league_public_id <> competition_public_id then
    raise exception 'League and mapped Competition must share the same permanent public ID';
  end if;
  return new;
end;
$$;

create trigger validate_league_competition_mapping
before insert or update or delete on public.catalog_league_competition_mappings
for each row execute function public.validate_league_competition_mapping();

do $$
declare unexpected_status text;
begin
  select league.seed_status into unexpected_status
  from public.catalog_leagues league
  where league.seed_status not in ('imported_unverified', 'verified')
  limit 1;

  if found then
    raise exception 'Unsupported legacy League seed status for Competition backfill: %',
      unexpected_status;
  end if;
end;
$$;

insert into public.catalog_competitions(
  competition_id, sport_id, kind_id, import_batch_id
)
select league.league_id, league.sport_id, kind.id, league.import_batch_id
from public.catalog_leagues league
cross join public.competition_kinds kind
where kind.kind_id = 'league'
on conflict (competition_id) do nothing;

insert into public.competition_identity_versions(
  competition_id, display_name, short_name, country_region,
  primary_languages, active, record_status, import_batch_id
)
select competition.id, league.display_name, league.short_name,
       league.country_region, league.primary_languages, league.active,
       'imported_unverified', league.import_batch_id
from public.catalog_leagues league
join public.catalog_competitions competition
  on competition.competition_id = league.league_id
where not exists (
  select 1 from public.competition_identity_versions existing
  where existing.competition_id = competition.id and existing.is_current
);

insert into public.catalog_league_competition_mappings(
  league_id, competition_id
)
select league.id, competition.id
from public.catalog_leagues league
join public.catalog_competitions competition
  on competition.competition_id = league.league_id
on conflict (league_id) do nothing;

insert into public.catalog_competition_identifiers(
  competition_id, namespace, identifier, record_status, import_batch_id
)
select competition.id, identifier.namespace, identifier.identifier,
       'imported_unverified', competition.import_batch_id
from public.catalog_league_identifiers identifier
join public.catalog_leagues league on league.id = identifier.league_id
join public.catalog_competitions competition
  on competition.competition_id = league.league_id;

do $$
declare conflict_record record;
begin
  select league.league_id, sport.sport_id as league_sport,
         competition.competition_id,
         competition_sport.sport_id as competition_sport,
         kind.kind_id
  into conflict_record
  from public.catalog_leagues league
  left join public.catalog_league_competition_mappings mapping
    on mapping.league_id = league.id
  left join public.catalog_competitions competition
    on competition.id = mapping.competition_id
  left join public.catalog_sports sport on sport.id = league.sport_id
  left join public.catalog_sports competition_sport
    on competition_sport.id = competition.sport_id
  left join public.competition_kinds kind on kind.id = competition.kind_id
  where mapping.league_id is null
     or competition.competition_id <> league.league_id
     or competition.sport_id <> league.sport_id
     or kind.kind_id <> 'league'
  limit 1;

  if found then
    raise exception 'Existing League compatibility mapping is incomplete or inconsistent: %',
      row_to_json(conflict_record);
  end if;
end;
$$;

do $$
declare missing_identifier record;
begin
  select league.league_id, legacy_identifier.namespace,
         legacy_identifier.identifier
  into missing_identifier
  from public.catalog_league_identifiers legacy_identifier
  join public.catalog_leagues league on league.id = legacy_identifier.league_id
  join public.catalog_league_competition_mappings mapping
    on mapping.league_id = league.id
  left join public.catalog_competition_identifiers competition_identifier
    on competition_identifier.competition_id = mapping.competition_id
   and competition_identifier.namespace = legacy_identifier.namespace
   and competition_identifier.identifier = legacy_identifier.identifier
  where competition_identifier.id is null
  limit 1;

  if found then
    raise exception 'League identifier was not preserved for mapped Competition: %',
      row_to_json(missing_identifier);
  end if;
end;
$$;

create or replace function public.complete_catalog_league_competition()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  league_kind_uuid uuid;
  competition_uuid uuid;
begin
  select kind.id into strict league_kind_uuid
  from public.competition_kinds kind
  where kind.kind_id = 'league' and kind.active;

  insert into public.catalog_competitions(
    competition_id, sport_id, kind_id, import_batch_id
  ) values (
    new.league_id, new.sport_id, league_kind_uuid, new.import_batch_id
  ) returning id into competition_uuid;

  insert into public.competition_identity_versions(
    competition_id, display_name, short_name, country_region,
    primary_languages, active, record_status, import_batch_id
  ) values (
    competition_uuid, new.display_name, new.short_name, new.country_region,
    new.primary_languages, new.active, 'imported_unverified',
    new.import_batch_id
  );

  insert into public.catalog_league_competition_mappings(
    league_id, competition_id
  ) values (new.id, competition_uuid);

  return new;
end;
$$;

drop trigger if exists catalog_leagues_complete_competition
on public.catalog_leagues;
create trigger catalog_leagues_complete_competition
after insert on public.catalog_leagues
for each row execute function public.complete_catalog_league_competition();

create or replace function public.complete_catalog_league_identifier()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  competition_uuid uuid;
  competition_import_batch_uuid uuid;
begin
  select mapping.competition_id, competition.import_batch_id
  into strict competition_uuid, competition_import_batch_uuid
  from public.catalog_league_competition_mappings mapping
  join public.catalog_competitions competition
    on competition.id = mapping.competition_id
  where mapping.league_id = new.league_id;

  if exists (
    select 1
    from public.catalog_competition_identifiers competition_identifier
    where competition_identifier.competition_id = competition_uuid
      and competition_identifier.namespace = new.namespace
      and competition_identifier.identifier = new.identifier
  ) then
    return new;
  end if;

  insert into public.catalog_competition_identifiers(
    competition_id, namespace, identifier, record_status, import_batch_id
  ) values (
    competition_uuid, new.namespace, new.identifier,
    'imported_unverified', competition_import_batch_uuid
  );

  return new;
end;
$$;

drop trigger if exists catalog_league_identifiers_complete_competition
on public.catalog_league_identifiers;
create trigger catalog_league_identifiers_complete_competition
after insert on public.catalog_league_identifiers
for each row execute function public.complete_catalog_league_identifier();

-- ---------------------------------------------------------------------------
-- Stable Competition Edition identities and versioned Edition facts
-- ---------------------------------------------------------------------------

create table public.catalog_competition_editions (
  id uuid primary key default gen_random_uuid(),
  edition_id text not null unique check (
    edition_id ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    and edition_id ~ '[a-z]'
  ),
  competition_id uuid not null
    references public.catalog_competitions(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index catalog_competition_editions_competition_idx
on public.catalog_competition_editions(competition_id, edition_id);

create table public.competition_edition_versions (
  id uuid primary key default gen_random_uuid(),
  competition_edition_id uuid not null
    references public.catalog_competition_editions(id) on delete cascade,
  display_name text not null check (length(btrim(display_name)) > 0),
  season_label text,
  starts_on date,
  ends_on date,
  active boolean not null default true,
  effective_from date,
  effective_from_precision text not null default 'unknown'
    check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null
    check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid
    references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (season_label is null or length(btrim(season_label)) > 0),
  check (ends_on is null or starts_on is null or ends_on >= starts_on),
  check (effective_to is null or effective_from is null
    or effective_to >= effective_from)
);

create unique index competition_edition_current_idx
on public.competition_edition_versions(competition_edition_id)
where is_current;

create table public.catalog_competition_edition_identifiers (
  id uuid primary key default gen_random_uuid(),
  competition_edition_id uuid not null
    references public.catalog_competition_editions(id) on delete cascade,
  namespace text not null check (length(btrim(namespace)) > 0),
  identifier text not null check (length(btrim(identifier)) > 0),
  record_status text not null default 'imported_unverified'
    check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid
    references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  unique (namespace, identifier),
  unique (competition_edition_id, namespace, identifier)
);

-- ---------------------------------------------------------------------------
-- Many-to-many Competition and Edition relationships
-- ---------------------------------------------------------------------------

create table public.competition_relationship_versions (
  id uuid primary key default gen_random_uuid(),
  source_competition_id uuid not null
    references public.catalog_competitions(id) on delete cascade,
  target_competition_id uuid not null
    references public.catalog_competitions(id) on delete cascade,
  relationship_type text not null
    check (relationship_type ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  effective_from date,
  effective_from_precision text not null default 'unknown'
    check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null
    check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid
    references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (source_competition_id <> target_competition_id),
  check (effective_to is null or effective_from is null
    or effective_to >= effective_from)
);

create unique index competition_relationship_current_idx
on public.competition_relationship_versions(
  source_competition_id, target_competition_id, relationship_type
) where is_current;

create index competition_relationship_target_idx
on public.competition_relationship_versions(
  target_competition_id, relationship_type
) where is_current;

create or replace function public.validate_competition_relationship_sport()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  source_sport_uuid uuid;
  target_sport_uuid uuid;
begin
  select competition.sport_id into strict source_sport_uuid
  from public.catalog_competitions competition
  where competition.id = new.source_competition_id;

  select competition.sport_id into strict target_sport_uuid
  from public.catalog_competitions competition
  where competition.id = new.target_competition_id;

  if source_sport_uuid <> target_sport_uuid then
    raise exception 'Competition relationship source and target must belong to the same Sport';
  end if;
  return new;
end;
$$;

create trigger validate_competition_relationship_sport
before insert or update on public.competition_relationship_versions
for each row execute function public.validate_competition_relationship_sport();

create table public.competition_edition_relationship_versions (
  id uuid primary key default gen_random_uuid(),
  source_competition_edition_id uuid not null
    references public.catalog_competition_editions(id) on delete cascade,
  target_competition_edition_id uuid not null
    references public.catalog_competition_editions(id) on delete cascade,
  relationship_type text not null
    check (relationship_type ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  effective_from date,
  effective_from_precision text not null default 'unknown'
    check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null
    check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid
    references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (source_competition_edition_id <> target_competition_edition_id),
  check (effective_to is null or effective_from is null
    or effective_to >= effective_from)
);

create unique index competition_edition_relationship_current_idx
on public.competition_edition_relationship_versions(
  source_competition_edition_id, target_competition_edition_id,
  relationship_type
) where is_current;

create index competition_edition_relationship_target_idx
on public.competition_edition_relationship_versions(
  target_competition_edition_id, relationship_type
) where is_current;

create or replace function public.validate_competition_edition_relationship_sport()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  source_sport_uuid uuid;
  target_sport_uuid uuid;
begin
  select competition.sport_id into strict source_sport_uuid
  from public.catalog_competition_editions edition
  join public.catalog_competitions competition
    on competition.id = edition.competition_id
  where edition.id = new.source_competition_edition_id;

  select competition.sport_id into strict target_sport_uuid
  from public.catalog_competition_editions edition
  join public.catalog_competitions competition
    on competition.id = edition.competition_id
  where edition.id = new.target_competition_edition_id;

  if source_sport_uuid <> target_sport_uuid then
    raise exception 'Competition Edition relationship source and target must belong to the same Sport';
  end if;
  return new;
end;
$$;

create trigger validate_competition_edition_relationship_sport
before insert or update on public.competition_edition_relationship_versions
for each row execute function public.validate_competition_edition_relationship_sport();

-- ---------------------------------------------------------------------------
-- Edition-aware Team participation without changing Team identity
-- ---------------------------------------------------------------------------

create table public.team_competition_edition_participation_versions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.catalog_teams(id) on delete cascade,
  competition_edition_id uuid not null
    references public.catalog_competition_editions(id) on delete cascade,
  participation_role text not null default 'participant'
    check (participation_role ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  participating boolean not null default true,
  effective_from date,
  effective_from_precision text not null default 'unknown'
    check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null
    check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid
    references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (effective_to is null or effective_from is null
    or effective_to >= effective_from)
);

create unique index team_competition_edition_participation_current_idx
on public.team_competition_edition_participation_versions(
  team_id, competition_edition_id, participation_role
) where is_current;

create index team_competition_edition_participation_edition_idx
on public.team_competition_edition_participation_versions(
  competition_edition_id, participating
) where is_current;

create or replace function public.validate_team_competition_edition_sport()
returns trigger
language plpgsql
set search_path = ''
as $$
declare team_sport_uuid uuid;
declare competition_sport_uuid uuid;
begin
  select team.sport_id into strict team_sport_uuid
  from public.catalog_teams team where team.id = new.team_id;

  select competition.sport_id into strict competition_sport_uuid
  from public.catalog_competition_editions edition
  join public.catalog_competitions competition
    on competition.id = edition.competition_id
  where edition.id = new.competition_edition_id;

  if team_sport_uuid <> competition_sport_uuid then
    raise exception 'Team and Competition Edition must belong to the same Sport';
  end if;
  return new;
end;
$$;

create trigger validate_team_competition_edition_sport
before insert or update
on public.team_competition_edition_participation_versions
for each row execute function public.validate_team_competition_edition_sport();

-- ---------------------------------------------------------------------------
-- Presentation-only Competition filter groups
-- ---------------------------------------------------------------------------

create table public.catalog_competition_filter_groups (
  id uuid primary key default gen_random_uuid(),
  filter_group_id text not null unique
    check (filter_group_id ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  sport_id uuid references public.catalog_sports(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.competition_filter_group_versions (
  id uuid primary key default gen_random_uuid(),
  filter_group_id uuid not null
    references public.catalog_competition_filter_groups(id) on delete cascade,
  display_name text not null check (length(btrim(display_name)) > 0),
  description text,
  active boolean not null default true,
  effective_from date,
  effective_from_precision text not null default 'unknown'
    check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null
    check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid
    references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (effective_to is null or effective_from is null
    or effective_to >= effective_from)
);

create unique index competition_filter_group_current_idx
on public.competition_filter_group_versions(filter_group_id) where is_current;

create table public.competition_filter_group_membership_versions (
  id uuid primary key default gen_random_uuid(),
  filter_group_id uuid not null
    references public.catalog_competition_filter_groups(id) on delete cascade,
  competition_id uuid not null
    references public.catalog_competitions(id) on delete cascade,
  sort_order integer not null default 0,
  effective_from date,
  effective_from_precision text not null default 'unknown'
    check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null
    check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid
    references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (effective_to is null or effective_from is null
    or effective_to >= effective_from)
);

create unique index competition_filter_group_membership_current_idx
on public.competition_filter_group_membership_versions(
  filter_group_id, competition_id
) where is_current;

create or replace function public.validate_competition_filter_group_scope()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.sport_id is not null and exists (
    select 1
    from public.competition_filter_group_membership_versions membership
    join public.catalog_competitions competition
      on competition.id = membership.competition_id
    where membership.filter_group_id = new.id
      and membership.is_current
      and competition.sport_id <> new.sport_id
  ) then
    raise exception 'Filter group Sport scope conflicts with an existing Competition member';
  end if;
  return new;
end;
$$;

create trigger validate_competition_filter_group_scope
before insert or update on public.catalog_competition_filter_groups
for each row execute function public.validate_competition_filter_group_scope();

create or replace function public.validate_competition_filter_group_sport()
returns trigger
language plpgsql
set search_path = ''
as $$
declare group_sport_uuid uuid;
declare competition_sport_uuid uuid;
begin
  select filter_group.sport_id into strict group_sport_uuid
  from public.catalog_competition_filter_groups filter_group
  where filter_group.id = new.filter_group_id;

  select competition.sport_id into strict competition_sport_uuid
  from public.catalog_competitions competition
  where competition.id = new.competition_id;

  if group_sport_uuid is not null
     and group_sport_uuid <> competition_sport_uuid then
    raise exception 'Filter group and Competition must belong to the same Sport';
  end if;
  return new;
end;
$$;

create trigger validate_competition_filter_group_sport
before insert or update
on public.competition_filter_group_membership_versions
for each row execute function public.validate_competition_filter_group_sport();

-- ---------------------------------------------------------------------------
-- Alias/identifier resolution that preserves ambiguity
-- ---------------------------------------------------------------------------

create or replace function public.resolve_catalog_competition(
  identifier_value text,
  sport_identifier text default null
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with requested as (
    select lower(regexp_replace(btrim(identifier_value), '\s+', ' ', 'g'))
             as normalized_identifier
  ),
  candidates as (
    select competition.id as competition_uuid, 1 as match_rank,
           'competition_id'::text as match_basis
    from public.catalog_competitions competition
    where competition.competition_id = identifier_value

    union all

    select external_id.competition_id, 2, 'external_identifier'
    from public.catalog_competition_identifiers external_id
    where external_id.identifier = identifier_value

    union all

    select alias.competition_id, 3, 'alias'
    from public.competition_alias_versions alias
    cross join requested
    where alias.is_current
      and alias.normalized_alias = requested.normalized_identifier

    union all

    select identity_record.competition_id, 3, 'display_name'
    from public.competition_identity_versions identity_record
    cross join requested
    where identity_record.is_current
      and (
        lower(regexp_replace(btrim(identity_record.display_name), '\s+', ' ', 'g')) =
          requested.normalized_identifier
        or lower(regexp_replace(btrim(coalesce(identity_record.short_name, '')), '\s+', ' ', 'g')) =
          requested.normalized_identifier
      )
  ),
  scoped as (
    select distinct on (candidate.competition_uuid)
           candidate.competition_uuid, candidate.match_rank,
           candidate.match_basis
    from candidates candidate
    join public.catalog_competitions competition
      on competition.id = candidate.competition_uuid
    join public.catalog_sports sport on sport.id = competition.sport_id
    where sport_identifier is null or sport.sport_id = sport_identifier
    order by candidate.competition_uuid, candidate.match_rank,
             candidate.match_basis
  ),
  best_rank as (
    select min(match_rank) as match_rank from scoped
  ),
  matches as (
    select competition.id, competition.competition_id, sport.sport_id,
           kind.kind_id, identity_record.display_name,
           scoped.match_basis
    from scoped
    join best_rank on best_rank.match_rank = scoped.match_rank
    join public.catalog_competitions competition
      on competition.id = scoped.competition_uuid
    join public.catalog_sports sport on sport.id = competition.sport_id
    join public.competition_kinds kind on kind.id = competition.kind_id
    left join public.competition_identity_versions identity_record
      on identity_record.competition_id = competition.id
     and identity_record.is_current
    order by competition.competition_id
  ),
  aggregate_result as (
    select count(*) as match_count,
           coalesce(jsonb_agg(jsonb_build_object(
             'id', id,
             'competition_id', competition_id,
             'sport_id', sport_id,
             'kind_id', kind_id,
             'display_name', display_name,
             'match_basis', match_basis
           ) order by competition_id), '[]'::jsonb) as matches
    from matches
  )
  select jsonb_build_object(
    'status', case match_count
      when 0 then 'none'
      when 1 then 'resolved'
      else 'ambiguous'
    end,
    'matches', matches
  )
  from aggregate_result;
$$;

create or replace function public.resolve_catalog_competition_id(
  identifier_value text,
  sport_identifier text default null
)
returns uuid
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare result jsonb;
begin
  result := public.resolve_catalog_competition(
    identifier_value, sport_identifier
  );
  if result ->> 'status' = 'ambiguous' then
    raise exception 'Ambiguous Competition identifier: %', identifier_value;
  end if;
  if result ->> 'status' = 'resolved' then
    return (result #>> '{matches,0,id}')::uuid;
  end if;
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Public read models
-- ---------------------------------------------------------------------------

create view public.competition_catalog_read_model
with (security_invoker = true)
as
select
  competition.id as internal_id,
  competition.competition_id,
  sport.sport_id,
  sport.display_name as sport_name,
  kind.kind_id,
  kind.display_name as kind_name,
  identity_record.display_name,
  identity_record.short_name,
  identity_record.country_region,
  identity_record.primary_languages,
  identity_record.active,
  identity_record.record_status,
  league.league_id as legacy_league_id,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'value', alias.alias,
      'type', alias.alias_type,
      'locale', alias.locale
    ) order by alias.alias_type, alias.alias)
    from public.competition_alias_versions alias
    where alias.competition_id = competition.id and alias.is_current
  ), '[]'::jsonb) as aliases,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'namespace', identifier.namespace,
      'identifier', identifier.identifier
    ) order by identifier.namespace, identifier.identifier)
    from public.catalog_competition_identifiers identifier
    where identifier.competition_id = competition.id
  ), '[]'::jsonb) as external_identifiers
from public.catalog_competitions competition
join public.catalog_sports sport on sport.id = competition.sport_id
join public.competition_kinds kind on kind.id = competition.kind_id
left join public.competition_identity_versions identity_record
  on identity_record.competition_id = competition.id
 and identity_record.is_current
left join public.catalog_league_competition_mappings mapping
  on mapping.competition_id = competition.id
left join public.catalog_leagues league on league.id = mapping.league_id;

create view public.competition_edition_catalog_read_model
with (security_invoker = true)
as
select
  edition.id as internal_id,
  edition.edition_id,
  competition.competition_id,
  sport.sport_id,
  kind.kind_id,
  edition_version.display_name,
  edition_version.season_label,
  edition_version.starts_on,
  edition_version.ends_on,
  edition_version.active,
  edition_version.record_status
from public.catalog_competition_editions edition
join public.catalog_competitions competition
  on competition.id = edition.competition_id
join public.catalog_sports sport on sport.id = competition.sport_id
join public.competition_kinds kind on kind.id = competition.kind_id
left join public.competition_edition_versions edition_version
  on edition_version.competition_edition_id = edition.id
 and edition_version.is_current;

create view public.competition_filter_group_read_model
with (security_invoker = true)
as
select
  filter_group.id as internal_id,
  filter_group.filter_group_id,
  group_sport.sport_id as group_sport_id,
  group_version.display_name,
  group_version.description,
  group_version.active,
  membership.sort_order,
  competition.competition_id,
  competition_sport.sport_id as competition_sport_id,
  competition_identity.display_name as competition_name
from public.catalog_competition_filter_groups filter_group
left join public.catalog_sports group_sport
  on group_sport.id = filter_group.sport_id
left join public.competition_filter_group_versions group_version
  on group_version.filter_group_id = filter_group.id
 and group_version.is_current
left join public.competition_filter_group_membership_versions membership
  on membership.filter_group_id = filter_group.id
 and membership.is_current
left join public.catalog_competitions competition
  on competition.id = membership.competition_id
left join public.catalog_sports competition_sport
  on competition_sport.id = competition.sport_id
left join public.competition_identity_versions competition_identity
  on competition_identity.competition_id = competition.id
 and competition_identity.is_current;

-- ---------------------------------------------------------------------------
-- Existing immutability/versioning patterns, RLS, and grants
-- ---------------------------------------------------------------------------

drop trigger if exists competition_kinds_protect_identity
on public.competition_kinds;
create trigger competition_kinds_protect_identity
before update on public.competition_kinds
for each row execute function public.protect_catalog_public_identity('kind_id');

drop trigger if exists catalog_competitions_protect_identity
on public.catalog_competitions;
create or replace function public.protect_catalog_competition_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.id is distinct from new.id
     or old.competition_id is distinct from new.competition_id
     or old.sport_id is distinct from new.sport_id
     or old.kind_id is distinct from new.kind_id then
    raise exception 'Catalog Competition identity, Sport, and kind are immutable';
  end if;
  return new;
end;
$$;

create trigger catalog_competitions_protect_identity
before update on public.catalog_competitions
for each row execute function public.protect_catalog_competition_identity();

drop trigger if exists catalog_competition_editions_protect_identity
on public.catalog_competition_editions;
create or replace function public.protect_catalog_competition_edition_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.id is distinct from new.id
     or old.edition_id is distinct from new.edition_id
     or old.competition_id is distinct from new.competition_id then
    raise exception 'Catalog Competition Edition identity and parent Competition are immutable';
  end if;
  return new;
end;
$$;

create trigger catalog_competition_editions_protect_identity
before update on public.catalog_competition_editions
for each row execute function public.protect_catalog_competition_edition_identity();

drop trigger if exists competition_filter_groups_protect_identity
on public.catalog_competition_filter_groups;
create trigger competition_filter_groups_protect_identity
before update on public.catalog_competition_filter_groups
for each row execute function public.protect_catalog_public_identity('filter_group_id');

create trigger competition_kinds_set_updated_at
before update on public.competition_kinds
for each row execute function public.set_updated_at();

create trigger catalog_competitions_set_updated_at
before update on public.catalog_competitions
for each row execute function public.set_updated_at();

create trigger catalog_competition_editions_set_updated_at
before update on public.catalog_competition_editions
for each row execute function public.set_updated_at();

create trigger competition_filter_groups_set_updated_at
before update on public.catalog_competition_filter_groups
for each row execute function public.set_updated_at();

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'competition_identity_versions',
    'competition_alias_versions',
    'competition_edition_versions',
    'competition_relationship_versions',
    'competition_edition_relationship_versions',
    'team_competition_edition_participation_versions',
    'competition_filter_group_versions',
    'competition_filter_group_membership_versions'
  ] loop
    execute format(
      'create trigger protect_verified_version before update or delete on public.%I for each row execute function public.protect_verified_catalog_version()',
      table_name
    );
  end loop;
end;
$$;

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'competition_kinds',
    'catalog_competitions',
    'competition_identity_versions',
    'competition_alias_versions',
    'catalog_competition_identifiers',
    'catalog_league_competition_mappings',
    'catalog_competition_editions',
    'competition_edition_versions',
    'catalog_competition_edition_identifiers',
    'competition_relationship_versions',
    'competition_edition_relationship_versions',
    'team_competition_edition_participation_versions',
    'catalog_competition_filter_groups',
    'competition_filter_group_versions',
    'competition_filter_group_membership_versions'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format(
      'revoke all on table public.%I from public, anon, authenticated',
      table_name
    );
    execute format(
      'create policy "Public reads FANatical catalog %1$s" on public.%1$I for select to anon, authenticated using (true)',
      table_name
    );
    execute format(
      'grant select on table public.%I to anon, authenticated',
      table_name
    );
  end loop;
end;
$$;

grant select on
  public.competition_catalog_read_model,
  public.competition_edition_catalog_read_model,
  public.competition_filter_group_read_model
to anon, authenticated;

grant execute on function public.resolve_catalog_competition(text, text)
to anon, authenticated;
grant execute on function public.resolve_catalog_competition_id(text, text)
to anon, authenticated;

revoke all on function public.validate_league_competition_mapping()
from public, anon, authenticated;
revoke all on function public.complete_catalog_league_competition()
from public, anon, authenticated;
revoke all on function public.complete_catalog_league_identifier()
from public, anon, authenticated;
revoke all on function public.protect_catalog_competition_identity()
from public, anon, authenticated;
revoke all on function public.protect_catalog_competition_edition_identity()
from public, anon, authenticated;
revoke all on function public.validate_competition_relationship_sport()
from public, anon, authenticated;
revoke all on function public.validate_competition_edition_relationship_sport()
from public, anon, authenticated;
revoke all on function public.validate_team_competition_edition_sport()
from public, anon, authenticated;
revoke all on function public.validate_competition_filter_group_scope()
from public, anon, authenticated;
revoke all on function public.validate_competition_filter_group_sport()
from public, anon, authenticated;

comment on table public.catalog_competitions is
  'Stable canonical Competition identities. Existing Leagues map additively through catalog_league_competition_mappings.';
comment on table public.catalog_competition_editions is
  'Stable season/occurrence identities whose permanent ID and parent canonical Competition are immutable.';
comment on table public.team_competition_edition_participation_versions is
  'Versioned, Edition-aware Team participation. This does not replace or reinterpret team_primary_league_versions.';
comment on table public.competition_relationship_versions is
  'Same-Sport many-to-many Competition graph; no single-parent hierarchy is implied.';
comment on table public.competition_edition_relationship_versions is
  'Same-Sport many-to-many Edition graph, including Tournament Editions associated with multiple Tour Editions.';
comment on table public.catalog_competition_filter_groups is
  'Presentation/navigation identities only. Optional Sport scope constrains members; unscoped groups may span Sports. Filter groups are not factual Competitions.';
comment on function public.resolve_catalog_competition(text, text) is
  'Resolves canonical IDs, external identifiers, current names, and aliases while returning ambiguity instead of guessing.';

commit;
