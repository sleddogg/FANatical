import { CHEER_PLAYBACK_BPM } from "./cheerUtils";
import type { CheerDraft, CheerRecord } from "./types";

export const emptyCheerDraft: CheerDraft = {
  title: "",
  style: "Standard",
  lyrics: "",
  language: "Auto",
  recordingUrl: null,
  bpm: CHEER_PLAYBACK_BPM,
  measures: [{ id: "measure-1", actionSegments: [], lyricSegments: [], restSegments: [] }],
  sport: "Football",
  league: "NFL",
  team: "",
  description: "",
  opponent: "",
};

export const initialCheerLibrary: readonly CheerRecord[] = [{
  id: "cheer-d-fence",
  title: "D-Fence Clap Clap",
  style: "Call & Response",
  lyrics: "D-Fence\nClap, clap\nPatriots\nGo!",
  language: "English",
  recordingUrl: null,
  bpm: CHEER_PLAYBACK_BPM,
  measures: [{
    id: "d-fence-measure",
    actionSegments: [
      { id: "d-fence-clap-1", eventId: "d-fence-clap-1", startUnit: 8, units: 4, duration: "Quarter", timingType: "Note", continuesFromPrevious: false, continuesToNext: false, action: "Clap", audience: "All" },
      { id: "d-fence-clap-2", eventId: "d-fence-clap-2", startUnit: 12, units: 4, duration: "Quarter", timingType: "Note", continuesFromPrevious: false, continuesToNext: false, action: "Clap", audience: "All" },
    ],
    lyricSegments: [
      { id: "d-fence-d", eventId: "d-fence-d", startUnit: 0, units: 4, duration: "Quarter", timingType: "Note", continuesFromPrevious: false, continuesToNext: false, lyric: "D", audience: "End A" },
      { id: "d-fence-fence", eventId: "d-fence-fence", startUnit: 4, units: 4, duration: "Quarter", timingType: "Note", continuesFromPrevious: false, continuesToNext: false, lyric: "FENCE", audience: "End B" },
      { id: "d-fence-patriots-a", eventId: "d-fence-patriots", startUnit: 12, units: 4, duration: "Half", timingType: "Note", continuesFromPrevious: false, continuesToNext: true, lyric: "Patriots", audience: "All" },
    ],
    restSegments: [],
  }, {
    id: "d-fence-measure-2",
    actionSegments: [
      { id: "d-fence-clap-3", eventId: "d-fence-clap-3", startUnit: 0, units: 2, duration: "Eighth", timingType: "Note", continuesFromPrevious: false, continuesToNext: false, action: "Clap", audience: "All" },
      { id: "d-fence-clap-4", eventId: "d-fence-clap-4", startUnit: 2, units: 2, duration: "Eighth", timingType: "Note", continuesFromPrevious: false, continuesToNext: false, action: "Clap", audience: "All" },
      { id: "d-fence-wave", eventId: "d-fence-wave", startUnit: 12, units: 4, duration: "Quarter", timingType: "Note", continuesFromPrevious: false, continuesToNext: false, action: "Wave", audience: "All" },
    ],
    lyricSegments: [
      { id: "d-fence-patriots-b", eventId: "d-fence-patriots", startUnit: 0, units: 4, duration: "Half", timingType: "Note", continuesFromPrevious: true, continuesToNext: false, lyric: "Patriots", audience: "All" },
      { id: "d-fence-go", eventId: "d-fence-go", startUnit: 12, units: 4, duration: "Quarter", timingType: "Note", continuesFromPrevious: false, continuesToNext: false, lyric: "Go!", audience: "All" },
    ],
    restSegments: [
      { id: "d-fence-rest", eventId: "d-fence-rest", startUnit: 8, units: 4, duration: "Quarter", continuesFromPrevious: false, continuesToNext: false, originTrack: "action", action: "Clap", lyric: "", audience: "All" },
    ],
  }],
  teamId: "new-england-patriots",
  description: "Split the crowd for D-Fence, then bring everyone together for two claps.",
  sport: "Football",
  league: "NFL",
  team: "New England Patriots",
  opponent: "",
  publicationStatus: "Published",
  createdBy: "FANatical",
  createdAt: "2026-08-01T18:00:00.000Z",
  bookmarked: false,
}];
