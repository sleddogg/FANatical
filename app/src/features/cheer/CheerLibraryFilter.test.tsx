import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { followedTeams } from "../../data/followedTeams";
import { CheerLibraryFilter } from "./CheerLibraryFilter";

describe("Cheer Library filter selector", () => {
  it("uses Sport cards, a prominent Sport-wide action, and League cards", async () => {
    const user = userEvent.setup();
    const onApply = vi.fn();
    render(<CheerLibraryFilter activeFilter={{ kind: "all" }} followedTeams={followedTeams} onApply={onApply} />);

    await user.click(screen.getByRole("menuitem", { name: /Sport/ }));
    expect(screen.getByText("Choose a Sport")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Hockey" }));
    expect(screen.getByRole("button", { name: "Show All Hockey Cheers" })).toBeInTheDocument();
    expect(screen.getByText("Or narrow by league")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "NHL" }));
    expect(onApply).toHaveBeenCalledWith({ kind: "league", leagueId: "hockey-nhl" });
  });

  it("shows followed teams before searchable official Team results", async () => {
    const user = userEvent.setup();
    const onApply = vi.fn();
    render(<CheerLibraryFilter activeFilter={{ kind: "all" }} followedTeams={followedTeams} onApply={onApply} />);

    await user.click(screen.getByRole("menuitem", { name: /Team/ }));
    const followed = screen.getByText("Followed teams").parentElement!;
    await user.click(within(followed).getByRole("button", { name: /Patriots/ }));
    expect(onApply).toHaveBeenCalledWith({ kind: "team", teamId: "football-nfl-new-england-patriots" });

    onApply.mockClear();
    await user.type(screen.getByRole("searchbox", { name: "Search all official teams" }), "Edmonton Oilers");
    await user.click(screen.getByRole("button", { name: /Edmonton Oilers/ }));
    expect(onApply).toHaveBeenCalledWith({ kind: "team", teamId: "hockey-nhl-edmonton-oilers" });
  });
});
