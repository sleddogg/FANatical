import { act, render, screen, waitFor } from "@testing-library/react";
import type { Session, User } from "@supabase/supabase-js";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  authCallback: undefined as ((event: string, session: unknown) => void) | undefined,
  clearSignedUrls: vi.fn(),
  getSession: vi.fn(),
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
      signInWithPassword: vi.fn(),
      signUp: vi.fn(),
      signOut: vi.fn(),
    },
  },
}));

vi.mock("../profileMedia/profileMediaSignedUrlCache", () => ({
  clearProfileMediaSignedUrls: mocks.clearSignedUrls,
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

describe("Auth profile-media cache isolation", () => {
  beforeEach(() => {
    mocks.authCallback = undefined;
    mocks.clearSignedUrls.mockReset();
    mocks.getSession.mockReset().mockResolvedValue({ data: { session: session(user("user-a")) }, error: null });
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
});
