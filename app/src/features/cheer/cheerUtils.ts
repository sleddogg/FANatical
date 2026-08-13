import type { CheerCheckIn, CheerDuration, CheerLanguage, CheerMeasure, CrowdAssignment } from "./types";

export const MEASURE_CAPACITY_UNITS = 16;
export const CHEER_PLAYBACK_BPM = 60;

export const durationUnits: Readonly<Record<CheerDuration, number>> = {
  Whole: 16,
  "Dotted Half": 12,
  Half: 8,
  "One and a Half": 6,
  "One and a Quarter": 5,
  Quarter: 4,
  "Three Quarter": 3,
  Eighth: 2,
  Sixteenth: 1,
};

export type CheerTrack = "action" | "lyrics";

export function measureUsedUnits(measure: CheerMeasure, track: CheerTrack) {
  const segments = track === "action" ? measure.actionSegments : measure.lyricSegments;
  return [...segments, ...measure.restSegments].reduce((total, segment) => total + segment.units, 0);
}

export function segmentPositions<T extends { readonly startUnit: number; readonly units: number }>(segments: readonly T[]) {
  return [...segments]
    .sort((first, second) => first.startUnit - second.startUnit)
    .map((segment) => ({ segment, startUnit: segment.startUnit, units: segment.units }));
}

export function trackEndUnit(measure: CheerMeasure, track: CheerTrack) {
  const segments = track === "action" ? measure.actionSegments : measure.lyricSegments;
  return [...segments, ...measure.restSegments].reduce((end, segment) => Math.max(end, segment.startUnit + segment.units), 0);
}

export function canPlaceSegment(measure: CheerMeasure, track: CheerTrack, startUnit: number, units: number, ignoredSegmentId?: string) {
  if (startUnit < 0 || startUnit + units > MEASURE_CAPACITY_UNITS) return false;
  const segments = track === "action" ? measure.actionSegments : measure.lyricSegments;
  return [...segments, ...measure.restSegments].every((segment) => {
    if (segment.id === ignoredSegmentId) return true;
    const segmentEnd = segment.startUnit + segment.units;
    return startUnit + units <= segment.startUnit || startUnit >= segmentEnd;
  });
}

export function canPlaceRest(measure: CheerMeasure, startUnit: number, units: number, ignoredEventId?: string) {
  if (startUnit < 0 || startUnit + units > MEASURE_CAPACITY_UNITS) return false;
  return [...measure.actionSegments, ...measure.lyricSegments, ...measure.restSegments].every((segment) => {
    if (segment.eventId === ignoredEventId) return true;
    const segmentEnd = segment.startUnit + segment.units;
    return startUnit + units <= segment.startUnit || startUnit >= segmentEnd;
  });
}

export function audienceMatchesCheckIn(audience: CrowdAssignment, checkIn: CheerCheckIn) {
  if (checkIn.type === "GeneralLocation") return audience === "All";
  return audience === "All" || audience === checkIn.resolved.level || audience === checkIn.resolved.side || audience === checkIn.resolved.end;
}

export function estimateSyllables(value: string, language: CheerLanguage = "Auto") {
  const text = value.trim();
  if (!text || language === "Other") return null;
  const words = text.match(/[A-Za-zÀ-ÖØ-öø-ÿ]+(?:['’-][A-Za-zÀ-ÖØ-öø-ÿ]+)*/g);
  if (!words?.length) return null;

  return words.reduce((total, originalWord) => {
    const word = originalWord.toLowerCase().replace(/[^a-zà-öø-ÿ]/g, "");
    if (word.length <= 3) return total + 1;
    const withoutSilentE = word.replace(/(?:[^laeiouy]es|ed|[^laeiouy]e)$/i, "");
    const groups = withoutSilentE.match(/[aeiouyà-öø-ÿ]+/g)?.length ?? 1;
    return total + Math.max(1, groups);
  }, 0);
}

function wordSyllables(word: string) {
  return estimateSyllables(word, "English") ?? 1;
}

export function distributeLyricLine(line: string, slotCount: number) {
  const words = line.trim().split(/\s+/).filter(Boolean);
  if (!words.length || slotCount <= 0) return [];
  const actualSlots = Math.min(slotCount, words.length);
  const totalSyllables = words.reduce((total, word) => total + wordSyllables(word), 0);
  const target = totalSyllables / actualSlots;
  const chunks: string[] = [];
  let currentWords: string[] = [];
  let currentSyllables = 0;

  words.forEach((word, index) => {
    currentWords.push(word);
    currentSyllables += wordSyllables(word);
    const remainingWords = words.length - index - 1;
    const remainingSlots = actualSlots - chunks.length - 1;
    if (remainingSlots > 0 && (currentSyllables >= target || remainingWords === remainingSlots)) {
      chunks.push(currentWords.join(" "));
      currentWords = [];
      currentSyllables = 0;
    }
  });
  if (currentWords.length) chunks.push(currentWords.join(" "));
  return chunks;
}

export function lyricLines(lyrics: string) {
  return lyrics.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
}
