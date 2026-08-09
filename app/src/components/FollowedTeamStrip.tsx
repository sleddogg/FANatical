import { useCallback, useEffect, useRef, useState } from "react";
import type { TeamId } from "../domain/team";
import { useTeamContext } from "../state/TeamContext";

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
  const { followedTeams, selectedTeam, selectedTeamId, selectTeam } = useTeamContext();
  const viewportRef = useRef<HTMLDivElement>(null);
  const [scrollState, setScrollState] = useState<ScrollState>(initialScrollState);

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

  useEffect(() => {
    const viewport = viewportRef.current;

    if (!viewport) {
      return;
    }

    updateScrollState();
    viewport.addEventListener("scroll", updateScrollState, { passive: true });
    window.addEventListener("resize", updateScrollState);

    const resizeObserver = typeof ResizeObserver === "undefined" ? null : new ResizeObserver(updateScrollState);
    resizeObserver?.observe(viewport);

    return () => {
      viewport.removeEventListener("scroll", updateScrollState);
      window.removeEventListener("resize", updateScrollState);
      resizeObserver?.disconnect();
    };
  }, [updateScrollState]);

  const browseTeams = (direction: -1 | 1) => {
    const viewport = viewportRef.current;

    if (!viewport) {
      return;
    }

    viewport.scrollBy({
      left: direction * Math.max(96, viewport.clientWidth * 0.72),
      behavior: "smooth",
    });
  };

  const handleTeamSelection = (teamId: TeamId) => {
    selectTeam(teamId);
  };

  return (
    <div className="team-strip" data-has-overflow={scrollState.hasOverflow}>
      <button
        className="team-strip__arrow team-strip__arrow--previous"
        type="button"
        aria-label="Browse previous followed teams"
        disabled={!scrollState.canScrollBackward}
        onClick={() => browseTeams(-1)}
      >
        <span aria-hidden="true">‹</span>
      </button>

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
                title={`${team.name} · ${team.league}`}
                onClick={() => handleTeamSelection(team.id)}
              >
                <img src={team.logoUrl} alt="" onLoad={updateScrollState} />
                {isSelected ? <span className="team-strip__selected-marker" aria-hidden="true">✓</span> : null}
              </button>
            );
          })}
        </div>
      </div>

      <button
        className="team-strip__arrow team-strip__arrow--next"
        type="button"
        aria-label="Browse more followed teams"
        disabled={!scrollState.canScrollForward}
        onClick={() => browseTeams(1)}
      >
        <span aria-hidden="true">›</span>
      </button>

      <button
        className="team-strip__add"
        type="button"
        aria-label="Add Team (coming later)"
        title="Add Team will be implemented in a later task"
        disabled
      >
        <span aria-hidden="true">+</span>
      </button>

      <span className="visually-hidden" aria-live="polite">
        Selected team: {selectedTeam.name}
      </span>
    </div>
  );
}
