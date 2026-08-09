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
      "Article Comments",
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
    await user.click(screen.getByRole("button", { name: "Back to FANbase" }));
    await user.click(screen.getByRole("button", { name: /Locker Room/i }));
    expect(screen.getByRole("button", { name: /Best third-down package/i })).toBeInTheDocument();
  });

  it("uses the area name, context, and Back control as the only subpage header", async () => {
    const user = userEvent.setup();
    renderRoute("/fanbase?area=article-comments");

    expect(screen.getAllByRole("heading", { name: "Article Comments" })).toHaveLength(1);
    expect(screen.queryByRole("heading", { name: "FANbase" })).not.toBeInTheDocument();
    expect(screen.getByText("New England Patriots News discussions")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Choose FANbase team" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Article Comments are created from News Items" })).toBeDisabled();

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

  it("keeps Game Thread creation disabled because games schedule those threads", () => {
    renderRoute("/fanbase?area=game-threads");

    expect(screen.getByRole("heading", { name: "Game Threads" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Game Threads are created from scheduled games and events" })).toBeDisabled();
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

  it("demonstrates the 24-hour Game Thread lock", async () => {
    const user = userEvent.setup();
    renderRoute();

    await user.click(screen.getByRole("button", { name: /Game Threads/i }));
    await user.click(screen.getByRole("button", { name: /Miami Dolphins/i }));

    expect(screen.getByText("This Game Thread is archived.")).toBeInTheDocument();
    expect(screen.getAllByText(/24-hour post-game window has ended/i)).toHaveLength(2);
    expect(screen.queryByRole("button", { name: "Post comment" })).not.toBeInTheDocument();
  });

  it("supports local Fan Photo rating, reaction, comments, and reporting", async () => {
    const user = userEvent.setup();
    renderRoute();

    await user.click(screen.getByRole("button", { name: /Fan Photos/i }));
    await user.click(screen.getByRole("button", { name: /Ready before sunrise/i }));
    await user.click(screen.getByRole("button", { name: "Rate 5 out of 5" }));
    await user.click(screen.getByRole("button", { name: /Fire, 24 reactions/i }));
    await user.type(screen.getByRole("textbox", { name: "Add a comment" }), "The game-day details are perfect.");
    await user.click(screen.getByRole("button", { name: "Post" }));
    await user.click(screen.getByRole("button", { name: "Report photo" }));

    expect(screen.getByRole("button", { name: "Rate 5 out of 5" })).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByRole("button", { name: /Fire, 25 reactions/i })).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByText("The game-day details are perfect.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Reported" })).toBeInTheDocument();
  });

  it("opens News Discussion in the one linked Article Comments thread and reflects the first comment count", async () => {
    const user = userEvent.setup();
    renderRoute("/news");

    const newsCardOpenButton = screen.getByRole("button", { name: "Open Audio notebook: Reading the Patriots defense before the snap" });
    const newsCard = newsCardOpenButton.closest("article");
    expect(newsCard).not.toBeNull();
    await user.click(within(newsCard as HTMLElement).getByRole("button", { name: "Open FANbase discussion" }));

    expect(screen.getByRole("heading", { name: "Audio notebook: Reading the Patriots defense before the snap" })).toBeInTheDocument();
    expect(screen.getByText(/Your first comment will create it/i)).toBeInTheDocument();
    await user.type(screen.getByRole("textbox", { name: "Add to the conversation" }), "The secondary communication stood out to me.");
    await user.click(screen.getByRole("button", { name: "Post comment" }));
    expect(screen.getByText("1 comment")).toBeInTheDocument();

    await user.click(screen.getByRole("link", { name: /View News Item/i }));
    const itemOverlay = await screen.findByRole("dialog", { name: "Audio notebook: Reading the Patriots defense before the snap" });
    expect(within(itemOverlay).getByRole("button", { name: "Open FANbase discussion" })).toHaveTextContent("1");

    await user.click(within(itemOverlay).getByRole("button", { name: "Open FANbase discussion" }));
    await waitFor(() => expect(screen.getByText("The secondary communication stood out to me.")).toBeInTheDocument());
    expect(screen.getAllByText("The secondary communication stood out to me.")).toHaveLength(1);
  });
});
