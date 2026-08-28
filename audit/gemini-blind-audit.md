# FANatical Technical Audit Findings

## 1. COVERAGE

**Files Examined:**
- **Read fully:** `package.json`, `app/src/app/routes.tsx`, `app/src/features/account/accountRepository.ts`, `supabase/migrations/202608150001_user_profile_foundation.sql`, `supabase/migrations/202608180001_admin_foundation.sql`, `supabase/migrations/202608220001_profile_privacy.sql`, `supabase/migrations/202608270001_profile_media_path_ownership.sql`, `supabase/migrations/202608270002_ambiguity_safe_team_resolution.sql`.
- **Sampled:** `supabase/migrations/202608190001_team_registry_foundation.sql`, `supabase/migrations/202608230004_agent_backend_architecture.sql`, `supabase/migrations/202608230005_agent_operating_policy.sql`, `supabase/migrations/202608230007_factual_source_qualification.sql`, `supabase/migrations/202608230008_information_lineage_resolution_activation.sql`.
- **Not examined:** Playwright e2e tests, legacy HTML files in the root, and the `reference/` folder images.

**Verification Performed:**
- Ran `npm run typecheck` and `npm run backend:test` locally. Both completed successfully.
- Explored the Supabase migrations to trace the database schema and RLS policies.
- Skipped Playwright tests as the backend tests provided sufficient confidence and I wanted to focus on data integrity and security.
- **Confirmed:** I did not interact with the hosted infrastructure or run any destructive commands.

## 2. STRENGTHS

- **Robust RLS and Security Definer Usage:** The database relies heavily on `security definer` functions (e.g., `private.can_view_profile`, `public.get_profile_for_viewer`) to encapsulate complex authorization logic while keeping the underlying tables strictly locked down. This is a deliberate and strong design choice.
- **Storage Path Ownership:** The migration `202608270001_profile_media_path_ownership.sql` enforces that media paths belong to the user's namespace (`(storage.foldername(name))[1] = auth.uid()::text`). This prevents users from referencing or manipulating media in other users' buckets.
- **Ambiguity-Safe Resolution:** The `public.resolve_catalog_team` function explicitly handles ambiguous external identifiers by returning an `ambiguous` status and all candidates, rather than silently guessing. This is a load-bearing, defensive decision.
- **Agent Backend Architecture:** The agent job system (e.g., `agent_job_runtime_policies`, `agent_backend_operating_policies`) is highly structured with explicit leases, concurrency policies, and retry configurations. The constraints (like `agent_job_runtime_policies_retry_configuration_check`) ensure that retry configurations are logically sound.

## 3. DEFICIENCIES, RISKS AND GAPS

### Missing Unique Constraint on Profile Handles
- **Classification:** BLOCKING / HIGH CONSEQUENCE
- **Finding:** The `handle` column in `public.profiles` lacks a `UNIQUE` constraint. The `handle` is used as an `@username` equivalent. Without a unique constraint, multiple users can claim the exact same handle (e.g., `@admin`).
- **Consequence:** This breaks identity uniqueness in production. Multiple users can have the identical `@handle`, leading to impersonation, incorrect tagging, or routing collisions. While reversible, it would be messy to untangle who legitimately owns which handle once duplicated in production.
- **Location:** `supabase/migrations/202608150001_user_profile_foundation.sql` (line 5) and `supabase/migrations/202608220001_profile_privacy.sql` (where `save_my_profile` allows arbitrary handle updates without validation).

### Unvalidated Handle Format
- **Classification:** MEANINGFUL BUT LATER
- **Finding:** The `public.save_my_profile` function allows users to update their `handle` to any arbitrary string. There is no validation to prevent spaces, special characters, or malformed handles.
- **Location:** `supabase/migrations/202608220001_profile_privacy.sql` (line 44).

### Orphaned Catalog Actors on User Deletion
- **Classification:** LOW RISK / CLEANUP
- **Finding:** In `public.catalog_actors`, the `auth_user_id` column is configured with `on delete set null`. If a user is deleted from `auth.users`, their corresponding actor record remains active (`active = true`) but orphaned.
- **Location:** `supabase/migrations/202608190001_team_registry_foundation.sql` (line 12).

### Note on Deliberate Design Decisions
- The use of `security definer` for `public.get_profile_for_viewer` while keeping `public.profiles` readable only by the owner is a deliberate and effective way to enforce the `visibility` rules without exposing the entire table to complex RLS policies. This is not a defect, but a strong architectural pattern.