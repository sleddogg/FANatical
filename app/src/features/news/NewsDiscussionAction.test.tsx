import { act, render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { CommunityDiscussionTeaser } from "../community/types";

const mocks = vi.hoisted(() => ({ loadDiscussionTeaser: vi.fn() }));

vi.mock("../community/communityRepository", () => ({
  loadDiscussionTeaser: mocks.loadDiscussionTeaser,
}));

import { NewsDiscussionAction } from "./NewsDiscussionAction";

function teaser(contextName: string, commentCount: number): CommunityDiscussionTeaser {
  return {
    available: true,
    requiresAuth: false,
    viewerCanAccess: true,
    newsItemId: "news-one",
    contextKind: "team",
    contextDisplayKind: "Team",
    contextId: "hockey-000027",
    contextName,
    discussionId: "discussion-one",
    commentCount,
    article: null,
  };
}

describe("NewsDiscussionAction", () => {
  beforeEach(() => mocks.loadDiscussionTeaser.mockReset());

  it("shows the contextual durable count and does not reload for an equivalent origin object", async () => {
    mocks.loadDiscussionTeaser.mockResolvedValue(teaser("Edmonton Oilers", 12));
    const view = render(
      <MemoryRouter>
        <NewsDiscussionAction
          newsItemId="news-one"
          headline="Opening-night focus"
          origin={{ kind: "team", targetId: "hockey-000027" }}
        />
      </MemoryRouter>,
    );

    const link = await screen.findByRole("link", { name: /Edmonton Oilers Discussion.*12 comments/ });
    expect(link).toHaveTextContent("Discussion 12");
    expect(link).toHaveAttribute(
      "href",
      "/news/discussions/news-one?context=team&target=hockey-000027",
    );

    view.rerender(
      <MemoryRouter>
        <NewsDiscussionAction
          newsItemId="news-one"
          headline="Opening-night focus"
          origin={{ kind: "team", targetId: "hockey-000027" }}
        />
      </MemoryRouter>,
    );
    await waitFor(() => expect(mocks.loadDiscussionTeaser).toHaveBeenCalledTimes(1));
  });

  it("keeps a contextual zero distinct from an unavailable discussion", async () => {
    mocks.loadDiscussionTeaser.mockResolvedValue(teaser("National Hockey League", 0));
    render(
      <MemoryRouter>
        <NewsDiscussionAction
          newsItemId="news-one"
          headline="League notebook"
          origin={{ kind: "competition", targetId: "hockey-nhl" }}
        />
      </MemoryRouter>,
    );
    expect(await screen.findByText("Discussion 0")).toBeInTheDocument();
    expect(screen.queryByText("Unavailable")).not.toBeInTheDocument();
  });

  it("suppresses a stale count and link while the same Item changes context", async () => {
    let resolveCompetition!: (value: CommunityDiscussionTeaser) => void;
    const competitionResult = new Promise<CommunityDiscussionTeaser>((resolve) => {
      resolveCompetition = resolve;
    });
    mocks.loadDiscussionTeaser
      .mockResolvedValueOnce(teaser("Edmonton Oilers", 12))
      .mockReturnValueOnce(competitionResult);
    const view = render(
      <MemoryRouter>
        <NewsDiscussionAction
          newsItemId="news-one"
          headline="Context changes"
          origin={{ kind: "team", targetId: "hockey-000027" }}
        />
      </MemoryRouter>,
    );
    expect(await screen.findByRole("link", { name: /Edmonton Oilers Discussion.*12 comments/ })).toBeInTheDocument();

    view.rerender(
      <MemoryRouter>
        <NewsDiscussionAction
          newsItemId="news-one"
          headline="Context changes"
          origin={{ kind: "competition", targetId: "hockey-nhl" }}
        />
      </MemoryRouter>,
    );

    expect(screen.getByLabelText("Loading Discussion for Context changes")).toBeInTheDocument();
    expect(screen.queryByRole("link", { name: /Edmonton Oilers Discussion/ })).not.toBeInTheDocument();
    expect(mocks.loadDiscussionTeaser).toHaveBeenLastCalledWith("news-one", {
      kind: "competition",
      targetId: "hockey-nhl",
    });

    await act(async () => {
      resolveCompetition({
        ...teaser("National Hockey League", 4),
        contextKind: "competition",
        contextId: "hockey-nhl",
        discussionId: "discussion-two",
      });
    });
    const competitionLink = await screen.findByRole("link", { name: /National Hockey League Discussion.*4 comments/ });
    expect(competitionLink).toHaveTextContent("Discussion 4");
    expect(competitionLink).toHaveAttribute(
      "href",
      "/news/discussions/news-one?context=competition&target=hockey-nhl",
    );
  });
});
