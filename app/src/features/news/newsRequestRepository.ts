import { requireSupabase } from "../../lib/supabase/client";
import type { NewsFollowTarget, NewsIdentityTargetType } from "./types";

type UnknownRecord = Record<string, unknown>;

function record(value: unknown): UnknownRecord | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as UnknownRecord
    : null;
}

function text(value: unknown) {
  return typeof value === "string" && value ? value : null;
}

function targetType(value: unknown): NewsIdentityTargetType | null {
  return value === "author" || value === "organization" || value === "show" ? value : null;
}

export type NewsFollowRequestState = "Pending" | "Available" | "Unable to add";

export type NewsFollowRequest = Readonly<{
  id: string;
  inputKind: "url" | "name";
  rawInput: string;
  state: NewsFollowRequestState;
  reason: string | null;
  requestedAt: string;
  resolvedAt: string | null;
  followTarget: NewsFollowTarget | null;
  canFollow: boolean;
  isFollowing: boolean;
}>;

export async function submitNewsFollowRequest(inputKind: "url" | "name", rawInput: string) {
  const { data, error } = await requireSupabase().rpc("submit_news_follow_request", {
    input_kind_value: inputKind,
    raw_input_value: rawInput,
  });
  if (error) throw new Error(`Request could not be submitted. ${error.message}`);
  return data;
}

export async function loadMyNewsFollowRequests(): Promise<readonly NewsFollowRequest[]> {
  const { data, error } = await requireSupabase().rpc("get_my_news_follow_requests");
  if (error) throw new Error(`Requests could not be loaded. ${error.message}`);
  return Array.isArray(data) ? data.flatMap((candidate): NewsFollowRequest[] => {
    const row = record(candidate);
    const id = text(row?.request_id);
    const inputKind = row?.input_kind === "url" ? "url" : row?.input_kind === "name" ? "name" : null;
    const rawInput = text(row?.raw_input);
    const state = row?.state === "Available" || row?.state === "Unable to add" || row?.state === "Pending" ? row.state : null;
    const requestedAt = text(row?.requested_at);
    if (!id || !inputKind || !rawInput || !state || !requestedAt) return [];
    const followTargetType = targetType(row?.follow_target_type);
    const followTargetId = text(row?.follow_target_id);
    const followTargetName = text(row?.follow_target_name);
    return [{
      id,
      inputKind,
      rawInput,
      state,
      reason: text(row?.reason),
      requestedAt,
      resolvedAt: text(row?.resolved_at),
      followTarget: followTargetType && followTargetId && followTargetName
        ? { targetType: followTargetType, targetId: followTargetId, displayName: followTargetName }
        : null,
      canFollow: row?.can_follow === true,
      isFollowing: row?.is_following === true,
    }];
  }) : [];
}
