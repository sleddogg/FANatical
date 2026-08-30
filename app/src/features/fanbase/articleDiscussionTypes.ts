import type { TeamId } from "../../domain/team";

export type ArticleDiscussionSportId = "football" | "baseball" | "basketball";
export type ArticleDiscussionLeagueId =
  | "nfl"
  | "cfl"
  | "ufl"
  | "mlb"
  | "milb"
  | "nba"
  | "wnba";

export type ArticleDiscussionContentType =
  | "Article"
  | "News"
  | "Blog"
  | "Video"
  | "Podcast"
  | "Team Update"
  | "League Update";

export type ArticleDiscussionScope =
  | Readonly<{ kind: "team"; teamId: TeamId }>
  | Readonly<{ kind: "league"; leagueId: ArticleDiscussionLeagueId }>
  | Readonly<{ kind: "sport"; sportId: ArticleDiscussionSportId }>;

export type ArticleDiscussionSource = Readonly<{
  id: string;
  name: string;
  initials: string;
  description: string;
  category: "Media Outlet" | "Creator" | "Blogger" | "Podcast" | "Show";
  accessStatus: "usable" | "partial" | "restricted" | "unavailable";
  contentTypes: readonly ArticleDiscussionContentType[];
  sportTags: readonly ArticleDiscussionSportId[];
}>;

export type ArticleDiscussionItem = Readonly<{
  id: string;
  sourceId: string;
  headline: string;
  byline?: string;
  contentType: ArticleDiscussionContentType;
  publishedAt: string;
  summary: string;
  sport: ArticleDiscussionSportId;
  league: ArticleDiscussionLeagueId;
  teamIds: readonly TeamId[];
  discussionScope?: ArticleDiscussionScope;
}>;
