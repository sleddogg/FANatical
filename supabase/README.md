# FANatical Supabase foundation

The SQL in `migrations/` is the source of truth for the hosted database, RLS,
Storage policies, and realtime publication. It uses ordinary PostgreSQL tables;
Supabase-specific code is limited to Auth integration, the `storage.objects`
policies, and realtime publication.

## Hosted setup

1. Create or select the hosted FANatical Supabase project.
2. Apply the migrations with the Supabase CLI or the hosted SQL editor.
3. Copy `app/.env.example` to `app/.env.local` and provide the project URL and
   public publishable (or legacy anon) key. Never put the service-role key in
   the browser application.
4. Configure the development and production site URLs in Supabase Auth.
5. Start the app and create the development account from Profile / Sign In.

The private `profile-media` bucket stores source and optimized display files
under `<auth-user-id>/profile-visual/...`. PostgreSQL stores paths and crop
metadata; the UI creates short-lived signed URLs at read time.

The `staff_roles` table is the authorization source for the separate production
admin shell. Authenticated browser clients can read only their own active role;
role assignment is restricted to trusted database/service-role operations.
Future admin policies and RPCs should use `has_staff_access(...)` and grant the
minimum role or permission required by each operation.

The canonical team/source/venue registry, active verification policies, and
Trusted Source Registry review workflow are documented in
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
