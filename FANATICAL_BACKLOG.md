# FANatical Backlog

Work owed later. Every entry is something deliberately deferred until a known
condition, not something forgotten.

**How this differs from the other documents**

- `Fanatical build page.md` — product and architecture intent. Authoritative for
  what FANatical is meant to do.
- `FANATICAL_INVARIANTS.md` **gaps** — something is wrong or insufficiently
  enforced *now*.
- `FANATICAL_INVARIANTS.md` **deferred mechanics** — a product number, rule or
  mechanic still needs a future decision.
- `FANATICAL_BACKLOG.md` (this file) — concrete work deliberately deferred until
  a known condition.
- `AGENTS.md` — how agents work on this repository.

This file is never authoritative over the build page or the register. Where an
entry exists because of a registered gap or invariant, it points at that ID
rather than restating it.

**Entry rule**

No trigger condition, no entry. A concern with no identifiable future trigger is
a worry, not backlog work.

**Read trigger**

Before starting a new feature area, implementation phase or product surface,
read this file for entries whose Trigger now applies. Only matching entries are
pulled into the current work. Unrelated entries never block progress.

**Closing**

Completed entries are moved to Done with a note of what closed them — a commit,
a migration, an explicit product decision, or an explicit decision not to
implement. Nothing is deleted, so audits do not rediscover resolved work.

IDs run from BL-001 and are never reused.

---

## Open

### BL-001
**What** — Make the Playwright end-to-end suite reliably runnable, including the
system dependencies its browser needs.
**Why deferred** — The browser installs without admin rights, but `--with-deps`
requires sudo and the fallback build is not officially supported on this OS. The
suite has value now; making it dependable is a separate job.
**Trigger** — Before the end-to-end suite is relied on as a gate for merging or
deploying.
**Required at trigger** — REQUIRED
**Origin** — Grok blind audit, coverage section; confirmed again in the frontend
deep audit.

### BL-003
**What** — Wire secret scanning into a repeatable automatic check rather than a
command someone remembers to run.
**Why deferred** — The scan itself is done and clean across all 45 commits, and
`.gitleaks.toml` is committed. Automating it is a separate step that touches
build configuration.
**Trigger** — Before anyone other than Brad gains write access to the repository,
or when any continuous integration exists.
**Required at trigger** — REQUIRED
**Origin** — `GAP-04`; conversation, 27 Aug.

### BL-006
**What** — Build the screen where a fan chooses and changes their username,
including the "already taken" and format error paths.
**Why deferred** — The handle contract was built first so the rules are
authoritative in the database before any interface can create bad data. No screen
currently references a handle at all.
**Trigger** — Before fans are asked to choose handles, and before tagging.
**Required at trigger** — REQUIRED
**Origin** — Frontend deep audit; `FAN-ACCT-07`.

### BL-007
**What** — Either build the public profile route or revoke the `anon` grant on
`get_profile_for_viewer` until it exists.
**Why deferred** — The capability exists in the database and nothing in the app
consumes it, so personal fields on public profiles are readable by anyone holding
a user ID for a feature that has not shipped. Current exposure is low because the
only affected profile holds prototype values.
**Trigger** — Before real fans enter genuine personal details, or when public
profile viewing is built — whichever comes first.
**Required at trigger** — REQUIRED
**Origin** — Frontend deep audit; conversation, 27 Aug.
**Assessment, 29 Aug 2026** — Phase 4 adds anonymous News Demo,
navigation, contributor-profile, contributor-item and outbound-open RPCs. Their
populations are mechanically bounded to the current governed Demo
configuration, an explicitly addressed current followable News identity, and
published fan-safe News rows. None calls `get_profile_for_viewer`, reads the fan
profile population, or exposes fan personal fields. BL-007 therefore does not
fire for Phase 4; its first real-fan-details/public-profile trigger is unchanged.

### BL-008
**What** — Provide a fan-population exclusion that browser-side queries can
actually apply, so operational identities never appear in fan-facing surfaces.
**Why deferred** — `202608270004` establishes the population boundary and
excludes operational identities from `can_view_profile`. Whether a browser query
can apply the same exclusion given current table permissions is unproven, and no
fan-facing discovery surface exists yet to prove it against.
**Trigger** — When the first fan-facing discovery surface is built: tagging
autocomplete, a fan directory, a leaderboard or equivalent.
**Required at trigger** — REQUIRED
**Origin** — `FAN-DEV-07`; conversation, 27 Aug.
**Assessment, 29 Aug 2026** — Add to Feed discovers only versioned, currently
followable News Authors (`catalog_people` plus `news_author_profiles`),
organizational contributors and Shows. It never queries `profiles` or treats an
Auth user, staff actor or service actor as a fan. This is contributor discovery,
not fan discovery, so BL-008 does not fire; tagging, fan-directory, leaderboard
or equivalent fan-population discovery remains its trigger.

### BL-009
**What** — Add direct proof for the untested Team registry surfaces.
**Why deferred** — The Competition foundation was proven first because it was the
active work. `team_readiness` gates a product surface that does not consume it
yet, so the risk is latent.
**Trigger** — Before Live Cheer readiness is relied on in product, or before
`admin_grant_catalog_capability` is used by anyone other than Brad.
**Required at trigger** — REQUIRED
**Origin** — `GAP-01`.

### BL-010
**What** — Constrain `record_status = 'verified'` to require a
`verification_decision_id`.
**Why deferred** — No governed Competition verification path exists yet, and the
current fixture inserts a verified row without a decision. Adding the constraint
requires restructuring that fixture.
**Trigger** — Before any Competition verification or promotion path is
implemented.
**Required at trigger** — REQUIRED
**Origin** — `GAP-02`; `FAN-GOV-08`.

### BL-011
**What** — Give verification decisions the same append-only protection audit
events already have.
**Why deferred** — Reachable only as a privileged role, not through any browser
path, so it is a history-integrity concern rather than a live exposure.
**Trigger** — Before any automated or agent promotion of Competition facts.
**Required at trigger** — REQUIRED
**Origin** — `GAP-13`; undercuts `FAN-GOV-01`.

### BL-012
**What** — Validate granted capability strings against an allowlist so the
wildcard cannot be issued casually.
**Why deferred** — Only Brad currently grants capabilities, and documentation
already says not to grant the wildcard.
**Trigger** — Before any operator other than Brad can grant capabilities.
**Required at trigger** — REQUIRED
**Origin** — `GAP-09`; defeats `FAN-AGT-02`.

### BL-013
**What** — Schedule agent recovery so stale leases recover without a manual call.
**Why deferred** — No agents run unattended in production yet, so nothing
currently goes stale.
**Trigger** — Before any agent runs unattended against hosted.
**Required at trigger** — REQUIRED
**Origin** — `GAP-11`.

### BL-014
**What** — Replace the raw `regproc` recovery adapter surface with a closed
allowlist.
**Why deferred** — Staff gating limits reach today and no domain adapters are
registered in production.
**Trigger** — Before any domain adapter is registered on hosted.
**Required at trigger** — REQUIRED
**Origin** — `GAP-14`; `FAN-AGT-12`.

### BL-016
**What** — Prove table-level access control under real roles in suites other than
`profile_privacy.sql`.
**Why deferred** — The grants and policies read as correct, and capability checks
are well proven. Rewriting suites to use `SET LOCAL ROLE` is substantial work
with no current defect driving it.
**Trigger** — Before any status in the register is raised to Guaranteed on the
strength of a suite that does not switch roles.
**Required at trigger** — REQUIRED
**Origin** — `GAP-08`; `FAN-DEV-06`.
**Progress, 28 Aug** — Phase 2 added real-role RLS proof for the News
Admin/review boundary. `supabase/tests/news_identity_foundation.sql` switches to
`anon` and `authenticated` and proves private review reads and mutations denied
to anonymous visitors and ordinary fans, with the intended review operations
available to authorized staff. That boundary is proven.
**Why still open** — `GAP-08` remains open. Most older SQL suites still set a JWT
claim and call SECURITY DEFINER RPCs while connected as `postgres`, which
bypasses RLS, so those areas prove capability checks rather than table-level
access control and are not yet proven for RLS enforcement. This entry was closed
on 28 Aug on the strength of the News suite alone and reopened the same day; the
trigger above is a standing guard on every future promotion, not a one-time task.

### BL-017
**What** — Retire the `officialSportsDatabase` frontend fallback and give
`user_followed_teams.team_id` a catalog foreign key.
**Why deferred** — The fallback is deliberate compatibility while consumers move
to the repository adapter. Removing it early would break the app.
**Trigger** — When the last consumer of the frontend fallback moves to the
repository adapter.
**Required at trigger** — REQUIRED
**Origin** — `GAP-07`; `FAN-SYS-02`.

### BL-019
**What** — Stop shipping internal Cheer routing diagrams and prototype photo
assets in the public browser bundle.
**Why deferred** — Not a secret leak and not a correctness problem, but it puts
internal reference material and personal-looking mock photos on the public site
and inflates the bundle well past its warning threshold.
**Trigger** — Before public launch or any marketing push.
**Required at trigger** — REQUIRED
**Origin** — Grok blind audit `M13`.

### BL-020
**What** — Replace the prototype persona values still on the `NorthStarFan`
profile with real ones.
**Why deferred** — The defect that wrote them is fixed; cleaning up what it
already wrote is separate, and the account belongs to Brad.
**Trigger** — Before that profile is visible to anyone other than Brad.
**Required at trigger** — REQUIRED
**Origin** — Grok blind audit `B2`; hosted verification, 27 Aug.

### BL-021
**What** — Fix the eight places where the frontend reads the clock or writes to a
ref while a component is rendering.
**Why deferred** — The linter that surfaced them was only installed on 28 Aug,
and none of the affected surfaces governs a real product outcome yet. Three read
`Date.now()` during render, affecting event counts, prediction cutoff state and
mute status. Five write refs during render, in `FanPhotosArea.tsx`,
`ProfileEditDialog.tsx` and the avatar and visual contexts.
**Trigger** — Before prediction cutoff, event counts or mute status govern a real
product outcome, or before any React concurrent rendering behaviour is relied on.
**Required at trigger** — REQUIRED
**Origin** — First ESLint run, 28 Aug; `react-hooks/purity` and
`react-hooks/refs`.
**Pulled, 29 Aug** — Phase 4 now has a database-time followed-identity mute
contract. The Phase 4 Following UI treats the owner-safe
`get_my_news_following().muted_until` value as active only when the database
reader returns it; that reader converts database-expired mutes to `null`, so no
frontend render-time clock read decides mute behavior. The triggered News slice
is complete; the broader entry remains open for its other seven affected
surfaces.

### BL-022
**What** — Clear the remaining lint warnings: 22 synchronous state updates inside
effects and 18 fast-refresh export findings.
**Why deferred** — Neither affects production behaviour. The effect findings need
individual review because several are deliberate state synchronisation, and the
fast-refresh findings affect developer hot reload only.
**Trigger** — When the lint run is made a merge gate, or when hot reload friction
slows News UI work.
**Required at trigger** — OPTIONAL
**Origin** — First ESLint run, 28 Aug; `react-hooks/set-state-in-effect` and
`react-refresh/only-export-components`.

### BL-024
**What** — Behaviourally prove the Phase 3 dedupe/assignment concurrency
protection using multiple database sessions. The proof must establish that
concurrent assignment and dedupe operations cannot commit contradictory canonical
state, that the locking order prevents avoidable deadlock, and that the deferred
consistency constraints actually fire under the relevant interleavings.
**Why deferred** — Phase 3 has a single governed writer path, and the immediate
contradiction checks are behaviourally proven across four scenarios. Codex also
added deferred constraint triggers and ordered locking as defence in depth, but
their actual multi-session concurrency behaviour is not yet proven — the current
assertion confirms the triggers are declared deferrable and that the lock helper
names appear in the function bodies, which is structural rather than behavioural.
A single-session transactional SQL suite cannot prove race or deadlock behaviour.
**Trigger** — Before a second concurrent writer can reach these paths —
specifically before Phase 6 automated ingestion runs concurrently with staff or
another writer.
**Required at trigger** — REQUIRED
**Origin** — Phase 3 independent closure audit. Use a real multi-session
concurrency proof, similar in spirit to
`supabase/tests/team_color_bootstrap_concurrency.sh`.

### BL-025
**What** — Centralize or otherwise mechanically govern the distinction between
News identity intake actions and Resolution outcome actions. Replace the repeated
action-name knowledge with one canonical, mechanically shared definition while
preserving the existing intake-versus-outcome supersession behaviour.
**Why deferred** — The current intake actions are consistent and correct, but the
same literal list — `open_case`, `create_publisher_contributor_profile`,
`record_candidate`, `record_evidence` — is repeated in several places in
`202608290002_news_identity_intake_boundary.sql`, twice inside
`normalize_news_identity_outcome_supersession` alone. Adding a future intake
action and missing one list would silently classify it as a Resolution outcome and
corrupt the outcome supersession chain.
**Trigger** — Before adding any new News identity decision action of any class.
**Required at trigger** — REQUIRED
**Origin** — News identity-intake completion independent audit.
**Widened, 29 Aug** — The trigger originally read "any new intake-class decision
action". `202608290003` then added `establish_official_team_publication` and
`correct_official_team_publication` without touching
`normalize_news_identity_outcome_supersession`. That was correct — the classifier
treats anything outside the intake list as an outcome, and both actions are
outcome-shaped for this case kind, so the supersession chain came out right — but
the trigger as written did not fire, and nothing recorded the reasoning. There
are now three conceptual categories of decision action (intake, Resolution
outcome, and factual relationship mutation on a non-identity case kind) being
sorted by one binary classifier. The trigger is widened so that adding any action
requires a conscious, recorded decision about which side it falls on.

### BL-026
**What** — Add governed canonical mutation paths and appropriately authorized
wrappers for the remaining News identity alias, external-identifier and publisher-
policy tables: `person_alias_versions`, `person_identifiers`,
`news_organizational_contributor_alias_versions`,
`news_organizational_contributor_identifiers`, `podcast_show_alias_versions`,
`podcast_show_identifiers` and `news_publisher_policy_versions`.
**Why deferred** — The tables preserve the approved Phase 2 data shape, but no
current product or canary needs to write these capabilities. Expanding the
official Team/publication correction into seven unrelated write paths would
broaden a verified narrow fix without evidence for each future workflow.
**Trigger** — Before the corresponding person/organization/Show alias capability,
external-identifier capability or News publisher-policy capability is required.
**Required at trigger** — REQUIRED
**Origin** — Phase 3 real-world canary #3 mutation-boundary audit, 29 Aug.

### BL-028
**What** — Define and implement the operational-actor retirement path for an
explicitly deleted account or removed staff/operational Auth user.
**Why deferred** — Historical decisions and provenance correctly retain
`catalog_actors` through `auth.users on delete set null`, but no account-deletion
or staff-user removal workflow exists yet to coordinate the rest of the actor
lifecycle.
**Trigger** — Before explicit account deletion is implemented, or before an
operational/staff user is removed from `auth.users`.
**Required at trigger** — REQUIRED: preserve historical attribution; explicitly
retire the actor; revoke active capabilities; reserve or deliberately release
its handle/actor key under the approved identity policy; and prevent an active
actor from remaining without its Auth user.
**Origin** — Gemini blind audit, 29 Aug 2026; transferred before removal of the
temporary report.

### BL-029
**What** — Add abuse and storage controls for anonymous
`record_news_outbound_open` events.
**Why deferred** — Phase 4 records only a validated Item/destination pair and
stores no caller-supplied payload beyond that pair, but anonymous callers can
still create unbounded valid events. Rate, retention and capacity values are
material operating choices and are not invented during local entry hardening.
**Trigger** — Before public launch of the anonymous News surface.
**Required at trigger** — REQUIRED: approve and enforce bounded abuse, rate,
retention and storage-capacity controls while keeping navigation independent
from recording success.
**Origin** — Phase 4 final correction review, 29 Aug 2026.

### BL-030
**What** — Inventory and resolve legacy rows reported by
`private.news_manifestation_public_destination_kind_violations`, then validate
`news_manifestation_public_destination_kind_check` when safe.
**Why deferred** — The local migration deliberately uses `NOT VALID`: it rejects
every new or updated public wrapper/redirect without scanning, rewriting or
guessing about hosted legacy rows. Hosted state was not read or changed during
Phase 4.
**Trigger** — Before validating this constraint in any environment, or before
claiming that every stored legacy manifestation URL already satisfies it.
**Required at trigger** — REQUIRED: run the diagnostic, review each row with its
provenance, repair through an approved governed path, validate the constraint,
and verify the resulting representative destinations. Never silently rewrite
the historical URL evidence.
**Origin** — Phase 4 representative-destination correction, 29 Aug 2026.

### BL-031
**What** — Sweep the remaining historical audit/review files one at a time under
the repository audit-artifact policy.
**Why deferred** — The two temporary Phase 4 inputs were reconciled in this
phase, but older audit files have not yet been mapped finding-by-finding to their
durable homes.
**Trigger** — Before deleting any remaining file under `audit/` as obsolete.
**Required at trigger** — REQUIRED: confirm every unresolved finding has a
durable home in code, a permanent proof, the build page, the invariant register,
this backlog or an approved audit brief; preserve useful historical evidence;
then remove only the specifically reconciled artifact.
**Origin** — Phase 4 audit-artifact reconciliation, 29 Aug 2026.

### BL-032
**What** — Decide and implement how a fan can discover an Item first ingested
after their feed cursor has already passed that Item's older source publication
time.
**Why deferred** — Phase 4 preserves the approved chronological order and stable
publication-time cursor, but no automated ingestion or durable per-fan read
cursor exists yet. Boosting a late-discovered older Item to the top would violate
FAN-NEWS-11 and could fabricate seen-history.
**Trigger** — Before automated ingestion and a durable incremental/resume cursor
are both used for personal News feeds.
**Required at trigger** — REQUIRED: approve and prove a discoverability/backfill
behavior that preserves the source publication time, chronological feed order,
stable pagination and truthful fan interaction history. Do not add a ranking or
silently re-date the Item.
**Origin** — Phase 4 pre-build review backlog finding; reconciled 29 Aug 2026
before removal of the temporary planning package.

---

## Done

### BL-027 — closed 29 Aug
**What** — Add a mechanical schema proof that every News-domain table either has
at least one governed canonical mutation path or is explicitly registered as
read-only-by-design.
**Closed by** — `202608290004_news_mutation_registry.sql` introduced the
table-to-operation registry and a migration-time assertion before the first
Phase 4 table. `202608290006_news_personal_feed_contract.sql` extends the
registry before creating its seven tables, and `news_mutation_registry.sql`
mechanically compares the registry with every current News-domain table. The
clean local rebuild and full SQL suite passed with all 61 tables registered.
**Origin** — Phase 3 real-world canary #3 mutation-boundary audit, 29 Aug.

### BL-023 — closed 29 Aug
**What** — Explicitly prove that a historical published byline remains attached
to the intended stable person identity across a later governed person merge,
including the resulting fan-facing byline and Author display.
**Closed by** — `202608290005_news_identity_destination_hardening.sql` added a
fan-safe single-person canonical resolver separate from the staff pair reader,
and `202608290006_news_personal_feed_contract.sql` applies it to follow and
fan-safe byline reads. The identity and Phase 4 proofs establish unchanged
historical `raw_attribution`, canonical links and follow redirection, and no
duplicate effective follows or feed cards across a governed merge.
**Origin** — Phase 3 correction review; attribution proof required before the
first fan-facing News read.

### BL-005 — closed 28 Aug
**What** — Make the frontend test suite pass at its own committed configuration.
**Closed by** — The supported deterministic local configuration is one worker
with a 20-second per-test ceiling in `app/vite.config.ts`. The default
`npm run test:run` command passes all 58 files and 315 tests without weakening
their assertions.

The 28 Aug diagnosis compared the same unchanged suite in four conditions:

- a parallel five-second run failed 3 Profile tests;
- the Profile file alone passed all 7 tests under the same five-second ceiling;
- the parallel suite passed all 58 files / 315 tests under a 20-second ceiling;
- a repeated parallel five-second run failed 10 different tests across Profile,
  Cheer, FANbase, and Create Quiz.

The host had four physical CPU cores and the parallel runs consumed roughly
275–301% CPU. The changing timeout set, isolated-file success, and unchanged
parallel success with enough completion time established host CPU/resource
saturation rather than a deterministic ordering, shared-state, timer, or
application race defect. A later wrong-page assertion was downstream spillover
from an already timed-out asynchronous test, not an independent failure.

**Decision** — One worker / 20 seconds is the explicitly supported deterministic
local test configuration. Parallel execution is neither supported nor proven.
Faster parallel CI is a future performance/infrastructure concern, not a blocker
for the current suite.

### BL-004 — closed 28 Aug
**What** — Generate Supabase types and pass them to the client so schema changes
fail typecheck instead of failing in the browser.
**Closed by** — `app/scripts/generate-supabase-types.mjs` and the
`backend:types` script generate `database.types.ts` from the disposable local
schema. The shared Supabase client now uses `Database`, and the Phase 2 Admin
repository consumes the generated view and RPC types.

### BL-015 — closed 28 Aug
**What** — Permanently assert safe `search_path` and no PostgreSQL `PUBLIC`
execution on every application SECURITY DEFINER.
**Closed by** — `supabase/tests/security_definer_hygiene.sql` scans all
`public`/`private` SECURITY DEFINER functions and fails if either condition is
violated, including the new Phase 2 functions.

### BL-018 — closed 28 Aug
**What** — Make a read-only migration ledger check the first step of any apply to
hosted.
**Closed by** — `AGENTS.md` and `docs/production-deployment.md` now require the
linked read-only ledger comparison before any hosted apply and require a stop on
any divergence other than hosted being simply behind local.

### BL-002 — closed 28 Aug
**What** — Add a linter to the frontend with a configuration that fails only on
new code initially.
**Closed by** — ESLint installed, with a `lint` script in `app/package.json` and
a committed `app/eslint.config.js`. The deferral premise turned out to be wrong:
the first run produced 52 warnings and 0 errors across 221 files, not hundreds.
Unused variables, unreachable code, Rules-of-Hooks and exhaustive-deps are
configured as errors in that file and none of them fired. The remaining warnings
are carried forward as BL-021 and BL-022.
