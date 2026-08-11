import { render, screen, waitFor, within } from "@testing-library/react";
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

    expect(screen.getByRole("heading", { name: "Cheer", level: 1 })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "D-Fence Clap Clap" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Read" }));
    expect(screen.getByRole("heading", { name: "Read", level: 1 })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "D-Fence Clap Clap", level: 2 }).closest("main")).toHaveTextContent("D-Fence");
    await user.click(screen.getByRole("button", { name: /Cheer Library/ }));
    await user.click(screen.getByRole("button", { name: "Listen" }));
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

  it("places independent events directly, exposes rhythmic controls, and publishes through Finish Cheer", async () => {
    const user = userEvent.setup();
    renderCheer();
    await reachBuilder(user);
    expect(screen.queryByLabelText("Tempo BPM")).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Record" })).toBeInTheDocument();

    const teachingDialog = screen.getByRole("dialog", { name: "One Cheer, five creator lanes" });
    expect(teachingDialog).toHaveTextContent("👏");
    expect(teachingDialog).toHaveTextContent("West");
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
    expect(within(tray).getByRole("button", { name: "Uprights Left" })).toBeInTheDocument();
    expect(within(tray).getByRole("button", { name: "Uprights Right" })).toBeInTheDocument();
    await user.click(within(tray).getByRole("button", { name: "East" }));
    expect(screen.getByRole("button", { name: "Action audience East" })).toHaveTextContent("East");

    await user.click(screen.getByRole("button", { name: "Finish Cheer" }));
    expect(screen.getByRole("heading", { name: "Finish Cheer", level: 2 })).toBeInTheDocument();
    expect(screen.getByText("Selected when this Cheer was created").parentElement).toHaveTextContent("SportFootball");
    expect(screen.queryByRole("combobox", { name: /Sport/ })).not.toBeInTheDocument();
    expect(screen.getByLabelText("Team")).toHaveValue("");
    await user.type(screen.getByLabelText("Short description / instruction"), "Raise the noise on third down.");
    await user.click(screen.getByRole("button", { name: "Publish Cheer" }));
    expect(screen.getByRole("heading", { name: "North End Echo" })).toBeInTheDocument();
    expect(screen.getByText("Raise the noise on third down.")).toBeInTheDocument();
    expect(screen.getByText(/Published · Echo/)).toBeInTheDocument();
  });

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
    expect(within(tray).getAllByRole("button").filter((button) => /beat/.test(button.getAttribute("aria-label") ?? "")).map((button) => button.getAttribute("aria-label")?.split(",")[0])).toEqual(["Sixteenth", "Eighth", "Quarter", "Half", "Dotted Half", "Whole"]);
    await user.click(within(tray).getByRole("button", { name: "Rest" }));
    expect(screen.getByRole("button", { name: "Rest timing Sixteenth at beat 4 and three quarters" })).toHaveTextContent("𝄿");
    expect(screen.queryByRole("button", { name: "Action Clap at beat 4 and three quarters" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Place Lyric at beat 4 and three quarters" })).toBeDisabled();
    await user.click(within(tray).getByRole("button", { name: /Quarter.*1 beat/ }));

    expect(screen.getByText("Measure 2")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Rest timing Quarter at beat 1" })).toHaveTextContent("↪");
  });

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
    expect(screen.getByText("Sport-specific choreography stays locked to this Cheer.").parentElement).toHaveTextContent("Football");
    expect(screen.queryByRole("combobox", { name: "Sport" })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Continue to Lyrics" }));
    expect(screen.getByLabelText("Lyric line 1")).toHaveValue("Go Patriots go");
    await user.click(screen.getByRole("button", { name: "Build" }));
    expect(screen.getByRole("button", { name: "Action Wave at beat 2" })).toHaveTextContent("🌊");
    await user.click(screen.getByRole("button", { name: "Finish Cheer" }));
    expect(screen.getByLabelText("Rivalry / Opponent")).toHaveValue("New York");
  });

  it("restores a complete saved Cheer from persistent browser storage after remount", async () => {
    const user = userEvent.setup();
    const firstRender = renderCheer();
    await reachBuilder(user, "Persistent Echo", "Hold the line");
    await closeHowTo(user, true);
    await user.click(screen.getByRole("button", { name: "Place Action at beat 2" }));
    await user.click(screen.getByRole("button", { name: "Action audience All" }));
    await user.click(within(screen.getByRole("region", { name: "Selected choreography controls" })).getByRole("button", { name: "West" }));
    await user.click(screen.getByRole("button", { name: "Finish Cheer" }));
    await user.type(screen.getByLabelText("Team"), "Edmonton Elks");
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
    expect(screen.getByRole("button", { name: "Action audience West" })).toHaveTextContent("West");
    await user.click(screen.getByRole("button", { name: "Finish Cheer" }));
    expect(screen.getByLabelText("Team")).toHaveValue("Edmonton Elks");
    expect(screen.getByLabelText("Rivalry / Opponent")).toHaveValue("Calgary");
  });

  it("keeps manual Check In session state without a temporary Library notice", async () => {
    const user = userEvent.setup();
    renderCheer();
    await user.click(screen.getByRole("button", { name: "Check In" }));
    const dialog = screen.getByRole("dialog", { name: "Check In" });
    await user.click(within(dialog).getByRole("button", { name: "Lower" }));
    await user.click(within(dialog).getByRole("button", { name: "West" }));
    await user.click(within(dialog).getByRole("button", { name: "South" }));
    await user.click(within(dialog).getByRole("button", { name: "Save Check In" }));
    expect(JSON.parse(window.sessionStorage.getItem("fanatical.cheer.check-in") ?? "{}")).toEqual({ level: "Lower", eastWest: "West", northSouth: "South" });
    expect(screen.queryByRole("status")).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Follow" }));
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
