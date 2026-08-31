import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type PropsWithChildren } from "react";
import type { User } from "@supabase/supabase-js";
import { isSupabaseConfigured, supabase } from "../../lib/supabase/client";
import { clearNewsDemoState } from "../news/newsDemoState";
import { clearAccountDerivedClientState } from "./accountClientState";

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
  signIn: async () => { throw new Error("FANatical's account service is not configured."); },
  signUp: async () => { throw new Error("FANatical's account service is not configured."); },
  signOut: async () => undefined,
};

const AuthContext = createContext<AuthContextValue>(unavailableAuth);

export function AuthProvider({ children }: PropsWithChildren) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(isSupabaseConfigured);
  const authenticatedUserId = useRef<string | null>(null);
  const authenticatedUser = useRef<User | null>(null);
  const transitionSequence = useRef(0);
  const transitionTarget = useRef<string | null | undefined>(undefined);
  const transitionPromise = useRef<Promise<void> | null>(null);

  const transitionToUser = useCallback((nextUser: User | null) => {
    const nextUserId = nextUser?.id ?? null;
    if (transitionPromise.current && transitionTarget.current === nextUserId) return transitionPromise.current;
    if (transitionTarget.current !== undefined && authenticatedUserId.current === nextUserId) {
      authenticatedUser.current = nextUser;
      setUser(nextUser);
      setLoading(false);
      return Promise.resolve();
    }

    const sequence = ++transitionSequence.current;
    transitionTarget.current = nextUserId;
    setUser(null);
    setLoading(true);
    const pending = clearAccountDerivedClientState().then(() => {
      if (transitionSequence.current !== sequence) return;
      authenticatedUserId.current = nextUserId;
      authenticatedUser.current = nextUser;
      setUser(nextUser);
      setLoading(false);
    }).finally(() => {
      if (transitionSequence.current === sequence) transitionPromise.current = null;
    });
    transitionPromise.current = pending;
    return pending;
  }, []);

  useEffect(() => {
    if (!supabase) return;
    let current = true;
    void supabase.auth.getSession().then(({ data, error }) => {
      if (!current) return;
      if (error) console.error("FANatical could not restore the account session.", error);
      void transitionToUser(data.session?.user ?? null);
    });
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      void transitionToUser(session?.user ?? null);
    });
    return () => {
      current = false;
      data.subscription.unsubscribe();
    };
  }, [transitionToUser]);

  const signIn = useCallback(async (email: string, password: string) => {
    if (!supabase) throw new Error("FANatical's account service is not configured.");
    clearNewsDemoState();
    const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
    if (error) throw error;
  }, []);

  const signUp = useCallback(async ({ email, password, displayName }: SignUpInput) => {
    if (!supabase) throw new Error("FANatical's account service is not configured.");
    clearNewsDemoState();
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
    const userBeforeRequest = authenticatedUser.current;
    setUser(null);
    setLoading(true);
    const { error } = await supabase.auth.signOut({ scope: "local" });
    if (error) {
      setUser(userBeforeRequest);
      setLoading(false);
      throw error;
    }
    await transitionToUser(null);
  }, [transitionToUser]);

  const value = useMemo<AuthContextValue>(() => ({ configured: isSupabaseConfigured, loading, user, signIn, signUp, signOut }), [loading, signIn, signOut, signUp, user]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  return useContext(AuthContext);
}
