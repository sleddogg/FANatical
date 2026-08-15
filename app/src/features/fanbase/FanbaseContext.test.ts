import { describe, expect, it } from "vitest";
import { getGameThreadStatus } from "./FanbaseContext";
import type { GameThread } from "./types";

function game(startsAt: number, endsAt: number): GameThread {
  return {
    id: "game",
    threadId: "thread",
    teamId: "new-england-patriots",
    sportId: "football",
    leagueId: "football-nfl",
    opponent: "Opponent",
    venue: "Venue",
    startsAt: new Date(startsAt).toISOString(),
    endsAt: new Date(endsAt).toISOString(),
    finalResult: null,
  };
}

describe("Game Thread status", () => {
  const now = Date.parse("2026-08-09T12:00:00.000Z");

  it("derives scheduled and live states from game timestamps", () => {
    expect(getGameThreadStatus(game(now + 1_000, now + 2_000), now)).toBe("Scheduled");
    expect(getGameThreadStatus(game(now - 1_000, now + 1_000), now)).toBe("Live");
  });

  it("keeps post-game discussion open for exactly 24 hours, then archives it", () => {
    const endedAt = now - 23 * 60 * 60 * 1000;
    expect(getGameThreadStatus(game(now - 30 * 60 * 60 * 1000, endedAt), now)).toBe("Post-game");

    const archivedAt = now - 24 * 60 * 60 * 1000 - 1;
    expect(getGameThreadStatus(game(now - 30 * 60 * 60 * 1000, archivedAt), now)).toBe("Archived");
  });
});
