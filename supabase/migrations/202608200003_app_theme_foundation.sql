-- Establish the first verified team-color palette consumed by FANatical's
-- reusable app theme. This preserves the existing candidate, evidence,
-- decision, version, and audit conventions instead of creating a UI-only fact.

do $$
declare
  migration_actor_id uuid;
  oilers_team_id uuid;
  policy_id_value uuid;
  proposal_id_value uuid;
  decision_id_value uuid;
  official_source_id uuid;
  corroborating_source_id uuid;
  policy_snapshot_value jsonb;
  evidence_snapshot_value jsonb;
begin
  insert into public.catalog_actors(actor_key, actor_type, display_name, active)
  values ('theme-foundation-migration', 'service', 'FANatical Theme Foundation Migration', true)
  on conflict (actor_key) do update set display_name = excluded.display_name, active = true
  returning id into migration_actor_id;

  select id into strict oilers_team_id
  from public.catalog_teams
  where team_id = 'hockey-000027';

  select id, to_jsonb(policy)
  into strict policy_id_value, policy_snapshot_value
  from public.verification_policies policy
  where data_type = 'team_colors' and is_current and active;

  insert into public.source_independence_groups(group_id, display_name, notes)
  values
    ('edmonton-oilers-hockey-club', 'Edmonton Oilers Hockey Club', 'Official club-controlled brand material.'),
    ('brand-color-code', 'BrandColorCode', 'Independent brand-color reference publisher.')
  on conflict (group_id) do update set display_name = excluded.display_name, notes = excluded.notes;

  insert into public.trusted_sources(
    source_id, display_name, base_url, reference_url, independence_group_id,
    review_status, notes, metadata
  )
  select
    'edmonton-oilers-brand-book', 'Official Edmonton Oilers Brand Book',
    'https://www.nhl.com/oilers',
    'https://cloud.edmontonoilers.com/brand-hub/Edmonton-Oilers-Brand-Book.pdf',
    independence.id, 'approved',
    'Primary source for the Oilers logo technical information and official RGB values.',
    jsonb_build_object(
      'ownership_review', jsonb_build_object(
        'notes', 'Club-controlled source reviewed for the verified Oilers palette.',
        'reviewed_at', '2026-08-20T00:00:00Z',
        'reviewed_by_actor_id', migration_actor_id
      )
    )
  from public.source_independence_groups independence
  where independence.group_id = 'edmonton-oilers-hockey-club'
  on conflict (source_id) do update set
    display_name = excluded.display_name,
    base_url = excluded.base_url,
    reference_url = excluded.reference_url,
    independence_group_id = excluded.independence_group_id,
    review_status = excluded.review_status,
    notes = excluded.notes,
    metadata = public.trusted_sources.metadata || excluded.metadata
  returning id into official_source_id;

  insert into public.trusted_sources(
    source_id, display_name, base_url, reference_url, independence_group_id,
    review_status, notes, metadata
  )
  select
    'brand-color-code-edmonton-oilers', 'BrandColorCode - Edmonton Oilers',
    'https://www.brandcolorcode.com',
    'https://www.brandcolorcode.com/edmonton-oilers',
    independence.id, 'approved',
    'Independent corroboration of the Oilers hex and RGB palette.',
    jsonb_build_object(
      'ownership_review', jsonb_build_object(
        'notes', 'Independent publisher ownership reviewed for team-color corroboration.',
        'reviewed_at', '2026-08-20T00:00:00Z',
        'reviewed_by_actor_id', migration_actor_id
      )
    )
  from public.source_independence_groups independence
  where independence.group_id = 'brand-color-code'
  on conflict (source_id) do update set
    display_name = excluded.display_name,
    base_url = excluded.base_url,
    reference_url = excluded.reference_url,
    independence_group_id = excluded.independence_group_id,
    review_status = excluded.review_status,
    notes = excluded.notes,
    metadata = public.trusted_sources.metadata || excluded.metadata
  returning id into corroborating_source_id;

  update public.source_trust_assignments
  set is_current = false, effective_to = date '2026-08-20', superseded_at = now()
  where source_id in (official_source_id, corroborating_source_id)
    and data_type = 'team_colors' and is_current;

  insert into public.source_trust_assignments(source_id, data_type, trust_tier, effective_from, notes)
  values
    (official_source_id, 'team_colors', 1, date '2026-08-20', 'Official club brand book.'),
    (corroborating_source_id, 'team_colors', 3, date '2026-08-20', 'Independent corroborating brand-color reference.');

  insert into public.catalog_audit_events(actor_id, action, entity_type, entity_id, details)
  values
    (
      migration_actor_id, 'source.registry_reviewed', 'trusted_source',
      'edmonton-oilers-brand-book',
      jsonb_build_object('review_status', 'approved', 'independence_group', 'edmonton-oilers-hockey-club')
    ),
    (
      migration_actor_id, 'source.registry_reviewed', 'trusted_source',
      'brand-color-code-edmonton-oilers',
      jsonb_build_object('review_status', 'approved', 'independence_group', 'brand-color-code')
    ),
    (
      migration_actor_id, 'source.trust_assigned', 'trusted_source',
      'edmonton-oilers-brand-book',
      jsonb_build_object('data_type', 'team_colors', 'trust_tier', 1)
    ),
    (
      migration_actor_id, 'source.trust_assigned', 'trusted_source',
      'brand-color-code-edmonton-oilers',
      jsonb_build_object('data_type', 'team_colors', 'trust_tier', 3)
    );

  insert into public.catalog_change_proposals(
    fact_type, operation, target_team_id, payload, status,
    proposed_by_actor_id, submitted_at
  ) values (
    'team_colors', 'replace', oilers_team_id,
    jsonb_build_object(
      'primary', '#00205B',
      'secondary', '#D14520',
      'tertiary', '#FFFFFF',
      'quaternary', '',
      'quinary', '',
      'effective_from', '2024-03-11',
      'effective_from_precision', 'day'
    ),
    'pending', migration_actor_id, '2026-08-20T00:00:00Z'
  ) returning id into proposal_id_value;

  insert into public.catalog_proposal_evidence(
    proposal_id, source_id, evidence_url, evidence_summary, observed_at,
    supports_proposal, submitted_by_actor_id
  ) values
    (
      proposal_id_value, official_source_id,
      'https://cloud.edmontonoilers.com/brand-hub/Edmonton-Oilers-Brand-Book.pdf',
      'Logo Technical Information lists Oilers Blue as RGB 0,32,91 and Oilers Orange as RGB 209,69,32; these convert to #00205B and #D14520. White is retained as the third official palette color.',
      '2026-08-20T00:00:00Z', true, migration_actor_id
    ),
    (
      proposal_id_value, corroborating_source_id,
      'https://www.brandcolorcode.com/edmonton-oilers',
      'Independently lists #00205B / RGB 0,32,91, #D14520 / RGB 209,69,32, and #FFFFFF / RGB 255,255,255.',
      '2026-08-20T00:00:00Z', true, migration_actor_id
    );

  select coalesce(jsonb_agg(jsonb_build_object(
    'source_id', source.source_id,
    'independence_group', independence.group_id,
    'trust_tier', trust.trust_tier,
    'evidence_url', evidence.evidence_url,
    'supports_proposal', evidence.supports_proposal
  ) order by source.source_id), '[]'::jsonb)
  into evidence_snapshot_value
  from public.catalog_proposal_evidence evidence
  join public.trusted_sources source on source.id = evidence.source_id
  join public.source_independence_groups independence on independence.id = source.independence_group_id
  join public.source_trust_assignments trust
    on trust.source_id = source.id and trust.data_type = 'team_colors' and trust.is_current
  where evidence.proposal_id = proposal_id_value;

  insert into public.catalog_verification_decisions(
    proposal_id, decision, policy_id, decided_by_actor_id,
    policy_snapshot, evidence_snapshot, notes, decided_at
  ) values (
    proposal_id_value, 'approved', policy_id_value, migration_actor_id,
    policy_snapshot_value, evidence_snapshot_value,
    'Approved from the official Edmonton Oilers Brand Book and independent BrandColorCode corroboration.',
    '2026-08-20T00:00:00Z'
  ) returning id into decision_id_value;

  update public.team_color_versions
  set is_current = false,
      effective_to = case
        when effective_from is null or effective_from <= date '2024-03-10' then date '2024-03-10'
        else effective_from
      end,
      superseded_at = now()
  where team_id = oilers_team_id and is_current;

  insert into public.team_color_versions(
    team_id, primary_color, secondary_color, tertiary_color,
    quaternary_color, quinary_color, effective_from,
    effective_from_precision, is_current, record_status,
    verification_decision_id
  ) values (
    oilers_team_id, '#00205B', '#D14520', '#FFFFFF',
    null, null, date '2024-03-11', 'day', true, 'verified',
    decision_id_value
  );

  update public.catalog_change_proposals
  set status = 'approved', resolved_at = '2026-08-20T00:00:00Z',
      resolution_notes = 'Promoted by the app theme foundation migration after two-source verification.'
  where id = proposal_id_value;

  insert into public.catalog_audit_events(
    actor_id, action, entity_type, entity_id, proposal_id, details
  ) values (
    migration_actor_id, 'proposal.approved_and_promoted', 'team_colors',
    oilers_team_id::text, proposal_id_value,
    jsonb_build_object(
      'decision_id', decision_id_value,
      'primary', '#00205B',
      'secondary', '#D14520',
      'tertiary', '#FFFFFF'
    )
  );
end;
$$;
