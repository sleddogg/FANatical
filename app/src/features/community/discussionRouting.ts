import type { NewsTemporaryFilter } from "../news/types";
import type { DiscussionOrigin } from "./types";

export function discussionOriginForFilter(filter: NewsTemporaryFilter): DiscussionOrigin | null {
  return filter.kind === "all" ? null : { kind: filter.kind, targetId: filter.targetId };
}

export function communityDiscussionPath(newsItemId: string, origin: DiscussionOrigin | null) {
  const parameters = new URLSearchParams();
  if (origin) {
    parameters.set("context", origin.kind);
    parameters.set("target", origin.targetId);
  }
  const query = parameters.toString();
  return `/news/discussions/${encodeURIComponent(newsItemId)}${query ? `?${query}` : ""}`;
}

export function parseDiscussionOrigin(parameters: URLSearchParams): DiscussionOrigin | null {
  const kind = parameters.get("context");
  const targetId = parameters.get("target")?.trim();
  return targetId && (kind === "team" || kind === "competition" || kind === "sport")
    ? { kind, targetId }
    : null;
}
