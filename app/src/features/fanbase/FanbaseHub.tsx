import { useMemo } from "react";
import type { TeamId } from "../../domain/team";
import { getGameThreadStatus, useFanbaseContext } from "./FanbaseContext";
import type { FanbaseAreaId } from "./types";

type FanbaseHubProps = {
  readonly teamId: TeamId;
  readonly onOpenArea: (area: FanbaseAreaId) => void;
};

const areaDefinitions = [
  { id: "article-comments", title: "Article Discussions", icon: "◌", description: "Continue the conversation around News Items in one connected discussion." },
  { id: "locker-room", title: "Locker Room", icon: "▤", description: "Start standalone team talk about tactics, rosters, trades, and more." },
  { id: "game-threads", title: "Game Threads", icon: "▣", description: "Join scheduled, live, post-game, and archived game conversations." },
  { id: "fan-photos", title: "Fan Photos", icon: "▧", description: "Rate and react to Game Face, Fan Cave, and Memorabilia posts." },
  { id: "events", title: "Events", icon: "◫", description: "Find watch parties, meetups, rivalry events, and online gatherings." },
  { id: "groups", title: "Groups", icon: "◉", description: "Connect in public, private, invite-based, and joined fan groups." },
] as const satisfies readonly { id: FanbaseAreaId; title: string; icon: string; description: string }[];

export function FanbaseHub({ teamId, onOpenArea }: FanbaseHubProps) {
  const { threads, gameThreads, fanPhotos, events, groups } = useFanbaseContext();
  const activity = useMemo<Record<FanbaseAreaId, string>>(() => {
    const teamThreads = threads.filter((thread) => thread.teamId === teamId);
    const liveGames = gameThreads.filter((game) => game.teamId === teamId && getGameThreadStatus(game) === "Live").length;
    const upcomingEvents = events.filter((event) => event.teamId === teamId && Date.parse(event.startsAt) > Date.now()).length;
    return {
      "article-comments": `${teamThreads.filter((thread) => thread.kind === "article").length} active News discussions`,
      "locker-room": `${teamThreads.filter((thread) => thread.kind === "locker").length} team topics`,
      "game-threads": liveGames ? `${liveGames} live now` : `${gameThreads.filter((game) => game.teamId === teamId).length} game conversations`,
      "fan-photos": `${fanPhotos.filter((photo) => photo.teamId === teamId).length} photos to explore`,
      events: `${upcomingEvents} upcoming gatherings`,
      groups: `${groups.filter((group) => group.teamId === teamId && group.joined).length} groups joined`,
    };
  }, [events, fanPhotos, gameThreads, groups, teamId, threads]);

  return (
    <section className="fanbase-hub" aria-label="FANbase areas">
      {areaDefinitions.map((area) => (
        <button key={area.id} className="fanbase-hub-card" type="button" onClick={() => onOpenArea(area.id)}>
          <span className="fanbase-hub-card__icon" aria-hidden="true">{area.icon}</span>
          <span className="fanbase-hub-card__copy">
            <strong>{area.title}</strong>
            <span>{area.description}</span>
            <small>{activity[area.id]} <span aria-hidden="true">→</span></small>
          </span>
        </button>
      ))}
    </section>
  );
}
