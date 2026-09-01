import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ rpc: vi.fn() }));

vi.mock("../../lib/supabase/client", () => ({
  requireSupabase: () => ({ rpc: mocks.rpc }),
}));

import { loadCommunityDiscussion } from "./communityRepository";

describe("communityRepository", () => {
  beforeEach(() => mocks.rpc.mockReset());

  it("preserves the backend suspension deadline and denied participation capabilities", async () => {
    mocks.rpc.mockResolvedValue({
      data: {
        discussion_id: "community-discussion-one",
        news_item_id: "news-item-one",
        context_kind: "sport",
        context_display_kind: "Sport",
        context_id: "hockey",
        context_name: "Hockey",
        comment_count: 1,
        context_is_current: true,
        viewer_has_fanatical_name: true,
        posting_restricted_until: "2026-09-08T12:00:00Z",
        article: null,
        comments: [{
          comment_id: "community-comment-one",
          parent_comment_id: null,
          body: "Existing readable comment",
          status: "active",
          author_hidden: false,
          fanatical_name: "SuspendedFan",
          avatar: null,
          created_at: "2026-09-01T12:00:00Z",
          edited: false,
          reply_count: 0,
          can_reply: false,
          can_edit: false,
          can_delete: false,
          viewer_has_reported: false,
          can_report: false,
          can_hide: false,
          my_hide_intent_id: null,
          can_unhide: false,
        }],
      },
      error: null,
    });

    await expect(loadCommunityDiscussion("community-discussion-one"))
      .resolves.toMatchObject({
        postingRestrictedUntil: "2026-09-08T12:00:00Z",
        comments: [{ canReply: false, canEdit: false, canDelete: false }],
      });
  });
});
