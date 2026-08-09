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
  it("renders the six hub areas in the required order", () => {
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
    ]);
    expect(screen.getByText("New England Patriots fan community")).toBeInTheDocument();
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
    expect(composer).not.toBeNull();
    expect(composer!.compareDocumentPosition(conversationHeading) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(screen.getAllByRole("article").filter((article) => article.classList.contains("community-comment"))).toHaveLength(6);
    expect(screen.getAllByRole("button", { name: /Like, .* reactions/i }).length).toBeGreaterThan(0);

    await user.click(screen.getByRole("button", { name: "Share" }));
    expect(screen.getByRole("status")).toHaveTextContent("Sharing is represented as a local frontend placeholder.");
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
    expect(screen.getByRole("heading", { name: "Your Photos" })).toBeInTheDocument();
    expect(screen.getAllByRole("button", { name: /Our new watch room/i })).toHaveLength(2);
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
    await user.click(screen.getByRole("button", { name: "Open Game Face Fan Photos" }));
    expect(screen.getByRole("heading", { name: "Photos to Rate" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Your Photos" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Rankings" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /Ready before sunrise/i }));
    const viewer = screen.getByRole("dialog", { name: "Ready before sunrise" });
    expect(screen.queryByRole("navigation", { name: "Application navigation" })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Rate 5 out of 5" }));
    await user.click(within(viewer).getByRole("button", { name: "Flip" }));
    await user.click(within(viewer).getByRole("button", { name: /Fire, 24 reactions/i }));
    await user.type(screen.getByRole("textbox", { name: "Add a comment" }), "The game-day details are perfect.");
    await user.click(screen.getByRole("button", { name: "Post" }));
    await user.click(screen.getByRole("button", { name: "Report FANfoto" }));

    expect(screen.getByRole("button", { name: /Fire, 25 reactions/i })).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByText("The game-day details are perfect.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Reported" })).toBeInTheDocument();
    await user.click(within(viewer).getByRole("button", { name: "Photo" }));
    expect(screen.getByRole("button", { name: "Rate 5 out of 5" })).toHaveAttribute("aria-pressed", "true");
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
    expect(screen.getByRole("heading", { name: "Choose a category" })).toBeInTheDocument();
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
