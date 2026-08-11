import { useEffect, useState } from "react";
import type { CheerCheckIn } from "./types";

const levels = ["Upper", "Lower"] as const;
const eastWestOptions = ["East", "West"] as const;
const northSouthOptions = ["North", "South"] as const;

export function CheerCheckInDialog({ initial, onSave, onClear, onClose }: {
  readonly initial: CheerCheckIn | null;
  readonly onSave: (selection: CheerCheckIn) => void;
  readonly onClear: () => void;
  readonly onClose: () => void;
}) {
  const [selection, setSelection] = useState<CheerCheckIn>(initial ?? { level: "Upper", eastWest: "East", northSouth: "North" });

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const onKeyDown = (event: KeyboardEvent) => event.key === "Escape" && onClose();
    window.addEventListener("keydown", onKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [onClose]);

  return (
    <div className="cheer-dialog-layer">
      <button className="cheer-dialog-backdrop" type="button" aria-label="Close Check In" onClick={onClose} />
      <section className="cheer-check-in" role="dialog" aria-modal="true" aria-labelledby="cheer-check-in-title">
        <header><div><span className="eyebrow">Manual stadium location</span><h2 id="cheer-check-in-title">Check In</h2></div><button type="button" aria-label="Close Check In" onClick={onClose}>×</button></header>
        <p>Choose one option from each pair. FANatical uses these three attributes to show the Cheer instructions intended for your area.</p>
        <div className="cheer-check-in__stadium" aria-hidden="true"><span>N</span><span>W</span><div><b>{selection.level}</b><small>{selection.eastWest} · {selection.northSouth}</small></div><span>E</span><span>S</span></div>
        <fieldset><legend>Level</legend><div>{levels.map((value) => <button key={value} type="button" aria-pressed={selection.level === value} onClick={() => setSelection((current) => ({ ...current, level: value }))}>{value}</button>)}</div></fieldset>
        <fieldset><legend>East / West half</legend><div>{eastWestOptions.map((value) => <button key={value} type="button" aria-pressed={selection.eastWest === value} onClick={() => setSelection((current) => ({ ...current, eastWest: value }))}>{value}</button>)}</div></fieldset>
        <fieldset><legend>North / South half</legend><div>{northSouthOptions.map((value) => <button key={value} type="button" aria-pressed={selection.northSouth === value} onClick={() => setSelection((current) => ({ ...current, northSouth: value }))}>{value}</button>)}</div></fieldset>
        <div className="cheer-check-in__actions">{initial ? <button type="button" onClick={onClear}>Check Out</button> : null}<button className="cheer-primary-button" type="button" onClick={() => onSave(selection)}>Save Check In</button></div>
      </section>
    </div>
  );
}
