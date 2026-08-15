import { describe, expect, it } from "vitest";
import { findOfficialTeam, type PopulatedTeamColors } from "../data/officialSportsDatabase";
import { colorContrast, teamBadgePalette, teamInitials } from "./TeamBadge";

describe("TeamBadge", () => {
  it("preserves current initials and chooses accessible palette combinations", () => {
    expect(teamInitials("Edmonton Oilers")).toBe("EO");
    expect(teamInitials("New England Patriots")).toBe("NEP");

    for (const teamId of [
      "hockey-nhl-edmonton-oilers",
      "football-nfl-new-england-patriots",
      "baseball-mlb-boston-red-sox",
      "basketball-nba-boston-celtics",
    ]) {
      const colors = findOfficialTeam(teamId)?.colors;
      expect(colors?.primary).not.toBeNull();
      const populatedColors = colors as PopulatedTeamColors;
      const palette = teamBadgePalette(populatedColors);
      expect(colorContrast(palette.text, palette.center)).toBeGreaterThanOrEqual(4.5);
      expect([populatedColors.primary, populatedColors.secondary]).toContain(palette.center);
      expect([populatedColors.primary, populatedColors.secondary]).toContain(palette.ring);
    }
  });
});
