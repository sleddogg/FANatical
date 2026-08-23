# FANatical canonical team registry

The PostgreSQL registry is the canonical backend model for team identity and
team-maintained data. The React `officialSportsDatabase` remains a temporary
compatibility fallback while feature consumers are moved to the repository
adapter in focused passes.

## Identity

- `catalog_teams.id` is a hidden UUID used by database foreign keys.
- `catalog_teams.team_id` is the immutable readable public ID, for example
  `hockey-000027` for the Edmonton Oilers.
- Existing application slugs are namespaced rows in
  `catalog_team_identifiers`; they are not canonical identities.
- `resolve_catalog_team_id(...)` accepts either a public ID or a compatibility
  identifier.
- `submit_team_registration_proposal(...)` reserves the next public ID for a
  sport and submits it to the normal verification workflow.

FANatical currently models one mutable primary league per team. Prior primary
league rows remain as history after a verified successor is promoted.

## Current facts and history

Mutable facts use append-only version tables:

- `team_identity_versions`
- `team_alias_versions`
- `team_location_versions`
- `team_primary_league_versions`
- `team_color_versions`
- `team_logo_versions`
- `team_venue_relationship_versions`
- `venue_detail_versions`
- `venue_mapping_versions` and normalized mapping children

Verified values cannot be deleted or edited. Approval atomically marks a
current version as superseded and inserts its verified successor. There is no
automatic stale state based only on age.

## Verification

The Trusted Source Registry is normalized into:

- `trusted_sources`
- `trusted_source_alias_versions`
- `trusted_source_url_scope_versions`
- `trusted_source_redirects`
- `source_independence_groups`
- `source_independence_group_assignment_versions`
- `source_trust_assignments` (one versioned trust tier per publisher/data type)
- `source_applicability_versions` (separate versioned
  global/sport/league/team applicability)
- `verification_policies` (immutable version records)
- `catalog_change_proposals`
- `catalog_proposal_evidence`
- `catalog_verification_decisions`
- `catalog_audit_events`
- `team_color_source_reliability_observations`

Workbook source rows are imported as `pending_review` with no ownership group,
trust tier, or applicability. Candidate import cannot approve sources. A source
reviewer must first identify common ownership/control and assign an independence
group; trust is then assigned separately for each data type. Tier 4 sources are
research leads that do not verify facts, and Tier 5 sources are blocked for the
assigned data type.

Trusted sources represent reusable publishers by default. Team-specific pages
are evidence URLs, not separate publisher identities. Reviewed URL scopes
explicitly model canonical/alias hosts, subdomain permission, path ownership,
and CDN/document hosts. Resolution returns `none`, one canonical publisher, or
an ambiguity that requires review. Source redirects preserve historical
evidence and immutable decision snapshots rather than rewriting them.
`trusted_source_duplicate_candidates_read_model` surfaces overlapping URL
scopes or normalized publisher names to reviewers; it never merges records or
constitutes a governance decision by itself.

Trust tier and applicability are separate governance concepts. A publisher can
have only one current tier for a data type, plus any number of independently
versioned global, sport, league, or team applicability scopes. Evidence
submission independently validates the tier, target applicability, URL
ownership, and independence/policy requirements, then stores the exact
trust-tier, applicability, URL-scope, and independence-assignment versions used
at decision time. A more-specific applicability can be selected without ever
changing tier. Hostname sharing never by itself proves common publisher
identity or independence.

Empirical Team Color reliability is derived only from later verification
outcomes and never changes governance trust. Matches and contradictions require
corroboration outside the source's own independence group; unresolved and
not-assessable outcomes remain explicit. The read model includes sample size,
breadth, recency, and a conservative match-rate estimate.

The initial active, versioned policies cover team colours, primary-league
membership, primary-venue relationships, and venue seat mappings. Each requires
two qualifying Tier 1-3 sources from different independence groups and at least
one Tier 1 or Tier 2 source. Team colours must be uppercase six-digit HEX.
Venue mappings additionally require a separate builder and verifier, and the
verifier must hold `venue.mapping.verify` for the applicable scope. Policies and
their evidence are snapshotted into the immutable verification decision.

Verified data does not become stale merely because time passes. Rechecking is
driven by scheduled review, a known real-world event, a detected conflict or
mismatch, or a manual request.

Operational agents authenticate through Supabase Auth and map to a
`catalog_actors` row. Admins grant narrow, optionally scoped capabilities with
`admin_grant_catalog_capability(...)`. Agents use proposal/evidence RPCs; they
do not receive a Supabase service-role key. A policy can require the verifier
to be a different actor from the proposal builder.

The production Team Color Agent queue, narrow read interface, source-candidate
intake, expected-version replacement protection, mandatory verifier separation,
trust-tier rubric, exact RPC sequence, and secure provisioning procedure are
documented in [`TEAM_COLOR_AGENT.md`](TEAM_COLOR_AGENT.md). Team Color Agents use
that interface rather than direct table writes or broad `catalog.read_internal`
access.

## Read models

- `team_catalog_read_model` is the flat browser/repository projection.
- `get_team_record(...)` assembles the human/agent-facing nested record from
  normalized tables.
- `team_readiness` calculates separate `catalog_ready` and
  `live_cheer_ready` states. Official logos are optional for both.

Catalog readiness requires verified identity and verified primary league.
Live Cheer readiness additionally requires a verified primary venue
relationship and a verified current venue map.

## Seed provenance

`202608190002_team_registry_seed.sql` records the earlier incomplete workbook
import and remains immutable migration history. The current canonical
seed/reference is the completed workbook applied by
`202608190004_complete_master_team_seed.sql`, reproducibly generated by:

```bash
python3 supabase/scripts/generate_team_registry_seed.py \
  --workbook /path/to/FANatical_Master_Teams.xlsx \
  --frontend-catalog app/src/data/officialSportsDatabase.ts \
  --celtics-reference /path/to/FANatical_Team_Record_Boston_Celtics_Example.md \
  --venue-source app/src/features/internal/venues/rexallVenueData.ts \
  --import-key master-teams-complete-2026-08-19 \
  --output supabase/migrations/202608190004_complete_master_team_seed.sql
```

The completed seed contains 5 sport identities, 125 league identities, and
1,948 team identities. Of these, 124 leagues and 1,947 teams come from the
completed workbook; the Celtics/NBA identity comes from the supplied read-model
example to preserve the current app. It also contains 366 namespaced legacy
frontend team IDs, the four existing color palettes, 130 deduplicated pending
source candidates, and the existing Rexall Place mapping as unverified
compatibility data.

The generator preserves supplied Sport, League, and Team IDs exactly. The
completion migration checks any pre-existing League or Team ID against its
sport, name, and primary-league identity and aborts rather than silently
repurposing an established ID. Exact source-reference URLs are deduplicated;
multiple workbook contexts for one URL remain attached to that one pending
source candidate.

Seed import batches store source filenames, SHA-256 hashes, counts, and an
explicit `verified_source_data = false` marker.
