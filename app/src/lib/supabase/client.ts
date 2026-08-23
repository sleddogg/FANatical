import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { resolveSupabaseBackendEnvironment } from "./backendEnvironment";

export const supabaseBackendEnvironment = resolveSupabaseBackendEnvironment({
  configuredUrl: import.meta.env.VITE_SUPABASE_URL,
  browserOrigin: typeof window === "undefined" ? undefined : window.location.origin,
  browserHostname: typeof window === "undefined" ? undefined : window.location.hostname,
  development: import.meta.env.DEV,
  allowHostedDevelopment: import.meta.env.VITE_ALLOW_HOSTED_SUPABASE_DEV === "true",
});

const supabaseUrl = supabaseBackendEnvironment.url;
const supabasePublicKey = (import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ?? import.meta.env.VITE_SUPABASE_ANON_KEY)?.trim();

if (supabaseBackendEnvironment.warning) console.error(supabaseBackendEnvironment.warning);

export const isSupabaseConfigured = Boolean(supabaseUrl && supabasePublicKey);

export const supabase: SupabaseClient | null = isSupabaseConfigured
  ? createClient(supabaseUrl!, supabasePublicKey!, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    })
  : null;

export function requireSupabase(): SupabaseClient {
  if (!supabase) throw new Error("FANatical's account service is not configured.");
  return supabase;
}
