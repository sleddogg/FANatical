import { describe, expect, it } from "vitest";
import {
  createGamePrediction,
  loadGamePredictions,
  predictionRulesForGame,
  predictorMinimumPredictions,
  predictorSummary,
  resolveGamePrediction,
  saveGamePredictions,
  type GamePredictionRecord,
} from "./gamePredictor";
import { demoUser, initialGameThreads } from "./mockFanbaseData";
import type { GameThread } from "./types";

function footballGame(final = true): GameThread {
  return {
    id: "calculation-game",
    threadId: "thread",
    teamId: "new-england-patriots",
    sportId: "football",
    leagueId: "football-nfl",
    opponent: "Opponent",
    venue: "Venue",
    startsAt: "2026-08-14T18:00:00.000Z",
    endsAt: "2026-08-14T22:00:00.000Z",
    finalResult: final ? { teamAScore: 24, teamBScore: 21, outcome: "Regulation", finalizedAt: "2026-08-14T22:05:00.000Z" } : null,
  };
}

function prediction(): GamePredictionRecord {
  return {
    id: "prediction",
    gameId: "calculation-game",
    userId: demoUser.id,
    username: demoUser.username,
    sportId: "football",
    leagueId: "football-nfl",
    teamAScore: 35,
    teamBScore: 10,
    predictedOutcome: "Regulation",
    submittedAt: "2026-08-14T17:00:00.000Z",
    lockedAt: "2026-08-14T18:00:00.000Z",
    resolution: null,
  };
}

describe("Game Day Predictor", () => {
  it("uses absolute score errors so opposing misses never cancel", () => {
    const resolved = resolveGamePrediction(prediction(), footballGame()).resolution;
    expect(resolved).not.toBeNull();
    expect(resolved?.teamAScoreError).toBe(11);
    expect(resolved?.teamBScoreError).toBe(11);
    expect(resolved?.totalScoreError).toBe(22);
    expect(resolved?.correctWinner).toBe(true);
    expect(resolved?.exactScore).toBe(false);
    expect(resolved?.predictorRating).toBeGreaterThanOrEqual(0);
    expect(resolved?.predictorRating).toBeLessThanOrEqual(100);
  });

  it("awards a 100 Rating and CALLED IT qualification for an exact score", () => {
    const exact = { ...prediction(), teamAScore: 24, teamBScore: 21 };
    const resolved = resolveGamePrediction(exact, footballGame()).resolution;
    expect(resolved?.totalScoreError).toBe(0);
    expect(resolved?.exactScore).toBe(true);
    expect(resolved?.predictorRating).toBe(100);
  });

  it("uses League-specific outcome rules and enforces the start cutoff", () => {
    const nfl = footballGame(false);
    const mlb = initialGameThreads.find((game) => game.id === "game-sox-yankees")!;
    expect(predictionRulesForGame(nfl).outcomes).toEqual(["Regulation", "Overtime", "Tie"]);
    expect(predictionRulesForGame(mlb).outcomes).toEqual(["Regulation", "Extra Innings"]);
    expect(createGamePrediction(nfl, { teamAScore: 24, teamBScore: 17, predictedOutcome: "Regulation" }, new Date("2026-08-14T17:59:59.000Z"))).not.toBeNull();
    expect(createGamePrediction(nfl, { teamAScore: 24, teamBScore: 17, predictedOutcome: "Regulation" }, new Date("2026-08-14T18:00:00.000Z"))).toBeNull();
  });

  it("persists resolved history and assigns a sport percentile only after qualification", () => {
    const records = loadGamePredictions(initialGameThreads);
    const summary = predictorSummary(records, demoUser.id, "football");
    expect(summary.predictionCount).toBeGreaterThanOrEqual(predictorMinimumPredictions);
    expect(summary.predictorPercentile).not.toBeNull();
    saveGamePredictions(records);
    expect(loadGamePredictions(initialGameThreads).find((record) => record.id === "prediction-pats-recent-demo")?.resolution?.totalScoreError).toBe(22);
  });
});

