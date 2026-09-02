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
**Assessment, 31 Aug 2026** — Phase 5A's direct current-Fanatical-Name profile
route is not fan discovery. Its database reader resolves exactly one requested
name through `private.fan_profile_population`; it neither lists nor searches fans.
BL-008 therefore does not fire. Its first tagging, fan-directory, leaderboard or
equivalent discovery trigger remains Phase 5B or later.
**Assessment, 2 Sep 2026** — TRIGGERED NOW. Mention autocomplete is the first
fan-facing fan-discovery surface. It must use `private.fan_profile_population`.
This is not a public fan directory.

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
**Assessment, 31 Aug 2026** — Phase 5A community moderation does not use catalog
capabilities. It requires the exact `community_moderate` permission on an active
`staff_roles` row, and the real-role SQL suite denies a catalog wildcard actor.
BL-012 therefore does not fire; its capability-grant trigger is unchanged.

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
**Assessment, 2 Sep 2026** — Standing real-role rule. Any new Guaranteed Phase 5B
claim still requires a suite that switches roles. This entry is not a one-time
task and is not closed by Phase 5B planning.

### BL-017
**What** — Retire the `officialSportsDatabase` frontend fallback and give
`user_followed_teams.team_id` a catalog foreign key.
**Why deferred** — The fallback is deliberate compatibility while consumers move
to the repository adapter. Removing it early would break the app.
**Trigger** — When the last consumer of the frontend fallback moves to the
repository adapter.
**Required at trigger** — REQUIRED
**Origin** — `GAP-07`; `FAN-SYS-02`.
**Assessment, 2 Sep 2026** — NOT TRIGGERED unless the last
`officialSportsDatabase` fallback consumer moves. Phase 5B must safely resolve
existing Team Follow identifiers when calculating inheritance and must not
repeat that legacy design in new Follow tables, but it does not retire the
fallback or claim the legacy foreign-key work complete.

### BL-019
**What** — Stop shipping internal Cheer routing diagrams and prototype photo
assets in the public browser bundle.
**Why deferred** — Not a secret leak and not a correctness problem, but it puts
internal reference material and personal-looking mock photos on the public site
and inflates the bundle well past its warning threshold.
**Trigger** — Before public launch or any marketing push.
**Required at trigger** — REQUIRED
**Origin** — Grok blind audit `M13`.

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
**Assessment, 31 Aug 2026** — Phase 5A's seven-day comment edit window and
7/7/14/14-day Community restriction cadence are enforced by database
`statement_timestamp()` and returned as server decisions. No render-time clock
governs either outcome, so Phase 5A does not pull the unrelated remaining work.
**Assessment, 2 Sep 2026** — NOT TRIGGERED. Phase 5B uses database time for
rating, voting, Poll close, and similar deadlines. Do not pull leftover
render-clock sites that do not govern those outcomes.

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
**Assessment, 31 Aug 2026** — Add-to-Feed Requests introduce request-domain
submission and resolution RPCs, not a News identity decision action. Available
resolution accepts only an identity already followable under the Phase 4
authority and creates no intake/Resolution decision history. BL-025 therefore
does not fire.

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
**Assessment, 31 Aug 2026** — Phase 5A does not expand or change anonymous
outbound-open recording. Its anonymous Community surface returns only a bounded
discussion count teaser and no comment bodies. BL-029 remains tied to the public
launch of the anonymous News surface and is not pulled into 5A.

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

### BL-033
**What** — Add the missing permanent person-split reselection proof for the
split half of FAN-ATTR-05.
**Why deferred** — Phase 4 retains the original person and merge decisions on
each follow, excludes a follow whose recorded merge decision is no longer
current, and reports `needs_reselection` through Following. Existing permanent
proofs cover merge redirection and corrupt-graph recovery, but none performs a
governed merge and later governed split while comparing follows created before
and during the merged period. The split behavior is therefore enforced but
unproven.
**Trigger** — Before a person-split decision is used on hosted data, or before
FAN-ATTR-05's split half is claimed proven.
**Required at trigger** — REQUIRED: add a rollback-safe, real-role SQL proof
through the governed decision path showing that a pre-merge unambiguous follow
returns to its original person after the split, a follow created during the
ambiguous merged period is removed from feed eligibility and marked for
reselection, neither follow is silently reassigned, and the fan can still
manage the exact fan-owned follow.
**Origin** — Phase 4 documentation follow-up, 30 Aug 2026; `FAN-ATTR-05`.
**Assessment, 31 Aug 2026** — Phase 5A proves Request resolution against a current
followable target, including a governed Author-merge case, but it neither performs
nor relies on a hosted person split. The missing split-reselection proof remains
a Phase 5B-or-later gate under this entry's original trigger.
**Assessment, 2 Sep 2026** — NOT TRIGGERED. Journalist Score recomputation
against the current canonical identity is not FAN-ATTR-05 Follow reselection.

### BL-034
**What** — Populate and curate the hosted, staff-governed signed-out News Demo
universe.
**Why deferred** — Phase 4 built and deployed the governed Demo machinery, but
hosted currently holds no Demo configuration version and no selected Demo
identities. The safe fan-facing result is "Demo Mode is not configured yet"
rather than a fallback to fake, mock or local News content. Brad does not need
the public Demo curated yet and wants to consider it alongside the broader
signed-out FANatical experience once more surfaces such as Quiz, FANbase and
Cheer are further developed.
**Trigger** — When the broader signed-out/public FANatical experience is being
prepared for external beta, public evaluation, launch, or another situation
where signed-out visitors are expected to see a representative News experience.
**Required at trigger** — REQUIRED: choose and staff-approve the real News
identities and Items intended for the Demo universe, populate the governed
hosted configuration through the approved News/Admin path, and verify that
anonymous visitors can see only that configured fan-safe universe.
**Origin** — Phase 4 production closeout, 31 Aug 2026. The currently empty
hosted Demo universe is deliberate configuration state, not a Phase 4 defect.

### BL-036
**What** — Retire the legacy `public` profile-visibility compatibility and the
legacy `profiles.fanatical_name` compatibility behavior.
**Why deferred** — Both mechanisms preserve rollback compatibility while the
Phase 4 frontend remains the immediately previous rollback-capable production
frontend. Removing them during the local Phase 5A correction pass would make
that rollback unsafe.
**Trigger** — After the Phase 4 frontend is no longer the immediately previous
rollback-capable production frontend.
**Required at trigger** — REQUIRED: confirm the active and immediately previous
frontends no longer depend on either legacy value/path; inventory and safely
normalize any remaining compatible data; remove only the obsolete compatibility
logic; and re-prove current profile privacy and Fanatical Name reads/writes.
**Origin** — Phase 5A final audit reconciliation, 1 Sep 2026.
**Assessment, 2 Sep 2026** — Conditional at a later frontend promotion when the
Phase 4 frontend is no longer the immediately previous rollback-capable
production frontend. Phase 5B local work must remain compatible with that
previous frontend until then.

### BL-037
**What** — Establish a conscious, mechanically enforced mutation-governance
boundary before introducing a new mutable application-table domain outside the
currently governed News and Community domains.
**Why deferred** — No such new domain is part of Phase 5A. News and Community
already have scoped mechanical registries/assertions, BL-027 remains closed, and
universalizing governance across every historical table is not justified by the
current work.
**Trigger** — Before a future migration introduces the first mutable
application table in a new domain outside the currently governed News and
Community domains.
**Required at trigger** — REQUIRED: explicitly define the new domain boundary,
its canonical mutation operations, direct-role grants/RLS expectations, and a
migration-time mechanical assertion (or an approved equivalent) before the new
table is accepted.
**Origin** — Phase 5A final audit reconciliation, 1 Sep 2026.
**Assessment, 2 Sep 2026** — Not triggered if every new mutable Phase 5B table
stays in the governed News or Community domains. A third mutable domain would
fire this entry.

### BL-038
**What** — Make `supabase/tests/phase5a_community_requests.sql`'s signed-out
Team teaser assertions independent of a freshly reset database, or explicitly
document the suite as reset-dependent.
**Why deferred** — The suite is correct against a clean local rebuild today,
and Phase 5A has one governed writer path for these fixtures. The hard-coded
`comment_count: 0` assertions (around lines 219–229) assume no discussion
already exists for the fixture Team/context; that is only true immediately
after a reset.
**Trigger** — Before this suite is relied on as a repeatable regression or
merge gate, or before it is ever run against a non-reset or shared database.
**Required at trigger** — REQUIRED: either reset state before the affected
assertions, derive the expected count from the database rather than
hard-coding zero, or isolate the fixture context so no other suite or run can
have created prior discussion activity there.
**Origin** — Retired-thread verification pass (Codex-lane finding),
reconciled 1 Sep 2026; confirmed directly against
`supabase/tests/phase5a_community_requests.sql` lines 219–229.
**Assessment, 2 Sep 2026** — TRIGGERED NOW. Make the Phase 5A community suite’s
empty-count teasers reset-independent before relying on that suite as a
repeatable Phase 5B regression or merge gate.

### BL-039
**What** — Add direct SQL proof that Hide and Report remain available to a
suspended fan, matching the intended restriction scope.
**Why deferred** — The build page states Community restriction blocks new
posts, replies, edits, and deletes, while Hide/Unhide and Report remain
available; the code matches that intent —
`public.hide_community_user`, `hide_community_comment_author`,
`unhide_community_user`, `unhide_community_intent`, and
`report_community_comment` all call only `private.assert_community_fan`,
never `private.assert_community_participation_allowed` or
`assert_community_posting_allowed`. But no test in the current suite drives
Hide or Report from a suspended account, so the match between code and intent
is unproven, not just unenforced.
**Trigger** — Before the next Community SQL suite expansion, or before any
change routes Hide or Report through the suspension-enforcing helpers
(`assert_community_participation_allowed` / `assert_community_posting_allowed`),
even accidentally.
**Required at trigger** — REQUIRED: add a real-role SQL proof that a
suspended fan can still Hide and Report, and that Hide/Report remain denied to
the boundaries they were already denied to (Auth requirement, population
boundary) regardless of suspension.
**Origin** — Retired-thread verification pass (Codex-lane finding),
reconciled 1 Sep 2026; confirmed by tracing every caller of
`assert_community_participation_allowed` / `assert_community_posting_allowed`
against the five Hide/Report function definitions in
`20260831203022_phase5a_community_foundation.sql`.
**Assessment, 2 Sep 2026** — TRIGGERED NOW. Prove that a suspended fan can still
Hide, Unhide, manage Block, and Report, and that those actions remain denied to
the boundaries they were already denied to.

### BL-040
**What** — Add a cycle guard (visited-path or depth limit) to the recursive
descendant-count CTE in `public.get_community_discussion`.
**Why deferred** — Unreachable today: `parent_comment_id` is set once at
insert and never updated, and the `community_comments` tables are revoked
from `anon`/`authenticated`, so no path exists to create a cyclical parent
chain. Adding a guard now would be defensive code with no current defect
behind it.
**Trigger** — Before anything is built that can update `parent_comment_id`
after insert, including comment-import or comment-migration tooling,
moderation re-parenting, or any admin correction path.
**Required at trigger** — REQUIRED: add a visited-set or depth-bounded guard
to the recursive CTE so a cyclical parent chain terminates instead of
looping, and add a test that proves it.
**Origin** — Retired-thread verification pass, reconciled 1 Sep 2026;
confirmed by reading the recursive descendant-count CTE in
`get_community_discussion`, `20260831203022_phase5a_community_foundation.sql`.
**Assessment, 2 Sep 2026** — NOT TRIGGERED. Quote must not update
`parent_comment_id` after insert. A later parent-update path would fire this
entry.

### BL-041
**What** — Correct or replace the `phase-4-complete` tag so it points at the
actual Phase 4 closeout commit.
**Why deferred** — Not a code defect, and nothing currently resolves the tag
automatically; it is a documentation/reference-accuracy gap. Retagging is a
small, low-risk git operation but is still a deliberate repository action
outside a documentation-only pass.
**Trigger** — Before `phase-4-complete` is cited as the Phase 5A base state
in any audit, handoff, or rollback procedure, or before any tooling is built
that resolves this tag automatically.
**Required at trigger** — REQUIRED: move (or replace) the `phase-4-complete`
tag to commit `97f25c85` ("Phase 4 Complete"), confirm no existing reference
depends on the tag's current position, and note the correction wherever the
tag was previously cited.
**Origin** — Retired-thread verification pass, reconciled 1 Sep 2026;
confirmed by cloning the repository and unshallowing: `phase-4-complete`
resolves to `46cb51ce`, exactly one commit before `97f25c85`, its direct
descendant (`git rev-list --count 46cb51ce..97f25c85` = 1).
**Assessment, 2 Sep 2026** — Conditional. Cite commit SHAs unless the incorrect
`phase-4-complete` tag is used in a Phase 5B audit, handoff, or rollback
procedure.

### BL-042
**What** — Make a typed-name Request and a pasted-URL Request that are proven to
identify the same underlying Author, Show, or organizational contributor
converge on one canonical request target and one requester relationship per fan.
**Why deferred** — Phase 5A deliberately performs conservative same-candidate
dedupe: normalized repetitions of the same typed name converge, and normalized
repetitions of the same URL converge, but a name and URL are not treated as
equivalent without governed identity evidence. This avoids unsafe automatic
identity conflation, but it can leave two request targets for one real identity.
**Trigger** — Before claiming cross-input Request dedupe is complete, or before
staff resolution, notification, or reporting assumes typed-name and pasted-URL
requests for the same real identity already share one target.
**Required at trigger** — REQUIRED: add a governed, provenance-preserving and
concurrency-safe equivalence/merge path; retain every requester's raw name/URL
evidence; converge duplicate per-fan relationships without losing ownership;
preserve terminal outcome history; keep final notifications exactly once; and
never auto-Follow. Prove same-name, same-URL, name-versus-URL convergence,
ambiguous/non-equivalent cases, retry, and concurrent merge behavior.
**Origin** — Phase 5A documentation correction, 1 Sep 2026; current
`phase5a_community_requests.sql` proves same normalized-name dedupe and keeps
distinct URL candidates separate, but does not prove name-versus-URL convergence.
**Assessment, 2 Sep 2026** — NOT TRIGGERED. Phase 5B does not claim cross-input
Request dedupe complete.

### BL-043
**What** — Govern and verify the complete purge of the designated pre-launch fan
test accounts—Brad, TestFan, and NorthStarFan—and all fan-owned test data/media.
**Why deferred** — The three accounts are intentionally useful for controlled
multi-fan acceptance testing before launch. `NorthStarFan` is therefore an
approved test persona rather than an accidental real fan, and its legacy avatar
already falls back to the generic avatar for other fans. Deleting the accounts
now would remove needed test actors without improving the current boundary.
**Trigger** — Before the first real beta/public fan is onboarded, and before any
test identity could enter real discovery, leaderboards, rewards, analytics, or
other production population/metric outputs.
**Required at trigger** — REQUIRED: use one reviewed, recoverable and
referentially complete cleanup procedure; clear/remove NorthStarFan's legacy
active display derivative rather than migrating it; remove the three Auth users
and every fan-owned profile, media, comment, reply, Hide, report, restriction,
notification, Request, follow, preference, and other test record; preserve real
application schema/migrations and governed News/catalog/Team/Competition data;
and verify no test UUID, email, Fanatical Name, fixture content, or test media
remains. Do not perform a casual Auth-only delete that leaves orphaned records.
**Origin** — Settled Phase 5A closeout decision, 1 Sep 2026; supersedes the
former BL-020 prototype-cleanup and BL-035 avatar-migration blockers.
**Assessment, 2 Sep 2026** — NOT TRIGGERED. This remains the pre-beta purge only.

---

## Done

### BL-006 — closed 31 Aug 2026
**What** — Build the screen where a fan chooses and changes their username,
including the "already taken" and format error paths.
**Closed by** — Phase 5A treats `profiles.handle` as the sole Fanatical Name,
enforces the ratified 3–20 contract in `20260831203014`, and adds claim/change,
taken/format handling plus race, immediate-release and reclaim proof. Hosted
activation remains governed separately by FAN-RUN-04.
**Origin** — Frontend deep audit; `FAN-ACCT-07`.

### BL-007 — closed 31 Aug 2026
**What** — Either build the public profile route or revoke the `anon` grant on
`get_profile_for_viewer` until it exists.
**Closed by** — `20260831203014` removes the UUID reader and anonymous profile
access and establishes the Private/Members-visible current-name reader;
`20260831203022` adds reciprocal-Hide enforcement to that boundary. The Phase 5A
UI uses the combined contract, and real-role tests prove protected fields are
absent rather than React-hidden. The designated pre-launch test-account purge is
governed separately by BL-043.
**Origin** — Frontend deep audit; conversation, 27 Aug.

### BL-020 — closed 1 Sep 2026
**What** — Resolve the hosted `NorthStarFan` prototype-persona concern before it
is treated as a real fan account.
**Closed by** — Brad designated `NorthStarFan` as the intentional third
pre-launch acceptance persona alongside Brad and TestFan. It may participate in
controlled hosted testing and needs no persona scrub or Brad-only lookup
exception. BL-043 requires all three test accounts and their fan-owned data to
be purged before any real beta/public fan is onboarded.
**Origin** — Grok blind audit `B2`; hosted verification, 27 Aug; settled product
decision, 1 Sep 2026.

### BL-035 — closed 1 Sep 2026
**What** — Resolve the one hosted active UUID-prefixed avatar display derivative.
**Closed by** — Read-only inventory proved the only affected display belongs to
the designated `NorthStarFan` test account. Phase 5A already refuses to return
that path to other fans and uses the generic avatar, proving the real fan-facing
boundary. The settled decision is not to migrate test media into the opaque
namespace; clear/remove the legacy display and remove remaining test media under
BL-043 before real beta/public onboarding.
**Origin** — Phase 5A hosted read-only preflight and settled closeout decision,
1 Sep 2026.

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
**Extended, 31 Aug 2026** — Phase 5A extends the News mutation registry before
its request-domain tables and adds the parallel mechanically enumerated Community
registry/assertion before any `community_*` table escapes. This uses and extends
the closed mechanism; it does not reopen BL-027.
**Origin** — Phase 3 real-world canary #3 mutation-boundary audit, 29 Aug.
**Assessment, 2 Sep 2026** — Closed mechanism still governs both registries.
Phase 5B tables enter the existing News or Community registry before they
escape; this uses the closed mechanism and does not reopen BL-027.

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
