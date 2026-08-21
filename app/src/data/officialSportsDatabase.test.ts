import { describe, expect, it } from "vitest";
import { findOfficialLeague, findOfficialSportById, officialLeagues, officialSports, officialTeams } from "./officialSportsDatabase";

describe("official sports database", () => {
  it("preserves the controlled Sport to League to Team hierarchy", () => {
    expect(officialSports.map((sport) => sport.displayName)).toEqual(["Football", "Baseball", "Basketball", "Hockey", "Soccer", "Generic", "Other"]);
    expect(officialLeagues).toHaveLength(20);
    expect(officialTeams).toHaveLength(366);
    expect(new Set(officialLeagues.map((league) => league.id))).toHaveProperty("size", officialLeagues.length);
    expect(new Set(officialTeams.map((team) => team.id))).toHaveProperty("size", officialTeams.length);

    for (const league of officialLeagues) expect(findOfficialSportById(league.parentSportId)).not.toBeNull();
    for (const team of officialTeams) expect(findOfficialLeague(team.parentLeagueId)).not.toBeNull();
  });

  it("uses explicit stable IDs independently from display labels", () => {
    expect(officialLeagues).toContainEqual({ id: "hockey-nhl", displayName: "NHL", parentSportId: "hockey" });
    expect(officialTeams).toContainEqual(expect.objectContaining({ id: "hockey-nhl-edmonton-oilers", displayName: "Edmonton Oilers", parentLeagueId: "hockey-nhl" }));
    expect(officialTeams).toContainEqual(expect.objectContaining({ id: "football-nfl-new-england-patriots", displayName: "New England Patriots", parentLeagueId: "football-nfl" }));
  });

  it("stores complete canonical palettes only for the four currently populated teams", () => {
    const populated = officialTeams.filter((team) => team.colors.primary !== null);
    expect(populated.map((team) => team.id)).toEqual([
      "basketball-nba-boston-celtics",
      "hockey-nhl-edmonton-oilers",
      "baseball-mlb-boston-red-sox",
      "football-nfl-new-england-patriots",
    ]);
    expect(populated.find((team) => team.id === "hockey-nhl-edmonton-oilers")?.colors).toEqual({ primary: "#00205B", secondary: "#D14520", tertiary: "#FFFFFF", quaternary: null, quinary: null });
    expect(populated.find((team) => team.id === "basketball-nba-boston-celtics")?.colors).toEqual({ primary: "#007A33", secondary: "#BA9653", tertiary: "#963821", quaternary: "#FFFFFF", quinary: null });
    expect(officialTeams.find((team) => team.id === "hockey-nhl-anaheim-ducks")?.colors).toEqual({ primary: null, secondary: null, tertiary: null, quaternary: null, quinary: null });
  });
});
