# FANatical Supabase foundation

The SQL in `migrations/` is the source of truth for the hosted database, RLS,
Storage policies, and realtime publication. It uses ordinary PostgreSQL tables;
Supabase-specific code is limited to Auth integration, the `storage.objects`
policies, and realtime publication.

## Normal local development

FANatical's ordinary Vite workflow uses a fully local Supabase stack. Docker
Engine (or another Docker-compatible container runtime) must be installed and
running on the development machine.

From `app/`:

```sh
npm run backend:start
npm run dev -- --host
```

`backend:start` launches local Postgres, Auth, Storage, Realtime, Studio, and
the local email inbox, then writes the browser-safe local key to the gitignored
`app/.env.development.local`. It deliberately hides all keys in terminal
output. `npm run dev` uses `/supabase`; Vite proxies that path to
`127.0.0.1:15421`. A phone therefore uses the same LAN address as the frontend
without a changing IP in an environment file. Use this only on a trusted LAN;
do not expose the Vite development server or local stack to the public internet.

Useful commands:

```sh
npm run backend:status  # safe URLs and current local status
npm run backend:reset   # local only: rebuild every repository migration
npm run backend:test    # transactional local database SQL/privacy tests
npm run backend:test:phase5a-concurrency # local multi-session name/comment/Request races
npm run backend:verify  # live local Auth, Storage privacy, and Realtime checks
npm run backend:acceptance:reset-proof # reset/restart fixture repair and preservation proof
npm run backend:types   # regenerate app/src/lib/supabase/database.types.ts
npm run backend:stop    # preserve local data and stop the stack
```

Create a local test account through Profile / Sign In / Create Account. Local
email confirmation is disabled, so any development-only email and password can
sign in immediately. Local Auth users and Storage objects are separate from
production; do not copy production users, credentials, or media. Studio is at
`http://127.0.0.1:15423` and the captured local email inbox is at
`http://127.0.0.1:15424`. FANatical uses the `15420–15429` local port block to
avoid Bobby's ordinary ephemeral client-port range.

The Phase 5A reset also provisions `FANatical Local Request Candidate` as a
governed, followable local-only organization that is deliberately absent from
the Demo universe and Brad/TestFan's baseline Following. To accept the Available
Request path, submit that exact name as Brad, resolve it as Available in the
admin shell (the matching target search is prefilled), then return as Brad and
use the Request's explicit Follow action. Resolution never auto-Follows it.

The `profile-media` bucket and all of its private-profile, display-derivative,
and owner-only original policies are created by the migrations during local
start/reset. `supabase/tests/profile_privacy.sql` exercises those boundaries.

## Intentional hosted development

Hosted development is an explicit exception. Put the hosted browser URL and
publishable key in the gitignored `app/.env.hosted.local` (the existing generic
`.env.local` is also supported), then run:

```sh
npm run dev:hosted -- --host
```

This mode displays a fixed yellow production warning and logs the same warning
without keys or tokens. Any localhost/private-LAN browser using FANatical's
known production Supabase URL without that explicit opt-in is blocked. The
guard does not block `fanaticalpeople.com` or another non-local production host.

## Hosted setup and migrations

1. Create or select the hosted FANatical Supabase project.
2. Apply the migrations with the Supabase CLI or the hosted SQL editor.
3. Cloudflare Workers Builds supplies `VITE_SUPABASE_URL` and
   `VITE_SUPABASE_PUBLISHABLE_KEY`. For an intentional hosted local smoke test,
   copy `app/.env.example` to `app/.env.hosted.local`. Never put the service-role
   key in the browser application.
4. Configure the development and production site URLs in Supabase Auth.
5. Start the app and create the development account from Profile / Sign In.

Local helper commands use only `supabase start`, `stop`, `status`, and
`db reset --local`; they never push migrations or mutate the linked project.
The existing hosted link remains available for the separate reviewed workflow:
inspect the pending migration list, obtain explicit approval, run
`supabase db push`, and verify the hosted result. Never add `--linked` to a
local reset command.

The private `profile-media` bucket keeps owner source/original objects under the
owner's `<auth-user-id>/...` prefix. Phase 5A fan-facing avatar derivatives use
the owner's immutable random `fan-media-<opaque>/avatar/...` namespace instead.
Owners may write/read both of their own namespaces. A fan-safe reader accepts
only the active, registered avatar derivative in the opaque namespace; source
objects, inactive media, UUID-prefixed legacy displays, and the wider media
library stay owner-only. PostgreSQL stores paths and crop metadata; the UI creates
short-lived signed URLs only after the current-name server reader authorizes the
request. The bucket must remain private.

`profiles.visibility` is the canonical profile audience. Phase 5A owner controls
are `private` and `members_visible`. Legacy `public` remains constraint-valid only
for rollback compatibility and is treated as Private by fan-safe readers; old
unconsented Public rows are migrated to Private. The signed-in-only
`get_member_profile_by_fanatical_name(text)` returns a server allowlist by current
Fanatical Name and enforces the fan population and reciprocal Hide. The old UUID
reader `get_profile_for_viewer(uuid)` is removed. Anonymous users receive no fan
profile or comment body.

Private comment attribution is narrow: a signed-in, non-separated ordinary fan
may receive the author's current Fanatical Name and permitted active avatar
derivative, not the member profile or optional personal fields. Members-visible
may additionally return only the approved fields whose individual owner controls
are enabled. Email, phone, exact date of birth, Auth UUIDs, internal owner IDs,
security data, originals, and inactive media are absent from the payload.

Supabase signed URLs are bearer URLs and cannot be revoked immediately. A URL
issued to an authorized signed-in member can remain usable until its expiry after
the owner changes visibility or either fan creates a Hide intent. FANatical does
not deliberately reuse the prior URL after current authorization changes, but
immediate third-party revocation would require an authorization proxy or a
shorter-lived delivery mechanism.

The `staff_roles` table is the authorization source for the separate production
admin shell. Authenticated browser clients can read only their own active role;
role assignment is restricted to trusted database/service-role operations.
Admin policies and RPCs grant the minimum role or permission required by each
operation. In particular, Phase 5A Community moderation requires the exact
`community_moderate` permission; a role label, catalog capability, or catalog
wildcard does not authorize its queue or mutations. Request resolution remains a
separate staff-role operation and revalidates current Phase 4 followability.

The canonical team/competition/source/venue registry, active verification
policies, and Trusted Source Registry review workflow are documented in
[`TEAM_REGISTRY.md`](TEAM_REGISTRY.md). Its seed workbook data is deliberately
marked imported and unverified. Catalog agents authenticate normally and use
narrow proposal/evidence RPCs; they never receive the service-role key.
The completed `FANatical_Master_Teams.xlsx` workbook is the current catalog
seed/reference; the earlier incomplete import remains only as immutable
migration history.

The autonomous Team Color research interface and dedicated OpenClaw
authentication/provisioning contract are documented in
[`TEAM_COLOR_AGENT.md`](TEAM_COLOR_AGENT.md). Agent secrets stay in the external
agent's encrypted secret configuration; they are never browser build variables
and never belong in this repository.

## Portability

The UI talks to account/profile repository modules rather than issuing queries
from components. A future self-hosted deployment can keep this schema and
replace the Supabase client adapters with the in-house auth, file, and realtime
transports.
