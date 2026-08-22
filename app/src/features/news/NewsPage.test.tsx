import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createMemoryRouter, RouterProvider } from "react-router-dom";
import { describe, expect, it } from "vitest";
import { appRoutes } from "../../app/routes";
import { followedTeamsStorageKey } from "../../data/followedTeams";
import { themePreferenceStorageKey } from "../../data/themePreferenceStorage";

function renderNews(initialEntries: string[] = ["/news"]) {
  const router = createMemoryRouter(appRoutes, { initialEntries });
  return {
    router,
    ...render(<RouterProvider router={router} />),
  };
}

describe("News frontend", () => {
  it("defaults to the app-wide selected team and renders its chronological feed", () => {
    renderNews();

    expect(screen.getByRole("heading", { level: 1, name: "News" })).toBeInTheDocument();
    expect(screen.getByText("Latest from New England Patriots")).toBeInTheDocument();
    expect(screen.queryByText(/FANatical feed/i)).not.toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Latest" })).not.toBeInTheDocument();
    expect(screen.queryByText(/always in chronological order/i)).not.toBeInTheDocument();
    expect(document.querySelector(".news-feed-heading")).not.toBeInTheDocument();
    const filter = screen.getByRole("button", { name: "Filter News. Current context: New England Patriots" });
    expect(filter.querySelector(".team-badge")).toBeInTheDocument();
    expect(within(filter).queryByText(/Patriots/i)).not.toBeInTheDocument();
    const headlines = screen.getAllByRole("heading", { level: 2 }).map((heading) => heading.textContent);
    expect(headlines).toContain("Patriots turn up the tempo as the offense enters its final camp phase");
    expect(headlines).toContain("Audio notebook: Reading the Patriots defense before the snap");
    expect(headlines).not.toContain("Celtics test two rotation ideas designed for smaller, faster lineups");
  });

  it("updates the shared selected team from the News filter", async () => {
    const user = userEvent.setup();
    renderNews();

    await user.click(screen.getByRole("button", { name: /Filter News/ }));
    await user.click(screen.getByRole("button", { name: /Selected Team/i }));
    await user.click(screen.getByRole("button", { name: /Boston Celtics/i }));

    expect(screen.getByText("Latest from Boston Celtics")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Filter News. Current context: Boston Celtics" }).querySelector(".team-badge")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Celtics test two rotation ideas designed for smaller, faster lineups" })).toBeInTheDocument();

    await user.click(screen.getByRole("link", { name: "FANatical home" }));
    expect(screen.getByRole("button", { name: "Select Boston Celtics" })).toHaveAttribute("aria-pressed", "true");
  });

  it("shows the active league code in the filter control", async () => {
    const user = userEvent.setup();
    renderNews();

    await user.click(screen.getByRole("button", { name: /Filter News/ }));
    await user.click(screen.getByRole("button", { name: /^League/i }));
    await user.click(screen.getByRole("button", { name: "NFL" }));

    expect(screen.getByText("Latest from the NFL")).toBeInTheDocument();
    const filter = screen.getByRole("button", { name: "Filter News. Current context: NFL" });
    expect(within(filter).getByText("NFL")).toBeInTheDocument();
  });

  it("applies sport and all contexts through the nested menu", async () => {
    const user = userEvent.setup();
    renderNews();

    await user.click(screen.getByRole("button", { name: /Filter News/ }));
    await user.click(screen.getByRole("button", { name: /Sport/i }));
    await user.click(screen.getByRole("button", { name: /Football/i }));
    expect(screen.getByText("Latest from Football")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Filter News. Current context: Football" }).querySelector("#mdi-football")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Three adjustments reshaping the CFL playoff race" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Podcast: What the new UFL schedule could mean for spring football" })).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /Filter News/ }));
    await user.click(screen.getByRole("button", { name: /All Followed News/i }));
    expect(screen.getByText("Latest from All Followed Sources")).toBeInTheDocument();
    expect(within(screen.getByRole("button", { name: "Filter News. Current context: All" })).getByText("All")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Red Sox map out a flexible bullpen plan for the coming series" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Celtics test two rotation ideas designed for smaller, faster lineups" })).toBeInTheDocument();
  });

  it("uses shared theme variables and keeps a relevant current-team context for broad filters", async () => {
    window.localStorage.setItem(themePreferenceStorageKey, JSON.stringify({
      source: "current-team",
      order: "normal",
      customColor1: "#00205B",
      customColor2: "#D14520",
    }));
    const user = userEvent.setup();
    renderNews();

    const page = document.querySelector(".news-page");
    expect(page).toHaveAttribute("data-news-theme-active", "true");
    expect(page?.querySelector(".news-feed-field")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /Filter News/ }));
    await user.click(screen.getByRole("button", { name: /Sport/i }));
    await user.click(screen.getByRole("button", { name: /Baseball/i }));

    expect(screen.getByText("Latest from Baseball")).toBeInTheDocument();
    await waitFor(() => expect(document.querySelector(".application-shell")).toHaveStyle({ "--theme-color-1-100": "#BD3039" }));

    await user.click(screen.getByRole("button", { name: /Filter News/ }));
    await user.click(screen.getByRole("button", { name: /All Followed News/i }));
    expect(screen.getByText("Latest from All Followed Sources")).toBeInTheDocument();
    expect(document.querySelector(".application-shell")).toHaveStyle({ "--theme-color-1-100": "#BD3039" });
  });

  it("keeps broader News neutral when Current Team has no relevant followed team", async () => {
    window.localStorage.setItem(followedTeamsStorageKey, JSON.stringify(["football-nfl-new-england-patriots"]));
    window.localStorage.setItem(themePreferenceStorageKey, JSON.stringify({
      source: "current-team",
      order: "normal",
      customColor1: "#00205B",
      customColor2: "#D14520",
    }));
    const user = userEvent.setup();
    renderNews();

    await user.click(screen.getByRole("button", { name: /Filter News/ }));
    await user.click(screen.getByRole("button", { name: /Sport/i }));
    await user.click(screen.getByRole("button", { name: /Baseball/i }));

    expect(screen.getByText("Latest from Baseball")).toBeInTheDocument();
    expect(document.querySelector(".application-shell")).toHaveAttribute("data-theme-active", "true");
    expect(document.querySelector(".news-page")).toHaveAttribute("data-news-theme-active", "false");
  });

  it("preserves shared Favorite Team, Custom, Swapped, and None theme modes", () => {
    window.localStorage.setItem(themePreferenceStorageKey, JSON.stringify({
      source: "custom",
      order: "swapped",
      customColor1: "#00205B",
      customColor2: "#D14520",
    }));
    const { unmount } = renderNews();

    expect(document.querySelector(".application-shell")).toHaveAttribute("data-theme-order", "swapped");
    expect(document.querySelector(".news-page")).toHaveAttribute("data-news-theme-active", "true");
    expect(document.querySelector(".application-shell")).toHaveStyle({
      "--theme-color-1-100": "#D14520",
      "--theme-color-2-100": "#00205B",
    });

    unmount();
    window.localStorage.setItem(themePreferenceStorageKey, JSON.stringify({
      source: "favorite-team",
      order: "normal",
      customColor1: "#00205B",
      customColor2: "#D14520",
    }));
    const favoriteRender = renderNews();
    expect(document.querySelector(".news-page")).toHaveAttribute("data-news-theme-active", "true");
    expect(document.querySelector(".application-shell")).toHaveStyle({ "--theme-color-1-100": "#002244" });

    favoriteRender.unmount();
    window.localStorage.removeItem(themePreferenceStorageKey);
    renderNews();
    expect(document.querySelector(".news-page")).toHaveAttribute("data-news-theme-active", "false");
  });

  it("contains filter keyboard focus and restores it when the dialog closes", async () => {
    const user = userEvent.setup();
    renderNews();

    const trigger = screen.getByRole("button", { name: /Filter News/ });
    await user.click(trigger);
    const dialog = screen.getByRole("dialog", { name: "Choose News context" });
    expect(dialog).toHaveFocus();

    await user.keyboard("{Shift>}{Tab}{/Shift}");
    expect(within(dialog).getByRole("button", { name: /All Followed News/i })).toHaveFocus();
    await user.tab();
    expect(within(dialog).getByRole("button", { name: "Close filters" })).toHaveFocus();

    await user.keyboard("{Escape}");
    await waitFor(() => expect(trigger).toHaveFocus());
  });

  it("exposes card actions and view counts with usable accessible names", () => {
    renderNews();
    const card = screen.getByRole("heading", { name: "Patriots turn up the tempo as the offense enters its final camp phase" }).closest("article");
    expect(card).not.toBeNull();
    const actions = within(card!).getByRole("group", { name: /Actions for Patriots turn up the tempo/i });
    expect(within(actions).getByRole("button", { name: "React" })).toHaveAttribute("aria-pressed", "false");
    expect(within(actions).getByRole("button", { name: "Open FANbase Article Discussion" })).toBeInTheDocument();
    expect(within(actions).getByRole("button", { name: "Share News item" })).toBeInTheDocument();
    expect(within(actions).getByText("3240 views")).toHaveClass("visually-hidden");
  });

  it("follows and manages mock sources in the Source Manager", async () => {
    const user = userEvent.setup();
    renderNews();

    await user.click(screen.getByRole("button", { name: /Add Feed/i }));
    const manager = screen.getByRole("dialog", { name: "Source Manager" });
    const search = within(manager).getByRole("searchbox", { name: /Search the FANatical Source Catalog/i });
    await user.type(search, "Film Room Lab");
    await user.click(within(manager).getByRole("button", { name: "Follow" }));
    expect(within(manager).getByRole("button", { name: "Following" })).toBeDisabled();

    await user.click(within(manager).getByRole("tab", { name: "Manage Sources" }));
    expect(within(manager).getByRole("heading", { name: "Film Room Lab" })).toBeInTheDocument();
  });

  it("represents source requests when the mock catalog has no match", async () => {
    const user = userEvent.setup();
    renderNews();

    await user.click(screen.getByRole("button", { name: /Add Feed/i }));
    const manager = screen.getByRole("dialog", { name: "Source Manager" });
    await user.type(within(manager).getByRole("searchbox"), "Sunday Moon Sports");
    await user.click(within(manager).getByRole("button", { name: "Request Source" }));

    expect(within(manager).getByRole("button", { name: "Requested" })).toBeDisabled();
  });

  it("opens local items over the app and closes them with browser Back", async () => {
    const user = userEvent.setup();
    const { router } = renderNews();

    await user.click(screen.getByRole("button", { name: "Open Patriots turn up the tempo as the offense enters its final camp phase" }));
    expect(screen.getByRole("dialog", { name: "Patriots turn up the tempo as the offense enters its final camp phase" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Discussion" })).toBeInTheDocument();
    expect(router.state.location.search).toBe("?item=patriots-camp-tempo");
    expect(screen.getByText(/New England moved through its sharpest practice/i)).toBeInTheDocument();

    const opener = screen.getByRole("button", { name: "Open Patriots turn up the tempo as the offense enters its final camp phase" });
    await user.click(screen.getByRole("button", { name: "Close News item" }));
    await waitFor(() => expect(screen.queryByRole("dialog", { name: /Patriots turn up the tempo/i })).not.toBeInTheDocument());
    await waitFor(() => expect(opener).toHaveFocus());
    expect(screen.getByText("Latest from New England Patriots")).toBeInTheDocument();
  });

  it("opens the connected Article Discussion from the News Item top bar", async () => {
    const user = userEvent.setup();
    const { router } = renderNews();

    await user.click(screen.getByRole("button", { name: "Open Patriots turn up the tempo as the offense enters its final camp phase" }));
    await user.click(screen.getByRole("button", { name: "Discussion" }));
    expect(screen.getByRole("heading", { name: "Article Discussions" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Patriots turn up the tempo as the offense enters its final camp phase" })).toBeInTheDocument();

    await router.navigate(-1);
    await waitFor(() => expect(screen.getByRole("button", { name: "Discussion" })).toBeInTheDocument());
    expect(screen.getByRole("dialog", { name: "Patriots turn up the tempo as the offense enters its final camp phase" })).toBeInTheDocument();
  });

  it("represents external source-controlled items without leaving the app", async () => {
    const user = userEvent.setup();
    renderNews();

    await user.click(screen.getByRole("button", { name: "Open Audio notebook: Reading the Patriots defense before the snap" }));
    expect(screen.getByRole("heading", { name: "This item stays with its source" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /Continue to Weekend Sports Radio episode page/i }));
    expect(screen.getByRole("status")).toHaveTextContent("External destinations are not connected");
  });
});
