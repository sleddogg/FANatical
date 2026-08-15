import { useEffect, useRef, useState } from "react";
import { TeamBadge } from "../../components/TeamBadge";
import type { FollowedTeam } from "../../domain/team";
import { leagueOptions, sportOptions } from "./mockNewsData";
import type { NewsFeedContext } from "./types";

type FilterPanel = "root" | "team" | "league" | "sport";

type NewsFilterMenuProps = {
  readonly followedTeams: readonly FollowedTeam[];
  readonly onApply: (context: NewsFeedContext) => void;
  readonly onClose: () => void;
};

const panelTitles: Record<FilterPanel, string> = {
  root: "Choose News context",
  team: "Selected Team",
  league: "League",
  sport: "Sport",
};

export function NewsFilterMenu({ followedTeams, onApply, onClose }: NewsFilterMenuProps) {
  const [panel, setPanel] = useState<FilterPanel>("root");
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
    <div className="news-filter-layer">
      <button className="news-layer-backdrop" type="button" aria-label="Close News filters" onClick={onClose} />
      <section
        className="news-filter-menu"
        role="dialog"
        aria-modal="true"
        aria-labelledby="news-filter-title"
        ref={dialogRef}
        tabIndex={-1}
      >
        <header className="news-filter-menu__header">
          {panel === "root" ? (
            <span className="news-filter-menu__spacer" />
          ) : (
            <button className="news-text-button" type="button" onClick={() => setPanel("root")}>
              ← Back
            </button>
          )}
          <h2 id="news-filter-title">{panelTitles[panel]}</h2>
          <button className="news-icon-button news-icon-button--small" type="button" aria-label="Close filters" onClick={onClose}>
            ×
          </button>
        </header>

        {panel === "root" ? (
          <div className="news-filter-menu__options">
            <button type="button" onClick={() => setPanel("team")}>
              <span><strong>Selected Team</strong><small>Choose from your followed teams</small></span><span aria-hidden="true">›</span>
            </button>
            <button type="button" onClick={() => setPanel("league")}>
              <span><strong>League</strong><small>View one competition</small></span><span aria-hidden="true">›</span>
            </button>
            <button type="button" onClick={() => setPanel("sport")}>
              <span><strong>Sport</strong><small>Combine all leagues in a sport</small></span><span aria-hidden="true">›</span>
            </button>
            <button type="button" onClick={() => onApply({ kind: "all" })}>
              <span><strong>All Followed News</strong><small>Everything you follow, newest first</small></span><span aria-hidden="true">✓</span>
            </button>
          </div>
        ) : null}

        {panel === "team" ? (
          <div className="news-filter-menu__options">
            {followedTeams.map((team) => (
              <button key={team.id} type="button" onClick={() => onApply({ kind: "team", teamId: team.id })}>
                <span className="news-filter-team">
                  <TeamBadge team={team} />
                  <span><strong>{team.name}</strong><small>{team.league} · {team.sport}</small></span>
                </span>
                <span aria-hidden="true">›</span>
              </button>
            ))}
          </div>
        ) : null}

        {panel === "league" ? (
          <div className="news-filter-groups">
            {sportOptions.map((sport) => (
              <section key={sport.id} aria-labelledby={`league-group-${sport.id}`}>
                <h3 id={`league-group-${sport.id}`}>{sport.label}</h3>
                <div className="news-filter-menu__compact-options">
                  {leagueOptions.filter((league) => league.sportId === sport.id).map((league) => (
                    <button key={league.id} type="button" onClick={() => onApply({ kind: "league", leagueId: league.id })}>
                      {league.label}
                    </button>
                  ))}
                </div>
              </section>
            ))}
          </div>
        ) : null}

        {panel === "sport" ? (
          <div className="news-filter-menu__options">
            {sportOptions.map((sport) => (
              <button key={sport.id} type="button" onClick={() => onApply({ kind: "sport", sportId: sport.id })}>
                <span><strong>{sport.label}</strong><small>All included {sport.label.toLowerCase()} leagues</small></span>
                <span aria-hidden="true">›</span>
              </button>
            ))}
          </div>
        ) : null}
      </section>
    </div>
  );
}
