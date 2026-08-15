import { beforeEach, describe, expect, it } from "vitest";
import { developmentCheerLibrary } from "./mockCheerData";
import { generateLiveVariants, liveRoutingDimensions, loadPreloadedLiveVariant, preloadAvailableLiveVariants, resolveTargetRelativeLiveVariant, selectLiveVariant, withPublishTimeLiveVariants } from "./cheerLiveVariants";
import type { CheerRecord, CrowdAssignment, MappedVenueCheckIn } from "./types";

const lowerSideAEndA: MappedVenueCheckIn = {
  type: "MappedVenue",
  raw: { method: "Manual", eventId: "mock-event:venue-rexall-place:edmonton-oilers:current", venueId: "venue-rexall-place", venueName: "Rexall Place", sport: "Hockey", teamEvent: "Edmonton Oilers", section: "114", row: "12", seat: "8" },
  resolved: { level: "Lower", side: "Side A", end: "End A", sources: { level: "Section mapping", side: "Section mapping", end: "Section mapping" } },
  confirmedAt: "2026-08-14T18:00:00.000Z",
};

function routedTest(audiences: readonly CrowdAssignment[]): CheerRecord {
  const source = developmentCheerLibrary[0]!;
  const segment = source.measures[0]!.actionSegments[0]!;
  return {
    ...source,
    id: "cheer-local-live-test",
    title: "test",
    measures: [{
      ...source.measures[0]!,
      actionSegments: audiences.map((audience, index) => ({ ...segment, id: `action-${index}`, eventId: `action-${index}`, startUnit: index * 2, audience })),
      lyricSegments: [],
    }],
  };
}

function combinations(cheer: CheerRecord) {
  return generateLiveVariants(cheer, "2026-08-14T00:00:00.000Z").map((variant) => [variant.routing.level, variant.routing.side, variant.routing.end]);
}

describe("publish-time Live Variants", () => {
  beforeEach(() => window.sessionStorage.clear());

  it("generates 1, 2, 4, or 8 variants from the dimensions actually used", () => {
    expect(generateLiveVariants(routedTest(["All"]))).toHaveLength(1);
    expect(generateLiveVariants(routedTest(["Upper"]))).toHaveLength(2);
    expect(generateLiveVariants(routedTest(["Upper", "Side A"]))).toHaveLength(4);
    expect(generateLiveVariants(routedTest(["Upper", "Side A", "End A"]))).toHaveLength(8);
  });

  it("generates all eight Level, Side, and End combinations for a three-dimension test Cheer", () => {
    const cheer = routedTest(["Upper", "Lower", "Side A", "Side B", "End A", "End B"]);
    expect(liveRoutingDimensions(cheer)).toEqual(["Level", "Side", "End"]);
    expect(combinations(cheer)).toEqual([
      ["Upper", "Side A", "End A"],
      ["Upper", "Side A", "End B"],
      ["Upper", "Side B", "End A"],
      ["Upper", "Side B", "End B"],
      ["Lower", "Side A", "End A"],
      ["Lower", "Side A", "End B"],
      ["Lower", "Side B", "End A"],
      ["Lower", "Side B", "End B"],
    ]);
  });

  it("generates only for a published Cheer titled test when it is saved", () => {
    const target = routedTest(["Upper"]);
    expect(withPublishTimeLiveVariants(target).liveVariants).toHaveLength(2);
    expect(withPublishTimeLiveVariants({ ...target, title: "Another Cheer" }).liveVariants).toBeUndefined();
    expect(withPublishTimeLiveVariants({ ...target, publicationStatus: "Draft" }).liveVariants).toBeUndefined();
  });

  it("selects and caches only the variant matching the resolved seat", () => {
    const cheer = withPublishTimeLiveVariants(routedTest(["Upper", "Side A", "End A"]));
    const selected = selectLiveVariant(cheer, lowerSideAEndA);
    expect(selected?.routing).toEqual({ level: "Lower", side: "Side A", end: "End A" });
    expect(preloadAvailableLiveVariants([cheer], lowerSideAEndA)).toHaveLength(1);
    expect(loadPreloadedLiveVariant(cheer.id, lowerSideAEndA)?.id).toBe(selected?.id);
  });

  it("uses the proposal target end to include target-relative choreography only for fans in that end", () => {
    const source = routedTest(["All", "Backboard Left"]);
    const cheer = { ...source, liveVariants: generateLiveVariants(source) };
    const variant = selectLiveVariant(cheer, lowerSideAEndA)!;
    const targetFan = resolveTargetRelativeLiveVariant(cheer, variant, lowerSideAEndA, "End A");
    const otherEndCheckIn: MappedVenueCheckIn = {
      ...lowerSideAEndA,
      resolved: { ...lowerSideAEndA.resolved, end: "End B" },
    };
    const otherFan = resolveTargetRelativeLiveVariant(cheer, variant, otherEndCheckIn, "End A");
    expect(targetFan.measures[0]?.actionSegments).toHaveLength(2);
    expect(otherFan.measures[0]?.actionSegments).toHaveLength(1);
    expect(otherFan.measures[0]?.actionSegments[0]?.sourceAudience).toBe("All");
  });
});
