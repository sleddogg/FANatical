import { useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { StatDashboard } from "../../components/StatDashboard";
import { AppIcon, type AppIconName } from "../../components/AppIcon";
import { ActiveQuiz } from "./ActiveQuiz";
import { CreateQuizFlow } from "./CreateQuizFlow";
import { MOCK_RETAKE_COOLDOWN_DAYS, mockQuizAttempts, mockQuizCatalog, mockQuizStats, quizLeagues } from "./mockQuizData";
import { mockQuizQuestionSets } from "./mockQuizQuestions";
import { QuizResults } from "./QuizResults";
import { quizDifficulties, quizSports, type QuizAttempt, type QuizDifficulty, type QuizRecord, type QuizSelectionPath, type QuizSport, type QuizSubmissionRecord } from "./types";
import "./quiz.css";

type QuizStep = "sport" | "league" | "difficulty" | "path" | "random-empty" | "browse" | "retake" | "selected" | "active" | "results";

const sportIcons: Readonly<Record<QuizSport, string>> = {
  Hockey: "◉",
  Football: "◆",
  Baseball: "●",
  Basketball: "◍",
};

const difficultyDescriptions: Readonly<Record<QuizDifficulty, string>> = {
  "All-Star": "Deep cuts for the sharpest fans",
  Star: "A serious test of league knowledge",
  "League Average": "Balanced questions for regular fans",
  Grinder: "Detailed, determined, and challenging",
  Rookie: "A welcoming place to build your knowledge",
};

const pathDetails: Readonly<Record<QuizSelectionPath, { title: string; icon: AppIconName; description: string }>> = {
  random: { title: "Random Quiz", icon: "sparkles", description: "Let FANatical choose an available match for you." },
  browse: { title: "Browse Category", icon: "squares-2x2", description: "Explore matching topics and choose your quiz." },
  retake: { title: "Retake Quiz", icon: "arrow-path", description: "Replay an eligible completed quiz after cooldown." },
};

function daysSince(value: string) {
  return Math.floor((Date.now() - Date.parse(value)) / (24 * 60 * 60 * 1000));
}

function QuizStatsDashboard() {
  return (
    <StatDashboard
      label="Quiz dashboard"
      primary={[{ label: "Streak", value: mockQuizStats.streak, icon: <AppIcon name="fire" /> }, { label: "Today", value: mockQuizStats.today, icon: <AppIcon name="calendar-days" /> }]}
      secondary={[{ label: "Fan Score", value: mockQuizStats.fanScore, icon: <AppIcon name="star" /> }, { label: "Fan Coins", value: mockQuizStats.fanCoins, icon: "●" }, { label: "Completed", value: mockQuizStats.completed, icon: <AppIcon name="check-circle" /> }, { label: "Average Score", value: mockQuizStats.averageScore, icon: <AppIcon name="chart-bar" /> }]}
    />
  );
}

function QuizSelectionHeader({ title, context, backLabel, onBack }: {
  readonly title: string;
  readonly context?: string | null;
  readonly backLabel?: string;
  readonly onBack?: () => void;
}) {
  return (
    <header className="quiz-selection-header">
      <div>{onBack ? <button type="button" aria-label={backLabel ?? "Back one quiz selection level"} onClick={onBack}><AppIcon name="arrow-left" /><span>Back</span></button> : null}</div>
      <h2 id="quiz-selection-title">{title}</h2>
      <div>{context ? <span className="quiz-selection-header__context" aria-label="Current quiz context">{context}</span> : null}</div>
    </header>
  );
}

function QuizCard({ quiz, detail, onChoose }: { readonly quiz: QuizRecord; readonly detail?: string; readonly onChoose: () => void }) {
  return (
    <button className="quiz-catalog-card" type="button" onClick={onChoose}>
      <span className="quiz-catalog-card__topic">{quiz.topic}</span>
      <strong>{quiz.title}</strong>
      <span>{quiz.description}</span>
      <small>{detail ?? `${quiz.questionCount} questions · ${quiz.averageScore}% average score`}</small>
      <b>Choose quiz <AppIcon name="arrow-right" /></b>
    </button>
  );
}

export function QuizPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const [step, setStep] = useState<QuizStep>("sport");
  const [sport, setSport] = useState<QuizSport | null>(null);
  const [league, setLeague] = useState<string | null>(null);
  const [difficulty, setDifficulty] = useState<QuizDifficulty | null>(null);
  const [selectedPath, setSelectedPath] = useState<QuizSelectionPath | null>(null);
  const [selectedTopic, setSelectedTopic] = useState<string | null>(null);
  const [selectedQuizId, setSelectedQuizId] = useState<string | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [sessionAttempts, setSessionAttempts] = useState<readonly QuizAttempt[]>([]);
  const [, setSubmittedQuizzes] = useState<readonly QuizSubmissionRecord[]>([]);
  const [resultCorrectAnswers, setResultCorrectAnswers] = useState(0);

  const matchingQuizzes = useMemo(() => mockQuizCatalog.filter((quiz) => quiz.sport === sport && quiz.league === league && quiz.difficulty === difficulty), [difficulty, league, sport]);
  const attemptsByQuiz = useMemo(() => {
    const attempts = new Map<string, QuizAttempt>();
    [...mockQuizAttempts, ...sessionAttempts].forEach((attempt) => {
      const current = attempts.get(attempt.quizId);
      if (!current || Date.parse(attempt.completedAt) > Date.parse(current.completedAt)) attempts.set(attempt.quizId, attempt);
    });
    return attempts;
  }, [sessionAttempts]);
  const eligibleRetakes = useMemo(() => matchingQuizzes.flatMap((quiz) => {
    const attempt = attemptsByQuiz.get(quiz.id);
    return attempt && daysSince(attempt.completedAt) >= MOCK_RETAKE_COOLDOWN_DAYS ? [{ quiz, attempt }] : [];
  }), [attemptsByQuiz, matchingQuizzes]);
  const selectedQuiz = selectedQuizId ? mockQuizCatalog.find((quiz) => quiz.id === selectedQuizId) : undefined;
  const browseTopics = [...new Set(matchingQuizzes.map((quiz) => quiz.topic))];
  const browseQuizzes = selectedTopic ? matchingQuizzes.filter((quiz) => quiz.topic === selectedTopic) : matchingQuizzes;

  const chooseQuiz = (quiz: QuizRecord, path: QuizSelectionPath) => {
    setSelectedQuizId(quiz.id);
    setSelectedPath(path);
    setStep("selected");
  };

  const choosePath = (path: QuizSelectionPath) => {
    setSelectedPath(path);
    if (path === "browse") {
      setSelectedTopic(null);
      setStep("browse");
      return;
    }
    if (path === "retake") {
      setStep("retake");
      return;
    }
    const available = matchingQuizzes.filter((quiz) => {
      const attempt = attemptsByQuiz.get(quiz.id);
      return !attempt || daysSince(attempt.completedAt) >= MOCK_RETAKE_COOLDOWN_DAYS;
    }).sort((first, second) => Number(attemptsByQuiz.has(first.id)) - Number(attemptsByQuiz.has(second.id)));
    if (available[0]) chooseQuiz(available[0], "random");
    else setStep("random-empty");
  };

  const appBack = () => {
    if (location.key === "default") navigate("/");
    else navigate(-1);
  };

  const selectionBack = () => {
    if (step === "league") setStep("sport");
    else if (step === "difficulty") setStep("league");
    else if (step === "path") setStep("difficulty");
    else if (step === "browse" || step === "retake" || step === "random-empty") setStep("path");
    else if (step === "selected") setStep(selectedPath === "browse" ? "browse" : selectedPath === "retake" ? "retake" : "path");
  };

  const finishQuiz = (correctAnswers: number) => {
    if (!selectedQuiz) return;
    setSessionAttempts((current) => [...current, { id: `session-attempt-${selectedQuiz.id}-${Date.now()}`, quizId: selectedQuiz.id, score: correctAnswers * 10, completedAt: new Date().toISOString(), completionStatus: "Completed" }]);
    setResultCorrectAnswers(correctAnswers);
    setStep("results");
  };

  const openNextQuiz = () => {
    if (!selectedQuiz) return;
    const retainTopic = selectedPath === "browse" && selectedTopic !== null;
    const candidates = mockQuizCatalog.filter((quiz) => quiz.id !== selectedQuiz.id
      && quiz.sport === selectedQuiz.sport
      && quiz.league === selectedQuiz.league
      && quiz.difficulty === selectedQuiz.difficulty
      && (!retainTopic || quiz.topic === selectedQuiz.topic)
      && (() => {
        const attempt = attemptsByQuiz.get(quiz.id);
        return !attempt || daysSince(attempt.completedAt) >= MOCK_RETAKE_COOLDOWN_DAYS;
      })());
    const nextQuiz = candidates[0];
    if (!nextQuiz) {
      setSelectedQuizId(null);
      setStep(retainTopic ? "browse" : "path");
      return;
    }
    setSport(nextQuiz.sport);
    setLeague(nextQuiz.league);
    setDifficulty(nextQuiz.difficulty);
    setSelectedQuizId(nextQuiz.id);
    setStep("selected");
  };

  const changeDifficulty = () => {
    setDifficulty(null);
    setSelectedPath(null);
    setSelectedTopic(null);
    setSelectedQuizId(null);
    setStep("difficulty");
  };

  const changeLeague = () => {
    setLeague(null);
    setDifficulty(null);
    setSelectedPath(null);
    setSelectedTopic(null);
    setSelectedQuizId(null);
    setStep("league");
  };

  const returnToQuizHub = () => {
    setStep("sport");
    setSport(null);
    setLeague(null);
    setDifficulty(null);
    setSelectedPath(null);
    setSelectedTopic(null);
    setSelectedQuizId(null);
  };

  if (step === "active" && selectedQuiz) {
    return <ActiveQuiz quiz={selectedQuiz} questions={mockQuizQuestionSets[selectedQuiz.questionSetId]} onComplete={finishQuiz} />;
  }

  if (step === "results" && selectedQuiz) {
    return <QuizResults quiz={selectedQuiz} correctAnswers={resultCorrectAnswers} onNextQuiz={openNextQuiz} onChangeDifficulty={changeDifficulty} onChangeLeague={changeLeague} onQuizHub={returnToQuizHub} />;
  }

  const selectionContext = [sport, league, difficulty].filter(Boolean).join(" · ");

  const renderStep = () => {
    if (step === "sport") return (
      <section className="quiz-selection-panel" aria-labelledby="quiz-selection-title"><QuizSelectionHeader title="Pick a Sport" /><p className="quiz-selection-guidance">Choose where you want to test your fan knowledge.</p><div className="quiz-option-list">{quizSports.map((option) => <button key={option} type="button" onClick={() => { setSport(option); setLeague(null); setDifficulty(null); setStep("league"); }}><span className="quiz-option-list__icon" aria-hidden="true">{sportIcons[option]}</span><strong>{option}</strong><AppIcon name="arrow-right" /></button>)}</div></section>
    );

    if (step === "league") return (
      <section className="quiz-selection-panel" aria-labelledby="quiz-selection-title"><QuizSelectionHeader title="Pick a League" context={sport} backLabel="Back to sports" onBack={selectionBack} /><div className="quiz-option-grid">{sport ? quizLeagues[sport].map((option) => <button key={option} type="button" aria-label={`${option} ${sport}`} onClick={() => { setLeague(option); setDifficulty(null); setStep("difficulty"); }}><strong>{option}</strong><small>{sport}</small></button>) : null}</div></section>
    );

    if (step === "difficulty") return (
      <section className="quiz-selection-panel" aria-labelledby="quiz-selection-title"><QuizSelectionHeader title="Pick a Difficulty" context={[sport, league].filter(Boolean).join(" · ")} backLabel="Back to leagues" onBack={selectionBack} /><div className="quiz-difficulty-list">{quizDifficulties.map((option) => <button key={option} type="button" onClick={() => { setDifficulty(option); setStep("path"); }}><span><strong>{option}</strong><small>{difficultyDescriptions[option]}</small></span><AppIcon name="arrow-right" /></button>)}</div></section>
    );

    if (step === "path") return (
      <section className="quiz-selection-panel" aria-labelledby="quiz-selection-title"><QuizSelectionHeader title="Choose a Quiz" context={selectionContext} backLabel="Back to difficulties" onBack={selectionBack} /><div className="quiz-path-grid">{(["random", "browse", "retake"] as const).map((path) => <button key={path} type="button" onClick={() => choosePath(path)}><AppIcon name={pathDetails[path].icon} /><strong>{pathDetails[path].title}</strong><small>{pathDetails[path].description}</small>{path === "retake" ? <b>{eligibleRetakes.length} eligible</b> : null}</button>)}</div></section>
    );

    if (step === "random-empty") return (
      <section className="quiz-selection-panel" aria-labelledby="quiz-selection-title"><QuizSelectionHeader title="Choose a Quiz" context={selectionContext} backLabel="Back to quiz selection" onBack={selectionBack} /><div className="quiz-empty-state"><AppIcon name="information-circle" /><h3>No quizzes available for this selection</h3><p>Try another difficulty or return to Quiz Selection and browse a different path.</p><button type="button" onClick={() => setStep("difficulty")}>Change difficulty</button></div></section>
    );

    if (step === "browse") return (
      <section className="quiz-selection-panel quiz-selection-panel--catalog" aria-labelledby="quiz-selection-title"><QuizSelectionHeader title="Choose a Quiz" context={selectionContext} backLabel="Back to quiz selection" onBack={selectionBack} /><div className="quiz-step-heading"><span className="eyebrow">Browse Category</span><h3>Choose a Topic</h3><p>Filter the matching quiz cards by category, then pick one to play.</p></div>{matchingQuizzes.length ? <><div className="quiz-topic-filter" aria-label="Quiz topics"><button type="button" aria-pressed={selectedTopic === null} onClick={() => setSelectedTopic(null)}>All topics</button>{browseTopics.map((topic) => <button key={topic} type="button" aria-pressed={selectedTopic === topic} onClick={() => setSelectedTopic(topic)}>{topic}</button>)}</div><div className="quiz-catalog-grid">{browseQuizzes.map((quiz) => <QuizCard key={quiz.id} quiz={quiz} onChoose={() => chooseQuiz(quiz, "browse")} />)}</div></> : <div className="quiz-empty-state"><AppIcon name="information-circle" /><h3>No quizzes available</h3><p>No approved quiz cards match this sport, league, and difficulty yet.</p></div>}</section>
    );

    if (step === "retake") return (
      <section className="quiz-selection-panel quiz-selection-panel--catalog" aria-labelledby="quiz-selection-title"><QuizSelectionHeader title="Choose a Quiz" context={selectionContext} backLabel="Back to quiz selection" onBack={selectionBack} /><div className="quiz-step-heading"><span className="eyebrow">Retake Quiz</span><h3>Eligible Retakes</h3><p>Completed quizzes return after the mock {MOCK_RETAKE_COOLDOWN_DAYS}-day cooldown. Perfect scores remain eligible.</p></div>{eligibleRetakes.length ? <div className="quiz-catalog-grid">{eligibleRetakes.map(({ quiz, attempt }) => <QuizCard key={quiz.id} quiz={quiz} detail={`Last score ${attempt.score}% · completed ${daysSince(attempt.completedAt)} days ago`} onChoose={() => chooseQuiz(quiz, "retake")} />)}</div> : <div className="quiz-empty-state"><AppIcon name="clock" /><h3>No retakes available yet.</h3><p>Recently completed quizzes remain in cooldown, and unfinished quizzes appear through Random or Browse.</p></div>}</section>
    );

    return selectedQuiz ? (
      <section className="quiz-selection-panel quiz-selection-panel--landing" aria-labelledby="quiz-selection-title"><QuizSelectionHeader title="Choose a Quiz" context={selectionContext} backLabel={selectedPath === "browse" ? "Back to quiz categories" : selectedPath === "retake" ? "Back to retakes" : "Back to quiz selection"} onBack={selectionBack} /><article className="quiz-landing-card"><span className="quiz-landing-card__topic">{selectedQuiz.topic}</span><span className="eyebrow">Selected quiz</span><h3>{selectedQuiz.title}</h3><p>{selectedQuiz.description}</p><dl><div><dt>Sport</dt><dd>{selectedQuiz.sport}</dd></div><div><dt>League</dt><dd>{selectedQuiz.league}</dd></div><div><dt>Difficulty</dt><dd>{selectedQuiz.difficulty}</dd></div><div><dt>Questions</dt><dd>{selectedQuiz.questionCount}</dd></div></dl><div className="quiz-landing-card__meta"><span>Created by {selectedQuiz.createdBy}</span><span>{selectedQuiz.averageScore}% community average</span></div><button type="button" onClick={() => setStep("active")}>Start Quiz</button></article></section>
    ) : null;
  };

  return (
    <div className="quiz-page">
      <header className="quiz-topbar">
        <button className="quiz-back" type="button" aria-label="Back" onClick={appBack}><AppIcon name="arrow-left" /><span>Back</span></button>
        <div className="quiz-topbar__title"><h1>Quiz</h1></div>
        <button className="quiz-add" type="button" aria-label="Add Quiz" aria-expanded={createOpen} onClick={() => setCreateOpen(true)}><AppIcon name="plus" /><span>Add Quiz</span></button>
      </header>
      <QuizStatsDashboard />
      <div className="quiz-workspace surface">{renderStep()}</div>
      {createOpen ? <CreateQuizFlow onClose={() => setCreateOpen(false)} onSubmit={(submission) => setSubmittedQuizzes((current) => [...current, submission])} /> : null}
    </div>
  );
}
