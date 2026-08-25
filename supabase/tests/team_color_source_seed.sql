begin;

create or replace function pg_temp.assert_true(condition boolean, message text)
returns void language plpgsql as $$
begin
  if not coalesce(condition, false) then
    raise exception 'Team Color source seed assertion failed: %', message;
  end if;
end;
$$;

do $$
declare
  seed_import_key constant text := 'team-color-source-reference-2026-08-24';
begin
  perform pg_temp.assert_true(exists (
    select 1 from public.catalog_import_batches batch
    where batch.import_key = seed_import_key
      and batch.source_filename = 'FANatical_Team_Color_Source_Seed_Reference.xlsx'
      and batch.source_sha256 = 'b6ed74f865db6b6921f5c574b37902238b0b6ce9d13386ea9fa42792372e6901'
      and batch.source_kind = 'source_reference'
      and not batch.verified_source_data
      and batch.record_counts = jsonb_build_object(
        'broad_tier_2_sources',3,
        'canonical_sources',116,
        'league_mappings',125,
        'legacy_source_redirects',123,
        'official_tier_1_sources',113,
        'url_scopes',199
      )
  ), 'workbook provenance and complete counts must be durable');

  perform pg_temp.assert_true((
    select count(*) = 116
       and count(*) filter (
         where source.metadata #>> '{team_color_source_seed,source_class}'
           = 'Official Tier 1'
       ) = 113
       and count(*) filter (
         where source.metadata #>> '{team_color_source_seed,source_class}'
           = 'Broad Tier 2'
       ) = 3
       and bool_and(source.review_status = 'approved')
       and bool_and(source.superseded_by_source_id is null)
    from public.trusted_sources source
    where source.metadata #>> '{team_color_source_seed,import_key}' = seed_import_key
  ), 'all 113 official and 3 broad canonical identities must be approved and current');

  perform pg_temp.assert_true((
    select count(*) = 116
       and count(distinct grouping.id) = 116
       and bool_and(assignment.review_status = 'approved')
    from public.trusted_sources source
    join public.source_independence_group_assignment_versions assignment
      on assignment.source_id = source.id and assignment.is_current
    join public.source_independence_groups grouping
      on grouping.id = assignment.independence_group_id
     and grouping.id = source.independence_group_id
    where source.metadata #>> '{team_color_source_seed,import_key}' = seed_import_key
      and grouping.group_id = source.source_id
  ), 'every canonical source must have its supplied independent ownership group');

  perform pg_temp.assert_true((
    select count(*) = 116
       and count(*) filter (where trust.trust_tier = 1) = 113
       and count(*) filter (where trust.trust_tier = 2) = 3
    from public.trusted_sources source
    join public.source_trust_assignments trust
      on trust.source_id = source.id and trust.data_type = 'team_colors'
     and trust.is_current
    where source.metadata #>> '{team_color_source_seed,import_key}' = seed_import_key
  ), 'Team Color governance tiers must contain 113 Tier 1 and 3 Tier 2 sources');

  perform pg_temp.assert_true((
    select count(*) = 128
       and count(*) filter (
         where applicability.applicability_kind = 'league'
       ) = 125
       and count(*) filter (
         where applicability.applicability_kind = 'global'
       ) = 3
       and count(distinct applicability.league_id) filter (
         where applicability.applicability_kind = 'league'
       ) = 125
       and bool_and(applicability.review_status = 'approved')
    from public.trusted_sources source
    join public.source_applicability_versions applicability
      on applicability.source_id = source.id
     and applicability.data_type = 'team_colors'
     and applicability.is_current
    where source.metadata #>> '{team_color_source_seed,import_key}' = seed_import_key
  ), 'all 125 active leagues and 3 broad sources must have exact applicability');

  perform pg_temp.assert_true(not exists (
    select 1 from public.catalog_leagues league
    where league.active and not exists (
      select 1
      from public.source_applicability_versions applicability
      join public.trusted_sources source on source.id = applicability.source_id
      where applicability.data_type = 'team_colors'
        and applicability.is_current
        and applicability.review_status = 'approved'
        and applicability.applicability_kind = 'league'
        and applicability.league_id = league.id
        and source.metadata #>> '{team_color_source_seed,source_class}'
          = 'Official Tier 1'
    )
  ), 'every active catalog league must match an official workbook source mapping');

  perform pg_temp.assert_true((
    select count(*) = 199
    from public.trusted_source_url_scope_versions scope
    join public.trusted_sources source on source.id = scope.source_id
    where source.metadata #>> '{team_color_source_seed,import_key}' = seed_import_key
      and scope.is_current and scope.review_status = 'approved'
      and scope.review_notes like 'Team Color source seed%'
  ), 'all canonical base and mapped-reference URL scopes must be present once');

  perform pg_temp.assert_true(not exists (
    select 1
    from public.trusted_sources source
    cross join lateral (
      select max(match.specificity) best_specificity
      from public.trusted_source_url_matches(source.reference_url) match
    ) best
    where source.metadata #>> '{team_color_source_seed,import_key}' = seed_import_key
      and (
        best.best_specificity is null
        or (
          select count(distinct match.canonical_source_id)
          from public.trusted_source_url_matches(source.reference_url) match
          where match.specificity = best.best_specificity
        ) <> 1
        or not exists (
          select 1 from public.trusted_source_url_matches(source.reference_url) match
          where match.specificity = best.best_specificity
            and match.canonical_source_id = source.id
        )
      )
  ), 'each representative URL must resolve unambiguously to its canonical source');

  perform pg_temp.assert_true((
    select count(*) = 123
    from public.trusted_source_redirects redirect
    join public.trusted_sources legacy on legacy.id = redirect.source_id
    join public.catalog_import_batches batch on batch.id = legacy.import_batch_id
    join public.trusted_sources canonical on canonical.id = redirect.canonical_source_id
    where batch.import_key = 'master-teams-complete-2026-08-19'
      and redirect.reason like 'Canonicalized by the authoritative Team Color source workbook%'
      and canonical.metadata #>> '{team_color_source_seed,import_key}' = seed_import_key
      and legacy.review_status = 'retired'
  ), 'older page-level source candidates must preserve history through 123 canonical redirects');

  perform pg_temp.assert_true((
    select count(*) = 116
       and bool_and(enrollment.qualification_status = 'probationary')
       and bool_and(enrollment.assessed_case_count = 0)
       and bool_and(enrollment.match_count = 0)
       and bool_and(enrollment.contradiction_count = 0)
       and bool_and(enrollment.raw_match_rate is null)
       and bool_and(enrollment.latest_evaluation_id is null)
    from public.trusted_sources source
    join public.source_qualification_enrollments enrollment
      on enrollment.source_id = source.id and enrollment.data_type = 'team_colors'
    where source.metadata #>> '{team_color_source_seed,import_key}' = seed_import_key
  ), 'governance Tier 1/2 must leave every seeded source empirically probationary and unrated');

  perform pg_temp.assert_true(not exists (
    select 1 from public.source_qualification_observations observation
    join public.trusted_sources source on source.id = observation.tested_source_id
    where source.metadata #>> '{team_color_source_seed,import_key}' = seed_import_key
  ) and not exists (
    select 1 from public.source_qualification_evaluations evaluation
    join public.source_qualification_enrollments enrollment
      on enrollment.id = evaluation.enrollment_id
    join public.trusted_sources source on source.id = enrollment.source_id
    where source.metadata #>> '{team_color_source_seed,import_key}' = seed_import_key
  ), 'the source seed must create no qualification observations, ratings, or decisions');

  perform pg_temp.assert_true(not exists (
    select 1 from public.team_color_versions version
    join public.catalog_import_batches batch on batch.id = version.import_batch_id
    where batch.import_key = seed_import_key
  ), 'the source seed must not create Team Color facts');

  perform pg_temp.assert_true(exists (
    select 1
    from public.trusted_sources source
    join public.source_applicability_versions applicability
      on applicability.source_id = source.id
     and applicability.data_type = 'team_colors'
     and applicability.is_current
    join public.catalog_leagues league on league.id = applicability.league_id
    where source.source_id = 'official-hockey-khl'
      and league.league_id = 'hockey-khl'
      and source.metadata ->> 'automated_access'
        = 'Do not automatically extract without official KHL permission.'
      and applicability.notes like '%Official permission required for automated extraction%'
      and applicability.notes like '%do not automate extraction without KHL permission%'
  ), 'KHL must remain registered while preserving the automated-access warning');

  perform pg_temp.assert_true(not exists (
    select 1
    from public.information_lineage_versions version
    where version.provenance ->> 'seed_import_key' = seed_import_key
  ), 'the source seed must not invent information lineages');
end;
$$;

rollback;
