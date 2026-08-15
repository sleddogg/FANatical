import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createMemoryRouter, RouterProvider } from "react-router-dom";
import { describe, expect, it } from "vitest";
import { appRoutes } from "../../app/routes";

function renderRoute(route = "/fanbase") {
  const router = createMemoryRouter(appRoutes, { initialEntries: [route] });
  return { router, ...render(<RouterProvider router={router} />) };
}

describe("FANbase frontend", () => {
  it("renders the FANbase areas in the required order", () => {
    renderRoute();

    const hub = screen.getByRole("region", { name: "FANbase areas" });
    const titles = Array.from(hub.querySelectorAll(".fanbase-hub-card strong")).map((element) => element.textContent);
    expect(titles).toEqual([
      "Article Discussions",
      "Locker Room",
      "Game Threads",
      "Fan Photos",
      "Events",
      "Groups",
      "Polls",
      "Leaderboards",
    ]);
    expect(screen.getByText("New England Patriots fan community")).toBeInTheDocument();
  });

  it("opens Polls on the current FANbase team's unanswered Active queue", async () => {
    const user = userEvent.setup();
    renderRoute();

    await user.click(screen.getByRole("button", { name: /Polls.*Vote on trending questions/i }));

    expect(screen.getByRole("heading", { name: "Polls", level: 1 })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "New England Patriots" })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: "Active" })).toHaveAttribute("aria-selected", "true");
    expect(document.querySelectorAll(".poll-card")).toHaveLength(10);
  });

  it("records a Poll vote, reveals results, and exposes Browse search", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=polls");

    const poll = screen.getByRole("heading", { name: "Which unit will define the Patriots' season?" }).closest("article");
    expect(poll).not.toBeNull();
    await user.click(within(poll as HTMLElement).getByRole("button", { name: "Defense" }));
    expect(within(poll as HTMLElement).getByText("Your vote", { exact: false })).toBeInTheDocument();

    await user.click(screen.getByRole("tab", { name: "Browse" }));
    const search = screen.getByRole("searchbox", { name: "Search Polls" });
    await user.type(search, "playoff push");
    expect(screen.getByRole("heading", { name: "How confident are you in the playoff push?" })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Which offensive identity should New England lean into?" })).not.toBeInTheDocument();
  });

  it("browses an exact official League Poll scope outside the current FANbase", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=polls");

    await user.click(screen.getByRole("button", { name: "Change Poll scope" }));
    let dialog = screen.getByRole("dialog", { name: "Pick a Sport" });
    await user.click(within(dialog).getByRole("button", { name: /Hockey.*Browse polls/i }));
    dialog = screen.getByRole("dialog", { name: "Pick a League" });
    await user.click(within(dialog).getByRole("button", { name: /NHL.*League or team polls/i }));
    dialog = screen.getByRole("dialog", { name: "Pick a Team" });
    await user.click(within(dialog).getByRole("button", { name: "Show NHL polls" }));

    expect(screen.getByRole("heading", { name: "NHL" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Should the NHL change its playoff format?" })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: /Oilers offseason moves/i })).not.toBeInTheDocument();
  });

  it("creates a team-scoped Poll with generated topic metadata", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=polls");

    await user.click(screen.getByRole("button", { name: "Create Poll" }));
    const dialog = screen.getByRole("dialog", { name: "Create Poll" });
    await user.type(within(dialog).getByRole("textbox", { name: "Poll question" }), "Which rookie makes the biggest impact?");
    await user.type(within(dialog).getByRole("textbox", { name: "Option 1" }), "Quarterback");
    await user.type(within(dialog).getByRole("textbox", { name: "Option 2" }), "Receiver");
    await user.type(within(dialog).getByRole("textbox", { name: "Option 3" }), "Cornerback");
    await user.type(within(dialog).getByRole("textbox", { name: "Option 4" }), "Pass rusher");
    await user.click(within(dialog).getByRole("button", { name: "Publish Poll" }));

    expect(screen.getByRole("heading", { name: "Which rookie makes the biggest impact?" })).toBeInTheDocument();
    expect(screen.getByText("One canonical Poll record", { exact: false })).toBeInTheDocument();
  });

  it("uses the team-only filter and updates the global selected team", async () => {
    const user = userEvent.setup();
    renderRoute();

    await user.click(screen.getByRole("button", { name: "Choose FANbase team" }));
    const filter = screen.getByRole("dialog", { name: "Choose a followed team" });
    expect(within(filter).queryByText("League")).not.toBeInTheDocument();
    expect(within(filter).queryByText("Sport")).not.toBeInTheDocument();
    await user.click(within(filter).getByRole("button", { name: /Boston Celtics/i }));

    expect(screen.getByText("Boston Celtics fan community")).toBeInTheDocument();
    await user.click(screen.getByRole("link", { name: "FANatical home" }));
    expect(screen.getByRole("button", { name: "Select Boston Celtics" })).toHaveAttribute("aria-pressed", "true");
  });

  it("creates a Locker Room thread in the selected team's canonical list", async () => {
    const user = userEvent.setup();
    renderRoute();

    await user.click(screen.getByRole("button", { name: "Create in FANbase" }));
    const createDialog = screen.getByRole("dialog", { name: "Create in FANbase" });
    await user.click(within(createDialog).getByRole("button", { name: /Locker Room thread/i }));
    await user.type(within(createDialog).getByRole("textbox", { name: "Thread title" }), "Best third-down package");
    await user.type(within(createDialog).getByRole("textbox", { name: "Opening post" }), "Which personnel grouping gives the offense the cleanest answer?");
    await user.click(within(createDialog).getByRole("button", { name: "Create Locker Room thread" }));

    expect(screen.getByRole("heading", { name: "Best third-down package" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Back to Locker Room" }));
    expect(screen.getByRole("button", { name: /Best third-down package/i })).toBeInTheDocument();
  });

  it("uses the area name, context, and Back control as the only subpage header", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=article-comments");

    expect(screen.getAllByRole("heading", { name: "Article Discussions" })).toHaveLength(1);
    expect(screen.queryByRole("heading", { name: "FANbase" })).not.toBeInTheDocument();
    expect(screen.getByText("New England Patriots News discussions")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Choose FANbase team" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Article Discussions are created from News Items" })).toBeDisabled();

    await user.click(screen.getByRole("button", { name: "Back to FANbase" }));
    expect(screen.getByRole("heading", { name: "FANbase" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Choose FANbase team" })).toBeInTheDocument();
  });

  it("opens the contextual Locker Room form directly", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=locker-room");

    await user.click(screen.getByRole("button", { name: "Create Locker Room thread" }));
    const dialog = screen.getByRole("dialog", { name: "Locker Room thread" });
    expect(within(dialog).getByRole("textbox", { name: "Thread title" })).toBeInTheDocument();
    expect(within(dialog).queryByRole("button", { name: /Creation options/i })).not.toBeInTheDocument();
  });

  it("uses the compact composer-first layout for an opened Locker Room topic", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=locker-room&item=locker-pats-play-action");

    const topicTitle = "Which play-action package should lead the opening drive?";
    expect(screen.getAllByRole("heading", { name: topicTitle })).toHaveLength(1);
    expect(screen.queryByRole("link", { name: /View News Item/i })).not.toBeInTheDocument();

    const composer = screen.getByRole("textbox", { name: "Add to the conversation" }).closest("form");
    const conversationHeading = screen.getByRole("heading", { name: "Conversation" });
    expect(composer).not.toBeNull();
    expect(composer!.compareDocumentPosition(conversationHeading) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();

    await user.click(screen.getByRole("button", { name: "Choose topic reaction" }));
    await user.click(screen.getByRole("menuitemradio", { name: "Fire, 8 reactions" }));
    expect(screen.getByRole("button", { name: "Choose topic reaction" })).toHaveTextContent("Fire · 35");

    await user.click(screen.getByRole("button", { name: "Share" }));
    expect(screen.getByRole("status")).toHaveTextContent("Sharing is represented as a local frontend placeholder.");
    expect(screen.getByRole("button", { name: "Like, 6 reactions" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Reply" })).toBeInTheDocument();
  });

  it("keeps Game Thread creation disabled because games schedule those threads", () => {
    renderRoute("/fanbase?area=game-threads");

    expect(screen.getByRole("heading", { name: "Game Threads" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Game Threads are created from scheduled games and events" })).toBeDisabled();
  });

  it("keeps the Game Threads list organized with actual team names", () => {
    renderRoute("/fanbase?area=game-threads");

    expect(screen.getByText("Live")).toBeInTheDocument();
    expect(screen.getAllByText("Scheduled").length).toBeGreaterThan(0);
    expect(screen.getByText("Post-Game")).toBeInTheDocument();
    expect(screen.getByText("Archived")).toBeInTheDocument();
    expect(screen.queryByText("Selected Team", { exact: false })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: /New England Patriots.*New York Jets/i })).toBeInTheDocument();
  });

  it("uses one Game Thread context card followed by the composer and a populated conversation", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=game-threads&item=game-pats-jets");

    const matchup = "New England Patriots vs. New York Jets";
    expect(screen.getAllByRole("heading", { name: matchup })).toHaveLength(1);
    expect(screen.getByText("Pregame, live, and post-game conversation")).toBeInTheDocument();
    expect(screen.getByText("Gillette Stadium")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Choose.*reaction/i })).not.toBeInTheDocument();

    const composer = screen.getByRole("textbox", { name: "Add to the conversation" }).closest("form");
    const conversationHeading = screen.getByRole("heading", { name: "Conversation" });
    const predictor = screen.getByRole("region", { name: "Call the final score" });
    const gameContext = screen.getByText("Gillette Stadium").closest("article");
    expect(composer).not.toBeNull();
    expect(gameContext).not.toBeNull();
    expect(gameContext!.compareDocumentPosition(predictor) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(predictor.compareDocumentPosition(conversationHeading) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(composer!.compareDocumentPosition(conversationHeading) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(screen.getAllByRole("article").filter((article) => article.classList.contains("community-comment"))).toHaveLength(6);
    expect(screen.getAllByRole("button", { name: /Like, .* reactions/i }).length).toBeGreaterThan(0);

    await user.click(screen.getByRole("button", { name: "Share" }));
    expect(screen.getByRole("status")).toHaveTextContent("Sharing is represented as a local frontend placeholder.");
  });

  it("submits and locks a sport-specific pregame prediction", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=game-threads&item=game-pats-next");

    const predictor = screen.getByRole("region", { name: "Call the final score" });
    await user.type(within(predictor).getByRole("spinbutton", { name: "New England Patriots" }), "27");
    await user.type(within(predictor).getByRole("spinbutton", { name: "Buffalo Bills" }), "20");
    expect(within(predictor).getByRole("button", { name: "Tie" })).toBeInTheDocument();
    await user.click(within(predictor).getByRole("button", { name: "Lock Prediction" }));

    expect(within(predictor).getByText("Your prediction is locked")).toBeInTheDocument();
    expect(within(predictor).getByText(/New England Patriots 27–20 Buffalo Bills/)).toBeInTheDocument();
  });

  it("resolves a completed prediction with absolute errors, Rating, Percentile, and exact-score recognition", () => {
    renderRoute("/fanbase?area=game-threads&item=game-pats-recent");

    const predictor = screen.getByRole("region", { name: "Call the final score" });
    expect(within(predictor).getByLabelText("Final score")).toHaveTextContent("24");
    expect(within(predictor).getByText("New England Patriots error").parentElement).toHaveTextContent("11");
    expect(within(predictor).getByText("Buffalo Bills error").parentElement).toHaveTextContent("11");
    expect(within(predictor).getByText("Total Score Error").parentElement).toHaveTextContent("22");
    expect(within(predictor).getByText("Predictor Rating").parentElement).toHaveTextContent(/\d+/);
    expect(within(predictor).getByText("Football Predictor").parentElement).toHaveTextContent("percentile");
    expect(within(predictor).getByText("Maya84").closest("span")).toHaveTextContent("24–21");
    expect(within(predictor).getByRole("heading", { name: "CALLED IT" })).toBeInTheDocument();
  });

  it.each([
    ["fan-photos", "Add Fan Photo", "Fan Photo"],
    ["events", "Create Event", "Event"],
    ["groups", "Create Group", "Group"],
  ])("opens the contextual %s creation form directly", async (area, actionName, dialogName) => {
    const user = userEvent.setup();
    renderRoute(`/fanbase?area=${area}`);

    await user.click(screen.getByRole("button", { name: actionName }));
    expect(screen.getByRole("dialog", { name: dialogName })).toBeInTheDocument();
  });

  it("uses a compact event-type tag without the generic detail icon", () => {
    renderRoute("/fanbase?area=events&item=event-pats-watch");

    const eventHeadings = screen.getAllByRole("heading", { name: "Opening Night Watch Party" });
    expect(eventHeadings).toHaveLength(2);
    expect(eventHeadings.some((heading) => heading.tagName === "H1")).toBe(true);
    const detail = eventHeadings.find((heading) => heading.closest("article"))?.closest("article");
    expect(detail).not.toBeNull();
    expect(within(detail as HTMLElement).getByText("Watch Party")).toHaveClass("fanbase-event-detail__type");
    expect((detail as HTMLElement).querySelector(".fanbase-detail-card__glyph")).not.toBeInTheDocument();
    expect(within(detail as HTMLElement).getByText("Harbor Street Social · Boston")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Back to Events" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Invite/Add People to event" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Create Event" })).not.toBeInTheDocument();
  });

  it("invites additional mock connections from an Event detail", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=events&item=event-pats-watch");

    await user.click(screen.getByRole("button", { name: "Invite/Add People to event" }));
    let dialog = screen.getByRole("dialog", { name: "Invite/Add People" });
    let search = within(dialog).getByRole("searchbox", { name: "Search connections" });
    await user.type(search, "Green");
    await user.click(within(dialog).getByRole("checkbox", { name: /GreenLine/i }));
    expect(within(dialog).getByRole("button", { name: "Remove GreenLine from selection" })).toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: "Send invitations" }));

    await user.click(screen.getByRole("button", { name: "Invite/Add People to event" }));
    dialog = screen.getByRole("dialog", { name: "Invite/Add People" });
    search = within(dialog).getByRole("searchbox", { name: "Search connections" });
    await user.type(search, "Green");
    expect(within(dialog).getByRole("checkbox", { name: /GreenLine.*Already invited/i })).toBeDisabled();
  });

  it("searches and selects multiple mock connections before creating an Event", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=events");

    await user.click(screen.getByRole("button", { name: "Create Event" }));
    const dialog = screen.getByRole("dialog", { name: "Event" });
    await user.type(within(dialog).getByRole("textbox", { name: "Event title" }), "Film Room Meetup");
    await user.type(within(dialog).getByLabelText("Date and time"), "2026-08-20T19:00");
    await user.type(within(dialog).getByRole("textbox", { name: "Location or online label" }), "North End Fan Club");
    await user.type(within(dialog).getByRole("textbox", { name: "Description" }), "A local meetup to compare preseason notes.");
    await user.click(within(dialog).getByRole("button", { name: "Choose fans" }));

    const search = within(dialog).getByRole("searchbox", { name: "Search connections" });
    await user.type(search, "Maya");
    await user.click(within(dialog).getByRole("checkbox", { name: /Maya84/i }));
    await user.clear(search);
    await user.type(search, "Road");
    await user.click(within(dialog).getByRole("checkbox", { name: /RoadGameRob/i }));

    expect(within(dialog).getByRole("button", { name: "Remove Maya84 from invites" })).toBeInTheDocument();
    expect(within(dialog).getByRole("button", { name: "Remove RoadGameRob from invites" })).toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: "Create Event" }));

    expect(screen.getAllByRole("heading", { name: "Film Room Meetup" })).toHaveLength(2);
    expect(screen.getByText("North End Fan Club")).toBeInTheDocument();
  });

  it("selects optional invitees before creating a Group", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=groups");

    await user.click(screen.getByRole("button", { name: "Create Group" }));
    const dialog = screen.getByRole("dialog", { name: "Group" });
    await user.type(within(dialog).getByRole("textbox", { name: "Group name" }), "Fourth Quarter Club");
    await user.selectOptions(within(dialog).getByRole("combobox", { name: "Visibility" }), "Invite Only");
    await user.type(within(dialog).getByRole("textbox", { name: "Description" }), "A focused place for late-game strategy talk.");
    await user.click(within(dialog).getByRole("button", { name: "Choose fans" }));
    const selector = within(dialog).getByRole("group", { name: "Mock FANatical friends and connections" });
    await user.click(within(selector).getByRole("checkbox", { name: /Maya84/i }));
    await user.click(within(selector).getByRole("checkbox", { name: /GreenLine/i }));
    expect(within(dialog).getByRole("button", { name: "Remove Maya84 from invites" })).toBeInTheDocument();
    expect(within(dialog).getByRole("button", { name: "Remove GreenLine from invites" })).toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: "Create Group" }));

    expect(screen.getByRole("heading", { name: "Fourth Quarter Club" })).toBeInTheDocument();
    expect(screen.getByText("Invite Only")).toBeInTheDocument();
    expect(screen.getByText("2 pending invites")).toBeInTheDocument();
  });

  it("uses the group name header and keeps the composer below the conversation", () => {
    renderRoute("/fanbase?area=groups&item=group-pats-road-crew");

    expect(screen.getAllByRole("heading", { name: "New England Road Crew" })).toHaveLength(1);
    expect(screen.queryByRole("heading", { name: "Groups" })).not.toBeInTheDocument();
    expect(screen.getByText("Away-game travel plans, ticket tips, and meetup coordination.")).toBeInTheDocument();
    expect(screen.getByText("318 members")).toBeInTheDocument();
    expect(screen.getByText("Owner · Joined")).toBeInTheDocument();
    expect(document.querySelector(".community-thread__lead")).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Manage group membership" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Create Group" })).not.toBeInTheDocument();

    const conversationHeading = screen.getByRole("heading", { name: "Conversation" });
    const composer = screen.getByRole("textbox", { name: "Add to the conversation" }).closest("form");
    expect(composer).not.toBeNull();
    expect(conversationHeading.compareDocumentPosition(composer!) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  });

  it("uses role-aware local group membership actions", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=groups&item=group-pats-road-crew");

    await user.click(screen.getByRole("button", { name: "Manage group membership" }));
    let dialog = screen.getByRole("dialog", { name: "Group membership" });
    expect(within(dialog).getByRole("button", { name: "Invite/Add People" })).toBeInTheDocument();
    expect(within(dialog).getByRole("button", { name: "Add as Moderator" })).toBeInTheDocument();
    let search = within(dialog).getByRole("searchbox", { name: "Search connections" });
    await user.type(search, "Fenway");
    await user.click(within(dialog).getByRole("checkbox", { name: /FenwayFaithful/i }));
    expect(within(dialog).getByRole("button", { name: "Remove FenwayFaithful from selection" })).toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: "Send invitations" }));
    expect(screen.getByText("1 pending invites")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Manage group membership" }));
    dialog = screen.getByRole("dialog", { name: "Group membership" });
    await user.click(within(dialog).getByRole("button", { name: "Add as Moderator" }));
    search = within(dialog).getByRole("searchbox", { name: "Search connections" });
    await user.type(search, "Maya");
    await user.click(within(dialog).getByRole("checkbox", { name: /Maya84/i }));
    await user.click(within(dialog).getByRole("button", { name: "Add moderators" }));

    await user.click(screen.getByRole("button", { name: "Manage group membership" }));
    dialog = screen.getByRole("dialog", { name: "Group membership" });
    await user.click(within(dialog).getByRole("button", { name: "Add as Moderator" }));
    search = within(dialog).getByRole("searchbox", { name: "Search connections" });
    await user.type(search, "Maya");
    expect(within(dialog).getByRole("checkbox", { name: /Maya84.*Already a moderator/i })).toBeDisabled();
  });

  it("centers one Fan Photo category with both neighboring categories secondary", async () => {
    const user = userEvent.setup();
    const { router } = renderRoute("/fanbase?area=fan-photos");

    expect(screen.getByText("Game Face, Fan Cave, and Memorabilia")).toBeInTheDocument();
    expect(screen.getByText("Swipe or select a category to browse, rate, and celebrate how fans show up.")).toBeInTheDocument();
    expect(screen.queryByText("Explore FANfotos")).not.toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Choose a category" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Open Fan Cave Fan Photos" })).toHaveAttribute("aria-current", "true");
    expect(screen.getByRole("button", { name: "Open Game Face Fan Photos" })).not.toHaveAttribute("aria-current");
    expect(screen.getByRole("button", { name: "Open Memorabilia Fan Photos" })).not.toHaveAttribute("aria-current");

    await user.click(screen.getByRole("button", { name: "Open Game Face Fan Photos" }));
    expect(router.state.location.search).toBe("?area=fan-photos");
    expect(screen.getByRole("button", { name: "Open Game Face Fan Photos" })).toHaveAttribute("aria-current", "true");
    await user.click(screen.getByRole("button", { name: "Open Game Face Fan Photos" }));
    expect(router.state.location.search).toContain("category=Game+Face");
  });

  it("uses an unrated visual queue and replaces a FANfoto after a half-star rating", async () => {
    const user = userEvent.setup();
    const { router } = renderRoute("/fanbase?area=fan-photos&category=Game%20Face");

    expect(screen.getByRole("heading", { name: "Game Face" })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Fan Photos" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Back to Fan Photos" })).toBeInTheDocument();
    const queue = screen.getByRole("region", { name: "Photos to Rate" });
    expect(within(queue).getByText("Ready before sunrise")).toBeInTheDocument();
    const readyCard = within(queue).getByRole("button", { name: "Open Ready before sunrise" }).closest("article");
    expect(readyCard).not.toBeNull();
    expect(within(readyCard as HTMLElement).getByText("@Maya84")).toBeInTheDocument();
    expect(within(queue).queryByText(/ratings/i)).not.toBeInTheDocument();
    expect(within(queue).queryByRole("group", { name: /Rate Ready before sunrise/i })).not.toBeInTheDocument();

    await user.click(within(queue).getByRole("button", { name: "Open Ready before sunrise" }));
    expect(router.state.location.search).toContain("origin=rating-queue");
    let viewer = screen.getByRole("dialog", { name: "Ready before sunrise" });
    expect(within(viewer).getByRole("button", { name: "Rate this FANfoto to unlock details" })).toBeDisabled();
    expect(viewer.querySelectorAll(".fan-photo-star-rating__star")).toHaveLength(5);

    await user.click(within(viewer).getByRole("button", { name: "Close FANfoto" }));
    expect(within(queue).getByText("Ready before sunrise")).toBeInTheDocument();
    await user.click(within(queue).getByRole("button", { name: "Open Ready before sunrise" }));
    viewer = screen.getByRole("dialog", { name: "Ready before sunrise" });
    await user.click(within(viewer).getByRole("button", { name: "Rate 4.5 out of 5" }));
    expect(within(viewer).getByRole("button", { name: "Flip" })).toBeEnabled();
    await user.click(within(viewer).getByRole("button", { name: "Close FANfoto" }));

    expect(within(queue).queryByText("Ready before sunrise")).not.toBeInTheDocument();
    expect(within(queue).getByText("Sunday alter ego")).toBeInTheDocument();
    const rankings = screen.getByRole("region", { name: "Rankings" });
    await user.click(within(rankings).getByRole("button", { name: "Show Team rankings for Patriots" }));
    const ratedRow = within(rankings).getByRole("button", { name: "Open Ready before sunrise" }).closest("tr");
    expect(ratedRow).not.toBeNull();
    expect(within(ratedRow as HTMLElement).getByLabelText("Rated 4.5 out of 5")).toHaveTextContent("✓");
  });

  it("moves across ranking columns around the same FANfoto and jumps to the active rank 1", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=fan-photos&category=Game%20Face");

    const rankings = screen.getByRole("region", { name: "Rankings" });
    expect(within(rankings).getByRole("button", { name: "Show Personal rankings for You" })).toHaveAttribute("aria-pressed", "true");
    expect(within(rankings).getByRole("button", { name: "Show Team rankings for Patriots" })).toBeInTheDocument();
    expect(within(rankings).getByRole("button", { name: "Show League rankings for NFL" })).toBeInTheDocument();
    expect(within(rankings).getByRole("button", { name: "Show Sport rankings for Football" })).toBeInTheDocument();
    expect(within(rankings).getByRole("button", { name: "View The lucky game-day fit at Personal rank 1" })).toBeInTheDocument();
    expect(within(rankings).getByRole("button", { name: "View All in from the stands at Personal rank 2" })).toBeInTheDocument();
    expect(within(rankings).getByRole("button", { name: "View The lucky game-day fit at Team rank 75" })).toBeInTheDocument();
    expect(within(rankings).getByRole("button", { name: "View The lucky game-day fit at League rank 174" })).toBeInTheDocument();
    expect(within(rankings).getByRole("button", { name: "View The lucky game-day fit at Sport rank 541" })).toBeInTheDocument();
    expect(within(rankings).getByRole("button", { name: "View The lucky game-day fit at Global rank 795" })).toBeInTheDocument();

    await user.click(within(rankings).getByRole("button", { name: "View The lucky game-day fit at Team rank 75" }));
    expect(within(rankings).getByRole("button", { name: "Show Team rankings for Patriots" })).toHaveAttribute("aria-pressed", "true");
    expect(within(rankings).getByRole("button", { name: "View Ready before sunrise at Team rank 74" })).toBeInTheDocument();
    expect(within(rankings).getByRole("button", { name: "View All in from the stands at Team rank 76" })).toBeInTheDocument();
    expect(within(rankings).getByRole("button", { name: "View Double coverage at Team rank 77" })).toBeInTheDocument();
    expect(within(rankings).getByRole("button", { name: "Jump to Team rank 1" })).toBeInTheDocument();
    expect(within(rankings).getByRole("button", { name: "Open The lucky game-day fit" }).closest("tr")).toHaveAttribute("data-focused", "true");

    await user.click(within(rankings).getByRole("button", { name: "Jump to Team rank 1" }));
    expect(within(rankings).queryByRole("button", { name: "Jump to Team rank 1" })).not.toBeInTheDocument();
    expect(within(rankings).getByRole("button", { name: "Open Built for kickoff" }).closest("tr")).toHaveAttribute("data-focused", "true");
    expect(rankings.querySelector(".fan-photo-ranking-viewport")).toBeInTheDocument();
  });

  it("keeps local Fan Photo creation connected to the chosen category and shared record", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=fan-photos&category=Fan%20Cave");

    await user.click(screen.getByRole("button", { name: "Add Fan Photo" }));
    const createDialog = screen.getByRole("dialog", { name: "Fan Photo" });
    await user.type(within(createDialog).getByRole("textbox", { name: "Photo title" }), "Our new watch room");
    await user.selectOptions(within(createDialog).getByRole("combobox", { name: "Category" }), "Fan Cave");
    await user.type(within(createDialog).getByRole("textbox", { name: "Details" }), "Built together over three offseasons.");
    await user.click(within(createDialog).getByRole("button", { name: "Create Fan Photo" }));

    const viewer = screen.getByRole("dialog", { name: "Our new watch room" });
    await user.click(within(viewer).getByRole("button", { name: "Flip" }));
    expect(within(viewer).getByText("Built together over three offseasons.")).toBeInTheDocument();
    await user.click(within(viewer).getByRole("button", { name: "Close FANfoto" }));
    expect(screen.queryByRole("heading", { name: "Your Photos" })).not.toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Rankings" })).toBeInTheDocument();
  });

  it("demonstrates the 24-hour Game Thread lock", async () => {
    const user = userEvent.setup();
    renderRoute();

    await user.click(screen.getByRole("button", { name: /Game Threads/i }));
    await user.click(screen.getByRole("button", { name: /Miami Dolphins/i }));

    expect(screen.getByText("This Game Thread is archived.")).toBeInTheDocument();
    expect(screen.getAllByText(/24-hour post-game window has ended/i)).toHaveLength(1);
    expect(screen.queryByRole("button", { name: "Post comment" })).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Back to Game Threads" }));
    expect(screen.getByRole("button", { name: /Miami Dolphins/i })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Back to FANbase" }));
    expect(screen.getByRole("heading", { name: "FANbase" })).toBeInTheDocument();
  });

  it("supports local Fan Photo rating, reaction, comments, and reporting", async () => {
    const user = userEvent.setup();
    renderRoute();

    await user.click(screen.getByRole("button", { name: /Fan Photos/i }));
    expect(screen.getByRole("button", { name: "Open Game Face Fan Photos" })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Photos to Rate" })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Show Game Face" }));
    await user.click(screen.getByRole("button", { name: "Open Game Face Fan Photos" }));
    expect(screen.getByRole("heading", { name: "Photos to Rate" })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Your Photos" })).not.toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Rankings" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /Ready before sunrise/i }));
    const viewer = screen.getByRole("dialog", { name: "Ready before sunrise" });
    expect(screen.queryByRole("navigation", { name: "Application navigation" })).not.toBeInTheDocument();
    await user.click(within(viewer).getByRole("button", { name: "Rate 4.5 out of 5" }));
    await user.click(within(viewer).getByRole("button", { name: "Flip" }));
    await user.click(within(viewer).getByRole("button", { name: /Fire, 24 reactions/i }));
    await user.type(screen.getByRole("textbox", { name: "Add a comment" }), "The game-day details are perfect.");
    await user.click(screen.getByRole("button", { name: "Post" }));
    await user.click(screen.getByRole("button", { name: "Report FANfoto" }));

    expect(screen.getByRole("button", { name: /Fire, 25 reactions/i })).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByText("The game-day details are perfect.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Reported" })).toBeInTheDocument();
    await user.click(within(viewer).getByRole("button", { name: "Photo" }));
    expect(screen.getByRole("button", { name: "Rate 4.5 out of 5" })).toHaveAttribute("aria-pressed", "true");
  });

  it("keeps multiple images inside one canonical FANfoto while flipping front and back", async () => {
    const user = userEvent.setup();
    const { router } = renderRoute("/fanbase?area=fan-photos&category=Memorabilia&item=photo-pats-mask");

    const viewer = screen.getByRole("dialog", { name: "Four views of a handmade mask" });
    expect(within(viewer).getByText("1 / 4")).toBeInTheDocument();
    expect(within(viewer).getByRole("img", { name: /Front view of a handmade/i })).toBeInTheDocument();
    await user.click(within(viewer).getByRole("button", { name: "Next image" }));
    expect(within(viewer).getByText("2 / 4")).toBeInTheDocument();
    expect(within(viewer).getByRole("img", { name: /Side view of a handmade/i })).toBeInTheDocument();

    await user.click(within(viewer).getByRole("button", { name: "Flip" }));
    expect(within(viewer).getByRole("heading", { name: "Four views of a handmade mask" })).toBeInTheDocument();
    expect(within(viewer).getByText("All four images belong to this one FANfoto entry.", { exact: false })).toBeInTheDocument();
    await user.click(within(viewer).getByRole("button", { name: "Photo" }));
    expect(within(viewer).getByText("2 / 4")).toBeInTheDocument();
    expect(within(viewer).getByRole("img", { name: /Side view of a handmade/i })).toBeInTheDocument();

    await user.click(within(viewer).getByRole("button", { name: "Close FANfoto" }));
    expect(router.state.location.search).toContain("category=Memorabilia");
    expect(router.state.location.search).not.toContain("item=");
    expect(screen.getByRole("heading", { name: "Photos to Rate" })).toBeInTheDocument();
    expect(screen.getByRole("navigation", { name: "Application navigation" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Back to Fan Photos" }));
    expect(screen.getByText("Swipe or select a category to browse, rate, and celebrate how fans show up.")).toBeInTheDocument();
  });

  it("opens News Discussion in the one linked Article Discussion and reflects the first comment count", async () => {
    const user = userEvent.setup();
    renderRoute("/news");

    const newsCardOpenButton = screen.getByRole("button", { name: "Open Audio notebook: Reading the Patriots defense before the snap" });
    const newsCard = newsCardOpenButton.closest("article");
    expect(newsCard).not.toBeNull();
    await user.click(within(newsCard as HTMLElement).getByRole("button", { name: "Open FANbase Article Discussion" }));

    expect(screen.getByRole("heading", { name: "Audio notebook: Reading the Patriots defense before the snap" })).toBeInTheDocument();
    expect(screen.getByText(/Your first comment will create it/i)).toBeInTheDocument();
    await user.type(screen.getByRole("textbox", { name: "Add to the conversation" }), "The secondary communication stood out to me.");
    await user.click(screen.getByRole("button", { name: "Post comment" }));
    expect(screen.getByText("1 comment")).toBeInTheDocument();

    await user.click(screen.getByRole("link", { name: /View News Item/i }));
    const itemOverlay = await screen.findByRole("dialog", { name: "Audio notebook: Reading the Patriots defense before the snap" });
    expect(within(itemOverlay).getByRole("button", { name: "Open FANbase Article Discussion" })).toHaveTextContent("1");
    expect(within(itemOverlay).getByRole("button", { name: "Back to Discussion" })).toBeInTheDocument();

    await user.click(within(itemOverlay).getByRole("button", { name: "Back to Discussion" }));
    await waitFor(() => expect(screen.getByText("The secondary communication stood out to me.")).toBeInTheDocument());
    expect(screen.getAllByText("The secondary communication stood out to me.")).toHaveLength(1);

    await user.click(screen.getByRole("link", { name: /View News Item/i }));
    await user.click(screen.getByRole("button", { name: "Close News item" }));
    expect(screen.getByRole("heading", { name: "News" })).toBeInTheDocument();
    expect(screen.queryByRole("dialog", { name: /Audio notebook/i })).not.toBeInTheDocument();
  });

  it("uses one compact Article Discussion card and places the composer before comments", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=article-comments&item=patriots-camp-tempo");

    const headline = "Patriots turn up the tempo as the offense enters its final camp phase";
    expect(screen.getAllByRole("heading", { name: headline })).toHaveLength(1);
    expect(screen.getByText(/Connected News Item/)).toBeInTheDocument();
    const composer = screen.getByRole("textbox", { name: "Add to the conversation" }).closest("form");
    const conversationHeading = screen.getByRole("heading", { name: "Conversation" });
    expect(composer).not.toBeNull();
    expect(composer!.compareDocumentPosition(conversationHeading) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();

    expect(screen.queryByRole("menu", { name: "Choose a reaction" })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Choose discussion reaction" }));
    await user.click(screen.getByRole("menuitemradio", { name: "Fire, 31 reactions" }));
    expect(screen.getByRole("button", { name: "Choose discussion reaction" })).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByRole("button", { name: "Choose discussion reaction" })).toHaveTextContent("Fire · 99");
  });
});
