const loopbackHostnames = new Set(["127.0.0.1", "[::1]"]);
const supportedProtocols = new Set(["http:", "https:"]);

export const loopbackTargetError = "Refusing to provision acceptance fixtures outside loopback-only local Supabase.";

export function requireLoopbackSupabaseApiUrl(value) {
  if (typeof value !== "string" || value.trim() === "") throw new Error(loopbackTargetError);

  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error(loopbackTargetError);
  }

  if (
    !supportedProtocols.has(url.protocol)
    || !loopbackHostnames.has(url.hostname)
    || url.username !== ""
    || url.password !== ""
  ) {
    throw new Error(loopbackTargetError);
  }

  return url.toString();
}
