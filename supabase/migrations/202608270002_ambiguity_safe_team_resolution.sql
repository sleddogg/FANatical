-- Bring Team identifier resolution in line with the canonical Competition
-- resolver: preserve every distinct candidate and never choose an arbitrary
-- Team when a bare external identifier exists in more than one namespace.

create or replace function public.resolve_catalog_team(
  identifier_value text
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with candidates as (
    select team.id as team_uuid, 1 as match_rank,
           'team_id'::text as match_basis
    from public.catalog_teams team
    where team.team_id = identifier_value

    union all

    select external_id.team_id, 2, 'external_identifier'
    from public.catalog_team_identifiers external_id
    where external_id.identifier = identifier_value
  ),
  scoped as (
    select distinct on (candidate.team_uuid)
           candidate.team_uuid, candidate.match_rank,
           candidate.match_basis
    from candidates candidate
    order by candidate.team_uuid, candidate.match_rank,
             candidate.match_basis
  ),
  best_rank as (
    select min(match_rank) as match_rank from scoped
  ),
  matches as (
    select team.id, team.team_id, sport.sport_id,
           identity_record.display_name, scoped.match_basis
    from scoped
    join best_rank on best_rank.match_rank = scoped.match_rank
    join public.catalog_teams team on team.id = scoped.team_uuid
    join public.catalog_sports sport on sport.id = team.sport_id
    left join public.team_identity_versions identity_record
      on identity_record.team_id = team.id
     and identity_record.is_current
    order by team.team_id
  ),
  aggregate_result as (
    select count(*) as match_count,
           coalesce(jsonb_agg(jsonb_build_object(
             'id', id,
             'team_id', team_id,
             'sport_id', sport_id,
             'display_name', display_name,
             'match_basis', match_basis
           ) order by team_id), '[]'::jsonb) as matches
    from matches
  )
  select jsonb_build_object(
    'status', case match_count
      when 0 then 'none'
      when 1 then 'resolved'
      else 'ambiguous'
    end,
    'matches', matches
  )
  from aggregate_result;
$$;

create or replace function public.resolve_catalog_team_id(
  identifier_value text
)
returns uuid
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare result jsonb;
begin
  result := public.resolve_catalog_team(identifier_value);
  if result ->> 'status' = 'ambiguous' then
    raise exception 'Ambiguous Team identifier: %', identifier_value;
  end if;
  if result ->> 'status' = 'resolved' then
    return (result #>> '{matches,0,id}')::uuid;
  end if;
  return null;
end;
$$;

grant execute on function public.resolve_catalog_team(text)
to anon, authenticated;
grant execute on function public.resolve_catalog_team_id(text)
to anon, authenticated;

comment on function public.resolve_catalog_team(text) is
  'Resolves canonical Team IDs and bare external identifiers while returning every ambiguous Team candidate instead of guessing.';
comment on function public.resolve_catalog_team_id(text) is
  'Strict Team resolver: returns one unambiguous Team UUID, null for no match, and raises when a bare external identifier is ambiguous.';
