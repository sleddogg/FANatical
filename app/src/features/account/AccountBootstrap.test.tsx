import { render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  loadAccountSettings: vi.fn(),
  loadFollowedTeams: vi.fn(),
  loadHomeCustomization: vi.fn(),
  loadNavigationSide: vi.fn(),
  loadNewsDemoSelections: vi.fn(),
  loadProfileImageShape: vi.fn(),
  loadProfileVisualImages: vi.fn(),
  loadRemoteProfileVisuals: vi.fn(),
  loadSelectedTeamId: vi.fn(),
  loadThemePreference: vi.fn(),
  replaceAccountFollowedTeams: vi.fn(),
  saveAccountSettings: vi.fn(),
  saveOwnedProfile: vi.fn(),
  uploadRemoteProfileVisual: vi.fn(),
  useAuth: vi.fn(),
}));

vi.mock("../../data/followedTeams", () => ({
  followedTeamsStorageKey: "fanatical.test.followed-teams",
  loadFollowedTeams: mocks.loadFollowedTeams,
}));

vi.mock("../../data/navigationSideStorage", () => ({
  loadNavigationSide: mocks.loadNavigationSide,
}));

vi.mock("../../data/profileImageShapeStorage", () => ({
  loadProfileImageShape: mocks.loadProfileImageShape,
}));

vi.mock("../../data/homeCustomizationStorage", () => ({
  loadHomeCustomization: mocks.loadHomeCustomization,
}));

vi.mock("../../data/themePreferenceStorage", () => ({
  loadThemePreference: mocks.loadThemePreference,
}));

vi.mock("../../data/selectedTeamPreference", () => ({
  localSelectedTeamPreferenceStore: {
    loadSelectedTeamId: mocks.loadSelectedTeamId,
  },
}));

vi.mock("../profileVisual/profileVisualStorage", () => ({
  loadProfileVisualImages: mocks.loadProfileVisualImages,
}));

vi.mock("../profileVisual/profileVisualRepository", () => ({
  loadRemoteProfileVisuals: mocks.loadRemoteProfileVisuals,
  uploadRemoteProfileVisual: mocks.uploadRemoteProfileVisual,
}));

vi.mock("../news/newsDemoState", () => ({
  loadNewsDemoSelections: mocks.loadNewsDemoSelections,
}));

vi.mock("./accountRepository", () => ({
  loadAccountSettings: mocks.loadAccountSettings,
  replaceAccountFollowedTeams: mocks.replaceAccountFollowedTeams,
  saveAccountSettings: mocks.saveAccountSettings,
  saveOwnedProfile: mocks.saveOwnedProfile,
}));

vi.mock("./AuthContext", () => ({
  useAuth: mocks.useAuth,
}));

import { AccountBootstrapProvider, useAccountBootstrap } from "./AccountBootstrap";

const realUserId = "real-signup-user";
const localVisual = { variant: "wide", id: "local-wide-visual" };

function BootstrapProbe() {
  const state = useAccountBootstrap();
  return <output>{`${state.ready ? "ready" : "waiting"}:${state.revision}:${state.error}`}</output>;
}

function renderBootstrap() {
  return render(
    <AccountBootstrapProvider>
      <BootstrapProbe />
    </AccountBootstrapProvider>,
  );
}

describe("real-account prototype bootstrap", () => {
  beforeEach(() => {
    for (const mock of Object.values(mocks)) mock.mockReset();

    mocks.useAuth.mockReturnValue({
      configured: true,
      loading: false,
      user: { id: realUserId },
    });
    mocks.loadFollowedTeams.mockReturnValue([
      {
        id: "edmonton-oilers",
        officialTeamId: "hockey-nhl-edmonton-oilers",
      },
    ]);
    mocks.loadSelectedTeamId.mockResolvedValue("edmonton-oilers");
    mocks.loadNavigationSide.mockReturnValue("right");
    mocks.loadProfileImageShape.mockReturnValue("square");
    mocks.loadHomeCustomization.mockReturnValue({ density: "comfortable" });
    mocks.loadThemePreference.mockReturnValue({ source: "team", order: "normal" });
    mocks.loadProfileVisualImages.mockResolvedValue([localVisual]);
    mocks.loadRemoteProfileVisuals.mockResolvedValue([]);
    mocks.replaceAccountFollowedTeams.mockResolvedValue(undefined);
    mocks.saveAccountSettings.mockResolvedValue(undefined);
    mocks.uploadRemoteProfileVisual.mockResolvedValue(undefined);
  });

  it("preserves the signup-created profile while migrating legitimate local account state once", async () => {
    mocks.loadAccountSettings.mockResolvedValue({ prototypeMigrationVersion: 0 });
    window.localStorage.setItem("fanatical.test.followed-teams", '["hockey-nhl-edmonton-oilers"]');

    renderBootstrap();

    await waitFor(() => expect(screen.getByText("ready:1:")).toBeInTheDocument());

    expect(mocks.saveOwnedProfile).not.toHaveBeenCalled();
    expect(mocks.replaceAccountFollowedTeams).toHaveBeenCalledOnce();
    expect(mocks.replaceAccountFollowedTeams).toHaveBeenCalledWith(
      realUserId,
      ["hockey-nhl-edmonton-oilers"],
    );
    expect(mocks.saveAccountSettings).toHaveBeenNthCalledWith(1, realUserId, {
      navigationSide: "right",
      profileImageShape: "square",
      homeCustomization: { density: "comfortable" },
      themePreference: { source: "team", order: "normal" },
      selectedTeamId: "hockey-nhl-edmonton-oilers",
    });
    expect(mocks.uploadRemoteProfileVisual).toHaveBeenCalledWith(realUserId, localVisual);
    expect(mocks.saveAccountSettings).toHaveBeenNthCalledWith(2, realUserId, {
      prototypeMigrationVersion: 1,
    });

    const persistedCalls = JSON.stringify([
      ...mocks.replaceAccountFollowedTeams.mock.calls,
      ...mocks.saveAccountSettings.mock.calls,
      ...mocks.uploadRemoteProfileVisual.mock.calls,
    ]);
    expect(persistedCalls).not.toMatch(
      /Alex Mercer|Sleddogg|Edmonton, Alberta|New England Patriots|Boston Red Sox|Boston Celtics/,
    );
  });

  it("does not persist fallback demo teams when no followed-team state was stored", async () => {
    mocks.loadAccountSettings.mockResolvedValue({ prototypeMigrationVersion: 0 });
    mocks.loadProfileVisualImages.mockResolvedValue([]);

    renderBootstrap();

    await waitFor(() => expect(screen.getByText("ready:1:")).toBeInTheDocument());

    expect(mocks.saveOwnedProfile).not.toHaveBeenCalled();
    expect(mocks.loadFollowedTeams).not.toHaveBeenCalled();
    expect(mocks.loadSelectedTeamId).not.toHaveBeenCalled();
    expect(mocks.replaceAccountFollowedTeams).not.toHaveBeenCalled();
    expect(mocks.saveAccountSettings).toHaveBeenNthCalledWith(1, realUserId, {
      navigationSide: "right",
      profileImageShape: "square",
      homeCustomization: { density: "comfortable" },
      themePreference: { source: "team", order: "normal" },
    });
    expect(mocks.saveAccountSettings).toHaveBeenNthCalledWith(2, realUserId, {
      prototypeMigrationVersion: 1,
    });
  });

  it("never reads or writes News Demo selections while bootstrapping a real account", async () => {
    mocks.loadAccountSettings.mockResolvedValue({ prototypeMigrationVersion: 0 });
    mocks.loadProfileVisualImages.mockResolvedValue([]);
    mocks.loadNewsDemoSelections.mockReturnValue([
      { targetType: "organization", targetId: "demo-organization" },
    ]);

    renderBootstrap();
    await waitFor(() => expect(screen.getByText("ready:1:")).toBeInTheDocument());

    expect(mocks.loadNewsDemoSelections).not.toHaveBeenCalled();
    expect(JSON.stringify([
      ...mocks.replaceAccountFollowedTeams.mock.calls,
      ...mocks.saveAccountSettings.mock.calls,
      ...mocks.uploadRemoteProfileVisual.mock.calls,
    ])).not.toContain("demo-organization");
  });

  it("uses prototype_migration_version to avoid repeating any migration", async () => {
    mocks.loadAccountSettings.mockResolvedValue({ prototypeMigrationVersion: 1 });

    renderBootstrap();

    await waitFor(() => expect(screen.getByText("ready:1:")).toBeInTheDocument());

    expect(mocks.loadAccountSettings).toHaveBeenCalledOnce();
    expect(mocks.saveOwnedProfile).not.toHaveBeenCalled();
    expect(mocks.replaceAccountFollowedTeams).not.toHaveBeenCalled();
    expect(mocks.saveAccountSettings).not.toHaveBeenCalled();
    expect(mocks.uploadRemoteProfileVisual).not.toHaveBeenCalled();
  });
});
