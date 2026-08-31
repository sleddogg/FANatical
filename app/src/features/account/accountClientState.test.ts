import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  clearNewsDemoState: vi.fn(),
  clearProfileMediaSignedUrls: vi.fn(),
  clearProfileVisualStorage: vi.fn(),
}));

vi.mock("../news/newsDemoState", () => ({ clearNewsDemoState: mocks.clearNewsDemoState }));
vi.mock("../profileMedia/profileMediaSignedUrlCache", () => ({ clearProfileMediaSignedUrls: mocks.clearProfileMediaSignedUrls }));
vi.mock("../profileVisual/profileVisualStorage", () => ({ clearProfileVisualStorage: mocks.clearProfileVisualStorage }));

import {
  accountClientStateClearedEvent,
  accountDerivedLocalStorageKeys,
  accountDerivedSessionStorageKeys,
  clearAccountDerivedClientState,
} from "./accountClientState";

describe("account client-state transition boundary", () => {
  beforeEach(() => {
    mocks.clearNewsDemoState.mockReset();
    mocks.clearProfileMediaSignedUrls.mockReset();
    mocks.clearProfileVisualStorage.mockReset().mockResolvedValue(undefined);
    window.sessionStorage.clear();
  });

  it("clears every account-derived browser and memory source while preserving unrelated device preferences", async () => {
    for (const key of accountDerivedLocalStorageKeys) window.localStorage.setItem(key, "account-a");
    for (const key of accountDerivedSessionStorageKeys) window.sessionStorage.setItem(key, "account-a");
    window.localStorage.setItem("fanatical.cheer.teaching-dismissed", "true");
    window.localStorage.setItem("fanatical.fanbase.polls", "device-data");
    const cleared = vi.fn();
    window.addEventListener(accountClientStateClearedEvent, cleared, { once: true });

    await clearAccountDerivedClientState();

    for (const key of accountDerivedLocalStorageKeys) expect(window.localStorage.getItem(key)).toBeNull();
    for (const key of accountDerivedSessionStorageKeys) expect(window.sessionStorage.getItem(key)).toBeNull();
    expect(window.localStorage.getItem("fanatical.cheer.teaching-dismissed")).toBe("true");
    expect(window.localStorage.getItem("fanatical.fanbase.polls")).toBe("device-data");
    expect(mocks.clearNewsDemoState).toHaveBeenCalledOnce();
    expect(mocks.clearProfileMediaSignedUrls).toHaveBeenCalledOnce();
    expect(mocks.clearProfileVisualStorage).toHaveBeenCalledOnce();
    expect(cleared).toHaveBeenCalledOnce();
  });

  it("still clears memory and publishes the neutral-state event when browser Storage denies removal", async () => {
    const removal = vi.spyOn(Storage.prototype, "removeItem").mockImplementation(() => { throw new DOMException("denied"); });
    const cleared = vi.fn();
    window.addEventListener(accountClientStateClearedEvent, cleared, { once: true });

    await expect(clearAccountDerivedClientState()).resolves.toBeUndefined();

    expect(mocks.clearNewsDemoState).toHaveBeenCalledOnce();
    expect(mocks.clearProfileMediaSignedUrls).toHaveBeenCalledOnce();
    expect(mocks.clearProfileVisualStorage).toHaveBeenCalledOnce();
    expect(cleared).toHaveBeenCalledOnce();
    removal.mockRestore();
  });
});
