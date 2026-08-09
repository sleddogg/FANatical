# FANatical application shell

This directory contains the new browser-first React and TypeScript application. The static prototype in the repository root remains separate reference material.

## Commands

```bash
npm install
npm run dev
npm run typecheck
npm run test:run
npm run build
```

Real viewport checks are configured with Playwright:

```bash
npx playwright install chromium
npm run test:e2e
```

The Chromium installation is intentionally not performed automatically because it is a large runtime download. `npm run test:e2e:list` validates the suite configuration without installing a browser.

## Current boundary

Only the application foundation, routes, shared shells, navigation, design tokens, and test baseline are implemented. PWA/service-worker behavior, Capacitor configuration, data systems, authentication, and feature functionality are intentionally deferred.
