import { describe, expect, it } from "vitest";
import { FANATICAL_PRODUCTION_SUPABASE_HOSTNAME, resolveSupabaseBackendEnvironment } from "./backendEnvironment";

describe("Supabase backend environment", () => {
  it("resolves the local proxy against localhost and LAN origins", () => {
    expect(resolveSupabaseBackendEnvironment({
      configuredUrl: "/supabase",
      browserOrigin: "http://localhost:5173",
      browserHostname: "localhost",
      development: true,
      allowHostedDevelopment: false,
    })).toEqual({ url: "http://localhost:5173/supabase", kind: "local" });

    expect(resolveSupabaseBackendEnvironment({
      configuredUrl: "/supabase",
      browserOrigin: "http://192.168.1.24:5173",
      browserHostname: "192.168.1.24",
      development: true,
      allowHostedDevelopment: false,
    })).toEqual({ url: "http://192.168.1.24:5173/supabase", kind: "local" });
  });

  it("blocks an accidental development connection to production", () => {
    expect(() => resolveSupabaseBackendEnvironment({
      configuredUrl: `https://${FANATICAL_PRODUCTION_SUPABASE_HOSTNAME}`,
      browserOrigin: "http://localhost:5173",
      browserHostname: "localhost",
      development: true,
      allowHostedDevelopment: false,
    })).toThrow("Blocked localhost/LAN access");
  });

  it("allows explicit hosted development with a prominent warning", () => {
    const result = resolveSupabaseBackendEnvironment({
      configuredUrl: `https://${FANATICAL_PRODUCTION_SUPABASE_HOSTNAME}`,
      browserOrigin: "http://192.168.1.24:5173",
      browserHostname: "192.168.1.24",
      development: true,
      allowHostedDevelopment: true,
    });
    expect(result.kind).toBe("hosted");
    expect(result.warning).toContain("PRODUCTION Supabase");
  });

  it("does not block the deployed production site", () => {
    expect(resolveSupabaseBackendEnvironment({
      configuredUrl: `https://${FANATICAL_PRODUCTION_SUPABASE_HOSTNAME}`,
      browserOrigin: "https://fanaticalpeople.com",
      browserHostname: "fanaticalpeople.com",
      development: false,
      allowHostedDevelopment: false,
    })).toEqual({ url: `https://${FANATICAL_PRODUCTION_SUPABASE_HOSTNAME}`, kind: "hosted" });
  });

  it("blocks a production build served from a local hostname unless opted in", () => {
    expect(() => resolveSupabaseBackendEnvironment({
      configuredUrl: `https://${FANATICAL_PRODUCTION_SUPABASE_HOSTNAME}`,
      browserOrigin: "http://127.0.0.1:4173",
      browserHostname: "127.0.0.1",
      development: false,
      allowHostedDevelopment: false,
    })).toThrow("Blocked localhost/LAN access");
  });
});
