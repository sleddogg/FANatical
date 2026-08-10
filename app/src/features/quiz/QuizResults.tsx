import { useEffect } from "react";
import type { QuizRecord } from "./types";

type QuizResultsProps = {
  readonly quiz: QuizRecord;
  readonly correctAnswers: number;
  readonly onNextQuiz: () => void;
  readonly onChangeDifficulty: () => void;
  readonly onChangeLeague: () => void;
  readonly onQuizHub: () => void;
};

export function QuizResults({ quiz, correctAnswers, onNextQuiz, onChangeDifficulty, onChangeLeague, onQuizHub }: QuizResultsProps) {
  const percentage = correctAnswers * 10;
  const fanScore = Math.max(50, correctAnswers * 60);
  const fanCoins = correctAnswers * 2;

  useEffect(() => {
    document.body.classList.add("quiz-immersive-active");
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.classList.remove("quiz-immersive-active");
      document.body.style.overflow = previousOverflow;
    };
  }, []);

  return (
    <section className="quiz-results-screen" aria-labelledby="quiz-results-title">
      <article className="quiz-results-surface">
        <span className="eyebrow">Quiz complete</span>
        <h1 id="quiz-results-title">{quiz.title}</h1>
        <div className="quiz-results-score"><strong>{percentage}%</strong><span>{correctAnswers} correct answers out of 10</span></div>
        <dl>
          <div><dt>Fan Score earned</dt><dd>+{fanScore}</dd></div>
          <div><dt>Fan Coins earned</dt><dd>+{fanCoins}</dd></div>
          <div><dt>Status</dt><dd>Completed</dd></div>
        </dl>
        <p className="quiz-results-note">Reward values are local demo values; final scoring and reward formulas remain a product decision.</p>
        <div className="quiz-results-actions">
          <button className="quiz-results-actions__primary" type="button" onClick={onNextQuiz}>Next Quiz</button>
          <div className="quiz-results-actions__secondary"><button type="button" onClick={onChangeDifficulty}>Change Difficulty</button><button type="button" onClick={onChangeLeague}>Change League</button></div>
          <button className="quiz-results-actions__hub" type="button" onClick={onQuizHub}>Quiz Hub</button>
        </div>
      </article>
    </section>
  );
}
