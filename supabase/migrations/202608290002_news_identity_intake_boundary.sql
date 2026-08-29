-- FANatical News Phase 2 foundation completion: governed identity intake and
-- historical podcast Show relationships. This migration adds no publisher
-- registry, ingestion runtime, monitoring, queue, Worker, feed, or Phase 4 UI.

begin;

-- ---------------------------------------------------------------------------
-- Extend the existing immutable Resolution decision ledger so intake and
-- Show-relationship mutations carry the same staff/automation provenance
-- shape as Phase 3 canonical content mutations. Automatic Resolution remains
-- a separate origin and retains its governed rule requirement.
-- ---------------------------------------------------------------------------

alter table public.news_identity_resolution_decisions
  add column decided_by_actor_id uuid references public.catalog_actors(id);

alter table public.news_identity_resolution_decisions
  drop constraint news_identity_resolution_decisions_action_check,
  drop constraint news_identity_resolution_decisions_decision_origin_check,
  drop constraint news_identity_resolution_decisions_check1;

alter table public.news_identity_resolution_decisions
  add constraint news_identity_resolution_decisions_action_check check (action in (
    'automatic_link', 'automatic_merge', 'automatic_review_required',
    'confirm_create', 'link_existing', 'keep_separate',
    'establish_affiliation', 'correct_affiliation', 'merge',
    'reverse_merge', 'not_identity', 'insufficient_evidence', 'reopen',
    'open_case', 'create_publisher_contributor_profile',
    'record_candidate', 'record_evidence',
    'establish_show_contributor', 'correct_show_contributor',
    'establish_show_publisher', 'correct_show_publisher'
  )),
  add constraint news_identity_resolution_decisions_decision_origin_check
    check (decision_origin in ('automatic', 'staff', 'automation')),
  add constraint news_identity_resolution_decisions_origin_provenance_check
    check (
      (
        decision_origin = 'staff'
        and automatic_rule_key is null
      )
      or (
        decision_origin = 'automatic'
        and automatic_rule_key is not null
        and decided_by_user_id is null
        and decided_by_actor_id is null
      )
      or (
        decision_origin = 'automation'
        and automatic_rule_key is null
        and decided_by_user_id is null
        and decided_by_actor_id is not null
      )
    );

create index news_identity_decisions_actor_idx
on public.news_identity_resolution_decisions(decided_by_actor_id, decided_at)
where decided_by_actor_id is not null;

alter table public.news_identity_resolution_cases
  drop constraint news_identity_resolution_cases_case_kind_check,
  add constraint news_identity_resolution_cases_case_kind_check check (case_kind in (
    'identity', 'publisher_profile', 'affiliation', 'person_merge',
    'show_contributor', 'show_publisher'
  )),
  add constraint news_identity_resolution_cases_show_subject_check check (
    case_kind not in ('show_contributor', 'show_publisher')
    or subject_show_id is not null
  );

alter table public.news_identity_resolution_cases
  add column opened_by_decision_id uuid
    references public.news_identity_resolution_decisions(id);
alter table public.news_identity_resolution_candidates
  add column recorded_by_decision_id uuid
    references public.news_identity_resolution_decisions(id);
alter table public.news_identity_resolution_evidence
  add column recorded_by_decision_id uuid
    references public.news_identity_resolution_decisions(id);
alter table public.news_publisher_contributor_profiles
  add column created_by_decision_id uuid
    references public.news_identity_resolution_decisions(id);

comment on column public.news_identity_resolution_cases.opened_by_decision_id is
  'Immutable provenance for cases opened through the governed canonical intake path. Historical pre-migration rows may be null.';
comment on column public.news_identity_resolution_candidates.recorded_by_decision_id is
  'Immutable provenance for candidates recorded through the governed canonical intake path. Historical pre-migration rows may be null.';
comment on column public.news_identity_resolution_evidence.recorded_by_decision_id is
  'Immutable provenance for evidence recorded through the governed canonical intake path. Historical pre-migration rows may be null.';
comment on column public.news_publisher_contributor_profiles.created_by_decision_id is
  'Immutable provenance for publisher-profile identities created through the governed canonical intake path. Historical pre-migration rows may be null.';

create or replace function public.protect_news_contributor_profile_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Publisher contributor profiles cannot be deleted';
  end if;
  if old.id is distinct from new.id
     or old.contributor_profile_id is distinct from new.contributor_profile_id
     or old.publisher_source_id is distinct from new.publisher_source_id
     or old.created_by_decision_id is distinct from new.created_by_decision_id then
    raise exception 'Publisher contributor profile identity, publisher, and creation provenance are immutable';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Shared provenance helpers. Browser roles cannot execute these functions;
-- public admin_* wrappers below are the current authorized staff surface.
-- ---------------------------------------------------------------------------

create or replace function private.require_news_identity_mutation_origin(
  decision_origin_value text,
  decided_by_user_id_value uuid,
  decided_by_actor_id_value uuid
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if decision_origin_value = 'staff' then
    if decided_by_user_id_value is null then
      raise exception 'Staff News identity mutations require an authenticated user';
    end if;
  elsif decision_origin_value = 'automation' then
    if decided_by_user_id_value is not null or decided_by_actor_id_value is null then
      raise exception 'Automated News identity mutations require an actor and no staff user';
    end if;
  else
    raise exception 'News identity mutation origin must be staff or automation';
  end if;

  if decided_by_actor_id_value is not null and not exists (
    select 1
    from public.catalog_actors actor
    where actor.id = decided_by_actor_id_value and actor.active
  ) then
    raise exception 'News identity mutation actor must be active';
  end if;
end;
$$;

create or replace function private.record_news_identity_mutation_decision(
  case_id_value uuid,
  action_value text,
  selected_candidate_id_value uuid,
  result_identity_type_value text,
  result_identity_id_value uuid,
  action_payload_value jsonb,
  decision_origin_value text,
  decided_by_user_id_value uuid,
  decided_by_actor_id_value uuid,
  notes_value text,
  supersedes_decision_id_value uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  case_record public.news_identity_resolution_cases%rowtype;
  decision_uuid uuid := gen_random_uuid();
  result_person_uuid uuid;
  result_org_uuid uuid;
  result_show_uuid uuid;
  result_profile_uuid uuid;
begin
  perform private.require_news_identity_mutation_origin(
    decision_origin_value,
    decided_by_user_id_value,
    decided_by_actor_id_value
  );
  if action_value not in (
    'open_case', 'create_publisher_contributor_profile',
    'record_candidate', 'record_evidence',
    'establish_show_contributor', 'correct_show_contributor',
    'establish_show_publisher', 'correct_show_publisher'
  ) then
    raise exception 'Unsupported canonical News identity mutation action';
  end if;

  select * into strict case_record
  from public.news_identity_resolution_cases
  where id = case_id_value;

  if selected_candidate_id_value is not null and not exists (
    select 1
    from public.news_identity_resolution_candidates candidate
    where candidate.id = selected_candidate_id_value
      and candidate.case_id = case_id_value
  ) then
    raise exception 'Selected News identity candidate must belong to the same case';
  end if;

  if result_identity_type_value = 'human' then
    select id into strict result_person_uuid
    from public.catalog_people where id = result_identity_id_value;
  elsif result_identity_type_value = 'organization' then
    select id into strict result_org_uuid
    from public.news_organizational_contributors
    where id = result_identity_id_value;
  elsif result_identity_type_value = 'show' then
    select id into strict result_show_uuid
    from public.podcast_shows where id = result_identity_id_value;
  elsif result_identity_type_value = 'publisher_profile' then
    select id into strict result_profile_uuid
    from public.news_publisher_contributor_profiles
    where id = result_identity_id_value;
  elsif result_identity_type_value not in ('affiliation', 'none') then
    raise exception 'Unsupported News identity mutation result type';
  elsif result_identity_id_value is not null then
    raise exception 'This News identity mutation result type cannot carry an identity ID';
  end if;

  insert into public.news_identity_resolution_decisions(
    id, case_id, action, decision_origin, selected_candidate_id,
    result_identity_type, result_person_id,
    result_organizational_contributor_id, result_show_id,
    result_contributor_profile_id, question_snapshot,
    action_payload_snapshot, notes, decided_by_user_id,
    decided_by_actor_id, supersedes_decision_id
  ) values (
    decision_uuid, case_id_value, action_value, decision_origin_value,
    selected_candidate_id_value, result_identity_type_value,
    result_person_uuid, result_org_uuid, result_show_uuid,
    result_profile_uuid, case_record.unresolved_question,
    coalesce(action_payload_value, '{}'::jsonb), notes_value,
    decided_by_user_id_value, decided_by_actor_id_value,
    supersedes_decision_id_value
  );
  return decision_uuid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Governed case, candidate, evidence, and publisher-profile intake.
-- Existing validation/evaluation triggers remain the Resolution authority.
-- ---------------------------------------------------------------------------

create or replace function private.open_news_identity_case_canonical(
  case_kind_value text,
  proposed_identity_type_value text,
  proposed_name_value text,
  publisher_source_id_value uuid,
  subject_person_id_value uuid,
  subject_organizational_contributor_id_value uuid,
  subject_show_id_value uuid,
  subject_contributor_profile_id_value uuid,
  raw_byline_value text,
  profile_url_value text,
  unresolved_question_value text,
  context_value jsonb,
  decision_origin_value text,
  decided_by_user_id_value uuid,
  decided_by_actor_id_value uuid,
  notes_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  case_uuid uuid := gen_random_uuid();
  decision_uuid uuid;
  publisher_uuid uuid := publisher_source_id_value;
  profile_publisher_uuid uuid;
begin
  perform private.require_news_identity_mutation_origin(
    decision_origin_value,
    decided_by_user_id_value,
    decided_by_actor_id_value
  );
  if case_kind_value not in (
    'identity', 'publisher_profile', 'affiliation', 'person_merge',
    'show_contributor', 'show_publisher'
  ) then
    raise exception 'Unsupported News identity case kind';
  end if;
  if length(btrim(coalesce(unresolved_question_value, ''))) = 0 then
    raise exception 'News identity intake requires an unresolved question';
  end if;

  if publisher_uuid is not null then
    publisher_uuid := public.canonical_trusted_source_id(publisher_uuid);
    perform 1 from public.trusted_sources where id = publisher_uuid;
    if not found then raise exception 'News identity case publisher does not exist'; end if;
  end if;
  if subject_person_id_value is not null then
    perform 1 from public.catalog_people where id = subject_person_id_value;
    if not found then raise exception 'News identity case person does not exist'; end if;
  end if;
  if subject_organizational_contributor_id_value is not null then
    perform 1 from public.news_organizational_contributors
    where id = subject_organizational_contributor_id_value;
    if not found then raise exception 'News identity case organization does not exist'; end if;
  end if;
  if subject_show_id_value is not null then
    perform 1 from public.podcast_shows where id = subject_show_id_value;
    if not found then raise exception 'News identity case Show does not exist'; end if;
  end if;
  if subject_contributor_profile_id_value is not null then
    select profile.publisher_source_id into strict profile_publisher_uuid
    from public.news_publisher_contributor_profiles profile
    where profile.id = subject_contributor_profile_id_value;
    profile_publisher_uuid := public.canonical_trusted_source_id(profile_publisher_uuid);
    if publisher_uuid is null then
      publisher_uuid := profile_publisher_uuid;
    elsif publisher_uuid <> profile_publisher_uuid then
      raise exception 'News identity case publisher must match its contributor profile';
    end if;
  end if;
  if case_kind_value = 'person_merge' and subject_person_id_value is null then
    raise exception 'Person-merge intake requires a subject person';
  end if;
  if case_kind_value in ('show_contributor', 'show_publisher')
     and subject_show_id_value is null then
    raise exception 'Show relationship intake requires a subject Show';
  end if;

  insert into public.news_identity_resolution_cases(
    id, case_kind, proposed_identity_type, proposed_name,
    publisher_source_id, subject_person_id,
    subject_organizational_contributor_id, subject_show_id,
    subject_contributor_profile_id, raw_byline, profile_url,
    unresolved_question, context, created_by_user_id
  ) values (
    case_uuid, case_kind_value, proposed_identity_type_value,
    proposed_name_value, publisher_uuid, subject_person_id_value,
    subject_organizational_contributor_id_value, subject_show_id_value,
    subject_contributor_profile_id_value, raw_byline_value,
    profile_url_value, unresolved_question_value,
    coalesce(context_value, '{}'::jsonb),
    case when decision_origin_value = 'staff'
      then decided_by_user_id_value else null end
  );

  decision_uuid := private.record_news_identity_mutation_decision(
    case_uuid, 'open_case', null, 'none', null,
    jsonb_build_object(
      'case_kind', case_kind_value,
      'proposed_identity_type', proposed_identity_type_value,
      'publisher_source_id', publisher_uuid,
      'subject_person_id', subject_person_id_value,
      'subject_organizational_contributor_id',
        subject_organizational_contributor_id_value,
      'subject_show_id', subject_show_id_value,
      'subject_contributor_profile_id', subject_contributor_profile_id_value
    ),
    decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, notes_value, null
  );
  update public.news_identity_resolution_cases
  set opened_by_decision_id = decision_uuid
  where id = case_uuid;
  return case_uuid;
end;
$$;

create or replace function private.create_news_publisher_contributor_profile_canonical(
  case_id_value uuid,
  decision_origin_value text,
  decided_by_user_id_value uuid,
  decided_by_actor_id_value uuid,
  notes_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  case_record public.news_identity_resolution_cases%rowtype;
  profile_uuid uuid := gen_random_uuid();
  decision_uuid uuid;
begin
  select * into strict case_record
  from public.news_identity_resolution_cases
  where id = case_id_value
  for update;
  if case_record.case_kind <> 'publisher_profile'
     or case_record.publisher_source_id is null then
    raise exception 'Publisher contributor profile creation requires a publisher-profile case';
  end if;
  if case_record.subject_contributor_profile_id is not null then
    raise exception 'Resolution case already has a publisher contributor profile';
  end if;

  decision_uuid := private.record_news_identity_mutation_decision(
    case_id_value, 'create_publisher_contributor_profile', null,
    'none', null,
    jsonb_build_object(
      'contributor_profile_id', profile_uuid,
      'publisher_source_id', case_record.publisher_source_id,
      'profile_url', case_record.profile_url
    ),
    decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, notes_value, null
  );
  insert into public.news_publisher_contributor_profiles(
    id, publisher_source_id, created_by_decision_id
  ) values (
    profile_uuid, case_record.publisher_source_id, decision_uuid
  );
  update public.news_identity_resolution_cases
  set subject_contributor_profile_id = profile_uuid
  where id = case_id_value;
  return profile_uuid;
end;
$$;

create or replace function private.record_news_identity_candidate_canonical(
  case_id_value uuid,
  candidate_kind_value text,
  identity_type_value text,
  target_identity_id_value uuid,
  display_name_value text,
  proposed_facts_value jsonb,
  decision_origin_value text,
  decided_by_user_id_value uuid,
  decided_by_actor_id_value uuid,
  notes_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidate_uuid uuid := gen_random_uuid();
  decision_uuid uuid;
  person_uuid uuid;
  organization_uuid uuid;
  show_uuid uuid;
  profile_uuid uuid;
begin
  perform 1
  from public.news_identity_resolution_cases
  where id = case_id_value;
  if not found then raise exception 'News identity Resolution case does not exist'; end if;
  if length(btrim(coalesce(display_name_value, ''))) = 0 then
    raise exception 'News identity candidate requires a display name';
  end if;

  if candidate_kind_value = 'proposed_identity' then
    if target_identity_id_value is not null then
      raise exception 'A proposed identity candidate cannot claim an existing identity ID';
    end if;
  elsif target_identity_id_value is null then
    raise exception 'An existing identity candidate requires a target identity ID';
  end if;

  if target_identity_id_value is not null and identity_type_value = 'human' then
    select id into strict person_uuid
    from public.catalog_people where id = target_identity_id_value;
  elsif target_identity_id_value is not null and identity_type_value = 'organization' then
    select id into strict organization_uuid
    from public.news_organizational_contributors
    where id = target_identity_id_value;
  elsif target_identity_id_value is not null and identity_type_value = 'show' then
    select id into strict show_uuid
    from public.podcast_shows where id = target_identity_id_value;
  elsif target_identity_id_value is not null and identity_type_value = 'publisher_profile' then
    select id into strict profile_uuid
    from public.news_publisher_contributor_profiles
    where id = target_identity_id_value;
  elsif identity_type_value not in ('human', 'organization', 'show', 'publisher_profile') then
    raise exception 'Unsupported News identity candidate type';
  end if;

  decision_uuid := private.record_news_identity_mutation_decision(
    case_id_value, 'record_candidate', null, 'none', null,
    jsonb_build_object(
      'candidate_id', candidate_uuid,
      'candidate_kind', candidate_kind_value,
      'identity_type', identity_type_value,
      'target_identity_id', target_identity_id_value,
      'display_name', display_name_value,
      'proposed_facts', coalesce(proposed_facts_value, '{}'::jsonb)
    ),
    decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, notes_value, null
  );

  insert into public.news_identity_resolution_candidates(
    id, case_id, candidate_kind, identity_type,
    person_id, organizational_contributor_id, show_id,
    contributor_profile_id, display_name, proposed_facts,
    recorded_by_decision_id
  ) values (
    candidate_uuid, case_id_value, candidate_kind_value,
    identity_type_value, person_uuid, organization_uuid, show_uuid,
    profile_uuid, display_name_value,
    coalesce(proposed_facts_value, '{}'::jsonb), decision_uuid
  );
  return candidate_uuid;
end;
$$;

create or replace function private.record_news_identity_evidence_canonical(
  case_id_value uuid,
  candidate_id_value uuid,
  evidence_kind_value text,
  publisher_source_id_value uuid,
  evidence_url_value text,
  bridge_from_publisher_source_id_value uuid,
  bridge_to_publisher_source_id_value uuid,
  visibility_value text,
  is_conflicting_value boolean,
  evidence_summary_value text,
  observed_payload_value jsonb,
  observed_at_value timestamptz,
  decision_origin_value text,
  decided_by_user_id_value uuid,
  decided_by_actor_id_value uuid,
  notes_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  evidence_uuid uuid := gen_random_uuid();
  decision_uuid uuid;
  publisher_uuid uuid := publisher_source_id_value;
  bridge_from_uuid uuid := bridge_from_publisher_source_id_value;
  bridge_to_uuid uuid := bridge_to_publisher_source_id_value;
begin
  perform 1
  from public.news_identity_resolution_cases
  where id = case_id_value;
  if not found then raise exception 'News identity Resolution case does not exist'; end if;
  if candidate_id_value is not null and not exists (
    select 1
    from public.news_identity_resolution_candidates candidate
    where candidate.id = candidate_id_value and candidate.case_id = case_id_value
  ) then
    raise exception 'News identity evidence candidate must belong to the same case';
  end if;
  perform 1
  from public.news_identity_evidence_kinds
  where evidence_kind = evidence_kind_value and active;
  if not found then raise exception 'News identity evidence kind is not governed or active'; end if;
  if length(btrim(coalesce(evidence_summary_value, ''))) = 0 then
    raise exception 'News identity evidence requires a summary';
  end if;

  if publisher_uuid is not null then
    publisher_uuid := public.canonical_trusted_source_id(publisher_uuid);
  end if;
  if bridge_from_uuid is not null then
    bridge_from_uuid := public.canonical_trusted_source_id(bridge_from_uuid);
  end if;
  if bridge_to_uuid is not null then
    bridge_to_uuid := public.canonical_trusted_source_id(bridge_to_uuid);
  end if;

  decision_uuid := private.record_news_identity_mutation_decision(
    case_id_value, 'record_evidence', candidate_id_value, 'none', null,
    jsonb_build_object(
      'evidence_id', evidence_uuid,
      'evidence_kind', evidence_kind_value,
      'candidate_id', candidate_id_value,
      'publisher_source_id', publisher_uuid,
      'evidence_url', evidence_url_value,
      'bridge_from_publisher_source_id', bridge_from_uuid,
      'bridge_to_publisher_source_id', bridge_to_uuid,
      'visibility', visibility_value,
      'is_conflicting', coalesce(is_conflicting_value, false),
      'observed_at', observed_at_value
    ),
    decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, notes_value, null
  );

  insert into public.news_identity_resolution_evidence(
    id, case_id, candidate_id, evidence_kind, publisher_source_id,
    evidence_url, bridge_from_publisher_source_id,
    bridge_to_publisher_source_id, visibility, is_conflicting,
    evidence_summary, observed_payload, observed_at,
    recorded_by_user_id, recorded_by_decision_id
  ) values (
    evidence_uuid, case_id_value, candidate_id_value,
    evidence_kind_value, publisher_uuid, evidence_url_value,
    bridge_from_uuid, bridge_to_uuid, visibility_value,
    coalesce(is_conflicting_value, false), evidence_summary_value,
    coalesce(observed_payload_value, '{}'::jsonb), observed_at_value,
    case when decision_origin_value = 'staff'
      then decided_by_user_id_value else null end,
    decision_uuid
  );
  return evidence_uuid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Governed, time-bounded Show relationships. Corrections close only the
-- recorded version; factual effective dates are supplied explicitly and are
-- never replaced with the time FANatical recorded the correction.
-- ---------------------------------------------------------------------------

create or replace function private.record_podcast_show_contributor_canonical(
  case_id_value uuid,
  relationship_id_value uuid,
  person_id_value uuid,
  contributor_role_value text,
  effective_from_value timestamptz,
  effective_to_value timestamptz,
  decision_origin_value text,
  decided_by_user_id_value uuid,
  decided_by_actor_id_value uuid,
  notes_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  case_record public.news_identity_resolution_cases%rowtype;
  current_relationship public.podcast_show_contributor_versions%rowtype;
  action_value text;
  previous_decision_uuid uuid;
  decision_uuid uuid;
  decision_at_value timestamptz;
  relationship_uuid uuid := gen_random_uuid();
begin
  select * into strict case_record
  from public.news_identity_resolution_cases
  where id = case_id_value
  for update;
  if case_record.case_kind <> 'show_contributor'
     or case_record.subject_show_id is null then
    raise exception 'Show contributor mutation requires a Show-contributor case';
  end if;
  perform 1 from public.catalog_people where id = person_id_value;
  if not found then raise exception 'Show contributor person does not exist'; end if;
  perform 1 from public.news_show_contributor_roles
  where contributor_role = contributor_role_value and active;
  if not found then raise exception 'Show contributor role is not governed or active'; end if;

  if relationship_id_value is null then
    action_value := 'establish_show_contributor';
  else
    action_value := 'correct_show_contributor';
    select * into strict current_relationship
    from public.podcast_show_contributor_versions relationship
    where relationship.id = relationship_id_value
      and relationship.show_id = case_record.subject_show_id
      and relationship.is_current
    for update;
  end if;

  select decision.id into previous_decision_uuid
  from public.news_identity_resolution_decisions decision
  where decision.case_id = case_id_value
    and decision.action not in (
      'open_case', 'create_publisher_contributor_profile',
      'record_candidate', 'record_evidence'
    )
  order by decision.decided_at desc, decision.id desc
  limit 1;

  decision_uuid := private.record_news_identity_mutation_decision(
    case_id_value, action_value, null, 'show', case_record.subject_show_id,
    jsonb_build_object(
      'relationship_id', relationship_uuid,
      'supersedes_relationship_id', relationship_id_value,
      'show_id', case_record.subject_show_id,
      'person_id', person_id_value,
      'contributor_role', contributor_role_value,
      'effective_from', effective_from_value,
      'effective_to', effective_to_value
    ),
    decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, notes_value, previous_decision_uuid
  );
  select decided_at into decision_at_value
  from public.news_identity_resolution_decisions where id = decision_uuid;
  perform private.snapshot_news_identity_decision_evidence(
    decision_uuid, case_id_value
  );

  if relationship_id_value is not null then
    update public.podcast_show_contributor_versions
    set is_current = false,
        superseded_at = decision_at_value,
        closed_by_decision_id = decision_uuid
    where id = current_relationship.id;
  end if;

  insert into public.podcast_show_contributor_versions(
    id, show_id, person_id, contributor_role,
    effective_from, effective_to, resolution_decision_id, notes
  ) values (
    relationship_uuid, case_record.subject_show_id, person_id_value,
    contributor_role_value, effective_from_value, effective_to_value,
    decision_uuid, notes_value
  );

  update public.news_identity_resolution_cases
  set status = case when decision_origin_value = 'staff'
        then 'resolved_manual' else 'resolved_automatic' end,
      automatic_resolution_result = action_value,
      resolution_stop_reason = null,
      resolved_at = decision_at_value
  where id = case_id_value;
  return relationship_uuid;
end;
$$;

create or replace function private.record_podcast_show_publisher_canonical(
  case_id_value uuid,
  relationship_id_value uuid,
  publisher_source_id_value uuid,
  relationship_type_value text,
  effective_from_value timestamptz,
  effective_to_value timestamptz,
  decision_origin_value text,
  decided_by_user_id_value uuid,
  decided_by_actor_id_value uuid,
  notes_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  case_record public.news_identity_resolution_cases%rowtype;
  current_relationship public.podcast_show_publisher_relationship_versions%rowtype;
  publisher_uuid uuid;
  action_value text;
  previous_decision_uuid uuid;
  decision_uuid uuid;
  decision_at_value timestamptz;
  relationship_uuid uuid := gen_random_uuid();
begin
  select * into strict case_record
  from public.news_identity_resolution_cases
  where id = case_id_value
  for update;
  if case_record.case_kind <> 'show_publisher'
     or case_record.subject_show_id is null then
    raise exception 'Show publisher mutation requires a Show-publisher case';
  end if;
  publisher_uuid := public.canonical_trusted_source_id(
    publisher_source_id_value
  );
  perform 1 from public.trusted_sources where id = publisher_uuid;
  if not found then raise exception 'Show publisher identity does not exist'; end if;
  perform 1 from public.news_show_publisher_relationship_types
  where relationship_type = relationship_type_value and active;
  if not found then raise exception 'Show publisher relationship type is not governed or active'; end if;

  if relationship_id_value is null then
    action_value := 'establish_show_publisher';
  else
    action_value := 'correct_show_publisher';
    select * into strict current_relationship
    from public.podcast_show_publisher_relationship_versions relationship
    where relationship.id = relationship_id_value
      and relationship.show_id = case_record.subject_show_id
      and relationship.is_current
    for update;
  end if;

  select decision.id into previous_decision_uuid
  from public.news_identity_resolution_decisions decision
  where decision.case_id = case_id_value
    and decision.action not in (
      'open_case', 'create_publisher_contributor_profile',
      'record_candidate', 'record_evidence'
    )
  order by decision.decided_at desc, decision.id desc
  limit 1;

  decision_uuid := private.record_news_identity_mutation_decision(
    case_id_value, action_value, null, 'show', case_record.subject_show_id,
    jsonb_build_object(
      'relationship_id', relationship_uuid,
      'supersedes_relationship_id', relationship_id_value,
      'show_id', case_record.subject_show_id,
      'publisher_source_id', publisher_uuid,
      'relationship_type', relationship_type_value,
      'effective_from', effective_from_value,
      'effective_to', effective_to_value
    ),
    decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, notes_value, previous_decision_uuid
  );
  select decided_at into decision_at_value
  from public.news_identity_resolution_decisions where id = decision_uuid;
  perform private.snapshot_news_identity_decision_evidence(
    decision_uuid, case_id_value
  );

  if relationship_id_value is not null then
    update public.podcast_show_publisher_relationship_versions
    set is_current = false,
        superseded_at = decision_at_value,
        closed_by_decision_id = decision_uuid
    where id = current_relationship.id;
  end if;

  insert into public.podcast_show_publisher_relationship_versions(
    id, show_id, publisher_source_id, relationship_type,
    effective_from, effective_to, resolution_decision_id, notes
  ) values (
    relationship_uuid, case_record.subject_show_id, publisher_uuid,
    relationship_type_value, effective_from_value, effective_to_value,
    decision_uuid, notes_value
  );

  update public.news_identity_resolution_cases
  set status = case when decision_origin_value = 'staff'
        then 'resolved_manual' else 'resolved_automatic' end,
      automatic_resolution_result = action_value,
      resolution_stop_reason = null,
      resolved_at = decision_at_value
  where id = case_id_value;
  return relationship_uuid;
end;
$$;

-- Intake actions are causal audit records, not Resolution outcomes. Existing
-- Phase 2 evaluators ask for the latest decision when chaining supersession;
-- normalize that pointer so an automatic/staff outcome supersedes the prior
-- outcome rather than an intervening case/candidate/evidence intake action.
create or replace function public.normalize_news_identity_outcome_supersession()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.action not in (
    'open_case', 'create_publisher_contributor_profile',
    'record_candidate', 'record_evidence'
  ) and new.supersedes_decision_id is not null and exists (
    select 1
    from public.news_identity_resolution_decisions decision
    where decision.id = new.supersedes_decision_id
      and decision.action in (
        'open_case', 'create_publisher_contributor_profile',
        'record_candidate', 'record_evidence'
      )
  ) then
    select decision.id into new.supersedes_decision_id
    from public.news_identity_resolution_decisions decision
    where decision.case_id = new.case_id
      and decision.action not in (
        'open_case', 'create_publisher_contributor_profile',
        'record_candidate', 'record_evidence'
      )
    order by decision.decided_at desc, decision.id desc
    limit 1;
  end if;
  return new;
end;
$$;

create trigger normalize_news_identity_outcome_supersession
before insert on public.news_identity_resolution_decisions
for each row execute function public.normalize_news_identity_outcome_supersession();

-- ---------------------------------------------------------------------------
-- Thin staff wrappers. These are the only new browser-callable mutations.
-- Future automation receives no public wrapper in this phase; a separately
-- authorized caller can reuse the private canonical functions later.
-- ---------------------------------------------------------------------------

create or replace function public.admin_open_news_identity_case(
  case_kind_value text,
  proposed_identity_type_value text,
  proposed_name_value text,
  publisher_source_id_value uuid,
  subject_person_id_value uuid,
  subject_organizational_contributor_id_value uuid,
  subject_show_id_value uuid,
  subject_contributor_profile_id_value uuid,
  raw_byline_value text,
  profile_url_value text,
  unresolved_question_value text,
  context_value jsonb default '{}'::jsonb,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News identity intake access is required';
  end if;
  return private.open_news_identity_case_canonical(
    case_kind_value, proposed_identity_type_value, proposed_name_value,
    publisher_source_id_value, subject_person_id_value,
    subject_organizational_contributor_id_value, subject_show_id_value,
    subject_contributor_profile_id_value, raw_byline_value,
    profile_url_value, unresolved_question_value, context_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

create or replace function public.admin_create_news_publisher_contributor_profile(
  case_id_value uuid,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News identity intake access is required';
  end if;
  return private.create_news_publisher_contributor_profile_canonical(
    case_id_value, 'staff', auth.uid(), public.current_catalog_actor_id(),
    notes_value
  );
end;
$$;

create or replace function public.admin_record_news_identity_candidate(
  case_id_value uuid,
  candidate_kind_value text,
  identity_type_value text,
  target_identity_id_value uuid,
  display_name_value text,
  proposed_facts_value jsonb default '{}'::jsonb,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News identity intake access is required';
  end if;
  return private.record_news_identity_candidate_canonical(
    case_id_value, candidate_kind_value, identity_type_value,
    target_identity_id_value, display_name_value, proposed_facts_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

create or replace function public.admin_record_news_identity_evidence(
  case_id_value uuid,
  candidate_id_value uuid,
  evidence_kind_value text,
  publisher_source_id_value uuid,
  evidence_url_value text,
  bridge_from_publisher_source_id_value uuid,
  bridge_to_publisher_source_id_value uuid,
  visibility_value text,
  is_conflicting_value boolean,
  evidence_summary_value text,
  observed_payload_value jsonb default '{}'::jsonb,
  observed_at_value timestamptz default null,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News identity intake access is required';
  end if;
  return private.record_news_identity_evidence_canonical(
    case_id_value, candidate_id_value, evidence_kind_value,
    publisher_source_id_value, evidence_url_value,
    bridge_from_publisher_source_id_value,
    bridge_to_publisher_source_id_value, visibility_value,
    is_conflicting_value, evidence_summary_value,
    observed_payload_value, observed_at_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

create or replace function public.admin_record_podcast_show_contributor(
  case_id_value uuid,
  person_id_value uuid,
  contributor_role_value text,
  effective_from_value timestamptz,
  effective_to_value timestamptz,
  relationship_id_value uuid default null,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News identity intake access is required';
  end if;
  return private.record_podcast_show_contributor_canonical(
    case_id_value, relationship_id_value, person_id_value,
    contributor_role_value, effective_from_value, effective_to_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

create or replace function public.admin_record_podcast_show_publisher(
  case_id_value uuid,
  publisher_source_id_value uuid,
  relationship_type_value text,
  effective_from_value timestamptz,
  effective_to_value timestamptz,
  relationship_id_value uuid default null,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News identity intake access is required';
  end if;
  return private.record_podcast_show_publisher_canonical(
    case_id_value, relationship_id_value, publisher_source_id_value,
    relationship_type_value, effective_from_value, effective_to_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

revoke all on function public.admin_open_news_identity_case(
  text,text,text,uuid,uuid,uuid,uuid,uuid,text,text,text,jsonb,text
) from public, anon;
grant execute on function public.admin_open_news_identity_case(
  text,text,text,uuid,uuid,uuid,uuid,uuid,text,text,text,jsonb,text
) to authenticated;
revoke all on function public.admin_create_news_publisher_contributor_profile(
  uuid,text
) from public, anon;
grant execute on function public.admin_create_news_publisher_contributor_profile(
  uuid,text
) to authenticated;
revoke all on function public.admin_record_news_identity_candidate(
  uuid,text,text,uuid,text,jsonb,text
) from public, anon;
grant execute on function public.admin_record_news_identity_candidate(
  uuid,text,text,uuid,text,jsonb,text
) to authenticated;
revoke all on function public.admin_record_news_identity_evidence(
  uuid,uuid,text,uuid,text,uuid,uuid,text,boolean,text,jsonb,timestamptz,text
) from public, anon;
grant execute on function public.admin_record_news_identity_evidence(
  uuid,uuid,text,uuid,text,uuid,uuid,text,boolean,text,jsonb,timestamptz,text
) to authenticated;
revoke all on function public.admin_record_podcast_show_contributor(
  uuid,uuid,text,timestamptz,timestamptz,uuid,text
) from public, anon;
grant execute on function public.admin_record_podcast_show_contributor(
  uuid,uuid,text,timestamptz,timestamptz,uuid,text
) to authenticated;
revoke all on function public.admin_record_podcast_show_publisher(
  uuid,uuid,text,timestamptz,timestamptz,uuid,text
) from public, anon;
grant execute on function public.admin_record_podcast_show_publisher(
  uuid,uuid,text,timestamptz,timestamptz,uuid,text
) to authenticated;

revoke all on function private.require_news_identity_mutation_origin(
  text,uuid,uuid
) from public, anon, authenticated;
revoke all on function private.record_news_identity_mutation_decision(
  uuid,text,uuid,text,uuid,jsonb,text,uuid,uuid,text,uuid
) from public, anon, authenticated;
revoke all on function private.open_news_identity_case_canonical(
  text,text,text,uuid,uuid,uuid,uuid,uuid,text,text,text,jsonb,
  text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function private.create_news_publisher_contributor_profile_canonical(
  uuid,text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function private.record_news_identity_candidate_canonical(
  uuid,text,text,uuid,text,jsonb,text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function private.record_news_identity_evidence_canonical(
  uuid,uuid,text,uuid,text,uuid,uuid,text,boolean,text,jsonb,timestamptz,
  text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function private.record_podcast_show_contributor_canonical(
  uuid,uuid,uuid,text,timestamptz,timestamptz,text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function private.record_podcast_show_publisher_canonical(
  uuid,uuid,uuid,text,timestamptz,timestamptz,text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function public.normalize_news_identity_outcome_supersession()
from public, anon, authenticated;

comment on function public.admin_open_news_identity_case(
  text,text,text,uuid,uuid,uuid,uuid,uuid,text,text,text,jsonb,text
) is 'Authorized staff wrapper over the shared canonical Phase 2 identity-case intake operation.';
comment on function public.admin_record_news_identity_evidence(
  uuid,uuid,text,uuid,text,uuid,uuid,text,boolean,text,jsonb,timestamptz,text
) is 'Authorized staff wrapper for provenance-backed public evidence. Existing URL ownership and automatic Resolution triggers remain authoritative.';
comment on function public.admin_record_podcast_show_contributor(
  uuid,uuid,text,timestamptz,timestamptz,uuid,text
) is 'Authorized staff wrapper for versioned Show/person host and contributor facts.';
comment on function public.admin_record_podcast_show_publisher(
  uuid,uuid,text,timestamptz,timestamptz,uuid,text
) is 'Authorized staff wrapper for versioned Show/publisher and network facts.';

-- No News publisher-policy setter is added here. Phase 3 controlled canary
-- publication does not consult news_publisher_policy_versions; factual source
-- governance and preview policy remain separate existing systems.

commit;
