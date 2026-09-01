import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  hideCommunityFan: vi.fn(),
  loadMyHiddenFans: vi.fn(),
  unhideCommunityIntent: vi.fn(),
}));

vi.mock("./communityRepository", () => ({
  hideCommunityFan: mocks.hideCommunityFan,
  loadMyHiddenFans: mocks.loadMyHiddenFans,
  unhideCommunityIntent: mocks.unhideCommunityIntent,
}));

import { HiddenFansSettings } from "./HiddenFansSettings";

describe("HiddenFansSettings", () => {
  beforeEach(() => {
    mocks.hideCommunityFan.mockReset().mockResolvedValue(undefined);
    mocks.loadMyHiddenFans.mockReset().mockResolvedValue([]);
    mocks.unhideCommunityIntent.mockReset().mockResolvedValue(undefined);
  });

  it("hides the current owner of an exact Fanatical Name and refreshes the list", async () => {
    const user = userEvent.setup();
    render(<HiddenFansSettings />);

    await screen.findByText("You have not hidden anyone.");
    expect(screen.getByLabelText("Hide by current Fanatical Name")).not.toBeRequired();
    await user.type(screen.getByLabelText("Hide by current Fanatical Name"), "TestFan");
    await user.click(screen.getByRole("button", { name: "Hide" }));

    await waitFor(() => expect(mocks.hideCommunityFan).toHaveBeenCalledWith("TestFan"));
    expect(mocks.loadMyHiddenFans).toHaveBeenCalledTimes(2);
    expect(screen.getByLabelText("Hide by current Fanatical Name")).toHaveValue("");
  });

  it("does not present an account empty state while the control is disabled", () => {
    render(<HiddenFansSettings disabled />);
    expect(screen.getByText("Sign in to manage Hidden fans.")).toBeInTheDocument();
    expect(screen.queryByText("You have not hidden anyone.")).not.toBeInTheDocument();
  });

  it("removes only the viewer's own Hide intent", async () => {
    const user = userEvent.setup();
    mocks.loadMyHiddenFans
      .mockResolvedValueOnce([{
        hideIntentId: "hide-one",
        fanaticalName: "Brad",
        hiddenSince: "2026-08-31T00:00:00Z",
        alsoHidesYou: true,
      }])
      .mockResolvedValueOnce([]);
    render(<HiddenFansSettings />);

    await screen.findByText("Brad");
    await user.click(screen.getByRole("button", { name: "Unhide" }));

    await waitFor(() => expect(mocks.unhideCommunityIntent).toHaveBeenCalledWith("hide-one"));
    expect(await screen.findByText("You have not hidden anyone.")).toBeInTheDocument();
  });
});
