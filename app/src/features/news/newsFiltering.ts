import { findFollowedTeam } from "../../data/followedTeams";
import type { FollowedTeam } from "../../domain/team";
import { leagueOptions, sportOptions } from "./mockNewsData";
import type {
  FollowedSourcePreference,
  NewsFeedContext,
  NewsItem,
  NewsSource,
} from "./types";

export function filterNewsItems(
  newsItems: readonly NewsItem[],
  context: NewsFeedContext,
  sourcePreferences: readonly FollowedSourcePreference[],
  currentTime = Date.now(),
) {
  const activeSources = new Map(
    sourcePreferences
      .filter((preference) => !preference.mutedUntil || Date.parse(preference.mutedUntil) <= currentTime)
      .map((preference) => [preference.sourceId, new Set(preference.contentTypes)]),
  );

  return [...newsItems]
    .filter((item) => activeSources.get(item.sourceId)?.has(item.contentType))
    .filter((item) => {
      switch (context.kind) {
        case "team":
          return item.teamIds.includes(context.teamId);
        case "league":
          return item.league === context.leagueId;
        case "sport":
          return item.sport === context.sportId;
        case "all":
          return true;
      }
    })
    .sort((first, second) => Date.parse(second.publishedAt) - Date.parse(first.publishedAt));
}

export function getFeedContextLabel(context: NewsFeedContext, teams?: readonly FollowedTeam[]) {
  const contextName = getFeedContextName(context, teams);
  if (context.kind === "league") {
    return `Latest from the ${contextName}`;
  }
  if (context.kind === "all") {
    return "Latest from All Followed Sources";
  }
  return `Latest from ${contextName}`;
}

export function getFeedContextName(context: NewsFeedContext, teams?: readonly FollowedTeam[]) {
  switch (context.kind) {
    case "team":
      return teams?.find((team) => team.id === context.teamId)?.name ?? findFollowedTeam(context.teamId)?.name ?? context.teamId;
    case "league":
      return leagueOptions.find((league) => league.id === context.leagueId)?.label ?? context.leagueId.toUpperCase();
    case "sport":
      return sportOptions.find((sport) => sport.id === context.sportId)?.label ?? context.sportId;
    case "all":
      return "All";
  }
}

function teamMatchesFeedContext(team: FollowedTeam, context: NewsFeedContext) {
  if (context.kind === "team") return team.id === context.teamId;
  if (context.kind === "league") return team.league.toLowerCase() === context.leagueId;
  if (context.kind === "sport") return team.sport.toLowerCase() === context.sportId;
  return true;
}

export function findThemeTeamForNewsContext(
  context: NewsFeedContext,
  currentTeam: FollowedTeam,
  followedTeams: readonly FollowedTeam[],
) {
  if (context.kind === "all") return currentTeam;
  if (teamMatchesFeedContext(currentTeam, context)) return currentTeam;
  return followedTeams.find((team) => teamMatchesFeedContext(team, context));
}

export function getSourceForItem(item: NewsItem, sourceCatalog: readonly NewsSource[]) {
  return sourceCatalog.find((source) => source.id === item.sourceId);
}

export function formatPublishedAt(publishedAt: string, currentTime = Date.now()) {
  const differenceInMinutes = Math.max(0, Math.round((currentTime - Date.parse(publishedAt)) / 60_000));

  if (differenceInMinutes < 60) {
    return differenceInMinutes <= 1 ? "Just now" : `${differenceInMinutes} min ago`;
  }

  const differenceInHours = Math.floor(differenceInMinutes / 60);
  if (differenceInHours < 24) {
    return `${differenceInHours} hr${differenceInHours === 1 ? "" : "s"} ago`;
  }

  return new Intl.DateTimeFormat("en", { month: "short", day: "numeric" }).format(new Date(publishedAt));
}

export function formatCount(count: number) {
  if (count < 1_000) {
    return String(count);
  }

  const compactCount = count / 1_000;
  return `${compactCount >= 10 ? Math.round(compactCount) : compactCount.toFixed(1)}k`;
}
