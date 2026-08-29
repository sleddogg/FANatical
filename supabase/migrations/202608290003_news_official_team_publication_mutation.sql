-- FANatical News Phase 2 correction: governed official Team/publication facts.
-- This migration adds only the missing shared canonical mutation and staff
-- wrapper. The relationship is factual and creates no follow, feed eligibility,
-- TeamContext, ranking, Worker, or public automation behavior.

begin;

-- The immutable decision ledger names the two new factual relationship
-- outcomes explicitly while retaining every existing identity action.
alter table public.news_identity_resolution_decisions
  drop constraint news_identity_resolution_decisions_action_check,
  add constraint news_identity_resolution_decisions_action_check check (action in (
    'automatic_link', 'automatic_merge', 'automatic_review_required',
    'confirm_create', 'link_existing', 'keep_separate',
    'establish_affiliation', 'correct_affiliation', 'merge',
    'reverse_merge', 'not_identity', 'insufficient_evidence', 'reopen',
    'open_case', 'create_publisher_contributor_profile',
    'record_candidate', 'record_evidence',
    'establish_show_contributor', 'correct_show_contributor',
    'establish_show_publisher', 'correct_show_publisher',
    'establish_official_team_publication',
    'correct_official_team_publication'
  ));

-- Official Team/publication review is its own factual case kind. The publisher
-- is required, and only the optional organizational contributor may be the
-- case subject; the canonical Team is supplied to and validated by the
-- relationship mutation itself.
alter table public.news_identity_resolution_cases
  drop constraint news_identity_resolution_cases_case_kind_check,
  add constraint news_identity_resolution_cases_case_kind_check check (case_kind in (
    'identity', 'publisher_profile', 'affiliation', 'person_merge',
    'show_contributor', 'show_publisher', 'official_team_publication'
  )),
  add constraint news_identity_resolution_cases_official_team_subject_check check (
    case_kind <> 'official_team_publication'
    or (
      publisher_source_id is not null
      and subject_person_id is null
      and subject_show_id is null
      and subject_contributor_profile_id is null
    )
  );

-- Keep the existing shared provenance helper authoritative for staff and
-- future governed automation callers. These new actions are relationship
-- outcomes, not intake actions, so the existing outcome-supersession behavior
-- remains correct.
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
    'establish_show_publisher', 'correct_show_publisher',
    'establish_official_team_publication',
    'correct_official_team_publication'
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

-- Extend the existing shared case opener without changing its public staff
-- signature or any previously supported case behavior.
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
    'show_contributor', 'show_publisher', 'official_team_publication'
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
  if case_kind_value = 'official_team_publication'
     and (
       publisher_uuid is null
       or subject_person_id_value is not null
       or subject_show_id_value is not null
       or subject_contributor_profile_id_value is not null
     ) then
    raise exception 'Official Team/publication intake requires a publisher and permits only an optional organizational subject';
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

-- This relationship case has factual publisher/Team targets rather than an
-- identity candidate. Keeping candidates out prevents the general identity
-- evaluator from treating the case as an identity-linking question.
create or replace function public.validate_official_team_publication_candidate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.news_identity_resolution_cases resolution_case
    where resolution_case.id = new.case_id
      and resolution_case.case_kind = 'official_team_publication'
  ) then
    raise exception 'Official Team/publication cases do not accept identity candidates';
  end if;
  return new;
end;
$$;

create trigger validate_official_team_publication_candidate
before insert on public.news_identity_resolution_candidates
for each row execute function public.validate_official_team_publication_candidate();

-- Shared history-preserving mutation. The publisher and optional organization
-- are bound by the governed case; the Team is a canonical catalog FK. Factual
-- effective dates are copied exactly into the new version, while the immutable
-- decision timestamp closes the superseded record version separately.
create or replace function private.record_news_official_team_publication_canonical(
  case_id_value uuid,
  relationship_id_value uuid,
  team_id_value uuid,
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
  current_relationship public.news_official_team_publication_versions%rowtype;
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

  if case_record.case_kind <> 'official_team_publication'
     or case_record.publisher_source_id is null then
    raise exception 'Official Team/publication mutation requires its governed relationship case';
  end if;

  publisher_uuid := public.canonical_trusted_source_id(
    case_record.publisher_source_id
  );
  perform 1 from public.trusted_sources where id = publisher_uuid;
  if not found then raise exception 'Official Team/publication publisher does not exist'; end if;
  perform 1 from public.catalog_teams where id = team_id_value;
  if not found then raise exception 'Official Team/publication Team identity does not exist'; end if;
  if case_record.subject_organizational_contributor_id is not null then
    perform 1 from public.news_organizational_contributors
    where id = case_record.subject_organizational_contributor_id;
    if not found then
      raise exception 'Official Team/publication organization does not exist';
    end if;
  end if;
  if relationship_type_value not in (
    'official_publication', 'official_newsroom', 'official_team_site'
  ) then
    raise exception 'Official Team/publication relationship type is not governed';
  end if;

  if relationship_id_value is null then
    action_value := 'establish_official_team_publication';
    select decision.id into previous_decision_uuid
    from public.news_identity_resolution_decisions decision
    where decision.case_id = case_id_value
      and decision.action not in (
        'open_case', 'create_publisher_contributor_profile',
        'record_candidate', 'record_evidence'
      )
    order by decision.decided_at desc, decision.id desc
    limit 1;
  else
    action_value := 'correct_official_team_publication';
    select * into strict current_relationship
    from public.news_official_team_publication_versions relationship
    where relationship.id = relationship_id_value
      and relationship.publisher_source_id = publisher_uuid
      and relationship.organizational_contributor_id is not distinct from
        case_record.subject_organizational_contributor_id
      and relationship.is_current
    for update;
    previous_decision_uuid := current_relationship.resolution_decision_id;
  end if;

  decision_uuid := private.record_news_identity_mutation_decision(
    case_id_value, action_value, null, 'affiliation', null,
    jsonb_build_object(
      'relationship_id', relationship_uuid,
      'supersedes_relationship_id', relationship_id_value,
      'publisher_source_id', publisher_uuid,
      'team_id', team_id_value,
      'organizational_contributor_id',
        case_record.subject_organizational_contributor_id,
      'relationship_type', relationship_type_value,
      'effective_from', effective_from_value,
      'effective_to', effective_to_value
    ),
    decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, notes_value, previous_decision_uuid
  );
  select decided_at into decision_at_value
  from public.news_identity_resolution_decisions
  where id = decision_uuid;
  perform private.snapshot_news_identity_decision_evidence(
    decision_uuid, case_id_value
  );

  if relationship_id_value is not null then
    update public.news_official_team_publication_versions
    set is_current = false,
        superseded_at = decision_at_value,
        closed_by_decision_id = decision_uuid
    where id = current_relationship.id;
  end if;

  insert into public.news_official_team_publication_versions(
    id, publisher_source_id, team_id, organizational_contributor_id,
    relationship_type, effective_from, effective_to,
    resolution_decision_id, notes
  ) values (
    relationship_uuid, publisher_uuid, team_id_value,
    case_record.subject_organizational_contributor_id,
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

-- Thin current staff surface. There is intentionally no public automation
-- wrapper; a future separately authorized caller can reuse the private
-- canonical operation with automation actor provenance.
create or replace function public.admin_record_news_official_team_publication(
  case_id_value uuid,
  team_id_value uuid,
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
  return private.record_news_official_team_publication_canonical(
    case_id_value, relationship_id_value, team_id_value,
    relationship_type_value, effective_from_value, effective_to_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

revoke all on function public.admin_record_news_official_team_publication(
  uuid,uuid,text,timestamptz,timestamptz,uuid,text
) from public, anon;
grant execute on function public.admin_record_news_official_team_publication(
  uuid,uuid,text,timestamptz,timestamptz,uuid,text
) to authenticated;

revoke all on function private.record_news_official_team_publication_canonical(
  uuid,uuid,uuid,text,timestamptz,timestamptz,text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function public.validate_official_team_publication_candidate()
from public, anon, authenticated;

comment on function public.admin_record_news_official_team_publication(
  uuid,uuid,text,timestamptz,timestamptz,uuid,text
) is 'Authorized staff wrapper for versioned factual official Team/publication relationships. It creates no fan follow or News-feed eligibility.';
comment on function private.record_news_official_team_publication_canonical(
  uuid,uuid,uuid,text,timestamptz,timestamptz,text,uuid,uuid,text
) is 'Shared canonical official Team/publication relationship mutation with staff or future automation provenance and independent factual/history time.';

commit;
