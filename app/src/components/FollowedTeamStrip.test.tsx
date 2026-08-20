import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { TeamId } from "../domain/team";
import type { SelectedTeamPreferenceStore } from "../data/selectedTeamPreference";
import { followedTeamsStorageKey } from "../data/followedTeams";
import { TeamProvider, useTeamContext } from "../state/TeamContext";
import { FollowedTeamStrip } from "./FollowedTeamStrip";

function SelectedTeamProbe() {
  const { selectedTeam } = useTeamContext();
  return <output aria-label="Shared selected team">{selectedTeam.name}</output>;
}

function createPreferenceStore(initialTeamId: TeamId | null = null) {
  return {
    loadSelectedTeamId: vi.fn(async () => initialTeamId),
    saveSelectedTeamId: vi.fn(async (_teamId: TeamId) => undefined),
  } satisfies SelectedTeamPreferenceStore;
}

describe("FollowedTeamStrip", () => {
  beforeEach(() => {
    window.localStorage.removeItem(followedTeamsStorageKey);
  });

  it("defaults to the Patriots and keeps Manage Teams outside the followed-team group", () => {
    render(
      <TeamProvider preferenceStore={createPreferenceStore()}>
        <FollowedTeamStrip />
      </TeamProvider>,
    );

    expect(screen.getByRole("button", { name: "Select New England Patriots" })).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    expect(screen.getByRole("group", { name: "Followed teams" })).toContainElement(
      screen.getByRole("button", { name: "Select Boston Celtics" }),
    );
    expect(screen.getByRole("group", { name: "Followed teams" })).not.toContainElement(
      screen.getByRole("button", { name: "Manage Teams" }),
    );
    expect(screen.getByRole("button", { name: "Manage Teams" })).toHaveAttribute("data-tooltip-label", "Manage Teams");
    expect(screen.queryByRole("button", { name: /Browse (previous|more) followed teams/ })).not.toBeInTheDocument();
  });

  it("updates the shared selected-team value and persistence when a team is selected", async () => {
    const user = userEvent.setup();
    const preferenceStore = createPreferenceStore();

    render(
      <TeamProvider preferenceStore={preferenceStore}>
        <FollowedTeamStrip />
        <SelectedTeamProbe />
      </TeamProvider>,
    );

    await user.click(screen.getByRole("button", { name: "Select Boston Celtics" }));

    expect(screen.getByRole("button", { name: "Select Boston Celtics" })).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByRole("button", { name: "Select New England Patriots" })).toHaveAttribute(
      "aria-pressed",
      "false",
    );
    expect(screen.getByRole("status", { name: "Shared selected team" })).toHaveTextContent("Boston Celtics");
    expect(preferenceStore.saveSelectedTeamId).toHaveBeenCalledWith("boston-celtics");
  });

  it("restores a valid persisted team selection", async () => {
    const preferenceStore = createPreferenceStore("boston-red-sox");

    render(
      <TeamProvider preferenceStore={preferenceStore}>
        <FollowedTeamStrip />
        <SelectedTeamProbe />
      </TeamProvider>,
    );

    await waitFor(() => {
      expect(screen.getByRole("button", { name: "Select Boston Red Sox" })).toHaveAttribute(
        "aria-pressed",
        "true",
      );
    });
    expect(screen.getByRole("status", { name: "Shared selected team" })).toHaveTextContent("Boston Red Sox");
  });

  it("opens Manage Teams by default and adds a team through the vertical drill-down", async () => {
    const user = userEvent.setup();
    const preferenceStore = createPreferenceStore();

    render(
      <TeamProvider preferenceStore={preferenceStore}>
        <FollowedTeamStrip />
        <SelectedTeamProbe />
      </TeamProvider>,
    );

    await user.click(screen.getByRole("button", { name: "Manage Teams" }));
    expect(screen.getByRole("dialog", { name: "Manage Teams" })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: "Manage Teams" })).toHaveAttribute("aria-selected", "true");
    await user.click(screen.getByRole("tab", { name: "Add a Team" }));
    await user.click(screen.getByRole("button", { name: "Hockey" }));
    expect(screen.getByRole("button", { name: /Back to Sports/ })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /^NHL/ }));
    expect(screen.getByRole("button", { name: /Back to Leagues/ })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Add Edmonton Oilers" }));

    const oilers = await screen.findByRole("button", { name: "Select Edmonton Oilers" });
    expect(oilers).toBeInTheDocument();
    expect(JSON.parse(window.localStorage.getItem(followedTeamsStorageKey) ?? "[]")).toContain("hockey-nhl-edmonton-oilers");
    expect(screen.getByRole("tab", { name: "Manage Teams" })).toHaveAttribute("aria-selected", "true");
    await user.click(oilers);
    expect(oilers).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByRole("status", { name: "Shared selected team" })).toHaveTextContent("Edmonton Oilers");
  });

  it("persists keyboard reordering and makes the first team the Favorite Team", async () => {
    const user = userEvent.setup();

    render(
      <TeamProvider preferenceStore={createPreferenceStore()}>
        <FollowedTeamStrip />
      </TeamProvider>,
    );

    await user.click(screen.getByRole("button", { name: "Manage Teams" }));
    const reorderRedSox = screen.getByRole("button", { name: "Reorder Boston Red Sox" });
    reorderRedSox.focus();
    await user.keyboard("{ArrowUp}");

    await waitFor(() => {
      expect(JSON.parse(window.localStorage.getItem(followedTeamsStorageKey) ?? "[]")[0]).toBe("baseball-mlb-boston-red-sox");
    });
    const redSoxRow = screen.getByText("Boston Red Sox").closest("li");
    expect(redSoxRow).not.toBeNull();
    expect(within(redSoxRow!).getByText("Favorite Team")).toBeInTheDocument();
    expect(screen.getAllByRole("button", { name: /^Select / })[0]).toHaveAccessibleName("Select Boston Red Sox");
  });

  it("requires confirmation before removing a team and persists the result", async () => {
    const user = userEvent.setup();

    render(
      <TeamProvider preferenceStore={createPreferenceStore()}>
        <FollowedTeamStrip />
        <SelectedTeamProbe />
      </TeamProvider>,
    );

    await user.click(screen.getByRole("button", { name: "Manage Teams" }));
    const managedTeams = screen.getByRole("list", { name: "Ordered followed teams" });
    const patriotsRow = within(managedTeams).getByText("New England Patriots").closest("li");
    expect(patriotsRow).not.toBeNull();
    await user.click(within(patriotsRow!).getByRole("button", { name: "Remove" }));
    expect(screen.getByRole("alertdialog", { name: "Remove New England Patriots?" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Select New England Patriots" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Remove Team" }));

    await waitFor(() => expect(screen.queryByRole("button", { name: "Select New England Patriots" })).not.toBeInTheDocument());
    expect(JSON.parse(window.localStorage.getItem(followedTeamsStorageKey) ?? "[]")).not.toContain("football-nfl-new-england-patriots");
    expect(screen.getByRole("status", { name: "Shared selected team" })).toHaveTextContent("Boston Red Sox");
    const redSoxRow = within(managedTeams).getByText("Boston Red Sox").closest("li");
    expect(redSoxRow).not.toBeNull();
    expect(within(redSoxRow!).getByText("Favorite Team")).toBeInTheDocument();
  });

  it("handles an intentionally empty followed-team list", async () => {
    const user = userEvent.setup();
    window.localStorage.setItem(followedTeamsStorageKey, "[]");

    render(
      <TeamProvider preferenceStore={createPreferenceStore()}>
        <FollowedTeamStrip />
      </TeamProvider>,
    );

    expect(within(screen.getByRole("group", { name: "Followed teams" })).queryByRole("button")).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Manage Teams" }));
    const emptyState = screen.getByText("No followed teams yet").closest("div");
    expect(emptyState).not.toBeNull();
    await user.click(within(emptyState!).getByRole("button", { name: "Add a Team" }));
    expect(screen.getByText("Choose a Sport")).toBeInTheDocument();
  });
});
