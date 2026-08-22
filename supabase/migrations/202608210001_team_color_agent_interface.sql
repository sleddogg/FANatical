-- Production Team Color Agent interface.
--
-- This migration keeps team colors in FANatical's canonical catalog and adds
-- only the controlled queue, source-candidate, proposal-safety, and agent RPC
-- surfaces needed for autonomous research. Agents authenticate normally and
-- never write catalog facts, approve sources, assign trust, or verify proposals.

-- ---------------------------------------------------------------------------
-- Durable queue, attempt history, and source-candidate associations
-- ---------------------------------------------------------------------------

create table if not exists public.team_color_work_items (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.catalog_teams(id) on delete cascade,
  work_kind text not null check (work_kind in ('fill_missing_or_unverified', 'verified_recheck')),
  recheck_trigger text check (recheck_trigger in (
    'scheduled_review', 'known_real_world_event',
    'detected_conflict_or_mismatch', 'manual_request'
  )),
  request_reason text not null check (length(btrim(request_reason)) > 0),
  priority integer not null default 100 check (priority between -10000 and 10000),
  status text not null default 'queued' check (status in (
    'queued', 'claimed', 'retry_wait', 'pending_verification',
    'blocked', 'needs_review', 'completed', 'failed', 'cancelled'
  )),
  available_at timestamptz not null default now(),
  claimed_by_actor_id uuid references public.catalog_actors(id),
  lease_token uuid,
  lease_expires_at timestamptz,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  expected_current_color_version_id uuid references public.team_color_versions(id),
  proposal_id uuid references public.catalog_change_proposals(id),
  failure_category text,
  failure_reason text,
  outcome_summary jsonb not null default '{}'::jsonb,
  created_by_actor_id uuid references public.catalog_actors(id),
  created_by_auth_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  claimed_at timestamptz,
  completed_at timestamptz,
  check (
    (work_kind = 'fill_missing_or_unverified' and recheck_trigger is null)
    or (work_kind = 'verified_recheck' and recheck_trigger is not null)
  ),
  check (
    (status = 'claimed' and claimed_by_actor_id is not null and lease_token is not null and lease_expires_at is not null)
    or (status <> 'claimed' and claimed_by_actor_id is null and lease_token is null and lease_expires_at is null)
  )
);

create unique index if not exists team_color_work_one_active_per_team_idx
on public.team_color_work_items(team_id)
where status in ('queued', 'claimed', 'retry_wait', 'pending_verification', 'blocked', 'needs_review');

create index if not exists team_color_work_claim_idx
on public.team_color_work_items(priority desc, available_at, created_at, id)
where status in ('queued', 'retry_wait');

create table if not exists public.team_color_work_attempts (
  id uuid primary key default gen_random_uuid(),
  work_item_id uuid not null references public.team_color_work_items(id) on delete cascade,
  attempt_number integer not null check (attempt_number > 0),
  actor_id uuid not null references public.catalog_actors(id),
  lease_token uuid not null,
  claimed_at timestamptz not null default now(),
  last_heartbeat_at timestamptz not null default now(),
  lease_expires_at timestamptz not null,
  ended_at timestamptz,
  outcome text check (outcome in (
    'released', 'retry', 'submitted_for_verification', 'completed',
    'blocked', 'needs_review', 'failed', 'lease_expired'
  )),
  failure_category text,
  failure_reason text,
  summary jsonb not null default '{}'::jsonb,
  unique (work_item_id, attempt_number),
  unique (lease_token)
);

create table if not exists public.team_color_work_events (
  id bigint generated always as identity primary key,
  work_item_id uuid not null references public.team_color_work_items(id) on delete cascade,
  attempt_number integer,
  actor_id uuid references public.catalog_actors(id),
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists team_color_work_events_item_idx
on public.team_color_work_events(work_item_id, occurred_at, id);

create table if not exists public.team_color_source_candidates (
  id uuid primary key default gen_random_uuid(),
  work_item_id uuid not null references public.team_color_work_items(id) on delete cascade,
  source_id uuid not null references public.trusted_sources(id),
  evidence_url text not null check (evidence_url ~* '^https?://[^[:space:]]+$'),
  discovery_summary text not null check (length(btrim(discovery_summary)) > 0),
  observed_at timestamptz not null,
  submitted_by_actor_id uuid not null references public.catalog_actors(id),
  created_at timestamptz not null default now(),
  unique (work_item_id, source_id, evidence_url)
);

alter table public.catalog_change_proposals
  add column if not exists team_color_work_item_id uuid references public.team_color_work_items(id),
  add column if not exists expected_current_color_version_id uuid references public.team_color_versions(id),
  add column if not exists team_color_change_kind text,
  add column if not exists proposal_reason text,
  add column if not exists recheck_trigger text;

alter table public.catalog_change_proposals
  drop constraint if exists catalog_team_color_change_kind_check;
alter table public.catalog_change_proposals
  add constraint catalog_team_color_change_kind_check
  check (team_color_change_kind is null or team_color_change_kind in (
    'fill_missing_or_unverified', 'verified_replacement'
  ));

alter table public.catalog_change_proposals
  drop constraint if exists catalog_team_color_recheck_trigger_check;
alter table public.catalog_change_proposals
  add constraint catalog_team_color_recheck_trigger_check
  check (recheck_trigger is null or recheck_trigger in (
    'scheduled_review', 'known_real_world_event',
    'detected_conflict_or_mismatch', 'manual_request'
  ));

-- Historical resolved color proposals predate the autonomous interface. Every
-- new pending color proposal must use the controlled wrapper and carry its
-- concurrency/replacement metadata.
alter table public.catalog_change_proposals
  drop constraint if exists pending_team_color_proposal_metadata_check;
alter table public.catalog_change_proposals
  add constraint pending_team_color_proposal_metadata_check
  check (
    fact_type <> 'team_colors'
    or status <> 'pending'
    or (
      target_team_id is not null
      and team_color_work_item_id is not null
      and team_color_change_kind is not null
      and length(btrim(proposal_reason)) > 0
    )
  );

do $$
begin
  if exists (
    select 1
    from public.catalog_change_proposals
    where fact_type = 'team_colors' and status = 'pending'
    group by target_team_id
    having count(*) > 1
  ) then
    raise exception 'Duplicate pending team-color proposals must be resolved before activating the Team Color Agent interface';
  end if;
end $$;

create unique index if not exists catalog_one_pending_team_color_proposal_idx
on public.catalog_change_proposals(target_team_id)
where fact_type = 'team_colors' and status = 'pending';

create unique index if not exists catalog_team_color_work_proposal_idx
on public.catalog_change_proposals(team_color_work_item_id)
where team_color_work_item_id is not null;

drop trigger if exists team_color_work_items_set_updated_at on public.team_color_work_items;
create trigger team_color_work_items_set_updated_at
before update on public.team_color_work_items
for each row execute function public.set_updated_at();

create or replace function public.protect_team_color_work_event()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Team Color work-event history is append-only';
end;
$$;

drop trigger if exists team_color_work_events_append_only on public.team_color_work_events;
create trigger team_color_work_events_append_only
before update or delete on public.team_color_work_events
for each row execute function public.protect_team_color_work_event();

-- ---------------------------------------------------------------------------
-- Capability and queue helpers
-- ---------------------------------------------------------------------------

create or replace function public.has_team_color_capability(
  required_capability text,
  requested_team_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_catalog_capability(
    required_capability,
    team.sport_id,
    membership.league_id,
    team.id,
    null
  )
  from public.catalog_teams team
  left join public.team_primary_league_versions membership
    on membership.team_id = team.id and membership.is_current
  where team.id = requested_team_id;
$$;

create or replace function public.enqueue_team_color_work(
  team_identifier text,
  priority_value integer default 100,
  recheck_trigger_value text default null,
  reason_value text default 'Team colors are missing or unverified.',
  available_at_value timestamptz default now()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  team_uuid uuid := public.resolve_catalog_team_id(team_identifier);
  current_color public.team_color_versions%rowtype;
  work_kind_value text;
  existing_id uuid;
  result_id uuid;
begin
  if team_uuid is null then raise exception 'Unknown team identifier'; end if;
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
     and not public.has_team_color_capability('team_colors.work.enqueue', team_uuid) then
    raise exception 'Team Color work-enqueue capability is required';
  end if;
  if priority_value not between -10000 and 10000 then raise exception 'Priority is outside the allowed range'; end if;
  if nullif(btrim(reason_value), '') is null then raise exception 'A work reason is required'; end if;

  perform pg_advisory_xact_lock(hashtextextended(team_uuid::text, 0));
  select * into current_color
  from public.team_color_versions
  where team_id = team_uuid and is_current;

  if found and current_color.record_status = 'verified' then
    work_kind_value := 'verified_recheck';
    if recheck_trigger_value not in (
      'scheduled_review', 'known_real_world_event',
      'detected_conflict_or_mismatch', 'manual_request'
    ) then
      raise exception 'Verified-team work requires an approved recheck trigger';
    end if;
  else
    work_kind_value := 'fill_missing_or_unverified';
    if recheck_trigger_value is not null then
      raise exception 'A recheck trigger applies only to verified-team rechecks';
    end if;
  end if;

  if exists (
    select 1 from public.catalog_change_proposals proposal
    where proposal.target_team_id = team_uuid
      and proposal.fact_type = 'team_colors' and proposal.status = 'pending'
  ) then
    raise exception 'This team already has a pending team-color proposal';
  end if;

  select id into existing_id
  from public.team_color_work_items
  where team_id = team_uuid
    and status in ('queued', 'claimed', 'retry_wait', 'pending_verification', 'blocked', 'needs_review');
  if existing_id is not null then return existing_id; end if;

  insert into public.team_color_work_items(
    team_id, work_kind, recheck_trigger, request_reason, priority, available_at,
    expected_current_color_version_id, created_by_actor_id, created_by_auth_user_id
  ) values (
    team_uuid, work_kind_value, recheck_trigger_value, btrim(reason_value),
    priority_value, coalesce(available_at_value, now()), current_color.id,
    actor_uuid, auth.uid()
  ) returning id into result_id;

  insert into public.team_color_work_events(work_item_id, actor_id, event_type, details)
  values (result_id, actor_uuid, 'queued', jsonb_build_object(
    'priority', priority_value,
    'work_kind', work_kind_value,
    'recheck_trigger', recheck_trigger_value,
    'reason', btrim(reason_value)
  ));
  return result_id;
end;
$$;

create or replace function public.enqueue_team_color_backlog(
  batch_size_value integer default 100,
  priority_value integer default 100
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  candidate record;
  inserted_count integer := 0;
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
     and not public.has_catalog_capability('team_colors.work.enqueue') then
    raise exception 'Team Color work-enqueue capability is required';
  end if;
  if batch_size_value not between 1 and 1000 then raise exception 'Batch size must be between 1 and 1000'; end if;
  if priority_value not between -10000 and 10000 then raise exception 'Priority is outside the allowed range'; end if;

  for candidate in
    select team.id as team_uuid, team.team_id, colors.id as color_version_id
    from public.catalog_teams team
    left join public.team_color_versions colors on colors.team_id = team.id and colors.is_current
    where (colors.id is null or colors.record_status = 'imported_unverified')
      and not exists (
        select 1 from public.team_color_work_items work
        where work.team_id = team.id
          and work.status in ('queued', 'claimed', 'retry_wait', 'pending_verification', 'blocked', 'needs_review')
      )
      and not exists (
        select 1 from public.catalog_change_proposals proposal
        where proposal.target_team_id = team.id
          and proposal.fact_type = 'team_colors' and proposal.status = 'pending'
      )
    order by case when colors.record_status = 'imported_unverified' then 0 else 1 end,
             team.team_id
    limit batch_size_value
    for update of team skip locked
  loop
    insert into public.team_color_work_items(
      team_id, work_kind, request_reason, priority,
      expected_current_color_version_id, created_by_actor_id, created_by_auth_user_id
    ) values (
      candidate.team_uuid, 'fill_missing_or_unverified',
      'Team colors are missing or imported but unverified.', priority_value,
      candidate.color_version_id, actor_uuid, auth.uid()
    );
    inserted_count := inserted_count + 1;
  end loop;
  return inserted_count;
end;
$$;

create or replace function public.expire_team_color_work_leases()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  expired record;
  expired_count integer := 0;
begin
  for expired in
    select * from public.team_color_work_items
    where status = 'claimed' and lease_expires_at <= now()
    for update skip locked
  loop
    update public.team_color_work_attempts
    set ended_at = now(), outcome = 'lease_expired',
        failure_category = 'lease_expired',
        failure_reason = 'The agent lease expired before the work was finished.'
    where work_item_id = expired.id
      and attempt_number = expired.attempt_count and ended_at is null;

    update public.team_color_work_items
    set status = 'retry_wait', available_at = now(),
        claimed_by_actor_id = null, lease_token = null, lease_expires_at = null,
        failure_category = 'lease_expired',
        failure_reason = 'The prior agent lease expired before completion.'
    where id = expired.id;

    insert into public.team_color_work_events(
      work_item_id, attempt_number, actor_id, event_type, details
    ) values (
      expired.id, expired.attempt_count, expired.claimed_by_actor_id,
      'lease_expired', jsonb_build_object('expired_at', expired.lease_expires_at)
    );
    expired_count := expired_count + 1;
  end loop;
  return expired_count;
end;
$$;

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
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.team_color_work_items%rowtype;
  result_value jsonb;
begin
  if actor_uuid is null then raise exception 'An active catalog actor is required'; end if;
  select * into strict work_record from public.team_color_work_items where id = work_item_id_value;
  if work_record.status <> 'claimed'
     or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value
     or work_record.lease_expires_at <= now() then
    raise exception 'An active Team Color work lease owned by this actor is required';
  end if;
  if not public.has_team_color_capability('team_colors.work.read', work_record.team_id) then
    raise exception 'Team Color work-read capability is required';
  end if;

  select jsonb_build_object(
    'work', jsonb_build_object(
      'work_item_id', work.id,
      'work_kind', work.work_kind,
      'recheck_trigger', work.recheck_trigger,
      'request_reason', work.request_reason,
      'priority', work.priority,
      'status', work.status,
      'attempt_number', work.attempt_count,
      'lease_token', work.lease_token,
      'lease_expires_at', work.lease_expires_at,
      'expected_current_color_version_id', work.expected_current_color_version_id,
      'proposal_id', work.proposal_id
    ),
    'team', jsonb_build_object(
      'team_id', team.team_id,
      'display_name', identity_record.display_name,
      'short_name', identity_record.short_name,
      'abbreviation', identity_record.abbreviation,
      'sport_id', sport.sport_id,
      'sport_name', sport.display_name,
      'league_id', league.league_id,
      'league_name', league.display_name,
      'league_short_name', league.short_name,
      'aliases', coalesce((
        select jsonb_agg(jsonb_build_object(
          'value', alias.alias, 'type', alias.alias_type,
          'locale', alias.locale, 'status', alias.record_status
        ) order by alias.alias_type, alias.alias)
        from public.team_alias_versions alias
        where alias.team_id = team.id and alias.is_current
      ), '[]'::jsonb),
      'identifiers', coalesce((
        select jsonb_agg(jsonb_build_object(
          'namespace', identifier.namespace,
          'identifier', identifier.identifier,
          'status', identifier.record_status
        ) order by identifier.namespace, identifier.identifier)
        from public.catalog_team_identifiers identifier
        where identifier.team_id = team.id
      ), '[]'::jsonb)
    ),
    'current_colors', case when colors.id is null then null else jsonb_build_object(
      'version_id', colors.id,
      'primary', colors.primary_color,
      'secondary', colors.secondary_color,
      'tertiary', colors.tertiary_color,
      'quaternary', colors.quaternary_color,
      'quinary', colors.quinary_color,
      'effective_from', colors.effective_from,
      'effective_from_precision', colors.effective_from_precision,
      'status', colors.record_status,
      'verification_decision_id', colors.verification_decision_id
    ) end,
    'pending_proposal', case when proposal.id is null then null else jsonb_build_object(
      'proposal_id', proposal.id,
      'status', proposal.status,
      'change_kind', proposal.team_color_change_kind,
      'reason', proposal.proposal_reason,
      'recheck_trigger', proposal.recheck_trigger,
      'payload', proposal.payload,
      'submitted_at', proposal.submitted_at,
      'evidence', coalesce((
        select jsonb_agg(jsonb_build_object(
          'source_id', evidence_source.source_id,
          'evidence_url', evidence.evidence_url,
          'evidence_summary', evidence.evidence_summary,
          'observed_at', evidence.observed_at,
          'supports_proposal', evidence.supports_proposal,
          'created_at', evidence.created_at
        ) order by evidence.created_at)
        from public.catalog_proposal_evidence evidence
        join public.trusted_sources evidence_source on evidence_source.id = evidence.source_id
        where evidence.proposal_id = proposal.id
      ), '[]'::jsonb)
    ) end,
    'approved_sources', coalesce((
      select jsonb_agg(jsonb_build_object(
        'source_id', source.source_id,
        'display_name', source.display_name,
        'base_url', source.base_url,
        'reference_url', source.reference_url,
        'independence_group_id', independence.group_id,
        'independence_group_name', independence.display_name,
        'trust_tier', trust.trust_tier,
        'trust_effective_from', trust.effective_from,
        'trust_notes', trust.notes,
        'source_notes', source.notes
      ) order by trust.trust_tier, source.display_name)
      from public.trusted_sources source
      join public.source_independence_groups independence on independence.id = source.independence_group_id
      join public.source_trust_assignments trust on trust.source_id = source.id
        and trust.data_type = 'team_colors' and trust.is_current
      where source.review_status = 'approved' and trust.trust_tier between 1 and 4
    ), '[]'::jsonb),
    'submitted_source_candidates', coalesce((
      select jsonb_agg(jsonb_build_object(
        'candidate_id', candidate.id,
        'source_id', candidate_source.source_id,
        'source_review_status', candidate_source.review_status,
        'evidence_url', candidate.evidence_url,
        'discovery_summary', candidate.discovery_summary,
        'observed_at', candidate.observed_at,
        'created_at', candidate.created_at
      ) order by candidate.created_at)
      from public.team_color_source_candidates candidate
      join public.trusted_sources candidate_source on candidate_source.id = candidate.source_id
      where candidate.work_item_id = work.id
    ), '[]'::jsonb),
    'verification_policy', (
      select jsonb_build_object(
        'policy_key', policy.policy_key,
        'version', policy.version,
        'minimum_evidence_count', policy.minimum_evidence_count,
        'allowed_trust_tiers', policy.allowed_trust_tiers,
        'require_independent_sources', policy.require_independent_sources,
        'require_independent_verifier', policy.require_independent_verifier,
        'configuration', policy.configuration
      )
      from public.verification_policies policy
      where policy.data_type = 'team_colors' and policy.is_current and policy.active
    )
  ) into result_value
  from public.team_color_work_items work
  join public.catalog_teams team on team.id = work.team_id
  join public.catalog_sports sport on sport.id = team.sport_id
  left join public.team_identity_versions identity_record on identity_record.team_id = team.id and identity_record.is_current
  left join public.team_primary_league_versions membership on membership.team_id = team.id and membership.is_current
  left join public.catalog_leagues league on league.id = membership.league_id
  left join public.team_color_versions colors on colors.team_id = team.id and colors.is_current
  left join public.catalog_change_proposals proposal on proposal.id = work.proposal_id
  where work.id = work_item_id_value;
  return result_value;
end;
$$;

create or replace function public.claim_next_team_color_work(
  lease_seconds_value integer default 900
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  selected_work public.team_color_work_items%rowtype;
  lease_token_result uuid := gen_random_uuid();
  lease_duration integer := greatest(60, least(coalesce(lease_seconds_value, 900), 3600));
begin
  if actor_uuid is null then raise exception 'An active catalog actor is required'; end if;
  perform public.expire_team_color_work_leases();

  -- A queued item's expected version is a concurrency guard. If another process
  -- changed the underlying version, require review instead of silently retargeting.
  update public.team_color_work_items work
  set status = 'needs_review',
      failure_category = 'current_version_changed',
      failure_reason = 'The current team-color version changed before this work was claimed.'
  where work.status in ('queued', 'retry_wait')
    and work.expected_current_color_version_id is distinct from (
      select colors.id from public.team_color_versions colors
      where colors.team_id = work.team_id and colors.is_current
    );

  select work.* into selected_work
  from public.team_color_work_items work
  join public.catalog_teams team on team.id = work.team_id
  left join public.team_primary_league_versions membership
    on membership.team_id = team.id and membership.is_current
  where work.status in ('queued', 'retry_wait')
    and work.available_at <= now()
    and public.has_catalog_capability(
      'team_colors.work.claim', team.sport_id, membership.league_id, team.id, null
    )
    and not exists (
      select 1 from public.catalog_change_proposals proposal
      where proposal.target_team_id = work.team_id
        and proposal.fact_type = 'team_colors' and proposal.status = 'pending'
    )
  order by work.priority desc, work.available_at, work.created_at, work.id
  for update of work skip locked
  limit 1;

  if not found then return null; end if;

  update public.team_color_work_items
  set status = 'claimed', claimed_by_actor_id = actor_uuid,
      lease_token = lease_token_result,
      lease_expires_at = now() + make_interval(secs => lease_duration),
      attempt_count = attempt_count + 1, claimed_at = now(),
      failure_category = null, failure_reason = null
  where id = selected_work.id
  returning * into selected_work;

  insert into public.team_color_work_attempts(
    work_item_id, attempt_number, actor_id, lease_token, lease_expires_at
  ) values (
    selected_work.id, selected_work.attempt_count, actor_uuid,
    lease_token_result, selected_work.lease_expires_at
  );
  insert into public.team_color_work_events(
    work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    selected_work.id, selected_work.attempt_count, actor_uuid, 'claimed',
    jsonb_build_object('lease_expires_at', selected_work.lease_expires_at)
  );

  return public.get_my_team_color_work(selected_work.id, lease_token_result);
end;
$$;

create or replace function public.renew_team_color_work_lease(
  work_item_id_value uuid,
  lease_token_value uuid,
  lease_seconds_value integer default 900
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.team_color_work_items%rowtype;
  lease_duration integer := greatest(60, least(coalesce(lease_seconds_value, 900), 3600));
begin
  select * into strict work_record from public.team_color_work_items where id = work_item_id_value for update;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now() then
    raise exception 'An unexpired Team Color work lease owned by this actor is required';
  end if;
  if not public.has_team_color_capability('team_colors.work.update', work_record.team_id) then
    raise exception 'Team Color work-update capability is required';
  end if;

  update public.team_color_work_items
  set lease_expires_at = now() + make_interval(secs => lease_duration)
  where id = work_item_id_value
  returning * into work_record;
  update public.team_color_work_attempts
  set last_heartbeat_at = now(), lease_expires_at = work_record.lease_expires_at
  where work_item_id = work_item_id_value
    and attempt_number = work_record.attempt_count and ended_at is null;
  return work_record.lease_expires_at;
end;
$$;

create or replace function public.release_team_color_work(
  work_item_id_value uuid,
  lease_token_value uuid,
  retry_at_value timestamptz default null,
  category_value text default null,
  reason_value text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.team_color_work_items%rowtype;
  next_status text := case when retry_at_value is null then 'queued' else 'retry_wait' end;
begin
  select * into strict work_record from public.team_color_work_items where id = work_item_id_value for update;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now() then
    raise exception 'An unexpired Team Color work lease owned by this actor is required';
  end if;
  if not public.has_team_color_capability('team_colors.work.update', work_record.team_id) then
    raise exception 'Team Color work-update capability is required';
  end if;
  if work_record.proposal_id is not null then
    raise exception 'Work with a submitted proposal must be finished, not released';
  end if;

  update public.team_color_work_attempts
  set ended_at = now(), outcome = case when retry_at_value is null then 'released' else 'retry' end,
      failure_category = category_value, failure_reason = reason_value
  where work_item_id = work_record.id
    and attempt_number = work_record.attempt_count and ended_at is null;
  update public.team_color_work_items
  set status = next_status, available_at = coalesce(retry_at_value, now()),
      claimed_by_actor_id = null, lease_token = null, lease_expires_at = null,
      failure_category = category_value, failure_reason = reason_value
  where id = work_record.id;
  insert into public.team_color_work_events(
    work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    work_record.id, work_record.attempt_count, actor_uuid, next_status,
    jsonb_build_object('retry_at', retry_at_value, 'category', category_value, 'reason', reason_value)
  );
end;
$$;

create or replace function public.finish_team_color_work(
  work_item_id_value uuid,
  lease_token_value uuid,
  outcome_value text,
  category_value text default null,
  reason_value text default null,
  retry_at_value timestamptz default null,
  summary_value jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.team_color_work_items%rowtype;
  next_status text;
  attempt_outcome text;
  current_color public.team_color_versions%rowtype;
begin
  if outcome_value not in ('no_change', 'submitted_for_verification', 'blocked', 'needs_review', 'retry', 'failed') then
    raise exception 'Invalid Team Color work outcome';
  end if;
  select * into strict work_record from public.team_color_work_items where id = work_item_id_value for update;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now() then
    raise exception 'An unexpired Team Color work lease owned by this actor is required';
  end if;
  if not public.has_team_color_capability('team_colors.work.update', work_record.team_id) then
    raise exception 'Team Color work-update capability is required';
  end if;

  if outcome_value = 'submitted_for_verification' then
    if work_record.proposal_id is null or not exists (
      select 1 from public.catalog_change_proposals proposal
      where proposal.id = work_record.proposal_id
        and proposal.status = 'pending' and proposal.fact_type = 'team_colors'
    ) then
      raise exception 'A pending Team Color proposal is required';
    end if;
    next_status := 'pending_verification';
    attempt_outcome := 'submitted_for_verification';
  elsif outcome_value = 'no_change' then
    select * into current_color from public.team_color_versions
    where team_id = work_record.team_id and is_current;
    if work_record.work_kind <> 'verified_recheck'
       or not found or current_color.record_status <> 'verified'
       or current_color.id is distinct from work_record.expected_current_color_version_id then
      raise exception 'No-change completion is valid only for an unchanged verified-team recheck';
    end if;
    next_status := 'completed';
    attempt_outcome := 'completed';
  elsif outcome_value = 'retry' then
    if retry_at_value is null or retry_at_value <= now() then
      raise exception 'Retry work requires a future retry timestamp';
    end if;
    next_status := 'retry_wait';
    attempt_outcome := 'retry';
  else
    if nullif(btrim(reason_value), '') is null then
      raise exception 'Blocked, needs-review, and failed outcomes require a reason';
    end if;
    next_status := outcome_value;
    attempt_outcome := outcome_value;
  end if;

  update public.team_color_work_attempts
  set ended_at = now(), outcome = attempt_outcome,
      failure_category = category_value, failure_reason = reason_value,
      summary = coalesce(summary_value, '{}'::jsonb)
  where work_item_id = work_record.id
    and attempt_number = work_record.attempt_count and ended_at is null;
  update public.team_color_work_items
  set status = next_status,
      available_at = case when next_status = 'retry_wait' then retry_at_value else available_at end,
      claimed_by_actor_id = null, lease_token = null, lease_expires_at = null,
      failure_category = category_value, failure_reason = reason_value,
      outcome_summary = coalesce(summary_value, '{}'::jsonb),
      completed_at = case when next_status = 'completed' then now() else null end
  where id = work_record.id;
  insert into public.team_color_work_events(
    work_item_id, attempt_number, actor_id, event_type, details
  ) values (
    work_record.id, work_record.attempt_count, actor_uuid, next_status,
    jsonb_build_object(
      'outcome', outcome_value, 'category', category_value,
      'reason', reason_value, 'retry_at', retry_at_value,
      'summary', coalesce(summary_value, '{}'::jsonb)
    )
  );
end;
$$;

create or replace function public.requeue_team_color_work(
  work_item_id_value uuid,
  available_at_value timestamptz default now(),
  priority_value integer default null,
  reason_value text default 'Requeued after review.'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.team_color_work_items%rowtype;
  current_color_id uuid;
  current_color_status text;
begin
  select * into strict work_record from public.team_color_work_items where id = work_item_id_value for update;
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
     and not public.has_team_color_capability('team_colors.work.enqueue', work_record.team_id) then
    raise exception 'Team Color work-enqueue capability is required';
  end if;
  if work_record.status not in ('blocked', 'needs_review', 'failed') then
    raise exception 'Only blocked, needs-review, or failed work can be requeued';
  end if;
  if work_record.proposal_id is not null and exists (
    select 1 from public.catalog_change_proposals where id = work_record.proposal_id and status = 'pending'
  ) then
    raise exception 'Resolve the pending proposal before requeueing this work';
  end if;
  select id, record_status into current_color_id, current_color_status from public.team_color_versions
  where team_id = work_record.team_id and is_current;
  if work_record.work_kind = 'fill_missing_or_unverified'
     and current_color_status = 'verified' then
    raise exception 'This fill work became a verified-team recheck; cancel it and enqueue an explicit recheck trigger';
  end if;
  if work_record.work_kind = 'verified_recheck'
     and current_color_status is distinct from 'verified' then
    raise exception 'This recheck no longer targets a verified current color version';
  end if;
  update public.team_color_work_items
  set status = 'retry_wait', available_at = coalesce(available_at_value, now()),
      priority = coalesce(priority_value, priority),
      expected_current_color_version_id = current_color_id,
      proposal_id = null, failure_category = null, failure_reason = null,
      request_reason = coalesce(nullif(btrim(reason_value), ''), request_reason),
      completed_at = null
  where id = work_record.id;
  insert into public.team_color_work_events(work_item_id, actor_id, event_type, details)
  values (work_record.id, actor_uuid, 'requeued', jsonb_build_object(
    'available_at', available_at_value,
    'priority', coalesce(priority_value, work_record.priority),
    'reason', reason_value
  ));
end;
$$;

create or replace function public.cancel_team_color_work(
  work_item_id_value uuid,
  reason_value text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.team_color_work_items%rowtype;
begin
  select * into strict work_record from public.team_color_work_items where id = work_item_id_value for update;
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
     and not public.has_team_color_capability('team_colors.work.enqueue', work_record.team_id) then
    raise exception 'Team Color work-enqueue capability is required';
  end if;
  if nullif(btrim(reason_value), '') is null then raise exception 'A cancellation reason is required'; end if;
  if work_record.status in ('claimed', 'pending_verification', 'completed', 'cancelled') then
    raise exception 'Claimed, pending-verification, completed, or already-cancelled work cannot be cancelled';
  end if;
  if work_record.proposal_id is not null and exists (
    select 1 from public.catalog_change_proposals where id = work_record.proposal_id and status = 'pending'
  ) then
    raise exception 'Resolve the pending proposal before cancelling this work';
  end if;
  update public.team_color_work_items
  set status = 'cancelled', failure_category = 'cancelled',
      failure_reason = btrim(reason_value), completed_at = now()
  where id = work_record.id;
  insert into public.team_color_work_events(work_item_id, actor_id, event_type, details)
  values (work_record.id, actor_uuid, 'cancelled', jsonb_build_object('reason', btrim(reason_value)));
end;
$$;

-- ---------------------------------------------------------------------------
-- Controlled source-candidate and proposal submission
-- ---------------------------------------------------------------------------

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
  source_record public.trusted_sources%rowtype;
  candidate_id uuid;
begin
  select * into strict work_record from public.team_color_work_items where id = work_item_id_value for update;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now() then
    raise exception 'An unexpired Team Color work lease owned by this actor is required';
  end if;
  if not public.has_team_color_capability('team_colors.source_candidates.submit', work_record.team_id) then
    raise exception 'Team Color source-candidate capability is required';
  end if;
  if source_registry_id !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then raise exception 'Source Registry ID must be a lowercase slug'; end if;
  if nullif(btrim(display_name_value), '') is null then raise exception 'Source display name is required'; end if;
  if base_url_value !~* '^https?://[^[:space:]]+$'
     or reference_url_value !~* '^https?://[^[:space:]]+$'
     or evidence_url_value !~* '^https?://[^[:space:]]+$' then
    raise exception 'Source and evidence URLs must be absolute HTTP(S) URLs';
  end if;
  if nullif(btrim(discovery_summary_value), '') is null then raise exception 'A discovery summary is required'; end if;

  select * into source_record from public.trusted_sources where source_id = source_registry_id for update;
  if not found then
    insert into public.trusted_sources(
      source_id, display_name, base_url, reference_url, review_status, notes, metadata
    ) values (
      source_registry_id, btrim(display_name_value), base_url_value, reference_url_value,
      'pending_review', 'Submitted by a Team Color Agent for source-governance review.',
      jsonb_build_object(
        'candidate_origin', 'team_color_agent',
        'submitted_by_actor_id', actor_uuid,
        'submitted_at', now()
      )
    ) returning * into source_record;
  else
    if source_record.reference_url is not null
       and source_record.reference_url <> reference_url_value then
      raise exception 'Source Registry ID already belongs to a different reference URL';
    end if;
  end if;

  insert into public.team_color_source_candidates(
    work_item_id, source_id, evidence_url, discovery_summary,
    observed_at, submitted_by_actor_id
  ) values (
    work_record.id, source_record.id, evidence_url_value,
    btrim(discovery_summary_value), coalesce(observed_at_value, now()), actor_uuid
  ) on conflict (work_item_id, source_id, evidence_url) do update set
    discovery_summary = excluded.discovery_summary,
    observed_at = excluded.observed_at
  returning id into candidate_id;

  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'source.candidate_submitted', 'trusted_source',
    source_registry_id, jsonb_build_object(
      'work_item_id', work_record.id,
      'team_id', work_record.team_id,
      'review_status', source_record.review_status,
      'evidence_url', evidence_url_value
    )
  );
  return candidate_id;
end;
$$;

create or replace function public.submit_team_color_proposal(
  work_item_id_value uuid,
  lease_token_value uuid,
  payload_value jsonb,
  reason_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  work_record public.team_color_work_items%rowtype;
  current_color public.team_color_versions%rowtype;
  change_kind_value text;
  result_id uuid;
  color_key text;
begin
  select * into strict work_record from public.team_color_work_items where id = work_item_id_value for update;
  if work_record.status <> 'claimed' or work_record.claimed_by_actor_id <> actor_uuid
     or work_record.lease_token <> lease_token_value or work_record.lease_expires_at <= now() then
    raise exception 'An unexpired Team Color work lease owned by this actor is required';
  end if;
  if not public.has_team_color_capability('catalog.propose.team_colors', work_record.team_id) then
    raise exception 'Team Color proposal capability is required';
  end if;
  if work_record.proposal_id is not null then raise exception 'This work item already has a proposal'; end if;
  if nullif(btrim(reason_value), '') is null then raise exception 'A proposal reason is required'; end if;

  foreach color_key in array array['primary', 'secondary'] loop
    if coalesce(payload_value ->> color_key, '') !~ '^#[0-9A-F]{6}$' then
      raise exception 'Team color % must be uppercase six-digit HEX (#RRGGBB)', color_key;
    end if;
  end loop;
  foreach color_key in array array['tertiary', 'quaternary', 'quinary'] loop
    if nullif(payload_value ->> color_key, '') is not null
       and payload_value ->> color_key !~ '^#[0-9A-F]{6}$' then
      raise exception 'Team color % must be uppercase six-digit HEX (#RRGGBB)', color_key;
    end if;
  end loop;
  if coalesce(nullif(payload_value ->> 'effective_from_precision', ''), 'unknown')
     not in ('day', 'year', 'unknown') then
    raise exception 'Invalid effective-date precision';
  end if;

  select * into current_color from public.team_color_versions
  where team_id = work_record.team_id and is_current for update;
  if current_color.id is distinct from work_record.expected_current_color_version_id then
    raise exception 'The current team-color version changed after this work was queued';
  end if;

  if found and current_color.record_status = 'verified' then
    if work_record.work_kind <> 'verified_recheck' or work_record.recheck_trigger is null then
      raise exception 'Verified colors may be replaced only by authorized recheck work';
    end if;
    if current_color.primary_color = payload_value ->> 'primary'
       and current_color.secondary_color = payload_value ->> 'secondary'
       and current_color.tertiary_color is not distinct from nullif(payload_value ->> 'tertiary', '')
       and current_color.quaternary_color is not distinct from nullif(payload_value ->> 'quaternary', '')
       and current_color.quinary_color is not distinct from nullif(payload_value ->> 'quinary', '') then
      raise exception 'The proposed palette matches the verified current palette; finish the recheck as no_change';
    end if;
    change_kind_value := 'verified_replacement';
  else
    if work_record.work_kind <> 'fill_missing_or_unverified' then
      raise exception 'The work kind no longer matches the current color state';
    end if;
    change_kind_value := 'fill_missing_or_unverified';
  end if;

  if exists (
    select 1 from public.catalog_change_proposals proposal
    where proposal.target_team_id = work_record.team_id
      and proposal.fact_type = 'team_colors' and proposal.status = 'pending'
  ) then
    raise exception 'This team already has a pending team-color proposal';
  end if;

  insert into public.catalog_change_proposals(
    fact_type, operation, target_team_id, payload, status,
    proposed_by_actor_id, team_color_work_item_id,
    expected_current_color_version_id, team_color_change_kind,
    proposal_reason, recheck_trigger
  ) values (
    'team_colors', 'replace', work_record.team_id, payload_value, 'pending',
    actor_uuid, work_record.id, work_record.expected_current_color_version_id,
    change_kind_value, btrim(reason_value), work_record.recheck_trigger
  ) returning id into result_id;

  update public.team_color_work_items set proposal_id = result_id where id = work_record.id;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, proposal_id, details
  ) values (
    actor_uuid, auth.uid(), 'proposal.submitted', 'team_colors',
    work_record.team_id::text, result_id, jsonb_build_object(
      'work_item_id', work_record.id,
      'change_kind', change_kind_value,
      'expected_current_color_version_id', work_record.expected_current_color_version_id,
      'recheck_trigger', work_record.recheck_trigger,
      'reason', btrim(reason_value)
    )
  );
  return result_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Verification hardening and policy v2
-- ---------------------------------------------------------------------------

update public.verification_policies
set is_current = false, active = false, superseded_at = now()
where data_type = 'team_colors' and is_current and active;

insert into public.verification_policies(
  policy_key, version, data_type, minimum_evidence_count, allowed_trust_tiers,
  require_independent_sources, require_independent_verifier, configuration,
  is_current, active
)
values (
  'team-colors', 2, 'team_colors', 2, array[1,2,3]::smallint[], true, true,
  jsonb_build_object(
    'minimum_tier_1_or_2_evidence_count', 1,
    'value_format', 'uppercase_six_digit_hex',
    'automatic_age_staleness', false,
    'recheck_triggers', jsonb_build_array(
      'scheduled_review', 'known_real_world_event',
      'detected_conflict_or_mismatch', 'manual_request'
    ),
    'trust_tier_rubric', jsonb_build_object(
      '1', 'First-party team, club, or controlling owner brand standards that publish exact official color values.',
      '2', 'Official league, governing body, licensing authority, or authorized brand portal that publishes exact team color values with authoritative provenance.',
      '3', 'Reputable independent specialist or editorial reference that publishes exact values with stable attribution or methodology; suitable for corroboration, not unilateral authority.',
      '4', 'Research lead only: useful for discovery but insufficient for verification.',
      '5', 'Blocked for this data type because provenance, reliability, or integrity is unacceptable.'
    ),
    'independence_rule', 'Qualifying evidence must come from different ownership or control groups; multiple pages or brands under common control count once.',
    'official_source_rule', 'An official source is preferred as the evidence anchor but does not bypass the two-independent-source requirement.'
  ),
  true, true
);

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
  color_key text;
begin
  if new.decision <> 'approved' then return new; end if;

  select * into strict proposal_record
  from public.catalog_change_proposals
  where id = new.proposal_id;
  select * into strict policy_record
  from public.verification_policies
  where id = new.policy_id;

  minimum_high_trust_count := coalesce(
    (policy_record.configuration ->> 'minimum_tier_1_or_2_evidence_count')::integer,
    0
  );
  if minimum_high_trust_count > 0 then
    select count(distinct evidence.id) into high_trust_count
    from public.catalog_proposal_evidence evidence
    join public.trusted_sources source on source.id = evidence.source_id
    join public.source_trust_assignments trust on trust.source_id = source.id
      and trust.data_type = proposal_record.fact_type and trust.is_current
    where evidence.proposal_id = proposal_record.id
      and evidence.supports_proposal
      and source.review_status = 'approved'
      and source.independence_group_id is not null
      and trust.trust_tier in (1, 2);
    if high_trust_count < minimum_high_trust_count then
      raise exception 'Policy requires at least % Tier 1 or Tier 2 evidence row(s)', minimum_high_trust_count;
    end if;
  end if;

  if proposal_record.fact_type = 'team_colors' then
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

    select * into current_color
    from public.team_color_versions
    where team_id = proposal_record.target_team_id and is_current
    for update;
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

    foreach color_key in array array['primary', 'secondary'] loop
      if coalesce(proposal_record.payload ->> color_key, '') !~ '^#[0-9A-F]{6}$' then
        raise exception 'Team color % must be uppercase six-digit HEX (#RRGGBB)', color_key;
      end if;
    end loop;
    foreach color_key in array array['tertiary', 'quaternary', 'quinary'] loop
      if nullif(proposal_record.payload ->> color_key, '') is not null
         and proposal_record.payload ->> color_key !~ '^#[0-9A-F]{6}$' then
        raise exception 'Team color % must be uppercase six-digit HEX (#RRGGBB)', color_key;
      end if;
    end loop;

    -- Preserve the evidence details and exact trust-assignment version used at
    -- decision time, rather than relying only on mutable current source rows.
    select coalesce(jsonb_agg(jsonb_build_object(
      'evidence_id', evidence.id,
      'source_id', source.source_id,
      'source_display_name', source.display_name,
      'source_review_status', source.review_status,
      'independence_group_id', independence.group_id,
      'evidence_url', evidence.evidence_url,
      'evidence_summary', evidence.evidence_summary,
      'observed_at', evidence.observed_at,
      'evidence_created_at', evidence.created_at,
      'supports_proposal', evidence.supports_proposal,
      'trust_assignment_id', trust.id,
      'trust_tier', trust.trust_tier,
      'trust_effective_from', trust.effective_from,
      'trust_notes', trust.notes
    ) order by evidence.created_at, evidence.id), '[]'::jsonb)
    into new.evidence_snapshot
    from public.catalog_proposal_evidence evidence
    join public.trusted_sources source on source.id = evidence.source_id
    left join public.source_independence_groups independence on independence.id = source.independence_group_id
    left join public.source_trust_assignments trust on trust.source_id = source.id
      and trust.data_type = 'team_colors' and trust.is_current
    where evidence.proposal_id = proposal_record.id;
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
    'trust_tier_rubric', policy_record.configuration -> 'trust_tier_rubric'
  );
  return new;
end;
$$;

create or replace function public.sync_team_color_work_from_proposal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  next_status text;
begin
  if new.fact_type <> 'team_colors' or new.team_color_work_item_id is null
     or new.status = old.status then
    return new;
  end if;
  if new.status = 'approved' then
    next_status := 'completed';
  elsif new.status in ('rejected', 'withdrawn') then
    next_status := 'needs_review';
  else
    return new;
  end if;

  update public.team_color_work_items
  set status = next_status,
      failure_category = case when next_status = 'needs_review' then 'proposal_' || new.status else null end,
      failure_reason = case when next_status = 'needs_review' then coalesce(new.resolution_notes, 'Proposal requires review.') else null end,
      completed_at = case when next_status = 'completed' then now() else null end
  where id = new.team_color_work_item_id
    and status = 'pending_verification';

  insert into public.team_color_work_events(work_item_id, actor_id, event_type, details)
  select new.team_color_work_item_id, public.current_catalog_actor_id(),
         case when next_status = 'completed' then 'proposal_approved' else 'proposal_' || new.status end,
         jsonb_build_object('proposal_id', new.id, 'resolution_notes', new.resolution_notes)
  where exists (
    select 1 from public.team_color_work_items where id = new.team_color_work_item_id
  );
  return new;
end;
$$;

drop trigger if exists sync_team_color_work_from_proposal on public.catalog_change_proposals;
create trigger sync_team_color_work_from_proposal
after update of status on public.catalog_change_proposals
for each row execute function public.sync_team_color_work_from_proposal();

-- A narrow reviewer queue retains the team/work association without granting
-- direct access to all catalog internals.
create or replace function public.get_team_color_source_candidate_review_queue()
returns table (
  candidate_id uuid,
  work_item_id uuid,
  team_id text,
  team_name text,
  source_id text,
  source_name text,
  base_url text,
  reference_url text,
  evidence_url text,
  discovery_summary text,
  observed_at timestamptz,
  review_status text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null)
     and not public.has_catalog_capability('source.registry.review') then
    raise exception 'Source Registry review capability is required';
  end if;
  return query
  select candidate.id, candidate.work_item_id, team.team_id,
         identity_record.display_name, source.source_id, source.display_name,
         source.base_url, source.reference_url, candidate.evidence_url,
         candidate.discovery_summary, candidate.observed_at,
         source.review_status, candidate.created_at
  from public.team_color_source_candidates candidate
  join public.team_color_work_items work on work.id = candidate.work_item_id
  join public.catalog_teams team on team.id = work.team_id
  left join public.team_identity_versions identity_record
    on identity_record.team_id = team.id and identity_record.is_current
  join public.trusted_sources source on source.id = candidate.source_id
  order by case source.review_status when 'pending_review' then 0 else 1 end,
           candidate.created_at, candidate.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS, grants, and interface comments
-- ---------------------------------------------------------------------------

alter table public.team_color_work_items enable row level security;
alter table public.team_color_work_attempts enable row level security;
alter table public.team_color_work_events enable row level security;
alter table public.team_color_source_candidates enable row level security;

revoke all on public.team_color_work_items from public, anon, authenticated;
revoke all on public.team_color_work_attempts from public, anon, authenticated;
revoke all on public.team_color_work_events from public, anon, authenticated;
revoke all on public.team_color_source_candidates from public, anon, authenticated;

create policy "Authorized staff read Team Color work items"
on public.team_color_work_items for select to authenticated
using (public.has_staff_access(array['admin','staff','content_admin']::text[], null));
create policy "Authorized staff read Team Color work attempts"
on public.team_color_work_attempts for select to authenticated
using (public.has_staff_access(array['admin','staff','content_admin']::text[], null));
create policy "Authorized staff read Team Color work events"
on public.team_color_work_events for select to authenticated
using (public.has_staff_access(array['admin','staff','content_admin']::text[], null));
create policy "Authorized source reviewers read Team Color candidates"
on public.team_color_source_candidates for select to authenticated
using (
  public.has_staff_access(array['admin','staff','content_admin']::text[], null)
  or public.has_catalog_capability('source.registry.review')
);

grant select on public.team_color_work_items, public.team_color_work_attempts,
  public.team_color_work_events, public.team_color_source_candidates to authenticated;

revoke all on function public.has_team_color_capability(text, uuid) from public, anon;
grant execute on function public.has_team_color_capability(text, uuid) to authenticated;
revoke all on function public.enqueue_team_color_work(text, integer, text, text, timestamptz) from public, anon;
grant execute on function public.enqueue_team_color_work(text, integer, text, text, timestamptz) to authenticated;
revoke all on function public.enqueue_team_color_backlog(integer, integer) from public, anon;
grant execute on function public.enqueue_team_color_backlog(integer, integer) to authenticated;
revoke all on function public.expire_team_color_work_leases() from public, anon, authenticated;
revoke all on function public.get_my_team_color_work(uuid, uuid) from public, anon;
grant execute on function public.get_my_team_color_work(uuid, uuid) to authenticated;
revoke all on function public.claim_next_team_color_work(integer) from public, anon;
grant execute on function public.claim_next_team_color_work(integer) to authenticated;
revoke all on function public.renew_team_color_work_lease(uuid, uuid, integer) from public, anon;
grant execute on function public.renew_team_color_work_lease(uuid, uuid, integer) to authenticated;
revoke all on function public.release_team_color_work(uuid, uuid, timestamptz, text, text) from public, anon;
grant execute on function public.release_team_color_work(uuid, uuid, timestamptz, text, text) to authenticated;
revoke all on function public.finish_team_color_work(uuid, uuid, text, text, text, timestamptz, jsonb) from public, anon;
grant execute on function public.finish_team_color_work(uuid, uuid, text, text, text, timestamptz, jsonb) to authenticated;
revoke all on function public.requeue_team_color_work(uuid, timestamptz, integer, text) from public, anon;
grant execute on function public.requeue_team_color_work(uuid, timestamptz, integer, text) to authenticated;
revoke all on function public.cancel_team_color_work(uuid, text) from public, anon;
grant execute on function public.cancel_team_color_work(uuid, text) to authenticated;
revoke all on function public.submit_team_color_source_candidate(uuid, uuid, text, text, text, text, text, text, timestamptz) from public, anon;
grant execute on function public.submit_team_color_source_candidate(uuid, uuid, text, text, text, text, text, text, timestamptz) to authenticated;
revoke all on function public.submit_team_color_proposal(uuid, uuid, jsonb, text) from public, anon;
grant execute on function public.submit_team_color_proposal(uuid, uuid, jsonb, text) to authenticated;
revoke all on function public.get_team_color_source_candidate_review_queue() from public, anon;
grant execute on function public.get_team_color_source_candidate_review_queue() to authenticated;

revoke all on function public.protect_team_color_work_event() from public, anon, authenticated;
revoke all on function public.sync_team_color_work_from_proposal() from public, anon, authenticated;

comment on table public.team_color_work_items is
  'Durable canonical-team queue for missing/unverified color research and explicit verified-team rechecks.';
comment on table public.team_color_work_attempts is
  'One row per Team Color Agent lease attempt, including retry/failure outcome and lease history.';
comment on table public.team_color_work_events is
  'Append-only Team Color queue lifecycle history.';
comment on table public.team_color_source_candidates is
  'Agent-discovered sources associated with Team Color work; source review, independence, and trust remain separate.';
comment on function public.claim_next_team_color_work(integer) is
  'Atomically claims the highest-priority eligible Team Color work item using FOR UPDATE SKIP LOCKED and returns its narrow research context.';
comment on function public.submit_team_color_proposal(uuid, uuid, jsonb, text) is
  'Only supported autonomous Team Color proposal entrypoint; captures expected current version, change kind, recheck trigger, and reason.';
comment on function public.submit_team_color_source_candidate(uuid, uuid, text, text, text, text, text, text, timestamptz) is
  'Creates or associates a pending-review source candidate without granting approval, independence, or trust authority.';
