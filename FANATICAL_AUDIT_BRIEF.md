# FANatical Phase Audit Brief

The standing instruction given to each independent auditor at the end of a build
phase. Fill in the header fields, hand it to each auditor separately, and collect
the passes before anyone sees anyone else's.

**How this differs from the other documents**

- `Fanatical build page.md` — product and architecture intent.
- `FANATICAL_INVARIANTS.md` — what must not silently become false.
- `FANATICAL_BACKLOG.md` — work deliberately deferred, with its trigger.
- `FANATICAL_NEWS_IMPLEMENTATION_PLAN.md` — the News phase plan.
- `AGENTS.md` — how agents work in this repository.
- This file — how completed phase work is independently audited.

This file never overrides the build page or the register. Where an audit finding
conflicts with a ratified invariant, the invariant is right and the finding is the
error.

---

## Header — fill in before issuing

- **State under audit:** `Builder's complete unsaved Phase 5A change set
  relative to the Phase 4 closeout base—not only the community migration and
  SQL suite. The audit scope includes all four Phase 5A migrations
  (20260831203014, 20260831203022, 20260831203030, and 20260901020424), all
  Phase 5A SQL and concurrency proofs, the full Profile/Community/Request/
  Notifications/Admin frontend and browser-test surface, generated database
  types, supporting local-verification scripts, and the Phase 5A authority,
  invariant, backlog, and audit-document changes. The frozen git inventory
  issued with this brief is the exact scope. It excludes the non-authoritative
  reference snapshots `Fanatical build page - 2026-08-31.md` and
  `Fanatical build page - pre-Phase 5.md`; auditors must use only the canonical
  `Fanatical build page.md`. The implementation tree was frozen and independently
  audited on 1 Sep 2026; the accepted documentation/backlog reconciliation is
  complete, and the resulting tree is not yet Saved. Built from Phase 4 closeout commit
  97f25c85ca52a3539cb203386772677d56ec4621 ("Phase 4 Complete"). Do not cite
  the phase-4-complete tag as the base state: it points one commit earlier, at
  46cb51ce61e793652ebf7a2d754aa868bdb98c30, and is pending correction under
  BL-041. Replace this line with the actual commit SHA once the work is
  Saved.`
- **Branch:** `production-foundation`
- **Phase under audit:** `5A`
- **Audit outcome:** `PASS WITH NON-BLOCKING FINDINGS. No Phase 5A implementation
  blocker remained. The accepted closeout findings were reconciled into the
  canonical authority, invariant and backlog documents; they do not require a
  second independent audit.`
- **Phase exit gate:**

  > Fanatical Name and profile-privacy boundaries hold under real roles;
  > contextual News-Item discussions are unique per Item/context with no
  > duplicate roots under concurrency and no row created by an empty read;
  > Team access requires a matching Team follow, while the expressly temporary
  > signed-in Competition/League and Sport access remains until those direct
  > follow types and inherited-access routing are built under Phase 5B;
  > comments, Hide, and reports/moderation/restrictions work as specified,
  > including preserved correction history; Requests dedupe repeat submissions
  > of the same normalized candidate correctly, resolve only against a current
  > followable target, and never auto-Follow; typed-name versus pasted-URL
  > convergence for the same underlying identity remains explicitly deferred
  > under BL-042;
  > final Request outcomes and direct replies produce idempotent
  > notifications; anonymous, owner, runtime, reviewer, and public RLS
  > boundaries are all proven; Poll and rating schema/tests remain out of
  > scope for this phase.
  >
  > Source: `FANATICAL_NEWS_IMPLEMENTATION_PLAN.md`, Phase 5A row (§8) and the
  > SQL/RLS testing sequence (§7).

- **Known local-versus-hosted status:** `BL-020 and BL-035 are closed decisions,
  not local or hosted activation blockers. NorthStarFan is an intentional
  pre-launch test persona; its legacy display path is withheld from other fans
  by the generic-avatar fallback and will be cleared rather than migrated.
  BL-043 requires Brad, TestFan, NorthStarFan, and their fan-owned test data/media
  to be purged before the first real beta/public fan. The four Phase 5A
  migrations remain unhosted; linked-ledger comparison, explicit apply approval,
  hosted RLS/RPC/privacy verification, frontend promotion, and live smoke remain
  separate hosted closeout work.`

The exit gate lives in this header and nowhere else in this file, so that a later
phase cannot accidentally inherit an earlier phase's criteria. An auditor issued
this brief with an empty state-under-audit field or an empty exit gate should stop
and say so rather than infer either.

For reference, the Phase 2 exit gate was:

> same-name identity cases work safely; historical affiliations are preserved;
> organizational contributors are represented correctly; Show identity/history
> works; merge/reversal provenance is sufficient; Admin access boundaries work
> correctly.

---

## What state you are auditing

The work under audit is normally **uncommitted**. Defective work is not committed
and then fixed; it is audited, fixed, and only then Saved and Uploaded. Nothing
broken enters the commit history.

Audit the working directory exactly as the builder left it.

From the moment the builder reports complete until every first pass is submitted,
nothing in the folder changes — no fixes, no further builder runs, no manual
edits. That freeze is procedural, and Brad enforces it because he is the only one
dispatching work. It exists so that every auditor reads identical input; findings
from a moving target cannot be compared, and apparent disagreements turn out to be
timing.

If you have reason to believe the folder changed mid-audit — the builder's report
describes something absent, or a file does not match what you recorded earlier in
your own pass — stop and say so rather than auditing a moving target.

Where the work has already been Saved, a commit SHA in the header is the stronger
form of the same freeze. Use it when it is available. Saving is not Uploading.

## Scope and independence

Review the changed surface plus the reasonably affected seams around it. Do not
re-audit unrelated parts of the application just for completeness.

Do not read the other auditors' findings before submitting your first pass.

The builder of the work under audit is never an auditor of it, per FAN-DEV-01.

=========================================================
1. BUILDER CLAIM CHECK
=========================================================

Review the builder's completion report claim by claim.

For each material claim, classify it as:

- CONFIRMED
- PARTIALLY SUPPORTED
- UNSUPPORTED

Quote or clearly identify the claim and cite the code, migration, test, or
behavior that supports your conclusion.

This section is required and is separate from your findings.

=========================================================
2. FINDINGS
=========================================================

For each finding include:

- Finding
- What concretely breaks
- Who is affected
- Under what condition
- Evidence: file, migration, test, or behavior

Classify each finding into exactly one bucket:

**FIX NOW**
A current defect, invariant violation, security/privacy/data-integrity issue,
material architecture contradiction, or behavior that makes this phase unsafe or
incomplete.

**BACKLOG**
A real issue, but not required to make this phase correct. Include the concrete
trigger for when it becomes required.

**NEEDS PRODUCT DECISION**
The implementation cannot be completed correctly without an unresolved product,
behavior, policy, or material operating decision.

**NO ACTION**
Not substantiated, already handled, intentional behavior, ordinary implementation
choice, cosmetic preference, or something that does not materially affect this
phase.

Assign severity only to FIX NOW findings, solely to rank fix order.

Do not invent thresholds, percentages, cadences, confidence values, or product
rules.

Do not expand the current phase merely because something could be improved.

=========================================================
3. AREAS EXAMINED AND FOUND SOUND
=========================================================

List the relevant areas you examined and found sound, even where you found no
issue.

A clean area stated explicitly counts as examined.

An area never mentioned should be treated as outside the audit, not as passed.

=========================================================
4. LIMITS OF VERIFICATION
=========================================================

State what you could not verify and why.

Examples:

- tests not run;
- behavior inferred from code rather than executed;
- hosted-state behavior unavailable from local inspection;
- environment/tooling limitations.

Do not present inference as verification.

=========================================================
5. EXIT-GATE VERDICT
=========================================================

State independently whether the current phase exit gate is satisfied.

Answer YES or NO and explain briefly what that conclusion rests on.

Evaluate against the exit gate named in the header of this brief, and against
nothing else. If the header's exit gate is empty, stop and ask for it rather than
inferring criteria from the phase plan or from a previous phase.

=========================================================
PROCESS RULES
=========================================================

This is an independent first-pass audit.

Do not read or react to the other auditors' findings until all first passes are
complete.

The auditor does not implement the fixes it later certifies.

The full cycle:

1. The builder completes the phase and reports. The folder freezes.
2. All three auditors submit independent first passes. No auditor reads another's
   before submitting its own.
3. Brad consolidates the findings once and decides what is accepted. One auditor
   drafts the fix prompt.
4. The builder implements the accepted fixes.
5. The two auditors who did not draft the fix prompt review the result.
6. Only when that is clean: Save, then Upload.

Nothing accepted is deferred by being left out of the fix prompt without a
decision. An accepted finding is either fixed now or moved to
`FANATICAL_BACKLOG.md` with a trigger.

Every accepted finding leaves the conversation and lands somewhere durable. FIX
NOW items are fixed in this phase. BACKLOG items become entries in
`FANATICAL_BACKLOG.md` under that file's own rules, including a trigger condition.
NEEDS PRODUCT DECISION items go to Brad and, once decided, are recorded in the
build page or the register as appropriate. Nothing accepted is left only in chat.

Use this level of audit rigor because the current phase is consequential
foundation work. Do not assume this three-auditor process applies to ordinary
low-risk UI/CSS work.
