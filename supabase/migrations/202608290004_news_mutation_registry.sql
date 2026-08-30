-- Phase 4 entry hardening: every News-domain table is mechanically registered
-- as writable only through a governed canonical operation or read-only by
-- design. This migration deliberately creates no table; BL-027 must be closed
-- before the first Phase 4 News table is added.

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
  select *
  from (values
    ('public', 'catalog_people', 'governed', array['public.admin_review_news_identity_case(uuid,text,uuid,jsonb,text)'], 'Created only by governed identity Resolution.'),
    ('public', 'person_identity_versions', 'governed', array['public.admin_review_news_identity_case(uuid,text,uuid,jsonb,text)'], 'Versioned by governed identity Resolution.'),
    ('public', 'person_alias_versions', 'read_only', array[]::text[], 'No Phase 1-4 alias mutation is approved; BL-026 gates any future write path.'),
    ('public', 'person_identifiers', 'read_only', array[]::text[], 'No Phase 1-4 identifier mutation is approved; BL-026 gates any future write path.'),
    ('public', 'news_author_profiles', 'governed', array['public.admin_review_news_identity_case(uuid,text,uuid,jsonb,text)'], 'Author roles are created only by governed identity Resolution.'),
    ('public', 'news_organizational_contributors', 'governed', array['public.admin_review_news_identity_case(uuid,text,uuid,jsonb,text)'], 'Created only by governed identity Resolution.'),
    ('public', 'news_organizational_contributor_versions', 'governed', array['public.admin_review_news_identity_case(uuid,text,uuid,jsonb,text)'], 'Versioned only by governed identity Resolution.'),
    ('public', 'news_organizational_contributor_alias_versions', 'read_only', array[]::text[], 'No Phase 1-4 alias mutation is approved; BL-026 gates any future write path.'),
    ('public', 'news_organizational_contributor_identifiers', 'read_only', array[]::text[], 'No Phase 1-4 identifier mutation is approved; BL-026 gates any future write path.'),
    ('public', 'podcast_shows', 'governed', array['public.admin_review_news_identity_case(uuid,text,uuid,jsonb,text)'], 'Created only by governed identity Resolution.'),
    ('public', 'podcast_show_identity_versions', 'governed', array['public.admin_review_news_identity_case(uuid,text,uuid,jsonb,text)'], 'Versioned only by governed identity Resolution.'),
    ('public', 'podcast_show_alias_versions', 'read_only', array[]::text[], 'No Phase 1-4 alias mutation is approved; BL-026 gates any future write path.'),
    ('public', 'podcast_show_identifiers', 'read_only', array[]::text[], 'No Phase 1-4 identifier mutation is approved; BL-026 gates any future write path.'),
    ('public', 'news_publisher_policy_versions', 'read_only', array[]::text[], 'Publisher News policy has no approved Phase 1-4 mutation; BL-026 gates any future path and it is never feed eligibility.'),
    ('public', 'news_publisher_contributor_profiles', 'governed', array['public.admin_create_news_publisher_contributor_profile(uuid,text)'], 'Created through the governed contributor-profile intake path.'),
    ('public', 'news_publisher_contributor_profile_versions', 'governed', array['public.admin_create_news_publisher_contributor_profile(uuid,text)','public.admin_review_news_identity_case(uuid,text,uuid,jsonb,text)'], 'Created and corrected through governed identity operations.'),
    ('public', 'news_person_publisher_relationship_versions', 'governed', array['public.admin_review_news_identity_case(uuid,text,uuid,jsonb,text)'], 'Affiliations are versioned through governed review.'),
    ('public', 'podcast_show_contributor_versions', 'governed', array['public.admin_record_podcast_show_contributor(uuid,uuid,text,timestamp with time zone,timestamp with time zone,uuid,text)'], 'Show contributor relationships use the governed staff wrapper.'),
    ('public', 'podcast_show_publisher_relationship_versions', 'governed', array['public.admin_record_podcast_show_publisher(uuid,uuid,text,timestamp with time zone,timestamp with time zone,uuid,text)'], 'Show publisher relationships use the governed staff wrapper.'),
    ('public', 'news_official_team_publication_versions', 'governed', array['public.admin_record_news_official_team_publication(uuid,uuid,text,timestamp with time zone,timestamp with time zone,uuid,text)'], 'Official Team/publication relationships use the governed canonical path.'),
    ('public', 'news_identity_resolution_cases', 'governed', array['public.admin_open_news_identity_case(text,text,text,uuid,uuid,uuid,uuid,uuid,text,text,text,jsonb,text)'], 'Cases are opened through the governed intake wrapper.'),
    ('public', 'news_identity_resolution_candidates', 'governed', array['public.admin_record_news_identity_candidate(uuid,text,text,uuid,text,jsonb,text)'], 'Candidates are appended through the governed intake wrapper.'),
    ('public', 'news_identity_resolution_evidence', 'governed', array['public.admin_record_news_identity_evidence(uuid,uuid,text,uuid,text,uuid,uuid,text,boolean,text,jsonb,timestamp with time zone,text)'], 'Evidence is appended through the governed intake wrapper.'),
    ('public', 'news_identity_resolution_decisions', 'governed', array['public.admin_review_news_identity_case(uuid,text,uuid,jsonb,text)'], 'Decisions are appended through governed review and automatic Resolution.'),
    ('public', 'news_identity_decision_evidence', 'governed', array['public.admin_review_news_identity_case(uuid,text,uuid,jsonb,text)'], 'Evidence snapshots are created only with governed decisions.'),
    ('public', 'news_person_pair_state_periods', 'governed', array['public.admin_review_news_identity_case(uuid,text,uuid,jsonb,text)'], 'Person merge state changes only through governed Resolution.'),
    ('public', 'news_identity_evidence_kinds', 'read_only', array[]::text[], 'Migration-seeded controlled vocabulary.'),
    ('public', 'news_identity_resolution_rules', 'read_only', array[]::text[], 'Migration-seeded controlled vocabulary.'),
    ('public', 'news_person_publisher_relationship_types', 'read_only', array[]::text[], 'Migration-seeded controlled vocabulary.'),
    ('public', 'news_show_contributor_roles', 'read_only', array[]::text[], 'Migration-seeded controlled vocabulary.'),
    ('public', 'news_show_publisher_relationship_types', 'read_only', array[]::text[], 'Migration-seeded controlled vocabulary.'),
    ('public', 'news_content_evidence_kinds', 'read_only', array[]::text[], 'Migration-seeded controlled vocabulary.'),
    ('public', 'news_content_review_case_types', 'read_only', array[]::text[], 'Migration-seeded controlled vocabulary.'),
    ('public', 'news_content_decisions', 'governed', array['public.admin_create_news_item(text,text,text,text,timestamp with time zone,uuid,uuid,uuid,text,text)'], 'Every content operation records a governed decision.'),
    ('public', 'news_content_evidence', 'governed', array['public.admin_record_news_content_evidence(text,text,uuid,text,timestamp with time zone,text)'], 'Evidence is appended through the governed evidence path.'),
    ('public', 'news_content_decision_evidence', 'governed', array['public.admin_create_news_item(text,text,text,text,timestamp with time zone,uuid,uuid,uuid,text,text)'], 'Links are written only as part of governed content operations.'),
    ('public', 'news_items', 'governed', array['public.admin_create_news_item(text,text,text,text,timestamp with time zone,uuid,uuid,uuid,text,text)'], 'Stable Items are created through the governed content path.'),
    ('public', 'news_item_versions', 'governed', array['public.admin_create_news_item(text,text,text,text,timestamp with time zone,uuid,uuid,uuid,text,text)','public.admin_record_news_item_version(uuid,text,text,text,timestamp with time zone,uuid,uuid,text)'], 'Item facts are versioned through governed content operations.'),
    ('public', 'news_podcast_episodes', 'governed', array['public.admin_create_news_item(text,text,text,text,timestamp with time zone,uuid,uuid,uuid,text,text)'], 'Podcast subtype rows are created atomically with governed Items.'),
    ('public', 'news_manifestations', 'governed', array['public.admin_create_news_manifestation(uuid,text,timestamp with time zone,text,uuid,text)'], 'Manifestations use the governed content path.'),
    ('public', 'news_manifestation_urls', 'governed', array['public.admin_add_news_manifestation_url(uuid,text,text,boolean,uuid,text)'], 'URLs use the governed content path.'),
    ('public', 'news_manifestation_assignment_versions', 'governed', array['public.admin_assign_news_manifestation(uuid,uuid,uuid,text)'], 'Assignments are versioned through the governed content path.'),
    ('public', 'news_representative_destination_versions', 'governed', array['public.admin_set_news_representative_destination(uuid,uuid,uuid,text)'], 'Destinations are versioned through the governed content path and its validation trigger.'),
    ('public', 'news_byline_mentions', 'governed', array['public.admin_record_news_byline(uuid,integer,text,text,uuid,text)'], 'Historical raw attribution is appended through the governed byline path.'),
    ('public', 'news_byline_resolution_versions', 'governed', array['public.admin_resolve_news_byline(uuid,text,uuid,text,uuid,text)'], 'Byline identity links are versioned through governed Resolution.'),
    ('public', 'news_item_classifications', 'governed', array['public.admin_record_news_classification(uuid,uuid,text,uuid,uuid,text)'], 'Stable classification identities are created by the governed path.'),
    ('public', 'news_item_classification_versions', 'governed', array['public.admin_record_news_classification(uuid,uuid,text,uuid,uuid,text)'], 'Classification facts are versioned through the governed path.'),
    ('public', 'news_deduplication_cases', 'governed', array['public.admin_record_news_deduplication(uuid,uuid,text,uuid,text,text,uuid,uuid)'], 'Dedupe cases use the governed content path.'),
    ('public', 'news_deduplication_decision_versions', 'governed', array['public.admin_record_news_deduplication(uuid,uuid,text,uuid,text,text,uuid,uuid)'], 'Dedupe decisions are versioned through the governed content path.'),
    ('public', 'news_remote_preview_references', 'governed', array['public.admin_record_news_remote_preview(uuid,text,text,text,text,uuid,text)'], 'Preview references use the governed content path.'),
    ('public', 'news_remote_preview_policy_versions', 'governed', array['public.admin_record_news_remote_preview(uuid,text,text,text,text,uuid,text)','public.admin_set_news_remote_preview_policy(uuid,text,uuid,text)'], 'Preview display policy is versioned through governed content paths.'),
    ('public', 'news_content_review_cases', 'governed', array['public.admin_open_news_content_review_case(text,uuid,uuid,text,jsonb,text)'], 'Typed review cases use the governed review path.'),
    ('public', 'news_content_review_decisions', 'governed', array['public.admin_review_news_content_case(uuid,text,jsonb,text)'], 'Review outcomes are appended through the governed review path.')
  ) registry(table_schema, table_name, mutation_mode, canonical_operations, rationale);
$$;

create or replace function private.assert_news_domain_mutation_registry()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  failure_detail text;
begin
  select string_agg(format('%I.%I', domain_table.table_schema, domain_table.table_name), ', ' order by domain_table.table_name)
  into failure_detail
  from (
    select namespace.nspname::text as table_schema, relation.relname::text as table_name
    from pg_catalog.pg_class relation
    join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relkind in ('r', 'p')
      and (
        relation.relname like 'news\_%' escape '\'
        or relation.relname like 'podcast\_%' escape '\'
        or relation.relname like 'user\_news\_%' escape '\'
        or relation.relname in (
          'catalog_people', 'person_identity_versions',
          'person_alias_versions', 'person_identifiers'
        )
      )
  ) domain_table
  left join private.news_domain_mutation_registry() registry
    on registry.table_schema = domain_table.table_schema
   and registry.table_name = domain_table.table_name
  where registry.table_name is null;
  if failure_detail is not null then
    raise exception 'Unregistered News-domain tables: %', failure_detail;
  end if;

  select string_agg(format('%I.%I', registry.table_schema, registry.table_name), ', ' order by registry.table_name)
  into failure_detail
  from private.news_domain_mutation_registry() registry
  where to_regclass(format('%I.%I', registry.table_schema, registry.table_name)) is null;
  if failure_detail is not null then
    raise exception 'News mutation registry references missing tables: %', failure_detail;
  end if;

  select string_agg(format('%I.%I', registry.table_schema, registry.table_name), ', ' order by registry.table_name)
  into failure_detail
  from private.news_domain_mutation_registry() registry
  where registry.mutation_mode not in ('governed', 'read_only')
     or length(btrim(registry.rationale)) = 0
     or (registry.mutation_mode = 'governed' and cardinality(registry.canonical_operations) = 0)
     or (registry.mutation_mode = 'read_only' and cardinality(registry.canonical_operations) <> 0);
  if failure_detail is not null then
    raise exception 'Invalid News mutation registry entries: %', failure_detail;
  end if;

  select string_agg(
    format('%I.%I -> %s', registry.table_schema, registry.table_name, operation.operation_name),
    ', ' order by registry.table_name, operation.operation_name
  )
  into failure_detail
  from private.news_domain_mutation_registry() registry
  cross join lateral unnest(registry.canonical_operations) operation(operation_name)
  where to_regprocedure(operation.operation_name) is null;
  if failure_detail is not null then
    raise exception 'News mutation registry references missing canonical operations: %', failure_detail;
  end if;
end;
$$;

revoke all on function private.news_domain_mutation_registry()
from public, anon, authenticated;
revoke all on function private.assert_news_domain_mutation_registry()
from public, anon, authenticated;

comment on function private.news_domain_mutation_registry() is
  'BL-027 registry: every mechanically selected News-domain table is governed by named canonical operations or explicitly read-only by design.';
comment on function private.assert_news_domain_mutation_registry() is
  'Fails when a News-domain table is unregistered, a registered table is missing, a mode is invalid, or a named governed operation does not exist.';

select private.assert_news_domain_mutation_registry();
