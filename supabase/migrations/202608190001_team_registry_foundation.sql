-- FANatical canonical team, verification, and venue-registry foundation.
--
-- Design rules:
--   * UUIDs are internal database identities; public IDs are immutable.
--   * Mutable team and venue facts are append-only version rows.
--   * Imported seed data is usable for compatibility but is not verified.
--   * Verified facts can only be promoted/superseded atomically through RPCs.
--   * Operational agents authenticate as ordinary Supabase Auth principals and
--     receive narrow catalog capabilities. They never receive service-role keys.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Immutable catalog identities
-- ---------------------------------------------------------------------------

create table if not exists public.catalog_sports (
  id uuid primary key default gen_random_uuid(),
  sport_id text not null unique check (sport_id ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  display_name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.catalog_import_batches (
  id uuid primary key default gen_random_uuid(),
  import_key text not null unique,
  source_filename text not null,
  source_sha256 text not null check (source_sha256 ~ '^[0-9a-f]{64}$'),
  source_kind text not null check (source_kind in ('master_workbook', 'legacy_frontend', 'reference_example', 'venue_prototype')),
  record_counts jsonb not null default '{}'::jsonb,
  verified_source_data boolean not null default false,
  notes text,
  imported_at timestamptz not null default now()
);

create table if not exists public.catalog_leagues (
  id uuid primary key default gen_random_uuid(),
  league_id text not null unique check (league_id ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  sport_id uuid not null references public.catalog_sports(id),
  display_name text not null,
  short_name text,
  country_region text,
  primary_languages text[] not null default array[]::text[],
  active boolean not null default true,
  seed_status text not null default 'imported_unverified'
    check (seed_status in ('imported_unverified', 'verified')),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists catalog_leagues_sport_idx on public.catalog_leagues(sport_id, display_name);

create table if not exists public.catalog_teams (
  id uuid primary key default gen_random_uuid(),
  team_id text not null unique check (team_id ~ '^[a-z0-9]+-[0-9]{6}$'),
  sport_id uuid not null references public.catalog_sports(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists catalog_teams_sport_idx on public.catalog_teams(sport_id, team_id);

create table if not exists public.catalog_league_identifiers (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.catalog_leagues(id) on delete cascade,
  namespace text not null,
  identifier text not null,
  created_at timestamptz not null default now(),
  unique (namespace, identifier),
  unique (league_id, namespace, identifier)
);

create table if not exists public.catalog_team_identifiers (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.catalog_teams(id) on delete cascade,
  namespace text not null,
  identifier text not null,
  record_status text not null default 'imported_unverified'
    check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid,
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  unique (namespace, identifier),
  unique (team_id, namespace, identifier)
);

comment on table public.catalog_team_identifiers is
  'Namespaced compatibility and external identifiers. Bare, unscoped legacy ID arrays are intentionally avoided.';

create table if not exists public.catalog_team_id_sequences (
  sport_id uuid primary key references public.catalog_sports(id) on delete cascade,
  next_value integer not null check (next_value > 0),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Authenticated catalog actors and narrow capabilities
-- ---------------------------------------------------------------------------

create table if not exists public.catalog_actors (
  id uuid primary key default gen_random_uuid(),
  actor_key text not null unique,
  actor_type text not null check (actor_type in ('human', 'agent', 'service')),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  display_name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.catalog_actor_capabilities (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.catalog_actors(id) on delete cascade,
  capability text not null,
  sport_id uuid references public.catalog_sports(id) on delete cascade,
  league_id uuid references public.catalog_leagues(id) on delete cascade,
  team_id uuid references public.catalog_teams(id) on delete cascade,
  venue_id uuid,
  active boolean not null default true,
  granted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create unique index if not exists catalog_actor_capability_scope_idx
on public.catalog_actor_capabilities (
  actor_id,
  capability,
  coalesce(sport_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(league_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(team_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(venue_id, '00000000-0000-0000-0000-000000000000'::uuid)
);

-- ---------------------------------------------------------------------------
-- Trusted Source Registry and versioned verification policy
-- ---------------------------------------------------------------------------

create table if not exists public.source_independence_groups (
  id uuid primary key default gen_random_uuid(),
  group_id text not null unique,
  display_name text not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.trusted_sources (
  id uuid primary key default gen_random_uuid(),
  source_id text not null unique,
  display_name text not null,
  base_url text,
  reference_url text,
  independence_group_id uuid references public.source_independence_groups(id),
  review_status text not null default 'pending_review'
    check (review_status in ('pending_review', 'approved', 'suspended', 'retired')),
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.source_trust_assignments (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.trusted_sources(id) on delete cascade,
  data_type text not null,
  trust_tier smallint not null check (trust_tier between 1 and 5),
  effective_from date,
  effective_to date,
  is_current boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create unique index if not exists source_trust_current_idx
on public.source_trust_assignments(source_id, data_type) where is_current;

create table if not exists public.verification_policies (
  id uuid primary key default gen_random_uuid(),
  policy_key text not null,
  version integer not null check (version > 0),
  data_type text not null,
  minimum_evidence_count integer not null check (minimum_evidence_count >= 0),
  allowed_trust_tiers smallint[] not null,
  require_independent_sources boolean not null default true,
  require_independent_verifier boolean not null default true,
  configuration jsonb not null default '{}'::jsonb,
  is_current boolean not null default false,
  active boolean not null default false,
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  unique (policy_key, version),
  check (allowed_trust_tiers <@ array[1,2,3,4,5]::smallint[])
);

create unique index if not exists verification_policy_current_idx
on public.verification_policies(data_type) where is_current and active;

comment on table public.verification_policies is
  'Policies are deliberately unseeded until FANatical approves data-type-specific evidence and trust-tier requirements.';

-- ---------------------------------------------------------------------------
-- Generic venue identities are declared before proposals so both can be scoped
-- ---------------------------------------------------------------------------

create table if not exists public.catalog_venues (
  id uuid primary key default gen_random_uuid(),
  venue_id text not null unique check (venue_id ~ '^venue-[a-z0-9]+(?:-[a-z0-9]+)*$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.catalog_actor_capabilities
  add constraint catalog_actor_capabilities_venue_fk
  foreign key (venue_id) references public.catalog_venues(id) on delete cascade;

-- ---------------------------------------------------------------------------
-- Proposal, evidence, decision, and append-only audit machinery
-- ---------------------------------------------------------------------------

create table if not exists public.catalog_change_proposals (
  id uuid primary key default gen_random_uuid(),
  fact_type text not null check (fact_type in (
    'team_registration', 'league_registration', 'team_identity', 'team_alias',
    'team_external_identifier', 'team_location', 'team_primary_league',
    'team_colors', 'team_logo', 'team_venue_relationship',
    'venue_registration', 'venue_identity', 'venue_mapping'
  )),
  operation text not null default 'replace' check (operation in ('create', 'replace', 'retire')),
  target_team_id uuid references public.catalog_teams(id),
  target_league_id uuid references public.catalog_leagues(id),
  target_venue_id uuid references public.catalog_venues(id),
  proposed_public_id text,
  payload jsonb not null,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'withdrawn')),
  proposed_by_actor_id uuid not null references public.catalog_actors(id),
  submitted_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolution_notes text
);

create index if not exists catalog_proposals_status_idx on public.catalog_change_proposals(status, submitted_at);
create index if not exists catalog_proposals_team_idx on public.catalog_change_proposals(target_team_id, status);
create index if not exists catalog_proposals_venue_idx on public.catalog_change_proposals(target_venue_id, status);

create table if not exists public.catalog_proposal_evidence (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.catalog_change_proposals(id) on delete cascade,
  source_id uuid not null references public.trusted_sources(id),
  evidence_url text not null,
  evidence_summary text,
  observed_at timestamptz,
  supports_proposal boolean not null default true,
  submitted_by_actor_id uuid not null references public.catalog_actors(id),
  created_at timestamptz not null default now(),
  unique (proposal_id, source_id, evidence_url)
);

create table if not exists public.catalog_verification_decisions (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null unique references public.catalog_change_proposals(id),
  decision text not null check (decision in ('approved', 'rejected')),
  policy_id uuid references public.verification_policies(id),
  decided_by_actor_id uuid not null references public.catalog_actors(id),
  policy_snapshot jsonb not null default '{}'::jsonb,
  evidence_snapshot jsonb not null default '[]'::jsonb,
  notes text,
  decided_at timestamptz not null default now()
);

alter table public.catalog_team_identifiers
  add constraint catalog_team_identifiers_verification_decision_fk
  foreign key (verification_decision_id) references public.catalog_verification_decisions(id);

create table if not exists public.catalog_audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid references public.catalog_actors(id),
  auth_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  proposal_id uuid references public.catalog_change_proposals(id),
  details jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists catalog_audit_entity_idx on public.catalog_audit_events(entity_type, entity_id, occurred_at desc);
create index if not exists catalog_audit_proposal_idx on public.catalog_audit_events(proposal_id, occurred_at);

-- ---------------------------------------------------------------------------
-- Versioned mutable team and venue facts
-- effective_to is exclusive. is_current identifies the active read-model row.
-- ---------------------------------------------------------------------------

create table if not exists public.team_identity_versions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.catalog_teams(id) on delete cascade,
  display_name text not null,
  short_name text not null,
  abbreviation text,
  founded_year integer check (founded_year between 1700 and 2200),
  active boolean not null default true,
  effective_from date,
  effective_from_precision text not null default 'unknown' check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create unique index if not exists team_identity_current_idx on public.team_identity_versions(team_id) where is_current;

create table if not exists public.team_alias_versions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.catalog_teams(id) on delete cascade,
  alias text not null,
  normalized_alias text generated always as (lower(regexp_replace(trim(alias), '\s+', ' ', 'g'))) stored,
  alias_type text not null check (alias_type in ('common_name', 'short_name', 'abbreviation', 'former_name', 'other')),
  locale text,
  effective_from date,
  effective_from_precision text not null default 'unknown' check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create index if not exists team_alias_lookup_idx on public.team_alias_versions(normalized_alias) where is_current;
create unique index if not exists team_alias_current_unique_idx
on public.team_alias_versions(team_id, normalized_alias, alias_type, coalesce(locale, '')) where is_current;

create table if not exists public.team_location_versions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.catalog_teams(id) on delete cascade,
  city text,
  region text,
  country text not null,
  country_code text check (country_code is null or country_code ~ '^[A-Z]{2}$'),
  effective_from date,
  effective_from_precision text not null default 'unknown' check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create unique index if not exists team_location_current_idx on public.team_location_versions(team_id) where is_current;

create table if not exists public.team_primary_league_versions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.catalog_teams(id) on delete cascade,
  league_id uuid not null references public.catalog_leagues(id),
  conference_id text,
  division_id text,
  effective_from date,
  effective_from_precision text not null default 'unknown' check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create unique index if not exists team_primary_league_current_idx on public.team_primary_league_versions(team_id) where is_current;

create table if not exists public.team_color_versions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.catalog_teams(id) on delete cascade,
  primary_color text not null check (primary_color ~ '^#[0-9A-F]{6}$'),
  secondary_color text not null check (secondary_color ~ '^#[0-9A-F]{6}$'),
  tertiary_color text check (tertiary_color is null or tertiary_color ~ '^#[0-9A-F]{6}$'),
  quaternary_color text check (quaternary_color is null or quaternary_color ~ '^#[0-9A-F]{6}$'),
  quinary_color text check (quinary_color is null or quinary_color ~ '^#[0-9A-F]{6}$'),
  effective_from date,
  effective_from_precision text not null default 'unknown' check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create unique index if not exists team_colors_current_idx on public.team_color_versions(team_id) where is_current;

create table if not exists public.catalog_media_assets (
  id uuid primary key default gen_random_uuid(),
  asset_id text not null unique,
  storage_bucket text,
  storage_path text,
  source_url text,
  media_type text,
  rights_status text not null default 'needs_review'
    check (rights_status in ('available', 'unavailable', 'not_imported', 'needs_review', 'approved')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (storage_path is not null or source_url is not null)
);

create table if not exists public.team_logo_versions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.catalog_teams(id) on delete cascade,
  asset_id uuid not null references public.catalog_media_assets(id),
  logo_role text not null check (logo_role in ('primary', 'secondary', 'historic')),
  usage_status text not null check (usage_status in ('available', 'unavailable', 'not_imported', 'needs_review')),
  effective_from date,
  effective_from_precision text not null default 'unknown' check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create unique index if not exists team_primary_logo_current_idx
on public.team_logo_versions(team_id) where is_current and logo_role = 'primary';

create table if not exists public.venue_detail_versions (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.catalog_venues(id) on delete cascade,
  display_name text not null,
  city text,
  region text,
  country text,
  country_code text check (country_code is null or country_code ~ '^[A-Z]{2}$'),
  latitude numeric(9,6),
  longitude numeric(9,6),
  effective_from date,
  effective_from_precision text not null default 'unknown' check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create unique index if not exists venue_detail_current_idx on public.venue_detail_versions(venue_id) where is_current;

create table if not exists public.team_venue_relationship_versions (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.catalog_teams(id) on delete cascade,
  venue_id uuid not null references public.catalog_venues(id) on delete cascade,
  relationship_type text not null check (relationship_type in ('primary', 'secondary', 'alternate', 'temporary')),
  effective_from date,
  effective_from_precision text not null default 'unknown' check (effective_from_precision in ('day', 'year', 'unknown')),
  effective_to date,
  is_current boolean not null default true,
  record_status text not null check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create unique index if not exists team_primary_venue_current_idx
on public.team_venue_relationship_versions(team_id) where is_current and relationship_type = 'primary';
create unique index if not exists team_venue_relationship_current_idx
on public.team_venue_relationship_versions(team_id, venue_id, relationship_type) where is_current;

-- ---------------------------------------------------------------------------
-- Versioned generic venue mapping and range-based ticket inventory
-- ---------------------------------------------------------------------------

create table if not exists public.venue_mapping_versions (
  id uuid primary key default gen_random_uuid(),
  venue_id uuid not null references public.catalog_venues(id) on delete cascade,
  version integer not null check (version > 0),
  routing_convention_version integer not null check (routing_convention_version > 0),
  section_format text not null check (section_format in ('Numeric', 'Mixed')),
  seating_chart_image_url text,
  seating_chart_source_label text,
  seating_chart_source_url text,
  effective_from date,
  effective_to date,
  is_current boolean not null default true,
  record_status text not null check (record_status in ('imported_unverified', 'verified')),
  verification_decision_id uuid references public.catalog_verification_decisions(id),
  import_batch_id uuid references public.catalog_import_batches(id),
  created_at timestamptz not null default now(),
  superseded_at timestamptz,
  unique (venue_id, version),
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create unique index if not exists venue_mapping_current_idx on public.venue_mapping_versions(venue_id) where is_current;

create table if not exists public.venue_mapping_sections (
  id uuid primary key default gen_random_uuid(),
  mapping_version_id uuid not null references public.venue_mapping_versions(id) on delete cascade,
  section_code text not null,
  level text not null check (level in ('Upper', 'Lower', 'N/A')),
  side text not null check (side in ('Side A', 'Side B')),
  venue_end text not null check (venue_end in ('End A', 'End B')),
  unique (mapping_version_id, section_code)
);

create table if not exists public.venue_mapping_section_exceptions (
  id uuid primary key default gen_random_uuid(),
  section_id uuid not null references public.venue_mapping_sections(id) on delete cascade,
  exception_key text not null,
  row_start text,
  row_end text,
  seat_start text,
  seat_end text,
  level_override text check (level_override is null or level_override in ('Upper', 'Lower', 'N/A')),
  side_override text check (side_override is null or side_override in ('Side A', 'Side B')),
  end_override text check (end_override is null or end_override in ('End A', 'End B')),
  unique (section_id, exception_key),
  check (level_override is not null or side_override is not null or end_override is not null)
);

create table if not exists public.venue_mapping_inventory_rules (
  id uuid primary key default gen_random_uuid(),
  mapping_version_id uuid not null references public.venue_mapping_versions(id) on delete cascade,
  rule_key text not null,
  section_codes text[] not null default array[]::text[],
  levels text[] not null default array[]::text[],
  row_values jsonb not null default '{"values":[],"ranges":[]}'::jsonb,
  seat_values jsonb not null default '{"values":[],"ranges":[]}'::jsonb,
  unique (mapping_version_id, rule_key),
  check (levels <@ array['Upper','Lower','N/A']::text[])
);

create table if not exists public.venue_mapping_inventory_overrides (
  id uuid primary key default gen_random_uuid(),
  inventory_rule_id uuid not null references public.venue_mapping_inventory_rules(id) on delete cascade,
  row_start text,
  row_end text,
  seat_values jsonb not null
);

create table if not exists public.venue_mapping_team_profiles (
  id uuid primary key default gen_random_uuid(),
  mapping_version_id uuid not null references public.venue_mapping_versions(id) on delete cascade,
  team_id uuid not null references public.catalog_teams(id) on delete cascade,
  levels text[] not null,
  sides text[] not null,
  ends text[] not null,
  unique (mapping_version_id, team_id),
  check (levels <@ array['Upper','Lower','N/A']::text[]),
  check (sides <@ array['Side A','Side B']::text[]),
  check (ends <@ array['End A','End B']::text[])
);

create table if not exists public.venue_mapping_sports (
  mapping_version_id uuid not null references public.venue_mapping_versions(id) on delete cascade,
  sport_id uuid not null references public.catalog_sports(id) on delete cascade,
  primary key (mapping_version_id, sport_id)
);

-- ---------------------------------------------------------------------------
-- Mutation protection
-- ---------------------------------------------------------------------------

create or replace function public.protect_catalog_public_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and (
    old.id is distinct from new.id
    or (to_jsonb(old) ->> tg_argv[0]) is distinct from (to_jsonb(new) ->> tg_argv[0])
  ) then
    raise exception 'Catalog identities are immutable';
  end if;
  return new;
end;
$$;

drop trigger if exists catalog_sports_protect_identity on public.catalog_sports;
create trigger catalog_sports_protect_identity before update on public.catalog_sports
for each row execute function public.protect_catalog_public_identity('sport_id');
drop trigger if exists catalog_leagues_protect_identity on public.catalog_leagues;
create trigger catalog_leagues_protect_identity before update on public.catalog_leagues
for each row execute function public.protect_catalog_public_identity('league_id');
drop trigger if exists catalog_teams_protect_identity on public.catalog_teams;
create trigger catalog_teams_protect_identity before update on public.catalog_teams
for each row execute function public.protect_catalog_public_identity('team_id');
drop trigger if exists catalog_venues_protect_identity on public.catalog_venues;
create trigger catalog_venues_protect_identity before update on public.catalog_venues
for each row execute function public.protect_catalog_public_identity('venue_id');

create or replace function public.protect_verified_catalog_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and old.record_status = 'verified' then
    raise exception 'Verified catalog facts cannot be deleted';
  end if;
  if tg_op = 'UPDATE' and old.record_status = 'verified' then
    if (to_jsonb(old) - 'is_current' - 'effective_to' - 'superseded_at')
       is distinct from
       (to_jsonb(new) - 'is_current' - 'effective_to' - 'superseded_at') then
      raise exception 'Verified catalog values cannot be overwritten';
    end if;
    if old.is_current = false or new.is_current = true or new.superseded_at is null then
      raise exception 'Verified catalog facts may only transition from current to superseded';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'team_identity_versions', 'team_alias_versions', 'team_location_versions',
    'team_primary_league_versions', 'team_color_versions', 'team_logo_versions',
    'venue_detail_versions', 'team_venue_relationship_versions', 'venue_mapping_versions'
  ] loop
    execute format('drop trigger if exists protect_verified_version on public.%I', table_name);
    execute format(
      'create trigger protect_verified_version before update or delete on public.%I for each row execute function public.protect_verified_catalog_version()',
      table_name
    );
  end loop;
end $$;

create or replace function public.protect_catalog_audit_event()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Catalog audit history is append-only';
end;
$$;

drop trigger if exists catalog_audit_append_only on public.catalog_audit_events;
create trigger catalog_audit_append_only before update or delete on public.catalog_audit_events
for each row execute function public.protect_catalog_audit_event();

-- Existing shared updated-at trigger function is reused.
drop trigger if exists catalog_sports_set_updated_at on public.catalog_sports;
create trigger catalog_sports_set_updated_at before update on public.catalog_sports for each row execute function public.set_updated_at();
drop trigger if exists catalog_leagues_set_updated_at on public.catalog_leagues;
create trigger catalog_leagues_set_updated_at before update on public.catalog_leagues for each row execute function public.set_updated_at();
drop trigger if exists catalog_teams_set_updated_at on public.catalog_teams;
create trigger catalog_teams_set_updated_at before update on public.catalog_teams for each row execute function public.set_updated_at();
drop trigger if exists catalog_venues_set_updated_at on public.catalog_venues;
create trigger catalog_venues_set_updated_at before update on public.catalog_venues for each row execute function public.set_updated_at();
drop trigger if exists catalog_actors_set_updated_at on public.catalog_actors;
create trigger catalog_actors_set_updated_at before update on public.catalog_actors for each row execute function public.set_updated_at();
drop trigger if exists source_groups_set_updated_at on public.source_independence_groups;
create trigger source_groups_set_updated_at before update on public.source_independence_groups for each row execute function public.set_updated_at();
drop trigger if exists trusted_sources_set_updated_at on public.trusted_sources;
create trigger trusted_sources_set_updated_at before update on public.trusted_sources for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Authorization helpers and admin actor/capability management
-- ---------------------------------------------------------------------------

create or replace function public.current_catalog_actor_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select actor.id
  from public.catalog_actors actor
  where actor.auth_user_id = auth.uid() and actor.active
  limit 1;
$$;

create or replace function public.has_catalog_capability(
  required_capability text,
  required_sport_id uuid default null,
  required_league_id uuid default null,
  required_team_id uuid default null,
  required_venue_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.catalog_actors actor
    join public.catalog_actor_capabilities capability on capability.actor_id = actor.id
    where actor.auth_user_id = auth.uid()
      and actor.active
      and capability.active
      and capability.capability in (required_capability, '*')
      and (capability.sport_id is null or capability.sport_id = required_sport_id)
      and (capability.league_id is null or capability.league_id = required_league_id)
      and (capability.team_id is null or capability.team_id = required_team_id)
      and (capability.venue_id is null or capability.venue_id = required_venue_id)
  );
$$;

create or replace function public.admin_upsert_catalog_actor(
  actor_key_value text,
  actor_type_value text,
  auth_user_id_value uuid,
  display_name_value text,
  active_value boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare result_id uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null) then
    raise exception 'Admin access is required';
  end if;
  if actor_type_value not in ('human', 'agent', 'service') then raise exception 'Invalid actor type'; end if;
  insert into public.catalog_actors(actor_key, actor_type, auth_user_id, display_name, active)
  values (actor_key_value, actor_type_value, auth_user_id_value, display_name_value, active_value)
  on conflict (actor_key) do update set
    actor_type = excluded.actor_type,
    auth_user_id = excluded.auth_user_id,
    display_name = excluded.display_name,
    active = excluded.active
  returning id into result_id;
  return result_id;
end;
$$;

create or replace function public.admin_grant_catalog_capability(
  actor_key_value text,
  capability_value text,
  sport_public_id text default null,
  league_public_id text default null,
  team_public_id text default null,
  venue_public_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_record public.catalog_actors%rowtype;
  sport_uuid uuid;
  league_uuid uuid;
  team_uuid uuid;
  venue_uuid uuid;
  result_id uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null) then raise exception 'Admin access is required'; end if;
  select * into actor_record from public.catalog_actors where actor_key = actor_key_value;
  if not found then raise exception 'Unknown catalog actor'; end if;
  if sport_public_id is not null then select id into strict sport_uuid from public.catalog_sports where sport_id = sport_public_id; end if;
  if league_public_id is not null then select id into strict league_uuid from public.catalog_leagues where league_id = league_public_id; end if;
  if team_public_id is not null then select id into strict team_uuid from public.catalog_teams where team_id = team_public_id; end if;
  if venue_public_id is not null then select id into strict venue_uuid from public.catalog_venues where venue_id = venue_public_id; end if;

  select id into result_id
  from public.catalog_actor_capabilities
  where actor_id = actor_record.id
    and capability = capability_value
    and sport_id is not distinct from sport_uuid
    and league_id is not distinct from league_uuid
    and team_id is not distinct from team_uuid
    and venue_id is not distinct from venue_uuid;

  if result_id is null then
    insert into public.catalog_actor_capabilities(actor_id, capability, sport_id, league_id, team_id, venue_id, granted_by)
    values (actor_record.id, capability_value, sport_uuid, league_uuid, team_uuid, venue_uuid, auth.uid())
    returning id into result_id;
  else
    update public.catalog_actor_capabilities set active = true, granted_by = auth.uid() where id = result_id;
  end if;
  return result_id;
end;
$$;

create or replace function public.admin_upsert_source_independence_group(
  group_id_value text,
  display_name_value text,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare result_id uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null) then raise exception 'Admin access is required'; end if;
  insert into public.source_independence_groups(group_id, display_name, notes)
  values (group_id_value, display_name_value, notes_value)
  on conflict (group_id) do update set display_name = excluded.display_name, notes = excluded.notes
  returning id into result_id;
  return result_id;
end;
$$;

create or replace function public.admin_upsert_trusted_source(
  source_id_value text,
  display_name_value text,
  base_url_value text default null,
  reference_url_value text default null,
  independence_group_value text default null,
  review_status_value text default 'pending_review',
  notes_value text default null,
  metadata_value jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare group_uuid uuid; result_id uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null) then raise exception 'Admin access is required'; end if;
  if independence_group_value is not null then
    select id into strict group_uuid from public.source_independence_groups where group_id = independence_group_value;
  end if;
  insert into public.trusted_sources(
    source_id, display_name, base_url, reference_url, independence_group_id,
    review_status, notes, metadata
  ) values (
    source_id_value, display_name_value, base_url_value, reference_url_value,
    group_uuid, review_status_value, notes_value, coalesce(metadata_value, '{}'::jsonb)
  ) on conflict (source_id) do update set
    display_name = excluded.display_name,
    base_url = excluded.base_url,
    reference_url = excluded.reference_url,
    independence_group_id = excluded.independence_group_id,
    review_status = excluded.review_status,
    notes = excluded.notes,
    metadata = excluded.metadata
  returning id into result_id;
  return result_id;
end;
$$;

create or replace function public.admin_set_source_trust(
  source_registry_id text,
  data_type_value text,
  trust_tier_value smallint,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare source_uuid uuid; result_id uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null) then raise exception 'Admin access is required'; end if;
  select id into strict source_uuid from public.trusted_sources where source_id = source_registry_id;
  update public.source_trust_assignments
  set is_current = false, effective_to = current_date, superseded_at = now()
  where source_id = source_uuid and data_type = data_type_value and is_current;
  insert into public.source_trust_assignments(source_id, data_type, trust_tier, effective_from, notes)
  values (source_uuid, data_type_value, trust_tier_value, current_date, notes_value)
  returning id into result_id;
  return result_id;
end;
$$;

create or replace function public.admin_create_verification_policy(
  policy_key_value text,
  data_type_value text,
  minimum_evidence_count_value integer,
  allowed_trust_tiers_value smallint[],
  require_independent_sources_value boolean default true,
  require_independent_verifier_value boolean default true,
  configuration_value jsonb default '{}'::jsonb,
  activate_value boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare next_version integer; result_id uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null) then raise exception 'Admin access is required'; end if;
  select coalesce(max(version), 0) + 1 into next_version from public.verification_policies where policy_key = policy_key_value;
  if activate_value then
    update public.verification_policies
    set is_current = false, active = false, superseded_at = now()
    where data_type = data_type_value and is_current and active;
  end if;
  insert into public.verification_policies(
    policy_key, version, data_type, minimum_evidence_count, allowed_trust_tiers,
    require_independent_sources, require_independent_verifier, configuration,
    is_current, active
  ) values (
    policy_key_value, next_version, data_type_value, minimum_evidence_count_value,
    allowed_trust_tiers_value, require_independent_sources_value,
    require_independent_verifier_value, coalesce(configuration_value, '{}'::jsonb),
    activate_value, activate_value
  ) returning id into result_id;
  return result_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Proposal submission and evidence RPCs
-- ---------------------------------------------------------------------------

create or replace function public.resolve_catalog_team_id(identifier_value text)
returns uuid
language sql
stable
security invoker
set search_path = ''
as $$
  select team.id from public.catalog_teams team where team.team_id = identifier_value
  union all
  select external_id.team_id from public.catalog_team_identifiers external_id where external_id.identifier = identifier_value
  limit 1;
$$;

create or replace function public.submit_catalog_proposal(
  fact_type_value text,
  payload_value jsonb,
  team_identifier text default null,
  league_identifier text default null,
  venue_identifier text default null,
  operation_value text default 'replace'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  team_uuid uuid;
  league_uuid uuid;
  venue_uuid uuid;
  sport_uuid uuid;
  result_id uuid;
begin
  if actor_uuid is null then raise exception 'An active catalog actor is required'; end if;
  if team_identifier is not null then team_uuid := public.resolve_catalog_team_id(team_identifier); end if;
  if league_identifier is not null then select id into league_uuid from public.catalog_leagues where league_id = league_identifier; end if;
  if venue_identifier is not null then select id into venue_uuid from public.catalog_venues where venue_id = venue_identifier; end if;
  if team_identifier is not null and team_uuid is null then raise exception 'Unknown team identifier'; end if;
  if league_identifier is not null and league_uuid is null then raise exception 'Unknown league identifier'; end if;
  if venue_identifier is not null and venue_uuid is null then raise exception 'Unknown venue identifier'; end if;

  select coalesce(team.sport_id, league.sport_id) into sport_uuid
  from (select team_uuid as id) requested
  left join public.catalog_teams team on team.id = requested.id
  left join public.catalog_leagues league on league.id = league_uuid;

  if sport_uuid is null and payload_value ? 'sport_id' then
    select id into sport_uuid from public.catalog_sports where sport_id = payload_value ->> 'sport_id';
  end if;

  if not public.has_catalog_capability('catalog.propose.' || fact_type_value, sport_uuid, league_uuid, team_uuid, venue_uuid)
     and not public.has_catalog_capability('catalog.propose', sport_uuid, league_uuid, team_uuid, venue_uuid) then
    raise exception 'The catalog actor lacks proposal capability for this scope';
  end if;

  insert into public.catalog_change_proposals(
    fact_type, operation, target_team_id, target_league_id, target_venue_id,
    proposed_public_id, payload, proposed_by_actor_id
  ) values (
    fact_type_value, operation_value, team_uuid, league_uuid, venue_uuid,
    nullif(payload_value ->> 'public_id', ''), payload_value, actor_uuid
  ) returning id into result_id;

  insert into public.catalog_audit_events(actor_id, auth_user_id, action, entity_type, entity_id, proposal_id)
  values (actor_uuid, auth.uid(), 'proposal.submitted', fact_type_value,
    coalesce(team_identifier, league_identifier, venue_identifier, payload_value ->> 'public_id'), result_id);
  return result_id;
end;
$$;

create or replace function public.submit_team_registration_proposal(payload_value jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  sport_record public.catalog_sports%rowtype;
  sequence_record public.catalog_team_id_sequences%rowtype;
  allocated_team_id text;
begin
  select * into strict sport_record from public.catalog_sports where sport_id = payload_value ->> 'sport_id';
  select * into strict sequence_record from public.catalog_team_id_sequences where sport_id = sport_record.id for update;
  allocated_team_id := sport_record.sport_id || '-' || lpad(sequence_record.next_value::text, 6, '0');
  update public.catalog_team_id_sequences set next_value = next_value + 1 where sport_id = sport_record.id;
  return public.submit_catalog_proposal(
    'team_registration', payload_value || jsonb_build_object('public_id', allocated_team_id),
    null, null, null, 'create'
  );
end;
$$;

create or replace function public.add_catalog_proposal_evidence(
  proposal_id_value uuid,
  source_registry_id text,
  evidence_url_value text,
  evidence_summary_value text default null,
  observed_at_value timestamptz default null,
  supports_proposal_value boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  proposal_record public.catalog_change_proposals%rowtype;
  source_uuid uuid;
  result_id uuid;
begin
  if actor_uuid is null then raise exception 'An active catalog actor is required'; end if;
  select * into proposal_record from public.catalog_change_proposals where id = proposal_id_value;
  if not found or proposal_record.status <> 'pending' then raise exception 'A pending proposal is required'; end if;
  if proposal_record.proposed_by_actor_id <> actor_uuid
     and not public.has_catalog_capability('catalog.evidence.add', null, proposal_record.target_league_id, proposal_record.target_team_id, proposal_record.target_venue_id) then
    raise exception 'The catalog actor cannot add evidence to this proposal';
  end if;
  select id into source_uuid from public.trusted_sources where source_id = source_registry_id;
  if source_uuid is null then raise exception 'Unknown Trusted Source Registry ID'; end if;
  insert into public.catalog_proposal_evidence(
    proposal_id, source_id, evidence_url, evidence_summary, observed_at,
    supports_proposal, submitted_by_actor_id
  ) values (
    proposal_id_value, source_uuid, evidence_url_value, evidence_summary_value,
    observed_at_value, supports_proposal_value, actor_uuid
  ) returning id into result_id;
  insert into public.catalog_audit_events(actor_id, auth_user_id, action, entity_type, entity_id, proposal_id)
  values (actor_uuid, auth.uid(), 'proposal.evidence_added', 'catalog_proposal', proposal_id_value::text, proposal_id_value);
  return result_id;
end;
$$;

create or replace function public.withdraw_my_catalog_proposal(proposal_id_value uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare actor_uuid uuid := public.current_catalog_actor_id();
begin
  update public.catalog_change_proposals
  set status = 'withdrawn', resolved_at = now(), resolution_notes = 'Withdrawn by proposer'
  where id = proposal_id_value and status = 'pending' and proposed_by_actor_id = actor_uuid;
  if not found then raise exception 'Pending proposal owned by this actor was not found'; end if;
  insert into public.catalog_audit_events(actor_id, auth_user_id, action, entity_type, entity_id, proposal_id)
  values (actor_uuid, auth.uid(), 'proposal.withdrawn', 'catalog_proposal', proposal_id_value::text, proposal_id_value);
end;
$$;

-- ---------------------------------------------------------------------------
-- Atomic verification and promotion
-- ---------------------------------------------------------------------------

create or replace function public.review_catalog_proposal(
  proposal_id_value uuid,
  decision_value text,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  reviewer_uuid uuid := public.current_catalog_actor_id();
  proposal_record public.catalog_change_proposals%rowtype;
  policy_record public.verification_policies%rowtype;
  decision_uuid uuid;
  qualified_evidence_count integer;
  independent_group_count integer;
  evidence_snapshot_value jsonb;
  scope_sport_uuid uuid;
  new_team_uuid uuid;
  new_league_uuid uuid;
  new_venue_uuid uuid;
  new_mapping_uuid uuid;
  inventory_rule_uuid uuid;
  item jsonb;
  override_item jsonb;
  section_uuid uuid;
  effective_date date;
begin
  if reviewer_uuid is null then raise exception 'An active catalog actor is required'; end if;
  if decision_value not in ('approved', 'rejected') then raise exception 'Decision must be approved or rejected'; end if;
  select * into proposal_record from public.catalog_change_proposals where id = proposal_id_value for update;
  if not found or proposal_record.status <> 'pending' then raise exception 'A pending proposal is required'; end if;
  select coalesce(team.sport_id, league.sport_id) into scope_sport_uuid
  from (select proposal_record.target_team_id as id) requested
  left join public.catalog_teams team on team.id = requested.id
  left join public.catalog_leagues league on league.id = proposal_record.target_league_id;
  if scope_sport_uuid is null and proposal_record.payload ? 'sport_id' then
    select id into scope_sport_uuid from public.catalog_sports where sport_id = proposal_record.payload ->> 'sport_id';
  end if;
  if not public.has_catalog_capability('catalog.verify.' || proposal_record.fact_type, scope_sport_uuid, proposal_record.target_league_id, proposal_record.target_team_id, proposal_record.target_venue_id)
     and not public.has_catalog_capability('catalog.verify', scope_sport_uuid, proposal_record.target_league_id, proposal_record.target_team_id, proposal_record.target_venue_id) then
    raise exception 'The catalog actor lacks verification capability for this scope';
  end if;

  if decision_value = 'approved' then
    select * into policy_record from public.verification_policies
    where data_type = proposal_record.fact_type and is_current and active;
    if not found then raise exception 'No active verification policy exists for %', proposal_record.fact_type; end if;
    if policy_record.require_independent_verifier and proposal_record.proposed_by_actor_id = reviewer_uuid then
      raise exception 'This policy requires a verifier other than the proposal builder';
    end if;

    select count(distinct evidence.id), count(distinct source.independence_group_id)
      into qualified_evidence_count, independent_group_count
    from public.catalog_proposal_evidence evidence
    join public.trusted_sources source on source.id = evidence.source_id
    join public.source_trust_assignments trust on trust.source_id = source.id
      and trust.data_type = proposal_record.fact_type and trust.is_current
    where evidence.proposal_id = proposal_id_value
      and evidence.supports_proposal
      and source.review_status = 'approved'
      and trust.trust_tier = any(policy_record.allowed_trust_tiers);

    if qualified_evidence_count < policy_record.minimum_evidence_count then
      raise exception 'Proposal has % qualifying evidence rows; policy requires %', qualified_evidence_count, policy_record.minimum_evidence_count;
    end if;
    if policy_record.require_independent_sources
       and independent_group_count < policy_record.minimum_evidence_count then
      raise exception 'Proposal does not have enough independent source groups';
    end if;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'source_id', source.source_id,
    'independence_group_id', group_record.group_id,
    'evidence_url', evidence.evidence_url,
    'observed_at', evidence.observed_at,
    'supports_proposal', evidence.supports_proposal,
    'trust_tier', trust.trust_tier
  ) order by evidence.created_at), '[]'::jsonb)
  into evidence_snapshot_value
  from public.catalog_proposal_evidence evidence
  join public.trusted_sources source on source.id = evidence.source_id
  left join public.source_independence_groups group_record on group_record.id = source.independence_group_id
  left join public.source_trust_assignments trust on trust.source_id = source.id
    and trust.data_type = proposal_record.fact_type and trust.is_current
  where evidence.proposal_id = proposal_id_value;

  insert into public.catalog_verification_decisions(
    proposal_id, decision, policy_id, decided_by_actor_id, policy_snapshot,
    evidence_snapshot, notes
  ) values (
    proposal_id_value, decision_value,
    case when decision_value = 'approved' then policy_record.id else null end,
    reviewer_uuid,
    case when decision_value = 'approved' then jsonb_build_object(
      'policy_key', policy_record.policy_key,
      'version', policy_record.version,
      'minimum_evidence_count', policy_record.minimum_evidence_count,
      'allowed_trust_tiers', policy_record.allowed_trust_tiers,
      'require_independent_sources', policy_record.require_independent_sources,
      'require_independent_verifier', policy_record.require_independent_verifier,
      'configuration', policy_record.configuration
    ) else '{}'::jsonb end,
    evidence_snapshot_value, notes_value
  ) returning id into decision_uuid;

  if decision_value = 'rejected' then
    update public.catalog_change_proposals set status = 'rejected', resolved_at = now(), resolution_notes = notes_value where id = proposal_id_value;
    insert into public.catalog_audit_events(actor_id, auth_user_id, action, entity_type, entity_id, proposal_id, details)
    values (reviewer_uuid, auth.uid(), 'proposal.rejected', proposal_record.fact_type, coalesce(proposal_record.target_team_id, proposal_record.target_league_id, proposal_record.target_venue_id)::text, proposal_id_value, jsonb_build_object('decision_id', decision_uuid));
    return decision_uuid;
  end if;

  effective_date := nullif(proposal_record.payload ->> 'effective_from', '')::date;

  case proposal_record.fact_type
    when 'team_registration' then
      select id into new_team_uuid from public.catalog_teams where team_id = proposal_record.proposed_public_id;
      if new_team_uuid is not null then raise exception 'Public team ID already exists'; end if;
      select id into strict new_team_uuid from public.catalog_sports where sport_id = proposal_record.payload ->> 'sport_id';
      insert into public.catalog_teams(team_id, sport_id)
      values (proposal_record.proposed_public_id, new_team_uuid)
      returning id into new_team_uuid;
      insert into public.team_identity_versions(
        team_id, display_name, short_name, abbreviation, founded_year, active,
        effective_from, effective_from_precision, record_status, verification_decision_id
      ) values (
        new_team_uuid, proposal_record.payload ->> 'display_name',
        coalesce(nullif(proposal_record.payload ->> 'short_name', ''), proposal_record.payload ->> 'display_name'),
        nullif(proposal_record.payload ->> 'abbreviation', ''),
        nullif(proposal_record.payload ->> 'founded_year', '')::integer,
        coalesce((proposal_record.payload ->> 'active')::boolean, true), effective_date,
        coalesce(nullif(proposal_record.payload ->> 'effective_from_precision', ''), 'unknown'),
        'verified', decision_uuid
      );

    when 'league_registration' then
      select id into strict new_team_uuid from public.catalog_sports where sport_id = proposal_record.payload ->> 'sport_id';
      insert into public.catalog_leagues(league_id, sport_id, display_name, short_name, active, seed_status)
      values (proposal_record.proposed_public_id, new_team_uuid, proposal_record.payload ->> 'display_name',
        nullif(proposal_record.payload ->> 'short_name', ''), coalesce((proposal_record.payload ->> 'active')::boolean, true), 'verified')
      returning id into new_league_uuid;

    when 'team_identity' then
      update public.team_identity_versions set is_current = false, effective_to = effective_date, superseded_at = now()
      where team_id = proposal_record.target_team_id and is_current;
      insert into public.team_identity_versions(
        team_id, display_name, short_name, abbreviation, founded_year, active,
        effective_from, effective_from_precision, record_status, verification_decision_id
      ) values (
        proposal_record.target_team_id, proposal_record.payload ->> 'display_name',
        coalesce(nullif(proposal_record.payload ->> 'short_name', ''), proposal_record.payload ->> 'display_name'),
        nullif(proposal_record.payload ->> 'abbreviation', ''),
        nullif(proposal_record.payload ->> 'founded_year', '')::integer,
        coalesce((proposal_record.payload ->> 'active')::boolean, true), effective_date,
        coalesce(nullif(proposal_record.payload ->> 'effective_from_precision', ''), 'unknown'),
        'verified', decision_uuid
      );

    when 'team_alias' then
      insert into public.team_alias_versions(
        team_id, alias, alias_type, locale, effective_from, effective_from_precision,
        record_status, verification_decision_id
      ) values (
        proposal_record.target_team_id, proposal_record.payload ->> 'alias', proposal_record.payload ->> 'alias_type',
        nullif(proposal_record.payload ->> 'locale', ''), effective_date,
        coalesce(nullif(proposal_record.payload ->> 'effective_from_precision', ''), 'unknown'), 'verified', decision_uuid
      );

    when 'team_external_identifier' then
      insert into public.catalog_team_identifiers(team_id, namespace, identifier, record_status, verification_decision_id)
      values (proposal_record.target_team_id, proposal_record.payload ->> 'namespace', proposal_record.payload ->> 'identifier', 'verified', decision_uuid);

    when 'team_location' then
      update public.team_location_versions set is_current = false, effective_to = effective_date, superseded_at = now()
      where team_id = proposal_record.target_team_id and is_current;
      insert into public.team_location_versions(
        team_id, city, region, country, country_code, effective_from,
        effective_from_precision, record_status, verification_decision_id
      ) values (
        proposal_record.target_team_id, nullif(proposal_record.payload ->> 'city', ''),
        nullif(proposal_record.payload ->> 'region', ''), proposal_record.payload ->> 'country',
        nullif(proposal_record.payload ->> 'country_code', ''), effective_date,
        coalesce(nullif(proposal_record.payload ->> 'effective_from_precision', ''), 'unknown'), 'verified', decision_uuid
      );

    when 'team_primary_league' then
      select id into strict new_league_uuid from public.catalog_leagues where league_id = proposal_record.payload ->> 'league_id';
      if (select sport_id from public.catalog_leagues where id = new_league_uuid) <> (select sport_id from public.catalog_teams where id = proposal_record.target_team_id) then
        raise exception 'Team and primary league must belong to the same sport';
      end if;
      update public.team_primary_league_versions set is_current = false, effective_to = effective_date, superseded_at = now()
      where team_id = proposal_record.target_team_id and is_current;
      insert into public.team_primary_league_versions(
        team_id, league_id, conference_id, division_id, effective_from,
        effective_from_precision, record_status, verification_decision_id
      ) values (
        proposal_record.target_team_id, new_league_uuid,
        nullif(proposal_record.payload ->> 'conference_id', ''), nullif(proposal_record.payload ->> 'division_id', ''),
        effective_date, coalesce(nullif(proposal_record.payload ->> 'effective_from_precision', ''), 'unknown'), 'verified', decision_uuid
      );

    when 'team_colors' then
      update public.team_color_versions set is_current = false, effective_to = effective_date, superseded_at = now()
      where team_id = proposal_record.target_team_id and is_current;
      insert into public.team_color_versions(
        team_id, primary_color, secondary_color, tertiary_color, quaternary_color,
        quinary_color, effective_from, effective_from_precision, record_status,
        verification_decision_id
      ) values (
        proposal_record.target_team_id, upper(proposal_record.payload ->> 'primary'), upper(proposal_record.payload ->> 'secondary'),
        upper(nullif(proposal_record.payload ->> 'tertiary', '')), upper(nullif(proposal_record.payload ->> 'quaternary', '')),
        upper(nullif(proposal_record.payload ->> 'quinary', '')), effective_date,
        coalesce(nullif(proposal_record.payload ->> 'effective_from_precision', ''), 'unknown'), 'verified', decision_uuid
      );

    when 'team_logo' then
      select id into strict new_team_uuid from public.catalog_media_assets where asset_id = proposal_record.payload ->> 'asset_id';
      if proposal_record.payload ->> 'logo_role' = 'primary' then
        update public.team_logo_versions set is_current = false, effective_to = effective_date, superseded_at = now()
        where team_id = proposal_record.target_team_id and is_current and logo_role = 'primary';
      end if;
      insert into public.team_logo_versions(
        team_id, asset_id, logo_role, usage_status, effective_from,
        effective_from_precision, record_status, verification_decision_id
      ) values (
        proposal_record.target_team_id, new_team_uuid, proposal_record.payload ->> 'logo_role',
        proposal_record.payload ->> 'usage_status', effective_date,
        coalesce(nullif(proposal_record.payload ->> 'effective_from_precision', ''), 'unknown'), 'verified', decision_uuid
      );

    when 'team_venue_relationship' then
      select id into strict new_venue_uuid from public.catalog_venues where venue_id = proposal_record.payload ->> 'venue_id';
      if proposal_record.payload ->> 'relationship_type' = 'primary' then
        update public.team_venue_relationship_versions set is_current = false, effective_to = effective_date, superseded_at = now()
        where team_id = proposal_record.target_team_id and is_current and relationship_type = 'primary';
      else
        update public.team_venue_relationship_versions set is_current = false, effective_to = effective_date, superseded_at = now()
        where team_id = proposal_record.target_team_id and venue_id = new_venue_uuid
          and relationship_type = proposal_record.payload ->> 'relationship_type' and is_current;
      end if;
      insert into public.team_venue_relationship_versions(
        team_id, venue_id, relationship_type, effective_from, effective_from_precision,
        record_status, verification_decision_id
      ) values (
        proposal_record.target_team_id, new_venue_uuid, proposal_record.payload ->> 'relationship_type',
        effective_date, coalesce(nullif(proposal_record.payload ->> 'effective_from_precision', ''), 'unknown'), 'verified', decision_uuid
      );

    when 'venue_registration' then
      insert into public.catalog_venues(venue_id) values (proposal_record.proposed_public_id) returning id into new_venue_uuid;
      insert into public.venue_detail_versions(
        venue_id, display_name, city, region, country, country_code, latitude,
        longitude, effective_from, effective_from_precision, record_status,
        verification_decision_id
      ) values (
        new_venue_uuid, proposal_record.payload ->> 'display_name', nullif(proposal_record.payload ->> 'city', ''),
        nullif(proposal_record.payload ->> 'region', ''), nullif(proposal_record.payload ->> 'country', ''),
        nullif(proposal_record.payload ->> 'country_code', ''), nullif(proposal_record.payload ->> 'latitude', '')::numeric,
        nullif(proposal_record.payload ->> 'longitude', '')::numeric, effective_date,
        coalesce(nullif(proposal_record.payload ->> 'effective_from_precision', ''), 'unknown'), 'verified', decision_uuid
      );

    when 'venue_identity' then
      update public.venue_detail_versions set is_current = false, effective_to = effective_date, superseded_at = now()
      where venue_id = proposal_record.target_venue_id and is_current;
      insert into public.venue_detail_versions(
        venue_id, display_name, city, region, country, country_code, latitude,
        longitude, effective_from, effective_from_precision, record_status,
        verification_decision_id
      ) values (
        proposal_record.target_venue_id, proposal_record.payload ->> 'display_name', nullif(proposal_record.payload ->> 'city', ''),
        nullif(proposal_record.payload ->> 'region', ''), nullif(proposal_record.payload ->> 'country', ''),
        nullif(proposal_record.payload ->> 'country_code', ''), nullif(proposal_record.payload ->> 'latitude', '')::numeric,
        nullif(proposal_record.payload ->> 'longitude', '')::numeric, effective_date,
        coalesce(nullif(proposal_record.payload ->> 'effective_from_precision', ''), 'unknown'), 'verified', decision_uuid
      );

    when 'venue_mapping' then
      update public.venue_mapping_versions set is_current = false, effective_to = effective_date, superseded_at = now()
      where venue_id = proposal_record.target_venue_id and is_current;
      insert into public.venue_mapping_versions(
        venue_id, version, routing_convention_version, section_format,
        seating_chart_image_url, seating_chart_source_label, seating_chart_source_url,
        effective_from, record_status, verification_decision_id
      ) values (
        proposal_record.target_venue_id,
        coalesce((select max(version) + 1 from public.venue_mapping_versions where venue_id = proposal_record.target_venue_id), 1),
        (proposal_record.payload ->> 'routing_convention_version')::integer,
        proposal_record.payload ->> 'section_format', nullif(proposal_record.payload ->> 'seating_chart_image_url', ''),
        nullif(proposal_record.payload ->> 'seating_chart_source_label', ''), nullif(proposal_record.payload ->> 'seating_chart_source_url', ''),
        effective_date, 'verified', decision_uuid
      ) returning id into new_mapping_uuid;

      for item in select value from jsonb_array_elements(coalesce(proposal_record.payload -> 'sections', '[]'::jsonb)) loop
        insert into public.venue_mapping_sections(mapping_version_id, section_code, level, side, venue_end)
        values (new_mapping_uuid, item ->> 'section', item ->> 'level', item ->> 'side', item ->> 'end')
        returning id into section_uuid;
        insert into public.venue_mapping_section_exceptions(
          section_id, exception_key, row_start, row_end, seat_start, seat_end,
          level_override, side_override, end_override
        ) select section_uuid, exception_item ->> 'id', nullif(exception_item ->> 'row_start', ''),
          nullif(exception_item ->> 'row_end', ''), nullif(exception_item ->> 'seat_start', ''),
          nullif(exception_item ->> 'seat_end', ''), nullif(exception_item ->> 'level', ''),
          nullif(exception_item ->> 'side', ''), nullif(exception_item ->> 'end', '')
        from jsonb_array_elements(coalesce(item -> 'exceptions', '[]'::jsonb)) exception_item;
      end loop;

      for item in select value from jsonb_array_elements(coalesce(proposal_record.payload -> 'inventory_rules', '[]'::jsonb)) loop
        insert into public.venue_mapping_inventory_rules(
          mapping_version_id, rule_key, section_codes, levels, row_values, seat_values
        ) values (
          new_mapping_uuid, item ->> 'id',
          array(select jsonb_array_elements_text(coalesce(item -> 'sections', '[]'::jsonb))),
          array(select jsonb_array_elements_text(coalesce(item -> 'levels', '[]'::jsonb))),
          coalesce(item -> 'rows', '{"values":[],"ranges":[]}'::jsonb),
          coalesce(item -> 'seats', '{"values":[],"ranges":[]}'::jsonb)
        ) returning id into inventory_rule_uuid;
        for override_item in select value from jsonb_array_elements(coalesce(item -> 'row_seat_overrides', '[]'::jsonb)) loop
          insert into public.venue_mapping_inventory_overrides(
            inventory_rule_id, row_start, row_end, seat_values
          ) values (
            inventory_rule_uuid, nullif(override_item ->> 'row_start', ''),
            nullif(override_item ->> 'row_end', ''), override_item -> 'seats'
          );
        end loop;
      end loop;

      insert into public.venue_mapping_team_profiles(mapping_version_id, team_id, levels, sides, ends)
      select new_mapping_uuid, public.resolve_catalog_team_id(profile_item ->> 'team_id'),
        array(select jsonb_array_elements_text(profile_item -> 'levels')),
        array(select jsonb_array_elements_text(profile_item -> 'sides')),
        array(select jsonb_array_elements_text(profile_item -> 'ends'))
      from jsonb_array_elements(coalesce(proposal_record.payload -> 'team_profiles', '[]'::jsonb)) profile_item;

      insert into public.venue_mapping_sports(mapping_version_id, sport_id)
      select new_mapping_uuid, sport.id
      from jsonb_array_elements_text(coalesce(proposal_record.payload -> 'sport_ids', '[]'::jsonb)) requested(sport_id)
      join public.catalog_sports sport on sport.sport_id = requested.sport_id;
  end case;

  update public.catalog_change_proposals set status = 'approved', resolved_at = now(), resolution_notes = notes_value where id = proposal_id_value;
  insert into public.catalog_audit_events(actor_id, auth_user_id, action, entity_type, entity_id, proposal_id, details)
  values (reviewer_uuid, auth.uid(), 'proposal.approved_and_promoted', proposal_record.fact_type,
    coalesce(proposal_record.target_team_id, proposal_record.target_league_id, proposal_record.target_venue_id, new_team_uuid, new_league_uuid, new_venue_uuid)::text,
    proposal_id_value, jsonb_build_object('decision_id', decision_uuid));
  return decision_uuid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Computed public read models
-- ---------------------------------------------------------------------------

create or replace view public.team_catalog_read_model
with (security_invoker = true)
as
select
  team.id as internal_id,
  team.team_id,
  sport.sport_id,
  sport.display_name as sport_name,
  identity_record.display_name,
  identity_record.short_name,
  identity_record.abbreviation,
  identity_record.founded_year,
  identity_record.active,
  identity_record.record_status as identity_status,
  league.league_id as primary_league_id,
  league.display_name as primary_league_name,
  league.short_name as primary_league_short_name,
  membership.conference_id,
  membership.division_id,
  membership.record_status as primary_league_status,
  location_record.city,
  location_record.region,
  location_record.country,
  location_record.country_code,
  location_record.record_status as location_status,
  colors.primary_color,
  colors.secondary_color,
  colors.tertiary_color,
  colors.quaternary_color,
  colors.quinary_color,
  colors.record_status as colors_status,
  coalesce((
    select jsonb_agg(jsonb_build_object('namespace', external_id.namespace, 'identifier', external_id.identifier) order by external_id.namespace, external_id.identifier)
    from public.catalog_team_identifiers external_id where external_id.team_id = team.id
  ), '[]'::jsonb) as external_identifiers
from public.catalog_teams team
join public.catalog_sports sport on sport.id = team.sport_id
left join public.team_identity_versions identity_record on identity_record.team_id = team.id and identity_record.is_current
left join public.team_primary_league_versions membership on membership.team_id = team.id and membership.is_current
left join public.catalog_leagues league on league.id = membership.league_id
left join public.team_location_versions location_record on location_record.team_id = team.id and location_record.is_current
left join public.team_color_versions colors on colors.team_id = team.id and colors.is_current;

create or replace view public.team_readiness
with (security_invoker = true)
as
select
  team.id as internal_id,
  team.team_id,
  (
    identity_record.record_status = 'verified'
    and membership.record_status = 'verified'
  ) as catalog_ready,
  (
    identity_record.record_status = 'verified'
    and membership.record_status = 'verified'
    and primary_venue.record_status = 'verified'
    and mapping.record_status = 'verified'
  ) as live_cheer_ready,
  array_remove(array[
    case when identity_record.id is null then 'identity' when identity_record.record_status <> 'verified' then 'verified_identity' end,
    case when membership.id is null then 'primary_league' when membership.record_status <> 'verified' then 'verified_primary_league' end
  ], null) as catalog_missing_requirements,
  array_remove(array[
    case when primary_venue.id is null then 'primary_venue' when primary_venue.record_status <> 'verified' then 'verified_primary_venue' end,
    case when primary_venue.id is not null and mapping.id is null then 'venue_mapping'
         when mapping.id is not null and mapping.record_status <> 'verified' then 'verified_venue_mapping' end
  ], null) as live_cheer_missing_requirements
from public.catalog_teams team
left join public.team_identity_versions identity_record on identity_record.team_id = team.id and identity_record.is_current
left join public.team_primary_league_versions membership on membership.team_id = team.id and membership.is_current
left join public.team_venue_relationship_versions primary_venue
  on primary_venue.team_id = team.id and primary_venue.is_current and primary_venue.relationship_type = 'primary'
left join public.venue_mapping_versions mapping on mapping.venue_id = primary_venue.venue_id and mapping.is_current;

create or replace function public.get_team_record(team_identifier text)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with target as (
    select public.resolve_catalog_team_id(team_identifier) as id
  )
  select jsonb_build_object(
    'schema_version', 1,
    'team_id', team.team_id,
    'legacy_ids', coalesce((
      select jsonb_agg(identifier.identifier order by identifier.identifier)
      from public.catalog_team_identifiers identifier
      where identifier.team_id = team.id and identifier.namespace like 'legacy%'
    ), '[]'::jsonb),
    'sport_id', sport.sport_id,
    'identity', jsonb_build_object(
      'display_name', identity_record.display_name,
      'short_name', identity_record.short_name,
      'abbreviation', identity_record.abbreviation,
      'founded_year', identity_record.founded_year,
      'active', identity_record.active,
      'status', identity_record.record_status,
      'aliases', coalesce((
        select jsonb_agg(jsonb_build_object(
          'value', alias.alias, 'type', alias.alias_type, 'locale', alias.locale,
          'effective_from', alias.effective_from, 'effective_to', alias.effective_to,
          'status', alias.record_status
        ) order by alias.alias_type, alias.alias)
        from public.team_alias_versions alias where alias.team_id = team.id
      ), '[]'::jsonb)
    ),
    'location', (
      select jsonb_build_object(
        'city', location_record.city, 'region', location_record.region,
        'country', location_record.country, 'country_code', location_record.country_code,
        'effective_from', location_record.effective_from, 'effective_to', location_record.effective_to,
        'status', location_record.record_status
      ) from public.team_location_versions location_record
      where location_record.team_id = team.id and location_record.is_current
    ),
    'current_competition', (
      select jsonb_build_object(
        'league_id', league.league_id, 'league_name', league.display_name,
        'conference_id', membership.conference_id, 'division_id', membership.division_id,
        'effective_from', membership.effective_from, 'status', membership.record_status
      ) from public.team_primary_league_versions membership
      join public.catalog_leagues league on league.id = membership.league_id
      where membership.team_id = team.id and membership.is_current
    ),
    'competition_history', coalesce((
      select jsonb_agg(jsonb_build_object(
        'league_id', league.league_id, 'conference_id', membership.conference_id,
        'division_id', membership.division_id, 'effective_from', membership.effective_from,
        'effective_to', membership.effective_to, 'superseded_at', membership.superseded_at,
        'status', membership.record_status
      ) order by membership.effective_from nulls first)
      from public.team_primary_league_versions membership
      join public.catalog_leagues league on league.id = membership.league_id
      where membership.team_id = team.id and not membership.is_current
    ), '[]'::jsonb),
    'colors', jsonb_build_object(
      'current', (
        select jsonb_build_object(
          'primary', colors.primary_color, 'secondary', colors.secondary_color,
          'tertiary', colors.tertiary_color, 'quaternary', colors.quaternary_color,
          'quinary', colors.quinary_color, 'effective_from', colors.effective_from,
          'status', colors.record_status
        ) from public.team_color_versions colors where colors.team_id = team.id and colors.is_current
      ),
      'history', coalesce((
        select jsonb_agg(jsonb_build_object(
          'primary', colors.primary_color, 'secondary', colors.secondary_color,
          'tertiary', colors.tertiary_color, 'quaternary', colors.quaternary_color,
          'quinary', colors.quinary_color, 'effective_from', colors.effective_from,
          'effective_to', colors.effective_to, 'status', colors.record_status
        ) order by colors.effective_from nulls first)
        from public.team_color_versions colors where colors.team_id = team.id and not colors.is_current
      ), '[]'::jsonb)
    ),
    'branding', jsonb_build_object(
      'generated_badge', jsonb_build_object('type', 'derived', 'stored_asset', false),
      'official_logos', coalesce((
        select jsonb_agg(jsonb_build_object(
          'asset_id', asset.asset_id, 'role', logo.logo_role,
          'usage_status', logo.usage_status, 'effective_from', logo.effective_from,
          'status', logo.record_status
        ) order by logo.logo_role, logo.effective_from desc nulls last)
        from public.team_logo_versions logo
        join public.catalog_media_assets asset on asset.id = logo.asset_id
        where logo.team_id = team.id and logo.is_current
      ), '[]'::jsonb),
      'display_policy', jsonb_build_object('preferred', 'official_primary', 'fallback', 'generated_badge')
    ),
    'venues', coalesce((
      select jsonb_agg(jsonb_build_object(
        'venue_id', venue.venue_id, 'relationship', relationship.relationship_type,
        'effective_from', relationship.effective_from, 'effective_to', relationship.effective_to,
        'status', relationship.record_status
      ) order by relationship.is_current desc, relationship.relationship_type)
      from public.team_venue_relationship_versions relationship
      join public.catalog_venues venue on venue.id = relationship.venue_id
      where relationship.team_id = team.id
    ), '[]'::jsonb),
    'completeness', jsonb_build_object(
      'catalog_ready', readiness.catalog_ready,
      'live_cheer_ready', readiness.live_cheer_ready,
      'catalog_missing_requirements', readiness.catalog_missing_requirements,
      'live_cheer_missing_requirements', readiness.live_cheer_missing_requirements
    ),
    'record_metadata', jsonb_build_object('created_at', team.created_at, 'updated_at', team.updated_at)
  )
  from target
  join public.catalog_teams team on team.id = target.id
  join public.catalog_sports sport on sport.id = team.sport_id
  left join public.team_identity_versions identity_record on identity_record.team_id = team.id and identity_record.is_current
  left join public.team_readiness readiness on readiness.internal_id = team.id;
$$;

-- ---------------------------------------------------------------------------
-- RLS and grants
-- ---------------------------------------------------------------------------

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'catalog_sports', 'catalog_leagues', 'catalog_teams', 'catalog_league_identifiers',
    'catalog_team_identifiers', 'team_identity_versions', 'team_alias_versions',
    'team_location_versions', 'team_primary_league_versions', 'team_color_versions',
    'catalog_media_assets', 'team_logo_versions', 'catalog_venues', 'venue_detail_versions',
    'team_venue_relationship_versions', 'venue_mapping_versions', 'venue_mapping_sections',
    'venue_mapping_section_exceptions', 'venue_mapping_inventory_rules',
    'venue_mapping_inventory_overrides', 'venue_mapping_team_profiles', 'venue_mapping_sports',
    'catalog_import_batches', 'catalog_actors', 'catalog_actor_capabilities', 'source_independence_groups',
    'trusted_sources', 'source_trust_assignments', 'verification_policies',
    'catalog_change_proposals', 'catalog_proposal_evidence',
    'catalog_verification_decisions', 'catalog_audit_events', 'catalog_team_id_sequences'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('revoke all on table public.%I from public, anon, authenticated', table_name);
  end loop;
end $$;

-- Public catalog and venue read data. These rows contain no private user data.
do $$
declare table_name text;
begin
  foreach table_name in array array[
    'catalog_sports', 'catalog_leagues', 'catalog_teams', 'catalog_league_identifiers',
    'catalog_team_identifiers', 'team_identity_versions', 'team_alias_versions',
    'team_location_versions', 'team_primary_league_versions', 'team_color_versions',
    'catalog_media_assets', 'team_logo_versions', 'catalog_venues', 'venue_detail_versions',
    'team_venue_relationship_versions', 'venue_mapping_versions', 'venue_mapping_sections',
    'venue_mapping_section_exceptions', 'venue_mapping_inventory_rules',
    'venue_mapping_inventory_overrides', 'venue_mapping_team_profiles', 'venue_mapping_sports'
  ] loop
    execute format('create policy "Public reads FANatical catalog %1$s" on public.%1$I for select to anon, authenticated using (true)', table_name);
    execute format('grant select on table public.%I to anon, authenticated', table_name);
  end loop;
end $$;

-- Internal registry/proposal rows are visible only to capable actors or admins.
do $$
declare table_name text;
begin
  foreach table_name in array array[
    'catalog_import_batches', 'catalog_actors', 'catalog_actor_capabilities', 'source_independence_groups',
    'trusted_sources', 'source_trust_assignments', 'verification_policies',
    'catalog_change_proposals', 'catalog_proposal_evidence',
    'catalog_verification_decisions', 'catalog_audit_events', 'catalog_team_id_sequences'
  ] loop
    execute format(
      'create policy "Authorized actors read FANatical catalog %1$s" on public.%1$I for select to authenticated using (public.has_catalog_capability(''catalog.read_internal'') or public.has_staff_access(array[''admin'',''staff'',''content_admin'']::text[], null))',
      table_name
    );
    execute format('grant select on table public.%I to authenticated', table_name);
  end loop;
end $$;

grant select on public.team_catalog_read_model, public.team_readiness to anon, authenticated;
grant execute on function public.resolve_catalog_team_id(text), public.get_team_record(text) to anon, authenticated;

revoke all on function public.current_catalog_actor_id() from public, anon;
grant execute on function public.current_catalog_actor_id() to authenticated;
revoke all on function public.has_catalog_capability(text, uuid, uuid, uuid, uuid) from public, anon;
grant execute on function public.has_catalog_capability(text, uuid, uuid, uuid, uuid) to authenticated;
revoke all on function public.admin_upsert_catalog_actor(text, text, uuid, text, boolean) from public, anon;
grant execute on function public.admin_upsert_catalog_actor(text, text, uuid, text, boolean) to authenticated;
revoke all on function public.admin_grant_catalog_capability(text, text, text, text, text, text) from public, anon;
grant execute on function public.admin_grant_catalog_capability(text, text, text, text, text, text) to authenticated;
revoke all on function public.admin_upsert_source_independence_group(text, text, text) from public, anon;
grant execute on function public.admin_upsert_source_independence_group(text, text, text) to authenticated;
revoke all on function public.admin_upsert_trusted_source(text, text, text, text, text, text, text, jsonb) from public, anon;
grant execute on function public.admin_upsert_trusted_source(text, text, text, text, text, text, text, jsonb) to authenticated;
revoke all on function public.admin_set_source_trust(text, text, smallint, text) from public, anon;
grant execute on function public.admin_set_source_trust(text, text, smallint, text) to authenticated;
revoke all on function public.admin_create_verification_policy(text, text, integer, smallint[], boolean, boolean, jsonb, boolean) from public, anon;
grant execute on function public.admin_create_verification_policy(text, text, integer, smallint[], boolean, boolean, jsonb, boolean) to authenticated;
revoke all on function public.submit_catalog_proposal(text, jsonb, text, text, text, text) from public, anon;
grant execute on function public.submit_catalog_proposal(text, jsonb, text, text, text, text) to authenticated;
revoke all on function public.submit_team_registration_proposal(jsonb) from public, anon;
grant execute on function public.submit_team_registration_proposal(jsonb) to authenticated;
revoke all on function public.add_catalog_proposal_evidence(uuid, text, text, text, timestamptz, boolean) from public, anon;
grant execute on function public.add_catalog_proposal_evidence(uuid, text, text, text, timestamptz, boolean) to authenticated;
revoke all on function public.withdraw_my_catalog_proposal(uuid) from public, anon;
grant execute on function public.withdraw_my_catalog_proposal(uuid) to authenticated;
revoke all on function public.review_catalog_proposal(uuid, text, text) from public, anon;
grant execute on function public.review_catalog_proposal(uuid, text, text) to authenticated;

revoke all on function public.protect_catalog_public_identity() from public, anon, authenticated;
revoke all on function public.protect_verified_catalog_version() from public, anon, authenticated;
revoke all on function public.protect_catalog_audit_event() from public, anon, authenticated;

comment on view public.team_catalog_read_model is
  'Flat compatibility projection for the current frontend and future repository adapter.';
comment on view public.team_readiness is
  'Calculated readiness. Official logos are optional. Age alone never creates a stale state.';
comment on function public.get_team_record(text) is
  'Human/agent-facing team record assembled from normalized canonical tables.';
