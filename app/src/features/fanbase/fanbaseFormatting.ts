import type { ReactionSummary } from "./types";

export function formatFanbaseTime(value: string) {
  const difference = Date.now() - Date.parse(value);
  const minutes = Math.max(0, Math.floor(difference / 60_000));
  if (minutes < 60) {
    return minutes < 1 ? "Just now" : `${minutes}m ago`;
  }
  const hours = Math.floor(minutes / 60);
  if (hours < 24) {
    return `${hours}h ago`;
  }
  return new Intl.DateTimeFormat("en", { month: "short", day: "numeric" }).format(new Date(value));
}

export function formatEventDate(value: string) {
  return new Intl.DateTimeFormat("en", {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(value));
}

export function totalReactions(reactions: ReactionSummary) {
  return Object.values(reactions).reduce((total, count) => total + count, 0);
}

export function formatRating(total: number, count: number) {
  return count ? (total / count).toFixed(1) : "New";
}
