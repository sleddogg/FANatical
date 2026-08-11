import { useEffect, useMemo, useState, type CSSProperties, type ReactNode } from "react";
import { canPlaceRest, canPlaceSegment, distributeLyricLine, durationUnits, estimateSyllables, lyricLines, MEASURE_CAPACITY_UNITS, measureUsedUnits, segmentPositions, trackEndUnit, type CheerTrack } from "./cheerUtils";
import type { CheerAction, CheerActionSegment, CheerDraft, CheerDuration, CheerLyricSegment, CheerMeasure, CheerRestSegment, CheerSport, CheerTimingType, CrowdAssignment } from "./types";
import { cheerActionIcon, cheerAudienceImage, cheerDurationSymbol, cheerSportAudienceLegend } from "./cheerPresentation";
import { CheerRecording } from "./CheerRecording";

const durationOptions = [
  { value: "Sixteenth", beats: "¼ beat" },
  { value: "Eighth", beats: "½ beat" },
  { value: "Quarter", beats: "1 beat" },
  { value: "Half", beats: "2 beats" },
  { value: "Dotted Half", beats: "3 beats" },
  { value: "Whole", beats: "4 beats" },
] as const satisfies readonly { readonly value: CheerDuration; readonly beats: string }[];

const actionOptions = [
  { value: "Clap", icon: "👏" },
  { value: "Stomp", icon: "🦶" },
  { value: "Wave", icon: "🌊" },
  { value: "None", icon: "—" },
] as const satisfies readonly { readonly value: CheerAction; readonly icon: string }[];

const baseAudiences = ["All", "East", "West", "North", "South", "Upper", "Lower"] as const satisfies readonly CrowdAssignment[];
const teachingDismissalKey = "fanatical.cheer.d-fence-how-to-dismissed";
let builderSequence = 0;

type BuilderSelection = Readonly<{
  track: CheerTrack | "rest";
  eventId: string;
  control: "audience" | "action" | "timing" | "lyrics";
}>;

type SelectedSegment = CheerActionSegment | CheerLyricSegment | CheerRestSegment;

type CopyBuffer = Readonly<{
  track: CheerTrack;
  duration: CheerDuration;
  audience: CrowdAssignment;
  action: CheerAction;
  lyric: string;
}>;

function localId(prefix: string) {
  builderSequence += 1;
  return `${prefix}-local-${builderSequence}`;
}

function emptyMeasure(): CheerMeasure {
  return { id: localId("measure"), actionSegments: [], lyricSegments: [], restSegments: [] };
}

function laneStyle(startUnit: number, units: number): CSSProperties {
  return { gridColumn: `${startUnit + 1} / span ${units}` };
}

function beatPositionLabel(unit: number) {
  const beat = Math.floor(unit / 4) + 1;
  const subdivision = unit % 4;
  if (subdivision === 0) return `beat ${beat}`;
  if (subdivision === 1) return `beat ${beat} and a quarter`;
  if (subdivision === 2) return `beat ${beat} and a half`;
  return `beat ${beat} and three quarters`;
}

function audienceOptions(sport: CheerSport): readonly CrowdAssignment[] {
  if (sport === "Basketball") return [...baseAudiences, "Backboard Left", "Backboard Right"];
  if (sport === "Football") return [...baseAudiences, "Uprights Left", "Uprights Right"];
  return baseAudiences;
}

function AudienceVisual({ audience }: { readonly audience: CrowdAssignment }) {
  const image = cheerAudienceImage(audience);
  if (image) return <span className="cheer-audience-visual cheer-audience-visual--image"><img src={image} alt="" /></span>;
  return <span className="cheer-audience-visual" data-audience={audience}><i>{audience}</i></span>;
}

function PlacedAudience({ audience }: { readonly audience: CrowdAssignment }) {
  const image = cheerAudienceImage(audience);
  return image ? <img className="cheer-placed-audience-image" src={image} alt="" /> : <>{audience}</>;
}

function DfenceHowTo({ onClose }: { readonly onClose: (dontShowAgain: boolean) => void }) {
  const [dontShowAgain, setDontShowAgain] = useState(false);

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const closeOnEscape = (event: KeyboardEvent) => event.key === "Escape" && onClose(false);
    window.addEventListener("keydown", closeOnEscape);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", closeOnEscape);
    };
  }, [onClose]);

  const cells = (values: readonly string[]) => <div>{values.map((value, index) => <span key={`${value}-${index}`} data-empty={value ? undefined : "true"}>{value}</span>)}</div>;

  return (
    <div className="cheer-dialog-layer">
      <button className="cheer-dialog-backdrop" type="button" aria-label="Close D-Fence How To" onClick={() => onClose(dontShowAgain)} />
      <section className="cheer-how-to" role="dialog" aria-modal="true" aria-labelledby="cheer-how-to-title">
        <header><div><span className="eyebrow">How To</span><h2 id="cheer-how-to-title">One Cheer, five creator lanes</h2></div><button type="button" aria-label="Close D-Fence How To" onClick={() => onClose(dontShowAgain)}>×</button></header>
        <p>Click any empty rhythmic position to place an Action or Lyric. New events use an eighth note when it fits and a sixteenth note in the smallest available gap.</p>
        <div className="cheer-how-to__lanes" aria-label="D FENCE five lane teaching example">
          <span>WHO · Action</span>{cells(["", "", "All", "All"])}
          <span>ACTION</span>{cells(["", "", "👏", "👏"])}
          <span>TIMING / PACING</span>{cells(["1", "2", "3", "4"])}
          <span>LYRICS</span>{cells(["D", "FENCE", "", ""])}
          <span>WHO · Lyrics</span>{cells(["West", "East", "", ""])}
        </div>
        <div className="cheer-how-to__audience-legend" aria-label="Sport-specific WHO symbols">
          {cheerSportAudienceLegend.map((item) => <article key={item.title}><img src={item.image} alt="" /><div><strong>{item.title}</strong><small>{item.context}</small></div></article>)}
        </div>
        <p className="cheer-how-to__note">Action and Lyrics are independent timelines. Events can continue into the next measure, and each event can route to a different audience without duplicating the Cheer.</p>
        <label className="cheer-how-to__dismiss"><input type="checkbox" checked={dontShowAgain} onChange={(event) => setDontShowAgain(event.target.checked)} /> Don’t show this again</label>
        <button className="cheer-primary-button" type="button" onClick={() => onClose(dontShowAgain)}>Close</button>
      </section>
    </div>
  );
}

function DeleteMeasureDialog({ measureNumber, onCancel, onConfirm }: { readonly measureNumber: number; readonly onCancel: () => void; readonly onConfirm: () => void }) {
  return (
    <div className="cheer-dialog-layer">
      <button className="cheer-dialog-backdrop" type="button" aria-label="Cancel deleting measure" onClick={onCancel} />
      <section className="cheer-delete-dialog" role="dialog" aria-modal="true" aria-labelledby="delete-measure-title">
        <span className="eyebrow">Measure deletion</span><h2 id="delete-measure-title">Delete Measure {measureNumber}?</h2><p>This removes every Action, Lyric, timing, and audience assignment from this measure.</p>
        <div><button type="button" onClick={onCancel}>Cancel</button><button type="button" onClick={onConfirm}>Delete Measure</button></div>
      </section>
    </div>
  );
}

function Lane({ label, children, className = "" }: { readonly label: string; readonly children: ReactNode; readonly className?: string }) {
  return <div className={`cheer-lane ${className}`}><strong>{label}</strong><div className="cheer-lane__timeline">{children}</div></div>;
}

function PlacementCells({ measure, track, copyBuffer, onPlace }: { readonly measure: CheerMeasure; readonly track: CheerTrack; readonly copyBuffer: CopyBuffer | null; readonly onPlace: (unit: number) => void }) {
  return <>{Array.from({ length: MEASURE_CAPACITY_UNITS }, (_, unit) => {
    const copyMatches = !copyBuffer || copyBuffer.track === track;
    const units = copyBuffer && copyMatches ? Math.min(durationUnits[copyBuffer.duration], MEASURE_CAPACITY_UNITS - unit) : durationUnits.Sixteenth;
    const available = copyMatches && canPlaceSegment(measure, track, unit, units);
    const verb = copyBuffer && copyMatches ? "Paste copied" : "Place";
    return <button className="cheer-placement-cell" key={unit} type="button" disabled={!available} style={laneStyle(unit, 1)} aria-label={`${verb} ${track === "action" ? "Action" : "Lyric"} at ${beatPositionLabel(unit)}`} onClick={() => onPlace(unit)}><span aria-hidden="true">+</span></button>;
  })}</>;
}

function MeasureTimeline({ measure, measureIndex, selected, copyBuffer, onSelect, onPlace, onUpdateLyric }: {
  readonly measure: CheerMeasure;
  readonly measureIndex: number;
  readonly selected: BuilderSelection | null;
  readonly copyBuffer: CopyBuffer | null;
  readonly onSelect: (selection: BuilderSelection) => void;
  readonly onPlace: (track: CheerTrack, startUnit: number) => void;
  readonly onUpdateLyric: (eventId: string, lyric: string) => void;
}) {
  const positionedActions = segmentPositions(measure.actionSegments);
  const positionedLyrics = segmentPositions(measure.lyricSegments);
  const positionedRests = segmentPositions(measure.restSegments);
  const isSelected = (track: BuilderSelection["track"], eventId: string, control: BuilderSelection["control"]) => selected?.track === track && selected.eventId === eventId && selected.control === control;

  return (
    <div className="cheer-measure__scroll" tabIndex={0} aria-label={`Measure ${measureIndex + 1} choreography timeline`}>
      <div className="cheer-measure__lanes">
        <Lane label="WHO · Action" className="cheer-lane--who">{positionedActions.map(({ segment, startUnit, units }) => <button key={segment.id} type="button" data-default={segment.audience === "All" ? "true" : undefined} data-selected={isSelected("action", segment.eventId, "audience") ? "true" : undefined} style={laneStyle(startUnit, units)} onClick={() => onSelect({ track: "action", eventId: segment.eventId, control: "audience" })} aria-label={`Action audience ${segment.audience}`}><PlacedAudience audience={segment.audience} /></button>)}</Lane>
        <Lane label="ACTION" className="cheer-lane--action"><PlacementCells measure={measure} track="action" copyBuffer={copyBuffer} onPlace={(unit) => onPlace("action", unit)} />{positionedActions.map(({ segment, startUnit, units }) => <button className="cheer-lane-event" key={segment.id} type="button" data-selected={isSelected("action", segment.eventId, "action") ? "true" : undefined} data-continuation={segment.continuesFromPrevious ? "true" : undefined} style={laneStyle(startUnit, units)} onClick={() => onSelect({ track: "action", eventId: segment.eventId, control: "action" })} aria-label={`Action ${segment.action} at ${beatPositionLabel(startUnit)}`}>{segment.continuesFromPrevious ? "↪" : cheerActionIcon(segment.action)}</button>)}</Lane>
        <Lane label="TIMING / PACING" className="cheer-lane--timing">
          <div className="cheer-timing-spine" aria-hidden="true">{[1, 2, 3, 4].map((beat) => <span key={beat}>{beat}</span>)}</div>
          <div className="cheer-timing-track cheer-timing-track--action">{positionedActions.map(({ segment, startUnit, units }) => <button key={segment.id} type="button" data-selected={isSelected("action", segment.eventId, "timing") ? "true" : undefined} data-continuation={segment.continuesFromPrevious ? "true" : undefined} style={laneStyle(startUnit, units)} onClick={() => onSelect({ track: "action", eventId: segment.eventId, control: "timing" })} aria-label={`Action Note timing ${segment.duration} at ${beatPositionLabel(startUnit)}`}>{segment.continuesFromPrevious ? "↪" : cheerDurationSymbol(segment.duration, "Note")}</button>)}{positionedRests.map(({ segment, startUnit, units }) => <button className="cheer-timing-rest" key={segment.id} type="button" data-selected={isSelected("rest", segment.eventId, "timing") ? "true" : undefined} data-continuation={segment.continuesFromPrevious ? "true" : undefined} style={laneStyle(startUnit, units)} onClick={() => onSelect({ track: "rest", eventId: segment.eventId, control: "timing" })} aria-label={`Rest timing ${segment.duration} at ${beatPositionLabel(startUnit)}`}>{segment.continuesFromPrevious ? "↪" : cheerDurationSymbol(segment.duration, "Rest")}</button>)}</div>
          <div className="cheer-timing-track cheer-timing-track--lyrics">{positionedLyrics.map(({ segment, startUnit, units }) => <button key={segment.id} type="button" data-selected={isSelected("lyrics", segment.eventId, "timing") ? "true" : undefined} data-continuation={segment.continuesFromPrevious ? "true" : undefined} style={laneStyle(startUnit, units)} onClick={() => onSelect({ track: "lyrics", eventId: segment.eventId, control: "timing" })} aria-label={`Lyrics Note timing ${segment.duration} at ${beatPositionLabel(startUnit)}`}>{segment.continuesFromPrevious ? "↪" : cheerDurationSymbol(segment.duration, "Note")}</button>)}</div>
        </Lane>
        <Lane label="LYRICS" className="cheer-lane--lyrics"><PlacementCells measure={measure} track="lyrics" copyBuffer={copyBuffer} onPlace={(unit) => onPlace("lyrics", unit)} />{positionedLyrics.map(({ segment, startUnit, units }) => segment.continuesFromPrevious ? <button key={segment.id} type="button" className="cheer-lane__rest cheer-lane-event" data-continuation="true" style={laneStyle(startUnit, units)} onClick={() => onSelect({ track: "lyrics", eventId: segment.eventId, control: "lyrics" })} aria-label={`Continued lyrics at ${beatPositionLabel(startUnit)}`}>↪</button> : <input className="cheer-lane-event" key={segment.id} dir="auto" style={laneStyle(startUnit, units)} aria-label={`Lyrics at ${beatPositionLabel(startUnit)}`} data-selected={isSelected("lyrics", segment.eventId, "lyrics") ? "true" : undefined} value={segment.lyric} placeholder="Words" onFocus={() => onSelect({ track: "lyrics", eventId: segment.eventId, control: "lyrics" })} onChange={(event) => onUpdateLyric(segment.eventId, event.target.value)} />)}</Lane>
        <Lane label="WHO · Lyrics" className="cheer-lane--who">{positionedLyrics.map(({ segment, startUnit, units }) => <button key={segment.id} type="button" data-default={segment.audience === "All" ? "true" : undefined} data-selected={isSelected("lyrics", segment.eventId, "audience") ? "true" : undefined} style={laneStyle(startUnit, units)} onClick={() => onSelect({ track: "lyrics", eventId: segment.eventId, control: "audience" })} aria-label={`Lyric audience ${segment.audience}`}><PlacedAudience audience={segment.audience} /></button>)}</Lane>
      </div>
    </div>
  );
}

export function CheerBuilder({ draft, onChange, onFinish }: { readonly draft: CheerDraft; readonly onChange: (draft: CheerDraft) => void; readonly onFinish: () => void }) {
  const [activeMeasureId, setActiveMeasureId] = useState(draft.measures[0]?.id ?? "");
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [recordingOpen, setRecordingOpen] = useState(false);
  const [message, setMessage] = useState("");
  const [measureWarnings, setMeasureWarnings] = useState<Readonly<Record<string, string>>>({});
  const [selection, setSelection] = useState<BuilderSelection | null>(null);
  const [copyBuffer, setCopyBuffer] = useState<CopyBuffer | null>(null);
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);
  const [showHowTo, setShowHowTo] = useState(() => window.localStorage.getItem(teachingDismissalKey) !== "true");
  const lines = useMemo(() => lyricLines(draft.lyrics), [draft.lyrics]);
  const hasTimedSegments = draft.measures.some((measure) => measure.actionSegments.length > 0 || measure.lyricSegments.length > 0 || measure.restSegments.length > 0);
  const selectedSegment = useMemo<SelectedSegment | null>(() => {
    if (!selection) return null;
    for (const measure of draft.measures) {
      const segments = selection.track === "action" ? measure.actionSegments : selection.track === "lyrics" ? measure.lyricSegments : measure.restSegments;
      const startingPiece = segments.find((segment) => segment.eventId === selection.eventId && !segment.continuesFromPrevious);
      if (startingPiece) return startingPiece;
    }
    return null;
  }, [draft.measures, selection]);
  const selectedAction = selection?.track === "action" ? (selectedSegment as CheerActionSegment | null)?.action ?? null : null;
  const selectedTimingType: CheerTimingType = selection?.track === "rest" ? "Rest" : "Note";
  const availableAudiences = audienceOptions(draft.sport);

  const addMeasure = () => {
    const measure = emptyMeasure();
    onChange({ ...draft, measures: [...draft.measures, measure] });
    setActiveMeasureId(measure.id);
    setSelection(null);
    setMessage("");
  };

  const updateEvent = (track: CheerTrack, eventId: string, patch: Partial<CheerActionSegment & CheerLyricSegment>) => {
    onChange({
      ...draft,
      measures: draft.measures.map((measure) => track === "action"
        ? { ...measure, actionSegments: measure.actionSegments.map((segment) => segment.eventId === eventId ? { ...segment, ...patch } : segment) }
        : { ...measure, lyricSegments: measure.lyricSegments.map((segment) => segment.eventId === eventId ? { ...segment, ...patch } : segment) }),
    });
  };

  const performDeleteMeasure = (measureId: string) => {
    if (draft.measures.length === 1) return;
    const removed = draft.measures.find((measure) => measure.id === measureId);
    const removedEventIds = new Set([...(removed?.actionSegments ?? []), ...(removed?.lyricSegments ?? []), ...(removed?.restSegments ?? [])].map((segment) => segment.eventId));
    const next = draft.measures
      .filter((measure) => measure.id !== measureId)
      .map((measure) => ({
        ...measure,
        actionSegments: measure.actionSegments.filter((segment) => !removedEventIds.has(segment.eventId)),
        lyricSegments: measure.lyricSegments.filter((segment) => !removedEventIds.has(segment.eventId)),
        restSegments: measure.restSegments.filter((segment) => !removedEventIds.has(segment.eventId)),
      }));
    onChange({ ...draft, measures: next });
    if (activeMeasureId === measureId) setActiveMeasureId(next[0]?.id ?? "");
    if (selection && removedEventIds.has(selection.eventId)) setSelection(null);
    setMeasureWarnings((current) => Object.fromEntries(Object.entries(current).filter(([id]) => id !== measureId)));
    setConfirmDeleteId(null);
  };

  const placeSegment = (measureId: string, track: CheerTrack, startUnit: number) => {
    const measure = draft.measures.find((candidate) => candidate.id === measureId);
    if (!measure) return;
    if (copyBuffer) {
      if (copyBuffer.track !== track) return;
      const startMeasureIndex = draft.measures.findIndex((candidate) => candidate.id === measureId);
      const nextMeasures: CheerMeasure[] = draft.measures.map((candidate) => ({ ...candidate, actionSegments: [...candidate.actionSegments], lyricSegments: [...candidate.lyricSegments], restSegments: [...candidate.restSegments] }));
      const eventId = localId(track === "action" ? "action-event" : "lyric-event");
      let remaining = durationUnits[copyBuffer.duration];
      let measureIndex = startMeasureIndex;
      let pieceStart = startUnit;
      let pieceIndex = 0;

      while (remaining > 0) {
        if (measureIndex >= nextMeasures.length) nextMeasures.push(emptyMeasure());
        const targetMeasure = nextMeasures[measureIndex]!;
        const units = Math.min(remaining, MEASURE_CAPACITY_UNITS - pieceStart);
        if (units <= 0) {
          measureIndex += 1;
          pieceStart = 0;
          continue;
        }
        if (!canPlaceSegment(targetMeasure, track, pieceStart, units)) {
          setMeasureWarnings({ [targetMeasure.id]: `This copied ${copyBuffer.duration} ${track === "action" ? "Action" : "Lyric"} collides with another event.` });
          setActiveMeasureId(targetMeasure.id);
          return;
        }
        const common = { eventId, startUnit: pieceStart, units, duration: copyBuffer.duration, timingType: "Note" as const, continuesFromPrevious: pieceIndex > 0, continuesToNext: remaining > units, audience: copyBuffer.audience };
        nextMeasures[measureIndex] = track === "action"
          ? { ...targetMeasure, actionSegments: [...targetMeasure.actionSegments, { id: localId("action-piece"), ...common, action: copyBuffer.action }] }
          : { ...targetMeasure, lyricSegments: [...targetMeasure.lyricSegments, { id: localId("lyric-piece"), ...common, lyric: copyBuffer.lyric }] };
        remaining -= units;
        measureIndex += 1;
        pieceStart = 0;
        pieceIndex += 1;
      }

      onChange({ ...draft, measures: nextMeasures });
      setSelection({ track, eventId, control: track === "action" ? "action" : "lyrics" });
      setActiveMeasureId(measureId);
      setMeasureWarnings({});
      setMessage(`Copied ${track === "action" ? "Action" : "Lyric"} placed. Copy mode remains active.`);
      return;
    }
    const duration: CheerDuration | null = canPlaceSegment(measure, track, startUnit, durationUnits.Eighth)
      ? "Eighth"
      : canPlaceSegment(measure, track, startUnit, durationUnits.Sixteenth) ? "Sixteenth" : null;
    if (!duration) return;
    const eventId = localId(track === "action" ? "action-event" : "lyric-event");
    const common = { eventId, startUnit, units: durationUnits[duration], duration, timingType: "Note" as const, continuesFromPrevious: false, continuesToNext: false, audience: "All" as const };
    const nextMeasures = draft.measures.map((candidate) => {
      if (candidate.id !== measureId) return candidate;
      return track === "action"
        ? { ...candidate, actionSegments: [...candidate.actionSegments, { id: localId("action-piece"), ...common, action: "Clap" as const }] }
        : { ...candidate, lyricSegments: [...candidate.lyricSegments, { id: localId("lyric-piece"), ...common, lyric: "" }] };
    });
    onChange({ ...draft, measures: nextMeasures });
    setSelection({ track, eventId, control: track === "action" ? "action" : "lyrics" });
    setActiveMeasureId(measureId);
    setMeasureWarnings({});
    setMessage("");
  };

  const copySelected = () => {
    if (!selection || !selectedSegment || selection.track === "rest") return;
    setCopyBuffer({
      track: selection.track,
      duration: selectedSegment.duration,
      audience: selectedSegment.audience,
      action: selection.track === "action" ? (selectedSegment as CheerActionSegment).action : "Clap",
      lyric: selection.track === "lyrics" ? (selectedSegment as CheerLyricSegment).lyric : "",
    });
    setMeasureWarnings({});
    setMessage(`Copy mode: choose an available ${selection.track === "action" ? "Action" : "Lyric"} position.`);
  };

  const changeEventDuration = (duration: CheerDuration) => {
    if (!selection || !selectedSegment) return;
    let startMeasureIndex = -1;
    let startUnit = selectedSegment.startUnit;
    draft.measures.forEach((measure, measureIndex) => {
      const segments = selection.track === "action" ? measure.actionSegments : selection.track === "lyrics" ? measure.lyricSegments : measure.restSegments;
      const startingPiece = segments.find((segment) => segment.eventId === selection.eventId && !segment.continuesFromPrevious);
      if (startingPiece) {
        startMeasureIndex = measureIndex;
        startUnit = startingPiece.startUnit;
      }
    });
    if (startMeasureIndex < 0) return;

    const nextMeasures: CheerMeasure[] = draft.measures.map((measure) => ({
      ...measure,
      actionSegments: selection.track === "action" ? measure.actionSegments.filter((segment) => segment.eventId !== selection.eventId) : [...measure.actionSegments],
      lyricSegments: selection.track === "lyrics" ? measure.lyricSegments.filter((segment) => segment.eventId !== selection.eventId) : [...measure.lyricSegments],
      restSegments: selection.track === "rest" ? measure.restSegments.filter((segment) => segment.eventId !== selection.eventId) : [...measure.restSegments],
    }));
    let remaining = durationUnits[duration];
    let measureIndex = startMeasureIndex;
    let pieceStart = startUnit;
    let pieceIndex = 0;

    while (remaining > 0) {
      if (measureIndex >= nextMeasures.length) nextMeasures.push(emptyMeasure());
      const measure = nextMeasures[measureIndex]!;
      const units = Math.min(remaining, MEASURE_CAPACITY_UNITS - pieceStart);
      if (units <= 0) {
        measureIndex += 1;
        pieceStart = 0;
        continue;
      }
      const available = selection.track === "rest"
        ? canPlaceRest(measure, pieceStart, units)
        : canPlaceSegment(measure, selection.track, pieceStart, units);
      if (!available) {
        setMeasureWarnings({ [measure.id]: `This ${duration} ${selection.track === "rest" ? "rest" : "note"} collides with another event.` });
        setActiveMeasureId(measure.id);
        return;
      }
      const common = {
        id: localId(selection.track === "action" ? "action-piece" : "lyric-piece"),
        eventId: selection.eventId,
        startUnit: pieceStart,
        units,
        duration,
        continuesFromPrevious: pieceIndex > 0,
        continuesToNext: remaining > units,
      };
      if (selection.track === "action") {
        const action = selectedSegment as CheerActionSegment;
        nextMeasures[measureIndex] = { ...measure, actionSegments: [...measure.actionSegments, { ...common, timingType: "Note", audience: action.audience, action: action.action }] };
      } else if (selection.track === "lyrics") {
        const lyric = selectedSegment as CheerLyricSegment;
        nextMeasures[measureIndex] = { ...measure, lyricSegments: [...measure.lyricSegments, { ...common, timingType: "Note", audience: lyric.audience, lyric: lyric.lyric }] };
      } else {
        const rest = selectedSegment as CheerRestSegment;
        nextMeasures[measureIndex] = { ...measure, restSegments: [...measure.restSegments, { ...common, originTrack: rest.originTrack, action: rest.action, lyric: rest.lyric, audience: rest.audience }] };
      }
      remaining -= units;
      measureIndex += 1;
      pieceStart = 0;
      pieceIndex += 1;
    }

    onChange({ ...draft, measures: nextMeasures });
    setMeasureWarnings({});
    setMessage(pieceIndex > 1 ? `Continued this event into Measure ${measureIndex}.` : "");
  };

  const changeTimingType = (timingType: CheerTimingType) => {
    if (!selection || !selectedSegment || timingType === selectedTimingType) return;
    if (timingType === "Rest" && selection.track !== "rest") {
      const sourceTrack = selection.track;
      const source = selectedSegment as CheerActionSegment | CheerLyricSegment;
      const nextMeasures: CheerMeasure[] = draft.measures.map((measure) => ({
        ...measure,
        actionSegments: sourceTrack === "action" ? measure.actionSegments.filter((segment) => segment.eventId !== selection.eventId) : [...measure.actionSegments],
        lyricSegments: sourceTrack === "lyrics" ? measure.lyricSegments.filter((segment) => segment.eventId !== selection.eventId) : [...measure.lyricSegments],
        restSegments: [...measure.restSegments],
      }));
      const sourcePieces = draft.measures.flatMap((measure, measureIndex) => {
        const segments = sourceTrack === "action" ? measure.actionSegments : measure.lyricSegments;
        return segments.filter((segment) => segment.eventId === selection.eventId).map((segment) => ({ measureIndex, segment }));
      });
      for (const { measureIndex, segment } of sourcePieces) {
        const measure = nextMeasures[measureIndex]!;
        if (!canPlaceRest(measure, segment.startUnit, segment.units)) {
          setMeasureWarnings({ [measure.id]: "A Rest must be empty across both Action and Lyrics. Remove the colliding event first." });
          setActiveMeasureId(measure.id);
          return;
        }
        const rest: CheerRestSegment = {
          id: localId("rest-piece"), eventId: selection.eventId, startUnit: segment.startUnit, units: segment.units,
          duration: segment.duration, continuesFromPrevious: segment.continuesFromPrevious, continuesToNext: segment.continuesToNext,
          originTrack: sourceTrack, action: sourceTrack === "action" ? (source as CheerActionSegment).action : "Clap",
          lyric: sourceTrack === "lyrics" ? (source as CheerLyricSegment).lyric : "", audience: source.audience,
        };
        nextMeasures[measureIndex] = { ...measure, restSegments: [...measure.restSegments, rest] };
      }
      onChange({ ...draft, measures: nextMeasures });
      setSelection({ track: "rest", eventId: selection.eventId, control: "timing" });
    } else if (timingType === "Note" && selection.track === "rest") {
      const rest = selectedSegment as CheerRestSegment;
      const nextMeasures: CheerMeasure[] = draft.measures.map((measure) => {
        const pieces = measure.restSegments.filter((segment) => segment.eventId === selection.eventId);
        const base = { ...measure, restSegments: measure.restSegments.filter((segment) => segment.eventId !== selection.eventId) };
        if (rest.originTrack === "action") {
          return { ...base, actionSegments: [...measure.actionSegments, ...pieces.map((piece): CheerActionSegment => ({ id: localId("action-piece"), eventId: piece.eventId, startUnit: piece.startUnit, units: piece.units, duration: piece.duration, timingType: "Note", continuesFromPrevious: piece.continuesFromPrevious, continuesToNext: piece.continuesToNext, action: rest.action, audience: rest.audience }))] };
        }
        return { ...base, lyricSegments: [...measure.lyricSegments, ...pieces.map((piece): CheerLyricSegment => ({ id: localId("lyric-piece"), eventId: piece.eventId, startUnit: piece.startUnit, units: piece.units, duration: piece.duration, timingType: "Note", continuesFromPrevious: piece.continuesFromPrevious, continuesToNext: piece.continuesToNext, lyric: rest.lyric, audience: rest.audience }))] };
      });
      onChange({ ...draft, measures: nextMeasures });
      setSelection({ track: rest.originTrack, eventId: selection.eventId, control: "timing" });
    }
    setMeasureWarnings({});
    setMessage("");
  };

  const updateSelected = (patch: { readonly duration?: CheerDuration; readonly timingType?: CheerTimingType; readonly audience?: CrowdAssignment; readonly action?: CheerAction }) => {
    if (!selection || !selectedSegment) return;
    if (patch.duration) {
      changeEventDuration(patch.duration);
      return;
    }
    if (patch.timingType) {
      changeTimingType(patch.timingType);
      return;
    }
    if (selection.track === "rest") return;
    updateEvent(selection.track, selection.eventId, patch as Partial<CheerActionSegment & CheerLyricSegment>);
    setMeasureWarnings({});
    setMessage("");
  };

  const removeSelected = () => {
    if (!selection) return;
    onChange({
      ...draft,
      measures: draft.measures.map((measure) => ({
        ...measure,
        actionSegments: selection.track === "action" ? measure.actionSegments.filter((segment) => segment.eventId !== selection.eventId) : measure.actionSegments,
        lyricSegments: selection.track === "lyrics" ? measure.lyricSegments.filter((segment) => segment.eventId !== selection.eventId) : measure.lyricSegments,
        restSegments: selection.track === "rest" ? measure.restSegments.filter((segment) => segment.eventId !== selection.eventId) : measure.restSegments,
      })),
    });
    setSelection(null);
    setMeasureWarnings({});
    setMessage("");
  };

  const addLyricSuggestion = (line: string) => {
    const startingIndex = Math.max(0, draft.measures.findIndex((measure) => measure.id === activeMeasureId));
    const chunks = distributeLyricLine(line, 4);
    if (!chunks.length) return;
    const nextMeasures: CheerMeasure[] = draft.measures.map((measure) => ({ ...measure, actionSegments: [...measure.actionSegments], lyricSegments: [...measure.lyricSegments], restSegments: [...measure.restSegments] }));
    let measureIndex = startingIndex;
    let lastEventId = "";
    const measureAt = (index: number) => {
      while (nextMeasures.length <= index) nextMeasures.push(emptyMeasure());
      return nextMeasures[index]!;
    };

    chunks.forEach((lyric) => {
      let measure = measureAt(measureIndex);
      let startUnit = trackEndUnit(measure, "lyrics");
      if (!canPlaceSegment(measure, "lyrics", startUnit, durationUnits.Quarter)) {
        measureIndex += 1;
        measure = measureAt(measureIndex);
        startUnit = trackEndUnit(measure, "lyrics");
      }
      if (!canPlaceSegment(measure, "lyrics", startUnit, durationUnits.Quarter)) {
        measureIndex += 1;
        measure = emptyMeasure();
        nextMeasures.splice(measureIndex, 0, measure);
        startUnit = 0;
      }
      const eventId = localId("lyric-event");
      const segment: CheerLyricSegment = { id: localId("lyric-piece"), eventId, startUnit, units: durationUnits.Quarter, duration: "Quarter", timingType: "Note", continuesFromPrevious: false, continuesToNext: false, lyric, audience: "All" };
      lastEventId = eventId;
      nextMeasures[measureIndex] = { ...measure, lyricSegments: [...measure.lyricSegments, segment] };
    });

    onChange({ ...draft, measures: nextMeasures });
    const lastMeasure = nextMeasures[measureIndex]!;
    setActiveMeasureId(lastMeasure.id);
    setMeasureWarnings({});
    setMessage(measureIndex > startingIndex ? `Continued this lyric line into Measure ${measureIndex + 1}.` : `Added this lyric line to Measure ${measureIndex + 1}.`);
    setDrawerOpen(false);
    if (lastEventId) setSelection({ track: "lyrics", eventId: lastEventId, control: "lyrics" });
  };

  const closeHowTo = (dontShowAgain: boolean) => {
    if (dontShowAgain) window.localStorage.setItem(teachingDismissalKey, "true");
    setShowHowTo(false);
  };

  const confirmMeasureIndex = confirmDeleteId ? draft.measures.findIndex((measure) => measure.id === confirmDeleteId) : -1;

  return (
    <div className="cheer-builder">
      <header className="cheer-builder__heading"><div><span className="eyebrow">{draft.sport} · 4/4 Crowd choreography</span><h2>{draft.title}</h2><p>Click any available rhythmic position to place an Action or Lyric.</p></div><div><button type="button" aria-expanded={recordingOpen} onClick={() => setRecordingOpen((current) => !current)}>{draft.recordingUrl ? "Recording" : "Record"}</button><button type="button" onClick={() => setShowHowTo(true)}>How To</button><button className="cheer-primary-button" type="button" disabled={!hasTimedSegments} onClick={onFinish}>Finish Cheer</button></div></header>
      {recordingOpen ? <CheerRecording recordingUrl={draft.recordingUrl} onChange={(recordingUrl) => onChange({ ...draft, recordingUrl })} /> : null}
      {!hasTimedSegments ? <p className="cheer-builder__save-note">Place an Action or Lyric event before finishing.</p> : null}
      {message ? <p className="cheer-builder__message" role="status">{message}</p> : null}
      <section className="cheer-measures" aria-label="Cheer measures">
        {draft.measures.map((measure, measureIndex) => {
          const actionUsed = measureUsedUnits(measure, "action");
          const lyricUsed = measureUsedUnits(measure, "lyrics");
          return (
            <article className="cheer-measure" key={measure.id} data-active={activeMeasureId === measure.id ? "true" : undefined}>
              <header><div><span>Measure {measureIndex + 1}</span><strong>Action {actionUsed / 4}/4 · Lyrics {lyricUsed / 4}/4</strong></div><button className="cheer-delete-measure" type="button" disabled={draft.measures.length === 1} onClick={() => setConfirmDeleteId(measure.id)}>Delete Measure</button></header>
              {measureWarnings[measure.id] ? <p className="cheer-measure__warning" role="alert">{measureWarnings[measure.id]}</p> : null}
              <MeasureTimeline measure={measure} measureIndex={measureIndex} selected={selection} copyBuffer={copyBuffer} onPlace={(track, startUnit) => placeSegment(measure.id, track, startUnit)} onSelect={(next) => { setSelection(next); setActiveMeasureId(measure.id); setMeasureWarnings({}); if (!copyBuffer) setMessage(""); }} onUpdateLyric={(eventId, lyric) => updateEvent("lyrics", eventId, { lyric } as Partial<CheerActionSegment & CheerLyricSegment>)} />
            </article>
          );
        })}
      </section>
      <button className="cheer-add-measure" type="button" onClick={addMeasure}>+ Add Measure</button>
      <div className="cheer-builder-dock">
        <section className="cheer-control-tray" aria-label="Selected choreography controls">
          {!selection ? <p>Select an event, its timing symbol, or its WHO route to edit it.</p> : null}
          {selection?.control === "timing" ? <div className="cheer-timing-controls"><strong>Timing</strong><div className="cheer-note-rest-toggle" aria-label="Timing type">{(["Note", "Rest"] as const).map((timingType) => <button key={timingType} type="button" aria-pressed={selectedTimingType === timingType} onClick={() => updateSelected({ timingType })}>{timingType}</button>)}</div><div className="cheer-duration-options">{durationOptions.map((option) => <button className="cheer-duration-option" key={option.value} type="button" aria-label={`${option.value}, ${option.beats}`} aria-pressed={selectedSegment?.duration === option.value} onClick={() => updateSelected({ duration: option.value })}><b>{cheerDurationSymbol(option.value, selectedTimingType)}</b><span>{option.value}</span><small>{option.beats}</small></button>)}</div></div> : null}
          {selection?.control === "action" ? <div><strong>Action</strong><div>{actionOptions.map((option) => <button className="cheer-action-option" key={option.value} type="button" aria-pressed={selectedAction === option.value} onClick={() => updateSelected({ action: option.value })}><b>{option.icon}</b><span>{option.value}</span></button>)}</div></div> : null}
          {selection?.control === "audience" ? <div><strong>WHO · Audience</strong><div>{availableAudiences.map((audience) => <button className="cheer-audience-option" key={audience} type="button" aria-label={audience} aria-pressed={selectedSegment?.audience === audience} onClick={() => updateSelected({ audience })}><AudienceVisual audience={audience} /><span>{audience}</span></button>)}</div></div> : null}
          {selection?.control === "lyrics" ? <p><strong>Lyrics</strong> · Type directly in the selected lyric event or choose a source line below.</p> : null}
          {selection && selection.track !== "rest" ? <button className="cheer-control-tray__copy" type="button" aria-pressed={copyBuffer?.track === selection.track} onClick={copySelected}>Copy {selection.track === "action" ? "Action" : "Lyric"}</button> : null}
          {copyBuffer ? <button className="cheer-control-tray__cancel-copy" type="button" onClick={() => { setCopyBuffer(null); setMessage(""); }}>Cancel Copy</button> : null}
          {selection ? <button className="cheer-control-tray__remove" type="button" onClick={removeSelected}>Remove selected {selection.track === "action" ? "Action" : selection.track === "lyrics" ? "Lyric" : "Rest"}</button> : null}
        </section>
        <section className="cheer-lyrics-drawer" data-open={drawerOpen ? "true" : undefined}>
          <button className="cheer-lyrics-drawer__handle" type="button" aria-expanded={drawerOpen} onClick={() => setDrawerOpen((current) => !current)}><span>Original Lyrics</span><b aria-hidden="true">{drawerOpen ? "⌄" : "⌃"}</b></button>
          {drawerOpen ? <div>{lines.map((line, index) => <button type="button" key={`${line}-${index}`} onClick={() => addLyricSuggestion(line)}><small>{estimateSyllables(line, draft.language) ?? "—"}</small><span>{line}</span><b>Use line</b></button>)}</div> : null}
        </section>
      </div>
      {showHowTo ? <DfenceHowTo onClose={closeHowTo} /> : null}
      {confirmDeleteId && confirmMeasureIndex >= 0 ? <DeleteMeasureDialog measureNumber={confirmMeasureIndex + 1} onCancel={() => setConfirmDeleteId(null)} onConfirm={() => performDeleteMeasure(confirmDeleteId)} /> : null}
    </div>
  );
}
