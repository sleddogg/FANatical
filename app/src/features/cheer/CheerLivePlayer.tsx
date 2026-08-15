import { useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { cheerActionIcon, cheerDurationSymbol } from "./cheerPresentation";
import { CHEER_PLAYBACK_BPM, MEASURE_CAPACITY_UNITS } from "./cheerUtils";
import type { CheerLiveActionSegment, CheerLiveLyricSegment, CheerLiveMeasure, CheerLiveRestSegment, CheerLiveVariant, CheerRecord } from "./types";

type LiveSegment = CheerLiveActionSegment | CheerLiveLyricSegment | CheerLiveRestSegment;

function segmentStyle(startUnit: number, units: number): CSSProperties {
  return { gridColumn: `${startUnit + 1} / span ${units}` };
}

function LiveLane({ label, playhead, children }: { readonly label: string; readonly playhead: number | null; readonly children: ReactNode }) {
  return <div className="cheer-live-lane"><strong>{label}</strong><div>{children}{playhead !== null ? <i className="cheer-live-playhead" aria-hidden="true" style={{ left: `${(playhead / MEASURE_CAPACITY_UNITS) * 100}%` }} /> : null}</div></div>;
}

function isActive(segment: LiveSegment, unit: number | null) {
  return unit !== null && unit >= segment.startUnit && unit < segment.startUnit + segment.units;
}

function timingCues(measure: CheerLiveMeasure) {
  const byStart = new Map<number, CheerLiveActionSegment | CheerLiveLyricSegment>();
  for (const segment of [...measure.actionSegments, ...measure.lyricSegments]) {
    const current = byStart.get(segment.startUnit);
    if (!current || segment.units < current.units) byStart.set(segment.startUnit, segment);
  }
  return [...byStart.values(), ...measure.restSegments].sort((first, second) => first.startUnit - second.startUnit);
}

function LiveMeasure({ measure, index, current, localUnit }: { readonly measure: CheerLiveMeasure; readonly index: number; readonly current: boolean; readonly localUnit: number | null }) {
  const playhead = current ? localUnit : null;
  const cues = timingCues(measure);
  return <article className="cheer-live-measure" data-current={current ? "true" : undefined} aria-label={`${current ? "Current" : "Next"} Measure ${index + 1}`}><header><span>{current ? "Current" : "Next"}</span><strong>Measure {index + 1}</strong></header><div className="cheer-live-measure__scroll"><div className="cheer-live-measure__lanes"><LiveLane label="ACTION" playhead={playhead}>{measure.actionSegments.map((segment) => <span key={segment.id} style={segmentStyle(segment.startUnit, segment.units)} data-active={current && isActive(segment, localUnit) ? "true" : undefined}>{segment.continuesFromPrevious ? "↪" : cheerActionIcon(segment.action)}</span>)}</LiveLane><LiveLane label="TIMING / PACING" playhead={playhead}>{cues.map((segment) => { const rest = !Object.prototype.hasOwnProperty.call(segment, "timingType"); return <span key={`${segment.id}-timing`} style={segmentStyle(segment.startUnit, segment.units)} data-rest={rest ? "true" : undefined} data-active={current && isActive(segment, localUnit) ? "true" : undefined}>{segment.continuesFromPrevious ? "↪" : cheerDurationSymbol(segment.duration, rest ? "Rest" : "Note")}</span>; })}</LiveLane><LiveLane label="LYRICS" playhead={playhead}>{measure.lyricSegments.map((segment) => <span key={segment.id} style={segmentStyle(segment.startUnit, segment.units)} data-active={current && isActive(segment, localUnit) ? "true" : undefined}>{segment.continuesFromPrevious ? "↪" : segment.lyric || "…"}</span>)}</LiveLane></div></div></article>;
}

export function CheerLivePlayer({ cheer, variant, sharedStartAt, onComplete }: {
  readonly cheer: CheerRecord;
  readonly variant: CheerLiveVariant;
  readonly sharedStartAt: number;
  readonly onComplete: () => void;
}) {
  const [now, setNow] = useState(Date.now);
  const completed = useRef(false);
  const unitMilliseconds = 60_000 / CHEER_PLAYBACK_BPM / 4;
  const totalUnits = variant.measures.length * MEASURE_CAPACITY_UNITS;
  const elapsedUnits = Math.max(0, (now - sharedStartAt) / unitMilliseconds);
  const previewing = now < sharedStartAt;
  const countdown = Math.min(5, Math.max(1, Math.ceil((sharedStartAt - now) / 1_000)));
  const currentIndex = useMemo(() => Math.min(variant.measures.length - 1, Math.floor(Math.min(elapsedUnits, totalUnits - 0.001) / MEASURE_CAPACITY_UNITS)), [elapsedUnits, totalUnits, variant.measures.length]);
  const localUnit = previewing ? 0 : elapsedUnits - currentIndex * MEASURE_CAPACITY_UNITS;
  const currentMeasure = previewing ? variant.measures[0] : variant.measures[currentIndex];
  const nextMeasure = previewing ? variant.measures[1] : variant.measures[currentIndex + 1];

  useEffect(() => {
    let frame = 0;
    const tick = () => {
      setNow(Date.now());
      frame = window.requestAnimationFrame(tick);
    };
    frame = window.requestAnimationFrame(tick);
    return () => window.cancelAnimationFrame(frame);
  }, []);

  useEffect(() => {
    if (completed.current || elapsedUnits < totalUnits) return;
    completed.current = true;
    onComplete();
  }, [elapsedUnits, onComplete, totalUnits]);

  return <main id="main-content" className="cheer-live-player" aria-labelledby="cheer-live-title"><header><span className="eyebrow">Live Cheer · synchronized playback</span><h1 id="cheer-live-title">{cheer.title}</h1><p>{cheer.team || cheer.league || `${cheer.sport}-wide`} · {CHEER_PLAYBACK_BPM} BPM</p></header><section className="cheer-live-stack" aria-label="Live choreography">{currentMeasure ? <LiveMeasure measure={currentMeasure} index={previewing ? 0 : currentIndex} current localUnit={localUnit} /> : null}{nextMeasure ? <LiveMeasure measure={nextMeasure} index={previewing ? 1 : currentIndex + 1} current={false} localUnit={null} /> : null}</section>{previewing ? <div className="cheer-live-countdown" role="status" aria-live="assertive"><strong>{countdown}…</strong><span>Cheer going Live</span></div> : null}</main>;
}
