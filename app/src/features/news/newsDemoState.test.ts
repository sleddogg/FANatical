import { beforeEach, describe, expect, it } from "vitest";
import {
  clearNewsDemoState,
  loadNewsDemoSelections,
  saveNewsDemoSelections,
} from "./newsDemoState";

const universe = [
  { targetType: "author", targetId: "author-one", displayName: "Author One" },
  { targetType: "show", targetId: "show-one", displayName: "Show One" },
] as const;

describe("News Demo runtime state", () => {
  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
    clearNewsDemoState();
  });

  it("keeps choices in memory only and prunes anything outside the governed universe", () => {
    expect(loadNewsDemoSelections(universe)).toEqual([
      { targetType: "author", targetId: "author-one" },
      { targetType: "show", targetId: "show-one" },
    ]);

    saveNewsDemoSelections([
      { targetType: "show", targetId: "show-one" },
      { targetType: "author", targetId: "not-configured" },
    ]);
    expect(loadNewsDemoSelections(universe)).toEqual([
      { targetType: "show", targetId: "show-one" },
    ]);
    expect(localStorage).toHaveLength(0);
    expect(sessionStorage).toHaveLength(0);
  });

  it("discards every choice when authentication clears Demo state", () => {
    saveNewsDemoSelections([{ targetType: "show", targetId: "show-one" }]);
    clearNewsDemoState();
    expect(loadNewsDemoSelections(universe)).toHaveLength(2);
  });
});
