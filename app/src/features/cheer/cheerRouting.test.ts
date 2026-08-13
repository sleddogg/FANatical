import { describe, expect, it } from "vitest";
import { cheerAudienceImage, cheerAudienceOptions, migrateLegacyAudience, requiredSportForRouting } from "./cheerRouting";
import type { CheerSport, CrowdAssignment } from "./types";

const expectedOptions: Record<CheerSport, CrowdAssignment[]> = {
  Soccer: ["All", "Upper", "Lower", "Side A", "Side B", "End A", "End B"],
  Hockey: ["All", "Upper", "Lower", "Side A", "Side B", "End A", "End B"],
  Basketball: ["All", "Upper", "Lower", "Side A", "Side B", "End A", "End B", "Backboard Left", "Backboard Right"],
  Football: ["All", "Upper", "Lower", "Side A", "Side B", "End A", "End B", "Uprights Left", "Uprights Right"],
  Baseball: ["All", "Upper", "Lower", "Side A", "Side B", "First Base Side", "Third Base Side", "Outfield"],
  Generic: ["All", "Upper", "Lower", "Side A", "Side B", "End A", "End B"],
  Other: ["All", "Upper", "Lower", "Side A", "Side B", "End A", "End B"],
};

describe("Cheer WHO routing", () => {
  it.each(Object.entries(expectedOptions) as [CheerSport, CrowdAssignment[]][])("offers the correct %s routes", (sport, choices) => {
    expect(cheerAudienceOptions(sport)).toEqual(choices);
    expect(cheerAudienceOptions(sport)).not.toEqual(expect.arrayContaining(["East", "West", "North", "South"]));
  });

  it.each(Object.entries(expectedOptions) as [CheerSport, CrowdAssignment[]][])("provides working graphics for %s routes except compact All", (sport, choices) => {
    expect(cheerAudienceImage("All", sport)).toBeNull();
    for (const choice of choices.filter((audience) => audience !== "All")) {
      expect(cheerAudienceImage(choice, sport)).toMatch(/^\/src\/|^data:|\.(png|webp|jpg)/);
    }
  });

  it("converts legacy compass assignments to the new routing language", () => {
    expect(migrateLegacyAudience("North", "Hockey")).toBe("Side A");
    expect(migrateLegacyAudience("South", "Football")).toBe("Side B");
    expect(migrateLegacyAudience("West", "Soccer")).toBe("End A");
    expect(migrateLegacyAudience("East", "Basketball")).toBe("End B");
    expect(migrateLegacyAudience("East", "Baseball")).toBe("First Base Side");
    expect(migrateLegacyAudience("West", "Baseball")).toBe("Third Base Side");
    expect(migrateLegacyAudience("North", "Baseball")).toBe("Outfield");
  });

  it("locks only sport-specific routing assignments", () => {
    const measure = (audience: CrowdAssignment) => [{ id: "m", actionSegments: [{ id: "a", eventId: "a", startUnit: 0, units: 2, duration: "Eighth" as const, timingType: "Note" as const, continuesFromPrevious: false, continuesToNext: false, action: "Clap" as const, audience }], lyricSegments: [], restSegments: [] }];
    expect(requiredSportForRouting(measure("Side A"))).toBeNull();
    expect(requiredSportForRouting(measure("Uprights Left"))).toBe("Football");
    expect(requiredSportForRouting(measure("Backboard Right"))).toBe("Basketball");
    expect(requiredSportForRouting(measure("Outfield"))).toBe("Baseball");
  });
});
