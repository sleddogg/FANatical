import { useEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";
import {
  findOfficialLeague,
  findOfficialSportById,
  findOfficialTeam,
  leaguesForSport,
  officialSports,
  teamsForLeague,
  type OfficialLeagueId,
  type OfficialSportId,
  type OfficialTeamId,
} from "../../data/officialSportsDatabase";
import type { FollowedTeam } from "../../domain/team";
import { AppIcon } from "../../components/AppIcon";

type AddTeamStage = "sport" | "league" | "team" | "confirm";

export function ProfileAddTeamDialog({ followedTeams, onAdd, onClose, placement = "center" }: {
  readonly followedTeams: readonly FollowedTeam[];
  readonly onAdd: (teamId: OfficialTeamId) => void;
  readonly onClose: () => void;
  readonly placement?: "center" | "bottom";
}) {
  const [stage, setStage] = useState<AddTeamStage>("sport");
  const [sportId, setSportId] = useState<OfficialSportId | null>(null);
  const [leagueId, setLeagueId] = useState<OfficialLeagueId | null>(null);
  const [teamId, setTeamId] = useState<OfficialTeamId | null>(null);
  const [search, setSearch] = useState("");
  const dialogRef = useRef<HTMLElement>(null);
  const selectableSports = useMemo(() => officialSports.filter((sport) => leaguesForSport(sport.id)
    .some((league) => teamsForLeague(league.id).length > 0)), []);
  const leagues = sportId ? leaguesForSport(sportId).filter((league) => teamsForLeague(league.id).length > 0) : [];
  const teams = leagueId ? teamsForLeague(leagueId).filter((team) => team.displayName.toLocaleLowerCase().includes(search.trim().toLocaleLowerCase())) : [];
  const followedOfficialIds = new Set(followedTeams.map((team) => team.officialTeamId)
    .filter((teamId): teamId is OfficialTeamId => teamId !== null));
  const sport = findOfficialSportById(sportId);
  const league = findOfficialLeague(leagueId);
  const team = findOfficialTeam(teamId);

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    dialogRef.current?.focus();
    const closeOnEscape = (event: KeyboardEvent) => event.key === "Escape" && onClose();
    window.addEventListener("keydown", closeOnEscape);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", closeOnEscape);
    };
  }, [onClose]);

  const back = () => {
    if (stage === "confirm") {
      setStage("team");
      setTeamId(null);
    } else if (stage === "team") {
      setStage("league");
      setLeagueId(null);
      setSearch("");
    } else if (stage === "league") {
      setStage("sport");
      setSportId(null);
    }
  };

  const title = stage === "sport" ? "Pick a Sport" : stage === "league" ? "Pick a League" : stage === "team" ? "Pick a Team" : "Confirm Team";

  return createPortal(
    <div className={`profile-dialog-layer${placement === "bottom" ? " profile-dialog-layer--bottom" : ""}`}>
      <button className="profile-dialog-backdrop" type="button" aria-label="Cancel adding team" onClick={onClose} />
      <section className="profile-add-team-dialog" role="dialog" aria-modal="true" aria-labelledby="profile-add-team-title" ref={dialogRef} tabIndex={-1}>
        <header>
          {stage === "sport" ? <span /> : <button className="profile-add-team-dialog__back" type="button" onClick={back}><AppIcon name="arrow-left" /> Back</button>}
          <div><span className="eyebrow">Followed teams</span><h2 id="profile-add-team-title">{title}</h2><p>{[sport?.displayName, league?.displayName].filter(Boolean).join(" · ") || "Add a team to this Profile"}</p></div>
          <button className="profile-icon-button" type="button" aria-label="Cancel adding team" onClick={onClose}><AppIcon name="x-mark" /></button>
        </header>

        {stage === "sport" ? <div className="profile-add-team-dialog__grid" aria-label="Sports">
          {selectableSports.map((candidate) => <button key={candidate.id} type="button" onClick={() => { setSportId(candidate.id); setStage("league"); }}><strong>{candidate.displayName}</strong><small>Choose league</small></button>)}
        </div> : null}

        {stage === "league" ? <div className="profile-add-team-dialog__grid" aria-label={`${sport?.displayName ?? "Sport"} leagues`}>
          {leagues.map((candidate) => <button key={candidate.id} type="button" onClick={() => { setLeagueId(candidate.id); setStage("team"); }}><strong>{candidate.displayName}</strong><small>{teamsForLeague(candidate.id).length} teams</small></button>)}
        </div> : null}

        {stage === "team" ? <div className="profile-add-team-dialog__teams">
          <label>Search teams<input type="search" value={search} placeholder={`Search ${league?.displayName ?? "league"} teams`} onChange={(event) => setSearch(event.target.value)} /></label>
          <div className="profile-add-team-dialog__team-list">
            {teams.map((team) => {
              const alreadyFollowed = followedOfficialIds.has(team.id);
              return <button key={team.id} type="button" disabled={alreadyFollowed} aria-label={alreadyFollowed ? `${team.displayName}, already followed` : `Select ${team.displayName}`} onClick={() => { setTeamId(team.id); setStage("confirm"); }}><span><strong>{team.displayName}</strong><small>{league?.displayName} · {sport?.displayName}</small></span><span>{alreadyFollowed ? "Following" : "Select"}</span></button>;
            })}
            {!teams.length ? <p>No teams match this search.</p> : null}
          </div>
        </div> : null}

        {stage === "confirm" && team ? <div className="profile-add-team-dialog__confirmation">
          <span className="eyebrow">Add to followed teams</span>
          <h3>{team.displayName}</h3>
          <p>{league?.displayName} · {sport?.displayName}</p>
          <button type="button" onClick={() => onAdd(team.id)}>Confirm Add Team</button>
        </div> : null}

        <footer><button type="button" onClick={onClose}>Cancel</button></footer>
      </section>
    </div>,
    document.body,
  );
}
