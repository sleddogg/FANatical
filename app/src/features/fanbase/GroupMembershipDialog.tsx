import { useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { mockFanConnections } from "./mockFanbaseData";
import type { FanGroup } from "./types";

type MembershipAction = "invite" | "moderator";

type GroupMembershipDialogProps = {
  readonly group: FanGroup;
  readonly onInvite: (userIds: readonly string[]) => void;
  readonly onAddModerators: (userIds: readonly string[]) => void;
  readonly onClose: () => void;
};

export function GroupMembershipDialog({ group, onInvite, onAddModerators, onClose }: GroupMembershipDialogProps) {
  const [action, setAction] = useState<MembershipAction>("invite");
  const [search, setSearch] = useState("");
  const [selectedIds, setSelectedIds] = useState<readonly string[]>([]);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const canInvite = group.viewerRole === "Owner" || group.viewerRole === "Moderator";
  const canAddModerators = group.viewerRole === "Owner";
  const canManage = canInvite || canAddModerators;
  const matchingConnections = useMemo(() => {
    const query = search.trim().toLowerCase();
    return mockFanConnections.filter((connection) => connection.username.toLowerCase().includes(query));
  }, [search]);

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeButtonRef.current?.focus();
    const closeOnEscape = (event: KeyboardEvent) => event.key === "Escape" && onClose();
    window.addEventListener("keydown", closeOnEscape);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", closeOnEscape);
    };
  }, [onClose]);

  const chooseAction = (nextAction: MembershipAction) => {
    setAction(nextAction);
    setSelectedIds([]);
    setSearch("");
  };

  const unavailableReason = (userId: string) => {
    if (action === "moderator") return group.moderatorUserIds.includes(userId) ? "Already a moderator" : null;
    if (group.memberUserIds.includes(userId)) return "Already a member";
    if (group.invitedUserIds.includes(userId)) return "Already invited";
    return null;
  };

  const toggleSelection = (userId: string) => {
    if (unavailableReason(userId)) return;
    setSelectedIds((current) => current.includes(userId) ? current.filter((id) => id !== userId) : [...current, userId]);
  };

  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!selectedIds.length) return;
    if (action === "moderator") onAddModerators(selectedIds);
    else onInvite(selectedIds);
    onClose();
  };

  const visibilityGuidance = group.visibility === "Public"
    ? "Invited fans can join this public group from its listing."
    : group.visibility === "Private"
      ? "Only invited people can access this private group."
      : "Membership in this group begins with an invitation.";

  return (
    <div className="fanbase-dialog-layer fanbase-dialog-layer--centered">
      <button className="fanbase-backdrop" type="button" aria-label="Close group membership" onClick={onClose} />
      <section className="fanbase-create group-membership-dialog" role="dialog" aria-modal="true" aria-labelledby="group-membership-title">
        <header>
          <div><span className="eyebrow">{group.visibility} group · {group.viewerRole ?? "Not joined"}</span><h2 id="group-membership-title">Group membership</h2><p>{group.name}</p></div>
          <button ref={closeButtonRef} className="fanbase-icon-button" type="button" aria-label="Close group membership" onClick={onClose}>×</button>
        </header>
        {canManage ? (
          <form className="group-membership-dialog__body" onSubmit={submit}>
            <div className="group-membership-dialog__actions" role="group" aria-label="Membership action">
              <button type="button" aria-pressed={action === "invite"} onClick={() => chooseAction("invite")}>Invite/Add People</button>
              {canAddModerators ? <button type="button" aria-pressed={action === "moderator"} onClick={() => chooseAction("moderator")}>Add as Moderator</button> : null}
            </div>
            <p className="fanbase-form-note">{action === "moderator" ? "Owners can promote an existing or newly added connection to moderator in this mock flow." : visibilityGuidance}</p>
            <label>Search connections<input type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search by username" /></label>
            {selectedIds.length ? (
              <div className="fanbase-invite-picker__selected" aria-label="Selected people">
                {selectedIds.map((userId) => {
                  const connection = mockFanConnections.find((candidate) => candidate.id === userId);
                  return connection ? <button key={userId} type="button" aria-label={`Remove ${connection.username} from selection`} onClick={() => toggleSelection(userId)}><span className="community-avatar" aria-hidden="true">{connection.initials}</span>@{connection.username}<span aria-hidden="true">×</span></button> : null;
                })}
              </div>
            ) : <p className="fanbase-invite-picker__empty">No people selected.</p>}
            <div className="fanbase-invite-picker__list" role="group" aria-label="Mock FANatical friends and connections">
              {matchingConnections.length ? matchingConnections.map((connection) => {
                const reason = unavailableReason(connection.id);
                return (
                  <label key={connection.id}>
                    <input type="checkbox" checked={selectedIds.includes(connection.id)} disabled={reason !== null} onChange={() => toggleSelection(connection.id)} />
                    <span className="community-avatar" aria-hidden="true">{connection.initials}</span>
                    <span><strong>@{connection.username}</strong><small>{reason ?? "FANatical connection"}</small></span>
                  </label>
                );
              }) : <p>No connections match that search.</p>}
            </div>
            <button className="fanbase-primary-button" type="submit" disabled={!selectedIds.length}>{action === "moderator" ? "Add moderators" : "Send invitations"}</button>
          </form>
        ) : (
          <div className="group-membership-dialog__restricted"><span className="community-avatar" aria-hidden="true">{group.name.split(" ").map((word) => word[0]).slice(0, 2).join("")}</span><strong>Membership is managed by group owners and moderators.</strong><p>{group.joined ? "You can participate in the conversation as a member." : group.visibility === "Public" ? "Join this public group before participating." : "An invitation is required to join this group."}</p></div>
        )}
      </section>
    </div>
  );
}
