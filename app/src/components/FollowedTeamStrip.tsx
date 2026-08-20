import { useCallback, useEffect, useRef, useState } from "react";
import type { TeamId } from "../domain/team";
import { useTeamContext } from "../state/TeamContext";
import type { OfficialTeamId } from "../data/officialSportsDatabase";
import { TeamBadge } from "./TeamBadge";
import { AppIcon } from "./AppIcon";
import { ManageTeamsDialog } from "./ManageTeamsDialog";

type ScrollState = Readonly<{
  canScrollBackward: boolean;
  canScrollForward: boolean;
  hasOverflow: boolean;
}>;

const initialScrollState: ScrollState = {
  canScrollBackward: false,
  canScrollForward: false,
  hasOverflow: false,
};

export function FollowedTeamStrip() {
  const { followedTeams, selectedTeam, selectedTeamId, selectTeam, addFollowedTeam, replaceFollowedTeams } = useTeamContext();
  const viewportRef = useRef<HTMLDivElement>(null);
  const manageButtonRef = useRef<HTMLButtonElement>(null);
  const [scrollState, setScrollState] = useState<ScrollState>(initialScrollState);
  const [manageTeamsOpen, setManageTeamsOpen] = useState(false);

  const updateScrollState = useCallback(() => {
    const viewport = viewportRef.current;

    if (!viewport) {
      return;
    }

    const maximumScrollLeft = Math.max(0, viewport.scrollWidth - viewport.clientWidth);
    setScrollState({
      canScrollBackward: viewport.scrollLeft > 2,
      canScrollForward: viewport.scrollLeft < maximumScrollLeft - 2,
      hasOverflow: maximumScrollLeft > 2,
    });
  }, []);

  const updateStripLayout = useCallback(() => {
    const viewport = viewportRef.current;
    const frame = viewport?.parentElement;

    if (!viewport || !frame) return;

    frame.style.removeProperty("width");
    const availableWidth = frame.clientWidth;
    const firstTeam = viewport.querySelector<HTMLElement>(".team-strip__team");
    const teamWidth = firstTeam?.offsetWidth ?? 0;
    const gap = Number.parseFloat(window.getComputedStyle(viewport).columnGap) || 0;
    const hasOverflow = viewport.scrollWidth > availableWidth + 2;

    if (hasOverflow && teamWidth > 0) {
      const pitch = teamWidth + gap;
      const fullyVisibleTeams = Math.max(1, Math.floor((availableWidth - teamWidth / 2) / pitch));
      const peekWidth = Math.min(availableWidth, fullyVisibleTeams * pitch + teamWidth / 2);
      frame.style.width = `${peekWidth}px`;
    }

    updateScrollState();
  }, [updateScrollState]);

  useEffect(() => {
    const viewport = viewportRef.current;

    if (!viewport) {
      return;
    }

    updateStripLayout();
    viewport.addEventListener("scroll", updateScrollState, { passive: true });
    window.addEventListener("resize", updateStripLayout);

    const resizeObserver = typeof ResizeObserver === "undefined" ? null : new ResizeObserver(updateStripLayout);
    const navigation = viewport.closest(".bottom-navigation");
    if (navigation) resizeObserver?.observe(navigation);

    return () => {
      viewport.removeEventListener("scroll", updateScrollState);
      window.removeEventListener("resize", updateStripLayout);
      resizeObserver?.disconnect();
    };
  }, [updateScrollState, updateStripLayout]);

  useEffect(() => {
    updateStripLayout();
  }, [followedTeams.length, updateStripLayout]);

  const handleTeamSelection = (teamId: TeamId) => {
    selectTeam(teamId);
  };

  const closeManageTeams = () => {
    setManageTeamsOpen(false);
    window.requestAnimationFrame(() => manageButtonRef.current?.focus());
  };

  return (
    <>
      <div className="team-strip" data-has-overflow={scrollState.hasOverflow}>
      <div
        className="team-strip__viewport-frame"
        data-can-scroll-backward={scrollState.canScrollBackward}
        data-can-scroll-forward={scrollState.canScrollForward}
      >
        <div className="team-strip__viewport" ref={viewportRef} role="group" aria-label="Followed teams">
          {followedTeams.map((team) => {
            const isSelected = team.id === selectedTeamId;

            return (
              <button
                key={team.id}
                className={`team-strip__team${isSelected ? " team-strip__team--selected" : ""}`}
                type="button"
                aria-label={`Select ${team.name}`}
                aria-pressed={isSelected}
                data-tooltip-label={`${team.name} · ${team.league}`}
                onClick={() => handleTeamSelection(team.id)}
              >
                <TeamBadge team={team} />
                {isSelected ? <span className="team-strip__selected-marker"><AppIcon name="check" /></span> : null}
              </button>
            );
          })}
        </div>
      </div>

      <button
        className="team-strip__manage"
        type="button"
        aria-label="Manage Teams"
        data-tooltip-label="Manage Teams"
        ref={manageButtonRef}
        onClick={() => setManageTeamsOpen(true)}
      >
        <AppIcon name="pencil-square" />
      </button>

      <span className="visually-hidden" aria-live="polite">
        Selected team: {selectedTeam.name}
      </span>
      </div>
      {manageTeamsOpen ? <ManageTeamsDialog followedTeams={followedTeams} onAdd={(teamId: OfficialTeamId) => addFollowedTeam(teamId)} onReplace={replaceFollowedTeams} onClose={closeManageTeams} /> : null}
    </>
  );
}
