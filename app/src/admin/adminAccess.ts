export const staffRoles = ["admin", "staff", "venue_admin", "content_admin", "moderator"] as const;

export type StaffRole = (typeof staffRoles)[number];

export type StaffAccess = Readonly<{
  userId: string;
  role: StaffRole;
  permissions: readonly string[];
}>;

type StaffRoleRecord = Readonly<{
  user_id?: unknown;
  role?: unknown;
  permissions?: unknown;
  is_active?: unknown;
}>;

export function parseStaffAccess(record: StaffRoleRecord | null): StaffAccess | null {
  if (
    !record
    || record.is_active !== true
    || typeof record.user_id !== "string"
    || !staffRoles.includes(record.role as StaffRole)
    || !Array.isArray(record.permissions)
    || !record.permissions.every((permission) => typeof permission === "string")
  ) {
    return null;
  }

  return {
    userId: record.user_id,
    role: record.role as StaffRole,
    permissions: record.permissions,
  };
}

export function formatStaffRole(role: StaffRole) {
  return role.split("_").map((part) => `${part.charAt(0).toUpperCase()}${part.slice(1)}`).join(" ");
}
