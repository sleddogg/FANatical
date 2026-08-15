import { useMemo, useState } from "react";
import { useLocation, useNavigate, useSearchParams } from "react-router-dom";
import { demoUser } from "../fanbase/mockFanbaseData";
import {
  buildSportsStatsSnapshot,
  officialTeamName,
  sportIqWeights,
  sportsStatsPredictorMinimum,
  sportsStatsUser,
} from "../stats/sportsStats";
import type { OfficialSportId } from "../../data/officialSportsDatabase";
import "./profile.css";
import "./personalSportsStats.css";

function formatValue(value: number | null, suffix = "") {
  return value === null ? "—" : `${value}${suffix}`;
}

export function PersonalSportsStatsPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const [searchParams] = useSearchParams();
  const snapshot = useMemo(() => buildSportsStatsSnapshot(), []);
  const requestedUserId = searchParams.get("user") ?? demoUser.id;
  const user = sportsStatsUser(requestedUserId, snapshot) ?? sportsStatsUser(demoUser.id, snapshot)!;
  const sportsWithEvidence = user.sports.filter((sport) => sport.evidenceUnits > 0);
  const [selectedSportId, setSelectedSportId] = useState<OfficialSportId>(() => sportsWithEvidence[0]?.sportId ?? user.sportIds[0] ?? "generic");
  const selectedSport = user.sports.find((sport) => sport.sportId === selectedSportId) ?? sportsWithEvidence[0] ?? user.sports[0];
  const isOwner = user.id === demoUser.id;

  const back = () => {
    if (searchParams.get("from") === "leaderboard") navigate("/fanbase?area=leaderboards");
    else if (location.key === "default") navigate("/profile");
    else navigate(-1);
  };

  return (
    <div className="personal-stats-page">
      <header className="profile-topbar personal-stats-topbar">
        <button className="profile-back-button" type="button" onClick={back}><span aria-hidden="true">←</span><span>Back</span></button>
        <div><span className="eyebrow">{isOwner ? "Your sports intelligence" : "Public sports intelligence"}</span><h1>{user.username} Sports Stats</h1><p>Quiz, Predictor, and Team-specific fandom performance</p></div>
        <span />
      </header>

      <section className="personal-stats-hero surface" aria-labelledby="overall-sport-iq-title">
        <div><span className="eyebrow">Evidence-weighted across sports</span><h2 id="overall-sport-iq-title">Overall Sport IQ</h2><p>Built from underlying scored activity, so sports with more meaningful results contribute proportionally more.</p></div>
        <strong>{formatValue(user.overallSportIq)}</strong>
      </section>

      <section className="personal-fan-scores" aria-labelledby="fan-score-breakdown-title">
        <header><span className="eyebrow">One score per FANbase</span><h2 id="fan-score-breakdown-title">Fan Score</h2></header>
        <div>{Object.entries(user.fanScores).map(([teamKey, score]) => <article className="surface" key={teamKey}><span>{officialTeamName(teamKey)}</span><strong>{score.toLocaleString()}</strong><small>Team-specific Fan Score</small></article>)}</div>
      </section>

      <section className="personal-sport-breakdown" aria-labelledby="sport-breakdown-title">
        <header><span className="eyebrow">Sport-by-sport evidence</span><h2 id="sport-breakdown-title">Sport IQ breakdown</h2></header>
        <div className="personal-sport-tabs" role="tablist" aria-label="Choose sport statistics">
          {sportsWithEvidence.map((sport) => <button key={sport.sportId} type="button" role="tab" aria-selected={selectedSport?.sportId === sport.sportId} onClick={() => setSelectedSportId(sport.sportId)}>{sport.sportName}</button>)}
        </div>
        {selectedSport ? <div className="personal-sport-panel" role="tabpanel">
          <div className="personal-iq-cards">
            <article className="surface personal-iq-card personal-iq-card--primary"><span>{selectedSport.sportName} Sport IQ</span><strong>{formatValue(selectedSport.sportIq)}</strong><small>{selectedSport.evidenceUnits} scored evidence units</small></article>
            <article className="surface personal-iq-card"><span>Quiz IQ</span><strong>{formatValue(selectedSport.quiz.iq)}</strong><small>{selectedSport.quiz.questions} questions across {selectedSport.quiz.attempts} quizzes</small></article>
            <article className="surface personal-iq-card"><span>Predictor IQ</span><strong>{formatValue(selectedSport.predictor.iq)}</strong><small>{selectedSport.predictor.qualified ? `${selectedSport.predictor.percentile}th percentile` : `${selectedSport.predictor.predictions} / ${sportsStatsPredictorMinimum} predictions · provisional`}</small></article>
          </div>

          <article className="personal-contribution surface">
            <header><div><span className="eyebrow">Configurable composition</span><h3>What builds {selectedSport.sportName} Sport IQ</h3></div><strong>{Math.round(sportIqWeights.quiz * 100)}% Quiz · {Math.round(sportIqWeights.predictor * 100)}% Predictor</strong></header>
            <div className="personal-contribution__bar" aria-label={`${Math.round(sportIqWeights.quiz * 100)} percent Quiz IQ and ${Math.round(sportIqWeights.predictor * 100)} percent Predictor IQ`}><span style={{ width: `${sportIqWeights.quiz * 100}%` }} /><i /></div>
            <p>Quiz performance carries substantially more weight. Missing evidence is not treated as a zero.</p>
          </article>

          <div className="personal-stat-detail-grid">
            <article className="surface"><span className="eyebrow">Quiz contribution</span><h3>{selectedSport.quiz.averageScore}% average</h3><dl><div><dt>Quizzes completed</dt><dd>{selectedSport.quiz.attempts}</dd></div><div><dt>Questions answered</dt><dd>{selectedSport.quiz.questions}</dd></div><div><dt>Estimated correct</dt><dd>{selectedSport.quiz.correctAnswers}</dd></div><div><dt>Normalized Quiz IQ</dt><dd>{formatValue(selectedSport.quiz.iq)}</dd></div></dl><p>Difficulty and performance relative to each quiz's average are included in normalization.</p></article>
            <article className="surface"><span className="eyebrow">Prediction history</span><h3>{selectedSport.predictor.predictions} predictions</h3><dl><div><dt>Winner accuracy</dt><dd>{selectedSport.predictor.winnerAccuracy}%</dd></div><div><dt>Exact scores</dt><dd>{selectedSport.predictor.exactScores}</dd></div><div><dt>Average Team A error</dt><dd>{selectedSport.predictor.averageTeamAError}</dd></div><div><dt>Average Team B error</dt><dd>{selectedSport.predictor.averageTeamBError}</dd></div><div><dt>Average total error</dt><dd>{selectedSport.predictor.averageTotalScoreError}</dd></div><div><dt>Percentile</dt><dd>{selectedSport.predictor.percentile === null ? "Not yet qualified" : `${selectedSport.predictor.percentile}th`}</dd></div></dl></article>
          </div>
        </div> : <p className="personal-stats-empty">No scored sports activity is available yet.</p>}
      </section>

      <section className="personal-all-sports surface" aria-labelledby="all-sports-title">
        <header><h2 id="all-sports-title">All sports</h2><p>Overall Sport IQ is weighted by each sport's underlying evidence volume, not an equal average.</p></header>
        <div className="personal-all-sports__table-wrap"><table><thead><tr><th>Sport</th><th>Sport IQ</th><th>Quiz IQ</th><th>Predictor IQ</th><th>Evidence</th></tr></thead><tbody>{sportsWithEvidence.map((sport) => <tr key={sport.sportId}><th scope="row">{sport.sportName}</th><td>{formatValue(sport.sportIq)}</td><td>{formatValue(sport.quiz.iq)}</td><td>{formatValue(sport.predictor.iq)}{!sport.predictor.qualified && sport.predictor.predictions ? <small>Provisional</small> : null}</td><td>{sport.evidenceUnits}</td></tr>)}</tbody></table></div>
      </section>

      <p className="personal-trophy-note">Trophy details remain in the existing Profile Trophy Case.</p>
    </div>
  );
}
