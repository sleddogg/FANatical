import { useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { CheerLivePlayer } from "./CheerLivePlayer";
import { loadCheerCheckIn } from "./cheerCheckIn";
import { loadPreloadedLiveVariant } from "./cheerLiveVariants";
import { loadCheerProposals, saveCheerProposals } from "./cheerLaunch";
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
  const proposal = proposals.find((candidate) => candidate.id === proposalId) ?? null;
  const cheer = proposal ? cheers.find((candidate) => candidate.id === proposal.cheerId) ?? null : null;
  const variant = useMemo(() => cheer ? loadPreloadedLiveVariant(cheer.id, checkIn) : null, [checkIn, cheer]);

  useEffect(() => {
    let mounted = true;
    void loadCheerLibrary().then((stored) => {
      if (!mounted || !stored) return;
      setCheers([...stored, ...seededCheerLibrary.filter((seed) => !stored.some((cheerRecord) => cheerRecord.id === seed.id))]);
    });
    return () => { mounted = false; };
  }, []);

  const complete = () => {
    saveCheerProposals(loadCheerProposals().filter((candidate) => candidate.id !== proposalId));
    navigate("/cheer/launch", { replace: true });
  };

  if (!proposal) return <main id="main-content" className="cheer-live-unavailable"><h1>Live Cheer unavailable</h1><p>This proposal is no longer active.</p><button type="button" onClick={() => navigate("/cheer/launch", { replace: true })}>Return to Cheer Launch</button></main>;
  if (!cheer) return <main id="main-content" className="cheer-live-unavailable"><h1>Loading Live Cheer…</h1></main>;
  if (!proposal.sharedStartAt || !variant) return <main id="main-content" className="cheer-live-unavailable"><h1>Live Variant unavailable</h1><p>This Cheer does not have a preloaded Live Variant for the current resolved seat.</p><button type="button" onClick={() => navigate("/cheer/launch", { replace: true })}>Return to Cheer Launch</button></main>;
  return <CheerLivePlayer cheer={cheer} variant={variant} sharedStartAt={proposal.sharedStartAt} onComplete={complete} />;
}
