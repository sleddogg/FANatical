import type { QuizAttempt, QuizRecord, QuizSport } from "./types";

const daysAgo = (days: number) => new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

export const quizLeagues: Readonly<Record<QuizSport, readonly string[]>> = {
  Hockey: ["NHL", "AHL", "PWHL"],
  Football: ["NFL", "CFL", "UFL"],
  Baseball: ["MLB", "NPB", "KBO"],
  Basketball: ["NBA", "WNBA", "EuroLeague"],
};

export const mockQuizStats = {
  streak: "5 days",
  today: "2 / 3",
  fanScore: "12,450",
  fanCoins: "320",
  completed: "42",
  averageScore: "78%",
} as const;

export const MOCK_RETAKE_COOLDOWN_DAYS = 14;

const quiz = (record: Omit<QuizRecord, "questionSetId">): QuizRecord => ({ ...record, questionSetId: record.sport });

const baseQuizCatalog: readonly Omit<QuizRecord, "questionSetId">[] = [
  { id: "nfl-rookie-rules", sport: "Football", league: "NFL", difficulty: "Rookie", topic: "Rules", title: "NFL Rules: First Down Fundamentals", description: "Build confidence with downs, scoring, field markings, and the shape of a standard game.", questionCount: 10, averageScore: 84, createdBy: "FANatical Quiz Desk", approvalStatus: "Approved", tags: ["rules", "scoring"] },
  { id: "nfl-rookie-legends", sport: "Football", league: "NFL", difficulty: "Rookie", topic: "Players", title: "NFL Legends: Names Every Fan Knows", description: "Match iconic players with the teams, positions, and moments that made them famous.", questionCount: 10, averageScore: 79, createdBy: "GridironArchivist", approvalStatus: "Approved", tags: ["players", "history"] },
  { id: "nfl-rookie-moments", sport: "Football", league: "NFL", difficulty: "Rookie", topic: "Moments", title: "Sunday Moments: The Modern NFL", description: "A quick tour through memorable recent plays, celebrations, and championship Sundays.", questionCount: 10, averageScore: 81, createdBy: "FANatical Quiz Desk", approvalStatus: "Approved", tags: ["moments", "playoffs"] },
  { id: "nfl-grinder-draft", sport: "Football", league: "NFL", difficulty: "Grinder", topic: "Draft", title: "Inside the NFL Draft Room", description: "Test the picks, trades, terminology, and strategy behind draft weekend.", questionCount: 10, averageScore: 68, createdBy: "CoachView", approvalStatus: "Approved", tags: ["draft", "transactions"] },
  { id: "nfl-star-playoffs", sport: "Football", league: "NFL", difficulty: "Star", topic: "Playoffs", title: "The Road to the Super Bowl", description: "Wild cards, playoff records, and championship details for committed football fans.", questionCount: 10, averageScore: 61, createdBy: "FANatical Quiz Desk", approvalStatus: "Approved", tags: ["playoffs", "records"] },
  { id: "cfl-league-average-history", sport: "Football", league: "CFL", difficulty: "League Average", topic: "History", title: "Canadian Football Through the Years", description: "Teams, Grey Cup milestones, and the details that make Canadian football distinct.", questionCount: 10, averageScore: 72, createdBy: "NorthStarFan", approvalStatus: "Approved", tags: ["history", "rules"] },
  { id: "ufl-rookie-teams", sport: "Football", league: "UFL", difficulty: "Rookie", topic: "General Knowledge", title: "Meet the UFL", description: "A welcoming introduction to UFL teams, cities, and league basics.", questionCount: 10, averageScore: 77, createdBy: "FANatical Quiz Desk", approvalStatus: "Approved", tags: ["teams", "rules"] },
  { id: "nhl-rookie-basics", sport: "Hockey", league: "NHL", difficulty: "Rookie", topic: "Rules", title: "Hockey Basics: From Faceoff to Final Horn", description: "Periods, penalties, scoring, and the essential language of an NHL game.", questionCount: 10, averageScore: 86, createdBy: "FANatical Quiz Desk", approvalStatus: "Approved", tags: ["rules", "scoring"] },
  { id: "nhl-star-history", sport: "Hockey", league: "NHL", difficulty: "Star", topic: "History", title: "Stanley Cup Stories", description: "Championship runs, historic franchises, and unforgettable names from hockey history.", questionCount: 10, averageScore: 63, createdBy: "IceTimeMaya", approvalStatus: "Approved", tags: ["history", "playoffs"] },
  { id: "ahl-grinder-prospects", sport: "Hockey", league: "AHL", difficulty: "Grinder", topic: "Players", title: "Tomorrow's Hockey Stars", description: "Prospects, affiliates, and the player-development path through the AHL.", questionCount: 10, averageScore: 69, createdBy: "ProspectWatch", approvalStatus: "Approved", tags: ["players", "teams"] },
  { id: "pwhl-league-average-moments", sport: "Hockey", league: "PWHL", difficulty: "League Average", topic: "Moments", title: "PWHL Milestones", description: "Breakthrough games, league firsts, and the stars shaping a new hockey era.", questionCount: 10, averageScore: 74, createdBy: "FANatical Quiz Desk", approvalStatus: "Approved", tags: ["moments", "players"] },
  { id: "mlb-rookie-rules", sport: "Baseball", league: "MLB", difficulty: "Rookie", topic: "Rules", title: "Baseball by the Numbers", description: "Outs, innings, bases, and scoring for fans building their baseball foundation.", questionCount: 10, averageScore: 88, createdBy: "FenwayFaithful", approvalStatus: "Approved", tags: ["rules", "scoring"] },
  { id: "mlb-grinder-ballparks", sport: "Baseball", league: "MLB", difficulty: "Grinder", topic: "History", title: "Cathedrals of Baseball", description: "Identify famous ballparks through their history, dimensions, and signature details.", questionCount: 10, averageScore: 67, createdBy: "FANatical Quiz Desk", approvalStatus: "Approved", tags: ["history", "teams"] },
  { id: "npb-star-champions", sport: "Baseball", league: "NPB", difficulty: "Star", topic: "Playoffs", title: "Japan Series Champions", description: "A challenging look at NPB postseason history and championship clubs.", questionCount: 10, averageScore: 58, createdBy: "DiamondWorld", approvalStatus: "Approved", tags: ["playoffs", "history"] },
  { id: "nba-rookie-stars", sport: "Basketball", league: "NBA", difficulty: "Rookie", topic: "Players", title: "NBA Stars and Their Teams", description: "Connect leading players with their teams, positions, and signature skills.", questionCount: 10, averageScore: 85, createdBy: "GreenLine", approvalStatus: "Approved", tags: ["players", "teams"] },
  { id: "nba-all-star-records", sport: "Basketball", league: "NBA", difficulty: "All-Star", topic: "Records", title: "NBA Record Book", description: "The toughest numbers, streaks, and all-time achievements in NBA history.", questionCount: 10, averageScore: 49, createdBy: "FANatical Quiz Desk", approvalStatus: "Approved", tags: ["records", "history"] },
  { id: "wnba-league-average-history", sport: "Basketball", league: "WNBA", difficulty: "League Average", topic: "History", title: "WNBA Teams, Titles, and Trailblazers", description: "Celebrate championship teams and the players who shaped the league.", questionCount: 10, averageScore: 73, createdBy: "HoopsHistorian", approvalStatus: "Approved", tags: ["history", "players"] },
];

export const mockQuizCatalog: readonly QuizRecord[] = baseQuizCatalog.map(quiz);

export const mockQuizAttempts: readonly QuizAttempt[] = [
  { id: "attempt-nfl-rules", quizId: "nfl-rookie-rules", score: 100, completedAt: daysAgo(22), completionStatus: "Completed" },
  { id: "attempt-nfl-legends", quizId: "nfl-rookie-legends", score: 80, completedAt: daysAgo(5), completionStatus: "Completed" },
  { id: "attempt-nhl-history", quizId: "nhl-star-history", score: 90, completedAt: daysAgo(20), completionStatus: "Completed" },
  { id: "attempt-mlb-ballparks", quizId: "mlb-grinder-ballparks", score: 70, completedAt: daysAgo(16), completionStatus: "Completed" },
];
