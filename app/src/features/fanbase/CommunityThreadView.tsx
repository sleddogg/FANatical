import { useState, type FormEvent } from "react";
import { getThreadCommentCount } from "./FanbaseContext";
import { formatFanbaseTime } from "./fanbaseFormatting";
import { ReactionPicker } from "./ReactionPicker";
import type { DiscussionThread, ReactionType } from "./types";

type CommunityThreadViewProps = {
  readonly thread: DiscussionThread | undefined;
  readonly title: string;
  readonly context: string;
  readonly body?: string;
  readonly emptyMessage?: string;
  readonly locked?: boolean;
  readonly compactTopicMode?: boolean;
  readonly onSubmitComment: (body: string, parentId: string | null) => void;
  readonly onReactToThread: (reaction: ReactionType) => void;
  readonly onReactToComment: (commentId: string, reaction: ReactionType) => void;
  readonly onReportThread: () => void;
  readonly onReportComment: (commentId: string) => void;
};

export function CommunityThreadView({
  thread,
  title,
  context,
  body,
  emptyMessage = "Be the first fan to start this discussion.",
  locked = false,
  compactTopicMode = false,
  onSubmitComment,
  onReactToThread,
  onReactToComment,
  onReportThread,
  onReportComment,
}: CommunityThreadViewProps) {
  const [commentBody, setCommentBody] = useState("");
  const [replyTarget, setReplyTarget] = useState<{ id: string; username: string } | null>(null);
  const commentCount = getThreadCommentCount(thread);

  const submitComment = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!commentBody.trim() || locked) {
      return;
    }
    onSubmitComment(commentBody, replyTarget?.id ?? null);
    setCommentBody("");
    setReplyTarget(null);
  };

  const composer = locked ? (
    <div className="community-thread__locked" role="status"><strong>This Game Thread is archived.</strong><span>The 24-hour post-game window has ended. It remains available to read.</span></div>
  ) : (
    <form className="community-composer" onSubmit={submitComment}>
      <div className="community-avatar" aria-hidden="true">NF</div>
      <label>
        <span>{replyTarget ? `Replying to @${replyTarget.username}` : "Add to the conversation"}</span>
        <textarea value={commentBody} onChange={(event) => setCommentBody(event.target.value)} rows={3} required maxLength={1000} placeholder="Share your take…" />
      </label>
      {replyTarget ? <button className="fanbase-text-button" type="button" onClick={() => setReplyTarget(null)}>Cancel reply</button> : null}
      <button className="fanbase-primary-button" type="submit">Post comment</button>
    </form>
  );

  return (
    <div className={compactTopicMode ? "community-thread community-thread--compact-topic" : "community-thread"}>
      {!compactTopicMode ? (
        <article className="community-thread__lead surface">
          <span className="eyebrow">{context}</span>
          <h2>{title}</h2>
          {body ? <p>{body}</p> : null}
          <div className="community-thread__meta">
            <span>{commentCount} {commentCount === 1 ? "comment" : "comments"}</span>
            {thread?.createdAt ? <span>Active {formatFanbaseTime(thread.createdAt)}</span> : <span>New discussion</span>}
            <button type="button" onClick={onReportThread}>{thread?.reported ? "Reported" : "Report"}</button>
          </div>
          {thread ? <ReactionPicker reactions={thread.reactions} viewerReaction={thread.viewerReaction} onReact={onReactToThread} /> : null}
        </article>
      ) : null}

      <section className="community-comments" aria-labelledby="community-comments-title">
        {compactTopicMode ? composer : null}
        <div className="community-comments__heading">
          <h3 id="community-comments-title">Conversation</h3>
          <span>{thread?.comments.length ?? 0} recent shown</span>
        </div>

        {thread?.comments.length ? thread.comments.map((comment) => (
          <article className={comment.parentId ? "community-comment community-comment--reply" : "community-comment"} key={comment.id}>
            <span className="community-avatar" aria-hidden="true">{comment.author.initials}</span>
            <div className="community-comment__body">
              <div className="community-comment__author"><strong>@{comment.author.username}</strong><small>{formatFanbaseTime(comment.createdAt)}</small></div>
              <p>{comment.body}</p>
              <div className="community-comment__controls">
                <ReactionPicker compact reactions={comment.reactions} viewerReaction={comment.viewerReaction} onReact={(reaction) => onReactToComment(comment.id, reaction)} />
                {!locked ? <button type="button" onClick={() => setReplyTarget({ id: comment.id, username: comment.author.username })}>Reply</button> : null}
                <button type="button" onClick={() => onReportComment(comment.id)}>{comment.reported ? "Reported" : "Report"}</button>
              </div>
            </div>
          </article>
        )) : (
          <div className="community-comments__empty"><span aria-hidden="true">◌</span><p>{emptyMessage}</p></div>
        )}

        {!compactTopicMode ? composer : null}
      </section>
    </div>
  );
}
