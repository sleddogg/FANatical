import { describe, expect, it } from "vitest";
import { loadThemePreference, saveThemePreference, themePreferenceStorageKey } from "./themePreferenceStorage";

describe("theme preference storage", () => {
  it("round-trips the complete preference", () => {
    saveThemePreference({ source: "custom", order: "swapped", customColor1: "#123456", customColor2: "#ABCDEF" });
    expect(loadThemePreference()).toEqual({ source: "custom", order: "swapped", customColor1: "#123456", customColor2: "#ABCDEF" });
  });

  it("normalizes corrupt stored values", () => {
    window.localStorage.setItem(themePreferenceStorageKey, JSON.stringify({ source: "unknown", order: "backwards", customColor1: "red" }));
    expect(loadThemePreference()).toEqual({ source: "none", order: "normal", customColor1: "#00205B", customColor2: "#D14520" });
  });
});
