import type { FollowedTeam, TeamId } from "../domain/team";
import { findOfficialLeague, findOfficialSportById, findOfficialTeam, type OfficialTeamId } from "./officialSportsDatabase";

export const followedTeamsStorageKey = "fanatical.followed-team-ids.v1";

export const followedTeams = [
  {
    id: "new-england-patriots",
    officialTeamId: "football-nfl-new-england-patriots",
    name: "New England Patriots",
    shortName: "Patriots",
    sport: "Football",
    league: "NFL",
    colors: findOfficialTeam("football-nfl-new-england-patriots")!.colors,
  },
  {
    id: "boston-red-sox",
    officialTeamId: "baseball-mlb-boston-red-sox",
    name: "Boston Red Sox",
    shortName: "Red Sox",
    sport: "Baseball",
    league: "MLB",
    colors: findOfficialTeam("baseball-mlb-boston-red-sox")!.colors,
  },
  {
    id: "boston-celtics",
    officialTeamId: "basketball-nba-boston-celtics",
    name: "Boston Celtics",
    shortName: "Celtics",
    sport: "Basketball",
    league: "NBA",
    colors: findOfficialTeam("basketball-nba-boston-celtics")!.colors,
  },
] as const satisfies readonly FollowedTeam[];

export const defaultSelectedTeamId: TeamId = "new-england-patriots";

export const defaultFollowedTeamIds: readonly OfficialTeamId[] = followedTeams.map((team) => team.officialTeamId);

export function officialTeamToFollowedTeam(teamId: OfficialTeamId): FollowedTeam | null {
  const team = findOfficialTeam(teamId);
  const league = team ? findOfficialLeague(team.parentLeagueId) : null;
  const sport = league ? findOfficialSportById(league.parentSportId) : null;
  if (!team || !league || !sport) return null;
  const nameParts = team.displayName.split(/\s+/);
  return {
    id: team.id,
    officialTeamId: team.id,
    name: team.displayName,
    shortName: nameParts[nameParts.length - 1] ?? team.displayName,
    sport: sport.displayName,
    league: league.displayName,
    colors: team.colors,
  };
}

export function followedTeamsFromOfficialIds(teamIds: readonly OfficialTeamId[]): readonly FollowedTeam[] {
  const seededByOfficialId = new Map<OfficialTeamId, FollowedTeam>(followedTeams.map((team) => [team.officialTeamId, team]));
  return [...new Set(teamIds)].map((teamId) => seededByOfficialId.get(teamId) ?? officialTeamToFollowedTeam(teamId)).filter((team): team is FollowedTeam => team !== null);
}

export function loadPersistedFollowedTeamIds(): readonly OfficialTeamId[] {
  if (typeof window === "undefined") return [];

  try {
    const value: unknown = JSON.parse(window.localStorage.getItem(followedTeamsStorageKey) ?? "[]");
    if (!Array.isArray(value)) return [];
    return [...new Set(value.filter((teamId): teamId is OfficialTeamId => typeof teamId === "string" && Boolean(findOfficialTeam(teamId))))];
  } catch {
    return [];
  }
}

export function savePersistedFollowedTeamIds(teamIds: readonly OfficialTeamId[]) {
  if (typeof window === "undefined") return;

  try {
    window.localStorage.setItem(followedTeamsStorageKey, JSON.stringify([...new Set(teamIds)]));
  } catch (error) {
    throw new Error("Your followed teams could not be saved in this browser.", { cause: error });
  }
}

export function loadFollowedTeams(): readonly FollowedTeam[] {
  if (typeof window === "undefined") {
    return followedTeams;
  }
  try {
    return window.localStorage.getItem(followedTeamsStorageKey) === null
      ? followedTeams
      : followedTeamsFromOfficialIds(loadPersistedFollowedTeamIds());
  } catch {
    return followedTeams;
  }
}

export function findFollowedTeam(teamId: TeamId) {
  return loadFollowedTeams().find((team) => team.id === teamId);
}

export function isFollowedTeamId(value: unknown): value is TeamId {
  return typeof value === "string" && loadFollowedTeams().some((team) => team.id === value);
}
