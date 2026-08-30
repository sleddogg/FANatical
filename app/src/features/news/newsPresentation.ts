import type { NewsIdentityTargetType } from "./types";

export function newsIdentityProfilePath(targetType: NewsIdentityTargetType, targetId: string) {
  const segment = targetType === "author"
    ? "authors"
    : targetType === "organization"
      ? "organizations"
      : "shows";
  return `/news/${segment}/${encodeURIComponent(targetId)}`;
}

export function formatFanSafeNewsPublishedAt(publishedAt: string, serverTime: string) {
  const published = Date.parse(publishedAt);
  const server = Date.parse(serverTime);
  if (Number.isFinite(published) && Number.isFinite(server)) {
    const minutes = Math.max(0, Math.floor((server - published) / 60_000));
    if (minutes < 60) return minutes <= 1 ? "Just now" : `${minutes} min ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours} hr${hours === 1 ? "" : "s"} ago`;
  }
  return new Intl.DateTimeFormat("en", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(new Date(publishedAt));
}
