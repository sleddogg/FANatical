import { describe, expect, it } from "vitest";
import {
  communityDiscussionPath,
  discussionOriginForFilter,
  parseDiscussionOrigin,
} from "./discussionRouting";

describe("Phase 5A discussion routing", () => {
  it.each([
    ["team", "hockey-000027", "Edmonton Oilers"],
    ["competition", "hockey-nhl", "National Hockey League"],
    ["sport", "hockey", "Hockey"],
  ] as const)("preserves the active %s context", (kind, targetId, displayName) => {
    const origin = discussionOriginForFilter({ kind, targetId, displayName });
    expect(origin).toEqual({ kind, targetId });
    expect(communityDiscussionPath("news/item", origin))
      .toBe(`/news/discussions/news%2Fitem?context=${kind}&target=${targetId}`);
    expect(parseDiscussionOrigin(new URLSearchParams(`context=${kind}&target=${targetId}`)))
      .toEqual({ kind, targetId });
  });

  it("keeps All/no-origin routing explicit and rejects incomplete context queries", () => {
    expect(discussionOriginForFilter({ kind: "all", displayName: "All Followed News" })).toBeNull();
    expect(communityDiscussionPath("news-one", null)).toBe("/news/discussions/news-one");
    expect(parseDiscussionOrigin(new URLSearchParams("context=team"))).toBeNull();
    expect(parseDiscussionOrigin(new URLSearchParams("context=all&target=hockey"))).toBeNull();
  });
});
