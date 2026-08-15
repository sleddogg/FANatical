import { describe, expect, it } from "vitest";
import { developmentCheerLibrary, initialCheerLibrary, seededCheerLibrary } from "./mockCheerData";
import { deriveAudienceZoneRequirements } from "./cheerAudienceEligibility";
import { filterCheers, isCheerLaunchEligible, type CheerLibraryFilter } from "./cheerLibrary";
import type { CheerRecord, CrowdAssignment, MappedVenueCheckIn } from "./types";

const oilersCheckIn: MappedVenueCheckIn = {
  type: "MappedVenue",
  raw: { method: "Manual", venueId: "venue-rexall-place", venueName: "Rexall Place", sport: "Hockey", teamEvent: "Edmonton Oilers", section: "114", row: "12", seat: "8" },
  resolved: { level: "Lower", side: "Side A", end: "End A", sources: { level: "Section mapping", side: "Section mapping", end: "Section mapping" } },
  confirmedAt: "2026-08-14T18:00:00.000Z",
};

const oilKingsCheckIn: MappedVenueCheckIn = {
  ...oilersCheckIn,
  raw: { ...oilersCheckIn.raw, teamEvent: "Edmonton Oil Kings" },
};

function withAudienceZones(audiences: readonly CrowdAssignment[]): CheerRecord {
  const source = developmentCheerLibrary[0]!;
  const measure = source.measures[0]!;
  return {
    ...source,
    id: `audience-${audiences.join("-")}`,
    title: `Audience ${audiences.join(" + ")}`,
    measures: [{
      ...measure,
      actionSegments: audiences.map((audience, index) => ({
        ...measure.actionSegments[0]!,
        id: `audience-action-${index}`,
        eventId: `audience-action-${index}`,
        startUnit: index * 2,
        audience,
      })),
      lyricSegments: [],
    }],
  };
}

function titles(filter: CheerLibraryFilter) {
  return filterCheers(seededCheerLibrary, filter, oilersCheckIn, "Demo User").map((cheer) => cheer.title);
}

describe("Cheer Library filtering and launch eligibility", () => {
  it("uses exact Sport-wide, League-wide, and Team matches", () => {
    expect(titles({ kind: "sport", sportId: "hockey" })).toEqual(["Hockey Crowd Pulse"]);
    expect(titles({ kind: "league", leagueId: "hockey-nhl" })).toEqual(["NHL Ice Roar"]);
    expect(titles({ kind: "team", teamId: "hockey-nhl-edmonton-oilers" })).toEqual(["Oil Country Rise"]);
    expect(titles({ kind: "league", leagueId: "hockey-shl" })).toEqual(["SHL Ice Thunder"]);
    expect(titles({ kind: "sport", sportId: "baseball" })).toEqual(["Ballpark Rally"]);
  });

  it("keeps browsing filters separate from current launch eligibility", () => {
    const [genericHockey, nhl, oilers, shl, baseball] = developmentCheerLibrary;
    expect(isCheerLaunchEligible(genericHockey!, oilersCheckIn)).toBe(true);
    expect(isCheerLaunchEligible(nhl!, oilersCheckIn)).toBe(true);
    expect(isCheerLaunchEligible(oilers!, oilersCheckIn)).toBe(true);
    expect(isCheerLaunchEligible(shl!, oilersCheckIn)).toBe(false);
    expect(isCheerLaunchEligible(baseball!, oilersCheckIn)).toBe(false);
    expect(isCheerLaunchEligible(initialCheerLibrary[0]!, oilersCheckIn)).toBe(false);
    expect(titles({ kind: "available" })).toEqual(["Hockey Crowd Pulse", "NHL Ice Roar", "Oil Country Rise"]);
  });

  it("derives Upper and Lower requirements from Who routing", () => {
    const cheer = withAudienceZones(["Upper", "Lower", "Upper", "Side A"]);
    expect([...deriveAudienceZoneRequirements(cheer)]).toEqual(["Upper", "Lower"]);
  });

  it("requires the checked-in event profile to support every routed level", () => {
    const bothLevels = withAudienceZones(["Upper", "Lower"]);
    const lowerOnly = withAudienceZones(["Lower"]);

    expect(isCheerLaunchEligible(bothLevels, oilersCheckIn)).toBe(true);
    expect(isCheerLaunchEligible(bothLevels, oilKingsCheckIn)).toBe(false);
    expect(isCheerLaunchEligible(lowerOnly, oilKingsCheckIn)).toBe(true);
  });

  it("keeps a zone-incompatible Cheer browseable outside Available Now", () => {
    const bothLevels = withAudienceZones(["Upper", "Lower"]);
    expect(filterCheers([bothLevels], { kind: "available" }, oilKingsCheckIn, "Demo User")).toEqual([]);
    expect(filterCheers([bothLevels], { kind: "sport", sportId: "hockey" }, oilKingsCheckIn, "Demo User")).toEqual([bothLevels]);
    expect(filterCheers([bothLevels], { kind: "all" }, oilKingsCheckIn, "Demo User")).toEqual([bothLevels]);
  });
});
