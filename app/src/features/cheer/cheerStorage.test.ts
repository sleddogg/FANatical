import { beforeEach, describe, expect, it } from "vitest";
import { loadCheerLibrary } from "./cheerStorage";
import { initialCheerLibrary } from "./mockCheerData";

const storageKey = "fanatical.cheer.library";

function legacyRecord(id: string, title: string) {
  const { sportId: _sportId, leagueId: _leagueId, teamId: _teamId, ...seed } = initialCheerLibrary[0]!;
  return { ...seed, id, title, teamId: "new-england-patriots" };
}

describe("Cheer controlled metadata migration", () => {
  beforeEach(() => window.localStorage.clear());

  it("keeps the built-in Defense classification when it maps cleanly", async () => {
    window.localStorage.setItem(storageKey, JSON.stringify([legacyRecord("cheer-d-fence", "D-Fence Clap Clap")]));
    const loaded = await loadCheerLibrary();
    expect(loaded?.[0]).toMatchObject({
      sportId: "football",
      leagueId: "football-nfl",
      teamId: "football-nfl-new-england-patriots",
      sport: "Football",
      league: "NFL",
      team: "New England Patriots",
    });
  });

  it("resets other legacy free-text classifications to Sport-wide defaults", async () => {
    window.localStorage.setItem(storageKey, JSON.stringify([legacyRecord("cheer-local-test", "Old Test Cheer")]));
    const loaded = await loadCheerLibrary();
    expect(loaded?.[0]).toMatchObject({
      sportId: "football",
      leagueId: null,
      teamId: null,
      sport: "Football",
      league: "",
      team: "",
    });
  });

  it("backfills Live Variants only for the existing published test Cheer", async () => {
    window.localStorage.setItem(storageKey, JSON.stringify([
      legacyRecord("cheer-local-live-test", "test"),
      legacyRecord("cheer-local-other", "Other Cheer"),
    ]));
    const loaded = await loadCheerLibrary();
    expect(loaded?.[0]?.liveVariants).toHaveLength(2);
    expect(loaded?.[0]?.liveVariants?.map((variant) => variant.routing.end)).toEqual(["End A", "End B"]);
    expect(loaded?.[1]?.liveVariants).toBeUndefined();
  });
});
