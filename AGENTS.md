# FANatical Repository Instructions

## Current Repository / Deployment State

- Canonical working branch: `production-foundation`
- GitHub default branch: `production-foundation`
- Cloudflare Workers Builds production branch: `production-foundation`
- Do not recreate or restore remote `main`.
- Local `production-foundation` is synchronized with `origin/production-foundation`.
- The stale `origin/main` reference has been pruned.
- `fanaticalpeople.com` is live and points to the `fanatical-web` Cloudflare Worker.
- Cloudflare build configuration:
  - Root: `app`
  - Build: `npm run build`
  - Deploy: `npm run deploy:web`
- Required Cloudflare build variables are:
  - `VITE_SUPABASE_URL`
  - `VITE_SUPABASE_PUBLISHABLE_KEY`
- The obsolete `app/public/_redirects` file was removed because Wrangler already provides SPA fallback.
- The temporary Cloudflare deploy hook was deleted.
- Do not change Cloudflare, GitHub branching, Wrangler configuration, Supabase configuration, deployment configuration, or domains unless the user explicitly asks.

## Local Files

There are eight currently untracked image files under `images/icons` and `images/logos`. They are intentionally untouched. Do not stage, delete, move, rename, or commit them unless the user specifically asks.

## Workflow

FANatical development has returned to frontend styling and UX.

- Work on one page or feature at a time.
- Do not make unrelated cleanup, refactors, architecture changes, dependency upgrades, or speculative improvements.

Before editing:

1. Inspect the existing implementation.
2. Explain briefly what files or components need changing.
3. Make only the requested change.
4. Preserve existing functionality unless the requested change explicitly alters it.
5. After editing, run the appropriate build and type checks.
6. Report exactly what changed and any issue that remains.

Do not assume the user is a programmer. Explain approvals or decisions in plain English, including what will happen before asking the user to approve a command.

## Styling Priorities

For styling work, prioritize:

- Responsive mobile and desktop behavior
- Accessibility and usability
- Preserving working functionality
- Finishing the current page before moving to another page
- Existing FANatical design decisions rather than inventing replacements
