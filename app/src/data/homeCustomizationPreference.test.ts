import { beforeEach, describe, expect, it } from "vitest";
import {
  defaultHomeCustomization,
  homeCustomizationStorageKey,
  loadHomeCustomization,
  normalizeHomeCustomization,
  saveHomeCustomization,
} from "./homeCustomizationPreference";

describe("Home customization preference", () => {
  beforeEach(() => window.localStorage.removeItem(homeCustomizationStorageKey));

  it("preserves the current Home copy as the default", () => {
    expect(loadHomeCustomization()).toEqual(defaultHomeCustomization);
  });

  it("normalizes character limits, field order, and invalid values", () => {
    const normalized = normalizeHomeCustomization({
      textOverlay: { enabled: true, bigText: "B".repeat(35), smallText: "S".repeat(75), position: "elsewhere" },
      fanCard: { enabled: true, fieldIds: ["nickname", "height", "nickname", "weight", "birthplace", "given-name"], layout: "stack", position: "top-right" },
    });

    expect(normalized.textOverlay.bigText).toHaveLength(30);
    expect(normalized.textOverlay.smallText).toHaveLength(70);
    expect(normalized.textOverlay.position).toBe("bottom-left");
    expect(normalized.fanCard.fieldIds).toEqual(["nickname", "height", "weight", "birthplace"]);
    expect(normalized.fanCard.layout).toBe("stack");
  });

  it("round-trips a local prototype preference", () => {
    const next = {
      ...defaultHomeCustomization,
      fanCard: { enabled: true, fieldIds: ["fanatical-name"], layout: "grid" as const, position: "top-right" as const },
    };
    saveHomeCustomization(next);
    expect(JSON.parse(window.localStorage.getItem(homeCustomizationStorageKey) ?? "null")).toEqual(next);
    expect(loadHomeCustomization()).toEqual(next);
  });
});
