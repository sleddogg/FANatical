/**
 * Creates RFC 4122 version-4 identifiers for application records and channels.
 *
 * This helper is deliberately not an authentication, session-token, password,
 * or credential generator. Supported browsers expose crypto.getRandomValues
 * even when an HTTP LAN origin does not expose crypto.randomUUID.
 */
export function createUuid(): string {
  const cryptoApi = globalThis.crypto;
  if (cryptoApi && typeof cryptoApi.randomUUID === "function") return cryptoApi.randomUUID();

  if (!cryptoApi || typeof cryptoApi.getRandomValues !== "function") {
    throw new Error("Secure random UUID generation is unavailable in this browser.");
  }

  const bytes = cryptoApi.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6]! & 0x0f) | 0x40;
  bytes[8] = (bytes[8]! & 0x3f) | 0x80;
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0"));

  return `${hex.slice(0, 4).join("")}-${hex.slice(4, 6).join("")}-${hex.slice(6, 8).join("")}-${hex.slice(8, 10).join("")}-${hex.slice(10).join("")}`;
}
