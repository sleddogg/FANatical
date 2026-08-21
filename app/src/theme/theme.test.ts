import { describe, expect, it } from "vitest";
import type { TeamColors } from "../data/officialSportsDatabase";
import {
  buildThemeColorScale,
  defaultThemePreference,
  deriveThemeColor,
  normalizeThemePreference,
  readableForeground,
  resolveTheme,
  themeCssProperties,
} from "./theme";

const oilersColors: TeamColors = {
  primary: "#00205B",
  secondary: "#D14520",
  tertiary: "#FFFFFF",
  quaternary: null,
  quinary: null,
};

describe("app theme", () => {
  it("normalizes durable settings and invalid custom colors", () => {
    expect(normalizeThemePreference({ source: "custom", order: "swapped", customColor1: "#abcdef", customColor2: "invalid" })).toEqual({
      source: "custom",
      order: "swapped",
      customColor1: "#ABCDEF",
      customColor2: defaultThemePreference.customColor2,
    });
  });

  it("builds perceptual Oilers variants at the shared strengths", () => {
    expect(buildThemeColorScale("#00205B")).toEqual({
      15: "#355182",
      40: "#1A396E",
      80: "#072860",
      100: "#00205B",
    });
  });

  it("uses the same four-level derivation for custom colors", () => {
    expect(buildThemeColorScale("#D14520")).toEqual({
      15: "#D86C51",
      40: "#D45A3C",
      80: "#D14D2C",
      100: "#D14520",
    });
    expect(Object.keys(buildThemeColorScale("#D14520"))).toEqual(["15", "40", "80", "100"]);
    expect(deriveThemeColor("#D14520", 100)).toBe("#D14520");
  });

  it("resolves Favorite Team and applies swapping before pages consume colors", () => {
    const resolved = resolveTheme(
      { ...defaultThemePreference, source: "favorite-team", order: "swapped" },
      oilersColors,
      null,
      "Edmonton Oilers",
    );
    expect(resolved).toMatchObject({
      active: true,
      source: "favorite-team",
      sourceLabel: "Edmonton Oilers",
      color1: "#D14520",
      color2: "#00205B",
    });
    expect(themeCssProperties(resolved)["--theme-color-1-100"]).toBe("#D14520");
    expect(themeCssProperties(resolved)["--theme-color-2-100"]).toBe("#00205B");
  });

  it("falls back to FANatical neutral colors when a team palette is unavailable", () => {
    const resolved = resolveTheme({ ...defaultThemePreference, source: "current-team" }, null, null, "Favorite", "Unknown Team");
    expect(resolved.active).toBe(false);
    expect(resolved.unavailableReason).toContain("Unknown Team");
    expect(resolved.color1).toBe("#111111");
    expect(resolved.color1Scale).toEqual({ 15: "#414141", 40: "#282828", 80: "#181818", 100: "#111111" });
    expect(resolved.color2Scale).toEqual({ 15: "#828280", 40: "#757572", 80: "#6C6C69", 100: "#686865" });
    expect(resolved.color2Foreground).toEqual({ 15: "#111111", 40: "#FFFFFF", 80: "#FFFFFF", 100: "#FFFFFF" });
  });

  it("chooses a readable foreground for pale and dark surfaces", () => {
    expect(readableForeground("#F2F4F7")).toBe("#111111");
    expect(readableForeground("#00205B")).toBe("#FFFFFF");
  });
});
