import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createMemoryRouter, RouterProvider } from "react-router-dom";
import { describe, expect, it } from "vitest";
import { appRoutes } from "../../app/routes";

function renderLeaderboards() {
  const router = createMemoryRouter(appRoutes, { initialEntries: ["/fanbase?area=leaderboards"] });
  return { router, ...render(<RouterProvider router={router} />) };
}

describe("FANbase Leaderboards", () => {
  it("defaults to the current Team and sorts the one table by tappable stat headers", async () => {
    const user = userEvent.setup();
    renderLeaderboards();

    expect(screen.getByRole("heading", { name: "Leaderboards", level: 1 })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "New England Patriots", level: 2 })).toBeInTheDocument();
    const table = screen.getByRole("table");
    expect(within(table).getByRole("button", { name: "Sort by Fan Score" })).toBeInTheDocument();
    expect(within(table).getAllByRole("row")[1]).toHaveTextContent("Maya84");

    await user.click(within(table).getByRole("button", { name: "Sort by Quiz IQ" }));
    expect(within(table).getByRole("button", { name: "Sort by Quiz IQ" }).querySelector(".app-icon")).toBeInTheDocument();
  });

  it("changes population without mixing Team-only Fan Score into broader rankings", async () => {
    const user = userEvent.setup();
    renderLeaderboards();

    await user.click(screen.getByRole("button", { name: "NFL" }));
    expect(screen.getByRole("heading", { name: "NFL", level: 2 })).toBeInTheDocument();
    expect(within(screen.getByRole("table")).queryByRole("button", { name: "Sort by Fan Score" })).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Friends" }));
    expect(screen.getByRole("heading", { name: "Friends", level: 2 })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Sunday Family Huddle" })).toBeInTheDocument();
  });

  it("opens the shared personal sports stats structure from a fan name", async () => {
    const user = userEvent.setup();
    renderLeaderboards();

    await user.click(screen.getByRole("button", { name: /Maya84/ }));
    expect(screen.getByRole("heading", { name: "Maya84 Sports Stats", level: 1 })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Overall Sport IQ" })).toBeInTheDocument();
    expect(screen.getByText("Trophy details remain in the existing Profile Trophy Case.")).toBeInTheDocument();
  });
});
