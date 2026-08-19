import { describe, expect, it } from "vitest";
import { clampProfileAvatarCrop, panProfileAvatarCrop, pinchProfileAvatarCrop } from "./types";

describe("profile avatar positioning", () => {
  it("supports desktop drag positioning without leaving valid crop bounds", () => {
    expect(panProfileAvatarCrop({ focalX: 0.5, focalY: 0.5, zoom: 2 }, 60, -30, 300, 300)).toEqual({
      focalX: 0.4,
      focalY: 0.55,
      zoom: 2,
    });
    expect(panProfileAvatarCrop({ focalX: 0.05, focalY: 0.95, zoom: 1 }, 100, -100, 100, 100)).toEqual({
      focalX: 0,
      focalY: 1,
      zoom: 1,
    });
  });

  it("supports mobile pinch zoom and midpoint movement", () => {
    expect(pinchProfileAvatarCrop({ focalX: 0.5, focalY: 0.5, zoom: 1.5 }, 1.5, 20, -10, 200, 200)).toEqual({
      focalX: expect.closeTo(0.4333, 3),
      focalY: expect.closeTo(0.5333, 3),
      zoom: 2.25,
    });
  });

  it("clamps slider and pinch zoom to the supported range", () => {
    expect(clampProfileAvatarCrop({ focalX: 0.5, focalY: 0.5, zoom: 0.2 }).zoom).toBe(1);
    expect(clampProfileAvatarCrop({ focalX: 0.5, focalY: 0.5, zoom: 9 }).zoom).toBe(4);
  });
});
