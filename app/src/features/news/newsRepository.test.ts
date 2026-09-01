import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  rpc: vi.fn(),
}));

vi.mock("../../lib/supabase/client", () => ({
  requireSupabase: () => ({ rpc: mocks.rpc }),
}));

import {
  loadNewsDemoFeed,
  loadNewsNavigation,
  loadPersonalNewsFeed,
  recordNewsOutboundOpen,
} from "./newsRepository";

const row = {
  news_item_id: "news-item-one",
  item_kind: "written",
  headline: "A current published headline",
  summary: "A fan-safe summary.",
  publication_time: "2026-08-29T16:00:00.000Z",
  server_time: "2026-08-29T17:00:00.000Z",
  destination_url: "https://publisher.example/item",
  publisher_id: "publisher-one",
  publisher_name: "Publisher One",
  show_id: null,
  show_name: null,
  preview_url: "https://publisher.example/preview.jpg",
  preview_kind: "image",
  preview_alt_text: "Players at practice.",
  bylines: [
    { raw_attribution: "Historical Name", target_type: "author", target_id: "author-current" },
    { raw_attribution: "Disputed Name", target_type: null, target_id: null },
  ],
  classifications: [
    { target_type: "sport", target_public_id: "hockey", target_display_name: "Hockey" },
  ],
};

describe("Phase 4 News repository", () => {
  beforeEach(() => mocks.rpc.mockReset());

  it("maps only the fan-safe feed fields and passes temporary filters without a client page limit", async () => {
    mocks.rpc.mockResolvedValue({ data: [row], error: null });
    const result = await loadPersonalNewsFeed({
      kind: "team",
      targetId: "hockey-000027",
      displayName: "Edmonton Oilers",
    });

    expect(mocks.rpc).toHaveBeenCalledWith("get_my_news_feed", {
      filter_kind_value: "team",
      filter_target_public_id_value: "hockey-000027",
    });
    expect(result[0]).toMatchObject({
      id: "news-item-one",
      destinationUrl: "https://publisher.example/item",
      publisher: { id: "publisher-one", name: "Publisher One" },
      preview: { alt: "Players at practice." },
      bylines: [
        { rawAttribution: "Historical Name", targetType: "author", targetId: "author-current" },
        { rawAttribution: "Disputed Name", targetType: null, targetId: null },
      ],
    });
    expect(result[0]).not.toHaveProperty("body");
    expect(result[0]).not.toHaveProperty("viewCount");
    expect(result[0]).not.toHaveProperty("reactionCount");
    expect(result[0]).not.toHaveProperty("review");
  });

  it("sends Demo selections as the complete caller-local bounded target set", async () => {
    mocks.rpc.mockResolvedValue({ data: [], error: null });
    await loadNewsDemoFeed([
      { targetType: "organization", targetId: "organization-one" },
      { targetType: "show", targetId: "show-one" },
    ], { kind: "all", displayName: "All Followed News" });

    expect(mocks.rpc).toHaveBeenCalledWith("get_news_demo_feed", {
      selected_targets_value: [
        { target_type: "organization", target_id: "organization-one" },
        { target_type: "show", target_id: "show-one" },
      ],
      filter_kind_value: "all",
    });
  });

  it("records only the exact Item and representative destination supplied by the card", async () => {
    mocks.rpc.mockResolvedValue({ data: "event-id", error: null });
    await recordNewsOutboundOpen("news-item-one", "https://publisher.example/item");
    expect(mocks.rpc).toHaveBeenCalledWith("record_news_outbound_open", {
      news_item_public_id_value: "news-item-one",
      destination_url_value: "https://publisher.example/item",
    });
  });

  it("pages the canonical News navigation beyond the PostgREST row cap", async () => {
    const firstPage = Array.from({ length: 1_000 }, (_, index) => ({
      filter_type: "team",
      target_id: `team-${index}`,
      display_name: `Team ${index}`,
      sport_id: "hockey",
    }));
    const range = vi.fn()
      .mockResolvedValueOnce({ data: firstPage, error: null })
      .mockResolvedValueOnce({
        data: [{
          filter_type: "competition",
          target_id: "hockey-nhl",
          display_name: "National Hockey League",
          sport_id: "hockey",
          competition_kind_id: "league",
          is_followed: false,
        }],
        error: null,
      });
    mocks.rpc.mockReturnValue({ range });

    const result = await loadNewsNavigation();

    expect(mocks.rpc).toHaveBeenNthCalledWith(1, "get_news_navigation");
    expect(mocks.rpc).toHaveBeenNthCalledWith(2, "get_news_navigation");
    expect(range).toHaveBeenNthCalledWith(1, 0, 999);
    expect(range).toHaveBeenNthCalledWith(2, 1_000, 1_999);
    expect(result).toHaveLength(1_001);
    expect(result.at(-1)).toEqual({
      filterType: "competition",
      targetId: "hockey-nhl",
      displayName: "National Hockey League",
      sportId: "hockey",
      competitionKindId: "league",
      isFollowed: false,
    });
  });
});
