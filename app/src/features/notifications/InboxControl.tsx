import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { AppIcon } from "../../components/AppIcon";
import { useAuth } from "../account/AuthContext";
import { trapDialogFocus } from "../news/dialogKeyboard";
import { markModerationNoticesRead, markNotificationsRead, type AccountNotification } from "./notificationRepository";
import { useNotifications } from "./NotificationContext";
import "./notifications.css";

function notificationLabel(notification: AccountNotification) {
  if (notification.type === "direct_reply") return `${notification.actorFanaticalName ?? "A fan"} replied to your comment.`;
  if (notification.type === "request_available") return "Your Add-to-Feed Request is Available. Follow remains your choice.";
  return `Your Add-to-Feed Request is Unable to add${typeof notification.metadata.reason === "string" ? `: ${notification.metadata.reason}` : "."}`;
}

function notificationPath(notification: AccountNotification) {
  const discussionId = notification.type === "direct_reply" && typeof notification.metadata.discussion_id === "string"
    ? notification.metadata.discussion_id
    : null;
  return discussionId ? `/community/discussions/${encodeURIComponent(discussionId)}` : "/news";
}

export function InboxControl() {
  const { user } = useAuth();
  const { inbox, loading, refresh } = useNotifications();
  const [open, setOpen] = useState(false);
  const [error, setError] = useState("");
  const triggerRef = useRef<HTMLButtonElement>(null);
  const closeRef = useRef<HTMLButtonElement>(null);
  const dialogRef = useRef<HTMLElement>(null);

  useEffect(() => {
    if (!open) return undefined;
    const previousOverflow = document.body.style.overflow;
    const returnFocus = triggerRef.current;
    document.body.style.overflow = "hidden";
    closeRef.current?.focus();
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
      else trapDialogFocus(event, dialogRef.current);
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = previousOverflow;
      window.requestAnimationFrame(() => returnFocus?.focus());
    };
  }, [open]);

  if (!user) return null;
  const totalUnread = inbox.unreadCount + inbox.moderationUnreadCount;

  const openInbox = async () => {
    setOpen(true);
    setError("");
    try {
      const refreshed = await refresh();
      await Promise.all([
        markNotificationsRead(refreshed.notifications.filter((item) => !item.read).map((item) => item.id)),
        markModerationNoticesRead(refreshed.moderationNotices.filter((item) => !item.read).map((item) => item.id)),
      ]);
      await refresh();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Inbox could not be loaded.");
    }
  };

  return (
    <>
      <button ref={triggerRef} className="inbox-control" type="button" aria-label={`Inbox${totalUnread ? `, ${totalUnread} unread` : ""}`} onClick={() => void openInbox()}>
        <AppIcon name="chat-bubble-left-right" />
        {totalUnread ? <span className="inbox-control__badge">{totalUnread > 99 ? "99+" : totalUnread}</span> : null}
      </button>
      {open ? (
        <div className="inbox-layer">
          <button className="inbox-backdrop" type="button" aria-label="Close Inbox" onClick={() => setOpen(false)} />
          <section ref={dialogRef} className="inbox-dialog" role="dialog" aria-modal="true" aria-labelledby="inbox-title" tabIndex={-1}>
            <header><div><span className="eyebrow">Your account</span><h2 id="inbox-title">Inbox</h2></div><button ref={closeRef} type="button" aria-label="Close Inbox" onClick={() => setOpen(false)}><AppIcon name="x-mark" /></button></header>
            {loading ? <p role="status">Refreshing…</p> : null}
            {error ? <p role="alert">{error}</p> : null}
            {!loading && !error ? (
              <>
                <section><h3>Replies and Requests</h3>{inbox.notifications.length ? <ul>{inbox.notifications.map((notification) => <li key={notification.id}><Link to={notificationPath(notification)} onClick={() => setOpen(false)}><strong>{notificationLabel(notification)}</strong><time dateTime={notification.createdAt}>{new Date(notification.createdAt).toLocaleString()}</time></Link></li>)}</ul> : <p>No reply or Request notifications.</p>}</section>
                <section className="inbox-dialog__moderation"><h3>Account notices</h3><p>Moderation notices are separate from social notifications.</p>{inbox.moderationNotices.length ? <ul>{inbox.moderationNotices.map((notice) => <li key={notice.id}><strong>{notice.message}</strong><time dateTime={notice.createdAt}>{new Date(notice.createdAt).toLocaleString()}</time></li>)}</ul> : <p>No moderation notices.</p>}</section>
              </>
            ) : null}
          </section>
        </div>
      ) : null}
    </>
  );
}
