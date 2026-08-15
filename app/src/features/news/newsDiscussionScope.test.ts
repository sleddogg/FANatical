import { describe, expect, it } from "vitest";
import { mockNewsItems } from "./mockNewsData";
import { newsDiscussionScopeMatchesTeam, newsItemDiscussionScope } from "./newsDiscussionScope";

describe("canonical News Item discussion scope", () => {
  it("owns a team article in that article's team even when another FANbase is selected", () => {
    const redSoxItem = mockNewsItems.find((item) => item.id === "red-sox-farm-defense")!;
    const scope = newsItemDiscussionScope(redSoxItem);
    expect(scope).toEqual({ kind: "team", teamId: "boston-red-sox" });
    expect(newsDiscussionScopeMatchesTeam(scope, "new-england-patriots")).toBe(false);
    expect(newsDiscussionScopeMatchesTeam(scope, "boston-red-sox")).toBe(true);
  });

  it("owns broad articles at League scope and supports an explicit Sport scope", () => {
    const leagueItem = mockNewsItems.find((item) => item.id === "nfl-kickoff-rule")!;
    expect(newsItemDiscussionScope(leagueItem)).toEqual({ kind: "league", leagueId: "nfl" });
    expect(newsDiscussionScopeMatchesTeam(newsItemDiscussionScope(leagueItem), "new-england-patriots")).toBe(true);
    expect(newsItemDiscussionScope({ ...leagueItem, discussionScope: { kind: "sport", sportId: "football" } })).toEqual({ kind: "sport", sportId: "football" });
  });
});
