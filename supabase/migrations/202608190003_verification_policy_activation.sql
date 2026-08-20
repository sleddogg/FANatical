-- Activate FANatical's initial verification policies and formalize source review.
-- Existing policies/decisions remain historical. Imported workbook sources are
-- not automatically reviewed, grouped, or trusted.

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
      and (
        capability.capability in (required_capability, '*')
        or (
          required_capability = 'catalog.verify.venue_mapping'
          and capability.capability = 'venue.mapping.verify'
        )
      )
      and (capability.sport_id is null or capability.sport_id = required_sport_id)
      and (capability.league_id is null or capability.league_id = required_league_id)
      and (capability.team_id is null or capability.team_id = required_team_id)
      and (capability.venue_id is null or capability.venue_id = required_venue_id)
  );
$$;

comment on function public.has_catalog_capability(text, uuid, uuid, uuid, uuid) is
  'Checks narrow actor capabilities. venue.mapping.verify is the approved verifier capability for venue_mapping proposals.';

-- Candidate import/upsert cannot approve a source, assign common ownership, or
-- assign trust. Those decisions use the dedicated review RPCs below.
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
begin
  if not public.has_staff_access(array['admin']::text[], null) then
    raise exception 'Admin access is required';
  end if;
  if independence_group_value is not null
     or coalesce(review_status_value, 'pending_review') <> 'pending_review' then
    raise exception 'Candidate import cannot assign ownership or approval; use review_trusted_source';
  end if;

  insert into public.trusted_sources(
    source_id, display_name, base_url, reference_url, independence_group_id,
    review_status, notes, metadata
  ) values (
    source_id_value, display_name_value, base_url_value, reference_url_value,
    null, 'pending_review', notes_value, coalesce(metadata_value, '{}'::jsonb)
  ) on conflict (source_id) do update set
    display_name = excluded.display_name,
    base_url = excluded.base_url,
    reference_url = excluded.reference_url,
    notes = excluded.notes,
    metadata = public.trusted_sources.metadata || excluded.metadata
  returning id into result_id;

  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'source.candidate_upserted', 'trusted_source',
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
  old_group_id text;
begin
  if not public.has_staff_access(array['admin']::text[], null)
     and not public.has_catalog_capability('source.registry.review') then
    raise exception 'source.registry.review capability is required';
  end if;
  if review_status_value not in ('pending_review', 'approved', 'suspended', 'retired') then
    raise exception 'Invalid source review status';
  end if;
  if review_status_value = 'approved' and independence_group_value is null then
    raise exception 'Approved sources require a reviewed ownership independence group';
  end if;

  select * into strict source_record
  from public.trusted_sources
  where source_id = source_registry_id
  for update;

  if independence_group_value is not null then
    select id into strict group_uuid
    from public.source_independence_groups
    where group_id = independence_group_value;
  end if;
  select group_id into old_group_id
  from public.source_independence_groups
  where id = source_record.independence_group_id;

  update public.trusted_sources
  set independence_group_id = group_uuid,
      review_status = review_status_value,
      metadata = metadata || jsonb_build_object(
        'ownership_review', jsonb_build_object(
          'notes', ownership_notes_value,
          'reviewed_at', now(),
          'reviewed_by_actor_id', actor_uuid
        )
      )
  where id = source_record.id;

  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'source.registry_reviewed', 'trusted_source',
    source_registry_id, jsonb_build_object(
      'previous_review_status', source_record.review_status,
      'new_review_status', review_status_value,
      'previous_independence_group', old_group_id,
      'new_independence_group', independence_group_value,
      'ownership_notes', ownership_notes_value
    )
  );
  return source_record.id;
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
declare
  actor_uuid uuid := public.current_catalog_actor_id();
  source_record public.trusted_sources%rowtype;
  prior_assignment public.source_trust_assignments%rowtype;
  result_id uuid;
begin
  if not public.has_staff_access(array['admin']::text[], null)
     and not public.has_catalog_capability('source.trust.assign') then
    raise exception 'source.trust.assign capability is required';
  end if;
  if trust_tier_value not between 1 and 5 then
    raise exception 'Trust tier must be between 1 and 5';
  end if;
  if nullif(btrim(data_type_value), '') is null then
    raise exception 'A data type is required';
  end if;

  select * into strict source_record
  from public.trusted_sources
  where source_id = source_registry_id
  for update;
  if source_record.review_status <> 'approved'
     or source_record.independence_group_id is null then
    raise exception 'Source ownership and independence must be approved before assigning data-type trust';
  end if;

  select * into prior_assignment
  from public.source_trust_assignments
  where source_id = source_record.id and data_type = data_type_value and is_current
  for update;

  update public.source_trust_assignments
  set is_current = false, effective_to = current_date, superseded_at = now()
  where source_id = source_record.id and data_type = data_type_value and is_current;

  insert into public.source_trust_assignments(
    source_id, data_type, trust_tier, effective_from, notes
  ) values (
    source_record.id, data_type_value, trust_tier_value, current_date, notes_value
  ) returning id into result_id;

  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, details
  ) values (
    actor_uuid, auth.uid(), 'source.trust_assigned', 'trusted_source',
    source_registry_id, jsonb_build_object(
      'data_type', data_type_value,
      'previous_tier', prior_assignment.trust_tier,
      'new_tier', trust_tier_value,
      'notes', notes_value
    )
  );
  return result_id;
end;
$$;

-- Pending candidates cannot be attached as evidence. Tier 4 can be attached as
-- a research lead but never qualifies under active policies. Tier 5 is blocked.
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
  source_record public.trusted_sources%rowtype;
  trust_record public.source_trust_assignments%rowtype;
  result_id uuid;
begin
  if actor_uuid is null then raise exception 'An active catalog actor is required'; end if;
  select * into proposal_record from public.catalog_change_proposals where id = proposal_id_value;
  if not found or proposal_record.status <> 'pending' then raise exception 'A pending proposal is required'; end if;
  if proposal_record.proposed_by_actor_id <> actor_uuid
     and not public.has_catalog_capability('catalog.evidence.add', null, proposal_record.target_league_id, proposal_record.target_team_id, proposal_record.target_venue_id) then
    raise exception 'The catalog actor cannot add evidence to this proposal';
  end if;

  select * into source_record
  from public.trusted_sources
  where source_id = source_registry_id;
  if not found then raise exception 'Unknown Trusted Source Registry ID'; end if;
  if source_record.review_status <> 'approved' or source_record.independence_group_id is null then
    raise exception 'Source ownership and independence review is not approved';
  end if;

  select * into trust_record
  from public.source_trust_assignments
  where source_id = source_record.id
    and data_type = proposal_record.fact_type
    and is_current;
  if not found then
    raise exception 'Source has no current trust assignment for data type %', proposal_record.fact_type;
  end if;
  if trust_record.trust_tier = 5 then
    raise exception 'Tier 5 sources are blocked for this data type';
  end if;

  insert into public.catalog_proposal_evidence(
    proposal_id, source_id, evidence_url, evidence_summary, observed_at,
    supports_proposal, submitted_by_actor_id
  ) values (
    proposal_id_value, source_record.id, evidence_url_value, evidence_summary_value,
    observed_at_value, supports_proposal_value, actor_uuid
  ) returning id into result_id;

  insert into public.catalog_audit_events(
    actor_id, auth_user_id, action, entity_type, entity_id, proposal_id, details
  ) values (
    actor_uuid, auth.uid(), 'proposal.evidence_added', 'catalog_proposal',
    proposal_id_value::text, proposal_id_value,
    jsonb_build_object('source_id', source_registry_id, 'trust_tier', trust_record.trust_tier)
  );
  return result_id;
end;
$$;

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
  coalesce(jsonb_agg(jsonb_build_object(
    'data_type', trust.data_type,
    'trust_tier', trust.trust_tier,
    'effective_from', trust.effective_from,
    'notes', trust.notes
  ) order by trust.data_type) filter (where trust.id is not null), '[]'::jsonb) as current_trust_assignments
from public.trusted_sources source
left join public.source_independence_groups independence on independence.id = source.independence_group_id
left join public.source_trust_assignments trust on trust.source_id = source.id and trust.is_current
group by source.id, independence.id;

-- Supersede any current policy for these data types without rewriting history.
update public.verification_policies
set is_current = false, active = false, superseded_at = now()
where data_type in ('team_colors', 'team_primary_league', 'team_venue_relationship', 'venue_mapping')
  and is_current and active;

insert into public.verification_policies(
  policy_key, version, data_type, minimum_evidence_count, allowed_trust_tiers,
  require_independent_sources, require_independent_verifier, configuration,
  is_current, active
)
values
  (
    'team-colors', 1, 'team_colors', 2, array[1,2,3]::smallint[], true, false,
    jsonb_build_object(
      'minimum_tier_1_or_2_evidence_count', 1,
      'value_format', 'uppercase_six_digit_hex',
      'tier_4', 'research_lead_only', 'tier_5', 'blocked',
      'automatic_age_staleness', false,
      'recheck_triggers', jsonb_build_array('scheduled_review', 'known_real_world_event', 'detected_conflict_or_mismatch', 'manual_request')
    ), true, true
  ),
  (
    'team-primary-league', 1, 'team_primary_league', 2, array[1,2,3]::smallint[], true, false,
    jsonb_build_object(
      'minimum_tier_1_or_2_evidence_count', 1,
      'tier_4', 'research_lead_only', 'tier_5', 'blocked',
      'automatic_age_staleness', false,
      'recheck_triggers', jsonb_build_array('scheduled_review', 'known_real_world_event', 'detected_conflict_or_mismatch', 'manual_request')
    ), true, true
  ),
  (
    'team-primary-venue', 1, 'team_venue_relationship', 2, array[1,2,3]::smallint[], true, false,
    jsonb_build_object(
      'relationship_type', 'primary',
      'minimum_tier_1_or_2_evidence_count', 1,
      'tier_4', 'research_lead_only', 'tier_5', 'blocked',
      'automatic_age_staleness', false,
      'recheck_triggers', jsonb_build_array('scheduled_review', 'known_real_world_event', 'detected_conflict_or_mismatch', 'manual_request')
    ), true, true
  ),
  (
    'venue-seat-mapping', 1, 'venue_mapping', 2, array[1,2,3]::smallint[], true, true,
    jsonb_build_object(
      'minimum_tier_1_or_2_evidence_count', 1,
      'required_verifier_capability', 'venue.mapping.verify',
      'builder_must_differ_from_verifier', true,
      'tier_4', 'research_lead_only', 'tier_5', 'blocked',
      'automatic_age_staleness', false,
      'recheck_triggers', jsonb_build_array('scheduled_review', 'known_real_world_event', 'detected_conflict_or_mismatch', 'manual_request')
    ), true, true
  );

-- Enforce configuration more specific than the generic policy columns and add
-- it to each immutable decision snapshot.
create or replace function public.enforce_catalog_verification_policy_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  proposal_record public.catalog_change_proposals%rowtype;
  policy_record public.verification_policies%rowtype;
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
    foreach color_key in array array['primary', 'secondary'] loop
      if coalesce(proposal_record.payload ->> color_key, '') !~ '^#[0-9A-F]{6}$' then
        raise exception 'Team color % must be uppercase six-digit HEX (#RRGGBB)', color_key;
      end if;
    end loop;
    foreach color_key in array array['tertiary', 'quaternary', 'quinary'] loop
      if nullif(proposal_record.payload ->> color_key, '') is not null
         and (proposal_record.payload ->> color_key) !~ '^#[0-9A-F]{6}$' then
        raise exception 'Team color % must be uppercase six-digit HEX (#RRGGBB)', color_key;
      end if;
    end loop;
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
    'required_verifier_capability', policy_record.configuration ->> 'required_verifier_capability'
  );
  return new;
end;
$$;

drop trigger if exists enforce_catalog_verification_policy_decision
on public.catalog_verification_decisions;
create trigger enforce_catalog_verification_policy_decision
before insert on public.catalog_verification_decisions
for each row execute function public.enforce_catalog_verification_policy_decision();

-- Prevent an incomplete activation or accidental source promotion from applying.
do $$
declare
  active_policy_count integer;
  promoted_import_source_count integer;
begin
  select count(*) into active_policy_count
  from public.verification_policies
  where is_current and active
    and data_type in ('team_colors', 'team_primary_league', 'team_venue_relationship', 'venue_mapping');
  if active_policy_count <> 4 then
    raise exception 'Expected four active initial verification policies, found %', active_policy_count;
  end if;

  select count(*) into promoted_import_source_count
  from public.trusted_sources
  where import_batch_id is not null and review_status <> 'pending_review';
  if promoted_import_source_count <> 0 then
    raise exception 'Imported workbook source candidates must remain pending_review';
  end if;
end $$;

grant select on public.trusted_source_review_read_model to authenticated;
revoke all on function public.review_trusted_source(text, text, text, text) from public, anon;
grant execute on function public.review_trusted_source(text, text, text, text) to authenticated;
revoke all on function public.enforce_catalog_verification_policy_decision() from public, anon, authenticated;

comment on table public.verification_policies is
  'Immutable versioned verification rules. Rechecks are event-, conflict-, schedule-, or request-driven; age alone never makes a verified fact stale.';
comment on view public.trusted_source_review_read_model is
  'Internal source-review queue with ownership independence and current data-type-specific trust assignments.';
comment on function public.review_trusted_source(text, text, text, text) is
  'Reviews source ownership and independence separately from data-type-specific trust assignment.';
