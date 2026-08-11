import type { CSSProperties } from "react";
import { audienceMatchesCheckIn, segmentPositions } from "./cheerUtils";
import type { CheerCheckIn, CheerRecord } from "./types";

function previewStyle(startUnit: number, units: number): CSSProperties {
  return { gridColumn: `${startUnit + 1} / span ${units}` };
}

export function CheerFollowPreview({ cheer, checkIn }: { readonly cheer: CheerRecord; readonly checkIn: CheerCheckIn }) {
  return (
    <div className="cheer-follow-preview">
      <header><strong>Your checked-in choreography</strong><small>{checkIn.level} · {checkIn.eastWest} · {checkIn.northSouth}</small></header>
      {cheer.measures.map((measure, index) => {
        const actions = segmentPositions(measure.actionSegments).filter(({ segment }) => audienceMatchesCheckIn(segment.audience, checkIn));
        const lyrics = segmentPositions(measure.lyricSegments).filter(({ segment }) => audienceMatchesCheckIn(segment.audience, checkIn));
        return (
          <section key={measure.id} aria-label={`Personalized Measure ${index + 1}`}>
            <b>Measure {index + 1}</b>
            <div className="cheer-follow-preview__lane"><span>ACTION</span><div>{actions.map(({ segment, startUnit, units }) => <i key={segment.id} style={previewStyle(startUnit, units)}>{segment.continuesFromPrevious ? "↪" : segment.timingType === "Rest" ? "Rest" : segment.action}</i>)}</div></div>
            <div className="cheer-follow-preview__lane cheer-follow-preview__lane--timing"><span>TIMING</span><div>{[1, 2, 3, 4].map((beat) => <i key={beat}>{beat}</i>)}</div></div>
            <div className="cheer-follow-preview__lane"><span>LYRICS</span><div>{lyrics.map(({ segment, startUnit, units }) => <i key={segment.id} style={previewStyle(startUnit, units)}>{segment.continuesFromPrevious ? "↪" : segment.timingType === "Rest" ? "Rest" : segment.lyric || "…"}</i>)}</div></div>
          </section>
        );
      })}
      <p>This local preview proves location routing. Realtime synchronized Cheer remains deferred.</p>
    </div>
  );
}
