-- FANatical reusable publisher governance and empirical Team Color reliability.
--
-- This migration is additive and history preserving. Historical evidence keeps
-- its original trusted_sources foreign key and immutable decision snapshot.
-- Future evidence resolves to canonical publishers, records the exact URL,
-- trust, and independence versions used, and can later contribute only
-- independently corroborated empirical outcomes.

-- ---------------------------------------------------------------------------
-- Canonical publishers, redirects, versioned names, URL scopes, and ownership
-- ---------------------------------------------------------------------------

alter table public.trusted_sources
  add column if not exists superseded_by_source_id uuid references public.trusted_sources(id),
  add column if not exists superseded_at timestamptz;

create table public.trusted_source_alias_versions (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.trusted_sources(id),
  alias text not null check (length(btrim(alias)) > 0),
  normalized_alias text generated always as (
    lower(regexp_replace(btrim(alias), '\s+', ' ', 'g'))
  ) stored,
  alias_type text not null check (alias_type in (
    'publisher_name', 'former_name', 'legacy_source_id', 'other'
  )),
  is_current boolean not null default true,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  created_by_actor_id uuid references public.catalog_actors(id),
  notes text,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

create unique index trusted_source_alias_current_per_source_idx
on public.trusted_source_alias_versions(source_id, normalized_alias, alias_type)
where is_current;
create index trusted_source_alias_lookup_idx
on public.trusted_source_alias_versions(normalized_alias) where is_current;

create table public.trusted_source_url_scope_versions (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.trusted_sources(id),
  hostname text not null check (
    hostname = lower(hostname)
    and hostname ~ '^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$'
  ),
  include_subdomains boolean not null default false,
  path_prefix text not null default '/' check (path_prefix like '/%'),
  path_match text not null default 'prefix' check (path_match in ('exact', 'prefix')),
  scope_kind text not null default 'publisher' check (scope_kind in (
    'publisher', 'hostname_alias', 'path_owner', 'document_host', 'cdn'
  )),
  review_status text not null default 'pending_review' check (review_status in (
    'pending_review', 'approved', 'suspended', 'retired'
  )),
  is_current boolean not null default true,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  created_by_actor_id uuid references public.catalog_actors(id),
  review_notes text,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

create unique index trusted_source_url_scope_current_exact_idx
on public.trusted_source_url_scope_versions(
  source_id, hostname, include_subdomains, path_prefix, path_match, scope_kind
) where is_current;
create index trusted_source_url_scope_resolver_idx
on public.trusted_source_url_scope_versions(hostname, review_status)
where is_current;

create table public.source_independence_group_assignment_versions (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.trusted_sources(id),
  independence_group_id uuid references public.source_independence_groups(id),
  review_status text not null check (review_status in (
    'pending_review', 'approved', 'suspended', 'retired'
  )),
  is_current boolean not null default true,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  assigned_by_actor_id uuid references public.catalog_actors(id),
  notes text,
  created_at timestamptz not null default now(),
  check (
    review_status <> 'approved' or independence_group_id is not null
  ),
  check (effective_to is null or effective_to >= effective_from)
);

create unique index source_independence_assignment_current_idx
on public.source_independence_group_assignment_versions(source_id) where is_current;

create table public.trusted_source_redirects (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null unique references public.trusted_sources(id),
  canonical_source_id uuid not null references public.trusted_sources(id),
  reason text not null check (length(btrim(reason)) > 0),
  redirected_by_actor_id uuid references public.catalog_actors(id),
  redirected_at timestamptz not null default now(),
  check (source_id <> canonical_source_id)
);

-- Exact versions used by evidence remain stable even after governance changes.
alter table public.catalog_proposal_evidence
  add column if not exists source_url_scope_version_id uuid
    references public.trusted_source_url_scope_versions(id),
  add column if not exists source_trust_assignment_id uuid
    references public.source_trust_assignments(id),
  add column if not exists source_independence_assignment_id uuid
    references public.source_independence_group_assignment_versions(id),
  add column if not exists structured_claim jsonb;

-- Trust is reusable globally or narrowed to exactly one applicability level.
alter table public.source_trust_assignments
  add column if not exists sport_id uuid references public.catalog_sports(id),
  add column if not exists league_id uuid references public.catalog_leagues(id),
  add column if not exists team_id uuid references public.catalog_teams(id),
  add column if not exists assigned_by_actor_id uuid references public.catalog_actors(id);

alter table public.source_trust_assignments
  add constraint source_trust_single_applicability_scope_check
  check (num_nonnulls(sport_id, league_id, team_id) <= 1);

drop index if exists public.source_trust_current_idx;
create unique index source_trust_current_scoped_idx
on public.source_trust_assignments(
  source_id,
  data_type,
  coalesce(sport_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(league_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(team_id, '00000000-0000-0000-0000-000000000000'::uuid)
) where is_current;

-- Backfill an immutable ownership version before changing any source records.
insert into public.source_independence_group_assignment_versions(
  source_id, independence_group_id, review_status, effective_from, notes
)
select source.id, source.independence_group_id, source.review_status,
       source.created_at, 'Backfilled from the pre-versioned Trusted Source Registry.'
from public.trusted_sources source
where not exists (
  select 1 from public.source_independence_group_assignment_versions assignment
  where assignment.source_id = source.id and assignment.is_current
);

-- ---------------------------------------------------------------------------
-- URL parsing, canonical resolution, ownership matching, and applicability
-- ---------------------------------------------------------------------------

create or replace function public.normalized_source_url_parts(url_value text)
returns jsonb
language plpgsql
stable
strict
set search_path = ''
as $$
declare
  authority_value text;
  hostname_value text;
  path_value text;
  scheme_value text;
begin
  if url_value !~* '^https?://[^[:space:]]+$' then
    raise exception 'Evidence URL must be an absolute HTTP(S) URL';
  end if;
  scheme_value := lower(substring(url_value from '^([A-Za-z]+)://'));
  authority_value := substring(url_value from '^[A-Za-z]+://([^/?#]+)');
  if authority_value is null or authority_value like '%@%' or authority_value like '[%' then
    raise exception 'Evidence URL authority is not permitted';
  end if;
  hostname_value := lower(regexp_replace(authority_value, ':[0-9]+$', ''));
  hostname_value := regexp_replace(hostname_value, '\.$', '');
  if hostname_value !~ '^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$' then
    raise exception 'Evidence URL hostname is invalid';
  end if;
  path_value := coalesce(substring(url_value from '^[A-Za-z]+://[^/?#]+([^?#]*)'), '');
  path_value := '/' || ltrim(path_value, '/');
  path_value := regexp_replace(path_value, '/+', '/', 'g');
  if length(path_value) > 1 then
    path_value := regexp_replace(path_value, '/+$', '');
  end if;
  return jsonb_build_object(
    'scheme', scheme_value,
    'hostname', hostname_value,
    'path', path_value,
    'normalized_url', scheme_value || '://' || hostname_value || path_value
  );
end;
$$;

create or replace function public.normalize_source_url(url_value text)
returns text
language sql
stable
strict
set search_path = ''
as $$
  select public.normalized_source_url_parts(url_value) ->> 'normalized_url';
$$;

create or replace function public.normalize_source_path(path_value text)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare result_value text;
begin
  result_value := '/' || ltrim(coalesce(nullif(btrim(path_value), ''), '/'), '/');
  result_value := regexp_replace(result_value, '/+', '/', 'g');
  if length(result_value) > 1 then result_value := regexp_replace(result_value, '/+$', ''); end if;
  return result_value;
end;
$$;

-- ---------------------------------------------------------------------------
-- Controlled, audited publisher governance
-- ---------------------------------------------------------------------------

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
declare
  result_id uuid;
  actor_uuid uuid := public.current_catalog_actor_id();
  base_parts jsonb;
  reference_parts jsonb;
begin
  if not public.has_staff_access(array['admin']::text[], null) then
    raise exception 'Admin access is required';
  end if;
  if independence_group_value is not null
     or coalesce(review_status_value, 'pending_review') <> 'pending_review' then
    raise exception 'Candidate creation cannot assign ownership or approval; use controlled source-review interfaces';
  end if;
  if source_id_value !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
     or nullif(btrim(display_name_value), '') is null then
    raise exception 'A lowercase source slug and display name are required';
  end if;
  if exists (select 1 from public.trusted_sources where source_id = source_id_value) then
    raise exception 'Existing publisher identity cannot be overwritten; use controlled alias, URL-scope, review, trust, or redirect interfaces';
  end if;
  if exists (
    select 1 from public.trusted_sources source
    where lower(regexp_replace(btrim(source.display_name), '\s+', ' ', 'g')) =
          lower(regexp_replace(btrim(display_name_value), '\s+', ' ', 'g'))
       or exists (
         select 1 from public.trusted_source_alias_versions alias
         where alias.is_current and alias.normalized_alias =
           lower(regexp_replace(btrim(display_name_value), '\s+', ' ', 'g'))
       )
  ) then
    raise exception 'A potentially equivalent publisher already exists; resolve and reuse it or request reviewer resolution';
  end if;
  if base_url_value is not null then base_parts := public.normalized_source_url_parts(base_url_value); end if;
  if reference_url_value is not null then reference_parts := public.normalized_source_url_parts(reference_url_value); end if;

  insert into public.trusted_sources(
    source_id, display_name, base_url, reference_url, review_status, notes, metadata
  ) values (
    source_id_value, btrim(display_name_value), base_url_value, reference_url_value,
    'pending_review', notes_value, coalesce(metadata_value, '{}'::jsonb)
  ) returning id into result_id;
  insert into public.source_independence_group_assignment_versions(
    source_id, review_status, assigned_by_actor_id, notes
  ) values (result_id, 'pending_review', actor_uuid, 'Publisher candidate created; ownership review pending.');
  insert into public.trusted_source_alias_versions(
    source_id, alias, alias_type, created_by_actor_id
  ) values (result_id, source_id_value, 'legacy_source_id', actor_uuid);
  if base_parts is not null then
    insert into public.trusted_source_url_scope_versions(
      source_id, hostname, include_subdomains, path_prefix, path_match,
      scope_kind, review_status, created_by_actor_id, review_notes
    ) values (
      result_id, base_parts ->> 'hostname', false, base_parts ->> 'path', 'prefix',
      'publisher', 'pending_review', actor_uuid, 'Candidate base URL; reviewer approval required.'
    );
  end if;
  if reference_parts is not null and reference_parts is distinct from base_parts then
    insert into public.trusted_source_url_scope_versions(
      source_id, hostname, include_subdomains, path_prefix, path_match,
      scope_kind, review_status, created_by_actor_id, review_notes
    ) values (
      result_id, reference_parts ->> 'hostname', false, reference_parts ->> 'path', 'exact',
      'document_host', 'pending_review', actor_uuid, 'Candidate reference URL; reviewer approval required.'
    ) on conflict do nothing;
  end if;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'source.publisher_candidate_created', 'trusted_source',
    source_id_value, jsonb_build_object('review_status', 'pending_review')
  );
  return result_id;
end;
$$;

create or replace function public.review_trusted_source(
  source_registry_id text,
  independence_group_value text,
  review_status_value text,
  ownership_notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  source_record public.trusted_sources%rowtype;
  group_uuid uuid;
  old_assignment public.source_independence_group_assignment_versions%rowtype;
begin
  if not public.has_staff_access(array['admin']::text[], null)
     and not public.has_catalog_capability('source.registry.review') then
    raise exception 'source.registry.review capability is required';
  end if;
  if review_status_value not in ('pending_review','approved','suspended','retired') then
    raise exception 'Invalid source review status';
  end if;
  if review_status_value = 'approved' and independence_group_value is null then
    raise exception 'Approved publishers require a reviewed ownership independence group';
  end if;
  select * into strict source_record from public.trusted_sources
  where source_id = source_registry_id for update;
  if source_record.superseded_by_source_id is not null then
    raise exception 'Superseded publishers cannot be reviewed; use the canonical publisher';
  end if;
  if independence_group_value is not null then
    select id into strict group_uuid from public.source_independence_groups
    where group_id = independence_group_value;
  end if;
  select * into old_assignment
  from public.source_independence_group_assignment_versions
  where source_id = source_record.id and is_current for update;
  update public.source_independence_group_assignment_versions
  set is_current = false, effective_to = now()
  where source_id = source_record.id and is_current;
  insert into public.source_independence_group_assignment_versions(
    source_id, independence_group_id, review_status, assigned_by_actor_id, notes
  ) values (
    source_record.id, group_uuid, review_status_value, actor_uuid, ownership_notes_value
  );
  update public.trusted_sources
  set independence_group_id = group_uuid, review_status = review_status_value,
      updated_at = now(), metadata = metadata || jsonb_build_object(
        'ownership_review', jsonb_build_object(
          'notes', ownership_notes_value, 'reviewed_at', now(),
          'reviewed_by_actor_id', actor_uuid
        )
      )
  where id = source_record.id;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'source.registry_reviewed', 'trusted_source',
    source_registry_id, jsonb_build_object(
      'previous_assignment_version_id', old_assignment.id,
      'previous_review_status', source_record.review_status,
      'new_review_status', review_status_value,
      'new_independence_group', independence_group_value,
      'ownership_notes', ownership_notes_value
    )
  );
  return source_record.id;
end;
$$;

create or replace function public.review_trusted_source_url_scope(
  source_registry_id text,
  hostname_value text,
  include_subdomains_value boolean,
  path_prefix_value text,
  path_match_value text,
  scope_kind_value text,
  review_status_value text,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  source_uuid uuid;
  result_id uuid;
  normalized_host text := lower(regexp_replace(btrim(hostname_value), '\.$', ''));
  normalized_path text := public.normalize_source_path(path_prefix_value);
begin
  if not public.has_staff_access(array['admin']::text[], null)
     and not public.has_catalog_capability('source.registry.review') then
    raise exception 'source.registry.review capability is required';
  end if;
  if path_match_value not in ('exact','prefix')
     or scope_kind_value not in ('publisher','hostname_alias','path_owner','document_host','cdn')
     or review_status_value not in ('pending_review','approved','suspended','retired') then
    raise exception 'Invalid URL-scope governance value';
  end if;
  select id into strict source_uuid from public.trusted_sources
  where source_id = source_registry_id and superseded_by_source_id is null;
  update public.trusted_source_url_scope_versions
  set is_current = false, effective_to = now()
  where source_id = source_uuid and is_current
    and hostname = normalized_host
    and include_subdomains = include_subdomains_value
    and path_prefix = normalized_path
    and path_match = path_match_value
    and scope_kind = scope_kind_value;
  insert into public.trusted_source_url_scope_versions(
    source_id, hostname, include_subdomains, path_prefix, path_match,
    scope_kind, review_status, created_by_actor_id, review_notes
  ) values (
    source_uuid, normalized_host, include_subdomains_value, normalized_path,
    path_match_value, scope_kind_value, review_status_value, actor_uuid, notes_value
  ) returning id into result_id;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'source.url_scope_reviewed', 'trusted_source',
    source_registry_id, jsonb_build_object(
      'url_scope_version_id', result_id, 'hostname', normalized_host,
      'include_subdomains', include_subdomains_value, 'path_prefix', normalized_path,
      'path_match', path_match_value, 'scope_kind', scope_kind_value,
      'review_status', review_status_value, 'notes', notes_value
    )
  );
  return result_id;
end;
$$;

create or replace function public.add_trusted_source_alias(
  source_registry_id text,
  alias_value text,
  alias_type_value text,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  source_uuid uuid;
  result_id uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null)
     and not public.has_catalog_capability('source.registry.review') then
    raise exception 'source.registry.review capability is required';
  end if;
  if alias_type_value not in ('publisher_name','former_name','legacy_source_id','other') then
    raise exception 'Invalid publisher alias type';
  end if;
  select id into strict source_uuid from public.trusted_sources
  where source_id = source_registry_id and superseded_by_source_id is null;
  if exists (
    select 1 from public.trusted_source_alias_versions alias
    where alias.is_current and alias.source_id <> source_uuid
      and alias.normalized_alias = lower(regexp_replace(btrim(alias_value), '\s+', ' ', 'g'))
  ) then
    raise exception 'Alias already identifies a different publisher';
  end if;
  insert into public.trusted_source_alias_versions(
    source_id, alias, alias_type, created_by_actor_id, notes
  ) values (source_uuid, alias_value, alias_type_value, actor_uuid, notes_value)
  on conflict (source_id, normalized_alias, alias_type) where is_current
  do update set notes = excluded.notes
  returning id into result_id;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'source.alias_added', 'trusted_source', source_registry_id,
    jsonb_build_object('alias_version_id', result_id, 'alias', alias_value, 'alias_type', alias_type_value)
  );
  return result_id;
end;
$$;

create or replace function public.admin_set_source_trust_scoped(
  source_registry_id text,
  data_type_value text,
  trust_tier_value smallint,
  sport_identifier text default null,
  league_identifier text default null,
  team_identifier text default null,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  source_record public.trusted_sources%rowtype;
  sport_uuid uuid;
  league_uuid uuid;
  team_uuid uuid;
  result_id uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null)
     and not public.has_catalog_capability('source.trust.assign') then
    raise exception 'source.trust.assign capability is required';
  end if;
  if trust_tier_value not between 1 and 5 or nullif(btrim(data_type_value), '') is null then
    raise exception 'A data type and trust tier from 1 through 5 are required';
  end if;
  if num_nonnulls(sport_identifier, league_identifier, team_identifier) > 1 then
    raise exception 'Trust applicability may be global or scoped to exactly one sport, league, or team';
  end if;
  select * into strict source_record from public.trusted_sources
  where source_id = source_registry_id and superseded_by_source_id is null for update;
  if source_record.review_status <> 'approved' or source_record.independence_group_id is null then
    raise exception 'Publisher ownership and independence must be approved before trust is assigned';
  end if;
  if sport_identifier is not null then
    select id into strict sport_uuid from public.catalog_sports where sport_id = sport_identifier;
  elsif league_identifier is not null then
    select id into strict league_uuid from public.catalog_leagues where league_id = league_identifier;
  elsif team_identifier is not null then
    team_uuid := public.resolve_catalog_team_id(team_identifier);
    if team_uuid is null then raise exception 'Unknown team identifier'; end if;
  end if;
  update public.source_trust_assignments
  set is_current = false, effective_to = current_date, superseded_at = now()
  where source_id = source_record.id and data_type = data_type_value and is_current
    and sport_id is not distinct from sport_uuid
    and league_id is not distinct from league_uuid
    and team_id is not distinct from team_uuid;
  insert into public.source_trust_assignments(
    source_id, data_type, trust_tier, effective_from, sport_id, league_id,
    team_id, assigned_by_actor_id, notes
  ) values (
    source_record.id, data_type_value, trust_tier_value, current_date, sport_uuid,
    league_uuid, team_uuid, actor_uuid, notes_value
  ) returning id into result_id;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'source.trust_assigned', 'trusted_source', source_registry_id,
    jsonb_build_object(
      'trust_assignment_id', result_id, 'data_type', data_type_value,
      'new_tier', trust_tier_value, 'sport_id', sport_identifier,
      'league_id', league_identifier, 'team_id', team_identifier, 'notes', notes_value
    )
  );
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
language sql
security definer
set search_path = ''
as $$
  select public.admin_set_source_trust_scoped(
    source_registry_id, data_type_value, trust_tier_value,
    null, null, null, notes_value
  );
$$;

create or replace function public.redirect_trusted_source(
  source_registry_id text,
  canonical_source_registry_id text,
  reason_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  source_record public.trusted_sources%rowtype;
  target_record public.trusted_sources%rowtype;
  conflict_count integer;
  result_id uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null)
     and not public.has_catalog_capability('source.registry.review') then
    raise exception 'source.registry.review capability is required';
  end if;
  if nullif(btrim(reason_value), '') is null then raise exception 'A redirect reason is required'; end if;
  select * into strict source_record from public.trusted_sources
  where source_id = source_registry_id for update;
  select * into strict target_record from public.trusted_sources
  where source_id = canonical_source_registry_id and superseded_by_source_id is null for update;
  if source_record.id = target_record.id or source_record.superseded_by_source_id is not null then
    raise exception 'Source is already canonicalized';
  end if;
  if source_record.independence_group_id is not null
     and target_record.independence_group_id is not null
     and source_record.independence_group_id <> target_record.independence_group_id then
    raise exception 'Publishers with different reviewed ownership groups require human conflict resolution';
  end if;
  select count(*) into conflict_count
  from public.source_trust_assignments old_trust
  join public.source_trust_assignments new_trust
    on new_trust.source_id = target_record.id
   and new_trust.data_type = old_trust.data_type
   and new_trust.is_current and old_trust.is_current
   and new_trust.sport_id is not distinct from old_trust.sport_id
   and new_trust.league_id is not distinct from old_trust.league_id
   and new_trust.team_id is not distinct from old_trust.team_id
  where old_trust.source_id = source_record.id
    and new_trust.trust_tier <> old_trust.trust_tier;
  if conflict_count > 0 then
    raise exception 'Conflicting current trust assignments require reviewer resolution before redirect';
  end if;
  insert into public.trusted_source_redirects(
    source_id, canonical_source_id, reason, redirected_by_actor_id
  ) values (source_record.id, target_record.id, btrim(reason_value), actor_uuid)
  returning id into result_id;
  insert into public.trusted_source_url_scope_versions(
    source_id, hostname, include_subdomains, path_prefix, path_match,
    scope_kind, review_status, created_by_actor_id, review_notes
  )
  select target_record.id, scope.hostname, scope.include_subdomains,
         scope.path_prefix, scope.path_match, scope.scope_kind,
         scope.review_status, actor_uuid,
         'Transferred by audited publisher redirect: ' || btrim(reason_value)
  from public.trusted_source_url_scope_versions scope
  where scope.source_id = source_record.id and scope.is_current
  on conflict do nothing;
  insert into public.trusted_source_alias_versions(
    source_id, alias, alias_type, created_by_actor_id, notes
  )
  select target_record.id, alias.alias, alias.alias_type, actor_uuid,
         'Transferred by audited publisher redirect: ' || btrim(reason_value)
  from public.trusted_source_alias_versions alias
  where alias.source_id = source_record.id and alias.is_current
  on conflict do nothing;
  insert into public.source_trust_assignments(
    source_id, data_type, trust_tier, effective_from, sport_id, league_id,
    team_id, assigned_by_actor_id, notes
  )
  select target_record.id, old_trust.data_type, old_trust.trust_tier,
         current_date, old_trust.sport_id, old_trust.league_id,
         old_trust.team_id, actor_uuid,
         'Transferred by audited publisher redirect: ' || btrim(reason_value)
  from public.source_trust_assignments old_trust
  where old_trust.source_id = source_record.id and old_trust.is_current
    and not exists (
      select 1 from public.source_trust_assignments target_trust
      where target_trust.source_id = target_record.id
        and target_trust.data_type = old_trust.data_type
        and target_trust.is_current
        and target_trust.sport_id is not distinct from old_trust.sport_id
        and target_trust.league_id is not distinct from old_trust.league_id
        and target_trust.team_id is not distinct from old_trust.team_id
    );
  update public.trusted_sources
  set review_status = 'retired', superseded_by_source_id = target_record.id,
      superseded_at = now(), updated_at = now()
  where id = source_record.id;
  update public.trusted_source_url_scope_versions
  set is_current = false, effective_to = now(), review_status = 'retired'
  where source_id = source_record.id and is_current;
  update public.trusted_source_alias_versions
  set is_current = false, effective_to = now()
  where source_id = source_record.id and is_current;
  update public.source_independence_group_assignment_versions
  set is_current = false, effective_to = now(), review_status = 'retired'
  where source_id = source_record.id and is_current;
  update public.source_trust_assignments
  set is_current = false, effective_to = current_date, superseded_at = now()
  where source_id = source_record.id and is_current;
  insert into public.trusted_source_alias_versions(
    source_id, alias, alias_type, created_by_actor_id, notes
  ) values (
    target_record.id, source_record.source_id, 'legacy_source_id', actor_uuid,
    'Historical source ID redirected without rewriting evidence.'
  ) on conflict do nothing;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'source.redirected', 'trusted_source', source_registry_id,
    jsonb_build_object(
      'canonical_source_id', canonical_source_registry_id,
      'redirect_id', result_id, 'reason', btrim(reason_value),
      'historical_evidence_rewritten', false
    )
  );
  return result_id;
end;
$$;


create or replace function public.normalize_source_url(url_value text)
returns text
language sql
stable
strict
set search_path = ''
as $$
  select public.normalized_source_url_parts(url_value) ->> 'normalized_url';
$$;

create or replace function public.normalize_source_path(path_value text)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare result_value text;
begin
  result_value := '/' || ltrim(coalesce(nullif(btrim(path_value), ''), '/'), '/');
  result_value := regexp_replace(result_value, '/+', '/', 'g');
  if length(result_value) > 1 then result_value := regexp_replace(result_value, '/+$', ''); end if;
  return result_value;
end;
$$;

create or replace function public.canonical_trusted_source_id(source_uuid uuid)
returns uuid
language sql
stable
set search_path = ''
as $$
  with recursive chain(id, depth) as (
    select source_uuid, 0
    union all
    select redirect.canonical_source_id, chain.depth + 1
    from chain
    join public.trusted_source_redirects redirect on redirect.source_id = chain.id
    where chain.depth < 20
  )
  select id from chain order by depth desc limit 1;
$$;

create or replace function public.trusted_source_url_matches(evidence_url_value text)
returns table (
  matched_source_id uuid,
  canonical_source_id uuid,
  url_scope_version_id uuid,
  specificity integer
)
language sql
stable
security definer
set search_path = ''
as $$
  with parts as (
    select public.normalized_source_url_parts(evidence_url_value) value
  )
  select scope.source_id,
         public.canonical_trusted_source_id(scope.source_id),
         scope.id,
         (case when scope.include_subdomains then 0 else 100000 end)
           + (case when scope.path_match = 'exact' then 10000 else 0 end)
           + length(scope.path_prefix)
  from public.trusted_source_url_scope_versions scope
  cross join parts
  join public.trusted_sources source on source.id = scope.source_id
  where scope.is_current
    and scope.review_status in ('pending_review', 'approved')
    and source.review_status in ('pending_review', 'approved')
    and (
      parts.value ->> 'hostname' = scope.hostname
      or (
        scope.include_subdomains
        and right(parts.value ->> 'hostname', length(scope.hostname) + 1) = '.' || scope.hostname
      )
    )
    and (
      (scope.path_match = 'exact' and parts.value ->> 'path' = scope.path_prefix)
      or (
        scope.path_match = 'prefix'
        and (
          scope.path_prefix = '/'
          or parts.value ->> 'path' = scope.path_prefix
          or left(parts.value ->> 'path', length(scope.path_prefix) + 1) = scope.path_prefix || '/'
        )
      )
    );
$$;

create or replace function public.resolve_trusted_source_url(evidence_url_value text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  best_specificity integer;
  result_value jsonb;
  source_count integer;
begin
  if actor_uuid is null then raise exception 'An active catalog actor is required'; end if;
  if not public.has_catalog_capability('team_colors.work.read')
     and not public.has_catalog_capability('source.registry.review')
     and not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'Team Color read or source-review capability is required';
  end if;
  select max(match.specificity) into best_specificity
  from public.trusted_source_url_matches(evidence_url_value) match;
  if best_specificity is null then
    return jsonb_build_object(
      'status', 'none',
      'normalized_url', public.normalize_source_url(evidence_url_value),
      'matches', '[]'::jsonb
    );
  end if;
  select count(distinct match.canonical_source_id),
         coalesce(jsonb_agg(distinct jsonb_build_object(
           'source_id', source.source_id,
           'display_name', source.display_name,
           'review_status', source.review_status,
           'url_scope_version_id', match.url_scope_version_id
         )), '[]'::jsonb)
    into source_count, result_value
  from public.trusted_source_url_matches(evidence_url_value) match
  join public.trusted_sources source on source.id = match.canonical_source_id
  where match.specificity = best_specificity;
  return jsonb_build_object(
    'status', case when source_count = 1 then 'resolved' else 'ambiguous' end,
    'normalized_url', public.normalize_source_url(evidence_url_value),
    'matches', result_value
  );
end;
$$;

create or replace function public.applicable_source_trust_assignment(
  source_uuid uuid,
  data_type_value text,
  team_uuid uuid
)
returns uuid
language sql
stable
set search_path = ''
as $$
  select trust.id
  from public.source_trust_assignments trust
  join public.catalog_teams team on team.id = team_uuid
  left join public.team_primary_league_versions membership
    on membership.team_id = team.id and membership.is_current
  where trust.source_id = source_uuid
    and trust.data_type = data_type_value
    and trust.is_current
    and (trust.effective_from is null or trust.effective_from <= current_date)
    and (trust.effective_to is null or trust.effective_to >= current_date)
    and (
      trust.team_id = team.id
      or trust.league_id = membership.league_id
      or trust.sport_id = team.sport_id
      or num_nonnulls(trust.sport_id, trust.league_id, trust.team_id) = 0
    )
  order by case
    when trust.team_id is not null then 4
    when trust.league_id is not null then 3
    when trust.sport_id is not null then 2
    else 1 end desc,
    trust.created_at desc
  limit 1;
$$;

create or replace function public.resolve_team_color_source(
  work_item_id_value uuid,
  lease_token_value uuid,
  evidence_url_value text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.team_color_work_items%rowtype;
  resolution jsonb;
  resolved_source uuid;
  trust_uuid uuid;
begin
  select * into strict work_record
  from public.team_color_work_items where id = work_item_id_value;
  if work_record.status <> 'claimed'
     or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value
     or work_record.lease_expires_at <= now() then
    raise exception 'An active Team Color work lease owned by this actor is required';
  end if;
  if not public.has_team_color_capability('team_colors.work.read', work_record.team_id) then
    raise exception 'Team Color work-read capability is required';
  end if;
  resolution := public.resolve_trusted_source_url(evidence_url_value);
  if resolution ->> 'status' <> 'resolved' then return resolution; end if;
  select source.id into resolved_source
  from public.trusted_sources source
  where source.source_id = resolution #>> '{matches,0,source_id}';
  trust_uuid := public.applicable_source_trust_assignment(resolved_source, 'team_colors', work_record.team_id);
  return resolution || jsonb_build_object(
    'applicability', case when trust_uuid is null then 'not_applicable' else 'applicable' end,
    'trust_assignment_id', trust_uuid
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Governed candidate intake and structured Team Color evidence
-- ---------------------------------------------------------------------------

alter table public.team_color_source_candidates
  add column if not exists source_url_scope_version_id uuid
    references public.trusted_source_url_scope_versions(id),
  add column if not exists resolution_snapshot jsonb not null default '{}'::jsonb;

create or replace function public.team_color_palette_from_payload(payload_value jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_agg(value order by ordinal), '[]'::jsonb)
  from (
    select ordinal, payload_value ->> key as value
    from unnest(array['primary','secondary','tertiary','quaternary','quinary'])
      with ordinality keys(key, ordinal)
    where nullif(payload_value ->> key, '') is not null
  ) palette;
$$;

create or replace function public.validate_team_color_claim(claim_value jsonb)
returns boolean
language plpgsql
stable
set search_path = ''
as $$
declare
  classification_value text;
  palette_length integer;
  palette_item text;
begin
  if jsonb_typeof(claim_value) <> 'object' then return false; end if;
  classification_value := claim_value ->> 'classification';
  if classification_value not in (
    'current_canonical', 'historical', 'alternate',
    'special_treatment', 'unresolved'
  ) then return false; end if;
  if jsonb_typeof(claim_value -> 'palette') <> 'array' then return false; end if;
  palette_length := jsonb_array_length(claim_value -> 'palette');
  if classification_value = 'unresolved' then
    if palette_length > 5 then return false; end if;
  elsif palette_length not between 2 and 5 then
    return false;
  end if;
  for palette_item in select jsonb_array_elements_text(claim_value -> 'palette') loop
    if palette_item !~ '^#[0-9A-F]{6}$' then return false; end if;
  end loop;
  if claim_value ? 'effective_from'
     and nullif(claim_value ->> 'effective_from', '') is not null then
    perform (claim_value ->> 'effective_from')::date;
  end if;
  return true;
exception when others then
  return false;
end;
$$;

create or replace function public.add_catalog_proposal_evidence_governed(
  proposal_id_value uuid,
  source_registry_id text,
  evidence_url_value text,
  evidence_summary_value text,
  observed_at_value timestamptz,
  supports_proposal_value boolean,
  structured_claim_value jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  proposal_record public.catalog_change_proposals%rowtype;
  requested_source_uuid uuid;
  source_uuid uuid;
  source_record public.trusted_sources%rowtype;
  url_scope_uuid uuid;
  trust_uuid uuid;
  trust_record public.source_trust_assignments%rowtype;
  independence_uuid uuid;
  top_specificity integer;
  top_source_count integer;
  result_id uuid;
begin
  if actor_uuid is null then raise exception 'An active catalog actor is required'; end if;
  select * into proposal_record from public.catalog_change_proposals
  where id = proposal_id_value;
  if not found or proposal_record.status <> 'pending' then
    raise exception 'A pending proposal is required';
  end if;
  if proposal_record.proposed_by_actor_id <> actor_uuid
     and not public.has_catalog_capability(
       'catalog.evidence.add', null, proposal_record.target_league_id,
       proposal_record.target_team_id, proposal_record.target_venue_id
     ) then
    raise exception 'The catalog actor cannot add evidence to this proposal';
  end if;
  select id into requested_source_uuid from public.trusted_sources
  where source_id = source_registry_id;
  if requested_source_uuid is null then raise exception 'Unknown Trusted Source Registry ID'; end if;
  source_uuid := public.canonical_trusted_source_id(requested_source_uuid);
  select * into strict source_record from public.trusted_sources where id = source_uuid;
  if source_record.review_status <> 'approved' or source_record.independence_group_id is null then
    raise exception 'Publisher ownership and independence review is not approved';
  end if;

  select max(match.specificity) into top_specificity
  from public.trusted_source_url_matches(evidence_url_value) match;
  if top_specificity is null then
    raise exception 'Evidence URL is outside every permitted publisher URL scope';
  end if;
  select count(distinct match.canonical_source_id) into top_source_count
  from public.trusted_source_url_matches(evidence_url_value) match
  where match.specificity = top_specificity;
  if top_source_count <> 1 then
    raise exception 'Evidence URL ownership is ambiguous and requires source review';
  end if;
  select match.url_scope_version_id into url_scope_uuid
  from public.trusted_source_url_matches(evidence_url_value) match
  join public.trusted_source_url_scope_versions scope
    on scope.id = match.url_scope_version_id
  where match.specificity = top_specificity
    and match.canonical_source_id = source_uuid
    and scope.review_status = 'approved'
  order by match.url_scope_version_id
  limit 1;
  if url_scope_uuid is null then
    raise exception 'Evidence URL does not belong to the selected approved publisher';
  end if;

  if proposal_record.target_team_id is null then
    select trust.id into trust_uuid
    from public.source_trust_assignments trust
    where trust.source_id = source_uuid and trust.data_type = proposal_record.fact_type
      and trust.is_current
      and num_nonnulls(trust.sport_id, trust.league_id, trust.team_id) = 0
    order by trust.created_at desc limit 1;
  else
    trust_uuid := public.applicable_source_trust_assignment(
      source_uuid, proposal_record.fact_type, proposal_record.target_team_id
    );
  end if;
  if trust_uuid is null then
    raise exception 'Publisher has no current trust assignment applicable to this data type and target';
  end if;
  select * into strict trust_record from public.source_trust_assignments where id = trust_uuid;
  if trust_record.trust_tier = 5 then raise exception 'Tier 5 publishers are blocked for this data type'; end if;
  select assignment.id into independence_uuid
  from public.source_independence_group_assignment_versions assignment
  where assignment.source_id = source_uuid and assignment.is_current
    and assignment.review_status = 'approved'
    and assignment.independence_group_id = source_record.independence_group_id;
  if independence_uuid is null then raise exception 'Current approved independence assignment is required'; end if;

  if proposal_record.fact_type = 'team_colors' then
    if not public.validate_team_color_claim(structured_claim_value) then
      raise exception 'A valid structured Team Color claim is required';
    end if;
    if supports_proposal_value
       and structured_claim_value ->> 'classification' <> 'current_canonical' then
      raise exception 'Supporting Team Color evidence must claim the current canonical palette';
    end if;
    if supports_proposal_value
       and structured_claim_value -> 'palette' <>
           public.team_color_palette_from_payload(proposal_record.payload) then
      raise exception 'Supporting Team Color claim must exactly match proposal palette values and order';
    end if;
  elsif structured_claim_value is not null then
    raise exception 'Structured Team Color claims apply only to team_colors proposals';
  end if;

  insert into public.catalog_proposal_evidence(
    proposal_id, source_id, evidence_url, evidence_summary, observed_at,
    supports_proposal, submitted_by_actor_id, source_url_scope_version_id,
    source_trust_assignment_id, source_independence_assignment_id,
    structured_claim
  ) values (
    proposal_id_value, source_uuid, evidence_url_value, evidence_summary_value,
    observed_at_value, supports_proposal_value, actor_uuid, url_scope_uuid,
    trust_uuid, independence_uuid, structured_claim_value
  ) returning id into result_id;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, proposal_id, details
  ) values (
    actor_uuid, auth.uid(), 'proposal.evidence_added', 'catalog_proposal',
    proposal_id_value::text, proposal_id_value, jsonb_build_object(
      'source_id', source_record.source_id,
      'url_scope_version_id', url_scope_uuid,
      'trust_assignment_id', trust_uuid,
      'independence_assignment_id', independence_uuid,
      'trust_tier', trust_record.trust_tier,
      'structured_claim', structured_claim_value
    )
  );
  return result_id;
end;
$$;

create or replace function public.add_team_color_proposal_evidence(
  proposal_id_value uuid,
  source_registry_id text,
  evidence_url_value text,
  evidence_summary_value text,
  observed_at_value timestamptz,
  supports_proposal_value boolean,
  structured_claim_value jsonb
)
returns uuid
language sql
security definer
set search_path = ''
as $$
  select public.add_catalog_proposal_evidence_governed(
    proposal_id_value, source_registry_id, evidence_url_value,
    evidence_summary_value, observed_at_value, supports_proposal_value,
    structured_claim_value
  );
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
declare fact_type_value text;
begin
  select fact_type into fact_type_value from public.catalog_change_proposals
  where id = proposal_id_value;
  if fact_type_value = 'team_colors' then
    raise exception 'Use add_team_color_proposal_evidence with a structured claim for Team Color evidence';
  end if;
  return public.add_catalog_proposal_evidence_governed(
    proposal_id_value, source_registry_id, evidence_url_value,
    evidence_summary_value, observed_at_value, supports_proposal_value, null
  );
end;
$$;

create or replace function public.enforce_governed_catalog_evidence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare fact_type_value text;
begin
  if new.source_url_scope_version_id is null
     or new.source_trust_assignment_id is null
     or new.source_independence_assignment_id is null then
    raise exception 'New catalog evidence requires exact URL-scope, trust, and independence provenance';
  end if;
  select fact_type into strict fact_type_value
  from public.catalog_change_proposals where id = new.proposal_id;
  if fact_type_value = 'team_colors' and not public.validate_team_color_claim(new.structured_claim) then
    raise exception 'New Team Color evidence requires a valid structured claim';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_governed_catalog_evidence on public.catalog_proposal_evidence;
create trigger enforce_governed_catalog_evidence
before insert or update on public.catalog_proposal_evidence
for each row execute function public.enforce_governed_catalog_evidence();

create or replace function public.submit_team_color_source_candidate(
  work_item_id_value uuid,
  lease_token_value uuid,
  source_registry_id text,
  display_name_value text,
  base_url_value text,
  reference_url_value text,
  evidence_url_value text,
  discovery_summary_value text,
  observed_at_value timestamptz default now()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.team_color_work_items%rowtype;
  source_uuid uuid;
  candidate_id uuid;
  scope_uuid uuid;
  parts jsonb;
  match_count integer;
begin
  select * into strict work_record from public.team_color_work_items
  where id = work_item_id_value for update;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value
     or work_record.lease_expires_at <= now() then
    raise exception 'An unexpired Team Color work lease owned by this actor is required';
  end if;
  if not public.has_team_color_capability('team_colors.source_candidates.submit', work_record.team_id) then
    raise exception 'Team Color source-candidate capability is required';
  end if;
  if source_registry_id !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
     or nullif(btrim(display_name_value), '') is null
     or nullif(btrim(discovery_summary_value), '') is null then
    raise exception 'Source slug, display name, and discovery summary are required';
  end if;
  perform public.normalized_source_url_parts(base_url_value);
  perform public.normalized_source_url_parts(reference_url_value);
  parts := public.normalized_source_url_parts(evidence_url_value);

  select count(distinct match.canonical_source_id) into match_count
  from public.trusted_source_url_matches(evidence_url_value) match;
  if match_count > 0 then
    raise exception 'Evidence URL already resolves to one or more registry publishers; resolve/reuse it or request ambiguity review';
  end if;
  if exists (select 1 from public.trusted_sources where source_id = source_registry_id) then
    raise exception 'Source Registry ID already exists; resolve/reuse the canonical publisher';
  end if;
  if exists (
    select 1 from public.trusted_sources source
    where lower(regexp_replace(btrim(source.display_name), '\s+', ' ', 'g')) =
          lower(regexp_replace(btrim(display_name_value), '\s+', ' ', 'g'))
  ) then
    raise exception 'A potentially equivalent publisher already exists; request reviewer resolution';
  end if;

  insert into public.trusted_sources(
    source_id, display_name, base_url, reference_url, review_status, notes, metadata
  ) values (
    source_registry_id, btrim(display_name_value), base_url_value, reference_url_value,
    'pending_review', 'Submitted by a Team Color Agent for source-governance review.',
    jsonb_build_object('candidate_origin','team_color_agent','submitted_by_actor_id',actor_uuid,'submitted_at',now())
  ) returning id into source_uuid;
  insert into public.source_independence_group_assignment_versions(
    source_id, review_status, assigned_by_actor_id, notes
  ) values (source_uuid, 'pending_review', actor_uuid, 'Agent candidate; ownership review pending.');
  insert into public.trusted_source_alias_versions(
    source_id, alias, alias_type, created_by_actor_id
  ) values (source_uuid, source_registry_id, 'legacy_source_id', actor_uuid);
  insert into public.trusted_source_url_scope_versions(
    source_id, hostname, path_prefix, path_match, scope_kind,
    review_status, created_by_actor_id, review_notes
  ) values (
    source_uuid, parts ->> 'hostname', parts ->> 'path', 'exact', 'path_owner',
    'pending_review', actor_uuid, 'Exact candidate evidence URL; reviewer must establish reusable ownership scope.'
  ) returning id into scope_uuid;
  insert into public.team_color_source_candidates(
    work_item_id, source_id, evidence_url, discovery_summary, observed_at,
    submitted_by_actor_id, source_url_scope_version_id, resolution_snapshot
  ) values (
    work_record.id, source_uuid, evidence_url_value, btrim(discovery_summary_value),
    coalesce(observed_at_value, now()), actor_uuid, scope_uuid,
    jsonb_build_object('status','none','normalized_url',parts ->> 'normalized_url')
  ) returning id into candidate_id;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'source.candidate_submitted', 'trusted_source',
    source_registry_id, jsonb_build_object(
      'work_item_id', work_record.id, 'team_id', work_record.team_id,
      'review_status', 'pending_review', 'evidence_url', evidence_url_value,
      'url_scope_version_id', scope_uuid
    )
  );
  return candidate_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Append-only empirical reliability derived from verification outcomes
-- ---------------------------------------------------------------------------

create table public.team_color_source_reliability_observations (
  id uuid primary key default gen_random_uuid(),
  decision_id uuid not null references public.catalog_verification_decisions(id),
  proposal_id uuid not null references public.catalog_change_proposals(id),
  evidence_id uuid not null references public.catalog_proposal_evidence(id),
  source_id uuid not null references public.trusted_sources(id),
  independence_group_id uuid not null references public.source_independence_groups(id),
  team_id uuid not null references public.catalog_teams(id),
  sport_id uuid not null references public.catalog_sports(id),
  league_id uuid references public.catalog_leagues(id),
  outcome text not null check (outcome in (
    'match', 'contradiction', 'unresolved', 'not_assessable'
  )),
  claim_snapshot jsonb not null,
  verified_palette jsonb,
  independent_corroborating_group_count integer not null default 0
    check (independent_corroborating_group_count >= 0),
  evidence_observed_at timestamptz,
  decided_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (decision_id, evidence_id)
);

create index team_color_source_reliability_source_idx
on public.team_color_source_reliability_observations(source_id, decided_at desc);

create or replace function public.protect_team_color_source_reliability_observation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Team Color source reliability observations are append-only';
end;
$$;

create trigger team_color_source_reliability_append_only
before update or delete on public.team_color_source_reliability_observations
for each row execute function public.protect_team_color_source_reliability_observation();

create or replace function public.record_team_color_source_reliability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  decision_record public.catalog_verification_decisions%rowtype;
  evidence_record record;
  final_palette jsonb;
  corroborating_groups integer;
  outcome_value text;
  sport_uuid uuid;
  league_uuid uuid;
begin
  if new.fact_type <> 'team_colors' or new.status = old.status
     or new.status not in ('approved','rejected') then
    return new;
  end if;
  select * into strict decision_record
  from public.catalog_verification_decisions where proposal_id = new.id;
  select team.sport_id, membership.league_id into strict sport_uuid, league_uuid
  from public.catalog_teams team
  left join public.team_primary_league_versions membership
    on membership.team_id = team.id and membership.is_current
  where team.id = new.target_team_id;
  if new.status = 'approved' then
    final_palette := public.team_color_palette_from_payload(new.payload);
  end if;

  for evidence_record in
    select evidence.*,
           assignment.independence_group_id
    from public.catalog_proposal_evidence evidence
    join public.source_independence_group_assignment_versions assignment
      on assignment.id = evidence.source_independence_assignment_id
    where evidence.proposal_id = new.id
      and evidence.structured_claim is not null
  loop
    select count(distinct other_assignment.independence_group_id)
      into corroborating_groups
    from public.catalog_proposal_evidence other_evidence
    join public.source_independence_group_assignment_versions other_assignment
      on other_assignment.id = other_evidence.source_independence_assignment_id
    where other_evidence.proposal_id = new.id
      and other_evidence.id <> evidence_record.id
      and other_evidence.supports_proposal
      and other_evidence.structured_claim ->> 'classification' = 'current_canonical'
      and other_evidence.structured_claim -> 'palette' = final_palette
      and other_assignment.independence_group_id <> evidence_record.independence_group_id;

    if new.status = 'rejected' then
      outcome_value := 'unresolved';
    elsif evidence_record.structured_claim ->> 'classification' <> 'current_canonical' then
      outcome_value := 'not_assessable';
    elsif corroborating_groups < 1 then
      -- A publisher never earns a match or contradiction from a result that
      -- lacks corroboration outside its own ownership group.
      outcome_value := 'not_assessable';
    elsif evidence_record.structured_claim -> 'palette' = final_palette then
      outcome_value := 'match';
    else
      outcome_value := 'contradiction';
    end if;

    insert into public.team_color_source_reliability_observations(
      decision_id, proposal_id, evidence_id, source_id,
      independence_group_id, team_id, sport_id, league_id, outcome,
      claim_snapshot, verified_palette, independent_corroborating_group_count,
      evidence_observed_at, decided_at
    ) values (
      decision_record.id, new.id, evidence_record.id, evidence_record.source_id,
      evidence_record.independence_group_id, new.target_team_id, sport_uuid,
      league_uuid, outcome_value, evidence_record.structured_claim,
      final_palette, corroborating_groups, evidence_record.observed_at,
      decision_record.decided_at
    ) on conflict (decision_id, evidence_id) do nothing;
  end loop;
  return new;
end;
$$;

drop trigger if exists record_team_color_source_reliability on public.catalog_change_proposals;
create trigger record_team_color_source_reliability
after update of status on public.catalog_change_proposals
for each row execute function public.record_team_color_source_reliability();

create or replace view public.team_color_source_reliability_read_model
with (security_invoker = true)
as
with counts as (
  select public.canonical_trusted_source_id(source_id) as source_id,
         count(*) filter (where outcome = 'match')::integer as matches,
         count(*) filter (where outcome = 'contradiction')::integer as contradictions,
         count(*) filter (where outcome = 'unresolved')::integer as unresolved,
         count(*) filter (where outcome = 'not_assessable')::integer as not_assessable,
         count(*) filter (where outcome in ('match','contradiction'))::integer as assessed_sample_size,
         count(distinct team_id)::integer as team_breadth,
         count(distinct league_id) filter (where league_id is not null)::integer as league_breadth,
         count(distinct sport_id)::integer as sport_breadth,
         count(*) filter (where independent_corroborating_group_count > 0)::integer
           as independently_corroborated_observations,
         max(decided_at) as most_recent_outcome_at
  from public.team_color_source_reliability_observations
  group by public.canonical_trusted_source_id(source_id)
), rates as (
  select counts.*,
         case when assessed_sample_size = 0 then null
              else matches::numeric / assessed_sample_size end as raw_match_rate
  from counts
)
select source.source_id,
       source.display_name,
       independence.group_id as independence_group_id,
       coalesce(rates.matches, 0) as matches,
       coalesce(rates.contradictions, 0) as contradictions,
       coalesce(rates.unresolved, 0) as unresolved,
       coalesce(rates.not_assessable, 0) as not_assessable,
       coalesce(rates.assessed_sample_size, 0) as assessed_sample_size,
       rates.raw_match_rate,
       case when rates.assessed_sample_size is null or rates.assessed_sample_size = 0 then null
         else (
           rates.raw_match_rate + 3.8416 / (2 * rates.assessed_sample_size)
           - 1.96 * sqrt(
             (rates.raw_match_rate * (1 - rates.raw_match_rate)
               + 3.8416 / (4 * rates.assessed_sample_size))
             / rates.assessed_sample_size
           )
         ) / (1 + 3.8416 / rates.assessed_sample_size)
       end as conservative_match_rate,
       coalesce(rates.team_breadth, 0) as team_breadth,
       coalesce(rates.league_breadth, 0) as league_breadth,
       coalesce(rates.sport_breadth, 0) as sport_breadth,
       coalesce(rates.independently_corroborated_observations, 0)
         as independently_corroborated_observations,
       rates.most_recent_outcome_at
from public.trusted_sources source
left join public.source_independence_groups independence
  on independence.id = source.independence_group_id
left join rates on rates.source_id = source.id
where source.superseded_by_source_id is null;

comment on view public.team_color_source_reliability_read_model is
  'Read-only empirical outcomes. Governance review status and trust tier are intentionally excluded; reliability never changes trust automatically.';

-- Qualifying Team Color evidence is evaluated from the exact versions stored
-- on each evidence row. Current governance can change without rewriting the
-- decision-time provenance or accidentally broadening applicability.
create or replace function public.enforce_catalog_verification_policy_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  proposal_record public.catalog_change_proposals%rowtype;
  policy_record public.verification_policies%rowtype;
  current_color public.team_color_versions%rowtype;
  minimum_high_trust_count integer;
  high_trust_count integer;
  qualifying_count integer;
  independent_count integer;
  color_key text;
begin
  if new.decision <> 'approved' then return new; end if;
  select * into strict proposal_record
  from public.catalog_change_proposals where id = new.proposal_id;
  select * into strict policy_record
  from public.verification_policies where id = new.policy_id;
  minimum_high_trust_count := coalesce(
    (policy_record.configuration ->> 'minimum_tier_1_or_2_evidence_count')::integer, 0
  );

  if proposal_record.fact_type = 'team_colors' then
    select count(distinct evidence.id),
           count(distinct independence.independence_group_id),
           count(distinct evidence.id) filter (where trust.trust_tier in (1,2))
      into qualifying_count, independent_count, high_trust_count
    from public.catalog_proposal_evidence evidence
    join public.source_trust_assignments trust
      on trust.id = evidence.source_trust_assignment_id
    join public.source_independence_group_assignment_versions independence
      on independence.id = evidence.source_independence_assignment_id
    where evidence.proposal_id = proposal_record.id
      and evidence.supports_proposal
      and evidence.structured_claim ->> 'classification' = 'current_canonical'
      and evidence.structured_claim -> 'palette' =
          public.team_color_palette_from_payload(proposal_record.payload)
      and trust.trust_tier = any(policy_record.allowed_trust_tiers);
    if qualifying_count < policy_record.minimum_evidence_count then
      raise exception 'Proposal has % qualifying governed evidence rows; policy requires %',
        qualifying_count, policy_record.minimum_evidence_count;
    end if;
    if policy_record.require_independent_sources
       and independent_count < policy_record.minimum_evidence_count then
      raise exception 'Proposal does not have enough independently owned publisher groups';
    end if;
    if high_trust_count < minimum_high_trust_count then
      raise exception 'Policy requires at least % Tier 1 or Tier 2 evidence row(s)', minimum_high_trust_count;
    end if;
    if proposal_record.team_color_work_item_id is null
       or proposal_record.team_color_change_kind is null
       or nullif(btrim(proposal_record.proposal_reason), '') is null then
      raise exception 'Team Color approval requires autonomous-work safety metadata';
    end if;
    if not exists (
      select 1 from public.team_color_work_items work
      where work.id = proposal_record.team_color_work_item_id
        and work.proposal_id = proposal_record.id
        and work.status = 'pending_verification'
    ) then
      raise exception 'Team Color work must be submitted for verification before approval';
    end if;
    if proposal_record.proposed_by_actor_id = new.decided_by_actor_id then
      raise exception 'Team Color proposal builder and verifier must be different actors';
    end if;
    select * into current_color from public.team_color_versions
    where team_id = proposal_record.target_team_id and is_current for update;
    if current_color.id is distinct from proposal_record.expected_current_color_version_id then
      raise exception 'The current team-color version changed after research began';
    end if;
    if proposal_record.team_color_change_kind = 'verified_replacement' then
      if not found or current_color.record_status <> 'verified'
         or proposal_record.recheck_trigger is null then
        raise exception 'Verified replacement requires the expected verified version and a recheck trigger';
      end if;
    elsif found and current_color.record_status = 'verified' then
      raise exception 'A fill proposal cannot replace verified team colors';
    end if;
    foreach color_key in array array['primary','secondary'] loop
      if coalesce(proposal_record.payload ->> color_key, '') !~ '^#[0-9A-F]{6}$' then
        raise exception 'Team color % must be uppercase six-digit HEX (#RRGGBB)', color_key;
      end if;
    end loop;
    foreach color_key in array array['tertiary','quaternary','quinary'] loop
      if nullif(proposal_record.payload ->> color_key, '') is not null
         and proposal_record.payload ->> color_key !~ '^#[0-9A-F]{6}$' then
        raise exception 'Team color % must be uppercase six-digit HEX (#RRGGBB)', color_key;
      end if;
    end loop;
    select coalesce(jsonb_agg(jsonb_build_object(
      'evidence_id', evidence.id,
      'source_id', source.source_id,
      'source_display_name', source.display_name,
      'source_review_status', source.review_status,
      'independence_group_id', source_group.group_id,
      'independence_assignment_id', evidence.source_independence_assignment_id,
      'evidence_url', evidence.evidence_url,
      'url_scope_version_id', evidence.source_url_scope_version_id,
      'evidence_summary', evidence.evidence_summary,
      'structured_claim', evidence.structured_claim,
      'observed_at', evidence.observed_at,
      'evidence_created_at', evidence.created_at,
      'supports_proposal', evidence.supports_proposal,
      'trust_assignment_id', evidence.source_trust_assignment_id,
      'trust_tier', trust.trust_tier,
      'trust_scope', jsonb_build_object(
        'sport_id', trust_sport.sport_id,
        'league_id', trust_league.league_id,
        'team_id', trust_team.team_id
      ),
      'trust_effective_from', trust.effective_from,
      'trust_notes', trust.notes
    ) order by evidence.created_at, evidence.id), '[]'::jsonb)
    into new.evidence_snapshot
    from public.catalog_proposal_evidence evidence
    join public.trusted_sources source on source.id = evidence.source_id
    join public.source_trust_assignments trust
      on trust.id = evidence.source_trust_assignment_id
    join public.source_independence_group_assignment_versions independence
      on independence.id = evidence.source_independence_assignment_id
    join public.source_independence_groups source_group
      on source_group.id = independence.independence_group_id
    left join public.catalog_sports trust_sport on trust_sport.id = trust.sport_id
    left join public.catalog_leagues trust_league on trust_league.id = trust.league_id
    left join public.catalog_teams trust_team on trust_team.id = trust.team_id
    where evidence.proposal_id = proposal_record.id;
  else
    if minimum_high_trust_count > 0 then
      select count(distinct evidence.id) into high_trust_count
      from public.catalog_proposal_evidence evidence
      join public.source_trust_assignments trust
        on trust.id = evidence.source_trust_assignment_id
      where evidence.proposal_id = proposal_record.id
        and evidence.supports_proposal and trust.trust_tier in (1,2);
      if high_trust_count < minimum_high_trust_count then
        raise exception 'Policy requires at least % Tier 1 or Tier 2 evidence row(s)', minimum_high_trust_count;
      end if;
    end if;
  end if;

  if proposal_record.fact_type = 'team_venue_relationship'
     and policy_record.configuration ->> 'relationship_type' = 'primary'
     and proposal_record.payload ->> 'relationship_type' <> 'primary' then
    raise exception 'The active team venue policy applies only to primary venue relationships';
  end if;
  if proposal_record.fact_type = 'venue_mapping' then
    if proposal_record.proposed_by_actor_id = new.decided_by_actor_id then
      raise exception 'Venue mapping builder and verifier must be different actors';
    end if;
    if not public.has_catalog_capability(
      'venue.mapping.verify', null, null, null, proposal_record.target_venue_id
    ) then
      raise exception 'venue.mapping.verify capability is required';
    end if;
  end if;
  new.policy_snapshot := new.policy_snapshot || jsonb_build_object(
    'minimum_tier_1_or_2_evidence_count', minimum_high_trust_count,
    'required_verifier_capability', policy_record.configuration ->> 'required_verifier_capability',
    'trust_tier_rubric', policy_record.configuration -> 'trust_tier_rubric',
    'governed_source_versions', true
  );
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Safe registry backfill and the two established Edmonton publisher redirects
-- ---------------------------------------------------------------------------

insert into public.trusted_source_alias_versions(
  source_id, alias, alias_type, effective_from, notes
)
select source.id, source.source_id, 'legacy_source_id', source.created_at,
       'Backfilled source identifier alias.'
from public.trusted_sources source
on conflict do nothing;

insert into public.trusted_source_url_scope_versions(
  source_id, hostname, include_subdomains, path_prefix, path_match,
  scope_kind, review_status, effective_from, review_notes
)
select source.id, parts.value ->> 'hostname', false,
       parts.value ->> 'path', 'prefix', 'publisher', source.review_status,
       source.created_at, 'Backfilled from the pre-versioned base URL; overlapping publishers remain unresolved.'
from public.trusted_sources source
cross join lateral (
  select public.normalized_source_url_parts(source.base_url) value
) parts
where source.base_url ~* '^https?://[^[:space:]]+$'
on conflict do nothing;

insert into public.trusted_source_url_scope_versions(
  source_id, hostname, include_subdomains, path_prefix, path_match,
  scope_kind, review_status, effective_from, review_notes
)
select source.id, parts.value ->> 'hostname', false,
       parts.value ->> 'path', 'exact', 'document_host', source.review_status,
       source.created_at, 'Backfilled from the pre-versioned reference URL; reviewer may broaden only with evidence.'
from public.trusted_sources source
cross join lateral (
  select public.normalized_source_url_parts(source.reference_url) value
) parts
where source.reference_url ~* '^https?://[^[:space:]]+$'
on conflict do nothing;

do $$
declare
  migration_actor uuid;
  brand_group uuid;
  club_group uuid;
  oilers_team uuid;
  old_brand public.trusted_sources%rowtype;
  old_club public.trusted_sources%rowtype;
  brand_uuid uuid;
  club_uuid uuid;
  old_brand_trust public.source_trust_assignments%rowtype;
  old_club_trust public.source_trust_assignments%rowtype;
begin
  select id into strict migration_actor from public.catalog_actors
  where actor_key = 'theme-foundation-migration';
  select id into strict brand_group from public.source_independence_groups
  where group_id = 'brand-color-code';
  select id into strict club_group from public.source_independence_groups
  where group_id = 'edmonton-oilers-hockey-club';
  select id into strict oilers_team from public.catalog_teams
  where team_id = 'hockey-000027';
  select * into strict old_brand from public.trusted_sources
  where source_id = 'brand-color-code-edmonton-oilers';
  select * into strict old_club from public.trusted_sources
  where source_id = 'edmonton-oilers-brand-book';
  select * into strict old_brand_trust from public.source_trust_assignments
  where source_id = old_brand.id and data_type = 'team_colors' and is_current;
  select * into strict old_club_trust from public.source_trust_assignments
  where source_id = old_club.id and data_type = 'team_colors' and is_current;

  insert into public.trusted_sources(
    source_id, display_name, base_url, reference_url, independence_group_id,
    review_status, notes, metadata
  ) values (
    'brand-color-code', 'BrandColorCode', 'https://www.brandcolorcode.com',
    'https://www.brandcolorcode.com', brand_group, 'approved',
    'Reusable independent brand-color reference publisher. Team pages are evidence URLs, not separate publisher identities.',
    old_brand.metadata || jsonb_build_object('canonicalized_at', now(), 'canonicalized_from', old_brand.source_id)
  ) returning id into brand_uuid;
  insert into public.source_independence_group_assignment_versions(
    source_id, independence_group_id, review_status, assigned_by_actor_id, notes
  ) values (
    brand_uuid, brand_group, 'approved', migration_actor,
    'Ownership carried forward from the reviewed BrandColorCode Edmonton source.'
  );
  insert into public.trusted_source_alias_versions(
    source_id, alias, alias_type, created_by_actor_id, notes
  ) values
    (brand_uuid, 'Brand Color Code', 'publisher_name', migration_actor, 'Common publisher spelling.'),
    (brand_uuid, old_brand.source_id, 'legacy_source_id', migration_actor, 'Redirected historical source ID.');
  insert into public.trusted_source_url_scope_versions(
    source_id, hostname, include_subdomains, path_prefix, path_match,
    scope_kind, review_status, created_by_actor_id, review_notes
  ) values (
    brand_uuid, 'brandcolorcode.com', true, '/', 'prefix', 'publisher',
    'approved', migration_actor,
    'Reviewed reusable publisher scope; www and other publisher-controlled subdomains are permitted.'
  );
  insert into public.source_trust_assignments(
    source_id, data_type, trust_tier, effective_from, assigned_by_actor_id, notes
  ) values (
    brand_uuid, 'team_colors', old_brand_trust.trust_tier, current_date,
    migration_actor, 'Global publisher-level continuation of the reviewed Team Color trust assignment.'
  );

  insert into public.trusted_sources(
    source_id, display_name, base_url, reference_url, independence_group_id,
    review_status, notes, metadata
  ) values (
    'edmonton-oilers-hockey-club', 'Edmonton Oilers Hockey Club',
    'https://www.nhl.com/oilers', old_club.reference_url, club_group, 'approved',
    'Club-controlled official publisher, separate from league and unrelated NHL-hosted publishers.',
    old_club.metadata || jsonb_build_object('canonicalized_at', now(), 'canonicalized_from', old_club.source_id)
  ) returning id into club_uuid;
  insert into public.source_independence_group_assignment_versions(
    source_id, independence_group_id, review_status, assigned_by_actor_id, notes
  ) values (
    club_uuid, club_group, 'approved', migration_actor,
    'Club ownership carried forward from the reviewed official Edmonton source.'
  );
  insert into public.trusted_source_alias_versions(
    source_id, alias, alias_type, created_by_actor_id, notes
  ) values
    (club_uuid, 'Official Edmonton Oilers Brand Book', 'publisher_name', migration_actor, 'Historical source display name.'),
    (club_uuid, old_club.source_id, 'legacy_source_id', migration_actor, 'Redirected historical source ID.');
  insert into public.trusted_source_url_scope_versions(
    source_id, hostname, include_subdomains, path_prefix, path_match,
    scope_kind, review_status, created_by_actor_id, review_notes
  ) values (
    club_uuid, 'cloud.edmontonoilers.com', false, '/brand-hub', 'prefix',
    'document_host', 'approved', migration_actor,
    'Reviewed club-controlled brand-document path. No broad nhl.com ownership is inferred.'
  );
  insert into public.source_trust_assignments(
    source_id, data_type, trust_tier, effective_from, team_id,
    assigned_by_actor_id, notes
  ) values (
    club_uuid, 'team_colors', old_club_trust.trust_tier, current_date,
    oilers_team, migration_actor,
    'Team-scoped continuation of the reviewed Edmonton Oilers official-source trust assignment.'
  );

  insert into public.trusted_source_redirects(
    source_id, canonical_source_id, reason, redirected_by_actor_id
  ) values
    (old_brand.id, brand_uuid, 'Replaced team-specific seed identity with reusable publisher identity.', migration_actor),
    (old_club.id, club_uuid, 'Replaced document-specific seed identity with the club publisher identity.', migration_actor);
  update public.trusted_sources
  set review_status = 'retired', superseded_by_source_id = case id
      when old_brand.id then brand_uuid else club_uuid end,
      superseded_at = now(), updated_at = now()
  where id in (old_brand.id, old_club.id);
  update public.trusted_source_url_scope_versions
  set is_current = false, effective_to = now(), review_status = 'retired'
  where source_id in (old_brand.id, old_club.id) and is_current;
  update public.trusted_source_alias_versions
  set is_current = false, effective_to = now()
  where source_id in (old_brand.id, old_club.id) and is_current;
  update public.source_independence_group_assignment_versions
  set is_current = false, effective_to = now(), review_status = 'retired'
  where source_id in (old_brand.id, old_club.id) and is_current;
  update public.source_trust_assignments
  set is_current = false, effective_to = current_date, superseded_at = now()
  where source_id in (old_brand.id, old_club.id) and is_current;
  insert into public.catalog_audit_events(
    actor_id, action, entity_type, entity_id, details
  ) values
    (migration_actor, 'source.redirected', 'trusted_source', old_brand.source_id,
      jsonb_build_object('canonical_source_id','brand-color-code','historical_evidence_rewritten',false)),
    (migration_actor, 'source.redirected', 'trusted_source', old_club.source_id,
      jsonb_build_object('canonical_source_id','edmonton-oilers-hockey-club','historical_evidence_rewritten',false));

  if not exists (
    select 1 from public.catalog_proposal_evidence evidence
    where evidence.source_id = old_brand.id
  ) or not exists (
    select 1 from public.catalog_proposal_evidence evidence
    where evidence.source_id = old_club.id
  ) then
    raise exception 'Historical Edmonton evidence foreign keys were not preserved';
  end if;
  if not exists (
    select 1 from public.catalog_verification_decisions decision
    where decision.evidence_snapshot::text like '%brand-color-code-edmonton-oilers%'
      and decision.evidence_snapshot::text like '%edmonton-oilers-brand-book%'
  ) then
    raise exception 'Immutable Edmonton verification snapshot was not preserved';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Worker/reviewer read models, RLS, and least-privilege grants
-- ---------------------------------------------------------------------------

create or replace view public.trusted_source_review_read_model
with (security_invoker = true)
as
select
  source.source_id,
  source.display_name,
  source.base_url,
  source.reference_url,
  source.review_status,
  independence.group_id as independence_group_id,
  independence.display_name as independence_group_name,
  source.notes,
  source.metadata,
  coalesce(jsonb_agg(distinct jsonb_build_object(
    'data_type', trust.data_type,
    'trust_tier', trust.trust_tier,
    'effective_from', trust.effective_from,
    'sport_id', trust_sport.sport_id,
    'league_id', trust_league.league_id,
    'team_id', trust_team.team_id,
    'notes', trust.notes
  )) filter (where trust.id is not null), '[]'::jsonb) as current_trust_assignments,
  canonical.source_id as superseded_by_source_id,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'alias', alias.alias, 'alias_type', alias.alias_type,
      'version_id', alias.id
    ) order by alias.alias_type, alias.alias)
    from public.trusted_source_alias_versions alias
    where alias.source_id = source.id and alias.is_current
  ), '[]'::jsonb) as current_aliases,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'hostname', scope.hostname,
      'include_subdomains', scope.include_subdomains,
      'path_prefix', scope.path_prefix,
      'path_match', scope.path_match,
      'scope_kind', scope.scope_kind,
      'review_status', scope.review_status,
      'version_id', scope.id
    ) order by scope.hostname, length(scope.path_prefix) desc, scope.path_prefix)
    from public.trusted_source_url_scope_versions scope
    where scope.source_id = source.id and scope.is_current
  ), '[]'::jsonb) as current_url_scopes
from public.trusted_sources source
left join public.source_independence_groups independence
  on independence.id = source.independence_group_id
left join public.source_trust_assignments trust
  on trust.source_id = source.id and trust.is_current
left join public.catalog_sports trust_sport on trust_sport.id = trust.sport_id
left join public.catalog_leagues trust_league on trust_league.id = trust.league_id
left join public.catalog_teams trust_team on trust_team.id = trust.team_id
left join public.trusted_sources canonical
  on canonical.id = source.superseded_by_source_id
group by source.id, independence.id, canonical.id;

create or replace function public.applicable_team_color_sources(team_uuid uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'source_id', source.source_id,
    'display_name', source.display_name,
    'base_url', source.base_url,
    'reference_url', source.reference_url,
    'independence_group_id', independence.group_id,
    'independence_group_name', independence.display_name,
    'trust_assignment_id', trust.id,
    'trust_tier', trust.trust_tier,
    'trust_scope', case
      when trust.team_id is not null then 'team'
      when trust.league_id is not null then 'league'
      when trust.sport_id is not null then 'sport'
      else 'global' end,
    'trust_notes', trust.notes,
    'permitted_url_scopes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'hostname', scope.hostname,
        'include_subdomains', scope.include_subdomains,
        'path_prefix', scope.path_prefix,
        'path_match', scope.path_match,
        'scope_kind', scope.scope_kind
      ) order by scope.hostname, length(scope.path_prefix) desc)
      from public.trusted_source_url_scope_versions scope
      where scope.source_id = source.id and scope.is_current
        and scope.review_status = 'approved'
    ), '[]'::jsonb)
  ) order by trust.trust_tier, source.display_name), '[]'::jsonb)
  from public.trusted_sources source
  join public.source_independence_groups independence
    on independence.id = source.independence_group_id
  join public.source_trust_assignments trust
    on trust.id = public.applicable_source_trust_assignment(source.id, 'team_colors', team_uuid)
  where source.review_status = 'approved'
    and source.superseded_by_source_id is null
    and trust.trust_tier between 1 and 4;
$$;

alter function public.get_my_team_color_work(uuid, uuid)
rename to get_my_team_color_work_pre_publisher_governance;

create or replace function public.get_my_team_color_work(
  work_item_id_value uuid,
  lease_token_value uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  context_value jsonb;
  team_uuid uuid;
begin
  context_value := public.get_my_team_color_work_pre_publisher_governance(
    work_item_id_value, lease_token_value
  );
  select team_id into strict team_uuid
  from public.team_color_work_items where id = work_item_id_value;
  context_value := jsonb_set(
    context_value, '{approved_sources}',
    public.applicable_team_color_sources(team_uuid), true
  );
  return context_value || jsonb_build_object(
    'source_resolution', jsonb_build_object(
      'required_before_candidate_submission', true,
      'rpc', 'resolve_team_color_source',
      'evidence_rpc', 'add_team_color_proposal_evidence'
    )
  );
end;
$$;

-- The standalone resolver is intentionally readable by any active catalog
-- actor. It returns publisher identity/governance metadata, not catalog facts.
create or replace function public.resolve_trusted_source_url(evidence_url_value text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  best_specificity integer;
  result_value jsonb;
  source_count integer;
begin
  if actor_uuid is null then raise exception 'An active catalog actor is required'; end if;
  select max(match.specificity) into best_specificity
  from public.trusted_source_url_matches(evidence_url_value) match;
  if best_specificity is null then
    return jsonb_build_object(
      'status', 'none', 'normalized_url', public.normalize_source_url(evidence_url_value),
      'matches', '[]'::jsonb
    );
  end if;
  select count(distinct match.canonical_source_id),
         coalesce(jsonb_agg(distinct jsonb_build_object(
           'source_id', source.source_id, 'display_name', source.display_name,
           'review_status', source.review_status,
           'url_scope_version_id', match.url_scope_version_id
         )), '[]'::jsonb)
    into source_count, result_value
  from public.trusted_source_url_matches(evidence_url_value) match
  join public.trusted_sources source on source.id = match.canonical_source_id
  where match.specificity = best_specificity;
  return jsonb_build_object(
    'status', case when source_count = 1 then 'resolved' else 'ambiguous' end,
    'normalized_url', public.normalize_source_url(evidence_url_value),
    'matches', result_value
  );
end;
$$;

alter table public.trusted_source_alias_versions enable row level security;
alter table public.trusted_source_url_scope_versions enable row level security;
alter table public.source_independence_group_assignment_versions enable row level security;
alter table public.trusted_source_redirects enable row level security;
alter table public.team_color_source_reliability_observations enable row level security;

revoke all on public.trusted_source_alias_versions from public, anon, authenticated;
revoke all on public.trusted_source_url_scope_versions from public, anon, authenticated;
revoke all on public.source_independence_group_assignment_versions from public, anon, authenticated;
revoke all on public.trusted_source_redirects from public, anon, authenticated;
revoke all on public.team_color_source_reliability_observations from public, anon, authenticated;

create policy "Source governors read publisher aliases"
on public.trusted_source_alias_versions for select to authenticated
using (
  public.has_staff_access(array['admin','staff','content_admin']::text[], null)
  or public.has_catalog_capability('source.registry.review')
);
create policy "Source governors read publisher URL scopes"
on public.trusted_source_url_scope_versions for select to authenticated
using (
  public.has_staff_access(array['admin','staff','content_admin']::text[], null)
  or public.has_catalog_capability('source.registry.review')
);
create policy "Source governors read ownership versions"
on public.source_independence_group_assignment_versions for select to authenticated
using (
  public.has_staff_access(array['admin','staff','content_admin']::text[], null)
  or public.has_catalog_capability('source.registry.review')
);
create policy "Source governors read publisher redirects"
on public.trusted_source_redirects for select to authenticated
using (
  public.has_staff_access(array['admin','staff','content_admin']::text[], null)
  or public.has_catalog_capability('source.registry.review')
);
create policy "Authorized readers view source reliability"
on public.team_color_source_reliability_observations for select to authenticated
using (
  public.has_staff_access(array['admin','staff','content_admin']::text[], null)
  or public.has_catalog_capability('source.registry.review')
  or public.has_catalog_capability('team_colors.work.read')
);

grant select on public.trusted_source_alias_versions,
  public.trusted_source_url_scope_versions,
  public.source_independence_group_assignment_versions,
  public.trusted_source_redirects,
  public.team_color_source_reliability_observations to authenticated;
grant select on public.trusted_source_review_read_model,
  public.team_color_source_reliability_read_model to authenticated;

revoke all on function public.trusted_source_url_matches(text) from public, anon, authenticated;
revoke all on function public.canonical_trusted_source_id(uuid) from public, anon, authenticated;
revoke all on function public.applicable_source_trust_assignment(uuid,text,uuid) from public, anon, authenticated;
revoke all on function public.applicable_team_color_sources(uuid) from public, anon, authenticated;
revoke all on function public.add_catalog_proposal_evidence_governed(uuid,text,text,text,timestamptz,boolean,jsonb) from public, anon, authenticated;
revoke all on function public.enforce_governed_catalog_evidence() from public, anon, authenticated;
revoke all on function public.protect_team_color_source_reliability_observation() from public, anon, authenticated;
revoke all on function public.record_team_color_source_reliability() from public, anon, authenticated;
revoke all on function public.get_my_team_color_work_pre_publisher_governance(uuid,uuid) from public, anon, authenticated;

revoke all on function public.resolve_trusted_source_url(text) from public, anon;
grant execute on function public.resolve_trusted_source_url(text) to authenticated;
revoke all on function public.resolve_team_color_source(uuid,uuid,text) from public, anon;
grant execute on function public.resolve_team_color_source(uuid,uuid,text) to authenticated;
revoke all on function public.add_team_color_proposal_evidence(uuid,text,text,text,timestamptz,boolean,jsonb) from public, anon;
grant execute on function public.add_team_color_proposal_evidence(uuid,text,text,text,timestamptz,boolean,jsonb) to authenticated;
revoke all on function public.get_my_team_color_work(uuid,uuid) from public, anon;
grant execute on function public.get_my_team_color_work(uuid,uuid) to authenticated;
revoke all on function public.admin_upsert_trusted_source(text,text,text,text,text,text,text,jsonb) from public, anon;
grant execute on function public.admin_upsert_trusted_source(text,text,text,text,text,text,text,jsonb) to authenticated;
revoke all on function public.review_trusted_source(text,text,text,text) from public, anon;
grant execute on function public.review_trusted_source(text,text,text,text) to authenticated;
revoke all on function public.review_trusted_source_url_scope(text,text,boolean,text,text,text,text,text) from public, anon;
grant execute on function public.review_trusted_source_url_scope(text,text,boolean,text,text,text,text,text) to authenticated;
revoke all on function public.add_trusted_source_alias(text,text,text,text) from public, anon;
grant execute on function public.add_trusted_source_alias(text,text,text,text) to authenticated;
revoke all on function public.admin_set_source_trust_scoped(text,text,smallint,text,text,text,text) from public, anon;
grant execute on function public.admin_set_source_trust_scoped(text,text,smallint,text,text,text,text) to authenticated;
revoke all on function public.admin_set_source_trust(text,text,smallint,text) from public, anon;
grant execute on function public.admin_set_source_trust(text,text,smallint,text) to authenticated;
revoke all on function public.redirect_trusted_source(text,text,text) from public, anon;
grant execute on function public.redirect_trusted_source(text,text,text) to authenticated;

revoke all on function public.enforce_catalog_verification_policy_decision() from public, anon, authenticated;
revoke all on function public.submit_team_color_source_candidate(uuid,uuid,text,text,text,text,text,text,timestamptz) from public, anon;
grant execute on function public.submit_team_color_source_candidate(uuid,uuid,text,text,text,text,text,text,timestamptz) to authenticated;

comment on table public.trusted_source_url_scope_versions is
  'Versioned permitted URL ownership. Hostname alone never implies publisher identity; subdomain and path rules are explicit.';
comment on table public.source_independence_group_assignment_versions is
  'Versioned common-ownership classification. Multiple URLs from one group still count as one independent source.';
comment on table public.team_color_source_reliability_observations is
  'Append-only empirical outcomes from later verification. These observations never grant or alter governance trust.';
comment on function public.resolve_team_color_source(uuid,uuid,text) is
  'Lease-scoped read-only publisher resolver. Returns none, resolved, or ambiguous and checks Team Color trust applicability.';
comment on function public.add_team_color_proposal_evidence(uuid,text,text,text,timestamptz,boolean,jsonb) is
  'Adds governed Team Color evidence with exact publisher URL scope, applicability, ownership, trust, and structured palette claim versions.';

do $$
begin
  if (select count(*) from public.trusted_sources where review_status = 'pending_review') <> 130 then
    raise exception 'The 130 unresolved imported source candidates must remain pending_review';
  end if;
  if exists (
    select 1 from public.source_trust_assignments trust
    join public.trusted_sources source on source.id = trust.source_id
    where trust.is_current and source.source_id in ('nhl','sportslogos-net')
  ) then
    raise exception 'Migration must not grant new NHL or SportsLogos.Net trust';
  end if;
  if (select count(*) from public.trusted_source_redirects) < 2 then
    raise exception 'Expected the two reviewed Edmonton seed redirects';
  end if;
end $$;
