import {
  findOfficialLeague,
  findOfficialLeagueByName,
  findOfficialSportByName,
  findOfficialTeam,
  officialTeams,
  type OfficialSportId,
} from "../../data/officialSportsDatabase";
import type { FollowedTeam } from "../../domain/team";
import { initialGameThreads, demoUser, mockFanConnections } from "../fanbase/mockFanbaseData";
import { loadGamePredictions, predictorMinimumPredictions } from "../fanbase/gamePredictor";
import { mockQuizAttempts, mockQuizCatalog } from "../quiz/mockQuizData";
import type { QuizDifficulty } from "../quiz/types";

export const sportIqWeights = { quiz: 0.78, predictor: 0.22 } as const;
export const sportsStatsPredictorMinimum = predictorMinimumPredictions;

export type FanbaseCompetition = Readonly<{
  teamKey: string;
  teamName: string;
  leagueId: string | null;
  leagueName: string;
  sportId: OfficialSportId;
  sportName: string;
}>;

export type QuizIqSummary = Readonly<{
  iq: number | null;
  attempts: number;
  questions: number;
  correctAnswers: number;
  averageScore: number;
}>;

export type PredictorIqSummary = Readonly<{
  iq: number | null;
  percentile: number | null;
  qualified: boolean;
  predictions: number;
  winnerAccuracy: number;
  exactScores: number;
  averageTeamAError: number;
  averageTeamBError: number;
  averageTotalScoreError: number;
}>;

export type SportIqSummary = Readonly<{
  sportId: OfficialSportId;
  sportName: string;
  sportIq: number | null;
  evidenceUnits: number;
  quiz: QuizIqSummary;
  predictor: PredictorIqSummary;
}>;

export type SportsStatsUser = Readonly<{
  id: string;
  username: string;
  initials: string;
  friend: boolean;
  teamKeys: readonly string[];
  leagueIds: readonly string[];
  sportIds: readonly OfficialSportId[];
  fanScores: Readonly<Record<string, number>>;
  trophies: number;
  overallSportIq: number | null;
  sports: readonly SportIqSummary[];
}>;

type QuizEvidence = Readonly<{
  userId: string;
  sportId: OfficialSportId;
  score: number;
  peerAverage: number;
  difficulty: QuizDifficulty;
  questions: number;
}>;

type PredictorEvidence = Readonly<{
  userId: string;
  sportId: OfficialSportId;
  rating: number;
  correctWinner: boolean;
  exactScore: boolean;
  teamAError: number;
  teamBError: number;
}>;

type UserSeed = Readonly<{
  id: string;
  username: string;
  initials: string;
  friend?: boolean;
  teamKeys: readonly string[];
  leagueIds: readonly string[];
  sportIds: readonly OfficialSportId[];
  fanScores: Readonly<Record<string, number>>;
  trophies: number;
}>;

const difficultyWeight: Readonly<Record<QuizDifficulty, number>> = {
  "All-Star": 1.35,
  Star: 1.2,
  "League Average": 1,
  Grinder: 0.9,
  Rookie: 0.75,
};

const teamKeys = {
  patriots: "football-nfl-new-england-patriots",
  redSox: "baseball-mlb-boston-red-sox",
  celtics: "fanbase:boston-celtics",
  oilers: "hockey-nhl-edmonton-oilers",
  bruins: "hockey-nhl-boston-bruins",
  jets: "football-nfl-new-york-jets",
} as const;

const connectionById = new Map(mockFanConnections.map((connection) => [connection.id, connection]));
const identity = (id: string, fallback: { username: string; initials: string }) => connectionById.get(id) ?? { id, ...fallback };

const userSeeds: readonly UserSeed[] = [
  { id: demoUser.id, username: demoUser.username, initials: demoUser.initials, friend: false, teamKeys: [teamKeys.patriots, teamKeys.redSox, teamKeys.celtics], leagueIds: ["football-nfl", "baseball-mlb", "basketball-nba"], sportIds: ["football", "baseball", "basketball", "hockey"], fanScores: { [teamKeys.patriots]: 18460, [teamKeys.redSox]: 9840, [teamKeys.celtics]: 7360 }, trophies: 3 },
  { ...identity("maya-84", { username: "Maya84", initials: "M8" }), friend: true, teamKeys: [teamKeys.patriots, teamKeys.oilers], leagueIds: ["football-nfl", "hockey-nhl"], sportIds: ["football", "hockey"], fanScores: { [teamKeys.patriots]: 20125, [teamKeys.oilers]: 22480 }, trophies: 7 },
  { ...identity("green-line", { username: "GreenLine", initials: "GL" }), friend: true, teamKeys: [teamKeys.celtics], leagueIds: ["basketball-nba"], sportIds: ["basketball"], fanScores: { [teamKeys.celtics]: 21310 }, trophies: 6 },
  { ...identity("fenway-faithful", { username: "FenwayFaithful", initials: "FF" }), friend: true, teamKeys: [teamKeys.redSox], leagueIds: ["baseball-mlb"], sportIds: ["baseball"], fanScores: { [teamKeys.redSox]: 23990 }, trophies: 9 },
  { ...identity("coach-view", { username: "CoachView", initials: "CV" }), friend: true, teamKeys: [teamKeys.patriots], leagueIds: ["football-nfl"], sportIds: ["football"], fanScores: { [teamKeys.patriots]: 17120 }, trophies: 5 },
  { ...identity("road-game-rob", { username: "RoadGameRob", initials: "RR" }), friend: true, teamKeys: [teamKeys.patriots, teamKeys.bruins], leagueIds: ["football-nfl", "hockey-nhl"], sportIds: ["football", "hockey"], fanScores: { [teamKeys.patriots]: 19280, [teamKeys.bruins]: 11840 }, trophies: 8 },
  { id: "ice-district-erin", username: "IceDistrictErin", initials: "IE", teamKeys: [teamKeys.oilers], leagueIds: ["hockey-nhl"], sportIds: ["hockey"], fanScores: { [teamKeys.oilers]: 24760 }, trophies: 10 },
  { id: "sunday-scout", username: "SundayScout", initials: "SS", teamKeys: [teamKeys.jets], leagueIds: ["football-nfl"], sportIds: ["football"], fanScores: { [teamKeys.jets]: 15820 }, trophies: 4 },
  { id: "diamond-metric", username: "DiamondMetric", initials: "DM", teamKeys: [teamKeys.redSox], leagueIds: ["baseball-mlb"], sportIds: ["baseball"], fanScores: { [teamKeys.redSox]: 16750 }, trophies: 4 },
  { id: "city-hoops", username: "CityHoops", initials: "CH", teamKeys: [teamKeys.celtics], leagueIds: ["basketball-nba"], sportIds: ["basketball"], fanScores: { [teamKeys.celtics]: 18970 }, trophies: 5 },
];

const mockQuizEvidence: readonly QuizEvidence[] = [
  ...seedQuizSeries("maya-84", "football", [92, 86, 90, 78, 94], 70, "Star"),
  ...seedQuizSeries("maya-84", "hockey", [88, 96, 84, 90, 92, 82], 67, "Star"),
  ...seedQuizSeries("green-line", "basketball", [96, 92, 88, 94, 86, 90], 65, "All-Star"),
  ...seedQuizSeries("fenway-faithful", "baseball", [91, 86, 94, 82, 88, 90], 69, "Star"),
  ...seedQuizSeries("coach-view", "football", [84, 80, 88, 76, 90, 82], 72, "League Average"),
  ...seedQuizSeries("road-game-rob", "football", [78, 86, 80, 74, 88], 71, "League Average"),
  ...seedQuizSeries("road-game-rob", "hockey", [72, 82, 78], 73, "Grinder"),
  ...seedQuizSeries("ice-district-erin", "hockey", [94, 90, 96, 88, 92, 98, 86], 64, "All-Star"),
  ...seedQuizSeries("sunday-scout", "football", [82, 76, 86, 80, 74], 74, "Grinder"),
  ...seedQuizSeries("diamond-metric", "baseball", [86, 80, 90, 84, 78], 70, "Star"),
  ...seedQuizSeries("city-hoops", "basketball", [88, 84, 92, 78, 86], 71, "Star"),
];

const mockPredictorEvidence: readonly PredictorEvidence[] = [
  ...seedPredictionSeries("maya-84", "football", [88, 76, 91, 84, 80, 94]),
  ...seedPredictionSeries("maya-84", "hockey", [82, 90, 76, 88, 84, 92]),
  ...seedPredictionSeries("green-line", "basketball", [86, 79, 91, 83, 88]),
  ...seedPredictionSeries("fenway-faithful", "baseball", [78, 88, 82, 91, 74, 86]),
  ...seedPredictionSeries("coach-view", "football", [73, 81, 76, 84, 79]),
  ...seedPredictionSeries("road-game-rob", "football", [71, 78, 82, 75, 80]),
  ...seedPredictionSeries("road-game-rob", "hockey", [68, 77, 73]),
  ...seedPredictionSeries("ice-district-erin", "hockey", [92, 88, 95, 84, 90, 93, 87]),
  ...seedPredictionSeries("sunday-scout", "football", [70, 74, 68, 81, 76]),
  ...seedPredictionSeries("diamond-metric", "baseball", [84, 76, 88, 79, 86]),
  ...seedPredictionSeries("city-hoops", "basketball", [77, 83, 80, 86, 74]),
];

function seedQuizSeries(userId: string, sportId: OfficialSportId, scores: readonly number[], peerAverage: number, difficulty: QuizDifficulty): QuizEvidence[] {
  return scores.map((score) => ({ userId, sportId, score, peerAverage, difficulty, questions: 10 }));
}

function seedPredictionSeries(userId: string, sportId: OfficialSportId, ratings: readonly number[]): PredictorEvidence[] {
  return ratings.map((rating) => {
    const totalError = Math.max(0, Math.round((100 - rating) / 8));
    return { userId, sportId, rating, correctWinner: rating >= 70, exactScore: rating >= 94, teamAError: Math.ceil(totalError / 2), teamBError: Math.floor(totalError / 2) };
  });
}

function clamp(value: number, minimum = 0, maximum = 100) {
  return Math.min(maximum, Math.max(minimum, value));
}

function quizSummary(evidence: readonly QuizEvidence[]): QuizIqSummary {
  if (!evidence.length) return { iq: null, attempts: 0, questions: 0, correctAnswers: 0, averageScore: 0 };
  const weighted = evidence.reduce((total, item) => {
    const relativePerformance = clamp(50 + (item.score - item.peerAverage) * 1.5);
    const normalized = item.score * 0.65 + relativePerformance * 0.35;
    return total + normalized * difficultyWeight[item.difficulty] * item.questions;
  }, 0);
  const weight = evidence.reduce((total, item) => total + difficultyWeight[item.difficulty] * item.questions, 0);
  const questions = evidence.reduce((total, item) => total + item.questions, 0);
  const averageScore = evidence.reduce((total, item) => total + item.score, 0) / evidence.length;
  const confidence = Math.min(1, questions / 100);
  return {
    iq: Math.round(50 + (weighted / weight - 50) * confidence),
    attempts: evidence.length,
    questions,
    correctAnswers: Math.round(evidence.reduce((total, item) => total + item.score / 100 * item.questions, 0)),
    averageScore: Math.round(averageScore),
  };
}

function predictorSummary(evidence: readonly PredictorEvidence[], qualifiedRatings: readonly number[]): PredictorIqSummary {
  if (!evidence.length) return { iq: null, percentile: null, qualified: false, predictions: 0, winnerAccuracy: 0, exactScores: 0, averageTeamAError: 0, averageTeamBError: 0, averageTotalScoreError: 0 };
  const average = (pick: (item: PredictorEvidence) => number) => evidence.reduce((total, item) => total + pick(item), 0) / evidence.length;
  const iq = Math.round(average((item) => item.rating));
  const qualified = evidence.length >= sportsStatsPredictorMinimum;
  return {
    iq,
    percentile: qualified ? Math.round(qualifiedRatings.filter((rating) => rating <= iq).length / Math.max(1, qualifiedRatings.length) * 100) : null,
    qualified,
    predictions: evidence.length,
    winnerAccuracy: Math.round(average((item) => Number(item.correctWinner)) * 100),
    exactScores: evidence.filter((item) => item.exactScore).length,
    averageTeamAError: Number(average((item) => item.teamAError).toFixed(1)),
    averageTeamBError: Number(average((item) => item.teamBError).toFixed(1)),
    averageTotalScoreError: Number(average((item) => item.teamAError + item.teamBError).toFixed(1)),
  };
}

function actualQuizEvidence(): QuizEvidence[] {
  return mockQuizAttempts.flatMap((attempt) => {
    const quiz = mockQuizCatalog.find((candidate) => candidate.id === attempt.quizId);
    const sport = quiz ? findOfficialSportByName(quiz.sport) : null;
    return quiz && sport ? [{ userId: demoUser.id, sportId: sport.id, score: attempt.score, peerAverage: quiz.averageScore, difficulty: quiz.difficulty, questions: quiz.questionCount }] : [];
  });
}

function actualPredictorEvidence(): PredictorEvidence[] {
  return loadGamePredictions(initialGameThreads).flatMap((record) => record.userId === demoUser.id && record.resolution ? [{
    userId: record.userId,
    sportId: record.sportId,
    rating: record.resolution.predictorRating,
    correctWinner: record.resolution.correctWinner,
    exactScore: record.resolution.exactScore,
    teamAError: record.resolution.teamAScoreError,
    teamBError: record.resolution.teamBScoreError,
  }] : []);
}

export function resolveFanbaseCompetition(team: FollowedTeam): FanbaseCompetition {
  const officialTeam = officialTeams.find((candidate) => candidate.displayName === team.name);
  const sport = findOfficialSportByName(team.sport) ?? findOfficialSportByName("Generic")!;
  const league = officialTeam ? findOfficialLeague(officialTeam.parentLeagueId) : findOfficialLeagueByName(sport.id, team.league);
  return {
    teamKey: officialTeam?.id ?? `fanbase:${team.id}`,
    teamName: team.name,
    leagueId: league?.id ?? `${sport.id}-${team.league.toLocaleLowerCase().replaceAll(/[^a-z0-9]+/g, "-")}`,
    leagueName: league?.displayName ?? team.league,
    sportId: sport.id,
    sportName: sport.displayName,
  };
}

export function buildSportsStatsSnapshot(): readonly SportsStatsUser[] {
  const quizEvidence = [...mockQuizEvidence, ...actualQuizEvidence()];
  const predictionEvidence = [...mockPredictorEvidence, ...actualPredictorEvidence()];
  const qualifiedRatingsBySport = new Map<OfficialSportId, number[]>();
  for (const sportId of ["football", "baseball", "basketball", "hockey", "soccer", "generic", "other"] as const) {
    const ratings = userSeeds.flatMap((user) => {
      const records = predictionEvidence.filter((item) => item.userId === user.id && item.sportId === sportId);
      return records.length >= sportsStatsPredictorMinimum ? [Math.round(records.reduce((sum, item) => sum + item.rating, 0) / records.length)] : [];
    });
    qualifiedRatingsBySport.set(sportId, ratings);
  }

  return userSeeds.map((user) => {
    const sports = user.sportIds.map((sportId): SportIqSummary => {
      const sportName = findOfficialSportByName(sportId[0]!.toLocaleUpperCase() + sportId.slice(1))?.displayName ?? sportId;
      const quiz = quizSummary(quizEvidence.filter((item) => item.userId === user.id && item.sportId === sportId));
      const predictor = predictorSummary(predictionEvidence.filter((item) => item.userId === user.id && item.sportId === sportId), qualifiedRatingsBySport.get(sportId) ?? []);
      const availableWeight = (quiz.iq === null ? 0 : sportIqWeights.quiz) + (predictor.iq === null ? 0 : sportIqWeights.predictor);
      const sportIq = availableWeight ? Math.round(((quiz.iq ?? 0) * sportIqWeights.quiz + (predictor.iq ?? 0) * sportIqWeights.predictor) / availableWeight) : null;
      return { sportId, sportName, sportIq, evidenceUnits: quiz.questions + predictor.predictions * 10, quiz, predictor };
    });
    const weightedSports = sports.filter((sport) => sport.sportIq !== null && sport.evidenceUnits > 0);
    const evidenceUnits = weightedSports.reduce((sum, sport) => sum + sport.evidenceUnits, 0);
    const overallSportIq = evidenceUnits ? Math.round(weightedSports.reduce((sum, sport) => sum + sport.sportIq! * sport.evidenceUnits, 0) / evidenceUnits) : null;
    return { ...user, friend: user.friend ?? false, overallSportIq, sports };
  });
}

export function sportsStatsUser(userId: string, snapshot = buildSportsStatsSnapshot()) {
  return snapshot.find((user) => user.id === userId) ?? null;
}

export function sportSummaryForUser(user: SportsStatsUser, sportId: OfficialSportId) {
  return user.sports.find((sport) => sport.sportId === sportId) ?? null;
}

export function fanScoreForUser(user: SportsStatsUser, teamKey: string) {
  return user.fanScores[teamKey] ?? null;
}

export function officialTeamName(teamKey: string) {
  return findOfficialTeam(teamKey)?.displayName ?? (teamKey === teamKeys.celtics ? "Boston Celtics" : "Team FANbase");
}
