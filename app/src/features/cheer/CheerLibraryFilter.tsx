import { useMemo, useState } from "react";
import { findOfficialLeague, leaguesForSport, officialSports, officialTeams, type OfficialSportId } from "../../data/officialSportsDatabase";
import type { FollowedTeam } from "../../domain/team";
import type { CheerLibraryFilter } from "./cheerLibrary";

type FilterStage = "main" | "team" | "sport" | "sportDetail";

function followedTeamRecord(team: FollowedTeam) {
  return officialTeams.find((candidate) => candidate.displayName === team.name) ?? null;
}

export function CheerLibraryFilter({ activeFilter, followedTeams, onApply }: {
  readonly activeFilter: CheerLibraryFilter;
  readonly followedTeams: readonly FollowedTeam[];
  readonly onApply: (filter: CheerLibraryFilter) => void;
}) {
  const [stage, setStage] = useState<FilterStage>("main");
  const [teamQuery, setTeamQuery] = useState("");
  const [sportId, setSportId] = useState<OfficialSportId | null>(null);
  const selectedSport = officialSports.find((sport) => sport.id === sportId) ?? null;
  const leagues = sportId ? leaguesForSport(sportId) : [];
  const teamResults = useMemo(() => {
    const query = teamQuery.trim().toLocaleLowerCase();
    if (!query) return [];
    return officialTeams.filter((team) => team.displayName.toLocaleLowerCase().includes(query)).slice(0, 40);
  }, [teamQuery]);

  const apply = (filter: CheerLibraryFilter) => onApply(filter);

  if (stage === "main") {
    const options = [
      { label: "Available Now", filter: { kind: "available" } as const },
      { label: "All", filter: { kind: "all" } as const },
      { label: "Bookmarks", filter: { kind: "bookmarks" } as const },
      { label: "My Cheers", filter: { kind: "mine" } as const },
    ];
    return <div className="cheer-filter-panel cheer-filter-panel--main" role="menu" aria-label="Cheer Library filters">{options.map((option) => <button key={option.label} type="button" role="menuitemradio" aria-checked={activeFilter.kind === option.filter.kind} onClick={() => apply(option.filter)}>{option.label}</button>)}<button type="button" role="menuitem" onClick={() => setStage("team")}>Team <span aria-hidden="true">→</span></button><button type="button" role="menuitem" onClick={() => setStage("sport")}>Sport <span aria-hidden="true">→</span></button></div>;
  }

  if (stage === "team") {
    return <div className="cheer-filter-panel cheer-filter-panel--selector"><header><button type="button" onClick={() => setStage("main")}>← Filters</button><strong>Choose a Team</strong></header><section><span className="eyebrow">Followed teams</span><div className="cheer-filter-grid">{followedTeams.map((team) => { const officialTeam = followedTeamRecord(team); return <button key={team.id} type="button" disabled={!officialTeam} title={officialTeam ? undefined : "Official league data is not available yet"} onClick={() => officialTeam && apply({ kind: "team", teamId: officialTeam.id })}><strong>{team.shortName}</strong><small>{officialTeam ? team.league : "Not yet available"}</small></button>; })}</div></section><label className="cheer-team-search">Search all official teams<input type="search" value={teamQuery} placeholder="Team name" autoFocus onChange={(event) => setTeamQuery(event.target.value)} /></label><div className="cheer-team-results" aria-live="polite">{teamQuery.trim() && !teamResults.length ? <p>No official teams match that search.</p> : teamResults.map((team) => { const league = findOfficialLeague(team.parentLeagueId); return <button key={team.id} type="button" onClick={() => apply({ kind: "team", teamId: team.id })}><strong>{team.displayName}</strong><small>{league?.displayName} · {officialSports.find((sport) => sport.id === league?.parentSportId)?.displayName}</small></button>; })}</div></div>;
  }

  if (stage === "sport") {
    return <div className="cheer-filter-panel cheer-filter-panel--selector"><header><button type="button" onClick={() => setStage("main")}>← Filters</button><strong>Choose a Sport</strong></header><div className="cheer-filter-grid cheer-filter-grid--sport">{officialSports.map((sport) => <button key={sport.id} type="button" onClick={() => { setSportId(sport.id); setStage("sportDetail"); }}><strong>{sport.displayName}</strong></button>)}</div></div>;
  }

  return <div className="cheer-filter-panel cheer-filter-panel--selector"><header><button type="button" onClick={() => setStage("sport")}>← Sports</button><strong>{selectedSport?.displayName ?? "Sport"}</strong></header>{selectedSport ? <button className="cheer-filter-primary" type="button" onClick={() => apply({ kind: "sport", sportId: selectedSport.id })}><span>Show All {selectedSport.displayName} Cheers</span></button> : null}{leagues.length ? <section><span className="eyebrow">Or narrow by league</span><div className="cheer-filter-grid cheer-filter-grid--league">{leagues.map((league) => <button key={league.id} type="button" onClick={() => apply({ kind: "league", leagueId: league.id })}><strong>{league.displayName}</strong></button>)}</div></section> : null}</div>;
}
