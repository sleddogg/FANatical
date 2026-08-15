import type { OfficialLeagueId, OfficialSportId } from "../../data/officialSportsDatabase";
import { demoUser } from "./mockFanbaseData";
import type { GamePredictionOutcome, GameThread } from "./types";

export const predictorMinimumPredictions = 5;
export const gamePredictionStorageKey = "fanatical.fanbase.game-predictions.v1";

export type PredictionRuleProfile = Readonly<{
  id: string;
  outcomes: readonly GamePredictionOutcome[];
  maximumScore: number;
  totalErrorNormalization: number;
  supportsShutouts: boolean;
  weights: Readonly<{
    winner: number;
    scoreAccuracy: number;
    exactScore: number;
    outcome: number;
    shutout: number;
  }>;
}>;

export type PredictionResolution = Readonly<{
  finalTeamAScore: number;
  finalTeamBScore: number;
  finalOutcome: GamePredictionOutcome;
  correctWinner: boolean;
  teamAScoreError: number;
  teamBScoreError: number;
  totalScoreError: number;
  exactScore: boolean;
  correctShutout: boolean | null;
  correctOutcome: boolean;
  predictorRating: number;
  resolvedAt: string;
}>;

export type GamePredictionRecord = Readonly<{
  id: string;
  gameId: string;
  userId: string;
  username: string;
  sportId: OfficialSportId;
  leagueId: OfficialLeagueId | null;
  teamAScore: number;
  teamBScore: number;
  predictedOutcome: GamePredictionOutcome;
  submittedAt: string;
  lockedAt: string;
  resolution: PredictionResolution | null;
}>;

export type PredictorSummary = Readonly<{
  predictionCount: number;
  correctWinnerCount: number;
  exactScoreCount: number;
  averageTeamAError: number;
  averageTeamBError: number;
  averageTotalScoreError: number;
  predictorRating: number;
  predictorPercentile: number | null;
}>;

const standardWeights = { winner: 30, scoreAccuracy: 40, exactScore: 15, outcome: 10, shutout: 5 } as const;

const sportRules: Readonly<Record<OfficialSportId, PredictionRuleProfile>> = {
  football: { id: "football", outcomes: ["Regulation", "Overtime", "Tie"], maximumScore: 80, totalErrorNormalization: 56, supportsShutouts: true, weights: standardWeights },
  baseball: { id: "baseball", outcomes: ["Regulation", "Extra Innings", "Tie"], maximumScore: 30, totalErrorNormalization: 18, supportsShutouts: true, weights: standardWeights },
  basketball: { id: "basketball", outcomes: ["Regulation", "Overtime"], maximumScore: 180, totalErrorNormalization: 50, supportsShutouts: false, weights: standardWeights },
  hockey: { id: "hockey", outcomes: ["Regulation", "Overtime", "Shootout"], maximumScore: 20, totalErrorNormalization: 10, supportsShutouts: true, weights: standardWeights },
  soccer: { id: "soccer", outcomes: ["Regulation", "Draw"], maximumScore: 20, totalErrorNormalization: 8, supportsShutouts: true, weights: standardWeights },
  generic: { id: "generic", outcomes: ["Regulation", "Overtime", "Tie"], maximumScore: 100, totalErrorNormalization: 50, supportsShutouts: false, weights: standardWeights },
  other: { id: "other", outcomes: ["Regulation", "Overtime", "Tie"], maximumScore: 100, totalErrorNormalization: 50, supportsShutouts: false, weights: standardWeights },
};

const leagueRuleOverrides: Partial<Record<OfficialLeagueId, PredictionRuleProfile>> = {
  "football-nfl": { ...sportRules.football, id: "football-nfl", outcomes: ["Regulation", "Overtime", "Tie"] },
  "baseball-mlb": { ...sportRules.baseball, id: "baseball-mlb", outcomes: ["Regulation", "Extra Innings"] },
  "baseball-npb": { ...sportRules.baseball, id: "baseball-npb", outcomes: ["Regulation", "Extra Innings", "Tie"] },
  "hockey-nhl": { ...sportRules.hockey, id: "hockey-nhl", outcomes: ["Regulation", "Overtime", "Shootout"] },
};

const mockQualifiedRatings: Readonly<Record<OfficialSportId, readonly number[]>> = {
  football: [42, 48, 51, 55, 58, 61, 64, 67, 69, 72, 74, 76, 79, 81, 84, 87, 90, 93, 96],
  baseball: [38, 45, 50, 54, 59, 63, 68, 72, 76, 81, 86, 91],
  basketball: [40, 47, 52, 57, 62, 66, 71, 75, 80, 85, 89, 94],
  hockey: [41, 46, 53, 58, 62, 67, 71, 75, 79, 83, 88, 92, 96],
  soccer: [39, 44, 49, 55, 60, 65, 70, 74, 78, 82, 87, 91],
  generic: [40, 50, 60, 70, 80, 90],
  other: [40, 50, 60, 70, 80, 90],
};

export function predictionRulesForGame(game: GameThread) {
  return (game.leagueId ? leagueRuleOverrides[game.leagueId] : null) ?? sportRules[game.sportId];
}

function winner(teamAScore: number, teamBScore: number) {
  return teamAScore === teamBScore ? "Tie" : teamAScore > teamBScore ? "Team A" : "Team B";
}

function shutout(teamAScore: number, teamBScore: number) {
  if (teamAScore === 0 && teamBScore > 0) return "Team B";
  if (teamBScore === 0 && teamAScore > 0) return "Team A";
  return "None";
}

export function resolveGamePrediction(prediction: GamePredictionRecord, game: GameThread): GamePredictionRecord {
  if (!game.finalResult) return prediction;
  const rules = predictionRulesForGame(game);
  const teamAScoreError = Math.abs(prediction.teamAScore - game.finalResult.teamAScore);
  const teamBScoreError = Math.abs(prediction.teamBScore - game.finalResult.teamBScore);
  const totalScoreError = teamAScoreError + teamBScoreError;
  const exactScore = totalScoreError === 0;
  const correctWinner = winner(prediction.teamAScore, prediction.teamBScore) === winner(game.finalResult.teamAScore, game.finalResult.teamBScore);
  const correctOutcome = prediction.predictedOutcome === game.finalResult.outcome;
  const correctShutout = rules.supportsShutouts ? shutout(prediction.teamAScore, prediction.teamBScore) === shutout(game.finalResult.teamAScore, game.finalResult.teamBScore) : null;
  const scoreAccuracy = Math.max(0, 1 - totalScoreError / rules.totalErrorNormalization);
  const applicableWeight = rules.weights.winner + rules.weights.scoreAccuracy + rules.weights.exactScore + rules.weights.outcome + (rules.supportsShutouts ? rules.weights.shutout : 0);
  const earned = (correctWinner ? rules.weights.winner : 0)
    + scoreAccuracy * rules.weights.scoreAccuracy
    + (exactScore ? rules.weights.exactScore : 0)
    + (correctOutcome ? rules.weights.outcome : 0)
    + (correctShutout ? rules.weights.shutout : 0);
  const predictorRating = Math.round(earned / applicableWeight * 100);
  return {
    ...prediction,
    resolution: {
      finalTeamAScore: game.finalResult.teamAScore,
      finalTeamBScore: game.finalResult.teamBScore,
      finalOutcome: game.finalResult.outcome,
      correctWinner,
      teamAScoreError,
      teamBScoreError,
      totalScoreError,
      exactScore,
      correctShutout,
      correctOutcome,
      predictorRating,
      resolvedAt: game.finalResult.finalizedAt,
    },
  };
}

export function predictorSummary(records: readonly GamePredictionRecord[], userId: string, sportId: OfficialSportId): PredictorSummary {
  const resolved = records.filter((record) => record.userId === userId && record.sportId === sportId && record.resolution !== null);
  const count = resolved.length;
  const total = (pick: (resolution: PredictionResolution) => number) => resolved.reduce((sum, record) => sum + pick(record.resolution!), 0);
  const rating = count ? Math.round(total((resolution) => resolution.predictorRating) / count) : 0;
  const cohort = mockQualifiedRatings[sportId];
  const percentile = count >= predictorMinimumPredictions ? Math.round(cohort.filter((cohortRating) => cohortRating <= rating).length / cohort.length * 100) : null;
  return {
    predictionCount: count,
    correctWinnerCount: total((resolution) => Number(resolution.correctWinner)),
    exactScoreCount: total((resolution) => Number(resolution.exactScore)),
    averageTeamAError: count ? Number((total((resolution) => resolution.teamAScoreError) / count).toFixed(1)) : 0,
    averageTeamBError: count ? Number((total((resolution) => resolution.teamBScoreError) / count).toFixed(1)) : 0,
    averageTotalScoreError: count ? Number((total((resolution) => resolution.totalScoreError) / count).toFixed(1)) : 0,
    predictorRating: rating,
    predictorPercentile: percentile,
  };
}

export function createGamePrediction(game: GameThread, input: { readonly teamAScore: number; readonly teamBScore: number; readonly predictedOutcome: GamePredictionOutcome }, submittedAt = new Date()): GamePredictionRecord | null {
  if (submittedAt.getTime() >= Date.parse(game.startsAt)) return null;
  const rules = predictionRulesForGame(game);
  if (!Number.isInteger(input.teamAScore) || !Number.isInteger(input.teamBScore) || input.teamAScore < 0 || input.teamBScore < 0 || input.teamAScore > rules.maximumScore || input.teamBScore > rules.maximumScore || !rules.outcomes.includes(input.predictedOutcome)) return null;
  return {
    id: `game-prediction-${crypto.randomUUID()}`,
    gameId: game.id,
    userId: demoUser.id,
    username: demoUser.username,
    sportId: game.sportId,
    leagueId: game.leagueId,
    teamAScore: input.teamAScore,
    teamBScore: input.teamBScore,
    predictedOutcome: input.predictedOutcome,
    submittedAt: submittedAt.toISOString(),
    lockedAt: game.startsAt,
    resolution: null,
  };
}

function historicalPrediction(index: number, rating: number, exactScore = false): GamePredictionRecord {
  const teamAScoreError = exactScore ? 0 : Math.max(1, Math.round((100 - rating) / 12));
  const teamBScoreError = exactScore ? 0 : Math.max(1, Math.round((100 - rating) / 15));
  return {
    id: `prediction-history-football-${index}`,
    gameId: `historic-football-game-${index}`,
    userId: demoUser.id,
    username: demoUser.username,
    sportId: "football",
    leagueId: "football-nfl",
    teamAScore: 24 + index,
    teamBScore: 17 + index,
    predictedOutcome: "Regulation",
    submittedAt: new Date(Date.now() - (index + 20) * 7 * 86_400_000).toISOString(),
    lockedAt: new Date(Date.now() - (index + 20) * 7 * 86_400_000 + 3_600_000).toISOString(),
    resolution: {
      finalTeamAScore: 24 + index + teamAScoreError,
      finalTeamBScore: 17 + index - teamBScoreError,
      finalOutcome: "Regulation",
      correctWinner: true,
      teamAScoreError,
      teamBScoreError,
      totalScoreError: teamAScoreError + teamBScoreError,
      exactScore,
      correctShutout: true,
      correctOutcome: true,
      predictorRating: rating,
      resolvedAt: new Date(Date.now() - (index + 20) * 7 * 86_400_000 + 4 * 3_600_000).toISOString(),
    },
  };
}

const seedPrediction = (input: Omit<GamePredictionRecord, "id" | "sportId" | "leagueId" | "lockedAt" | "resolution"> & { id: string }): GamePredictionRecord => ({
  ...input,
  sportId: "football",
  leagueId: "football-nfl",
  lockedAt: input.submittedAt,
  resolution: null,
});

const seededPredictions: readonly GamePredictionRecord[] = [
  historicalPrediction(1, 78),
  historicalPrediction(2, 82),
  historicalPrediction(3, 74),
  historicalPrediction(4, 88),
  seedPrediction({ id: "prediction-pats-recent-demo", gameId: "game-pats-recent", userId: demoUser.id, username: demoUser.username, teamAScore: 35, teamBScore: 10, predictedOutcome: "Regulation", submittedAt: new Date(Date.now() - 20 * 3_600_000).toISOString() }),
  seedPrediction({ id: "prediction-pats-recent-maya", gameId: "game-pats-recent", userId: "maya-84", username: "Maya84", teamAScore: 24, teamBScore: 21, predictedOutcome: "Regulation", submittedAt: new Date(Date.now() - 20.5 * 3_600_000).toISOString() }),
  seedPrediction({ id: "prediction-pats-archive-demo", gameId: "game-pats-archive", userId: demoUser.id, username: demoUser.username, teamAScore: 20, teamBScore: 20, predictedOutcome: "Tie", submittedAt: new Date(Date.now() - 80 * 3_600_000).toISOString() }),
  seedPrediction({ id: "prediction-pats-archive-road", gameId: "game-pats-archive", userId: "road-game-rob", username: "RoadGameRob", teamAScore: 20, teamBScore: 20, predictedOutcome: "Tie", submittedAt: new Date(Date.now() - 81 * 3_600_000).toISOString() }),
];

function isPredictionRecord(value: unknown): value is GamePredictionRecord {
  if (!value || typeof value !== "object") return false;
  const record = value as Partial<GamePredictionRecord>;
  return typeof record.id === "string" && typeof record.gameId === "string" && typeof record.userId === "string" && typeof record.username === "string" && typeof record.teamAScore === "number" && typeof record.teamBScore === "number" && typeof record.predictedOutcome === "string" && typeof record.submittedAt === "string";
}

export function saveGamePredictions(records: readonly GamePredictionRecord[]) {
  try {
    window.localStorage.setItem(gamePredictionStorageKey, JSON.stringify(records));
  } catch {
    // The predictor remains usable in memory if browser persistence is unavailable.
  }
}

export function loadGamePredictions(games: readonly GameThread[]) {
  let stored: readonly GamePredictionRecord[] = [];
  try {
    const parsed: unknown = JSON.parse(window.localStorage.getItem(gamePredictionStorageKey) ?? "[]");
    if (Array.isArray(parsed)) stored = parsed.filter(isPredictionRecord);
  } catch {
    stored = [];
  }
  const merged = [...stored, ...seededPredictions.filter((seed) => !stored.some((record) => record.id === seed.id))];
  const resolved = merged.map((record) => {
    const game = games.find((candidate) => candidate.id === record.gameId);
    return game?.finalResult ? resolveGamePrediction(record, game) : record;
  });
  saveGamePredictions(resolved);
  return resolved;
}

