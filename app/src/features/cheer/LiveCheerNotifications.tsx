import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";
import { useNavigate } from "react-router-dom";
import { cheerCheckInChangedEvent, loadCheerCheckIn } from "./cheerCheckIn";
import { isCheerLaunchEligible } from "./cheerLibrary";
import { preloadAvailableLiveVariants } from "./cheerLiveVariants";
import {
  checkInIsInProposalTarget,
  cheerProposalsChangedEvent,
  currentLiveUserId,
  joinCheerProposal,
  launchContext,
  loadCheerProposals,
  pruneStoredCheerProposals,
  updateStoredProposal,
  type CheerProposal,
} from "./cheerLaunch";
import { cheerLibraryChangedEvent, loadCheerLibrary } from "./cheerStorage";
import { seededCheerLibrary } from "./mockCheerData";
import type { CheerCheckIn, CheerRecord } from "./types";

type NoticeKind = "Discovery" | "Armed" | "GoingLive";
type LiveNotice = Readonly<{
  id: string;
  eventId: string;
  kind: NoticeKind;
  title: string;
  body: string;
  proposalId: string | null;
  joined: boolean;
}>;

const discoveryMarkerPrefix = "fanatical.live.discovery.v1";
const proposalMarkerPrefix = "fanatical.live.proposal-notification.v1";

function marker(prefix: string, suffix: string) {
  return `${prefix}:${currentLiveUserId}:${encodeURIComponent(suffix)}`;
}

function vibrate(pattern: number | number[]) {
  if (typeof navigator.vibrate === "function") navigator.vibrate(pattern);
}

export function LiveCheerNotificationProvider({ children }: { readonly children: ReactNode }) {
  const navigate = useNavigate();
  const [checkIn, setCheckIn] = useState<CheerCheckIn | null>(loadCheerCheckIn);
  const [proposals, setProposals] = useState<readonly CheerProposal[]>(pruneStoredCheerProposals);
  const [cheers, setCheers] = useState<readonly CheerRecord[]>(seededCheerLibrary);
  const [notices, setNotices] = useState<readonly LiveNotice[]>([]);
  const systemNotifications = useRef(new Map<string, Readonly<{ notification: Notification; notice: LiveNotice }>>());

  const refresh = useCallback(() => {
    setCheckIn(loadCheerCheckIn());
    setProposals(pruneStoredCheerProposals());
  }, []);

  const refreshCheers = useCallback(() => {
    void loadCheerLibrary().then((stored) => {
      if (!stored) return;
      setCheers([...stored, ...seededCheerLibrary.filter((seed) => !stored.some((cheer) => cheer.id === seed.id))]);
    });
  }, []);

  useEffect(() => {
    let mounted = true;
    void loadCheerLibrary().then((stored) => {
      if (!mounted || !stored) return;
      setCheers([...stored, ...seededCheerLibrary.filter((seed) => !stored.some((cheer) => cheer.id === seed.id))]);
    });
    return () => { mounted = false; };
  }, []);

  useEffect(() => {
    window.addEventListener(cheerProposalsChangedEvent, refresh);
    window.addEventListener(cheerCheckInChangedEvent, refresh);
    window.addEventListener(cheerLibraryChangedEvent, refreshCheers);
    const interval = window.setInterval(refresh, 500);
    return () => {
      window.removeEventListener(cheerProposalsChangedEvent, refresh);
      window.removeEventListener(cheerCheckInChangedEvent, refresh);
      window.removeEventListener(cheerLibraryChangedEvent, refreshCheers);
      window.clearInterval(interval);
    };
  }, [refresh, refreshCheers]);

  const closeNotice = useCallback((id: string) => {
    setNotices((current) => current.filter((notice) => notice.id !== id));
    systemNotifications.current.get(id)?.notification.close();
    systemNotifications.current.delete(id);
  }, []);

  const openProposal = useCallback((proposalId: string, destination: "Launch" | "Read" | "Follow" | "Live", join: boolean) => {
    const activeCheckIn = loadCheerCheckIn();
    const proposal = loadCheerProposals().find((candidate) => candidate.id === proposalId);
    if (!activeCheckIn || !proposal || proposal.eventId !== launchContext(activeCheckIn).eventId) return;
    if (join) updateStoredProposal(proposalId, (proposal) => joinCheerProposal(proposal));
    if (destination === "Live") navigate(`/cheer/live/${proposalId}`);
    else if (destination === "Read" || destination === "Follow") navigate(`/cheer/launch?proposal=${encodeURIComponent(proposalId)}&view=${destination}`);
    else navigate("/cheer/launch");
  }, [navigate]);

  const performPrimaryAction = useCallback((notice: LiveNotice) => {
    closeNotice(notice.id);
    if (notice.kind === "Discovery") navigate("/cheer/launch?source=live-discovery");
    else if (notice.kind === "GoingLive" && notice.proposalId) openProposal(notice.proposalId, "Live", !notice.joined);
    else if (notice.proposalId) openProposal(notice.proposalId, "Launch", false);
  }, [closeNotice, navigate, openProposal]);

  const emit = useCallback((notice: LiveNotice, vibration: number | number[]) => {
    vibrate(vibration);
    const foreground = document.visibilityState === "visible";
    if (!foreground && typeof Notification !== "undefined" && Notification.permission === "granted") {
      const system = new Notification(notice.title, {
        body: `${notice.body}${notice.kind === "GoingLive" && !notice.joined ? "\nJOIN" : ""}`,
        tag: notice.id,
        requireInteraction: notice.kind === "GoingLive",
      });
      system.onclick = () => {
        window.focus();
        performPrimaryAction(notice);
      };
      systemNotifications.current.set(notice.id, { notification: system, notice });
      return;
    }
    setNotices((current) => current.some((candidate) => candidate.id === notice.id) ? current : [...current, notice]);
  }, [performPrimaryAction]);

  useEffect(() => {
    if (!checkIn) return;
    const context = launchContext(checkIn);
    const current = proposals.flatMap((proposal) => {
      if (proposal.eventId !== context.eventId) return [];
      const cheer = cheers.find((candidate) => candidate.id === proposal.cheerId);
      if (!cheer) return [];
      const joined = proposal.joinedUserIds.includes(currentLiveUserId);
      const eligible = isCheerLaunchEligible(cheer, checkIn);
      return eligible || joined ? [{ proposal, cheer, eligible, joined }] : [];
    });
    preloadAvailableLiveVariants(
      cheers.filter((cheer) => isCheerLaunchEligible(cheer, checkIn)),
      checkIn,
    );

    const discoveryKey = marker(discoveryMarkerPrefix, context.eventId);
    if (current.some(({ eligible }) => eligible) && !window.localStorage.getItem(discoveryKey)) {
      window.localStorage.setItem(discoveryKey, new Date().toISOString());
      emit({ id: `discovery:${context.eventId}`, eventId: context.eventId, kind: "Discovery", title: "Live Cheers available", body: "Fans are gathering for a Live Cheer in your current event.", proposalId: null, joined: false }, 120);
    }

    for (const { proposal, cheer, eligible, joined } of current) {
      const targetRecipient = eligible && proposal.targetEnd !== null && checkInIsInProposalTarget(checkIn, proposal);
      const armedKey = marker(proposalMarkerPrefix, `${proposal.id}:armed`);
      if (proposal.status === "Armed" && (joined || targetRecipient) && !window.sessionStorage.getItem(armedKey)) {
        window.sessionStorage.setItem(armedKey, new Date().toISOString());
        emit({ id: `armed:${proposal.id}`, eventId: proposal.eventId, kind: "Armed", title: `${cheer.title} is ARMED`, body: `${proposal.gameMoment} · Read, Follow, or join the crowd now.`, proposalId: proposal.id, joined }, [90, 60, 90, 60, 90]);
      }

      const goingKey = marker(proposalMarkerPrefix, `${proposal.id}:going-live`);
      if (proposal.status === "GoingLive" && !window.sessionStorage.getItem(goingKey)) {
        window.sessionStorage.setItem(goingKey, new Date().toISOString());
        emit({ id: `going:${proposal.id}`, eventId: proposal.eventId, kind: "GoingLive", title: "CHEER GOING LIVE", body: cheer.title, proposalId: proposal.id, joined }, 600);
      }
    }
  }, [checkIn, cheers, emit, proposals]);

  useEffect(() => {
    const proposalById = new Map(proposals.map((proposal) => [proposal.id, proposal]));
    const currentEventId = checkIn ? launchContext(checkIn).eventId : null;
    setNotices((current) => current.filter((notice) => {
      if (notice.eventId !== currentEventId) return false;
      if (notice.proposalId === null) return true;
      const proposal = proposalById.get(notice.proposalId);
      if (!proposal || proposal.eventId !== currentEventId) return false;
      if (notice.kind === "GoingLive") return proposal.status === "GoingLive";
      if (notice.kind === "Armed") return proposal.status === "Armed";
      return true;
    }));
    for (const [id, entry] of systemNotifications.current) {
      const kind = id.startsWith("going:") ? "GoingLive" : id.startsWith("armed:") ? "Armed" : null;
      if (entry.notice.eventId !== currentEventId) {
        entry.notification.close();
        systemNotifications.current.delete(id);
        continue;
      }
      if (!kind) continue;
      const proposalId = id.slice(id.indexOf(":") + 1);
      const proposal = proposalById.get(proposalId);
      const remainsRelevant = proposal?.eventId === currentEventId && (kind === "GoingLive" ? proposal.status === "GoingLive" : proposal.status === "Armed");
      if (!remainsRelevant) {
        entry.notification.close();
        systemNotifications.current.delete(id);
      }
    }
  }, [checkIn, proposals]);

  return <>{children}{notices.length ? <aside className="live-notification-stack" aria-label="Live Cheer notifications">{notices.map((notice) => <section key={notice.id} className="live-notification" role="status"><header><div><span>{notice.kind === "Armed" ? "ARMED" : "LIVE CHEERS"}</span><strong>{notice.title}</strong></div><button type="button" aria-label={`Dismiss ${notice.title}`} onClick={() => closeNotice(notice.id)}>×</button></header><p>{notice.body}</p><footer>{notice.kind === "Armed" && notice.proposalId ? <><button type="button" onClick={() => { closeNotice(notice.id); openProposal(notice.proposalId!, "Read", false); }}>Read</button><button type="button" onClick={() => { closeNotice(notice.id); openProposal(notice.proposalId!, "Follow", false); }}>Follow</button>{!notice.joined ? <button type="button" onClick={() => { closeNotice(notice.id); openProposal(notice.proposalId!, "Launch", true); }}>Join</button> : null}</> : <button className="live-notification__primary" type="button" onClick={() => performPrimaryAction(notice)}>{notice.kind === "Discovery" ? "View Live Cheers" : notice.joined ? "Open Live Cheer" : "JOIN"}</button>}</footer></section>)}</aside> : null}</>;
}
