import { useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { cheerActionIcon, cheerAudienceImage, cheerDurationSymbol } from "./cheerPresentation";
import { CHEER_PLAYBACK_BPM, MEASURE_CAPACITY_UNITS, segmentPositions } from "./cheerUtils";
import type { CheerActionSegment, CheerLyricSegment, CheerMeasure, CheerRecord, CheerRestSegment, CheerSport, CrowdAssignment } from "./types";

type PlayerPhase = "idle" | "count-in" | "playing" | "paused" | "complete";
type TimedSegment = CheerActionSegment | CheerLyricSegment | CheerRestSegment;

function segmentStyle(startUnit: number, units: number): CSSProperties {
  return { gridColumn: `${startUnit + 1} / span ${units}` };
}

function FollowLane({ label, children, playhead }: { readonly label: string; readonly children: ReactNode; readonly playhead: number | null }) {
  return <div className="cheer-follow-lane"><strong>{label}</strong><div>{children}{playhead !== null ? <i className="cheer-follow-playhead" aria-hidden="true" style={{ left: `${(playhead / MEASURE_CAPACITY_UNITS) * 100}%` }} /> : null}</div></div>;
}

function FollowAudience({ audience, sport }: { readonly audience: CrowdAssignment; readonly sport: CheerSport }) {
  const image = cheerAudienceImage(audience, sport);
  return image ? <img src={image} alt={audience} /> : <>{audience}</>;
}

function isActive(segment: TimedSegment, unit: number | null) {
  return unit !== null && unit >= segment.startUnit && unit < segment.startUnit + segment.units;
}

function FollowMeasure({ measure, index, sport, current, localUnit }: { readonly measure: CheerMeasure; readonly index: number; readonly sport: CheerSport; readonly current: boolean; readonly localUnit: number | null }) {
  const actions = segmentPositions(measure.actionSegments);
  const lyrics = segmentPositions(measure.lyricSegments);
  const rests = segmentPositions(measure.restSegments);
  const playhead = current ? localUnit : null;
  return (
    <article className="cheer-follow-measure" data-current={current ? "true" : undefined} aria-label={`${current ? "Current" : "Next"} Measure ${index + 1}`}>
      <header><span>{current ? "Current" : "Next"}</span><strong>Measure {index + 1}</strong></header>
      <div className="cheer-follow-measure__scroll">
        <div className="cheer-follow-measure__lanes">
          <FollowLane label="WHO · Action" playhead={playhead}>{actions.map(({ segment, startUnit, units }) => <span key={segment.id} style={segmentStyle(startUnit, units)} data-active={current && isActive(segment, localUnit) ? "true" : undefined}><FollowAudience audience={segment.audience} sport={sport} /></span>)}</FollowLane>
          <FollowLane label="ACTION" playhead={playhead}>{actions.map(({ segment, startUnit, units }) => <span key={segment.id} style={segmentStyle(startUnit, units)} data-active={current && isActive(segment, localUnit) ? "true" : undefined}>{segment.continuesFromPrevious ? "↪" : cheerActionIcon(segment.action)}</span>)}</FollowLane>
          <FollowLane label="ACTION TIMING" playhead={playhead}>{actions.map(({ segment, startUnit, units }) => <span key={`${segment.id}-action-timing`} style={segmentStyle(startUnit, units)} data-active={current && isActive(segment, localUnit) ? "true" : undefined}>{segment.continuesFromPrevious ? "↪" : cheerDurationSymbol(segment.duration, "Note")}</span>)}{rests.map(({ segment, startUnit, units }) => <span key={`${segment.id}-action-rest`} style={segmentStyle(startUnit, units)} data-rest="true" data-active={current && isActive(segment, localUnit) ? "true" : undefined}>{segment.continuesFromPrevious ? "↪" : cheerDurationSymbol(segment.duration, "Rest")}</span>)}</FollowLane>
          <FollowLane label="LYRIC TIMING" playhead={playhead}>{lyrics.map(({ segment, startUnit, units }) => <span key={`${segment.id}-lyric-timing`} style={segmentStyle(startUnit, units)} data-active={current && isActive(segment, localUnit) ? "true" : undefined}>{segment.continuesFromPrevious ? "↪" : cheerDurationSymbol(segment.duration, "Note")}</span>)}{rests.map(({ segment, startUnit, units }) => <span key={`${segment.id}-lyric-rest`} style={segmentStyle(startUnit, units)} data-rest="true" data-active={current && isActive(segment, localUnit) ? "true" : undefined}>{segment.continuesFromPrevious ? "↪" : cheerDurationSymbol(segment.duration, "Rest")}</span>)}</FollowLane>
          <FollowLane label="LYRICS" playhead={playhead}>{lyrics.map(({ segment, startUnit, units }) => <span key={segment.id} style={segmentStyle(startUnit, units)} data-active={current && isActive(segment, localUnit) ? "true" : undefined}>{segment.continuesFromPrevious ? "↪" : segment.lyric || "…"}</span>)}</FollowLane>
          <FollowLane label="WHO · Lyrics" playhead={playhead}>{lyrics.map(({ segment, startUnit, units }) => <span key={segment.id} style={segmentStyle(startUnit, units)} data-active={current && isActive(segment, localUnit) ? "true" : undefined}><FollowAudience audience={segment.audience} sport={sport} /></span>)}</FollowLane>
        </div>
      </div>
    </article>
  );
}

export function CheerFollowPlayer({ cheer }: { readonly cheer: CheerRecord }) {
  const totalUnits = cheer.measures.length * MEASURE_CAPACITY_UNITS;
  const unitMilliseconds = 60_000 / CHEER_PLAYBACK_BPM / 4;
  const beatMilliseconds = 60_000 / CHEER_PLAYBACK_BPM;
  const [phase, setPhase] = useState<PlayerPhase>("idle");
  const [position, setPosition] = useState(0);
  const [countIn, setCountIn] = useState<number | null>(null);
  const positionRef = useRef(0);

  useEffect(() => { positionRef.current = position; }, [position]);
  useEffect(() => {
    setPhase("idle");
    setPosition(0);
    setCountIn(null);
  }, [cheer.id]);

  useEffect(() => {
    if (phase !== "count-in" || countIn === null) return;
    const timeout = window.setTimeout(() => {
      if (countIn > 1) setCountIn(countIn - 1);
      else {
        setCountIn(null);
        setPhase("playing");
      }
    }, beatMilliseconds);
    return () => window.clearTimeout(timeout);
  }, [beatMilliseconds, countIn, phase]);

  useEffect(() => {
    if (phase !== "playing") return;
    const startPosition = positionRef.current;
    const startedAt = performance.now();
    let frame = 0;
    const advance = (now: number) => {
      const next = startPosition + (now - startedAt) / unitMilliseconds;
      if (next >= totalUnits) {
        setPosition(totalUnits);
        setPhase("complete");
        return;
      }
      setPosition(next);
      frame = window.requestAnimationFrame(advance);
    };
    frame = window.requestAnimationFrame(advance);
    return () => window.cancelAnimationFrame(frame);
  }, [phase, totalUnits, unitMilliseconds]);

  const beginCountIn = () => {
    setPosition(0);
    setCountIn(3);
    setPhase("count-in");
  };
  const play = () => phase === "paused" ? setPhase("playing") : beginCountIn();
  const pause = () => {
    if (phase === "count-in") {
      setCountIn(null);
      setPhase("idle");
    } else if (phase === "playing") setPhase("paused");
  };
  const restart = () => beginCountIn();

  const currentIndex = useMemo(() => Math.min(cheer.measures.length - 1, Math.floor(Math.min(position, totalUnits - 0.001) / MEASURE_CAPACITY_UNITS)), [cheer.measures.length, position, totalUnits]);
  const localUnit = phase === "idle" || phase === "count-in" ? null : position - currentIndex * MEASURE_CAPACITY_UNITS;
  const currentMeasure = cheer.measures[currentIndex];
  const nextMeasure = cheer.measures[currentIndex + 1];
  const progressBeat = Math.min(4, Math.floor((localUnit ?? 0) / 4) + 1);

  return (
    <main className="cheer-follow-player" aria-labelledby="cheer-follow-title">
      <header><div><span className="eyebrow">Practice player · {CHEER_PLAYBACK_BPM} BPM</span><h2 id="cheer-follow-title">{cheer.title}</h2><p>{cheer.team || "League-wide"} · {cheer.sport} · Measure {currentIndex + 1} of {cheer.measures.length}{phase === "playing" || phase === "paused" ? ` · Beat ${progressBeat}` : ""}</p></div><div className="cheer-playback-controls" aria-label="Follow playback controls"><button type="button" disabled={phase === "playing" || phase === "count-in"} onClick={play}>Play</button><button type="button" disabled={phase !== "playing" && phase !== "count-in"} onClick={pause}>Pause</button><button type="button" onClick={restart}>Restart</button></div></header>
      {countIn !== null ? <div className="cheer-follow-count-in" role="status" aria-live="assertive"><span>{countIn}</span><small>Get ready</small></div> : null}
      {phase === "complete" ? <p className="cheer-follow-complete" role="status">Cheer complete. Restart when you’re ready to practice again.</p> : null}
      <section className="cheer-follow-stack" aria-label="Follow choreography">
        {currentMeasure ? <FollowMeasure measure={currentMeasure} index={currentIndex} sport={cheer.sport} current localUnit={localUnit} /> : null}
        {nextMeasure ? <FollowMeasure measure={nextMeasure} index={currentIndex + 1} sport={cheer.sport} current={false} localUnit={null} /> : <div className="cheer-follow-end"><span>End of Cheer</span><small>The current measure is the final measure.</small></div>}
      </section>
    </main>
  );
}
