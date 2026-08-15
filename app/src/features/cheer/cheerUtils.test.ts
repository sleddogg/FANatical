import { describe, expect, it } from "vitest";
import { audienceMatchesCheckIn, canPlaceRest, canPlaceSegment, distributeLyricLine, durationUnits, estimateSyllables, measureUsedUnits, segmentPositions, trackEndUnit } from "./cheerUtils";
import type { CheerActionSegment, CheerLyricSegment, CheerMeasure } from "./types";

function actionSegment(id: string, startUnit: number, duration: CheerActionSegment["duration"], action: CheerActionSegment["action"] = "Clap", audience: CheerActionSegment["audience"] = "All"): CheerActionSegment {
  return { id, eventId: id, startUnit, units: durationUnits[duration], duration, timingType: "Note", continuesFromPrevious: false, continuesToNext: false, action, audience };
}

function lyricSegment(id: string, startUnit: number, duration: CheerLyricSegment["duration"], lyric: string, audience: CheerLyricSegment["audience"] = "All"): CheerLyricSegment {
  return { id, eventId: id, startUnit, units: durationUnits[duration], duration, timingType: "Note", continuesFromPrevious: false, continuesToNext: false, lyric, audience };
}

describe("Cheer composition helpers", () => {
  it("estimates English syllables without making the helper mandatory", () => {
    expect(estimateSyllables("We love the players", "English")).toBeGreaterThan(0);
    expect(estimateSyllables("你好，球迷", "Auto")).toBeNull();
    expect(estimateSyllables("Any language remains valid", "Other")).toBeNull();
  });

  it("suggests intact lyric chunks across available beats", () => {
    expect(distributeLyricLine("We love the players more than our sons", 4)).toEqual([
      "We love",
      "the players",
      "more than",
      "our sons",
    ]);
  });

  it("uses sixteenth-note units to calculate a 4/4 measure", () => {
    expect(durationUnits.Whole).toBe(16);
    expect(durationUnits["Dotted Half"]).toBe(12);
    expect(durationUnits["Three Quarter"]).toBe(3);
    expect(durationUnits["One and a Quarter"]).toBe(5);
    expect(durationUnits["One and a Half"]).toBe(6);
    const measure: CheerMeasure = { id: "measure", actionSegments: [
      actionSegment("one", 0, "Half", "None"),
      actionSegment("two", 8, "Quarter", "Clap", "East"),
      actionSegment("three", 12, "Quarter"),
    ], lyricSegments: [lyricSegment("lyric", 0, "Whole", "Defence", "West")], restSegments: [] };
    expect(measureUsedUnits(measure, "action")).toBe(16);
    expect(measureUsedUnits(measure, "lyrics")).toBe(16);
    expect(segmentPositions(measure.actionSegments).map(({ startUnit }) => startUnit)).toEqual([0, 8, 12]);
    expect(trackEndUnit(measure, "action")).toBe(16);
    expect(canPlaceSegment(measure, "action", 6, 2)).toBe(false);
    expect(canPlaceSegment(measure, "lyrics", 8, 2)).toBe(false);
  });

  it("keeps empty rhythmic positions while preventing collisions", () => {
    const measure: CheerMeasure = { id: "gapped", actionSegments: [actionSegment("clap", 8, "Eighth")], lyricSegments: [], restSegments: [] };
    expect(canPlaceSegment(measure, "action", 0, 2)).toBe(true);
    expect(canPlaceSegment(measure, "action", 7, 2)).toBe(false);
    expect(canPlaceSegment(measure, "action", 10, 2)).toBe(true);
    expect(segmentPositions(measure.actionSegments)[0]?.startUnit).toBe(8);
  });

  it("reserves a Rest across both content tracks", () => {
    const rest = { id: "rest", eventId: "rest", startUnit: 4, units: 4, duration: "Quarter" as const, continuesFromPrevious: false, continuesToNext: false, originTrack: "action" as const, action: "Clap" as const, lyric: "", audience: "All" as const };
    const measure: CheerMeasure = { id: "rested", actionSegments: [], lyricSegments: [], restSegments: [rest] };
    expect(canPlaceSegment(measure, "action", 4, 1)).toBe(false);
    expect(canPlaceSegment(measure, "lyrics", 6, 1)).toBe(false);
    expect(canPlaceSegment(measure, "lyrics", 8, 1)).toBe(true);
    expect(canPlaceRest({ ...measure, restSegments: [], lyricSegments: [lyricSegment("words", 8, "Quarter", "Go")] }, 8, 4)).toBe(false);
  });

  it("routes only All and matching single location attributes", () => {
    const checkIn = {
      type: "MappedVenue",
      raw: { method: "Manual", eventId: "mock-event:venue-rexall-place:hockey:current", venueId: "venue-rexall-place", venueName: "Rexall Place", sport: "Hockey", teamEvent: "", section: "214", row: "12", seat: "8" },
      resolved: { level: "Upper", side: "Side A", end: "End A", sources: { level: "Section mapping", side: "Section mapping", end: "Section mapping" } },
      confirmedAt: "2026-08-12T00:00:00.000Z",
    } as const;
    expect(audienceMatchesCheckIn("All", checkIn)).toBe(true);
    expect(audienceMatchesCheckIn("Upper", checkIn)).toBe(true);
    expect(audienceMatchesCheckIn("Side A", checkIn)).toBe(true);
    expect(audienceMatchesCheckIn("End A", checkIn)).toBe(true);
    expect(audienceMatchesCheckIn("Lower", checkIn)).toBe(false);
    expect(audienceMatchesCheckIn("Side B", checkIn)).toBe(false);
  });

  it("allows only All routing at a general location", () => {
    const checkIn = { type: "GeneralLocation", location: { id: "park", name: "Park", locality: "Edmonton", contextKey: "park" }, routing: { mode: "AllOnly" }, confirmedAt: "2026-08-12T00:00:00.000Z" } as const;
    expect(audienceMatchesCheckIn("All", checkIn)).toBe(true);
    expect(audienceMatchesCheckIn("Upper", checkIn)).toBe(false);
    expect(audienceMatchesCheckIn("Side A", checkIn)).toBe(false);
  });
});
