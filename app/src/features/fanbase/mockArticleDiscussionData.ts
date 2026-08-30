import type {
  ArticleDiscussionItem,
  ArticleDiscussionSource,
} from "./articleDiscussionTypes";

const hoursAgo = (hours: number) => new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();

export const articleDiscussionSources = [
  {
    id: "fan-field-journal",
    name: "Fan Field Journal",
    initials: "FF",
    description: "FANbase Article Discussion context fixture.",
    category: "Media Outlet",
    accessStatus: "usable",
    contentTypes: ["Article"],
    sportTags: ["football"],
  },
  {
    id: "diamond-line",
    name: "The Diamond Line",
    initials: "DL",
    description: "FANbase Article Discussion context fixture.",
    category: "Media Outlet",
    accessStatus: "usable",
    contentTypes: ["Team Update"],
    sportTags: ["baseball"],
  },
  {
    id: "hardwood-standard",
    name: "Hardwood Standard",
    initials: "HS",
    description: "FANbase Article Discussion context fixture.",
    category: "Media Outlet",
    accessStatus: "usable",
    contentTypes: ["Article"],
    sportTags: ["basketball"],
  },
] as const satisfies readonly ArticleDiscussionSource[];

export const articleDiscussionNewsItems = [
  {
    id: "patriots-camp-tempo",
    sourceId: "fan-field-journal",
    headline: "Patriots turn up the tempo as the offense enters its final camp phase",
    byline: "Maya Bennett",
    contentType: "Article",
    publishedAt: hoursAgo(0.5),
    summary: "New England used a faster practice script while testing combinations across the offensive line.",
    sport: "football",
    league: "nfl",
    teamIds: ["new-england-patriots"],
  },
  {
    id: "red-sox-bullpen-plan",
    sourceId: "diamond-line",
    headline: "Red Sox map out a flexible bullpen plan for the coming series",
    byline: "Elena Cruz",
    contentType: "Team Update",
    publishedAt: hoursAgo(1.8),
    summary: "Boston is preparing several late-inning combinations instead of assigning one fixed path.",
    sport: "baseball",
    league: "mlb",
    teamIds: ["boston-red-sox"],
  },
  {
    id: "celtics-rotation-options",
    sourceId: "hardwood-standard",
    headline: "Celtics test two rotation ideas designed for smaller, faster lineups",
    byline: "Jordan Lee",
    contentType: "Article",
    publishedAt: hoursAgo(3.1),
    summary: "Boston is exploring lineups that preserve spacing while keeping enough size on the glass.",
    sport: "basketball",
    league: "nba",
    teamIds: ["boston-celtics"],
  },
] as const satisfies readonly ArticleDiscussionItem[];

export function getArticleDiscussionSource(item: ArticleDiscussionItem) {
  return articleDiscussionSources.find((source) => source.id === item.sourceId);
}

export function formatArticleDiscussionPublishedAt(publishedAt: string) {
  return new Intl.DateTimeFormat("en", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(new Date(publishedAt));
}
