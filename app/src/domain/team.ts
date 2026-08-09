export type TeamId = "new-england-patriots" | "boston-red-sox" | "boston-celtics";

export type FollowedTeam = Readonly<{
  id: TeamId;
  name: string;
  shortName: string;
  sport: "Football" | "Baseball" | "Basketball";
  league: "NFL" | "MLB" | "NBA";
  logoUrl: string;
}>;
