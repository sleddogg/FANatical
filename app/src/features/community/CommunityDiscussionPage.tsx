import { useCallback, useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { Link, useNavigate, useParams, useSearchParams } from "react-router-dom";
import { AppIcon } from "../../components/AppIcon";
import { useAuth } from "../account/AuthContext";
import { useProfileAvatar } from "../profileAvatar/ProfileAvatarContext";
import { ProfileAvatarMedia } from "../profileAvatar/ProfileAvatarMedia";
import type { ProfileAvatarRecord } from "../profileAvatar/types";
import { recordNewsOutboundOpen } from "../news/newsRepository";
import { trapDialogFocus } from "../news/dialogKeyboard";
import { CommentTree } from "./CommentTree";
import { FanaticalNameForm } from "./FanaticalNameForm";
import {
  deleteCommunityComment,
  editCommunityComment,
  hideCommunityCommentAuthor,
  loadCommunityDiscussion,
  loadDiscussionTeaser,
  loadMyFanaticalName,
  postCommunityComment,
  postExistingCommunityComment,
  replyToCommunityComment,
  reportCommunityComment,
  unhideCommunityIntent,
} from "./communityRepository";
import { parseDiscussionOrigin } from "./discussionRouting";
import type { CommunityArticleReference, CommunityComment, CommunityDiscussion, CommunityDiscussionTeaser } from "./types";
import "./community.css";

type ComposerTarget = Readonly<{ mode: "new" }> | Readonly<{ mode: "reply" | "edit"; comment: CommunityComment }>;
type ReportTarget = Readonly<{ comment: CommunityComment; reason: "spam" | "harassment" | "hate" | "threats"; explanation: string }>;

function CommentComposer({
  target,
  busy,
  fanaticalName,
  avatar,
  onCancel,
  onSubmit,
}: {
  readonly target: ComposerTarget;
  readonly busy: boolean;
  readonly fanaticalName: string;
  readonly avatar: ProfileAvatarRecord | null;
  readonly onCancel?: () => void;
  readonly onSubmit: (body: string) => Promise<void>;
}) {
  const [body, setBody] = useState(target.mode === "edit" ? target.comment.body : "");
  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!body.trim()) return;
    await onSubmit(body.trim());
    setBody("");
  };
  const label = target.mode === "new" ? "Add a comment" : target.mode === "reply" ? `Reply to ${target.comment.fanaticalName}` : "Edit comment";
  return (
    <form className="community-composer" onSubmit={(event) => void submit(event)}>
      <div className="community-composer__identity"><ProfileAvatarMedia avatar={avatar} /><strong>{fanaticalName}</strong></div>
      <label>{label}<textarea rows={target.mode === "new" ? 4 : 3} value={body} disabled={busy} onChange={(event) => setBody(event.target.value)} /></label>
      <div>{onCancel ? <button type="button" disabled={busy} onClick={onCancel}>Cancel</button> : null}<button type="submit" disabled={busy || !body.trim()}>{busy ? "Saving…" : target.mode === "edit" ? "Save edit" : "Post"}</button></div>
    </form>
  );
}

export function ArticleReferenceCard({ article }: { readonly article: CommunityArticleReference }) {
  const byline = article.bylines.join(", ");
  const details = [
    article.itemKind === "podcast_episode" ? "Podcast episode" : "Article",
    new Date(article.publishedAt).toLocaleString(),
  ];
  return (
    <article className="community-article-reference">
      {article.preview?.kind === "image" ? <img src={article.preview.url} alt={article.preview.alt} referrerPolicy="no-referrer" /> : null}
      <div>
        <p className="eyebrow">{article.publisherName}{article.showName ? ` · ${article.showName}` : ""}</p>
        <h2>{article.headline}</h2>
        {byline ? <p className="community-article-reference__byline">By {byline}</p> : null}
        <p className="community-article-reference__details">{details.join(" · ")}</p>
      </div>
      <a href={article.destinationUrl} target="_blank" rel="noreferrer" onClick={() => {
        void recordNewsOutboundOpen(article.newsItemId, article.destinationUrl).catch((reason: unknown) => {
          console.warn("FANatical could not record a News outbound open.", reason);
        });
      }}>Open <span className="visually-hidden">{article.headline}</span></a>
    </article>
  );
}

export function CommunitySuspensionNotice({ suspendedUntil }: { readonly suspendedUntil: string }) {
  return (
    <p className="community-restriction" role="status">
      Community participation is suspended until {new Date(suspendedUntil).toLocaleString()}. You may continue reading Community content, but cannot post, reply, edit, or delete comments while suspended.
    </p>
  );
}

function DiscussionScreen({
  newsItemId,
  directDiscussionId,
}: {
  readonly newsItemId?: string;
  readonly directDiscussionId?: string;
}) {
  const { configured, loading: authLoading, user } = useAuth();
  const { avatar } = useProfileAvatar();
  const navigate = useNavigate();
  const [searchParameters] = useSearchParams();
  const origin = useMemo(() => parseDiscussionOrigin(searchParameters), [searchParameters]);
  const userId = user?.id;
  const [teaser, setTeaser] = useState<CommunityDiscussionTeaser | null>(null);
  const [discussion, setDiscussion] = useState<CommunityDiscussion | null>(null);
  const [fanaticalName, setFanaticalName] = useState("");
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [composerTarget, setComposerTarget] = useState<ComposerTarget | null>(null);
  const [reportTarget, setReportTarget] = useState<ReportTarget | null>(null);
  const [accessDenied, setAccessDenied] = useState(false);
  const refreshEpoch = useRef(0);
  const reportDialogRef = useRef<HTMLFormElement>(null);
  const reportFirstControlRef = useRef<HTMLSelectElement>(null);
  const reportReturnFocusRef = useRef<HTMLElement | null>(null);
  const reportOpen = Boolean(reportTarget);

  const refresh = useCallback(async (knownDiscussionId?: string) => {
    if (!configured || authLoading) return;
    const epoch = ++refreshEpoch.current;
    setLoading(true);
    setError("");
    setAccessDenied(false);
    setDiscussion(null);
    try {
      let nextTeaser: CommunityDiscussionTeaser | null = null;
      let discussionId = knownDiscussionId ?? directDiscussionId ?? null;
      if (newsItemId) {
        nextTeaser = await loadDiscussionTeaser(newsItemId, origin);
        discussionId = discussionId ?? nextTeaser.discussionId;
      }
      let nextName = "";
      let nextDiscussion: CommunityDiscussion | null = null;
      const nextAccessDenied = nextTeaser?.viewerCanAccess === false;
      if (userId) {
        [nextName, nextDiscussion] = await Promise.all([
          loadMyFanaticalName(),
          discussionId && !nextAccessDenied
            ? loadCommunityDiscussion(discussionId)
            : Promise.resolve(null),
        ]);
      }
      if (epoch !== refreshEpoch.current) return;
      setTeaser(nextTeaser);
      setFanaticalName(nextName);
      setDiscussion(nextDiscussion);
      setAccessDenied(nextAccessDenied);
      setComposerTarget((current) => {
        if (!current) return null;
        if (current.mode === "new") {
          return nextDiscussion && nextDiscussion.contextIsCurrent !== false && !nextDiscussion.postingRestrictedUntil
            ? current
            : null;
        }
        const nextComment = nextDiscussion?.comments.find((comment) => comment.id === current.comment.id);
        const stillAllowed = current.mode === "reply" ? nextComment?.canReply : nextComment?.canEdit;
        return nextComment && stillAllowed ? { ...current, comment: nextComment } : null;
      });
      setReportTarget((current) => {
        if (!current) return null;
        const nextComment = nextDiscussion?.comments.find((comment) => comment.id === current.comment.id);
        return nextComment?.canReport ? { ...current, comment: nextComment } : null;
      });
    } catch (reason) {
      if (epoch !== refreshEpoch.current) return;
      setDiscussion(null);
      setAccessDenied(Boolean(userId));
      setComposerTarget(null);
      setReportTarget(null);
      setError(reason instanceof Error ? reason.message : "Discussion could not be loaded.");
    } finally {
      if (epoch === refreshEpoch.current) setLoading(false);
    }
  }, [authLoading, configured, directDiscussionId, newsItemId, origin, userId]);

  useEffect(() => {
    void Promise.resolve().then(() => refresh());
    const handleFocus = () => { void refresh(); };
    const handleVisibility = () => { if (document.visibilityState === "visible") void refresh(); };
    window.addEventListener("focus", handleFocus);
    document.addEventListener("visibilitychange", handleVisibility);
    return () => {
      window.removeEventListener("focus", handleFocus);
      document.removeEventListener("visibilitychange", handleVisibility);
      refreshEpoch.current += 1;
    };
  }, [refresh]);

  useEffect(() => {
    if (!reportOpen) return undefined;
    const previousOverflow = document.body.style.overflow;
    const returnFocus = reportReturnFocusRef.current;
    document.body.style.overflow = "hidden";
    reportFirstControlRef.current?.focus();
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") setReportTarget(null);
      else trapDialogFocus(event, reportDialogRef.current);
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = previousOverflow;
      window.requestAnimationFrame(() => returnFocus?.focus());
    };
  }, [reportOpen]);

  const run = async (action: () => Promise<void>, success: string) => {
    setBusy(true);
    setError("");
    setMessage("");
    try {
      await action();
      setComposerTarget(null);
      setReportTarget(null);
      setMessage(success);
      await refresh();
    } catch (reason) {
      const actionError = reason instanceof Error ? reason.message : "Community change could not be saved.";
      await refresh();
      setError(actionError);
    } finally {
      setBusy(false);
    }
  };

  const submitComposer = async (body: string) => {
    const target = composerTarget ?? { mode: "new" as const };
    if (target.mode === "reply" && discussion) {
      await run(() => replyToCommunityComment(discussion.id, target.comment.id, body), "Reply posted.");
    } else if (target.mode === "edit") {
      await run(() => editCommunityComment(target.comment.id, body), "Comment edited.");
    } else {
      if (discussion) {
        await run(
          () => postExistingCommunityComment(discussion.id, body).then(() => undefined),
          "Comment posted.",
        );
        return;
      }
      if (!newsItemId || !teaser?.contextKind || !teaser.contextId) throw new Error("This discussion context is unavailable.");
      setBusy(true);
      setError("");
      try {
        const created = await postCommunityComment(newsItemId, teaser.contextKind, teaser.contextId, body);
        setMessage("Comment posted.");
        await refresh(created.discussionId);
      } catch (reason) {
        const actionError = reason instanceof Error ? reason.message : "Comment could not be posted.";
        await refresh();
        setError(actionError);
      } finally {
        setBusy(false);
      }
    }
  };

  if (!configured) return <section className="community-page"><p className="community-error" role="alert">Community is unavailable because the FANatical data service is not configured.</p></section>;
  if (authLoading || loading) return <section className="community-page" aria-busy="true"><p role="status">Loading Discussion…</p></section>;

  const available = directDiscussionId ? Boolean(userId ? discussion : directDiscussionId) : teaser?.available === true;
  const count = discussion?.commentCount ?? teaser?.commentCount ?? 0;
  const contextName = discussion?.contextName ?? teaser?.contextName ?? "News";
  const article = discussion?.article ?? teaser?.article ?? null;

  return (
    <section className="community-page">
      <header className="community-page__header">
        <button type="button" aria-label="Back" onClick={() => navigate(-1)}><AppIcon name="arrow-left" /></button>
        <div><span className="eyebrow">{discussion?.contextDisplayKind ?? teaser?.contextDisplayKind ?? "News"} discussion</span><h1>{contextName}</h1><p>{count} {count === 1 ? "comment" : "comments"}</p></div>
      </header>
      {article ? <ArticleReferenceCard article={article} /> : null}
      {error ? <p className="community-error" role="alert">{error}</p> : null}
      {message ? <p className="community-message" role="status">{message}</p> : null}
      {!available ? <div className="community-empty surface"><h2>Discussion unavailable</h2><p>This Item has no single valid Competition or Sport discussion context.</p></div> : null}
      {available && !user ? (
        <div className="community-auth-gate surface">
          <h2>{count ? `${count} ${count === 1 ? "comment" : "comments"}` : "Start this discussion"}</h2>
          <p>Sign in to read comments and participate. Comment bodies are not available anonymously.</p>
          <Link to="/profile">Sign in</Link>
        </div>
      ) : null}
      {available && user && accessDenied ? (
        <div className="community-auth-gate surface">
          <h2>Discussion access unavailable</h2>
          <p>{teaser?.contextKind === "team" ? "Follow this Team to access its FANbase discussion." : "This discussion is not available to this account."}</p>
        </div>
      ) : null}
      {available && user && !accessDenied && discussion?.contextIsCurrent !== false && !fanaticalName ? (
        <div className="community-name-gate surface">
          <h2>Claim a Fanatical Name to participate</h2>
          <p>You can read now. A Fanatical Name is required before posting or replying.</p>
          <FanaticalNameForm onSaved={async (name) => { setFanaticalName(name); await refresh(); }} />
        </div>
      ) : null}
      {available && user && !accessDenied ? (
        <>
          {discussion?.contextIsCurrent === false ? <p className="community-restriction" role="status">New comments and replies are closed because this News classification is no longer current. Existing interaction remains preserved.</p> : null}
          {discussion?.postingRestrictedUntil ? <CommunitySuspensionNotice suspendedUntil={discussion.postingRestrictedUntil} /> : null}
          {fanaticalName && discussion?.contextIsCurrent !== false && !discussion?.postingRestrictedUntil && !composerTarget ? <CommentComposer target={{ mode: "new" }} busy={busy} fanaticalName={fanaticalName} avatar={avatar} onSubmit={submitComposer} /> : null}
          {discussion?.comments.length ? (
            <CommentTree
              comments={discussion.comments}
              busy={busy}
              onReply={(comment) => setComposerTarget({ mode: "reply", comment })}
              onEdit={(comment) => setComposerTarget({ mode: "edit", comment })}
              onDelete={(comment) => {
                if (window.confirm("Delete this comment permanently? This cannot be undone. Existing replies will remain.")) {
                  void run(() => deleteCommunityComment(comment.id), "Comment deleted.");
                }
              }}
              onHide={(comment) => void run(() => hideCommunityCommentAuthor(comment.id), `${comment.fanaticalName ?? "Fan"} hidden.`)}
              onUnhide={(comment) => comment.myHideIntentId && void run(() => unhideCommunityIntent(comment.myHideIntentId!), "Hide intent removed.")}
              onReport={(comment) => {
                reportReturnFocusRef.current = document.activeElement instanceof HTMLElement
                  ? document.activeElement
                  : null;
                setReportTarget({ comment, reason: "spam", explanation: "" });
              }}
            />
          ) : <div className="community-empty"><h2>No comments yet</h2><p>Be the first fan to start this contextual discussion.</p></div>}
          {composerTarget ? <CommentComposer key={composerTarget.mode === "new" ? "new" : `${composerTarget.mode}-${composerTarget.comment.id}`} target={composerTarget} busy={busy} fanaticalName={fanaticalName} avatar={avatar} onCancel={() => setComposerTarget(null)} onSubmit={submitComposer} /> : null}
        </>
      ) : null}
      {reportTarget ? (
        <div className="community-dialog-layer">
          <button className="community-dialog-backdrop" type="button" aria-label="Close report" onClick={() => setReportTarget(null)} />
          <form ref={reportDialogRef} className="community-dialog" role="dialog" aria-modal="true" aria-labelledby="community-report-title" tabIndex={-1} onSubmit={(event) => { event.preventDefault(); void run(() => reportCommunityComment(reportTarget.comment.id, reportTarget.reason, reportTarget.explanation), "Report submitted. Hiding is a separate choice."); }}>
            <h2 id="community-report-title">Report comment</h2>
            <label>Reason<select ref={reportFirstControlRef} value={reportTarget.reason} onChange={(event) => setReportTarget({ ...reportTarget, reason: event.target.value as ReportTarget["reason"] })}><option value="spam">Spam</option><option value="harassment">Harassment</option><option value="hate">Hate</option><option value="threats">Threats</option></select></label>
            <label>Optional explanation<textarea rows={4} value={reportTarget.explanation} onChange={(event) => setReportTarget({ ...reportTarget, explanation: event.target.value })} /></label>
            <div><button type="button" onClick={() => setReportTarget(null)}>Cancel</button><button type="submit" disabled={busy}>Submit report</button></div>
          </form>
        </div>
      ) : null}
    </section>
  );
}

export function CommunityDiscussionPage() {
  const { newsItemId = "" } = useParams();
  const { user } = useAuth();
  const [searchParameters] = useSearchParams();
  const origin = parseDiscussionOrigin(searchParameters);
  const routeKey = `${user?.id ?? "signed-out"}:${newsItemId}:${origin?.kind ?? "direct"}:${origin?.targetId ?? ""}`;
  return <DiscussionScreen key={routeKey} newsItemId={newsItemId} />;
}

export function DirectCommunityDiscussionPage() {
  const { discussionId = "" } = useParams();
  const { user } = useAuth();
  return <DiscussionScreen key={`${user?.id ?? "signed-out"}:${discussionId}`} directDiscussionId={discussionId} />;
}
