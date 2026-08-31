import { act, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { Session, User } from "@supabase/supabase-js";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  authCallback: undefined as ((event: string, session: unknown) => void) | undefined,
  clearClientState: vi.fn(),
  clearNewsDemoState: vi.fn(),
  getSession: vi.fn(),
  signInWithPassword: vi.fn(),
  signOut: vi.fn(),
  signUp: vi.fn(),
  unsubscribe: vi.fn(),
}));

vi.mock("../../lib/supabase/client", () => ({
  isSupabaseConfigured: true,
  supabase: {
    auth: {
      getSession: mocks.getSession,
      onAuthStateChange: (callback: (event: string, session: unknown) => void) => {
        mocks.authCallback = callback;
        return { data: { subscription: { unsubscribe: mocks.unsubscribe } } };
      },
      signInWithPassword: mocks.signInWithPassword,
      signUp: mocks.signUp,
      signOut: mocks.signOut,
    },
  },
}));

vi.mock("./accountClientState", () => ({
  clearAccountDerivedClientState: mocks.clearClientState,
}));

vi.mock("../news/newsDemoState", () => ({
  clearNewsDemoState: mocks.clearNewsDemoState,
}));

import { AuthProvider, useAuth } from "./AuthContext";

function user(id: string) {
  return { id } as User;
}

function session(authenticatedUser: User) {
  return { user: authenticatedUser } as Session;
}

function AuthProbe() {
  const { loading, user: authenticatedUser } = useAuth();
  return <output>{loading ? "loading" : authenticatedUser?.id ?? "signed-out"}</output>;
}

function AuthActions() {
  const { signIn, signOut, signUp } = useAuth();
  return <>
    <button type="button" onClick={() => { void signIn("fan@example.test", "password"); }}>Test sign in</button>
    <button type="button" onClick={() => { void signUp({ email: "new@example.test", password: "password", displayName: "New Fan" }); }}>Test register</button>
    <button type="button" onClick={() => { void signOut().catch(() => undefined); }}>Test sign out</button>
  </>;
}

describe("Auth profile-media cache isolation", () => {
  beforeEach(() => {
    mocks.authCallback = undefined;
    mocks.clearClientState.mockReset().mockResolvedValue(undefined);
    mocks.clearNewsDemoState.mockReset();
    mocks.getSession.mockReset().mockResolvedValue({ data: { session: session(user("user-a")) }, error: null });
    mocks.signInWithPassword.mockReset().mockResolvedValue({ data: { session: session(user("user-a")) }, error: null });
    mocks.signUp.mockReset().mockResolvedValue({ data: { session: null }, error: null });
    mocks.signOut.mockReset().mockResolvedValue({ error: null });
    mocks.unsubscribe.mockReset();
  });

  it("runs one central cleanup on initial resolution, identity changes, expiry, and not same-user refreshes", async () => {
    render(<AuthProvider><AuthProbe /></AuthProvider>);
    await waitFor(() => expect(screen.getByText("user-a")).toBeInTheDocument());
    expect(mocks.clearClientState).toHaveBeenCalledTimes(1);

    await act(async () => { mocks.authCallback?.("TOKEN_REFRESHED", session(user("user-a"))); });
    expect(screen.getByText("user-a")).toBeInTheDocument();
    expect(mocks.clearClientState).toHaveBeenCalledTimes(1);

    await act(async () => { mocks.authCallback?.("SIGNED_IN", session(user("user-b"))); });
    expect(screen.getByText("user-b")).toBeInTheDocument();
    expect(mocks.clearClientState).toHaveBeenCalledTimes(2);

    await act(async () => { mocks.authCallback?.("SIGNED_OUT", null); });
    expect(screen.getByText("signed-out")).toBeInTheDocument();
    expect(mocks.clearClientState).toHaveBeenCalledTimes(3);
  });

  it("keeps presentation neutral until transition cleanup finishes", async () => {
    let releaseCleanup!: () => void;
    mocks.clearClientState.mockReturnValue(new Promise<void>((resolve) => { releaseCleanup = resolve; }));

    render(<AuthProvider><AuthProbe /></AuthProvider>);
    await waitFor(() => expect(screen.getByText("loading")).toBeInTheDocument());
    expect(screen.queryByText("user-a")).not.toBeInTheDocument();

    await act(async () => releaseCleanup());
    await waitFor(() => expect(screen.getByText("user-a")).toBeInTheDocument());
  });

  it("restores the current user when explicit local sign-out fails", async () => {
    mocks.signOut.mockResolvedValue({ error: new Error("sign-out failed") });
    const interaction = userEvent.setup();
    render(<AuthProvider><AuthProbe /><AuthActions /></AuthProvider>);
    await waitFor(() => expect(screen.getByText("user-a")).toBeInTheDocument());
    mocks.clearClientState.mockClear();

    await interaction.click(screen.getByRole("button", { name: "Test sign out" }));
    await waitFor(() => expect(screen.getByText("user-a")).toBeInTheDocument());
    expect(mocks.clearClientState).not.toHaveBeenCalled();
  });

  it("discards memory-only News Demo choices during sign-in and registration", async () => {
    const userInteraction = userEvent.setup();
    render(<AuthProvider><AuthActions /></AuthProvider>);
    await waitFor(() => expect(mocks.getSession).toHaveBeenCalled());
    mocks.clearNewsDemoState.mockClear();

    await userInteraction.click(screen.getByRole("button", { name: "Test sign in" }));
    await waitFor(() => expect(mocks.signInWithPassword).toHaveBeenCalled());
    expect(mocks.clearNewsDemoState).toHaveBeenCalledTimes(1);

    await userInteraction.click(screen.getByRole("button", { name: "Test register" }));
    await waitFor(() => expect(mocks.signUp).toHaveBeenCalled());
    expect(mocks.clearNewsDemoState).toHaveBeenCalledTimes(2);
  });
});
