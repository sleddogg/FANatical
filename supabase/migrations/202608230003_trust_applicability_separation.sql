-- Separate publisher trust tier from target applicability.
--
-- Locked semantics:
--   * one current trust tier per (publisher, data_type);
--   * zero or more separately versioned applicability scopes;
--   * evidence snapshots and revalidates both versions independently.

-- Refuse to guess if an environment has already used the overly permissive
-- scope-coupled model to assign conflicting current tiers.
do $$
begin
  if exists (
    select 1
    from public.source_trust_assignments
    where is_current
    group by source_id, data_type
    having count(distinct trust_tier) > 1
  ) then
    raise exception 'Conflicting current scoped trust tiers require explicit governance resolution before separation';
  end if;
end $$;

create table public.source_applicability_versions (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.trusted_sources(id),
  data_type text not null check (length(btrim(data_type)) > 0),
  applicability_kind text not null check (applicability_kind in (
    'global', 'sport', 'league', 'team'
  )),
  sport_id uuid references public.catalog_sports(id),
  league_id uuid references public.catalog_leagues(id),
  team_id uuid references public.catalog_teams(id),
  review_status text not null default 'pending_review' check (review_status in (
    'pending_review', 'approved', 'suspended', 'retired'
  )),
  is_current boolean not null default true,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  reviewed_by_actor_id uuid references public.catalog_actors(id),
  notes text,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from),
  check (
    (applicability_kind = 'global' and num_nonnulls(sport_id, league_id, team_id) = 0)
    or (applicability_kind = 'sport' and sport_id is not null and num_nonnulls(league_id, team_id) = 0)
    or (applicability_kind = 'league' and league_id is not null and num_nonnulls(sport_id, team_id) = 0)
    or (applicability_kind = 'team' and team_id is not null and num_nonnulls(sport_id, league_id) = 0)
  )
);

create unique index source_applicability_current_scope_idx
on public.source_applicability_versions(
  source_id,
  data_type,
  applicability_kind,
  coalesce(sport_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(league_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(team_id, '00000000-0000-0000-0000-000000000000'::uuid)
) where is_current;

create index source_applicability_lookup_idx
on public.source_applicability_versions(source_id, data_type, review_status)
where is_current;

-- Every current scoped trust row becomes one applicability version. The tier
-- remains on its original history row until duplicate current rows are safely
-- consolidated below.
insert into public.source_applicability_versions(
  source_id, data_type, applicability_kind, sport_id, league_id, team_id,
  review_status, is_current, effective_from, reviewed_by_actor_id, notes
)
select trust.source_id, trust.data_type,
       case
         when trust.team_id is not null then 'team'
         when trust.league_id is not null then 'league'
         when trust.sport_id is not null then 'sport'
         else 'global'
       end,
       trust.sport_id, trust.league_id, trust.team_id,
       'approved', true, trust.created_at, trust.assigned_by_actor_id,
       'Migrated from the former scope-coupled trust assignment ' || trust.id::text || '.'
from public.source_trust_assignments trust
where trust.is_current;

-- If another environment contains multiple same-tier scopes, preserve each
-- applicability and retain only the newest row as the one tier version.
with ranked as (
  select id,
         row_number() over (
           partition by source_id, data_type
           order by created_at desc, id desc
         ) as position
  from public.source_trust_assignments
  where is_current
)
update public.source_trust_assignments trust
set is_current = false, effective_to = current_date, superseded_at = now(),
    notes = concat_ws(' ', trust.notes, 'Superseded while separating applicability from trust tier.')
from ranked
where trust.id = ranked.id and ranked.position > 1;

drop view public.trusted_source_review_read_model;
drop function public.applicable_team_color_sources(uuid);

-- Remove the two APIs that could assign a different tier at each scope.
drop function public.admin_set_source_trust_scoped(text,text,smallint,text,text,text,text);
drop function public.admin_set_source_trust(text,text,smallint,text);

drop index public.source_trust_current_scoped_idx;
alter table public.source_trust_assignments
  drop constraint source_trust_single_applicability_scope_check,
  drop column sport_id,
  drop column league_id,
  drop column team_id;

create unique index source_trust_current_data_type_idx
on public.source_trust_assignments(source_id, data_type)
where is_current;

comment on table public.source_trust_assignments is
  'Versioned publisher trust tier by data type. Applicability is stored only in source_applicability_versions.';
comment on column public.source_trust_assignments.trust_tier is
  'Publisher trust tier for this data type; never team-, league-, or sport-specific.';

alter table public.catalog_proposal_evidence
  add column source_applicability_version_id uuid
    references public.source_applicability_versions(id);

comment on column public.catalog_proposal_evidence.source_trust_assignment_id is
  'Exact publisher/data-type trust-tier version used by this evidence. The legacy column name is retained for FK/history compatibility.';
comment on column public.catalog_proposal_evidence.source_applicability_version_id is
  'Exact independently selected applicability version used by this evidence.';

-- ---------------------------------------------------------------------------
-- Independent lookup and controlled governance APIs
-- ---------------------------------------------------------------------------

create or replace function public.current_source_trust_tier_assignment(
  source_uuid uuid,
  data_type_value text
)
returns uuid
language sql
stable
set search_path = ''
as $$
  select trust.id
  from public.source_trust_assignments trust
  where trust.source_id = source_uuid
    and trust.data_type = data_type_value
    and trust.is_current
    and (trust.effective_from is null or trust.effective_from <= current_date)
    and (trust.effective_to is null or trust.effective_to >= current_date)
  limit 1;
$$;

create or replace function public.applicable_source_applicability_version(
  source_uuid uuid,
  data_type_value text,
  team_uuid uuid
)
returns uuid
language sql
stable
set search_path = ''
as $$
  select applicability.id
  from public.source_applicability_versions applicability
  join public.catalog_teams team on team.id = team_uuid
  left join public.team_primary_league_versions membership
    on membership.team_id = team.id and membership.is_current
  where applicability.source_id = source_uuid
    and applicability.data_type = data_type_value
    and applicability.is_current
    and applicability.review_status = 'approved'
    and applicability.effective_from <= now()
    and (applicability.effective_to is null or applicability.effective_to >= now())
    and (
      (applicability.applicability_kind = 'team' and applicability.team_id = team.id)
      or (applicability.applicability_kind = 'league' and applicability.league_id = membership.league_id)
      or (applicability.applicability_kind = 'sport' and applicability.sport_id = team.sport_id)
      or applicability.applicability_kind = 'global'
    )
  order by case applicability.applicability_kind
    when 'team' then 4
    when 'league' then 3
    when 'sport' then 2
    else 1 end desc,
    applicability.created_at desc
  limit 1;
$$;

create or replace function public.admin_set_source_trust_tier(
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
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  source_record public.trusted_sources%rowtype;
  prior_record public.source_trust_assignments%rowtype;
  result_id uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null)
     and not public.has_catalog_capability('source.trust.assign') then
    raise exception 'source.trust.assign capability is required';
  end if;
  if trust_tier_value not between 1 and 5 or nullif(btrim(data_type_value), '') is null then
    raise exception 'A data type and trust tier from 1 through 5 are required';
  end if;
  select * into strict source_record from public.trusted_sources
  where source_id = source_registry_id and superseded_by_source_id is null for update;
  if source_record.review_status <> 'approved' or source_record.independence_group_id is null then
    raise exception 'Publisher ownership and independence must be approved before trust is assigned';
  end if;
  select * into prior_record from public.source_trust_assignments
  where source_id = source_record.id and data_type = data_type_value and is_current
  for update;
  update public.source_trust_assignments
  set is_current = false, effective_to = current_date, superseded_at = now()
  where source_id = source_record.id and data_type = data_type_value and is_current;
  insert into public.source_trust_assignments(
    source_id, data_type, trust_tier, effective_from, assigned_by_actor_id, notes
  ) values (
    source_record.id, data_type_value, trust_tier_value, current_date,
    actor_uuid, notes_value
  ) returning id into result_id;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'source.trust_tier_assigned', 'trusted_source',
    source_registry_id, jsonb_build_object(
      'data_type', data_type_value,
      'previous_trust_tier_version_id', prior_record.id,
      'previous_tier', prior_record.trust_tier,
      'trust_tier_version_id', result_id,
      'new_tier', trust_tier_value,
      'notes', notes_value
    )
  );
  return result_id;
end;
$$;

create or replace function public.review_source_applicability(
  source_registry_id text,
  data_type_value text,
  applicability_kind_value text,
  sport_identifier text default null,
  league_identifier text default null,
  team_identifier text default null,
  review_status_value text default 'approved',
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
  prior_id uuid;
  result_id uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null)
     and not public.has_catalog_capability('source.applicability.assign') then
    raise exception 'source.applicability.assign capability is required';
  end if;
  if nullif(btrim(data_type_value), '') is null
     or applicability_kind_value not in ('global','sport','league','team')
     or review_status_value not in ('pending_review','approved','suspended','retired') then
    raise exception 'Valid data type, applicability kind, and review status are required';
  end if;
  if (applicability_kind_value = 'global' and num_nonnulls(sport_identifier,league_identifier,team_identifier) <> 0)
     or (applicability_kind_value = 'sport' and sport_identifier is null)
     or (applicability_kind_value = 'league' and league_identifier is null)
     or (applicability_kind_value = 'team' and team_identifier is null)
     or num_nonnulls(sport_identifier,league_identifier,team_identifier) > 1 then
    raise exception 'Applicability kind and identifier do not match';
  end if;
  select * into strict source_record from public.trusted_sources
  where source_id = source_registry_id and superseded_by_source_id is null for update;
  if source_record.review_status <> 'approved' or source_record.independence_group_id is null then
    raise exception 'Publisher ownership and independence must be approved before applicability is reviewed';
  end if;
  if sport_identifier is not null then
    select id into strict sport_uuid from public.catalog_sports where sport_id = sport_identifier;
  elsif league_identifier is not null then
    select id into strict league_uuid from public.catalog_leagues where league_id = league_identifier;
  elsif team_identifier is not null then
    team_uuid := public.resolve_catalog_team_id(team_identifier);
    if team_uuid is null then raise exception 'Unknown team identifier'; end if;
  end if;
  select id into prior_id
  from public.source_applicability_versions
  where source_id = source_record.id and data_type = data_type_value and is_current
    and applicability_kind = applicability_kind_value
    and sport_id is not distinct from sport_uuid
    and league_id is not distinct from league_uuid
    and team_id is not distinct from team_uuid
  for update;
  update public.source_applicability_versions
  set is_current = false, effective_to = now()
  where source_id = source_record.id and data_type = data_type_value and is_current
    and applicability_kind = applicability_kind_value
    and sport_id is not distinct from sport_uuid
    and league_id is not distinct from league_uuid
    and team_id is not distinct from team_uuid;
  insert into public.source_applicability_versions(
    source_id, data_type, applicability_kind, sport_id, league_id, team_id,
    review_status, reviewed_by_actor_id, notes
  ) values (
    source_record.id, data_type_value, applicability_kind_value,
    sport_uuid, league_uuid, team_uuid, review_status_value, actor_uuid, notes_value
  ) returning id into result_id;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'source.applicability_reviewed', 'trusted_source',
    source_registry_id, jsonb_build_object(
      'data_type', data_type_value,
      'previous_applicability_version_id', prior_id,
      'applicability_version_id', result_id,
      'applicability_kind', applicability_kind_value,
      'sport_id', sport_identifier,
      'league_id', league_identifier,
      'team_id', team_identifier,
      'review_status', review_status_value,
      'notes', notes_value
    )
  );
  return result_id;
end;
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
  tier_uuid uuid;
  applicability_uuid uuid;
  tier_value smallint;
  applicability_kind_value text;
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
  tier_uuid := public.current_source_trust_tier_assignment(resolved_source, 'team_colors');
  applicability_uuid := public.applicable_source_applicability_version(
    resolved_source, 'team_colors', work_record.team_id
  );
  select trust_tier into tier_value
  from public.source_trust_assignments where id = tier_uuid;
  select applicability_kind into applicability_kind_value
  from public.source_applicability_versions where id = applicability_uuid;
  return resolution || jsonb_build_object(
    'trust_tier_status', case when tier_uuid is null then 'unassigned' else 'assigned' end,
    'trust_tier_version_id', tier_uuid,
    'trust_tier', tier_value,
    'applicability', case when applicability_uuid is null then 'not_applicable' else 'applicable' end,
    'applicability_version_id', applicability_uuid,
    'applicability_kind', applicability_kind_value
  );
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
  tier_uuid uuid;
  tier_record public.source_trust_assignments%rowtype;
  applicability_uuid uuid;
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
  join public.trusted_source_url_scope_versions scope on scope.id = match.url_scope_version_id
  where match.specificity = top_specificity
    and match.canonical_source_id = source_uuid
    and scope.review_status = 'approved'
  order by match.url_scope_version_id limit 1;
  if url_scope_uuid is null then
    raise exception 'Evidence URL does not belong to the selected approved publisher';
  end if;

  tier_uuid := public.current_source_trust_tier_assignment(
    source_uuid, proposal_record.fact_type
  );
  if tier_uuid is null then
    raise exception 'Publisher has no current trust tier for data type %', proposal_record.fact_type;
  end if;
  select * into strict tier_record from public.source_trust_assignments where id = tier_uuid;
  if tier_record.trust_tier = 5 then
    raise exception 'Tier 5 publishers are blocked for this data type';
  end if;
  if proposal_record.target_team_id is null then
    select applicability.id into applicability_uuid
    from public.source_applicability_versions applicability
    where applicability.source_id = source_uuid
      and applicability.data_type = proposal_record.fact_type
      and applicability.applicability_kind = 'global'
      and applicability.is_current and applicability.review_status = 'approved'
      and applicability.effective_from <= now()
      and (applicability.effective_to is null or applicability.effective_to >= now())
    order by applicability.created_at desc limit 1;
  else
    applicability_uuid := public.applicable_source_applicability_version(
      source_uuid, proposal_record.fact_type, proposal_record.target_team_id
    );
  end if;
  if applicability_uuid is null then
    raise exception 'Publisher is not currently applicable to this data type and target';
  end if;
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
    source_trust_assignment_id, source_applicability_version_id,
    source_independence_assignment_id, structured_claim
  ) values (
    proposal_id_value, source_uuid, evidence_url_value, evidence_summary_value,
    observed_at_value, supports_proposal_value, actor_uuid, url_scope_uuid,
    tier_uuid, applicability_uuid, independence_uuid, structured_claim_value
  ) returning id into result_id;
  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, proposal_id, details
  ) values (
    actor_uuid, auth.uid(), 'proposal.evidence_added', 'catalog_proposal',
    proposal_id_value::text, proposal_id_value, jsonb_build_object(
      'source_id', source_record.source_id,
      'url_scope_version_id', url_scope_uuid,
      'trust_tier_version_id', tier_uuid,
      'trust_tier', tier_record.trust_tier,
      'applicability_version_id', applicability_uuid,
      'independence_assignment_id', independence_uuid,
      'structured_claim', structured_claim_value
    )
  );
  return result_id;
end;
$$;

create or replace function public.enforce_governed_catalog_evidence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  proposal_record public.catalog_change_proposals%rowtype;
  source_uuid uuid;
  canonical_scope_source uuid;
  tier_source_uuid uuid;
  applicability_source_uuid uuid;
  ownership_source_uuid uuid;
  expected_applicability_uuid uuid;
begin
  if new.source_url_scope_version_id is null
     or new.source_trust_assignment_id is null
     or new.source_applicability_version_id is null
     or new.source_independence_assignment_id is null then
    raise exception 'New catalog evidence requires exact URL, trust-tier, applicability, and independence provenance';
  end if;
  select * into strict proposal_record
  from public.catalog_change_proposals where id = new.proposal_id;
  if proposal_record.fact_type = 'team_colors'
     and not public.validate_team_color_claim(new.structured_claim) then
    raise exception 'New Team Color evidence requires a valid structured claim';
  end if;
  select id into strict source_uuid from public.trusted_sources
  where id = new.source_id and review_status = 'approved'
    and superseded_by_source_id is null;
  select public.canonical_trusted_source_id(scope.source_id)
    into strict canonical_scope_source
  from public.trusted_source_url_scope_versions scope
  where scope.id = new.source_url_scope_version_id
    and scope.is_current and scope.review_status = 'approved';
  if canonical_scope_source <> source_uuid or not exists (
    select 1 from public.trusted_source_url_matches(new.evidence_url) match
    where match.url_scope_version_id = new.source_url_scope_version_id
      and match.canonical_source_id = source_uuid
  ) then
    raise exception 'Evidence URL is outside the selected current approved publisher URL scope';
  end if;
  select trust.source_id into strict tier_source_uuid
  from public.source_trust_assignments trust
  where trust.id = new.source_trust_assignment_id
    and trust.data_type = proposal_record.fact_type
    and trust.is_current
    and (trust.effective_from is null or trust.effective_from <= current_date)
    and (trust.effective_to is null or trust.effective_to >= current_date);
  if tier_source_uuid <> source_uuid
     or new.source_trust_assignment_id <>
        public.current_source_trust_tier_assignment(source_uuid, proposal_record.fact_type) then
    raise exception 'Evidence trust-tier version is not the current publisher/data-type tier';
  end if;
  select applicability.source_id into strict applicability_source_uuid
  from public.source_applicability_versions applicability
  where applicability.id = new.source_applicability_version_id
    and applicability.data_type = proposal_record.fact_type
    and applicability.is_current and applicability.review_status = 'approved';
  if proposal_record.target_team_id is null then
    select applicability.id into expected_applicability_uuid
    from public.source_applicability_versions applicability
    where applicability.source_id = source_uuid
      and applicability.data_type = proposal_record.fact_type
      and applicability.applicability_kind = 'global'
      and applicability.is_current and applicability.review_status = 'approved'
    order by applicability.created_at desc limit 1;
  else
    expected_applicability_uuid := public.applicable_source_applicability_version(
      source_uuid, proposal_record.fact_type, proposal_record.target_team_id
    );
  end if;
  if applicability_source_uuid <> source_uuid
     or new.source_applicability_version_id <> expected_applicability_uuid then
    raise exception 'Evidence applicability version is not current for the target';
  end if;
  select assignment.source_id into strict ownership_source_uuid
  from public.source_independence_group_assignment_versions assignment
  join public.trusted_sources source
    on source.id = assignment.source_id
   and source.independence_group_id = assignment.independence_group_id
  where assignment.id = new.source_independence_assignment_id
    and assignment.is_current and assignment.review_status = 'approved';
  if ownership_source_uuid <> source_uuid then
    raise exception 'Evidence ownership assignment does not belong to the selected publisher';
  end if;
  return new;
end;
$$;

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
  from public.catalog_change_proposals where id = new.proposal_id;
  select * into strict policy_record
  from public.verification_policies where id = new.policy_id;
  minimum_high_trust_count := coalesce(
    (policy_record.configuration ->> 'minimum_tier_1_or_2_evidence_count')::integer, 0
  );

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
      'trust_tier_version_id', evidence.source_trust_assignment_id,
      'trust_tier', trust.trust_tier,
      'trust_effective_from', trust.effective_from,
      'trust_notes', trust.notes,
      'applicability_version_id', evidence.source_applicability_version_id,
      'applicability_kind', applicability.applicability_kind,
      'applicability_scope', jsonb_build_object(
        'sport_id', applicability_sport.sport_id,
        'league_id', applicability_league.league_id,
        'team_id', applicability_team.team_id
      ),
      'applicability_notes', applicability.notes
    ) order by evidence.created_at, evidence.id), '[]'::jsonb)
    into new.evidence_snapshot
    from public.catalog_proposal_evidence evidence
    join public.trusted_sources source on source.id = evidence.source_id
    join public.source_trust_assignments trust
      on trust.id = evidence.source_trust_assignment_id
    join public.source_applicability_versions applicability
      on applicability.id = evidence.source_applicability_version_id
    join public.source_independence_group_assignment_versions independence
      on independence.id = evidence.source_independence_assignment_id
    join public.source_independence_groups source_group
      on source_group.id = independence.independence_group_id
    left join public.catalog_sports applicability_sport on applicability_sport.id = applicability.sport_id
    left join public.catalog_leagues applicability_league on applicability_league.id = applicability.league_id
    left join public.catalog_teams applicability_team on applicability_team.id = applicability.team_id
    where evidence.proposal_id = proposal_record.id;
  elsif minimum_high_trust_count > 0 then
    select count(distinct evidence.id) into high_trust_count
    from public.catalog_proposal_evidence evidence
    join public.source_trust_assignments trust
      on trust.id = evidence.source_trust_assignment_id and trust.is_current
    where evidence.proposal_id = proposal_record.id
      and evidence.supports_proposal and trust.trust_tier in (1,2);
    if high_trust_count < minimum_high_trust_count then
      raise exception 'Policy requires at least % Tier 1 or Tier 2 evidence row(s)', minimum_high_trust_count;
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
    'independent_trust_and_applicability_versions', true
  );
  return new;
end;
$$;

create or replace function public.enforce_current_team_color_evidence_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  proposal_record public.catalog_change_proposals%rowtype;
  policy_record public.verification_policies%rowtype;
  qualifying_count integer;
  independent_count integer;
  high_trust_count integer;
  minimum_high_trust_count integer;
begin
  if new.decision <> 'approved' then return new; end if;
  select * into strict proposal_record
  from public.catalog_change_proposals where id = new.proposal_id;
  if proposal_record.fact_type <> 'team_colors' then return new; end if;
  select * into strict policy_record
  from public.verification_policies where id = new.policy_id;
  minimum_high_trust_count := coalesce(
    (policy_record.configuration ->> 'minimum_tier_1_or_2_evidence_count')::integer, 0
  );
  select count(distinct evidence.id),
         count(distinct ownership.independence_group_id),
         count(distinct evidence.id) filter (where trust.trust_tier in (1,2))
    into qualifying_count, independent_count, high_trust_count
  from public.catalog_proposal_evidence evidence
  join public.trusted_sources source
    on source.id = evidence.source_id
   and source.review_status = 'approved'
   and source.superseded_by_source_id is null
  join public.trusted_source_url_scope_versions scope
    on scope.id = evidence.source_url_scope_version_id
   and scope.is_current and scope.review_status = 'approved'
  join public.source_trust_assignments trust
    on trust.id = evidence.source_trust_assignment_id
   and trust.is_current
   and (trust.effective_from is null or trust.effective_from <= current_date)
   and (trust.effective_to is null or trust.effective_to >= current_date)
  join public.source_applicability_versions applicability
    on applicability.id = evidence.source_applicability_version_id
   and applicability.is_current and applicability.review_status = 'approved'
   and applicability.effective_from <= now()
   and (applicability.effective_to is null or applicability.effective_to >= now())
  join public.source_independence_group_assignment_versions ownership
    on ownership.id = evidence.source_independence_assignment_id
   and ownership.is_current and ownership.review_status = 'approved'
  where evidence.proposal_id = proposal_record.id
    and evidence.supports_proposal
    and evidence.structured_claim ->> 'classification' = 'current_canonical'
    and evidence.structured_claim -> 'palette' =
        public.team_color_palette_from_payload(proposal_record.payload)
    and trust.trust_tier = any(policy_record.allowed_trust_tiers)
    and trust.id = public.current_source_trust_tier_assignment(source.id, 'team_colors')
    and applicability.id = public.applicable_source_applicability_version(
      source.id, 'team_colors', proposal_record.target_team_id
    )
    and exists (
      select 1 from public.trusted_source_url_matches(evidence.evidence_url) match
      where match.url_scope_version_id = scope.id
        and match.canonical_source_id = source.id
    )
    and ownership.source_id = source.id
    and applicability.source_id = source.id
    and applicability.data_type = 'team_colors'
    and scope.source_id = source.id;
  if qualifying_count < policy_record.minimum_evidence_count then
    raise exception 'Proposal has % currently governed evidence rows; policy requires %',
      qualifying_count, policy_record.minimum_evidence_count;
  end if;
  if policy_record.require_independent_sources
     and independent_count < policy_record.minimum_evidence_count then
    raise exception 'Proposal does not have enough currently governed independent publisher groups';
  end if;
  if high_trust_count < minimum_high_trust_count then
    raise exception 'Policy requires at least % currently governed Tier 1 or Tier 2 evidence row(s)',
      minimum_high_trust_count;
  end if;
  return new;
end;
$$;

-- Publisher redirects preserve both governance histories while transferring
-- any non-conflicting current tier and applicability versions independently.
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
  where old_trust.source_id = source_record.id
    and new_trust.trust_tier <> old_trust.trust_tier;
  if conflict_count > 0 then
    raise exception 'Conflicting current publisher/data-type trust tiers require reviewer resolution before redirect';
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
    source_id, data_type, trust_tier, effective_from, assigned_by_actor_id, notes
  )
  select target_record.id, old_trust.data_type, old_trust.trust_tier,
         current_date, actor_uuid,
         'Transferred by audited publisher redirect: ' || btrim(reason_value)
  from public.source_trust_assignments old_trust
  where old_trust.source_id = source_record.id and old_trust.is_current
    and not exists (
      select 1 from public.source_trust_assignments target_trust
      where target_trust.source_id = target_record.id
        and target_trust.data_type = old_trust.data_type
        and target_trust.is_current
    );
  insert into public.source_applicability_versions(
    source_id, data_type, applicability_kind, sport_id, league_id, team_id,
    review_status, reviewed_by_actor_id, notes
  )
  select target_record.id, old_app.data_type, old_app.applicability_kind,
         old_app.sport_id, old_app.league_id, old_app.team_id,
         old_app.review_status, actor_uuid,
         'Transferred by audited publisher redirect: ' || btrim(reason_value)
  from public.source_applicability_versions old_app
  where old_app.source_id = source_record.id and old_app.is_current
    and not exists (
      select 1 from public.source_applicability_versions target_app
      where target_app.source_id = target_record.id
        and target_app.data_type = old_app.data_type
        and target_app.applicability_kind = old_app.applicability_kind
        and target_app.sport_id is not distinct from old_app.sport_id
        and target_app.league_id is not distinct from old_app.league_id
        and target_app.team_id is not distinct from old_app.team_id
        and target_app.is_current
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
  update public.source_applicability_versions
  set is_current = false, effective_to = now(), review_status = 'retired'
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
      'historical_evidence_rewritten', false,
      'tier_and_applicability_transferred_independently', true
    )
  );
  return result_id;
end;
$$;

-- Reviewer read model: one tier per data type and a separate applicability set.
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
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'data_type', trust.data_type,
      'trust_tier', trust.trust_tier,
      'trust_tier_version_id', trust.id,
      'effective_from', trust.effective_from,
      'effective_to', trust.effective_to,
      'notes', trust.notes
    ) order by trust.data_type)
    from public.source_trust_assignments trust
    where trust.source_id = source.id and trust.is_current
  ), '[]'::jsonb) as current_trust_tiers,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'data_type', applicability.data_type,
      'applicability_version_id', applicability.id,
      'applicability_kind', applicability.applicability_kind,
      'sport_id', sport.sport_id,
      'league_id', league.league_id,
      'team_id', team.team_id,
      'review_status', applicability.review_status,
      'effective_from', applicability.effective_from,
      'effective_to', applicability.effective_to,
      'notes', applicability.notes
    ) order by applicability.data_type, applicability.applicability_kind,
               coalesce(team.team_id, league.league_id, sport.sport_id, ''))
    from public.source_applicability_versions applicability
    left join public.catalog_sports sport on sport.id = applicability.sport_id
    left join public.catalog_leagues league on league.id = applicability.league_id
    left join public.catalog_teams team on team.id = applicability.team_id
    where applicability.source_id = source.id and applicability.is_current
  ), '[]'::jsonb) as current_applicabilities,
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
left join public.trusted_sources canonical
  on canonical.id = source.superseded_by_source_id;

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
    'trust_tier_version_id', trust.id,
    'trust_tier', trust.trust_tier,
    'trust_notes', trust.notes,
    'selected_applicability', jsonb_build_object(
      'applicability_version_id', selected_app.id,
      'applicability_kind', selected_app.applicability_kind,
      'sport_id', selected_sport.sport_id,
      'league_id', selected_league.league_id,
      'team_id', selected_team.team_id,
      'notes', selected_app.notes
    ),
    'applicability_scopes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'applicability_version_id', applicability.id,
        'applicability_kind', applicability.applicability_kind,
        'sport_id', sport.sport_id,
        'league_id', league.league_id,
        'team_id', team.team_id,
        'notes', applicability.notes
      ) order by case applicability.applicability_kind
          when 'global' then 1 when 'sport' then 2 when 'league' then 3 else 4 end,
          coalesce(team.team_id, league.league_id, sport.sport_id, ''))
      from public.source_applicability_versions applicability
      left join public.catalog_sports sport on sport.id = applicability.sport_id
      left join public.catalog_leagues league on league.id = applicability.league_id
      left join public.catalog_teams team on team.id = applicability.team_id
      where applicability.source_id = source.id
        and applicability.data_type = 'team_colors'
        and applicability.is_current
        and applicability.review_status = 'approved'
    ), '[]'::jsonb),
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
    on trust.id = public.current_source_trust_tier_assignment(source.id, 'team_colors')
  join public.source_applicability_versions selected_app
    on selected_app.id = public.applicable_source_applicability_version(
      source.id, 'team_colors', team_uuid
    )
  left join public.catalog_sports selected_sport on selected_sport.id = selected_app.sport_id
  left join public.catalog_leagues selected_league on selected_league.id = selected_app.league_id
  left join public.catalog_teams selected_team on selected_team.id = selected_app.team_id
  where source.review_status = 'approved'
    and source.superseded_by_source_id is null
    and trust.trust_tier between 1 and 4;
$$;

-- The former helper returned a scoped trust row. All qualification callers now
-- use the two independent helpers above, so retaining it would invite semantic
-- regression.
drop function public.applicable_source_trust_assignment(uuid,text,uuid);

alter table public.source_applicability_versions enable row level security;
revoke all on table public.source_applicability_versions from public, anon, authenticated;
create policy "Authorized actors read FANatical source applicability"
on public.source_applicability_versions for select to authenticated
using (
  public.has_catalog_capability('catalog.read_internal')
  or public.has_staff_access(array['admin','staff','content_admin']::text[], null)
);
grant select on table public.source_applicability_versions to authenticated;

revoke all on function public.current_source_trust_tier_assignment(uuid,text) from public, anon, authenticated;
revoke all on function public.applicable_source_applicability_version(uuid,text,uuid) from public, anon, authenticated;
revoke all on function public.admin_set_source_trust_tier(text,text,smallint,text) from public, anon;
grant execute on function public.admin_set_source_trust_tier(text,text,smallint,text) to authenticated;
revoke all on function public.review_source_applicability(text,text,text,text,text,text,text,text) from public, anon;
grant execute on function public.review_source_applicability(text,text,text,text,text,text,text,text) to authenticated;
revoke all on function public.redirect_trusted_source(text,text,text) from public, anon;
grant execute on function public.redirect_trusted_source(text,text,text) to authenticated;
grant select on public.trusted_source_review_read_model to authenticated;
revoke all on function public.applicable_team_color_sources(uuid) from public, anon;
grant execute on function public.applicable_team_color_sources(uuid) to authenticated;

comment on table public.source_applicability_versions is
  'Versioned publisher applicability by data type and global/sport/league/team target. It never carries or changes trust tier.';
comment on function public.resolve_team_color_source(uuid,uuid,text) is
  'Lease-scoped read-only publisher resolver. Reports publisher trust tier and target applicability independently after URL ownership resolution.';
comment on function public.add_team_color_proposal_evidence(uuid,text,text,text,timestamptz,boolean,jsonb) is
  'Adds governed Team Color evidence with independently snapshotted trust-tier and applicability versions plus URL ownership, independence, and structured claims.';

-- Deployment guards preserve reviewed state while proving the structural split.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'source_trust_assignments'
      and column_name in ('sport_id','league_id','team_id')
  ) then
    raise exception 'Trust tier table must not carry applicability columns';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'source_applicability_versions'
      and column_name = 'trust_tier'
  ) then
    raise exception 'Applicability table must not carry trust tier';
  end if;
  if exists (
    select 1 from public.source_trust_assignments
    where is_current
    group by source_id, data_type having count(*) > 1
  ) then
    raise exception 'More than one current trust tier exists for a publisher/data type';
  end if;
  if not exists (
    select 1 from public.source_trust_assignments trust
    join public.trusted_sources source on source.id = trust.source_id
    where source.source_id = 'brand-color-code' and trust.data_type = 'team_colors'
      and trust.trust_tier = 3 and trust.is_current
  ) or not exists (
    select 1 from public.source_applicability_versions applicability
    join public.trusted_sources source on source.id = applicability.source_id
    where source.source_id = 'brand-color-code'
      and applicability.data_type = 'team_colors'
      and applicability.applicability_kind = 'global'
      and applicability.review_status = 'approved' and applicability.is_current
  ) then
    raise exception 'BrandColorCode must remain Team Colors Tier 3 with global applicability';
  end if;
  if not exists (
    select 1 from public.source_trust_assignments trust
    join public.trusted_sources source on source.id = trust.source_id
    where source.source_id = 'edmonton-oilers-hockey-club'
      and trust.data_type = 'team_colors' and trust.trust_tier = 1 and trust.is_current
  ) or not exists (
    select 1 from public.source_applicability_versions applicability
    join public.trusted_sources source on source.id = applicability.source_id
    join public.catalog_teams team on team.id = applicability.team_id
    where source.source_id = 'edmonton-oilers-hockey-club'
      and applicability.data_type = 'team_colors'
      and applicability.applicability_kind = 'team'
      and team.team_id = 'hockey-000027'
      and applicability.review_status = 'approved' and applicability.is_current
  ) then
    raise exception 'Edmonton Oilers publisher must remain Team Colors Tier 1 with Edmonton applicability';
  end if;
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
end $$;
