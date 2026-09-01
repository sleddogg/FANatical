import { act, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { AccountInbox } from "./notificationRepository";

const mocks = vi.hoisted(() => ({
  loadAccountInbox: vi.fn(),
  markModerationNoticesRead: vi.fn(),
  markNotificationsRead: vi.fn(),
}));

vi.mock("../account/AuthContext", () => ({
  useAuth: () => ({ configured: true, loading: false, user: { id: "viewer-one" } }),
}));

vi.mock("./notificationRepository", async (importOriginal) => {
  const original = await importOriginal<typeof import("./notificationRepository")>();
  return {
    ...original,
    loadAccountInbox: mocks.loadAccountInbox,
    markModerationNoticesRead: mocks.markModerationNoticesRead,
    markNotificationsRead: mocks.markNotificationsRead,
  };
});

import { InboxControl } from "./InboxControl";
import { NotificationProvider } from "./NotificationContext";

const emptyInbox: AccountInbox = {
  unreadCount: 0,
  notifications: [],
  moderationUnreadCount: 0,
  moderationNotices: [],
};

const staleInbox: AccountInbox = {
  ...emptyInbox,
  unreadCount: 1,
  notifications: [{
    id: "notification-one",
    type: "direct_reply",
    actorFanaticalName: "HiddenFan",
    metadata: { discussion_id: "discussion-one" },
    createdAt: "2026-08-31T00:00:00Z",
    read: false,
  }],
};

const restoredInbox: AccountInbox = {
  ...emptyInbox,
  moderationUnreadCount: 1,
  moderationNotices: [{
    id: "notice-restored",
    type: "posting_restored",
    message: "Your Community posting restriction was lifted. You may post and reply again.",
    createdAt: "2026-09-01T12:00:00Z",
    read: false,
  }],
};

describe("InboxControl", () => {
  beforeEach(() => {
    mocks.loadAccountInbox.mockReset();
    mocks.markModerationNoticesRead.mockReset().mockResolvedValue(undefined);
    mocks.markNotificationsRead.mockReset().mockResolvedValue(undefined);
  });

  it("never renders a cached direct notification while the authoritative refresh is pending", async () => {
    let resolveRefresh!: (value: AccountInbox) => void;
    const refreshResult = new Promise<AccountInbox>((resolve) => { resolveRefresh = resolve; });
    mocks.loadAccountInbox
      .mockResolvedValueOnce(staleInbox)
      .mockReturnValueOnce(refreshResult)
      .mockResolvedValueOnce(emptyInbox);
    const user = userEvent.setup();
    render(<NotificationProvider><InboxControl /></NotificationProvider>);

    await screen.findByRole("button", { name: "Inbox, 1 unread" });
    await user.click(screen.getByRole("button", { name: "Inbox, 1 unread" }));
    expect(screen.getByRole("status")).toHaveTextContent("Refreshing…");
    expect(screen.queryByText(/HiddenFan replied/)).not.toBeInTheDocument();

    await act(async () => { resolveRefresh(emptyInbox); });
    await waitFor(() => expect(screen.getByText("No reply or Request notifications.")).toBeInTheDocument());
  });

  it("fails closed instead of revealing cached notification content when refresh fails", async () => {
    mocks.loadAccountInbox
      .mockResolvedValueOnce(staleInbox)
      .mockRejectedValueOnce(new Error("Authoritative refresh failed"));
    const user = userEvent.setup();
    render(<NotificationProvider><InboxControl /></NotificationProvider>);

    await screen.findByRole("button", { name: "Inbox, 1 unread" });
    await user.click(screen.getByRole("button", { name: "Inbox, 1 unread" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("Authoritative refresh failed");
    expect(screen.queryByText(/HiddenFan replied/)).not.toBeInTheDocument();
    expect(screen.queryByText("Replies and Requests")).not.toBeInTheDocument();
  });

  it("renders and marks a posting-restoration message as a separate account notice", async () => {
    mocks.loadAccountInbox
      .mockResolvedValueOnce(restoredInbox)
      .mockResolvedValueOnce(restoredInbox)
      .mockResolvedValueOnce({
        ...restoredInbox,
        moderationUnreadCount: 0,
        moderationNotices: [{ ...restoredInbox.moderationNotices[0], read: true }],
      });
    const user = userEvent.setup();
    render(<NotificationProvider><InboxControl /></NotificationProvider>);

    await screen.findByRole("button", { name: "Inbox, 1 unread" });
    await user.click(screen.getByRole("button", { name: "Inbox, 1 unread" }));

    expect(await screen.findByText("Your Community posting restriction was lifted. You may post and reply again.")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Account notices" })).toBeInTheDocument();
    await waitFor(() => expect(mocks.markModerationNoticesRead).toHaveBeenCalledWith(["notice-restored"]));
  });
});
