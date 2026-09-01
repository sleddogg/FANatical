import { requireSupabase } from "../../lib/supabase/client";

type UnknownRecord = Record<string, unknown>;

function record(value: unknown): UnknownRecord | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as UnknownRecord
    : null;
}

function text(value: unknown) {
  return typeof value === "string" && value ? value : null;
}

export type AccountNotification = Readonly<{
  id: string;
  type: "direct_reply" | "request_available" | "request_unable";
  actorFanaticalName: string | null;
  metadata: UnknownRecord;
  createdAt: string;
  read: boolean;
}>;

export type ModerationNotice = Readonly<{
  id: string;
  type: "comment_removed" | "posting_restricted" | "posting_restored";
  message: string;
  createdAt: string;
  read: boolean;
}>;

export type AccountInbox = Readonly<{
  unreadCount: number;
  notifications: readonly AccountNotification[];
  moderationUnreadCount: number;
  moderationNotices: readonly ModerationNotice[];
}>;

function count(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? Math.max(0, Math.trunc(value)) : 0;
}

export async function loadAccountInbox(): Promise<AccountInbox> {
  const client = requireSupabase();
  const [socialResult, moderationResult] = await Promise.all([
    client.rpc("get_my_community_notifications"),
    client.rpc("get_my_community_moderation_notices"),
  ]);
  if (socialResult.error) throw new Error(`Inbox could not be loaded. ${socialResult.error.message}`);
  if (moderationResult.error) throw new Error(`Account notices could not be loaded. ${moderationResult.error.message}`);
  const social = record(socialResult.data) ?? {};
  const moderation = record(moderationResult.data) ?? {};
  const notifications = Array.isArray(social.notifications) ? social.notifications.flatMap((candidate): AccountNotification[] => {
    const row = record(candidate);
    const id = text(row?.notification_id);
    const type = row?.type === "direct_reply" || row?.type === "request_available" || row?.type === "request_unable" ? row.type : null;
    const createdAt = text(row?.created_at);
    if (!id || !type || !createdAt) return [];
    return [{
      id,
      type,
      actorFanaticalName: text(row?.actor_fanatical_name),
      metadata: record(row?.metadata) ?? {},
      createdAt,
      read: row?.read === true,
    }];
  }) : [];
  const notices = Array.isArray(moderation.notices) ? moderation.notices.flatMap((candidate): ModerationNotice[] => {
    const row = record(candidate);
    const id = text(row?.notice_id);
    const type = row?.type === "comment_removed" || row?.type === "posting_restricted" || row?.type === "posting_restored" ? row.type : null;
    const message = text(row?.message);
    const createdAt = text(row?.created_at);
    return id && type && message && createdAt ? [{ id, type, message, createdAt, read: row?.read === true }] : [];
  }) : [];
  return {
    unreadCount: count(social.unread_count),
    notifications,
    moderationUnreadCount: count(moderation.unread_count),
    moderationNotices: notices,
  };
}

export async function markNotificationsRead(ids: readonly string[]) {
  if (!ids.length) return;
  const { error } = await requireSupabase().rpc("mark_my_community_notifications_read", {
    notification_public_ids: [...ids],
  });
  if (error) throw new Error(`Inbox could not be marked read. ${error.message}`);
}

export async function markModerationNoticesRead(ids: readonly string[]) {
  if (!ids.length) return;
  const { error } = await requireSupabase().rpc("mark_my_community_moderation_notices_read", {
    notice_public_ids: [...ids],
  });
  if (error) throw new Error(`Account notices could not be marked read. ${error.message}`);
}
