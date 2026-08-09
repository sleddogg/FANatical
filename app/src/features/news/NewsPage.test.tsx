import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createMemoryRouter, RouterProvider } from "react-router-dom";
import { describe, expect, it } from "vitest";
import { appRoutes } from "../../app/routes";

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

    expect(screen.getByText("Latest from New England Patriots")).toBeInTheDocument();
    const headlines = screen.getAllByRole("heading", { level: 2 }).map((heading) => heading.textContent);
    expect(headlines).toContain("Patriots turn up the tempo as the offense enters its final camp phase");
    expect(headlines).toContain("Audio notebook: Reading the Patriots defense before the snap");
    expect(headlines).not.toContain("Celtics test two rotation ideas designed for smaller, faster lineups");
  });

  it("updates the shared selected team from the News filter", async () => {
    const user = userEvent.setup();
    renderNews();

    await user.click(screen.getByRole("button", { name: "Open News filters" }));
    await user.click(screen.getByRole("button", { name: /Selected Team/i }));
    await user.click(screen.getByRole("button", { name: /Boston Celtics/i }));

    expect(screen.getByText("Latest from Boston Celtics")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Celtics test two rotation ideas designed for smaller, faster lineups" })).toBeInTheDocument();

    await user.click(screen.getByRole("link", { name: "FANatical home" }));
    expect(screen.getByRole("button", { name: "Select Boston Celtics" })).toHaveAttribute("aria-pressed", "true");
  });

  it("applies sport and all-followed contexts through the nested menu", async () => {
    const user = userEvent.setup();
    renderNews();

    await user.click(screen.getByRole("button", { name: "Open News filters" }));
    await user.click(screen.getByRole("button", { name: /Sport/i }));
    await user.click(screen.getByRole("button", { name: /Football/i }));
    expect(screen.getByText("Latest across Football")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Three adjustments reshaping the CFL playoff race" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Podcast: What the new UFL schedule could mean for spring football" })).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Open News filters" }));
    await user.click(screen.getByRole("button", { name: /All Followed News/i }));
    expect(screen.getByText("All followed News · newest first")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Red Sox map out a flexible bullpen plan for the coming series" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Celtics test two rotation ideas designed for smaller, faster lineups" })).toBeInTheDocument();
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
    expect(router.state.location.search).toBe("?item=patriots-camp-tempo");
    expect(screen.getByText(/New England moved through its sharpest practice/i)).toBeInTheDocument();

    await router.navigate(-1);
    await waitFor(() => {
      expect(screen.queryByRole("dialog", { name: /Patriots turn up the tempo/i })).not.toBeInTheDocument();
    });
    expect(screen.getByText("Latest from New England Patriots")).toBeInTheDocument();
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
