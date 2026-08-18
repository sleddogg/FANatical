import { useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { AppIcon } from "../../components/AppIcon";
import { CheerFollowPlayer } from "./CheerFollowPlayer";
import { CheerListenScreen } from "./CheerListenScreen";
import { CheerReadScreen } from "./CheerReadScreen";
import { loadCheerCheckIn } from "./cheerCheckIn";
import {
  MAX_ACTIVE_CHEER_PROPOSALS,
  confirmGameMomentTrigger,
  cheerProposalsChangedEvent,
  currentLiveUserId,
  joinCheerProposal,
  launchContext,
  leaveCheerProposal,
  loadCheerProposals,
  proposalJoinThreshold,
  pruneExpiredCheerProposals,
  recentTriggerConfirmations,
  saveCheerProposals,
  triggerQuorumForJoinedCount,
  type CheerProposal,
} from "./cheerLaunch";
import { loadCheerLibrary, saveCheerLibrary } from "./cheerStorage";
import { seededCheerLibrary } from "./mockCheerData";
import type { CheerRecord } from "./types";
import "./cheer.css";

type ProposalView = "Read" | "Listen" | "Follow";

function proposalStatus(proposal: CheerProposal, now: number) {
  if (proposal.status === "GoingLive" && proposal.sharedStartAt) return `CHEER GOING LIVE IN ${Math.min(10, Math.max(0, Math.ceil((proposal.sharedStartAt - now) / 1_000)))}…`;
  if (proposal.status === "Armed") return `ARMED · Waiting for ${proposal.gameMoment}`;
  return proposal.mode === "ASAP" ? "Gathering for ASAP" : `Gathering for ${proposal.gameMoment}`;
}

function ProposalCard({ proposal, cheer, now, onOpen, onChange }: {
  readonly proposal: CheerProposal;
  readonly cheer: CheerRecord;
  readonly now: number;
  readonly onOpen: (view: ProposalView) => void;
  readonly onChange: (proposal: CheerProposal) => void;
}) {
  const joined = proposal.joinedUserIds.includes(currentLiveUserId);
  const triggerCount = recentTriggerConfirmations(proposal).length;
  const joinThreshold = proposalJoinThreshold(proposal.mode);
  const triggerQuorum = triggerQuorumForJoinedCount(proposal.joinedUserIds.length);
  return <article className="cheer-proposal-card" data-status={proposal.status.toLocaleLowerCase()}><header><div><span className="eyebrow">{proposal.mode === "ASAP" ? "ASAP" : proposal.gameMoment}</span><h2>{cheer.title}</h2><p>{cheer.description || "A fan-created Cheer ready to bring this crowd together."}</p></div><strong className="cheer-proposal-card__status">{proposalStatus(proposal, now)}</strong></header><dl><div><dt>Launched by</dt><dd>@{proposal.launchedByUsername.replace(/^@/, "")}</dd></div><div><dt>Live context</dt><dd>{proposal.contextLabel}</dd></div></dl><div className="cheer-proposal-card__content-actions" aria-label={`${cheer.title} content`}><button type="button" onClick={() => onOpen("Read")}>Read</button><button type="button" onClick={() => onOpen("Listen")}>Listen</button><button type="button" onClick={() => onOpen("Follow")}>Follow</button></div><section className="cheer-proposal-card__join" aria-label={`${cheer.title} crowd status`}><div><strong>{proposal.joinedUserIds.length} / {joinThreshold}</strong><span>fans joined</span></div><button className={joined ? "" : "cheer-primary-button"} type="button" onClick={() => onChange(joined ? leaveCheerProposal(proposal) : joinCheerProposal(proposal))}>{joined ? "Leave" : "Join"}</button></section>{proposal.status === "Armed" ? <section className="cheer-proposal-card__trigger"><div><strong>{triggerCount} / {triggerQuorum} trigger confirmations</strong><span>Confirm during the game moment. Attempts never un-arm the Cheer.</span></div>{joined ? <button className="cheer-primary-button" type="button" onClick={() => onChange(confirmGameMomentTrigger(proposal))}>Trigger Now</button> : <small>Join this Cheer to confirm the game moment.</small>}</section> : null}{proposal.status === "GoingLive" ? <aside className="cheer-proposal-card__ready" role="status"><strong>{proposalStatus(proposal, now)}</strong><span>Joined fans will open the synchronized Live screen for the five-second pre-roll.</span></aside> : null}</article>;
}

export function CheerLaunchPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [checkIn] = useState(loadCheerCheckIn);
  const [proposals, setProposals] = useState<readonly CheerProposal[]>(loadCheerProposals);
  const [now, setNow] = useState(Date.now);
  const [cheers, setCheers] = useState<readonly CheerRecord[]>(seededCheerLibrary);
  const [active, setActive] = useState<{ cheerId: string; view: ProposalView } | null>(null);
  const [discoveryPulse, setDiscoveryPulse] = useState(() => searchParams.get("source") === "live-discovery");
  const context = checkIn ? launchContext(checkIn) : null;
  const activeProposals = useMemo(() => context ? proposals.filter((proposal) => proposal.eventId === context.eventId) : [], [context, proposals]);
  const activeCheer = active ? cheers.find((cheer) => cheer.id === active.cheerId) ?? null : null;

  useEffect(() => {
    let mounted = true;
    void loadCheerLibrary().then((stored) => {
      if (!mounted || !stored) return;
      setCheers([...stored, ...seededCheerLibrary.filter((seed) => !stored.some((cheer) => cheer.id === seed.id))]);
    });
    return () => { mounted = false; };
  }, []);

  useEffect(() => {
    if (!discoveryPulse) return;
    const timeout = window.setTimeout(() => setDiscoveryPulse(false), 1_400);
    return () => window.clearTimeout(timeout);
  }, [discoveryPulse]);

  useEffect(() => {
    if (searchParams.get("source") !== "live-discovery") return;
    setDiscoveryPulse(true);
    navigate("/cheer/launch", { replace: true });
  }, [navigate, searchParams]);

  useEffect(() => {
    const proposalId = searchParams.get("proposal");
    const requestedView = searchParams.get("view");
    if (!proposalId || (requestedView !== "Read" && requestedView !== "Follow")) return;
    const proposal = proposals.find((candidate) => candidate.id === proposalId && candidate.eventId === context?.eventId);
    const cheer = proposal ? cheers.find((candidate) => candidate.id === proposal.cheerId) : null;
    if (!cheer) return;
    setActive({ cheerId: cheer.id, view: requestedView });
    navigate("/cheer/launch", { replace: true });
  }, [cheers, context?.eventId, navigate, proposals, searchParams]);

  useEffect(() => {
    const interval = window.setInterval(() => setNow(Date.now()), 100);
    return () => window.clearInterval(interval);
  }, []);

  useEffect(() => {
    const refreshProposals = () => setProposals(loadCheerProposals());
    window.addEventListener(cheerProposalsChangedEvent, refreshProposals);
    return () => window.removeEventListener(cheerProposalsChangedEvent, refreshProposals);
  }, []);

  useEffect(() => {
    const active = pruneExpiredCheerProposals(proposals, now);
    if (active.length === proposals.length) return;
    setProposals(active);
    saveCheerProposals(active);
  }, [now, proposals]);

  useEffect(() => {
    const ready = activeProposals.find((proposal) => proposal.status === "GoingLive"
      && proposal.sharedStartAt !== null
      && proposal.joinedUserIds.includes(currentLiveUserId)
      && proposal.sharedStartAt - now <= 5_000);
    if (ready) navigate(`/cheer/live/${ready.id}`);
  }, [activeProposals, navigate, now]);

  const changeProposal = (updated: CheerProposal) => {
    const next = proposals.map((proposal) => proposal.id === updated.id ? updated : proposal);
    setProposals(next);
    saveCheerProposals(next);
  };

  const updateRecording = (recordingUrl: string | null) => {
    if (!activeCheer) return;
    const next = cheers.map((cheer) => cheer.id === activeCheer.id ? { ...cheer, recordingUrl } : cheer);
    setCheers(next);
    void saveCheerLibrary(next);
  };

  if (active && activeCheer) {
    return <div className="cheer-page cheer-launch-page"><header className="cheer-topbar"><button className="cheer-topbar__back" type="button" onClick={() => setActive(null)}><AppIcon name="arrow-left" /><span>Launch Page</span></button><div><span className="eyebrow">{activeCheer.title}</span><h1>{active.view}</h1></div><span /></header>{active.view === "Read" ? <CheerReadScreen cheer={activeCheer} /> : active.view === "Listen" ? <CheerListenScreen cheer={activeCheer} onRecordingChange={updateRecording} /> : <CheerFollowPlayer cheer={activeCheer} />}</div>;
  }

  return <div className="cheer-page cheer-launch-page"><header className="cheer-topbar"><button className="cheer-topbar__back" type="button" onClick={() => navigate("/cheer")}><AppIcon name="arrow-left" /><span>Cheer Library</span></button><div><span className="eyebrow">Shared crowd proposals</span><h1>Cheer Launch</h1></div><span className="cheer-launch-page__capacity" aria-label={`${activeProposals.length} of ${MAX_ACTIVE_CHEER_PROPOSALS} active proposals`}>{activeProposals.length} / {MAX_ACTIVE_CHEER_PROPOSALS}</span></header><main className="cheer-launch-board" aria-labelledby="cheer-launch-board-title">{discoveryPulse ? <div className="cheer-live-discovery-pulse" role="status"><AppIcon name="sparkles" /><strong>LIVE CHEERS</strong><AppIcon name="sparkles" /></div> : null}<header><div><h2 id="cheer-launch-board-title">{context?.label ?? "Check in to launch"}</h2><p>Join an active proposal. Up to five Cheers can gather at once in this live context.</p></div></header>{!checkIn ? <section className="cheer-empty"><AppIcon name="information-circle" /><h2>No active Check-In</h2><p>Return to the Cheer Library and check into a mapped team/game context before launching.</p></section> : activeProposals.length ? <div className="cheer-launch-board__proposals">{activeProposals.map((proposal) => { const cheer = cheers.find((candidate) => candidate.id === proposal.cheerId); return cheer ? <ProposalCard key={proposal.id} proposal={proposal} cheer={cheer} now={now} onOpen={(view) => setActive({ cheerId: cheer.id, view })} onChange={changeProposal} /> : null; })}</div> : <section className="cheer-empty"><AppIcon name="information-circle" /><h2>No active proposals</h2><p>Launch an eligible Cheer from Available Now to add it here.</p></section>}</main></div>;
}
