import { afterEach, describe, expect, it, vi } from "vitest";
import { createUuid } from "./uuid";

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("createUuid", () => {
  it("uses crypto.randomUUID when the browser provides it", () => {
    const expected = "123e4567-e89b-42d3-a456-426614174000";
    const randomUUID = vi.fn(() => expected);
    const getRandomValues = vi.fn();
    vi.stubGlobal("crypto", { randomUUID, getRandomValues });

    expect(createUuid()).toBe(expected);
    expect(randomUUID).toHaveBeenCalledOnce();
    expect(getRandomValues).not.toHaveBeenCalled();
  });

  it("creates an RFC 4122 version-4 UUID with getRandomValues when randomUUID is unavailable", () => {
    const getRandomValues = vi.fn((bytes: Uint8Array) => {
      bytes.forEach((_, index) => { bytes[index] = index; });
      return bytes;
    });
    vi.stubGlobal("crypto", { getRandomValues });

    const uuid = createUuid();

    expect(uuid).toBe("00010203-0405-4607-8809-0a0b0c0d0e0f");
    expect(uuid).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    expect(getRandomValues).toHaveBeenCalledOnce();
  });
});
