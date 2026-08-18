import type { ReactNode } from "react";
import type { TeamId } from "../../domain/team";
import { findFollowedTeam } from "../../data/followedTeams";
import { mockNewsItems, mockSourceCatalog } from "../news/mockNewsData";
import { getSourceForItem } from "../news/newsFiltering";
import { newsDiscussionScopeMatchesTeam, newsItemDiscussionScope } from "../news/newsDiscussionScope";
import { CommunityThreadView } from "./CommunityThreadView";
import { ArticleDiscussionCard } from "./ArticleDiscussionCard";
import { FanPhotosArea } from "./FanPhotosArea";
import { LockerRoomTopicCard } from "./LockerRoomTopicCard";
import { PollsArea } from "./PollsArea";
import { GameDayPredictor } from "./GameDayPredictor";
import { LeaderboardsArea } from "./LeaderboardsArea";
import { formatGameStatusLabel, GameThreadContextCard } from "./GameThreadContextCard";
import { getGameThreadStatus, getThreadCommentCount, useFanbaseContext } from "./FanbaseContext";
import { formatEventDate, formatFanbaseTime, totalReactions } from "./fanbaseFormatting";
import type { FanbaseAreaId, FanPhotoCategory } from "./types";
import { AppIcon } from "../../components/AppIcon";

type FanbaseAreaViewProps = {
  readonly area: FanbaseAreaId;
  readonly itemId: string | null;
  readonly itemOrigin: "rating-queue" | null;
  readonly photoCategory: FanPhotoCategory | null;
  readonly teamId: TeamId;
  readonly onOpenPhotoCategory: (category: FanPhotoCategory) => void;
  readonly onOpenItem: (itemId: string) => void;
  readonly onOpenRatingItem: (itemId: string) => void;
  readonly onCloseItem: () => void;
};

function EmptyArea({ children }: { children: ReactNode }) {
  return <div className="fanbase-empty surface"><AppIcon name="information-circle" /><p>{children}</p></div>;
}

function ArticleCommentsArea({ teamId, itemId, onOpenItem }: Omit<FanbaseAreaViewProps, "area">) {
  const fanbase = useFanbaseContext();
  const selectedNewsItem = itemId ? mockNewsItems.find((item) => item.id === itemId) : undefined;
  const articleThreads = fanbase.threads
    .filter((thread) => {
      if (thread.kind !== "article") return false;
      const item = mockNewsItems.find((newsItem) => newsItem.id === thread.newsItemId);
      if (!item) return false;
      const scope = thread.discussionScope ?? newsItemDiscussionScope(item);
      return newsDiscussionScopeMatchesTeam(scope, teamId);
    })
    .sort((first, second) => Date.parse(second.createdAt) - Date.parse(first.createdAt));

  if (selectedNewsItem) {
    const source = getSourceForItem(selectedNewsItem, mockSourceCatalog);
    const thread = fanbase.getArticleThread(selectedNewsItem.id);
    const discussionScope = thread?.discussionScope ?? newsItemDiscussionScope(selectedNewsItem);
    const discussionPath = `/fanbase?area=article-comments&item=${selectedNewsItem.id}`;
    return (
      <>
        <ArticleDiscussionCard
          item={selectedNewsItem}
          source={source}
          thread={thread}
          discussionPath={discussionPath}
          onReact={(reaction) => thread && fanbase.reactToThread(thread.id, reaction)}
          onReport={() => thread && fanbase.reportThread(thread.id)}
        />
        <CommunityThreadView
          thread={thread}
          title={selectedNewsItem.headline}
          context={`${source?.name ?? "News"} discussion`}
          body={selectedNewsItem.summary}
          emptyMessage="No one has started this Article Discussion yet. Your first comment will create it."
          compactTopicMode
          onSubmitComment={(body, parentId) => {
            if (thread) {
              fanbase.addComment(thread.id, body, parentId);
            } else {
              fanbase.addArticleComment(selectedNewsItem.id, discussionScope, body, parentId);
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
              <AppIcon name="chevron-right" />
            </button>
          );
        }) : <EmptyArea>No Article Discussions have started for this team yet.</EmptyArea>}
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
        <LockerRoomTopicCard
          thread={selectedThread}
          onReact={(reaction) => fanbase.reactToThread(selectedThread.id, reaction)}
          onReport={() => fanbase.reportThread(selectedThread.id)}
        />
        <CommunityThreadView
          thread={selectedThread}
          title={selectedThread.title ?? "Locker Room thread"}
          context={`${selectedThread.category ?? "Team Talk"} · @${selectedThread.creator?.username ?? "fan"}`}
          body={selectedThread.body ?? ""}
          compactTopicMode
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
            <span className="fanbase-entry-card__glyph"><AppIcon name="chat-bubble-left-right" /></span>
            <span className="fanbase-entry-card__copy"><small>{thread.category} · @{thread.creator?.username}</small><strong>{thread.title}</strong><span>{getThreadCommentCount(thread)} comments · {totalReactions(thread.reactions)} reactions · {formatFanbaseTime(thread.createdAt)}</span></span>
            <AppIcon name="chevron-right" />
          </button>
        ))}
      </div>
    </>
  );
}

function GameThreadsArea({ teamId, itemId, onOpenItem }: Omit<FanbaseAreaViewProps, "area">) {
  const fanbase = useFanbaseContext();
  const teamName = findFollowedTeam(teamId)?.name ?? "Your team";
  const games = fanbase.gameThreads.filter((game) => game.teamId === teamId);
  const selectedGame = itemId ? games.find((game) => game.id === itemId) : undefined;
  const selectedThread = selectedGame ? fanbase.threads.find((thread) => thread.id === selectedGame.threadId) : undefined;

  if (selectedGame && selectedThread) {
    const status = getGameThreadStatus(selectedGame);
    return (
      <>
        <GameThreadContextCard game={selectedGame} thread={selectedThread} teamName={teamName} status={status} onReport={() => fanbase.reportThread(selectedThread.id)} />
        <GameDayPredictor game={selectedGame} teamName={teamName} />
        <CommunityThreadView
          thread={selectedThread}
          title={selectedThread.title ?? `vs. ${selectedGame.opponent}`}
          context={`${status} Game Thread`}
          body={status === "Archived" ? "The 24-hour post-game window has ended. This discussion is now read-only." : "Pregame, live, and post-game conversation stays together here."}
          locked={status === "Archived"}
          compactTopicMode
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
              <span className={`fanbase-status fanbase-status--${status.toLowerCase().replace("-", "")}`}>{formatGameStatusLabel(status)}</span>
              <strong>{teamName} <small>vs.</small> {game.opponent}</strong>
              <span>{formatEventDate(game.startsAt)} · {game.venue}</span>
              <small>{getThreadCommentCount(thread)} comments {status === "Archived" ? "· Read only" : "· Join conversation"}</small>
            </button>
          );
        })}
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
        <article className="fanbase-detail-card fanbase-detail-card--event surface">
          <span className="fanbase-status fanbase-event-detail__type">{selectedEvent.eventType}</span><h2>{selectedEvent.title}</h2><p>{selectedEvent.description}</p>
          <dl><div><dt>When</dt><dd>{formatEventDate(selectedEvent.startsAt)}</dd></div><div><dt>Where</dt><dd>{selectedEvent.location.label}</dd></div><div><dt>Host</dt><dd>{selectedEvent.host}</dd></div><div><dt>Fans joined</dt><dd>{selectedEvent.joinCount}</dd></div></dl>
          <div className="fanbase-detail-actions"><button className="fanbase-primary-button" type="button" aria-pressed={selectedEvent.joined} onClick={() => fanbase.toggleEventJoined(selectedEvent.id)}>{selectedEvent.joined ? <><span>Joined</span><AppIcon name="check" /></> : "Join event"}</button><button type="button" aria-pressed={selectedEvent.saved} onClick={() => fanbase.toggleEventSaved(selectedEvent.id)}>{selectedEvent.saved ? <><span>Saved</span><AppIcon name="check" /></> : "Save"}</button><button type="button" onClick={() => fanbase.reportEvent(selectedEvent.id)}>{selectedEvent.reported ? "Reported" : "Report"}</button></div>
        </article>
      </>
    );
  }
  return (
    <div className="fanbase-card-grid">{teamEvents.map((event) => <button className="fanbase-simple-card" key={event.id} type="button" onClick={() => onOpenItem(event.id)}><span className="fanbase-status">{event.eventType}</span><strong>{event.title}</strong><span>{formatEventDate(event.startsAt)}</span><small>{event.location.label} · {event.joinCount} joined {event.joined ? "· You’re going" : ""}</small></button>)}</div>
  );
}

function GroupsArea({ teamId, itemId, onOpenItem }: Omit<FanbaseAreaViewProps, "area">) {
  const fanbase = useFanbaseContext();
  const teamGroups = fanbase.groups.filter((group) => group.teamId === teamId);
  const selectedGroup = itemId ? teamGroups.find((group) => group.id === itemId) : undefined;
  const thread = selectedGroup ? fanbase.threads.find((candidate) => candidate.id === selectedGroup.threadId) : undefined;
  if (selectedGroup) {
    const initials = selectedGroup.name.split(" ").map((word) => word[0]).slice(0, 2).join("");
    const canJoinDirectly = selectedGroup.joined || selectedGroup.visibility === "Public";
    return (
      <>
        <article className="group-identity-card surface">
          <span className="group-identity-card__avatar" aria-hidden="true">{initials}</span>
          <div className="group-identity-card__context"><span className="fanbase-status">{selectedGroup.visibility}</span><span>{selectedGroup.memberCount} members</span><span>{selectedGroup.joined ? `${selectedGroup.viewerRole ?? "Member"} · Joined` : "Not joined"}</span>{selectedGroup.invitedUserIds.length ? <span>{selectedGroup.invitedUserIds.length} pending invites</span> : null}</div>
          <div className="fanbase-detail-actions">{canJoinDirectly ? <button className="fanbase-primary-button" type="button" aria-pressed={selectedGroup.joined} onClick={() => fanbase.toggleGroupJoined(selectedGroup.id)}>{selectedGroup.joined ? <><span>Joined</span><AppIcon name="check" /></> : "Join group"}</button> : null}<button type="button" onClick={() => fanbase.reportGroup(selectedGroup.id)}>{selectedGroup.reported ? "Reported" : "Report"}</button></div>
        </article>
        {selectedGroup.joined ? <CommunityThreadView thread={thread} title={`${selectedGroup.name} conversation`} context="Group conversation" compactTopicMode compactComposerPosition="bottom" emptyMessage="Start the group conversation." onSubmitComment={(body, parentId) => thread && fanbase.addComment(thread.id, body, parentId)} onReactToThread={(reaction) => thread && fanbase.reactToThread(thread.id, reaction)} onReactToComment={(commentId, reaction) => thread && fanbase.reactToComment(thread.id, commentId, reaction)} onReportThread={() => thread && fanbase.reportThread(thread.id)} onReportComment={(commentId) => thread && fanbase.reportComment(thread.id, commentId)} /> : <EmptyArea>{selectedGroup.visibility === "Public" ? "Join this public group to participate in its conversation." : "An invitation is required to participate in this group."}</EmptyArea>}
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
    case "fan-photos": return <FanPhotosArea teamId={props.teamId} itemId={props.itemId} itemOrigin={props.itemOrigin} category={props.photoCategory} onOpenCategory={props.onOpenPhotoCategory} onOpenItem={props.onOpenItem} onOpenRatingItem={props.onOpenRatingItem} onCloseItem={props.onCloseItem} />;
    case "events": return <EventsArea {...props} />;
    case "groups": return <GroupsArea {...props} />;
    case "polls": return <PollsArea teamId={props.teamId} itemId={props.itemId} />;
    case "leaderboards": return <LeaderboardsArea teamId={props.teamId} />;
  }
}
