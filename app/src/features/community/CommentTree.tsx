import { useMemo, useState, type CSSProperties } from "react";
import { Link } from "react-router-dom";
import { AppIcon } from "../../components/AppIcon";
import { CommunityAvatar } from "./CommunityAvatar";
import type { CommunityComment } from "./types";

export type CommunityCommentNode = Readonly<{
  comment: CommunityComment;
  children: readonly CommunityCommentNode[];
}>;

const replyBranchColors = ["#b43a3a", "#2563a8", "#2f7d4d", "#8a4ca3", "#a96213"] as const;

function visualIndentLevel(logicalDepth: number) {
  if (logicalDepth <= 0) return 0;
  const phase = (logicalDepth - 1) % 4;
  return 1 + (phase <= 2 ? phase : 4 - phase);
}

export function buildCommunityCommentTree(comments: readonly CommunityComment[]) {
  const nodes = new Map(comments.map((comment) => [comment.id, { comment, children: [] as CommunityCommentNode[] }]));
  const roots: CommunityCommentNode[] = [];
  for (const comment of comments) {
    const node = nodes.get(comment.id)!;
    const parent = comment.parentId ? nodes.get(comment.parentId) : null;
    if (parent) parent.children.push(node);
    else roots.push(node);
  }
  return roots;
}

function formatCommentTime(value: string) {
  return new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
}

function CommentNode({
  node,
  depth,
  branchIndex,
  lineage,
  busy,
  onReply,
  onEdit,
  onDelete,
  onHide,
  onUnhide,
  onReport,
}: {
  readonly node: CommunityCommentNode;
  readonly depth: number;
  readonly branchIndex: number | null;
  readonly lineage: readonly string[];
  readonly busy: boolean;
  readonly onReply: (comment: CommunityComment) => void;
  readonly onEdit: (comment: CommunityComment) => void;
  readonly onDelete: (comment: CommunityComment) => void;
  readonly onHide: (comment: CommunityComment) => void;
  readonly onUnhide: (comment: CommunityComment) => void;
  readonly onReport: (comment: CommunityComment) => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const comment = node.comment;
  const author = comment.authorHidden || comment.status === "unavailable"
    ? "Hidden fan"
    : comment.fanaticalName ?? "Unavailable author";
  const nextLineage = [...lineage, author];
  const visualDepth = visualIndentLevel(depth);
  const parentVisualDepth = depth ? visualIndentLevel(depth - 1) : 0;
  const visualOffset = visualDepth - parentVisualDepth;
  const parentAuthor = lineage.at(-1);
  const branchColor = branchIndex === null
    ? "var(--team-color-primary, #00205b)"
    : replyBranchColors[branchIndex % replyBranchColors.length];
  return (
    <li
      className="community-comment"
      data-branch-index={branchIndex ?? "root"}
      data-visual-indent={visualDepth}
      data-visual-offset={visualOffset}
      style={{
        "--community-branch-color": branchColor,
        "--community-depth": visualDepth,
      } as CSSProperties}
    >
      <article aria-label={depth ? `Reply in thread: ${nextLineage.join(" then ")}` : `Comment by ${author}`}>
        <header>
          <CommunityAvatar avatar={comment.avatar} fanaticalName={comment.fanaticalName} />
          <div>
            {comment.fanaticalName ? <Link to={`/fans/${encodeURIComponent(comment.fanaticalName)}`}>{comment.fanaticalName}</Link> : <strong>{author}</strong>}
            <small><time dateTime={comment.createdAt}>{formatCommentTime(comment.createdAt)}</time>{comment.edited ? " · Edited" : ""}</small>
          </div>
        </header>
        {visualOffset < 0 && parentAuthor ? <p className="community-comment__reply-cue">Replying to {parentAuthor}</p> : null}
        <p className={`community-comment__body community-comment__body--${comment.status}`}>{comment.body}</p>
        {comment.status === "active" || comment.canHide || comment.canUnhide ? (
          <div className="community-comment__actions">
            {comment.canReply ? <button type="button" disabled={busy} onClick={() => onReply(comment)}>Reply</button> : null}
            {comment.canEdit ? <button type="button" disabled={busy} onClick={() => onEdit(comment)}>Edit</button> : null}
            {comment.canDelete ? <button type="button" disabled={busy} onClick={() => onDelete(comment)}>Delete</button> : null}
            {comment.canHide ? <button type="button" disabled={busy} onClick={() => onHide(comment)}>Hide user</button> : null}
            {comment.canUnhide ? <button type="button" disabled={busy} onClick={() => onUnhide(comment)}>Unhide user</button> : null}
            {comment.canReport ? <button type="button" disabled={busy} onClick={() => onReport(comment)}>Report</button> : null}
            {comment.viewerHasReported ? <span className="community-comment__reported">Reported</span> : null}
          </div>
        ) : null}
      </article>
      {node.children.length ? (
        <div className="community-comment__branch">
          <button
            className="community-comment__branch-toggle"
            type="button"
            aria-expanded={expanded}
            onClick={() => setExpanded((current) => !current)}
          >
            <AppIcon name={expanded ? "chevron-down" : "chevron-right"} />
            {expanded ? "Collapse" : "Show"} {comment.replyCount} {comment.replyCount === 1 ? "reply" : "replies"}
          </button>
          {expanded ? (
            <ol>
              {node.children.map((child, childIndex) => (
                <CommentNode
                  key={child.comment.id}
                  node={child}
                  depth={depth + 1}
                  branchIndex={depth === 0 ? childIndex : branchIndex}
                  lineage={nextLineage}
                  busy={busy}
                  onReply={onReply}
                  onEdit={onEdit}
                  onDelete={onDelete}
                  onHide={onHide}
                  onUnhide={onUnhide}
                  onReport={onReport}
                />
              ))}
            </ol>
          ) : null}
        </div>
      ) : null}
    </li>
  );
}

export function CommentTree({
  comments,
  busy,
  onReply,
  onEdit,
  onDelete,
  onHide,
  onUnhide,
  onReport,
}: {
  readonly comments: readonly CommunityComment[];
  readonly busy: boolean;
  readonly onReply: (comment: CommunityComment) => void;
  readonly onEdit: (comment: CommunityComment) => void;
  readonly onDelete: (comment: CommunityComment) => void;
  readonly onHide: (comment: CommunityComment) => void;
  readonly onUnhide: (comment: CommunityComment) => void;
  readonly onReport: (comment: CommunityComment) => void;
}) {
  const roots = useMemo(() => buildCommunityCommentTree(comments), [comments]);
  return (
    <ol className="community-comment-tree" aria-label="Discussion comments">
      {roots.map((node) => (
        <CommentNode
          key={node.comment.id}
          node={node}
          depth={0}
          branchIndex={null}
          lineage={[]}
          busy={busy}
          onReply={onReply}
          onEdit={onEdit}
          onDelete={onDelete}
          onHide={onHide}
          onUnhide={onUnhide}
          onReport={onReport}
        />
      ))}
    </ol>
  );
}
