import { beforeEach, describe, expect, it } from "vitest";
import { developmentCheerLibrary } from "./mockCheerData";
import {
  ASAP_GATHERING_WINDOW_MS,
  ASAP_JOIN_THRESHOLD,
  CHEER_TRIGGER_WINDOW_MS,
  GAME_MOMENT_GATHERING_WINDOW_MS,
  GAME_MOMENT_JOIN_THRESHOLD,
  MAX_ACTIVE_CHEER_PROPOSALS,
  confirmGameMomentTrigger,
  createCheerProposal,
  currentLiveUserId,
  joinCheerProposal,
  leaveCheerProposal,
  pruneExpiredCheerProposals,
  recentTriggerConfirmations,
  triggerQuorumForJoinedCount,
  type CheerProposal,
} from "./cheerLaunch";
import type { MappedVenueCheckIn } from "./types";

const checkIn: MappedVenueCheckIn = {
  type: "MappedVenue",
  raw: { method: "Manual", venueId: "venue-rexall-place", venueName: "Rexall Place", sport: "Hockey", teamEvent: "Edmonton Oilers", section: "114", row: "12", seat: "8" },
  resolved: { level: "Lower", side: "Side A", end: "End A", sources: { level: "Section mapping", side: "Section mapping", end: "Section mapping" } },
  confirmedAt: "2026-08-14T18:00:00.000Z",
};

function create(existing: readonly CheerProposal[] = [], mode: "ASAP" | "GameMoment" = "ASAP") {
  return createCheerProposal(existing, {
    cheer: developmentCheerLibrary[0]!,
    checkIn,
    mode,
    gameMoment: mode === "GameMoment" ? "Next Puck Drop" : null,
    now: 1_000,
  });
}

describe("shared Cheer Launch proposals", () => {
  beforeEach(() => window.sessionStorage.clear());

  it("caps one live-context Launch page at five active proposals", () => {
    let proposals: readonly CheerProposal[] = [];
    for (let index = 0; index < MAX_ACTIVE_CHEER_PROPOSALS; index += 1) proposals = create(proposals).proposals;
    const blocked = create(proposals);
    expect(proposals).toHaveLength(5);
    expect(blocked.proposal).toBeNull();
    expect(blocked.error).toMatch(/5 active Cheer proposals/);
  });

  it("joins, reaches the ASAP threshold, and returns to Gathering after Leave", () => {
    const proposal = create().proposal!;
    expect(proposal.joinedUserIds).toHaveLength(ASAP_JOIN_THRESHOLD - 1);
    expect(proposal.gatheringExpiresAt).toBe(1_000 + ASAP_GATHERING_WINDOW_MS);
    const joined = joinCheerProposal(proposal, currentLiveUserId, 2_000);
    expect(joined.joinedUserIds).toHaveLength(ASAP_JOIN_THRESHOLD);
    expect(joined.status).toBe("GoingLive");
    expect(joined.sharedStartAt).toBe(7_000);
    const left = leaveCheerProposal(joined, currentLiveUserId, 3_000);
    expect(left.joinedUserIds).toHaveLength(ASAP_JOIN_THRESHOLD - 1);
    expect(left.status).toBe("Gathering");
    expect(left.sharedStartAt).toBeNull();
  });

  it("arms Game Moment at 100 joins and requires 10 percent within one second", () => {
    const proposal = create([], "GameMoment").proposal!;
    expect(proposal.joinedUserIds).toHaveLength(GAME_MOMENT_JOIN_THRESHOLD - 1);
    expect(proposal.gatheringExpiresAt).toBe(1_000 + GAME_MOMENT_GATHERING_WINDOW_MS);
    const armed = joinCheerProposal(proposal, currentLiveUserId, 2_000);
    expect(armed.status).toBe("Armed");
    expect(armed.gatheringExpiresAt).toBeNull();
    expect(triggerQuorumForJoinedCount(armed.joinedUserIds.length)).toBe(10);
    expect(recentTriggerConfirmations(armed, 2_000)).toHaveLength(9);
    const triggered = confirmGameMomentTrigger(armed, currentLiveUserId, 2_001);
    expect(triggered.status).toBe("GoingLive");
    expect(triggered.sharedStartAt).toBe(7_001);

    const expiredAttempt = confirmGameMomentTrigger(armed, currentLiveUserId, 2_000 + CHEER_TRIGGER_WINDOW_MS + 1);
    expect(expiredAttempt.status).toBe("Armed");
    expect(recentTriggerConfirmations(expiredAttempt, 2_000 + CHEER_TRIGGER_WINDOW_MS + 1)).toHaveLength(1);
  });

  it("rounds the dynamic trigger quorum up and counts joined fans only", () => {
    const source = joinCheerProposal(create([], "GameMoment").proposal!, currentLiveUserId, 2_000);
    const joinedUserIds = [currentLiveUserId, ...Array.from({ length: 136 }, (_, index) => `joined-${index}`)];
    const armed: CheerProposal = {
      ...source,
      joinedUserIds,
      triggerConfirmations: joinedUserIds.slice(1, 14).map((userId) => ({ userId, confirmedAt: 3_000 })),
    };
    expect(triggerQuorumForJoinedCount(137)).toBe(14);
    expect(confirmGameMomentTrigger(armed, currentLiveUserId, 3_001).status).toBe("GoingLive");
    expect(confirmGameMomentTrigger(armed, "not-joined", 3_001)).toBe(armed);
  });

  it("expires Gathering proposals but never expires an ARMED Game Moment", () => {
    const asap = create().proposal!;
    const gameMoment = create([], "GameMoment").proposal!;
    expect(pruneExpiredCheerProposals([asap], 1_000 + ASAP_GATHERING_WINDOW_MS)).toEqual([]);
    expect(pruneExpiredCheerProposals([gameMoment], 1_000 + GAME_MOMENT_GATHERING_WINDOW_MS)).toEqual([]);

    const armed = joinCheerProposal(gameMoment, currentLiveUserId, 2_000);
    const afterLeave = leaveCheerProposal(armed, currentLiveUserId, 3_000);
    expect(afterLeave.status).toBe("Armed");
    expect(pruneExpiredCheerProposals([afterLeave], 1_000 + GAME_MOMENT_GATHERING_WINDOW_MS * 2)).toEqual([afterLeave]);
  });
});
