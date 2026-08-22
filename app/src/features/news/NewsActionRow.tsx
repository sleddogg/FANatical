import { AppIcon } from "../../components/AppIcon";
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
    <div className={`news-actions news-actions--${variant}`} role="group" aria-label={`Actions for ${item.headline}`}>
      <button type="button" aria-label={reacted ? "Remove reaction" : "React"} aria-pressed={reacted} onClick={onReaction}>
        <AppIcon name={reacted ? "heart-solid" : "heart"} />
        <small>{formatCount(reactionCount)}</small>
      </button>
      <button type="button" aria-label="Open FANbase Article Discussion" onClick={onDiscussion}>
        <AppIcon name="chat-bubble-left-right" />
        <small>{formatCount(discussionCount)}</small>
      </button>
      <button type="button" aria-label="Share News item" onClick={onShare}>
        <AppIcon name="share" />
        <small>Share</small>
      </button>
      <span className="news-actions__views">
        <AppIcon name="eye" />
        <small aria-hidden="true">{formatCount(item.viewCount)}</small>
        <span className="visually-hidden">{item.viewCount} views</span>
      </span>
    </div>
  );
}
