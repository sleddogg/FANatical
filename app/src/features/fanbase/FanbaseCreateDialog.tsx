import { useEffect, useRef, useState, type FormEvent } from "react";
import type { FollowedTeam } from "../../domain/team";
import type {
  CreateEventInput,
  CreateFanPhotoInput,
  CreateGroupInput,
  CreateLockerRoomInput,
  FanbaseAreaId,
} from "./types";
import { mockFanConnections } from "./mockFanbaseData";

export type FanbaseCreationType = "locker" | "photo" | "event" | "group";

type FanbaseCreateDialogProps = {
  readonly team: FollowedTeam;
  readonly initialCreationType?: FanbaseCreationType;
  readonly onCreateLocker: (input: CreateLockerRoomInput) => string;
  readonly onCreatePhoto: (input: CreateFanPhotoInput) => string;
  readonly onCreateEvent: (input: CreateEventInput) => string;
  readonly onCreateGroup: (input: CreateGroupInput) => string;
  readonly onCreated: (area: FanbaseAreaId, itemId: string, photoCategory?: CreateFanPhotoInput["category"]) => void;
  readonly onClose: () => void;
};

const creationLabels: Record<FanbaseCreationType, string> = {
  locker: "Locker Room thread",
  photo: "Fan Photo",
  event: "Event",
  group: "Group",
};

function readFormValue(formData: FormData, key: string) {
  return String(formData.get(key) ?? "").trim();
}

function ConnectionInvitePicker({ selectedIds, onToggle }: { readonly selectedIds: readonly string[]; readonly onToggle: (userId: string) => void }) {
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState("");
  const matchingConnections = mockFanConnections.filter((connection) => connection.username.toLowerCase().includes(search.trim().toLowerCase()));

  return (
    <section className="fanbase-invite-picker" aria-labelledby="fanbase-invite-picker-title">
      <div className="fanbase-invite-picker__heading">
        <div><strong id="fanbase-invite-picker-title">Invite Fans</strong><small>Optional · mock FANatical connections</small></div>
        <button type="button" aria-expanded={open} onClick={() => setOpen((current) => !current)}>{open ? "Done" : "Choose fans"}</button>
      </div>
      {selectedIds.length ? (
        <div className="fanbase-invite-picker__selected" aria-label="Selected invitees">
          {selectedIds.map((userId) => {
            const connection = mockFanConnections.find((candidate) => candidate.id === userId);
            return connection ? <button key={userId} type="button" aria-label={`Remove ${connection.username} from invites`} onClick={() => onToggle(userId)}><span className="community-avatar" aria-hidden="true">{connection.initials}</span>@{connection.username}<span aria-hidden="true">×</span></button> : null;
          })}
        </div>
      ) : <p className="fanbase-invite-picker__empty">No fans selected.</p>}
      {open ? (
        <div className="fanbase-invite-picker__panel">
          <label>Search connections<input type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search by username" /></label>
          <div className="fanbase-invite-picker__list" role="group" aria-label="Mock FANatical friends and connections">
            {matchingConnections.length ? matchingConnections.map((connection) => (
              <label key={connection.id}>
                <input type="checkbox" checked={selectedIds.includes(connection.id)} onChange={() => onToggle(connection.id)} />
                <span className="community-avatar" aria-hidden="true">{connection.initials}</span>
                <span><strong>@{connection.username}</strong><small>FANatical connection</small></span>
              </label>
            )) : <p>No connections match that search.</p>}
          </div>
        </div>
      ) : null}
    </section>
  );
}

export function FanbaseCreateDialog({
  team,
  initialCreationType,
  onCreateLocker,
  onCreatePhoto,
  onCreateEvent,
  onCreateGroup,
  onCreated,
  onClose,
}: FanbaseCreateDialogProps) {
  const [creationType, setCreationType] = useState<FanbaseCreationType | null>(initialCreationType ?? null);
  const [selectedInviteeIds, setSelectedInviteeIds] = useState<readonly string[]>([]);
  const closeButtonRef = useRef<HTMLButtonElement>(null);

  const toggleInvitee = (userId: string) => {
    setSelectedInviteeIds((current) => current.includes(userId) ? current.filter((id) => id !== userId) : [...current, userId]);
  };

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeButtonRef.current?.focus();
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [onClose]);

  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!creationType) {
      return;
    }
    const formData = new FormData(event.currentTarget);
    if (creationType === "locker") {
      const id = onCreateLocker({
        teamId: team.id,
        title: readFormValue(formData, "title"),
        category: readFormValue(formData, "category"),
        body: readFormValue(formData, "body"),
      });
      onCreated("locker-room", id);
    } else if (creationType === "photo") {
      const category = readFormValue(formData, "category") as CreateFanPhotoInput["category"];
      const id = onCreatePhoto({
        teamId: team.id,
        title: readFormValue(formData, "title"),
        category,
        details: readFormValue(formData, "details"),
      });
      onCreated("fan-photos", id, category);
    } else if (creationType === "event") {
      const id = onCreateEvent({
        teamId: team.id,
        title: readFormValue(formData, "title"),
        eventType: readFormValue(formData, "eventType") as CreateEventInput["eventType"],
        startsAt: new Date(readFormValue(formData, "startsAt")).toISOString(),
        location: { label: readFormValue(formData, "location") },
        visibility: readFormValue(formData, "visibility") as CreateEventInput["visibility"],
        description: readFormValue(formData, "description"),
        invitedUserIds: selectedInviteeIds,
      });
      onCreated("events", id);
    } else {
      const id = onCreateGroup({
        teamId: team.id,
        name: readFormValue(formData, "name"),
        visibility: readFormValue(formData, "visibility") as CreateGroupInput["visibility"],
        description: readFormValue(formData, "description"),
        invitedUserIds: selectedInviteeIds,
      });
      onCreated("groups", id);
    }
  };

  return (
    <div className="fanbase-dialog-layer fanbase-dialog-layer--centered">
      <button className="fanbase-backdrop" type="button" aria-label="Close Create" onClick={onClose} />
      <section className="fanbase-create" role="dialog" aria-modal="true" aria-labelledby="fanbase-create-title">
        <header>
          <div>
            <span className="eyebrow">Creating for {team.shortName}</span>
            <h2 id="fanbase-create-title">{creationType ? creationLabels[creationType] : "Create in FANbase"}</h2>
          </div>
          <button ref={closeButtonRef} className="fanbase-icon-button" type="button" aria-label="Close Create" onClick={onClose}>×</button>
        </header>

        {!creationType ? (
          <div className="fanbase-create__options">
            <button type="button" onClick={() => setCreationType("locker")}><span aria-hidden="true">▤</span><span><strong>Locker Room thread</strong><small>Start standalone team talk</small></span></button>
            <button type="button" onClick={() => setCreationType("photo")}><span aria-hidden="true">▧</span><span><strong>Fan Photo</strong><small>Share Game Face, Fan Cave, or Memorabilia</small></span></button>
            <button type="button" onClick={() => setCreationType("event")}><span aria-hidden="true">◫</span><span><strong>Event</strong><small>Organize a watch party or meetup</small></span></button>
            <button type="button" onClick={() => setCreationType("group")}><span aria-hidden="true">◉</span><span><strong>Group</strong><small>Create a smaller fan community</small></span></button>
          </div>
        ) : (
          <form className="fanbase-create__form" onSubmit={submit}>
            {!initialCreationType ? <button className="fanbase-text-button" type="button" onClick={() => setCreationType(null)}>← Creation options</button> : null}

            {creationType === "locker" ? (
              <>
                <label>Thread title<input name="title" required maxLength={100} /></label>
                <label>Category<select name="category" defaultValue="General Team Talk"><option>General Team Talk</option><option>Coaching Tactics</option><option>Roster Talk</option><option>Rivalry</option></select></label>
                <label>Opening post<textarea name="body" required rows={5} maxLength={1200} /></label>
              </>
            ) : null}

            {creationType === "photo" ? (
              <>
                <div className="fanbase-create__mock-upload"><img src={team.logoUrl} alt="" /><span>Mock artwork for this local-only photo flow</span><small>Real uploads and image processing are intentionally deferred.</small></div>
                <label>Photo title<input name="title" required maxLength={80} /></label>
                <label>Category<select name="category" defaultValue="Game Face"><option>Game Face</option><option>Fan Cave</option><option>Memorabilia</option></select></label>
                <label>Details<textarea name="details" required rows={4} maxLength={600} /></label>
              </>
            ) : null}

            {creationType === "event" ? (
              <>
                <label>Event title<input name="title" required maxLength={100} /></label>
                <div className="fanbase-form-row">
                  <label>Type<select name="eventType" defaultValue="Watch Party"><option>Watch Party</option><option>Meetup</option><option>Rivalry Event</option><option>Online Event</option></select></label>
                  <label>Visibility<select name="visibility" defaultValue="Private"><option>Private</option><option>Public</option></select></label>
                </div>
                <label>Date and time<input name="startsAt" type="datetime-local" required /></label>
                <label>Location or online label<input name="location" required maxLength={120} /></label>
                <label>Description<textarea name="description" required rows={4} maxLength={800} /></label>
                <ConnectionInvitePicker selectedIds={selectedInviteeIds} onToggle={toggleInvitee} />
                <p className="fanbase-form-note">Public event promotion may require review when backend moderation is added.</p>
              </>
            ) : null}

            {creationType === "group" ? (
              <>
                <label>Group name<input name="name" required maxLength={80} /></label>
                <label>Visibility<select name="visibility" defaultValue="Private"><option>Public</option><option>Private</option><option>Invite Only</option></select></label>
                <label>Description<textarea name="description" required rows={5} maxLength={800} /></label>
                <ConnectionInvitePicker selectedIds={selectedInviteeIds} onToggle={toggleInvitee} />
                <p className="fanbase-form-note">Visibility is represented for the demo; final discovery and invitation rules remain a product To-Do.</p>
              </>
            ) : null}

            <button className="fanbase-primary-button" type="submit">Create {creationLabels[creationType]}</button>
          </form>
        )}
      </section>
    </div>
  );
}
