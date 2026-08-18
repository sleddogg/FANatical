import { useEffect, useState } from "react";
import { getThreadCommentCount } from "./FanbaseContext";
import { formatFanbaseTime, totalReactions } from "./fanbaseFormatting";
import { reactionTypes } from "./ReactionPicker";
import type { DiscussionThread, ReactionType } from "./types";
import { AppIcon } from "../../components/AppIcon";

type LockerRoomTopicCardProps = {
  readonly thread: DiscussionThread;
  readonly onReact: (reaction: ReactionType) => void;
  readonly onReport: () => void;
};

const reactionIcons: Record<ReactionType, string> = {
  Like: "👍",
  Love: "♥",
  Fire: "🔥",
  "Mind Blown": "✦",
};

export function LockerRoomTopicCard({ thread, onReact, onReport }: LockerRoomTopicCardProps) {
  const [reactionMenuOpen, setReactionMenuOpen] = useState(false);
  const [shareNotice, setShareNotice] = useState("");
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
    <article className="article-discussion-card locker-room-topic-card surface">
      <div className="article-discussion-card__content">
        <div className="locker-room-topic-card__context">
          <span className="fanbase-entry-card__glyph"><AppIcon name="chat-bubble-left-right" /></span>
          <span><strong>{thread.category ?? "Team Talk"}</strong><small>Started by @{thread.creator?.username ?? "fan"}</small></span>
        </div>
        <h2>{thread.title ?? "Locker Room topic"}</h2>
        {thread.body ? <p>{thread.body}</p> : null}
        <div className="article-discussion-card__meta">
          <span>Started {formatFanbaseTime(thread.createdAt)}</span>
          <span>{commentCount} {commentCount === 1 ? "comment" : "comments"}</span>
          <button type="button" onClick={onReport}>{thread.reported ? "Reported" : "Report"}</button>
        </div>
      </div>

      <div className="article-discussion-card__actions locker-room-topic-card__actions">
        <div className="article-reaction-selector">
          <button type="button" aria-label="Choose topic reaction" aria-expanded={reactionMenuOpen} aria-pressed={Boolean(thread.viewerReaction)} onClick={() => setReactionMenuOpen((open) => !open)}>
            <span aria-hidden="true">{thread.viewerReaction ? reactionIcons[thread.viewerReaction] : "♡"}</span>
            <small>{thread.viewerReaction ?? "React"} · {totalReactions(thread.reactions)}</small>
          </button>
          {reactionMenuOpen ? (
            <div className="article-reaction-menu" role="menu" aria-label="Choose a topic reaction">
              {reactionTypes.map((reaction) => (
                <button key={reaction} type="button" role="menuitemradio" aria-label={`${reaction}, ${thread.reactions[reaction]} reactions`} aria-checked={thread.viewerReaction === reaction} onClick={() => selectReaction(reaction)}>
                  <span aria-hidden="true">{reactionIcons[reaction]}</span><span>{reaction}</span><small>{thread.reactions[reaction]}</small>
                </button>
              ))}
            </div>
          ) : null}
        </div>
        <button type="button" onClick={() => setShareNotice("Sharing is represented as a local frontend placeholder.")}><AppIcon name="share" /><small>Share</small></button>
      </div>
      <div className="article-discussion-card__notice" role="status" aria-live="polite">{shareNotice}</div>
    </article>
  );
}
