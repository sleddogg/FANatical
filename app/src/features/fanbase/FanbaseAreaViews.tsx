import { useState, type CSSProperties, type FormEvent, type ReactNode } from "react";
import { Link } from "react-router-dom";
import type { TeamId } from "../../domain/team";
import { mockNewsItems, mockSourceCatalog } from "../news/mockNewsData";
import { getSourceForItem } from "../news/newsFiltering";
import { CommunityThreadView } from "./CommunityThreadView";
import { getGameThreadStatus, getThreadCommentCount, useFanbaseContext } from "./FanbaseContext";
import { formatEventDate, formatFanbaseTime, formatRating, totalReactions } from "./fanbaseFormatting";
import { ReactionPicker } from "./ReactionPicker";
import type { FanbaseAreaId, FanPhotoCategory } from "./types";

type FanbaseAreaViewProps = {
  readonly area: FanbaseAreaId;
  readonly itemId: string | null;
  readonly teamId: TeamId;
  readonly onOpenItem: (itemId: string) => void;
};

function EmptyArea({ children }: { children: ReactNode }) {
  return <div className="fanbase-empty surface"><span aria-hidden="true">◌</span><p>{children}</p></div>;
}

function ArticleCommentsArea({ teamId, itemId, onOpenItem }: Omit<FanbaseAreaViewProps, "area">) {
  const fanbase = useFanbaseContext();
  const selectedNewsItem = itemId ? mockNewsItems.find((item) => item.id === itemId) : undefined;
  const articleThreads = fanbase.threads
    .filter((thread) => thread.kind === "article" && thread.teamId === teamId)
    .sort((first, second) => Date.parse(second.createdAt) - Date.parse(first.createdAt));

  if (selectedNewsItem) {
    const source = getSourceForItem(selectedNewsItem, mockSourceCatalog);
    const thread = fanbase.getArticleThread(selectedNewsItem.id);
    const discussionTeamId = thread?.teamId ?? teamId;
    return (
      <>
        <div className="article-context-card">
          <span className="news-source-avatar" aria-hidden="true">{source?.initials ?? "N"}</span>
          <div><small>{source?.name ?? "FANatical News"} · {selectedNewsItem.contentType}</small><strong>{selectedNewsItem.headline}</strong></div>
          <Link to={`/news?item=${selectedNewsItem.id}`}>View News Item ↗</Link>
        </div>
        <CommunityThreadView
          thread={thread}
          title={selectedNewsItem.headline}
          context={`${source?.name ?? "News"} discussion`}
          body={selectedNewsItem.summary}
          emptyMessage="No one has started this Article Comments thread yet. Your first comment will create it."
          onSubmitComment={(body, parentId) => {
            if (thread) {
              fanbase.addComment(thread.id, body, parentId);
            } else {
              fanbase.addArticleComment(selectedNewsItem.id, discussionTeamId, body, parentId);
            }
          }}
          onReactToThread={(reaction) => thread && fanbase.reactToThread(thread.id, reaction)}
          onReactToComment={(commentId, reaction) => thread && fanbase.reactToComment(thread.id, commentId, reaction)}
          onReportThread={() => thread && fanbase.reportThread(thread.id)}
          onReportComment={(commentId) => thread && fanbase.reportComment(thread.id, commentId)}
        />
      </>
    );
  }

  return (
    <>
      <div className="fanbase-list">
        {articleThreads.length ? articleThreads.map((thread) => {
          const item = mockNewsItems.find((newsItem) => newsItem.id === thread.newsItemId);
          if (!item) {
            return null;
          }
          const source = getSourceForItem(item, mockSourceCatalog);
          return (
            <button className="fanbase-entry-card" key={thread.id} type="button" onClick={() => onOpenItem(item.id)}>
              <span className="news-source-avatar" aria-hidden="true">{source?.initials ?? "N"}</span>
              <span className="fanbase-entry-card__copy"><small>{source?.name ?? "News"}</small><strong>{item.headline}</strong><span>{getThreadCommentCount(thread)} comments · {totalReactions(thread.reactions)} reactions · {formatFanbaseTime(thread.createdAt)}</span></span>
              <span aria-hidden="true">›</span>
            </button>
          );
        }) : <EmptyArea>No Article Comments threads have started for this team yet.</EmptyArea>}
      </div>
    </>
  );
}

function LockerRoomArea({ teamId, itemId, onOpenItem }: Omit<FanbaseAreaViewProps, "area">) {
  const fanbase = useFanbaseContext();
  const threads = fanbase.threads.filter((thread) => thread.kind === "locker" && thread.teamId === teamId);
  const selectedThread = itemId ? threads.find((thread) => thread.id === itemId) : undefined;

  if (selectedThread) {
    return (
      <>
        <CommunityThreadView
          thread={selectedThread}
          title={selectedThread.title ?? "Locker Room thread"}
          context={`${selectedThread.category ?? "Team Talk"} · @${selectedThread.creator?.username ?? "fan"}`}
          body={selectedThread.body ?? ""}
          onSubmitComment={(body, parentId) => fanbase.addComment(selectedThread.id, body, parentId)}
          onReactToThread={(reaction) => fanbase.reactToThread(selectedThread.id, reaction)}
          onReactToComment={(commentId, reaction) => fanbase.reactToComment(selectedThread.id, commentId, reaction)}
          onReportThread={() => fanbase.reportThread(selectedThread.id)}
          onReportComment={(commentId) => fanbase.reportComment(selectedThread.id, commentId)}
        />
      </>
    );
  }

  return (
    <>
      <div className="fanbase-list">
        {threads.map((thread) => (
          <button className="fanbase-entry-card" key={thread.id} type="button" onClick={() => onOpenItem(thread.id)}>
            <span className="fanbase-entry-card__glyph" aria-hidden="true">▤</span>
            <span className="fanbase-entry-card__copy"><small>{thread.category} · @{thread.creator?.username}</small><strong>{thread.title}</strong><span>{getThreadCommentCount(thread)} comments · {totalReactions(thread.reactions)} reactions · {formatFanbaseTime(thread.createdAt)}</span></span>
            <span aria-hidden="true">›</span>
          </button>
        ))}
      </div>
    </>
  );
}

function GameThreadsArea({ teamId, itemId, onOpenItem }: Omit<FanbaseAreaViewProps, "area">) {
  const fanbase = useFanbaseContext();
  const games = fanbase.gameThreads.filter((game) => game.teamId === teamId);
  const selectedGame = itemId ? games.find((game) => game.id === itemId) : undefined;
  const selectedThread = selectedGame ? fanbase.threads.find((thread) => thread.id === selectedGame.threadId) : undefined;

  if (selectedGame && selectedThread) {
    const status = getGameThreadStatus(selectedGame);
    return (
      <>
        <div className={`game-scoreboard game-scoreboard--${status.toLowerCase().replace("-", "")}`}>
          <span>{status}</span><strong>Selected Team <small>vs.</small> {selectedGame.opponent}</strong><small>{selectedGame.venue}</small>
        </div>
        <CommunityThreadView
          thread={selectedThread}
          title={selectedThread.title ?? `vs. ${selectedGame.opponent}`}
          context={`${status} Game Thread`}
          body={status === "Archived" ? "The 24-hour post-game window has ended. This discussion is now read-only." : "Pregame, live, and post-game conversation stays together here."}
          locked={status === "Archived"}
          onSubmitComment={(body, parentId) => fanbase.addComment(selectedThread.id, body, parentId)}
          onReactToThread={(reaction) => fanbase.reactToThread(selectedThread.id, reaction)}
          onReactToComment={(commentId, reaction) => fanbase.reactToComment(selectedThread.id, commentId, reaction)}
          onReportThread={() => fanbase.reportThread(selectedThread.id)}
          onReportComment={(commentId) => fanbase.reportComment(selectedThread.id, commentId)}
        />
      </>
    );
  }

  const order = { Live: 0, Scheduled: 1, "Post-game": 2, Archived: 3 } as const;
  return (
    <>
      <div className="fanbase-list fanbase-game-list">
        {[...games].sort((first, second) => order[getGameThreadStatus(first)] - order[getGameThreadStatus(second)]).map((game) => {
          const status = getGameThreadStatus(game);
          const thread = fanbase.threads.find((candidate) => candidate.id === game.threadId);
          return (
            <button className="fanbase-game-card" key={game.id} type="button" onClick={() => onOpenItem(game.id)}>
              <span className={`fanbase-status fanbase-status--${status.toLowerCase().replace("-", "")}`}>{status}</span>
              <strong>Selected Team <small>vs.</small> {game.opponent}</strong>
              <span>{formatEventDate(game.startsAt)} · {game.venue}</span>
              <small>{getThreadCommentCount(thread)} comments {status === "Archived" ? "· Read only" : "· Join conversation"}</small>
            </button>
          );
        })}
      </div>
    </>
  );
}

function FanPhotosArea({ teamId, itemId, onOpenItem }: Omit<FanbaseAreaViewProps, "area">) {
  const fanbase = useFanbaseContext();
  const [category, setCategory] = useState<FanPhotoCategory | "All">("All");
  const photos = fanbase.fanPhotos.filter((photo) => photo.teamId === teamId && (category === "All" || photo.category === category));
  const selectedPhoto = itemId ? fanbase.fanPhotos.find((photo) => photo.id === itemId && photo.teamId === teamId) : undefined;
  const [commentBody, setCommentBody] = useState("");

  if (selectedPhoto) {
    const submit = (event: FormEvent<HTMLFormElement>) => {
      event.preventDefault();
      if (!commentBody.trim()) return;
      fanbase.addFanPhotoComment(selectedPhoto.id, commentBody);
      setCommentBody("");
    };
    return (
      <>
        <article className="fan-photo-detail surface">
          <div className="fan-photo-visual" style={{ "--fan-photo-accent": selectedPhoto.accent } as CSSProperties}>
            {selectedPhoto.rankingBadge ? <span className="fan-photo-badge">{selectedPhoto.rankingBadge}</span> : null}
            <img src={selectedPhoto.imageUrl} alt={selectedPhoto.imageAlt} />
          </div>
          <div className="fan-photo-detail__copy">
            <span className="eyebrow">{selectedPhoto.category}</span><h2>{selectedPhoto.title}</h2><p>{selectedPhoto.details}</p>
            <div className="fan-photo-rating"><strong>{formatRating(selectedPhoto.ratingTotal, selectedPhoto.ratingCount)}</strong><span>average from {selectedPhoto.ratingCount} ratings</span></div>
            <fieldset className="fan-photo-rating-control"><legend>Your rating</legend>{[1, 2, 3, 4, 5].map((rating) => <button key={rating} type="button" aria-label={`Rate ${rating} out of 5`} aria-pressed={selectedPhoto.viewerRating === rating} onClick={() => fanbase.rateFanPhoto(selectedPhoto.id, rating)}>★</button>)}</fieldset>
            <ReactionPicker reactions={selectedPhoto.reactions} viewerReaction={selectedPhoto.viewerReaction} onReact={(reaction) => fanbase.reactToFanPhoto(selectedPhoto.id, reaction)} />
            <button className="fanbase-report-button" type="button" onClick={() => fanbase.reportFanPhoto(selectedPhoto.id)}>{selectedPhoto.reported ? "Reported" : "Report photo"}</button>
          </div>
        </article>
        <section className="photo-comments surface"><h3>Photo comments</h3>{selectedPhoto.comments.map((comment) => <article key={comment.id}><span className="community-avatar">{comment.author.initials}</span><div><strong>@{comment.author.username}</strong><p>{comment.body}</p></div></article>)}<form onSubmit={submit}><label><span>Add a comment</span><textarea required rows={2} value={commentBody} onChange={(event) => setCommentBody(event.target.value)} /></label><button className="fanbase-primary-button" type="submit">Post</button></form></section>
      </>
    );
  }

  return (
    <>
      <div className="fanbase-chip-row" aria-label="Photo categories">{(["All", "Game Face", "Fan Cave", "Memorabilia"] as const).map((option) => <button key={option} type="button" aria-pressed={category === option} onClick={() => setCategory(option)}>{option}</button>)}</div>
      <div className="fan-photo-grid">
        {photos.map((photo) => (
          <button className="fan-photo-card" key={photo.id} type="button" onClick={() => onOpenItem(photo.id)}>
            <span className="fan-photo-visual" style={{ "--fan-photo-accent": photo.accent } as CSSProperties}>{photo.rankingBadge ? <span className="fan-photo-badge">{photo.rankingBadge}</span> : null}<img src={photo.imageUrl} alt="" /></span>
            <span className="fan-photo-card__copy"><small>{photo.category} · @{photo.owner.username}</small><strong>{photo.title}</strong><span>★ {formatRating(photo.ratingTotal, photo.ratingCount)} · {totalReactions(photo.reactions)} reactions · {photo.comments.length} comments</span></span>
          </button>
        ))}
      </div>
    </>
  );
}

function EventsArea({ teamId, itemId, onOpenItem }: Omit<FanbaseAreaViewProps, "area">) {
  const fanbase = useFanbaseContext();
  const teamEvents = fanbase.events.filter((event) => event.teamId === teamId);
  const selectedEvent = itemId ? teamEvents.find((event) => event.id === itemId) : undefined;
  if (selectedEvent) {
    return (
      <>
        <article className="fanbase-detail-card surface">
          <span className="fanbase-detail-card__glyph" aria-hidden="true">◫</span><span className="eyebrow">{selectedEvent.eventType}</span><h2>{selectedEvent.title}</h2><p>{selectedEvent.description}</p>
          <dl><div><dt>When</dt><dd>{formatEventDate(selectedEvent.startsAt)}</dd></div><div><dt>Where</dt><dd>{selectedEvent.location}</dd></div><div><dt>Host</dt><dd>{selectedEvent.host}</dd></div><div><dt>Fans joined</dt><dd>{selectedEvent.joinCount}</dd></div></dl>
          <div className="fanbase-detail-actions"><button className="fanbase-primary-button" type="button" aria-pressed={selectedEvent.joined} onClick={() => fanbase.toggleEventJoined(selectedEvent.id)}>{selectedEvent.joined ? "Joined ✓" : "Join event"}</button><button type="button" aria-pressed={selectedEvent.saved} onClick={() => fanbase.toggleEventSaved(selectedEvent.id)}>{selectedEvent.saved ? "Saved ✓" : "Save"}</button><button type="button" onClick={() => fanbase.reportEvent(selectedEvent.id)}>{selectedEvent.reported ? "Reported" : "Report"}</button></div>
        </article>
      </>
    );
  }
  return (
    <div className="fanbase-card-grid">{teamEvents.map((event) => <button className="fanbase-simple-card" key={event.id} type="button" onClick={() => onOpenItem(event.id)}><span className="fanbase-status">{event.eventType}</span><strong>{event.title}</strong><span>{formatEventDate(event.startsAt)}</span><small>{event.location} · {event.joinCount} joined {event.joined ? "· You’re going" : ""}</small></button>)}</div>
  );
}

function GroupsArea({ teamId, itemId, onOpenItem }: Omit<FanbaseAreaViewProps, "area">) {
  const fanbase = useFanbaseContext();
  const teamGroups = fanbase.groups.filter((group) => group.teamId === teamId);
  const selectedGroup = itemId ? teamGroups.find((group) => group.id === itemId) : undefined;
  const thread = selectedGroup ? fanbase.threads.find((candidate) => candidate.id === selectedGroup.threadId) : undefined;
  if (selectedGroup) {
    return (
      <>
        <article className="group-detail-banner surface"><span className="fanbase-detail-card__glyph" aria-hidden="true">◉</span><div><span className="eyebrow">{selectedGroup.visibility} group</span><h2>{selectedGroup.name}</h2><p>{selectedGroup.description}</p></div><div className="fanbase-detail-actions"><button className="fanbase-primary-button" type="button" aria-pressed={selectedGroup.joined} onClick={() => fanbase.toggleGroupJoined(selectedGroup.id)}>{selectedGroup.joined ? "Joined ✓" : "Join group"}</button><button type="button" onClick={() => fanbase.reportGroup(selectedGroup.id)}>{selectedGroup.reported ? "Reported" : "Report"}</button></div></article>
        {selectedGroup.joined ? <CommunityThreadView thread={thread} title={`${selectedGroup.name} conversation`} context="Group conversation" emptyMessage="Start the group conversation." onSubmitComment={(body, parentId) => thread && fanbase.addComment(thread.id, body, parentId)} onReactToThread={(reaction) => thread && fanbase.reactToThread(thread.id, reaction)} onReactToComment={(commentId, reaction) => thread && fanbase.reactToComment(thread.id, commentId, reaction)} onReportThread={() => thread && fanbase.reportThread(thread.id)} onReportComment={(commentId) => thread && fanbase.reportComment(thread.id, commentId)} /> : <EmptyArea>Join this public group to participate in its conversation.</EmptyArea>}
      </>
    );
  }
  return (
    <div className="fanbase-card-grid">{teamGroups.map((group) => <button className="fanbase-simple-card" key={group.id} type="button" onClick={() => onOpenItem(group.id)}><span className="fanbase-status">{group.visibility}</span><strong>{group.name}</strong><span>{group.description}</span><small>{group.memberCount} members · {group.joined ? "Joined" : "Discoverable"} · {formatFanbaseTime(group.latestActivity)}</small></button>)}</div>
  );
}

export function FanbaseAreaView(props: FanbaseAreaViewProps) {
  switch (props.area) {
    case "article-comments": return <ArticleCommentsArea {...props} />;
    case "locker-room": return <LockerRoomArea {...props} />;
    case "game-threads": return <GameThreadsArea {...props} />;
    case "fan-photos": return <FanPhotosArea {...props} />;
    case "events": return <EventsArea {...props} />;
    case "groups": return <GroupsArea {...props} />;
  }
}
