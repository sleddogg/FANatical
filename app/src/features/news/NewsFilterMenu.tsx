import { useEffect, useMemo, useRef, useState } from "react";
import { AppIcon } from "../../components/AppIcon";
import { trapDialogFocus } from "./dialogKeyboard";
import type { NewsNavigationEntry, NewsTemporaryFilter } from "./types";

type FilterPanel = "root" | "team" | "competition" | "sport";

type NewsFilterMenuProps = {
  readonly currentFilter: NewsTemporaryFilter;
  readonly navigation: readonly NewsNavigationEntry[];
  readonly onApply: (filter: NewsTemporaryFilter) => void;
  readonly onClose: () => void;
};

const panelTitles: Readonly<Record<FilterPanel, string>> = {
  root: "Choose News context",
  team: "Team",
  competition: "Competition",
  sport: "Sport",
};

export function NewsFilterMenu({
  currentFilter,
  navigation,
  onApply,
  onClose,
}: NewsFilterMenuProps) {
  const [panel, setPanel] = useState<FilterPanel>("root");
  const [teamQuery, setTeamQuery] = useState("");
  const dialogRef = useRef<HTMLElement>(null);
  const sports = navigation.filter((entry) => entry.filterType === "sport");
  const competitions = navigation.filter((entry) => entry.filterType === "competition");
  const teams = navigation.filter((entry) => entry.filterType === "team");
  const visibleTeams = useMemo(() => {
    const query = teamQuery.trim().toLocaleLowerCase();
    return query
      ? teams.filter((team) => team.displayName.toLocaleLowerCase().includes(query))
      : teams;
  }, [teamQuery, teams]);

  useEffect(() => {
    dialogRef.current?.focus();
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
      else trapDialogFocus(event, dialogRef.current);
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [onClose]);

  const apply = (entry: NewsNavigationEntry) => {
    onApply({
      kind: entry.filterType,
      targetId: entry.targetId,
      displayName: entry.displayName,
    });
  };

  const selected = (entry: NewsNavigationEntry) => (
    currentFilter.kind === entry.filterType
      && currentFilter.targetId === entry.targetId
  );

  return (
    <div className="news-filter-layer">
      <button className="news-layer-backdrop" type="button" aria-label="Close News filters" onClick={onClose} />
      <section
        id="news-filter-menu"
        className="news-filter-menu"
        role="dialog"
        aria-modal="true"
        aria-labelledby="news-filter-title"
        ref={dialogRef}
        tabIndex={-1}
      >
        <header className="news-filter-menu__header">
          {panel === "root" ? <span className="news-filter-menu__spacer" /> : (
            <button className="news-text-button" type="button" onClick={() => setPanel("root")}>
              <AppIcon name="arrow-left" /> Back
            </button>
          )}
          <h2 id="news-filter-title">{panelTitles[panel]}</h2>
          <button className="news-icon-button news-icon-button--small" type="button" aria-label="Close filters" onClick={onClose}>
            <AppIcon name="x-mark" />
          </button>
        </header>

        {panel === "root" ? (
          <div className="news-filter-menu__options">
            <button type="button" onClick={() => setPanel("team")}>
              <span><strong>Team</strong><small>Temporarily narrow eligible News to one Team</small></span><AppIcon name="chevron-right" />
            </button>
            <button type="button" onClick={() => setPanel("competition")}>
              <span><strong>Competition</strong><small>Temporarily view one competition</small></span><AppIcon name="chevron-right" />
            </button>
            <button type="button" onClick={() => setPanel("sport")}>
              <span><strong>Sport</strong><small>Temporarily combine eligible News in one Sport</small></span><AppIcon name="chevron-right" />
            </button>
            <button type="button" aria-pressed={currentFilter.kind === "all"} onClick={() => onApply({ kind: "all", displayName: "All Followed News" })}>
              <span><strong>All Followed News</strong><small>Everything that qualifies through your follows</small></span>
              {currentFilter.kind === "all" ? <AppIcon name="check" /> : <AppIcon name="chevron-right" />}
            </button>
          </div>
        ) : null}

        {panel === "team" ? (
          <div className="news-filter-browser">
            <label className="source-search">
              <span>Find a Team</span>
              <input type="search" value={teamQuery} onChange={(event) => setTeamQuery(event.target.value)} />
            </label>
            <div className="news-filter-menu__compact-options news-filter-menu__compact-options--list">
              {visibleTeams.map((team) => (
                <button key={team.targetId} type="button" aria-pressed={selected(team)} onClick={() => apply(team)}>
                  <span>{team.displayName}</span>{selected(team) ? <AppIcon name="check" /> : null}
                </button>
              ))}
              {!visibleTeams.length ? <p>No Team matches that search.</p> : null}
            </div>
          </div>
        ) : null}

        {panel === "competition" ? (
          <div className="news-filter-groups">
            {sports.map((sport) => {
              const entries = competitions.filter((competition) => competition.sportId === sport.targetId);
              return entries.length ? (
                <section key={sport.targetId} aria-labelledby={`competition-group-${sport.targetId}`}>
                  <h3 id={`competition-group-${sport.targetId}`}>{sport.displayName}</h3>
                  <div className="news-filter-menu__compact-options">
                    {entries.map((competition) => (
                      <button key={competition.targetId} type="button" aria-pressed={selected(competition)} onClick={() => apply(competition)}>
                        {competition.displayName}
                      </button>
                    ))}
                  </div>
                </section>
              ) : null;
            })}
          </div>
        ) : null}

        {panel === "sport" ? (
          <div className="news-filter-menu__options">
            {sports.map((sport) => (
              <button key={sport.targetId} type="button" aria-pressed={selected(sport)} onClick={() => apply(sport)}>
                <span><strong>{sport.displayName}</strong><small>All eligible {sport.displayName} News</small></span>
                {selected(sport) ? <AppIcon name="check" /> : <AppIcon name="chevron-right" />}
              </button>
            ))}
          </div>
        ) : null}
      </section>
    </div>
  );
}
