import type { TeamId } from "../../domain/team";

export type SportId = "football" | "baseball" | "basketball";
export type LeagueId = "nfl" | "cfl" | "ufl" | "mlb" | "milb" | "nba" | "wnba";
export type NewsContentType =
  | "Article"
  | "News"
  | "Blog"
  | "Video"
  | "Podcast"
  | "Team Update"
  | "League Update";
export type NewsViewType = "local" | "external";
export type SourceAccessStatus = "usable" | "partial" | "restricted" | "unavailable";

export type NewsDiscussionScope =
  | Readonly<{ kind: "team"; teamId: TeamId }>
  | Readonly<{ kind: "league"; leagueId: LeagueId }>
  | Readonly<{ kind: "sport"; sportId: SportId }>;

export type NewsSource = Readonly<{
  id: string;
  name: string;
  initials: string;
  description: string;
  category: "Media Outlet" | "Creator" | "Blogger" | "Podcast" | "Show";
  accessStatus: SourceAccessStatus;
  contentTypes: readonly NewsContentType[];
  sportTags: readonly SportId[];
}>;

export type NewsItem = Readonly<{
  id: string;
  sourceId: string;
  headline: string;
  byline?: string;
  contentType: NewsContentType;
  publishedAt: string;
  summary: string;
  body: readonly string[];
  sport: SportId;
  league: LeagueId;
  teamIds: readonly TeamId[];
  discussionScope?: NewsDiscussionScope;
  viewType: NewsViewType;
  imageUrl?: string;
  imageAlt?: string;
  externalDestination?: string;
  viewCount: number;
  reactionCount: number;
}>;

export type NewsFeedContext =
  | Readonly<{ kind: "team"; teamId: TeamId }>
  | Readonly<{ kind: "league"; leagueId: LeagueId }>
  | Readonly<{ kind: "sport"; sportId: SportId }>
  | Readonly<{ kind: "all" }>;

export type FollowedSourcePreference = Readonly<{
  sourceId: string;
  contentTypes: readonly NewsContentType[];
  mutedUntil: string | null;
}>;
