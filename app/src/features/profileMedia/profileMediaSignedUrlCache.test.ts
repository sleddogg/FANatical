import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  createSignedUrl: vi.fn(),
  createSignedUrls: vi.fn(),
}));

vi.mock("../../lib/supabase/client", () => ({
  requireSupabase: () => ({
    storage: { from: () => ({ createSignedUrl: mocks.createSignedUrl, createSignedUrls: mocks.createSignedUrls }) },
  }),
}));

import {
  cachedProfileMediaSignedUrl,
  clearProfileMediaSignedUrls,
  profileMediaBucket,
  resetProfileMediaSignedUrlCacheForTests,
  resolveProfileMediaSignedUrl,
  resolveProfileMediaSignedUrls,
} from "./profileMediaSignedUrlCache";

describe("profile media signed URL cache", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-08-22T12:00:00Z"));
    resetProfileMediaSignedUrlCacheForTests();
    mocks.createSignedUrl.mockReset().mockImplementation(async (path: string) => ({ data: { signedUrl: `signed:${path}:${mocks.createSignedUrl.mock.calls.length}` }, error: null }));
    mocks.createSignedUrls.mockReset().mockImplementation(async (paths: string[]) => ({
      data: paths.map((path) => ({ path, signedUrl: `signed:${path}:batch-${mocks.createSignedUrls.mock.calls.length}`, signedURL: "", error: null })),
      error: null,
    }));
  });

  afterEach(() => vi.useRealTimers());

  it("reuses unchanged paths until the five-minute expiry safety window", async () => {
    const first = await resolveProfileMediaSignedUrl("user-a", profileMediaBucket, "user-a/avatar.webp");
    vi.advanceTimersByTime(54 * 60 * 1000);
    const cached = await resolveProfileMediaSignedUrl("user-a", profileMediaBucket, "user-a/avatar.webp");
    vi.advanceTimersByTime(2 * 60 * 1000);
    const refreshed = await resolveProfileMediaSignedUrl("user-a", profileMediaBucket, "user-a/avatar.webp");

    expect(cached).toBe(first);
    expect(refreshed).not.toBe(first);
    expect(mocks.createSignedUrl).toHaveBeenCalledTimes(2);
  });

  it("deduplicates concurrent signing for the same user and path", async () => {
    let release!: () => void;
    mocks.createSignedUrl.mockImplementationOnce(async (path: string) => {
      await new Promise<void>((resolve) => { release = resolve; });
      return { data: { signedUrl: `signed:${path}` }, error: null };
    });
    const first = resolveProfileMediaSignedUrl("user-a", profileMediaBucket, "user-a/avatar.webp");
    const second = resolveProfileMediaSignedUrl("user-a", profileMediaBucket, "user-a/avatar.webp");
    await vi.waitFor(() => expect(mocks.createSignedUrl).toHaveBeenCalledOnce());
    release();

    await expect(Promise.all([first, second])).resolves.toEqual(["signed:user-a/avatar.webp", "signed:user-a/avatar.webp"]);
    expect(mocks.createSignedUrl).toHaveBeenCalledOnce();
  });

  it("batches only missing paths and leaves cached paths unchanged", async () => {
    await resolveProfileMediaSignedUrl("user-a", profileMediaBucket, "active.webp");
    const urls = await resolveProfileMediaSignedUrls("user-a", profileMediaBucket, ["active.webp", "inactive-a.webp", "inactive-b.webp"]);

    expect(mocks.createSignedUrl).toHaveBeenCalledOnce();
    expect(mocks.createSignedUrls).toHaveBeenCalledWith(["inactive-a.webp", "inactive-b.webp"], 3600);
    expect(urls.get("active.webp")).toBe("signed:active.webp:1");
  });

  it("signs only a changed display path during repeated metadata refreshes", async () => {
    await resolveProfileMediaSignedUrl("user-a", profileMediaBucket, "old.webp");
    await resolveProfileMediaSignedUrl("user-a", profileMediaBucket, "old.webp");
    await resolveProfileMediaSignedUrl("user-a", profileMediaBucket, "new.webp");
    expect(mocks.createSignedUrl).toHaveBeenCalledTimes(2);
  });

  it("keeps accounts isolated and clears one user's cached URLs on identity change", async () => {
    await resolveProfileMediaSignedUrl("user-a", profileMediaBucket, "shared-looking-path.webp");
    await resolveProfileMediaSignedUrl("user-b", profileMediaBucket, "shared-looking-path.webp");
    expect(mocks.createSignedUrl).toHaveBeenCalledTimes(2);

    clearProfileMediaSignedUrls("user-a");
    expect(cachedProfileMediaSignedUrl("user-a", profileMediaBucket, "shared-looking-path.webp")).toBeUndefined();
    expect(cachedProfileMediaSignedUrl("user-b", profileMediaBucket, "shared-looking-path.webp")).toBeDefined();
    await resolveProfileMediaSignedUrl("user-a", profileMediaBucket, "shared-looking-path.webp");
    expect(mocks.createSignedUrl).toHaveBeenCalledTimes(3);
  });

  it("retains the shared cache across a module reload such as HMR", async () => {
    const firstModule = await import("./profileMediaSignedUrlCache");
    await firstModule.resolveProfileMediaSignedUrl("user-a", profileMediaBucket, "hmr.webp");
    vi.resetModules();
    const refreshedModule = await import("./profileMediaSignedUrlCache");
    await refreshedModule.resolveProfileMediaSignedUrl("user-a", profileMediaBucket, "hmr.webp");
    expect(mocks.createSignedUrl).toHaveBeenCalledOnce();
  });
});
