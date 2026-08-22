import { beforeEach, describe, expect, it, vi } from "vitest";
import { initialProfile } from "../profile/mockProfileData";

const mocks = vi.hoisted(() => ({
  clearSignedUrls: vi.fn(),
  from: vi.fn(),
  rpc: vi.fn(),
  rows: new Map<string, unknown[]>(),
  singleRows: new Map<string, unknown>(),
}));

function queryFor(table: string) {
  const query = {
    select: vi.fn(() => query),
    eq: vi.fn(() => query),
    order: vi.fn(async () => ({ data: mocks.rows.get(table) ?? [], error: null })),
    maybeSingle: vi.fn(async () => ({ data: mocks.singleRows.get(table) ?? null, error: null })),
  };
  return query;
}

vi.mock("../../lib/supabase/client", () => ({
  requireSupabase: () => ({ from: mocks.from, rpc: mocks.rpc }),
}));

vi.mock("../profileMedia/profileMediaSignedUrlCache", () => ({
  clearProfileMediaSignedUrls: mocks.clearSignedUrls,
}));

import { loadOwnedProfile, loadViewableProfile, saveOwnedProfile } from "./accountRepository";

describe("profile privacy account repository", () => {
  beforeEach(() => {
    mocks.clearSignedUrls.mockReset();
    mocks.rows.clear();
    mocks.singleRows.clear();
    mocks.from.mockReset().mockImplementation((table: string) => queryFor(table));
    mocks.rpc.mockReset();
  });

  it("loads canonical visibility for owner records and preserves public for legacy-shaped responses", async () => {
    mocks.singleRows.set("profiles", { display_name: "Owner", handle: "@owner", tagline: "", featured_fan_photo_category: "Fan Cave", visibility: "private" });
    mocks.singleRows.set("fan_identities", {});
    mocks.rows.set("sports_played", []);
    await expect(loadOwnedProfile("user-a")).resolves.toMatchObject({ id: "user-a", visibility: "private" });

    mocks.singleRows.set("profiles", { display_name: "Owner", handle: "@owner", tagline: "", featured_fan_photo_category: "Fan Cave" });
    await expect(loadOwnedProfile("user-a")).resolves.toMatchObject({ visibility: "public" });
  });

  it("persists Public and Private through the profile RPC and clears signed media only when visibility changes", async () => {
    mocks.rpc.mockResolvedValue({ data: null, error: null });
    const privateProfile = { ...initialProfile, id: "user-a", visibility: "private" as const };
    await saveOwnedProfile("user-a", privateProfile, "public");
    expect(mocks.rpc).toHaveBeenLastCalledWith("save_my_profile", expect.objectContaining({
      profile_data: expect.objectContaining({ visibility: "private" }),
    }));
    expect(mocks.clearSignedUrls).toHaveBeenCalledWith("user-a");

    mocks.clearSignedUrls.mockReset();
    const publicProfile = { ...privateProfile, visibility: "public" as const };
    await saveOwnedProfile("user-a", publicProfile, "private");
    expect(mocks.rpc).toHaveBeenLastCalledWith("save_my_profile", expect.objectContaining({
      profile_data: expect.objectContaining({ visibility: "public" }),
    }));
    expect(mocks.clearSignedUrls).toHaveBeenCalledWith("user-a");

    mocks.clearSignedUrls.mockReset();
    await saveOwnedProfile("user-a", publicProfile, "public");
    expect(mocks.clearSignedUrls).not.toHaveBeenCalled();
  });

  it("parses the safe public profile boundary without exposing source metadata", async () => {
    mocks.rpc.mockResolvedValue({
      data: {
        profile: { user_id: "user-a", display_name: "Public Fan", handle: "@public", tagline: "Hello", visibility: "public", featured_fan_photo_category: "Fan Cave" },
        fan_identity: { fan_since: "1996", primary_team: "Edmonton Oilers" },
        sports_played: [],
        avatar: { display_path: "user-a/avatar/photo-display.webp" },
        visuals: [
          { variant: "mobile", display_path: "user-a/profile-visual/mobile/mobile-display.webp" },
          { variant: "wide", display_path: "user-a/profile-visual/wide/wide-display.webp" },
        ],
      },
      error: null,
    });

    const result = await loadViewableProfile("user-a");
    expect(result).toMatchObject({
      profile: { id: "user-a", visibility: "public", displayName: "Public Fan" },
      media: {
        avatarDisplayPath: "user-a/avatar/photo-display.webp",
        visualDisplayPaths: {
          mobile: "user-a/profile-visual/mobile/mobile-display.webp",
          wide: "user-a/profile-visual/wide/wide-display.webp",
        },
      },
    });
    expect(JSON.stringify(result)).not.toContain("source");
  });

  it("returns no public profile when the database visibility boundary denies the viewer", async () => {
    mocks.rpc.mockResolvedValue({ data: null, error: null });
    await expect(loadViewableProfile("private-user")).resolves.toBeNull();
  });
});
