import celticsLogo from "../assets/teams/celtics.png";
import patriotsLogo from "../assets/teams/patriots.png";
import redSoxLogo from "../assets/teams/redsox.png";
import type { FollowedTeam, TeamId } from "../domain/team";

export const followedTeams = [
  {
    id: "new-england-patriots",
    name: "New England Patriots",
    shortName: "Patriots",
    sport: "Football",
    league: "NFL",
    logoUrl: patriotsLogo,
  },
  {
    id: "boston-red-sox",
    name: "Boston Red Sox",
    shortName: "Red Sox",
    sport: "Baseball",
    league: "MLB",
    logoUrl: redSoxLogo,
  },
  {
    id: "boston-celtics",
    name: "Boston Celtics",
    shortName: "Celtics",
    sport: "Basketball",
    league: "NBA",
    logoUrl: celticsLogo,
  },
] as const satisfies readonly FollowedTeam[];

export const defaultSelectedTeamId: TeamId = "new-england-patriots";

export function findFollowedTeam(teamId: TeamId) {
  return followedTeams.find((team) => team.id === teamId);
}

export function isFollowedTeamId(value: unknown): value is TeamId {
  return typeof value === "string" && followedTeams.some((team) => team.id === value);
}
