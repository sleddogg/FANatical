-- Phase 4 backend entry contract. This migration deliberately stops before
-- React/UI work. It establishes the only durable follow/scope/mute/Dismiss
-- state, governed followability and Demo configuration, and fan-safe feed reads.

-- Extend the BL-027 registry before creating the first Phase 4 table.
alter function private.news_domain_mutation_registry()
rename to news_domain_mutation_registry_through_phase3;

create or replace function private.news_domain_mutation_registry()
returns table (
  table_schema text,
  table_name text,
  mutation_mode text,
  canonical_operations text[],
  rationale text
)
language sql
stable
security definer
set search_path = ''
as $$
  select * from private.news_domain_mutation_registry_through_phase3()
  union all
  select *
  from (values
    ('public', 'news_phase4_configuration_decisions', 'governed', array['public.admin_set_news_identity_followability(text,text,boolean,text)','public.admin_set_news_demo_universe(jsonb,text)'], 'Append-only staff decisions own Phase 4 followability and Demo configuration.'),
    ('public', 'news_followable_identity_versions', 'governed', array['public.admin_set_news_identity_followability(text,text,boolean,text)'], 'Followability is versioned through one staff-authorized operation and is independent of publisher trust.'),
    ('public', 'news_demo_configuration_versions', 'governed', array['public.admin_set_news_demo_universe(jsonb,text)'], 'The signed-out Demo universe is versioned through one staff-authorized operation.'),
    ('public', 'news_demo_configuration_identities', 'governed', array['public.admin_set_news_demo_universe(jsonb,text)'], 'Demo members are immutable children of a governed configuration version.'),
    ('public', 'user_news_identity_follows', 'governed', array['public.follow_news_identity(text,text,text[],text[])','public.mute_my_news_follow(uuid,text)','public.unmute_my_news_follow(uuid)','public.unfollow_news_identity(uuid)'], 'Account-owned follows are writable only through owner-scoped RPCs.'),
    ('public', 'user_news_follow_scopes', 'governed', array['public.follow_news_identity(text,text,text[],text[])','public.set_my_news_follow_scopes(uuid,text[],text[])'], 'All/Sport/Team scopes are replaced only through owner-scoped RPCs.'),
    ('public', 'user_news_item_dismissals', 'governed', array['public.dismiss_news_item(text)','public.undo_news_item_dismissal(text)'], 'Per-fan display suppression and Undo are owner-scoped and never mutate canonical News.' )
  ) registry(table_schema, table_name, mutation_mode, canonical_operations, rationale);
$$;

revoke all on function private.news_domain_mutation_registry_through_phase3()
from public, anon, authenticated;
revoke all on function private.news_domain_mutation_registry()
from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Governed followability and signed-out Demo configuration
-- ---------------------------------------------------------------------------

create table public.news_phase4_configuration_decisions (
  id uuid primary key default gen_random_uuid(),
  action text not null check (action in (
    'set_identity_followability', 'set_demo_universe'
  )),
  notes text not null check (length(btrim(notes)) > 0),
  decided_by_user_id uuid not null references auth.users(id),
  decided_by_actor_id uuid references public.catalog_actors(id),
  decided_at timestamptz not null default clock_timestamp()
);

create table public.news_followable_identity_versions (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (target_type in (
    'author', 'organization', 'show'
  )),
  person_id uuid references public.catalog_people(id),
  organizational_contributor_id uuid
    references public.news_organizational_contributors(id),
  show_id uuid references public.podcast_shows(id),
  followable boolean not null,
  rationale text not null check (length(btrim(rationale)) > 0),
  recorded_from timestamptz not null,
  recorded_to timestamptz,
  is_current boolean not null default true,
  decision_id uuid not null references public.news_phase4_configuration_decisions(id),
  supersedes_version_id uuid references public.news_followable_identity_versions(id),
  superseded_at timestamptz,
  closed_by_decision_id uuid references public.news_phase4_configuration_decisions(id),
  created_at timestamptz not null default now(),
  check (num_nonnulls(person_id, organizational_contributor_id, show_id) = 1),
  check (
    (target_type = 'author' and person_id is not null)
    or (target_type = 'organization' and organizational_contributor_id is not null)
    or (target_type = 'show' and show_id is not null)
  ),
  check (recorded_to is null or recorded_to >= recorded_from)
);

create unique index news_followable_author_current_idx
on public.news_followable_identity_versions(person_id)
where is_current and target_type = 'author';
create unique index news_followable_organization_current_idx
on public.news_followable_identity_versions(organizational_contributor_id)
where is_current and target_type = 'organization';
create unique index news_followable_show_current_idx
on public.news_followable_identity_versions(show_id)
where is_current and target_type = 'show';

create table public.news_demo_configuration_versions (
  id uuid primary key default gen_random_uuid(),
  configuration_key text not null default 'signed_out_demo'
    check (configuration_key = 'signed_out_demo'),
  version_number integer not null check (version_number > 0),
  recorded_from timestamptz not null,
  recorded_to timestamptz,
  is_current boolean not null default true,
  decision_id uuid not null references public.news_phase4_configuration_decisions(id),
  supersedes_version_id uuid references public.news_demo_configuration_versions(id),
  superseded_at timestamptz,
  closed_by_decision_id uuid references public.news_phase4_configuration_decisions(id),
  created_at timestamptz not null default now(),
  unique (configuration_key, version_number),
  check (recorded_to is null or recorded_to >= recorded_from)
);

create unique index news_demo_configuration_current_idx
on public.news_demo_configuration_versions(configuration_key)
where is_current;

create table public.news_demo_configuration_identities (
  configuration_version_id uuid not null
    references public.news_demo_configuration_versions(id),
  ordinal integer not null check (ordinal > 0),
  target_type text not null check (target_type in (
    'author', 'organization', 'show'
  )),
  person_id uuid references public.catalog_people(id),
  organizational_contributor_id uuid
    references public.news_organizational_contributors(id),
  show_id uuid references public.podcast_shows(id),
  created_at timestamptz not null default now(),
  primary key (configuration_version_id, ordinal),
  check (num_nonnulls(person_id, organizational_contributor_id, show_id) = 1),
  check (
    (target_type = 'author' and person_id is not null)
    or (target_type = 'organization' and organizational_contributor_id is not null)
    or (target_type = 'show' and show_id is not null)
  )
);

create unique index news_demo_configuration_author_idx
on public.news_demo_configuration_identities(configuration_version_id, person_id)
where target_type = 'author';
create unique index news_demo_configuration_organization_idx
on public.news_demo_configuration_identities(
  configuration_version_id, organizational_contributor_id
)
where target_type = 'organization';
create unique index news_demo_configuration_show_idx
on public.news_demo_configuration_identities(configuration_version_id, show_id)
where target_type = 'show';

-- ---------------------------------------------------------------------------
-- Account-owned follow, scope, mute, and Dismiss state
-- ---------------------------------------------------------------------------

create table public.user_news_identity_follows (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  target_type text not null check (target_type in (
    'author', 'organization', 'show'
  )),
  person_id uuid references public.catalog_people(id),
  organizational_contributor_id uuid
    references public.news_organizational_contributors(id),
  show_id uuid references public.podcast_shows(id),
  canonical_person_id_at_follow uuid references public.catalog_people(id),
  person_merge_decision_ids_at_follow uuid[] not null default array[]::uuid[],
  muted_until timestamptz,
  followed_at timestamptz not null default statement_timestamp(),
  unfollowed_at timestamptz,
  is_current boolean not null default true,
  created_at timestamptz not null default now(),
  check (num_nonnulls(person_id, organizational_contributor_id, show_id) = 1),
  check (
    (target_type = 'author' and person_id is not null
      and canonical_person_id_at_follow is not null)
    or (target_type = 'organization' and organizational_contributor_id is not null
      and canonical_person_id_at_follow is null
      and cardinality(person_merge_decision_ids_at_follow) = 0)
    or (target_type = 'show' and show_id is not null
      and canonical_person_id_at_follow is null
      and cardinality(person_merge_decision_ids_at_follow) = 0)
  ),
  check (
    (is_current and unfollowed_at is null)
    or (not is_current and unfollowed_at is not null)
  ),
  check (unfollowed_at is null or unfollowed_at >= followed_at)
);

create unique index user_news_author_follow_current_idx
on public.user_news_identity_follows(user_id, person_id)
where is_current and target_type = 'author';
create unique index user_news_organization_follow_current_idx
on public.user_news_identity_follows(user_id, organizational_contributor_id)
where is_current and target_type = 'organization';
create unique index user_news_show_follow_current_idx
on public.user_news_identity_follows(user_id, show_id)
where is_current and target_type = 'show';
create index user_news_follows_owner_current_idx
on public.user_news_identity_follows(user_id, is_current, target_type);

create table public.user_news_follow_scopes (
  follow_id uuid not null references public.user_news_identity_follows(id),
  scope_type text not null check (scope_type in ('sport', 'team')),
  sport_id uuid references public.catalog_sports(id),
  team_id uuid references public.catalog_teams(id),
  created_at timestamptz not null default now(),
  check (num_nonnulls(sport_id, team_id) = 1),
  check (
    (scope_type = 'sport' and sport_id is not null)
    or (scope_type = 'team' and team_id is not null)
  )
);

create unique index user_news_follow_sport_scope_idx
on public.user_news_follow_scopes(follow_id, sport_id)
where scope_type = 'sport';
create unique index user_news_follow_team_scope_idx
on public.user_news_follow_scopes(follow_id, team_id)
where scope_type = 'team';

create table public.user_news_item_dismissals (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  news_item_id uuid not null references public.news_items(id),
  dismissed_at timestamptz not null default statement_timestamp(),
  primary key (user_id, news_item_id)
);

-- No browser role receives direct table access. All reads and writes below are
-- deliberately bounded SECURITY DEFINER RPCs.
do $$
declare table_name text;
begin
  foreach table_name in array array[
    'news_phase4_configuration_decisions',
    'news_followable_identity_versions',
    'news_demo_configuration_versions',
    'news_demo_configuration_identities',
    'user_news_identity_follows',
    'user_news_follow_scopes',
    'user_news_item_dismissals'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format(
      'revoke all on table public.%I from public, anon, authenticated',
      table_name
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Protection and target-resolution helpers
-- ---------------------------------------------------------------------------

create or replace function public.protect_news_phase4_history_row()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'News Phase 4 configuration history cannot be overwritten or deleted';
end;
$$;

create or replace function public.protect_news_phase4_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'News Phase 4 version history cannot be deleted';
  end if;
  if old.is_current = false
     or new.is_current = true
     or new.recorded_to is null
     or new.superseded_at is null
     or new.closed_by_decision_id is null then
    raise exception 'News Phase 4 versions may only transition from current to superseded';
  end if;
  if (to_jsonb(old)
        - 'is_current' - 'recorded_to' - 'superseded_at' - 'closed_by_decision_id')
     is distinct from
     (to_jsonb(new)
        - 'is_current' - 'recorded_to' - 'superseded_at' - 'closed_by_decision_id') then
    raise exception 'Historical News Phase 4 configuration cannot be overwritten';
  end if;
  return new;
end;
$$;

create trigger protect_news_phase4_configuration_decisions
before update or delete on public.news_phase4_configuration_decisions
for each row execute function public.protect_news_phase4_history_row();
create trigger protect_news_followable_identity_versions
before update or delete on public.news_followable_identity_versions
for each row execute function public.protect_news_phase4_version();
create trigger protect_news_demo_configuration_versions
before update or delete on public.news_demo_configuration_versions
for each row execute function public.protect_news_phase4_version();
create trigger protect_news_demo_configuration_identities
before update or delete on public.news_demo_configuration_identities
for each row execute function public.protect_news_phase4_history_row();

create or replace function private.resolve_news_follow_target(
  target_type_value text,
  target_public_id_value text
)
returns table (
  target_type text,
  person_id uuid,
  organizational_contributor_id uuid,
  show_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  requested_person_uuid uuid;
  canonical_person_uuid uuid;
begin
  if target_type_value = 'author' then
    select profile.person_id into requested_person_uuid
    from public.news_author_profiles profile
    where profile.author_id = target_public_id_value;
    if requested_person_uuid is null then
      raise exception 'News Author follow target does not exist';
    end if;
    canonical_person_uuid := private.try_resolve_news_canonical_person(requested_person_uuid);
    if canonical_person_uuid is null then
      raise exception 'News Author follow target is temporarily unavailable';
    end if;
    if not exists (
      select 1
      from public.news_author_profiles profile
      join public.person_identity_versions identity
        on identity.person_id = profile.person_id
       and identity.is_current and identity.active
      where profile.person_id = canonical_person_uuid
    ) then
      raise exception 'Canonical News Author follow target is not active';
    end if;
    return query select 'author'::text, canonical_person_uuid, null::uuid, null::uuid;
  elsif target_type_value = 'organization' then
    return query
    select 'organization'::text, null::uuid, contributor.id, null::uuid
    from public.news_organizational_contributors contributor
    join public.news_organizational_contributor_versions identity
      on identity.organizational_contributor_id = contributor.id
     and identity.is_current and identity.active
    where contributor.contributor_id = target_public_id_value;
    if not found then raise exception 'News organization follow target does not exist or is inactive'; end if;
  elsif target_type_value = 'show' then
    return query
    select 'show'::text, null::uuid, null::uuid, show_record.id
    from public.podcast_shows show_record
    join public.podcast_show_identity_versions identity
      on identity.show_id = show_record.id
     and identity.is_current and identity.active
    where show_record.show_id = target_public_id_value;
    if not found then raise exception 'Podcast Show follow target does not exist or is inactive'; end if;
  else
    raise exception 'News follow target must be an author, organization, or show';
  end if;
end;
$$;

create or replace function private.record_news_phase4_configuration_decision(
  action_value text,
  notes_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare decision_uuid uuid := gen_random_uuid();
begin
  if length(btrim(coalesce(notes_value, ''))) = 0 then
    raise exception 'A governed News Phase 4 configuration decision requires a reason';
  end if;
  insert into public.news_phase4_configuration_decisions(
    id, action, notes, decided_by_user_id, decided_by_actor_id
  ) values (
    decision_uuid, action_value, notes_value, auth.uid(),
    public.current_catalog_actor_id()
  );
  return decision_uuid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Staff configuration operations
-- ---------------------------------------------------------------------------

create or replace function public.admin_set_news_identity_followability(
  target_type_value text,
  target_public_id_value text,
  followable_value boolean,
  rationale_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_record record;
  current_record public.news_followable_identity_versions%rowtype;
  decision_uuid uuid;
  decision_at_value timestamptz;
  version_uuid uuid := gen_random_uuid();
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News configuration staff access is required';
  end if;
  select * into strict target_record
  from private.resolve_news_follow_target(target_type_value, target_public_id_value);

  select * into current_record
  from public.news_followable_identity_versions version
  where version.is_current
    and (
      (target_record.target_type = 'author' and version.target_type = 'author'
        and version.person_id = target_record.person_id)
      or (target_record.target_type = 'organization' and version.target_type = 'organization'
        and version.organizational_contributor_id = target_record.organizational_contributor_id)
      or (target_record.target_type = 'show' and version.target_type = 'show'
        and version.show_id = target_record.show_id)
    )
  for update;
  if found and current_record.followable = followable_value then
    raise exception 'This News identity already has the requested followability state';
  end if;

  decision_uuid := private.record_news_phase4_configuration_decision(
    'set_identity_followability', rationale_value
  );
  select decided_at into decision_at_value
  from public.news_phase4_configuration_decisions where id = decision_uuid;

  if current_record.id is not null then
    update public.news_followable_identity_versions
    set is_current = false,
        recorded_to = decision_at_value,
        superseded_at = decision_at_value,
        closed_by_decision_id = decision_uuid
    where id = current_record.id;
  end if;

  insert into public.news_followable_identity_versions(
    id, target_type, person_id, organizational_contributor_id, show_id,
    followable, rationale, recorded_from, decision_id, supersedes_version_id
  ) values (
    version_uuid, target_record.target_type, target_record.person_id,
    target_record.organizational_contributor_id, target_record.show_id,
    followable_value, rationale_value, decision_at_value, decision_uuid,
    current_record.id
  );
  return version_uuid;
end;
$$;

create or replace function public.admin_set_news_demo_universe(
  targets_value jsonb,
  notes_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  decision_uuid uuid;
  decision_at_value timestamptz;
  current_record public.news_demo_configuration_versions%rowtype;
  configuration_uuid uuid := gen_random_uuid();
  next_version_number integer;
  target_count integer;
  inserted_count integer;
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News configuration staff access is required';
  end if;
  if jsonb_typeof(targets_value) <> 'array' then
    raise exception 'News Demo universe must be a JSON array';
  end if;
  target_count := jsonb_array_length(targets_value);

  select * into current_record
  from public.news_demo_configuration_versions
  where configuration_key = 'signed_out_demo' and is_current
  for update;
  select coalesce(max(version_number), 0) + 1 into next_version_number
  from public.news_demo_configuration_versions
  where configuration_key = 'signed_out_demo';

  decision_uuid := private.record_news_phase4_configuration_decision(
    'set_demo_universe', notes_value
  );
  select decided_at into decision_at_value
  from public.news_phase4_configuration_decisions where id = decision_uuid;

  if current_record.id is not null then
    update public.news_demo_configuration_versions
    set is_current = false,
        recorded_to = decision_at_value,
        superseded_at = decision_at_value,
        closed_by_decision_id = decision_uuid
    where id = current_record.id;
  end if;

  insert into public.news_demo_configuration_versions(
    id, version_number, recorded_from, decision_id, supersedes_version_id
  ) values (
    configuration_uuid, next_version_number, decision_at_value,
    decision_uuid, current_record.id
  );

  insert into public.news_demo_configuration_identities(
    configuration_version_id, ordinal, target_type,
    person_id, organizational_contributor_id, show_id
  )
  select
    configuration_uuid,
    target.ordinality::integer,
    resolved.target_type,
    resolved.person_id,
    resolved.organizational_contributor_id,
    resolved.show_id
  from jsonb_array_elements(targets_value) with ordinality target(value, ordinality)
  cross join lateral private.resolve_news_follow_target(
    target.value ->> 'target_type',
    target.value ->> 'target_id'
  ) resolved
  where exists (
    select 1
    from public.news_followable_identity_versions followability
    where followability.is_current and followability.followable
      and followability.target_type = resolved.target_type
      and (
        (resolved.target_type = 'author' and followability.person_id = resolved.person_id)
        or (resolved.target_type = 'organization'
          and followability.organizational_contributor_id = resolved.organizational_contributor_id)
        or (resolved.target_type = 'show' and followability.show_id = resolved.show_id)
      )
  );
  get diagnostics inserted_count = row_count;
  if inserted_count <> target_count then
    raise exception 'Every News Demo identity must be unique, active, and currently followable';
  end if;
  return configuration_uuid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Owner-scoped follow, scope, mute, Dismiss, and Undo operations
-- ---------------------------------------------------------------------------

create or replace function private.replace_my_news_follow_scopes(
  follow_id_value uuid,
  owner_id_value uuid,
  sport_scope_ids_value text[],
  team_scope_ids_value text[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from unnest(coalesce(sport_scope_ids_value, array[]::text[])) scope_id
    where not exists (
      select 1 from public.catalog_sports sport where sport.sport_id = scope_id
    )
  ) then
    raise exception 'A requested News Sport follow scope does not exist';
  end if;
  if exists (
    select 1 from unnest(coalesce(team_scope_ids_value, array[]::text[])) scope_id
    where not exists (
      select 1 from public.catalog_teams team where team.team_id = scope_id
    )
  ) then
    raise exception 'A requested News Team follow scope does not exist';
  end if;
  if not exists (
    select 1 from public.user_news_identity_follows follow
    where follow.id = follow_id_value and follow.user_id = owner_id_value
      and follow.is_current
  ) then
    raise exception 'Current News follow does not belong to this fan';
  end if;

  delete from public.user_news_follow_scopes where follow_id = follow_id_value;
  insert into public.user_news_follow_scopes(follow_id, scope_type, sport_id)
  select follow_id_value, 'sport', sport.id
  from public.catalog_sports sport
  where sport.sport_id = any(coalesce(sport_scope_ids_value, array[]::text[]));
  insert into public.user_news_follow_scopes(follow_id, scope_type, team_id)
  select follow_id_value, 'team', team.id
  from public.catalog_teams team
  where team.team_id = any(coalesce(team_scope_ids_value, array[]::text[]));
end;
$$;

create or replace function public.follow_news_identity(
  target_type_value text,
  target_public_id_value text,
  sport_scope_ids_value text[] default array[]::text[],
  team_scope_ids_value text[] default array[]::text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_uuid uuid := auth.uid();
  target_record record;
  follow_uuid uuid := gen_random_uuid();
  requested_person_uuid uuid;
begin
  if owner_uuid is null then raise exception 'Authentication is required'; end if;
  select * into strict target_record
  from private.resolve_news_follow_target(target_type_value, target_public_id_value);

  if not exists (
    select 1
    from public.news_followable_identity_versions followability
    where followability.is_current and followability.followable
      and followability.target_type = target_record.target_type
      and (
        (target_record.target_type = 'author' and followability.person_id = target_record.person_id)
        or (target_record.target_type = 'organization'
          and followability.organizational_contributor_id = target_record.organizational_contributor_id)
        or (target_record.target_type = 'show' and followability.show_id = target_record.show_id)
      )
  ) then
    raise exception 'News identity is not currently approved as followable';
  end if;

  if target_record.target_type = 'author' then
    select profile.person_id into strict requested_person_uuid
    from public.news_author_profiles profile
    where profile.author_id = target_public_id_value;
    if exists (
      select 1
      from public.user_news_identity_follows follow
      where follow.user_id = owner_uuid and follow.is_current
        and follow.target_type = 'author'
        and private.try_resolve_news_canonical_person(follow.person_id)
          = target_record.person_id
    ) then
      raise exception 'This fan already follows the current canonical Author';
    end if;
  elsif target_record.target_type = 'organization' and exists (
    select 1 from public.user_news_identity_follows follow
    where follow.user_id = owner_uuid and follow.is_current
      and follow.target_type = 'organization'
      and follow.organizational_contributor_id = target_record.organizational_contributor_id
  ) then
    raise exception 'This fan already follows the organization';
  elsif target_record.target_type = 'show' and exists (
    select 1 from public.user_news_identity_follows follow
    where follow.user_id = owner_uuid and follow.is_current
      and follow.target_type = 'show' and follow.show_id = target_record.show_id
  ) then
    raise exception 'This fan already follows the Show';
  end if;

  insert into public.user_news_identity_follows(
    id, user_id, target_type, person_id,
    organizational_contributor_id, show_id,
    canonical_person_id_at_follow, person_merge_decision_ids_at_follow
  ) values (
    follow_uuid, owner_uuid, target_record.target_type,
    case when target_record.target_type = 'author' then requested_person_uuid end,
    target_record.organizational_contributor_id, target_record.show_id,
    case when target_record.target_type = 'author' then target_record.person_id end,
    case when target_record.target_type = 'author'
      then private.current_news_person_merge_decisions(target_record.person_id)
      else array[]::uuid[] end
  );
  perform private.replace_my_news_follow_scopes(
    follow_uuid, owner_uuid, sport_scope_ids_value, team_scope_ids_value
  );
  return follow_uuid;
end;
$$;

create or replace function public.set_my_news_follow_scopes(
  follow_id_value uuid,
  sport_scope_ids_value text[] default array[]::text[],
  team_scope_ids_value text[] default array[]::text[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_uuid uuid := auth.uid();
  selected_follow public.user_news_identity_follows%rowtype;
  equivalent_follow_id uuid;
begin
  if owner_uuid is null then raise exception 'Authentication is required'; end if;
  select * into strict selected_follow
  from public.user_news_identity_follows
  where id = follow_id_value and user_id = owner_uuid and is_current
  for update;

  for equivalent_follow_id in
    select follow.id
    from public.user_news_identity_follows follow
    where follow.user_id = owner_uuid and follow.is_current
      and (
        follow.id = selected_follow.id
        or (selected_follow.target_type = 'author' and follow.target_type = 'author'
          and private.try_resolve_news_canonical_person(selected_follow.person_id)
            is not null
          and private.try_resolve_news_canonical_person(follow.person_id)
            = private.try_resolve_news_canonical_person(selected_follow.person_id))
        or (selected_follow.target_type = 'organization'
          and follow.target_type = 'organization'
          and follow.organizational_contributor_id
            = selected_follow.organizational_contributor_id)
        or (selected_follow.target_type = 'show' and follow.target_type = 'show'
          and follow.show_id = selected_follow.show_id)
      )
    order by follow.id
  loop
    perform private.replace_my_news_follow_scopes(
      equivalent_follow_id, owner_uuid,
      sport_scope_ids_value, team_scope_ids_value
    );
  end loop;
end;
$$;

create or replace function public.mute_my_news_follow(
  follow_id_value uuid,
  duration_value text
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_uuid uuid := auth.uid();
  selected_follow public.user_news_identity_follows%rowtype;
  mute_until_value timestamptz;
begin
  if owner_uuid is null then raise exception 'Authentication is required'; end if;
  if duration_value = '7_days' then
    mute_until_value := statement_timestamp() + interval '7 days';
  elsif duration_value = '30_days' then
    mute_until_value := statement_timestamp() + interval '30 days';
  else
    raise exception 'News mute duration must be 7_days or 30_days';
  end if;
  select * into strict selected_follow
  from public.user_news_identity_follows
  where id = follow_id_value and user_id = owner_uuid and is_current
  for update;

  update public.user_news_identity_follows follow
  set muted_until = mute_until_value
  where follow.user_id = owner_uuid and follow.is_current
    and (
      follow.id = selected_follow.id
      or (selected_follow.target_type = 'author' and follow.target_type = 'author'
        and private.try_resolve_news_canonical_person(selected_follow.person_id)
          is not null
        and private.try_resolve_news_canonical_person(follow.person_id)
          = private.try_resolve_news_canonical_person(selected_follow.person_id))
      or (selected_follow.target_type = 'organization'
        and follow.target_type = 'organization'
        and follow.organizational_contributor_id = selected_follow.organizational_contributor_id)
      or (selected_follow.target_type = 'show' and follow.target_type = 'show'
        and follow.show_id = selected_follow.show_id)
    );
  return mute_until_value;
end;
$$;

create or replace function public.unmute_my_news_follow(
  follow_id_value uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_uuid uuid := auth.uid();
  selected_follow public.user_news_identity_follows%rowtype;
begin
  if owner_uuid is null then raise exception 'Authentication is required'; end if;
  select * into strict selected_follow
  from public.user_news_identity_follows
  where id = follow_id_value and user_id = owner_uuid and is_current
  for update;
  update public.user_news_identity_follows follow
  set muted_until = null
  where follow.user_id = owner_uuid and follow.is_current
    and (
      follow.id = selected_follow.id
      or (selected_follow.target_type = 'author' and follow.target_type = 'author'
        and private.try_resolve_news_canonical_person(selected_follow.person_id)
          is not null
        and private.try_resolve_news_canonical_person(follow.person_id)
          = private.try_resolve_news_canonical_person(selected_follow.person_id))
      or (selected_follow.target_type = 'organization'
        and follow.target_type = 'organization'
        and follow.organizational_contributor_id = selected_follow.organizational_contributor_id)
      or (selected_follow.target_type = 'show' and follow.target_type = 'show'
        and follow.show_id = selected_follow.show_id)
    );
end;
$$;

create or replace function public.unfollow_news_identity(
  follow_id_value uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_uuid uuid := auth.uid();
  selected_follow public.user_news_identity_follows%rowtype;
  unfollowed_at_value timestamptz := statement_timestamp();
begin
  if owner_uuid is null then raise exception 'Authentication is required'; end if;
  select * into strict selected_follow
  from public.user_news_identity_follows
  where id = follow_id_value and user_id = owner_uuid and is_current
  for update;
  update public.user_news_identity_follows follow
  set is_current = false, unfollowed_at = unfollowed_at_value, muted_until = null
  where follow.user_id = owner_uuid and follow.is_current
    and (
      follow.id = selected_follow.id
      or (selected_follow.target_type = 'author' and follow.target_type = 'author'
        and private.try_resolve_news_canonical_person(selected_follow.person_id)
          is not null
        and private.try_resolve_news_canonical_person(follow.person_id)
          = private.try_resolve_news_canonical_person(selected_follow.person_id))
      or (selected_follow.target_type = 'organization'
        and follow.target_type = 'organization'
        and follow.organizational_contributor_id = selected_follow.organizational_contributor_id)
      or (selected_follow.target_type = 'show' and follow.target_type = 'show'
        and follow.show_id = selected_follow.show_id)
    );
end;
$$;

create or replace function public.get_my_news_following()
returns table (
  target_type text,
  target_id text,
  display_name text,
  follow_ids uuid[],
  muted_until timestamptz,
  needs_reselection boolean,
  sport_scope_ids text[],
  team_scope_ids text[]
)
language sql
stable
security definer
set search_path = ''
as $$
  with current_follow as (
    select
      follow.*,
      case when follow.target_type = 'author'
        then private.try_resolve_news_canonical_person(follow.person_id) end
        as canonical_person_id,
      exists (
        select 1
        from unnest(follow.person_merge_decision_ids_at_follow) merge_decision_id
        where not exists (
          select 1
          from public.news_person_pair_state_periods period
          where period.is_current and period.state = 'merged'
            and period.opened_by_decision_id = merge_decision_id
        )
      ) as split_requires_reselection
    from public.user_news_identity_follows follow
    where follow.user_id = auth.uid() and follow.is_current
  ), grouped as (
    select
      current_follow.target_type,
      case when current_follow.target_type = 'author'
        then coalesce(
          current_follow.canonical_person_id,
          current_follow.person_id
        ) end as display_person_id,
      current_follow.organizational_contributor_id,
      current_follow.show_id,
      array_agg(current_follow.id order by current_follow.followed_at, current_follow.id)
        as follow_ids,
      case when bool_or(
        current_follow.muted_until is null
        or current_follow.muted_until <= statement_timestamp()
      ) then null else max(current_follow.muted_until) end as muted_until,
      bool_or(
        current_follow.split_requires_reselection
        or (
          current_follow.target_type = 'author'
          and current_follow.canonical_person_id is null
        )
      ) as needs_reselection
    from current_follow
    group by current_follow.target_type,
      case when current_follow.target_type = 'author'
        then coalesce(
          current_follow.canonical_person_id,
          current_follow.person_id
        ) end,
      current_follow.organizational_contributor_id, current_follow.show_id
  )
  select
    grouped.target_type,
    coalesce(author_profile.author_id, contributor.contributor_id, show_record.show_id),
    coalesce(person_identity.public_name, organization_identity.display_name,
      show_identity.display_name),
    grouped.follow_ids,
    grouped.muted_until,
    grouped.needs_reselection,
    coalesce(scope_rows.sport_scope_ids, array[]::text[]),
    coalesce(scope_rows.team_scope_ids, array[]::text[])
  from grouped
  left join public.news_author_profiles author_profile
    on author_profile.person_id = grouped.display_person_id
  left join public.person_identity_versions person_identity
    on person_identity.person_id = grouped.display_person_id
   and person_identity.is_current
  left join public.news_organizational_contributors contributor
    on contributor.id = grouped.organizational_contributor_id
  left join public.news_organizational_contributor_versions organization_identity
    on organization_identity.organizational_contributor_id
      = grouped.organizational_contributor_id
   and organization_identity.is_current
  left join public.podcast_shows show_record on show_record.id = grouped.show_id
  left join public.podcast_show_identity_versions show_identity
    on show_identity.show_id = grouped.show_id and show_identity.is_current
  left join lateral (
    select
      array_agg(distinct sport.sport_id order by sport.sport_id)
        filter (where sport.sport_id is not null) as sport_scope_ids,
      array_agg(distinct team.team_id order by team.team_id)
        filter (where team.team_id is not null) as team_scope_ids
    from unnest(grouped.follow_ids) followed(follow_id_value)
    join public.user_news_follow_scopes scope
      on scope.follow_id = followed.follow_id_value
    left join public.catalog_sports sport on sport.id = scope.sport_id
    left join public.catalog_teams team on team.id = scope.team_id
  ) scope_rows on true
  order by grouped.target_type, coalesce(
    author_profile.author_id, contributor.contributor_id, show_record.show_id
  );
$$;

create or replace function public.dismiss_news_item(
  news_item_public_id_value text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare owner_uuid uuid := auth.uid(); item_uuid uuid;
begin
  if owner_uuid is null then raise exception 'Authentication is required'; end if;
  select id into strict item_uuid
  from public.news_items where news_item_id = news_item_public_id_value;
  insert into public.user_news_item_dismissals(user_id, news_item_id)
  values (owner_uuid, item_uuid)
  on conflict (user_id, news_item_id)
  do update set dismissed_at = statement_timestamp();
end;
$$;

create or replace function public.undo_news_item_dismissal(
  news_item_public_id_value text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare owner_uuid uuid := auth.uid(); item_uuid uuid;
begin
  if owner_uuid is null then raise exception 'Authentication is required'; end if;
  select id into strict item_uuid
  from public.news_items where news_item_id = news_item_public_id_value;
  delete from public.user_news_item_dismissals
  where user_id = owner_uuid and news_item_id = item_uuid;
end;
$$;

-- ---------------------------------------------------------------------------
-- One shared fan-safe feed implementation. Personal and Demo wrappers provide
-- only bounded target sets; publisher policy and wire status never participate.
-- ---------------------------------------------------------------------------

create or replace function private.get_news_feed_for_targets(
  viewer_user_id_value uuid,
  demo_targets_value jsonb,
  filter_kind_value text,
  filter_target_public_id_value text,
  cursor_publication_time_value timestamptz,
  cursor_news_item_id_value text,
  page_size_value integer
)
returns table (
  news_item_id text,
  item_kind text,
  headline text,
  summary text,
  publication_time timestamptz,
  server_time timestamptz,
  destination_url text,
  publisher_id text,
  publisher_name text,
  show_id text,
  show_name text,
  preview_url text,
  preview_kind text,
  preview_alt_text text,
  bylines jsonb,
  classifications jsonb
)
language sql
stable
security definer
set search_path = ''
as $$
  with requested_external_targets as (
    select target.value ->> 'target_type' as target_type,
           target.value ->> 'target_id' as target_public_id
    from jsonb_array_elements(coalesce(demo_targets_value, '[]'::jsonb)) target(value)
  ), account_targets as (
    select
      follow.id as follow_id,
      follow.target_type,
      case when follow.target_type = 'author'
        then private.try_resolve_news_canonical_person(follow.person_id) end as person_id,
      follow.organizational_contributor_id,
      follow.show_id
    from public.user_news_identity_follows follow
    where viewer_user_id_value is not null
      and follow.user_id = viewer_user_id_value
      and follow.is_current
      and (follow.muted_until is null or follow.muted_until <= statement_timestamp())
      and not exists (
        select 1
        from unnest(follow.person_merge_decision_ids_at_follow) merge_decision_id
        where not exists (
          select 1
          from public.news_person_pair_state_periods period
          where period.is_current and period.state = 'merged'
            and period.opened_by_decision_id = merge_decision_id
        )
      )
  ), external_targets as (
    select
      null::uuid as follow_id,
      resolved.target_type,
      resolved.person_id,
      resolved.organizational_contributor_id,
      resolved.show_id
    from requested_external_targets requested
    cross join lateral private.resolve_news_follow_target(
      requested.target_type, requested.target_public_id
    ) resolved
    where viewer_user_id_value is null
  ), effective_targets as (
    select * from account_targets
    union all
    select * from external_targets
  ), item_scope as (
    select
      classification.news_item_id,
      coalesce(
        version.sport_id,
        competition.sport_id,
        edition_competition.sport_id,
        team.sport_id
      ) as sport_id,
      coalesce(version.competition_id, edition.competition_id) as competition_id,
      version.team_id,
      coalesce(sport.sport_id, competition_sport.sport_id,
        edition_sport.sport_id, team_sport.sport_id) as sport_public_id,
      coalesce(competition.competition_id, edition_competition.competition_id)
        as competition_public_id,
      team.team_id as team_public_id
    from public.news_item_classifications classification
    join public.news_item_classification_versions version
      on version.classification_id = classification.id and version.is_current
    left join public.catalog_sports sport on sport.id = version.sport_id
    left join public.catalog_competitions competition
      on competition.id = version.competition_id
    left join public.catalog_sports competition_sport
      on competition_sport.id = competition.sport_id
    left join public.catalog_competition_editions edition
      on edition.id = version.competition_edition_id
    left join public.catalog_competitions edition_competition
      on edition_competition.id = edition.competition_id
    left join public.catalog_sports edition_sport
      on edition_sport.id = edition_competition.sport_id
    left join public.catalog_teams team on team.id = version.team_id
    left join public.catalog_sports team_sport on team_sport.id = team.sport_id
  ), byline_credit as (
    select
      ready.id as news_item_uuid,
      mention.id as byline_mention_id,
      coalesce(resolution.person_id, profile_version.person_id) as source_person_id,
      coalesce(resolution.organizational_contributor_id,
        profile_version.organizational_contributor_id) as organizational_contributor_id,
      resolution.show_id
    from public.news_ready_item_read_model ready
    join public.news_byline_mentions mention
      on mention.manifestation_id = ready.manifestation_id
    join public.news_byline_resolution_versions resolution
      on resolution.byline_mention_id = mention.id and resolution.is_current
    left join public.news_publisher_contributor_profile_versions profile_version
      on profile_version.contributor_profile_id = resolution.contributor_profile_id
     and profile_version.is_current
  ), credit as (
    select
      byline.news_item_uuid,
      byline.byline_mention_id,
      byline.source_person_id,
      case when byline.source_person_id is not null
        then private.try_resolve_news_canonical_person(byline.source_person_id) end
        as canonical_person_id,
      byline.organizational_contributor_id,
      byline.show_id
    from byline_credit byline
    union all
    select ready.id, null::uuid, null::uuid, null::uuid, null::uuid, ready.show_id
    from public.news_ready_item_read_model ready
    where ready.show_id is not null
  ), undisputed_credit as (
    select credit.*
    from credit
    where credit.byline_mention_id is null
       or not exists (
         select 1
         from public.news_content_review_cases review_case
         where review_case.case_type = 'attribution'
           and review_case.status in ('open', 'insufficient_evidence')
           and review_case.subject_byline_mention_id = credit.byline_mention_id
           and (
             (review_case.subject_identity_type = 'person'
               and review_case.subject_person_id = credit.source_person_id)
             or (review_case.subject_identity_type = 'organization'
               and review_case.subject_organizational_contributor_id
                 = credit.organizational_contributor_id)
             or (review_case.subject_identity_type = 'show'
               and review_case.subject_show_id = credit.show_id)
           )
       )
  ), qualifying_items as (
    select distinct credit.news_item_uuid
    from undisputed_credit credit
    join effective_targets target
      on (
        target.target_type = 'author'
        and credit.canonical_person_id = target.person_id
      ) or (
        target.target_type = 'organization'
        and credit.organizational_contributor_id = target.organizational_contributor_id
      ) or (
        target.target_type = 'show' and credit.show_id = target.show_id
      )
    where target.follow_id is null
       or not exists (
         select 1 from public.user_news_follow_scopes scope
         where scope.follow_id = target.follow_id
       )
       or exists (
         select 1
         from public.user_news_follow_scopes scope
         join item_scope on item_scope.news_item_id = credit.news_item_uuid
         where scope.follow_id = target.follow_id
           and (
             (scope.scope_type = 'sport' and scope.sport_id = item_scope.sport_id)
             or (scope.scope_type = 'team' and scope.team_id = item_scope.team_id)
           )
       )
  ), safe_byline_rows as (
    select
      mention.manifestation_id,
      mention.id,
      mention.ordinal,
      mention.raw_attribution,
      case when dispute.review_case_id is null then
        case
          when coalesce(resolution.person_id, profile_version.person_id) is not null then 'author'
          when coalesce(resolution.organizational_contributor_id,
            profile_version.organizational_contributor_id) is not null then 'organization'
          when resolution.show_id is not null then 'show'
        end
      end as target_type,
      case when dispute.review_case_id is null then
        coalesce(author_profile.author_id, contributor.contributor_id, show_record.show_id)
      end as target_id
    from public.news_byline_mentions mention
    left join public.news_byline_resolution_versions resolution
      on resolution.byline_mention_id = mention.id and resolution.is_current
    left join public.news_publisher_contributor_profile_versions profile_version
      on profile_version.contributor_profile_id = resolution.contributor_profile_id
     and profile_version.is_current
    left join lateral (
      select private.try_resolve_news_canonical_person(
        coalesce(resolution.person_id, profile_version.person_id)
      ) as person_id
      where coalesce(resolution.person_id, profile_version.person_id) is not null
    ) canonical_person on true
    left join public.news_author_profiles author_profile
      on author_profile.person_id = canonical_person.person_id
    left join public.news_organizational_contributors contributor
      on contributor.id = coalesce(
        resolution.organizational_contributor_id,
        profile_version.organizational_contributor_id
      )
    left join public.podcast_shows show_record on show_record.id = resolution.show_id
    left join lateral (
      select review_case.id as review_case_id
      from public.news_content_review_cases review_case
      where review_case.case_type = 'attribution'
        and review_case.status in ('open', 'insufficient_evidence')
        and review_case.subject_byline_mention_id = mention.id
        and (
          (review_case.subject_identity_type = 'person'
            and review_case.subject_person_id = coalesce(
              resolution.person_id, profile_version.person_id
            ))
          or (review_case.subject_identity_type = 'organization'
            and review_case.subject_organizational_contributor_id = coalesce(
              resolution.organizational_contributor_id,
              profile_version.organizational_contributor_id
            ))
          or (review_case.subject_identity_type = 'show'
            and review_case.subject_show_id = resolution.show_id)
        )
      limit 1
    ) dispute on true
  ), safe_bylines as (
    select
      manifestation_id,
      jsonb_agg(jsonb_build_object(
        'raw_attribution', raw_attribution,
        'target_type', target_type,
        'target_id', target_id
      ) order by ordinal, id) as items
    from safe_byline_rows
    group by manifestation_id
  ), filtered as (
    select ready.*, coalesce(safe_bylines.items, '[]'::jsonb) as safe_byline_items
    from public.news_ready_item_read_model ready
    join qualifying_items eligible on eligible.news_item_uuid = ready.id
    left join safe_bylines on safe_bylines.manifestation_id = ready.manifestation_id
    where ready.publication_state = 'published'
      and ready.publication_time <= statement_timestamp()
      and ready.destination_url_kind in ('canonical', 'alternate')
      and not exists (
        select 1
        from public.user_news_item_dismissals dismissal
        where viewer_user_id_value is not null
          and dismissal.user_id = viewer_user_id_value
          and dismissal.news_item_id = ready.id
      )
      and (
        filter_kind_value = 'all'
        or exists (
          select 1 from item_scope
          where item_scope.news_item_id = ready.id
            and (
              (filter_kind_value = 'sport'
                and item_scope.sport_public_id = filter_target_public_id_value)
              or (filter_kind_value = 'competition'
                and item_scope.competition_public_id = filter_target_public_id_value)
              or (filter_kind_value = 'team'
                and item_scope.team_public_id = filter_target_public_id_value)
            )
        )
      )
      and (
        cursor_publication_time_value is null
        or ready.publication_time < cursor_publication_time_value
        or (
          ready.publication_time = cursor_publication_time_value
          and ready.news_item_id > cursor_news_item_id_value
        )
      )
  )
  select
    filtered.news_item_id,
    filtered.item_kind,
    filtered.headline,
    filtered.summary,
    filtered.publication_time,
    statement_timestamp(),
    filtered.destination_url,
    filtered.publisher_id,
    filtered.publisher_name,
    show_record.show_id,
    filtered.show_name,
    filtered.preview_url,
    filtered.preview_kind,
    preview.alt_text,
    filtered.safe_byline_items,
    filtered.classifications
  from filtered
  left join public.podcast_shows show_record on show_record.id = filtered.show_id
  left join lateral (
    select remote.alt_text
    from public.news_remote_preview_references remote
    join public.news_remote_preview_policy_versions policy
      on policy.preview_reference_id = remote.id
     and policy.is_current and policy.publisher_policy_state = 'approved'
    where remote.manifestation_id = filtered.manifestation_id
      and remote.remote_url = filtered.preview_url
    limit 1
  ) preview on true
  order by filtered.publication_time desc, filtered.news_item_id
  limit page_size_value;
$$;

create or replace function private.validate_news_feed_request(
  filter_kind_value text,
  filter_target_public_id_value text,
  cursor_publication_time_value timestamptz,
  cursor_news_item_id_value text,
  page_size_value integer
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare normalized_filter_target_value text := filter_target_public_id_value;
begin
  if filter_kind_value not in ('all', 'sport', 'competition', 'team') then
    raise exception 'News filter must be all, sport, competition, or team';
  end if;
  if (filter_kind_value = 'all') <> (filter_target_public_id_value is null) then
    raise exception 'Only a scoped News filter has one target';
  end if;
  if filter_kind_value = 'sport' and not exists (
    select 1 from public.catalog_sports where sport_id = filter_target_public_id_value
  ) then raise exception 'News Sport filter does not exist'; end if;
  if filter_kind_value = 'competition' and not exists (
    select 1 from public.catalog_competitions
    where competition_id = filter_target_public_id_value
  ) then raise exception 'News Competition filter does not exist'; end if;
  if filter_kind_value = 'team' then
    select team.team_id into strict normalized_filter_target_value
    from public.catalog_teams team
    where team.id = public.resolve_catalog_team_id(filter_target_public_id_value);
  end if;
  if (cursor_publication_time_value is null) <> (cursor_news_item_id_value is null) then
    raise exception 'News feed cursor requires both publication time and Item ID';
  end if;
  if page_size_value is not null and page_size_value <= 0 then
    raise exception 'News feed page size must be positive';
  end if;
  return normalized_filter_target_value;
end;
$$;

create or replace function public.get_my_news_feed(
  filter_kind_value text default 'all',
  filter_target_public_id_value text default null,
  cursor_publication_time_value timestamptz default null,
  cursor_news_item_id_value text default null,
  page_size_value integer default null
)
returns table (
  news_item_id text,
  item_kind text,
  headline text,
  summary text,
  publication_time timestamptz,
  server_time timestamptz,
  destination_url text,
  publisher_id text,
  publisher_name text,
  show_id text,
  show_name text,
  preview_url text,
  preview_kind text,
  preview_alt_text text,
  bylines jsonb,
  classifications jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  owner_uuid uuid := auth.uid();
  normalized_filter_target_value text;
begin
  if owner_uuid is null then raise exception 'Authentication is required'; end if;
  normalized_filter_target_value := private.validate_news_feed_request(
    filter_kind_value, filter_target_public_id_value,
    cursor_publication_time_value, cursor_news_item_id_value, page_size_value
  );
  return query select * from private.get_news_feed_for_targets(
    owner_uuid, null, filter_kind_value, normalized_filter_target_value,
    cursor_publication_time_value, cursor_news_item_id_value, page_size_value
  );
end;
$$;

create or replace function public.get_news_demo_universe()
returns table (
  target_type text,
  target_id text,
  display_name text,
  ordinal integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    member.target_type,
    coalesce(author_profile.author_id, contributor.contributor_id, show_record.show_id),
    coalesce(person_identity.public_name, organization_identity.display_name,
      show_identity.display_name),
    member.ordinal
  from public.news_demo_configuration_versions configuration
  join public.news_demo_configuration_identities member
    on member.configuration_version_id = configuration.id
  left join public.news_author_profiles author_profile
    on author_profile.person_id = member.person_id
  left join public.person_identity_versions person_identity
    on person_identity.person_id = member.person_id and person_identity.is_current
  left join public.news_organizational_contributors contributor
    on contributor.id = member.organizational_contributor_id
  left join public.news_organizational_contributor_versions organization_identity
    on organization_identity.organizational_contributor_id = contributor.id
   and organization_identity.is_current
  left join public.podcast_shows show_record on show_record.id = member.show_id
  left join public.podcast_show_identity_versions show_identity
    on show_identity.show_id = show_record.id and show_identity.is_current
  where configuration.configuration_key = 'signed_out_demo'
    and configuration.is_current
  order by member.ordinal;
$$;

create or replace function public.get_news_demo_feed(
  selected_targets_value jsonb,
  filter_kind_value text default 'all',
  filter_target_public_id_value text default null,
  cursor_publication_time_value timestamptz default null,
  cursor_news_item_id_value text default null,
  page_size_value integer default null
)
returns table (
  news_item_id text,
  item_kind text,
  headline text,
  summary text,
  publication_time timestamptz,
  server_time timestamptz,
  destination_url text,
  publisher_id text,
  publisher_name text,
  show_id text,
  show_name text,
  preview_url text,
  preview_kind text,
  preview_alt_text text,
  bylines jsonb,
  classifications jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  requested_count integer;
  allowed_count integer;
  normalized_filter_target_value text;
begin
  if auth.uid() is not null then
    raise exception 'Signed-in fans use their personal News feed';
  end if;
  if jsonb_typeof(selected_targets_value) <> 'array' then
    raise exception 'News Demo selections must be a JSON array';
  end if;
  normalized_filter_target_value := private.validate_news_feed_request(
    filter_kind_value, filter_target_public_id_value,
    cursor_publication_time_value, cursor_news_item_id_value, page_size_value
  );
  requested_count := jsonb_array_length(selected_targets_value);
  select count(*) into allowed_count
  from jsonb_array_elements(selected_targets_value) requested(value)
  join public.get_news_demo_universe() allowed
    on allowed.target_type = requested.value ->> 'target_type'
   and allowed.target_id = requested.value ->> 'target_id';
  if allowed_count <> requested_count then
    raise exception 'News Demo selections must stay inside the configured universe';
  end if;
  return query select * from private.get_news_feed_for_targets(
    null, selected_targets_value, filter_kind_value, normalized_filter_target_value,
    cursor_publication_time_value, cursor_news_item_id_value, page_size_value
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants and permanent BL-027 assertion
-- ---------------------------------------------------------------------------

revoke all on function public.admin_set_news_identity_followability(text,text,boolean,text)
from public, anon;
grant execute on function public.admin_set_news_identity_followability(text,text,boolean,text)
to authenticated;
revoke all on function public.admin_set_news_demo_universe(jsonb,text)
from public, anon;
grant execute on function public.admin_set_news_demo_universe(jsonb,text)
to authenticated;

revoke all on function public.follow_news_identity(text,text,text[],text[])
from public, anon;
grant execute on function public.follow_news_identity(text,text,text[],text[])
to authenticated;
revoke all on function public.set_my_news_follow_scopes(uuid,text[],text[])
from public, anon;
grant execute on function public.set_my_news_follow_scopes(uuid,text[],text[])
to authenticated;
revoke all on function public.mute_my_news_follow(uuid,text)
from public, anon;
grant execute on function public.mute_my_news_follow(uuid,text)
to authenticated;
revoke all on function public.unmute_my_news_follow(uuid)
from public, anon;
grant execute on function public.unmute_my_news_follow(uuid)
to authenticated;
revoke all on function public.unfollow_news_identity(uuid)
from public, anon;
grant execute on function public.unfollow_news_identity(uuid)
to authenticated;
revoke all on function public.get_my_news_following()
from public, anon;
grant execute on function public.get_my_news_following()
to authenticated;
revoke all on function public.dismiss_news_item(text)
from public, anon;
grant execute on function public.dismiss_news_item(text)
to authenticated;
revoke all on function public.undo_news_item_dismissal(text)
from public, anon;
grant execute on function public.undo_news_item_dismissal(text)
to authenticated;
revoke all on function public.get_my_news_feed(text,text,timestamptz,text,integer)
from public, anon;
grant execute on function public.get_my_news_feed(text,text,timestamptz,text,integer)
to authenticated;

revoke all on function public.get_news_demo_universe() from public, authenticated;
grant execute on function public.get_news_demo_universe() to anon;
revoke all on function public.get_news_demo_feed(jsonb,text,text,timestamptz,text,integer)
from public, authenticated;
grant execute on function public.get_news_demo_feed(jsonb,text,text,timestamptz,text,integer)
to anon;

revoke all on function private.resolve_news_follow_target(text,text)
from public, anon, authenticated;
revoke all on function private.record_news_phase4_configuration_decision(text,text)
from public, anon, authenticated;
revoke all on function private.replace_my_news_follow_scopes(uuid,uuid,text[],text[])
from public, anon, authenticated;
revoke all on function private.get_news_feed_for_targets(
  uuid,jsonb,text,text,timestamptz,text,integer
) from public, anon, authenticated;
revoke all on function private.validate_news_feed_request(
  text,text,timestamptz,text,integer
) from public, anon, authenticated;
revoke all on function public.protect_news_phase4_history_row()
from public, anon, authenticated;
revoke all on function public.protect_news_phase4_version()
from public, anon, authenticated;

comment on function public.get_my_news_feed(text,text,timestamptz,text,integer) is
  'The authoritative signed-in News feed: explicit individual follows, active mute, subject-specific attribution review, optional scopes and temporary filters, per-fan Dismiss, and strict original chronology.';
comment on function public.get_news_demo_feed(jsonb,text,text,timestamptz,text,integer) is
  'Anonymous Demo feed constrained to the current governed identity universe; selected targets are caller-local and never persisted.';
comment on table public.user_news_item_dismissals is
  'Per-fan display suppression only. It changes no follow, canonical News fact, history, search access, or discussion.';

select private.assert_news_domain_mutation_registry();
