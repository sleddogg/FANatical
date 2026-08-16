import { describe, expect, it } from "vitest";
import { loadNavigationSide, navigationSideStorageKey, saveNavigationSide } from "./navigationSidePreference";

describe("navigation side preference", () => {
  it("defaults left and persists an explicit side", () => {
    expect(loadNavigationSide()).toBe("left");
    saveNavigationSide("right");
    expect(window.localStorage.getItem(navigationSideStorageKey)).toBe("right");
    expect(loadNavigationSide()).toBe("right");
  });
});
