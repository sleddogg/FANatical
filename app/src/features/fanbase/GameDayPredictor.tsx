import { useMemo, useState } from "react";
import { findOfficialSportById } from "../../data/officialSportsDatabase";
import {
  createGamePrediction,
  loadGamePredictions,
  predictionRulesForGame,
  predictorMinimumPredictions,
  predictorSummary,
  saveGamePredictions,
} from "./gamePredictor";
import { demoUser, initialGameThreads } from "./mockFanbaseData";
import type { GamePredictionOutcome, GameThread } from "./types";
import { AppIcon } from "../../components/AppIcon";

function formatPredictionTime(value: string) {
  return new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" }).format(new Date(value));
}

function formatMetric(value: boolean | null) {
  return value === null ? "Not applicable" : value ? "Yes" : "No";
}

export function GameDayPredictor({ game, teamName }: { readonly game: GameThread; readonly teamName: string }) {
  const [records, setRecords] = useState(() => loadGamePredictions(initialGameThreads));
  const [teamAScore, setTeamAScore] = useState("");
  const [teamBScore, setTeamBScore] = useState("");
  const rules = predictionRulesForGame(game);
  const [outcome, setOutcome] = useState<GamePredictionOutcome>(rules.outcomes[0] ?? "Regulation");
  const [error, setError] = useState("");
  const prediction = records.find((record) => record.gameId === game.id && record.userId === demoUser.id) ?? null;
  const sportName = findOfficialSportById(game.sportId)?.displayName ?? "Sport";
  const summary = useMemo(() => predictorSummary(records, demoUser.id, game.sportId), [game.sportId, records]);
  const exactPredictors = records.filter((record) => record.gameId === game.id && record.resolution?.exactScore);
  const beforeCutoff = Date.now() < Date.parse(game.startsAt);
  const opposingTeam = game.opponent;

  const submit = () => {
    if (!teamAScore.trim() || !teamBScore.trim()) return setError("Enter a whole-number score for both teams.");
    const nextTeamAScore = Number(teamAScore);
    const nextTeamBScore = Number(teamBScore);
    const tieOutcome = outcome === "Tie" || outcome === "Draw";
    if (!Number.isInteger(nextTeamAScore) || !Number.isInteger(nextTeamBScore)) return setError("Enter a whole-number score for both teams.");
    if (tieOutcome && nextTeamAScore !== nextTeamBScore) return setError(`${outcome} predictions require equal scores.`);
    if (!tieOutcome && nextTeamAScore === nextTeamBScore) return setError(`Choose ${rules.outcomes.find((candidate) => candidate === "Tie" || candidate === "Draw") ?? "a tie outcome"} for an equal-score prediction.`);
    const created = createGamePrediction(game, { teamAScore: nextTeamAScore, teamBScore: nextTeamBScore, predictedOutcome: outcome });
    if (!created) return setError(`Predictions close at game time. Scores must be between 0 and ${rules.maximumScore}.`);
    const nextRecords = [created, ...records];
    setRecords(nextRecords);
    saveGamePredictions(nextRecords);
    setError("");
  };

  return (
    <section className="game-predictor surface" aria-labelledby={`predictor-${game.id}-title`}>
      <header className="game-predictor__header">
        <div><span className="eyebrow">Game Day Predictor</span><h2 id={`predictor-${game.id}-title`}>Call the final score</h2><p>{sportName} prediction rules · Locks at game time</p></div>
        <span className={game.finalResult ? "game-predictor__state game-predictor__state--final" : prediction || !beforeCutoff ? "game-predictor__state game-predictor__state--locked" : "game-predictor__state"}>{game.finalResult ? "Final" : prediction || !beforeCutoff ? "Locked" : "Open"}</span>
      </header>

      {game.finalResult ? (
        <div className="game-predictor__resolved">
          <div className="game-predictor-scoreboard" aria-label="Final score"><span><small>{teamName}</small><strong>{game.finalResult.teamAScore}</strong></span><b>Final{game.finalResult.outcome !== "Regulation" ? ` · ${game.finalResult.outcome}` : ""}</b><span><small>{opposingTeam}</small><strong>{game.finalResult.teamBScore}</strong></span></div>
          {prediction?.resolution ? (
            <>
              <div className="game-predictor__prediction-line"><span>Your prediction</span><strong>{teamName} {prediction.teamAScore}–{prediction.teamBScore} {opposingTeam}</strong><small>{prediction.predictedOutcome} · Submitted {formatPredictionTime(prediction.submittedAt)}</small></div>
              {prediction.resolution.exactScore ? <div className="game-predictor-called-it"><AppIcon name="check-circle" /><strong>CALLED IT</strong><small>Exact final score</small></div> : null}
              <div className="game-predictor-metrics">
                <div><span>Correct winner</span><strong>{formatMetric(prediction.resolution.correctWinner)}</strong></div>
                <div><span>{teamName} error</span><strong>{prediction.resolution.teamAScoreError}</strong></div>
                <div><span>{opposingTeam} error</span><strong>{prediction.resolution.teamBScoreError}</strong></div>
                <div><span>Total Score Error</span><strong>{prediction.resolution.totalScoreError}</strong></div>
                <div><span>Exact score</span><strong>{formatMetric(prediction.resolution.exactScore)}</strong></div>
                {rules.supportsShutouts ? <div><span>Shutout call</span><strong>{formatMetric(prediction.resolution.correctShutout)}</strong></div> : null}
                {rules.outcomes.length > 1 ? <div><span>{game.finalResult.outcome === "Tie" || game.finalResult.outcome === "Draw" ? "Tie / draw" : "Game outcome"}</span><strong>{formatMetric(prediction.resolution.correctOutcome)}</strong></div> : null}
              </div>
              <div className="game-predictor-rating">
                <div><span>Predictor Rating</span><strong>{prediction.resolution.predictorRating}</strong><small>Absolute score · 0–100</small></div>
                <div><span>{sportName} Predictor</span><strong>{summary.predictorPercentile === null ? `${summary.predictionCount} / ${predictorMinimumPredictions}` : `${summary.predictorPercentile}th`}</strong><small>{summary.predictorPercentile === null ? "Predictions needed for official percentile" : "percentile among qualified predictors"}</small></div>
              </div>
              <details className="game-predictor-history"><summary>{sportName} prediction history</summary><dl><div><dt>Predictions</dt><dd>{summary.predictionCount}</dd></div><div><dt>Correct winners</dt><dd>{summary.correctWinnerCount}</dd></div><div><dt>Exact scores</dt><dd>{summary.exactScoreCount}</dd></div><div><dt>Average {teamName} error</dt><dd>{summary.averageTeamAError}</dd></div><div><dt>Average opponent error</dt><dd>{summary.averageTeamBError}</dd></div><div><dt>Average Total Score Error</dt><dd>{summary.averageTotalScoreError}</dd></div><div><dt>{sportName} Rating</dt><dd>{summary.predictorRating}</dd></div></dl></details>
            </>
          ) : <div className="game-predictor__empty"><strong>No prediction submitted</strong><p>The cutoff passed before you locked a prediction for this game.</p></div>}
          {exactPredictors.length ? <div className="game-predictor-recognition"><span className="eyebrow">Exact-score predictors</span><h3>CALLED IT</h3><div>{exactPredictors.map((record) => <span key={record.id}><b>{record.username}</b><small>{record.teamAScore}–{record.teamBScore}</small></span>)}</div></div> : null}
        </div>
      ) : prediction ? (
        <div className="game-predictor-locked"><AppIcon name="lock-closed" /><div><strong>Your prediction is locked</strong><p>{teamName} {prediction.teamAScore}–{prediction.teamBScore} {opposingTeam} · {prediction.predictedOutcome}</p><small>Submitted {formatPredictionTime(prediction.submittedAt)} · Resolves automatically when the game is final.</small></div></div>
      ) : beforeCutoff ? (
        <div className="game-predictor-form">
          <div className="game-predictor-score-inputs"><label><span>{teamName}</span><input type="number" inputMode="numeric" min="0" max={rules.maximumScore} value={teamAScore} placeholder="0" onChange={(event) => setTeamAScore(event.target.value)} /></label><span aria-hidden="true">–</span><label><span>{opposingTeam}</span><input type="number" inputMode="numeric" min="0" max={rules.maximumScore} value={teamBScore} placeholder="0" onChange={(event) => setTeamBScore(event.target.value)} /></label></div>
          {rules.outcomes.length > 1 ? <fieldset className="game-predictor-outcomes"><legend>How will it finish?</legend>{rules.outcomes.map((candidate) => <button key={candidate} type="button" aria-pressed={outcome === candidate} onClick={() => setOutcome(candidate)}>{candidate}</button>)}</fieldset> : null}
          {error ? <p className="game-predictor-error" role="alert">{error}</p> : null}
          <button className="game-predictor-submit" type="button" onClick={submit}>Lock Prediction</button>
        </div>
      ) : <div className="game-predictor__empty"><strong>Predictions are locked</strong><p>The game-start cutoff has passed. Come back when the game is final to see exact-score recognition.</p></div>}
    </section>
  );
}
