import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createMemoryRouter, RouterProvider } from "react-router-dom";
import { beforeEach, describe, expect, it } from "vitest";
import { appRoutes } from "../../app/routes";
import { followedTeamsStorageKey } from "../../data/followedTeams";
import { navigationSideStorageKey } from "../../data/navigationSidePreference";

function renderProfile() {
  window.sessionStorage.clear();
  const router = createMemoryRouter(appRoutes, { initialEntries: ["/profile"] });
  return render(<RouterProvider router={router} />);
}

describe("Profile owner experience", () => {
  beforeEach(() => {
    window.localStorage.removeItem(followedTeamsStorageKey);
  });

  it("renders identity, canonical FANfoto categories, stats, and one active tab", () => {
    renderProfile();

    expect(screen.getByRole("heading", { name: "NorthStarFan", level: 1 })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Edit profile" })).toBeInTheDocument();
    expect(screen.getByRole("region", { name: "Profile FANfoto categories" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Open Game Face Fan Photos" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Open Fan Cave Fan Photos" })).toHaveAttribute("aria-current", "true");
    expect(screen.getByRole("button", { name: "Open Memorabilia Fan Photos" })).toBeInTheDocument();
    expect(screen.getByText("18,460")).toBeInTheDocument();
    expect(screen.getByRole("region", { name: "Profile at a glance" })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: "Bio" })).toHaveAttribute("aria-selected", "true");
    expect(screen.queryByText("Weight")).not.toBeInTheDocument();
    expect(screen.queryByText("@NorthStarFan")).not.toBeInTheDocument();
    expect(screen.queryByText(/The outfits, paint, signs/)).not.toBeInTheDocument();
  });

  it("edits local profile content, featured category, and Sports Played records", async () => {
    const user = userEvent.setup();
    renderProfile();

    await user.click(screen.getByRole("button", { name: "Edit profile" }));
    const dialog = screen.getByRole("dialog", { name: "Edit Profile" });
    const nameInput = within(dialog).getByLabelText("Display name");
    expect(within(dialog).getByRole("radio", { name: "Public profile" })).toBeChecked();
    expect(within(dialog).getByRole("radio", { name: "Private profile" })).toBeDisabled();
    await user.clear(nameInput);
    await user.type(nameInput, "Sleddogg");
    expect(within(dialog).queryByLabelText("Avatar placeholder")).not.toBeInTheDocument();
    expect(within(dialog).queryByLabelText("Banner placeholder")).not.toBeInTheDocument();
    expect(within(dialog).getAllByText("FANatical default")).toHaveLength(2);
    await user.click(within(dialog).getByRole("button", { name: "Add Mobile image" }));
    expect(within(dialog).getByRole("group", { name: "Mobile Visual crop area" })).toBeInTheDocument();
    expect(within(dialog).getByRole("group", { name: "Wide Visual crop area" })).toBeInTheDocument();
    expect(within(dialog).getByLabelText("Choose Mobile Visual")).toHaveAttribute("accept", "image/jpeg,image/png,image/webp");
    expect(within(dialog).getByLabelText("Choose Wide Visual")).toHaveAttribute("accept", "image/jpeg,image/png,image/webp");
    await user.click(within(dialog).getByRole("button", { name: /Back to Profile settings/ }));
    expect(within(dialog).getByRole("radio", { name: "Left" })).toBeChecked();
    await user.click(within(dialog).getByRole("radio", { name: "Right" }));
    expect(within(dialog).queryByRole("radio", { name: "Circle" })).not.toBeInTheDocument();
    expect(within(dialog).queryByRole("radio", { name: "Square" })).not.toBeInTheDocument();
    await user.click(within(dialog).getByRole("radio", { name: "Game Face" }));
    await user.click(within(dialog).getByRole("button", { name: "Add sport" }));
    const sportInputs = within(dialog).getAllByLabelText("Sport");
    await user.type(sportInputs[sportInputs.length - 1]!, "Curling");
    await user.click(within(dialog).getByRole("button", { name: "Save profile" }));

    expect(screen.getByRole("heading", { name: "Sleddogg", level: 1 })).toBeInTheDocument();
    expect(window.localStorage.getItem(navigationSideStorageKey)).toBe("right");
    expect(screen.getByRole("button", { name: "Open Game Face Fan Photos" })).toHaveAttribute("aria-current", "true");
    await user.click(screen.getByRole("tab", { name: "Sports Played" }));
    expect(screen.getByRole("heading", { name: "Curling" })).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Edit profile" }));
    const updatedDialog = screen.getByRole("dialog", { name: "Edit Profile" });
    await user.click(within(updatedDialog).getByRole("button", { name: "Remove Curling" }));
    await user.click(within(updatedDialog).getByRole("button", { name: "Save profile" }));
    expect(screen.queryByRole("heading", { name: "Curling" })).not.toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Hockey" })).toBeInTheDocument();

    await user.click(screen.getByRole("tab", { name: "Trophy Case" }));
    expect(screen.getByRole("heading", { name: "Trophy Case" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Founding Fan" })).toBeInTheDocument();
  });

  it("customizes responsive Home text and a Profile-backed Fan Card", async () => {
    const user = userEvent.setup();
    renderProfile();

    await user.click(screen.getByRole("button", { name: "Edit profile" }));
    const dialog = screen.getByRole("dialog", { name: "Edit Profile" });
    const textPanel = within(dialog).getByRole("region", { name: "Text Overlay" });
    const fanCardPanel = within(dialog).getByRole("region", { name: "Fan Card" });
    const bigText = within(textPanel).getByLabelText("Big text");
    await user.clear(bigText);
    await user.type(bigText, "A".repeat(35));
    expect(bigText).toHaveValue("A".repeat(30));
    expect(within(textPanel).getByText("30 / 30")).toBeInTheDocument();
    await user.click(within(textPanel).getByRole("radio", { name: "Top Left" }));

    await user.click(within(fanCardPanel).getByRole("switch", { name: "Enable Fan Card" }));
    await user.click(within(fanCardPanel).getByRole("button", { name: "Select FANatical name, North Star" }));
    await user.click(within(fanCardPanel).getByRole("button", { name: "Select Nickname, Sleddogg" }));
    expect(within(fanCardPanel).getByRole("button", { name: "FANatical name, selected 1 of 4, North Star" })).toHaveTextContent("1");
    expect(within(fanCardPanel).getByRole("button", { name: "Nickname, selected 2 of 4, Sleddogg" })).toHaveTextContent("2");
    await user.click(within(fanCardPanel).getByRole("button", { name: "Move Nickname up" }));
    await user.click(within(fanCardPanel).getByRole("radio", { name: "Stack" }));
    await user.click(within(fanCardPanel).getByRole("radio", { name: "Bottom Left" }));
    await user.click(within(dialog).getByRole("button", { name: "Save profile" }));

    await user.click(screen.getByRole("link", { name: "FANatical home" }));
    expect(screen.getByRole("heading", { name: "A".repeat(30) })).toBeInTheDocument();
    const textOverlay = screen.getByRole("heading", { name: "A".repeat(30) }).closest(".home-hero__text-overlay");
    expect(textOverlay).not.toHaveTextContent("FANatical");
    const fanCard = screen.getByLabelText("Fan Card");
    expect(within(fanCard).getByText("Sleddogg")).toBeInTheDocument();
    expect(within(fanCard).getByText("North Star")).toBeInTheDocument();
    expect(within(fanCard).queryByText("Nickname")).not.toBeInTheDocument();
    expect(within(fanCard).queryByText("FANatical name")).not.toBeInTheDocument();
    expect(within(fanCard).queryByRole("term")).not.toBeInTheDocument();
    expect(fanCard).toHaveClass("home-hero__fan-card--stack");
  });

  it("keeps Profile curation separate while opening the shared multi-image viewer", async () => {
    const user = userEvent.setup();
    renderProfile();

    const gameFaceCategory = screen.getByRole("button", { name: "Open Game Face Fan Photos" });
    await user.click(gameFaceCategory);
    await user.click(gameFaceCategory);
    expect(screen.getByRole("heading", { name: "Game Face", level: 1 })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "At a glance" })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Move The lucky game-day fit up" }));
    const table = screen.getByRole("table");
    expect(within(within(table).getAllByRole("row")[1]!).getByRole("button", { name: "Open The lucky game-day fit" })).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Back to Profile" }));
    const memorabiliaCategory = screen.getByRole("button", { name: "Open Memorabilia Fan Photos" });
    await user.click(memorabiliaCategory);
    await user.click(memorabiliaCategory);
    expect(screen.getByRole("heading", { name: "Memorabilia", level: 1 })).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Open Four views of a handmade mask" }));
    expect(screen.getByRole("dialog", { name: "Four views of a handmade mask" })).toBeInTheDocument();
    expect(screen.getByText("1 / 4")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Next image" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Close FANfoto" }));
    expect(screen.queryByRole("dialog", { name: "Four views of a handmade mask" })).not.toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Memorabilia", level: 1 })).toBeInTheDocument();
  });

  it("reuses the category-aware FANfoto creation flow", async () => {
    const user = userEvent.setup();
    renderProfile();

    const gameFaceCategory = screen.getByRole("button", { name: "Open Game Face Fan Photos" });
    await user.click(gameFaceCategory);
    await user.click(gameFaceCategory);
    await user.click(screen.getByRole("button", { name: "Add Game Face FANfoto" }));

    const dialog = screen.getByRole("dialog", { name: "Fan Photo" });
    expect(within(dialog).getByLabelText("Category")).toHaveValue("Game Face");
    await user.type(within(dialog).getByLabelText("Photo title"), "Snow-game face paint");
    await user.type(within(dialog).getByLabelText("Details"), "A local mock FANfoto added from Profile.");
    await user.click(within(dialog).getByRole("button", { name: "Create Fan Photo" }));

    expect(screen.getByRole("button", { name: "Open Snow-game face paint" })).toBeInTheDocument();
  });

  it("creates chronologically sorted Moments and opens dedicated Moment details", async () => {
    const user = userEvent.setup();
    renderProfile();

    await user.click(screen.getByRole("tab", { name: "Moments" }));
    await user.click(screen.getByRole("button", { name: "Add Moment" }));
    const dialog = screen.getByRole("dialog", { name: "Add Moment" });
    await user.type(within(dialog).getByLabelText("Title"), "The 2006 comeback");
    await user.clear(within(dialog).getByLabelText("Moment Date / Date Occurred"));
    await user.type(within(dialog).getByLabelText("Moment Date / Date Occurred"), "2006-10-14");
    await user.type(within(dialog).getByLabelText("Full story / memory"), "A memory added today that still belongs with the 2006 season.");
    await user.selectOptions(within(dialog).getByLabelText(/Connected FANfoto/), "photo-pats-mask");
    await user.click(within(dialog).getByRole("button", { name: "Save Moment" }));

    const momentLinks = screen.getAllByRole("button", { name: /^Open Moment:/ });
    expect(momentLinks[momentLinks.length - 1]).toHaveAccessibleName("Open Moment: The 2006 comeback");
    await user.click(momentLinks[momentLinks.length - 1]!);
    expect(screen.getByRole("heading", { name: "The 2006 comeback", level: 2 })).toBeInTheDocument();
    expect(screen.getByText("October 14, 2006")).toBeInTheDocument();
    expect(screen.queryByRole("tab", { name: "Moments" })).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Open connected FANfoto: Four views of a handmade mask" }));
    expect(screen.getByRole("dialog", { name: "Four views of a handmade mask" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Close FANfoto" }));
    expect(screen.getByRole("heading", { name: "The 2006 comeback", level: 2 })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Back to Moments" }));
    expect(screen.getByRole("tab", { name: "Moments" })).toHaveAttribute("aria-selected", "true");
  });

  it("adds an official team to the shared persisted followed-team list and prevents duplicates", async () => {
    const user = userEvent.setup();
    const rendered = renderProfile();

    await user.click(screen.getByRole("tab", { name: "Fan Identity" }));
    await user.click(screen.getByRole("button", { name: "Add Team" }));
    expect(screen.getByRole("dialog", { name: "Pick a Sport" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /^Hockey/ }));
    await user.click(screen.getByRole("button", { name: /^NHL/ }));
    await user.click(screen.getByRole("button", { name: "Select Edmonton Oilers" }));
    await user.click(screen.getByRole("button", { name: "Confirm Add Team" }));

    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
    expect(screen.getByText("Edmonton Oilers")).toBeInTheDocument();
    expect(JSON.parse(window.localStorage.getItem(followedTeamsStorageKey) ?? "[]")).toContain("hockey-nhl-edmonton-oilers");

    await user.click(screen.getByRole("button", { name: "Add Team" }));
    await user.click(screen.getByRole("button", { name: /^Hockey/ }));
    await user.click(screen.getByRole("button", { name: /^NHL/ }));
    expect(screen.getByRole("button", { name: "Edmonton Oilers, already followed" })).toBeDisabled();
    await user.click(screen.getByRole("button", { name: "Cancel" }));

    rendered.unmount();
    renderProfile();
    await user.click(screen.getByRole("tab", { name: "Fan Identity" }));
    expect(screen.getByText("Edmonton Oilers")).toBeInTheDocument();
  });
});
