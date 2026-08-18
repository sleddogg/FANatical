# FANatical web application

This directory contains the new browser-first React and TypeScript application. The static prototype in the repository root remains separate reference material.

## Commands

```bash
npm install
npm run dev
npm run typecheck
npm run test:run
npm run build
npm run build:admin
```

Real viewport checks are configured with Playwright:

```bash
npx playwright install chromium
npm run test:e2e
```

The Chromium installation is intentionally not performed automatically because it is a large runtime download. `npm run test:e2e:list` validates the suite configuration without installing a browser.

## Production surfaces

The default build is the responsive fan application for `fanaticalpeople.com` and `app.fanaticalpeople.com`. The admin-mode build is a separate, private shell for `admin.fanaticalpeople.com`; it requires both Supabase authentication and an active backend `staff_roles` assignment.

Hosted Supabase provides the current account/profile foundation. PWA metadata is present, but service-worker/offline behavior and Capacitor packaging remain deliberately deferred. See [`../docs/production-deployment.md`](../docs/production-deployment.md) for the deployment architecture, environment variables, DNS safety boundary, Auth redirects, and admin provisioning process.
