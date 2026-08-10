export const quizSports = ["Hockey", "Football", "Baseball", "Basketball"] as const;
export type QuizSport = (typeof quizSports)[number];

export const quizDifficulties = ["All-Star", "Star", "League Average", "Grinder", "Rookie"] as const;
export type QuizDifficulty = (typeof quizDifficulties)[number];

export type QuizQuestion = Readonly<{
  id: string;
  prompt: string;
  answers: readonly [string, string, string, string];
  correctAnswerIndex: 0 | 1 | 2 | 3;
}>;

export type QuizRecord = Readonly<{
  id: string;
  sport: QuizSport;
  league: string;
  difficulty: QuizDifficulty;
  topic: string;
  title: string;
  description: string;
  questionCount: 10;
  questionSetId: QuizSport;
  averageScore: number;
  createdBy: string;
  approvalStatus: "Approved";
  tags: readonly string[];
}>;

export type QuizAttempt = Readonly<{
  id: string;
  quizId: QuizRecord["id"];
  score: number;
  completedAt: string;
  completionStatus: "Completed";
}>;

export type QuizSelectionPath = "random" | "browse" | "retake";

export type QuizQuestionDraft = {
  id: string;
  prompt: string;
  answers: [string, string, string, string];
  correctAnswerIndex: 0 | 1 | 2 | 3 | null;
};

export type QuizSubmissionRecord = Readonly<{
  id: string;
  sport: QuizSport;
  league: string;
  submittedDifficulty: QuizDifficulty;
  topic: string;
  tags: readonly string[];
  title: string;
  description: string;
  questionCount: 10;
  questions: readonly QuizQuestion[];
  createdBy: string;
  createdAt: string;
  approvalStatus: "Pending Review";
}>;
