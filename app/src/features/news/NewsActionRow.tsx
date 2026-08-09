import { formatCount } from "./newsFiltering";
import type { NewsItem } from "./types";

type NewsActionRowProps = {
  readonly item: NewsItem;
  readonly discussionCount: number;
  readonly reacted: boolean;
  readonly variant: "card" | "detail";
  readonly onReaction: () => void;
  readonly onDiscussion: () => void;
  readonly onShare: () => void;
};

export function NewsActionRow({
  item,
  discussionCount,
  reacted,
  variant,
  onReaction,
  onDiscussion,
  onShare,
}: NewsActionRowProps) {
  const reactionCount = item.reactionCount + (reacted ? 1 : 0);

  return (
    <div className={`news-actions news-actions--${variant}`} aria-label={`Actions for ${item.headline}`}>
      <button type="button" aria-label={reacted ? "Remove reaction" : "React"} aria-pressed={reacted} onClick={onReaction}>
        <span aria-hidden="true">{reacted ? "♥" : "♡"}</span>
        <small>{formatCount(reactionCount)}</small>
      </button>
      <button type="button" aria-label="Open FANbase discussion" onClick={onDiscussion}>
        <span aria-hidden="true">◯</span>
        <small>{formatCount(discussionCount)}</small>
      </button>
      <button type="button" aria-label="Share News item" onClick={onShare}>
        <span aria-hidden="true">↗</span>
        <small>Share</small>
      </button>
      <span className="news-actions__views" aria-label={`${item.viewCount} views`}>
        <span aria-hidden="true">◉</span>
        <small>{formatCount(item.viewCount)}</small>
      </span>
    </div>
  );
}
