-- FANatical News Phase 2: durable people, organizational contributors,
-- podcast Shows, publisher-specific profiles, identity Resolution, and the
-- staff review boundary. This migration deliberately creates no News Items,
-- monitoring endpoints, fan follows, or feed behavior.

begin;

-- ---------------------------------------------------------------------------
-- Governed vocabularies. Resolution evaluates these rows, not hard-coded
-- confidence scores or evidence-count thresholds.
-- ---------------------------------------------------------------------------

create table public.news_identity_evidence_kinds (
  evidence_kind text primary key
    check (evidence_kind ~ '^[a-z0-9]+(?:_[a-z0-9]+)*$'),
  display_name text not null check (length(btrim(display_name)) > 0),
  evidence_class text not null check (evidence_class in ('explicit', 'supporting')),
  subject_types text[] not null check (
    subject_types <@ array['human','organization','show','publisher_profile','affiliation','person_merge']::text[]
    and cardinality(subject_types) > 0
  ),
  can_bridge_person_identities boolean not null default false,
  active boolean not null default true,
  description text not null,
  created_at timestamptz not null default now()
);

insert into public.news_identity_evidence_kinds(
  evidence_kind, display_name, evidence_class, subject_types,
  can_bridge_person_identities, description
)
values
  ('publisher_author_profile', 'Official publisher Author profile', 'explicit', array['human','publisher_profile','affiliation'], false, 'A public Author/profile page controlled by the publisher.'),
  ('publisher_masthead', 'Publisher masthead or directory', 'explicit', array['human','organization','affiliation'], false, 'A public publisher masthead or contributor directory.'),
  ('visible_byline_profile', 'Visible byline linked to public profile', 'explicit', array['human','publisher_profile'], false, 'A visible byline linked to a genuine public contributor profile.'),
  ('official_organizational_profile', 'Official organizational identity', 'explicit', array['organization','publisher_profile'], false, 'An official public identity for a newsroom, staff desk, wire organization, or Team newsroom.'),
  ('official_show_profile', 'Official Show page, feed, or profile', 'explicit', array['show'], false, 'A public first-party page, feed, or profile establishing a podcast Show.'),
  ('first_party_cross_publisher_bridge', 'Explicit first-party identity bridge', 'explicit', array['human','person_merge'], true, 'Public first-party evidence explicitly connecting the same person across identities or publishers.'),
  ('name_match', 'Name match', 'supporting', array['human','organization','show','publisher_profile','person_merge'], false, 'Matching name text is a clue only and never merges identities.'),
  ('hidden_metadata', 'Hidden publisher metadata', 'supporting', array['human','organization','show','publisher_profile','affiliation','person_merge'], false, 'Machine metadata is supporting evidence and never overrides contradictory visible public attribution.');

create table public.news_identity_resolution_rules (
  rule_key text primary key check (rule_key ~ '^[a-z0-9]+(?:_[a-z0-9]+)*$'),
  display_name text not null,
  active boolean not null default true,
  rule_definition jsonb not null,
  created_at timestamptz not null default now()
);

insert into public.news_identity_resolution_rules(rule_key, display_name, rule_definition)
values
  (
    'explicit_public_non_conflicting',
    'Explicit public non-conflicting identity evidence',
    '{"requires_explicit":true,"requires_public_visibility":true,"allows_visible_conflict":false,"hidden_metadata_may_override_visible":false,"numeric_threshold":null}'::jsonb
  ),
  (
    'explicit_public_identity_bridge',
    'Explicit public non-conflicting person bridge',
    '{"requires_explicit":true,"requires_public_visibility":true,"requires_identity_bridge":true,"allows_visible_conflict":false,"numeric_threshold":null}'::jsonb
  );

create table public.news_person_publisher_relationship_types (
  relationship_type text primary key,
  display_name text not null,
  active boolean not null default true
);

insert into public.news_person_publisher_relationship_types(relationship_type, display_name)
values
  ('employee', 'Employee'),
  ('freelance', 'Freelance'),
  ('contract', 'Contract'),
  ('guest', 'Guest'),
  ('columnist', 'Columnist'),
  ('contributor', 'Contributor'),
  ('unknown', 'Unknown');

create table public.news_show_contributor_roles (
  contributor_role text primary key,
  display_name text not null,
  active boolean not null default true
);

insert into public.news_show_contributor_roles(contributor_role, display_name)
values ('host', 'Host'), ('contributor', 'Contributor'), ('unknown', 'Unknown');

create table public.news_show_publisher_relationship_types (
  relationship_type text primary key,
  display_name text not null,
  active boolean not null default true
);

insert into public.news_show_publisher_relationship_types(relationship_type, display_name)
values ('network', 'Network'), ('publisher', 'Publisher'), ('unknown', 'Unknown');

-- ---------------------------------------------------------------------------
-- Stable identity populations and mutable public facts.
-- catalog_people is intentionally independent from Auth profiles/fans and
-- operational catalog_actors. A future explicit bridge can be additive.
-- ---------------------------------------------------------------------------

create table public.catalog_people (
  id uuid primary key default gen_random_uuid(),
  person_id text not null unique default (
    'person-' || replace(gen_random_uuid()::text, '-', '')
  ) check (person_id ~ '^person-[0-9a-f]{32}$'),
  created_at timestamptz not null default now()
);

create table public.person_identity_versions (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.catalog_people(id),
  public_name text not null check (length(btrim(public_name)) > 0),
  normalized_name text generated always as (
    lower(regexp_replace(btrim(public_name), '\s+', ' ', 'g'))
  ) stored,
  name_kind text not null default 'professional_name'
    check (name_kind in ('professional_name', 'pen_name')),
  active boolean not null default true,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  is_current boolean not null default true,
  resolution_decision_id uuid,
  superseded_at timestamptz,
  closed_by_decision_id uuid,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

create unique index person_identity_current_idx
on public.person_identity_versions(person_id) where is_current;
create index person_identity_name_lookup_idx
on public.person_identity_versions(normalized_name) where is_current;

create table public.person_alias_versions (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.catalog_people(id),
  alias text not null check (length(btrim(alias)) > 0),
  normalized_alias text generated always as (
    lower(regexp_replace(btrim(alias), '\s+', ' ', 'g'))
  ) stored,
  alias_kind text not null default 'name_variant'
    check (alias_kind in ('name_variant', 'former_professional_name', 'pen_name', 'other')),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  is_current boolean not null default true,
  resolution_decision_id uuid,
  superseded_at timestamptz,
  closed_by_decision_id uuid,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

create index person_alias_lookup_idx
on public.person_alias_versions(normalized_alias) where is_current;
create unique index person_alias_current_idx
on public.person_alias_versions(person_id, normalized_alias, alias_kind) where is_current;

create table public.person_identifiers (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.catalog_people(id),
  namespace text not null check (length(btrim(namespace)) > 0),
  identifier text not null check (length(btrim(identifier)) > 0),
  created_at timestamptz not null default now(),
  unique (namespace, identifier),
  unique (person_id, namespace, identifier)
);

create table public.news_author_profiles (
  id uuid primary key default gen_random_uuid(),
  author_id text not null unique default (
    'author-' || replace(gen_random_uuid()::text, '-', '')
  ) check (author_id ~ '^author-[0-9a-f]{32}$'),
  person_id uuid not null unique references public.catalog_people(id),
  created_by_resolution_decision_id uuid,
  created_at timestamptz not null default now()
);

comment on table public.news_author_profiles is
  'News Author role attached to a persistent person. Presence here does not itself grant fan followability.';

create table public.news_organizational_contributors (
  id uuid primary key default gen_random_uuid(),
  contributor_id text not null unique default (
    'organization-' || replace(gen_random_uuid()::text, '-', '')
  ) check (contributor_id ~ '^organization-[0-9a-f]{32}$'),
  created_at timestamptz not null default now()
);

create table public.news_organizational_contributor_versions (
  id uuid primary key default gen_random_uuid(),
  organizational_contributor_id uuid not null references public.news_organizational_contributors(id),
  display_name text not null check (length(btrim(display_name)) > 0),
  normalized_name text generated always as (
    lower(regexp_replace(btrim(display_name), '\s+', ' ', 'g'))
  ) stored,
  active boolean not null default true,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  is_current boolean not null default true,
  resolution_decision_id uuid,
  superseded_at timestamptz,
  closed_by_decision_id uuid,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

create unique index news_org_identity_current_idx
on public.news_organizational_contributor_versions(organizational_contributor_id)
where is_current;
create index news_org_identity_name_lookup_idx
on public.news_organizational_contributor_versions(normalized_name) where is_current;

create table public.news_organizational_contributor_alias_versions (
  id uuid primary key default gen_random_uuid(),
  organizational_contributor_id uuid not null references public.news_organizational_contributors(id),
  alias text not null check (length(btrim(alias)) > 0),
  normalized_alias text generated always as (
    lower(regexp_replace(btrim(alias), '\s+', ' ', 'g'))
  ) stored,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  is_current boolean not null default true,
  resolution_decision_id uuid,
  superseded_at timestamptz,
  closed_by_decision_id uuid,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

create index news_org_alias_lookup_idx
on public.news_organizational_contributor_alias_versions(normalized_alias) where is_current;

create table public.news_organizational_contributor_identifiers (
  id uuid primary key default gen_random_uuid(),
  organizational_contributor_id uuid not null references public.news_organizational_contributors(id),
  namespace text not null check (length(btrim(namespace)) > 0),
  identifier text not null check (length(btrim(identifier)) > 0),
  created_at timestamptz not null default now(),
  unique (namespace, identifier),
  unique (organizational_contributor_id, namespace, identifier)
);

create table public.podcast_shows (
  id uuid primary key default gen_random_uuid(),
  show_id text not null unique default (
    'show-' || replace(gen_random_uuid()::text, '-', '')
  ) check (show_id ~ '^show-[0-9a-f]{32}$'),
  created_at timestamptz not null default now()
);

create table public.podcast_show_identity_versions (
  id uuid primary key default gen_random_uuid(),
  show_id uuid not null references public.podcast_shows(id),
  display_name text not null check (length(btrim(display_name)) > 0),
  normalized_name text generated always as (
    lower(regexp_replace(btrim(display_name), '\s+', ' ', 'g'))
  ) stored,
  active boolean not null default true,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  is_current boolean not null default true,
  resolution_decision_id uuid,
  superseded_at timestamptz,
  closed_by_decision_id uuid,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

create unique index podcast_show_identity_current_idx
on public.podcast_show_identity_versions(show_id) where is_current;
create index podcast_show_name_lookup_idx
on public.podcast_show_identity_versions(normalized_name) where is_current;

create table public.podcast_show_alias_versions (
  id uuid primary key default gen_random_uuid(),
  show_id uuid not null references public.podcast_shows(id),
  alias text not null check (length(btrim(alias)) > 0),
  normalized_alias text generated always as (
    lower(regexp_replace(btrim(alias), '\s+', ' ', 'g'))
  ) stored,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  is_current boolean not null default true,
  resolution_decision_id uuid,
  superseded_at timestamptz,
  closed_by_decision_id uuid,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

create index podcast_show_alias_lookup_idx
on public.podcast_show_alias_versions(normalized_alias) where is_current;

create table public.podcast_show_identifiers (
  id uuid primary key default gen_random_uuid(),
  show_id uuid not null references public.podcast_shows(id),
  namespace text not null check (length(btrim(namespace)) > 0),
  identifier text not null check (length(btrim(identifier)) > 0),
  created_at timestamptz not null default now(),
  unique (namespace, identifier),
  unique (show_id, namespace, identifier)
);

-- Publisher identity is reused through trusted_sources. This News policy is
-- deliberately separate and receives no backfill from review_status, trust,
-- applicability, ownership, or empirical reliability.
create table public.news_publisher_policy_versions (
  id uuid primary key default gen_random_uuid(),
  publisher_source_id uuid not null references public.trusted_sources(id),
  news_status text not null check (news_status in (
    'pending_review', 'available', 'suspended', 'retired'
  )),
  notes text,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  is_current boolean not null default true,
  resolution_decision_id uuid,
  superseded_at timestamptz,
  closed_by_decision_id uuid,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to >= effective_from)
);

create unique index news_publisher_policy_current_idx
on public.news_publisher_policy_versions(publisher_source_id) where is_current;

create table public.news_publisher_contributor_profiles (
  id uuid primary key default gen_random_uuid(),
  contributor_profile_id text not null unique default (
    'contributor-profile-' || replace(gen_random_uuid()::text, '-', '')
  ) check (contributor_profile_id ~ '^contributor-profile-[0-9a-f]{32}$'),
  publisher_source_id uuid not null references public.trusted_sources(id),
  created_at timestamptz not null default now()
);

create table public.news_publisher_contributor_profile_versions (
  id uuid primary key default gen_random_uuid(),
  contributor_profile_id uuid not null references public.news_publisher_contributor_profiles(id),
  display_name text not null check (length(btrim(display_name)) > 0),
  profile_url text check (profile_url is null or profile_url ~* '^https://[^[:space:]]+$'),
  person_id uuid references public.catalog_people(id),
  organizational_contributor_id uuid references public.news_organizational_contributors(id),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  is_current boolean not null default true,
  resolution_decision_id uuid,
  superseded_at timestamptz,
  closed_by_decision_id uuid,
  created_at timestamptz not null default now(),
  check (num_nonnulls(person_id, organizational_contributor_id) = 1),
  check (effective_to is null or effective_to >= effective_from)
);

create unique index news_contributor_profile_current_idx
on public.news_publisher_contributor_profile_versions(contributor_profile_id)
where is_current;

-- ---------------------------------------------------------------------------
-- Historical factual relationships.
-- ---------------------------------------------------------------------------

create table public.news_person_publisher_relationship_versions (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references public.catalog_people(id),
  publisher_source_id uuid not null references public.trusted_sources(id),
  relationship_type text not null references public.news_person_publisher_relationship_types(relationship_type),
  effective_from timestamptz,
  effective_to timestamptz,
  is_current boolean not null default true,
  resolution_decision_id uuid,
  superseded_at timestamptz,
  closed_by_decision_id uuid,
  notes text,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create unique index news_person_publisher_current_idx
on public.news_person_publisher_relationship_versions(
  person_id, publisher_source_id, relationship_type
) where is_current;

create table public.podcast_show_contributor_versions (
  id uuid primary key default gen_random_uuid(),
  show_id uuid not null references public.podcast_shows(id),
  person_id uuid not null references public.catalog_people(id),
  contributor_role text not null references public.news_show_contributor_roles(contributor_role),
  effective_from timestamptz,
  effective_to timestamptz,
  is_current boolean not null default true,
  resolution_decision_id uuid,
  superseded_at timestamptz,
  closed_by_decision_id uuid,
  notes text,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create unique index podcast_show_contributor_current_idx
on public.podcast_show_contributor_versions(show_id, person_id, contributor_role)
where is_current;

create table public.podcast_show_publisher_relationship_versions (
  id uuid primary key default gen_random_uuid(),
  show_id uuid not null references public.podcast_shows(id),
  publisher_source_id uuid not null references public.trusted_sources(id),
  relationship_type text not null references public.news_show_publisher_relationship_types(relationship_type),
  effective_from timestamptz,
  effective_to timestamptz,
  is_current boolean not null default true,
  resolution_decision_id uuid,
  superseded_at timestamptz,
  closed_by_decision_id uuid,
  notes text,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create unique index podcast_show_publisher_current_idx
on public.podcast_show_publisher_relationship_versions(
  show_id, publisher_source_id, relationship_type
) where is_current;

create table public.news_official_team_publication_versions (
  id uuid primary key default gen_random_uuid(),
  publisher_source_id uuid not null references public.trusted_sources(id),
  team_id uuid not null references public.catalog_teams(id),
  organizational_contributor_id uuid references public.news_organizational_contributors(id),
  relationship_type text not null check (relationship_type in (
    'official_publication', 'official_newsroom', 'official_team_site'
  )),
  effective_from timestamptz,
  effective_to timestamptz,
  is_current boolean not null default true,
  resolution_decision_id uuid,
  superseded_at timestamptz,
  closed_by_decision_id uuid,
  notes text,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_from is null or effective_to >= effective_from)
);

create unique index news_official_team_publication_current_idx
on public.news_official_team_publication_versions(
  publisher_source_id,
  team_id,
  coalesce(organizational_contributor_id, '00000000-0000-0000-0000-000000000000'::uuid),
  relationship_type
) where is_current;

-- ---------------------------------------------------------------------------
-- Identity Resolution cases, candidates, evidence, and immutable decisions.
-- ---------------------------------------------------------------------------

create table public.news_identity_resolution_cases (
  id uuid primary key default gen_random_uuid(),
  case_id text not null unique default (
    'news-identity-case-' || replace(gen_random_uuid()::text, '-', '')
  ) check (case_id ~ '^news-identity-case-[0-9a-f]{32}$'),
  case_kind text not null check (case_kind in (
    'identity', 'publisher_profile', 'affiliation', 'person_merge'
  )),
  proposed_identity_type text check (proposed_identity_type in (
    'human', 'organization', 'show', 'unknown'
  )),
  proposed_name text check (proposed_name is null or length(btrim(proposed_name)) > 0),
  normalized_proposed_name text generated always as (
    lower(regexp_replace(btrim(coalesce(proposed_name, '')), '\s+', ' ', 'g'))
  ) stored,
  publisher_source_id uuid references public.trusted_sources(id),
  subject_person_id uuid references public.catalog_people(id),
  subject_organizational_contributor_id uuid references public.news_organizational_contributors(id),
  subject_show_id uuid references public.podcast_shows(id),
  subject_contributor_profile_id uuid references public.news_publisher_contributor_profiles(id),
  raw_byline text,
  profile_url text check (profile_url is null or profile_url ~* '^https://[^[:space:]]+$'),
  unresolved_question text not null check (length(btrim(unresolved_question)) > 0),
  status text not null default 'open' check (status in (
    'open', 'needs_review', 'resolved_automatic', 'resolved_manual',
    'not_identity', 'insufficient_evidence', 'reopened'
  )),
  automatic_resolution_result text,
  resolution_stop_reason text,
  context jsonb not null default '{}'::jsonb,
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (num_nonnulls(
    subject_person_id,
    subject_organizational_contributor_id,
    subject_show_id,
    subject_contributor_profile_id
  ) <= 1),
  check (case_kind <> 'person_merge' or subject_person_id is not null)
);

create index news_identity_cases_queue_idx
on public.news_identity_resolution_cases(status, created_at);
create index news_identity_cases_name_idx
on public.news_identity_resolution_cases(normalized_proposed_name, status);

create table public.news_identity_resolution_candidates (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.news_identity_resolution_cases(id),
  candidate_kind text not null check (candidate_kind in (
    'existing_identity', 'proposed_identity', 'publisher_profile_link',
    'affiliation', 'merge_target'
  )),
  identity_type text not null check (identity_type in (
    'human', 'organization', 'show', 'publisher_profile'
  )),
  person_id uuid references public.catalog_people(id),
  organizational_contributor_id uuid references public.news_organizational_contributors(id),
  show_id uuid references public.podcast_shows(id),
  contributor_profile_id uuid references public.news_publisher_contributor_profiles(id),
  display_name text not null check (length(btrim(display_name)) > 0),
  normalized_name text generated always as (
    lower(regexp_replace(btrim(display_name), '\s+', ' ', 'g'))
  ) stored,
  proposed_facts jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (num_nonnulls(
    person_id, organizational_contributor_id, show_id, contributor_profile_id
  ) <= 1),
  check (
    candidate_kind = 'proposed_identity'
    or num_nonnulls(person_id, organizational_contributor_id, show_id, contributor_profile_id) = 1
  ),
  check (
    (identity_type = 'human' and person_id is not null)
    or (identity_type = 'organization' and organizational_contributor_id is not null)
    or (identity_type = 'show' and show_id is not null)
    or (identity_type = 'publisher_profile' and contributor_profile_id is not null)
    or candidate_kind = 'proposed_identity'
  )
);

create index news_identity_candidates_case_idx
on public.news_identity_resolution_candidates(case_id, created_at);

create table public.news_identity_resolution_evidence (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.news_identity_resolution_cases(id),
  candidate_id uuid references public.news_identity_resolution_candidates(id),
  evidence_kind text not null references public.news_identity_evidence_kinds(evidence_kind),
  publisher_source_id uuid references public.trusted_sources(id),
  evidence_url text check (evidence_url is null or evidence_url ~* '^https://[^[:space:]]+$'),
  source_url_scope_version_id uuid
    references public.trusted_source_url_scope_versions(id),
  bridge_from_publisher_source_id uuid references public.trusted_sources(id),
  bridge_to_publisher_source_id uuid references public.trusted_sources(id),
  visibility text not null check (visibility in (
    'visible_public', 'public_profile', 'hidden_metadata'
  )),
  is_conflicting boolean not null default false,
  evidence_summary text not null check (length(btrim(evidence_summary)) > 0),
  observed_payload jsonb not null default '{}'::jsonb,
  observed_at timestamptz,
  recorded_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  check (
    num_nonnulls(
      bridge_from_publisher_source_id,
      bridge_to_publisher_source_id
    ) in (0, 2)
  ),
  check (
    bridge_from_publisher_source_id is null
    or bridge_from_publisher_source_id <> bridge_to_publisher_source_id
  )
);

create index news_identity_evidence_case_idx
on public.news_identity_resolution_evidence(case_id, created_at);

create table public.news_identity_resolution_decisions (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.news_identity_resolution_cases(id),
  action text not null check (action in (
    'automatic_link', 'automatic_merge', 'automatic_review_required',
    'confirm_create', 'link_existing', 'keep_separate',
    'establish_affiliation', 'correct_affiliation', 'merge',
    'reverse_merge', 'not_identity', 'insufficient_evidence', 'reopen'
  )),
  decision_origin text not null check (decision_origin in ('automatic', 'staff')),
  selected_candidate_id uuid references public.news_identity_resolution_candidates(id),
  result_identity_type text check (result_identity_type in (
    'human', 'organization', 'show', 'publisher_profile', 'affiliation', 'none'
  )),
  result_person_id uuid references public.catalog_people(id),
  result_organizational_contributor_id uuid references public.news_organizational_contributors(id),
  result_show_id uuid references public.podcast_shows(id),
  result_contributor_profile_id uuid references public.news_publisher_contributor_profiles(id),
  automatic_rule_key text references public.news_identity_resolution_rules(rule_key),
  stop_reason text,
  question_snapshot text not null,
  action_payload_snapshot jsonb not null default '{}'::jsonb,
  notes text,
  decided_by_user_id uuid references auth.users(id) on delete set null,
  supersedes_decision_id uuid references public.news_identity_resolution_decisions(id),
  decided_at timestamptz not null default clock_timestamp(),
  check (num_nonnulls(
    result_person_id,
    result_organizational_contributor_id,
    result_show_id,
    result_contributor_profile_id
  ) <= 1),
  check (
    decision_origin = 'staff'
    or (automatic_rule_key is not null and decided_by_user_id is null)
  )
);

create index news_identity_decisions_case_idx
on public.news_identity_resolution_decisions(case_id, decided_at, id);

create table public.news_identity_decision_evidence (
  decision_id uuid not null references public.news_identity_resolution_decisions(id),
  evidence_id uuid not null references public.news_identity_resolution_evidence(id),
  evidence_role text not null check (evidence_role in (
    'explicit', 'supporting', 'bridge', 'conflicting'
  )),
  primary key (decision_id, evidence_id)
);

create table public.news_person_pair_state_periods (
  id uuid primary key default gen_random_uuid(),
  person_a_id uuid not null references public.catalog_people(id),
  person_b_id uuid not null references public.catalog_people(id),
  state text not null check (state in ('distinct', 'ambiguous', 'merged')),
  canonical_person_id uuid references public.catalog_people(id),
  effective_from timestamptz not null,
  effective_to timestamptz,
  is_current boolean not null default true,
  opened_by_decision_id uuid not null references public.news_identity_resolution_decisions(id),
  closed_by_decision_id uuid references public.news_identity_resolution_decisions(id),
  superseded_at timestamptz,
  created_at timestamptz not null default now(),
  check (person_a_id::text < person_b_id::text),
  check (effective_to is null or effective_to >= effective_from),
  check (
    (state = 'merged' and canonical_person_id in (person_a_id, person_b_id))
    or (state in ('distinct', 'ambiguous') and canonical_person_id is null)
  )
);

create unique index news_person_pair_state_current_idx
on public.news_person_pair_state_periods(person_a_id, person_b_id) where is_current;
create index news_person_pair_state_history_idx
on public.news_person_pair_state_periods(person_a_id, person_b_id, effective_from, effective_to);

-- Decision foreign keys are added after the decision identity exists.
alter table public.person_identity_versions
  add constraint person_identity_resolution_decision_fk
  foreign key (resolution_decision_id) references public.news_identity_resolution_decisions(id),
  add constraint person_identity_closed_decision_fk
  foreign key (closed_by_decision_id) references public.news_identity_resolution_decisions(id);
alter table public.person_alias_versions
  add constraint person_alias_resolution_decision_fk
  foreign key (resolution_decision_id) references public.news_identity_resolution_decisions(id),
  add constraint person_alias_closed_decision_fk
  foreign key (closed_by_decision_id) references public.news_identity_resolution_decisions(id);
alter table public.news_author_profiles
  add constraint news_author_created_decision_fk
  foreign key (created_by_resolution_decision_id) references public.news_identity_resolution_decisions(id);
alter table public.news_organizational_contributor_versions
  add constraint news_org_resolution_decision_fk
  foreign key (resolution_decision_id) references public.news_identity_resolution_decisions(id),
  add constraint news_org_closed_decision_fk
  foreign key (closed_by_decision_id) references public.news_identity_resolution_decisions(id);
alter table public.news_organizational_contributor_alias_versions
  add constraint news_org_alias_resolution_decision_fk
  foreign key (resolution_decision_id) references public.news_identity_resolution_decisions(id),
  add constraint news_org_alias_closed_decision_fk
  foreign key (closed_by_decision_id) references public.news_identity_resolution_decisions(id);
alter table public.podcast_show_identity_versions
  add constraint podcast_show_identity_resolution_decision_fk
  foreign key (resolution_decision_id) references public.news_identity_resolution_decisions(id),
  add constraint podcast_show_identity_closed_decision_fk
  foreign key (closed_by_decision_id) references public.news_identity_resolution_decisions(id);
alter table public.podcast_show_alias_versions
  add constraint podcast_show_alias_resolution_decision_fk
  foreign key (resolution_decision_id) references public.news_identity_resolution_decisions(id),
  add constraint podcast_show_alias_closed_decision_fk
  foreign key (closed_by_decision_id) references public.news_identity_resolution_decisions(id);
alter table public.news_publisher_policy_versions
  add constraint news_publisher_policy_resolution_decision_fk
  foreign key (resolution_decision_id) references public.news_identity_resolution_decisions(id),
  add constraint news_publisher_policy_closed_decision_fk
  foreign key (closed_by_decision_id) references public.news_identity_resolution_decisions(id);
alter table public.news_publisher_contributor_profile_versions
  add constraint news_contributor_profile_resolution_decision_fk
  foreign key (resolution_decision_id) references public.news_identity_resolution_decisions(id),
  add constraint news_contributor_profile_closed_decision_fk
  foreign key (closed_by_decision_id) references public.news_identity_resolution_decisions(id);
alter table public.news_person_publisher_relationship_versions
  add constraint news_person_publisher_resolution_decision_fk
  foreign key (resolution_decision_id) references public.news_identity_resolution_decisions(id),
  add constraint news_person_publisher_closed_decision_fk
  foreign key (closed_by_decision_id) references public.news_identity_resolution_decisions(id);
alter table public.podcast_show_contributor_versions
  add constraint podcast_show_contributor_resolution_decision_fk
  foreign key (resolution_decision_id) references public.news_identity_resolution_decisions(id),
  add constraint podcast_show_contributor_closed_decision_fk
  foreign key (closed_by_decision_id) references public.news_identity_resolution_decisions(id);
alter table public.podcast_show_publisher_relationship_versions
  add constraint podcast_show_publisher_resolution_decision_fk
  foreign key (resolution_decision_id) references public.news_identity_resolution_decisions(id),
  add constraint podcast_show_publisher_closed_decision_fk
  foreign key (closed_by_decision_id) references public.news_identity_resolution_decisions(id);
alter table public.news_official_team_publication_versions
  add constraint news_official_team_resolution_decision_fk
  foreign key (resolution_decision_id) references public.news_identity_resolution_decisions(id),
  add constraint news_official_team_closed_decision_fk
  foreign key (closed_by_decision_id) references public.news_identity_resolution_decisions(id);

-- ---------------------------------------------------------------------------
-- History and identity protection.
-- ---------------------------------------------------------------------------

create or replace function public.protect_news_identity_history_row()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'News identity evidence, candidates, identifiers, and decisions are append-only';
end;
$$;

create or replace function public.protect_news_stable_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Persistent News identities cannot be deleted';
  end if;
  if old.id is distinct from new.id
     or (to_jsonb(old) ->> tg_argv[0]) is distinct from (to_jsonb(new) ->> tg_argv[0]) then
    raise exception 'Persistent News identities are immutable';
  end if;
  return new;
end;
$$;

create or replace function public.protect_news_identity_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'News identity version history cannot be deleted';
  end if;
  if old.is_current = false
     or new.is_current = true
     or new.superseded_at is null
     or new.closed_by_decision_id is null then
    raise exception 'News identity versions may only transition from current to superseded';
  end if;
  if (to_jsonb(old) - 'is_current' - 'superseded_at' - 'closed_by_decision_id')
     is distinct from
     (to_jsonb(new) - 'is_current' - 'superseded_at' - 'closed_by_decision_id') then
    raise exception 'Historical News identity facts cannot be overwritten';
  end if;
  return new;
end;
$$;

-- Person-pair state is an observed system timeline rather than a versioned
-- real-world fact. Its effective_to is therefore set by the state transition,
-- while factual identity and relationship periods above remain immutable.
create or replace function public.protect_news_person_pair_state_period()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'News person-pair state history cannot be deleted';
  end if;
  if old.is_current = false
     or new.is_current = true
     or new.effective_to is null
     or new.superseded_at is null
     or new.closed_by_decision_id is null then
    raise exception 'News person-pair states may only transition from current to superseded';
  end if;
  if (to_jsonb(old) - 'is_current' - 'effective_to' - 'superseded_at' - 'closed_by_decision_id')
     is distinct from
     (to_jsonb(new) - 'is_current' - 'effective_to' - 'superseded_at' - 'closed_by_decision_id') then
    raise exception 'Historical News person-pair state facts cannot be overwritten';
  end if;
  return new;
end;
$$;

create or replace function public.protect_news_author_profile_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'News Author profiles cannot be deleted';
  end if;
  if old.id is distinct from new.id
     or old.author_id is distinct from new.author_id
     or old.person_id is distinct from new.person_id then
    raise exception 'News Author profile identity and parent person are immutable';
  end if;
  return new;
end;
$$;

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
     or old.publisher_source_id is distinct from new.publisher_source_id then
    raise exception 'Publisher contributor profile identity and publisher are immutable';
  end if;
  return new;
end;
$$;

create trigger catalog_people_protect_identity
before update or delete on public.catalog_people
for each row execute function public.protect_news_stable_identity('person_id');
create trigger news_org_contributors_protect_identity
before update or delete on public.news_organizational_contributors
for each row execute function public.protect_news_stable_identity('contributor_id');
create trigger podcast_shows_protect_identity
before update or delete on public.podcast_shows
for each row execute function public.protect_news_stable_identity('show_id');
create trigger news_author_profiles_protect_identity
before update or delete on public.news_author_profiles
for each row execute function public.protect_news_author_profile_identity();
create trigger news_contributor_profiles_protect_identity
before update or delete on public.news_publisher_contributor_profiles
for each row execute function public.protect_news_contributor_profile_identity();

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'person_identity_versions',
    'person_alias_versions',
    'news_organizational_contributor_versions',
    'news_organizational_contributor_alias_versions',
    'podcast_show_identity_versions',
    'podcast_show_alias_versions',
    'news_publisher_policy_versions',
    'news_publisher_contributor_profile_versions',
    'news_person_publisher_relationship_versions',
    'podcast_show_contributor_versions',
    'podcast_show_publisher_relationship_versions',
    'news_official_team_publication_versions'
  ] loop
    execute format(
      'create trigger protect_news_identity_version before update or delete on public.%I for each row execute function public.protect_news_identity_version()',
      table_name
    );
  end loop;

  foreach table_name in array array[
    'person_identifiers',
    'news_organizational_contributor_identifiers',
    'podcast_show_identifiers',
    'news_identity_resolution_candidates',
    'news_identity_resolution_evidence',
    'news_identity_resolution_decisions',
    'news_identity_decision_evidence'
  ] loop
    execute format(
      'create trigger protect_news_identity_history before update or delete on public.%I for each row execute function public.protect_news_identity_history_row()',
      table_name
    );
  end loop;
end $$;

create trigger protect_news_person_pair_state_period
before update or delete on public.news_person_pair_state_periods
for each row execute function public.protect_news_person_pair_state_period();

create trigger news_identity_cases_set_updated_at
before update on public.news_identity_resolution_cases
for each row execute function public.set_updated_at();

create or replace function public.validate_news_identity_evidence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare kind_record public.news_identity_evidence_kinds%rowtype;
declare candidate_case_id uuid;
declare candidate_identity_type text;
declare case_subject_type text;
declare case_kind_value text;
declare case_publisher_source_uuid uuid;
declare best_specificity integer;
declare resolved_source_count integer;
declare resolved_source_uuid uuid;
declare resolved_scope_uuid uuid;
declare claimed_source_uuid uuid;
declare bridge_from_source_uuid uuid;
declare bridge_to_source_uuid uuid;
begin
  select * into strict kind_record
  from public.news_identity_evidence_kinds
  where evidence_kind = new.evidence_kind and active;

  if new.candidate_id is not null then
    select candidate.case_id, candidate.identity_type
    into strict candidate_case_id, candidate_identity_type
    from public.news_identity_resolution_candidates candidate
    where candidate.id = new.candidate_id;
    if candidate_case_id <> new.case_id then
      raise exception 'Identity evidence candidate must belong to the same Resolution case';
    end if;
  end if;

  select case
      when resolution_case.case_kind = 'person_merge' then 'person_merge'
      when resolution_case.case_kind = 'affiliation' then 'affiliation'
      when resolution_case.case_kind = 'publisher_profile' then 'publisher_profile'
      else resolution_case.proposed_identity_type
    end,
    resolution_case.case_kind,
    coalesce(resolution_case.publisher_source_id, subject_profile.publisher_source_id)
  into case_subject_type, case_kind_value, case_publisher_source_uuid
  from public.news_identity_resolution_cases resolution_case
  left join public.news_publisher_contributor_profiles subject_profile
    on subject_profile.id = resolution_case.subject_contributor_profile_id
  where resolution_case.id = new.case_id;

  if case_publisher_source_uuid is not null then
    case_publisher_source_uuid := public.canonical_trusted_source_id(
      case_publisher_source_uuid
    );
  end if;

  if candidate_identity_type is not null
     and not (candidate_identity_type = any(kind_record.subject_types))
     and not (case_subject_type = any(kind_record.subject_types)) then
    raise exception 'Identity evidence kind does not apply to this candidate or Resolution case';
  elsif new.candidate_id is null
        and case_subject_type is not null
        and case_subject_type <> 'unknown'
        and not (case_subject_type = any(kind_record.subject_types)) then
    raise exception 'Identity evidence kind does not apply to this Resolution case';
  end if;

  if kind_record.evidence_class = 'explicit'
     and new.visibility = 'hidden_metadata' then
    raise exception 'Hidden metadata cannot be explicit identity evidence';
  end if;

  if kind_record.evidence_class = 'explicit' then
    if new.evidence_url is null then
      raise exception 'Explicit identity evidence requires a public evidence URL';
    end if;
    if new.publisher_source_id is null then
      raise exception 'Explicit first-party evidence requires its claimed publisher';
    end if;

    -- This is ownership resolution only. It deliberately does not consult or
    -- copy source trust tier, review applicability, independence, or News
    -- publisher policy.
    select max(match.specificity)
    into best_specificity
    from public.trusted_source_url_matches(new.evidence_url) match;

    if best_specificity is null then
      raise exception 'Explicit first-party evidence URL is not owned by a trusted publisher';
    end if;

    select count(distinct match.canonical_source_id)
    into resolved_source_count
    from public.trusted_source_url_matches(new.evidence_url) match
    where match.specificity = best_specificity;

    if resolved_source_count <> 1 then
      raise exception 'Explicit first-party evidence URL has ambiguous trusted publisher ownership';
    end if;

    select match.canonical_source_id, match.url_scope_version_id
    into strict resolved_source_uuid, resolved_scope_uuid
    from public.trusted_source_url_matches(new.evidence_url) match
    where match.specificity = best_specificity
    order by match.canonical_source_id::text, match.url_scope_version_id::text
    limit 1;

    claimed_source_uuid := public.canonical_trusted_source_id(new.publisher_source_id);
    if resolved_source_uuid <> claimed_source_uuid then
      raise exception 'Explicit first-party evidence URL does not belong to the claimed publisher';
    end if;
    if not kind_record.can_bridge_person_identities
       and case_publisher_source_uuid is not null
       and claimed_source_uuid <> case_publisher_source_uuid then
      raise exception 'Explicit first-party evidence publisher does not match the Resolution case publisher';
    end if;
    new.source_url_scope_version_id := resolved_scope_uuid;
  elsif new.source_url_scope_version_id is not null then
    raise exception 'Supporting evidence cannot claim first-party URL-scope provenance';
  end if;

  if kind_record.can_bridge_person_identities then
    if new.bridge_from_publisher_source_id is null
       or new.bridge_to_publisher_source_id is null then
      raise exception 'Cross-publisher bridge evidence requires both publisher endpoints';
    end if;
    bridge_from_source_uuid := public.canonical_trusted_source_id(
      new.bridge_from_publisher_source_id
    );
    bridge_to_source_uuid := public.canonical_trusted_source_id(
      new.bridge_to_publisher_source_id
    );
    if bridge_from_source_uuid = bridge_to_source_uuid then
      raise exception 'Cross-publisher bridge endpoints must resolve to different publishers';
    end if;
    if claimed_source_uuid not in (bridge_from_source_uuid, bridge_to_source_uuid) then
      raise exception 'Cross-publisher bridge evidence must be owned by one of its publisher endpoints';
    end if;
    if case_kind_value <> 'person_merge'
       and case_publisher_source_uuid is not null
       and case_publisher_source_uuid not in (
         bridge_from_source_uuid,
         bridge_to_source_uuid
       ) then
      raise exception 'Cross-publisher bridge must include the Resolution case publisher';
    end if;
  elsif new.bridge_from_publisher_source_id is not null
        or new.bridge_to_publisher_source_id is not null then
    raise exception 'Only governed bridge evidence may claim publisher bridge endpoints';
  end if;
  return new;
end;
$$;

create trigger validate_news_identity_evidence_on_insert
before insert on public.news_identity_resolution_evidence
for each row execute function public.validate_news_identity_evidence();

-- ---------------------------------------------------------------------------
-- Deterministic pair-state transitions and automatic Resolution.
-- ---------------------------------------------------------------------------

create or replace function private.news_person_has_publisher_identity(
  person_id_value uuid,
  publisher_source_id_value uuid default null
)
returns boolean
language sql
stable
set search_path = ''
as $$
  with associated_publishers(publisher_source_id) as (
    select relationship.publisher_source_id
    from public.news_person_publisher_relationship_versions relationship
    where relationship.person_id = person_id_value
    union
    select profile.publisher_source_id
    from public.news_publisher_contributor_profile_versions version
    join public.news_publisher_contributor_profiles profile
      on profile.id = version.contributor_profile_id
    where version.person_id = person_id_value
  )
  select exists (
    select 1
    from associated_publishers associated
    where publisher_source_id_value is null
       or public.canonical_trusted_source_id(associated.publisher_source_id)
          = public.canonical_trusted_source_id(publisher_source_id_value)
  );
$$;

create or replace function private.news_bridge_connects_person_to_publisher(
  evidence_id_value uuid,
  person_id_value uuid,
  publisher_source_id_value uuid
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((
    select (
      (
        public.canonical_trusted_source_id(evidence.bridge_from_publisher_source_id)
          = public.canonical_trusted_source_id(publisher_source_id_value)
        and private.news_person_has_publisher_identity(
          person_id_value,
          evidence.bridge_to_publisher_source_id
        )
      )
      or
      (
        public.canonical_trusted_source_id(evidence.bridge_to_publisher_source_id)
          = public.canonical_trusted_source_id(publisher_source_id_value)
        and private.news_person_has_publisher_identity(
          person_id_value,
          evidence.bridge_from_publisher_source_id
        )
      )
    )
    from public.news_identity_resolution_evidence evidence
    join public.news_identity_evidence_kinds kind
      on kind.evidence_kind = evidence.evidence_kind
    where evidence.id = evidence_id_value
      and kind.evidence_class = 'explicit'
      and kind.can_bridge_person_identities
      and evidence.source_url_scope_version_id is not null
      and evidence.visibility <> 'hidden_metadata'
      and not evidence.is_conflicting
  ), false);
$$;

create or replace function private.news_bridge_connects_people(
  evidence_id_value uuid,
  person_one_id uuid,
  person_two_id uuid
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((
    select (
      (
        private.news_person_has_publisher_identity(
          person_one_id,
          evidence.bridge_from_publisher_source_id
        )
        and private.news_person_has_publisher_identity(
          person_two_id,
          evidence.bridge_to_publisher_source_id
        )
      )
      or
      (
        private.news_person_has_publisher_identity(
          person_one_id,
          evidence.bridge_to_publisher_source_id
        )
        and private.news_person_has_publisher_identity(
          person_two_id,
          evidence.bridge_from_publisher_source_id
        )
      )
    )
    from public.news_identity_resolution_evidence evidence
    join public.news_identity_evidence_kinds kind
      on kind.evidence_kind = evidence.evidence_kind
    where evidence.id = evidence_id_value
      and kind.evidence_class = 'explicit'
      and kind.can_bridge_person_identities
      and evidence.source_url_scope_version_id is not null
      and evidence.visibility <> 'hidden_metadata'
      and not evidence.is_conflicting
  ), false);
$$;

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

  perform 1 from public.catalog_people where id in (person_a, person_b) for update;
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

create or replace function private.snapshot_news_identity_decision_evidence(
  decision_id_value uuid,
  case_id_value uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.news_identity_decision_evidence(
    decision_id, evidence_id, evidence_role
  )
  select
    decision_id_value,
    evidence.id,
    case
      when evidence.is_conflicting then 'conflicting'
      when kind.can_bridge_person_identities then 'bridge'
      else kind.evidence_class
    end
  from public.news_identity_resolution_evidence evidence
  join public.news_identity_evidence_kinds kind
    on kind.evidence_kind = evidence.evidence_kind
  where evidence.case_id = case_id_value
  on conflict (decision_id, evidence_id) do nothing;
$$;

create or replace function private.evaluate_news_identity_case(case_id_value uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  case_record public.news_identity_resolution_cases%rowtype;
  candidate_record public.news_identity_resolution_candidates%rowtype;
  decision_uuid uuid := gen_random_uuid();
  explicit_candidate_count integer;
  visible_conflict_count integer;
  evidence_count integer;
  explicit_bridge_count integer;
  selected_candidate_uuid uuid;
  stop_reason_value text;
  action_value text;
  rule_key_value text;
  current_profile_person uuid;
  current_profile_org uuid;
  previous_decision_uuid uuid;
  case_publisher_uuid uuid;
  cross_publisher_bridge_required boolean := false;
begin
  select * into strict case_record
  from public.news_identity_resolution_cases
  where id = case_id_value
  for update;

  -- Later evidence may supersede an automatic outcome. Staff terminal outcomes
  -- remain closed until a deliberate reopen action.
  if case_record.status in ('resolved_manual', 'not_identity') then
    return null;
  end if;

  select decision.id into previous_decision_uuid
  from public.news_identity_resolution_decisions decision
  where decision.case_id = case_id_value
  order by decision.decided_at desc, decision.id desc
  limit 1;

  select
    count(*),
    count(distinct evidence.candidate_id) filter (
      where kind.evidence_class = 'explicit'
        and evidence.visibility <> 'hidden_metadata'
        and not evidence.is_conflicting
        and evidence.candidate_id is not null
    ),
    count(*) filter (
      where evidence.is_conflicting
        and evidence.visibility <> 'hidden_metadata'
    )
  into evidence_count, explicit_candidate_count, visible_conflict_count
  from public.news_identity_resolution_evidence evidence
  join public.news_identity_evidence_kinds kind
    on kind.evidence_kind = evidence.evidence_kind and kind.active
  where evidence.case_id = case_id_value;

  select evidence.candidate_id
  into selected_candidate_uuid
  from public.news_identity_resolution_evidence evidence
  join public.news_identity_evidence_kinds kind
    on kind.evidence_kind = evidence.evidence_kind and kind.active
  where evidence.case_id = case_id_value
    and kind.evidence_class = 'explicit'
    and evidence.visibility <> 'hidden_metadata'
    and not evidence.is_conflicting
    and evidence.candidate_id is not null
  group by evidence.candidate_id
  order by evidence.candidate_id
  limit 1;

  if selected_candidate_uuid is not null then
    select * into strict candidate_record
    from public.news_identity_resolution_candidates
    where id = selected_candidate_uuid;
  else
    select * into candidate_record
    from public.news_identity_resolution_candidates
    where case_id = case_id_value
    order by created_at, id
    limit 1;
  end if;

  case_publisher_uuid := case_record.publisher_source_id;
  if case_publisher_uuid is null
     and case_record.subject_contributor_profile_id is not null then
    select profile.publisher_source_id
    into case_publisher_uuid
    from public.news_publisher_contributor_profiles profile
    where profile.id = case_record.subject_contributor_profile_id;
  end if;
  if case_publisher_uuid is not null then
    case_publisher_uuid := public.canonical_trusted_source_id(case_publisher_uuid);
  end if;

  if candidate_record.person_id is not null
     and case_publisher_uuid is not null
     and private.news_person_has_publisher_identity(candidate_record.person_id)
     and not private.news_person_has_publisher_identity(
       candidate_record.person_id,
       case_publisher_uuid
     ) then
    cross_publisher_bridge_required := true;
  end if;

  select count(*) into explicit_bridge_count
  from public.news_identity_resolution_evidence evidence
  join public.news_identity_evidence_kinds kind
    on kind.evidence_kind = evidence.evidence_kind and kind.active
  where evidence.case_id = case_id_value
    and evidence.candidate_id = selected_candidate_uuid
    and kind.evidence_class = 'explicit'
    and kind.can_bridge_person_identities
    and evidence.visibility <> 'hidden_metadata'
    and not evidence.is_conflicting
    and case
      when case_record.case_kind = 'person_merge' then
        private.news_bridge_connects_people(
          evidence.id,
          case_record.subject_person_id,
          candidate_record.person_id
        )
      when cross_publisher_bridge_required then
        private.news_bridge_connects_person_to_publisher(
          evidence.id,
          candidate_record.person_id,
          case_publisher_uuid
        )
      else true
    end;

  if visible_conflict_count > 0 then
    stop_reason_value := 'conflicting_public_evidence';
  elsif explicit_candidate_count > 1 then
    stop_reason_value := 'ambiguous_explicit_evidence';
  elsif candidate_record.id is null then
    stop_reason_value := 'no_identity_candidate';
  elsif case_record.case_kind = 'affiliation' then
    stop_reason_value := 'affiliation_requires_review';
  elsif case_record.case_kind = 'person_merge'
        and (explicit_candidate_count <> 1
             or explicit_bridge_count = 0
             or candidate_record.person_id is null) then
    stop_reason_value := 'missing_identity_bridge';
  elsif cross_publisher_bridge_required
        and (explicit_candidate_count <> 1 or explicit_bridge_count = 0) then
    stop_reason_value := 'missing_cross_publisher_identity_bridge';
  elsif explicit_candidate_count = 0 then
    stop_reason_value := case
      when evidence_count = 0 then 'name_alone_is_ambiguous'
      else 'supporting_evidence_only'
    end;
  elsif candidate_record.candidate_kind = 'proposed_identity' then
    stop_reason_value := 'identity_creation_requires_review';
  elsif case_record.subject_contributor_profile_id is not null then
    select version.person_id, version.organizational_contributor_id
    into current_profile_person, current_profile_org
    from public.news_publisher_contributor_profile_versions version
    where version.contributor_profile_id = case_record.subject_contributor_profile_id
      and version.is_current;
    if current_profile_person is not null
       and current_profile_person is distinct from candidate_record.person_id then
      stop_reason_value := 'existing_profile_link_conflict';
    elsif current_profile_org is not null
          and current_profile_org is distinct from candidate_record.organizational_contributor_id then
      stop_reason_value := 'existing_profile_link_conflict';
    end if;
  end if;

  if stop_reason_value is not null then
    insert into public.news_identity_resolution_decisions(
      id, case_id, action, decision_origin, selected_candidate_id,
      result_identity_type, automatic_rule_key, stop_reason,
      question_snapshot, action_payload_snapshot, supersedes_decision_id
    ) values (
      decision_uuid, case_id_value, 'automatic_review_required', 'automatic',
      candidate_record.id, 'none',
      case when case_record.case_kind = 'person_merge'
                  or cross_publisher_bridge_required
        then 'explicit_public_identity_bridge'
        else 'explicit_public_non_conflicting'
      end,
      stop_reason_value, case_record.unresolved_question,
      jsonb_build_object(
        'evidence_count', evidence_count,
        'explicit_candidate_count', explicit_candidate_count,
        'visible_conflict_count', visible_conflict_count,
        'cross_publisher_bridge_required', cross_publisher_bridge_required,
        'valid_bridge_count', explicit_bridge_count
      ), previous_decision_uuid
    );
    perform private.snapshot_news_identity_decision_evidence(decision_uuid, case_id_value);

    update public.news_identity_resolution_cases
    set status = 'needs_review',
        automatic_resolution_result = 'review_required',
        resolution_stop_reason = stop_reason_value,
        resolved_at = null
    where id = case_id_value;

    if case_record.subject_person_id is not null
       and candidate_record.person_id is not null
       and case_record.subject_person_id <> candidate_record.person_id
       then
      perform private.set_news_person_pair_state(
        case_record.subject_person_id,
        candidate_record.person_id,
        'ambiguous',
        null,
        decision_uuid
      );
    end if;
    return decision_uuid;
  end if;

  if case_record.case_kind = 'person_merge' then
    action_value := 'automatic_merge';
    rule_key_value := 'explicit_public_identity_bridge';
  elsif cross_publisher_bridge_required then
    action_value := 'automatic_link';
    rule_key_value := 'explicit_public_identity_bridge';
  else
    action_value := 'automatic_link';
    rule_key_value := 'explicit_public_non_conflicting';
  end if;

  insert into public.news_identity_resolution_decisions(
    id, case_id, action, decision_origin, selected_candidate_id,
    result_identity_type, result_person_id,
    result_organizational_contributor_id, result_show_id,
    result_contributor_profile_id, automatic_rule_key,
    question_snapshot, action_payload_snapshot, supersedes_decision_id
  ) values (
    decision_uuid, case_id_value, action_value, 'automatic', candidate_record.id,
    candidate_record.identity_type, candidate_record.person_id,
    candidate_record.organizational_contributor_id, candidate_record.show_id,
    candidate_record.contributor_profile_id, rule_key_value,
    case_record.unresolved_question,
    jsonb_build_object('visible_public_evidence_wins_over_hidden_metadata', true),
    previous_decision_uuid
  );
  perform private.snapshot_news_identity_decision_evidence(decision_uuid, case_id_value);

  if case_record.case_kind = 'person_merge' then
    perform private.set_news_person_pair_state(
      case_record.subject_person_id,
      candidate_record.person_id,
      'merged',
      candidate_record.person_id,
      decision_uuid
    );
  elsif case_record.subject_contributor_profile_id is not null
        and not exists (
          select 1
          from public.news_publisher_contributor_profile_versions version
          where version.contributor_profile_id = case_record.subject_contributor_profile_id
            and version.is_current
        ) then
    insert into public.news_publisher_contributor_profile_versions(
      contributor_profile_id, display_name, profile_url,
      person_id, organizational_contributor_id, resolution_decision_id
    ) values (
      case_record.subject_contributor_profile_id,
      coalesce(case_record.proposed_name, candidate_record.display_name),
      case_record.profile_url,
      candidate_record.person_id,
      candidate_record.organizational_contributor_id,
      decision_uuid
    );
  end if;

  update public.news_identity_resolution_cases
  set status = 'resolved_automatic',
      automatic_resolution_result = action_value,
      resolution_stop_reason = null,
      resolved_at = clock_timestamp()
  where id = case_id_value;

  return decision_uuid;
end;
$$;

create or replace function private.evaluate_news_identity_case_on_evidence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.evaluate_news_identity_case(new.case_id);
  return new;
end;
$$;

create trigger evaluate_news_identity_case_after_candidate
after insert on public.news_identity_resolution_candidates
for each row execute function private.evaluate_news_identity_case_on_evidence();
create trigger evaluate_news_identity_case_after_evidence
after insert on public.news_identity_resolution_evidence
for each row execute function private.evaluate_news_identity_case_on_evidence();

-- ---------------------------------------------------------------------------
-- Staff review mutation. The action is question-oriented and every outcome is
-- an immutable decision. Supporting evidence can keep identities separate but
-- cannot authorize a merge without an explicit public bridge.
-- ---------------------------------------------------------------------------

create or replace function public.admin_review_news_identity_case(
  case_id_value uuid,
  action_value text,
  target_identity_id_value uuid default null,
  action_payload_value jsonb default '{}'::jsonb,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  case_record public.news_identity_resolution_cases%rowtype;
  decision_uuid uuid := gen_random_uuid();
  decision_at timestamptz := clock_timestamp();
  identity_type_value text := nullif(action_payload_value ->> 'identity_type', '');
  display_name_value text;
  target_person_uuid uuid;
  target_org_uuid uuid;
  target_show_uuid uuid;
  target_profile_uuid uuid;
  selected_candidate_uuid uuid;
  publisher_uuid uuid;
  relationship_uuid uuid;
  relationship_type_value text;
  previous_decision_uuid uuid;
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News identity review access is required';
  end if;
  if action_value not in (
    'confirm_create', 'link_existing', 'keep_separate',
    'establish_affiliation', 'correct_affiliation', 'merge',
    'reverse_merge', 'not_identity', 'insufficient_evidence', 'reopen'
  ) then
    raise exception 'Unsupported News identity review action';
  end if;

  select * into strict case_record
  from public.news_identity_resolution_cases
  where id = case_id_value
  for update;

  select decision.id into previous_decision_uuid
  from public.news_identity_resolution_decisions decision
  where decision.case_id = case_id_value
  order by decision.decided_at desc, decision.id desc
  limit 1;

  display_name_value := coalesce(
    nullif(btrim(action_payload_value ->> 'display_name'), ''),
    case_record.proposed_name
  );

  if action_value = 'confirm_create' then
    if identity_type_value not in ('human', 'organization', 'show') then
      raise exception 'Confirm/create requires human, organization, or show identity_type';
    end if;
    if display_name_value is null then
      raise exception 'Confirm/create requires a public display name';
    end if;

    if identity_type_value = 'human' then
      target_person_uuid := gen_random_uuid();
      insert into public.catalog_people(id) values (target_person_uuid);
    elsif identity_type_value = 'organization' then
      target_org_uuid := gen_random_uuid();
      insert into public.news_organizational_contributors(id) values (target_org_uuid);
    else
      target_show_uuid := gen_random_uuid();
      insert into public.podcast_shows(id) values (target_show_uuid);
    end if;
  elsif action_value = 'link_existing' then
    if target_identity_id_value is null
       or identity_type_value not in ('human', 'organization', 'show', 'publisher_profile') then
      raise exception 'Link existing requires a target identity and identity_type';
    end if;
    if identity_type_value = 'human' then
      select id into strict target_person_uuid from public.catalog_people where id = target_identity_id_value;
    elsif identity_type_value = 'organization' then
      select id into strict target_org_uuid from public.news_organizational_contributors where id = target_identity_id_value;
    elsif identity_type_value = 'show' then
      select id into strict target_show_uuid from public.podcast_shows where id = target_identity_id_value;
    else
      select id into strict target_profile_uuid from public.news_publisher_contributor_profiles where id = target_identity_id_value;
    end if;
  elsif action_value in ('keep_separate', 'merge', 'reverse_merge') then
    if case_record.subject_person_id is null or target_identity_id_value is null then
      raise exception 'Person identity action requires a subject and target person';
    end if;
    select id into strict target_person_uuid
    from public.catalog_people where id = target_identity_id_value;
    if target_person_uuid = case_record.subject_person_id then
      raise exception 'Person identity action requires two different people';
    end if;
    identity_type_value := 'human';
  elsif action_value in ('establish_affiliation', 'correct_affiliation') then
    target_person_uuid := coalesce(target_identity_id_value, case_record.subject_person_id);
    if target_person_uuid is null then
      raise exception 'Affiliation review requires a person identity';
    end if;
    perform 1 from public.catalog_people where id = target_person_uuid;
    if not found then raise exception 'Affiliation person identity does not exist'; end if;
    publisher_uuid := nullif(action_payload_value ->> 'publisher_source_id', '')::uuid;
    relationship_type_value := nullif(action_payload_value ->> 'relationship_type', '');
    if publisher_uuid is null or relationship_type_value is null then
      raise exception 'Affiliation review requires publisher_source_id and relationship_type';
    end if;
    perform 1 from public.trusted_sources where id = publisher_uuid;
    if not found then raise exception 'Affiliation publisher identity does not exist'; end if;
    perform 1 from public.news_person_publisher_relationship_types
    where relationship_type = relationship_type_value and active;
    if not found then raise exception 'Affiliation relationship type is not governed or active'; end if;
    identity_type_value := 'affiliation';
    if action_value = 'correct_affiliation' then
      relationship_uuid := nullif(action_payload_value ->> 'relationship_id', '')::uuid;
      if relationship_uuid is null then
        raise exception 'Correct affiliation requires relationship_id';
      end if;
      perform 1
      from public.news_person_publisher_relationship_versions relationship
      where relationship.id = relationship_uuid
        and relationship.person_id = target_person_uuid
        and relationship.is_current
      for update;
      if not found then raise exception 'Current affiliation relationship does not exist for this person'; end if;
    end if;
  elsif action_value in ('not_identity', 'insufficient_evidence', 'reopen') then
    identity_type_value := 'none';
  end if;

  if action_value = 'merge' then
    if length(btrim(coalesce(notes_value, ''))) = 0 then
      raise exception 'A manual merge requires a reason';
    end if;
    select candidate.id into selected_candidate_uuid
    from public.news_identity_resolution_candidates candidate
    where candidate.case_id = case_id_value
      and candidate.person_id = target_person_uuid
      and exists (
        select 1
        from public.news_identity_resolution_evidence evidence
        join public.news_identity_evidence_kinds kind
          on kind.evidence_kind = evidence.evidence_kind
        where evidence.case_id = case_id_value
          and evidence.candidate_id = candidate.id
          and kind.evidence_class = 'explicit'
          and kind.can_bridge_person_identities
          and evidence.visibility <> 'hidden_metadata'
          and not evidence.is_conflicting
          and private.news_bridge_connects_people(
            evidence.id,
            case_record.subject_person_id,
            target_person_uuid
          )
      )
    order by candidate.created_at, candidate.id
    limit 1;
    if selected_candidate_uuid is null or exists (
      select 1
      from public.news_identity_resolution_evidence evidence
      where evidence.case_id = case_id_value
        and evidence.is_conflicting
        and evidence.visibility <> 'hidden_metadata'
    ) then
      raise exception 'A person merge requires explicit public non-conflicting bridge evidence';
    end if;
  elsif action_value = 'reverse_merge' then
    if length(btrim(coalesce(notes_value, ''))) = 0 then
      raise exception 'A merge reversal requires a reason';
    end if;
    if not exists (
      select 1
      from public.news_person_pair_state_periods period
      where period.is_current and period.state = 'merged'
        and period.person_a_id in (case_record.subject_person_id, target_person_uuid)
        and period.person_b_id in (case_record.subject_person_id, target_person_uuid)
    ) then
      raise exception 'The requested person pair is not currently merged';
    end if;
  end if;

  if selected_candidate_uuid is null and target_identity_id_value is not null then
    select candidate.id into selected_candidate_uuid
    from public.news_identity_resolution_candidates candidate
    where candidate.case_id = case_id_value
      and target_identity_id_value in (
        candidate.person_id,
        candidate.organizational_contributor_id,
        candidate.show_id,
        candidate.contributor_profile_id
      )
    order by candidate.created_at, candidate.id
    limit 1;
  end if;

  insert into public.news_identity_resolution_decisions(
    id, case_id, action, decision_origin, selected_candidate_id,
    result_identity_type, result_person_id,
    result_organizational_contributor_id, result_show_id,
    result_contributor_profile_id, question_snapshot,
    action_payload_snapshot, notes, decided_by_user_id,
    supersedes_decision_id, decided_at
  ) values (
    decision_uuid, case_id_value, action_value, 'staff', selected_candidate_uuid,
    identity_type_value, target_person_uuid, target_org_uuid, target_show_uuid,
    target_profile_uuid, case_record.unresolved_question,
    coalesce(action_payload_value, '{}'::jsonb), notes_value, auth.uid(),
    previous_decision_uuid, decision_at
  );
  perform private.snapshot_news_identity_decision_evidence(decision_uuid, case_id_value);

  if action_value = 'confirm_create' and identity_type_value = 'human' then
    insert into public.person_identity_versions(
      person_id, public_name, name_kind, resolution_decision_id
    ) values (
      target_person_uuid,
      display_name_value,
      coalesce(nullif(action_payload_value ->> 'name_kind', ''), 'professional_name'),
      decision_uuid
    );
    insert into public.news_author_profiles(
      person_id, created_by_resolution_decision_id
    ) values (target_person_uuid, decision_uuid);
  elsif action_value = 'confirm_create' and identity_type_value = 'organization' then
    insert into public.news_organizational_contributor_versions(
      organizational_contributor_id, display_name, resolution_decision_id
    ) values (target_org_uuid, display_name_value, decision_uuid);
  elsif action_value = 'confirm_create' and identity_type_value = 'show' then
    insert into public.podcast_show_identity_versions(
      show_id, display_name, resolution_decision_id
    ) values (target_show_uuid, display_name_value, decision_uuid);
  end if;

  if action_value in ('confirm_create', 'link_existing')
     and case_record.subject_contributor_profile_id is not null
     and identity_type_value in ('human', 'organization') then
    update public.news_publisher_contributor_profile_versions
    set is_current = false,
        superseded_at = decision_at,
        closed_by_decision_id = decision_uuid
    where contributor_profile_id = case_record.subject_contributor_profile_id
      and is_current;

    insert into public.news_publisher_contributor_profile_versions(
      contributor_profile_id, display_name, profile_url,
      person_id, organizational_contributor_id, resolution_decision_id,
      effective_from
    ) values (
      case_record.subject_contributor_profile_id,
      coalesce(display_name_value, case_record.raw_byline),
      case_record.profile_url,
      target_person_uuid,
      target_org_uuid,
      decision_uuid,
      decision_at
    );
  end if;

  if action_value = 'keep_separate' then
    perform private.set_news_person_pair_state(
      case_record.subject_person_id, target_person_uuid,
      'distinct', null, decision_uuid
    );
  elsif action_value = 'merge' then
    perform private.set_news_person_pair_state(
      case_record.subject_person_id, target_person_uuid,
      'merged', target_person_uuid, decision_uuid
    );
  elsif action_value = 'reverse_merge' then
    perform private.set_news_person_pair_state(
      case_record.subject_person_id, target_person_uuid,
      'distinct', null, decision_uuid
    );
  elsif action_value in ('establish_affiliation', 'correct_affiliation') then
    if action_value = 'correct_affiliation' then
      update public.news_person_publisher_relationship_versions
      set is_current = false,
          superseded_at = decision_at,
          closed_by_decision_id = decision_uuid
      where id = relationship_uuid;
    end if;
    insert into public.news_person_publisher_relationship_versions(
      person_id, publisher_source_id, relationship_type,
      effective_from, effective_to, resolution_decision_id, notes
    ) values (
      target_person_uuid, publisher_uuid, relationship_type_value,
      coalesce(nullif(action_payload_value ->> 'effective_from', '')::timestamptz, decision_at),
      nullif(action_payload_value ->> 'effective_to', '')::timestamptz,
      decision_uuid, notes_value
    );
  end if;

  if action_value = 'not_identity' then
    update public.news_identity_resolution_cases
    set status = 'not_identity', automatic_resolution_result = null,
        resolution_stop_reason = 'staff_determined_not_identity',
        resolved_at = decision_at
    where id = case_id_value;
  elsif action_value = 'insufficient_evidence' then
    update public.news_identity_resolution_cases
    set status = 'insufficient_evidence', automatic_resolution_result = null,
        resolution_stop_reason = 'staff_requires_more_evidence',
        resolved_at = decision_at
    where id = case_id_value;
  elsif action_value = 'reopen' then
    update public.news_identity_resolution_cases
    set status = 'reopened', automatic_resolution_result = null,
        resolution_stop_reason = null, resolved_at = null
    where id = case_id_value;
  else
    update public.news_identity_resolution_cases
    set status = 'resolved_manual', automatic_resolution_result = action_value,
        resolution_stop_reason = null, resolved_at = decision_at
    where id = case_id_value;
  end if;

  return decision_uuid;
end;
$$;

-- Point-in-time query returns the recorded state directly. No redirect-chain
-- inference is needed after a merge or later split.
create or replace function public.get_news_person_pair_state_at(
  person_one_id uuid,
  person_two_id uuid,
  at_time timestamptz
)
returns table (
  state text,
  canonical_person_id uuid,
  effective_from timestamptz,
  effective_to timestamptz,
  opened_by_decision_id uuid,
  closed_by_decision_id uuid
)
language sql
stable
set search_path = ''
as $$
  select
    period.state,
    period.canonical_person_id,
    period.effective_from,
    period.effective_to,
    period.opened_by_decision_id,
    period.closed_by_decision_id
  from public.news_person_pair_state_periods period
  where period.person_a_id = case
      when person_one_id::text < person_two_id::text then person_one_id else person_two_id end
    and period.person_b_id = case
      when person_one_id::text < person_two_id::text then person_two_id else person_one_id end
    and period.effective_from <= at_time
    and (period.effective_to is null or at_time < period.effective_to)
  order by period.effective_from desc
  limit 1;
$$;

-- ---------------------------------------------------------------------------
-- Dense staff read model. Publisher factual-governance fields are intentionally
-- absent except for the reused identity/name itself.
-- ---------------------------------------------------------------------------

create view public.news_identity_review_read_model
with (security_invoker = true)
as
select
  resolution_case.id,
  resolution_case.case_id,
  resolution_case.case_kind,
  resolution_case.proposed_identity_type,
  resolution_case.proposed_name,
  resolution_case.raw_byline,
  resolution_case.profile_url,
  resolution_case.status,
  resolution_case.automatic_resolution_result,
  resolution_case.resolution_stop_reason,
  resolution_case.unresolved_question,
  resolution_case.subject_person_id,
  resolution_case.subject_organizational_contributor_id,
  resolution_case.subject_show_id,
  resolution_case.subject_contributor_profile_id,
  resolution_case.publisher_source_id,
  publisher.source_id as publisher_id,
  publisher.display_name as publisher_name,
  resolution_case.context,
  resolution_case.created_at,
  resolution_case.updated_at,
  resolution_case.resolved_at,
  coalesce(candidate_rows.items, '[]'::jsonb) as possible_matches,
  coalesce(evidence_rows.items, '[]'::jsonb) as public_evidence,
  coalesce(affiliation_rows.items, '[]'::jsonb) as affiliations,
  coalesce(decision_rows.items, '[]'::jsonb) as decision_history
from public.news_identity_resolution_cases resolution_case
left join public.trusted_sources publisher
  on publisher.id = resolution_case.publisher_source_id
left join lateral (
  select jsonb_agg(jsonb_build_object(
    'id', candidate.id,
    'candidate_kind', candidate.candidate_kind,
    'identity_type', candidate.identity_type,
    'display_name', candidate.display_name,
    'person_id', candidate.person_id,
    'organizational_contributor_id', candidate.organizational_contributor_id,
    'show_id', candidate.show_id,
    'contributor_profile_id', candidate.contributor_profile_id,
    'proposed_facts', candidate.proposed_facts
  ) order by candidate.created_at, candidate.id) as items
  from public.news_identity_resolution_candidates candidate
  where candidate.case_id = resolution_case.id
) candidate_rows on true
left join lateral (
  select jsonb_agg(jsonb_build_object(
    'id', evidence.id,
    'kind', evidence.evidence_kind,
    'class', kind.evidence_class,
    'visibility', evidence.visibility,
    'is_conflicting', evidence.is_conflicting,
    'summary', evidence.evidence_summary,
    'url', evidence.evidence_url,
    'publisher_source_id', evidence.publisher_source_id,
    'source_url_scope_version_id', evidence.source_url_scope_version_id,
    'bridge_from_publisher_source_id', evidence.bridge_from_publisher_source_id,
    'bridge_to_publisher_source_id', evidence.bridge_to_publisher_source_id,
    'candidate_id', evidence.candidate_id,
    'can_bridge_identities', kind.can_bridge_person_identities,
    'observed_at', evidence.observed_at
  ) order by evidence.created_at, evidence.id) as items
  from public.news_identity_resolution_evidence evidence
  join public.news_identity_evidence_kinds kind
    on kind.evidence_kind = evidence.evidence_kind
  where evidence.case_id = resolution_case.id
) evidence_rows on true
left join lateral (
  select jsonb_agg(jsonb_build_object(
    'id', relationship.id,
    'person_id', relationship.person_id,
    'publisher_source_id', relationship.publisher_source_id,
    'publisher_name', relationship_publisher.display_name,
    'relationship_type', relationship.relationship_type,
    'effective_from', relationship.effective_from,
    'effective_to', relationship.effective_to,
    'is_current', relationship.is_current
  ) order by relationship.effective_from nulls first, relationship.created_at) as items
  from public.news_person_publisher_relationship_versions relationship
  join public.trusted_sources relationship_publisher
    on relationship_publisher.id = relationship.publisher_source_id
  where relationship.person_id = resolution_case.subject_person_id
     or relationship.person_id in (
       select candidate.person_id
       from public.news_identity_resolution_candidates candidate
       where candidate.case_id = resolution_case.id and candidate.person_id is not null
     )
) affiliation_rows on true
left join lateral (
  select jsonb_agg(jsonb_build_object(
    'id', decision.id,
    'action', decision.action,
    'origin', decision.decision_origin,
    'rule', decision.automatic_rule_key,
    'stop_reason', decision.stop_reason,
    'result_identity_type', decision.result_identity_type,
    'result_person_id', decision.result_person_id,
    'result_organizational_contributor_id', decision.result_organizational_contributor_id,
    'result_show_id', decision.result_show_id,
    'notes', decision.notes,
    'decided_at', decision.decided_at
  ) order by decision.decided_at, decision.id) as items
  from public.news_identity_resolution_decisions decision
  where decision.case_id = resolution_case.id
) decision_rows on true;

create view public.news_publisher_policy_read_model
with (security_invoker = true)
as
select
  publisher.id as publisher_source_id,
  publisher.source_id as publisher_id,
  publisher.display_name,
  coalesce(policy.news_status, 'unreviewed') as news_status,
  policy.id as policy_version_id,
  policy.effective_from,
  policy.notes
from public.trusted_sources publisher
left join public.news_publisher_policy_versions policy
  on policy.publisher_source_id = publisher.id and policy.is_current;

-- ---------------------------------------------------------------------------
-- RLS and grants. Canonical and review data remain staff-only in Phase 2;
-- later public read models can expose only approved fields. Browser mutation is
-- limited to the audited staff RPC above.
-- ---------------------------------------------------------------------------

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'news_identity_evidence_kinds',
    'news_identity_resolution_rules',
    'news_person_publisher_relationship_types',
    'news_show_contributor_roles',
    'news_show_publisher_relationship_types',
    'catalog_people',
    'person_identity_versions',
    'person_alias_versions',
    'person_identifiers',
    'news_author_profiles',
    'news_organizational_contributors',
    'news_organizational_contributor_versions',
    'news_organizational_contributor_alias_versions',
    'news_organizational_contributor_identifiers',
    'podcast_shows',
    'podcast_show_identity_versions',
    'podcast_show_alias_versions',
    'podcast_show_identifiers',
    'news_publisher_policy_versions',
    'news_publisher_contributor_profiles',
    'news_publisher_contributor_profile_versions',
    'news_person_publisher_relationship_versions',
    'podcast_show_contributor_versions',
    'podcast_show_publisher_relationship_versions',
    'news_official_team_publication_versions',
    'news_identity_resolution_cases',
    'news_identity_resolution_candidates',
    'news_identity_resolution_evidence',
    'news_identity_resolution_decisions',
    'news_identity_decision_evidence',
    'news_person_pair_state_periods'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('revoke all on table public.%I from public, anon, authenticated', table_name);
    execute format(
      'create policy "Authorized staff read News identity %1$s" on public.%1$I for select to authenticated using (public.has_staff_access(array[''admin'',''staff'',''content_admin'']::text[], null))',
      table_name
    );
    execute format('grant select on table public.%I to authenticated', table_name);
  end loop;
end $$;

grant select on public.news_identity_review_read_model,
  public.news_publisher_policy_read_model to authenticated;

revoke all on function public.admin_review_news_identity_case(uuid,text,uuid,jsonb,text)
from public, anon;
grant execute on function public.admin_review_news_identity_case(uuid,text,uuid,jsonb,text)
to authenticated;
revoke all on function public.get_news_person_pair_state_at(uuid,uuid,timestamptz)
from public, anon;
grant execute on function public.get_news_person_pair_state_at(uuid,uuid,timestamptz)
to authenticated;

revoke all on function public.protect_news_identity_history_row()
from public, anon, authenticated;
revoke all on function public.protect_news_stable_identity()
from public, anon, authenticated;
revoke all on function public.protect_news_identity_version()
from public, anon, authenticated;
revoke all on function public.protect_news_person_pair_state_period()
from public, anon, authenticated;
revoke all on function public.protect_news_author_profile_identity()
from public, anon, authenticated;
revoke all on function public.protect_news_contributor_profile_identity()
from public, anon, authenticated;
revoke all on function public.validate_news_identity_evidence()
from public, anon, authenticated;
revoke all on function private.news_person_has_publisher_identity(uuid,uuid)
from public, anon, authenticated;
revoke all on function private.news_bridge_connects_person_to_publisher(uuid,uuid,uuid)
from public, anon, authenticated;
revoke all on function private.news_bridge_connects_people(uuid,uuid,uuid)
from public, anon, authenticated;
revoke all on function private.set_news_person_pair_state(uuid,uuid,text,uuid,uuid)
from public, anon, authenticated;
revoke all on function private.snapshot_news_identity_decision_evidence(uuid,uuid)
from public, anon, authenticated;
revoke all on function private.evaluate_news_identity_case(uuid)
from public, anon, authenticated;
revoke all on function private.evaluate_news_identity_case_on_evidence()
from public, anon, authenticated;

comment on table public.catalog_people is
  'Persistent non-Auth human identities. Names are mutable facts; fan profiles and operational actors are separate populations.';
comment on table public.news_organizational_contributors is
  'Newsrooms, staff desks, wire organizations, and official organizations. These identities are never represented as people.';
comment on table public.podcast_shows is
  'Persistent podcast Show identities independent of host, contributor, publisher, and network changes.';
comment on table public.news_publisher_policy_versions is
  'News-specific publisher availability policy. trusted_sources governance status, tiers, applicability, and ownership never populate this table automatically.';
comment on table public.news_person_pair_state_periods is
  'Point-in-time distinct, ambiguous, or merged state for a person pair, including the recorded canonical identity during merged periods.';
comment on view public.news_identity_review_read_model is
  'Staff-only question-oriented identity Resolution queue with candidates, public evidence, affiliations, and immutable decision history.';

commit;
