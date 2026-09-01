import { render, screen, waitFor, within } from "@testing-library/react";
import { createMemoryRouter, RouterProvider } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  authCallback: undefined as ((event: string, session: unknown) => void) | undefined,
  getSession: vi.fn(),
}));

vi.mock("../../lib/supabase/client", () => ({
  isSupabaseConfigured: true,
  supabaseBackendEnvironment: {
    kind: "hosted",
    url: "https://example.supabase.co",
    warning: null,
  },
  supabase: {
    auth: {
      getSession: mocks.getSession,
      onAuthStateChange: (callback: (event: string, session: unknown) => void) => {
        mocks.authCallback = callback;
        return { data: { subscription: { unsubscribe: vi.fn() } } };
      },
      signInWithPassword: vi.fn(),
      signUp: vi.fn(),
      signOut: vi.fn(),
    },
  },
  requireSupabase: () => { throw new Error("Anonymous presentation must not query account data."); },
}));

vi.mock("../../data/teamCatalogRepository", () => ({
  loadTeamCatalog: vi.fn().mockResolvedValue({ sports: [] }),
  findCatalogTeam: vi.fn().mockReturnValue(null),
}));

import { appRoutes } from "../../app/routes";

function renderRoute(route: string) {
  const router = createMemoryRouter(appRoutes, { initialEntries: [route] });
  return render(<RouterProvider router={router} />);
}

function seedAccountAPresentation() {
  window.localStorage.setItem("fanatical.followed-team-ids.v1", '["hockey-nhl-edmonton-oilers"]');
  window.localStorage.setItem("fanatical.selected-team-id", "hockey-nhl-edmonton-oilers");
  window.localStorage.setItem("fanatical.navigation-side.v1", "right");
  window.localStorage.setItem("fanatical.profile-image-shape.v1", "square");
  window.localStorage.setItem("fanatical.theme-preference.v1", JSON.stringify({ source: "custom", order: "normal", customColor1: "#123456", customColor2: "#654321" }));
  window.localStorage.setItem("fanatical.home-customization.v1", JSON.stringify({
    textOverlay: { enabled: true, bigText: "Account A Home", smallText: "Private overlay", position: "top-right" },
    fanCard: { enabled: true, fieldIds: ["fanatical-name", "nickname"], layout: "stack", position: "bottom-right" },
  }));
  window.sessionStorage.setItem("fanatical.profile.featuredFanPhotoCategory", "Memorabilia");
}

describe("configured anonymous account presentation", () => {
  beforeEach(() => {
    mocks.authCallback = undefined;
    mocks.getSession.mockReset().mockResolvedValue({ data: { session: null }, error: null });
    window.sessionStorage.clear();
    seedAccountAPresentation();
  });

  it("renders generic Home and removes all prototype and prior-account presentation", async () => {
    renderRoute("/");

    await waitFor(() => expect(screen.getByRole("heading", { name: "Your home for fandom." })).toBeInTheDocument());
    const home = screen.getByRole("region", { name: "FANatical Home" });
    expect(within(home).queryByText(/North Star|Alex Mercer|Sleddogg|Account A Home|Private overlay/)).not.toBeInTheDocument();
    expect(within(home).queryByLabelText("Fan Card")).not.toBeInTheDocument();
    expect(screen.getByRole("navigation", { name: "Feature shortcuts" })).toHaveClass("home-hero__shortcuts--left");
    expect(screen.getByRole("button", { name: "Select New England Patriots" })).toHaveAttribute("aria-pressed", "true");
    expect(screen.queryByRole("button", { name: "Select Edmonton Oilers" })).not.toBeInTheDocument();
    expect(document.querySelector(".application-shell")).toHaveAttribute("data-theme-active", "false");
  });

  it("renders signed-out Profile with only the existing onboarding controls", async () => {
    renderRoute("/profile");

    const profile = await screen.findByRole("main");
    await waitFor(() => expect(profile.querySelector(".profile-page--signed-out")).not.toBeNull());
    const signedOutProfile = profile.querySelector(".profile-page--signed-out") as HTMLElement;
    expect(within(signedOutProfile).getByRole("button", { name: "Sign In" })).toBeInTheDocument();
    expect(within(signedOutProfile).getByRole("button", { name: "Create Account" })).toBeInTheDocument();
    expect(signedOutProfile).toHaveTextContent(/^Sign InCreate Account$/);
    expect(signedOutProfile).not.toHaveTextContent(/NorthStarFan|North Star|Alex Mercer|Sleddogg|Fan Score|Fan Coins|Founding Fan/);
  });

  it("does not flash a persona or prior account while initial Auth is unresolved", () => {
    mocks.getSession.mockReturnValue(new Promise(() => undefined));
    const { unmount } = renderRoute("/profile");
    const main = screen.getByRole("main");
    expect(main.querySelector(".profile-page--auth-neutral")).not.toBeNull();
    expect(main).not.toHaveTextContent(/NorthStarFan|North Star|Alex Mercer|Sleddogg|Fan Score|Fan Coins/);
    expect(within(main).queryByRole("button", { name: "Sign In" })).not.toBeInTheDocument();
    unmount();
  });
});
