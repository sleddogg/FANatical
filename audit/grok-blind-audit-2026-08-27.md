# FANatical blind technical audit

**Auditor:** independent read of this repository on 2026-08-27  
**Branch at time of read:** `cursor-backend-audit` at `4043077` (`chore: add Cursor ignore rules`), matching local `production-foundation`  
**Scope:** repository code, schema, tests, configuration, and documentation. Hosted infrastructure was not touched.

This is an audit of the system as it exists, not of the product spec’s completeness scores. Spec sections marked 10/10 are design documents. Most fan-facing features in the React app are still client-side prototypes sitting on top of a much more finished identity, privacy, catalog, and agent backend.

---

## 1. Coverage

### Verification commands run

Database target was confirmed **before** any SQL execution:

| Check | Result |
| --- | --- |
| Docker container | `supabase_db_fanatical-local` |
| Image | `public.ecr.aws/supabase/postgres:17.6.1.155` |
| Host bind | `0.0.0.0:15422 -> 5432/tcp` |
| In-container `SELECT current_database(), current_user, inet_server_addr()` | `postgres` / `postgres` / empty (Unix socket via `docker exec`, not a network host) |
| Container hostname | Docker id `ca767f6215cf`, not `*.supabase.co` |
| `supabase/config.toml` | `project_id = "fanatical-local"`, API `15421`, DB `15422` |

All SQL was sent with `docker exec -i supabase_db_fanatical-local psql -U postgres -d postgres`. No `supabase db push`, no `--linked`, no hosted/admin environment files.

| Command | Result |
| --- | --- |
| Live schema inventory (migrations, RLS, SECURITY DEFINER PUBLIC execute) | Completed. All 23 repository migrations are applied locally, including `202608260001`. Every `public` table has RLS. No `public`/`private` SECURITY DEFINER function retains PUBLIC EXECUTE. `profiles.relforcerowsecurity` is false. |
| Rolled-back storage-path probe (avatar_path rebind) | Completed; attack succeeded. Transaction rolled back. Details in finding B1. |
| All 11 files in `supabase/tests/*.sql` via the same local `docker exec` | All passed (≈207s). `profile_privacy_verification.sql` “passes” by returning a JSON dump with no assertions. |
| `npm run typecheck` (from `app/`) | Passed |
| `npm run test:run` (Vitest) | **Failed:** 2 tests timed out, 307 passed, 54 files passed / 2 files failed. Not fixed. Details below. |
| `npm run build` | Passed. Warns that the main JS chunk exceeds 500 kB; emits large Cheer routing and mock photo assets. |
| `npm run build:admin` | Passed |

Vitest failures (timeouts at the default 5000 ms; not investigated further):

- `app/src/features/cheer/CheerPage.test.tsx` — `reopens a published Cheer with identity, finish metadata, lyrics, and direct placement`
- `app/src/features/profile/ProfilePage.test.tsx` — `edits local profile content, featured category, and Sports Played records`

### Verification skipped, and why

| Item | Why skipped |
| --- | --- |
| Hosted Supabase schema, RLS, or data | Explicitly out of scope. One hosted migration is pending and must not be applied from this audit. |
| `npm run backend:test` wrapper | Equivalent SQL was run with independently confirmed `docker exec` to `supabase_db_fanatical-local`. |
| `npm run backend:verify` | Live local Auth/Storage/Realtime HTTP script. Not run. Storage RLS was instead probed in SQL. Auth signup/session was not exercised through the Storage API or Realtime websocket. |
| `supabase/tests/team_color_bootstrap_concurrency.sh` | Not part of the `.sql` suite. Not run. |
| Playwright (`npm run test:e2e`) | Requires a Chromium install the README says is not automatic. Not run. |
| `supabase db reset`, `db push`, or any linked-project command | Would mutate local or hosted state beyond transactional tests. |

### Files opened and read in full (or essentially in full)

**Config / deploy / local backend**

- `AGENTS.md`
- `supabase/config.toml`
- `supabase/README.md`
- `supabase/.gitignore`
- `app/package.json`
- `app/.gitignore`
- `app/.env.example`, `app/.env.development`, `app/.env.test`, `app/.env.hosted`, `app/.env.admin`
- `app/vite.config.ts`
- `app/wrangler.web.jsonc`, `app/wrangler.admin.jsonc`
- `app/scripts/local-supabase.mjs`
- `app/scripts/verify-local-supabase.mjs` (read; not executed)
- `app/playwright.config.ts`
- `app/e2e/shell.spec.ts`, `app/e2e/local-backend-network.spec.ts`
- `app/public/_headers`
- `app/public-admin/_headers`, `app/public-admin/_redirects`
- `app/README.md`
- `docs/production-deployment.md` (read through the operational checks; not memorized line-by-line after that)

**Migrations (full read)**

- `supabase/migrations/202608150001_user_profile_foundation.sql`
- `supabase/migrations/202608180001_admin_foundation.sql`
- `supabase/migrations/202608200001_profile_photo_library.sql`
- `supabase/migrations/202608200002_profile_visual_library.sql`
- `supabase/migrations/202608200003_app_theme_foundation.sql`
- `supabase/migrations/202608220001_profile_privacy.sql`

**Tests (full read)**

- `supabase/tests/profile_privacy.sql`
- `supabase/tests/profile_privacy_verification.sql`

**App / auth / admin / profile media (full or near-full)**

- `app/src/lib/supabase/client.ts`
- `app/src/lib/supabase/backendEnvironment.ts`
- `app/src/lib/supabase/backendEnvironment.test.ts`
- `app/src/admin/adminAccess.ts`, `app/src/admin/adminAccess.test.ts`, `app/src/admin/AdminApp.tsx`
- `app/src/features/account/AuthContext.tsx`
- `app/src/features/account/AccountDialog.tsx`
- `app/src/features/account/AccountBootstrap.tsx`
- `app/src/features/account/accountRepository.ts`
- `app/src/features/profileAvatar/profileAvatarRepository.ts`
- `app/src/features/profileMedia/profileMediaRefresh.ts`
- `app/src/features/profileMedia/profileMediaSignedUrlCache.ts` (through the lifetime/cache logic)
- `app/src/features/profile/ProfilePrivacySettings.tsx`
- `app/src/features/profile/ProfilePrivacySettings.test.tsx`
- `app/src/features/profile/mockProfileData.ts`
- `app/src/app/App.tsx`, `app/src/app/routes.tsx`
- `app/src/test/setup.ts`
- `app/src/pages/HomePage.test.tsx`

### Files sampled in part (structure, grants, critical functions, or representative sections — not every line)

**Large SQL (read headers, identity/protection triggers, capability helpers, grant/RLS tails, and selected function bodies; not every helper and not seed rows)**

- `202608190001_team_registry_foundation.sql` — identity tables, `has_catalog_capability`, admin RPCs, `review_catalog_proposal` through independent-verifier enforcement, `protect_verified_catalog_version`, RLS/grant loops
- `202608190003_verification_policy_activation.sql` — capability alias for venue mapping; `admin_upsert_trusted_source` candidate-import restriction
- `202608210001_team_color_agent_interface.sql` — queue schema, `has_team_color_capability`, `enqueue_team_color_work`, grant/RLS block
- `202608230004_agent_backend_architecture.sql` — runtime policy tables, lineage/verification queues, `run_agent_backend_recovery`, final revoke/grant block
- `202608230005_agent_operating_policy.sql` — full read of policy seed and concurrency triggers
- `202608230011_information_lineage_reviewer_lifecycle.sql` — grant/RLS tail
- `202608260001_canonical_competition_foundation.sql` — identity model, league mapping trigger, resolver, RLS/grants
- Grant/capability grep hits in `202608230001`, `202608230002`, `202608230003`, `202608230006`, `202608230007`, `202608230008`, `202608230010`

**Seed SQL (not row-audited)**

- `202608190002_team_registry_seed.sql` (1645 lines)
- `202608190004_complete_master_team_seed.sql` (3101 lines)
- `202608230009_team_color_source_seed.sql` (859 lines)

**SQL tests (structure and role-switching sampled; bodies executed, not fully read)**

- `competition_foundation.sql` (helpers + intent)
- `team_color_agent_workflow.sql` (jwt/capability sections; **no `SET ROLE`**)
- `source_qualification.sql`, `source_qualification_lineage_bootstrap.sql`, `information_lineage_resolution.sql`, `information_lineage_reviewer.sql`, `trusted_source_publisher_reliability.sql`, `team_color_bootstrap_revalidation.sql`, `team_color_source_seed.sql` — executed, not fully read
- `team_color_bootstrap_concurrency.sh` — read, not executed

**Frontend sampled**

- `app/src/features/profile/ProfilePage.tsx` (mock + live mix)
- `app/src/features/news/NewsPage.tsx` (mock feed)
- `app/src/features/cheer/cheerStorage.ts`, `cheerCheckIn.ts`, `cheerRouting.ts` (imports)
- `app/src/data/teamCatalogRepository.ts` (backend vs compatibility fallback)
- `app/src/features/profileVisual/profileVisualRepository.ts` (select lists)
- `app/src/features/internal/venues/rexallVenueData.ts` (convention + resolver)
- Remaining `app/src/**/*.test.ts(x)` — counted via Vitest, not each file read

**Docs sampled**

- `Fanatical build page.md` — status map and Core Platform / App Structure opening; not the remaining ~5,000 lines
- `AGENT_ARCHITECTURE.md` — status, principles, numeric policy, Brad/Astro/agent roles
- `supabase/TEAM_REGISTRY.md` — identity and Competition foundation
- `supabase/TEAM_COLOR_AGENT.md` — security boundary and capability list
- Root `index.html` (static prototype)

### Not examined

- `reference/` image contents (per scope: background). Production **does** import `reference/cheer/*.png` from `cheerRouting.ts`; I recorded the import, not the pixels.
- SVG icon artwork and the eight untracked files under `images/icons` and `images/logos`
- `app/node_modules/**`, lockfile internals
- Seed workbook rows and SHA details
- Root static prototypes beyond a sample of `index.html` (`news.html`, `quiz.html`, `fanbase.html`, `cheer.html`, `profile.html`, `quiz.js`, `quiz-data.js`)
- Gitignored `app/.env.local` / `app/.env.development.local` contents (keys)
- Hosted project, Cloudflare dashboard, DNS, Auth provider settings
- Every SECURITY DEFINER function body (~150+). I read the identity, privacy, admin, capability, enqueue, recovery, and grant surfaces, then grepped the rest.

**Confidence is high** on profile privacy SQL, catalog/agent authorization pattern, local/hosted guard, and the two blocking findings below. **Confidence is lower** on the interior of source-qualification / lineage / verifier comparison math, whether hosted matches local, and whether the two Vitest timeouts are product bugs or environment slowness.

---

## 2. Strengths (including decisions that look deliberate)

The backend is the serious part of this repository. The React app is a working shell with a real account/profile path; News, FANbase, Quiz, Cheer, trophies, and Fan Coins are still mostly local prototypes. That split looks intentional, not accidental.

### Durable facts, not session memory

Catalog identities are immutable public IDs plus hidden UUIDs. Mutable facts are append-only version rows. Verified rows cannot be overwritten or deleted; they can only be superseded (`protect_verified_catalog_version`, `supabase/migrations/202608190001_team_registry_foundation.sql` lines 616–637). Audit events are append-only. Team Color work events are append-only. Imported workbook data is labeled `imported_unverified` and is not silently treated as verified. That matches `AGENT_ARCHITECTURE.md` and `TEAM_REGISTRY.md`.

### Agents cannot be the database

Agents are ordinary Auth users mapped to `catalog_actors`. They get narrow capabilities. They do not receive a service-role key. They submit proposals and evidence through SECURITY DEFINER RPCs; they do not write version tables directly (`TEAM_COLOR_AGENT.md` security boundary; `202608210001` comments and grants). `review_catalog_proposal` refuses self-approval when `require_independent_verifier` is set (lines 1142–1144 of `202608190001`). The later Team Color policy seeds `require_independent_verifier = true` (`202608230005` lines 254–261).

### Authorization is in the database

The repeated pattern is: revoke table rights from `anon`/`authenticated`, enable RLS, expose only SELECT to staff/capable actors, and put mutations in SECURITY DEFINER functions that check `auth.uid()`, `has_staff_access`, or `has_catalog_capability`, with `SET search_path = ''`. Admin RPCs are executable by `authenticated` so PostgREST can call them, but they raise `Admin access is required` unless `staff_roles.role = 'admin'` (`admin_upsert_catalog_actor` / `admin_grant_catalog_capability`, `202608190001` lines 745–782). Views that I sampled use `security_invoker = true`, which avoids the usual Postgres “view owner bypasses RLS” footgun.

Live local check: **0** `public` tables without RLS; **0** SECURITY DEFINER functions in `public`/`private` still granting EXECUTE to PUBLIC.

### Profile media privacy was designed, not bolted on

`profiles.visibility` replaced `is_public`. Direct table reads of `profiles` and source-bearing visual tables are owner-only. Public viewers are supposed to use `get_profile_for_viewer`, which omits original paths (`202608220001` lines 83–184). Storage SELECT is owner-folder **or** a display path that `private.profile_media_path_is_visible` accepts; originals win over a conflicting display label (lines 186–223). `supabase/tests/profile_privacy.sql` actually `SET LOCAL ROLE` to `authenticated` and `anon` and asserts those boundaries. `verify-local-supabase.mjs` (unread at runtime) independently refuses any request whose hostname is the production project.

### Local vs hosted is treated as a safety boundary

Ordinary `npm run dev` uses `VITE_SUPABASE_URL=/supabase` proxied to `127.0.0.1:15421`. Accidental localhost use of the production hostname throws (`backendEnvironment.ts` lines 50–53). `dev:hosted` is an explicit opt-in with a warning. Local helper commands use `db reset --local` and never `--linked`. SQL tests redact keys. Vitest stubs Supabase env to empty so `.env.local` cannot aim unit tests at hosted (`app/src/test/setup.ts` lines 5–10).

### Operating numbers are data, not comments

Lease length, retry, concurrency (1 specialist + 1 verifier, 2 global), watchdog interval, and six-month revalidation are versioned rows (`202608230005`). Claim paths ignore a caller-supplied lease duration and use policy (`team_color_agent_workflow.sql` assertion around lines 396–403). That is a real design, and the workflow test actually checks it.

### Frontend account path is adapter-shaped

Components talk to `accountRepository` / media repositories rather than issuing ad-hoc queries everywhere. `save_my_profile` is SECURITY INVOKER and uses `auth.uid()`. Admin UI is a gate only; it does not mutate `staff_roles`. Wrangler configs contain no secrets.

These look like choices, not accidents.

---

## 3–6. Deficiencies, risks, and gaps

Ranked by consequence. Each item is either a defect or a deliberate decision I would still question.

---

### BLOCKING / HIGH CONSEQUENCE

#### B1. Private display media can be rebound through `profiles.avatar_path`

**Kind:** defect  
**Where:** `private.profile_media_path_is_visible` includes `profiles.avatar_path` as a display path (`202608220001` lines 205–223). Owners may `UPDATE` any column on their `profiles` row (`202608150001` lines 249–251 and 299; privacy migration never narrowed this). There is no trigger requiring `avatar_path` / `source_path` / `display_path` to live under the owner’s storage folder. Unique constraints on `profile_photos.display_path` do not apply to `profiles.avatar_path`.

`supabase/tests/profile_privacy.sql` never tries a cross-user path. Filenames in the real uploader are `{userId}/avatar/{timestamp}-{uuid}-display.webp` (`profileAvatarRepository.ts` lines 114–118), so blind guessing is hard — but `get_profile_for_viewer` returns `display_path` while a profile is public (lines 144–161 of the privacy migration). After the owner switches to private, anyone who saw that path can keep it.

**Confirmed by running** (local `docker exec`, transaction rolled back):

1. Victim profile `private`, display object at `{victim}/avatar/victim-display.webp`.
2. Anon cannot read it (baseline).
3. Attacker, as `authenticated`, `UPDATE profiles SET avatar_path = '{victim}/avatar/victim-display.webp'`.
4. `private.profile_media_path_is_visible(victim display)` → `true` for the attacker.
5. Attacker `SELECT` of the victim display object → **1 row**.
6. Attacker `SELECT` of the victim **source** object → **0 rows** (originals still protected).
7. Anon `SELECT` of the victim display object after the public attacker rebound → **1 row**.

**What concretely breaks:** a private profile’s **display** derivatives become readable by the attacker, and by the world if the attacker’s profile is public. Originals appear protected.  
**Reversible?** Yes, if the owner replaces the file (new path) or the attacker’s `avatar_path` is cleared. Until then the private display object stays world-readable. Not an Auth bypass; it is a confused-deputy on storage authorization.

---

#### B2. First sign-in writes the demo “Sleddogg / Alex Mercer” profile onto the real account, publicly

**Kind:** defect (the *idea* of migrating prototype preferences is deliberate; this implementation is not)  
**Where:** `migratePrototypeAccount` in `app/src/features/account/AccountBootstrap.tsx` lines 24–34:

```ts
await saveOwnedProfile(userId, { ...initialProfile, id: userId });
```

`initialProfile` (`app/src/features/profile/mockProfileData.ts` lines 4–32) is a public demo identity: display name from `demoUser`, handle `@…`, given name **Alex Mercer**, nickname **Sleddogg**, birthplace **Edmonton, Alberta**, Patriots/Red Sox/Celtics fan-identity text, etc.

`saveOwnedProfile` sends that payload to `save_my_profile`, including `visibility: "public"` (`accountRepository.ts` lines 162–178). Signup had already created a profile from the user’s display name (`handle_new_fanatical_user`, `202608150001` lines 119–135; `AuthContext.tsx` lines 68–77). The bootstrap then overwrites it. Followed teams are taken from localStorage; the profile is **not** — it is always the hardcoded demo. `user_settings.prototype_migration_version` defaults to 0, so this runs once per new account.

I did not click through a live signup. The code path is unconditional for any configured Supabase session whose settings version is below 1. `fanaticalpeople.com` is documented as live against hosted Supabase.

**What concretely breaks:** a new real account’s identity fields become the public demo persona, clobbering the display name they just typed. `get_profile_for_viewer` is granted to `anon` and would return that persona if a viewer knows the user id.  
**Reversible?** Yes, the owner can edit. The wrong public record exists until they do. This is identity-data corruption, not a permissions hole.

---

### MEANINGFUL BUT LATER

#### M1. Default profile audience is public

**Kind:** deliberate; I would question it  
**Where:** `202608220001` lines 11–12; live local `column_default` is `'public'::text` (from `profile_privacy_verification.sql` output). `get_profile_for_viewer` exposes given name, birthplace, height, weight, jersey number, fan identity, followed team ids (`202608220001` lines 93–175). The UI explains Public vs Private (`ProfilePrivacySettings.tsx` lines 19–27) but new rows are public before anyone opens that control. Combined with B2, the demo persona is public by default.

#### M2. No uniqueness or format rule on `profiles.handle`

**Kind:** defect / omitted constraint  
**Where:** `profiles.handle` is `text not null default ''` with no unique index (foundation migration lines 8–9; no later unique). `handle_new_fanatical_user` derives `@` + stripped display name, so two users named “Fan” both get `@fan`. Handles are part of the public viewer RPC. This will collide the moment two people share a nickname.

#### M3. Media metadata paths are not bound to the owner folder

**Kind:** defect (same family as B1)  
**Where:** `profile_photos`, `profile_visual_images`, and `profile_visuals` accept any `source_path`/`display_path` string as long as RLS `user_id = auth.uid()` holds. Storage **upload** is folder-scoped (`202608150001` lines 320–322). Metadata is not. B1 is the `avatar_path` instance; the same missing prefix check exists on the library tables. Unique path constraints stop two rows from sharing a display path, but they do not stop an owner from pointing at another user’s object if that path is not already registered.

#### M4. Signed URLs remain valid after a profile goes private

**Kind:** deliberate; documented  
**Where:** `supabase/README.md` lines 102–107; client cache lifetime is one hour with a five-minute safety window (`profileMediaSignedUrlCache.ts` lines 5–6). The README is honest. B1 is worse because it persists after expiry. Shortening URL TTL does not fix B1.

#### M5. Almost no SQL tests except `profile_privacy.sql` exercise table RLS as `authenticated`/`anon`

**Kind:** coverage gap, not a schema bug by itself  
**Where:** repository grep for `set local role` under `supabase/tests/` hits **only** `profile_privacy.sql`. Agent/catalog tests set `request.jwt.claim.sub` and call SECURITY DEFINER RPCs while remaining `postgres` (bypasses RLS). That is a valid way to test capability checks. It is **not** a valid way to prove “authenticated cannot SELECT `catalog_actors`.” I am not claiming those tables are open; the grant/RLS SQL looks closed. I am claiming the suite does not prove it the way the privacy test does.

`profile_privacy_verification.sql` is named like a proof and is only a `SELECT jsonb_build_object(...)`. The runner treats a successful SELECT as “Passed”. It asserted nothing. On this local database it even reported `"visibility_values": null` because there were no profiles.

`adminAccess.test.ts` only parses a JSON shape. It never talks to `staff_roles` RLS.

Vitest globally blanks Supabase credentials, so the 307 passing frontend tests do not exercise Auth, RLS, or Storage. That is deliberate isolation (`setup.ts`), not coverage of the backend.

#### M6. Fan product surfaces are still mock/local while the live site is an identity-capable app

**Kind:** deliberate staging; risky if users treat the UI as real  
**Where:** `NewsPage.tsx` imports `mockNewsItems`. FANbase uses `mockFanbaseData`. Quiz uses `mockQuizData`. Cheer libraries live in IndexedDB/localStorage (`cheerStorage.ts`). `ProfilePage.tsx` still imports `initialProfile`, `profileMoments`, `profileStats`, `profileTrophies` (lines 13–14) alongside live `loadOwnedProfile`. Trophy Case / Fan Score / Fan Coins on the profile are fake numbers (`mockProfileData.ts` lines 35–40). Cheer check-in stores tickets’ file names locally, not the backend (`cheerCheckIn.ts`).

This is not “the spec is unfinished.” The spec claims many of these systems are complete as **design**. The implementation is a prototype UI on a real account database. Users on `fanaticalpeople.com` can create real accounts and then see fictional scores and news.

#### M7. Two team catalogs

**Kind:** deliberate and documented; drift risk  
**Where:** `TEAM_REGISTRY.md` lines 4–6; `teamCatalogRepository.ts` falls back to `officialSportsDatabase` when the backend snapshot fails. `user_followed_teams.team_id` is unconstrained text (foundation lines 58–67) with a comment that a catalog FK can come later. A user can persist a team id the catalog does not know.

#### M8. Competition foundation is in local migrations and not verified on hosted

**Kind:** operational gap  
**Where:** local `supabase_migrations.schema_migrations` includes `202608260001`. I did not inspect hosted. The instruction that one hosted migration is pending is consistent with this file being the one. Until it is applied through the normal reviewed workflow, hosted News/catalog consumers cannot rely on Competition tables. The migration wraps itself in `BEGIN`/`COMMIT` (`202608260001` lines 14 and 1222). Inside Supabase’s own migration transaction that usually warns and then commits early; locally it applied. I would still watch that file when it is pushed.

#### M9. Watchdog/recovery is an RPC, not a scheduled job in this repo

**Kind:** deliberate incompleteness  
**Where:** `run_agent_backend_recovery()` requires staff or `agent.watchdog.run` (`202608230004` lines 3732–3734) and is granted to `authenticated`. `expire_*` helpers are revoked from `authenticated` and only run inside that wrapper. There is no `pg_cron` (or other scheduler) in the migrations I read. `202608230005` says the migration does not launch workers. Stale leases will not recover themselves in production until something privileged calls this on the 15-minute cadence the policy describes.

#### M10. `admin_register_catalog_domain_adapter` takes `regproc` and recovery `EXECUTE`s it

**Kind:** deliberate high privilege; I would question the surface  
**Where:** grant at `202608230004` lines 4610–4611; `run_agent_backend_recovery` does `execute format('select %s()', adapter_record.recover_domain_function::regproc)` (lines 3745–3746). Restricted to `has_staff_access` / equivalent admin RPCs. A compromised admin account can aim SECURITY DEFINER execution at any existing function. Prefer a closed allowlist of adapter names over raw `regproc` when this is enabled in production.

#### M11. Wildcard catalog capability `*`

**Kind:** deliberate; I would keep it rare  
**Where:** `has_catalog_capability` matches `required_capability` **or** `'*'` (`202608190001` lines 722–723). `admin_grant_catalog_capability` does not validate the capability string against an allowlist (lines 761–807). `TEAM_COLOR_AGENT.md` correctly says not to grant `*` to the agent. There is no database check preventing it.

#### M12. Venue mapping and inventory tables are anonymously readable

**Kind:** likely deliberate for Cheer/seat resolution; I would question publishing inventory rules  
**Where:** `202608190001` lines 1671–1686 grant `SELECT` to `anon, authenticated` with `using (true)` on `venue_mapping_versions`, sections, exceptions, inventory rules/overrides, team profiles. Cheer production code imports `rexallVenueData` (`cheerCheckIn.ts` line 1). If those Postgres rows will hold commercially sensitive seating maps, public SELECT is a product decision to revisit before filling them.

#### M13. Production JS bundle is very large and includes mock photos plus Cheer routing reference art

**Kind:** performance / product-boundary issue  
**Confirmed by** `npm run build`: `main-CurFfNHz.js` 1.1 MB (292 kB gzip), plus many 1–6 MB images from `images/FAN fotos/` and `reference/cheer/routing/`. `cheerRouting.ts` lines 1–30 import those reference PNGs into the fan app. Not a secret-key leak. It does put internal routing diagrams and personal-looking mock photos on the public Worker.

#### M14. Sign-out is local-device only

**Kind:** deliberate  
**Where:** `AuthContext.tsx` line 84 `signOut({ scope: "local" })`; UI copy in `AccountDialog.tsx` line 76. Refresh tokens on other devices remain valid. Fine for multi-device. Stolen tokens are not revoked by “Sign Out” on this device.

#### M15. Local Auth policy is weaker than the UI, and the UI is the only 8-character check

**Kind:** local-dev only unless hosted was aligned (not verified)  
**Where:** `supabase/config.toml` `minimum_password_length = 6`, `enable_confirmations = false`. `AccountDialog` uses `minLength={8}`. Hosted Auth was not inspected.

#### M16. Static prototype HTML remains in the repository root

**Kind:** leftover, low operational risk if nothing serves it in production  
Cloudflare builds `app/`. Root `index.html` / `news.html` / etc. are the old prototype (`app/README.md` line 3). They should not be deployed by the current Worker config. They can still confuse humans about which UI is canonical.

#### M17. Documentation drift on `_redirects`

**Kind:** docs  
`AGENTS.md` says `app/public/_redirects` was removed. `docs/production-deployment.md` line 121 still says Workers copies `_headers` and `_redirects`. Admin still has `app/public-admin/_redirects` (`/* /index.html 200`). Wrangler SPA fallback makes the web file unnecessary.

---

### LOW RISK / CLEANUP

#### L1. `GRANT SELECT` on `profiles` to `anon` from the first migration was never revoked

**Where:** `202608150001` line 298. After privacy, there is no anon SELECT policy, so RLS should return zero rows (the privacy test checks this). The leftover GRANT is noise. Same class: some policies still target PostgreSQL `PUBLIC` (visible in the verification dump as `"roles": ["public"]`) while grants are narrower.

#### L2. `FORCE ROW LEVEL SECURITY` is off

**Where:** live `profiles.relforcerowsecurity = f`. Table owner / `service_role` bypass RLS. Normal for Supabase. SECURITY DEFINER functions run as owner and **must** keep doing their own `auth.uid()` checks. The ones I read do. I did not read every one.

#### L3. Replica identity FULL + Realtime publication on profile-related tables

**Where:** foundation migration lines 309–371. After privacy, non-owners cannot SELECT `profiles`, so they should not receive those change events. `fan_identities` remains readable for public profiles, including `additional_identity` jsonb. Acceptable for a public profile; worth remembering if visibility gains more states.

#### L4. Vitest timeouts in this run

Two tests hit the 5s limit (`CheerPage.test.tsx:387`, `ProfilePage.test.tsx:37`). 307 others passed. This environment may simply be slow. I did not re-run them. Do not treat the timeout as proof the Cheer/Profile editors are broken.

#### L5. Admin `parseStaffAccess` allows any string in `permissions`

**Where:** `adminAccess.ts` lines 24–25. Harmless while the shell has no permission-gated tools. Tighten when those tools exist. Database `staff_roles.permissions` is already `text[]`.

#### L6. `current_catalog_actor_id` is `LIMIT 1` without `ORDER BY`

**Where:** `202608190001` lines 697–700. Mitigated by `catalog_actors.auth_user_id uuid unique` (line 108). Fine unless that unique is dropped later.

#### L7. CSP `style-src 'unsafe-inline'` and `Permissions-Policy` camera/microphone on the fan `_headers`

**Where:** `app/public/_headers`. Cheer recording likely needs mic. `'unsafe-inline'` styles are common. Admin headers correctly add `noindex` and turn camera/mic off.

#### L8. Local stack listens on `0.0.0.0:15422`

Docker published Postgres to all host interfaces. `supabase/README.md` already says use a trusted LAN only. This is a development-machine exposure, not the production Worker.

---

## 7. What I could not verify / low confidence

- **Hosted schema vs this repo.** Local has all 23 migrations. Hosted was not queried. Treat anything that depends on `202608260001` (Competition) as not live until that reviewed push happens.
- **Whether B2 has already happened to real hosted users.** Code says it will on first bootstrap. I did not read hosted `profiles` rows.
- **Storage API vs SQL RLS.** The rebind was proven with `SET ROLE` + `storage.objects` RLS, which is what Storage uses. I did not call `download` / `createSignedUrl` over HTTP.
- **Source-qualification scoring, lineage comparison, and verifier consensus interiors.** Tests passed; I did not manually re-derive the algorithms.
- **Concurrency script** for the 100-team Team Color bootstrap threshold.
- **Playwright viewport/network e2e.**
- **Whether production Auth password/confirmation settings match `config.toml` (they should not; that file is local-only).**
- **The two Vitest timeouts** as product vs harness.
- **Every SECURITY DEFINER body.** Pattern is consistent on the surfaces I read; that is not a proof about the ones I only grepped.

---

## Short independent read

This is a catalog-and-agent backend with unusually strong instincts (append-only verified facts, capability-scoped RPCs, empty `search_path`, invoker views, independent verifiers, local/hosted split) sitting under a fan UI that is still mostly mock data. The live site can already create real people. Before treating accounts as production-ready, fix the display-path confused deputy (B1) and stop writing the demo profile onto new accounts (B2). Do not read a green SQL file name as proof of the behavior it sounds like; `profile_privacy.sql` is a real RLS test, `profile_privacy_verification.sql` is not, and the agent suites test RPCs as superuser.

The rest — default-public profiles, handle uniqueness, mock News/Cheer/Quiz, unscheduled watchdog, dual team catalogs — is real work, but it is the next layer, not the same class as private media escaping or identity being overwritten.
