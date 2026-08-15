import { describe, expect, it } from "vitest";
import { followedTeams } from "../../data/followedTeams";
import { demoUser } from "../fanbase/mockFanbaseData";
import {
  buildSportsStatsSnapshot,
  fanScoreForUser,
  resolveFanbaseCompetition,
  sportIqWeights,
  sportsStatsUser,
} from "./sportsStats";

describe("shared sports stats", () => {
  it("keeps Fan Score Team-specific and uses a Quiz-heavy configurable Sport IQ", () => {
    const snapshot = buildSportsStatsSnapshot();
    const user = sportsStatsUser(demoUser.id, snapshot)!;
    const patriots = resolveFanbaseCompetition(followedTeams[0]);
    const redSox = resolveFanbaseCompetition(followedTeams[1]);

    expect(fanScoreForUser(user, patriots.teamKey)).toBe(18460);
    expect(fanScoreForUser(user, redSox.teamKey)).toBe(9840);
    expect(sportIqWeights.quiz).toBeGreaterThan(sportIqWeights.predictor);
  });

  it("builds Overall Sport IQ from underlying evidence volume", () => {
    const user = sportsStatsUser(demoUser.id, buildSportsStatsSnapshot())!;
    const evidenceSports = user.sports.filter((sport) => sport.sportIq !== null && sport.evidenceUnits > 0);
    const expected = Math.round(evidenceSports.reduce((total, sport) => total + sport.sportIq! * sport.evidenceUnits, 0) / evidenceSports.reduce((total, sport) => total + sport.evidenceUnits, 0));
    expect(user.overallSportIq).toBe(expected);
  });
});
