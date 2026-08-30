import { describe, expect, it } from "vitest";
import { articleDiscussionNewsItems } from "./mockArticleDiscussionData";
import {
  articleDiscussionScopeForItem,
  articleDiscussionScopeMatchesTeam,
} from "./articleDiscussionScope";

describe("canonical FANbase Article Discussion scope", () => {
  it("owns a team article in that article's team even when another FANbase is selected", () => {
    const redSoxItem = articleDiscussionNewsItems.find(
      (item) => item.id === "red-sox-bullpen-plan",
    )!;
    const scope = articleDiscussionScopeForItem(redSoxItem);
    expect(scope).toEqual({ kind: "team", teamId: "boston-red-sox" });
    expect(articleDiscussionScopeMatchesTeam(scope, "new-england-patriots")).toBe(false);
    expect(articleDiscussionScopeMatchesTeam(scope, "boston-red-sox")).toBe(true);
  });

  it("owns broad articles at League scope and supports an explicit Sport scope", () => {
    const leagueItem = articleDiscussionNewsItems[0]!;
    const broadItem = { ...leagueItem, teamIds: [] };
    expect(articleDiscussionScopeForItem(broadItem)).toEqual({
      kind: "league",
      leagueId: "nfl",
    });
    expect(
      articleDiscussionScopeMatchesTeam(
        articleDiscussionScopeForItem(broadItem),
        "new-england-patriots",
      ),
    ).toBe(true);
    expect(
      articleDiscussionScopeForItem({
        ...broadItem,
        discussionScope: { kind: "sport", sportId: "football" },
      }),
    ).toEqual({ kind: "sport", sportId: "football" });
  });
});
