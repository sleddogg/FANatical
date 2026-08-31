import { describe, expect, it } from "vitest";
import { loopbackTargetError, requireLoopbackSupabaseApiUrl } from "./local-supabase-safety.mjs";

describe("local acceptance provisioning target", () => {
  it.each([
    ["hosted Supabase", "https://example-project.supabase.co"],
    ["public IP", "https://203.0.113.10:54321"],
    ["LAN IP", "http://192.168.5.94:15421"],
    ["wildcard address", "http://0.0.0.0:15421"],
    ["loopback-looking suffix", "http://127.0.0.1.example.invalid:15421"],
    ["credential-host confusion", "http://127.0.0.1@supabase.example.invalid:15421"],
    ["non-loopback IPv6", "http://[2001:db8::1]:15421"],
    ["unsupported protocol", "ftp://127.0.0.1:15421"],
    ["URL credentials", "http://user:password@127.0.0.1:15421"],
    ["malformed URL", "not-a-url"],
  ])("refuses %s", (_label, target) => {
    expect(() => requireLoopbackSupabaseApiUrl(target)).toThrow(loopbackTargetError);
  });

  it.each([
    "http://127.0.0.1:15421",
    "http://[::1]:15421",
  ])("accepts the loopback API target %s", (target) => {
    expect(new URL(requireLoopbackSupabaseApiUrl(target)).hostname).toMatch(/^(127\.0\.0\.1|\[::1\])$/);
  });
});
