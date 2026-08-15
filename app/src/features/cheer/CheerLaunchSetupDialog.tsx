import { useState } from "react";
import { ASAP_JOIN_THRESHOLD, GAME_MOMENT_JOIN_THRESHOLD, cheerUsesTargetRelativeRouting, gameMomentsForSport, type CheerGameMoment, type CheerLaunchMode, type CheerTargetSelection } from "./cheerLaunch";
import type { CheerCheckIn, CheerRecord } from "./types";

export function CheerLaunchSetupDialog({ cheer, checkIn, onCancel, onLaunch }: {
  readonly cheer: CheerRecord;
  readonly checkIn: CheerCheckIn;
  readonly onCancel: () => void;
  readonly onLaunch: (mode: CheerLaunchMode, gameMoment: CheerGameMoment | null, targetSelection: CheerTargetSelection | null) => string | null;
}) {
  const moments = gameMomentsForSport[cheer.sport];
  const [mode, setMode] = useState<CheerLaunchMode>("ASAP");
  const [gameMoment, setGameMoment] = useState<CheerGameMoment | null>(moments[0] ?? null);
  const [targetSelection, setTargetSelection] = useState<CheerTargetSelection>("Your End");
  const [error, setError] = useState("");

  const submit = () => {
    const nextError = onLaunch(mode, mode === "GameMoment" ? gameMoment : null, cheerUsesTargetRelativeRouting(cheer) ? targetSelection : null);
    setError(nextError ?? "");
  };

  return <div className="cheer-dialog-layer"><button className="cheer-dialog-backdrop" type="button" aria-label="Cancel launching Cheer" onClick={onCancel} /><section className="cheer-launch-setup" role="dialog" aria-modal="true" aria-labelledby="launch-cheer-title"><span className="eyebrow">Add to the shared Launch page</span><h2 id="launch-cheer-title">Launch {cheer.title}</h2><p>Choose how this Cheer should gather the crowd.</p><fieldset><legend>Launch mode</legend><label><input type="radio" name="launch-mode" value="ASAP" checked={mode === "ASAP"} onChange={() => setMode("ASAP")} /><span><strong>ASAP</strong><small>Go live as soon as {ASAP_JOIN_THRESHOLD} fans have joined.</small></span></label><label data-disabled={!moments.length || undefined}><input type="radio" name="launch-mode" value="GameMoment" checked={mode === "GameMoment"} disabled={!moments.length} onChange={() => setMode("GameMoment")} /><span><strong>Game Moment</strong><small>{moments.length ? `Arm at ${GAME_MOMENT_JOIN_THRESHOLD} joins, then wait for crowd confirmations.` : `No ${cheer.sport} game moments are configured yet.`}</small></span></label></fieldset>{cheerUsesTargetRelativeRouting(cheer) ? <fieldset><legend>Which end?</legend><div className="cheer-launch-setup__moments"><button type="button" aria-pressed={targetSelection === "Your End"} onClick={() => setTargetSelection("Your End")}>Your End{checkIn.type === "MappedVenue" ? ` · ${checkIn.resolved.end}` : ""}</button><button type="button" aria-pressed={targetSelection === "Opposite End"} onClick={() => setTargetSelection("Opposite End")}>Opposite End{checkIn.type === "MappedVenue" ? ` · ${checkIn.resolved.end === "End A" ? "End B" : "End A"}` : ""}</button></div></fieldset> : null}{mode === "GameMoment" ? <fieldset><legend>Game moment</legend><div className="cheer-launch-setup__moments">{moments.map((moment) => <button key={moment} type="button" aria-pressed={gameMoment === moment} onClick={() => setGameMoment(moment)}>{moment}</button>)}</div></fieldset> : null}{error ? <p className="cheer-launch-setup__error" role="alert">{error}</p> : null}<footer><button type="button" onClick={onCancel}>Cancel</button><button className="cheer-primary-button" type="button" onClick={submit}>Add to Launch Page</button></footer></section></div>;
}
