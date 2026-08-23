-- Final pre-launch Trusted Source hardening.
--
-- Evidence already stores exact governance versions. This migration makes the
-- database revalidate those versions at insertion and approval time, and gives
-- source reviewers a read-only overlap queue for equivalent-publisher review.

create or replace function public.enforce_governed_catalog_evidence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  proposal_record public.catalog_change_proposals%rowtype;
  source_uuid uuid;
  scope_source_uuid uuid;
  trust_source_uuid uuid;
  ownership_source_uuid uuid;
  canonical_scope_source uuid;
begin
  if new.source_url_scope_version_id is null
     or new.source_trust_assignment_id is null
     or new.source_independence_assignment_id is null then
    raise exception 'New catalog evidence requires exact URL-scope, trust, and independence provenance';
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
  select scope.source_id, public.canonical_trusted_source_id(scope.source_id)
    into strict scope_source_uuid, canonical_scope_source
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
  select trust.source_id into strict trust_source_uuid
  from public.source_trust_assignments trust
  where trust.id = new.source_trust_assignment_id
    and trust.is_current
    and (trust.effective_from is null or trust.effective_from <= current_date)
    and (trust.effective_to is null or trust.effective_to >= current_date);
  if trust_source_uuid <> source_uuid then
    raise exception 'Evidence trust assignment does not belong to the selected publisher';
  end if;
  if proposal_record.target_team_id is not null and
     public.applicable_source_trust_assignment(
       source_uuid, proposal_record.fact_type, proposal_record.target_team_id
     ) <> new.source_trust_assignment_id then
    raise exception 'Evidence trust assignment is not the narrowest current applicability for the target';
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
  join public.source_independence_group_assignment_versions ownership
    on ownership.id = evidence.source_independence_assignment_id
   and ownership.is_current and ownership.review_status = 'approved'
  where evidence.proposal_id = proposal_record.id
    and evidence.supports_proposal
    and evidence.structured_claim ->> 'classification' = 'current_canonical'
    and evidence.structured_claim -> 'palette' =
        public.team_color_palette_from_payload(proposal_record.payload)
    and trust.trust_tier = any(policy_record.allowed_trust_tiers)
    and trust.id = public.applicable_source_trust_assignment(
      source.id, 'team_colors', proposal_record.target_team_id
    )
    and exists (
      select 1 from public.trusted_source_url_matches(evidence.evidence_url) match
      where match.url_scope_version_id = scope.id
        and match.canonical_source_id = source.id
    )
    and ownership.source_id = source.id
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

drop trigger if exists enforce_current_team_color_evidence_decision
on public.catalog_verification_decisions;
create trigger enforce_current_team_color_evidence_decision
before insert on public.catalog_verification_decisions
for each row execute function public.enforce_current_team_color_evidence_decision();

create or replace view public.trusted_source_duplicate_candidates_read_model
with (security_invoker = true)
as
with url_overlaps as (
  select least(left_source.id,right_source.id) as left_id,
         greatest(left_source.id,right_source.id) as right_id,
         'url_scope_overlap'::text as reason,
         left_scope.id as left_scope_version_id,
         right_scope.id as right_scope_version_id
  from public.trusted_source_url_scope_versions left_scope
  join public.trusted_sources left_source on left_source.id = left_scope.source_id
  join public.trusted_source_url_scope_versions right_scope
    on right_scope.id > left_scope.id and right_scope.is_current
  join public.trusted_sources right_source
    on right_source.id = right_scope.source_id and right_source.id <> left_source.id
  where left_scope.is_current
    and left_source.superseded_by_source_id is null
    and right_source.superseded_by_source_id is null
    and (
      left_scope.hostname = right_scope.hostname
      or (left_scope.include_subdomains and right(right_scope.hostname, length(left_scope.hostname) + 1) = '.' || left_scope.hostname)
      or (right_scope.include_subdomains and right(left_scope.hostname, length(right_scope.hostname) + 1) = '.' || right_scope.hostname)
    )
    and (
      left_scope.path_prefix = '/'
      or right_scope.path_prefix = '/'
      or left_scope.path_prefix = right_scope.path_prefix
      or left(right_scope.path_prefix, length(left_scope.path_prefix) + 1) = left_scope.path_prefix || '/'
      or left(left_scope.path_prefix, length(right_scope.path_prefix) + 1) = right_scope.path_prefix || '/'
    )
), name_overlaps as (
  select least(left_source.id,right_source.id) as left_id,
         greatest(left_source.id,right_source.id) as right_id,
         'normalized_publisher_name'::text as reason,
         null::uuid as left_scope_version_id,
         null::uuid as right_scope_version_id
  from public.trusted_sources left_source
  join public.trusted_sources right_source on right_source.id > left_source.id
  where left_source.superseded_by_source_id is null
    and right_source.superseded_by_source_id is null
    and lower(regexp_replace(btrim(left_source.display_name), '\s+', ' ', 'g')) =
        lower(regexp_replace(btrim(right_source.display_name), '\s+', ' ', 'g'))
), candidates as (
  select * from url_overlaps
  union all
  select * from name_overlaps
)
select left_source.source_id as left_source_id,
       left_source.display_name as left_display_name,
       left_source.review_status as left_review_status,
       right_source.source_id as right_source_id,
       right_source.display_name as right_display_name,
       right_source.review_status as right_review_status,
       candidate.reason,
       candidate.left_scope_version_id,
       candidate.right_scope_version_id
from candidates candidate
join public.trusted_sources left_source on left_source.id = candidate.left_id
join public.trusted_sources right_source on right_source.id = candidate.right_id;

grant select on public.trusted_source_duplicate_candidates_read_model to authenticated;
revoke all on function public.enforce_current_team_color_evidence_decision()
  from public, anon, authenticated;
revoke all on function public.enforce_governed_catalog_evidence()
  from public, anon, authenticated;

comment on view public.trusted_source_duplicate_candidates_read_model is
  'Reviewer-only overlap detector. A row is a review candidate, never automatic proof that two publishers should be merged.';
comment on function public.enforce_current_team_color_evidence_decision() is
  'Revalidates exact URL ownership, trust applicability, and independence versions when a Team Color proposal is approved.';
