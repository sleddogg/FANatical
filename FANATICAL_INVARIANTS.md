# FANatical Invariants Register

> **STATUS: INDEPENDENTLY VERIFIED — LOCAL ENFORCEMENT SCOPE.**
> Enforcement and proof statuses were independently verified against the repository
> and local proof suites by Cursor on 2026-08-27. Hosted Supabase is separately
> verified current through `202608270004`; future hosted changes remain subject to
> FAN-RUN-04. A `Guaranteed` status describes the proved system rule, not a
> permanent assertion that every future hosted deployment remains in sync.

Rules that must not silently become false. Each entry states the rule in plain
English, where it is enforced, what proves it, and how much of that is actually
true today.

**Authoring and verification split**

- Claude drafted and reconciles this register.
- ChatGPT contributed the architecture/product half and ratifies product decisions.
- **A status may be promoted from Claimed to Guaranteed only by an independent
  verifier that did not build the underlying work.** The builder may supply
  evidence and tests but may not certify its own foundational work, per
  FAN-DEV-01.
- Cursor is the current independent verifier. That role is not permanently
  assigned; another independent verifier may fill it without any change to this
  register's structure.
- Codex currently builds.

**Status values**

`enforced + tested` · `enforced but unproven` · `documented only` ·
`settled — unbuilt` · `unclear`

**Bucketing convention**

An entry sits in the bucket its *weakest* part supports. Where a rule is proven
for one subsystem and unproven for another and the split is material, it is
written as two entries rather than one optimistic one.

**Source tags**

`C:` Claude repo-derived draft · `G:` ChatGPT architecture draft ·
`GK:` Grok blind audit, 2026-08-27 ·
`CV:` Cursor register verification, 2026-08-27

---

## Verification corrections incorporated

Recorded 2026-08-27 from the independent blind audit and Cursor verification
report (`audit/grok-blind-audit-2026-08-27.md` and
`audit/grok-register-verification-2026-08-27.md`). The reports remain historical
evidence; this register incorporates their corrections. Local verification is
complete, and hosted Supabase is current through `202608270004`. Individual entry
status lines below may still carry the older "hosted state pending" wording and
are corrected only by an independent verifier, never in place.

**The B1 and B2 fixes are locally proved.** `202608270001` plus
`profile_privacy.sql` bind profile-media metadata to the true owner's folder and
deny the old cross-user display-path rebind. `AccountBootstrap.test.tsx` proves
that first sign-in no longer writes the demo persona or unchosen demo follows to
a real account. Hosted presence and already-affected hosted records were not
inspected.

**Team resolution no longer guesses locally.** `202608270002` adds the
status-returning `resolve_catalog_team(...)` and makes
`resolve_catalog_team_id(...)` raise on a bare external identifier that maps to
more than one Team. `team_resolution.sql` directly proves canonical, unique
external, ambiguous and existing compatibility cases. Hosted presence remains
unknown under FAN-RUN-04.

**Current behavior is not automatically product authority.** Public-by-default
profiles, signed-URL lifetime, anonymous venue-map reads and device-local
sign-out are recorded below as current behavior / decision-needed items, not as
permanent FAN-* promises.

**Known coverage bias remains.** The original register was derived largely from
catalog and governance documentation. This revision adds the material account,
storage, session, product-honesty and privileged-execution omissions found by
the audits, while retaining every explicit proof gap.

---

# PART I — GUARANTEED

*Mechanically enforced and proven by an assertion that can be pointed to.*

## Identity and catalog integrity

**FAN-ID-01 — A Competition's and a Competition Edition's permanent public ID never changes.**
Enforcement: `protect_catalog_competition_identity()`, `protect_catalog_competition_edition_identity()` — `202608260001`
Proof: "canonical Competition public identities must be immutable"; "a Competition Edition permanent public ID must be immutable"
Status: enforced + tested · `C:ID-01` `G:ID-01`

**FAN-ID-02 — A Competition's Sport and kind are identity-defining and cannot be changed by ordinary mutation.**
Why: five same-Sport triggers read `sport_id` at write time; changing it silently invalidates relationships, mappings, participation and group scope. A genuine correction requires a governed replacement path, which Phase 1 deliberately does not expose.
Enforcement: `protect_catalog_competition_identity()`
Proof: "a canonical Competition Sport must be immutable"; "a canonical Competition kind must be immutable"
Status: enforced + tested · `C:ID-02` `G:ID-06`

**FAN-ID-03 — A Competition Edition never moves to a different parent Competition.**
Enforcement: `protect_catalog_competition_edition_identity()`
Proof: same-Sport and cross-Sport reassignment both rejected; "must retain its parent"
Status: enforced + tested · `C:ID-03` `G:ID-07`

**FAN-ID-04 — Every League has exactly one league-kind Competition sharing its Sport and permanent public ID.**
Enforcement: `complete_catalog_league_competition()` after-insert trigger; `validate_league_competition_mapping()`; migration-time consistency block
Proof: "League mappings must preserve public ID, Sport, and League meaning"; "a future League insert must atomically create its unverified league-kind Competition mapping"
Status: enforced + tested · `C:ID-04` `G:ID-04`

**FAN-ID-05 — League creation is atomic: failure to complete the Competition mapping rolls back the League rather than leaving a half-created catalog.**
Enforcement: same trigger, same transaction
Proof: "League completion failure must roll back the League instead of leaving a half-created record"
Status: enforced + tested · `C:ID-04` `G:ID-05`

**FAN-ID-06 — A League-to-Competition mapping is never deleted.**
Enforcement: `validate_league_competition_mapping()` raises on `DELETE`
Proof: "a durable League-to-Competition mapping must not be removable"
Status: enforced + tested · `C:ID-05`
Known consequence: a committed League and its Competition are permanently undeletable.

**FAN-ID-07 — Every legacy League compatibility identifier has a Competition counterpart.**
Enforcement: migration parity assertion; `complete_catalog_league_identifier()` trigger
Proof: "every legacy League identifier must have a Competition counterpart"
Status: enforced + tested · `C:ID-06`

**FAN-ID-08 — Factual Competition and Edition relationships never connect different Sports.**
Why: cross-Sport concepts belong in presentation groups, not the factual graph.
Enforcement: `validate_competition_relationship_sport()`, `validate_competition_edition_relationship_sport()`
Proof: "a factual Competition relationship must reject different Sports"; same for Editions
Status: enforced + tested · `G:ID-08`

**FAN-ID-09 — A presentation filter group is never a factual Competition.**
Enforcement: separate tables; no synthetic Competition is created
Proof: "a presentation filter group must not become a factual Competition" (scoped and unscoped cases)
Status: enforced + tested · `C:ID-07` `G:ID-09`

**FAN-ID-10 — A Sport-scoped group admits only that Sport's Competitions; an unscoped group may intentionally span Sports, and every member retains its own Sport identity.**
Enforcement: `validate_competition_filter_group_sport()`, `validate_competition_filter_group_scope()`
Proof: "a Sport filter group must reject a Competition from another Sport"; "an unscoped presentation group must accept two different Sports"; "historical cross-Sport membership must not block a new current Sport scope"
Status: enforced + tested · `C:ID-07` `G:ID-10`

**FAN-ID-11 — Competition resolution returns ambiguity rather than guessing.**
Enforcement: `resolve_catalog_competition(...)` returns `resolved` / `none` / `ambiguous`; `resolve_catalog_competition_id(...)` raises
Proof: "a genuinely ambiguous alias must be reported as ambiguous"; "the convenience resolver must reject rather than guess an ambiguous alias"
Status: enforced + tested; this entry is deliberately Competition-only · `C:ID-08` `G:ID-11`

**FAN-ID-12 — A Team keeps one canonical identity across promotion, relegation, qualification, cup and continental participation, and simultaneous Competitions.**
Enforcement: participation is Edition-scoped and additive; Team identity untouched
Proof: "one Manchester United identity must participate in four simultaneous Editions"; "promotion or relegation must retain one canonical Team identity"
Status: enforced + tested · `C:ID-09` `G:ID-02`

**FAN-ID-13 — A Team has at most one current primary League.**
Enforcement: partial unique index on `team_primary_league_versions where is_current`
Proof: "team_primary_league must remain singular per Team"; duplicate insert rejected
Status: enforced + tested · `C:ID-10`

## Versioning and history

**FAN-VER-01 — A verified Competition-family fact is never edited and never deleted; it may only transition from current to superseded.**
Enforcement: `protect_verified_catalog_version()` on all eight Competition version tables
Proof: "verified history must remain protected while governed supersession creates one current successor"; "every Competition version family must use verified-history protection" (`pg_trigger` catalog check)
Status: enforced + tested · `C:VER-01` `G:VER-03`

**FAN-VER-02 — Each Competition version family has exactly one current row per subject, with history retained.**
Enforcement: partial unique indexes `where is_current`
Proof: "all eight Competition version families must retain one historical row and one current successor"
Status: enforced + tested · `C:VER-02`

**FAN-VER-04 — Redirects, merges and reconciliation never rewrite historical evidence, observations or decisions.**
Enforcement: reconciliation is overlay-based
Proof: "redirect must not rewrite historical evidence source foreign keys"; "redirect reconciliation must not rewrite historical observations"; "a later lineage merge must not rewrite historical qualification observations"
Status: enforced + tested · `C:VER-04` `G:VER-04`

## Verification and source governance

**FAN-GOV-01 — At creation, a verification decision snapshots the exact policy, tier, applicability, URL-scope, independence and evidence versions on which it relies.**
Later edits to the referenced policy or source-governance rows do not automatically rewrite the stored snapshot. This entry does **not** claim that the decision row itself is immutable; see FAN-VER-06 and GAP-13.
Enforcement: decision creation and evidence provenance validation
Proof: "decision must snapshot supporting and conflicting evidence with immutable details"
Status: enforced + tested for snapshot creation · `C:GOV-01` `G:GOV-04`

**FAN-GOV-03 — Independence is explicit and governed. Different URLs, hostnames or brands never by themselves establish independence.**
Enforcement: "Approved publishers require a reviewed ownership independence group"; hostname sharing explicitly rejected as proof
Proof: independence reassessment and corroboration assertions in `trusted_source_publisher_reliability.sql`
Status: enforced + tested · `C:GOV-04` `G:GOV-03`

**FAN-GOV-04 — A publisher has at most one current trust tier per data type.**
Enforcement: current-tier uniqueness and trust-assignment workflow
Proof: "one publisher/data type must have only one current trust tier"
Status: enforced + tested · `C:GOV-05`

**FAN-GOV-05 — Trust tier and applicability are separate; narrowing applicability never changes tier.**
Enforcement: "Applicability table must not carry trust tier"
Status: enforced + tested · `C:GOV-06` `G:GOV-02`

**FAN-GOV-06 — Ambiguous evidence-URL ownership routes to source review rather than arbitrary publisher selection.**
Enforcement: source URL resolution preserves ambiguity
Proof: "ambiguous URL ownership must reject evidence"; path-prefix resolver assertions — `trusted_source_publisher_reliability.sql`
Status: enforced + tested · `C:GOV-07`

**FAN-GOV-11 — The active Team Color workflow requires three independent information lineages for normal research and at least one qualifying Tier 1–2 source; a second verifier round requires four lineages.**
Enforcement: active Team Color verification and agent runtime policies
Proof: "normal Team Color research must require three independent lineages"; "policy must require one Tier 1/2 source"; "Verifier 1 must require three lineages and Verifier 2 four lineages"
Status: enforced + tested · `CV:Team-Color-policy`

## Agent authority and controlled writes

**FAN-AGT-03 — A proposing actor can never verify its own proposal in a workflow whose policy requires independent verification.**
Enforcement: `review_catalog_proposal` refuses self-approval when `require_independent_verifier` is set; Team Color policy seeds it true
Proof: "Team Color Agent must be denied verification" — `team_color_agent_workflow.sql`
Status: enforced + tested · `C:AGT-03` `G:GOV-07`

**FAN-AGT-05 — Where a workflow's policy requires independent verification, verifier results are blinded and specialists never hand authoritative state to verifiers.**
Scope: applies to workflows that mandate blinded verification, currently Team Color.
Enforcement: blinded verifier-context construction and result separation
Proof: "blinded verifier context must not expose specialist palette, evidence, or proposal ID"; "generic verifier context must remain blinded while supporting a Quiz-shaped subject"
Status: enforced + tested · `C:AGT-05`

**FAN-AGT-07 — Retries, requeues, lease recovery, exception clearing and watchdog operations never grant authority the original work did not have.**
Backend policy, not the caller, owns retry and lease timing.
Enforcement: `AGENT_ARCHITECTURE.md`; capability separation; caller-selected retry timestamps rejected or ignored in favor of runtime policy
Proof: "permanent/configuration failures must not be blindly retried"; "reclaimed work must retain attempt history"; "specialist transient execution failure must ignore caller delay and retry immediately"; "specialist claim must ignore the legacy caller duration and use backend runtime policy"
Status: enforced + tested for the asserted retry, recovery, timing and late-worker cases · `C:AGT-08` `G:GOV-09`

## Runtime ownership

**FAN-RUN-01 — Postgres owns the durable agent-work ledger.** Work IDs, attempts, leases, evidence, review state and recovery state persist in Postgres.
Enforcement: ledger, lease and attempt-history tables in Postgres
Proof: "attempt history must retain lease expiry and retry outcomes"; "reclaimed work must retain attempt history"
Status: enforced + tested for the Postgres ledger; the Cloudflare executor boundary is FAN-RUN-08 · `C:SYS-08` `G:RUN-02`

## Account and privacy

**FAN-ACCT-02 — Profile media is owner-bound, and public delivery never exposes owner-only originals.**
A fan's profile, photo and visual-media metadata resolves only inside that fan's Storage folder. Third-party display access follows the true owner's visibility, never a claimant's. Public and other non-owner viewers may receive a permitted display derivative only; source/original objects remain owner-only.
Enforcement: owner RLS; four owner-path CHECKs; `private.profile_media_path_is_visible`; original-versus-display Storage policies — `202608270001`
Proof: `profile_privacy.sql` asserts the old cross-user `avatar_path` attack, library source/display path binding, malformed legacy-row denial, true-owner visibility, and owner/original versus viewer/display access under `SET LOCAL ROLE`
Status: enforced + tested locally. The CHECKs are `NOT VALID`, so malformed legacy rows require review through `private.profile_media_path_ownership_violations`; hosted state is unknown under FAN-RUN-04. · `C:ACCT-02` `GK:B1` `GK:M3` `GK:M4`

**FAN-ACCT-05 — First sign-in never overwrites a real account identity or follow state with hard-coded demo/prototype identity or unchosen demo follows.**
Locally held fan preferences may be migrated only when they are actual stored user state; mock defaults are not account data.
Enforcement: `migratePrototypeAccount` migrates stored preferences without calling `saveOwnedProfile` or importing default demo teams
Proof: three `AccountBootstrap.test.tsx` cases assert the profile write is absent, demo identity strings are not persisted, and demo teams are not written unless followed-team state already exists
Status: enforced + tested · `GK:B2`

---

# PART II — CLAIMED

*Settled and documented, or enforced but unproven. These read like guarantees and currently are not.*

## Identity and catalog integrity

**FAN-ID-16 — Team identifier resolution returns ambiguity rather than guessing.**
Exact canonical `team_id` matches take deterministic precedence. A unique bare external identifier remains compatible; the same external identifier attached to different Teams across namespaces returns every candidate, and the strict UUID resolver raises.
Enforcement: `resolve_catalog_team(...)` returns `resolved` / `none` / `ambiguous`; `resolve_catalog_team_id(...)` raises — `202608270002`
Proof: "an exact canonical Team public ID must resolve deterministically"; "one bare external identifier in two namespaces must report ambiguity"; "the strict Team resolver must raise instead of choosing a candidate" — `team_resolution.sql`
Status: enforced + tested locally by this implementation pass; independent promotion to Guaranteed and hosted state remain pending under FAN-DEV-01 and FAN-RUN-04 · `CV:GAP-06`

**FAN-ID-17 — Sport, League, Team and Venue permanent public IDs never change through ordinary mutation.**
Enforcement: `protect_catalog_public_identity()` protects both the internal UUID and `sport_id`, `league_id`, `team_id` or `venue_id`
Proof: **none in a permanent suite.** Cursor's rolled-back Team probe confirmed current enforcement but does not qualify as register proof.
Status: enforced but unproven · `CV:public-ID-immutability` · GAP-01

**FAN-ID-14 — `team_primary_league` is the Team's singular app-context League. Competition Edition participation is the factual membership record, and Competition-aware features use participation for membership questions.**
Enforcement: none — a query-discipline rule
Status: documented only; stated identically in the build spec and `TEAM_REGISTRY.md` · `C:NEWS-10` `G:ID-03`

**FAN-ID-15 — Catalog expansion uses durable governed workflows and never depends on anyone remembering a hidden companion record.**
Enforcement: partial — FAN-ID-04/05 make League expansion self-completing. Nothing generalises it.
Status: documented only · `G:ID-12`

## News identity and attribution

**FAN-NEWS-01 — A human Author is a persistent person identity that survives publisher changes.** Publisher-specific contributor profiles and bylines are linked evidence, not replacement people. · `C:NEWS-01` `G:NEWS-01`
Enforcement: `catalog_people`, publisher-specific contributor profiles, and time-bounded person/publisher relationship versions — `202608280001`
Proof: `news_identity_foundation.sql` proves same-name people remain distinct and one person's historical affiliation survives a publisher move
Status: enforced + tested locally; independent verification and hosted state remain pending under FAN-DEV-01 and FAN-RUN-04

**FAN-NEWS-02 — A stable public professional identity, including a pen name, is a valid Author identity.** A private or legal identity is not required to attribute journalism correctly. · `G:NEWS-02`
Enforcement: professional and pen-name kinds on versioned public person identities — `202608280001`
Proof: `news_identity_foundation.sql` creates and resolves a synthetic pen-name identity without legal/private identity data
Status: enforced + tested locally; independent verification and hosted state remain pending under FAN-DEV-01 and FAN-RUN-04

**FAN-NEWS-03 — A podcast Show is a persistent identity that survives host and network changes.** Host, contributor and network relationships are time-bounded records attached to the Show. · `C:NEWS-13` `G:NEWS-03`
Enforcement: stable `podcast_shows` identities plus versioned Show names, contributors and publisher/network relationships — `202608280001`
Proof: `news_identity_foundation.sql` retains one Show identity across synthetic host and network changes
Status: enforced + tested locally; independent verification and hosted state remain pending under FAN-DEV-01 and FAN-RUN-04

**FAN-NEWS-14 — News availability and monitoring policy is independent of factual verification trust.** News approval never grants verification authority; a factual trust tier never by itself determines News follow or feed eligibility. · `C:NEWS-14` `G:GOV-01`
Enforcement: News policy is versioned separately in `news_publisher_policy_versions`; no factual-governance field backfills or derives it — `202608280001`
Proof: `news_identity_foundation.sql` proves approved/Tier-1 factual governance leaves News status unreviewed and that an explicit News status remains independently recorded
Status: enforced + tested locally for the Phase 2 publisher-policy boundary; independent verification and hosted state remain pending under FAN-DEV-01 and FAN-RUN-04

**FAN-ATTR-02 — Merge and split decisions on ambiguous identities preserve history and are reversible; ambiguity is reviewed, never guessed.** · `C:ATTR-02` `G:NEWS-16`
Enforcement: immutable Resolution decisions/evidence and time-bounded `news_person_pair_state_periods` retain distinct, ambiguous and canonical-merge periods — `202608280001`
Proof: `news_identity_foundation.sql` proves ambiguity, explicit-bridge merge, manual reversal, and direct point-in-time state/canonical answers
Status: enforced + tested locally for Phase 2 person Resolution; independent verification and hosted state remain pending under FAN-DEV-01 and FAN-RUN-04

**FAN-ATTR-03 — A publisher/contributor relationship never implies employment.** Employee, freelance, contract, guest, columnist, contributor and unknown are distinct and recorded as what they are. · `C:ATTR-03` `G:ATTR-02`
Enforcement: governed relationship types and explicit time-bounded relationship versions — `202608280001`
Proof: `news_identity_foundation.sql` proves an unknown relationship and historical publisher move without inferring employment
Status: enforced + tested locally; independent verification and hosted state remain pending under FAN-DEV-01 and FAN-RUN-04

**FAN-ATTR-04 — Visible publisher attribution controls the public byline.** Hidden machine metadata alone — JSON-LD, meta tags, embedded fields — never overrides visible organizational attribution. Where the publisher itself publicly identifies the human Author elsewhere through a genuine public author, profile or byline identity, that public evidence may establish the human attribution. Hidden metadata remains usable as an internal resolution signal. · `C:ATTR-04` `G:ATTR-01`
Enforcement: governed explicit/supporting evidence classes and automatic Resolution rules reject hidden evidence as explicit and ignore hidden contradiction when non-conflicting visible public evidence establishes the identity — `202608280001`
Proof: `news_identity_foundation.sql` proves visible public evidence resolves despite contradictory hidden supporting metadata, while visible conflict routes to review
Status: enforced + tested locally for Phase 2 identity Resolution; independent verification and hosted state remain pending under FAN-DEV-01 and FAN-RUN-04

## Versioning and history

**FAN-VER-03 — Information-lineage and agent-policy version content is immutable and its history is never deleted.**
Enforcement: immutability and deletion-protection triggers
Proof: the cited lineage-merge test proves overlay history, not direct `UPDATE` or `DELETE` rejection; Cursor's rolled-back probe is not a permanent suite assertion
Status: enforced but unproven · `C:VER-03`

**FAN-VER-05 — A verified Team-registry fact is never edited and never deleted; it may only transition from current to superseded.**
Covers team colours, locations, logos, aliases, venue relationships, venue mappings.
Enforcement: `protect_verified_catalog_version()`
Proof: **none.** No test file exercises these families.
Status: enforced but unproven · `C:VER-01` · GAP-01

**FAN-VER-06 — Verified facts, verification decisions, relied-upon evidence, audit events, lineage, redirects and fan interaction history are never destructively rewritten or deleted.**
Scope: rejected or never-relied-upon candidate data may be cleaned up under a normal retention policy. The protected set is what a decision rested on, the trail recording it, and where fans actually interacted.
Enforcement: verified-row, audit and lineage protection cover part. `catalog_verification_decisions` currently has no privileged `UPDATE`/`DELETE` protection.
Status: documented only for the general rule; explicitly false for decision-row immutability · `C:VER-05` `G:VER-05` · GAP-13

## Verification and source governance

**FAN-GOV-02 — Governed verification must satisfy the active data-type policy's independent-evidence and high-trust minimums.**
Current non-Color policies seed two qualifying independent Tier 1–3 sources with at least one Tier 1–2 source. Team Color has the separately proved three-lineage rule in FAN-GOV-11.
Enforcement: `verification_policies` and evidence-validation workflows
Proof: non-Color Team-registry data types have no direct policy-floor suite, and GAP-02 permits privileged direct insertion of a verified row with no evidence
Status: enforced but unproven as a general rule · `C:GOV-03` · GAP-01, GAP-02

**FAN-GOV-07 — Factual data acquired by an agent enters as candidate / `imported_unverified`; it is never born verified.**
Enforcement: proposal RPCs and Competition backfill write `imported_unverified`; no universal row constraint exists
Proof: "a future League insert must atomically create its unverified league-kind Competition mapping" proves the Competition path
Status: enforced + tested on named proposal/Competition paths; documented only as a universal rule until GAP-02 closes · `C:GOV-10` `G:VER-01`

**FAN-GOV-08 — Nothing is verified without a verification decision behind it.**
Enforcement: **none.** `record_status='verified'` with a null `verification_decision_id` is accepted by every version table.
Status: documented only · `C:GOV-02` `G:VER-02` · GAP-02

**FAN-GOV-09 — Empirical reliability never grants governance trust.**
Enforcement: structural separation; `AGENT_ARCHITECTURE.md`
Status: enforced but unproven · `C:GOV-08`

**FAN-GOV-10 — Verified data does not become stale through the passage of time alone.** Recheck is driven by scheduled review, a known real-world event, a detected conflict or a manual request.
Why registered: any future "freshness" feature must be checked against it.
Enforcement: no age-derived state exists anywhere; recheck requires an approved trigger
Status: documented architectural invariant · `C:GOV-09` `G:VER-06`

**FAN-GOV-12 — Production Team Color proposal and verifier evidence may use only sources that are currently qualified for that data type and applicability.**
Qualification is rechecked when evidence is attached and again before an approved Team Color decision; an old qualifying snapshot does not permanently authorize a downgraded source.
Enforcement: `enforce_factual_source_qualification()` and `enforce_current_factual_source_qualification_decision()` — `202608230007`
Proof: "a rated but probationary source must be blocked from production evidence"; "a downgraded source must immediately lose production evidence eligibility"; qualified-evidence snapshot assertions. No permanent assertion directly rejects unqualified verifier evidence or a decision after later downgrade.
Status: enforced + tested for proposal-evidence attachment and downgrade; remaining verifier/decision-time cases are enforced but unproven, so the full rule remains Claimed · `CV:qualified-production-evidence`

**FAN-GOV-13 — Conflicting current trust assignments require reviewer resolution before a source redirect; the redirect path never chooses one automatically.**
Enforcement: redirect workflow raises on conflicting current assignments
Proof: **none** directly exercises the conflict case
Status: enforced but unproven; split from FAN-GOV-04 · `C:GOV-05`

**FAN-GOV-14 — Evidence attached to a selected publisher must fall inside that publisher's current approved URL scope.**
Enforcement: evidence attachment raises when the selected current scope does not own the URL
Proof: path-prefix resolution and ambiguous ownership are tested, but no assertion attaches an out-of-scope URL to a selected publisher
Status: enforced but unproven; split from FAN-GOV-06 · `C:GOV-07`

## Agent authority and controlled writes

**FAN-AGT-01 — Operational agents never receive a Supabase service-role key.** They authenticate as a `catalog_actors` row using the browser-safe project key plus their own credentials, and write only through governed interfaces.
Why: a service-role key removes every governance boundary at once and leaves no audit trail distinguishing the agent from the platform.
Enforcement: architecture and grants; authoritative writes use security-definer RPCs behind actor/capability checks
Proof: privilege-denial assertions prove grants, not RLS under an actual browser role
Status: enforced + tested for grants; RLS enforcement remains unproven, so the full rule is Claimed · `C:AGT-01` `G:GOV-05` · GAP-08

**FAN-AGT-02 — Every authoritative write requires a named capability whose scope covers the target.**
Enforcement: named capability checks across agent RPCs
Proof: multiple narrow-capability denials are asserted, but `has_catalog_capability` also accepts `*` and the grant RPC has no capability allowlist
Status: enforced + tested only when no wildcard grant exists; not a general guarantee · `C:AGT-02` `G:GOV-05` · GAP-09

**FAN-AGT-04 — Operational and queued authoritative work requires an active, unexpired lease owned by the acting actor.**
Scope: governs agent work queues; it does not imply that every future manual or administrative action needs a lease.
Enforcement: lease-owner/token/expiry checks across agent migrations
Proof: expiry, policy-selected duration, reclaim history and late-worker behavior are asserted; no permanent test invokes a mutating RPC with a missing or foreign live token
Status: enforced but unproven for the full ownership rule · `C:AGT-04`

**FAN-AGT-06 — Replacing a verified value requires the expected current version and an approved recheck trigger.**
Enforcement: verified replacement guards in Team Color submission and finalization
Proof: stale expected-current version and configured trigger lists are asserted; no permanent test submits a verified replacement with a missing trigger
Status: enforced but unproven for the full rule · `C:AGT-06` `G:VER-07`

**FAN-AGT-08 — Untrusted external content is evidence, never instruction.** Text from webpages, feeds, newsletters, publishers, users or third parties may influence candidate facts and classification, but never overrides system instructions, permissions, policies or verification rules.
Enforcement: `AGENT_ARCHITECTURE.md`
Status: documented only · `C:AGT-07` `G:GOV-08` · GAP-05

**FAN-AGT-09 — External retrieval alone can never promote content into verified factual truth.**
Scope: News and runtime systems may fetch public content. A successful fetch, and the content's own assertions, are never sufficient to establish a governed fact.
Enforcement: `AGENT_ARCHITECTURE.md`; capability and lease requirements; FAN-GOV-07
Status: documented, structurally supported · `C:AGT-09`

**FAN-AGT-10 — Operational agents modify controlled structured data through governed interfaces. They do not modify FANatical application code.**
Enforcement: agents authenticate against the database only; no repository or deployment access
Status: enforced by architecture, unprovable in SQL · `C:AGT-10` `G:GOV-06`

**FAN-AGT-11 — Every SECURITY DEFINER function uses a safe explicit `search_path`, and no SECURITY DEFINER function retains EXECUTE for PostgreSQL `PUBLIC`.**
Enforcement: current function definitions use `set search_path = ''`; grants are explicitly revoked from `PUBLIC`
Proof: `security_definer_hygiene.sql` scans every application SECURITY DEFINER in `public` and `private` and fails on either an unsafe path or PostgreSQL `PUBLIC` execution
Status: enforced + tested locally; independent verification and future hosted state remain subject to FAN-DEV-01 and FAN-RUN-04 · `CV:SECURITY-DEFINER-hygiene`

**FAN-AGT-12 — Privileged recovery executes only an explicitly approved, closed set of domain adapters; adapter registration must not become arbitrary function-execution authority.**
Enforcement: staff access protects registration, but `admin_register_catalog_domain_adapter` currently accepts a raw `regproc` that `run_agent_backend_recovery()` executes without a closed allowlist
Status: documented safety boundary, not enforced by the current adapter shape · `GK:M10` · GAP-14

## Runtime ownership

**FAN-RUN-02 — Admin access requires an active `staff_roles` row checked through RLS or `has_staff_access(...)`; browser and service-role clients cannot grant or mutate staff roles.**
Enforcement: grants, own-row SELECT policy and `has_staff_access(...)` — `202608180001`
Proof: Cursor's rolled-back browser and service-role probes were denied, but no permanent SQL test exercises those roles; frontend tests only parse the access shape
Status: enforced but unproven · `C:SYS-03` `G:RUN-05`

**FAN-RUN-03 — No Supabase secret key, service-role key, database password or Cloudflare API token is ever placed in a Vite or otherwise browser-bundled variable.**
Enforcement: `docs/production-deployment.md`. **No mechanical check.**
Status: documented only · `C:SYS-04` `G:RUN-06` · GAP-04

**FAN-RUN-04 — Hosted schema changes flow through migration history and are verified active in the hosted environment. Local completion is not hosted completion.**
Enforcement: `AGENTS.md`; `docs/production-deployment.md`
Status: documented only · `C:SYS-05` `G:RUN-07`

**FAN-RUN-05 — Web-hosting DNS changes are additive only; mail and authentication records are never modified.**
Scope: an operational and deployment safety rule, not core domain architecture.
Enforcement: `docs/production-deployment.md`
Status: documented only · `C:SYS-06`

**FAN-RUN-08 — Cloudflare executes work referenced by durable Postgres IDs; it does not own authoritative agent-work state.**
Enforcement: documented runtime architecture; Cloudflare code was not inspected in Cursor's verification pass
Status: documented only; split from the proved Postgres-ledger half of FAN-RUN-01 · `C:SYS-08` `G:RUN-02`

## Account and privacy

**FAN-ACCT-01 — Profile visibility is exactly `public` or `private`.**
Enforcement: table CHECK and `save_my_profile` validation
Proof: `profile_privacy.sql` round-trips both legal values but does not assert rejection of an illegal value
Status: enforced but unproven · `C:ACCT-01`

**FAN-ACCT-03 — Authentication and ownership are required for every profile write.**
Enforcement: function grants, `auth.uid()` checks and owner-only write RLS
Proof: no permanent suite invokes the write path as `anon` or asserts a cross-user table write denial
Status: enforced but unproven · `C:ACCT-03`

**FAN-ACCT-06 — Profile-media Storage uploads, updates and deletes stay inside the authenticated owner's first path segment.**
Enforcement: `storage.objects` policies compare `(storage.foldername(name))[1]` with `auth.uid()::text`
Proof: Cursor's rolled-back foreign-folder upload probe was denied, but `profile_privacy.sql` does not permanently assert the upload/write boundary
Status: enforced but unproven · `CV:owner-folder-uploads` · GAP-08

**FAN-ACCT-07 — A claimed handle is a 3–30 character, case-insensitive identity made only from ASCII letters, numbers and underscores, with no leading or trailing underscore.**
Numbers may lead and underscores may repeat. The entered casing is preserved for display, while ownership uses `lower(handle)`. The empty string is the unclaimed state. Reserved identities are case-insensitive and include the centrally maintained exact-name set and the entire `fanatical_` prefix. A presentation `@` is not stored as part of the handle.
Enforcement: private reservation registry; authoritative profile-write validation trigger; partial unique index on `lower(handle)`; unclaimed signup behaviour; clear collision handling in `save_my_profile` — `202608270003`
Proof: `profile_handle_integrity.sql` exercises every settled boundary, all required reservations, normalized collision rejection, multiple blank handles, casing preservation and owner changes through the authenticated RPC
Status: enforced + tested locally; independent verification and hosted state remain pending · GAP-12

**FAN-ACCT-10 — Operational agent/service identities are not fan identities and never claim public fan handles or appear in ordinary fan-only surfaces.**
Their permanent Auth user and `catalog_actors` identity remain intact independently of any technical profile row, profile visibility or handle state so capabilities, audit history, verification decisions and provenance retain the same actor. Shared Auth bootstrap may create a technical profile row, but the canonical fan-profile population excludes every profile linked to an agent/service actor, active or inactive. Fan discovery, tagging autocomplete, leaderboards and equivalent fan-only surfaces must use that enforceable population rather than assuming that every profile or Auth user is a fan.
Enforcement: `private.fan_profile_population`; operational check in `private.enforce_profile_handle_integrity()`; `private.can_view_profile()` fan-population join; migration preflight that refuses nonblank operational handles — `202608270004`
Proof: `operational_identity_handles.sql` proves technical-row retention, agent/service exclusion across active states, fan-facing RPC exclusion, direct and authenticated-RPC handle rejection, and preservation of the actor/Auth linkage
Status: enforced + tested locally; independent verification and hosted state remain pending

**FAN-ACCT-11 — A fan can never claim a handle matching an active operational actor's canonical identifier.**
Every agent/service `catalog_actors.actor_key` is automatically recorded case-insensitively in the central handle reservation registry without deriving a second operational name. The current reservation cannot be removed or reassigned while that actor is active. Manual reservations remain removable; an automatic reservation becomes removable after retirement or after the actor is renamed, while activation always recreates and validates the current reservation.
Enforcement: catalog-actor reservation trigger; actor-linked reservation provenance and lifecycle trigger; shared handle-namespace transaction lock; existing-claim rejection — `202608270004`
Proof: `operational_identity_handles.sql` proves agent and service reservation, punctuation-preserving actor keys, case-insensitive fan denial, active protection, rename/retirement release, reactivation, and collision-safe activation
Status: enforced + tested locally; independent verification and hosted state remain pending

## Product integration and truthfulness

**FAN-SYS-01 — Live Cheer readiness requires verified identity, verified primary league, verified primary venue relationship and a verified current venue map.**
Enforcement: `team_readiness` computes the condition, but the Cheer launch path does not read it
Proof: **none.** No test proves the product gate.
Status: documented only until the launch path consumes `live_cheer_ready` · `C:SYS-01` · GAP-01

**FAN-SYS-02 — While the temporary frontend fallback exists, `officialSportsDatabase.ts` never contradicts the canonical registry.**
Scope: a temporary compatibility invariant, retired — not violated — when the fallback is removed.
Enforcement: none. `user_followed_teams.team_id` is unconstrained text with no catalog foreign key.
Status: unclear · `C:SYS-07` `GK:M7` · GAP-07

**FAN-SYS-03 — Mock and prototype values never silently become canonical live account, News, Cheer, scoring, reward or history records.**
Mock surfaces must identify themselves as prototype presentation and stay outside authoritative persistence unless an explicit migration maps real user-held state. The locally proved FAN-ACCT-05 bootstrap case is one enforcement instance, not general coverage.
Enforcement: partial for account bootstrap; News, FANbase, Quiz, Cheer and profile rewards still contain mock/local surfaces
Status: documented only as a cross-product truthfulness boundary · `GK:B2` `GK:M6`

**FAN-SCR-01 — Fan Score and Fan Coins never influence each other.** Ad level, advertising exposure, purchases, Fan Coins, reward participation and other monetized behaviour never increase Fan Score, Sport IQ, leaderboard rank, predictor skill or other competitive standing — **and never preserve Fan Score from decay.** Monetized or reward-driven behaviour is not qualifying activity for any activity or decay calculation. Only genuine fan participation that would qualify independently of monetization may affect Fan Score activity or decay.
Enforcement: none — no schema exists
Status: documented only (core philosophy) · `C:SYS-02` `G:SCORE-04`

## Current behavior / decision needed — not ratified invariants

These entries deliberately use `CURRENT-*`, not `FAN-*`. They describe the
repository as observed on 2026-08-27 and must not be read as permanent product
authority.

**CURRENT-01 — New profiles default to `public`.** `profiles.visibility` has a
`public` default, and the public-viewer RPC is available to `anon`. Decision
needed: explicitly ratify public-by-default or replace it with an approved
privacy-onboarding rule. · `GK:M1`

**CURRENT-02 — A signed display-media URL issued while a profile is public may
remain usable after the profile becomes private until its bearer URL expires.**
The documented/client lifetime is approximately one hour with a five-minute
cache safety window. This is a delivery caveat to FAN-ACCT-02, not proof that
current visibility can revoke an already-issued bearer URL. · `GK:M4`

**CURRENT-03 — Venue mapping, section, exception, inventory-rule, override and
team-profile rows are readable by `anon`.** Decision needed before those rows
hold commercially sensitive inventory or seating information; current Cheer
still uses prototype data. · `GK:M12`

**CURRENT-04 — Sign-out uses Supabase's device-local scope.** Other devices'
refresh tokens remain valid. Decision needed for any future "sign out all
devices" or stolen-session response; the current button must not imply global
revocation. · `GK:M14`

---

# PART III — FUTURE

*Ratified product rules with no schema or code yet. Real invariants; simply unbuilt. Every entry is `settled — unbuilt`, enforcement `none`, proof `none`, unless stated.*

## News identity and following

**FAN-NEWS-04 — Following an organizational contributor qualifies only work actually attributed to that identity.** Following TSN Staff never means everything TSN publishes. · `C:NEWS-02` `G:NEWS-04`

**FAN-NEWS-05 — Written-news publishers are not broad follow targets.**
Valid follow targets are: human Authors; real organizational contributors such as TSN Staff, Sportsnet Staff, Canadian Press, Associated Press and Reuters; other genuinely distinct published contributor identities; and podcast Shows. A publisher does not become a follow target merely because it publishes news or hosts many writers. The previously considered small-publication exception was deliberately discarded. · `C:NEWS-03` `G:NEWS-05`

**FAN-NEWS-06 — FANatical never invents a composite identity such as "TSN NHL" to represent a scoped follow.** The identity stays `TSN Staff`; NHL is the scope. · `C:NEWS-04` `G:NEWS-06`

**FAN-NEWS-07 — Explicit follow creates feed eligibility; classification never does.** Order: explicit followed identity → optional follow scope → temporary News filter → chronological presentation. · `C:NEWS-05` `G:NEWS-07`

**FAN-NEWS-08 — A follow scope narrows eligibility and never broadens it.** A scoped follow may exclude work by the followed identity; it can never qualify work by a different identity. · `G:NEWS-08`

**FAN-NEWS-09 — Global Team context never creates a News follow and never makes any journalism automatically eligible — including official Team and newsroom journalism.** It drives onboarding, discovery, suggestions and initial temporary context only. · `C:NEWS-06` `G:NEWS-09`

**FAN-NEWS-10 — Changing a temporary News filter never mutates global or selected Team state elsewhere in the app.** · `C:NEWS-07` `G:NEWS-10` `G:UX-03`

**FAN-NEWS-11 — The personal News feed is ordered chronologically by publication time within the eligible scope.** Relevance scoring, engagement weighting, paid placement, source prestige and personalization weights never reorder it.
Why: this is the product's central promise. Any ranking layer converts FANatical into an algorithmic feed and makes "I follow this Author" stop meaning what the fan thinks it means. · `C:NEWS-12` `G:NEWS-11`

**FAN-NEWS-12 — Classification uses the most specific factual scope actually supported by evidence, and never more.** If evidence supports only Sport, classification stops at Sport. If Competition is supported, classify Competition. If Team is genuinely supported, classify Team. A mere Team mention never establishes Team classification. Unsupported specificity is never invented. · `C:NEWS-09` `G:NEWS-12`

**FAN-NEWS-13 — The zero-follow EXAMPLE card creates no follow and no eligibility**, appears only when the fan has zero actual News follows, and is not used merely because a chosen filter returned nothing. · `C:NEWS-08` `G:NEWS-14`

**FAN-NEWS-15 — Multiple qualifying follows never duplicate a News Item.** One canonical News Item produces one card — whether the fan follows several coauthors, or follows both an organizational contributor and a named human Author credited on the same item. · `C:NEWS-15` `G:NEWS-15`

**FAN-NEWS-16 — Selecting members of a filter group retains the real Competitions as the factual selection.** · `C:NEWS-11` `G:ID-09`

**FAN-NEWS-17 — A contributor becomes followable when FANatical has a stable public identity, evidence that the identity genuinely produces journalism or news, and a sufficiently reliable way to monitor or retrieve future work.** Followability never depends on factual verification trust tiers. No article-count, cadence or popularity threshold is defined; if one is later required it is a material value under FAN-DEV-04.

**FAN-NEWS-18 — FANatical is positive-selection based: fans receive journalism from identities they chose to follow. There is no separate negative-preference or block system competing with follow eligibility.** If a mute feature is later added, it is a temporary suspension of an existing follow, not a parallel eligibility system. No default mute duration is defined.

**FAN-NEWS-19 — A corrected factual classification applies to the item itself.** If a correction makes an item newly eligible for a fan, it appears at its original chronological position using its original publication time. It is never surfaced artificially at the top of the feed merely because the correction happened later. Corrections never rewrite prior fan interactions and never fabricate seen-history.

## Attribution

**FAN-ATTR-01 — Historical attribution stays attached to the item as published.** Later publisher moves, identity merges, host changes or relationship corrections never rewrite who the item was publicly attributed to at publication time. · `C:ATTR-01` `G:ATTR-03`

**FAN-ATTR-05 — Follows survive person merges and splits without silent reassignment.** On merge, follows redirect to the canonical identity. On a later split, follows that were unambiguous when created are restored from provenance; fans who followed during the ambiguous merged period are prompted to choose, never silently assigned. Enough durable provenance must be retained to reconstruct fan intent; no specific storage mechanism is mandated. · `C:ATTR-05` `G:NEWS-16`

## Deduplication and syndication

**FAN-DUP-01 — Deduplication distinguishes three cases and keeps them distinguishable:** alternate URLs for one manifestation, syndicated or rehosted copies of the same work, and independent journalism about the same event. · `C:DEDUP-02` `G:DEDUP-01`

**FAN-DUP-02 — Independent journalism is never collapsed merely because event, topic, headline, timing, Teams or opening text are similar.** · `C:DEDUP-02` `G:DEDUP-02`

**FAN-DUP-03 — Deduplication is reversible and evidence-preserving; suppression never destructively erases the records needed to unmerge a mistaken decision.** · `C:DEDUP-01` `G:DEDUP-03`

**FAN-DUP-04 — Reversing a dedup decision never rewrites historical fan interaction.** Comments, Polls, Ratings and reactions stay where fans actually interacted; a restored independent item gets its own discussion going forward rather than a guessed redistribution. · `C:DEDUP-03` `G:DEDUP-04`

**FAN-DUP-05 — For wire works, every manifestation is retained internally and one representative public destination is displayed.** The destination is global per canonical wire work and sticky unless it becomes unavailable; discussion attaches to the canonical News Item, never to the destination. · `C:DEDUP-04` `G:DEDUP-05`

## Destination and publisher obligations

**FAN-DEST-01 — FANatical does not republish third-party article bodies without explicit permission or licensing.** Absent permission the read target opens the publisher's public manifestation. · `C:DEST-01` `G:DEST-01`

**FAN-DEST-02 — Each canonical News Item has exactly one canonical FANatical discussion; the database relationship must prevent duplicate discussion roots.** An item may surface in many feeds and filters but resolves to one discussion container. · `C:DEST-02` `G:DEST-02`

**FAN-DEST-03 — FANatical-generated outbound opens are never labelled or presented as publisher views or readers.** · `C:DEST-03` `G:DEST-04`

**FAN-DEST-04 — Preview media is used for preview, not as licence to copy.** Publisher-provided preview and social metadata such as `og:image` may be used where appropriate. FANatical does not scrape article-body images to populate cards; remote-references publisher preview media rather than copying or caching it, unless explicit permission or licensing authorizes different handling; retains publisher preview-disable and takedown capability; and uses an appropriate fallback when preview media is unavailable or unusable. · `C:DEST-04` `G:DEST-03`

**FAN-DEST-05 — Email-only newsletter content with no public destination is not republished without permission.** Where the newsletter points to a public article, that public destination is used. Design consequence: a newsletter-only work may be undisplayable as a News Item at all, which bears on whether newsletter-only contributors can be followable under FAN-NEWS-17. · `C:DEST-05` `G:DEST-05`

**FAN-DEST-06 — The canonical article rating scale is 0–10.** The fan-facing control may present this as five stars with half-star increments; the stored canonical value remains 0–10. Rating revision and withdrawal mechanics, the reaction set, and Poll governance are deferred and are material values under FAN-DEV-04.

## Runtime ownership

**FAN-RUN-06 — Supabase/Postgres owns canonical News, catalog and community state** — not Cloudflare queues, browser state or agent-local memory. · `C:SYS-08` `G:RUN-01`

**FAN-RUN-07 — Cloudflare Queue messages carry durable work IDs, never authoritative work state.** Retrying or duplicating a message can never create a competing version of work state outside Postgres.
Why: queue delivery is at-least-once, so any state in a payload will eventually be processed twice. · `C:SYS-09` `G:RUN-03`

## Cheer and live participation

**FAN-CHR-01 — Browsing availability and Live launch eligibility are separate.** A Cheer may be browseable without being launchable. · `G:CHEER-01`

**FAN-CHR-02 — A Live Cheer launches only when the checked-in venue and seat mapping support every audience zone the Cheer uses** — Upper/Lower, Side A/B, End A/B, or any other routing it employs. · `G:CHEER-02`

**FAN-CHR-03 — Joining a Live Cheer never redefines its timeline.** The Cheer has a canonical start timestamp; a fan joining mid-Cheer synchronizes to the running timeline rather than restarting it or creating a second one. · `G:CHEER-03`

**FAN-CHR-04 — Monetization never interrupts a Live Cheer.** The full-length autoplay video ad occurs only after the Cheer ends. · `G:CHEER-04`

**FAN-CHR-05 — Generic and multi-sport Cheers stay routing-neutral in identity.** They may use default routing graphics for compatibility but never present as belonging to a specific Team or Sport, and launch eligibility still follows actual venue-zone support. · `G:CHEER-05`

## Scores, rewards and rankings

**FAN-SCR-02 — Fan Score is Team-specific.** It is not a league-wide or sport-wide identity score, and its leaderboards and ranks are per Team. · `G:SCORE-01`

**FAN-SCR-03 — Sport IQ is Sport-specific by default**, so casual activity in one Sport never drags down a fan's standing in their main Sport. · `G:SCORE-02`

**FAN-SCR-04 — A Sport must meet an approved sufficient-sample or qualification requirement before it affects any Overall Sport IQ.** Casual one-off attempts never automatically lower an overall measure. The numeric threshold is deliberately undefined and is a material value under FAN-DEV-04. Public percentile display is optional future presentation. Fan Score bands remain separate from Sport IQ qualification. · `G:SCORE-03`

**FAN-SCR-05 — Predictor performance retains Sport-specific meaning.** Overall views may exist; the Sport-specific record is never erased. · `G:SCORE-05`

**FAN-SCR-06 — Earned competitive awards are durable historical records.** Trophies, season titles, Predictor titles and equivalent awards — for example "Top Oilers Pre-Game Predictor — 2026" — remain part of FANatical's historical competition record, so repeat winners, multi-time champions and historical leaderboards stay meaningful. A later change in current standing never revokes a historical award.

**FAN-SCR-07 — Current Fan Score represents current fandom and activity, not a permanent lifetime high-water mark.** Long inactivity may reduce current Fan Score under a future approved scoring or decay system. Qualifying activity means genuine fan participation that would qualify independently of monetization: watching ads, purchases, Fan Coins and reward participation neither increase Fan Score nor count as activity preventing decay (see FAN-SCR-01). No decay threshold, cadence, percentage or formula is defined; all are material values under FAN-DEV-04. This rule and FAN-SCR-06 are deliberately complementary: current standing moves, historical awards do not.

## Account, privacy and retention

**FAN-ACCT-04 — Explicit account deletion retains only the minimum permissible historical award record necessary to preserve competition history.** Identifiability, anonymization and retention mechanics are explicitly deferred to the later privacy and retention policy and are not defined here. If a returning person can later be safely re-associated with historical awards through an approved identity process, those awards may be reattached. Both the retention policy and the identity process are material decisions under FAN-DEV-04.

**FAN-ACCT-08 — The permanent fan identity is the stable internal account/user ID; it never changes, is never displayed, and is never derived from or replaced by a handle or display name.** Trophies, follows, comments, tags, history and every other fan-owned record belong to that permanent identity. Handle and display name are mutable facts attached to it: a handle is a case-insensitively unique public label while claimed, while a display name is non-unique and is never an identifier. Renaming a handle never changes ownership. If a released handle is later claimed by someone else, the new holder receives only the label and inherits none of the prior holder's mentions, trophies, follows or history. A handle use resolves to the identity holding it at the time of the action.
Enforcement: none
Proof: none
Status: settled — unbuilt

**FAN-ACCT-09 — Tags and mentions reference the permanent fan identity, never handle text.** A historical tag displays the tagged fan's current handle rather than the text originally typed, so a rename continues to identify the intended person and a later handle reassignment cannot rebind history. This is deliberately distinct from FAN-ATTR-01: a News byline preserves what a publisher published as a fact about the past, while a tag records which person the fan meant as an identity pointer that follows that person.
Enforcement: none
Proof: none
Status: settled — unbuilt

## User context and accessibility

**FAN-UX-01 — Core actions never depend on hover alone.** Hover may add labels or delight on desktop; essential meaning and actions remain available to touch, keyboard and screen-reader users. · `G:UX-02`

---

# PART IV — PROCESS INVARIANTS

*Rules governing AI-assisted development. Proportional to consequence: ordinary low-risk work does not carry milestone ceremony.*

**FAN-DEV-01 — Independent review for meaningful milestones.** The builder is not the sole final verifier of meaningful milestone, foundational, security-sensitive, data-integrity, financial or production-runtime work. Ordinary low-risk implementation does not require independent certification.
Currently: Codex builds, Cursor verifies, Claude reviews adversarially. This is FAN-AGT-03 applied to tooling rather than to the database. · `G:DEV-01`

**FAN-DEV-02 — Invariant review where relevant.** A meaningful change that could affect a registered invariant is checked against the relevant invariant(s) before production. Changes that cannot reasonably affect an invariant do not require an invariants review. A green local test suite is not sufficient where a change can violate a cross-system rule no test covers. · `G:DEV-02`

**FAN-DEV-03 — One implementation owner per overlapping change set.** During audited work, one builder owns each overlapping area. Other agents may review, test, audit or work independently on unrelated areas, but do not simultaneously rewrite the same work under review. · `G:DEV-03`

**FAN-DEV-04 — Never invent material numbers.** Material thresholds, percentages, cadences, retry intervals, scoring bands, qualification requirements and other operating constants are never silently invented where they affect product behaviour or architecture. If a required material value is genuinely undecided, implementation stops for an explicit decision. · `G:DEV-04`
*Currently gated by this rule: Overall Sport IQ qualification; Fan Score decay parameters; rating revision and withdrawal mechanics; the reaction set; Poll governance; mute duration if mute is added; deletion retention policy; the approved identity process for award re-association; handle release behaviour, cooldown length, handle history, redirects and any versioning of past handles.*

**FAN-DEV-05 — Approval and verification proportional to blast radius.** Consequential hosted-state changes require explicit approval and post-change verification appropriate to their risk. Small, routine, reversible changes do not require the ceremony owed to database migrations, permissions, infrastructure, security or financial systems. · `G:DEV-05`

**FAN-DEV-06 — A named test proves nothing until it asserts something.** A file whose name implies verification, or a suite that runs as a superuser, does not establish the behaviour it appears to cover. Status in this register may only be raised on evidence that a test exercises the rule under the conditions the rule is about. · `GK:M5`

**FAN-DEV-07 — Any automation that creates or processes a record for “every X” states exactly which population X includes, and that population is mechanically selectable or enforceable rather than assumed.** Shared storage or authentication machinery does not make operational actors, administrators, organizations or other technical principals members of a fan-only population. A change must name the canonical population boundary it uses before applying bulk/bootstrap, discovery, ranking, notification or equivalent behaviour.

**FAN-DEV-08 — Review scope, escalation and deferral discipline.**

A reviewer may expand the current task only when the added work is necessary to:
prevent a concrete defect; prevent violation of a settled invariant; prevent an
unsafe, irreversible, security-sensitive, identity, permission, financial or
data-integrity failure; resolve a material architectural contradiction; prevent
an implementation that cannot actually satisfy the approved request; or surface a
material product decision, threshold, rule or behaviour that has not been
approved and that no agent may decide on Brad's behalf.

For a claimed concrete risk the reviewer must be able to state plainly what
breaks, for whom, and under what condition. If that cannot be stated, the concern
normally does not expand the current task.

Anything deferred is written somewhere durable: invariant or enforcement concerns
to this register; concrete future work to `FANATICAL_BACKLOG.md`; deferred
product context may also be referenced from the applicable section of
`Fanatical build page.md`. Deferred work is never left only in conversation.

Brad is the product authority. Technical implementation choices are resolved by
builders and reviewers unless they materially change product behaviour, user
trust, live data, security, cost, durable architecture or an approved invariant.

Where reviewers disagree: technical disagreements that preserve the same approved
behaviour are resolved through evidence without escalating; disagreement
involving product behaviour, material risk, architecture or an unresolved
decision is presented to Brad clearly; whichever reviewer spoke last does not
automatically win. Where reviewers disagree only on severity, record both views
and use the more cautious classification for live data, identity, security or
permissions until evidence resolves it, otherwise continue the current work
unless the disagreement independently meets the task-expansion bar.

A reviewer is rewarded for preventing meaningful failures, not for maximising the
number of additional tasks.

---

# PART V — OPEN ENFORCEMENT GAPS

**GAP-01 — Most of the Team registry still has no direct proof suite.** `team_resolution.sql` now proves canonical and ambiguity-safe Team resolution only. `submit_team_registration_proposal`, `team_readiness`, `admin_grant_catalog_capability`, `protect_catalog_public_identity`, `team_alias_versions`, `team_logo_versions`, `team_location_versions`, `team_venue_relationship_versions` and `venue_mapping_versions` still have no direct assertions. `team_readiness` is not consumed by Live Cheer; `admin_grant_catalog_capability` is the entry point to FAN-AGT-02.

**GAP-02 — A verified row can be written with no decision behind it.** Schema accepts `record_status='verified'` with a null `verification_decision_id`. Documented as forbidden, unenforced in SQL.

**GAP-04 — FAN-RUN-03 has no mechanical guard.** One mistaken `VITE_` prefix embeds a privileged secret in the browser bundle. Highest consequence in the register, protected by prose alone.

**GAP-05 — FAN-AGT-08 is prose only** — and News ingestion is where it gets tested for real.

**GAP-07 — FAN-SYS-02 is unverified**, and `user_followed_teams.team_id` is unconstrained text with no catalog foreign key, so a fan can persist a team the catalog does not know. · `GK:M7`

**GAP-08 — Most SQL suites still do not test RLS under a real role.** `profile_privacy.sql` and `news_identity_foundation.sql` now use `SET LOCAL ROLE`; most other suites still set a JWT claim and call SECURITY DEFINER RPCs while connected as `postgres`, which bypasses RLS. Those suites prove capability checks, not table-level access control. Affects the remaining proof basis of FAN-AGT-01. · `GK:M5`

**GAP-09 — The wildcard `*` catalog capability defeats FAN-AGT-02 and nothing prevents granting it.** `has_catalog_capability` matches the required capability or `'*'`, and `admin_grant_catalog_capability` validates the capability string against no allowlist. · `GK:M11`

**GAP-11 — Nothing schedules agent recovery.** `run_agent_backend_recovery()` exists and is capability-gated, but no scheduler calls it. Stale leases will not recover themselves in production. · `GK:M9`

**GAP-13 — Verification decisions are not append-only.** `catalog_verification_decisions` has insert-time snapshot triggers but no privileged `UPDATE`/`DELETE` protection. Cursor's rolled-back probe rewrote `policy_snapshot` and deleted the row. This remains a history-integrity gap in FAN-GOV-01/FAN-VER-06, not a browser-role write path.

**GAP-14 — Recovery adapters expose an oversized `regproc` execution surface.** `admin_register_catalog_domain_adapter` accepts a raw function reference and `run_agent_backend_recovery()` executes it as a SECURITY DEFINER function. Staff gating reduces reach but is not the closed allowlist required by FAN-AGT-12. · `GK:M10`

## Closed locally; hosted state still follows FAN-RUN-04

**GAP-03 — CLOSED LOCALLY: the Supabase frontend client is generated-schema typed.** `backend:types` generates `database.types.ts` from the disposable local schema, the shared client carries the `Database` generic, and the Phase 2 Admin repository consumes the generated view/RPC types. Future hosted state remains governed by FAN-RUN-04.

**GAP-15 — CLOSED LOCALLY: SECURITY DEFINER hygiene now has a permanent catalog assertion.** `security_definer_hygiene.sql` fails when any application SECURITY DEFINER in `public` or `private` lacks the approved empty `search_path` or remains executable by PostgreSQL `PUBLIC`. Future hosted state remains governed by FAN-RUN-04.

**GAP-06 — CLOSED LOCALLY: Team resolution used to guess and now refuses ambiguity.** The old `UNION ALL ... LIMIT 1` could silently pick one Team across namespaces. `202608270002` replaces it with a status-returning resolver and strict raising wrapper; `team_resolution.sql` proves both ambiguity paths and compatibility. This is now FAN-ID-16, not an open local gap.

**GAP-10 — CLOSED LOCALLY: all profile-media metadata tables are owner-folder bound.** `202608270001` installs four `NOT VALID` owner-path CHECKs and a legacy diagnostic view; `profile_privacy.sql` asserts new library source/display writes and the old avatar rebind are rejected. The remaining legacy-row review is an explicit FAN-ACCT-02 caveat, not an unbound-table gap. · `GK:M3`

**GAP-12 — CLOSED LOCALLY: claimed handles now have authoritative format, reservation and case-insensitive ownership enforcement.** `202608270003` preserves entered casing, permits multiple unclaimed profiles, stops deriving handles from display names, rejects unsafe existing rows instead of rewriting them, and makes the normalized unique index the final ownership boundary. `202608270004` adds serialized operational-identifier reservation and fan-population separation without rewriting profile data. `profile_handle_integrity.sql` and `operational_identity_handles.sql` prove the settled local contract. Hosted state remains unknown under FAN-RUN-04. · `GK:M2`

---

# PART VI — ARCHITECTURAL PRINCIPLES

*Useful, but not falsifiable — you cannot identify the day they became false. Kept deliberately, outside the register.*

**PRIN-01 — Cloudflare runtime glue stays thin around portable domain logic.** · `G:RUN-04`

**PRIN-02 — Mobile is a primary platform, not a later compatibility target.** · `G:UX-01`

**PRIN-03 — Keep users inside the FANatical ecosystem where FANatical can provide the experience directly.** · build spec Core Rule

**PRIN-04 — Protect durable, high-cost foundations; treat ordinary application code as replaceable.** · `AGENTS.md`

---

# PART VII — DEFERRED MECHANICS

*Direction settled; material values deliberately not chosen. Gated by FAN-DEV-04.*

1. Overall Sport IQ sufficient-sample threshold (FAN-SCR-04).
2. Fan Score decay threshold, cadence, percentage and formula (FAN-SCR-07).
3. Rating revision and withdrawal mechanics (FAN-DEST-06).
4. The News reaction set, and Poll creation, voting and moderation governance.
5. Mute default duration and suspension semantics, if mute is added (FAN-NEWS-18).
6. The privacy/retention policy defining "minimum award record" and "anonymized" (FAN-ACCT-04).
7. The approved identity process for reclaiming historical awards (FAN-ACCT-04).
8. Handle release behaviour, cooldown length, handle history, redirects and any versioning of past handles (FAN-ACCT-08).

---

# CROSSWALK

Maps the two source drafts onto canonical `FAN-*` IDs. The old `INV-*`
namespaces collide — the same ID means different rules in each — so this table
is the only safe way to translate a reference from either draft.

| Canonical | Claude draft | ChatGPT draft |
|---|---|---|
| FAN-ID-01 | ID-01 (Comp/Ed) | ID-01 (part) |
| FAN-ID-02 | ID-02 | ID-06 |
| FAN-ID-03 | ID-03 | ID-07 |
| FAN-ID-04 | ID-04 | ID-04 |
| FAN-ID-05 | ID-04 | ID-05 |
| FAN-ID-06 | ID-05 | — |
| FAN-ID-07 | ID-06 | — |
| FAN-ID-08 | — | ID-08 |
| FAN-ID-09 | ID-07 | ID-09 |
| FAN-ID-10 | ID-07 (note) | ID-10 |
| FAN-ID-11 | ID-08 | ID-11 |
| FAN-ID-12 | ID-09 | ID-02 |
| FAN-ID-13 | ID-10 | — |
| FAN-ID-14 | NEWS-10 | ID-03, NEWS-13 |
| FAN-ID-15 | — | ID-12 |
| FAN-ID-16 | — | — |
| FAN-ID-17 | — | — |
| FAN-VER-01 | VER-01 (Comp) | VER-03 |
| FAN-VER-02 | VER-02 | — |
| FAN-VER-03 | VER-03 | — |
| FAN-VER-04 | VER-04 | VER-04 |
| FAN-VER-05 | VER-01 (Team) | VER-03 |
| FAN-VER-06 | VER-05 | VER-05 |
| FAN-GOV-01 | GOV-01 | GOV-04 |
| FAN-GOV-02 | GOV-03 | — |
| FAN-GOV-03 | GOV-04 | GOV-03 |
| FAN-GOV-04 | GOV-05 | — |
| FAN-GOV-05 | GOV-06 | GOV-02 |
| FAN-GOV-06 | GOV-07 | — |
| FAN-GOV-07 | GOV-10 | VER-01 |
| FAN-GOV-08 | GOV-02 | VER-02 |
| FAN-GOV-09 | GOV-08 | — |
| FAN-GOV-10 | GOV-09 | VER-06 |
| FAN-GOV-11 | — | — |
| FAN-GOV-12 | — | — |
| FAN-GOV-13 | GOV-05 (split) | — |
| FAN-GOV-14 | GOV-07 (split) | — |
| FAN-AGT-01 | AGT-01 | GOV-05, RUN-05 |
| FAN-AGT-02 | AGT-02 | GOV-05 |
| FAN-AGT-03 | AGT-03 | GOV-07 |
| FAN-AGT-04 | AGT-04 | — |
| FAN-AGT-05 | AGT-05 | — |
| FAN-AGT-06 | AGT-06 | VER-07 |
| FAN-AGT-07 | AGT-08 | GOV-09 |
| FAN-AGT-08 | AGT-07 | GOV-08 |
| FAN-AGT-09 | AGT-09 | — |
| FAN-AGT-10 | AGT-10 | GOV-06 |
| FAN-AGT-11 | — | — |
| FAN-AGT-12 | — | — |
| FAN-NEWS-01 | NEWS-01 | NEWS-01 |
| FAN-NEWS-02 | — | NEWS-02 |
| FAN-NEWS-03 | NEWS-13 | NEWS-03 |
| FAN-NEWS-04 | NEWS-02 | NEWS-04 |
| FAN-NEWS-05 | NEWS-03 | NEWS-05 |
| FAN-NEWS-06 | NEWS-04 | NEWS-06 |
| FAN-NEWS-07 | NEWS-05 | NEWS-07 |
| FAN-NEWS-08 | — | NEWS-08 |
| FAN-NEWS-09 | NEWS-06 | NEWS-09 |
| FAN-NEWS-10 | NEWS-07 | NEWS-10, UX-03 |
| FAN-NEWS-11 | NEWS-12 | NEWS-11 |
| FAN-NEWS-12 | NEWS-09 | NEWS-12 |
| FAN-NEWS-13 | NEWS-08 | NEWS-14 |
| FAN-NEWS-14 | NEWS-14 | GOV-01 |
| FAN-NEWS-15 | NEWS-15 | NEWS-15 |
| FAN-NEWS-16 | NEWS-11 | ID-09 |
| FAN-NEWS-17 | open Q3 | open K3 |
| FAN-NEWS-18 | open Q1 | open K1 |
| FAN-NEWS-19 | open Q2 | open K2 |
| FAN-ATTR-01 | ATTR-01 | ATTR-03 |
| FAN-ATTR-02 | ATTR-02 | NEWS-16 |
| FAN-ATTR-03 | ATTR-03 | ATTR-02 |
| FAN-ATTR-04 | ATTR-04 | ATTR-01 |
| FAN-ATTR-05 | ATTR-05 | NEWS-16 |
| FAN-DUP-01 | DEDUP-02 | DEDUP-01 |
| FAN-DUP-02 | DEDUP-02 | DEDUP-02 |
| FAN-DUP-03 | DEDUP-01 | DEDUP-03 |
| FAN-DUP-04 | DEDUP-03 | DEDUP-04 |
| FAN-DUP-05 | DEDUP-04 | DEDUP-05 |
| FAN-DEST-01 | DEST-01 | DEST-01 |
| FAN-DEST-02 | DEST-02 | DEST-02 |
| FAN-DEST-03 | DEST-03 | DEST-04 |
| FAN-DEST-04 | DEST-04 | DEST-03 |
| FAN-DEST-05 | DEST-05 | DEST-05 |
| FAN-DEST-06 | open Q5 | open K5 |
| FAN-RUN-01 | SYS-08 | RUN-02 |
| FAN-RUN-02 | SYS-03 | RUN-05 |
| FAN-RUN-03 | SYS-04 | RUN-06 |
| FAN-RUN-04 | SYS-05 | RUN-07, DEV-05 |
| FAN-RUN-05 | SYS-06 | — |
| FAN-RUN-06 | SYS-08 | RUN-01 |
| FAN-RUN-07 | SYS-09 | RUN-03 |
| FAN-RUN-08 | SYS-08 (split) | RUN-02 (split) |
| FAN-CHR-01…05 | — | CHEER-01…05 |
| FAN-SCR-01 | SYS-02 | SCORE-04 |
| FAN-SCR-02 | — | SCORE-01 |
| FAN-SCR-03 | — | SCORE-02 |
| FAN-SCR-04 | — | SCORE-03 |
| FAN-SCR-05 | — | SCORE-05 |
| FAN-SCR-06 | — | open K6 |
| FAN-SCR-07 | — | open K6 |
| FAN-SYS-01 | SYS-01 | — |
| FAN-SYS-02 | SYS-07 | — |
| FAN-SYS-03 | — | — |
| FAN-ACCT-01 | ACCT-01 | — |
| FAN-ACCT-02 | ACCT-02 | — |
| FAN-ACCT-03 | ACCT-03 | — |
| FAN-ACCT-04 | ACCT-04 | open K6 |
| FAN-ACCT-05 | — | — |
| FAN-ACCT-06 | — | — |
| FAN-ACCT-07 | — | — |
| FAN-ACCT-08 | — | — |
| FAN-ACCT-09 | — | — |
| FAN-ACCT-10 | — | — |
| FAN-ACCT-11 | — | — |
| FAN-UX-01 | — | UX-02 |
| FAN-DEV-01…05 | — | DEV-01…05 |
| FAN-DEV-06 | — | — |
| FAN-DEV-07 | — | — |
| FAN-DEV-08 | — | — |
| PRIN-01 | — | RUN-04 |
| PRIN-02 | — | UX-01 |

---

# COUNTS

| Bucket | Count |
|---|---|
| Guaranteed — enforced + tested | 28 |
| Claimed — locally tested, independent verification pending | 12 |
| Claimed — enforced but unproven or only partially proved | 16 |
| Claimed — documented only or not universally enforced | 17 |
| Claimed — unclear | 1 |
| **Claimed total** | **46** |
| Future — settled, unbuilt | 45 |
| Process invariants | 7 |
| **Total invariants** | **126** |
| Current behavior / decision-needed items (not invariants) | 4 |
| Open enforcement gaps | 10 |
| Closed locally / hosted unknown gaps | 5 |
| Architectural principles | 4 |
| Deferred mechanics | 8 |

Roughly a quarter of this register is mechanically guaranteed by a direct local
assertion today. The largest block remains settled-but-unbuilt News, Cheer and
scoring, while the larger Claimed bucket now reflects Cursor's proof-quality
corrections instead of optimistic test-name or exception-string citations.
