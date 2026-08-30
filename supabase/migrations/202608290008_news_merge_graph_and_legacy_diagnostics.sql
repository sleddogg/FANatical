-- Phase 4 correction: keep current person-merge graphs resolvable under every
-- governed automatic and staff-reviewed write, and inventory legacy public
-- destinations preserved by the earlier NOT VALID constraint.

create or replace function private.set_news_person_pair_state(
  person_one_id uuid,
  person_two_id uuid,
  state_value text,
  canonical_person_id_value uuid,
  decision_id_value uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  person_a uuid;
  person_b uuid;
  transition_at timestamptz;
  result_id uuid;
  proposed_edge_would_cycle boolean;
  existing_canonical_count integer;
  existing_canonical_person_id uuid;
begin
  if person_one_id is null or person_two_id is null or person_one_id = person_two_id then
    raise exception 'A person pair requires two different identities';
  end if;
  if state_value not in ('distinct', 'ambiguous', 'merged') then
    raise exception 'Unsupported person-pair state';
  end if;
  if state_value = 'merged'
     and canonical_person_id_value not in (person_one_id, person_two_id) then
    raise exception 'Merged person pair requires one participating canonical identity';
  end if;
  if state_value <> 'merged' and canonical_person_id_value is not null then
    raise exception 'Only a merged person pair has one canonical identity';
  end if;

  if person_one_id::text < person_two_id::text then
    person_a := person_one_id;
    person_b := person_two_id;
  else
    person_a := person_two_id;
    person_b := person_one_id;
  end if;

  -- Every pair-state transition takes the same transaction-scoped lock. This
  -- serializes governed merge/split graph checks with their writes, preventing
  -- concurrent transactions from both validating against a stale graph.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'private.set_news_person_pair_state.current-merge-graph',
      0
    )
  );
  perform 1
  from public.catalog_people
  where id in (person_a, person_b)
  order by id
  for update;

  if state_value = 'merged' then
    -- Replacing the same current pair is not a new edge. Excluding it lets a
    -- governed correction replace that pair while still testing every other
    -- live edge in the affected component.
    with recursive component(person_id) as (
      select person_a
      union
      select case
        when period.person_a_id = component.person_id then period.person_b_id
        else period.person_a_id
      end
      from component
      join public.news_person_pair_state_periods period
        on period.is_current
       and period.state = 'merged'
       and component.person_id in (period.person_a_id, period.person_b_id)
       and not (
         period.person_a_id = person_a
         and period.person_b_id = person_b
       )
    )
    select exists (
      select 1 from component where component.person_id = person_b
    )
    into proposed_edge_would_cycle;

    if proposed_edge_would_cycle then
      raise exception 'Current News person merge would create a cycle';
    end if;

    with recursive affected_person(person_id) as (
      select seed.person_id
      from (values (person_a), (person_b)) seed(person_id)
      union
      select case
        when period.person_a_id = affected_person.person_id then period.person_b_id
        else period.person_a_id
      end
      from affected_person
      join public.news_person_pair_state_periods period
        on period.is_current
       and period.state = 'merged'
       and affected_person.person_id in (period.person_a_id, period.person_b_id)
       and not (
         period.person_a_id = person_a
         and period.person_b_id = person_b
       )
    ), affected_canonical as (
      select distinct period.canonical_person_id
      from public.news_person_pair_state_periods period
      where period.is_current
        and period.state = 'merged'
        and not (
          period.person_a_id = person_a
          and period.person_b_id = person_b
        )
        and exists (
          select 1
          from affected_person
          where affected_person.person_id in (
            period.person_a_id,
            period.person_b_id
          )
        )
    )
    select
      count(*),
      min(affected_canonical.canonical_person_id::text)::uuid
    into existing_canonical_count, existing_canonical_person_id
    from affected_canonical;

    if existing_canonical_count > 1
       or (
         existing_canonical_count = 1
         and existing_canonical_person_id <> canonical_person_id_value
       ) then
      raise exception 'Current News person merge graph already has a different canonical identity';
    end if;
  end if;

  transition_at := clock_timestamp();

  update public.news_person_pair_state_periods
  set is_current = false,
      effective_to = transition_at,
      superseded_at = transition_at,
      closed_by_decision_id = decision_id_value
  where person_a_id = person_a and person_b_id = person_b and is_current;

  insert into public.news_person_pair_state_periods(
    person_a_id, person_b_id, state, canonical_person_id,
    effective_from, opened_by_decision_id
  ) values (
    person_a, person_b, state_value, canonical_person_id_value,
    transition_at, decision_id_value
  ) returning id into result_id;

  return result_id;
end;
$$;

comment on function private.set_news_person_pair_state(uuid,uuid,text,uuid,uuid) is
  'Shared automatic/manual pair-state writer. Serializes graph transitions and rejects conflicting canonical targets or cyclic current merge edges before changing any period.';

create or replace view private.news_manifestation_public_destination_kind_violations
with (security_invoker = false)
as
select
  destination.id,
  destination.manifestation_url_id,
  destination.manifestation_id,
  destination.url_kind,
  destination.url,
  destination.normalized_url,
  destination.is_public_destination,
  destination.created_at
from public.news_manifestation_urls destination
where destination.is_public_destination
  and destination.url_kind not in ('canonical', 'alternate');

revoke all on private.news_manifestation_public_destination_kind_violations
from public, anon, authenticated;
grant usage on schema private to service_role;
grant select on private.news_manifestation_public_destination_kind_violations
to service_role;

comment on constraint news_manifestation_public_destination_kind_check
on public.news_manifestation_urls is
  'NOT VALID preserves legacy rows for explicit review. New or updated public destinations must be canonical or alternate URLs.';

comment on view private.news_manifestation_public_destination_kind_violations is
  'Service-only, owner-evaluated inventory of legacy wrapper or redirect URLs still marked as public destinations. The narrow view avoids granting diagnostic callers broad access to the protected News URL table; rows require explicit review before later constraint validation.';
