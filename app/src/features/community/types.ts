export type CommunityContextKind = "team" | "competition" | "sport";

export type DiscussionOrigin = Readonly<{
  kind: CommunityContextKind;
  targetId: string;
}>;

export type CommunityDiscussionTeaser = Readonly<{
  available: boolean;
  requiresAuth: boolean;
  viewerCanAccess: boolean | null;
  newsItemId: string | null;
  contextKind: CommunityContextKind | null;
  contextDisplayKind: "Team" | "League" | "Competition" | "Sport" | null;
  contextId: string | null;
  contextName: string | null;
  discussionId: string | null;
  commentCount: number;
  article: CommunityArticleReference | null;
}>;

export type CommunityArticleReference = Readonly<{
  newsItemId: string;
  itemKind: "written" | "podcast_episode";
  headline: string;
  publishedAt: string;
  destinationUrl: string;
  publisherName: string;
  showName: string | null;
  preview: Readonly<{
    url: string;
    kind: string;
    alt: string;
  }> | null;
  bylines: readonly string[];
}>;

export type CommunityAvatar = Readonly<{
  displayPath: string;
  width: number | null;
  height: number | null;
  focalX: number;
  focalY: number;
  zoom: number;
}>;

export type CommunityCommentStatus = "active" | "deleted" | "moderated" | "unavailable";

export type CommunityComment = Readonly<{
  id: string;
  parentId: string | null;
  body: string;
  status: CommunityCommentStatus;
  authorHidden: boolean;
  fanaticalName: string | null;
  avatar: CommunityAvatar | null;
  createdAt: string;
  edited: boolean;
  replyCount: number;
  canReply: boolean;
  canEdit: boolean;
  canDelete: boolean;
  viewerHasReported: boolean;
  canReport: boolean;
  canHide: boolean;
  myHideIntentId: string | null;
  canUnhide: boolean;
}>;

export type CommunityDiscussion = Readonly<{
  id: string;
  newsItemId: string;
  contextKind: CommunityContextKind;
  contextDisplayKind: "Team" | "League" | "Competition" | "Sport";
  contextId: string;
  contextName: string;
  commentCount: number;
  contextIsCurrent: boolean;
  viewerHasFanaticalName: boolean;
  postingRestrictedUntil: string | null;
  article: CommunityArticleReference | null;
  comments: readonly CommunityComment[];
}>;

export type TeamNewsDiscussionSummary = Readonly<{
  discussionId: string;
  newsItemId: string;
  contextId: string;
  contextName: string;
  commentCount: number;
  createdAt: string;
  article: CommunityArticleReference;
}>;

export type MemberProfile = Readonly<{
  fanaticalName: string;
  visibility: "private" | "members_visible";
  isPrivate: boolean;
  displayName: string | null;
  tagline: string | null;
  avatar: CommunityAvatar | null;
  personalFields: Readonly<Record<string, string>>;
}>;

export type HiddenFan = Readonly<{
  hideIntentId: string;
  fanaticalName: string | null;
  hiddenSince: string;
  alsoHidesYou: boolean;
}>;
