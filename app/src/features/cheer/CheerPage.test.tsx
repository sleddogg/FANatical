import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createMemoryRouter, RouterProvider } from "react-router-dom";
import { beforeEach, describe, expect, it } from "vitest";
import { appRoutes } from "../../app/routes";

function renderCheer() {
  const router = createMemoryRouter(appRoutes, { initialEntries: ["/cheer"] });
  return render(<RouterProvider router={router} />);
}

async function reachBuilder(user: ReturnType<typeof userEvent.setup>, title = "North End Echo", lyrics = "We love the players more than our sons", sport = "Football") {
  await user.click(screen.getByRole("button", { name: "Add Cheer" }));
  await user.type(screen.getByLabelText("Title"), title);
  await user.selectOptions(screen.getByLabelText("Cheer Style"), "Echo");
  await user.selectOptions(screen.getByLabelText("Sport"), sport);
  await user.click(screen.getByRole("button", { name: "Continue to Lyrics" }));
  await user.type(screen.getByLabelText("Lyric line 1"), lyrics);
  await user.click(screen.getByRole("button", { name: "Build" }));
}

async function closeHowTo(user: ReturnType<typeof userEvent.setup>, remember = false) {
  const dialog = screen.getByRole("dialog", { name: "One Cheer, five creator lanes" });
  if (remember) await user.click(within(dialog).getByRole("checkbox", { name: "Don’t show this again" }));
  await user.click(within(dialog).getByRole("button", { name: "Close" }));
}

describe("Cheer frontend", () => {
  beforeEach(() => {
    window.localStorage.clear();
    window.sessionStorage.clear();
  });

  it("opens Read and Listen as dedicated Library screens", async () => {
    const user = userEvent.setup();
    renderCheer();

    expect(screen.getByRole("heading", { name: "Cheer Library", level: 1 })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /LIVE CHEERS/ })).not.toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "All Cheers", level: 2 })).toBeInTheDocument();
    const dFenceCard = screen.getByRole("heading", { name: "D-Fence Clap Clap" }).closest("article");
    expect(dFenceCard).not.toBeNull();
    await user.click(within(dFenceCard!).getByRole("button", { name: "Read" }));
    expect(screen.getByRole("heading", { name: "Read", level: 1 })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "D-Fence Clap Clap", level: 2 }).closest("main")).toHaveTextContent("D-Fence");
    await user.click(screen.getByRole("button", { name: /Cheer Library/ }));
    await user.click(within(screen.getByRole("heading", { name: "D-Fence Clap Clap" }).closest("article")!).getByRole("button", { name: "Listen" }));
    expect(screen.getByRole("heading", { name: "Listen", level: 1 })).toBeInTheDocument();
    expect(screen.getByText("No reference recording is attached to this Cheer yet.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Record Reference" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Play" })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Record Reference" }));
    expect(screen.getByRole("heading", { name: "Record the idea" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /Cheer Library/ }));
    await user.click(screen.getByRole("button", { name: "Bookmark D-Fence Clap Clap" }));
    expect(screen.getByRole("button", { name: "Remove bookmark from D-Fence Clap Clap" })).toHaveAttribute("aria-pressed", "true");
  });

  it("defaults to Available Now for a mapped team Check-In while preserving independent Launch eligibility after filtering", async () => {
    const user = userEvent.setup();
    window.localStorage.setItem("fanatical.cheer.check-in.v2", JSON.stringify({
      type: "MappedVenue",
      raw: { method: "Manual", venueId: "venue-rexall-place", venueName: "Rexall Place", sport: "Hockey", teamEvent: "Edmonton Oilers", section: "114", row: "12", seat: "8" },
      resolved: { level: "Lower", side: "Side A", end: "End A", sources: { level: "Section mapping", side: "Section mapping", end: "Section mapping" } },
      confirmedAt: "2026-08-14T18:00:00.000Z",
    }));
    renderCheer();

    expect(screen.getByRole("heading", { name: "Available Now" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Hockey Crowd Pulse" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "NHL Ice Roar" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Oil Country Rise" })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "SHL Ice Thunder" })).not.toBeInTheDocument();
    expect(screen.getAllByRole("button", { name: "Launch" })).toHaveLength(3);

    await user.click(screen.getByRole("button", { name: "Filter Cheer Library" }));
    await user.click(screen.getByRole("menuitemradio", { name: "All" }));
    expect(screen.getByRole("heading", { name: "All Cheers" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Ballpark Rally" })).toBeInTheDocument();
    expect(within(screen.getByRole("heading", { name: "Ballpark Rally" }).closest("article")!).queryByRole("button", { name: "Launch" })).not.toBeInTheDocument();
    expect(screen.getAllByRole("button", { name: "Launch" })).toHaveLength(3);

    await user.click(within(screen.getByRole("heading", { name: "Oil Country Rise" }).closest("article")!).getByRole("button", { name: "Launch" }));
    const launchDialog = screen.getByRole("dialog", { name: "Launch Oil Country Rise" });
    expect(within(launchDialog).getByRole("radio", { name: /ASAP/ })).toBeChecked();
    await user.click(within(launchDialog).getByRole("button", { name: "Add to Launch Page" }));
    expect(await screen.findByRole("heading", { name: "Cheer Launch" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /Cheer Library/ }));
    const liveBanner = screen.getByRole("button", { name: /LIVE CHEERS/ });
    expect(liveBanner).toHaveTextContent("1 active Cheer");
    await user.click(liveBanner);
    expect(await screen.findByRole("heading", { name: "Cheer Launch" })).toBeInTheDocument();
    const proposal = screen.getByRole("heading", { name: "Oil Country Rise" }).closest("article");
    expect(proposal).not.toBeNull();
    expect(within(proposal!).getByText("19 / 20")).toBeInTheDocument();
    await user.click(within(proposal!).getByRole("button", { name: "Join" }));
    expect(within(proposal!).getByText("20 / 20")).toBeInTheDocument();
    expect(within(proposal!).getAllByText(/CHEER GOING LIVE IN 5/).length).toBeGreaterThan(0);
  });

  it("shows creator-specific library actions and permanently deletes an owned Cheer after confirmation", async () => {
    const user = userEvent.setup();
    renderCheer();

    const fanaticalCard = screen.getByRole("heading", { name: "D-Fence Clap Clap" }).closest("article");
    expect(fanaticalCard).not.toBeNull();
    expect(within(fanaticalCard!).queryByRole("button", { name: "Edit Cheer" })).not.toBeInTheDocument();
    expect(within(fanaticalCard!).queryByRole("button", { name: "Delete Cheer" })).not.toBeInTheDocument();
    await user.click(within(fanaticalCard!).getByRole("button", { name: "Contact Creator" }));
    const contactDialog = screen.getByRole("dialog", { name: "Contact Creator" });
    expect(contactDialog).toHaveTextContent("suggest a new verse");
    expect(contactDialog).toHaveTextContent("without exposing private contact information");
    await user.click(within(contactDialog).getByRole("button", { name: "Close" }));

    await reachBuilder(user, "Oilers Fight Song", "Let’s go Oilers", "Hockey");
    await closeHowTo(user, true);
    await user.click(screen.getByRole("button", { name: "Place Action at beat 1" }));
    await user.click(screen.getByRole("button", { name: "Finish Cheer" }));
    await user.click(screen.getByRole("button", { name: "Publish Cheer" }));

    const ownerCard = screen.getByRole("heading", { name: "Oilers Fight Song" }).closest("article");
    expect(ownerCard).not.toBeNull();
    expect(within(ownerCard!).getByRole("button", { name: "Edit Cheer" })).toBeInTheDocument();
    expect(within(ownerCard!).getByRole("button", { name: "Delete Cheer" })).toBeInTheDocument();
    expect(within(ownerCard!).queryByRole("button", { name: "Contact Creator" })).not.toBeInTheDocument();

    await user.click(within(ownerCard!).getByRole("button", { name: "Delete Cheer" }));
    const deleteDialog = screen.getByRole("dialog", { name: "Delete this Cheer?" });
    expect(deleteDialog).toHaveTextContent("This cannot be undone.");
    await user.click(within(deleteDialog).getByRole("button", { name: "Cancel" }));
    expect(screen.getByRole("heading", { name: "Oilers Fight Song" })).toBeInTheDocument();

    await user.click(within(ownerCard!).getByRole("button", { name: "Delete Cheer" }));
    await user.click(within(screen.getByRole("dialog", { name: "Delete this Cheer?" })).getByRole("button", { name: "Delete Cheer" }));
    expect(screen.queryByRole("heading", { name: "Oilers Fight Song" })).not.toBeInTheDocument();
    await waitFor(() => expect(window.localStorage.getItem("fanatical.cheer.library")).not.toContain("Oilers Fight Song"));
  }, 10_000);

  it("places independent events directly, exposes rhythmic controls, and publishes through Finish Cheer", async () => {
    const user = userEvent.setup();
    renderCheer();
    await reachBuilder(user);
    expect(screen.queryByLabelText("Tempo BPM")).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Record" })).toBeInTheDocument();

    const teachingDialog = screen.getByRole("dialog", { name: "One Cheer, five creator lanes" });
    expect(teachingDialog).toHaveTextContent("👏");
    expect(teachingDialog).toHaveTextContent("End A");
    expect(within(teachingDialog).getByRole("img", { name: "Side and End routing" })).toBeInTheDocument();
    expect(within(teachingDialog).getByRole("img", { name: "Upper and Lower routing" })).toBeInTheDocument();
    expect(within(teachingDialog).getByRole("img", { name: "Baseball routing" })).toBeInTheDocument();
    expect(teachingDialog).toHaveTextContent("Backboard Left");
    expect(teachingDialog).toHaveTextContent("Uprights Right");
    await closeHowTo(user, true);

    expect(screen.queryByRole("button", { name: "+ Action" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "+ Lyric" })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Place Action at beat 3" }));
    expect(screen.getByRole("button", { name: "Action Clap at beat 3" })).toHaveTextContent("👏");
    expect(screen.getByRole("button", { name: "Action Note timing Eighth at beat 3" })).toHaveTextContent("♪");

    await user.click(screen.getByRole("button", { name: "Action Note timing Eighth at beat 3" }));
    const tray = screen.getByRole("region", { name: "Selected choreography controls" });
    expect(within(tray).getByRole("button", { name: /Dotted Half.*3 beats/ })).toBeInTheDocument();
    await user.click(within(tray).getByRole("button", { name: /Quarter.*1 beat/ }));
    expect(screen.getByRole("button", { name: "Action Note timing Quarter at beat 3" })).toHaveTextContent("♩");

    await user.click(screen.getByRole("button", { name: "Action audience All" }));
    expect(within(tray).getByRole("button", { name: "Side A" }).querySelector("img")).toBeInTheDocument();
    expect(within(tray).getByRole("button", { name: "End B" }).querySelector("img")).toBeInTheDocument();
    expect(within(tray).getByRole("button", { name: "Upper" }).querySelector("img")).toBeInTheDocument();
    expect(within(tray).getByRole("button", { name: "Uprights Left" })).toBeInTheDocument();
    expect(within(tray).getByRole("button", { name: "Uprights Right" })).toBeInTheDocument();
    for (const retiredDirection of ["East", "West", "North", "South"]) {
      expect(within(tray).queryByRole("button", { name: retiredDirection })).not.toBeInTheDocument();
    }
    await user.click(within(tray).getByRole("button", { name: "End B" }));
    expect(screen.getByRole("button", { name: "Action audience End B" }).querySelector("img")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Finish Cheer" }));
    expect(screen.getByRole("heading", { name: "Finish Cheer", level: 2 })).toBeInTheDocument();
    expect(screen.getByRole("combobox", { name: "Sport" })).toHaveValue("Football");
    expect(screen.getByLabelText("Team")).toHaveValue("");
    await user.type(screen.getByLabelText("Short description / instruction"), "Raise the noise on third down.");
    await user.click(screen.getByRole("button", { name: "Publish Cheer" }));
    expect(screen.getByRole("heading", { name: "North End Echo" })).toBeInTheDocument();
    expect(screen.getByText("Raise the noise on third down.")).toBeInTheDocument();
    expect(screen.getByText(/Published · Echo/)).toBeInTheDocument();
  }, 10_000);

  it("automatically continues Use line into the next fixed measure", async () => {
    const user = userEvent.setup();
    renderCheer();
    await reachBuilder(user, "Automatic Measures", "Go team fight tonight");
    await closeHowTo(user);

    await user.click(screen.getByRole("button", { name: "Place Lyric at beat 1" }));
    await user.type(screen.getByLabelText("Lyrics at beat 1"), "Lead");
    await user.click(screen.getByRole("button", { name: "Lyrics Note timing Eighth at beat 1" }));
    await user.click(within(screen.getByRole("region", { name: "Selected choreography controls" })).getByRole("button", { name: /Whole.*4 beats/ }));

    await user.click(screen.getByRole("button", { name: "Original Lyrics" }));
    const useLine = screen.getByRole("button", { name: /Go team fight tonight.*Use line/ });
    expect(useLine).toHaveTextContent(/^\d+Go team fight tonightUse line$/);
    await user.click(useLine);
    expect(screen.getByText("Measure 2")).toBeInTheDocument();
    expect(screen.getByText("Continued this lyric line into Measure 2.")).toBeInTheDocument();
    expect(screen.getByDisplayValue("Go")).toBeInTheDocument();
  });

  it("shows Basketball routing visuals after Sport changes and supports Save Draft", async () => {
    const user = userEvent.setup();
    renderCheer();
    await reachBuilder(user, "Courtside Call", "Green runs deep", "Basketball");
    await closeHowTo(user, true);
    await user.click(screen.getByRole("button", { name: "Place Action at beat 1" }));
    await user.click(screen.getByRole("button", { name: "Action audience All" }));
    const tray = screen.getByRole("region", { name: "Selected choreography controls" });
    expect(within(tray).getByRole("button", { name: "Side A" }).querySelector("img")).toBeInTheDocument();
    expect(within(tray).getByRole("button", { name: "End A" }).querySelector("img")).toBeInTheDocument();
    expect(within(tray).getByRole("button", { name: "Backboard Left" })).toBeInTheDocument();
    expect(within(tray).getByRole("button", { name: "Backboard Right" })).toBeInTheDocument();
    expect(within(tray).queryByRole("button", { name: "Uprights Left" })).not.toBeInTheDocument();
    const backboardLeft = within(tray).getByRole("button", { name: "Backboard Left" });
    expect(backboardLeft.querySelector("img")).toBeInTheDocument();
    await user.click(backboardLeft);
    expect(screen.getByRole("button", { name: "Action audience Backboard Left" }).querySelector("img")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Finish Cheer" }));
    await user.click(screen.getByRole("button", { name: "Save Draft" }));
    expect(screen.getByText(/Draft · Echo/)).toBeInTheDocument();
  });

  it("uses dependent official League and Team selectors and clears invalid downstream choices", async () => {
    const user = userEvent.setup();
    renderCheer();
    await reachBuilder(user, "Controlled Metadata", "Official choices", "Hockey");
    await closeHowTo(user, true);
    await user.click(screen.getByRole("button", { name: "Place Action at beat 1" }));
    await user.click(screen.getByRole("button", { name: "Finish Cheer" }));

    const sport = screen.getByLabelText("Sport");
    const league = screen.getByLabelText("League");
    const team = screen.getByLabelText("Team");
    expect(league).toHaveDisplayValue("Sport-wide (no league)");
    expect(within(league).getByRole("option", { name: "NHL" })).toBeInTheDocument();
    expect(within(league).queryByRole("option", { name: "NFL" })).not.toBeInTheDocument();
    expect(team).toBeDisabled();

    await user.selectOptions(league, "hockey-nhl");
    expect(team).toBeEnabled();
    expect(within(team).getByRole("option", { name: "Edmonton Oilers" })).toBeInTheDocument();
    await user.selectOptions(team, "hockey-nhl-edmonton-oilers");

    await user.selectOptions(sport, "Baseball");
    expect(league).toHaveDisplayValue("Sport-wide (no league)");
    expect(team).toBeDisabled();
    expect(team).toHaveDisplayValue("League-wide (no team)");
    expect(within(league).getByRole("option", { name: "MLB" })).toBeInTheDocument();
    expect(within(league).queryByRole("option", { name: "NHL" })).not.toBeInTheDocument();

    await user.selectOptions(league, "baseball-mlb");
    await user.selectOptions(team, "baseball-mlb-boston-red-sox");
    await user.selectOptions(league, "baseball-npb");
    expect(team).toHaveDisplayValue("League-wide (no team)");
    expect(within(team).queryByRole("option", { name: "Boston Red Sox" })).not.toBeInTheDocument();
  }, 10_000);

  it("confirms deletion from the measure header", async () => {
    const user = userEvent.setup();
    renderCheer();
    await reachBuilder(user, "Measure Safety", "Keep this line");
    await closeHowTo(user);
    await user.click(screen.getByRole("button", { name: "+ Add Measure" }));
    await user.click(screen.getAllByRole("button", { name: "Place Action at beat 1" })[1]!);
    await user.click(screen.getAllByRole("button", { name: "Delete Measure" })[1]!);
    const dialog = screen.getByRole("dialog", { name: "Delete Measure 2?" });
    expect(dialog).toHaveTextContent("every Action, Lyric, timing, and audience assignment");
    await user.click(within(dialog).getByRole("button", { name: "Cancel" }));
    expect(screen.getByText("Measure 2")).toBeInTheDocument();
    await user.click(screen.getAllByRole("button", { name: "Delete Measure" })[1]!);
    await user.click(within(screen.getByRole("dialog", { name: "Delete Measure 2?" })).getByRole("button", { name: "Delete Measure" }));
    expect(screen.queryByText("Measure 2")).not.toBeInTheDocument();
  });

  it("uses a measure-wide Rest, shortest-to-longest timing choices, and cross-measure continuation", async () => {
    const user = userEvent.setup();
    renderCheer();
    await reachBuilder(user, "Boundary Beat", "Keep it moving");
    await closeHowTo(user, true);

    await user.click(screen.getByRole("button", { name: "Place Action at beat 4 and three quarters" }));
    expect(screen.getByRole("button", { name: "Action Note timing Sixteenth at beat 4 and three quarters" })).toHaveTextContent("𝅘𝅥𝅯");
    await user.click(screen.getByRole("button", { name: "Action Note timing Sixteenth at beat 4 and three quarters" }));
    const tray = screen.getByRole("region", { name: "Selected choreography controls" });
    expect(within(tray).getAllByRole("button").filter((button) => /beat/.test(button.getAttribute("aria-label") ?? "")).map((button) => button.getAttribute("aria-label")?.split(",")[0])).toEqual(["Sixteenth", "Eighth", "Three Quarter", "Quarter", "One and a Quarter", "One and a Half", "Half", "Dotted Half", "Whole"]);
    await user.click(within(tray).getByRole("button", { name: "Rest" }));
    expect(screen.getByRole("button", { name: "Rest timing Sixteenth at beat 4 and three quarters" })).toHaveTextContent("𝄿");
    expect(screen.queryByRole("button", { name: "Action Clap at beat 4 and three quarters" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Place Lyric at beat 4 and three quarters" })).toBeDisabled();
    await user.click(within(tray).getByRole("button", { name: /Quarter.*1 beat/ }));

    expect(screen.getByText("Measure 2")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Rest timing Quarter at beat 1" })).toHaveTextContent("↪");
  });

  it("expands a Rest by rippling both timelines as one undoable transaction", async () => {
    const user = userEvent.setup();
    renderCheer();
    await reachBuilder(user, "Shared Rest", "Pause together");
    await closeHowTo(user, true);

    await user.click(screen.getByRole("button", { name: "Place Action at beat 1" }));
    await user.click(screen.getByRole("button", { name: "Action Note timing Eighth at beat 1" }));
    const tray = screen.getByRole("region", { name: "Selected choreography controls" });
    await user.click(within(tray).getByRole("button", { name: "Rest" }));
    await user.click(screen.getByRole("button", { name: "Place Action at beat 1 and a half" }));
    await user.click(screen.getByRole("button", { name: "Place Lyric at beat 1 and a half" }));
    await user.click(screen.getByRole("button", { name: "Rest timing Eighth at beat 1" }));
    await user.click(within(tray).getByRole("button", { name: /One and a Quarter.*1¼ beats/ }));
    const dialog = screen.getByRole("dialog", { name: "Shift following events?" });
    expect(dialog).toHaveTextContent("This change needs ¾ beat more space. Shift later events by ¾ beat?");
    await user.click(within(dialog).getByRole("button", { name: "Continue and Shift" }));
    expect(screen.getByRole("button", { name: "Action Clap at beat 2 and a quarter" })).toBeInTheDocument();
    expect(screen.getByLabelText("Lyrics at beat 2 and a quarter")).toBeInTheDocument();

    await user.click(within(tray).getByRole("button", { name: "Undo" }));
    expect(screen.getByRole("button", { name: "Action Clap at beat 1 and a half" })).toBeInTheDocument();
    expect(screen.getByLabelText("Lyrics at beat 1 and a half")).toBeInTheDocument();
    await user.click(within(tray).getByRole("button", { name: "Redo" }));
    expect(screen.getByRole("button", { name: "Action Clap at beat 2 and a quarter" })).toBeInTheDocument();
  }, 10_000);

  it("copies an exact Action into an available position and across a measure boundary", async () => {
    const user = userEvent.setup();
    renderCheer();
    await reachBuilder(user, "Copy Pattern", "Clap it out");
    await closeHowTo(user, true);

    await user.click(screen.getByRole("button", { name: "Place Action at beat 1" }));
    await user.click(screen.getByRole("button", { name: "Action Note timing Eighth at beat 1" }));
    const tray = screen.getByRole("region", { name: "Selected choreography controls" });
    await user.click(within(tray).getByRole("button", { name: /Quarter.*1 beat/ }));
    await user.click(within(tray).getByRole("button", { name: "Copy Action" }));
    expect(screen.getByRole("status")).toHaveTextContent("Copy mode");
    expect(screen.getByRole("button", { name: "Place Lyric at beat 1" })).toBeDisabled();

    await user.click(screen.getByRole("button", { name: "Paste copied Action at beat 4 and a half" }));
    expect(screen.getByText("Measure 2")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Action Clap at beat 4 and a half" })).toHaveTextContent("👏");
    expect(screen.getAllByRole("button", { name: "Action Note timing Quarter at beat 1" }).some((button) => button.textContent === "↪")).toBe(true);
    expect(within(tray).getByRole("button", { name: "Cancel Copy" })).toBeInTheDocument();
  });

  it("inserts and deletes lane timing with ten-step Undo and Redo controls", async () => {
    const user = userEvent.setup();
    renderCheer();
    await reachBuilder(user, "Ripple Editor", "Move one lane only");
    await closeHowTo(user, true);

    await user.click(screen.getByRole("button", { name: "Place Action at beat 2" }));
    const tray = screen.getByRole("region", { name: "Selected choreography controls" });
    await user.click(within(tray).getByRole("button", { name: "Insert" }));
    expect(within(tray).getByRole("button", { name: "Cancel Insert" })).toBeInTheDocument();
    await user.click(within(tray).getByRole("button", { name: "Action" }));
    await user.click(within(tray).getByRole("button", { name: /Eighth.*½ beat/ }));
    await user.click(screen.getByRole("button", { name: "Action Note timing Eighth at beat 2" }));
    expect(screen.getByRole("status")).toHaveTextContent("shifted later Actions by ½ beat");
    expect(screen.getByRole("button", { name: "Action Clap at beat 2 and a half" })).toBeInTheDocument();

    await user.click(within(tray).getByRole("button", { name: "Undo" }));
    expect(screen.queryByRole("button", { name: "Action Clap at beat 2 and a half" })).not.toBeInTheDocument();
    await user.click(within(tray).getByRole("button", { name: "Redo" }));
    expect(screen.getByRole("button", { name: "Action Clap at beat 2 and a half" })).toBeInTheDocument();
    await user.click(within(tray).getByRole("button", { name: "Undo" }));

    await user.click(screen.getByRole("button", { name: "Place Lyric at beat 2" }));
    expect(within(tray).getByRole("button", { name: "Redo" })).toBeDisabled();
    await user.click(within(tray).getByRole("button", { name: "Delete Timing" }));
    await user.click(within(tray).getByRole("button", { name: /Eighth.*½ beat/ }));
    await user.click(screen.getByRole("button", { name: "Delete timing from Action at beat 1" }));
    const dialog = screen.getByRole("dialog", { name: "Delete empty timing?" });
    expect(dialog).toHaveTextContent("shift all later Actions earlier");
    await user.click(within(dialog).getByRole("button", { name: "Delete Timing" }));
    expect(screen.getByRole("button", { name: "Action Clap at beat 1 and a half" })).toBeInTheDocument();
    expect(screen.getByLabelText("Lyrics at beat 2")).toBeInTheDocument();
  }, 10_000);

  it("offers a same-lane ripple when an edited duration exceeds its gap", async () => {
    const user = userEvent.setup();
    renderCheer();
    await reachBuilder(user, "Timing Ripple", "Grow this cue");
    await closeHowTo(user, true);

    await user.click(screen.getByRole("button", { name: "Place Action at beat 1" }));
    await user.click(screen.getByRole("button", { name: "Place Action at beat 1 and a half" }));
    await user.click(screen.getByRole("button", { name: "Action Note timing Eighth at beat 1" }));
    const tray = screen.getByRole("region", { name: "Selected choreography controls" });
    await user.click(within(tray).getByRole("button", { name: /Quarter.*1 beat/ }));
    const dialog = screen.getByRole("dialog", { name: "Shift following events?" });
    expect(dialog).toHaveTextContent("Selected timing is larger than the available space");
    expect(dialog).toHaveTextContent("shift the following Actions by ½ beat");
    await user.click(within(dialog).getByRole("button", { name: "Continue and Shift" }));
    expect(screen.getByRole("button", { name: "Action Clap at beat 2" })).toBeInTheDocument();
  });

  it("reopens a published Cheer with identity, finish metadata, lyrics, and direct placement", async () => {
    const user = userEvent.setup();
    renderCheer();
    await reachBuilder(user, "Editable Echo", "Go Patriots go");
    await closeHowTo(user, true);
    await user.click(screen.getByRole("button", { name: "Place Action at beat 2" }));
    await user.click(screen.getByRole("button", { name: "Action Clap at beat 2" }));
    await user.click(within(screen.getByRole("region", { name: "Selected choreography controls" })).getByRole("button", { name: /Wave/ }));
    await user.click(screen.getByRole("button", { name: "Original Lyrics" }));
    await user.click(screen.getByRole("button", { name: /Go Patriots go.*Use line/ }));
    await user.click(screen.getByRole("button", { name: "Finish Cheer" }));
    await user.type(screen.getByLabelText("Rivalry / Opponent"), "New York");
    await user.click(screen.getByRole("button", { name: "Publish Cheer" }));

    await user.click(screen.getByRole("button", { name: "Edit Cheer" }));
    expect(screen.getByLabelText("Title")).toHaveValue("Editable Echo");
    expect(screen.getByRole("combobox", { name: "Sport" })).toHaveValue("Football");
    await user.click(screen.getByRole("button", { name: "Continue to Lyrics" }));
    expect(screen.getByLabelText("Lyric line 1")).toHaveValue("Go Patriots go");
    await user.click(screen.getByRole("button", { name: "Build" }));
    expect(screen.getByRole("button", { name: "Action Wave at beat 2" })).toHaveTextContent("🌊");
    await user.click(screen.getByRole("button", { name: "Finish Cheer" }));
    expect(screen.getByLabelText("Rivalry / Opponent")).toHaveValue("New York");
  });

  it("locks Sport only while sport-specific WHO routing remains", async () => {
    const user = userEvent.setup();
    renderCheer();
    await reachBuilder(user, "Sport Lock", "Raise it up", "Football");
    await closeHowTo(user, true);
    await user.click(screen.getByRole("button", { name: "Place Action at beat 1" }));
    await user.click(screen.getByRole("button", { name: "Action audience All" }));
    const tray = screen.getByRole("region", { name: "Selected choreography controls" });
    await user.click(within(tray).getByRole("button", { name: "Uprights Left" }));
    await user.click(screen.getByRole("button", { name: "Finish Cheer" }));
    expect(screen.queryByRole("combobox", { name: "Sport" })).not.toBeInTheDocument();
    expect(screen.getByText("Locked by sport-specific WHO routing in this Cheer.").parentElement).toHaveTextContent("Football");

    await user.click(screen.getByRole("button", { name: /Build/ }));
    await user.click(screen.getByRole("button", { name: "Action audience Uprights Left" }));
    await user.click(within(screen.getByRole("region", { name: "Selected choreography controls" })).getByRole("button", { name: "All" }));
    expect(screen.getByRole("button", { name: "Action audience All" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Finish Cheer" }));
    expect(screen.getByRole("combobox", { name: "Sport" })).toHaveValue("Football");
    await user.selectOptions(screen.getByRole("combobox", { name: "Sport" }), "Generic");
    expect(screen.getByRole("combobox", { name: "Sport" })).toHaveValue("Generic");
  }, 10_000);

  it("restores a complete saved Cheer from persistent browser storage after remount", async () => {
    const user = userEvent.setup();
    const firstRender = renderCheer();
    await reachBuilder(user, "Persistent Echo", "Hold the line");
    await closeHowTo(user, true);
    await user.click(screen.getByRole("button", { name: "Place Action at beat 2" }));
    await user.click(screen.getByRole("button", { name: "Action audience All" }));
    await user.click(within(screen.getByRole("region", { name: "Selected choreography controls" })).getByRole("button", { name: "End A" }));
    await user.click(screen.getByRole("button", { name: "Finish Cheer" }));
    await user.selectOptions(screen.getByLabelText("League"), "football-cfl");
    await user.selectOptions(screen.getByLabelText("Team"), "football-cfl-edmonton-elks");
    await user.type(screen.getByLabelText("Rivalry / Opponent"), "Calgary");
    await user.click(screen.getByRole("button", { name: "Save Draft" }));

    await waitFor(() => expect(window.localStorage.getItem("fanatical.cheer.library")).toContain("Persistent Echo"));
    firstRender.unmount();
    renderCheer();
    await screen.findByRole("heading", { name: "Persistent Echo" });
    await user.click(screen.getByRole("button", { name: "Edit Cheer" }));
    expect(screen.getByLabelText("Title")).toHaveValue("Persistent Echo");
    await user.click(screen.getByRole("button", { name: "Continue to Lyrics" }));
    expect(screen.getByLabelText("Lyric line 1")).toHaveValue("Hold the line");
    await user.click(screen.getByRole("button", { name: "Build" }));
    expect(screen.getByRole("button", { name: "Action audience End A" }).querySelector("img")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Finish Cheer" }));
    expect(screen.getByLabelText("League")).toHaveDisplayValue("CFL");
    expect(screen.getByLabelText("Team")).toHaveDisplayValue("Edmonton Elks");
    expect(screen.getByLabelText("Rivalry / Opponent")).toHaveValue("Calgary");
  });

  it("resolves and persists a manual venue Check-In without legacy compass controls", async () => {
    const user = userEvent.setup();
    renderCheer();
    await user.click(screen.getByRole("button", { name: "Filter Cheer Library" }));
    await user.click(screen.getByRole("menuitem", { name: /Sport/ }));
    await user.click(screen.getByRole("button", { name: "Baseball" }));
    await user.click(screen.getByRole("button", { name: "Show All Baseball Cheers" }));
    expect(screen.getByRole("heading", { name: "Baseball" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Check In" }));
    const dialog = screen.getByRole("dialog", { name: "Check In" });
    expect(within(dialog).getByRole("button", { name: "Take Photo / Upload Screenshot" })).toBeInTheDocument();
    expect(within(dialog).queryByRole("button", { name: "East" })).not.toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: "Enter Manually" }));
    await user.type(within(dialog).getByLabelText(/Venue/), "Rexall Place");
    expect(within(dialog).getByLabelText(/Sport/)).toHaveValue("Hockey");
    await user.selectOptions(within(dialog).getByLabelText(/Team \/ Event/), "Edmonton Oil Kings");
    const sectionInput = within(dialog).getByLabelText(/Section/);
    expect(sectionInput).toHaveAttribute("inputmode", "numeric");
    expect(dialog.querySelector("#check-in-sections")).not.toBeInTheDocument();
    await user.type(sectionInput, "20");
    expect(within(dialog).queryByText("Choose a valid section for this venue.")).not.toBeInTheDocument();
    fireEvent.blur(sectionInput);
    expect(within(dialog).getByText("Choose a valid section for this venue.")).toBeInTheDocument();
    await user.clear(sectionInput);
    await user.type(sectionInput, "202");
    expect(within(dialog).getByRole("button", { name: "Row 12" })).toBeInTheDocument();
    expect(within(dialog).queryByText("Choose a valid section for this venue.")).not.toBeInTheDocument();
    await user.clear(sectionInput);
    await user.type(sectionInput, "999");
    expect(within(dialog).getByText("Choose a valid section for this venue.")).toBeInTheDocument();
    await user.clear(sectionInput);
    await user.type(sectionInput, "114");
    await user.click(within(dialog).getByRole("button", { name: "Row 12" }));
    expect(within(dialog).getByRole("button", { name: "Change Row, currently 12" })).toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: "Seat 8" }));
    expect(within(dialog).getByRole("button", { name: "Change Seat, currently 8" })).toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: "Review Check-In" }));
    expect(within(dialog).getByText("Section 114 · Row 12 · Seat 8")).toBeInTheDocument();
    expect(within(dialog).queryByText("Lower · Side A · End A")).not.toBeInTheDocument();
    expect(within(dialog).queryByText("Rules used")).not.toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: "Confirm Check-In" }));
    expect(JSON.parse(window.localStorage.getItem("fanatical.cheer.check-in.v2") ?? "{}")).toMatchObject({
      raw: { venueName: "Rexall Place", sport: "Hockey", teamEvent: "Edmonton Oil Kings", section: "114", row: "12", seat: "8" },
      resolved: { level: "Lower", side: "Side A", end: "End A" },
    });
    expect(screen.getByRole("heading", { name: "Available Now" })).toBeInTheDocument();
    const checkInControl = screen.getByRole("button", { name: /Change Check In/ });
    expect(checkInControl).toHaveTextContent("Sec 114 · R12 · S8");
    await user.click(checkInControl);
    expect(screen.getByRole("button", { name: "Edit" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Check Out" })).toBeInTheDocument();
    await user.click(within(screen.getByRole("dialog", { name: "Check In" })).getByRole("button", { name: "Close Check In" }));
    expect(screen.queryByRole("status")).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Filter Cheer Library" }));
    await user.click(screen.getByRole("menuitemradio", { name: "All" }));
    await user.click(within(screen.getByRole("heading", { name: "D-Fence Clap Clap" }).closest("article")!).getByRole("button", { name: "Follow" }));
    expect(screen.getByRole("heading", { name: "Follow", level: 1 })).toBeInTheDocument();
    expect(screen.getByRole("region", { name: "Follow choreography" })).toHaveTextContent("CurrentMeasure 1");
    expect(screen.getByRole("region", { name: "Follow choreography" })).toHaveTextContent("NextMeasure 2");
    expect(screen.getAllByText("ACTION TIMING")).toHaveLength(2);
    expect(screen.getAllByText("LYRIC TIMING")).toHaveLength(2);
    expect(within(screen.getByRole("article", { name: "Next Measure 2" })).getAllByText("𝄽")).toHaveLength(2);
    expect(screen.getByText("Practice player · 60 BPM")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Play" }));
    expect(screen.getByRole("status")).toHaveTextContent("3Get ready");
  });

  it("accepts ticket images through the provider-neutral Check-In path", async () => {
    const user = userEvent.setup();
    renderCheer();
    await user.click(screen.getByRole("button", { name: "Check In" }));
    const dialog = screen.getByRole("dialog", { name: "Check In" });
    await user.click(within(dialog).getByRole("button", { name: "Take Photo / Upload Screenshot" }));
    expect(within(dialog).getByText("Ticket recognition is not enabled yet.")).toBeInTheDocument();
    const file = new File(["ticket"], "oilers-ticket.png", { type: "image/png" });
    await user.upload(within(dialog).getByLabelText("Ticket file"), file);
    expect(within(dialog).getByText("oilers-ticket.png")).toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: "Continue to Confirm / Edit" }));
    expect(within(dialog).getByRole("heading", { name: "Confirm / Edit ticket details" })).toBeInTheDocument();
  });

  it("checks into a shared general location with All-only routing", async () => {
    const user = userEvent.setup();
    renderCheer();
    await user.click(screen.getByRole("button", { name: "Check In" }));
    const dialog = screen.getByRole("dialog", { name: "Check In" });
    await user.click(within(dialog).getByRole("button", { name: "Choose General Location" }));
    await user.type(within(dialog).getByLabelText("Named location"), "Sir Winston Churchill Square");
    await user.click(within(dialog).getByRole("button", { name: "Review Location" }));
    expect(within(dialog).getByText("Whole crowd")).toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: "Confirm Check-In" }));
    expect(JSON.parse(window.localStorage.getItem("fanatical.cheer.check-in.v2") ?? "{}")).toMatchObject({ type: "GeneralLocation", location: { id: "location-churchill-square", contextKey: "edmonton:churchill-square" }, routing: { mode: "AllOnly" } });
    expect(screen.getByRole("button", { name: /Change Check In/ })).toHaveTextContent("Sir Winston Churchill Square");
  });

  it("keeps unsupported-language lyrics buildable without syllable estimates", async () => {
    const user = userEvent.setup();
    renderCheer();
    await user.click(screen.getByRole("button", { name: "Add Cheer" }));
    await user.type(screen.getByLabelText("Title"), "国际加油");
    await user.click(screen.getByRole("button", { name: "Continue to Lyrics" }));
    await user.selectOptions(screen.getByLabelText("Language"), "Other");
    await user.type(screen.getByLabelText("Lyric line 1"), "加油 球队");
    expect(screen.queryByText(/≈/)).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Build" }));
    expect(screen.getByRole("heading", { name: "国际加油" })).toBeInTheDocument();
  });
});
