import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { AppIcon } from "../../components/AppIcon";
import { communityDiscussionPath } from "../community/discussionRouting";
import { loadDiscussionTeaser } from "../community/communityRepository";
import type { CommunityDiscussionTeaser, DiscussionOrigin } from "../community/types";

export function NewsDiscussionAction({
  newsItemId,
  headline,
  origin,
}: {
  readonly newsItemId: string;
  readonly headline: string;
  readonly origin: DiscussionOrigin | null;
}) {
  const originKind = origin?.kind ?? null;
  const originTargetId = origin?.targetId ?? null;
  const requestKey = `${newsItemId}:${originKind ?? "direct"}:${originTargetId ?? ""}`;
  const [teaserState, setTeaserState] = useState<{
    key: string;
    value: CommunityDiscussionTeaser;
  } | null>(null);
  const teaser = teaserState?.key === requestKey ? teaserState.value : null;

  useEffect(() => {
    let current = true;
    const requestOrigin = originKind && originTargetId
      ? { kind: originKind, targetId: originTargetId } as const
      : null;
    void loadDiscussionTeaser(newsItemId, requestOrigin).then((next) => {
      if (current) setTeaserState({ key: requestKey, value: next });
    }).catch(() => {
      if (current) setTeaserState({ key: requestKey, value: {
        available: false,
        requiresAuth: false,
        viewerCanAccess: null,
        newsItemId: null,
        contextKind: null,
        contextDisplayKind: null,
        contextId: null,
        contextName: null,
        discussionId: null,
        commentCount: 0,
        article: null,
      } });
    });
    return () => { current = false; };
  }, [newsItemId, originKind, originTargetId, requestKey]);

  if (!teaser?.available) {
    return teaser ? (
      <span className="news-discussion-unavailable" aria-label={`Discussion unavailable for ${headline}`}>
        <AppIcon name="chat-bubble-left-right" /><small>Unavailable</small>
      </span>
    ) : (
      <span className="news-discussion-unavailable" aria-label={`Loading Discussion for ${headline}`}>
        <AppIcon name="chat-bubble-left-right" /><small>…</small>
      </span>
    );
  }

  return (
    <Link
      to={communityDiscussionPath(newsItemId, origin)}
      aria-label={`Open ${teaser.contextName ?? "News"} Discussion for ${headline}. ${teaser.commentCount} comments.`}
    >
      <AppIcon name="chat-bubble-left-right" />
      <small>Discussion {teaser.commentCount}</small>
    </Link>
  );
}
