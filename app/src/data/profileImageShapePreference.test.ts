import { describe, expect, it } from "vitest";
import { loadProfileImageShape, profileImageShapeStorageKey, saveProfileImageShape } from "./profileImageShapePreference";

describe("profile image shape preference", () => {
  it("defaults to circle and persists an explicit shape", () => {
    expect(loadProfileImageShape()).toBe("circle");
    saveProfileImageShape("square");
    expect(window.localStorage.getItem(profileImageShapeStorageKey)).toBe("square");
    expect(loadProfileImageShape()).toBe("square");
  });

  it("falls back to circle for an unsupported stored value", () => {
    window.localStorage.setItem(profileImageShapeStorageKey, "triangle");
    expect(loadProfileImageShape()).toBe("circle");
  });
});
