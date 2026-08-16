import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createMemoryRouter, RouterProvider } from "react-router-dom";
import { describe, expect, it } from "vitest";
import { appRoutes } from "./routes";
import { navigationSideStorageKey } from "../data/navigationSidePreference";

function renderRoute(route = "/") {
  const router = createMemoryRouter(appRoutes, { initialEntries: [route] });
  return {
    router,
    ...render(<RouterProvider router={router} />),
  };
}

describe("FANatical application shell", () => {
  it("renders the application", () => {
    renderRoute();

    expect(screen.getByRole("heading", { name: "Your home for fandom." })).toBeInTheDocument();
    expect(screen.getByRole("navigation", { name: "Home navigation" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Select New England Patriots" })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
  });

  it("restores the navigation side preference with accessible shortcut names and tooltips", () => {
    window.localStorage.setItem(navigationSideStorageKey, "right");
    renderRoute();

    const shortcuts = screen.getByRole("navigation", { name: "Feature shortcuts" });
    expect(shortcuts).toHaveClass("home-hero__shortcuts--right");
    for (const label of ["News", "Quiz", "FANbase", "Cheer"]) {
      const link = screen.getByRole("link", { name: label });
      expect(link).toBeInTheDocument();
      expect(link.querySelector(".home-hero__shortcut-tooltip")).toHaveTextContent(label);
      expect(link.querySelector("svg")).toHaveAttribute("aria-hidden", "true");
    }
  });

  it.each([
    ["/", "Your home for fandom."],
    ["/news", "News"],
    ["/quiz", "Quiz"],
    ["/fanbase", "FANbase"],
    ["/cheer", "Cheer Library"],
    ["/cheer/launch", "Cheer Launch"],
    ["/profile", "NorthStarFan"],
    ["/profile/stats", "NorthStarFan Sports Stats"],
  ])("resolves %s", (route, heading) => {
    renderRoute(route);

    expect(screen.getByRole("heading", { name: heading })).toBeInTheDocument();
  });

  it("uses the shared navigation to move between feature routes", async () => {
    const user = userEvent.setup();
    renderRoute("/news");

    await user.click(screen.getByRole("link", { name: "Quiz" }));

    expect(screen.getByRole("heading", { name: "Quiz" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Quiz" })).toHaveAttribute("aria-current", "page");
  });

  it("marks the current feature and Profile routes as active", () => {
    const { unmount } = renderRoute("/fanbase");

    expect(screen.getByRole("link", { name: "FANbase" })).toHaveAttribute("aria-current", "page");
    expect(screen.getByRole("link", { name: "News" })).not.toHaveAttribute("aria-current");

    unmount();
    renderRoute("/profile");

    expect(screen.getByRole("link", { name: "Profile" })).toHaveAttribute("aria-current", "page");
  });

  it("provides keyboard access to the main content", async () => {
    const user = userEvent.setup();
    renderRoute("/news");

    await user.tab();

    expect(screen.getByRole("link", { name: "Skip to main content" })).toHaveFocus();
    expect(screen.getByRole("main")).toHaveAttribute("id", "main-content");
  });
});
