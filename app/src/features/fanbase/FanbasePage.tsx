import { useSearchParams } from "react-router-dom";
import { useTeamContext } from "../../state/TeamContext";
import { FanbaseAreaView } from "./FanbaseAreaViews";
import { FanbaseCreateDialog, type FanbaseCreationType } from "./FanbaseCreateDialog";
import { getGameThreadStatus, useFanbaseContext } from "./FanbaseContext";
import { FanbaseHub } from "./FanbaseHub";
import { FanbaseTeamFilter } from "./FanbaseTeamFilter";
import type { FanbaseAreaId } from "./types";
import { useState } from "react";
import { formatEventDate } from "./fanbaseFormatting";
import "./fanbase.css";

const fanbaseAreaIds = new Set<FanbaseAreaId>([
  "article-comments",
  "locker-room",
  "game-threads",
  "fan-photos",
  "events",
  "groups",
]);

function isFanbaseArea(value: string | null): value is FanbaseAreaId {
  return value !== null && fanbaseAreaIds.has(value as FanbaseAreaId);
}

const areaTitles: Record<FanbaseAreaId, string> = {
  "article-comments": "Article Comments",
  "locker-room": "Locker Room",
  "game-threads": "Game Threads",
  "fan-photos": "Fan Photos",
  events: "Events",
  groups: "Groups",
};

const areaCreationTypes: Record<FanbaseAreaId, FanbaseCreationType | null> = {
  "article-comments": null,
  "locker-room": "locker",
  "game-threads": null,
  "fan-photos": "photo",
  events: "event",
  groups: "group",
};

const areaActionLabels: Record<FanbaseAreaId, { accessible: string; visible: string }> = {
  "article-comments": { accessible: "Article Comments are created from News Items", visible: "News only" },
  "locker-room": { accessible: "Create Locker Room thread", visible: "New Thread" },
  "game-threads": { accessible: "Game Threads are created from scheduled games and events", visible: "Scheduled" },
  "fan-photos": { accessible: "Add Fan Photo", visible: "Add Photo" },
  events: { accessible: "Create Event", visible: "New Event" },
  groups: { accessible: "Create Group", visible: "New Group" },
};

export function FanbasePage() {
  const { followedTeams, selectedTeam, selectedTeamId, selectTeam } = useTeamContext();
  const fanbase = useFanbaseContext();
  const [searchParams, setSearchParams] = useSearchParams();
  const [teamFilterOpen, setTeamFilterOpen] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);
  const areaParam = searchParams.get("area");
  const area = isFanbaseArea(areaParam) ? areaParam : null;
  const itemId = searchParams.get("item");

  const openArea = (nextArea: FanbaseAreaId) => {
    setSearchParams({ area: nextArea });
  };

  const openItem = (nextItemId: string) => {
    if (!area) return;
    setSearchParams({ area, item: nextItemId });
  };

  const backToFanbase = () => setSearchParams({});

  const chooseTeam = (teamId: typeof selectedTeamId) => {
    selectTeam(teamId);
    setTeamFilterOpen(false);
    setSearchParams(area ? { area } : {});
  };

  const created = (createdArea: FanbaseAreaId, createdItemId: string) => {
    setCreateOpen(false);
    setSearchParams({ area: createdArea, item: createdItemId });
  };

  const contextualCreationType = area ? areaCreationTypes[area] : null;
  const subpageContext = (() => {
    if (!area) return `${selectedTeam.name} fan community`;
    if (area === "article-comments") return `${selectedTeam.name} News discussions`;
    if (area === "locker-room") {
      const thread = itemId ? fanbase.threads.find((candidate) => candidate.id === itemId) : undefined;
      return thread ? `${thread.category ?? "Team talk"} · @${thread.creator?.username ?? "fan"}` : `${selectedTeam.name} standalone team talk`;
    }
    if (area === "game-threads") {
      const game = itemId ? fanbase.gameThreads.find((candidate) => candidate.id === itemId) : undefined;
      return game
        ? `${getGameThreadStatus(game)} · vs. ${game.opponent} · ${formatEventDate(game.startsAt)}`
        : `${selectedTeam.name} scheduled, live, and archived games`;
    }
    if (area === "fan-photos") {
      const photo = itemId ? fanbase.fanPhotos.find((candidate) => candidate.id === itemId) : undefined;
      return photo ? `${photo.category} · @${photo.owner.username}` : `${selectedTeam.name} Game Face, Fan Cave, and Memorabilia`;
    }
    if (area === "events") {
      const event = itemId ? fanbase.events.find((candidate) => candidate.id === itemId) : undefined;
      return event ? `${event.eventType} · ${formatEventDate(event.startsAt)} · ${event.location}` : `${selectedTeam.name} gatherings and watch parties`;
    }
    const group = itemId ? fanbase.groups.find((candidate) => candidate.id === itemId) : undefined;
    return group ? `${group.visibility} · ${group.memberCount} members` : `${selectedTeam.name} joined and discoverable groups`;
  })();

  return (
    <div className="fanbase-page">
      <header className={area ? "fanbase-topbar fanbase-topbar--subpage" : "fanbase-topbar"}>
        {area ? (
          <button className="fanbase-back-trigger" type="button" aria-label="Back to FANbase" onClick={backToFanbase}><span aria-hidden="true">←</span><span className="fanbase-back-trigger__full">Back to FANbase</span><span className="fanbase-back-trigger__short">Back</span></button>
        ) : (
          <button className="fanbase-team-trigger" type="button" aria-label="Choose FANbase team" aria-expanded={teamFilterOpen} onClick={() => setTeamFilterOpen(true)}>
            <span aria-hidden="true">☰</span><img src={selectedTeam.logoUrl} alt="" /><span>{selectedTeam.shortName}</span>
          </button>
        )}
        <div className="fanbase-topbar__title">
          <span className="eyebrow">{area ? "FANbase" : "Community hub"}</span>
          <h1>{area ? areaTitles[area] : "FANbase"}</h1>
          <p>{subpageContext}</p>
        </div>
        {area ? (
          <button
            className="fanbase-create-trigger fanbase-create-trigger--contextual"
            type="button"
            aria-label={areaActionLabels[area].accessible}
            aria-expanded={contextualCreationType ? createOpen : undefined}
            disabled={!contextualCreationType}
            onClick={() => contextualCreationType && setCreateOpen(true)}
          >
            <span aria-hidden="true">＋</span><span>{areaActionLabels[area].visible}</span>
          </button>
        ) : (
          <button className="fanbase-create-trigger" type="button" aria-label="Create in FANbase" aria-expanded={createOpen} onClick={() => setCreateOpen(true)}><span aria-hidden="true">＋</span><span>Create</span></button>
        )}
      </header>

      {area ? (
        <FanbaseAreaView area={area} itemId={itemId} teamId={selectedTeamId} onOpenItem={openItem} />
      ) : (
        <FanbaseHub teamId={selectedTeamId} onOpenArea={openArea} />
      )}

      {teamFilterOpen ? <FanbaseTeamFilter teams={followedTeams} selectedTeamId={selectedTeamId} onSelect={chooseTeam} onClose={() => setTeamFilterOpen(false)} /> : null}
      {createOpen ? (
        <FanbaseCreateDialog
          team={selectedTeam}
          {...(contextualCreationType ? { initialCreationType: contextualCreationType } : {})}
          onCreateLocker={fanbase.createLockerRoomThread}
          onCreatePhoto={fanbase.createFanPhoto}
          onCreateEvent={fanbase.createEvent}
          onCreateGroup={fanbase.createGroup}
          onCreated={created}
          onClose={() => setCreateOpen(false)}
        />
      ) : null}
    </div>
  );
}
