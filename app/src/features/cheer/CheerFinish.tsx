import type { FormEvent } from "react";
import { findOfficialLeague, findOfficialSportByName, findOfficialTeam, leaguesForSport, teamsForLeague, type OfficialLeagueId, type OfficialTeamId } from "../../data/officialSportsDatabase";
import { cheerSportOptions } from "./cheerRouting";
import type { CheerDraft, CheerLanguage, CheerPublicationStatus, CheerSport, CheerStyle } from "./types";

const cheerStyles = ["Standard", "Echo", "Call & Response", "Fight Song", "Clap Pattern"] as const satisfies readonly CheerStyle[];

export function CheerFinish({ draft, requiredSport, onChange, onFinish }: {
  readonly draft: CheerDraft;
  readonly requiredSport: CheerSport | null;
  readonly onChange: (draft: CheerDraft) => void;
  readonly onFinish: (status: CheerPublicationStatus) => void;
}) {
  const availableLeagues = leaguesForSport(draft.sportId);
  const availableTeams = teamsForLeague(draft.leagueId);

  const changeSport = (sport: CheerSport) => {
    const officialSport = findOfficialSportByName(sport);
    if (!officialSport) return;
    onChange({ ...draft, sport, sportId: officialSport.id, leagueId: null, teamId: null, league: "", team: "" });
  };

  const changeLeague = (value: string) => {
    const leagueId = value ? value as OfficialLeagueId : null;
    const league = findOfficialLeague(leagueId);
    if (leagueId && (!league || league.parentSportId !== draft.sportId)) return;
    onChange({ ...draft, leagueId, teamId: null, league: league?.displayName ?? "", team: "" });
  };

  const changeTeam = (value: string) => {
    const teamId = value ? value as OfficialTeamId : null;
    const team = findOfficialTeam(teamId);
    if (teamId && (!team || team.parentLeagueId !== draft.leagueId)) return;
    onChange({ ...draft, teamId, team: team?.displayName ?? "" });
  };

  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const submitter = (event.nativeEvent as SubmitEvent).submitter as HTMLButtonElement | null;
    onFinish(submitter?.value === "Draft" ? "Draft" : "Published");
  };

  return (
    <main className="cheer-finish">
      <form onSubmit={submit}>
        <header><span className="eyebrow">Final details</span><h2>Finish Cheer</h2><p>Review how this Cheer will be identified in the Library. Your recording, lyrics, and complete choreography are already attached.</p></header>
        <div className="cheer-finish__grid">
          <label className="cheer-finish__wide">Title<input required maxLength={100} value={draft.title} onChange={(event) => onChange({ ...draft, title: event.target.value })} /></label>
          <label>Cheer Style<select value={draft.style} onChange={(event) => onChange({ ...draft, style: event.target.value as CheerStyle })}>{cheerStyles.map((style) => <option key={style}>{style}</option>)}</select></label>
          {requiredSport ? <div className="cheer-finish__readonly"><span>Sport</span><strong>{requiredSport}</strong><small>Locked by sport-specific WHO routing in this Cheer.</small></div> : <label>Sport<select value={draft.sport} onChange={(event) => changeSport(event.target.value as CheerSport)}>{cheerSportOptions.map((sport) => <option key={sport}>{sport}</option>)}</select></label>}
          <label>League<select value={draft.leagueId ?? ""} onChange={(event) => changeLeague(event.target.value)}><option value="">Sport-wide (no league)</option>{availableLeagues.map((league) => <option key={league.id} value={league.id}>{league.displayName}</option>)}</select></label>
          <label>Team<select disabled={!draft.leagueId} value={draft.teamId ?? ""} onChange={(event) => changeTeam(event.target.value)}><option value="">League-wide (no team)</option>{availableTeams.map((team) => <option key={team.id} value={team.id}>{team.displayName}</option>)}</select></label>
          <label>Rivalry / Opponent<input value={draft.opponent} placeholder="Optional" onChange={(event) => onChange({ ...draft, opponent: event.target.value })} /></label>
          <label>Language<select value={draft.language} onChange={(event) => onChange({ ...draft, language: event.target.value as CheerLanguage })}><option>Auto</option><option>English</option><option>Other</option></select></label>
          <label className="cheer-finish__wide">Short description / instruction<textarea rows={4} maxLength={280} value={draft.description} placeholder="Tell fans when or how to use this Cheer…" onChange={(event) => onChange({ ...draft, description: event.target.value })} /></label>
        </div>
        <div className="cheer-finish__summary"><span>{draft.measures.length} {draft.measures.length === 1 ? "measure" : "measures"}</span><span>{draft.recordingUrl ? "Recording attached" : "No recording"}</span><span>{draft.lyrics.split(/\r?\n/).filter((line) => line.trim()).length} lyric lines</span></div>
        <div className="cheer-finish__actions"><button type="submit" name="intent" value="Draft">Save Draft</button><button className="cheer-primary-button" type="submit" name="intent" value="Published">Publish Cheer</button></div>
      </form>
    </main>
  );
}
