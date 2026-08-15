import { describe, expect, it } from "vitest";
import { initialPolls } from "./mockPollData";
import { loadPolls, savePolls } from "./pollStorage";
import { activePollsForScope, generatePollTopics, pollsForScope, searchPolls } from "./polls";
import type { FanPoll, PollScope } from "./types";

const patriotsScope = { kind: "team", sportId: "football", leagueId: "football-nfl", teamId: "football-nfl-new-england-patriots" } as const satisfies PollScope;
const nhlScope = { kind: "league", sportId: "hockey", leagueId: "hockey-nhl", teamId: null } as const satisfies PollScope;

describe("FANbase Poll queries", () => {
  it("queries exact Sport, League, and Team scopes without mixing broader records", () => {
    const patriots = pollsForScope(initialPolls, patriotsScope);
    const nhl = pollsForScope(initialPolls, nhlScope);

    expect(patriots.length).toBeGreaterThan(10);
    expect(patriots.every((poll) => poll.scope.kind === "team" && poll.scope.teamId === patriotsScope.teamId)).toBe(true);
    expect(nhl.map((poll) => poll.id)).toEqual(expect.arrayContaining(["poll-nhl-playoff-format", "poll-nhl-expansion"]));
    expect(nhl.some((poll) => poll.id.startsWith("poll-oilers"))).toBe(false);
  });

  it("keeps ten unanswered trending Polls and replenishes after a vote", () => {
    const before = activePollsForScope(initialPolls, patriotsScope);
    expect(before).toHaveLength(10);
    const votedId = before[0]!.id;
    const afterVote: readonly FanPoll[] = initialPolls.map((poll) => poll.id === votedId ? { ...poll, viewerOptionId: poll.options[0]!.id } : poll);
    const after = activePollsForScope(afterVote, patriotsScope);

    expect(after).toHaveLength(10);
    expect(after.some((poll) => poll.id === votedId)).toBe(false);
    expect(after.some((poll) => !before.some((previous) => previous.id === poll.id))).toBe(true);
  });

  it("generates useful searchable topics from the question and answers", () => {
    expect(generatePollTopics("Which goalie skill is hardest to teach?", ["Puck tracking", "Positioning"])).toEqual(expect.arrayContaining(["goalie", "skill", "hardest", "teach", "puck", "tracking", "positioning"]));
    expect(searchPolls(initialPolls, "Oilers offseason").map((poll) => poll.id)).toEqual(expect.arrayContaining(["poll-oilers-offseason-old", "poll-oilers-offseason-followup"]));
  });

  it("restores the same canonical Poll records from local browser storage", () => {
    const poll = initialPolls[0]!;
    const voted = { ...poll, viewerOptionId: poll.options[0]!.id, options: poll.options.map((option, index) => index === 0 ? { ...option, voteCount: option.voteCount + 1 } : option) };
    savePolls([voted]);

    const restored = loadPolls(initialPolls);
    expect(restored.find((candidate) => candidate.id === poll.id)?.viewerOptionId).toBe(poll.options[0]!.id);
    expect(restored).toHaveLength(initialPolls.length);
  });
});
