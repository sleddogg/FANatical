import { describe, expect, it } from "vitest";
import { createInitialFollowedSourcePreferences, mockNewsItems } from "./mockNewsData";
import { filterNewsItems } from "./newsFiltering";

const initialPreferences = createInitialFollowedSourcePreferences();

describe("News feed filtering", () => {
  it("shows the selected team's items newest first", () => {
    const items = filterNewsItems(
      mockNewsItems,
      { kind: "team", teamId: "new-england-patriots" },
      initialPreferences,
    );

    expect(items.map((item) => item.id)).toEqual([
      "patriots-camp-tempo",
      "patriots-audio-notebook",
    ]);
  });

  it("combines all leagues in a sport while preserving chronology", () => {
    const items = filterNewsItems(
      mockNewsItems,
      { kind: "sport", sportId: "football" },
      initialPreferences,
    );

    expect(new Set(items.map((item) => item.league))).toEqual(new Set(["nfl", "cfl", "ufl"]));
    expect(items.map((item) => Date.parse(item.publishedAt))).toEqual(
      [...items].map((item) => Date.parse(item.publishedAt)).sort((first, second) => second - first),
    );
  });

  it("combines followed sources and honors source-level controls", () => {
    const allItems = filterNewsItems(mockNewsItems, { kind: "all" }, initialPreferences);
    expect(allItems.some((item) => item.sourceId === "film-room-lab")).toBe(false);
    expect(new Set(allItems.map((item) => item.sport))).toEqual(new Set(["football", "baseball", "basketball"]));

    const mutedPreferences = initialPreferences.map((preference) => preference.sourceId === "diamond-line"
      ? { ...preference, mutedUntil: new Date(Date.now() + 86_400_000).toISOString() }
      : preference);
    const withoutDiamondLine = filterNewsItems(mockNewsItems, { kind: "all" }, mutedPreferences);

    expect(withoutDiamondLine.some((item) => item.sourceId === "diamond-line")).toBe(false);
  });
});
