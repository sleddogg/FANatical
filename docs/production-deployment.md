# FANatical production deployment

## Production topology

FANatical uses two Cloudflare Workers Static Assets projects built by Workers Builds from the same `app/` React and TypeScript source and one existing hosted Supabase project.

| Worker | Domains | Build command | Deploy command | Static assets | Purpose |
| --- | --- | --- | --- | --- | --- |
| `fanatical-web` | `fanaticalpeople.com`, `app.fanaticalpeople.com` | `npm run build` | `npx wrangler versions upload --config wrangler.web.jsonc` | `app/dist` | The same responsive fan application for browser, mobile web, and the installable-web foundation. |
| `fanatical-admin` | `admin.fanaticalpeople.com` | `npm run build:admin` | `npm run deploy:admin` | `app/dist-admin` | Private staff shell with no fan-facing navigation and no public account creation. |

The two builds share the public Supabase client and authenticated account session model. Admin access additionally requires an active row in `public.staff_roles`; RLS permits a signed-in user to read only their own active assignment. Browser clients have no insert, update, or delete permission on this table. Future admin data mutations must also call RLS-protected tables or security-definer RPCs that check `public.has_staff_access(...)`.

The existing `/internal/venues/rexall-place` and `/internal/venues/rexall-place/test` routes remain available in Vite development. They are not registered in the production fan build. Venue administration should move into the authorized admin surface in a later focused task without discarding the existing resolver or mapping model.

## Cloudflare Workers Builds projects

Import the `sleddogg/FANatical` Git repository twice in Workers & Pages. Both Workers must use `production-foundation` as their production branch and `app` as their root directory. Disable non-production branch builds so the unrelated legacy `main` branch is never built or uploaded as a preview.

Use these exact project settings:

| Setting | Public Worker | Admin Worker |
| --- | --- | --- |
| Project name | `fanatical-web` | `fanatical-admin` |
| Production branch | `production-foundation` | `production-foundation` |
| Root directory | `app` | `app` |
| Build command | `npm run build` | `npm run build:admin` |
| Deploy command | `npx wrangler versions upload --config wrangler.web.jsonc` | `npm run deploy:admin` |

Workers Builds installs dependencies before the build. Wrangler is pinned in `package.json`. The public Worker's Workers Builds deploy command names `wrangler.web.jsonc` directly and uploads a saved version without activating it; the admin Worker still runs its `deploy:admin` script, which selects `wrangler.admin.jsonc`. The configs use Workers Static Assets with `not_found_handling: "single-page-application"`; no Worker runtime script is needed for this client-only application.

For both **Production** and any intentionally enabled **Preview** environment, configure:

```text
VITE_SUPABASE_URL=https://lsuceoieqgbagxxwobxu.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=<the hosted project's publishable key>
```

The publishable key is designed for a browser client but should still be configured through Pages environment variables. Never add a Supabase secret key, service-role key, database password, or Cloudflare API token to a Vite variable.

The Supabase values above are build variables because Vite embeds them into the browser bundle. They are not Worker runtime bindings. Do not add Supabase secret/service-role credentials. Cloudflare's generated Workers Builds API token is used only by the build system to deploy the Worker.

### Custom domains and DNS

After both Workers deploy successfully to their `workers.dev` test addresses, add custom domains from each Worker's **Settings → Domains & Routes** panel:

1. Attach `fanaticalpeople.com` and `app.fanaticalpeople.com` to `fanatical-web`.
2. Attach `admin.fanaticalpeople.com` to `fanatical-admin`.
3. Let Cloudflare create/validate only the required web-host records and managed HTTPS certificates.

Do not modify or replace `auth.fanaticalpeople.com`, Microsoft 365/Exchange MX records, SPF, DKIM, DMARC, Resend records, or any other mail/authentication records. Web hosting DNS changes are additive only. Cloudflare manages HTTPS after the custom domains become active.

## Production release and rollback

This section describes the public `fanatical-web` Worker. The `fanatical-admin` Worker is unchanged and still deploys through its own `deploy:admin` script.

### Normal public-web release

1. Push the accepted commit to `production-foundation`.
2. Cloudflare Workers Builds builds it and uploads a saved Worker version. No production traffic moves to that version automatically.
3. Confirm in the Worker's **Deployments** panel that the uploaded version corresponds to the expected commit and build, and that it is not yet active.
4. Verify that uploaded version as appropriate for the change.
5. Deliberately promote that exact uploaded version through Cloudflare **Deployments**.
6. Perform the production smoke check.

Promotion activates the version that was already built and verified. Do not rebuild the commit in order to promote it.

`npm run deploy:web` is a different operation. It runs a fresh `wrangler deploy` and immediately activates the resulting version. It is not the normal promotion mechanism and should be used only when an immediate rebuild-and-deploy is explicitly intended.

### Rollback

Open the Worker in Cloudflare, go to **Deployments**, select a previously known-good saved version, and use **Rollback**.

Rollback changes frontend traffic only.

### Supabase and frontend rollback asymmetry

A Cloudflare frontend rollback does not reverse hosted Supabase migrations. Any migration deployed before a frontend promotion must therefore remain compatible with both the currently active frontend and the immediately previous rollback-capable frontend version.

Do not rely on frontend rollback to undo database or schema changes.

## Supabase production configuration

### Required first step before any hosted migration apply

Before `supabase db push` or any other hosted migration apply, run the linked
migration ledger comparison as a read-only preflight:

```bash
npx supabase migration list --linked
```

Read the ledger output itself and confirm exactly which versions are applied on
hosted and which local migration files remain pending. Continue only when local
and hosted agree and hosted is simply behind local. If hosted contains a version
with no matching local file, local history omits an applied version, or any other
divergence exists, stop without applying and resolve/report the discrepancy.

The linked project must contain both migrations:

```text
202608150001_user_profile_foundation.sql
202608180001_admin_foundation.sql
```

Apply pending migrations only through the migration source of truth:

```bash
npx supabase db push
```

In **Authentication → URL Configuration** set:

```text
Site URL: https://fanaticalpeople.com
Additional redirect URLs:
  https://fanaticalpeople.com/profile
  https://app.fanaticalpeople.com/profile
  http://localhost:5173/profile
```

The first two exact production redirects support the account-confirmation URL generated by the application on each public surface. Keep the localhost entry only for local development. Do not use a broad production wildcard. The admin shell signs into an existing account and does not create accounts or need its own confirmation redirect.

Do not change the existing Supabase email provider, custom auth domain, SMTP/Resend configuration, Auth identities, profile tables, `profile-media` bucket, or session settings for this deployment.

## Provision the first admin

No email address is implicitly trusted. First create or identify the FANatical Auth account, then run the following through a trusted Supabase SQL/admin channel, replacing the email and choosing the minimum appropriate role:

```sql
insert into public.staff_roles (user_id, role, permissions, is_active)
select id, 'admin', array[]::text[], true
from auth.users
where lower(email) = lower('ADMIN_ACCOUNT_EMAIL')
on conflict (user_id) do update
set role = excluded.role,
    permissions = excluded.permissions,
    is_active = excluded.is_active;
```

Allowed initial roles are `admin`, `staff`, `venue_admin`, `content_admin`, and `moderator`. Do not expose a UI that lets an unauthorized browser grant roles. Removing or deactivating this database record revokes admin-shell access at the next authorization check/sign-in.

## Build and deployment checks

From `app/`:

```bash
npm ci
npm run typecheck
npm run test:run
npm run build
npm run build:admin
npm run deploy:web -- --dry-run
npm run deploy:admin -- --dry-run
```

After deployment, verify:

1. `https://fanaticalpeople.com` and `https://app.fanaticalpeople.com` render the same fan application and direct nested-route refreshes return the SPA.
2. Sign-in, sign-out, account confirmation, profile loading, profile editing, followed teams, navigation side, and profile-media reads/uploads use the existing hosted project.
3. `https://admin.fanaticalpeople.com` shows sign-in when signed out, denies an ordinary authenticated account, and opens the shell only for an active `staff_roles` assignment.
4. No service-role credential appears in either deployment's environment or JavaScript output.
5. Existing mail delivery and `auth.fanaticalpeople.com` continue to resolve and operate unchanged.

Workers Static Assets natively supports the copied `_headers` and `_redirects` files. The Wrangler SPA fallback also serves `index.html` for unmatched browser navigation routes. The admin headers additionally block indexing. The web manifest establishes installable-web metadata only—there is deliberately no service worker or offline cache yet.
