import { describe, expect, it } from "vitest";
import { formatStaffRole, parseStaffAccess } from "./adminAccess";

describe("admin access records", () => {
  it("accepts an active backend staff assignment", () => {
    expect(parseStaffAccess({
      user_id: "user-1",
      role: "venue_admin",
      permissions: ["venues.manage"],
      is_active: true,
    })).toEqual({
      userId: "user-1",
      role: "venue_admin",
      permissions: ["venues.manage"],
    });
  });

  it("rejects inactive, malformed, and unknown assignments", () => {
    expect(parseStaffAccess({ user_id: "user-1", role: "admin", permissions: [], is_active: false })).toBeNull();
    expect(parseStaffAccess({ user_id: "user-1", role: "owner", permissions: [], is_active: true })).toBeNull();
    expect(parseStaffAccess({ user_id: "user-1", role: "admin", permissions: "all", is_active: true })).toBeNull();
  });

  it("formats staff roles for display", () => {
    expect(formatStaffRole("content_admin")).toBe("Content Admin");
  });
});
