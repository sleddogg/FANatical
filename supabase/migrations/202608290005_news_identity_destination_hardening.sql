-- Phase 4 entry hardening for BL-023, subject-specific attribution review,
-- and public representative destinations. No fan-facing feed table or UI is
-- introduced here.

-- ---------------------------------------------------------------------------
-- A fan-safe single-person resolver. This does not reuse the staff-oriented
-- pair-state reader: callers provide one person and receive the current final
-- canonical person across any governed merge chain.
-- ---------------------------------------------------------------------------

create or replace function private.resolve_news_canonical_person(
  person_id_value uuid
)
returns uuid
language plpgsql
stable
strict
security definer
set search_path = ''
as $$
declare
  current_person_uuid uuid := person_id_value;
  next_person_uuid uuid;
  next_person_count integer;
  visited_person_ids uuid[] := array[]::uuid[];
begin
  if current_person_uuid is null or not exists (
    select 1 from public.catalog_people where id = current_person_uuid
  ) then
    raise exception 'News person identity does not exist';
  end if;

  loop
    if current_person_uuid = any(visited_person_ids) then
      raise exception 'Current News person merges contain a cycle';
    end if;
    visited_person_ids := array_append(visited_person_ids, current_person_uuid);

    select
      count(distinct period.canonical_person_id),
      min(period.canonical_person_id::text)::uuid
    into next_person_count, next_person_uuid
    from public.news_person_pair_state_periods period
    where period.is_current
      and period.state = 'merged'
      and current_person_uuid in (period.person_a_id, period.person_b_id)
      and period.canonical_person_id <> current_person_uuid;

    if next_person_count = 0 then
      return current_person_uuid;
    end if;
    if next_person_count > 1 then
      raise exception 'Current News person merges have conflicting canonical identities';
    end if;
    current_person_uuid := next_person_uuid;
  end loop;
end;
$$;

-- Fan-serving readers use a deliberately non-diagnostic boundary so one
-- malformed legacy component cannot abort a complete feed or Following read.
-- The canonical resolver above remains strict and raising for staff diagnosis.
create or replace function private.try_resolve_news_canonical_person(
  person_id_value uuid
)
returns uuid
language plpgsql
stable
strict
security definer
set search_path = ''
as $$
begin
  return private.resolve_news_canonical_person(person_id_value);
exception
  when others then
    return null;
end;
$$;

create or replace function private.current_news_person_merge_decisions(
  person_id_value uuid
)
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  with recursive component(person_id, visited) as (
    select person_id_value, array[person_id_value]::uuid[]
    union all
    select
      case
        when period.person_a_id = component.person_id then period.person_b_id
        else period.person_a_id
      end,
      component.visited || case
        when period.person_a_id = component.person_id then period.person_b_id
        else period.person_a_id
      end
    from component
    join public.news_person_pair_state_periods period
      on period.is_current
     and period.state = 'merged'
     and component.person_id in (period.person_a_id, period.person_b_id)
    where not (
      case
        when period.person_a_id = component.person_id then period.person_b_id
        else period.person_a_id
      end = any(component.visited)
    )
  ), decision_ids as (
    select distinct period.opened_by_decision_id
    from component
    join public.news_person_pair_state_periods period
      on period.is_current
     and period.state = 'merged'
     and component.person_id in (period.person_a_id, period.person_b_id)
  )
  select coalesce(array_agg(opened_by_decision_id order by opened_by_decision_id), array[]::uuid[])
  from decision_ids;
$$;

create or replace function public.resolve_news_canonical_person(
  person_id_value uuid
)
returns uuid
language sql
stable
strict
security definer
set search_path = ''
as $$
  select private.resolve_news_canonical_person(person_id_value);
$$;

revoke all on function private.resolve_news_canonical_person(uuid)
from public, anon, authenticated;
revoke all on function private.try_resolve_news_canonical_person(uuid)
from public, anon, authenticated;
revoke all on function private.current_news_person_merge_decisions(uuid)
from public, anon, authenticated;
revoke all on function public.resolve_news_canonical_person(uuid)
from public;
grant execute on function public.resolve_news_canonical_person(uuid)
to anon, authenticated;

comment on function public.resolve_news_canonical_person(uuid) is
  'Fan-safe single-person resolver. Returns the current final canonical person across governed merge chains without exposing pair-state history.';
comment on function private.try_resolve_news_canonical_person(uuid) is
  'Internal fan-serving boundary. Returns NULL instead of aborting the surrounding read when a malformed legacy merge component cannot be resolved; staff diagnostics use the raising canonical resolver.';

-- ---------------------------------------------------------------------------
-- Attribution review is structurally tied to one byline and one disputed
-- person, organizational contributor, or Show. Existing non-attribution cases
-- remain unchanged.
-- ---------------------------------------------------------------------------

alter table public.news_content_review_cases
  add column subject_byline_mention_id uuid
    references public.news_byline_mentions(id),
  add column subject_identity_type text
    check (subject_identity_type in ('person', 'organization', 'show')),
  add column subject_person_id uuid references public.catalog_people(id),
  add column subject_organizational_contributor_id uuid
    references public.news_organizational_contributors(id),
  add column subject_show_id uuid references public.podcast_shows(id);

create index news_content_review_attribution_subject_idx
on public.news_content_review_cases(
  status,
  subject_byline_mention_id,
  subject_identity_type,
  subject_person_id,
  subject_organizational_contributor_id,
  subject_show_id
)
where case_type = 'attribution';

create or replace function public.validate_news_attribution_review_subject()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  resolved_person_uuid uuid;
  resolved_organization_uuid uuid;
  resolved_show_uuid uuid;
begin
  if new.case_type <> 'attribution' then
    if num_nonnulls(
      new.subject_byline_mention_id,
      new.subject_identity_type,
      new.subject_person_id,
      new.subject_organizational_contributor_id,
      new.subject_show_id
    ) <> 0 then
      raise exception 'Only attribution review may carry a disputed identity subject';
    end if;
    return new;
  end if;

  if new.subject_byline_mention_id is null
     or new.subject_identity_type is null
     or num_nonnulls(
       new.subject_person_id,
       new.subject_organizational_contributor_id,
       new.subject_show_id
     ) <> 1
     or (new.subject_identity_type = 'person' and new.subject_person_id is null)
     or (
       new.subject_identity_type = 'organization'
       and new.subject_organizational_contributor_id is null
     )
     or (new.subject_identity_type = 'show' and new.subject_show_id is null) then
    raise exception 'Attribution review requires one structured byline identity subject';
  end if;

  select
    coalesce(resolution.person_id, profile_version.person_id),
    coalesce(
      resolution.organizational_contributor_id,
      profile_version.organizational_contributor_id
    ),
    resolution.show_id
  into resolved_person_uuid, resolved_organization_uuid, resolved_show_uuid
  from public.news_byline_mentions mention
  join public.news_byline_resolution_versions resolution
    on resolution.byline_mention_id = mention.id
   and resolution.is_current
  left join public.news_publisher_contributor_profile_versions profile_version
    on profile_version.contributor_profile_id = resolution.contributor_profile_id
   and profile_version.is_current
  where mention.id = new.subject_byline_mention_id
    and mention.manifestation_id = new.manifestation_id;

  if not found then
    raise exception 'Attribution review subject must be a current resolved byline on the selected manifestation';
  end if;
  if new.subject_identity_type = 'person'
     and resolved_person_uuid is distinct from new.subject_person_id then
    raise exception 'Attribution review person does not match the current byline Resolution';
  end if;
  if new.subject_identity_type = 'organization'
     and resolved_organization_uuid is distinct from new.subject_organizational_contributor_id then
    raise exception 'Attribution review organization does not match the current byline Resolution';
  end if;
  if new.subject_identity_type = 'show'
     and resolved_show_uuid is distinct from new.subject_show_id then
    raise exception 'Attribution review Show does not match the current byline Resolution';
  end if;

  if new.news_item_id is not null and not exists (
    select 1
    from public.news_manifestation_assignment_versions assignment
    where assignment.manifestation_id = new.manifestation_id
      and assignment.news_item_id = new.news_item_id
      and assignment.is_current
  ) then
    raise exception 'Attribution review manifestation must be currently assigned to its News Item';
  end if;
  return new;
end;
$$;

create trigger validate_news_attribution_review_subject_on_insert
before insert on public.news_content_review_cases
for each row execute function public.validate_news_attribution_review_subject();

create or replace function public.admin_open_news_attribution_review_case(
  news_item_id_value uuid,
  manifestation_id_value uuid,
  byline_mention_id_value uuid,
  subject_identity_type_value text,
  subject_identity_id_value uuid,
  unresolved_question_value text,
  context_value jsonb default '{}'::jsonb,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  decision_uuid uuid;
  review_case_uuid uuid := gen_random_uuid();
  publisher_source_uuid uuid;
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  if news_item_id_value is null or manifestation_id_value is null
     or byline_mention_id_value is null or subject_identity_id_value is null then
    raise exception 'Attribution review requires an Item, manifestation, byline, and identity';
  end if;
  if subject_identity_type_value not in ('person', 'organization', 'show') then
    raise exception 'Unsupported attribution review identity type';
  end if;
  select publisher_source_id into strict publisher_source_uuid
  from public.news_manifestations where id = manifestation_id_value;

  decision_uuid := private.record_news_content_decision(
    'open_content_review', 'staff', auth.uid(), public.current_catalog_actor_id(),
    publisher_source_uuid, notes_value
  );
  insert into public.news_content_review_cases(
    id, case_type, news_item_id, manifestation_id,
    subject_byline_mention_id, subject_identity_type,
    subject_person_id, subject_organizational_contributor_id, subject_show_id,
    unresolved_question, context, opened_by_decision_id
  ) values (
    review_case_uuid, 'attribution', news_item_id_value,
    manifestation_id_value, byline_mention_id_value,
    subject_identity_type_value,
    case when subject_identity_type_value = 'person' then subject_identity_id_value end,
    case when subject_identity_type_value = 'organization' then subject_identity_id_value end,
    case when subject_identity_type_value = 'show' then subject_identity_id_value end,
    unresolved_question_value, coalesce(context_value, '{}'::jsonb), decision_uuid
  );
  return review_case_uuid;
end;
$$;

revoke all on function public.admin_open_news_attribution_review_case(
  uuid,uuid,uuid,text,uuid,text,jsonb,text
) from public, anon;
grant execute on function public.admin_open_news_attribution_review_case(
  uuid,uuid,uuid,text,uuid,text,jsonb,text
) to authenticated;
revoke all on function public.validate_news_attribution_review_subject()
from public, anon, authenticated;

comment on function public.admin_open_news_attribution_review_case(
  uuid,uuid,uuid,text,uuid,text,jsonb,text
) is
  'Opens an attribution review tied structurally to one resolved byline identity; fan reads expose neither the case nor its details.';

-- ---------------------------------------------------------------------------
-- Public representative destinations may be canonical or explicit alternate
-- publisher URLs. Redirects and tracking wrappers remain evidence/history but
-- can never be selected for a fan-facing open.
-- ---------------------------------------------------------------------------

alter table public.news_manifestation_urls
  add constraint news_manifestation_public_destination_kind_check
  check (
    not is_public_destination
    or url_kind in ('canonical', 'alternate')
  ) not valid;

create or replace function public.validate_news_representative_destination()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.news_manifestation_urls destination
    where destination.id = new.manifestation_url_id
      and destination.manifestation_id = new.manifestation_id
      and destination.is_public_destination
      and destination.url_kind in ('canonical', 'alternate')
  ) then
    raise exception 'Representative destination must be a canonical or alternate public URL on the selected manifestation';
  end if;
  if not exists (
    select 1
    from public.news_manifestation_assignment_versions assignment
    where assignment.manifestation_id = new.manifestation_id
      and assignment.news_item_id = new.news_item_id
      and assignment.is_current
  ) then
    raise exception 'Representative destination manifestation must be currently assigned to the News Item';
  end if;
  return new;
end;
$$;

select private.assert_news_domain_mutation_registry();
