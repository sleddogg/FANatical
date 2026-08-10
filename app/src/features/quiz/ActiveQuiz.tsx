import { useCallback, useEffect, useRef, useState } from "react";
import type { QuizQuestion, QuizRecord } from "./types";

export const QUIZ_TIMER_SECONDS = 15;
export const QUIZ_FEEDBACK_DELAY_MS = 2000;

type ActiveQuizProps = {
  readonly quiz: QuizRecord;
  readonly questions: readonly QuizQuestion[];
  readonly onComplete: (correctAnswers: number) => void;
};

export function ActiveQuiz({ quiz, questions, onComplete }: ActiveQuizProps) {
  const [questionIndex, setQuestionIndex] = useState(0);
  const [selectedAnswer, setSelectedAnswer] = useState<number | null>(null);
  const [locked, setLocked] = useState(false);
  const [timeLeft, setTimeLeft] = useState(QUIZ_TIMER_SECONDS);
  const [correctAnswers, setCorrectAnswers] = useState(0);
  const [feedback, setFeedback] = useState("");
  const lockedRef = useRef(false);
  const questionIndexRef = useRef(0);
  const correctAnswersRef = useRef(0);
  const advanceTimeoutRef = useRef<number | null>(null);
  const question = questions[questionIndex];

  useEffect(() => {
    document.body.classList.add("quiz-immersive-active");
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.classList.remove("quiz-immersive-active");
      document.body.style.overflow = previousOverflow;
      if (advanceTimeoutRef.current !== null) window.clearTimeout(advanceTimeoutRef.current);
    };
  }, []);

  const finishQuestion = useCallback((submittedAnswer: number | null) => {
    if (lockedRef.current || !question) return;
    lockedRef.current = true;
    setLocked(true);
    const correct = submittedAnswer === question.correctAnswerIndex;
    const nextCorrectAnswers = correctAnswersRef.current + (correct ? 1 : 0);
    correctAnswersRef.current = nextCorrectAnswers;
    setCorrectAnswers(nextCorrectAnswers);
    setFeedback(submittedAnswer === null ? "Time expired. The correct answer is shown." : correct ? "Correct!" : "Not quite. The correct answer is shown.");

    advanceTimeoutRef.current = window.setTimeout(() => {
      if (questionIndexRef.current === questions.length - 1) {
        onComplete(nextCorrectAnswers);
        return;
      }
      const nextIndex = questionIndexRef.current + 1;
      questionIndexRef.current = nextIndex;
      setQuestionIndex(nextIndex);
      setSelectedAnswer(null);
      setTimeLeft(QUIZ_TIMER_SECONDS);
      setFeedback("");
      lockedRef.current = false;
      setLocked(false);
    }, QUIZ_FEEDBACK_DELAY_MS);
  }, [onComplete, question, questions.length]);

  useEffect(() => {
    if (locked) return;
    const timer = window.setInterval(() => setTimeLeft((current) => Math.max(0, current - 1)), 1000);
    return () => window.clearInterval(timer);
  }, [locked, questionIndex]);

  useEffect(() => {
    if (timeLeft === 0 && !locked) finishQuestion(null);
  }, [finishQuestion, locked, timeLeft]);

  if (!question) return null;

  return (
    <section className="active-quiz-screen" aria-labelledby="active-quiz-question">
      <article className="active-quiz-surface">
        <header>
          <div className="active-quiz-context"><span>{quiz.league}</span><span>{quiz.difficulty}</span></div>
          <div className="active-quiz-timer" role="timer" aria-label={`${timeLeft} seconds remaining`}><span><b>{timeLeft}</b>s</span><div aria-hidden="true"><i style={{ width: `${(timeLeft / QUIZ_TIMER_SECONDS) * 100}%` }} /></div></div>
        </header>
        <div className="active-quiz-progress"><strong>{quiz.title}</strong><span>Question {questionIndex + 1} of 10</span></div>
        <h1 id="active-quiz-question">{question.prompt}</h1>
        <div className="active-quiz-answers" role="group" aria-label="Answer choices">
          {question.answers.map((answer, answerIndex) => {
            const state = locked
              ? answerIndex === question.correctAnswerIndex ? "correct" : answerIndex === selectedAnswer ? "incorrect" : "locked"
              : answerIndex === selectedAnswer ? "selected" : "idle";
            return <button key={answer} type="button" data-state={state} aria-pressed={selectedAnswer === answerIndex} disabled={locked} onClick={() => setSelectedAnswer(answerIndex)}><span aria-hidden="true">{String.fromCharCode(65 + answerIndex)}</span><strong>{answer}</strong>{locked && answerIndex === question.correctAnswerIndex ? <small>Correct</small> : null}</button>;
          })}
        </div>
        <footer>
          <p aria-live="polite">{feedback || `${correctAnswers} correct so far`}</p>
          <button type="button" disabled={selectedAnswer === null || locked} onClick={() => finishQuestion(selectedAnswer)}>Submit answer</button>
        </footer>
      </article>
    </section>
  );
}
