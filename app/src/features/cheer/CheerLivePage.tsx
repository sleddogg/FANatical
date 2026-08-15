import { useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { CheerLivePlayer } from "./CheerLivePlayer";
import { loadCheerCheckIn } from "./cheerCheckIn";
import { loadPreloadedLiveVariant, resolveTargetRelativeLiveVariant } from "./cheerLiveVariants";
import { loadCheerProposals, proposalBelongsToCheckIn, saveCheerProposals } from "./cheerLaunch";
import { loadCheerLibrary } from "./cheerStorage";
import { seededCheerLibrary } from "./mockCheerData";
import type { CheerRecord } from "./types";
import "./cheer.css";

export function CheerLivePage() {
  const navigate = useNavigate();
  const { proposalId = "" } = useParams();
  const [checkIn] = useState(loadCheerCheckIn);
  const [proposals] = useState(loadCheerProposals);
  const [cheers, setCheers] = useState<readonly CheerRecord[]>(seededCheerLibrary);
  const [now, setNow] = useState(Date.now);
  const proposal = proposals.find((candidate) => candidate.id === proposalId) ?? null;
  const cheer = proposal ? cheers.find((candidate) => candidate.id === proposal.cheerId) ?? null : null;
  const variant = useMemo(() => {
    if (!cheer || !proposal || !checkIn) return null;
    const preloaded = loadPreloadedLiveVariant(cheer.id, checkIn);
    return preloaded ? resolveTargetRelativeLiveVariant(cheer, preloaded, checkIn, proposal.targetEnd) : null;
  }, [checkIn, cheer, proposal]);

  useEffect(() => {
    let mounted = true;
    void loadCheerLibrary().then((stored) => {
      if (!mounted || !stored) return;
      setCheers([...stored, ...seededCheerLibrary.filter((seed) => !stored.some((cheerRecord) => cheerRecord.id === seed.id))]);
    });
    return () => { mounted = false; };
  }, []);

  useEffect(() => {
    const interval = window.setInterval(() => setNow(Date.now()), 100);
    return () => window.clearInterval(interval);
  }, []);

  const complete = () => {
    saveCheerProposals(loadCheerProposals().filter((candidate) => candidate.id !== proposalId));
    navigate("/cheer/launch", { replace: true });
  };

  if (!proposal) return <main id="main-content" className="cheer-live-unavailable"><h1>Live Cheer unavailable</h1><p>This proposal is no longer active.</p><button type="button" onClick={() => navigate("/cheer/launch", { replace: true })}>Return to Cheer Launch</button></main>;
  if (!checkIn || !proposalBelongsToCheckIn(proposal, checkIn)) return <main id="main-content" className="cheer-live-unavailable"><h1>Live Cheer unavailable</h1><p>This proposal belongs to a different checked-in event.</p><button type="button" onClick={() => navigate("/cheer/launch", { replace: true })}>Return to Cheer Launch</button></main>;
  if (!cheer) return <main id="main-content" className="cheer-live-unavailable"><h1>Loading Live Cheer…</h1></main>;
  if (!proposal.sharedStartAt || !variant) return <main id="main-content" className="cheer-live-unavailable"><h1>Live Variant unavailable</h1><p>This Cheer does not have a preloaded Live Variant for the current resolved seat.</p><button type="button" onClick={() => navigate("/cheer/launch", { replace: true })}>Return to Cheer Launch</button></main>;
  if (proposal.sharedStartAt - now > 5_000) return <main id="main-content" className="cheer-live-unavailable cheer-live-unavailable--waiting"><span className="eyebrow">Live session joined</span><h1>{cheer.title}</h1><p>Preparing the synchronized five-second pre-roll…</p></main>;
  return <CheerLivePlayer cheer={cheer} variant={variant} sharedStartAt={proposal.sharedStartAt} onComplete={complete} />;
}
