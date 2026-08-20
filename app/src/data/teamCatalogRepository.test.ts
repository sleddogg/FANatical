import { describe, expect, it } from "vitest";
import { findCatalogTeam, teamCatalogSnapshotFromRows } from "./teamCatalogRepository";

describe("team catalog repository compatibility projection", () => {
  it("maps canonical rows and namespaced legacy identifiers", () => {
    const snapshot = teamCatalogSnapshotFromRows(
      [{ sport_id: "hockey", display_name: "Hockey", active: true }],
      [{ league_id: "hockey-nhl", display_name: "National Hockey League", short_name: "NHL", sport_id: "hockey", active: true, seed_status: "imported_unverified" }],
      [{
        team_id: "hockey-000027",
        sport_id: "hockey",
        display_name: "Edmonton Oilers",
        short_name: "Edmonton Oilers",
        abbreviation: null,
        identity_status: "imported_unverified",
        primary_league_id: "hockey-nhl",
        primary_league_status: "imported_unverified",
        primary_color: "#FF4C00",
        secondary_color: "#041E42",
        tertiary_color: "#FFFFFF",
        quaternary_color: null,
        quinary_color: null,
        external_identifiers: [{ namespace: "legacy_frontend_id", identifier: "hockey-nhl-edmonton-oilers" }],
      }],
      [{ team_id: "hockey-000027", catalog_ready: false, live_cheer_ready: false }],
    );

    expect(snapshot.source).toBe("backend");
    expect(snapshot.teams).toHaveLength(1);
    expect(snapshot.teams[0]).toMatchObject({
      canonicalTeamId: "hockey-000027",
      legacyFrontendTeamId: "hockey-nhl-edmonton-oilers",
      parentLeagueId: "hockey-nhl",
      colors: { primary: "#FF4C00", secondary: "#041E42" },
      catalogReady: false,
    });
    expect(findCatalogTeam(snapshot, "hockey-000027")?.displayName).toBe("Edmonton Oilers");
    expect(findCatalogTeam(snapshot, "hockey-nhl-edmonton-oilers")?.canonicalTeamId).toBe("hockey-000027");
  });

  it("does not expose partially populated palettes", () => {
    const snapshot = teamCatalogSnapshotFromRows(
      [],
      [],
      [{
        team_id: "hockey-000001",
        sport_id: "hockey",
        display_name: "Example Team",
        short_name: "Example",
        primary_league_id: "hockey-nhl",
        primary_color: "#000000",
        secondary_color: null,
        external_identifiers: [],
      }],
      [],
    );
    expect(snapshot.teams[0]?.colors).toEqual({ primary: null, secondary: null, tertiary: null, quaternary: null, quinary: null });
  });
});
