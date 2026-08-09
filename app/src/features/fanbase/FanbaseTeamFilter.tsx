import { useEffect, useRef } from "react";
import type { FollowedTeam, TeamId } from "../../domain/team";

type FanbaseTeamFilterProps = {
  readonly teams: readonly FollowedTeam[];
  readonly selectedTeamId: TeamId;
  readonly onSelect: (teamId: TeamId) => void;
  readonly onClose: () => void;
};

export function FanbaseTeamFilter({ teams, selectedTeamId, onSelect, onClose }: FanbaseTeamFilterProps) {
  const dialogRef = useRef<HTMLElement>(null);

  useEffect(() => {
    dialogRef.current?.focus();
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [onClose]);

  return (
    <div className="fanbase-dialog-layer">
      <button className="fanbase-backdrop" type="button" aria-label="Close team filter" onClick={onClose} />
      <section className="fanbase-team-filter" role="dialog" aria-modal="true" aria-labelledby="fanbase-team-filter-title" ref={dialogRef} tabIndex={-1}>
        <header>
          <div><span className="eyebrow">FANbase context</span><h2 id="fanbase-team-filter-title">Choose a followed team</h2></div>
          <button className="fanbase-icon-button" type="button" aria-label="Close team filter" onClick={onClose}>×</button>
        </header>
        <div className="fanbase-team-filter__list">
          {teams.map((team) => (
            <button key={team.id} type="button" aria-pressed={team.id === selectedTeamId} onClick={() => onSelect(team.id)}>
              <img src={team.logoUrl} alt="" />
              <span><strong>{team.name}</strong><small>{team.league} · {team.sport}</small></span>
              <span aria-hidden="true">{team.id === selectedTeamId ? "✓" : "›"}</span>
            </button>
          ))}
        </div>
      </section>
    </div>
  );
}
