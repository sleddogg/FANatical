import { beforeEach, describe, expect, it } from "vitest";
import { loadRexallVenue, resolveRexallSeat, rexallStorageKey, saveRexallVenue, seededRexallVenue } from "./rexallVenueData";

describe("Rexall Place venue mapping", () => {
  beforeEach(() => window.localStorage.removeItem(rexallStorageKey));

  it("seeds the physical sections and team seating profiles", () => {
    const venue = loadRexallVenue();
    expect(venue.sections).toHaveLength(66);
    expect(venue.sections.find((section) => section.section === "114")).toMatchObject({ level: "Lower", side: "Side A", end: "End A" });
    expect(venue.sections.find((section) => section.section === "120")).toMatchObject({ side: "Side A", end: "End B" });
    expect(venue.sections.find((section) => section.section === "134")).toMatchObject({ side: "Side B", end: "End B" });
    expect(venue.teamProfiles).toEqual(expect.arrayContaining([
      expect.objectContaining({ teamName: "Edmonton Oilers", levels: "Upper + Lower" }),
      expect.objectContaining({ teamName: "Edmonton Oil Kings", levels: "Lower only" }),
    ]));
  });

  it("resolves section defaults and explains boundary exceptions", () => {
    const regular = resolveRexallSeat(seededRexallVenue, "Section 114", "12", 8);
    expect(regular).toMatchObject({ level: { value: "Lower", source: "Section 114 mapping" }, side: { value: "Side A" }, end: { value: "End A" } });

    const exception = resolveRexallSeat(seededRexallVenue, "110", "12", 12);
    expect(exception?.side).toEqual({ value: "Side B", source: "Section 110 seats 11–24 exception" });
    expect(exception?.end).toEqual({ value: "End A", source: "Section 110 mapping" });
    expect(exception?.level.source).toBe("Section 110 mapping");
  });

  it("migrates legacy compass mappings, overrides, profiles, and venue reference data in place", () => {
    window.localStorage.setItem(rexallStorageKey, JSON.stringify({
      id: "venue-rexall-place",
      slug: "rexall-place",
      name: "Custom Rexall Name",
      location: "Custom Edmonton Location",
      seatingChartImageUrl: "https://example.test/custom-chart.png",
      seatingChartSourceLabel: "Custom chart source",
      seatingChartSourceUrl: "https://example.test/source",
      updatedAt: "2026-08-10T10:00:00.000Z",
      sections: [{
        section: "110",
        level: "Lower",
        eastWest: "West",
        northSouth: "North",
        exceptions: [{ id: "legacy-exception", rowStart: "C", rowEnd: "C", seatStart: 11, seatEnd: 24, level: null, eastWest: null, northSouth: "South" }],
      }],
      teamProfiles: [{ id: "custom-team", teamName: "Custom Team", levels: "Not Applicable", eastWest: "West only", northSouth: "North only" }],
    }));

    const migrated = loadRexallVenue();
    expect(migrated).toMatchObject({ name: "Custom Rexall Name", location: "Custom Edmonton Location", seatingChartSourceLabel: "Custom chart source" });
    expect(migrated).toMatchObject({ routingConventionVersion: 2 });
    expect(migrated.sections[0]).toMatchObject({ level: "Lower", side: "Side A", end: "End A" });
    expect(migrated.sections[0]?.exceptions[0]).toMatchObject({ rowStart: "C", seatStart: 11, side: "Side B", end: null });
    expect(migrated.teamProfiles[0]).toMatchObject({ teamName: "Custom Team", levels: "N/A", sides: "Side A only", ends: "End A only" });
    const persisted = JSON.parse(window.localStorage.getItem(rexallStorageKey) ?? "{}") as Record<string, unknown>;
    expect(JSON.stringify(persisted)).not.toContain("eastWest");
    expect(JSON.stringify(persisted)).not.toContain("northSouth");
  });

  it("corrects existing unversioned Side/End records without losing exceptions or profiles", () => {
    window.localStorage.setItem(rexallStorageKey, JSON.stringify({
      id: "venue-rexall-place",
      slug: "rexall-place",
      name: "Rexall Place",
      location: "Edmonton, Alberta",
      seatingChartImageUrl: "https://example.test/chart.png",
      seatingChartSourceLabel: "Preserved source",
      seatingChartSourceUrl: "https://example.test/source",
      updatedAt: "2026-08-11T12:00:00.000Z",
      sections: [{
        section: "110",
        level: "Lower",
        side: "Side B",
        end: "End A",
        exceptions: [{ id: "existing-boundary", rowStart: "", rowEnd: "", seatStart: 11, seatEnd: 24, level: null, side: null, end: "End B" }],
      }],
      teamProfiles: [{ id: "custom-team", teamName: "Custom Team", levels: "Lower only", sides: "Side B only", ends: "End A only" }],
    }));

    const corrected = loadRexallVenue();
    expect(corrected).toMatchObject({ routingConventionVersion: 2, seatingChartSourceLabel: "Preserved source" });
    expect(corrected.sections[0]).toMatchObject({ section: "110", side: "Side A", end: "End A" });
    expect(corrected.sections[0]?.exceptions[0]).toMatchObject({ id: "existing-boundary", seatStart: 11, side: "Side B", end: null });
    expect(corrected.teamProfiles[0]).toMatchObject({ teamName: "Custom Team", sides: "Side A only", ends: "End A only" });
  });

  it("persists mapping changes in browser storage", () => {
    const changed = { ...seededRexallVenue, sections: seededRexallVenue.sections.map((section) => section.section === "114" ? { ...section, level: "Upper" as const } : section) };
    saveRexallVenue(changed);
    expect(JSON.parse(window.localStorage.getItem(rexallStorageKey) ?? "{}").name).toBe("Rexall Place");
    expect(loadRexallVenue().sections.find((section) => section.section === "114")?.level).toBe("Upper");
  });
});
