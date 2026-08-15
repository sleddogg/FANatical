import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import type { TeamId } from "../../domain/team";
import { findFollowedTeam } from "../../data/followedTeams";
import {
  buildSportsStatsSnapshot,
  fanScoreForUser,
  resolveFanbaseCompetition,
  sportSummaryForUser,
  sportsStatsPredictorMinimum,
  type SportsStatsUser,
} from "../stats/sportsStats";
import { demoUser } from "./mockFanbaseData";
import { useFanbaseContext } from "./FanbaseContext";
import "./leaderboards.css";

type PopulationId = "team" | "league" | "sport" | "friends" | `group:${string}`;
type SortColumn = "fanScore" | "name" | "sportIq" | "predictorIq" | "quizIq" | "trophies";

function sortableValue(user: SportsStatsUser, column: SortColumn, sportId: ReturnType<typeof resolveFanbaseCompetition>["sportId"], teamKey: string) {
  const sport = sportSummaryForUser(user, sportId);
  if (column === "name") return user.username.toLocaleLowerCase();
  if (column === "fanScore") return fanScoreForUser(user, teamKey) ?? -1;
  if (column === "sportIq") return sport?.sportIq ?? -1;
  if (column === "predictorIq") return sport?.predictor.qualified ? sport.predictor.iq ?? -1 : -1;
  if (column === "quizIq") return sport?.quiz.iq ?? -1;
  return user.trophies;
}

function StatSortButton({ label, column, activeColumn, direction, onSort }: { readonly label: string; readonly column: SortColumn; readonly activeColumn: SortColumn; readonly direction: "asc" | "desc"; readonly onSort: (column: SortColumn) => void }) {
  const active = column === activeColumn;
  return <button type="button" className={active ? "leaderboard-sort leaderboard-sort--active" : "leaderboard-sort"} aria-label={`Sort by ${label}`} onClick={() => onSort(column)}>{label}<span aria-hidden="true">{active ? direction === "desc" ? "↓" : "↑" : "↕"}</span></button>;
}

export function LeaderboardsArea({ teamId }: { readonly teamId: TeamId }) {
  const navigate = useNavigate();
  const { groups } = useFanbaseContext();
  const selectedTeam = findFollowedTeam(teamId)!;
  const competition = resolveFanbaseCompetition(selectedTeam);
  const [population, setPopulation] = useState<PopulationId>("team");
  const [sortColumn, setSortColumn] = useState<SortColumn>("fanScore");
  const [sortDirection, setSortDirection] = useState<"asc" | "desc">("desc");
  const snapshot = useMemo(() => buildSportsStatsSnapshot(), []);
  const joinedGroups = groups.filter((group) => group.teamId === teamId && group.joined);
  const selectedGroup = population.startsWith("group:") ? joinedGroups.find((group) => `group:${group.id}` === population) : null;
  const broadPopulation = population === "league" || population === "sport";

  useEffect(() => {
    setPopulation("team");
    setSortColumn("fanScore");
    setSortDirection("desc");
  }, [teamId]);

  useEffect(() => {
    if (broadPopulation && sortColumn === "fanScore") {
      setSortColumn("sportIq");
      setSortDirection("desc");
    }
  }, [broadPopulation, sortColumn]);

  const populationUsers = useMemo(() => {
    if (population === "team") return snapshot.filter((user) => fanScoreForUser(user, competition.teamKey) !== null);
    if (population === "league") return snapshot.filter((user) => user.leagueIds.includes(competition.leagueId ?? ""));
    if (population === "sport") return snapshot.filter((user) => user.sportIds.includes(competition.sportId));
    if (population === "friends") return snapshot.filter((user) => user.id === demoUser.id || user.friend);
    const memberIds = new Set(selectedGroup?.memberUserIds ?? []);
    return snapshot.filter((user) => memberIds.has(user.id));
  }, [competition.leagueId, competition.sportId, competition.teamKey, population, selectedGroup?.memberUserIds, snapshot]);

  const sortedUsers = useMemo(() => [...populationUsers].sort((first, second) => {
    const firstValue = sortableValue(first, sortColumn, competition.sportId, competition.teamKey);
    const secondValue = sortableValue(second, sortColumn, competition.sportId, competition.teamKey);
    const comparison = typeof firstValue === "string" && typeof secondValue === "string" ? firstValue.localeCompare(secondValue) : Number(firstValue) - Number(secondValue);
    return sortDirection === "asc" ? comparison : -comparison;
  }), [competition.sportId, competition.teamKey, populationUsers, sortColumn, sortDirection]);

  const populationLabel = population === "team" ? competition.teamName
    : population === "league" ? competition.leagueName
      : population === "sport" ? competition.sportName
        : population === "friends" ? "Friends"
          : selectedGroup?.name ?? "Group";

  const sort = (column: SortColumn) => {
    if (sortColumn === column) setSortDirection((current) => current === "desc" ? "asc" : "desc");
    else {
      setSortColumn(column);
      setSortDirection(column === "name" ? "asc" : "desc");
    }
  };

  return (
    <section className="leaderboards-area" aria-labelledby="leaderboard-title">
      <header className="leaderboards-intro surface">
        <div><span className="eyebrow">Compare your fandom</span><h2 id="leaderboard-title">{populationLabel}</h2><p>{broadPopulation ? `${competition.sportName}-specific knowledge and prediction performance` : `${competition.teamName} context · ${competition.sportName} IQ`}</p></div>
        <div className="leaderboard-populations" aria-label="Leaderboard population">
          <button type="button" aria-pressed={population === "team"} onClick={() => setPopulation("team")}>Current Team</button>
          <button type="button" aria-pressed={population === "league"} onClick={() => setPopulation("league")}>{competition.leagueName}</button>
          <button type="button" aria-pressed={population === "sport"} onClick={() => setPopulation("sport")}>{competition.sportName}</button>
          <button type="button" aria-pressed={population === "friends"} onClick={() => setPopulation("friends")}>Friends</button>
          {joinedGroups.map((group) => <button key={group.id} type="button" aria-pressed={population === `group:${group.id}`} onClick={() => setPopulation(`group:${group.id}`)}>{group.name}</button>)}
        </div>
      </header>

      <div className="leaderboard-table-wrap surface" tabIndex={0} aria-label={`${populationLabel} leaderboard; scroll horizontally on smaller screens`}>
        <table className="leaderboard-table">
          <thead><tr>
            <th scope="col">Rank</th>
            {!broadPopulation ? <th scope="col"><StatSortButton label="Fan Score" column="fanScore" activeColumn={sortColumn} direction={sortDirection} onSort={sort} /></th> : null}
            <th scope="col"><StatSortButton label="Name" column="name" activeColumn={sortColumn} direction={sortDirection} onSort={sort} /></th>
            <th scope="col"><StatSortButton label="Sport IQ" column="sportIq" activeColumn={sortColumn} direction={sortDirection} onSort={sort} /></th>
            <th scope="col"><StatSortButton label="Predictor IQ" column="predictorIq" activeColumn={sortColumn} direction={sortDirection} onSort={sort} /></th>
            <th scope="col"><StatSortButton label="Quiz IQ" column="quizIq" activeColumn={sortColumn} direction={sortDirection} onSort={sort} /></th>
            <th scope="col"><StatSortButton label="Trophies" column="trophies" activeColumn={sortColumn} direction={sortDirection} onSort={sort} /></th>
          </tr></thead>
          <tbody>{sortedUsers.map((user, index) => {
            const sport = sportSummaryForUser(user, competition.sportId);
            const fanScore = fanScoreForUser(user, competition.teamKey);
            return <tr key={user.id} className={user.id === demoUser.id ? "leaderboard-table__viewer" : undefined}>
              <td><strong className="leaderboard-rank">#{index + 1}</strong></td>
              {!broadPopulation ? <td>{fanScore === null ? <span className="leaderboard-empty">—</span> : fanScore.toLocaleString()}</td> : null}
              <td><button className="leaderboard-profile-link" type="button" onClick={() => navigate(`/profile/stats?user=${encodeURIComponent(user.id)}&from=leaderboard`)}><span className="leaderboard-avatar" aria-hidden="true">{user.initials}</span><span>{user.username}{user.id === demoUser.id ? <small>You</small> : null}</span></button></td>
              <td>{sport?.sportIq ?? <span className="leaderboard-empty">—</span>}</td>
              <td>{sport?.predictor.iq === null || sport?.predictor.iq === undefined ? <span className="leaderboard-empty">—</span> : <span className="leaderboard-qualified-stat"><strong>{sport.predictor.iq}</strong>{!sport.predictor.qualified ? <small>{sport.predictor.predictions}/{sportsStatsPredictorMinimum} · provisional</small> : sport.predictor.percentile !== null ? <small>{sport.predictor.percentile}th percentile</small> : null}</span>}</td>
              <td>{sport?.quiz.iq ?? <span className="leaderboard-empty">—</span>}</td>
              <td>{user.trophies}</td>
            </tr>;
          })}</tbody>
        </table>
        {!sortedUsers.length ? <div className="leaderboard-empty-state"><strong>No ranked fans yet</strong><p>This population needs scored Quiz or Predictor activity before it can be ranked.</p></div> : null}
      </div>
      <p className="leaderboard-footnote">Fan Score is Team-specific. Predictor IQ is marked provisional until {sportsStatsPredictorMinimum} completed predictions.</p>
    </section>
  );
}
