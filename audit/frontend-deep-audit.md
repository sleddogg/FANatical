# FANatical Frontend-First Technical Audit

## 1. COVERAGE REQUIREMENT

**Total Frontend Files:** 212 files (identified via `find app/src -type f \( -name "*.ts" -o -name "*.tsx" \) | wc -l`).

**Real-User Surface:** 25 files.
I established this surface by searching the entire `app/src` tree for imports of the Supabase client (`supabase`, `requireSupabase`), authentication contexts (`useAuth`, `AuthContext`), bootstrap logic (`AccountBootstrap`), and repository functions that persist data. I read each of these files in full:
- `app/src/state/ThemeContext.tsx`
- `app/src/state/TeamContext.tsx`
- `app/src/admin/AdminApp.tsx`
- `app/src/components/BottomNavigation.tsx`
- `app/src/data/profileImageShapePreference.ts`
- `app/src/data/navigationSidePreference.ts`
- `app/src/data/homeCustomizationPreference.ts`
- `app/src/data/teamCatalogRepository.ts`
- `app/src/data/themePreference.ts`
- `app/src/lib/supabase/client.ts`
- `app/src/pages/HomePage.tsx`
- `app/src/app/App.tsx`
- `app/src/layouts/RootShell.tsx`
- `app/src/features/profileMedia/profileMediaSignedUrlCache.ts`
- `app/src/features/profileAvatar/ProfileAvatarContext.tsx`
- `app/src/features/profileAvatar/profileAvatarRepository.ts`
- `app/src/features/profile/ProfilePage.tsx`
- `app/src/features/account/AccountDialog.tsx`
- `app/src/features/account/AuthContext.test.tsx`
- `app/src/features/account/AccountBootstrap.test.tsx`
- `app/src/features/account/AuthContext.tsx`
- `app/src/features/account/accountRepository.ts`
- `app/src/features/account/AccountBootstrap.tsx`
- `app/src/features/profileVisual/profileVisualRepository.ts`
- `app/src/features/profileVisual/ProfileVisualContext.tsx`

**Outside the Real-User Surface:** 187 files.
I established these are outside the surface by confirming they do not import any of the Supabase clients, auth contexts, or repository files that wrap Supabase. For example, `NewsPage.tsx`, `FanbasePage.tsx`, and `CheerPage.tsx` were verified to use local mock data (`mockNewsData.ts`, `mockFanbaseData.ts`, `mockCheerData.ts`) and local storage, demonstrating they do not cross into real user state.

**Unclassified Files:** 0 files. All files were classified.

## 2. VERIFICATION

- **TypeScript typecheck:** Passed. (`npm run typecheck`)
- **Frontend unit and integration test suite:** Failed. (`npm run test:run`) 8 tests failed due to timeouts in `CheerPage.test.tsx` and `QuizPage.test.tsx`.
- **Production build:** Passed. (`npm run build`)
- **Playwright end-to-end tests:** Skipped. `npx playwright install --with-deps` failed because it requires `sudo` privileges to install browser dependencies, which is not available in the current automated environment.

## 3. AUDIT FINDINGS

### Untyped Supabase Responses
- **Classification:** LOW RISK / CLEANUP (Deliberate design decision)
- **Finding:** The frontend uses `UnknownRow = Record<string, unknown>` and casts `result.data as UnknownRow`. It uses helper functions like `text(row, "key")` to safely extract strings. This is a deliberate design decision to avoid generating full TypeScript types from the database schema, keeping the frontend decoupled from exact backend types.
- **Location:** `app/src/features/account/accountRepository.ts` (lines 12, 38-41).

### Prototype Data Migration
- **Classification:** LOW RISK / CLEANUP (Deliberate design decision)
- **Finding:** `AccountBootstrap.tsx` automatically migrates prototype data (followed teams, settings, profile visuals) from `localStorage` and `IndexedDB` to the real user account in Supabase. This is a deliberate design decision to migrate users from the prototype to the real backend.
- **Location:** `app/src/features/account/AccountBootstrap.tsx` (lines 32-60).

### Storage Upload Paths
- **Classification:** LOW RISK / CLEANUP (Deliberate design decision)
- **Finding:** Upload paths in `profileAvatarRepository.ts` and `profileVisualRepository.ts` are constructed as `${userId}/avatar/...` and `${userId}/profile-visual/...`. This correctly matches the backend RLS policy `(storage.foldername(name))[1] = auth.uid()::text`.
- **Location:** `app/src/features/profileAvatar/profileAvatarRepository.ts` (line 98).

### Missing Handle Format Validation
- **Classification:** MEANINGFUL BUT LATER (Latent defect)
- **Finding:** The `saveOwnedProfile` function passes `handle: profile.handle.trim()` to the backend `save_my_profile` RPC. There is no regex validation for the handle format (e.g., no spaces, valid characters) on the frontend. Since the backend also lacks this validation, this is a latent defect that could allow malformed handles if the UI ever exposes a way to edit the handle.
- **Location:** `app/src/features/account/accountRepository.ts` (line 168).

### Missing Public Profile Route
- **Classification:** MEANINGFUL BUT LATER (Missing feature / Deliberate scope limitation)
- **Finding:** There is no route in `appRoutes` to view another user's profile (e.g., `/profile/:handle`). Users can only view their own profile at `/profile`. The `loadViewableProfile` function exists in the repository but is currently unused by the routing layer.
- **Location:** `app/src/app/routes.tsx` (lines 37-67).

### News and Cheer Live-versus-Mock Boundaries
- **Classification:** LOW RISK / CLEANUP (Deliberate design decision)
- **Finding:** `NewsPage.tsx`, `FanbasePage.tsx`, and `CheerPage.tsx` use mock data and local storage. There is no Supabase integration for News, Fanbase, or Cheer yet. They are entirely mock/local.
- **Location:** `app/src/features/news/NewsPage.tsx`, `app/src/features/fanbase/FanbasePage.tsx`, `app/src/features/cheer/CheerPage.tsx`.

### Realtime Account Synchronization
- **Classification:** LOW RISK / CLEANUP (Deliberate design decision)
- **Finding:** `subscribeToAccountChanges` uses Supabase Realtime to listen for changes to `profiles`, `fan_identities`, etc., and triggers a reload. This keeps the frontend fresh and prevents stale or contradictory frontend and backend data.
- **Location:** `app/src/features/account/accountRepository.ts` (lines 222-230).