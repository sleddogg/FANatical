import type { OfficialSportName, OfficialTeamId, TeamColors } from "../data/officialSportsDatabase";

export type TeamId = string;

export type FollowedTeam = Readonly<{
  id: TeamId;
  officialTeamId: OfficialTeamId | null;
  name: string;
  shortName: string;
  sport: OfficialSportName;
  league: string;
  colors: TeamColors;
}>;
