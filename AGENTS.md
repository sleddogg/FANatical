# FANatical Repository Instructions

## Current Repository / Deployment State

- Canonical working branch: `production-foundation`
- GitHub default branch: `production-foundation`
- Cloudflare Workers Builds production branch: `production-foundation`
- Do not recreate or restore remote `main`.
- Local `production-foundation` is synchronized with `origin/production-foundation`.
- The stale `origin/main` reference has been pruned.
- `fanaticalpeople.com` is live and points to the `fanatical-web` Cloudflare Worker.
- Cloudflare Workers Builds configuration for the public `fanatical-web` Worker:
  - Production branch: `production-foundation`
  - Root: `app`
  - Build: `npm run build`
  - Deploy: `npx wrangler versions upload --config wrangler.web.jsonc`
- A Git push to `production-foundation` therefore builds and uploads a saved
  Worker version without automatically sending production traffic to it.
- Normal production promotion activates that already-uploaded version through the
  Cloudflare Deployments interface rather than rebuilding the commit.
- `npm run deploy:web` still runs `wrangler deploy` and immediately activates a
  freshly built version. It remains an explicit rebuild-and-deploy command and is
  not the normal release or promotion path.
- Rollback restores a previously known-good saved version through Cloudflare
  Deployments. Do not rebuild historical code merely to perform a normal frontend
  rollback.
- This entry describes the public `fanatical-web` Worker only. The
  `fanatical-admin` Workers Builds configuration is unchanged.
- Required Cloudflare build variables are:
  - `VITE_SUPABASE_URL`
  - `VITE_SUPABASE_PUBLISHABLE_KEY`
- The obsolete `app/public/_redirects` file was removed because Wrangler already provides SPA fallback.
- The temporary Cloudflare deploy hook was deleted.
- Do not change Cloudflare, GitHub branching, Wrangler configuration, Supabase configuration, deployment configuration, or domains unless the user explicitly asks.

## Local Files

There are eight currently untracked image files under `images/icons` and `images/logos`. They are intentionally untouched. Do not stage, delete, move, rename, or commit them unless the user specifically asks.

## Workflow

FANatical development follows the active project/build-page phase and the
established architecture authority in `Fanatical build page.md` and directly
applicable repository documentation.

- Work on one page, feature, or approved architecture phase at a time.
- Do not make unrelated cleanup, refactors, architecture changes, dependency upgrades, or speculative improvements.

Before editing:

1. Inspect the existing implementation.
2. Explain briefly what files or components need changing.
3. Make only the requested change.
4. Preserve existing functionality unless the requested change explicitly alters it.
5. After editing, run the appropriate build and type checks.
6. Report exactly what changed and any issue that remains.

Do not assume the user is a programmer. Explain approvals or decisions in plain English, including what will happen before asking the user to approve a command.

### Backend / Migration Completion

These roles are generic: **builder** writes the migration, **verifier**
checks the builder's claims, and **independent auditor** certifies
material work. Tool names may change. Whoever drafts a correction prompt
does not certify that correction; see `FANATICAL_AUDIT_BRIEF.md` and
`FAN-DEV-01` in `FANATICAL_INVARIANTS.md`.

Every new migration created after the Phase 5A migration set must use an
exact 14-digit `YYYYMMDDHHMMSS` version prefix. Do not use a shorter
date-only version that could sort before an existing Phase 5A migration, and
do not rename existing migrations.

A local migration file alone does not make a feature complete. The database
rebuild is not the first syntax, permission, or ownership checker.

#### Every migration

Before the first execution, and again before any correction rerun, complete
an actual preflight. Reading the file is not enough. The rebuild is not
the first syntax, permission, or ownership checker.

1. Inspect the entire migration and the objects it changes for statement
   boundaries and terminators, ownership and grant order, permissions, and
   dependencies. Report those checks. Do not patch only the latest failing
   statement.
2. If the change would add a database role, a skip-row-security privilege,
   a schema move, a new permission model, or any other new security
   boundary, stop and ask Brad. Do not invent it in order to clear a warning.
3. Check current hosted-product rules for any restricted operation,
   including role creation and role attributes that local Postgres may allow
   and hosted Supabase may not.
4. After any failure, inspect the entire file for every occurrence of that
   failure class before editing again.
5. After two failed correction runs, stop. Another attempt requires a
   whole-file review by a different agent than the one who made those two
   corrections. That reviewer is the verifier, not a substitute for
   independent audit of material work.

Required local proofs, in addition to the tests that actually cover the
change:

- A clean rebuild from migration 1.
- If hosted already has earlier migrations, an upgrade from that hosted
  ledger state (the same applied versions). Do not copy live hosted rows.
- If the migration constrains, transforms, re-owns, or otherwise depends
  on already-present rows or objects, also prove it against safe local
  representative fixtures for those shapes.

#### Material migrations

A migration is material when it changes permissions, roles, privacy,
storage boundaries, schema location, or other foundation or security
behavior, or when it would invalidate a prior independent audit.

Material migrations also require, in order:

1. Record a real local advisor baseline. After a successful local apply,
   compare actual advisor results. Do not predict advisor output.
2. Classify every new or changed finding:
   - unchanged existing warning: keep as baseline;
   - genuine defect: fix it;
   - expected consequence of an already approved design: document the
     evidence and the technical disposition;
   - would change security architecture, product behaviour, or durable
     data rules, or remains materially uncertain: stop and ask Brad.
   Nothing is silently ignored. Brad does not personally classify routine
   technical notices.
3. Prove every affected role. That includes anonymous, ordinary-fan, and
   staff when those are affected, and also service roles, operational
   identities, exact staff capabilities, and any new role the migration
   creates when those are affected. Do not treat the named examples as
   the full list.
4. Freeze the tree. Independent audit follows `FANATICAL_AUDIT_BRIEF.md`
   and `FAN-DEV-01`. Ordinary low-risk work does not inherit that ceremony.

#### Hosted apply

Hosted apply remains a separate step after the local proofs above.
See `docs/production-deployment.md`.

- The first hosted step is a read-only linked migration-ledger
  comparison. Confirm exactly what hosted has applied and what local
  files are pending. If the ledgers differ in any way other than hosted
  being simply behind local, stop before applying anything and report
  the discrepancy.
- If a feature creates or depends on a Supabase migration, compare local
  migrations with the linked hosted project before reporting completion.
- If the required migration is pending remotely, stop and request
  approval to apply it through the normal Supabase migration workflow.
- After applying it, verify the hosted schema and all relevant RLS
  policies, functions, constraints, and other introduced backend
  dependencies. For material migrations, repeat hosted real-role proofs
  and the same advisor classification against the hosted baseline.
- Before applying hosted migrations that precede frontend promotion,
  ensure they remain compatible with both the currently active frontend
  and the immediately previous rollback-capable frontend.
- Cloudflare promotion is a later, separate step. It is not part of
  this migration gate.

## Review Scope and Deferral

Expand the current task only for a concrete failure, a settled-invariant
violation, an unsafe or live-data risk, a material architecture problem, an
implementation that cannot satisfy the approved request, or an unapproved
material product decision. For a claimed risk, be able to say what breaks, for
whom, and under what condition.

If a concern does not meet that bar, defer it rather than interrupting the task:

- invariant or enforcement concerns go to `FANATICAL_INVARIANTS.md`;
- concrete future work goes to `FANATICAL_BACKLOG.md`.

Never leave deferred work only in conversation.

Brad decides product behaviour. Builders and reviewers decide implementation
techniques that preserve the same approved behaviour.

`FAN-DEV-08` in `FANATICAL_INVARIANTS.md` is the canonical wording, including how
reviewer disagreements are handled.

## Deferred Work

Before starting a new feature area, implementation phase or product surface, read
`FANATICAL_BACKLOG.md` for entries whose Trigger condition now applies. Pull only
matching entries into the current work; unrelated entries do not block progress.
That file states its own entry, closing and cross-reference rules.

## Engineering Foundations

- Build the approved scope correctly and durably the first time. Do not
  use a temporary patch, a warning suppression, an accepted exception, or
  the shortest path merely to clear a gate. Fix the root cause and leave
  the permanent proof in place. "Narrow scope" prevents unrelated work; it
  never justifies knowingly incomplete work inside the approved scope.
- Protect durable, high-cost foundations: identity, user data, verified facts, permissions, financial records, history, relationships, and security boundaries.
- Keep interfaces between systems clean so News, Cheer, FANbase, agents, and other systems can evolve independently without becoming unnecessarily coupled.
- Treat ordinary application code—including UI, workflows, algorithms, layouts, implementation patterns, and services—as replaceable when change is needed, without threatening underlying data or system integrity.
- Prefer recoverability over assumed foresight. Use migrations, audit trails, versioning, backups, feature flags, tests, rollback-safe changes, and similar mechanisms where appropriate.
- If a materially consequential foundational decision is uncertain, stop and ask rather than inventing a product rule, data convention, permission model, migration strategy, or security boundary.

## Styling Priorities

For styling work, prioritize:

- Responsive mobile and desktop behavior
- Accessibility and usability
- Preserving working functionality
- Finishing the current page before moving to another page
- Existing FANatical design decisions rather than inventing replacements
