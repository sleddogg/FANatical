-- FANatical News Phase 3: canonical News Item/work identity, manifestations,
-- destinations, attribution, factual classification, reversible dedupe, and
-- staff-governed publication history. This migration deliberately creates no
-- fetch runtime, queue, monitoring, fan follow, personalized feed, discussion,
-- rating, reaction, poll, notification, or publisher view-count behavior.

begin;

-- ---------------------------------------------------------------------------
-- Governed content evidence and immutable action provenance
-- ---------------------------------------------------------------------------

create table public.news_content_evidence_kinds (
  evidence_kind text primary key
    check (evidence_kind ~ '^[a-z0-9]+(?:_[a-z0-9]+)*$'),
  display_name text not null check (length(btrim(display_name)) > 0),
  description text not null check (length(btrim(description)) > 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.news_content_evidence_kinds(
  evidence_kind, display_name, description
)
values
  (
    'source_publication_time',
    'Source publication time',
    'Public source evidence establishing the publisher-supplied publication timestamp.'
  ),
  (
    'manifestation_identity',
    'Manifestation identity',
    'Public source evidence establishing a particular published copy or manifestation.'
  ),
  (
    'factual_classification',
    'Factual classification',
    'Public evidence supporting a Sport, Competition, Competition Edition, or Team classification.'
  ),
  (
    'dedupe_relationship',
    'Dedupe relationship',
    'Public evidence supporting whether copies share a work or remain independent journalism.'
  ),
  (
    'representative_destination',
    'Representative destination',
    'Public evidence supporting the explicitly selected destination for a News Item.'
  ),
  (
    'remote_preview_reference',
    'Remote preview reference',
    'Public source evidence for a remotely referenced preview asset.'
  );

create table public.news_content_decisions (
  id uuid primary key default gen_random_uuid(),
  decision_id text not null unique default (
    'news-content-decision-' || replace(gen_random_uuid()::text, '-', '')
  ) check (decision_id ~ '^news-content-decision-[0-9a-f]{32}$'),
  action text not null check (action in (
    'record_evidence',
    'create_item', 'revise_item',
    'create_manifestation', 'add_manifestation_url',
    'assign_manifestation', 'unassign_manifestation',
    'set_representative_destination',
    'record_byline', 'resolve_byline',
    'record_classification', 'correct_classification',
    'record_dedupe', 'revise_dedupe',
    'record_remote_preview', 'revise_remote_preview_policy',
    'open_content_review', 'review_content_case'
  )),
  decision_origin text not null check (decision_origin in ('staff', 'automation')),
  decided_by_user_id uuid references auth.users(id),
  decided_by_actor_id uuid references public.catalog_actors(id),
  source_publisher_id uuid references public.trusted_sources(id),
  notes text,
  decided_at timestamptz not null default clock_timestamp(),
  check (
    (decision_origin = 'staff' and decided_by_user_id is not null)
    or (decision_origin = 'automation' and decided_by_actor_id is not null)
  )
);

comment on table public.news_content_decisions is
  'Immutable provenance shared by controlled staff writes and any future governed automated caller. Phase 3 creates staff callers only.';

create table public.news_content_evidence (
  id uuid primary key default gen_random_uuid(),
  evidence_id text not null unique default (
    'news-content-evidence-' || replace(gen_random_uuid()::text, '-', '')
  ) check (evidence_id ~ '^news-content-evidence-[0-9a-f]{32}$'),
  evidence_kind text not null
    references public.news_content_evidence_kinds(evidence_kind),
  evidence_url text not null
    check (evidence_url ~* '^https://[^[:space:]]+$'),
  publisher_source_id uuid not null references public.trusted_sources(id),
  source_url_scope_version_id uuid not null
    references public.trusted_source_url_scope_versions(id),
  evidence_summary text not null check (length(btrim(evidence_summary)) > 0),
  observed_at timestamptz not null,
  recorded_by_decision_id uuid not null references public.news_content_decisions(id),
  created_at timestamptz not null default now()
);

create index news_content_evidence_publisher_observed_idx
on public.news_content_evidence(publisher_source_id, observed_at desc);

create table public.news_content_decision_evidence (
  decision_id uuid not null references public.news_content_decisions(id),
  evidence_id uuid not null references public.news_content_evidence(id),
  created_at timestamptz not null default now(),
  primary key (decision_id, evidence_id)
);

-- ---------------------------------------------------------------------------
-- Stable News Item identity and append-only factual/publication versions
-- ---------------------------------------------------------------------------

create table public.news_items (
  id uuid primary key default gen_random_uuid(),
  news_item_id text not null unique default (
    'news-item-' || replace(gen_random_uuid()::text, '-', '')
  ) check (news_item_id ~ '^news-item-[0-9a-f]{32}$'),
  item_kind text not null check (item_kind in ('written', 'podcast_episode')),
  created_by_decision_id uuid not null references public.news_content_decisions(id),
  created_at timestamptz not null default now()
);

create table public.news_item_versions (
  id uuid primary key default gen_random_uuid(),
  news_item_id uuid not null references public.news_items(id),
  version_number integer not null check (version_number > 0),
  headline text not null check (length(btrim(headline)) > 0),
  summary text check (summary is null or length(btrim(summary)) > 0),
  publication_state text not null check (publication_state in (
    'draft', 'published', 'excluded', 'suppressed', 'needs_review'
  )),
  publication_time timestamptz,
  publication_time_evidence_id uuid references public.news_content_evidence(id),
  recorded_from timestamptz not null,
  recorded_to timestamptz,
  is_current boolean not null default true,
  decision_id uuid not null references public.news_content_decisions(id),
  supersedes_version_id uuid references public.news_item_versions(id),
  superseded_at timestamptz,
  closed_by_decision_id uuid references public.news_content_decisions(id),
  created_at timestamptz not null default now(),
  unique (news_item_id, version_number),
  check (recorded_to is null or recorded_to >= recorded_from),
  check (
    (publication_time is null and publication_time_evidence_id is null)
    or (publication_time is not null and publication_time_evidence_id is not null)
  ),
  check (
    publication_state <> 'published'
    or (publication_time is not null and publication_time_evidence_id is not null)
  )
);

create unique index news_item_versions_current_idx
on public.news_item_versions(news_item_id) where is_current;
create index news_item_versions_publication_idx
on public.news_item_versions(publication_state, publication_time desc, news_item_id)
where is_current;

create table public.news_podcast_episodes (
  news_item_id uuid primary key references public.news_items(id),
  show_id uuid not null references public.podcast_shows(id),
  episode_identifier text,
  created_by_decision_id uuid not null references public.news_content_decisions(id),
  created_at timestamptz not null default now(),
  check (episode_identifier is null or length(btrim(episode_identifier)) > 0)
);

-- ---------------------------------------------------------------------------
-- Manifestations and their URLs remain distinct from the underlying work
-- ---------------------------------------------------------------------------

create table public.news_manifestations (
  id uuid primary key default gen_random_uuid(),
  manifestation_id text not null unique default (
    'news-manifestation-' || replace(gen_random_uuid()::text, '-', '')
  ) check (manifestation_id ~ '^news-manifestation-[0-9a-f]{32}$'),
  publisher_source_id uuid not null references public.trusted_sources(id),
  manifestation_kind text not null check (manifestation_kind in (
    'written_article', 'syndicated_article',
    'podcast_episode_page', 'podcast_audio', 'other_public_copy'
  )),
  first_observed_at timestamptz not null,
  source_reference text,
  primary_evidence_id uuid not null references public.news_content_evidence(id),
  created_by_decision_id uuid not null references public.news_content_decisions(id),
  created_at timestamptz not null default now(),
  check (source_reference is null or length(btrim(source_reference)) > 0)
);

create index news_manifestations_publisher_observed_idx
on public.news_manifestations(publisher_source_id, first_observed_at desc);

create table public.news_manifestation_urls (
  id uuid primary key default gen_random_uuid(),
  manifestation_url_id text not null unique default (
    'news-url-' || replace(gen_random_uuid()::text, '-', '')
  ) check (manifestation_url_id ~ '^news-url-[0-9a-f]{32}$'),
  manifestation_id uuid not null references public.news_manifestations(id),
  url_kind text not null check (url_kind in (
    'canonical', 'alternate', 'redirect', 'wrapper'
  )),
  url text not null check (url ~* '^https://[^[:space:]]+$'),
  normalized_url text not null unique
    check (normalized_url ~* '^https://[^[:space:]]+$'),
  is_public_destination boolean not null default true,
  primary_evidence_id uuid not null references public.news_content_evidence(id),
  created_by_decision_id uuid not null references public.news_content_decisions(id),
  created_at timestamptz not null default now()
);

create index news_manifestation_urls_manifestation_idx
on public.news_manifestation_urls(manifestation_id, url_kind, created_at);

create table public.news_manifestation_assignment_versions (
  id uuid primary key default gen_random_uuid(),
  manifestation_id uuid not null references public.news_manifestations(id),
  news_item_id uuid not null references public.news_items(id),
  recorded_from timestamptz not null,
  recorded_to timestamptz,
  is_current boolean not null default true,
  primary_evidence_id uuid not null references public.news_content_evidence(id),
  decision_id uuid not null references public.news_content_decisions(id),
  supersedes_assignment_id uuid references public.news_manifestation_assignment_versions(id),
  superseded_at timestamptz,
  closed_by_decision_id uuid references public.news_content_decisions(id),
  created_at timestamptz not null default now(),
  check (recorded_to is null or recorded_to >= recorded_from)
);

create unique index news_manifestation_assignment_current_idx
on public.news_manifestation_assignment_versions(manifestation_id)
where is_current;
create index news_manifestation_assignment_item_idx
on public.news_manifestation_assignment_versions(news_item_id, is_current);
create index news_manifestation_assignment_history_idx
on public.news_manifestation_assignment_versions(
  manifestation_id, recorded_from, recorded_to
);

create table public.news_representative_destination_versions (
  id uuid primary key default gen_random_uuid(),
  news_item_id uuid not null references public.news_items(id),
  manifestation_id uuid not null references public.news_manifestations(id),
  manifestation_url_id uuid not null references public.news_manifestation_urls(id),
  recorded_from timestamptz not null,
  recorded_to timestamptz,
  is_current boolean not null default true,
  primary_evidence_id uuid not null references public.news_content_evidence(id),
  decision_id uuid not null references public.news_content_decisions(id),
  supersedes_destination_id uuid references public.news_representative_destination_versions(id),
  superseded_at timestamptz,
  closed_by_decision_id uuid references public.news_content_decisions(id),
  created_at timestamptz not null default now(),
  check (recorded_to is null or recorded_to >= recorded_from)
);

create unique index news_representative_destination_current_idx
on public.news_representative_destination_versions(news_item_id)
where is_current;

-- ---------------------------------------------------------------------------
-- Raw visible attribution and Phase 2 identity Resolution pointers
-- ---------------------------------------------------------------------------

create table public.news_byline_mentions (
  id uuid primary key default gen_random_uuid(),
  manifestation_id uuid not null references public.news_manifestations(id),
  ordinal integer not null check (ordinal > 0),
  raw_attribution text not null check (length(raw_attribution) > 0),
  visible_profile_url text
    check (visible_profile_url is null or visible_profile_url ~* '^https://[^[:space:]]+$'),
  primary_evidence_id uuid not null references public.news_content_evidence(id),
  created_by_decision_id uuid not null references public.news_content_decisions(id),
  created_at timestamptz not null default now(),
  unique (manifestation_id, ordinal)
);

comment on column public.news_byline_mentions.raw_attribution is
  'Visible ordered attribution exactly as published; it is never rewritten after an identity change or merge.';

create table public.news_byline_resolution_versions (
  id uuid primary key default gen_random_uuid(),
  byline_mention_id uuid not null references public.news_byline_mentions(id),
  target_identity_type text not null check (target_identity_type in (
    'person', 'organization', 'show', 'publisher_profile'
  )),
  person_id uuid references public.catalog_people(id),
  organizational_contributor_id uuid references public.news_organizational_contributors(id),
  show_id uuid references public.podcast_shows(id),
  contributor_profile_id uuid references public.news_publisher_contributor_profiles(id),
  resolution_basis text not null check (resolution_basis in (
    'visible_public_attribution', 'identity_review'
  )),
  identity_resolution_decision_id uuid
    references public.news_identity_resolution_decisions(id),
  recorded_from timestamptz not null,
  recorded_to timestamptz,
  is_current boolean not null default true,
  decision_id uuid not null references public.news_content_decisions(id),
  supersedes_resolution_id uuid references public.news_byline_resolution_versions(id),
  superseded_at timestamptz,
  closed_by_decision_id uuid references public.news_content_decisions(id),
  created_at timestamptz not null default now(),
  check (recorded_to is null or recorded_to >= recorded_from),
  check (num_nonnulls(
    person_id, organizational_contributor_id, show_id, contributor_profile_id
  ) = 1),
  check (
    (target_identity_type = 'person' and person_id is not null)
    or (target_identity_type = 'organization' and organizational_contributor_id is not null)
    or (target_identity_type = 'show' and show_id is not null)
    or (target_identity_type = 'publisher_profile' and contributor_profile_id is not null)
  ),
  check (
    resolution_basis <> 'identity_review'
    or identity_resolution_decision_id is not null
  )
);

create unique index news_byline_resolution_current_idx
on public.news_byline_resolution_versions(byline_mention_id)
where is_current;

-- ---------------------------------------------------------------------------
-- Factual classification only. Presentation/filter groups have no target
-- column or foreign key here and therefore cannot become article facts.
-- ---------------------------------------------------------------------------

create table public.news_item_classifications (
  id uuid primary key default gen_random_uuid(),
  classification_id text not null unique default (
    'news-classification-' || replace(gen_random_uuid()::text, '-', '')
  ) check (classification_id ~ '^news-classification-[0-9a-f]{32}$'),
  news_item_id uuid not null references public.news_items(id),
  created_by_decision_id uuid not null references public.news_content_decisions(id),
  created_at timestamptz not null default now()
);

create index news_item_classifications_item_idx
on public.news_item_classifications(news_item_id);

create table public.news_item_classification_versions (
  id uuid primary key default gen_random_uuid(),
  classification_id uuid not null references public.news_item_classifications(id),
  target_type text not null check (target_type in (
    'sport', 'competition', 'competition_edition', 'team'
  )),
  sport_id uuid references public.catalog_sports(id),
  competition_id uuid references public.catalog_competitions(id),
  competition_edition_id uuid references public.catalog_competition_editions(id),
  team_id uuid references public.catalog_teams(id),
  recorded_from timestamptz not null,
  recorded_to timestamptz,
  is_current boolean not null default true,
  primary_evidence_id uuid not null references public.news_content_evidence(id),
  decision_id uuid not null references public.news_content_decisions(id),
  supersedes_classification_version_id uuid
    references public.news_item_classification_versions(id),
  superseded_at timestamptz,
  closed_by_decision_id uuid references public.news_content_decisions(id),
  created_at timestamptz not null default now(),
  check (recorded_to is null or recorded_to >= recorded_from),
  check (num_nonnulls(
    sport_id, competition_id, competition_edition_id, team_id
  ) = 1),
  check (
    (target_type = 'sport' and sport_id is not null)
    or (target_type = 'competition' and competition_id is not null)
    or (target_type = 'competition_edition' and competition_edition_id is not null)
    or (target_type = 'team' and team_id is not null)
  )
);

create unique index news_item_classification_current_idx
on public.news_item_classification_versions(classification_id)
where is_current;

-- ---------------------------------------------------------------------------
-- Reversible manifestation dedupe decisions
-- ---------------------------------------------------------------------------

create table public.news_deduplication_cases (
  id uuid primary key default gen_random_uuid(),
  deduplication_case_id text not null unique default (
    'news-dedupe-case-' || replace(gen_random_uuid()::text, '-', '')
  ) check (deduplication_case_id ~ '^news-dedupe-case-[0-9a-f]{32}$'),
  manifestation_a_id uuid not null references public.news_manifestations(id),
  manifestation_b_id uuid not null references public.news_manifestations(id),
  created_by_decision_id uuid not null references public.news_content_decisions(id),
  created_at timestamptz not null default now(),
  check (manifestation_a_id::text < manifestation_b_id::text),
  unique (manifestation_a_id, manifestation_b_id)
);

create table public.news_deduplication_decision_versions (
  id uuid primary key default gen_random_uuid(),
  deduplication_case_id uuid not null references public.news_deduplication_cases(id),
  outcome text not null check (outcome in (
    'syndicated_copy', 'independent_journalism', 'needs_review'
  )),
  rationale text not null check (length(btrim(rationale)) > 0),
  recorded_from timestamptz not null,
  recorded_to timestamptz,
  is_current boolean not null default true,
  primary_evidence_id uuid not null references public.news_content_evidence(id),
  decision_id uuid not null references public.news_content_decisions(id),
  supersedes_deduplication_version_id uuid
    references public.news_deduplication_decision_versions(id),
  superseded_at timestamptz,
  closed_by_decision_id uuid references public.news_content_decisions(id),
  created_at timestamptz not null default now(),
  check (recorded_to is null or recorded_to >= recorded_from)
);

create unique index news_deduplication_decision_current_idx
on public.news_deduplication_decision_versions(deduplication_case_id)
where is_current;

-- ---------------------------------------------------------------------------
-- Remote preview references only; no copied body or canonical article media
-- ---------------------------------------------------------------------------

create table public.news_remote_preview_references (
  id uuid primary key default gen_random_uuid(),
  preview_reference_id text not null unique default (
    'news-preview-' || replace(gen_random_uuid()::text, '-', '')
  ) check (preview_reference_id ~ '^news-preview-[0-9a-f]{32}$'),
  manifestation_id uuid not null references public.news_manifestations(id),
  preview_kind text not null check (preview_kind in ('image', 'audio_artwork')),
  remote_url text not null check (remote_url ~* '^https://[^[:space:]]+$'),
  alt_text text,
  created_by_decision_id uuid not null references public.news_content_decisions(id),
  created_at timestamptz not null default now(),
  unique (manifestation_id, remote_url),
  check (alt_text is null or length(btrim(alt_text)) > 0)
);

create index news_remote_preview_references_manifestation_idx
on public.news_remote_preview_references(manifestation_id, created_at, id);

create table public.news_remote_preview_policy_versions (
  id uuid primary key default gen_random_uuid(),
  preview_reference_id uuid not null references public.news_remote_preview_references(id),
  publisher_policy_state text not null check (publisher_policy_state in (
    'approved', 'pending_review', 'blocked'
  )),
  primary_evidence_id uuid not null references public.news_content_evidence(id),
  recorded_from timestamptz not null,
  recorded_to timestamptz,
  is_current boolean not null default true,
  decision_id uuid not null references public.news_content_decisions(id),
  supersedes_policy_version_id uuid references public.news_remote_preview_policy_versions(id),
  superseded_at timestamptz,
  closed_by_decision_id uuid references public.news_content_decisions(id),
  created_at timestamptz not null default now(),
  check (recorded_to is null or recorded_to >= recorded_from)
);

create unique index news_remote_preview_policy_current_idx
on public.news_remote_preview_policy_versions(preview_reference_id)
where is_current;
create index news_remote_preview_policy_state_idx
on public.news_remote_preview_policy_versions(publisher_policy_state, is_current);

comment on table public.news_remote_preview_references is
  'Stable remote-preview reference identities. Publisher policy is append-only version history; FANatical does not store third-party article bodies or copy these assets as canonical article media.';
comment on table public.news_remote_preview_policy_versions is
  'Governed current and historical remote-preview policy. Only a current approved version may be exposed by canonical reads.';

-- ---------------------------------------------------------------------------
-- Question-oriented News content review, separate from identity Resolution
-- ---------------------------------------------------------------------------

create table public.news_content_review_case_types (
  case_type text primary key
    check (case_type ~ '^[a-z0-9]+(?:_[a-z0-9]+)*$'),
  display_name text not null check (length(btrim(display_name)) > 0),
  description text not null check (length(btrim(description)) > 0),
  active boolean not null default true
);

insert into public.news_content_review_case_types(case_type, display_name, description)
values
  ('publication_time', 'Publication time', 'Missing or conflicting source publication time.'),
  ('dedupe', 'Dedupe', 'Ambiguous manifestation/work relationship.'),
  ('classification', 'Classification', 'Unresolved factual classification.'),
  ('attribution', 'Attribution', 'Content attribution question requiring staff review.'),
  ('destination', 'Destination', 'Representative public destination question.'),
  ('publication_policy', 'Publication policy', 'News publication-state or policy question.');

create table public.news_content_review_cases (
  id uuid primary key default gen_random_uuid(),
  review_case_id text not null unique default (
    'news-content-case-' || replace(gen_random_uuid()::text, '-', '')
  ) check (review_case_id ~ '^news-content-case-[0-9a-f]{32}$'),
  case_type text not null references public.news_content_review_case_types(case_type),
  news_item_id uuid references public.news_items(id),
  manifestation_id uuid references public.news_manifestations(id),
  status text not null default 'open' check (status in (
    'open', 'resolved', 'insufficient_evidence', 'dismissed'
  )),
  unresolved_question text not null check (length(btrim(unresolved_question)) > 0),
  context jsonb not null default '{}'::jsonb,
  opened_by_decision_id uuid not null references public.news_content_decisions(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (num_nonnulls(news_item_id, manifestation_id) >= 1)
);

create index news_content_review_queue_idx
on public.news_content_review_cases(status, case_type, created_at);

create table public.news_content_review_decisions (
  id uuid primary key default gen_random_uuid(),
  review_case_id uuid not null references public.news_content_review_cases(id),
  action text not null check (action in (
    'resolve', 'insufficient_evidence', 'reopen', 'dismiss'
  )),
  question_snapshot text not null,
  action_payload_snapshot jsonb not null default '{}'::jsonb,
  notes text,
  decided_by_user_id uuid not null references auth.users(id),
  content_decision_id uuid not null references public.news_content_decisions(id),
  supersedes_review_decision_id uuid references public.news_content_review_decisions(id),
  decided_at timestamptz not null default clock_timestamp()
);

-- ---------------------------------------------------------------------------
-- History and cross-record integrity triggers
-- ---------------------------------------------------------------------------

create or replace function public.protect_news_content_history_row()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'News content evidence, decisions, and observed facts are append-only';
end;
$$;

create or replace function public.protect_news_content_stable_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
declare field_index integer;
begin
  if tg_op = 'DELETE' then
    raise exception 'Persistent News content identities cannot be deleted';
  end if;
  if old.id is distinct from new.id then
    raise exception 'Persistent News content identities are immutable';
  end if;
  if tg_nargs > 0 then
    for field_index in 0..tg_nargs - 1 loop
      if (to_jsonb(old) ->> tg_argv[field_index])
         is distinct from (to_jsonb(new) ->> tg_argv[field_index]) then
        raise exception 'Persistent News content identities and parent relationships are immutable';
      end if;
    end loop;
  end if;
  return new;
end;
$$;

create or replace function public.protect_news_content_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'News content version history cannot be deleted';
  end if;
  if old.is_current = false
     or new.is_current = true
     or new.recorded_to is null
     or new.superseded_at is null
     or new.closed_by_decision_id is null then
    raise exception 'News content versions may only transition from current to superseded';
  end if;
  if (to_jsonb(old)
        - 'is_current' - 'recorded_to' - 'superseded_at' - 'closed_by_decision_id')
     is distinct from
     (to_jsonb(new)
        - 'is_current' - 'recorded_to' - 'superseded_at' - 'closed_by_decision_id') then
    raise exception 'Historical News content facts cannot be overwritten';
  end if;
  return new;
end;
$$;

create or replace function public.protect_news_content_review_case()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'News content review cases cannot be deleted';
  end if;
  if (to_jsonb(old) - 'status' - 'updated_at' - 'resolved_at')
     is distinct from
     (to_jsonb(new) - 'status' - 'updated_at' - 'resolved_at') then
    raise exception 'News content review identity and question history cannot be overwritten';
  end if;
  return new;
end;
$$;

create or replace function public.validate_news_podcast_episode()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.news_items item
    where item.id = new.news_item_id and item.item_kind = 'podcast_episode'
  ) then
    raise exception 'Podcast episode details require a podcast_episode News Item';
  end if;
  return new;
end;
$$;

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
  ) then
    raise exception 'Representative destination must be a public URL on the selected manifestation';
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

create or replace function private.lock_news_manifestation_pair(
  manifestation_one_id_value uuid,
  manifestation_two_id_value uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare locked_manifestation_count integer;
begin
  with locked as (
    select manifestation.id
    from public.news_manifestations manifestation
    where manifestation.id in (
      manifestation_one_id_value, manifestation_two_id_value
    )
    order by manifestation.id
    for update
  )
  select count(*) into locked_manifestation_count from locked;
  if locked_manifestation_count <> 2 then
    raise exception 'Both News manifestations must exist';
  end if;
end;
$$;

create or replace function private.lock_news_manifestation_dedupe_scope(
  manifestation_id_value uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform manifestation.id
  from public.news_manifestations manifestation
  where manifestation.id = manifestation_id_value
     or exists (
       select 1
       from public.news_deduplication_cases dedupe_case
       where (
         dedupe_case.manifestation_a_id = manifestation_id_value
         and dedupe_case.manifestation_b_id = manifestation.id
       ) or (
         dedupe_case.manifestation_b_id = manifestation_id_value
         and dedupe_case.manifestation_a_id = manifestation.id
       )
     )
  order by manifestation.id
  for update;
end;
$$;

create or replace function private.lock_news_deduplication_case(
  deduplication_case_id_value uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  manifestation_a_uuid uuid;
  manifestation_b_uuid uuid;
begin
  select dedupe_case.manifestation_a_id, dedupe_case.manifestation_b_id
  into strict manifestation_a_uuid, manifestation_b_uuid
  from public.news_deduplication_cases dedupe_case
  where dedupe_case.id = deduplication_case_id_value;
  perform private.lock_news_manifestation_pair(
    manifestation_a_uuid, manifestation_b_uuid
  );
end;
$$;

create or replace function private.assert_news_dedupe_assignment_consistency(
  deduplication_case_id_value uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  outcome_value text;
  manifestation_a_item_id uuid;
  manifestation_b_item_id uuid;
begin
  select
    version.outcome,
    assignment_a.news_item_id,
    assignment_b.news_item_id
  into outcome_value, manifestation_a_item_id, manifestation_b_item_id
  from public.news_deduplication_cases dedupe_case
  join public.news_deduplication_decision_versions version
    on version.deduplication_case_id = dedupe_case.id
   and version.is_current
  left join public.news_manifestation_assignment_versions assignment_a
    on assignment_a.manifestation_id = dedupe_case.manifestation_a_id
   and assignment_a.is_current
  left join public.news_manifestation_assignment_versions assignment_b
    on assignment_b.manifestation_id = dedupe_case.manifestation_b_id
   and assignment_b.is_current
  where dedupe_case.id = deduplication_case_id_value;

  if not found then
    return;
  end if;

  if outcome_value = 'syndicated_copy'
     and manifestation_a_item_id is not null
     and manifestation_b_item_id is not null
     and manifestation_a_item_id is distinct from manifestation_b_item_id then
    raise exception 'Syndicated-copy manifestations cannot be assigned to different News Items';
  end if;

  if outcome_value in ('independent_journalism', 'needs_review')
     and manifestation_a_item_id is not null
     and manifestation_a_item_id is not distinct from manifestation_b_item_id then
    raise exception '% manifestations cannot be assigned to the same News Item',
      replace(outcome_value, '_', '-');
  end if;
end;
$$;

create or replace function private.assert_news_dedupe_assignment_consistency_for_manifestation(
  manifestation_id_value uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare deduplication_case_uuid uuid;
begin
  for deduplication_case_uuid in
    select dedupe_case.id
    from public.news_deduplication_cases dedupe_case
    where dedupe_case.manifestation_a_id = manifestation_id_value
       or dedupe_case.manifestation_b_id = manifestation_id_value
    order by dedupe_case.id
  loop
    perform private.assert_news_dedupe_assignment_consistency(
      deduplication_case_uuid
    );
  end loop;
end;
$$;

create or replace function public.validate_news_dedupe_assignment_consistency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'news_deduplication_decision_versions' then
    perform private.lock_news_deduplication_case(
      coalesce(new.deduplication_case_id, old.deduplication_case_id)
    );
    perform private.assert_news_dedupe_assignment_consistency(
      coalesce(new.deduplication_case_id, old.deduplication_case_id)
    );
  elsif tg_table_name = 'news_manifestation_assignment_versions' then
    perform private.lock_news_manifestation_dedupe_scope(
      coalesce(new.manifestation_id, old.manifestation_id)
    );
    perform private.assert_news_dedupe_assignment_consistency_for_manifestation(
      coalesce(new.manifestation_id, old.manifestation_id)
    );
  else
    raise exception 'Unsupported News dedupe/assignment consistency trigger table';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger news_items_protect_identity
before update or delete on public.news_items
for each row execute function public.protect_news_content_stable_identity(
  'news_item_id', 'item_kind'
);
create trigger news_manifestations_protect_identity
before update or delete on public.news_manifestations
for each row execute function public.protect_news_content_stable_identity(
  'manifestation_id', 'publisher_source_id'
);
create trigger news_classifications_protect_identity
before update or delete on public.news_item_classifications
for each row execute function public.protect_news_content_stable_identity(
  'classification_id', 'news_item_id'
);
create trigger news_deduplication_cases_protect_identity
before update or delete on public.news_deduplication_cases
for each row execute function public.protect_news_content_stable_identity(
  'deduplication_case_id', 'manifestation_a_id', 'manifestation_b_id'
);

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'news_item_versions',
    'news_manifestation_assignment_versions',
    'news_representative_destination_versions',
    'news_byline_resolution_versions',
    'news_item_classification_versions',
    'news_deduplication_decision_versions',
    'news_remote_preview_policy_versions'
  ] loop
    execute format(
      'create trigger protect_news_content_version before update or delete on public.%I for each row execute function public.protect_news_content_version()',
      table_name
    );
  end loop;

  foreach table_name in array array[
    'news_content_decisions',
    'news_content_evidence',
    'news_content_decision_evidence',
    'news_podcast_episodes',
    'news_manifestation_urls',
    'news_byline_mentions',
    'news_remote_preview_references',
    'news_content_review_decisions'
  ] loop
    execute format(
      'create trigger protect_news_content_history before update or delete on public.%I for each row execute function public.protect_news_content_history_row()',
      table_name
    );
  end loop;
end $$;

create trigger validate_news_podcast_episode_on_insert
before insert on public.news_podcast_episodes
for each row execute function public.validate_news_podcast_episode();

create trigger validate_news_representative_destination_on_insert
before insert on public.news_representative_destination_versions
for each row execute function public.validate_news_representative_destination();

create trigger protect_news_content_review_case
before update or delete on public.news_content_review_cases
for each row execute function public.protect_news_content_review_case();

create constraint trigger validate_news_assignment_dedupe_consistency
after insert or update or delete on public.news_manifestation_assignment_versions
deferrable initially deferred
for each row execute function public.validate_news_dedupe_assignment_consistency();

create constraint trigger validate_news_dedupe_assignment_consistency
after insert or update or delete on public.news_deduplication_decision_versions
deferrable initially deferred
for each row execute function public.validate_news_dedupe_assignment_consistency();

-- ---------------------------------------------------------------------------
-- Private canonical helpers. Public staff RPCs and any future governed
-- automation wrapper share these provenance/evidence boundaries.
-- ---------------------------------------------------------------------------

create or replace function private.record_news_content_decision(
  action_value text,
  decision_origin_value text,
  decided_by_user_id_value uuid,
  decided_by_actor_id_value uuid,
  source_publisher_id_value uuid,
  notes_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare decision_uuid uuid := gen_random_uuid();
begin
  insert into public.news_content_decisions(
    id, action, decision_origin, decided_by_user_id, decided_by_actor_id,
    source_publisher_id, notes
  ) values (
    decision_uuid, action_value, decision_origin_value,
    decided_by_user_id_value, decided_by_actor_id_value,
    source_publisher_id_value, notes_value
  );
  return decision_uuid;
end;
$$;

create or replace function private.link_news_content_decision_evidence(
  decision_id_value uuid,
  evidence_id_value uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if evidence_id_value is null then
    return;
  end if;
  insert into public.news_content_decision_evidence(decision_id, evidence_id)
  values (decision_id_value, evidence_id_value)
  on conflict do nothing;
end;
$$;

create or replace function private.resolve_news_content_evidence_scope(
  evidence_url_value text,
  publisher_source_id_value uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  best_specificity integer;
  canonical_count integer;
  resolved_canonical_source_id uuid;
  expected_canonical_source_id uuid;
  scope_version_uuid uuid;
begin
  select max(match.specificity) into best_specificity
  from public.trusted_source_url_matches(evidence_url_value) match;

  if best_specificity is null then
    raise exception 'News content evidence URL is not owned by a registered publisher';
  end if;

  select
    count(distinct match.canonical_source_id),
    min(match.canonical_source_id::text)::uuid,
    min(match.url_scope_version_id::text)::uuid
  into canonical_count, resolved_canonical_source_id, scope_version_uuid
  from public.trusted_source_url_matches(evidence_url_value) match
  where match.specificity = best_specificity;

  if canonical_count <> 1 then
    raise exception 'News content evidence URL has ambiguous publisher ownership';
  end if;

  expected_canonical_source_id :=
    public.canonical_trusted_source_id(publisher_source_id_value);
  if expected_canonical_source_id is null
     or resolved_canonical_source_id is distinct from expected_canonical_source_id then
    raise exception 'News content evidence URL does not belong to the claimed publisher';
  end if;

  return scope_version_uuid;
end;
$$;

create or replace function private.require_news_content_evidence(
  evidence_id_value uuid,
  expected_evidence_kinds_value text[] default null,
  expected_publisher_source_id_value uuid default null
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  evidence_record public.news_content_evidence%rowtype;
begin
  select * into strict evidence_record
  from public.news_content_evidence
  where id = evidence_id_value;
  if expected_evidence_kinds_value is not null
     and not (evidence_record.evidence_kind = any(expected_evidence_kinds_value)) then
    raise exception 'News content evidence kind does not support this action';
  end if;
  if expected_publisher_source_id_value is not null
     and public.canonical_trusted_source_id(evidence_record.publisher_source_id)
         is distinct from
         public.canonical_trusted_source_id(expected_publisher_source_id_value) then
    raise exception 'News content evidence publisher does not match this action source';
  end if;
end;
$$;

create or replace function private.record_news_content_evidence_canonical(
  evidence_kind_value text,
  evidence_url_value text,
  publisher_source_id_value uuid,
  evidence_summary_value text,
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
  decision_uuid uuid;
  evidence_uuid uuid := gen_random_uuid();
  scope_version_uuid uuid;
begin
  perform 1 from public.news_content_evidence_kinds
  where evidence_kind = evidence_kind_value and active;
  if not found then raise exception 'News content evidence kind is not governed or active'; end if;
  if length(btrim(coalesce(evidence_summary_value, ''))) = 0 then
    raise exception 'News content evidence requires a summary';
  end if;
  scope_version_uuid := private.resolve_news_content_evidence_scope(
    evidence_url_value, publisher_source_id_value
  );
  decision_uuid := private.record_news_content_decision(
    'record_evidence', decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, publisher_source_id_value, notes_value
  );
  insert into public.news_content_evidence(
    id, evidence_kind, evidence_url, publisher_source_id,
    source_url_scope_version_id, evidence_summary, observed_at,
    recorded_by_decision_id
  ) values (
    evidence_uuid, evidence_kind_value, evidence_url_value,
    publisher_source_id_value, scope_version_uuid,
    evidence_summary_value, observed_at_value, decision_uuid
  );
  return evidence_uuid;
end;
$$;

create or replace function private.create_news_item_canonical(
  item_kind_value text,
  headline_value text,
  summary_value text,
  publication_state_value text,
  publication_time_value timestamptz,
  publication_time_evidence_id_value uuid,
  source_publisher_id_value uuid,
  show_id_value uuid,
  episode_identifier_value text,
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
  decision_uuid uuid;
  decision_at_value timestamptz;
  item_uuid uuid := gen_random_uuid();
begin
  if item_kind_value not in ('written', 'podcast_episode') then
    raise exception 'Unsupported News Item kind';
  end if;
  if item_kind_value = 'podcast_episode' and show_id_value is null then
    raise exception 'Podcast episode News Items require a Phase 2 Show';
  end if;
  if item_kind_value = 'written' and show_id_value is not null then
    raise exception 'Written News Items cannot carry podcast episode details';
  end if;
  if publication_time_evidence_id_value is not null then
    perform private.require_news_content_evidence(
      publication_time_evidence_id_value,
      array['source_publication_time']::text[],
      source_publisher_id_value
    );
  end if;
  decision_uuid := private.record_news_content_decision(
    'create_item', decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, source_publisher_id_value, notes_value
  );
  select decided_at into decision_at_value
  from public.news_content_decisions where id = decision_uuid;

  insert into public.news_items(id, item_kind, created_by_decision_id)
  values (item_uuid, item_kind_value, decision_uuid);
  insert into public.news_item_versions(
    news_item_id, version_number, headline, summary, publication_state,
    publication_time, publication_time_evidence_id, recorded_from, decision_id
  ) values (
    item_uuid, 1, headline_value, summary_value, publication_state_value,
    publication_time_value, publication_time_evidence_id_value,
    decision_at_value, decision_uuid
  );
  if item_kind_value = 'podcast_episode' then
    insert into public.news_podcast_episodes(
      news_item_id, show_id, episode_identifier, created_by_decision_id
    ) values (
      item_uuid, show_id_value, episode_identifier_value, decision_uuid
    );
  end if;
  perform private.link_news_content_decision_evidence(
    decision_uuid, publication_time_evidence_id_value
  );
  return item_uuid;
end;
$$;

create or replace function private.record_news_item_version_canonical(
  news_item_id_value uuid,
  headline_value text,
  summary_value text,
  publication_state_value text,
  publication_time_value timestamptz,
  publication_time_evidence_id_value uuid,
  source_publisher_id_value uuid,
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
  current_version public.news_item_versions%rowtype;
  decision_uuid uuid;
  decision_at_value timestamptz;
  new_version_uuid uuid := gen_random_uuid();
begin
  select * into strict current_version
  from public.news_item_versions
  where news_item_id = news_item_id_value and is_current
  for update;
  if publication_time_evidence_id_value is not null then
    perform private.require_news_content_evidence(
      publication_time_evidence_id_value,
      array['source_publication_time']::text[],
      source_publisher_id_value
    );
  end if;
  decision_uuid := private.record_news_content_decision(
    'revise_item', decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, source_publisher_id_value, notes_value
  );
  select decided_at into decision_at_value
  from public.news_content_decisions where id = decision_uuid;

  update public.news_item_versions
  set is_current = false,
      recorded_to = decision_at_value,
      superseded_at = decision_at_value,
      closed_by_decision_id = decision_uuid
  where id = current_version.id;

  insert into public.news_item_versions(
    id, news_item_id, version_number, headline, summary, publication_state,
    publication_time, publication_time_evidence_id, recorded_from,
    decision_id, supersedes_version_id
  ) values (
    new_version_uuid, news_item_id_value, current_version.version_number + 1,
    headline_value, summary_value, publication_state_value,
    publication_time_value, publication_time_evidence_id_value,
    decision_at_value, decision_uuid, current_version.id
  );
  perform private.link_news_content_decision_evidence(
    decision_uuid, publication_time_evidence_id_value
  );
  return new_version_uuid;
end;
$$;

create or replace function private.create_news_manifestation_canonical(
  publisher_source_id_value uuid,
  manifestation_kind_value text,
  first_observed_at_value timestamptz,
  source_reference_value text,
  primary_evidence_id_value uuid,
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
declare decision_uuid uuid; manifestation_uuid uuid := gen_random_uuid();
begin
  perform private.require_news_content_evidence(
    primary_evidence_id_value,
    array['manifestation_identity']::text[],
    publisher_source_id_value
  );
  decision_uuid := private.record_news_content_decision(
    'create_manifestation', decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, publisher_source_id_value, notes_value
  );
  insert into public.news_manifestations(
    id, publisher_source_id, manifestation_kind, first_observed_at,
    source_reference, primary_evidence_id, created_by_decision_id
  ) values (
    manifestation_uuid, publisher_source_id_value, manifestation_kind_value,
    first_observed_at_value, source_reference_value,
    primary_evidence_id_value, decision_uuid
  );
  perform private.link_news_content_decision_evidence(decision_uuid, primary_evidence_id_value);
  return manifestation_uuid;
end;
$$;

create or replace function private.add_news_manifestation_url_canonical(
  manifestation_id_value uuid,
  url_kind_value text,
  url_value text,
  is_public_destination_value boolean,
  primary_evidence_id_value uuid,
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
  manifestation_record public.news_manifestations%rowtype;
  decision_uuid uuid;
  url_uuid uuid := gen_random_uuid();
  normalized_url_value text;
begin
  select * into strict manifestation_record
  from public.news_manifestations where id = manifestation_id_value;
  perform private.require_news_content_evidence(
    primary_evidence_id_value,
    array['manifestation_identity']::text[],
    manifestation_record.publisher_source_id
  );
  normalized_url_value := public.normalize_source_url(url_value);
  if normalized_url_value !~* '^https://[^[:space:]]+$' then
    raise exception 'News manifestation URLs must use HTTPS';
  end if;
  decision_uuid := private.record_news_content_decision(
    'add_manifestation_url', decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, manifestation_record.publisher_source_id, notes_value
  );
  insert into public.news_manifestation_urls(
    id, manifestation_id, url_kind, url, normalized_url,
    is_public_destination, primary_evidence_id, created_by_decision_id
  ) values (
    url_uuid, manifestation_id_value, url_kind_value, url_value,
    normalized_url_value, is_public_destination_value,
    primary_evidence_id_value, decision_uuid
  );
  perform private.link_news_content_decision_evidence(decision_uuid, primary_evidence_id_value);
  return url_uuid;
end;
$$;

create or replace function private.assign_news_manifestation_canonical(
  manifestation_id_value uuid,
  news_item_id_value uuid,
  primary_evidence_id_value uuid,
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
  manifestation_record public.news_manifestations%rowtype;
  current_assignment public.news_manifestation_assignment_versions%rowtype;
  decision_uuid uuid;
  decision_at_value timestamptz;
  action_value text;
begin
  perform private.lock_news_manifestation_dedupe_scope(
    manifestation_id_value
  );
  select * into strict manifestation_record
  from public.news_manifestations
  where id = manifestation_id_value;
  if news_item_id_value is not null then
    perform 1 from public.news_items where id = news_item_id_value;
    if not found then raise exception 'News Item does not exist'; end if;
  end if;
  perform private.require_news_content_evidence(
    primary_evidence_id_value,
    array['manifestation_identity','dedupe_relationship']::text[],
    null
  );

  select * into current_assignment
  from public.news_manifestation_assignment_versions
  where manifestation_id = manifestation_id_value and is_current
  for update;

  if found and current_assignment.news_item_id is not distinct from news_item_id_value then
    raise exception 'Manifestation is already assigned to this News Item';
  end if;
  if not found and news_item_id_value is null then
    raise exception 'Manifestation is already unresolved';
  end if;
  if current_assignment.id is not null and exists (
    select 1 from public.news_representative_destination_versions destination
    where destination.news_item_id = current_assignment.news_item_id
      and destination.manifestation_id = manifestation_id_value
      and destination.is_current
  ) then
    raise exception 'Change the representative destination before reassigning its manifestation';
  end if;

  action_value := case when news_item_id_value is null
    then 'unassign_manifestation' else 'assign_manifestation' end;
  decision_uuid := private.record_news_content_decision(
    action_value, decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, manifestation_record.publisher_source_id, notes_value
  );
  select decided_at into decision_at_value
  from public.news_content_decisions where id = decision_uuid;

  if current_assignment.id is not null then
    update public.news_manifestation_assignment_versions
    set is_current = false,
        recorded_to = decision_at_value,
        superseded_at = decision_at_value,
        closed_by_decision_id = decision_uuid
    where id = current_assignment.id;
  end if;

  if news_item_id_value is not null then
    insert into public.news_manifestation_assignment_versions(
      manifestation_id, news_item_id, recorded_from, primary_evidence_id,
      decision_id, supersedes_assignment_id
    ) values (
      manifestation_id_value, news_item_id_value, decision_at_value,
      primary_evidence_id_value, decision_uuid, current_assignment.id
    );
  end if;
  perform private.link_news_content_decision_evidence(decision_uuid, primary_evidence_id_value);
  perform private.assert_news_dedupe_assignment_consistency_for_manifestation(
    manifestation_id_value
  );
  return decision_uuid;
end;
$$;

create or replace function private.record_news_classification_canonical(
  news_item_id_value uuid,
  classification_id_value uuid,
  target_type_value text,
  target_id_value uuid,
  primary_evidence_id_value uuid,
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
  classification_uuid uuid := classification_id_value;
  classification_record public.news_item_classifications%rowtype;
  current_version public.news_item_classification_versions%rowtype;
  decision_uuid uuid;
  decision_at_value timestamptz;
  action_value text;
  sport_uuid uuid;
  competition_uuid uuid;
  edition_uuid uuid;
  team_uuid uuid;
begin
  perform 1 from public.news_items where id = news_item_id_value;
  if not found then raise exception 'News Item does not exist'; end if;
  perform private.require_news_content_evidence(
    primary_evidence_id_value,
    array['factual_classification']::text[],
    null
  );

  if target_type_value = 'sport' then
    select id into strict sport_uuid from public.catalog_sports where id = target_id_value;
  elsif target_type_value = 'competition' then
    select id into strict competition_uuid from public.catalog_competitions where id = target_id_value;
  elsif target_type_value = 'competition_edition' then
    select id into strict edition_uuid from public.catalog_competition_editions where id = target_id_value;
  elsif target_type_value = 'team' then
    select id into strict team_uuid from public.catalog_teams where id = target_id_value;
  else
    raise exception 'Classification target must be Sport, Competition, Competition Edition, or Team';
  end if;

  if classification_uuid is null then
    action_value := 'record_classification';
    classification_uuid := gen_random_uuid();
  else
    action_value := 'correct_classification';
    select * into strict classification_record
    from public.news_item_classifications
    where id = classification_uuid and news_item_id = news_item_id_value;
    select * into strict current_version
    from public.news_item_classification_versions
    where classification_id = classification_uuid and is_current
    for update;
  end if;

  decision_uuid := private.record_news_content_decision(
    action_value, decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, null, notes_value
  );
  select decided_at into decision_at_value
  from public.news_content_decisions where id = decision_uuid;

  if classification_id_value is null then
    insert into public.news_item_classifications(
      id, news_item_id, created_by_decision_id
    ) values (classification_uuid, news_item_id_value, decision_uuid);
  else
    update public.news_item_classification_versions
    set is_current = false,
        recorded_to = decision_at_value,
        superseded_at = decision_at_value,
        closed_by_decision_id = decision_uuid
    where id = current_version.id;
  end if;

  insert into public.news_item_classification_versions(
    classification_id, target_type, sport_id, competition_id,
    competition_edition_id, team_id, recorded_from, primary_evidence_id,
    decision_id, supersedes_classification_version_id
  ) values (
    classification_uuid, target_type_value, sport_uuid, competition_uuid,
    edition_uuid, team_uuid, decision_at_value, primary_evidence_id_value,
    decision_uuid, current_version.id
  );
  perform private.link_news_content_decision_evidence(decision_uuid, primary_evidence_id_value);
  return classification_uuid;
end;
$$;

create or replace function private.record_news_deduplication_canonical(
  manifestation_one_id_value uuid,
  manifestation_two_id_value uuid,
  outcome_value text,
  primary_evidence_id_value uuid,
  rationale_value text,
  reconcile_manifestation_id_value uuid,
  reconcile_news_item_id_value uuid,
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
  manifestation_a_uuid uuid;
  manifestation_b_uuid uuid;
  dedupe_case public.news_deduplication_cases%rowtype;
  current_version public.news_deduplication_decision_versions%rowtype;
  publisher_source_uuid uuid;
  decision_uuid uuid;
  decision_at_value timestamptz;
  action_value text;
begin
  if manifestation_one_id_value = manifestation_two_id_value then
    raise exception 'Dedupe requires two different manifestations';
  end if;
  if outcome_value not in ('syndicated_copy', 'independent_journalism', 'needs_review') then
    raise exception 'Unsupported News dedupe outcome';
  end if;
  if length(btrim(coalesce(rationale_value, ''))) = 0 then
    raise exception 'News dedupe requires a rationale';
  end if;
  perform private.require_news_content_evidence(
    primary_evidence_id_value,
    array['dedupe_relationship']::text[],
    null
  );

  perform private.lock_news_manifestation_pair(
    manifestation_one_id_value, manifestation_two_id_value
  );

  if manifestation_one_id_value::text < manifestation_two_id_value::text then
    manifestation_a_uuid := manifestation_one_id_value;
    manifestation_b_uuid := manifestation_two_id_value;
  else
    manifestation_a_uuid := manifestation_two_id_value;
    manifestation_b_uuid := manifestation_one_id_value;
  end if;
  if reconcile_manifestation_id_value is not null
     and reconcile_manifestation_id_value not in (
       manifestation_a_uuid, manifestation_b_uuid
     ) then
    raise exception 'Dedupe reconciliation must target one of the case manifestations';
  end if;

  select publisher_source_id into publisher_source_uuid
  from public.news_manifestations where id = manifestation_a_uuid;

  select * into dedupe_case
  from public.news_deduplication_cases
  where manifestation_a_id = manifestation_a_uuid
    and manifestation_b_id = manifestation_b_uuid
  for update;
  action_value := case when found then 'revise_dedupe' else 'record_dedupe' end;

  if dedupe_case.id is not null then
    select * into strict current_version
    from public.news_deduplication_decision_versions
    where deduplication_case_id = dedupe_case.id and is_current
    for update;
  end if;

  decision_uuid := private.record_news_content_decision(
    action_value, decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, publisher_source_uuid, notes_value
  );
  select decided_at into decision_at_value
  from public.news_content_decisions where id = decision_uuid;

  if dedupe_case.id is null then
    dedupe_case.id := gen_random_uuid();
    insert into public.news_deduplication_cases(
      id, manifestation_a_id, manifestation_b_id, created_by_decision_id
    ) values (
      dedupe_case.id, manifestation_a_uuid, manifestation_b_uuid, decision_uuid
    );
  else
    update public.news_deduplication_decision_versions
    set is_current = false,
        recorded_to = decision_at_value,
        superseded_at = decision_at_value,
        closed_by_decision_id = decision_uuid
    where id = current_version.id;
  end if;

  insert into public.news_deduplication_decision_versions(
    deduplication_case_id, outcome, rationale, recorded_from,
    primary_evidence_id, decision_id, supersedes_deduplication_version_id
  ) values (
    dedupe_case.id, outcome_value, rationale_value, decision_at_value,
    primary_evidence_id_value, decision_uuid, current_version.id
  );
  perform private.link_news_content_decision_evidence(decision_uuid, primary_evidence_id_value);

  if reconcile_manifestation_id_value is not null then
    perform private.assign_news_manifestation_canonical(
      reconcile_manifestation_id_value, reconcile_news_item_id_value,
      primary_evidence_id_value, decision_origin_value,
      decided_by_user_id_value, decided_by_actor_id_value,
      'Atomic assignment reconciliation for governed dedupe: ' ||
        coalesce(notes_value, rationale_value)
    );
  end if;

  perform private.assert_news_dedupe_assignment_consistency(dedupe_case.id);
  return dedupe_case.id;
end;
$$;

create or replace function private.record_news_remote_preview_canonical(
  manifestation_id_value uuid,
  preview_kind_value text,
  remote_url_value text,
  publisher_policy_state_value text,
  alt_text_value text,
  primary_evidence_id_value uuid,
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
  publisher_source_uuid uuid;
  decision_uuid uuid;
  decision_at_value timestamptz;
  preview_uuid uuid := gen_random_uuid();
begin
  select publisher_source_id into strict publisher_source_uuid
  from public.news_manifestations
  where id = manifestation_id_value
  for update;
  perform private.require_news_content_evidence(
    primary_evidence_id_value,
    array['remote_preview_reference']::text[],
    publisher_source_uuid
  );
  decision_uuid := private.record_news_content_decision(
    'record_remote_preview', decision_origin_value, decided_by_user_id_value,
    decided_by_actor_id_value, publisher_source_uuid, notes_value
  );
  select decided_at into decision_at_value
  from public.news_content_decisions where id = decision_uuid;
  insert into public.news_remote_preview_references(
    id, manifestation_id, preview_kind, remote_url, alt_text,
    created_by_decision_id
  ) values (
    preview_uuid, manifestation_id_value, preview_kind_value,
    remote_url_value, alt_text_value, decision_uuid
  );
  insert into public.news_remote_preview_policy_versions(
    preview_reference_id, publisher_policy_state,
    primary_evidence_id, recorded_from, decision_id
  ) values (
    preview_uuid, publisher_policy_state_value,
    primary_evidence_id_value, decision_at_value, decision_uuid
  );
  perform private.link_news_content_decision_evidence(decision_uuid, primary_evidence_id_value);
  return preview_uuid;
end;
$$;

create or replace function private.set_news_remote_preview_policy_canonical(
  preview_reference_id_value uuid,
  publisher_policy_state_value text,
  primary_evidence_id_value uuid,
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
  preview_record public.news_remote_preview_references%rowtype;
  current_policy public.news_remote_preview_policy_versions%rowtype;
  publisher_source_uuid uuid;
  decision_uuid uuid;
  decision_at_value timestamptz;
  new_policy_uuid uuid := gen_random_uuid();
begin
  select preview.* into strict preview_record
  from public.news_remote_preview_references preview
  where preview.id = preview_reference_id_value
  for update;
  select manifestation.publisher_source_id into strict publisher_source_uuid
  from public.news_manifestations manifestation
  where manifestation.id = preview_record.manifestation_id;
  select * into strict current_policy
  from public.news_remote_preview_policy_versions
  where preview_reference_id = preview_reference_id_value and is_current
  for update;
  if current_policy.publisher_policy_state = publisher_policy_state_value then
    raise exception 'Remote preview already has this current publisher policy state';
  end if;
  perform private.require_news_content_evidence(
    primary_evidence_id_value,
    array['remote_preview_reference']::text[],
    publisher_source_uuid
  );
  decision_uuid := private.record_news_content_decision(
    'revise_remote_preview_policy', decision_origin_value,
    decided_by_user_id_value, decided_by_actor_id_value,
    publisher_source_uuid, notes_value
  );
  select decided_at into decision_at_value
  from public.news_content_decisions where id = decision_uuid;

  update public.news_remote_preview_policy_versions
  set is_current = false,
      recorded_to = decision_at_value,
      superseded_at = decision_at_value,
      closed_by_decision_id = decision_uuid
  where id = current_policy.id;

  insert into public.news_remote_preview_policy_versions(
    id, preview_reference_id, publisher_policy_state, primary_evidence_id,
    recorded_from, decision_id, supersedes_policy_version_id
  ) values (
    new_policy_uuid, preview_reference_id_value,
    publisher_policy_state_value, primary_evidence_id_value,
    decision_at_value, decision_uuid, current_policy.id
  );
  perform private.link_news_content_decision_evidence(decision_uuid, primary_evidence_id_value);
  return new_policy_uuid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Governed staff write path
-- ---------------------------------------------------------------------------

create or replace function public.admin_record_news_content_evidence(
  evidence_kind_value text,
  evidence_url_value text,
  publisher_source_id_value uuid,
  evidence_summary_value text,
  observed_at_value timestamptz,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  return private.record_news_content_evidence_canonical(
    evidence_kind_value, evidence_url_value, publisher_source_id_value,
    evidence_summary_value, observed_at_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

create or replace function public.admin_create_news_item(
  item_kind_value text,
  headline_value text,
  summary_value text,
  publication_state_value text,
  publication_time_value timestamptz,
  publication_time_evidence_id_value uuid,
  source_publisher_id_value uuid,
  show_id_value uuid,
  episode_identifier_value text,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  return private.create_news_item_canonical(
    item_kind_value, headline_value, summary_value, publication_state_value,
    publication_time_value, publication_time_evidence_id_value,
    source_publisher_id_value, show_id_value, episode_identifier_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

create or replace function public.admin_record_news_item_version(
  news_item_id_value uuid,
  headline_value text,
  summary_value text,
  publication_state_value text,
  publication_time_value timestamptz,
  publication_time_evidence_id_value uuid,
  source_publisher_id_value uuid,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  return private.record_news_item_version_canonical(
    news_item_id_value, headline_value, summary_value,
    publication_state_value, publication_time_value,
    publication_time_evidence_id_value, source_publisher_id_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

create or replace function public.admin_create_news_manifestation(
  publisher_source_id_value uuid,
  manifestation_kind_value text,
  first_observed_at_value timestamptz,
  source_reference_value text,
  primary_evidence_id_value uuid,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  return private.create_news_manifestation_canonical(
    publisher_source_id_value, manifestation_kind_value,
    first_observed_at_value, source_reference_value,
    primary_evidence_id_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

create or replace function public.admin_add_news_manifestation_url(
  manifestation_id_value uuid,
  url_kind_value text,
  url_value text,
  is_public_destination_value boolean,
  primary_evidence_id_value uuid,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  return private.add_news_manifestation_url_canonical(
    manifestation_id_value, url_kind_value, url_value,
    is_public_destination_value, primary_evidence_id_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

create or replace function public.admin_assign_news_manifestation(
  manifestation_id_value uuid,
  news_item_id_value uuid,
  primary_evidence_id_value uuid,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  return private.assign_news_manifestation_canonical(
    manifestation_id_value, news_item_id_value, primary_evidence_id_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

create or replace function public.admin_set_news_representative_destination(
  news_item_id_value uuid,
  manifestation_url_id_value uuid,
  primary_evidence_id_value uuid,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  destination_url public.news_manifestation_urls%rowtype;
  current_destination public.news_representative_destination_versions%rowtype;
  publisher_source_uuid uuid;
  decision_uuid uuid;
  decision_at_value timestamptz;
  destination_uuid uuid := gen_random_uuid();
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  perform 1 from public.news_items where id = news_item_id_value;
  if not found then raise exception 'News Item does not exist'; end if;
  select * into strict destination_url
  from public.news_manifestation_urls where id = manifestation_url_id_value;
  select publisher_source_id into publisher_source_uuid
  from public.news_manifestations where id = destination_url.manifestation_id;
  perform private.require_news_content_evidence(
    primary_evidence_id_value,
    array['representative_destination']::text[],
    publisher_source_uuid
  );

  select * into current_destination
  from public.news_representative_destination_versions
  where news_item_id = news_item_id_value and is_current
  for update;
  if found and current_destination.manifestation_url_id = manifestation_url_id_value then
    raise exception 'This URL is already the representative destination';
  end if;

  decision_uuid := private.record_news_content_decision(
    'set_representative_destination', 'staff', auth.uid(),
    public.current_catalog_actor_id(), publisher_source_uuid, notes_value
  );
  select decided_at into decision_at_value
  from public.news_content_decisions where id = decision_uuid;

  if current_destination.id is not null then
    update public.news_representative_destination_versions
    set is_current = false,
        recorded_to = decision_at_value,
        superseded_at = decision_at_value,
        closed_by_decision_id = decision_uuid
    where id = current_destination.id;
  end if;

  insert into public.news_representative_destination_versions(
    id, news_item_id, manifestation_id, manifestation_url_id,
    recorded_from, primary_evidence_id, decision_id,
    supersedes_destination_id
  ) values (
    destination_uuid, news_item_id_value, destination_url.manifestation_id,
    manifestation_url_id_value, decision_at_value, primary_evidence_id_value,
    decision_uuid, current_destination.id
  );
  perform private.link_news_content_decision_evidence(decision_uuid, primary_evidence_id_value);
  return destination_uuid;
end;
$$;

create or replace function public.admin_record_news_byline(
  manifestation_id_value uuid,
  ordinal_value integer,
  raw_attribution_value text,
  visible_profile_url_value text,
  primary_evidence_id_value uuid,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  publisher_source_uuid uuid;
  decision_uuid uuid;
  byline_uuid uuid := gen_random_uuid();
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  select publisher_source_id into strict publisher_source_uuid
  from public.news_manifestations where id = manifestation_id_value;
  perform private.require_news_content_evidence(
    primary_evidence_id_value,
    array['manifestation_identity']::text[],
    publisher_source_uuid
  );
  decision_uuid := private.record_news_content_decision(
    'record_byline', 'staff', auth.uid(), public.current_catalog_actor_id(),
    publisher_source_uuid, notes_value
  );
  insert into public.news_byline_mentions(
    id, manifestation_id, ordinal, raw_attribution, visible_profile_url,
    primary_evidence_id, created_by_decision_id
  ) values (
    byline_uuid, manifestation_id_value, ordinal_value,
    raw_attribution_value, visible_profile_url_value,
    primary_evidence_id_value, decision_uuid
  );
  perform private.link_news_content_decision_evidence(decision_uuid, primary_evidence_id_value);
  return byline_uuid;
end;
$$;

create or replace function public.admin_resolve_news_byline(
  byline_mention_id_value uuid,
  target_identity_type_value text,
  target_identity_id_value uuid,
  resolution_basis_value text,
  identity_resolution_decision_id_value uuid,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_resolution public.news_byline_resolution_versions%rowtype;
  publisher_source_uuid uuid;
  decision_uuid uuid;
  decision_at_value timestamptz;
  resolution_uuid uuid := gen_random_uuid();
  person_uuid uuid;
  organization_uuid uuid;
  show_uuid uuid;
  profile_uuid uuid;
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  select manifestation.publisher_source_id into strict publisher_source_uuid
  from public.news_byline_mentions mention
  join public.news_manifestations manifestation on manifestation.id = mention.manifestation_id
  where mention.id = byline_mention_id_value;

  if target_identity_type_value = 'person' then
    select id into strict person_uuid from public.catalog_people where id = target_identity_id_value;
  elsif target_identity_type_value = 'organization' then
    select id into strict organization_uuid
    from public.news_organizational_contributors where id = target_identity_id_value;
  elsif target_identity_type_value = 'show' then
    select id into strict show_uuid from public.podcast_shows where id = target_identity_id_value;
  elsif target_identity_type_value = 'publisher_profile' then
    select id into strict profile_uuid
    from public.news_publisher_contributor_profiles where id = target_identity_id_value;
  else
    raise exception 'Unsupported News byline target identity type';
  end if;
  if resolution_basis_value not in ('visible_public_attribution', 'identity_review') then
    raise exception 'Visible public attribution or identity review is required';
  end if;
  if resolution_basis_value = 'identity_review'
     and identity_resolution_decision_id_value is null then
    raise exception 'Identity-review byline Resolution requires a Phase 2 decision';
  end if;

  select * into current_resolution
  from public.news_byline_resolution_versions
  where byline_mention_id = byline_mention_id_value and is_current
  for update;

  decision_uuid := private.record_news_content_decision(
    'resolve_byline', 'staff', auth.uid(), public.current_catalog_actor_id(),
    publisher_source_uuid, notes_value
  );
  select decided_at into decision_at_value
  from public.news_content_decisions where id = decision_uuid;

  if current_resolution.id is not null then
    update public.news_byline_resolution_versions
    set is_current = false,
        recorded_to = decision_at_value,
        superseded_at = decision_at_value,
        closed_by_decision_id = decision_uuid
    where id = current_resolution.id;
  end if;

  insert into public.news_byline_resolution_versions(
    id, byline_mention_id, target_identity_type,
    person_id, organizational_contributor_id, show_id, contributor_profile_id,
    resolution_basis, identity_resolution_decision_id,
    recorded_from, decision_id, supersedes_resolution_id
  ) values (
    resolution_uuid, byline_mention_id_value, target_identity_type_value,
    person_uuid, organization_uuid, show_uuid, profile_uuid,
    resolution_basis_value, identity_resolution_decision_id_value,
    decision_at_value, decision_uuid, current_resolution.id
  );
  return resolution_uuid;
end;
$$;

create or replace function public.admin_record_news_classification(
  news_item_id_value uuid,
  classification_id_value uuid,
  target_type_value text,
  target_id_value uuid,
  primary_evidence_id_value uuid,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  return private.record_news_classification_canonical(
    news_item_id_value, classification_id_value, target_type_value,
    target_id_value, primary_evidence_id_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

create or replace function public.admin_record_news_deduplication(
  manifestation_one_id_value uuid,
  manifestation_two_id_value uuid,
  outcome_value text,
  primary_evidence_id_value uuid,
  rationale_value text,
  notes_value text default null,
  reconcile_manifestation_id_value uuid default null,
  reconcile_news_item_id_value uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  return private.record_news_deduplication_canonical(
    manifestation_one_id_value, manifestation_two_id_value, outcome_value,
    primary_evidence_id_value, rationale_value,
    reconcile_manifestation_id_value, reconcile_news_item_id_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

create or replace function public.admin_record_news_remote_preview(
  manifestation_id_value uuid,
  preview_kind_value text,
  remote_url_value text,
  publisher_policy_state_value text,
  alt_text_value text,
  primary_evidence_id_value uuid,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  return private.record_news_remote_preview_canonical(
    manifestation_id_value, preview_kind_value, remote_url_value,
    publisher_policy_state_value, alt_text_value, primary_evidence_id_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

create or replace function public.admin_set_news_remote_preview_policy(
  preview_reference_id_value uuid,
  publisher_policy_state_value text,
  primary_evidence_id_value uuid,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  return private.set_news_remote_preview_policy_canonical(
    preview_reference_id_value, publisher_policy_state_value,
    primary_evidence_id_value,
    'staff', auth.uid(), public.current_catalog_actor_id(), notes_value
  );
end;
$$;

create or replace function public.admin_open_news_content_review_case(
  case_type_value text,
  news_item_id_value uuid,
  manifestation_id_value uuid,
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
  perform 1 from public.news_content_review_case_types
  where case_type = case_type_value and active;
  if not found then raise exception 'News content review case type is not governed or active'; end if;
  if news_item_id_value is null and manifestation_id_value is null then
    raise exception 'News content review requires an Item or manifestation subject';
  end if;
  if news_item_id_value is not null then
    perform 1 from public.news_items where id = news_item_id_value;
    if not found then raise exception 'News Item does not exist'; end if;
  end if;
  if manifestation_id_value is not null then
    select publisher_source_id into strict publisher_source_uuid
    from public.news_manifestations where id = manifestation_id_value;
  end if;
  decision_uuid := private.record_news_content_decision(
    'open_content_review', 'staff', auth.uid(), public.current_catalog_actor_id(),
    publisher_source_uuid, notes_value
  );
  insert into public.news_content_review_cases(
    id, case_type, news_item_id, manifestation_id, unresolved_question,
    context, opened_by_decision_id
  ) values (
    review_case_uuid, case_type_value, news_item_id_value,
    manifestation_id_value, unresolved_question_value,
    coalesce(context_value, '{}'::jsonb), decision_uuid
  );
  return review_case_uuid;
end;
$$;

create or replace function public.admin_review_news_content_case(
  review_case_id_value uuid,
  action_value text,
  action_payload_value jsonb default '{}'::jsonb,
  notes_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  case_record public.news_content_review_cases%rowtype;
  prior_review_decision_uuid uuid;
  content_decision_uuid uuid;
  review_decision_uuid uuid := gen_random_uuid();
  decision_at_value timestamptz;
  publisher_source_uuid uuid;
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  if action_value not in ('resolve', 'insufficient_evidence', 'reopen', 'dismiss') then
    raise exception 'Unsupported News content review action';
  end if;
  select * into strict case_record
  from public.news_content_review_cases
  where id = review_case_id_value
  for update;
  if case_record.manifestation_id is not null then
    select publisher_source_id into publisher_source_uuid
    from public.news_manifestations where id = case_record.manifestation_id;
  end if;
  select id into prior_review_decision_uuid
  from public.news_content_review_decisions
  where review_case_id = review_case_id_value
  order by decided_at desc, id desc
  limit 1;

  content_decision_uuid := private.record_news_content_decision(
    'review_content_case', 'staff', auth.uid(), public.current_catalog_actor_id(),
    publisher_source_uuid, notes_value
  );
  select decided_at into decision_at_value
  from public.news_content_decisions where id = content_decision_uuid;
  insert into public.news_content_review_decisions(
    id, review_case_id, action, question_snapshot,
    action_payload_snapshot, notes, decided_by_user_id,
    content_decision_id, supersedes_review_decision_id, decided_at
  ) values (
    review_decision_uuid, review_case_id_value, action_value,
    case_record.unresolved_question, coalesce(action_payload_value, '{}'::jsonb),
    notes_value, auth.uid(), content_decision_uuid,
    prior_review_decision_uuid, decision_at_value
  );

  update public.news_content_review_cases
  set status = case action_value
        when 'resolve' then 'resolved'
        when 'insufficient_evidence' then 'insufficient_evidence'
        when 'dismiss' then 'dismissed'
        else 'open'
      end,
      updated_at = decision_at_value,
      resolved_at = case when action_value = 'reopen' then null else decision_at_value end
  where id = review_case_id_value;
  return review_decision_uuid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Point-in-time assignment and deterministic staff-only publication proof
-- ---------------------------------------------------------------------------

create or replace function public.get_news_manifestation_item_at(
  manifestation_id_value uuid,
  at_time_value timestamptz
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare result_uuid uuid;
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  select assignment.news_item_id into result_uuid
  from public.news_manifestation_assignment_versions assignment
  where assignment.manifestation_id = manifestation_id_value
    and assignment.recorded_from <= at_time_value
    and (assignment.recorded_to is null or at_time_value < assignment.recorded_to)
  order by assignment.recorded_from desc, assignment.id desc
  limit 1;
  return result_uuid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Staff read models. Publication eligibility is current publication policy,
-- a valid sticky destination, and database time only. Attribution and
-- classifications are aggregated so the canonical row cardinality is one per
-- News Item.
-- ---------------------------------------------------------------------------

create view public.news_ready_item_read_model
with (security_invoker = true)
as
select
  item.id,
  item.news_item_id,
  item.item_kind,
  item_version.id as item_version_id,
  item_version.version_number,
  item_version.headline,
  item_version.summary,
  item_version.publication_state,
  item_version.publication_time,
  destination.id as representative_destination_version_id,
  manifestation.id as manifestation_id,
  manifestation.manifestation_id as manifestation_public_id,
  manifestation.manifestation_kind,
  destination_url.id as manifestation_url_id,
  destination_url.url as destination_url,
  destination_url.url_kind as destination_url_kind,
  publisher.id as publisher_source_id,
  publisher.source_id as publisher_id,
  publisher.display_name as publisher_name,
  podcast.show_id,
  show_identity.display_name as show_name,
  creation_decision.decision_origin as creation_origin,
  creation_decision.decided_by_user_id as created_by_user_id,
  creation_decision.decided_by_actor_id as created_by_actor_id,
  preview.remote_url as preview_url,
  preview.preview_kind,
  coalesce(byline_rows.items, '[]'::jsonb) as bylines,
  coalesce(classification_rows.items, '[]'::jsonb) as classifications
from public.news_items item
join public.news_item_versions item_version
  on item_version.news_item_id = item.id and item_version.is_current
join public.news_representative_destination_versions destination
  on destination.news_item_id = item.id and destination.is_current
join public.news_manifestations manifestation
  on manifestation.id = destination.manifestation_id
join public.news_manifestation_assignment_versions assignment
  on assignment.manifestation_id = manifestation.id
 and assignment.news_item_id = item.id
 and assignment.is_current
join public.news_manifestation_urls destination_url
  on destination_url.id = destination.manifestation_url_id
 and destination_url.manifestation_id = manifestation.id
 and destination_url.is_public_destination
join public.trusted_sources publisher
  on publisher.id = manifestation.publisher_source_id
join public.news_content_decisions creation_decision
  on creation_decision.id = item.created_by_decision_id
left join public.news_podcast_episodes podcast
  on podcast.news_item_id = item.id
left join public.podcast_show_identity_versions show_identity
  on show_identity.show_id = podcast.show_id and show_identity.is_current
left join lateral (
  select remote.remote_url, remote.preview_kind
  from public.news_remote_preview_references remote
  join public.news_remote_preview_policy_versions policy
    on policy.preview_reference_id = remote.id
   and policy.is_current
   and policy.publisher_policy_state = 'approved'
  where remote.manifestation_id = manifestation.id
  order by remote.created_at, remote.id
  limit 1
) preview on true
left join lateral (
  select jsonb_agg(jsonb_build_object(
    'mention_id', mention.id,
    'ordinal', mention.ordinal,
    'raw_attribution', mention.raw_attribution,
    'visible_profile_url', mention.visible_profile_url,
    'target_identity_type', resolution.target_identity_type,
    'person_id', resolution.person_id,
    'organizational_contributor_id', resolution.organizational_contributor_id,
    'show_id', resolution.show_id,
    'contributor_profile_id', resolution.contributor_profile_id
  ) order by mention.ordinal, mention.id) as items
  from public.news_byline_mentions mention
  left join public.news_byline_resolution_versions resolution
    on resolution.byline_mention_id = mention.id and resolution.is_current
  where mention.manifestation_id = manifestation.id
) byline_rows on true
left join lateral (
  select jsonb_agg(jsonb_build_object(
    'classification_id', classification.classification_id,
    'target_type', version.target_type,
    'target_public_id', case version.target_type
      when 'sport' then sport.sport_id
      when 'competition' then competition.competition_id
      when 'competition_edition' then edition.edition_id
      when 'team' then team.team_id
    end,
    'target_display_name', case version.target_type
      when 'sport' then sport.display_name
      when 'competition' then competition_identity.display_name
      when 'competition_edition' then edition_identity.display_name
      when 'team' then team_identity.display_name
    end
  ) order by classification.created_at, classification.id) as items
  from public.news_item_classifications classification
  join public.news_item_classification_versions version
    on version.classification_id = classification.id and version.is_current
  left join public.catalog_sports sport on sport.id = version.sport_id
  left join public.catalog_competitions competition on competition.id = version.competition_id
  left join public.competition_identity_versions competition_identity
    on competition_identity.competition_id = competition.id and competition_identity.is_current
  left join public.catalog_competition_editions edition
    on edition.id = version.competition_edition_id
  left join public.competition_edition_versions edition_identity
    on edition_identity.competition_edition_id = edition.id and edition_identity.is_current
  left join public.catalog_teams team on team.id = version.team_id
  left join public.team_identity_versions team_identity
    on team_identity.team_id = team.id and team_identity.is_current
  where classification.news_item_id = item.id
) classification_rows on true
where item.item_kind = 'written' or podcast.news_item_id is not null;

create view public.news_published_item_read_model
with (security_invoker = true)
as
select *
from public.news_ready_item_read_model ready
where ready.publication_state = 'published'
  and ready.publication_time <= statement_timestamp()
order by ready.publication_time desc, ready.news_item_id;

create view public.news_awaiting_publication_read_model
with (security_invoker = true)
as
select *
from public.news_ready_item_read_model ready
where ready.publication_state = 'published'
  and ready.publication_time > statement_timestamp()
order by ready.publication_time, ready.news_item_id;

create view public.news_content_review_read_model
with (security_invoker = true)
as
select
  review_case.id,
  review_case.review_case_id,
  review_case.case_type,
  review_case.news_item_id,
  item.news_item_id as news_item_public_id,
  review_case.manifestation_id,
  manifestation.manifestation_id as manifestation_public_id,
  review_case.status,
  review_case.unresolved_question,
  review_case.context,
  review_case.created_at,
  review_case.updated_at,
  review_case.resolved_at,
  coalesce(decision_rows.items, '[]'::jsonb) as decision_history
from public.news_content_review_cases review_case
left join public.news_items item on item.id = review_case.news_item_id
left join public.news_manifestations manifestation
  on manifestation.id = review_case.manifestation_id
left join lateral (
  select jsonb_agg(jsonb_build_object(
    'id', decision.id,
    'action', decision.action,
    'question_snapshot', decision.question_snapshot,
    'action_payload_snapshot', decision.action_payload_snapshot,
    'notes', decision.notes,
    'decided_by_user_id', decision.decided_by_user_id,
    'decided_at', decision.decided_at
  ) order by decision.decided_at, decision.id) as items
  from public.news_content_review_decisions decision
  where decision.review_case_id = review_case.id
) decision_rows on true;

create or replace function public.admin_get_news_published_items_at(
  at_time_value timestamptz
)
returns setof public.news_ready_item_read_model
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.has_staff_access(array['admin','staff','content_admin']::text[], null) then
    raise exception 'News content staff access is required';
  end if;
  return query
  select ready.*
  from public.news_ready_item_read_model ready
  where ready.publication_state = 'published'
    and ready.publication_time <= at_time_value
  order by ready.publication_time desc, ready.news_item_id;
end;
$$;

comment on function public.admin_get_news_published_items_at(timestamptz) is
  'Staff-only deterministic proof helper. Normal publication always uses database statement time through news_published_item_read_model.';

-- ---------------------------------------------------------------------------
-- RLS and grants. Base state and review records remain staff-only in Phase 3.
-- No browser role receives direct mutation privileges.
-- ---------------------------------------------------------------------------

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'news_content_evidence_kinds',
    'news_content_decisions',
    'news_content_evidence',
    'news_content_decision_evidence',
    'news_items',
    'news_item_versions',
    'news_podcast_episodes',
    'news_manifestations',
    'news_manifestation_urls',
    'news_manifestation_assignment_versions',
    'news_representative_destination_versions',
    'news_byline_mentions',
    'news_byline_resolution_versions',
    'news_item_classifications',
    'news_item_classification_versions',
    'news_deduplication_cases',
    'news_deduplication_decision_versions',
    'news_remote_preview_references',
    'news_remote_preview_policy_versions',
    'news_content_review_case_types',
    'news_content_review_cases',
    'news_content_review_decisions'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('revoke all on table public.%I from public, anon, authenticated', table_name);
    execute format(
      'create policy "Authorized staff read News content %1$s" on public.%1$I for select to authenticated using (public.has_staff_access(array[''admin'',''staff'',''content_admin'']::text[], null))',
      table_name
    );
    execute format('grant select on table public.%I to authenticated', table_name);
  end loop;
end $$;

grant select on public.news_ready_item_read_model,
  public.news_published_item_read_model,
  public.news_awaiting_publication_read_model,
  public.news_content_review_read_model
to authenticated;

revoke all on function public.admin_record_news_content_evidence(
  text,text,uuid,text,timestamptz,text
) from public, anon;
grant execute on function public.admin_record_news_content_evidence(
  text,text,uuid,text,timestamptz,text
) to authenticated;
revoke all on function public.admin_create_news_item(
  text,text,text,text,timestamptz,uuid,uuid,uuid,text,text
) from public, anon;
grant execute on function public.admin_create_news_item(
  text,text,text,text,timestamptz,uuid,uuid,uuid,text,text
) to authenticated;
revoke all on function public.admin_record_news_item_version(
  uuid,text,text,text,timestamptz,uuid,uuid,text
) from public, anon;
grant execute on function public.admin_record_news_item_version(
  uuid,text,text,text,timestamptz,uuid,uuid,text
) to authenticated;
revoke all on function public.admin_create_news_manifestation(
  uuid,text,timestamptz,text,uuid,text
) from public, anon;
grant execute on function public.admin_create_news_manifestation(
  uuid,text,timestamptz,text,uuid,text
) to authenticated;
revoke all on function public.admin_add_news_manifestation_url(
  uuid,text,text,boolean,uuid,text
) from public, anon;
grant execute on function public.admin_add_news_manifestation_url(
  uuid,text,text,boolean,uuid,text
) to authenticated;
revoke all on function public.admin_assign_news_manifestation(
  uuid,uuid,uuid,text
) from public, anon;
grant execute on function public.admin_assign_news_manifestation(
  uuid,uuid,uuid,text
) to authenticated;
revoke all on function public.admin_set_news_representative_destination(
  uuid,uuid,uuid,text
) from public, anon;
grant execute on function public.admin_set_news_representative_destination(
  uuid,uuid,uuid,text
) to authenticated;
revoke all on function public.admin_record_news_byline(
  uuid,integer,text,text,uuid,text
) from public, anon;
grant execute on function public.admin_record_news_byline(
  uuid,integer,text,text,uuid,text
) to authenticated;
revoke all on function public.admin_resolve_news_byline(
  uuid,text,uuid,text,uuid,text
) from public, anon;
grant execute on function public.admin_resolve_news_byline(
  uuid,text,uuid,text,uuid,text
) to authenticated;
revoke all on function public.admin_record_news_classification(
  uuid,uuid,text,uuid,uuid,text
) from public, anon;
grant execute on function public.admin_record_news_classification(
  uuid,uuid,text,uuid,uuid,text
) to authenticated;
revoke all on function public.admin_record_news_deduplication(
  uuid,uuid,text,uuid,text,text,uuid,uuid
) from public, anon;
grant execute on function public.admin_record_news_deduplication(
  uuid,uuid,text,uuid,text,text,uuid,uuid
) to authenticated;
revoke all on function public.admin_record_news_remote_preview(
  uuid,text,text,text,text,uuid,text
) from public, anon;
grant execute on function public.admin_record_news_remote_preview(
  uuid,text,text,text,text,uuid,text
) to authenticated;
revoke all on function public.admin_set_news_remote_preview_policy(
  uuid,text,uuid,text
) from public, anon;
grant execute on function public.admin_set_news_remote_preview_policy(
  uuid,text,uuid,text
) to authenticated;
revoke all on function public.admin_open_news_content_review_case(
  text,uuid,uuid,text,jsonb,text
) from public, anon;
grant execute on function public.admin_open_news_content_review_case(
  text,uuid,uuid,text,jsonb,text
) to authenticated;
revoke all on function public.admin_review_news_content_case(
  uuid,text,jsonb,text
) from public, anon;
grant execute on function public.admin_review_news_content_case(
  uuid,text,jsonb,text
) to authenticated;
revoke all on function public.get_news_manifestation_item_at(uuid,timestamptz)
from public, anon;
grant execute on function public.get_news_manifestation_item_at(uuid,timestamptz)
to authenticated;
revoke all on function public.admin_get_news_published_items_at(timestamptz)
from public, anon;
grant execute on function public.admin_get_news_published_items_at(timestamptz)
to authenticated;

revoke all on function private.record_news_content_decision(
  text,text,uuid,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function private.link_news_content_decision_evidence(uuid,uuid)
from public, anon, authenticated;
revoke all on function private.resolve_news_content_evidence_scope(text,uuid)
from public, anon, authenticated;
revoke all on function private.require_news_content_evidence(uuid,text[],uuid)
from public, anon, authenticated;
revoke all on function private.lock_news_manifestation_pair(uuid,uuid)
from public, anon, authenticated;
revoke all on function private.lock_news_manifestation_dedupe_scope(uuid)
from public, anon, authenticated;
revoke all on function private.lock_news_deduplication_case(uuid)
from public, anon, authenticated;
revoke all on function private.assert_news_dedupe_assignment_consistency(uuid)
from public, anon, authenticated;
revoke all on function private.assert_news_dedupe_assignment_consistency_for_manifestation(uuid)
from public, anon, authenticated;
revoke all on function private.record_news_content_evidence_canonical(
  text,text,uuid,text,timestamptz,text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function private.create_news_item_canonical(
  text,text,text,text,timestamptz,uuid,uuid,uuid,text,text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function private.record_news_item_version_canonical(
  uuid,text,text,text,timestamptz,uuid,uuid,text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function private.create_news_manifestation_canonical(
  uuid,text,timestamptz,text,uuid,text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function private.add_news_manifestation_url_canonical(
  uuid,text,text,boolean,uuid,text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function private.assign_news_manifestation_canonical(
  uuid,uuid,uuid,text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function private.record_news_classification_canonical(
  uuid,uuid,text,uuid,uuid,text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function private.record_news_deduplication_canonical(
  uuid,uuid,text,uuid,text,uuid,uuid,text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function private.record_news_remote_preview_canonical(
  uuid,text,text,text,text,uuid,text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function private.set_news_remote_preview_policy_canonical(
  uuid,text,uuid,text,uuid,uuid,text
) from public, anon, authenticated;
revoke all on function public.protect_news_content_history_row()
from public, anon, authenticated;
revoke all on function public.protect_news_content_stable_identity()
from public, anon, authenticated;
revoke all on function public.protect_news_content_version()
from public, anon, authenticated;
revoke all on function public.protect_news_content_review_case()
from public, anon, authenticated;
revoke all on function public.validate_news_podcast_episode()
from public, anon, authenticated;
revoke all on function public.validate_news_representative_destination()
from public, anon, authenticated;
revoke all on function public.validate_news_dedupe_assignment_consistency()
from public, anon, authenticated;

comment on table public.news_items is
  'Persistent News work identities. Headlines, publication timestamps, and publication state are versioned facts, not identity.';
comment on table public.news_manifestations is
  'Publisher copies or manifestations that may remain unresolved until a governed assignment is recorded.';
comment on table public.news_manifestation_assignment_versions is
  'Half-open recorded-time assignment history; an absent interval means the manifestation was unresolved.';
comment on table public.news_representative_destination_versions is
  'Explicit sticky representative public destination history. No automatic URL replacement exists in Phase 3.';
comment on table public.news_item_classification_versions is
  'Evidence-backed factual classification only. Presentation groups are deliberately not targetable.';
comment on table public.news_deduplication_decision_versions is
  'Reversible evidence-backed distinction between syndicated copies, independent journalism, and unresolved review; deferred constraint triggers reject contradictions with current manifestation assignments.';
comment on table public.news_remote_preview_policy_versions is
  'Append-only approval, review, and block history. Canonical reads expose only current approved policy.';
comment on view public.news_published_item_read_model is
  'Staff-only canonical chronological read: one current eligible row per News Item, ordered only by source publication time and permanent ID tie-breaker.';
comment on view public.news_awaiting_publication_read_model is
  'Derived staff view of otherwise-published Items whose source publication time is later than database statement time.';
comment on view public.news_content_review_read_model is
  'Staff-only typed content-question queue. News content cases never enter Phase 2 identity Resolution cases.';

commit;
