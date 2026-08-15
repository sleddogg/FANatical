import { describe, expect, it } from "vitest";
import { findOfficialLeague, findOfficialSportById, officialLeagues, officialSports, officialTeams } from "./officialSportsDatabase";

describe("official sports database", () => {
  it("preserves the controlled Sport to League to Team hierarchy", () => {
    expect(officialSports.map((sport) => sport.displayName)).toEqual(["Football", "Baseball", "Basketball", "Hockey", "Soccer", "Generic", "Other"]);
    expect(officialLeagues).toHaveLength(19);
    expect(officialTeams).toHaveLength(365);
    expect(new Set(officialLeagues.map((league) => league.id))).toHaveProperty("size", officialLeagues.length);
    expect(new Set(officialTeams.map((team) => team.id))).toHaveProperty("size", officialTeams.length);

    for (const league of officialLeagues) expect(findOfficialSportById(league.parentSportId)).not.toBeNull();
    for (const team of officialTeams) expect(findOfficialLeague(team.parentLeagueId)).not.toBeNull();
  });

  it("uses explicit stable IDs independently from display labels", () => {
    expect(officialLeagues).toContainEqual({ id: "hockey-nhl", displayName: "NHL", parentSportId: "hockey" });
    expect(officialTeams).toContainEqual({ id: "hockey-nhl-edmonton-oilers", displayName: "Edmonton Oilers", parentLeagueId: "hockey-nhl" });
    expect(officialTeams).toContainEqual({ id: "football-nfl-new-england-patriots", displayName: "New England Patriots", parentLeagueId: "football-nfl" });
  });
});
