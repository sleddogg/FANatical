import { beforeEach, describe, expect, it } from "vitest";
import { cheerCheckInStorageKey, clearCheerCheckIn, emptyMappedCheckInDraft, loadCheckInVenues, loadCheerCheckIn, loadGeneralLocations, resolveGeneralLocationCheckIn, resolveMappedCheckIn, saveCheerCheckIn, venueRows, venueSeats } from "./cheerCheckIn";

describe("Cheer venue Check-In", () => {
  beforeEach(() => window.localStorage.clear());

  it("uses the configured venue inventory and existing seat resolver", () => {
    const venue = loadCheckInVenues()[0]!.venue;
    const draft = { ...emptyMappedCheckInDraft("Manual"), venueId: venue.id, venueName: venue.name, sport: "Hockey" as const, teamEvent: "Edmonton Oil Kings", section: "110", row: "12", seat: "12" };
    expect(venueRows(venue, draft.section)).toContain("12");
    expect(venueSeats(venue, draft.section, draft.row)).toContain("12");
    expect(resolveMappedCheckIn(venue, draft)).toMatchObject({
      type: "MappedVenue",
      raw: { venueName: "Rexall Place", sport: "Hockey", section: "110", row: "12", seat: "12" },
      resolved: { level: "Lower", side: "Side B", end: "End A", sources: { side: "Section 110 seats 11–24 exception" } },
    });
  });

  it("persists raw and resolved Check-In data together", () => {
    const venue = loadCheckInVenues()[0]!.venue;
    const checkIn = resolveMappedCheckIn(venue, { ...emptyMappedCheckInDraft("Image"), venueId: venue.id, venueName: venue.name, sport: "Hockey", teamEvent: "Edmonton Oilers", section: "114", row: "12", seat: "8" });
    expect(checkIn).not.toBeNull();
    saveCheerCheckIn(checkIn!);
    expect(window.localStorage.getItem(cheerCheckInStorageKey)).toContain("Rexall Place");
    expect(loadCheerCheckIn()).toEqual(checkIn);
    clearCheerCheckIn();
    expect(loadCheerCheckIn()).toBeNull();
  });

  it("persists a canonical general location as an All-only context", () => {
    const location = loadGeneralLocations()[0]!;
    const checkIn = resolveGeneralLocationCheckIn(location);
    saveCheerCheckIn(checkIn);
    expect(loadCheerCheckIn()).toEqual(checkIn);
    expect(checkIn).toMatchObject({ type: "GeneralLocation", location: { id: location.id, contextKey: location.contextKey }, routing: { mode: "AllOnly" } });
  });

  it("migrates the existing raw/resolved Check-In record to the mapped type", () => {
    window.localStorage.setItem(cheerCheckInStorageKey, JSON.stringify({
      raw: { method: "Manual", venueId: "venue-rexall-place", venueName: "Rexall Place", sport: "Hockey", teamEvent: "Edmonton Oilers", section: "114", row: "12", seat: "8" },
      resolved: { level: "Lower", side: "Side A", end: "End A", sources: { level: "Section 114 mapping", side: "Section 114 mapping", end: "Section 114 mapping" } },
      confirmedAt: "2026-08-12T00:00:00.000Z",
    }));
    expect(loadCheerCheckIn()).toMatchObject({ type: "MappedVenue", raw: { section: "114", row: "12", seat: "8" }, resolved: { level: "Lower", side: "Side A", end: "End A" } });
  });
});
