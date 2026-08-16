import { cleanup } from "@testing-library/react";
import "@testing-library/jest-dom/vitest";
import { afterEach, beforeEach, vi } from "vitest";

// Unit tests exercise the deterministic local prototype unless a test opts into
// a mocked Supabase client explicitly. Developer credentials from .env.local
// must not make the test suite depend on the hosted project or its Auth state.
vi.stubEnv("VITE_SUPABASE_URL", "");
vi.stubEnv("VITE_SUPABASE_PUBLISHABLE_KEY", "");
vi.stubEnv("VITE_SUPABASE_ANON_KEY", "");

beforeEach(() => {
  window.localStorage.clear();
});

afterEach(() => {
  cleanup();
});
