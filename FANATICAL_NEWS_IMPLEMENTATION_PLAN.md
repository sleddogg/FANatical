The News system is in implementation. Phases 1–3 established the Competition,
identity, and canonical content foundations. Phase 4 begins with authority and
backend entry hardening before any fan-facing feed UI. The route remains an
additive Supabase domain, a separate later Cloudflare News Worker, and incremental
conversion of the existing React prototype.

## Pre-implementation review

### Genuine contradictions

There is no unresolvable contradiction inside the newest settled architecture. Cloudflare can remain disposable execution infrastructure while Supabase remains authoritative, and the generalized Competition model can coexist with `team_primary_league`.

`Fanatical build page.md` is the reconciled product authority. Where older prose
in this implementation plan differs, the build page and invariant register win.

The older lazy-discussion rule can coexist with “one canonical discussion per News Item”: materialize the row atomically on the first comment or poll, with a database uniqueness constraint guaranteeing one logical discussion.

### Required product decisions still missing

These do not block Competition, identity, content, or parser foundations, but they block the named feature:

1. **Rating behavior.** Rating revision, withdrawal, and aggregate presentation
   remain later work; Phase 4 does not implement ratings.
2. **News reactions.** The reaction set remains later work; the prototype heart
   is removed rather than promoted into product authority.
3. **Poll governance.** Creation, lifecycle, moderation, voting, and option
   limits remain later work.
4. **Notification surface.** Missing-identity requests, fulfilment, and
   notifications remain Phase 5 or later.

Wire services, official Team newsrooms, and other genuine organizational
contributors follow the same explicit individual-follow rule as every other
identity. There is no separate wire exclusion and no official-Team preference.
Mute is approved only on an existing followed human Author, organizational
contributor, or Show for 7 or 30 days from database `statement_timestamp()`.

### Technical decisions to approve

I recommend approving these before their respective migrations:

- Use a shared `catalog_people` identity foundation plus a News Author profile, rather than treating Auth `profiles` as journalists or creating permanently News-only people.
- Treat existing `trusted_sources` as canonical publisher/publication-brand identities. Use `source_independence_groups` for common control; do not introduce a duplicate News publisher registry.
- Add a small reusable Community foundation for discussions/comments/polls, but activate only the News-discussion slice. Do not convert all prototype FANbase features in this project.
- Start with one separate `fanatical-news-runtime` Worker containing isolated scheduled, queue, and email handlers. Give it a dedicated ordinary Supabase Auth service identity with narrow `news.*` capabilities—never a service-role key. Put any future browser worker behind a separate identity and deployment.
- Store hashes, response metadata, extracted facts, and bounded evidence in Supabase. Do not retain full third-party article bodies or raw newsletter bodies by default. Any larger diagnostic snapshot store and its retention policy require privacy/legal approval.

Before live monitoring is enabled, approve:

- FANatical User-Agent and contact details.
- Endpoint and recovery schedules.
- Lease/heartbeat and retry policies.
- Queue batch, delivery-retry, and DLQ settings.
- Per-host concurrency, timeout, redirect, response-size, decompression, and circuit/backoff policies.
- Robots cache behavior, Gap Detection comparison windows, feed pagination bounds, and evidence retention.
- Whether the older approximate refresh target in `Fanatical build page.md` remains approved for standard feeds.

None of the Team Color operating numbers should silently become News defaults.

# 1. Recommended architecture summary

```
React News / FANbase / Admin
        |
        | public read models + owner/staff RPCs
        v
Supabase/Postgres
  canonical sports/competitions/people/publishers/shows/news
  follows/preferences/community/ratings/notifications
  endpoint runs/evidence/review
  authoritative work ledger, leases, attempts, recovery, outbox
        ^
        | claim/complete/recover by durable work ID
        |
Cloudflare fanatical-news-runtime
  scheduled dispatcher | Queue consumers | Email handler
        ^
        |
Cloudflare Queues
  small at-least-once wake messages containing work IDs only
```

Boundaries:

- **React** owns temporary filter state, rendering, direct publisher links, and authenticated user actions. Components use a News repository rather than issuing arbitrary queries.
- **Supabase** owns all canonical identities, decisions, evidence, publication state, user state, community relationships, and work authority.
- **Cloudflare Queues** are delivery mechanisms, not a second job database.
- **Cloudflare News runtime** performs network and parsing work, but can only transition durable jobs through narrow RPCs.
- **Admin** handles genuinely ambiguous Resolution, byline, classification, deduplication, monitoring, and gap cases using audited RPCs.
- **Ordinary TypeScript modules** contain parsing, normalization, byline, classification, and deduplication logic so it is not coupled to Cloudflare.

## Pre-Phase 4 repository assessment (historical input)

### Frontend

This assessment described the prototype at Phase 4 entry. The local Phase 4
conversion now replaces those conditions: `NewsPage.tsx` reads through
`newsRepository.ts`; temporary filters do not call global Team mutation;
`types.ts` contains only fan-safe production News contracts; cards open the
representative publisher destination without copied bodies or fake counts;
`NewsItemOverlay.tsx`, `newsFiltering.ts`, and `mockNewsData.ts` are removed;
filters use canonical Sport/Competition/Team navigation; and Add to Feed manages
individual Authors, organizational contributors, and Shows. The deferred
FANbase Article Discussion fixture remains explicitly local to `features/fanbase`
rather than importing a production News mock contract.

### Global identity and Community

- [TeamContext.tsx (line 62)]\(/home/sleddogg/Desktop/FANatical code/app/src/state/TeamContext.tsx:62) persists global selected-team state. News must read its entry context but never mutate it.
- [teamCatalogRepository.ts (line 117)]\(/home/sleddogg/Desktop/FANatical code/app/src/data/teamCatalogRepository.ts:117) already maps canonical team IDs to namespaced legacy frontend IDs.
- [accountRepository.ts (line 203)]\(/home/sleddogg/Desktop/FANatical code/app/src/features/account/accountRepository.ts:203) demonstrates the repository/RPC pattern to follow.
- [FanbaseContext.tsx (line 132)]\(/home/sleddogg/Desktop/FANatical code/app/src/features/fanbase/FanbaseContext.tsx:132) is an in-memory prototype; only polls reach local storage.
- Article discussions are presently created as local `article:${newsItemId}` records at [FanbaseContext.tsx (line 153)]\(/home/sleddogg/Desktop/FANatical code/app/src/features/fanbase/FanbaseContext.tsx:153).
- [FanbaseAreaViews.tsx (line 38)]\(/home/sleddogg/Desktop/FANatical code/app/src/features/fanbase/FanbaseAreaViews.tsx:38) directly imports mock News records.
- Polls and comments have no production database tables.

### Supabase

- [202608150001\_user\_profile\_foundation.sql (line 58)]\(/home/sleddogg/Desktop/FANatical code/supabase/migrations/202608150001\_user\_profile\_foundation.sql:58) provides `profiles`, `user_followed_teams`, and `user_settings` with owner RLS.
- Global team follows still store legacy frontend text IDs; News can resolve them through canonical identifiers without rewriting the account system initially.
- [202608190001\_team\_registry\_foundation.sql (line 17)]\(/home/sleddogg/Desktop/FANatical code/supabase/migrations/202608190001\_team\_registry\_foundation.sql:17) provides canonical Sports, Leagues, Teams, service/agent actors, capabilities, trusted publishers, evidence, and append-only version patterns.
- [202608190004\_complete\_master\_team\_seed.sql (line 12)]\(/home/sleddogg/Desktop/FANatical code/supabase/migrations/202608190004\_complete\_master\_team\_seed.sql:12) seeds Football, Baseball, Basketball, Hockey, and Soccer. Golf and Tennis are absent.
- [TEAM\_REGISTRY.md (line 3)]\(/home/sleddogg/Desktop/FANatical code/supabase/TEAM\_REGISTRY.md:3) confirms `team_primary_league` is singular and that frontend sports data is only a compatibility fallback.
- [202608230001\_trusted\_source\_publisher\_reliability.sql (line 17)]\(/home/sleddogg/Desktop/FANatical code/supabase/migrations/202608230001\_trusted\_source\_publisher\_reliability.sql:17) already supplies publisher aliases, URL scopes, common-control assignments, redirects, ambiguity handling, and historical provenance.
- [202608230004\_agent\_backend\_architecture.sql (line 12)]\(/home/sleddogg/Desktop/FANatical code/supabase/migrations/202608230004\_agent\_backend\_architecture.sql:12) provides generic job policies and tested lease/retry patterns.
- Its [durable wake outbox (line 615)]\(/home/sleddogg/Desktop/FANatical code/supabase/migrations/202608230004\_agent\_backend\_architecture.sql:615) and [recovery entrypoint (line 3712)]\(/home/sleddogg/Desktop/FANatical code/supabase/migrations/202608230004\_agent\_backend\_architecture.sql:3712) should be extended rather than replaced.
- SQL tests already prove duplicate safety, lease expiry, late-worker rejection, wake reconciliation, and recovery in [team\_color\_agent\_workflow\.sql (line 1634)]\(/home/sleddogg/Desktop/FANatical code/supabase/tests/team\_color\_agent\_workflow\.sql:1634).

There are currently no News, notification, discussion, article-rating, monitoring, or content-processing tables.

### Cloudflare and tooling

- [wrangler.web.jsonc (line 1)]\(/home/sleddogg/Desktop/FANatical code/app/wrangler.web.jsonc:1) and [wrangler.admin.jsonc (line 1)]\(/home/sleddogg/Desktop/FANatical code/app/wrangler.admin.jsonc:1) are asset-only Workers.
- [package.json (line 6)]\(/home/sleddogg/Desktop/FANatical code/app/package.json:6) has no RSS/XML/HTML/email parsing or Worker-runtime dependencies.
- [AdminApp.tsx (line 12)]\(/home/sleddogg/Desktop/FANatical code/app/src/admin/AdminApp.tsx:12) is an authenticated foundation with planned areas, not a functioning review console.

# 2. Migration and schema sequence

The names below are proposed names; each migration should include constraints, indexes, RLS, capability checks, read models, audit events, and transactional SQL tests.

## Migration 1 — Canonical Competition foundation

Add Golf and Tennis to `catalog_sports`, then add:

- `competition_kinds`: controlled/extensible kinds such as league, cup, championship, tournament, tour, series, and other.
- `catalog_competitions`: immutable Competition identity, public ID, Sport FK, and kind FK.
- `competition_identity_versions`: append-only names/status/current version.
- `competition_alias_versions`: historical aliases such as EFL Cup, League Cup, and Carabao Cup. Alias resolution may return ambiguity rather than guessing.
- `catalog_competition_identifiers`: provider and legacy identifiers.
- `competition_editions`: seasons or concrete tournament editions.
- `competition_relationship_versions`: time-bounded Competition-to-Competition facts such as Tournament-to-Tour.
- `competition_edition_relationship_versions`: edition-specific many-to-many relationships, including joint ATP/WTA participation.
- `competition_edition_team_participation_versions`: time-bounded Team participation. This is the complete participation record; it does not alter `team_primary_league`.
- `catalog_league_competition_links`: one compatibility link from every existing League to its generalized Competition.
- `news_filter_groups` and `news_filter_group_competitions`: presentation groups only.

Do not add a universal participant abstraction. Add typed person/player participation later when player requirements exist.

## Migration 2 — Publisher, person, contributor, and Show identities

Reuse:

- `trusted_sources` as publisher/publication-brand identity.
- `trusted_source_alias_versions`, URL scopes, redirects, and ownership/independence assignments.
- `source_independence_groups` as common-control groups.

Add:

- `news_publisher_policies`: remote-preview-image allow/deny/takedown, monitoring/publication state, and official-team relationships.
- `catalog_people`: persistent non-Auth human identities.
- `person_identity_versions`, `person_alias_versions`, and `person_identifiers`.
- `person_redirect_versions`: reversible merge redirects; reversal restores separate identities without deleting either history.
- `news_author_profiles`: marks supported, publicly followable Authors and holds factual public profile data.
- `news_organizational_contributors`: newsrooms, staff desks, wire services, and team organizations that must not become fake people.
- `news_publisher_contributor_profiles`: publisher-specific profile/byline identity, linked to exactly one human or organizational contributor.
- `news_author_publisher_relationship_versions`: employee, freelance, guest, contractor, columnist, contributor, or other historical relationships with evidence and effective dates.
- `news_official_team_publication_versions`: versioned Publisher/Team official-content relationships.
- `podcast_shows`, Show aliases, and Show identifiers.
- `podcast_show_publisher_relationship_versions` and `podcast_show_contributor_versions`: historical publisher, host, and contributor relationships.

Observed coverage should normally be derived from actual byline plus classification history. Profile-page coverage clues stay as Resolution evidence rather than becoming a second manually maintained truth.

## Migration 3 — News work, evidence, and review foundation

Add:

- `news_job_types`: controlled job type → Queue family → required capability mapping.
- `news_work_items`: status, availability, idempotency key, root correlation ID, claim owner, lease token/expiry, attempt count, and failure state.
- `news_work_attempts`: every time-bounded worker attempt.
- `news_work_events`: append-only lifecycle/audit events.
- `news_evidence_records`: immutable URL, publisher scope, observation time, response metadata/hash, and bounded structured extraction.
- `news_review_tasks`: one review queue for Resolution, byline, classification, deduplication, endpoint, policy, and gap exceptions.
- `news_fetch_hosts` and `news_host_fetch_leases`: cross-endpoint host circuit state and database-enforced per-host concurrency.
- `news_fetch_policy_versions`: approved fetch safety and crawler configuration. Do not seed unapproved values.

Reuse `agent_job_runtime_policies` for News lease/retry policies and `agent_work_wake_outbox` for durable wake delivery. Add News-specific wake read/ack RPCs so the Cloudflare identity cannot inspect or acknowledge Team Color work.

Add `recover_news_domain()` and `reconcile_news_wakes()` to the established recovery path. Do not misuse `catalog_domain_adapters` as a general ingestion registry.

## Migration 4 — Monitoring, Resolution, and Gap Detection

Add:

- `news_monitoring_endpoints`: Feed, Sitemap, Web Page, Newsletter, or API endpoint identity, URL, publisher, conditional-request state, status, and next due time.
- `news_monitoring_setups`: logical plan for monitoring an Author, Show, publisher, or official team.
- `news_monitoring_setup_endpoints`: many-to-many endpoint assignments with explicit primary/redundant/discovery roles.
- `news_monitoring_overlap_groups` and membership: only endpoints expected to overlap.
- `news_endpoint_runs`: immutable fetch/run result with work and correlation IDs.
- `news_endpoint_observations`: URLs, GUIDs, message IDs, timestamps, raw attribution, and normalized metadata observed by a run.
- `news_resolution_cases`: one operational investigation accepting a URL, request, byline, Show, or endpoint clue.
- `news_resolution_candidates`: non-canonical candidate outputs.
- `news_resolution_evidence`: links fetched evidence to a case.
- `news_resolution_decisions`: accepted, rejected, ambiguous, superseded, or reversed decisions.
- `news_gap_cases`: expected endpoint miss plus its actual failing stage and terminal/review state.

There is no universal endpoint score. Health read models derive facts from runs, observations, configured roles, and explicit overlaps.

## Migration 5 — News Items, manifestations, bylines, classification, and dedupe

Add:

- `news_items`: stable underlying work identity and kind.
- `news_item_versions`: append-only headline, summary, source publication time, and publication/policy state.
- `podcast_episodes`: one-to-one News Item subtype with Show, RSS GUID, enclosure metadata, and public destination.
- `news_manifestations`: individual publication/hosting occurrences for written pages, podcast pages, audio enclosures, or supported embeds.
- `news_manifestation_urls`: canonical, alternate, redirect, and tracking-wrapper URLs for a manifestation.
- `news_manifestation_item_assignment_versions`: reversible assignment of each manifestation to an underlying News Item.
- `news_representative_manifestation_versions`: one current sticky fan-facing destination per News Item.
- `news_byline_mentions`: ordered raw attribution on each manifestation.
- `news_byline_resolution_versions`: resolved person, organizational contributor, and publisher profile with evidence/review state.
- `news_item_classification_versions`: one table with explicit nullable Sport/Competition/Edition/Team FKs and a constraint requiring exactly one target. Multiple rows allow multiple factual classifications.
- `news_classification_evidence_links`: decision provenance.
- `news_dedup_decisions`: alternate/syndicated/independent outcome, evidence, suppression state, supersession, and reversal.
- `news_item_policy_decisions`: published, excluded, suppressed, needs-review, or other explicit terminal state.
- `news_manifestation_previews`: remotely referenced social-preview image and status.

A manifestation can exist while unresolved. Publication requires a current item assignment, representative manifestation, acceptable policy decision, and any required byline/classification decisions.

## Migration 6 — Phase 4 follows, feed, display suppression, and opens

Add:

- individual follows for human Authors, organizational contributors, and Shows,
  retaining person-merge provenance;
- All/Sport/Team follow scopes, with no scope row meaning All coverage;
- followed-identity mute state using the approved 7-day and 30-day durations;
- per-fan, per-Item Dismiss state with Undo;
- governed followability and signed-out Demo configuration;
- `news_outbound_open_events`: immutable events for opens FANatical actually initiated.

Add RPC/read models:

- `get_my_news_feed(filter, cursor, optional_page_size)`; the Phase 4 frontend
  imposes no invented page limit.
- `search_news_follow_targets`.
- `get_news_navigation`.
- governed follow, unfollow, scope, mute, unmute, Dismiss, and Undo operations;
- Author, organizational-contributor, and Show profile reads;
- a zero-follow EXAMPLE reader limited to a current followable official-Team
  newsroom identity, with the controlled static example as fallback;
- an anonymous Demo read constrained to the governed configured universe.

The feed RPC first calculates eligible items from explicit individual follows,
active mute state, subject-specific attribution-review state, and optional
All/Sport/Team follow scopes. It then intersects that set with temporary
All/Sport/Competition/Team filters and removes that fan's dismissed Items. It
sorts by original publication time with a stable ID tie-breaker. Publisher News
policy and wire status are not eligibility. Do not materialize one feed row per
user.

Missing-identity requests, fulfilment, and notifications remain Migration 7 /
Phase 5 work. They do not appear as placeholder Phase 4 controls.

Legacy account Team IDs should be resolved through `catalog_team_identifiers` inside the feed boundary. A destructive account migration is unnecessary for the first News slice.

## Migration 7 — Community and engagement

Add a minimal reusable Community foundation:

- `community_discussions`, with a unique nullable `news_item_id`.
- `community_comments`, including parent-comment relationship and moderation state.
- `community_comment_reactions` and `community_reports`.
- `community_polls`, with `discussion_id` but no uniqueness constraint.
- `community_poll_options`.
- `community_poll_votes` or immutable vote events, according to the approved voting rule.
- `news_rating_events`: immutable rating, revision, or withdrawal events with a previous-event chain.
- `news_reaction_events`: after the reaction rule is approved.

`get_or_create_news_discussion(news_item_id)` should be an atomic upsert. The first comment or poll can materialize it; concurrent attempts still produce one row.

Do not create rating-value constraints until the rating scale is approved.

## Deliberate non-tables

Do not add:

- A second publisher registry.
- Publisher-follow records.
- Per-user feed materializations.
- Full third-party article-body storage.
- Filter groups as article classifications.
- A universal participant table.
- A universal endpoint score.
- A second Postgres queue competing with `news_work_items`.

# 3. Cloudflare runtime sequence

## Repository layout

Recommended implementation:

- `app/wrangler.news.jsonc`
- `app/workers/news/index.ts`
- `app/workers/news/handlers/scheduled.ts`
- `app/workers/news/handlers/queue.ts`
- `app/workers/news/handlers/email.ts`
- `app/workers/news/adapters/`
- pure parsing/domain modules under `app/src/domain/news/`
- a separate Worker TypeScript/test configuration

This leaves `fanatical-web` and `fanatical-admin` unchanged.

## Handler boundaries

- **Scheduled handler:** invokes Supabase recovery, creates due endpoint work, reads pending News wakes, sends work IDs to the proper Queue, and acknowledges a wake only after successful Queue submission. It never fetches publisher content.
- **Queue handler:** validates the message, claims the exact DB work item, runs its registered stage, persists output, and completes/fails the lease through RPCs.
- **Email handler:** validates the configured recipient/sender context, parses MIME, removes personalized information, records a Newsletter observation, and creates normal processing work.
- **Future browser Worker:** separate deployment, Queue, actor, capability, and review gate. It must not be a silent fallback for ordinary fetch failures.

## Queue families

Start with:

- `fanatical-news-monitor`: Feed, Sitemap, Web Page, API monitoring.
- `fanatical-news-process`: fetch, extract, resolve, byline, classify, dedupe, publish, and gap work.
- Corresponding DLQs.

Provision `fanatical-news-notify` only if an external delivery channel is approved. In-app request notifications can be created transactionally in Supabase.

A browser Queue is future-only.

## Lifecycle and duplicate safety

1. Supabase inserts or re-enables a `news_work_item` and emits a unique wake.
2. Dispatcher sends `{work_id}` plus non-sensitive correlation metadata.
3. Consumer claims through `FOR UPDATE SKIP LOCKED`.
4. Duplicate messages either fail to acquire the same lease or find terminal work and are acknowledged harmlessly.
5. Once work is claimed, domain failures transition through database retry policy; the current Queue delivery is acknowledged.
6. Cloudflare delivery retries are reserved for failures before a durable DB transition.
7. DLQ handling records a delivery failure against the work ID; the database remains capable of recovery or review.
8. Recovery expires leases, rejects late workers, repairs stranded next-stage work, and recreates missing wakes.

Cloudflare Queues support consumer limits, retries, and DLQs, but all those values need explicit configuration rather than inherited defaults. [Cloudflare Queue configuration](https://developers.cloudflare.com/queues/configuration/configure-queues/)

## Fetch safety

Every outbound request must use one shared fetch adapter that:

- Accepts only approved HTTPS public destinations.
- Rejects credentials, disallowed ports, local names, IP literals in private/reserved ranges, and malformed hostnames.
- Resolves and validates A/AAAA results before each request and redirect.
- Enables `global_fetch_strictly_public`.
- Revalidates every redirect destination.
- Uses the approved FANatical User-Agent/contact.
- Checks applicable robots rules for Web Page monitoring.
- Acquires the database host lease before network access.
- Enforces approved timeout, compressed/decompressed size, redirect, and content-type policies while streaming.
- Handles conditional Feed/Sitemap requests.
- Applies endpoint/host backoff and circuits through database policy.
- Never logs secrets, raw newsletter tokens, or retained bodies.

Cloudflare documents that `global_fetch_strictly_public` forces global fetches through the public Internet path, while its outbound proxy restricts access to internal services. Application-level URL and redirect validation remains necessary. [Compatibility flag](https://developers.cloudflare.com/workers/configuration/compatibility-flags/#global-fetch-strictly-public), [Workers security model](https://developers.cloudflare.com/workers/reference/security-model/)

## Local development and deployment

- Continue using the existing local Supabase stack.
- Run the Worker through Wrangler with local Queue persistence and fixture HTTP servers.
- Feed raw RFC-formatted email fixtures into Wrangler’s local Email handler. Cloudflare provides a local inbound-email route specifically for this. [Email Worker local testing](https://developers.cloudflare.com/email-service/local-development/routing/)
- Local Queue execution is supported, but local consumer concurrency is not; concurrency and host-lease behavior therefore require a controlled deployed canary. [Queue local development](https://developers.cloudflare.com/queues/configuration/local-development/)
- Add a local-only Auth service actor and gitignored Worker secrets.
- Add `dev:news`, `test:news-runtime`, and eventually `deploy:news` scripts.
- Do not run `deploy:news`, create Queues/Cron/Email routes, or apply hosted migrations without explicit approval.
- Before completion, compare local migrations with the linked Supabase project, obtain approval for pending migrations, apply them normally, and verify RLS/RPCs/constraints in the hosted project.

# 4. Content-processing sequence

1. **Trigger:** due endpoint, fan-submitted public URL, Newsletter email, or podcast Feed observation creates durable work.
2. **Dispatch/claim:** Queue receives only the durable work ID; consumer acquires a DB lease.
3. **Endpoint fetch:** apply host safety, robots where applicable, conditional headers, content checks, and operational policy.
4. **Observation:** record endpoint run and each URL/GUID/message observation idempotently.
5. **Destination normalization:** resolve tracking wrappers, redirects, canonical/alternate URLs, and publisher URL scope.
6. **Metadata extraction:** extract headline, source publication time, summary, canonical URL, JSON-LD, byline/profile links, podcast metadata, and allowed social-preview image. Article body may be parsed transiently but is not normally retained.
7. **Resolution:** one case may discover publisher, Author, contributor profile, affiliation, Show, endpoint candidates, and Monitoring Setup. Each output remains separately durable.
8. **Byline Resolution:** normalize variants, preserve ordered coauthors, resolve publisher profiles/IDs, represent organizational contributors, and send same-name ambiguity to review.
9. **Classification:** create evidence-backed Sport/Competition/Edition/Team decisions. Never infer every current competition from a Team mention.
10. **Deduplication:** apply exact URL/provider/GUID evidence first; distinguish syndication from independent reporting; review ambiguous similarity rather than inventing a confidence threshold.
11. **Content policy:** enforce public written/podcast v1, access state, image policy, and explicit excluded terminal states.
12. **Canonical assignment:** assign manifestation to the correct underlying work and select or retain the sticky representative destination.
13. **Publication:** create a published News Item version.
14. **Fan eligibility:** computed at feed read time, not stored during ingestion.
15. **Community:** provide the canonical discussion identity; materialize on first comment or poll.
16. **Request fulfillment:** resolution of a requested Author/Show creates an idempotent notification for every requesting fan.
17. **Gap Detection:** compare only configured overlapping sensors and preserve the exact failing stage.

Every fetch, Resolution, byline, classification, dedupe, policy, publication, notification, and gap stage can independently complete, retry, become terminal, or create review work.

# 5. UI conversion sequence

1. Add `newsRepository.ts` and production card/filter/profile models. Components receive canonical read models rather than raw Supabase rows.
2. Replace hard-coded Sport/League unions with canonical IDs and Competition-aware filter selections.
3. Initialize temporary News state from the global selected Team’s canonical mapping. Remove every `selectTeam()` call from News.
4. Keep filters in component/URL state only. Filtering another Team or Competition must not alter `TeamContext`.
5. Rebuild `NewsFilterMenu` from the row-based navigation RPC around the
   approved temporary All/Sport/Competition/Team selections, using canonical
   Competition IDs.
6. Replace the prototype source-management surface with **Add to Feed**:
   - Add: shared navigation plus direct Author/Show search.
   - Following: human Authors, organizational contributors, and Shows only.
   - How It Works: explain explicit individual eligibility.
   - Search uses relevance with alphabetical ties; unsearched browsing is alphabetical.
   - Preserve future selectable Highest Rated and Most Followed sorts without
     computing ratings or cross-fan follower totals in Phase 4.
7. Convert cards:
   - Publisher identity for attribution.
   - Clickable FANatical Author/Show profile.
   - Correct classifications and publication time.
   - Written and podcast variants.
   - Remote preview with publisher policy, `no-referrer` behavior, failure detection, and Sport icon fallback.
   - Direct public representative URL for headline/image/read action.
   - No local article body and no fake view count.
8. Remove `NewsItemOverlay` from normal written/podcast opening. Delete its obsolete styles once no route depends on it.
9. Remove Article Discussion's production import of the News mock catalog and
   remove its obsolete `?item=...` overlay link. A canonical News
   discussion-context repository remains Phase 5 work.
10. Add `/news/authors/:id`, `/news/organizations/:id`, and `/news/shows/:id`
    routes.
11. Add real Web Share/clipboard behavior.
12. Record outbound opens best-effort without delaying or blocking direct publisher navigation.
13. Add signed-out Demo Mode and keep its state isolated from account bootstrap.
14. Add ratings/reactions/poll controls only after their product decisions.
15. Remove `mockNewsData` and every production News prototype contract. Keep the
    explicitly deferred Article Discussion fixture and its types local to
    FANbase; test-only News fixtures stay inside their tests.
16. Preserve the current card layout, focus traps, app theme, reduced motion, and existing mobile breakpoints. When Current Team theme is active, the global selected Team should remain the app theme even while News temporarily filters elsewhere.
17. Add Golf and Tennis visual fallbacks through the existing `AppIcon` system without touching the intentionally untracked image files.

# 6. Bootstrap sequence

Use two distinct mechanisms:

- Structural Competition/filter-group seed data may be reviewed and applied through migrations with provenance.
- Volatile Authors, endpoints, Shows, and monitoring setups should use a reviewed bootstrap manifest and governed RPC/import path, not direct mutable production inserts.

Bootstrap by scenario rather than an arbitrary quantity:

- Hockey league/team writer.
- League-wide and NHL/junior crossover writer.
- Junior-only outlet.
- Official team newsroom.
- World Juniors and senior national-team distinctions.
- Multi-competition soccer writer.
- Domestic league/cup/continental classification.
- National-team soccer coverage.
- Golf Tour/Tournament relationship.
- Tennis Tournament related to more than one Tour.
- Independent public newsletter writer.
- Podcast Show and separate human hosts.
- Organizational/wire contributor.
- Shared-owner publications.
- Writer with publisher work and an independent publication.

Sequence:

1. Audit existing canonical Sports, Leagues, Teams, and identifiers before adding anything.
2. Add missing Competitions, Editions, aliases, and participation with evidence.
3. Review publisher identities and ownership groups through the existing registry.
4. Resolve people, contributor profiles, organizations, Shows, and affiliations.
5. Configure endpoints without activating unapproved schedules.
6. Exercise each monitoring method in a controlled canary.
7. Let real content populate observed coverage and expose missing filter groups.
8. Test alternate URLs, syndication, wire copies, same-name Authors, missing bylines, and ambiguous classification.
9. Activate explicit overlap groups only after actual endpoint behavior is understood.
10. Expand bootstrap only after safety, dedupe, and review checkpoints pass.

External aggregators may be used as miss signals, never as feed sources.

# 7. Testing sequence

## SQL and RLS

Test:

- Competition kinds, aliases, ambiguity, and legacy League mapping.
- Concurrent Team participation in domestic, cup, and continental editions.
- Tour/Tournament and multi-Tour edition relationships.
- Filter groups referencing canonical IDs without becoming classifications.
- Person/profile same-name ambiguity, historical affiliations, merge reversal, and split history.
- Organizational contributors never satisfying human Author FKs.
- Show follows independent of hosts.
- Publisher URL scope and ownership reuse.
- Work claim concurrency, duplicate wakes, late workers, lease recovery, retry exhaustion, and capability isolation.
- Manifestation alternate URLs, syndication, independent reporting, and sticky representative fallback.
- Reversible split without moving historical Community activity.
- Multi-Team and multi-Competition classifications with corrections.
- Author/Show eligibility followed by filter intersection.
- Publisher identity never becoming a normal follow target.
- Explicit organizational-contributor eligibility with no official-Team preference.
- Strict chronological order.
- Request notification idempotency.
- Discussion uniqueness under concurrency and multiple polls.
- Immutable rating history after the scale is approved.
- Anonymous, owner, runtime, reviewer, and public RLS boundaries.

## Pure TypeScript

Use fixtures for:

- RSS, Atom, standard Sitemap, News Sitemap, and Sitemap index parsing.
- Podcast RSS, GUIDs, enclosures, and episode pages.
- MIME Newsletter parsing and safe tracking-wrapper resolution.
- HTML metadata, JSON-LD, canonical URLs, byline/profile links, and preview images.
- Byline case/prefix/suffix variants, coauthors, same-name people, Staff/Newsroom, and missing attribution.
- URL normalization without destructive equivalence.
- Wire/syndication versus independent-reporting evidence.
- Classification aliases and explicit ambiguity.
- Robots parsing.
- SSRF cases: private/reserved IPv4 and IPv6, credentials, disallowed schemes/ports, redirects, DNS changes, decompression, and content-type failures.
- No logs containing credentials, newsletter tokens, raw bodies, or sensitive URLs.

## Worker integration

Test:

- Scheduled work creation and wake dispatch.
- Duplicate Queue delivery.
- Queue send success followed by outbox-ack failure.
- DB unavailable before and after claim.
- Consumer restart and expired lease.
- DLQ recording without losing durable work.
- Parent-stage completion followed by lost child wake.
- Email event to normal pipeline.
- Local Supabase Auth actor capability isolation.

Run a deployed canary for Queue concurrency because Wrangler does not simulate that locally.

## React and end-to-end

Rewrite current News tests to assert:

- Initial global Team context without global mutation.
- Canonical multi-Competition filters constrain eligible content only.
- Author and Show search/follow/unfollow.
- Individual organizational-contributor following with no Follow All control.
- Direct publisher opening and outbound-open recording.
- Author/Show profile routes.
- Written and podcast card variants.
- Image failure → Sport fallback.
- Discussion context and unique creation.
- Multiple polls and ratings after approval.
- Keyboard focus containment/restoration.
- Loading, empty, error, and signed-out states.
- No horizontal overflow at the existing phone, tablet, laptop, and desktop viewports.

Every phase should run local database reset/tests, backend verification, targeted Vitest, typecheck, build, Worker tests, Playwright, and `git diff --check`.

# 8. Implementation phases

| PhaseDeliverableReview before continuing |                                                                                                                       |                                                                                |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| 0                                        | Reconcile `Fanatical build page.md`; approve foundation choices and resolve wire eligibility                          | Product authority is singular and approvals recorded                           |
| 1                                        | Competition schema, League mapping, Golf/Tennis, aliases, Editions, participation, filter navigation RPC              | Hockey/Soccer/Golf/Tennis fixtures prove the model                             |
| 2                                        | Publisher reuse, people, Authors, organizations, Shows, affiliations, Admin review skeleton                           | Same-name, historical affiliation, and organization cases pass                 |
| 3                                        | Core News Items/manifestations/classification/dedupe plus manually inserted controlled records                        | A real-shaped chronological feed works without monitoring                      |
| 4                                        | Production News repository and UI conversion: feed, filters, Add to Feed, profiles, direct opens, Demo Mode           | Responsive/accessibility review and no global Team mutation                    |
| 5                                        | Requests, in-app fulfillment records, canonical News discussion, and News polls/ratings only where rules are approved | Request and Community uniqueness tests pass                                    |
| 6                                        | Work ledger integration and dedicated Worker shell; Feed adapter supports written RSS/Atom and podcast RSS            | Duplicate/recovery/security tests and local end-to-end path pass               |
| 7                                        | Resolution, byline, classification, dedupe, publication, and reviewer workflows over real canary content              | Ambiguous cases stop safely; no full bodies are retained                       |
| 8                                        | Sitemap, Web Page, API, and Newsletter adapters added incrementally                                                   | Publisher safety and endpoint-specific review after each method                |
| 9                                        | Overlap-based Gap Detection and adversarial bootstrap expansion                                                       | Stage-specific misses and terminal exclusions behave correctly                 |
| 10                                       | Hosted migration comparison, approved infrastructure provisioning, isolated production canary, beta rollout           | RLS, actors, queues, recovery, logs, publisher behavior, and rollback verified |

After Phase 1 contracts stabilize, pure parsers, Admin presentation, and React components can proceed in parallel against reviewed fixtures. Runtime consumers must wait for lease/RPC contracts; real bootstrap must wait for fetch safety; Gap Detection must wait for overlapping endpoint evidence; browser work must wait for demonstrated need.

# 9. Primary risks and checkpoints

- **Wrong identity merge:** preserve source identities, profile identities, evidence, and reversible redirects; review same-name cases.
- **Wrong syndication collapse:** keep manifestations and assignment history; default ambiguous cases to review, not a guessed score.
- **Feed eligibility drift:** enforce eligibility inside a tested RPC before applying temporary filters.
- **Legacy Team identifiers:** resolve through catalog mappings and test every bootstrap Team before relying on it.
- **Crawler harm:** central fetch adapter, host leases, robots handling, approved limits, structured host/endpoint circuits.
- **Queue dual authority:** Cloudflare carries only work IDs; all retry and terminal state remains in Supabase.
- **Copyright/privacy:** no normal full-body storage, minimized Newsletter evidence, token stripping, and an approved retention policy.
- **Remote-image privacy:** publishers still see the image request; use no-referrer behavior, sanitized URLs, explicit publisher controls, and a pre-beta privacy review.
- **Review backlog:** do not activate broad monitoring until the Admin review path exists and unresolved items stay out of feeds.
- **Publication-time anomalies:** retain both source publication time and first observation history; route implausible/conflicting times to policy review without inventing a threshold.
- **Cloudflare/Supabase credentials:** ordinary service principal, narrow capabilities, Cloudflare secrets only, and log-redaction tests.
- **Hosted drift:** completion requires linked migration comparison and hosted RLS/RPC verification, not merely local SQL files.

The recommended first implementation slice is Phase 0 followed by the canonical Competition migration.
