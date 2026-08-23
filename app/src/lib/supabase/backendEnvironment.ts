export const FANATICAL_PRODUCTION_SUPABASE_HOSTNAME = "lsuceoieqgbagxxwobxu.supabase.co";

type BackendEnvironmentInput = Readonly<{
  configuredUrl?: string | undefined;
  browserOrigin?: string | undefined;
  browserHostname?: string | undefined;
  development: boolean;
  allowHostedDevelopment: boolean;
}>;

export type SupabaseBackendEnvironment = Readonly<{
  url?: string;
  kind: "local" | "hosted" | "unconfigured";
  warning?: string;
}>;

function isLocalBrowserHostname(hostname: string | undefined) {
  if (!hostname) return false;
  const normalized = hostname.replace(/^\[|\]$/g, "").toLowerCase();
  if (normalized === "localhost" || normalized === "::1" || normalized.endsWith(".local")) return true;
  if (/^127\./.test(normalized) || /^10\./.test(normalized) || /^192\.168\./.test(normalized)) return true;
  const private172 = normalized.match(/^172\.(\d{1,3})\./);
  return private172 ? Number(private172[1]) >= 16 && Number(private172[1]) <= 31 : false;
}

function resolveUrl(configuredUrl: string | undefined, browserOrigin: string | undefined) {
  const trimmed = configuredUrl?.trim();
  if (!trimmed) return undefined;
  if (trimmed.startsWith("/") && browserOrigin) return new URL(trimmed, browserOrigin).toString().replace(/\/$/, "");
  return trimmed.replace(/\/$/, "");
}

function hostnameFor(url: string | undefined) {
  if (!url) return undefined;
  try {
    return new URL(url).hostname.toLowerCase();
  } catch {
    return undefined;
  }
}

export function resolveSupabaseBackendEnvironment(input: BackendEnvironmentInput): SupabaseBackendEnvironment {
  const url = resolveUrl(input.configuredUrl, input.browserOrigin);
  if (!url) return { kind: "unconfigured" };

  const hostname = hostnameFor(url);
  const usesProduction = hostname === FANATICAL_PRODUCTION_SUPABASE_HOSTNAME;
  const localBrowserContext = input.development || isLocalBrowserHostname(input.browserHostname);

  if (usesProduction && localBrowserContext && !input.allowHostedDevelopment) {
    throw new Error(
      "Blocked localhost/LAN access to FANatical production Supabase. Use `npm run dev:hosted` only for an intentional hosted smoke test.",
    );
  }

  if (usesProduction && localBrowserContext) {
    return {
      url,
      kind: "hosted",
      warning: "WARNING: This local FANatical session is using PRODUCTION Supabase. Reads, writes, Auth, and Storage affect real hosted data and usage.",
    };
  }

  return { url, kind: hostname === FANATICAL_PRODUCTION_SUPABASE_HOSTNAME ? "hosted" : "local" };
}
