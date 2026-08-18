import { useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { mockFanConnections } from "./mockFanbaseData";
import type { FanEvent } from "./types";
import { AppIcon } from "../../components/AppIcon";

type EventInviteDialogProps = {
  readonly event: FanEvent;
  readonly onInvite: (userIds: readonly string[]) => void;
  readonly onClose: () => void;
};

export function EventInviteDialog({ event, onInvite, onClose }: EventInviteDialogProps) {
  const [search, setSearch] = useState("");
  const [selectedIds, setSelectedIds] = useState<readonly string[]>([]);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const matchingConnections = useMemo(() => {
    const query = search.trim().toLowerCase();
    return mockFanConnections.filter((connection) => connection.username.toLowerCase().includes(query));
  }, [search]);

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeButtonRef.current?.focus();
    const closeOnEscape = (keyboardEvent: KeyboardEvent) => keyboardEvent.key === "Escape" && onClose();
    window.addEventListener("keydown", closeOnEscape);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", closeOnEscape);
    };
  }, [onClose]);

  const toggleSelection = (userId: string) => {
    if (event.invitedUserIds.includes(userId)) return;
    setSelectedIds((current) => current.includes(userId) ? current.filter((id) => id !== userId) : [...current, userId]);
  };

  const submit = (formEvent: FormEvent<HTMLFormElement>) => {
    formEvent.preventDefault();
    if (!selectedIds.length) return;
    onInvite(selectedIds);
    onClose();
  };

  return (
    <div className="fanbase-dialog-layer fanbase-dialog-layer--centered">
      <button className="fanbase-backdrop" type="button" aria-label="Close event invitations" onClick={onClose} />
      <section className="fanbase-create group-membership-dialog" role="dialog" aria-modal="true" aria-labelledby="event-invite-title">
        <header>
          <div><span className="eyebrow">{event.eventType}</span><h2 id="event-invite-title">Invite/Add People</h2><p>{event.title}</p></div>
          <button ref={closeButtonRef} className="fanbase-icon-button" type="button" aria-label="Close event invitations" onClick={onClose}><AppIcon name="x-mark" /></button>
        </header>
        <form className="group-membership-dialog__body" onSubmit={submit}>
          <p className="fanbase-form-note">Choose FANatical friends or connections to invite. Delivery remains local-only in this mock flow.</p>
          <label>Search connections<input type="search" value={search} onChange={(changeEvent) => setSearch(changeEvent.target.value)} placeholder="Search by username" /></label>
          {selectedIds.length ? (
            <div className="fanbase-invite-picker__selected" aria-label="Selected people">
              {selectedIds.map((userId) => {
                const connection = mockFanConnections.find((candidate) => candidate.id === userId);
                return connection ? <button key={userId} type="button" aria-label={`Remove ${connection.username} from selection`} onClick={() => toggleSelection(userId)}><span className="community-avatar" aria-hidden="true">{connection.initials}</span>@{connection.username}<AppIcon name="x-mark" /></button> : null;
              })}
            </div>
          ) : <p className="fanbase-invite-picker__empty">No people selected.</p>}
          <div className="fanbase-invite-picker__list" role="group" aria-label="Mock FANatical friends and connections">
            {matchingConnections.length ? matchingConnections.map((connection) => {
              const alreadyInvited = event.invitedUserIds.includes(connection.id);
              return (
                <label key={connection.id}>
                  <input type="checkbox" checked={selectedIds.includes(connection.id)} disabled={alreadyInvited} onChange={() => toggleSelection(connection.id)} />
                  <span className="community-avatar" aria-hidden="true">{connection.initials}</span>
                  <span><strong>@{connection.username}</strong><small>{alreadyInvited ? "Already invited" : "FANatical connection"}</small></span>
                </label>
              );
            }) : <p>No connections match that search.</p>}
          </div>
          <button className="fanbase-primary-button" type="submit" disabled={!selectedIds.length}>Send invitations</button>
        </form>
      </section>
    </div>
  );
}
