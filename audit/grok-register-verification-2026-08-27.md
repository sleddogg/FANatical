# FANatical invariants-register verification

**Auditor:** Cursor verification pass, 2026-08-27  
**Register under test:** `FANATICAL_INVARIANTS.md` (draft / unverified)  
**Blind audit (not revised):** `audit/grok-blind-audit-2026-08-27.md`  
**This file is the only new write.** The register, the blind audit, and all other repository files were left unchanged.

I treated every enforcement location, proof quote, and status in the register as an unverified claim. Status below is my call, using the register’s own vocabulary and FAN-DEV-06: a named file, a superuser suite, or an exception string in a migration does not make a rule `enforced + tested`. A test has to exercise the rule under the conditions the rule is about.

---

## Coverage statement

### Database target (confirmed before any SQL)

| Check | Result |
| --- | --- |
| Docker container | `supabase_db_fanatical-local` |
| Image | `public.ecr.aws/supabase/postgres:17.6.1.155` |
| Host bind | `0.0.0.0:15422 -> 5432/tcp` |
| `SELECT current_database(), current_user, inet_server_addr()` | `postgres` / `postgres` / empty (Unix socket via `docker exec`) |
| Applied migrations include | `202608260001` and `202608270001` (24 local versions) |

All SQL used `docker exec -i supabase_db_fanatical-local psql -U postgres -d postgres`. No `supabase db push`, no `--linked`, no hosted or admin environment files.

### What I verified independently this pass

- Every Guaranteed and Claimed invariant ID, plus all 12 GAPs: enforcement strings grepped in migrations; claimed proof quotes grepped in `supabase/tests/`.
- B1/B2 fixes: read `202608270001`, `profile_privacy.sql`, `AccountBootstrap.tsx` / `.test.tsx`; executed the privacy SQL suite; executed the three bootstrap Vitest cases; rolled-back probes of the old B1 write and of library-table path binding.
- Live local catalog of SECURITY DEFINER `search_path`, PUBLIC EXECUTE, `staff_roles` grants/policies, media-path CHECKs, current verification-policy numbers, `team_readiness` view text, and `catalog_verification_decisions` triggers.
- Rolled-back probes listed in the command table below.
- Unique `raise exception` templates in `supabase/migrations/` (326 templates / 538 literals). Assertion counts in `supabase/tests/` (~388 `assert_true` calls across 10 files; `profile_privacy_verification.sql` still has none).

### What I accepted without independent checking this pass

- **Hosted schema.** Not queried. `202608260001` and `202608270001` are present locally. Whether they are active on the hosted project is unknown. FAN-RUN-04 therefore still applies to every “local E+T” upgrade below.
- **Part III Future (FAN-NEWS / ATTR / DUP / DEST / CHR / SCR-02–07 / ACCT-04 / UX-01 / RUN-06–07).** I spot-checked that News still renders `mockNewsItems` and that Cheer still has no `team_readiness` consumer. I did not re-read every future entry against the build spec.
- **Part IV Process (FAN-DEV-01–06).** Process rules, not schema. I applied FAN-DEV-06 as a judging standard; I did not audit whether builders have been following it.
- **Interior math** of source-qualification scoring, lineage comparison, and verifier consensus. I checked whether named proofs exist, not whether the algorithms are correct.
- **Cloudflare Workers** holding no durable work state (FAN-RUN-01’s executor half).
- **FAN-RUN-03 / GAP-04 mechanical secret-key guard.** Grep of `app/src` found no `VITE_SUPABASE_SERVICE` / `service_role` literals. That is not a bundle audit and not a CI guard.
- **The ten catalog SQL suites other than `profile_privacy.sql`.** Proof quotes were matched by grep. Those files were executed in the 2026-08-27 blind pass; I did not re-run them today.

### Commands run

| Command | Result |
| --- | --- |
| `docker inspect supabase_db_fanatical-local` + in-container `current_database()` / migration list | Local target confirmed; `202608270001` applied |
| Live schema queries (CHECKs, grants, triggers, DEFINER `search_path`, policies, current `verification_policies`) | Completed |
| Rolled-back probes (invalid visibility, anon `save_my_profile`, cross-user `profiles` UPDATE, `staff_roles` INSERT as `authenticated` and `service_role`, cross-user `avatar_path`, cross-user `profile_photos` path, verified `team_color_versions` with null `verification_decision_id`, `team_id` mutation, ambiguous `resolve_catalog_team_id`, wildcard capability INSERT, lineage UPDATE/DELETE, decision UPDATE/DELETE, audit UPDATE, storage INSERT into a foreign folder, `save_my_profile` with `visibility=friends`) | Completed; transaction rolled back |
| `psql -f supabase/tests/profile_privacy.sql` against local | Passed (rolls back) |
| `npx vitest run src/features/account/AccountBootstrap.test.tsx` | 3 passed |
| Unique exception-template extraction from migrations | 326 unique templates |

### Commands skipped, and why

| Item | Why skipped |
| --- | --- |
| Hosted Supabase | Out of scope; would require linked/admin config |
| `supabase db push` / `--linked` | Forbidden |
| Remaining `supabase/tests/*.sql` | Proof quotes grepped; not re-executed this pass |
| `npm run typecheck` / full Vitest / web+admin builds | Not required to judge register statuses; last known results are in the blind audit |
| `npm run backend:verify`, Playwright, concurrency shell | Same as the blind pass |
| `profile_privacy_verification.sql` | Still a JSON dump with no assertions; running it would not prove anything |

---

## 1. Wrong statuses

Both directions. “Should be” is the status the register ought to carry **on the local repository**, with hosted still unknown under FAN-RUN-04.

### Overclaimed — labelled `enforced + tested` without a test that exercises the rule

| ID | Register claims | What I found | Status should be |
| --- | --- | --- | --- |
| **FAN-ACCT-01** | `enforced + tested`; proof `profile_privacy.sql` | A CHECK (`profiles_visibility_check`) and `save_my_profile` both reject anything other than `public`/`private`. I confirmed both with rolled-back probes (`friends` → CHECK; RPC → `Profile visibility must be public or private`). `profile_privacy.sql` only writes `public` and `private` and asserts those round-trips. It never tries an illegal value. | `enforced but unproven` |
| **FAN-ACCT-03** | `enforced + tested`; enforcement quote `Authentication is required` | `save_my_profile` is granted only to `authenticated`. Anon RPC → `permission denied for function save_my_profile`. Owner-only RLS: authenticated UPDATE of another user’s `profiles` row → 0 rows. The suite never calls the write path as `anon`, and never asserts a cross-user table UPDATE. The exception string is in the function, not in any test. | `enforced but unproven` |
| **FAN-RUN-02** | `enforced + tested` | Grants are SELECT-only to `authenticated`; only policy is own-row SELECT. Rolled-back probe: `authenticated` INSERT → `permission denied for table staff_roles`. `service_role` INSERT is also denied (stronger than the register says). No SQL test and no `adminAccess.test.ts` case talks to the table; that Vitest file only parses JSON. Every SQL suite that touches `staff_roles` inserts as `postgres`. | `enforced but unproven` |
| **FAN-GOV-01** | `enforced + tested`; proof “decision must snapshot … immutable details” | The cited assertion in `team_color_agent_workflow.sql` checks that an insert-time snapshot *contains* evidence/trust/applicability keys. It does not try to change the row later. `catalog_verification_decisions` has **INSERT** triggers only. Rolled-back probe as `postgres`: UPDATE of `policy_snapshot` succeeded (`{"policy_key": "rewritten"}`); DELETE succeeded. Later policy-table edits would not auto-rewrite a snapshot, but the decision row itself is not protected. | `enforced but unproven` for snapshot-at-insert; the “never rewrite” half is **not enforced** (see §2) |
| **FAN-GOV-02** | `enforced + tested` as a general governed-fact rule (“two qualifying independent sources, at least one Tier 1–2”) | Current `team_colors` policy is **3** independent lineages and 1 Tier 1–2, and that *policy row* is asserted. `team_primary_league`, `team_venue_relationship`, and `venue_mapping` still seed **2**, and have **zero** tests (GAP-01). Direct INSERT of `record_status='verified'` with null `verification_decision_id` succeeded (GAP-02) — a “governed fact” with no sources at all. No test asserts the general two-source floor. | `enforced but unproven` as a general rule; Team Color policy configuration is `enforced + tested` at **3**, not 2. Do not keep this in Guaranteed until GAP-02 closes and non-color data types have proofs. |
| **FAN-GOV-04** | `enforced + tested` | One-current-tier is asserted (`one publisher/data type must have only one current trust tier`). The second clause — “Conflicting current trust assignments require reviewer resolution before redirect” — is an exception in migrations and is **not** in any test. | Split, or weaken to `enforced + tested` for one-current-tier only; redirect-conflict half is `enforced but unproven` |
| **FAN-GOV-06** | `enforced + tested` | Ambiguous URL ownership **is** asserted (`ambiguous URL ownership must reject evidence`). Path-prefix matching is asserted on the resolver helper. No test attaches evidence whose URL sits outside the **selected** publisher’s approved scope (the exception the register cites). | `enforced + tested` for ambiguity; out-of-selected-scope attachment is `enforced but unproven` |
| **FAN-VER-03** | `enforced + tested`; proof “lineage merge must preserve the historical approved version…” | Triggers exist (`Information-lineage version content is immutable` / history cannot be deleted). I confirmed both with a rolled-back UPDATE/DELETE. The cited proof is a **merge overlay** test, not an immutability or deletion test. No suite assertion tries `UPDATE`/`DELETE` on `information_lineage_versions`. | `enforced but unproven` |
| **FAN-AGT-04** | `enforced + tested`; proof quote is the lease exception string | That string is not a test assertion. The suite tests lease **expiry**, policy-selected duration, reclaim/attempt history, and a late worker after watchdog. It never calls a mutating RPC with a missing or foreign lease token and asserts the lease exception. | `enforced but unproven` for “work requires a live lease you own”; expiry/recovery behaviour is `enforced + tested` |
| **FAN-AGT-06** | `enforced + tested` | Exception exists. Suite asserts stale expected-current version at comparison time, and that the policy lists `bootstrap_revalidation`. No test submits a verified replacement with a **missing** recheck trigger and expects the cited exception. | `enforced but unproven` |
| **FAN-GOV-07** | Guaranteed; “enforced + tested on existing paths; general constraint unenforceable until GAP-02” | Competition backfill **is** asserted as `imported_unverified`. The register’s own bucketing rule says an entry sits in the bucket its **weakest** part supports. The general “never born verified” rule is exactly GAP-02. | Move out of Guaranteed. Status: `enforced + tested` for Competition backfill and proposal RPCs that write `imported_unverified`; general constraint `documented only` until GAP-02 |
| **FAN-AGT-01** | Guaranteed; “enforced + tested for grants; RLS unproven” | Correct about grants vs RLS (GAP-08). Incorrectly sitting in Guaranteed. Privilege-denial assertions are `has_table_privilege` as `postgres`, not `SET LOCAL ROLE`. | Move out of Guaranteed. `enforced + tested` for grants; `enforced but unproven` for RLS |
| **FAN-AGT-02** | Guaranteed `enforced + tested`; notes GAP-09 | Capability denials **are** asserted for several Team Color RPCs. `has_catalog_capability` matches `*` and `admin_grant_catalog_capability` has no allowlist. Rolled-back probe: inserting `capability='*'` as `postgres` **succeeded**. That is not a hole in one RPC; it defeats the named-capability rule. | Keep GAP-09. Do not call the general rule Guaranteed. `enforced + tested` for named capabilities when `*` is absent; `*` makes the rule `enforced` only if nobody is granted it |
| **FAN-ID-11** | Guaranteed “for Competition resolution only” | Competition ambiguity proofs exist and match the quoted strings. Team resolver is GAP-06 — and is worse than “untested” (see §2). Bucketing convention requires a split or a Claimed entry. | Competition half may stay `enforced + tested` as its own entry. Do not keep a mixed entry in Guaranteed |
| **FAN-SYS-01** | Claimed `enforced but unproven` (view gates Live Cheer) | `team_readiness.live_cheer_ready` does encode verified identity + primary league + primary venue + current venue map. Nothing in the Cheer UI reads that view; launch still uses local/prototype data. A view that nobody consults does not enforce a product gate. | `documented only` until a launch path actually reads `live_cheer_ready` |
| **FAN-RUN-01** | `enforced + tested` for the ledger as built | Postgres attempt/lease history assertions exist. The sentence also claims Cloudflare is only an executor. Workers were not inspected this pass. | `enforced + tested` for the Postgres ledger; Cloudflare half `documented only` |

Proof-citation quality (not always a status flip): several Guaranteed proofs are **migration exception strings**, not test assertion messages — notably FAN-AGT-03 (`Team Color proposal builder and verifier must be different actors`) and FAN-AGT-05 (`Domain adapter did not return a valid blinded subject context`). Those two **do** have real tests under different wording (`Team Color Agent must be denied verification`; blinded-context assertions). Status can stay `enforced + tested`; the proof quotes should be replaced with the actual assertion strings.

### Underclaimed — the register is too weak, or a gap is stale

| ID | Register claims | What I found | Status should be |
| --- | --- | --- | --- |
| **FAN-ACCT-02** | Claimed `unclear — pending verification` | Local fix is real. Four `NOT VALID` CHECKs bind `profiles`, `profile_photos`, `profile_visual_images`, and `profile_visuals` to `user_id::text || '/%'`. `private.profile_media_path_is_visible` ignores a path that is not in the **row owner’s** folder. `profile_privacy.sql` now `SET LOCAL ROLE` and asserts the old B1 write, library-table binds, legacy NOT VALID install, helper denial, and that anon/attacker still cannot read the victim display. My probes independently rejected cross-user `avatar_path` and cross-user `profile_photos.source_path`. Vitest is not involved; this is a SQL proof. Caveats: CHECKs are **NOT VALID** (legacy rows can exist; a diagnostic view lists them); hosted `202608270001` was not inspected. | **`enforced + tested` on local schema.** Move to Guaranteed only together with the NOT VALID / hosted caveats. Do not leave `unclear`. |
| **GAP-10** | Open gap: library tables still accept any path; “avatar_path instance was fixed” | False on local schema. All four tables have ownership CHECKs, and `profile_privacy.sql` asserts library source **and** display binds. Probe: `profile_photos` cross-user `source_path` → CHECK violation. | **Close GAP-10.** The remaining residue is “NOT VALID legacy rows,” which is a cleanup caveat on FAN-ACCT-02, not an open family of unbound tables. |
| **FAN-VER-05** | `enforced but unproven` | Correct as a **suite** status (no team-registry proof file). Independently: `protect_verified_catalog_version` is on those tables; rolled-back overwrite of a verified `team_color_versions` row → `Verified catalog values cannot be overwritten`. That is my probe, not a registerable proof. | Keep `enforced but unproven` until a suite exists. Do not upgrade on a one-off probe. |
| **FAN-RUN-02 (enforcement strength)** | Browser cannot mutate `staff_roles` | Also true of `service_role` on this local database (INSERT denied). Only `postgres` (owner) has INSERT. | Status stays `enforced but unproven`; the enforcement sentence can be strengthened. |
| **DEFINER hygiene (unregistered)** | Not in the register | Live local: **164 / 164** `public`/`private` SECURITY DEFINER functions have `search_path=""`. **0** retain PUBLIC EXECUTE. | This is currently true and independently counted. It deserves an invariant (see §3). Status today would be `enforced but unproven` (no suite assertion of the catalog query). |

Competition-family Guaranteed entries FAN-ID-01–10, FAN-ID-12–13, FAN-VER-01–02, FAN-VER-04, FAN-GOV-03, FAN-GOV-05, FAN-AGT-03, FAN-AGT-05, FAN-AGT-07 (narrowly: no blind retry / attempt history / late-worker denial) had **matching assertion strings** in `competition_foundation.sql`, `trusted_source_publisher_reliability.sql`, or `team_color_agent_workflow.sql`. I did not re-execute those suites this pass. I am not flipping their statuses for missing proofs; I am also not recertifying that they still pass.

---

## 2. Contradictions

Where code or schema behaves contrary to a stated invariant. Execution where I could.

### GAP-06 / FAN-ID-11 (Team half) — the Team resolver guesses

**Register:** GAP-06 says `resolve_catalog_team_id` “has resolution tests but nothing asserting it refuses to guess,” i.e. missing proof of a never-guess rule.

**Code:** there is no status-returning Team resolver. `resolve_catalog_team_id` is:

```sql
select team.id from public.catalog_teams team where team.team_id = identifier_value
union all
select external_id.team_id from public.catalog_team_identifiers external_id
 where external_id.identifier = identifier_value
limit 1;
```

Identifiers are unique on `(namespace, identifier)`, **not** on `identifier` alone. The same external ID in two namespaces is legal.

**Probe (rolled back):** two hockey teams, identifier `shared-external-id` in `ns-a` and `ns-b`. `resolve_catalog_team_id('shared-external-id')` returned team 1’s UUID with **no error**. Outcome: `GUESSED`.

This is not an untested good function. It is a `LIMIT 1` picker. Competition resolution (FAN-ID-11) really does return `ambiguous`. Team resolution does the opposite.

**Consequence: HIGH CONSEQUENCE** for any catalog write that resolves a namespaced external ID through this function — evidence, proposals, and readiness can attach to the wrong Team. Not currently **BLOCKING** for the live fan site: followed-team IDs are unconstrained frontend strings (GAP-07), and agent fixtures use unique `hockey-######` public IDs. **Reversible in production?** A wrong verified fact would need supersession, not an in-place edit (FAN-VER-05). Ambiguous identifier rows themselves are ordinary inserts and can be deleted if still `imported_unverified`.

### FAN-GOV-01 — decision rows are mutable

Stated: a verification decision preserves the exact policy/tier/applicability/URL-scope/independence versions; later changes never rewrite old decisions.

**Probe (rolled back):** inserted a `rejected` decision (INSERT triggers skip the Team Color approval path when `decision <> 'approved'`), then `UPDATE policy_snapshot` and `DELETE`. Both succeeded as `postgres`.

Browser roles cannot do this (no write grant). Any migration, superuser session, or future SECURITY DEFINER helper can. Audit events **are** append-only (`Catalog audit history is append-only` — probe rejected UPDATE). Decisions are the exception sitting next to that protection.

**Consequence: MEANINGFUL BUT LATER.** History of *why* something was verified can be rewritten without a trace in that table. Not a live browser attack. **Reversible?** Only if you still have the old snapshot elsewhere (audit `details`, backups). Once updated, the decision table itself no longer tells the truth.

### FAN-GOV-08 / GAP-02 — confirmed, not new

Register already says a verified row can be written with a null `verification_decision_id`.

**Probe:** `INSERT team_color_versions (..., record_status='verified', verification_decision_id=NULL, is_current=false)` → **ALLOWED**.

This also falsifies the *general* reading of FAN-GOV-02 and FAN-GOV-07. Those overclaims are in §1; the schema behaviour is already named as GAP-02.

**Consequence:** already classified by the register. Direct INSERT is a superuser/service path, not a fan RPC. Still the hole that lets a fact be born “verified” with no decision and no sources.

### GAP-10 — register contradicts the schema (stale)

GAP-10 says library tables still accept any `source_path`/`display_path`. Local schema and `profile_privacy.sql` say otherwise. This is a register error, not a product hole. See §1.

### FAN-GOV-02 wording vs current Team Color policy

The invariant says **two** independent sources. Current `team_colors` policy `version = 4` requires **three** lineages (and Verifier 2 requires four). That is stricter, not looser, so it is not a safety contradiction. It *is* a false description of the live Team Color rule. Other data types still seed 2 and are untested.

### B1 / B2 — previously contradictory, now closed locally

I did not rediscover these. I verified the fixes:

- **B1 / FAN-ACCT-02:** attacker `UPDATE profiles.avatar_path` to a victim path is now a CHECK violation. Library tables likewise. `profile_privacy.sql` also drops/re-adds the NOT VALID constraint around a malformed legacy row and asserts the helper + storage RLS still deny attacker/anon while the owner can still read. **Passed.**
- **B2:** `migratePrototypeAccount` no longer calls `saveOwnedProfile`. Three Vitest cases assert it is not called, that demo identity strings are not persisted, and that demo teams are not written unless `localStorage` already had followed-team state. **Passed.**

Hosted accounts already bootstrapped, and hosted presence of `202608270001`, were not inspected.

---

## 3. Omissions

Migrations contain **326** distinct `raise exception` templates (538 literals). The test tree has on the order of **388** `assert_true` calls. The register has **109** rules, of which 37 are currently labelled Guaranteed and 48 are unbuilt product. Most of the 326 exceptions are instances of a few patterns already named: named capability, live lease, HEX format, admin access, pending proposal, URL-scope, independent verifier.

The question is not “which exception lacks an ID.” It is: **if this silently became false, would someone be harmed without the register noticing?**

### Deserve an entry

| Missing rule | Why it would harm if silently false | Suggested relation | Consequence |
| --- | --- | --- | --- |
| **First sign-in must not overwrite account identity with a demo persona** | This is B2. It happened in code, was not in the register, and is now fixed and tested. Without an entry it can regress the same way. | New FAN-ACCT-05 (or similar). Proof: `AccountBootstrap.test.tsx` | **HIGH CONSEQUENCE** if it returned; identity corruption on every new account. **Reversible** by owner edit; public wrong record exists until then. Not currently blocking (fix verified). |
| **Team identifier resolution never guesses** | Same family as FAN-ID-11. Currently **false** (`LIMIT 1`). GAP-06 undersells this as a missing test. | New FAN-ID-16, or rewrite GAP-06 as a known violation | **HIGH CONSEQUENCE** for catalog writes using namespaced IDs; not blocking the live fan UI today. Wrong verified facts need supersession. |
| **Sport / League / Team / Venue permanent public IDs never change** | `protect_catalog_public_identity` raises `Catalog identities are immutable`. FAN-ID-01 covers Competition/Edition only. Probe: `UPDATE catalog_teams.team_id` rejected. GAP-01 correctly says **zero tests**. If this trigger were dropped, every mapping and media path keyed on public IDs would silently retarget. | New FAN-ID entries parallel to FAN-ID-01; keep GAP-01 as the proof gap | **HIGH CONSEQUENCE** if dropped; currently enforced, unproven. |
| **SECURITY DEFINER functions use empty `search_path` and are not `EXECUTE`d by PUBLIC** | 164/164 and 0 PUBLIC EXECUTE locally. If a later migration omits `SET search_path = ''`, an attacker who can create objects in `public` can hijack the definer. If PUBLIC EXECUTE returns, the capability model is bypassed. | New FAN-AGT or FAN-RUN invariant plus a catalog assertion in a SQL suite | **HIGH CONSEQUENCE** / potential **BLOCKING** *if it became false*. Today it is true. A silent regression would be a privilege-escalation hole. Reversing it means replacing the function; any sessions already abused are not undoable. |
| **Storage uploads stay inside the owner’s folder** | INSERT/UPDATE/DELETE policies require `(storage.foldername(name))[1] = auth.uid()::text`. Metadata CHECKs (FAN-ACCT-02) do not stop a foreign **upload**. Probe: authenticated INSERT into a victim prefix → RLS denial. `profile_privacy.sql` tests SELECT, not INSERT. | Fold into FAN-ACCT-02 or a sibling | **HIGH CONSEQUENCE** if dropped (write into another fan’s namespace). Currently enforced, unproven. |
| **Public viewers never receive original/source objects — only display derivatives, and only when the true owner is public** | Already asserted in `profile_privacy.sql` (owner/original vs viewer/display vs anon). FAN-ACCT-02 talks about folder binding and claimant vs owner; it does not name the original-vs-display split. If storage SELECT ever treated originals like displays, private photography leaks. | Spell this out under FAN-ACCT-02 | **HIGH CONSEQUENCE** if it became false. Currently `enforced + tested`. |
| **Default profile visibility is `public`** | Column default `'public'`. Combined with `get_profile_for_viewer` granted to `anon`, a new account is world-readable until the fan finds the control. If product later assumes private-by-default, the register would not catch the mismatch. | New FAN-ACCT product rule (deliberate, not a defect) | **MEANINGFUL BUT LATER** (M1) |
| **A signed URL issued while public remains usable after the profile goes private, for the documented TTL** | Documented in `supabase/README.md`; client cache ~1 hour. This is a known exception to “third-party readability follows current visibility.” If someone “fixes privacy” without shortening or revoking URLs, they will think FAN-ACCT-02 is tighter than it is. | New caveat on FAN-ACCT-02 | **MEANINGFUL BUT LATER** (M4). Deliberate. |
| **Verification decision rows are append-only** | FAN-VER-06 wants this; FAN-GOV-01 claims it; schema does not do it. Audit events are protected; decisions are not. | Close the gap that §2 executed | **MEANINGFUL BUT LATER**. Superuser-shaped. |
| **Production Team Color evidence requires a currently qualified source** | Exceptions: `An unqualified source contributes to the Team Color proposal/verification`; `Source is not currently qualified for production % evidence`. If this were removed, empirical-unqualified publishers could back a “verified” palette. Adjacent to FAN-GOV-09 / FAN-AGT-09, but those are prose. | New GOV/AGT entry | **MEANINGFUL BUT LATER** (no live production agent) |
| **`admin_register_catalog_domain_adapter` does not take a raw `regproc` that recovery will `EXECUTE`** | Recovery does `execute format('select %s()', ...::regproc)`. A compromised admin can aim a SECURITY DEFINER call at an arbitrary function. Register is silent. | New FAN-AGT/RUN | **MEANINGFUL BUT LATER** (M10). Restricted to staff, but the surface is oversized. |
| **Live product surfaces that are still mock must not be treated as canonical records** | Live site creates real accounts; News/Quiz/FANbase/trophies/Fan Coins are still mock or local. If this is unnamed, a later change can persist mock scores into real tables without a register check. | New FAN-SYS / product-honesty rule | **MEANINGFUL BUT LATER** (M6) |
| **Venue mapping / inventory SELECT to `anon` is an explicit product decision** | If those tables later hold commercially sensitive seating maps, public SELECT is the leak. Register never says they are public. | New FAN-SYS or FAN-CHR caveat | **MEANINGFUL BUT LATER** (M12) |
| **Sign-out is device-local** (`scope: "local"`) | Other devices’ refresh tokens remain valid. Stolen-session response is not “hit Sign Out.” | New FAN-ACCT session rule | **MEANINGFUL BUT LATER** (M14) |
| **Caller-selected retry timestamps are not accepted** | Exception exists; specialist tests assert backend policy ignores caller delay. This is the concrete form of FAN-AGT-07 for retries. Worth naming so it cannot be “helpfully” reintroduced. | Fold into FAN-AGT-07 proof list rather than a new ID if FAN-AGT-07 is rewritten honestly | **LOW RISK / CLEANUP** unless a caller delay path returns |

### Enforced, but do not need their own IDs

These would be noise: uppercase HEX colors; “active catalog actor is required” on every RPC; each `*.capability is required` string; photo-library max-three; worker-pool concurrency numbers; pending-source-cannot-be-attached (belongs under FAN-GOV-03); `has_table_privilege` denials on queue tables (belongs under FAN-AGT-01 grants). Registering 200 capability strings would hide the rules that matter.

### Already named, and the naming is correct enough

GAP-01 (team registry untested), GAP-02 (verified without decision), GAP-03 (untyped client), GAP-04 (no secret-key guard), GAP-05 (FAN-AGT-08 prose), GAP-07 (dual catalogs / unconstrained `user_followed_teams.team_id`), GAP-08 (RLS almost untested), GAP-09 (`*`), GAP-11 (no scheduler — `run_agent_backend_recovery` is only called from tests, not `pg_cron` or a Worker), GAP-12 (handle uniqueness). I am not re-opening those except GAP-06 (too weak) and GAP-10 (stale).

---

## 4. Coverage of the blind findings

Blind items: B1, B2, M1–M17, L1–L8 (**27**). Classification is against the **current** register, not against the draft’s “2 of ~27” sentence.

### Already registered as a known invariant or gap — **8**

| Item | Where |
| --- | --- |
| **B1** | FAN-ACCT-02 (`GK:B1`). Fix verified locally this pass; status should move off `unclear`. |
| **M2** | GAP-12 (`GK:M2`) |
| **M3** | GAP-10 (`GK:M3`) — **registered, but the gap text is now false** (see §1 / §2) |
| **M5** | GAP-08 and FAN-DEV-06 (`GK:M5`) |
| **M7** | GAP-07 and FAN-SYS-02 (`GK:M7`) |
| **M8** | FAN-RUN-04 (local completion is not hosted completion). Not tagged `GK:M8`, but the rule is the same. |
| **M9** | GAP-11 (`GK:M9`) |
| **M11** | GAP-09 (`GK:M11`) |

### Not registered, genuinely new, worth registering — **7**

| Item | Why it belongs |
| --- | --- |
| **B2** | Explicitly admitted as uncovered. Now a real, tested account-integrity rule. |
| **M1** | Default-public is a product invariant. If it flips, or if someone assumes it already flipped, fans are exposed. |
| **M4** | Known exception to current-visibility privacy. Without it FAN-ACCT-02 is over-read. |
| **M6** | Live identity + mock News/Cheer/Quiz/scores. Harm is false belief, not a SQL hole. |
| **M10** | `regproc` executed by recovery. Privilege surface, not documented as an invariant. |
| **M12** | Anon-readable venue maps/inventory. Data-exposure decision with no register line. |
| **M14** | Local-only sign-out. Session-theft behaviour the privacy story does not mention. |

### Not registered, not worth registering — **12**

| Item | Reason |
| --- | --- |
| **M13** | Bundle size / mock photos in the Worker. Performance and product-boundary, not a system invariant. |
| **M15** | Local Auth 6-char / no confirm vs UI 8-char. Local-dev `config.toml`; hosted Auth was not in scope. |
| **M16** | Root HTML prototypes. Not served by the current Worker. |
| **M17** | `_redirects` docs drift. |
| **L1** | Leftover `GRANT SELECT` on `profiles` to `anon` with no anon policy. Noise; RLS still returns zero. |
| **L2** | `FORCE ROW LEVEL SECURITY` off. Normal Supabase table-owner bypass; not a product rule. |
| **L3** | Replica identity FULL / Realtime. Implementation detail. |
| **L4** | Vitest timeouts in one environment. Harness, not an invariant. |
| **L5** | `parseStaffAccess` accepts any permission string. Harmless until tools exist. |
| **L6** | `current_catalog_actor_id` `LIMIT 1` without `ORDER BY`. Mitigated by unique `auth_user_id`. |
| **L7** | CSP `'unsafe-inline'` / mic permissions. Frontend hygiene. |
| **L8** | Local Postgres on `0.0.0.0`. Dev-machine exposure, already documented. |

### Counts

| Class | Count |
| --- | --- |
| Already registered as a known invariant or gap | **8** |
| Not registered, worth registering | **7** |
| Not registered, not worth registering | **12** |
| **Total blind findings** | **27** |

**What this means for treating the register as authoritative**

The register is a good catalog of **documented catalog/governance intent**, and after the GK tags it captures **8 of 27** independent findings (about 30%), not the “2 of ~27” in its preamble. The missing 7 that are worth registering are almost all **account, storage, session, and live-product-honesty** rules — the bias the preamble already admits.

It is **not** yet safe to treat Guaranteed as “mechanically true.” On this pass, 15 Guaranteed or mixed-Guaranteed statuses were overclaimed (including whole entries that belong in Claimed because of GAP-02, GAP-06, GAP-08, GAP-09). Two Claimed/GAP items were underclaimed or stale (FAN-ACCT-02 should rise; GAP-10 should close). One stated Team-resolution gap is actually a **false function**, not a missing test.

Use the register as a checklist of what product has ratified. Do not use Part I as a proof of production safety until the status corrections above are applied, GAP-10 is closed, B2 is entered, and hosted migrations are confirmed under FAN-RUN-04.

---

## Status I would actually trust (local only)

These are the ones I would personally file as Guaranteed on **this** database, with the proofs I could point at:

- FAN-ID-01–10, FAN-ID-12–13, FAN-VER-01–02, FAN-VER-04 — proof strings exist in `competition_foundation.sql` (not re-executed this pass; grepped).
- FAN-GOV-03, FAN-GOV-05 (applicability/tier split), FAN-GOV-04’s one-current-tier half.
- FAN-AGT-03, FAN-AGT-05.
- FAN-ACCT-02 as rewritten (path bind + owner visibility), including library tables — **executed** this pass.
- B2’s rule (unregistered) — **executed** this pass.

Everything else in Part I is either unproven under FAN-DEV-06, mixed with a GAP, or contradicted.

---

## End
