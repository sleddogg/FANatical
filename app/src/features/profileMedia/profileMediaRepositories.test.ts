import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  resolve: vi.fn(),
  cached: vi.fn(),
  rows: new Map<string, unknown[]>(),
  singleRows: new Map<string, unknown>(),
}));

function queryFor(table: string) {
  const query = {
    select: vi.fn(() => query),
    eq: vi.fn(() => query),
    order: vi.fn(async () => ({ data: mocks.rows.get(table) ?? [], error: null })),
    maybeSingle: vi.fn(async () => ({ data: mocks.singleRows.get(table) ?? null, error: null })),
    then: (resolve: (value: unknown) => unknown) => Promise.resolve({ data: mocks.rows.get(table) ?? [], error: null }).then(resolve),
  };
  return query;
}

vi.mock("../../lib/supabase/client", () => ({
  requireSupabase: () => ({ from: (table: string) => queryFor(table) }),
}));

vi.mock("./profileMediaSignedUrlCache", () => ({
  profileMediaBucket: "profile-media",
  resolveProfileMediaSignedUrls: mocks.resolve,
  resolveProfileMediaSignedUrl: vi.fn(),
  cachedProfileMediaSignedUrl: mocks.cached,
  evictProfileMediaSignedUrls: vi.fn(),
}));

import { loadRemoteProfileAvatarLibrary, loadRemoteProfileAvatarSummary } from "../profileAvatar/profileAvatarRepository";
import { loadRemoteProfileVisualLibrary, loadRemoteProfileVisualSummary, loadRemoteProfileVisuals } from "../profileVisual/profileVisualRepository";

const avatarRows = [
  { id: "avatar-active", display_path: "avatar-active.webp", source_path: "avatar-active.jpg", source_filename: "active.jpg", source_media_type: "image/jpeg", source_width: 100, source_height: 100, focal_x: 0.5, focal_y: 0.5, zoom: 1, updated_at: "2026-08-22T00:00:00Z" },
  { id: "avatar-inactive", display_path: "avatar-inactive.webp", source_path: "avatar-inactive.jpg", source_filename: "inactive.jpg", source_media_type: "image/jpeg", source_width: 100, source_height: 100, focal_x: 0.5, focal_y: 0.5, zoom: 1, updated_at: "2026-08-22T00:00:00Z" },
];

const visualRows = [
  { id: "mobile-active", variant: "mobile", display_path: "mobile-active.webp", source_path: "mobile-active.jpg", source_filename: "mobile-active.jpg", source_media_type: "image/jpeg", source_width: 100, source_height: 100, focal_x: 0.5, focal_y: 0.5, zoom: 1, updated_at: "2026-08-22T00:00:00Z" },
  { id: "mobile-inactive", variant: "mobile", display_path: "mobile-inactive.webp", source_path: "mobile-inactive.jpg", source_filename: "mobile-inactive.jpg", source_media_type: "image/jpeg", source_width: 100, source_height: 100, focal_x: 0.5, focal_y: 0.5, zoom: 1, updated_at: "2026-08-22T00:00:00Z" },
  { id: "wide-active", variant: "wide", display_path: "wide-active.webp", source_path: "wide-active.jpg", source_filename: "wide-active.jpg", source_media_type: "image/jpeg", source_width: 100, source_height: 100, focal_x: 0.5, focal_y: 0.5, zoom: 1, updated_at: "2026-08-22T00:00:00Z" },
  { id: "wide-inactive", variant: "wide", display_path: "wide-inactive.webp", source_path: "wide-inactive.jpg", source_filename: "wide-inactive.jpg", source_media_type: "image/jpeg", source_width: 100, source_height: 100, focal_x: 0.5, focal_y: 0.5, zoom: 1, updated_at: "2026-08-22T00:00:00Z" },
];

describe("profile media repository URL scope", () => {
  beforeEach(() => {
    mocks.rows.clear();
    mocks.singleRows.clear();
    mocks.rows.set("profile_photos", avatarRows);
    mocks.singleRows.set("profiles", { active_profile_photo_id: "avatar-active" });
    mocks.rows.set("profile_visual_images", visualRows);
    mocks.rows.set("profile_visuals", [visualRows[0]!, visualRows[2]!]);
    mocks.resolve.mockReset().mockImplementation(async (_userId: string, _bucket: string, paths: string[]) => new Map(paths.map((path) => [path, `signed:${path}`])));
    mocks.cached.mockReset();
  });

  it("normal avatar loading signs only the active photo and editor loading resolves the full library", async () => {
    await loadRemoteProfileAvatarSummary("user-a");
    expect(mocks.resolve).toHaveBeenLastCalledWith("user-a", "profile-media", ["avatar-active.webp"]);
    await loadRemoteProfileAvatarLibrary("user-a");
    expect(mocks.resolve).toHaveBeenLastCalledWith("user-a", "profile-media", ["avatar-active.webp", "avatar-inactive.webp"]);
  });

  it("normal visual loading signs only active roles and editor loading resolves inactive thumbnails", async () => {
    await loadRemoteProfileVisualSummary("user-a");
    expect(mocks.resolve).toHaveBeenLastCalledWith("user-a", "profile-media", ["mobile-active.webp", "wide-active.webp"]);
    await loadRemoteProfileVisualLibrary("user-a");
    expect(mocks.resolve).toHaveBeenLastCalledWith("user-a", "profile-media", ["mobile-active.webp", "mobile-inactive.webp", "wide-active.webp", "wide-inactive.webp"]);
  });

  it("prototype bootstrap loading reads and signs active visuals without loading the saved library", async () => {
    const records = await loadRemoteProfileVisuals("user-a");
    expect(records.map((record) => record.displayPath)).toEqual(["mobile-active.webp", "wide-active.webp"]);
    expect(mocks.resolve).toHaveBeenLastCalledWith("user-a", "profile-media", ["mobile-active.webp", "wide-active.webp"]);
  });
});
