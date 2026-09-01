import { requireSupabase } from "../../lib/supabase/client";
import type {
  CommunityAvatar,
  CommunityArticleReference,
  CommunityComment,
  CommunityCommentStatus,
  CommunityContextKind,
  CommunityDiscussion,
  CommunityDiscussionTeaser,
  DiscussionOrigin,
  HiddenFan,
  MemberProfile,
  TeamNewsDiscussionSummary,
} from "./types";

type UnknownRecord = Record<string, unknown>;

function record(value: unknown): UnknownRecord | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as UnknownRecord
    : null;
}

function text(value: unknown) {
  return typeof value === "string" && value ? value : null;
}

function requiredText(value: unknown, label: string) {
  const result = text(value);
  if (!result) throw new Error(`The Community service returned an invalid ${label}.`);
  return result;
}

function integer(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? Math.max(0, Math.trunc(value)) : 0;
}

function contextKind(value: unknown): CommunityContextKind {
  if (value === "team" || value === "competition" || value === "sport") return value;
  throw new Error("The Community service returned an invalid discussion context.");
}

function contextDisplayKind(value: unknown, kind: CommunityContextKind): CommunityDiscussion["contextDisplayKind"] {
  if (value === "Team" || value === "League" || value === "Competition" || value === "Sport") return value;
  return kind === "team" ? "Team" : kind === "sport" ? "Sport" : "Competition";
}

function commentStatus(value: unknown): CommunityCommentStatus {
  if (value === "active" || value === "deleted" || value === "moderated" || value === "unavailable") return value;
  throw new Error("The Community service returned an invalid comment state.");
}

function avatar(value: unknown): CommunityAvatar | null {
  const row = record(value);
  const displayPath = text(row?.display_path);
  if (!displayPath) return null;
  return {
    displayPath,
    width: typeof row?.width === "number" ? row.width : null,
    height: typeof row?.height === "number" ? row.height : null,
    focalX: typeof row?.focal_x === "number" ? row.focal_x : 0.5,
    focalY: typeof row?.focal_y === "number" ? row.focal_y : 0.5,
    zoom: typeof row?.zoom === "number" ? row.zoom : 1,
  };
}

function articleReference(value: unknown): CommunityArticleReference | null {
  const row = record(value);
  const newsItemId = text(row?.news_item_id);
  const itemKind = row?.item_kind === "written" || row?.item_kind === "podcast_episode"
    ? row.item_kind
    : null;
  const headline = text(row?.headline);
  const publishedAt = text(row?.publication_time);
  const destinationUrl = text(row?.destination_url);
  const publisherName = text(row?.publisher_name);
  if (!newsItemId || !itemKind || !headline || !publishedAt || !destinationUrl || !publisherName) return null;
  const previewUrl = text(row?.preview_url);
  const previewKind = text(row?.preview_kind);
  return {
    newsItemId,
    itemKind,
    headline,
    publishedAt,
    destinationUrl,
    publisherName,
    showName: text(row?.show_name),
    preview: previewUrl && previewKind ? {
      url: previewUrl,
      kind: previewKind,
      alt: text(row?.preview_alt_text) ?? "",
    } : null,
    bylines: Array.isArray(row?.bylines)
      ? row.bylines.filter((candidate): candidate is string => typeof candidate === "string" && Boolean(candidate))
      : [],
  };
}

function serviceError(prefix: string, error: { message: string } | null) {
  return new Error(error ? `${prefix} ${error.message}` : prefix);
}

export async function loadDiscussionTeaser(
  newsItemId: string,
  origin: DiscussionOrigin | null,
): Promise<CommunityDiscussionTeaser> {
  const argumentsValue: {
    news_item_public_id_value: string;
    origin_context_kind_value?: string;
    origin_context_public_id_value?: string;
  } = { news_item_public_id_value: newsItemId };
  if (origin) {
    argumentsValue.origin_context_kind_value = origin.kind;
    argumentsValue.origin_context_public_id_value = origin.targetId;
  }
  const { data, error } = await requireSupabase().rpc("get_news_discussion_teaser", argumentsValue);
  if (error) throw serviceError("Discussion could not be loaded.", error);
  const row = record(data) ?? {};
  const kindValue = text(row.context_kind);
  const resolvedKind = kindValue ? contextKind(kindValue) : null;
  return {
    available: row.available === true,
    requiresAuth: row.requires_auth === true,
    viewerCanAccess: typeof row.viewer_can_access === "boolean" ? row.viewer_can_access : null,
    newsItemId: text(row.news_item_id),
    contextKind: resolvedKind,
    contextDisplayKind: resolvedKind ? contextDisplayKind(row.context_display_kind, resolvedKind) : null,
    contextId: text(row.context_id),
    contextName: text(row.context_name),
    discussionId: text(row.discussion_id),
    commentCount: integer(row.comment_count),
    article: articleReference(row.article),
  };
}

export async function loadCommunityDiscussion(discussionId: string): Promise<CommunityDiscussion | null> {
  const { data, error } = await requireSupabase().rpc("get_community_discussion", {
    discussion_public_id_value: discussionId,
  });
  if (error) throw serviceError("Discussion could not be loaded.", error);
  const row = record(data);
  if (!row) return null;
  const comments = Array.isArray(row.comments) ? row.comments.flatMap((candidate): CommunityComment[] => {
    const item = record(candidate);
    if (!item) return [];
    return [{
      id: requiredText(item.comment_id, "comment ID"),
      parentId: text(item.parent_comment_id),
      body: requiredText(item.body, "comment body"),
      status: commentStatus(item.status),
      authorHidden: item.author_hidden === true,
      fanaticalName: text(item.fanatical_name),
      avatar: avatar(item.avatar),
      createdAt: requiredText(item.created_at, "comment time"),
      edited: item.edited === true,
      replyCount: integer(item.reply_count),
      canReply: item.can_reply === true,
      canEdit: item.can_edit === true,
      canDelete: item.can_delete === true,
      viewerHasReported: item.viewer_has_reported === true,
      canReport: item.can_report === true,
      canHide: item.can_hide === true,
      myHideIntentId: text(item.my_hide_intent_id),
      canUnhide: item.can_unhide === true,
    }];
  }) : [];
  const resolvedKind = contextKind(row.context_kind);
  return {
    id: requiredText(row.discussion_id, "discussion ID"),
    newsItemId: requiredText(row.news_item_id, "News Item ID"),
    contextKind: resolvedKind,
    contextDisplayKind: contextDisplayKind(row.context_display_kind, resolvedKind),
    contextId: requiredText(row.context_id, "context ID"),
    contextName: requiredText(row.context_name, "context name"),
    commentCount: integer(row.comment_count),
    contextIsCurrent: row.context_is_current === true,
    viewerHasFanaticalName: row.viewer_has_fanatical_name === true,
    postingRestrictedUntil: text(row.posting_restricted_until),
    article: articleReference(row.article),
    comments,
  };
}

export async function loadTeamNewsDiscussions(teamId: string): Promise<readonly TeamNewsDiscussionSummary[]> {
  const { data, error } = await requireSupabase().rpc("get_team_news_discussions", {
    team_public_id_value: teamId,
  });
  if (error) throw serviceError("Team Article Discussions could not be loaded.", error);
  return Array.isArray(data) ? data.flatMap((candidate): TeamNewsDiscussionSummary[] => {
    const row = record(candidate);
    const article = articleReference(row?.article);
    const discussionId = text(row?.discussion_id);
    const newsItemId = text(row?.news_item_id);
    const contextId = text(row?.context_id);
    const contextName = text(row?.context_name);
    const createdAt = text(row?.created_at);
    return article && discussionId && newsItemId && contextId && contextName && createdAt ? [{
      discussionId,
      newsItemId,
      contextId,
      contextName,
      commentCount: integer(row?.comment_count),
      createdAt,
      article,
    }] : [];
  }) : [];
}

export async function postCommunityComment(
  newsItemId: string,
  contextKindValue: CommunityContextKind,
  contextId: string,
  body: string,
) {
  const { data, error } = await requireSupabase().rpc("post_news_discussion_comment", {
    news_item_public_id_value: newsItemId,
    context_kind_value: contextKindValue,
    context_public_id_value: contextId,
    body_value: body,
  });
  if (error) throw serviceError("Comment could not be posted.", error);
  const row = record(data);
  return {
    discussionId: requiredText(row?.discussion_id, "discussion ID"),
    commentId: requiredText(row?.comment_id, "comment ID"),
  };
}

export async function postExistingCommunityComment(discussionId: string, body: string) {
  const { data, error } = await requireSupabase().rpc("post_existing_community_discussion_comment", {
    discussion_public_id_value: discussionId,
    body_value: body,
  });
  if (error) throw serviceError("Comment could not be posted.", error);
  const row = record(data);
  return {
    discussionId: requiredText(row?.discussion_id, "discussion ID"),
    commentId: requiredText(row?.comment_id, "comment ID"),
  };
}

export async function replyToCommunityComment(discussionId: string, parentCommentId: string, body: string) {
  const { error } = await requireSupabase().rpc("reply_to_community_comment", {
    discussion_public_id_value: discussionId,
    parent_comment_public_id_value: parentCommentId,
    body_value: body,
  });
  if (error) throw serviceError("Reply could not be posted.", error);
}

export async function editCommunityComment(commentId: string, body: string) {
  const { error } = await requireSupabase().rpc("edit_my_community_comment", {
    comment_public_id_value: commentId,
    body_value: body,
  });
  if (error) throw serviceError("Comment could not be edited.", error);
}

export async function deleteCommunityComment(commentId: string) {
  const { error } = await requireSupabase().rpc("delete_my_community_comment", {
    comment_public_id_value: commentId,
  });
  if (error) throw serviceError("Comment could not be deleted.", error);
}

export async function hideCommunityFan(fanaticalName: string) {
  const { error } = await requireSupabase().rpc("hide_community_user", {
    fanatical_name_value: fanaticalName,
  });
  if (error) throw serviceError(`${fanaticalName} could not be hidden.`, error);
}

export async function hideCommunityCommentAuthor(commentId: string) {
  const { error } = await requireSupabase().rpc("hide_community_comment_author", {
    comment_public_id_value: commentId,
  });
  if (error) throw serviceError("The comment author could not be hidden.", error);
}

export async function unhideCommunityFan(fanaticalName: string) {
  const { error } = await requireSupabase().rpc("unhide_community_user", {
    fanatical_name_value: fanaticalName,
  });
  if (error) throw serviceError(`${fanaticalName} could not be unhidden.`, error);
}

export async function unhideCommunityIntent(hideIntentId: string) {
  const { error } = await requireSupabase().rpc("unhide_community_intent", {
    hide_intent_public_id_value: hideIntentId,
  });
  if (error) throw serviceError("The Hide intent could not be removed.", error);
}

export async function loadMyHiddenFans(): Promise<readonly HiddenFan[]> {
  const { data, error } = await requireSupabase().rpc("get_my_hidden_fans");
  if (error) throw serviceError("Hidden fans could not be loaded.", error);
  return Array.isArray(data) ? data.flatMap((candidate): HiddenFan[] => {
    const row = record(candidate);
    const hideIntentId = text(row?.hide_intent_id);
    const fanaticalName = text(row?.fanatical_name);
    const hiddenSince = text(row?.hidden_since);
    return hideIntentId && hiddenSince ? [{
      hideIntentId,
      fanaticalName,
      hiddenSince,
      alsoHidesYou: row?.also_hides_you === true,
    }] : [];
  }) : [];
}

export async function reportCommunityComment(
  commentId: string,
  reason: "spam" | "harassment" | "hate" | "threats",
  explanation: string,
) {
  const { error } = await requireSupabase().rpc("report_community_comment", {
    comment_public_id_value: commentId,
    reason_value: reason,
    ...(explanation.trim() ? { explanation_value: explanation.trim() } : {}),
  });
  if (error) throw serviceError("Report could not be submitted.", error);
}

export async function setMyFanaticalName(fanaticalName: string) {
  const { error } = await requireSupabase().rpc("set_my_fanatical_name", {
    fanatical_name_value: fanaticalName.trim(),
  });
  if (error) throw serviceError("Fanatical Name could not be saved.", error);
}

export async function loadMyFanaticalName() {
  const user = await requireSupabase().auth.getUser();
  if (user.error || !user.data.user) throw new Error("Authentication is required.");
  const result = await requireSupabase().from("profiles").select("handle").eq("user_id", user.data.user.id).maybeSingle();
  if (result.error) throw serviceError("Fanatical Name could not be loaded.", result.error);
  return result.data?.handle ?? "";
}

export async function loadMemberProfile(fanaticalName: string): Promise<MemberProfile | null> {
  const { data, error } = await requireSupabase().rpc("get_member_profile_by_fanatical_name", {
    fanatical_name_value: fanaticalName,
  });
  if (error) throw serviceError("Profile could not be loaded.", error);
  const row = record(data);
  if (!row) return null;
  const personal = record(row.personal_fields) ?? {};
  const personalFields = Object.fromEntries(
    Object.entries(personal).filter((entry): entry is [string, string] => typeof entry[1] === "string"),
  );
  return {
    fanaticalName: requiredText(row.fanatical_name, "Fanatical Name"),
    visibility: row.visibility === "members_visible" ? "members_visible" : "private",
    isPrivate: row.is_private === true,
    displayName: text(row.display_name),
    tagline: text(row.tagline),
    avatar: avatar(row.avatar),
    personalFields,
  };
}
