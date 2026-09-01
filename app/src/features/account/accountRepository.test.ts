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

import { loadOwnedProfile, saveOwnedProfile } from "./accountRepository";

describe("profile privacy account repository", () => {
  beforeEach(() => {
    mocks.clearSignedUrls.mockReset();
    mocks.rows.clear();
    mocks.singleRows.clear();
    mocks.from.mockReset().mockImplementation((table: string) => queryFor(table));
    mocks.rpc.mockReset();
  });

  it("loads canonical owner visibility and treats legacy-shaped responses conservatively", async () => {
    mocks.singleRows.set("profiles", { display_name: "Owner", handle: "@owner", fanatical_name: "Legacy duplicate", tagline: "", featured_fan_photo_category: "Fan Cave", visibility: "private" });
    mocks.singleRows.set("fan_identities", {});
    mocks.rows.set("sports_played", []);
    const loaded = await loadOwnedProfile("user-a");
    expect(loaded).toMatchObject({ id: "user-a", visibility: "private" });
    expect(loaded?.bio.some((field) => field.id === "fanatical-name")).toBe(false);

    mocks.singleRows.set("profiles", { display_name: "Owner", handle: "@owner", tagline: "", featured_fan_photo_category: "Fan Cave" });
    await expect(loadOwnedProfile("user-a")).resolves.toMatchObject({ visibility: "private" });
  });

  it("persists Members-visible and Private through the profile RPC and clears signed media only when visibility changes", async () => {
    mocks.rpc.mockResolvedValue({ data: null, error: null });
    const privateProfile = { ...initialProfile, id: "user-a", visibility: "private" as const };
    await saveOwnedProfile("user-a", privateProfile, "members_visible");
    expect(mocks.rpc).toHaveBeenLastCalledWith("save_my_profile", expect.objectContaining({
      profile_data: expect.objectContaining({ visibility: "private" }),
    }));
    expect(mocks.rpc.mock.calls.at(-1)?.[1].profile_data).not.toHaveProperty("fanatical_name");
    expect(mocks.clearSignedUrls).toHaveBeenCalledWith("user-a");

    mocks.clearSignedUrls.mockReset();
    const membersProfile = { ...privateProfile, visibility: "members_visible" as const };
    await saveOwnedProfile("user-a", membersProfile, "private");
    expect(mocks.rpc).toHaveBeenLastCalledWith("save_my_profile", expect.objectContaining({
      profile_data: expect.objectContaining({ visibility: "members_visible" }),
    }));
    expect(mocks.clearSignedUrls).toHaveBeenCalledWith("user-a");

    mocks.clearSignedUrls.mockReset();
    await saveOwnedProfile("user-a", membersProfile, "members_visible");
    expect(mocks.clearSignedUrls).not.toHaveBeenCalled();
  });

});
