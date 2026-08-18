import { useMemo } from "react";
import type { TeamId } from "../../domain/team";
import { getGameThreadStatus, useFanbaseContext } from "./FanbaseContext";
import { findFollowedTeam } from "../../data/followedTeams";
import { pollScopeForFollowedTeam, pollsForScope } from "./polls";
import type { FanbaseAreaId } from "./types";
import { mockNewsItems } from "../news/mockNewsData";
import { newsDiscussionScopeMatchesTeam, newsItemDiscussionScope } from "../news/newsDiscussionScope";
import { AppIcon, type AppIconName } from "../../components/AppIcon";

type FanbaseHubProps = {
  readonly teamId: TeamId;
  readonly onOpenArea: (area: FanbaseAreaId) => void;
};

const areaDefinitions = [
  { id: "article-comments", title: "Article Discussions", icon: "newspaper", description: "Continue the conversation around News Items in one connected discussion." },
  { id: "locker-room", title: "Locker Room", icon: "chat-bubble-left-right", description: "Start standalone team talk about tactics, rosters, trades, and more." },
  { id: "game-threads", title: "Game Threads", icon: "chat-bubble-left-right", description: "Join scheduled, live, post-game, and archived game conversations." },
  { id: "fan-photos", title: "Fan Photos", icon: "photo", description: "Rate and react to Game Face, Fan Cave, and Memorabilia posts." },
  { id: "events", title: "Events", icon: "calendar-days", description: "Find watch parties, meetups, rivalry events, and online gatherings." },
  { id: "groups", title: "Groups", icon: "user-group", description: "Connect in public, private, invite-based, and joined fan groups." },
  { id: "polls", title: "Polls", icon: "chart-bar-square", description: "Vote on trending questions or browse team, league, and sport-wide fan opinion." },
  { id: "leaderboards", title: "Leaderboards", icon: "trophy", description: "Compare Fan Score, Sport IQ, Quiz IQ, Predictor IQ, and trophies." },
] as const satisfies readonly { id: FanbaseAreaId; title: string; icon: AppIconName; description: string }[];

export function FanbaseHub({ teamId, onOpenArea }: FanbaseHubProps) {
  const { threads, gameThreads, fanPhotos, events, groups, polls } = useFanbaseContext();
  const activity = useMemo<Record<FanbaseAreaId, string>>(() => {
    const teamThreads = threads.filter((thread) => thread.teamId === teamId);
    const articleThreads = threads.filter((thread) => {
      if (thread.kind !== "article") return false;
      const item = mockNewsItems.find((newsItem) => newsItem.id === thread.newsItemId);
      return item ? newsDiscussionScopeMatchesTeam(thread.discussionScope ?? newsItemDiscussionScope(item), teamId) : false;
    });
    const liveGames = gameThreads.filter((game) => game.teamId === teamId && getGameThreadStatus(game) === "Live").length;
    const upcomingEvents = events.filter((event) => event.teamId === teamId && Date.parse(event.startsAt) > Date.now()).length;
    const followedTeam = findFollowedTeam(teamId);
    const teamPollCount = followedTeam ? pollsForScope(polls, pollScopeForFollowedTeam(followedTeam)).length : 0;
    return {
      "article-comments": `${articleThreads.length} active News discussions`,
      "locker-room": `${teamThreads.filter((thread) => thread.kind === "locker").length} team topics`,
      "game-threads": liveGames ? `${liveGames} live now` : `${gameThreads.filter((game) => game.teamId === teamId).length} game conversations`,
      "fan-photos": `${fanPhotos.filter((photo) => photo.teamId === teamId).length} photos to explore`,
      events: `${upcomingEvents} upcoming gatherings`,
      groups: `${groups.filter((group) => group.teamId === teamId && group.joined).length} groups joined`,
      polls: `${teamPollCount} Polls in this FANbase`,
      leaderboards: "Team, League, Sport, Friends, and Groups",
    };
  }, [events, fanPhotos, gameThreads, groups, polls, teamId, threads]);

  return (
    <section className="fanbase-hub" aria-label="FANbase areas">
      {areaDefinitions.map((area) => (
        <button key={area.id} className="fanbase-hub-card" type="button" onClick={() => onOpenArea(area.id)}>
          <span className="fanbase-hub-card__icon"><AppIcon name={area.icon} /></span>
          <span className="fanbase-hub-card__copy">
            <strong>{area.title}</strong>
            <span>{area.description}</span>
            <small>{activity[area.id]} <AppIcon name="arrow-right" /></small>
          </span>
        </button>
      ))}
    </section>
  );
}
