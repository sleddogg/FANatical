import { describe, expect, it } from "vitest";
import { defaultHomeCustomization } from "../data/homeCustomizationStorage";
import {
  positionConflictsWithNavigation,
  resolveHomeOverlayPositions,
  resolveSavedHomeCustomizationPositions,
} from "./homeOverlayLayout";

const measurements = {
  container: { width: 1000, height: 700 },
  navigation: { left: 32, top: 230, width: 64, height: 240 },
  edge: 32,
  textOverlay: { width: 360, height: 150 },
  fanCard: { width: 280, height: 180 },
};

describe("Home overlay layout", () => {
  it("only treats the middle anchor on the navigation side as intrinsically unavailable", () => {
    expect(positionConflictsWithNavigation("middle-left", "left")).toBe(true);
    expect(positionConflictsWithNavigation("top-left", "left")).toBe(false);
    expect(positionConflictsWithNavigation("bottom-left", "left")).toBe(false);
  });

  it("keeps two overlays on the same side when their measured rectangles fit", () => {
    expect(resolveHomeOverlayPositions({ textOverlay: "top-left", fanCard: "bottom-left" }, measurements)).toEqual({
      textOverlay: "top-left",
      fanCard: "bottom-left",
    });
  });

  it("moves only the later overlay when measured rectangles collide", () => {
    const resolved = resolveHomeOverlayPositions({ textOverlay: "top-right", fanCard: "top-right" }, measurements);
    expect(resolved.textOverlay).toBe("top-right");
    expect(resolved.fanCard).not.toBe("top-right");
  });

  it("repairs only saved placements made invalid by a navigation-side change", () => {
    const customization = {
      ...defaultHomeCustomization,
      textOverlay: { ...defaultHomeCustomization.textOverlay, position: "middle-left" as const },
      fanCard: { enabled: true, fieldIds: ["nickname"], layout: "grid" as const, position: "bottom-left" as const },
    };
    const resolved = resolveSavedHomeCustomizationPositions(customization, "left");
    expect(resolved.textOverlay.position).not.toBe("middle-left");
    expect(resolved.fanCard.position).toBe("bottom-left");
  });
});
