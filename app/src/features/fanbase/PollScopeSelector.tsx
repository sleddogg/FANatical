import { useState } from "react";
import {
  findOfficialLeague,
  findOfficialSportById,
  leaguesForSport,
  officialSports,
  teamsForLeague,
  type OfficialLeagueId,
  type OfficialSportId,
} from "../../data/officialSportsDatabase";
import { pollScopeLabel } from "./polls";
import type { PollScope } from "./types";
import { AppIcon } from "../../components/AppIcon";

type ScopeStage = "sport" | "league" | "team";

export function PollScopeSelector({ currentScope, onSelect, onClose }: {
  readonly currentScope: PollScope;
  readonly onSelect: (scope: PollScope) => void;
  readonly onClose: () => void;
}) {
  const [stage, setStage] = useState<ScopeStage>("sport");
  const [sportId, setSportId] = useState<OfficialSportId>(currentScope.sportId);
  const [leagueId, setLeagueId] = useState<OfficialLeagueId | null>(currentScope.leagueId);
  const [teamQuery, setTeamQuery] = useState("");
  const sport = findOfficialSportById(sportId);
  const league = findOfficialLeague(leagueId);
  const leagues = leaguesForSport(sportId);
  const teams = teamsForLeague(leagueId).filter((team) => team.displayName.toLocaleLowerCase().includes(teamQuery.trim().toLocaleLowerCase()));

  const chooseSport = (nextSportId: OfficialSportId) => {
    setSportId(nextSportId);
    setLeagueId(null);
    setTeamQuery("");
    setStage("league");
  };

  return (
    <div className="fanbase-dialog-layer poll-dialog-layer" role="presentation">
      <button className="fanbase-backdrop" type="button" aria-label="Close Poll filter" onClick={onClose} />
      <section className="poll-dialog" role="dialog" aria-modal="true" aria-labelledby="poll-scope-title">
        <header>
          <div><span className="eyebrow">Currently viewing</span><small>{pollScopeLabel(currentScope)}</small></div>
          <h2 id="poll-scope-title">{stage === "sport" ? "Pick a Sport" : stage === "league" ? "Pick a League" : "Pick a Team"}</h2>
          <button type="button" aria-label="Close Poll filter" onClick={onClose}><AppIcon name="x-mark" /></button>
        </header>

        {stage === "sport" ? (
          <div className="poll-scope-grid" aria-label="Sports">
            {officialSports.filter((candidate) => candidate.id !== "generic" && candidate.id !== "other").map((candidate) => (
              <button key={candidate.id} type="button" onClick={() => chooseSport(candidate.id)}><strong>{candidate.displayName}</strong><span>Browse polls</span></button>
            ))}
          </div>
        ) : null}

        {stage === "league" ? (
          <>
            <button className="poll-dialog__back" type="button" onClick={() => setStage("sport")}><AppIcon name="arrow-left" /> Sports</button>
            <button className="poll-scope-primary" type="button" onClick={() => onSelect({ kind: "sport", sportId, leagueId: null, teamId: null })}>Show {sport?.displayName} polls</button>
            {leagues.length ? <><span className="poll-dialog__divider">Or narrow by league</span><div className="poll-scope-grid" aria-label={`${sport?.displayName ?? "Sport"} leagues`}>{leagues.map((candidate) => <button key={candidate.id} type="button" onClick={() => { setLeagueId(candidate.id); setStage("team"); }}><strong>{candidate.displayName}</strong><span>League or team polls</span></button>)}</div></> : <p className="poll-dialog__empty">No official leagues are configured for this sport yet. Sport-wide polls are available.</p>}
          </>
        ) : null}

        {stage === "team" && leagueId ? (
          <>
            <button className="poll-dialog__back" type="button" onClick={() => setStage("league")}><AppIcon name="arrow-left" /> Leagues</button>
            <button className="poll-scope-primary" type="button" onClick={() => onSelect({ kind: "league", sportId, leagueId, teamId: null })}>Show {league?.displayName} polls</button>
            <label className="poll-team-search"><span>Or choose a team</span><input type="search" value={teamQuery} placeholder={`Search ${league?.displayName ?? "league"} teams`} onChange={(event) => setTeamQuery(event.target.value)} /></label>
            <div className="poll-team-results" aria-live="polite">
              {teams.map((team) => <button key={team.id} type="button" onClick={() => onSelect({ kind: "team", sportId, leagueId, teamId: team.id })}><strong>{team.displayName}</strong><span>{league?.displayName}</span></button>)}
              {!teams.length ? <p>No teams match that search.</p> : null}
            </div>
          </>
        ) : null}
      </section>
    </div>
  );
}
