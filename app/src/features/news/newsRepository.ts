import type { Database, Json } from "../../lib/supabase/database.types";
import { requireSupabase } from "../../lib/supabase/client";
import type {
  FanSafeNewsItem,
  FanSafeNewsItemKind,
  NewsByline,
  NewsClassification,
  NewsClassificationType,
  NewsDemoSelection,
  NewsFollowingEntry,
  NewsFollowTarget,
  NewsIdentityProfile,
  NewsIdentityTargetType,
  NewsNavigationEntry,
  NewsTemporaryFilter,
} from "./types";

type UnknownRecord = Record<string, unknown>;
const newsNavigationPageSize = 1_000;

function asRecord(value: unknown): UnknownRecord | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as UnknownRecord
    : null;
}

function requiredString(value: unknown, field: string) {
  if (typeof value !== "string" || !value) {
    throw new Error(`The News service returned an invalid ${field}.`);
  }
  return value;
}

function optionalString(value: unknown) {
  return typeof value === "string" && value ? value : null;
}

function identityTargetType(value: unknown): NewsIdentityTargetType {
  if (value === "author" || value === "organization" || value === "show") return value;
  throw new Error("The News service returned an invalid identity type.");
}

function itemKind(value: unknown): FanSafeNewsItemKind {
  if (value === "written" || value === "podcast_episode") return value;
  throw new Error("The News service returned an invalid Item kind.");
}

function classificationType(value: unknown): NewsClassificationType | null {
  return value === "sport"
    || value === "competition"
    || value === "competition_edition"
    || value === "team"
    ? value
    : null;
}

function competitionKind(value: unknown): NewsNavigationEntry["competitionKindId"] {
  return value === "league" || value === "cup" || value === "championship"
    || value === "tournament" || value === "tour" || value === "series" || value === "other"
    ? value
    : null;
}

function mapBylines(value: unknown): readonly NewsByline[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((candidate) => {
    const row = asRecord(candidate);
    if (!row || typeof row.raw_attribution !== "string" || !row.raw_attribution) return [];
    const targetType = row.target_type === null || row.target_type === undefined
      ? null
      : identityTargetType(row.target_type);
    const targetId = optionalString(row.target_id);
    return [{
      rawAttribution: row.raw_attribution,
      targetType: targetType && targetId ? targetType : null,
      targetId: targetType && targetId ? targetId : null,
    }];
  });
}

function mapClassifications(value: unknown): readonly NewsClassification[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((candidate) => {
    const row = asRecord(candidate);
    const targetType = classificationType(row?.target_type);
    const targetId = optionalString(row?.target_public_id);
    const displayName = optionalString(row?.target_display_name);
    return targetType && targetId && displayName
      ? [{ targetType, targetId, displayName }]
      : [];
  });
}

function mapFeedItem(candidate: unknown): FanSafeNewsItem {
  const row = asRecord(candidate);
  if (!row) throw new Error("The News service returned an invalid Item.");
  const previewUrl = optionalString(row.preview_url);
  const previewKind = optionalString(row.preview_kind);
  const showId = optionalString(row.show_id);
  const showName = optionalString(row.show_name);
  return {
    id: requiredString(row.news_item_id, "Item ID"),
    itemKind: itemKind(row.item_kind),
    headline: requiredString(row.headline, "headline"),
    summary: requiredString(row.summary, "summary"),
    publishedAt: requiredString(row.publication_time, "publication time"),
    serverTime: requiredString(row.server_time, "server time"),
    destinationUrl: requiredString(row.destination_url, "representative destination"),
    publisher: {
      id: requiredString(row.publisher_id, "publisher ID"),
      name: requiredString(row.publisher_name, "publisher name"),
    },
    show: showId && showName ? { id: showId, name: showName } : null,
    preview: previewUrl && previewKind
      ? {
          url: previewUrl,
          kind: previewKind,
          alt: optionalString(row.preview_alt_text) ?? "",
        }
      : null,
    bylines: mapBylines(row.bylines),
    classifications: mapClassifications(row.classifications),
  };
}

function feedArguments(filter: NewsTemporaryFilter) {
  return filter.kind === "all"
    ? { filter_kind_value: "all" }
    : {
        filter_kind_value: filter.kind,
        filter_target_public_id_value: filter.targetId,
      };
}

function serviceError(message: string, error: { message: string } | null) {
  return new Error(error ? `${message} ${error.message}` : message);
}

export async function loadPersonalNewsFeed(filter: NewsTemporaryFilter) {
  const { data, error } = await requireSupabase().rpc("get_my_news_feed", feedArguments(filter));
  if (error) throw serviceError("Your News feed could not be loaded.", error);
  return (data ?? []).map(mapFeedItem);
}

export async function loadMyNewsZeroFollowExample(teamId: string) {
  const { data, error } = await requireSupabase().rpc("get_my_news_zero_follow_example", {
    team_public_id_value: teamId,
  });
  if (error) throw serviceError("The News EXAMPLE could not be loaded.", error);
  return data?.[0] ? mapFeedItem(data[0]) : null;
}

export async function loadNewsDemoUniverse(): Promise<readonly NewsFollowTarget[]> {
  const { data, error } = await requireSupabase().rpc("get_news_demo_universe");
  if (error) throw serviceError("News Demo Mode could not be loaded.", error);
  return (data ?? []).map((row) => ({
    targetType: identityTargetType(row.target_type),
    targetId: requiredString(row.target_id, "Demo identity ID"),
    displayName: requiredString(row.display_name, "Demo identity name"),
  }));
}

export async function loadNewsDemoFeed(
  selections: readonly NewsDemoSelection[],
  filter: NewsTemporaryFilter,
) {
  const { data, error } = await requireSupabase().rpc("get_news_demo_feed", {
    selected_targets_value: selections.map((selection) => ({
      target_type: selection.targetType,
      target_id: selection.targetId,
    })) as Json,
    ...feedArguments(filter),
  });
  if (error) throw serviceError("The News Demo feed could not be loaded.", error);
  return (data ?? []).map(mapFeedItem);
}

export async function loadMyNewsFollowing(): Promise<readonly NewsFollowingEntry[]> {
  const { data, error } = await requireSupabase().rpc("get_my_news_following");
  if (error) throw serviceError("Your followed News identities could not be loaded.", error);
  return (data ?? []).map((row) => ({
    targetType: identityTargetType(row.target_type),
    targetId: requiredString(row.target_id, "followed identity ID"),
    displayName: requiredString(row.display_name, "followed identity name"),
    followIds: Array.isArray(row.follow_ids) ? row.follow_ids : [],
    mutedUntil: optionalString(row.muted_until),
    needsReselection: row.needs_reselection === true,
    sportScopeIds: Array.isArray(row.sport_scope_ids) ? row.sport_scope_ids : [],
    teamScopeIds: Array.isArray(row.team_scope_ids) ? row.team_scope_ids : [],
  }));
}

export async function searchNewsFollowTargets(query: string, teamId: string | null) {
  const args: { query_value?: string; team_public_id_value?: string } = {};
  if (query.trim()) args.query_value = query.trim();
  if (teamId) args.team_public_id_value = teamId;
  const { data, error } = await requireSupabase().rpc("search_news_follow_targets", args);
  if (error) throw serviceError("Add to Feed search could not be loaded.", error);
  return (data ?? []).map((row): NewsFollowTarget => ({
    targetType: identityTargetType(row.target_type),
    targetId: requiredString(row.target_id, "follow target ID"),
    displayName: requiredString(row.display_name, "follow target name"),
  }));
}

export async function followNewsTarget(
  target: NewsFollowTarget,
  sportScopeIds: readonly string[] = [],
  teamScopeIds: readonly string[] = [],
) {
  const { error } = await requireSupabase().rpc("follow_news_identity", {
    target_type_value: target.targetType,
    target_public_id_value: target.targetId,
    sport_scope_ids_value: [...sportScopeIds],
    team_scope_ids_value: [...teamScopeIds],
  });
  if (error) throw serviceError(`${target.displayName} could not be added to your feed.`, error);
}

export async function setNewsFollowScopes(
  followIds: readonly string[],
  sportScopeIds: readonly string[],
  teamScopeIds: readonly string[],
) {
  const followId = followIds[0];
  if (!followId) throw new Error("The followed identity has no current follow record.");
  const { error } = await requireSupabase().rpc("set_my_news_follow_scopes", {
    follow_id_value: followId,
    sport_scope_ids_value: [...sportScopeIds],
    team_scope_ids_value: [...teamScopeIds],
  });
  if (error) throw serviceError("The followed identity's scopes could not be saved.", error);
}

export async function muteNewsFollow(followId: string, duration: "7_days" | "30_days") {
  const { error } = await requireSupabase().rpc("mute_my_news_follow", {
    follow_id_value: followId,
    duration_value: duration,
  });
  if (error) throw serviceError("The followed identity could not be muted.", error);
}

export async function unmuteNewsFollow(followId: string) {
  const { error } = await requireSupabase().rpc("unmute_my_news_follow", { follow_id_value: followId });
  if (error) throw serviceError("The followed identity could not be unmuted.", error);
}

export async function unfollowNewsTarget(followId: string) {
  const { error } = await requireSupabase().rpc("unfollow_news_identity", { follow_id_value: followId });
  if (error) throw serviceError("The followed identity could not be removed from your feed.", error);
}

export async function dismissNewsItem(newsItemId: string) {
  const { error } = await requireSupabase().rpc("dismiss_news_item", {
    news_item_public_id_value: newsItemId,
  });
  if (error) throw serviceError("The News Item could not be dismissed.", error);
}

export async function undoNewsItemDismissal(newsItemId: string) {
  const { error } = await requireSupabase().rpc("undo_news_item_dismissal", {
    news_item_public_id_value: newsItemId,
  });
  if (error) throw serviceError("The News Item dismissal could not be undone.", error);
}

export async function loadNewsNavigation(): Promise<readonly NewsNavigationEntry[]> {
  const rows: Database["public"]["Functions"]["get_news_navigation"]["Returns"] = [];
  for (let offset = 0; ; offset += newsNavigationPageSize) {
    const { data, error } = await requireSupabase()
      .rpc("get_news_navigation")
      .range(offset, offset + newsNavigationPageSize - 1);
    if (error) throw serviceError("News filters could not be loaded.", error);
    const page = data ?? [];
    rows.push(...page);
    if (page.length < newsNavigationPageSize) break;
  }
  return rows.flatMap((row) => {
    const filterType = row.filter_type;
    if (filterType !== "sport" && filterType !== "competition" && filterType !== "team") return [];
    return [{
      filterType,
      targetId: requiredString(row.target_id, "News filter ID"),
      displayName: requiredString(row.display_name, "News filter name"),
      sportId: requiredString(row.sport_id, "News filter Sport ID"),
      competitionKindId: competitionKind(row.competition_kind_id),
      isFollowed: row.is_followed === true,
    }];
  });
}

export async function loadNewsIdentityProfile(
  targetType: NewsIdentityTargetType,
  targetId: string,
): Promise<NewsIdentityProfile> {
  const { data, error } = await requireSupabase().rpc("get_news_identity_profile", {
    target_type_value: targetType,
    target_public_id_value: targetId,
  });
  if (error) throw serviceError("The contributor profile could not be loaded.", error);
  const row = data?.[0];
  if (!row) throw new Error("This contributor profile is not currently available.");
  return {
    targetType: identityTargetType(row.target_type),
    targetId: requiredString(row.target_id, "profile identity ID"),
    displayName: requiredString(row.display_name, "profile identity name"),
  };
}

export async function loadNewsIdentityItems(
  targetType: NewsIdentityTargetType,
  targetId: string,
) {
  const { data, error } = await requireSupabase().rpc("get_news_identity_items", {
    target_type_value: targetType,
    target_public_id_value: targetId,
  });
  if (error) throw serviceError("This contributor's News Items could not be loaded.", error);
  return (data ?? []).map(mapFeedItem);
}

export async function recordNewsOutboundOpen(newsItemId: string, destinationUrl: string) {
  const { error } = await requireSupabase().rpc("record_news_outbound_open", {
    news_item_public_id_value: newsItemId,
    destination_url_value: destinationUrl,
  });
  if (error) throw serviceError("The outbound open could not be recorded.", error);
}
