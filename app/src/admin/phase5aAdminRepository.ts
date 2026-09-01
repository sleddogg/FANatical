import { requireSupabase } from "../lib/supabase/client";
import type { NewsIdentityTargetType } from "../features/news/types";

type UnknownRecord = Record<string, unknown>;

function record(value: unknown): UnknownRecord | null {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as UnknownRecord : null;
}

function text(value: unknown) {
  return typeof value === "string" && value ? value : null;
}

export type CommunityModerationQueueEntry = Readonly<{
  reportId: string;
  reason: string;
  explanation: string | null;
  reportedAt: string;
  commentId: string;
  commentBody: string;
  commentStatus: string;
  authorFanaticalName: string | null;
  reporterFanaticalName: string | null;
  priorRestrictionCount: number;
}>;

export type NewsRequestQueueEntry = Readonly<{
  targetId: string;
  inputKind: "url" | "name";
  displayInput: string;
  requesterCount: number;
  createdAt: string;
}>;

export type ActiveCommunityPostingRestriction = Readonly<{
  restrictionId: string;
  fanaticalName: string;
  ordinal: number;
  startsAt: string;
  endsAt: string;
  reason: string;
  createdAt: string;
}>;

export type NewsRequestFollowTarget = Readonly<{
  targetType: NewsIdentityTargetType;
  targetId: string;
  displayName: string;
}>;

export async function loadCommunityModerationQueue(): Promise<readonly CommunityModerationQueueEntry[]> {
  const { data, error } = await requireSupabase().rpc("get_community_moderation_queue");
  if (error) throw new Error(`Community moderation queue could not be loaded. ${error.message}`);
  return Array.isArray(data) ? data.flatMap((candidate): CommunityModerationQueueEntry[] => {
    const row = record(candidate);
    const reportId = text(row?.report_id);
    const reason = text(row?.reason);
    const reportedAt = text(row?.reported_at);
    const commentId = text(row?.comment_id);
    const commentBody = text(row?.comment_body);
    const commentStatus = text(row?.comment_status);
    const author = text(row?.author_fanatical_name);
    const reporter = text(row?.reporter_fanatical_name);
    if (!reportId || !reason || !reportedAt || !commentId || !commentBody || !commentStatus) return [];
    return [{
      reportId,
      reason,
      explanation: text(row?.explanation),
      reportedAt,
      commentId,
      commentBody,
      commentStatus,
      authorFanaticalName: author,
      reporterFanaticalName: reporter,
      priorRestrictionCount: typeof row?.prior_restriction_count === "number" ? row.prior_restriction_count : 0,
    }];
  }) : [];
}

export async function moderateCommunityReport(reportId: string, action: "dismiss" | "tombstone" | "restrict", reason: string) {
  const { error } = await requireSupabase().rpc("admin_moderate_community_report", {
    report_public_id_value: reportId,
    action_value: action,
    reason_value: reason.trim(),
  });
  if (error) throw new Error(`Community moderation action failed. ${error.message}`);
}

export async function loadActiveCommunityPostingRestrictions(): Promise<readonly ActiveCommunityPostingRestriction[]> {
  const { data, error } = await requireSupabase().rpc("get_active_community_posting_restrictions");
  if (error) throw new Error(`Active Community restrictions could not be loaded. ${error.message}`);
  return Array.isArray(data) ? data.flatMap((candidate): ActiveCommunityPostingRestriction[] => {
    const row = record(candidate);
    const restrictionId = text(row?.restriction_id);
    const fanaticalName = text(row?.fanatical_name);
    const startsAt = text(row?.starts_at);
    const endsAt = text(row?.ends_at);
    const reason = text(row?.reason);
    const createdAt = text(row?.created_at);
    return restrictionId && fanaticalName && startsAt && endsAt && reason && createdAt ? [{
      restrictionId,
      fanaticalName,
      ordinal: typeof row?.ordinal === "number" ? row.ordinal : 0,
      startsAt,
      endsAt,
      reason,
      createdAt,
    }] : [];
  }) : [];
}

export async function liftCommunityPostingRestriction(restrictionId: string, reason: string) {
  const { error } = await requireSupabase().rpc("admin_lift_community_posting_restriction", {
    restriction_public_id_value: restrictionId,
    reason_value: reason.trim(),
  });
  if (error) throw new Error(`Community restriction could not be lifted. ${error.message}`);
}

export async function loadNewsRequestQueue(): Promise<readonly NewsRequestQueueEntry[]> {
  const { data, error } = await requireSupabase().rpc("get_news_follow_request_queue");
  if (error) throw new Error(`News Request queue could not be loaded. ${error.message}`);
  return Array.isArray(data) ? data.flatMap((candidate): NewsRequestQueueEntry[] => {
    const row = record(candidate);
    const targetId = text(row?.request_target_id);
    const inputKind = row?.input_kind === "url" ? "url" : row?.input_kind === "name" ? "name" : null;
    const displayInput = text(row?.display_input);
    const createdAt = text(row?.created_at);
    if (!targetId || !inputKind || !displayInput || !createdAt) return [];
    return [{
      targetId,
      inputKind,
      displayInput,
      requesterCount: typeof row?.requester_count === "number" ? row.requester_count : 0,
      createdAt,
    }];
  }) : [];
}

export async function searchNewsRequestFollowTargets(
  query: string,
): Promise<readonly NewsRequestFollowTarget[]> {
  const { data, error } = await requireSupabase().rpc("search_news_follow_targets", {
    query_value: query.trim(),
  });
  if (error) throw new Error(`Current News targets could not be loaded. ${error.message}`);
  return (data ?? []).flatMap((row): NewsRequestFollowTarget[] => {
    const targetType = row.target_type === "author"
      || row.target_type === "organization"
      || row.target_type === "show"
      ? row.target_type
      : null;
    return targetType && row.target_id && row.display_name
      ? [{ targetType, targetId: row.target_id, displayName: row.display_name }]
      : [];
  });
}

export async function resolveNewsRequest(
  targetId: string,
  outcome: "available" | "unable",
  reason: string,
  followTarget?: Readonly<{ type: NewsIdentityTargetType; id: string }>,
) {
  const { error } = await requireSupabase().rpc("admin_resolve_news_follow_request", {
    request_target_public_id_value: targetId,
    outcome_value: outcome,
    follow_target_type_value: followTarget?.type ?? "",
    follow_target_public_id_value: followTarget?.id ?? "",
    reason_value: reason.trim(),
  });
  if (error) throw new Error(`News Request resolution failed. ${error.message}`);
}
