# FANatical canonical team and competition registry

The PostgreSQL registry is the canonical backend model for Team and Competition
identity and governed facts. The React `officialSportsDatabase` remains a
temporary compatibility fallback while feature consumers are moved to the
repository adapter in focused passes.

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

## Competition foundation

The generalized Competition model is additive. Existing `catalog_leagues`
identities and references remain authoritative for legacy League consumers,
and every existing or newly inserted League has one explicit
`catalog_league_competition_mappings` row to a league-kind canonical
Competition with the same public ID and Sport. A database trigger creates the
Competition identity, initial version, and mapping in the League insert's own
transaction; failure rolls back the League. The mapping is durable, and later
League compatibility identifiers are mirrored to the mapped Competition in
the same transaction. Backfilled and newly generated Competition facts are
`imported_unverified`, even when the legacy League has a verified status,
because League evidence is not silently promoted into a new factual record.

Canonical Competition data is separated into:

- `competition_kinds`, the controlled and extensible kind catalog initially
  covering league, cup, championship, tournament, tour, series, and other;
- `catalog_competitions`, the stable Competition identities;
- `competition_identity_versions`, `competition_alias_versions`, and
  `catalog_competition_identifiers`, which hold mutable names, aliases, and
  namespaced compatibility/external IDs;
- `catalog_competition_editions` and `competition_edition_versions`, which keep
  a stable Competition distinct from each season or occurrence;
- `team_competition_edition_participation_versions`, which records time-bounded
  Team participation in any number of Competition Editions without duplicating
  or changing the Team identity; and
- `competition_relationship_versions` and
  `competition_edition_relationship_versions`, which are many-to-many graphs
  rather than mandatory parent trees. Relationships are constrained to one
  Sport, while a Tournament or Tournament Edition can still relate to multiple
  same-Sport Tours or Tour Editions.

A Competition's permanent public ID, Sport, and kind are identity-defining and
cannot be directly changed. A correction that would alter Sport or kind must
use a future governed replacement/correction workflow that also revalidates
relationships, Editions, participation, and League compatibility; Phase 1 does
not expose a casual mutation path.

`team_primary_league_versions` and Competition participation answer different
questions. Primary League is the Team's singular primary app/team-context
League. `team_competition_edition_participation_versions` is the factual,
time-bounded record of every Competition Edition in which the Team
participates. News and other Competition-aware features must use participation
when answering Competition-membership questions; neither model replaces the
other.

`resolve_catalog_competition(...)` checks immutable public IDs, namespaced
external identifiers, current names, and current aliases. It returns
`resolved`, `none`, or every candidate for an `ambiguous` result rather than
guessing. `resolve_catalog_competition_id(...)` is the strict convenience form
and raises when a match is ambiguous.

Competition filter groups are separate presentation identities in
`catalog_competition_filter_groups`. Their versioned memberships reference real
canonical Competitions. A group such as Junior Hockey can therefore present
WHL, OHL, and QMJHL without creating a synthetic factual Competition. A filter
group may optionally be Sport-scoped; scoped groups accept only Competitions
from that Sport, while unscoped presentation groups may span Sports. The member
Competitions always retain their own Sport identities.

The Competition foundation adds Golf and Tennis to `catalog_sports`. It does
not add a complete Competition or filter-group bootstrap catalog; representative
Hockey, Soccer, Golf, Tennis, and Junior Hockey examples remain transactional
test fixtures until approved bootstrap data is supplied.

## Competition expansion and deferred governance

Phase 1 provides a safe expansion base but not the complete Competition
governance interface:

- a reviewed migration or privileged import may add a stable Sport ID;
- every League insert, including the existing approved
  `league_registration` path, is automatically Competition-complete;
- reviewed imports may add stable non-League Competition and Edition IDs,
  aliases, relationships, and participation as `imported_unverified`; and
- version successors preserve history through the established
  current-to-superseded transition used by Team governance.

Competition rows must remain `imported_unverified` until a Competition-specific
proposal, evidence, verification-policy, decision, and audit path exists.
Direct casual verification is not permitted. That governed promotion path must
be implemented before automated or agent promotion of Competition facts.

The following work is intentionally deferred to the earliest dependent News
implementation milestone:

- before provider-specific ingestion, assess an optional namespace argument
  for Competition resolution and decide whether commercial/private provider
  identifiers may be exposed through the public identifier catalog;
- before the first News consumer needs them, add a shared Team-participation
  read model and provider-appropriate Competition Edition resolver;
- during the first real-source/provider mapping spike, verify how incoming
  Competition, Edition, and participant metadata maps to these canonical
  records before ingestion depends heavily on Edition resolution; and
- when the first filter-group UI/API consumer is built, choose deliberately
  between the current row-per-membership view and a group-level JSON aggregate
  instead of changing the Phase 1 shape speculatively.

Separately, the existing frontend regression suite has timing-sensitive
Profile/Cheer cases under its default five-second timeout. The established
single-worker, longer-timeout invocation is the reliable full-suite check; this
is a repository-quality backlog item, not a Competition or News behavior
change.

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

The Competition identity, alias, Edition, relationship, participation, and
filter-group version tables use this same supersession and verified-history
protection pattern.

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

The completed Team seed contains 5 sport identities, 125 league identities,
and 1,948 team identities. The later Competition foundation adds Golf and
Tennis, so a fully migrated catalog contains 7 Sport identities while the
immutable Team seed's recorded counts remain unchanged. Of the Team seed's
records, 124 leagues and 1,947 teams come from the
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

The governed Team Color publisher reference is applied by
`202608230009_team_color_source_seed.sql`, reproducibly generated from
`FANatical_Team_Color_Source_Seed_Reference.xlsx` with:

```bash
python3 supabase/scripts/generate_team_color_source_seed.py \
  --workbook /path/to/FANatical_Team_Color_Source_Seed_Reference.xlsx \
  --output supabase/migrations/202608230009_team_color_source_seed.sql
```

That seed contains 125 active-league mappings, 113 canonical official Tier 1
publisher families, and three broad Tier 2 publishers. Governance approval and
applicability enroll all 116 publishers as empirically probationary/unrated;
the seed contains no Team Color facts, qualification observations or ratings,
or information lineages. Historical page-level candidates from the completed
master-team import are preserved through canonical redirects when the supplied
league mapping and publisher URL identify exactly one workbook source family.
