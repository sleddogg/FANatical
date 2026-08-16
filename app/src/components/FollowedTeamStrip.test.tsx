import { render, screen, waitFor } from "@testing-library/react";
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

  it("defaults to the Patriots and keeps Add Team outside the followed-team group", () => {
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
      screen.getByRole("button", { name: "Add Team" }),
    );
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

  it("adds, confirms, persists, and selects an official team from Home", async () => {
    const user = userEvent.setup();
    const preferenceStore = createPreferenceStore();

    render(
      <TeamProvider preferenceStore={preferenceStore}>
        <FollowedTeamStrip />
        <SelectedTeamProbe />
      </TeamProvider>,
    );

    await user.click(screen.getByRole("button", { name: "Add Team" }));
    expect(screen.getByRole("dialog", { name: "Pick a Sport" }).closest(".profile-dialog-layer--bottom")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /^Hockey/ }));
    await user.click(screen.getByRole("button", { name: /^NHL/ }));
    await user.click(screen.getByRole("button", { name: "Select Edmonton Oilers" }));
    expect(screen.getByRole("heading", { name: "Edmonton Oilers" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Confirm Add Team" }));

    const oilers = screen.getByRole("button", { name: "Select Edmonton Oilers" });
    expect(oilers).toBeInTheDocument();
    expect(JSON.parse(window.localStorage.getItem(followedTeamsStorageKey) ?? "[]")).toContain("hockey-nhl-edmonton-oilers");
    await user.click(oilers);
    expect(oilers).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByRole("status", { name: "Shared selected team" })).toHaveTextContent("Edmonton Oilers");
  });
});
