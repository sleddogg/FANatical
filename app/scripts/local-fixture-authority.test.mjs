import { describe, expect, it } from "vitest";
import { withTemporaryFixtureAuthority } from "./local-fixture-authority.mjs";

function lifecycle({
  staleAuthority = false,
  grantFailure = false,
  provisionFailure = false,
  signOutFailure = false,
  laterCleanupFailure = false,
} = {}) {
  let hasAuthority = staleAuthority;
  const events = [];
  const run = () => withTemporaryFixtureAuthority({
    removeAuthority: async (phase) => {
      events.push(`remove:${phase}`);
      hasAuthority = false;
    },
    grantAuthority: async () => {
      events.push("grant");
      hasAuthority = true;
      if (grantFailure) throw new Error("grant failed after write");
    },
    provision: async () => {
      events.push("provision");
      expect(hasAuthority).toBe(true);
      if (provisionFailure) throw new Error("provision failed");
      return "provisioned";
    },
    cleanupOperations: [
      async () => {
        events.push("sign-out");
        if (signOutFailure) throw new Error("sign-out failed");
      },
      async () => {
        events.push("later-cleanup");
        if (laterCleanupFailure) throw new Error("later cleanup failed");
      },
    ],
  });
  return {
    run,
    events,
    hasAuthority: () => hasAuthority,
  };
}

describe("temporary local fixture authority", () => {
  it("removes stale authority before provisioning and leaves none afterward", async () => {
    const fixture = lifecycle({ staleAuthority: true });

    await expect(fixture.run()).resolves.toBe("provisioned");

    expect(fixture.events).toEqual([
      "remove:stale",
      "grant",
      "provision",
      "sign-out",
      "later-cleanup",
      "remove:final",
    ]);
    expect(fixture.hasAuthority()).toBe(false);
  });

  it("leaves zero authority after successful provisioning", async () => {
    const fixture = lifecycle();

    await expect(fixture.run()).resolves.toBe("provisioned");

    expect(fixture.hasAuthority()).toBe(false);
  });

  it("leaves zero authority after failed provisioning", async () => {
    const fixture = lifecycle({ provisionFailure: true });

    await expect(fixture.run()).rejects.toThrow("provision failed");

    expect(fixture.hasAuthority()).toBe(false);
    expect(fixture.events.at(-1)).toBe("remove:final");
  });

  it("removes authority even when Auth sign-out fails", async () => {
    const fixture = lifecycle({ signOutFailure: true });

    await expect(fixture.run()).rejects.toThrow("sign-out failed");

    expect(fixture.events).toContain("later-cleanup");
    expect(fixture.events.at(-1)).toBe("remove:final");
    expect(fixture.hasAuthority()).toBe(false);
  });

  it("removes authority even when a later cleanup operation fails", async () => {
    const fixture = lifecycle({ laterCleanupFailure: true });

    await expect(fixture.run()).rejects.toThrow("later cleanup failed");

    expect(fixture.events.at(-1)).toBe("remove:final");
    expect(fixture.hasAuthority()).toBe(false);
  });

  it("removes authority when granting fails after creating the temporary role", async () => {
    const fixture = lifecycle({ grantFailure: true });

    await expect(fixture.run()).rejects.toThrow("grant failed after write");

    expect(fixture.events).not.toContain("provision");
    expect(fixture.events.at(-1)).toBe("remove:final");
    expect(fixture.hasAuthority()).toBe(false);
  });
});
