import { useEffect, useMemo, useRef, useState } from "react";
import { quizLeagues } from "./mockQuizData";
import { AppIcon } from "../../components/AppIcon";
import {
  quizDifficulties,
  quizSports,
  type QuizDifficulty,
  type QuizQuestionDraft,
  type QuizSport,
  type QuizSubmissionRecord,
} from "./types";

type CreateQuizStage = "identity" | "details" | "questions" | "review" | "success";

type CreateQuizFlowProps = {
  readonly onClose: () => void;
  readonly onSubmit: (submission: QuizSubmissionRecord) => void;
};

const topicOptions = ["Rules", "General Knowledge", "History", "Players", "Playoffs", "Records", "Awards", "Transactions", "Draft", "Rivalries", "Moments"] as const;
const answerIndexes = [0, 1, 2, 3] as const;

const createQuestionDrafts = (): QuizQuestionDraft[] => Array.from({ length: 10 }, (_, index) => ({
  id: `draft-question-${index + 1}`,
  prompt: "",
  answers: ["", "", "", ""],
  correctAnswerIndex: null,
}));

const isQuestionComplete = (question: QuizQuestionDraft) => question.prompt.trim().length > 0
  && question.answers.every((answer) => answer.trim().length > 0)
  && question.correctAnswerIndex !== null;

function CreationHeader({ title, context, onBack }: { readonly title: string; readonly context?: string; readonly onBack?: () => void }) {
  return (
    <header className="create-quiz-stage-header">
      <div>{onBack ? <button type="button" aria-label="Back one creation stage" onClick={onBack}><AppIcon name="arrow-left" /><span>Back</span></button> : null}</div>
      <h2 id="create-quiz-stage-title" tabIndex={-1}>{title}</h2>
      <div>{context ? <span>{context}</span> : null}</div>
    </header>
  );
}

export function CreateQuizFlow({ onClose, onSubmit }: CreateQuizFlowProps) {
  const dialogRef = useRef<HTMLElement>(null);
  const confirmRef = useRef<HTMLElement>(null);
  const headingRef = useRef<HTMLHeadingElement | null>(null);
  const [stage, setStage] = useState<CreateQuizStage>("identity");
  const [sport, setSport] = useState<QuizSport | "">("");
  const [league, setLeague] = useState("");
  const [difficulty, setDifficulty] = useState<QuizDifficulty | "">("");
  const [topic, setTopic] = useState("");
  const [tagsInput, setTagsInput] = useState("");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [questions, setQuestions] = useState<QuizQuestionDraft[]>(createQuestionDrafts);
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
  const [editingFromReview, setEditingFromReview] = useState(false);
  const [confirmExitOpen, setConfirmExitOpen] = useState(false);
  const [validationMessage, setValidationMessage] = useState("");
  const [submittedId, setSubmittedId] = useState("");

  const tags = useMemo(() => [...new Set(tagsInput.split(",").map((tag) => tag.trim()).filter(Boolean))], [tagsInput]);
  const completedQuestions = questions.filter(isQuestionComplete).length;
  const allQuestionsComplete = completedQuestions === 10;
  const identityComplete = Boolean(sport && league && difficulty && topic);
  const detailsComplete = title.trim().length > 0 && description.trim().length > 0;
  const currentQuestion = questions[currentQuestionIndex];
  const hasDraftContent = Boolean(sport || league || difficulty || topic || tagsInput.trim() || title.trim() || description.trim()
    || questions.some((question) => question.prompt.trim() || question.answers.some((answer) => answer.trim()) || question.correctAnswerIndex !== null));
  const context = [sport, league, difficulty].filter(Boolean).join(" · ");

  const requestClose = () => {
    if (stage !== "success" && hasDraftContent) setConfirmExitOpen(true);
    else onClose();
  };

  useEffect(() => {
    document.body.classList.add("quiz-create-active");
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.classList.remove("quiz-create-active");
      document.body.style.overflow = previousOverflow;
    };
  }, []);

  useEffect(() => {
    const heading = dialogRef.current?.querySelector<HTMLHeadingElement>("#create-quiz-stage-title");
    headingRef.current = heading ?? null;
    headingRef.current?.focus();
  }, [stage]);

  useEffect(() => {
    if (confirmExitOpen) confirmRef.current?.querySelector<HTMLButtonElement>("button")?.focus();
  }, [confirmExitOpen]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        if (confirmExitOpen) setConfirmExitOpen(false);
        else requestClose();
        return;
      }
      if (event.key !== "Tab") return;
      const focusRoot = confirmExitOpen ? confirmRef.current : dialogRef.current;
      const focusable = [...(focusRoot?.querySelectorAll<HTMLElement>("button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex='-1'])") ?? [])];
      const first = focusable.at(0);
      const last = focusable.at(-1);
      if (!first || !last) return;
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  });

  const updateQuestion = (update: (question: QuizQuestionDraft) => QuizQuestionDraft) => {
    setQuestions((current) => current.map((question, index) => index === currentQuestionIndex ? update(question) : question));
    setValidationMessage("");
  };

  const updateAnswer = (answerIndex: 0 | 1 | 2 | 3, value: string) => {
    updateQuestion((question) => {
      const answers: [string, string, string, string] = [...question.answers];
      answers[answerIndex] = value;
      return { ...question, answers };
    });
  };

  const backStage = () => {
    setValidationMessage("");
    if (stage === "details") setStage("identity");
    else if (stage === "questions") {
      if (editingFromReview) {
        setEditingFromReview(false);
        setStage("review");
      } else setStage("details");
    }
    else if (stage === "review") setStage("questions");
  };

  const openReview = () => {
    if (!allQuestionsComplete) {
      setValidationMessage(`Complete all 10 questions before review. ${10 - completedQuestions} remaining.`);
      return;
    }
    setValidationMessage("");
    setEditingFromReview(false);
    setStage("review");
  };

  const submitQuiz = () => {
    if (!identityComplete || !detailsComplete || !allQuestionsComplete || !sport || !difficulty) {
      setValidationMessage("This quiz is incomplete. Return to editing and complete every required field.");
      return;
    }
    const completeQuestions = questions.map((question, index) => {
      if (question.correctAnswerIndex === null) throw new Error(`Question ${index + 1} does not have a correct answer.`);
      return {
        id: `submitted-question-${index + 1}`,
        prompt: question.prompt.trim(),
        answers: question.answers.map((answer) => answer.trim()) as [string, string, string, string],
        correctAnswerIndex: question.correctAnswerIndex,
      };
    });
    const submissionId = `quiz-submission-${Date.now()}`;
    onSubmit({
      id: submissionId,
      sport,
      league,
      submittedDifficulty: difficulty,
      topic,
      tags,
      title: title.trim(),
      description: description.trim(),
      questionCount: 10,
      questions: completeQuestions,
      createdBy: "Demo FANatical User",
      createdAt: new Date().toISOString(),
      approvalStatus: "Pending Review",
    });
    setSubmittedId(submissionId);
    setStage("success");
  };

  const progressStage = stage === "identity" ? 0 : stage === "details" ? 1 : stage === "questions" ? 2 : 3;
  const stageTitle = stage === "identity" ? "Quiz Identity" : stage === "details" ? "Quiz Details" : stage === "questions" ? "Write Questions" : stage === "review" ? "Review Quiz" : "Quiz Submitted";

  return (
    <section ref={dialogRef} className="create-quiz-screen" role="dialog" aria-modal="true" aria-labelledby="create-quiz-stage-title">
      <div className="create-quiz-shell">
        <div className="create-quiz-topline"><strong>Create Quiz</strong><button type="button" aria-label="Exit Create Quiz" onClick={requestClose}><AppIcon name="x-mark" /></button></div>
        {stage !== "success" ? <div className="create-quiz-progress" aria-label={`${stageTitle} creation stage`}>{[0, 1, 2, 3].map((position) => <span key={position} data-state={position < progressStage ? "complete" : position === progressStage ? "current" : "upcoming"} />)}</div> : null}

        {stage === "identity" ? (
          <main className="create-quiz-stage">
            <CreationHeader title="Quiz Identity" />
            <div className="create-quiz-field-grid">
              <label><span>Sport</span><select value={sport} onChange={(event) => { setSport(event.target.value as QuizSport | ""); setLeague(""); }}><option value="">Choose a sport</option>{quizSports.map((option) => <option key={option} value={option}>{option}</option>)}</select></label>
              <label><span>League</span><select value={league} disabled={!sport} onChange={(event) => setLeague(event.target.value)}><option value="">Choose a league</option>{sport ? quizLeagues[sport].map((option) => <option key={option} value={option}>{option}</option>) : null}</select></label>
              <label><span>Difficulty</span><select aria-label="Difficulty" value={difficulty} onChange={(event) => setDifficulty(event.target.value as QuizDifficulty | "")}><option value="">Suggest a difficulty</option>{quizDifficulties.map((option) => <option key={option} value={option}>{option}</option>)}</select><small>Performance-based calibration can remain separate later.</small></label>
              <label><span>Topic / category</span><select value={topic} onChange={(event) => setTopic(event.target.value)}><option value="">Choose a topic</option>{topicOptions.map((option) => <option key={option} value={option}>{option}</option>)}</select></label>
              <label className="create-quiz-field-grid__wide"><span>Optional tags</span><input aria-label="Optional tags" value={tagsInput} maxLength={160} placeholder="team, player, season" onChange={(event) => setTagsInput(event.target.value)} aria-describedby="create-quiz-tags-help" /><small id="create-quiz-tags-help">Separate tags with commas.</small></label>
            </div>
            {tags.length ? <div className="create-quiz-tags" aria-label="Quiz tags">{tags.map((tag) => <span key={tag}>{tag}</span>)}</div> : null}
            <div className="create-quiz-stage-actions"><button type="button" disabled={!identityComplete} onClick={() => setStage("details")}>Continue to details</button></div>
          </main>
        ) : null}

        {stage === "details" ? (
          <main className="create-quiz-stage">
            <CreationHeader title="Quiz Details" context={context} onBack={backStage} />
            <div className="create-quiz-details-form">
              <label><span>Quiz title</span><input aria-label="Quiz title" value={title} maxLength={90} placeholder="Give fans a clear, memorable title" onChange={(event) => setTitle(event.target.value)} /><small>{title.length} / 90</small></label>
              <label><span>Short description</span><textarea aria-label="Short description" value={description} maxLength={240} rows={5} placeholder="Tell fans what knowledge this quiz will test" onChange={(event) => setDescription(event.target.value)} /><small>{description.length} / 240</small></label>
            </div>
            <div className="create-quiz-stage-actions"><button type="button" disabled={!detailsComplete} onClick={() => setStage("questions")}>Write 10 questions</button></div>
          </main>
        ) : null}

        {stage === "questions" && currentQuestion ? (
          <main className="create-quiz-stage create-quiz-stage--questions">
            <CreationHeader title="Write Questions" context={`${completedQuestions} / 10 complete`} onBack={backStage} />
            <nav className="create-quiz-question-nav" aria-label="Quiz question navigation">{questions.map((question, index) => <button key={question.id} type="button" data-state={isQuestionComplete(question) ? "complete" : "incomplete"} aria-current={index === currentQuestionIndex ? "step" : undefined} aria-label={`Question ${index + 1} ${isQuestionComplete(question) ? "complete" : "incomplete"}`} onClick={() => { setCurrentQuestionIndex(index); setValidationMessage(""); }}>{index + 1}</button>)}</nav>
            <article className="create-quiz-question-card" aria-labelledby="create-question-heading">
              <header><div><span className="eyebrow">Question {currentQuestionIndex + 1} of 10</span><h3 id="create-question-heading">Build one complete question</h3></div><span data-state={isQuestionComplete(currentQuestion) ? "complete" : "incomplete"}>{isQuestionComplete(currentQuestion) ? "Complete" : "Incomplete"}</span></header>
              <label className="create-quiz-question-prompt"><span>Question text</span><textarea rows={3} maxLength={280} value={currentQuestion.prompt} placeholder="What do you want to ask?" onChange={(event) => updateQuestion((question) => ({ ...question, prompt: event.target.value }))} /></label>
              <fieldset><legend>Answer choices <small>Select the one correct answer.</small></legend><div className="create-quiz-answer-list">{answerIndexes.map((answerIndex) => { const answerLetter = String.fromCharCode(65 + answerIndex); const correctInputId = `${currentQuestion.id}-correct-${answerIndex}`; return <div className="create-quiz-answer-row" key={answerIndex} data-correct={currentQuestion.correctAnswerIndex === answerIndex}><input id={correctInputId} type="radio" name={`correct-${currentQuestion.id}`} checked={currentQuestion.correctAnswerIndex === answerIndex} aria-label={`Mark answer ${answerLetter} as correct`} onChange={() => updateQuestion((question) => ({ ...question, correctAnswerIndex: answerIndex }))} /><label htmlFor={correctInputId} aria-hidden="true">{answerLetter}</label><input type="text" maxLength={180} value={currentQuestion.answers[answerIndex]} aria-label={`Answer ${answerLetter}`} placeholder={`Answer ${answerLetter}`} onChange={(event) => updateAnswer(answerIndex, event.target.value)} /><small>{currentQuestion.correctAnswerIndex === answerIndex ? "Correct" : "Mark correct"}</small></div>; })}</div></fieldset>
            </article>
            {validationMessage ? <p className="create-quiz-validation" role="status">{validationMessage}</p> : null}
            <div className="create-quiz-question-actions"><button type="button" disabled={currentQuestionIndex === 0} onClick={() => setCurrentQuestionIndex((current) => Math.max(0, current - 1))}>Previous question</button>{currentQuestionIndex < 9 ? <button type="button" onClick={() => setCurrentQuestionIndex((current) => Math.min(9, current + 1))}>Next question</button> : null}{editingFromReview ? <button type="button" disabled={!allQuestionsComplete} onClick={openReview}>Return to Review</button> : <button type="button" disabled={!allQuestionsComplete} onClick={openReview}>Review Quiz</button>}</div>
          </main>
        ) : null}

        {stage === "review" ? (
          <main className="create-quiz-stage create-quiz-stage--review">
            <CreationHeader title="Review Quiz" context="Ready to submit" onBack={backStage} />
            <section className="create-quiz-review-summary" aria-label="Quiz summary"><span className="eyebrow">Pending submission</span><h3>{title}</h3><p>{description}</p><dl><div><dt>Sport</dt><dd>{sport}</dd></div><div><dt>League</dt><dd>{league}</dd></div><div><dt>Difficulty</dt><dd>{difficulty}</dd></div><div><dt>Topic</dt><dd>{topic}</dd></div></dl>{tags.length ? <div className="create-quiz-tags">{tags.map((tag) => <span key={tag}>{tag}</span>)}</div> : null}</section>
            <section className="create-quiz-review-questions" aria-label="All quiz questions">{questions.map((question, questionIndex) => <article key={question.id}><header><strong>Question {questionIndex + 1}</strong><button type="button" onClick={() => { setCurrentQuestionIndex(questionIndex); setEditingFromReview(true); setStage("questions"); }}>Edit question {questionIndex + 1}</button></header><h4>{question.prompt}</h4><ol type="A">{question.answers.map((answer, answerIndex) => <li key={`${question.id}-${answerIndex}`} data-correct={question.correctAnswerIndex === answerIndex}>{answer}{question.correctAnswerIndex === answerIndex ? <strong>Correct answer</strong> : null}</li>)}</ol></article>)}</section>
            {validationMessage ? <p className="create-quiz-validation" role="alert">{validationMessage}</p> : null}
            <div className="create-quiz-stage-actions"><button type="button" onClick={submitQuiz}>Submit Quiz</button></div>
          </main>
        ) : null}

        {stage === "success" ? (
          <main className="create-quiz-stage create-quiz-success">
            <CreationHeader title="Quiz Submitted" />
            <span className="create-quiz-success__mark"><AppIcon name="check-circle" /></span><h3>{title}</h3><p>Your quiz has been saved locally and submitted for review. It will not become publicly playable until it is approved.</p><dl><div><dt>Status</dt><dd>Pending Review</dd></div><div><dt>Questions</dt><dd>10 complete</dd></div><div><dt>Submission</dt><dd>{submittedId}</dd></div></dl><button type="button" onClick={onClose}>Return to Quiz</button>
          </main>
        ) : null}
      </div>

      {confirmExitOpen ? <div className="create-quiz-confirm-layer"><section ref={confirmRef} role="alertdialog" aria-modal="true" aria-labelledby="abandon-quiz-title"><h2 id="abandon-quiz-title">Leave Create Quiz?</h2><p>Your unsaved quiz draft will be discarded.</p><div><button type="button" onClick={() => setConfirmExitOpen(false)}>Keep Creating</button><button type="button" onClick={onClose}>Leave Create Quiz</button></div></section></div> : null}
    </section>
  );
}
