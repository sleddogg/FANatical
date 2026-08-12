import type { TeamId } from "../../domain/team";

export type CheerStyle = "Standard" | "Echo" | "Call & Response" | "Fight Song" | "Clap Pattern";
export type CheerDuration = "Whole" | "Dotted Half" | "Half" | "Quarter" | "Eighth" | "Sixteenth";
export type CheerTimingType = "Note" | "Rest";
export type CheerContentTrack = "action" | "lyrics";
export type CheerAction = "None" | "Clap" | "Stomp" | "Wave";
export type CrowdAssignment = "All" | "Upper" | "Lower" | "Side A" | "Side B" | "End A" | "End B" | "First Base Side" | "Third Base Side" | "Outfield" | "Backboard Left" | "Backboard Right" | "Uprights Left" | "Uprights Right" | "North" | "East" | "West" | "South";
export type CheerLanguage = "Auto" | "English" | "Other";
export type CheerSport = "Football" | "Baseball" | "Basketball" | "Hockey" | "Soccer" | "Other";
export type CheerPublicationStatus = "Draft" | "Published";

export type CheerActionSegment = Readonly<{
  id: string;
  eventId: string;
  startUnit: number;
  units: number;
  duration: CheerDuration;
  timingType: CheerTimingType;
  continuesFromPrevious: boolean;
  continuesToNext: boolean;
  action: CheerAction;
  audience: CrowdAssignment;
}>;

export type CheerLyricSegment = Readonly<{
  id: string;
  eventId: string;
  startUnit: number;
  units: number;
  duration: CheerDuration;
  timingType: CheerTimingType;
  continuesFromPrevious: boolean;
  continuesToNext: boolean;
  lyric: string;
  audience: CrowdAssignment;
}>;

export type CheerRestSegment = Readonly<{
  id: string;
  eventId: string;
  startUnit: number;
  units: number;
  duration: CheerDuration;
  continuesFromPrevious: boolean;
  continuesToNext: boolean;
  originTrack: CheerContentTrack;
  action: CheerAction;
  lyric: string;
  audience: CrowdAssignment;
}>;

export type CheerMeasure = Readonly<{
  id: string;
  actionSegments: readonly CheerActionSegment[];
  lyricSegments: readonly CheerLyricSegment[];
  restSegments: readonly CheerRestSegment[];
}>;

export type CheerCheckIn = Readonly<{
  level: "Upper" | "Lower";
  eastWest: "East" | "West";
  northSouth: "North" | "South";
}>;

export type CheerRecord = Readonly<{
  id: string;
  title: string;
  style: CheerStyle;
  lyrics: string;
  language: CheerLanguage;
  recordingUrl: string | null;
  bpm: number;
  measures: readonly CheerMeasure[];
  teamId: TeamId;
  description?: string;
  sport: CheerSport;
  league: string;
  team: string;
  opponent: string;
  publicationStatus: CheerPublicationStatus;
  createdBy: "FANatical" | "Demo User";
  createdAt: string;
  bookmarked: boolean;
}>;

export type CheerDraft = Readonly<{
  title: string;
  style: CheerStyle;
  lyrics: string;
  language: CheerLanguage;
  recordingUrl: string | null;
  bpm: number;
  measures: readonly CheerMeasure[];
  sport: CheerSport;
  league: string;
  team: string;
  description: string;
  opponent: string;
}>;
