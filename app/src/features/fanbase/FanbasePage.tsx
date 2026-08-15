import { useSearchParams } from "react-router-dom";
import { useTeamContext } from "../../state/TeamContext";
import { FanbaseAreaView } from "./FanbaseAreaViews";
import { FanbaseCreateDialog, type FanbaseCreationType } from "./FanbaseCreateDialog";
import { EventInviteDialog } from "./EventInviteDialog";
import { useFanbaseContext } from "./FanbaseContext";
import { FanbaseHub } from "./FanbaseHub";
import { FanbaseTeamFilter } from "./FanbaseTeamFilter";
import { GroupMembershipDialog } from "./GroupMembershipDialog";
import { PollCreateDialog } from "./PollCreateDialog";
import { pollScopeForFollowedTeam } from "./polls";
import type { FanbaseAreaId, FanPhotoCategory } from "./types";
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
  "polls",
  "leaderboards",
]);

function isFanbaseArea(value: string | null): value is FanbaseAreaId {
  return value !== null && fanbaseAreaIds.has(value as FanbaseAreaId);
}

const fanPhotoCategories = new Set<FanPhotoCategory>(["Game Face", "Fan Cave", "Memorabilia"]);

function isFanPhotoCategory(value: string | null): value is FanPhotoCategory {
  return value !== null && fanPhotoCategories.has(value as FanPhotoCategory);
}

const areaTitles: Record<FanbaseAreaId, string> = {
  "article-comments": "Article Discussions",
  "locker-room": "Locker Room",
  "game-threads": "Game Threads",
  "fan-photos": "Fan Photos",
  events: "Events",
  groups: "Groups",
  polls: "Polls",
  leaderboards: "Leaderboards",
};

const areaCreationTypes: Record<FanbaseAreaId, FanbaseCreationType | null> = {
  "article-comments": null,
  "locker-room": "locker",
  "game-threads": null,
  "fan-photos": "photo",
  events: "event",
  groups: "group",
  polls: null,
  leaderboards: null,
};

const areaActionLabels: Record<FanbaseAreaId, { accessible: string; visible: string }> = {
  "article-comments": { accessible: "Article Discussions are created from News Items", visible: "News only" },
  "locker-room": { accessible: "Create Locker Room thread", visible: "New Thread" },
  "game-threads": { accessible: "Game Threads are created from scheduled games and events", visible: "Scheduled" },
  "fan-photos": { accessible: "Add Fan Photo", visible: "Add Photo" },
  events: { accessible: "Create Event", visible: "New Event" },
  groups: { accessible: "Create Group", visible: "New Group" },
  polls: { accessible: "Create Poll", visible: "New Poll" },
  leaderboards: { accessible: "Leaderboard comparison controls are below", visible: "Rankings" },
};

export function FanbasePage() {
  const { followedTeams, selectedTeam, selectedTeamId, selectTeam } = useTeamContext();
  const fanbase = useFanbaseContext();
  const [searchParams, setSearchParams] = useSearchParams();
  const [teamFilterOpen, setTeamFilterOpen] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);
  const [groupMembershipOpen, setGroupMembershipOpen] = useState(false);
  const [eventInviteOpen, setEventInviteOpen] = useState(false);
  const [pollCreateOpen, setPollCreateOpen] = useState(false);
  const areaParam = searchParams.get("area");
  const area = isFanbaseArea(areaParam) ? areaParam : null;
  const itemId = searchParams.get("item");
  const photoCategoryParam = searchParams.get("category");
  const photoCategory = area === "fan-photos" && isFanPhotoCategory(photoCategoryParam) ? photoCategoryParam : null;
  const itemOrigin = area === "fan-photos" && searchParams.get("origin") === "rating-queue" ? "rating-queue" : null;
  const selectedEvent = area === "events" && itemId ? fanbase.events.find((candidate) => candidate.id === itemId) : undefined;
  const selectedGroup = area === "groups" && itemId ? fanbase.groups.find((candidate) => candidate.id === itemId) : undefined;

  const openArea = (nextArea: FanbaseAreaId) => {
    setSearchParams({ area: nextArea });
  };

  const openItem = (nextItemId: string) => {
    if (!area) return;
    setSearchParams(photoCategory ? { area, category: photoCategory, item: nextItemId } : { area, item: nextItemId });
  };

  const openPhotoCategory = (nextCategory: FanPhotoCategory) => {
    setSearchParams({ area: "fan-photos", category: nextCategory });
  };

  const openRatingItem = (nextItemId: string) => {
    if (!photoCategory) return;
    setSearchParams({ area: "fan-photos", category: photoCategory, item: nextItemId, origin: "rating-queue" });
  };

  const back = () => {
    if (area && itemId) {
      setSearchParams(photoCategory ? { area, category: photoCategory } : { area });
      return;
    }
    if (area === "fan-photos" && photoCategory) {
      setSearchParams({ area });
      return;
    }
    setSearchParams({});
  };

  const chooseTeam = (teamId: typeof selectedTeamId) => {
    selectTeam(teamId);
    setTeamFilterOpen(false);
    setSearchParams(area ? { area } : {});
  };

  const created = (createdArea: FanbaseAreaId, createdItemId: string, createdPhotoCategory?: FanPhotoCategory) => {
    setCreateOpen(false);
    setSearchParams(createdPhotoCategory ? { area: createdArea, category: createdPhotoCategory, item: createdItemId } : { area: createdArea, item: createdItemId });
  };

  const contextualCreationType = area ? ((area === "groups" && selectedGroup) || (area === "events" && selectedEvent) ? null : areaCreationTypes[area]) : null;
  const subpageContext = (() => {
    if (!area) return `${selectedTeam.name} fan community`;
    if (area === "article-comments") return `${selectedTeam.name} News discussions`;
    if (area === "locker-room") return `${selectedTeam.name} standalone team talk`;
    if (area === "game-threads") return itemId ? "Pregame, live, and post-game conversation" : `${selectedTeam.name} scheduled, live, and archived games`;
    if (area === "fan-photos") {
      const photo = itemId ? fanbase.fanPhotos.find((candidate) => candidate.id === itemId) : undefined;
      if (photo) return `${photo.category} · @${photo.owner.username}`;
      return photoCategory ? `${selectedTeam.name} · ${photoCategory}` : "Game Face, Fan Cave, and Memorabilia";
    }
    if (area === "events") {
      return selectedEvent ? `${selectedEvent.eventType} · ${formatEventDate(selectedEvent.startsAt)} · ${selectedEvent.location.label}` : `${selectedTeam.name} gatherings and watch parties`;
    }
    if (area === "polls") return `${selectedTeam.name} by default · Browse any official sport, league, or team`;
    if (area === "leaderboards") return `${selectedTeam.name} fan rankings and sports intelligence`;
    return selectedGroup ? selectedGroup.description : `${selectedTeam.name} joined and discoverable groups`;
  })();

  const backTarget = itemId ? (photoCategory ?? (area ? areaTitles[area] : "FANbase")) : photoCategory ? "Fan Photos" : "FANbase";
  const pageTitle = selectedEvent?.title ?? selectedGroup?.name ?? (area === "fan-photos" && photoCategory ? photoCategory : area ? areaTitles[area] : "FANbase");
  const contextualAction = selectedEvent
    ? { accessible: "Invite/Add People to event", visible: "Invite People" }
    : selectedGroup
      ? { accessible: "Manage group membership", visible: "Members" }
      : area ? areaActionLabels[area] : null;

  return (
    <div className="fanbase-page">
      <header className={area ? "fanbase-topbar fanbase-topbar--subpage" : "fanbase-topbar"}>
        {area ? (
          <button className="fanbase-back-trigger" type="button" aria-label={`Back to ${backTarget}`} onClick={back}><span aria-hidden="true">←</span><span className="fanbase-back-trigger__full">Back to {backTarget}</span><span className="fanbase-back-trigger__short">Back</span></button>
        ) : (
          <button className="fanbase-team-trigger" type="button" aria-label="Choose FANbase team" aria-expanded={teamFilterOpen} onClick={() => setTeamFilterOpen(true)}>
            <span aria-hidden="true">☰</span><img src={selectedTeam.logoUrl} alt="" /><span>{selectedTeam.shortName}</span>
          </button>
        )}
        <div className="fanbase-topbar__title">
          <span className="eyebrow">{area ? "FANbase" : "Community hub"}</span>
          <h1>{pageTitle}</h1>
          <p>{subpageContext}</p>
        </div>
        {area ? (
          <button
            className="fanbase-create-trigger fanbase-create-trigger--contextual"
            type="button"
            aria-label={contextualAction?.accessible}
            aria-expanded={selectedEvent ? eventInviteOpen : selectedGroup ? groupMembershipOpen : area === "polls" ? pollCreateOpen : contextualCreationType ? createOpen : undefined}
            disabled={!contextualCreationType && !selectedGroup && !selectedEvent && area !== "polls"}
            onClick={() => selectedEvent ? setEventInviteOpen(true) : selectedGroup ? setGroupMembershipOpen(true) : area === "polls" ? setPollCreateOpen(true) : contextualCreationType && setCreateOpen(true)}
          >
            <span aria-hidden="true">＋</span><span>{contextualAction?.visible}</span>
          </button>
        ) : (
          <button className="fanbase-create-trigger" type="button" aria-label="Create in FANbase" aria-expanded={createOpen} onClick={() => setCreateOpen(true)}><span aria-hidden="true">＋</span><span>Create</span></button>
        )}
      </header>

      {area ? (
        <FanbaseAreaView area={area} itemId={itemId} itemOrigin={itemOrigin} photoCategory={photoCategory} teamId={selectedTeamId} onOpenPhotoCategory={openPhotoCategory} onOpenItem={openItem} onOpenRatingItem={openRatingItem} onCloseItem={back} />
      ) : (
        <FanbaseHub teamId={selectedTeamId} onOpenArea={openArea} />
      )}

      {teamFilterOpen ? <FanbaseTeamFilter teams={followedTeams} selectedTeamId={selectedTeamId} onSelect={chooseTeam} onClose={() => setTeamFilterOpen(false)} /> : null}
      {eventInviteOpen && selectedEvent ? <EventInviteDialog event={selectedEvent} onInvite={(userIds) => fanbase.invitePeopleToEvent(selectedEvent.id, userIds)} onClose={() => setEventInviteOpen(false)} /> : null}
      {groupMembershipOpen && selectedGroup ? <GroupMembershipDialog group={selectedGroup} onInvite={(userIds) => fanbase.invitePeopleToGroup(selectedGroup.id, userIds)} onAddModerators={(userIds) => fanbase.addGroupModerators(selectedGroup.id, userIds)} onClose={() => setGroupMembershipOpen(false)} /> : null}
      {pollCreateOpen ? <PollCreateDialog polls={fanbase.polls} initialScope={pollScopeForFollowedTeam(selectedTeam)} onCreate={fanbase.createPoll} onClose={(createdPollId) => { setPollCreateOpen(false); if (createdPollId) setSearchParams({ area: "polls", item: createdPollId }); }} /> : null}
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
