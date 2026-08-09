import { findFollowedTeam } from "../../data/followedTeams";
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

export function getFeedContextLabel(context: NewsFeedContext) {
  switch (context.kind) {
    case "team":
      return `Latest from ${findFollowedTeam(context.teamId)?.name ?? "your selected team"}`;
    case "league":
      return `Latest from ${leagueOptions.find((league) => league.id === context.leagueId)?.label ?? "this league"}`;
    case "sport":
      return `Latest across ${sportOptions.find((sport) => sport.id === context.sportId)?.label ?? "this sport"}`;
    case "all":
      return "All followed News · newest first";
  }
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
