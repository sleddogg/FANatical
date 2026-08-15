import type { VenueEnd } from "../internal/venues/types";
import { isTargetRelativeAudience } from "./cheerRouting";
import { hasPlayableLiveVariant } from "./cheerLiveVariants";
import type { CheerCheckIn, CheerRecord, CheerSport } from "./types";

export const cheerLaunchStorageKey = "fanatical.cheer.live-proposals.v1";
export const cheerProposalsChangedEvent = "fanatical:cheer-proposals-changed";
export const MAX_ACTIVE_CHEER_PROPOSALS = 5;
export const ASAP_JOIN_THRESHOLD = 20;
export const GAME_MOMENT_JOIN_THRESHOLD = 100;
export const ASAP_GATHERING_WINDOW_MS = 2 * 60_000;
export const GAME_MOMENT_GATHERING_WINDOW_MS = 15 * 60_000;
export const CHEER_TRIGGER_WINDOW_MS = 1_000;
export const CHEER_LIVE_COUNTDOWN_MS = 10_000;
export const currentLiveUserId = "demo-user";
export const currentLiveUsername = "Demo User";

export type CheerLaunchMode = "ASAP" | "GameMoment";
export type CheerGameMoment = "Next Field Goal" | "Next Free Throw" | "Next Puck Drop" | "Next Whistle";
export type CheerProposalStatus = "Gathering" | "Armed" | "GoingLive";
export type CheerTargetSelection = "Your End" | "Opposite End";

export type CheerTriggerConfirmation = Readonly<{
  userId: string;
  confirmedAt: number;
}>;

export type CheerProposal = Readonly<{
  id: string;
  cheerId: string;
  eventId: string;
  contextKey: string;
  contextLabel: string;
  launchedByUserId: string;
  launchedByUsername: string;
  launchedAt: number;
  mode: CheerLaunchMode;
  gameMoment: CheerGameMoment | null;
  targetSelection: CheerTargetSelection | null;
  targetEnd: VenueEnd | null;
  status: CheerProposalStatus;
  gatheringExpiresAt: number | null;
  sharedStartAt: number | null;
  joinedUserIds: readonly string[];
  triggerConfirmations: readonly CheerTriggerConfirmation[];
}>;

export const gameMomentsForSport: Readonly<Record<CheerSport, readonly CheerGameMoment[]>> = {
  Football: ["Next Field Goal"],
  Baseball: [],
  Basketball: ["Next Free Throw", "Next Whistle"],
  Hockey: ["Next Puck Drop", "Next Whistle"],
  Soccer: ["Next Whistle"],
  Generic: ["Next Whistle"],
  Other: ["Next Whistle"],
};

export function cheerUsesTargetRelativeRouting(cheer: CheerRecord) {
  return cheer.measures.some((measure) => [...measure.actionSegments, ...measure.lyricSegments]
    .some((segment) => isTargetRelativeAudience(segment.audience)));
}

export function resolveProposalTargetEnd(checkIn: CheerCheckIn, selection: CheerTargetSelection | null) {
  if (!selection || checkIn.type !== "MappedVenue") return null;
  if (selection === "Your End") return checkIn.resolved.end;
  return checkIn.resolved.end === "End A" ? "End B" : "End A";
}

export function checkInIsInProposalTarget(checkIn: CheerCheckIn, proposal: CheerProposal) {
  return checkIn.type === "MappedVenue" && proposal.targetEnd !== null && checkIn.resolved.end === proposal.targetEnd;
}

function isProposal(value: unknown): value is CheerProposal {
  if (!value || typeof value !== "object") return false;
  const candidate = value as Partial<CheerProposal>;
  return typeof candidate.id === "string"
    && typeof candidate.cheerId === "string"
    && typeof candidate.contextKey === "string"
    && (candidate.mode === "ASAP" || candidate.mode === "GameMoment")
    && (candidate.status === "Gathering" || candidate.status === "Armed" || candidate.status === "GoingLive")
    && Array.isArray(candidate.joinedUserIds)
    && Array.isArray(candidate.triggerConfirmations);
}

export function launchContext(checkIn: CheerCheckIn) {
  if (checkIn.type === "GeneralLocation") {
    const eventId = `location:${checkIn.location.contextKey}`;
    return { eventId, key: `event:${eventId}`, label: checkIn.location.name };
  }
  const eventId = checkIn.raw.eventId;
  return {
    eventId,
    key: `event:${eventId}`,
    label: `${checkIn.raw.teamEvent} · ${checkIn.raw.venueName}`,
  };
}

export function proposalBelongsToCheckIn(proposal: CheerProposal, checkIn: CheerCheckIn) {
  return proposal.eventId === launchContext(checkIn).eventId;
}

export function loadCheerProposals(): readonly CheerProposal[] {
  try {
    const parsed: unknown = JSON.parse(window.sessionStorage.getItem(cheerLaunchStorageKey) ?? "[]");
    return Array.isArray(parsed) ? parsed.filter(isProposal).map((proposal) => {
      const eventId = typeof proposal.eventId === "string" ? proposal.eventId : proposal.contextKey;
      return {
        ...proposal,
        eventId,
        contextKey: `event:${eventId}`,
        targetSelection: proposal.targetSelection === "Your End" || proposal.targetSelection === "Opposite End" ? proposal.targetSelection : null,
        targetEnd: proposal.targetEnd === "End A" || proposal.targetEnd === "End B" ? proposal.targetEnd : null,
        gatheringExpiresAt: proposal.status === "Gathering"
          ? typeof proposal.gatheringExpiresAt === "number" ? proposal.gatheringExpiresAt : proposal.launchedAt + gatheringWindowForMode(proposal.mode)
          : null,
        sharedStartAt: typeof proposal.sharedStartAt === "number" ? proposal.sharedStartAt : null,
      };
    }) : [];
  } catch {
    return [];
  }
}

export function saveCheerProposals(proposals: readonly CheerProposal[]) {
  window.sessionStorage.setItem(cheerLaunchStorageKey, JSON.stringify(proposals));
  window.dispatchEvent(new Event(cheerProposalsChangedEvent));
}

export function proposalJoinThreshold(mode: CheerLaunchMode) {
  return mode === "ASAP" ? ASAP_JOIN_THRESHOLD : GAME_MOMENT_JOIN_THRESHOLD;
}

export function gatheringWindowForMode(mode: CheerLaunchMode) {
  return mode === "ASAP" ? ASAP_GATHERING_WINDOW_MS : GAME_MOMENT_GATHERING_WINDOW_MS;
}

export function triggerQuorumForJoinedCount(joinedCount: number) {
  return Math.ceil(joinedCount * 0.1);
}

export function isCheerProposalExpired(proposal: CheerProposal, now = Date.now()) {
  return proposal.status === "Gathering" && proposal.gatheringExpiresAt !== null && now >= proposal.gatheringExpiresAt;
}

export function pruneExpiredCheerProposals(proposals: readonly CheerProposal[], now = Date.now()) {
  return proposals.filter((proposal) => !isCheerProposalExpired(proposal, now));
}

export function pruneStoredCheerProposals(now = Date.now()) {
  const current = loadCheerProposals();
  const active = pruneExpiredCheerProposals(current, now);
  if (active.length !== current.length) saveCheerProposals(active);
  return active;
}

function mockJoinedUsers(mode: CheerLaunchMode) {
  return Array.from({ length: proposalJoinThreshold(mode) - 1 }, (_, index) => `mock-crowd-${index + 1}`);
}

export function createCheerProposal(existing: readonly CheerProposal[], input: {
  readonly cheer: CheerRecord;
  readonly checkIn: CheerCheckIn;
  readonly mode: CheerLaunchMode;
  readonly gameMoment: CheerGameMoment | null;
  readonly targetSelection?: CheerTargetSelection | null;
  readonly now?: number;
}): Readonly<{ proposals: readonly CheerProposal[]; proposal: CheerProposal | null; error: string | null }> {
  const now = input.now ?? Date.now();
  const active = pruneExpiredCheerProposals(existing, now);
  const context = launchContext(input.checkIn);
  const activeInContext = active.filter((proposal) => proposal.eventId === context.eventId);
  if (activeInContext.length >= MAX_ACTIVE_CHEER_PROPOSALS) {
    return { proposals: active, proposal: null, error: "This Launch page already has 5 active Cheer proposals." };
  }
  if (input.mode === "GameMoment" && !input.gameMoment) {
    return { proposals: active, proposal: null, error: "Choose a game moment before launching this Cheer." };
  }
  const targetSelection = input.targetSelection ?? null;
  if (cheerUsesTargetRelativeRouting(input.cheer) && (input.checkIn.type !== "MappedVenue" || !targetSelection)) {
    return { proposals: active, proposal: null, error: "Choose which end this Cheer targets before launching." };
  }
  if (!hasPlayableLiveVariant(input.cheer, input.checkIn)) {
    return { proposals: active, proposal: null, error: "This Cheer does not have a playable Live Variant for your resolved seat." };
  }

  const proposal: CheerProposal = {
    id: `cheer-proposal-${crypto.randomUUID()}`,
    cheerId: input.cheer.id,
    eventId: context.eventId,
    contextKey: context.key,
    contextLabel: context.label,
    launchedByUserId: currentLiveUserId,
    launchedByUsername: currentLiveUsername,
    launchedAt: now,
    mode: input.mode,
    gameMoment: input.mode === "GameMoment" ? input.gameMoment : null,
    targetSelection: cheerUsesTargetRelativeRouting(input.cheer) ? targetSelection : null,
    targetEnd: cheerUsesTargetRelativeRouting(input.cheer) ? resolveProposalTargetEnd(input.checkIn, targetSelection) : null,
    status: "Gathering",
    gatheringExpiresAt: now + gatheringWindowForMode(input.mode),
    sharedStartAt: null,
    // The first pass starts near threshold so one local user can exercise the
    // shared crowd transitions without authentication or realtime clients.
    joinedUserIds: mockJoinedUsers(input.mode),
    triggerConfirmations: [],
  };
  return { proposals: [...active, proposal], proposal, error: null };
}

function mockTriggerConfirmations(proposal: CheerProposal, now: number): readonly CheerTriggerConfirmation[] {
  return proposal.joinedUserIds.slice(0, Math.max(0, triggerQuorumForJoinedCount(proposal.joinedUserIds.length) - 1)).map((userId) => ({ userId, confirmedAt: now }));
}

function reconcileProposal(proposal: CheerProposal, now: number): CheerProposal {
  if (proposal.mode === "GameMoment" && proposal.status === "Armed") return { ...proposal, gatheringExpiresAt: null };
  if (proposal.joinedUserIds.length < proposalJoinThreshold(proposal.mode)) {
    return { ...proposal, status: "Gathering", sharedStartAt: null, triggerConfirmations: [] };
  }
  if (proposal.status === "GoingLive") return { ...proposal, gatheringExpiresAt: null, sharedStartAt: proposal.sharedStartAt ?? now + CHEER_LIVE_COUNTDOWN_MS };
  if (proposal.mode === "ASAP") return { ...proposal, status: "GoingLive", gatheringExpiresAt: null, sharedStartAt: proposal.sharedStartAt ?? now + CHEER_LIVE_COUNTDOWN_MS, triggerConfirmations: [] };
  return {
    ...proposal,
    status: "Armed",
    gatheringExpiresAt: null,
    sharedStartAt: null,
    triggerConfirmations: proposal.status === "Armed" && proposal.triggerConfirmations.length
      ? proposal.triggerConfirmations
      : mockTriggerConfirmations(proposal, now),
  };
}

export function joinCheerProposal(proposal: CheerProposal, userId = currentLiveUserId, now = Date.now()): CheerProposal {
  if (proposal.joinedUserIds.includes(userId) || isCheerProposalExpired(proposal, now)) return proposal;
  return reconcileProposal({ ...proposal, joinedUserIds: [...proposal.joinedUserIds, userId] }, now);
}

export function leaveCheerProposal(proposal: CheerProposal, userId = currentLiveUserId, now = Date.now()): CheerProposal {
  return reconcileProposal({
    ...proposal,
    joinedUserIds: proposal.joinedUserIds.filter((candidate) => candidate !== userId),
    triggerConfirmations: proposal.triggerConfirmations.filter((confirmation) => confirmation.userId !== userId),
  }, now);
}

export function recentTriggerConfirmations(proposal: CheerProposal, now = Date.now()) {
  return proposal.triggerConfirmations.filter((confirmation) => proposal.joinedUserIds.includes(confirmation.userId) && now - confirmation.confirmedAt <= CHEER_TRIGGER_WINDOW_MS);
}

export function confirmGameMomentTrigger(proposal: CheerProposal, userId = currentLiveUserId, now = Date.now()): CheerProposal {
  if (proposal.status !== "Armed" || !proposal.joinedUserIds.includes(userId)) return proposal;
  const recent = recentTriggerConfirmations(proposal, now).filter((confirmation) => confirmation.userId !== userId);
  const triggerConfirmations = [...recent, { userId, confirmedAt: now }];
  const triggerQuorum = triggerQuorumForJoinedCount(proposal.joinedUserIds.length);
  return {
    ...proposal,
    triggerConfirmations,
    status: triggerConfirmations.length >= triggerQuorum ? "GoingLive" : "Armed",
    sharedStartAt: triggerConfirmations.length >= triggerQuorum ? now + CHEER_LIVE_COUNTDOWN_MS : null,
  };
}

export function updateStoredProposal(proposalId: string, update: (proposal: CheerProposal) => CheerProposal) {
  const proposals = loadCheerProposals().map((proposal) => proposal.id === proposalId ? update(proposal) : proposal);
  saveCheerProposals(proposals);
  return proposals;
}
