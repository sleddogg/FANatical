import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import type { NewsItem, NewsSource } from "../news/types";
import { formatPublishedAt } from "../news/newsFiltering";
import { getThreadCommentCount } from "./FanbaseContext";
import { formatFanbaseTime, totalReactions } from "./fanbaseFormatting";
import { reactionTypes } from "./ReactionPicker";
import type { DiscussionThread, ReactionType } from "./types";
import { AppIcon } from "../../components/AppIcon";

type ArticleDiscussionCardProps = {
  readonly item: NewsItem;
  readonly source: NewsSource | undefined;
  readonly thread: DiscussionThread | undefined;
  readonly discussionPath: string;
  readonly onReact: (reaction: ReactionType) => void;
  readonly onReport: () => void;
};

const reactionIcons: Record<ReactionType, string> = {
  Like: "👍",
  Love: "♥",
  Fire: "🔥",
  "Mind Blown": "✦",
};

export function ArticleDiscussionCard({
  item,
  source,
  thread,
  discussionPath,
  onReact,
  onReport,
}: ArticleDiscussionCardProps) {
  const [reactionMenuOpen, setReactionMenuOpen] = useState(false);
  const [shareNotice, setShareNotice] = useState("");
  const reactionMenuRef = useRef<HTMLDivElement>(null);
  const commentCount = getThreadCommentCount(thread);

  useEffect(() => {
    if (!reactionMenuOpen) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") setReactionMenuOpen(false);
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [reactionMenuOpen]);

  const selectReaction = (reaction: ReactionType) => {
    onReact(reaction);
    setReactionMenuOpen(false);
  };

  return (
    <article className="article-discussion-card surface">
      <div className="article-discussion-card__content">
        <div className="article-discussion-card__source">
          <span className="news-source-avatar" aria-hidden="true">{source?.initials ?? "N"}</span>
          <span><strong>{source?.name ?? "FANatical News"}</strong><small>{item.contentType} · Connected News Item</small></span>
        </div>
        <h2>{item.headline}</h2>
        <p>{item.summary}</p>
        <div className="article-discussion-card__meta">
          <span>{item.byline ? `By ${item.byline} · ` : ""}{formatPublishedAt(item.publishedAt)}</span>
          <span>{commentCount} {commentCount === 1 ? "comment" : "comments"}</span>
          <span>{thread ? `Active ${formatFanbaseTime(thread.createdAt)}` : "New discussion"}</span>
          <button type="button" disabled={!thread} onClick={onReport}>{thread?.reported ? "Reported" : "Report"}</button>
        </div>
      </div>

      <div className="article-discussion-card__actions">
        <div className="article-reaction-selector" ref={reactionMenuRef}>
          <button
            type="button"
            aria-label={thread ? "Choose discussion reaction" : "React after the discussion starts"}
            aria-expanded={thread ? reactionMenuOpen : undefined}
            aria-pressed={Boolean(thread?.viewerReaction)}
            disabled={!thread}
            onClick={() => setReactionMenuOpen((open) => !open)}
          >
            <span aria-hidden="true">{thread?.viewerReaction ? reactionIcons[thread.viewerReaction] : "♡"}</span>
            <small>{thread?.viewerReaction ?? "React"} · {thread ? totalReactions(thread.reactions) : 0}</small>
          </button>
          {reactionMenuOpen && thread ? (
            <div className="article-reaction-menu" role="menu" aria-label="Choose a reaction">
              {reactionTypes.map((reaction) => (
                <button key={reaction} type="button" role="menuitemradio" aria-label={`${reaction}, ${thread.reactions[reaction]} reactions`} aria-checked={thread.viewerReaction === reaction} onClick={() => selectReaction(reaction)}>
                  <span aria-hidden="true">{reactionIcons[reaction]}</span><span>{reaction}</span><small>{thread.reactions[reaction]}</small>
                </button>
              ))}
            </div>
          ) : null}
        </div>
        <button type="button" onClick={() => setShareNotice("Sharing is represented as a local frontend placeholder.")}><AppIcon name="share" /><small>Share</small></button>
        <Link to={`/news?item=${item.id}`} state={{ articleDiscussionPath: discussionPath }}><AppIcon name="newspaper" /><small>View News Item</small></Link>
      </div>
      <div className="article-discussion-card__notice" role="status" aria-live="polite">{shareNotice}</div>
    </article>
  );
}
