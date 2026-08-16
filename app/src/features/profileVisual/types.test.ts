import { describe, expect, it } from "vitest";
import { clampProfileVisualCrop, defaultProfileVisualCrop } from "./types";

describe("profile visual crop data", () => {
  it("uses a centered minimum-cover crop by default", () => {
    expect(defaultProfileVisualCrop).toEqual({ focalX: 0.5, focalY: 0.5, zoom: 1 });
  });

  it("clamps normalized position and zoom to valid rendering bounds", () => {
    expect(clampProfileVisualCrop({ focalX: -0.2, focalY: 1.4, zoom: 4 })).toEqual({
      focalX: 0,
      focalY: 1,
      zoom: 3,
    });
  });
});
