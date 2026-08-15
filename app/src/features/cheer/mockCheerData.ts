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
  sportId: "football",
  leagueId: null,
  teamId: null,
  sport: "Football",
  league: "",
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
  sportId: "football",
  leagueId: "football-nfl",
  teamId: "football-nfl-new-england-patriots",
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

function developmentCheer(input: Pick<CheerRecord, "id" | "title" | "description" | "sportId" | "leagueId" | "teamId" | "sport" | "league" | "team">): CheerRecord {
  const eventId = `${input.id}-event`;
  return {
    ...input,
    style: "Standard",
    lyrics: input.title,
    language: "English",
    recordingUrl: null,
    bpm: CHEER_PLAYBACK_BPM,
    measures: [{
      id: `${input.id}-measure`,
      actionSegments: [{ id: `${eventId}-action`, eventId: `${eventId}-action`, startUnit: 0, units: 2, duration: "Eighth", timingType: "Note", continuesFromPrevious: false, continuesToNext: false, action: "Clap", audience: "All" }],
      lyricSegments: [{ id: `${eventId}-lyric`, eventId: `${eventId}-lyric`, startUnit: 0, units: 4, duration: "Quarter", timingType: "Note", continuesFromPrevious: false, continuesToNext: false, lyric: input.title, audience: "All" }],
      restSegments: [],
    }],
    opponent: "",
    publicationStatus: "Published",
    createdBy: "FANatical",
    createdAt: "2026-08-14T18:00:00.000Z",
    bookmarked: false,
  };
}

export const developmentCheerLibrary: readonly CheerRecord[] = [
  developmentCheer({ id: "cheer-demo-hockey-wide", title: "Hockey Crowd Pulse", description: "A generic Hockey Cheer for any league or team.", sportId: "hockey", leagueId: null, teamId: null, sport: "Hockey", league: "", team: "" }),
  developmentCheer({ id: "cheer-demo-nhl-wide", title: "NHL Ice Roar", description: "A league-wide NHL Cheer for any NHL crowd.", sportId: "hockey", leagueId: "hockey-nhl", teamId: null, sport: "Hockey", league: "NHL", team: "" }),
  developmentCheer({ id: "cheer-demo-oilers", title: "Oil Country Rise", description: "An Edmonton Oilers-specific Cheer.", sportId: "hockey", leagueId: "hockey-nhl", teamId: "hockey-nhl-edmonton-oilers", sport: "Hockey", league: "NHL", team: "Edmonton Oilers" }),
  developmentCheer({ id: "cheer-demo-shl-wide", title: "SHL Ice Thunder", description: "A league-wide Cheer for SHL crowds.", sportId: "hockey", leagueId: "hockey-shl", teamId: null, sport: "Hockey", league: "SHL", team: "" }),
  developmentCheer({ id: "cheer-demo-baseball-wide", title: "Ballpark Rally", description: "A generic Baseball Cheer for any league or team.", sportId: "baseball", leagueId: null, teamId: null, sport: "Baseball", league: "", team: "" }),
];

export const seededCheerLibrary: readonly CheerRecord[] = [...initialCheerLibrary, ...developmentCheerLibrary];
