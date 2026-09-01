import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  rpc: vi.fn(),
}));

vi.mock("../../lib/supabase/client", () => ({
  requireSupabase: () => ({ rpc: mocks.rpc }),
}));

import { loadAccountInbox } from "./notificationRepository";

describe("notificationRepository", () => {
  beforeEach(() => mocks.rpc.mockReset());

  it("keeps a posting-restoration moderation notice separate from the social inbox", async () => {
    mocks.rpc.mockImplementation(async (functionName: string) => functionName === "get_my_community_notifications"
      ? { data: { unread_count: 0, notifications: [] }, error: null }
      : {
          data: {
            unread_count: 1,
            notices: [{
              notice_id: "notice-restored",
              type: "posting_restored",
              message: "Your Community posting restriction was lifted. You may post and reply again.",
              created_at: "2026-09-01T12:00:00Z",
              read: false,
            }],
          },
          error: null,
        });

    await expect(loadAccountInbox()).resolves.toEqual({
      unreadCount: 0,
      notifications: [],
      moderationUnreadCount: 1,
      moderationNotices: [{
        id: "notice-restored",
        type: "posting_restored",
        message: "Your Community posting restriction was lifted. You may post and reply again.",
        createdAt: "2026-09-01T12:00:00Z",
        read: false,
      }],
    });
  });
});
