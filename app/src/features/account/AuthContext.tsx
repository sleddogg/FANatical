import { createContext, useCallback, useContext, useEffect, useMemo, useState, type PropsWithChildren } from "react";
import type { User } from "@supabase/supabase-js";
import { isSupabaseConfigured, supabase } from "../../lib/supabase/client";

type SignUpInput = Readonly<{
  email: string;
  password: string;
  displayName: string;
}>;

type AuthContextValue = Readonly<{
  configured: boolean;
  loading: boolean;
  user: User | null;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (input: SignUpInput) => Promise<"signed-in" | "confirmation-required">;
  signOut: () => Promise<void>;
}>;

const unavailableAuth: AuthContextValue = {
  configured: false,
  loading: false,
  user: null,
  signIn: async () => { throw new Error("FANatical's hosted account service is not configured."); },
  signUp: async () => { throw new Error("FANatical's hosted account service is not configured."); },
  signOut: async () => undefined,
};

const AuthContext = createContext<AuthContextValue>(unavailableAuth);

export function AuthProvider({ children }: PropsWithChildren) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(isSupabaseConfigured);

  useEffect(() => {
    if (!supabase) return;
    let current = true;
    void supabase.auth.getSession().then(({ data, error }) => {
      if (!current) return;
      if (error) console.error("FANatical could not restore the account session.", error);
      setUser(data.session?.user ?? null);
      setLoading(false);
    });
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
      setLoading(false);
    });
    return () => {
      current = false;
      data.subscription.unsubscribe();
    };
  }, []);

  const signIn = useCallback(async (email: string, password: string) => {
    if (!supabase) throw new Error("FANatical's hosted account service is not configured.");
    const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
    if (error) throw error;
  }, []);

  const signUp = useCallback(async ({ email, password, displayName }: SignUpInput) => {
    if (!supabase) throw new Error("FANatical's hosted account service is not configured.");
    const { data, error } = await supabase.auth.signUp({
      email: email.trim(),
      password,
      options: {
        data: { display_name: displayName.trim() },
        emailRedirectTo: new URL("/profile", window.location.origin).toString(),
      },
    });
    if (error) throw error;
    return data.session ? "signed-in" : "confirmation-required";
  }, []);

  const signOut = useCallback(async () => {
    if (!supabase) return;
    const { error } = await supabase.auth.signOut({ scope: "local" });
    if (error) throw error;
  }, []);

  const value = useMemo<AuthContextValue>(() => ({ configured: isSupabaseConfigured, loading, user, signIn, signUp, signOut }), [loading, signIn, signOut, signUp, user]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  return useContext(AuthContext);
}
