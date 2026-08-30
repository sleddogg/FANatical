import { act, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { Session, User } from "@supabase/supabase-js";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  authCallback: undefined as ((event: string, session: unknown) => void) | undefined,
  clearSignedUrls: vi.fn(),
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

vi.mock("../profileMedia/profileMediaSignedUrlCache", () => ({
  clearProfileMediaSignedUrls: mocks.clearSignedUrls,
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
  const { signIn, signUp } = useAuth();
  return <>
    <button type="button" onClick={() => { void signIn("fan@example.test", "password"); }}>Test sign in</button>
    <button type="button" onClick={() => { void signUp({ email: "new@example.test", password: "password", displayName: "New Fan" }); }}>Test register</button>
  </>;
}

describe("Auth profile-media cache isolation", () => {
  beforeEach(() => {
    mocks.authCallback = undefined;
    mocks.clearSignedUrls.mockReset();
    mocks.clearNewsDemoState.mockReset();
    mocks.getSession.mockReset().mockResolvedValue({ data: { session: session(user("user-a")) }, error: null });
    mocks.signInWithPassword.mockReset().mockResolvedValue({ data: { session: session(user("user-a")) }, error: null });
    mocks.signUp.mockReset().mockResolvedValue({ data: { session: null }, error: null });
    mocks.signOut.mockReset().mockResolvedValue({ error: null });
    mocks.unsubscribe.mockReset();
  });

  it("keeps same-user token refreshes stable and clears the previous user's URLs on identity change or sign-out", async () => {
    render(<AuthProvider><AuthProbe /></AuthProvider>);
    await waitFor(() => expect(screen.getByText("user-a")).toBeInTheDocument());
    expect(mocks.clearSignedUrls).not.toHaveBeenCalled();

    await act(async () => { mocks.authCallback?.("TOKEN_REFRESHED", session(user("user-a"))); });
    expect(screen.getByText("user-a")).toBeInTheDocument();
    expect(mocks.clearSignedUrls).not.toHaveBeenCalled();

    await act(async () => { mocks.authCallback?.("SIGNED_IN", session(user("user-b"))); });
    expect(screen.getByText("user-b")).toBeInTheDocument();
    expect(mocks.clearSignedUrls).toHaveBeenLastCalledWith("user-a");

    await act(async () => { mocks.authCallback?.("SIGNED_OUT", null); });
    expect(screen.getByText("signed-out")).toBeInTheDocument();
    expect(mocks.clearSignedUrls).toHaveBeenLastCalledWith("user-b");
    expect(mocks.clearSignedUrls).toHaveBeenCalledTimes(2);
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
