import {
  useEffect,
  useMemo,
  useRef,
  useState,
  type KeyboardEvent,
  type PointerEvent as ReactPointerEvent,
} from "react";
import { createPortal } from "react-dom";
import {
  findOfficialLeague,
  findOfficialSportById,
  leaguesForSport,
  officialSports,
  teamsForLeague,
  type OfficialLeagueId,
  type OfficialSportId,
  type OfficialTeamId,
} from "../data/officialSportsDatabase";
import type { FollowedTeam } from "../domain/team";
import { AppIcon } from "./AppIcon";
import { TeamBadge } from "./TeamBadge";
import "./manageTeamsDialog.css";

type ManageTeamsTab = "manage" | "add";
type AddTeamStage = "sport" | "league" | "team";

type ManageTeamsDialogProps = Readonly<{
  followedTeams: readonly FollowedTeam[];
  onAdd: (teamId: OfficialTeamId) => Promise<"added" | "duplicate" | "unavailable">;
  onReplace: (teamIds: readonly OfficialTeamId[]) => Promise<void>;
  onClose: () => void;
}>;

function officialIds(teams: readonly FollowedTeam[]) {
  return teams.map((team) => team.officialTeamId).filter((teamId): teamId is OfficialTeamId => Boolean(teamId));
}

function moveTeam(teams: readonly FollowedTeam[], teamId: string, targetIndex: number) {
  const sourceIndex = teams.findIndex((team) => team.id === teamId);
  if (sourceIndex < 0 || targetIndex < 0 || targetIndex >= teams.length || sourceIndex === targetIndex) return [...teams];
  const next = [...teams];
  const [team] = next.splice(sourceIndex, 1);
  if (!team) return next;
  next.splice(targetIndex, 0, team);
  return next;
}

export function ManageTeamsDialog({ followedTeams, onAdd, onReplace, onClose }: ManageTeamsDialogProps) {
  const [tab, setTab] = useState<ManageTeamsTab>("manage");
  const [addStage, setAddStage] = useState<AddTeamStage>("sport");
  const [sportId, setSportId] = useState<OfficialSportId | null>(null);
  const [leagueId, setLeagueId] = useState<OfficialLeagueId | null>(null);
  const [orderedTeams, setOrderedTeams] = useState<readonly FollowedTeam[]>(followedTeams);
  const [removingTeam, setRemovingTeam] = useState<FollowedTeam | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [announcement, setAnnouncement] = useState("");
  const dialogRef = useRef<HTMLElement>(null);
  const orderedTeamsRef = useRef(orderedTeams);
  const activeDrag = useRef<{ teamId: string; pointerId: number } | null>(null);

  const selectableSports = useMemo(() => officialSports.filter((sport) => leaguesForSport(sport.id)
    .some((league) => teamsForLeague(league.id).length > 0)), []);
  const leagues = sportId ? leaguesForSport(sportId).filter((league) => teamsForLeague(league.id).length > 0) : [];
  const teams = leagueId ? teamsForLeague(leagueId) : [];
  const sport = findOfficialSportById(sportId);
  const league = findOfficialLeague(leagueId);
  const followedOfficialIds = new Set(officialIds(followedTeams));

  useEffect(() => {
    if (activeDrag.current) return;
    setOrderedTeams(followedTeams);
    orderedTeamsRef.current = followedTeams;
  }, [followedTeams]);

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    dialogRef.current?.focus();
    const closeOnEscape = (event: globalThis.KeyboardEvent) => {
      if (event.key !== "Escape") return;
      if (removingTeam) setRemovingTeam(null);
      else onClose();
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", closeOnEscape);
    };
  }, [onClose, removingTeam]);

  const updateOrderedTeams = (next: readonly FollowedTeam[]) => {
    orderedTeamsRef.current = next;
    setOrderedTeams(next);
  };

  const persistOrder = async (next: readonly FollowedTeam[], message: string) => {
    setBusy(true);
    setError("");
    try {
      await onReplace(officialIds(next));
      setAnnouncement(message);
    } catch (reason) {
      updateOrderedTeams(followedTeams);
      setError(reason instanceof Error ? reason.message : "Your team changes could not be saved.");
    } finally {
      setBusy(false);
    }
  };

  const reorderTo = async (teamId: string, targetIndex: number) => {
    const next = moveTeam(orderedTeamsRef.current, teamId, targetIndex);
    if (next.every((team, index) => team.id === orderedTeamsRef.current[index]?.id)) return;
    updateOrderedTeams(next);
    await persistOrder(next, `${next[0]?.name ?? "Your first team"} is now your Favorite Team.`);
  };

  const handleReorderKey = (event: KeyboardEvent<HTMLButtonElement>, teamId: string) => {
    const currentIndex = orderedTeamsRef.current.findIndex((team) => team.id === teamId);
    if (event.key === "ArrowUp") {
      event.preventDefault();
      void reorderTo(teamId, currentIndex - 1);
    } else if (event.key === "ArrowDown") {
      event.preventDefault();
      void reorderTo(teamId, currentIndex + 1);
    }
  };

  const handlePointerDown = (event: ReactPointerEvent<HTMLButtonElement>, teamId: string) => {
    if (busy || (event.pointerType === "mouse" && event.button !== 0)) return;
    activeDrag.current = { teamId, pointerId: event.pointerId };
    event.currentTarget.setPointerCapture(event.pointerId);
    event.currentTarget.closest("[data-team-row]")?.setAttribute("data-dragging", "true");
  };

  const handlePointerMove = (event: ReactPointerEvent<HTMLButtonElement>) => {
    const drag = activeDrag.current;
    if (!drag || drag.pointerId !== event.pointerId) return;
    event.preventDefault();
    const targetRow = document.elementFromPoint(event.clientX, event.clientY)?.closest<HTMLElement>("[data-team-row]");
    const targetId = targetRow?.dataset.teamId;
    if (!targetId || targetId === drag.teamId) return;
    const targetIndex = orderedTeamsRef.current.findIndex((team) => team.id === targetId);
    updateOrderedTeams(moveTeam(orderedTeamsRef.current, drag.teamId, targetIndex));
  };

  const finishPointerReorder = (event: ReactPointerEvent<HTMLButtonElement>) => {
    const drag = activeDrag.current;
    if (!drag || drag.pointerId !== event.pointerId) return;
    activeDrag.current = null;
    event.currentTarget.closest("[data-team-row]")?.removeAttribute("data-dragging");
    const next = orderedTeamsRef.current;
    const changed = next.some((team, index) => team.id !== followedTeams[index]?.id);
    if (changed) void persistOrder(next, `${next[0]?.name ?? "Your first team"} is now your Favorite Team.`);
  };

  const removeTeam = async () => {
    if (!removingTeam) return;
    const next = orderedTeamsRef.current.filter((team) => team.id !== removingTeam.id);
    updateOrderedTeams(next);
    setRemovingTeam(null);
    await persistOrder(next, `${removingTeam.name} was removed from your teams.`);
  };

  const addTeam = async (teamId: OfficialTeamId) => {
    setBusy(true);
    setError("");
    try {
      const result = await onAdd(teamId);
      if (result === "duplicate") {
        setError("That team is already in your followed teams.");
        return;
      }
      if (result === "unavailable") {
        setError("That team is not currently available to follow.");
        return;
      }
      const addedTeam = teams.find((team) => team.id === teamId);
      setAnnouncement(`${addedTeam?.displayName ?? "Team"} was added to your teams.`);
      setTab("manage");
      setAddStage("sport");
      setSportId(null);
      setLeagueId(null);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "That team could not be added.");
    } finally {
      setBusy(false);
    }
  };

  const showAddTab = () => {
    setTab("add");
    setError("");
  };

  const addBack = () => {
    setError("");
    if (addStage === "team") {
      setAddStage("league");
      setLeagueId(null);
    } else if (addStage === "league") {
      setAddStage("sport");
      setSportId(null);
    }
  };

  const handleTabKey = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
    event.preventDefault();
    const nextTab: ManageTeamsTab = tab === "manage" ? "add" : "manage";
    setTab(nextTab);
    setError("");
    window.requestAnimationFrame(() => document.getElementById(`${nextTab === "manage" ? "manage-teams" : "add-team"}-tab`)?.focus());
  };

  return createPortal(
    <div className="manage-teams-layer">
      <button className="manage-teams-layer__backdrop" type="button" aria-label="Close Manage Teams" onClick={onClose} />
      <section className="manage-teams-dialog" role="dialog" aria-modal="true" aria-labelledby="manage-teams-title" ref={dialogRef} tabIndex={-1}>
        <header className="manage-teams-dialog__header">
          <div><span className="eyebrow">Followed teams</span><h2 id="manage-teams-title">Manage Teams</h2></div>
          <button className="manage-teams-dialog__close" type="button" aria-label="Close Manage Teams" onClick={onClose}><AppIcon name="x-mark" /></button>
        </header>

        <div className="manage-teams-dialog__tabs" role="tablist" aria-label="Team management options" onKeyDown={handleTabKey}>
          <button type="button" role="tab" tabIndex={tab === "manage" ? 0 : -1} aria-selected={tab === "manage"} aria-controls="manage-teams-panel" id="manage-teams-tab" onClick={() => { setTab("manage"); setError(""); }}>Manage Teams</button>
          <button type="button" role="tab" tabIndex={tab === "add" ? 0 : -1} aria-selected={tab === "add"} aria-controls="add-team-panel" id="add-team-tab" onClick={showAddTab}>Add a Team</button>
        </div>

        {error ? <p className="manage-teams-dialog__error" role="alert"><AppIcon name="exclamation-triangle" /> {error}</p> : null}
        <span className="visually-hidden" aria-live="polite">{announcement}</span>

        {tab === "manage" ? <div className="manage-teams-dialog__panel" id="manage-teams-panel" role="tabpanel" aria-labelledby="manage-teams-tab">
          <p className="manage-teams-dialog__guidance">Your first team is automatically your Favorite Team. Drag a reorder handle, or focus it and use the Up and Down arrow keys.</p>
          {orderedTeams.length ? <ol className="manage-teams-list" aria-label="Ordered followed teams">
            {orderedTeams.map((team, index) => <li key={team.id} data-team-row data-team-id={team.id}>
              <button
                className="manage-teams-list__reorder"
                type="button"
                aria-label={`Reorder ${team.name}`}
                disabled={busy}
                onKeyDown={(event) => handleReorderKey(event, team.id)}
                onPointerDown={(event) => handlePointerDown(event, team.id)}
                onPointerMove={handlePointerMove}
                onPointerUp={finishPointerReorder}
                onPointerCancel={finishPointerReorder}
              ><AppIcon name="arrows-up-down" /></button>
              <TeamBadge team={team} />
              <span className="manage-teams-list__identity"><strong>{team.name}</strong><small>{index === 0 ? "Favorite Team" : `${team.league} · ${team.sport}`}</small></span>
              <button className="manage-teams-list__remove" type="button" disabled={busy} onClick={() => setRemovingTeam(team)}>Remove</button>
            </li>)}
          </ol> : <div className="manage-teams-dialog__empty"><AppIcon name="information-circle" /><strong>No followed teams yet</strong><p>Add a team to establish your Favorite Team and Home team order.</p><button type="button" onClick={showAddTab}>Add a Team</button></div>}
        </div> : null}

        {tab === "add" ? <div className="manage-teams-dialog__panel" id="add-team-panel" role="tabpanel" aria-labelledby="add-team-tab">
          <header className="manage-teams-add__context">
            {addStage === "sport" ? <span /> : <button type="button" onClick={addBack}><AppIcon name="arrow-left" /> {addStage === "team" ? "Back to Leagues" : "Back to Sports"}</button>}
            <div><strong>{addStage === "sport" ? "Choose a Sport" : addStage === "league" ? "Choose a League" : "Choose a Team"}</strong><small>{[sport?.displayName, league?.displayName].filter(Boolean).join(" · ")}</small></div>
          </header>
          <div className="manage-teams-add__list">
            {addStage === "sport" ? selectableSports.map((candidate) => <button key={candidate.id} type="button" onClick={() => { setSportId(candidate.id); setAddStage("league"); }}><span>{candidate.displayName}</span><AppIcon name="chevron-right" /></button>) : null}
            {addStage === "league" ? leagues.map((candidate) => <button key={candidate.id} type="button" onClick={() => { setLeagueId(candidate.id); setAddStage("team"); }}><span><strong>{candidate.displayName}</strong><small>{teamsForLeague(candidate.id).length} teams</small></span><AppIcon name="chevron-right" /></button>) : null}
            {addStage === "team" ? teams.map((candidate) => {
              const alreadyFollowed = followedOfficialIds.has(candidate.id);
              return <button key={candidate.id} type="button" disabled={alreadyFollowed || busy} aria-label={alreadyFollowed ? `${candidate.displayName}, already followed` : `Add ${candidate.displayName}`} onClick={() => void addTeam(candidate.id)}><span><strong>{candidate.displayName}</strong><small>{alreadyFollowed ? "Already followed" : `${league?.displayName} · ${sport?.displayName}`}</small></span>{alreadyFollowed ? <AppIcon name="check" /> : <AppIcon name="plus" />}</button>;
            }) : null}
          </div>
        </div> : null}

        {removingTeam ? <div className="manage-teams-confirm">
          <section role="alertdialog" aria-modal="true" aria-labelledby="remove-team-title" aria-describedby="remove-team-description">
            <h3 id="remove-team-title">Remove {removingTeam.name}?</h3>
            <p id="remove-team-description">This team will be removed from your followed teams. If it is first, the next team becomes your Favorite Team.</p>
            <div><button type="button" onClick={() => setRemovingTeam(null)}>Cancel</button><button type="button" className="manage-teams-confirm__remove" onClick={() => void removeTeam()}>Remove Team</button></div>
          </section>
        </div> : null}
      </section>
    </div>,
    document.body,
  );
}
