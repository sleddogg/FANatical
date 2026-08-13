import type { SectionException, TeamEndUse, TeamLevelUse, TeamSeatingProfile, TeamSideUse, VenueEnd, VenueLevel, VenueMapping, VenueSeatInventoryRule, VenueSectionMapping, VenueSelectableValues, VenueSide, VenueSportConfiguration } from "./types";

export const rexallStorageKey = "fanatical.internal.venues.rexall-place.v1";
export const venueRoutingConventionVersion = 2;

const lowerSections = [101, 102, 104, 106, 108, 110, 112, 114, 116, 118, 119, 120, 122, 124, 126, 128, 130, 132, 134, 136];
const upperSections = [201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 301, 302, 303, 304, 305, 333, 334, 335, 336, 337];

// FANatical venue convention: orient the playing surface's long axis horizontally.
// Side A is the upper long side, Side B the lower; End A is the left half, End B the right.
const sideASections = new Set([110, 112, 114, 116, 118, 119, 120, 122, 124, 126, 128, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227]);
const endASections = new Set([102, 104, 106, 108, 110, 112, 114, 116, 118, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 301, 302, 303, 304, 305]);

function exception(id: string, seatStart: number, seatEnd: number, overrides: Partial<Pick<SectionException, "side" | "end">>): SectionException {
  return { id, rowStart: "", rowEnd: "", seatStart, seatEnd, level: null, side: overrides.side ?? null, end: overrides.end ?? null };
}

function exceptionsFor(section: number): readonly SectionException[] {
  if (section === 101 || section === 119) return [
    exception(`${section}-end-a-seats`, 1, 10, { end: "End A" }),
    exception(`${section}-end-b-seats`, 11, 24, { end: "End B" }),
  ];
  if (section === 110 || section === 128) return [
    exception(`${section}-side-a-seats`, 1, 10, { side: "Side A" }),
    exception(`${section}-side-b-seats`, 11, 24, { side: "Side B" }),
  ];
  return [];
}

function sectionMapping(section: number): VenueSectionMapping {
  return {
    section: String(section),
    level: lowerSections.includes(section) ? "Lower" : "Upper",
    side: sideASections.has(section) ? "Side A" : "Side B",
    end: endASections.has(section) ? "End A" : "End B",
    exceptions: exceptionsFor(section),
  };
}

const seededProfiles: readonly TeamSeatingProfile[] = [{
  id: "edmonton-oilers",
  teamName: "Edmonton Oilers",
  levels: "Upper + Lower",
  sides: "Both",
  ends: "Both",
}, {
  id: "edmonton-oil-kings",
  teamName: "Edmonton Oil Kings",
  levels: "Lower only",
  sides: "Both",
  ends: "Both",
}];

const numericValues = (start: number, end: number): VenueSelectableValues => ({ values: [], ranges: [{ start: String(start), end: String(end) }] });

const seededSeatInventoryRules: readonly VenueSeatInventoryRule[] = [{
  id: "rexall-lower-bowl",
  sections: [],
  levels: ["Lower"],
  rows: numericValues(1, 30),
  seats: numericValues(1, 24),
  rowSeatOverrides: [],
}, {
  id: "rexall-upper-bowl",
  sections: [],
  levels: ["Upper"],
  rows: numericValues(1, 20),
  seats: numericValues(1, 24),
  rowSeatOverrides: [],
}];

export const seededRexallVenue: VenueMapping = {
  id: "venue-rexall-place",
  slug: "rexall-place",
  routingConventionVersion: venueRoutingConventionVersion,
  name: "Rexall Place",
  location: "Edmonton, Alberta",
  sectionFormat: "Numeric",
  seatingChartImageUrl: "https://seatingchartview.com/wp-content/uploads/2016/01/Rexall-Place-Hockey-Seating-Chart-768x724.jpg",
  seatingChartSourceLabel: "Northlands Coliseum hockey seating chart — SeatingChartView",
  seatingChartSourceUrl: "https://seatingchartview.com/northlands-coliseum/",
  sections: [...lowerSections, ...upperSections].sort((first, second) => first - second).map(sectionMapping),
  teamProfiles: seededProfiles,
  sports: [{ sport: "Hockey", teamProfileIds: seededProfiles.map((profile) => profile.id) }],
  seatInventoryRules: seededSeatInventoryRules,
  updatedAt: "2026-08-11T00:00:00.000Z",
};

type UnknownRecord = Record<string, unknown>;

function isRecord(value: unknown): value is UnknownRecord {
  return Boolean(value) && typeof value === "object";
}

function migrateLevel(value: unknown): VenueLevel {
  if (value === "Upper" || value === "Lower" || value === "N/A") return value;
  return "N/A";
}

type StoredRoutingConvention = "compass" | "pre-correction" | "venue-relative";

function normalizeSide(value: unknown): VenueSide {
  return value === "Side B" ? "Side B" : "Side A";
}

function normalizeEnd(value: unknown): VenueEnd {
  return value === "End B" ? "End B" : "End A";
}

function compassToSide(value: unknown): VenueSide {
  return value === "South" ? "Side B" : "Side A";
}

function compassToEnd(value: unknown): VenueEnd {
  return value === "East" ? "End B" : "End A";
}

function previousEndToSide(value: unknown): VenueSide {
  return value === "End B" ? "Side B" : "Side A";
}

function previousSideToEnd(value: unknown): VenueEnd {
  return value === "Side A" ? "End B" : "End A";
}

function migrateTeamLevels(value: unknown): TeamLevelUse {
  if (value === "Upper + Lower" || value === "Upper only" || value === "Lower only" || value === "N/A") return value;
  return value === "Not Applicable" ? "N/A" : "Upper + Lower";
}

function normalizeTeamSides(value: unknown): TeamSideUse {
  if (value === "Side A only" || value === "Side B only" || value === "Both") return value;
  return "Both";
}

function normalizeTeamEnds(value: unknown): TeamEndUse {
  if (value === "End A only" || value === "End B only" || value === "Both") return value;
  return "Both";
}

function compassToTeamSides(value: unknown): TeamSideUse {
  if (value === "North only") return "Side A only";
  return value === "South only" ? "Side B only" : "Both";
}

function compassToTeamEnds(value: unknown): TeamEndUse {
  if (value === "West only") return "End A only";
  return value === "East only" ? "End B only" : "Both";
}

function previousEndsToTeamSides(value: unknown): TeamSideUse {
  if (value === "End A only") return "Side A only";
  return value === "End B only" ? "Side B only" : "Both";
}

function previousSidesToTeamEnds(value: unknown): TeamEndUse {
  if (value === "Side B only") return "End A only";
  return value === "Side A only" ? "End B only" : "Both";
}

function storedConvention(value: UnknownRecord): StoredRoutingConvention {
  if (value.routingConventionVersion === venueRoutingConventionVersion) return "venue-relative";
  const hasCompassSections = Array.isArray(value.sections) && value.sections.some((section) => isRecord(section) && ("eastWest" in section || "northSouth" in section));
  const hasCompassProfiles = Array.isArray(value.teamProfiles) && value.teamProfiles.some((profile) => isRecord(profile) && ("eastWest" in profile || "northSouth" in profile));
  return hasCompassSections || hasCompassProfiles ? "compass" : "pre-correction";
}

function rawSideValue(value: UnknownRecord, convention: StoredRoutingConvention): unknown {
  if (convention === "compass") return value.northSouth;
  return convention === "pre-correction" ? value.end : value.side;
}

function rawEndValue(value: UnknownRecord, convention: StoredRoutingConvention): unknown {
  if (convention === "compass") return value.eastWest;
  return convention === "pre-correction" ? value.side : value.end;
}

function migrateSideValue(value: unknown, convention: StoredRoutingConvention): VenueSide {
  if (convention === "compass") return compassToSide(value);
  return convention === "pre-correction" ? previousEndToSide(value) : normalizeSide(value);
}

function migrateEndValue(value: unknown, convention: StoredRoutingConvention): VenueEnd {
  if (convention === "compass") return compassToEnd(value);
  return convention === "pre-correction" ? previousSideToEnd(value) : normalizeEnd(value);
}

function migrateException(value: unknown, convention: StoredRoutingConvention): SectionException | null {
  if (!isRecord(value) || typeof value.id !== "string") return null;
  const levelValue = value.level;
  const sideValue = rawSideValue(value, convention);
  const endValue = rawEndValue(value, convention);
  return {
    id: value.id,
    rowStart: typeof value.rowStart === "string" ? value.rowStart : "",
    rowEnd: typeof value.rowEnd === "string" ? value.rowEnd : "",
    seatStart: typeof value.seatStart === "number" ? value.seatStart : null,
    seatEnd: typeof value.seatEnd === "number" ? value.seatEnd : null,
    level: levelValue === null || typeof levelValue === "undefined" ? null : migrateLevel(levelValue),
    side: sideValue === null || typeof sideValue === "undefined" ? null : migrateSideValue(sideValue, convention),
    end: endValue === null || typeof endValue === "undefined" ? null : migrateEndValue(endValue, convention),
  };
}

function migrateSection(value: unknown, convention: StoredRoutingConvention): VenueSectionMapping | null {
  if (!isRecord(value) || typeof value.section !== "string") return null;
  return {
    section: value.section,
    level: migrateLevel(value.level),
    side: migrateSideValue(rawSideValue(value, convention), convention),
    end: migrateEndValue(rawEndValue(value, convention), convention),
    exceptions: Array.isArray(value.exceptions) ? value.exceptions.map((rule) => migrateException(rule, convention)).filter((rule): rule is SectionException => rule !== null) : [],
  };
}

function migrateProfile(value: unknown, convention: StoredRoutingConvention): TeamSeatingProfile | null {
  if (!isRecord(value) || typeof value.id !== "string" || typeof value.teamName !== "string") return null;
  const sides = convention === "compass"
    ? compassToTeamSides(value.northSouth)
    : convention === "pre-correction" ? previousEndsToTeamSides(value.ends) : normalizeTeamSides(value.sides);
  const ends = convention === "compass"
    ? compassToTeamEnds(value.eastWest)
    : convention === "pre-correction" ? previousSidesToTeamEnds(value.sides) : normalizeTeamEnds(value.ends);
  return {
    id: value.id,
    teamName: value.teamName,
    levels: migrateTeamLevels(value.levels),
    sides,
    ends,
  };
}

function stringValues(value: unknown): readonly string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

function migrateSelectableValues(value: unknown, fallback: VenueSelectableValues): VenueSelectableValues {
  if (!isRecord(value)) return fallback;
  const ranges = Array.isArray(value.ranges) ? value.ranges.flatMap((range) => isRecord(range) && typeof range.start === "string" && typeof range.end === "string" ? [{ start: range.start, end: range.end }] : []) : [];
  const values = stringValues(value.values);
  return values.length || ranges.length ? { values, ranges } : fallback;
}

function migrateSeatInventoryRules(value: unknown): readonly VenueSeatInventoryRule[] {
  if (!Array.isArray(value)) return seededRexallVenue.seatInventoryRules;
  const rules = value.flatMap((candidate, index) => {
    if (!isRecord(candidate)) return [];
    const fallback = seededRexallVenue.seatInventoryRules[index] ?? seededRexallVenue.seatInventoryRules[0]!;
    const levels = stringValues(candidate.levels).filter((level): level is VenueLevel => level === "Upper" || level === "Lower" || level === "N/A");
    const rowSeatOverrides = Array.isArray(candidate.rowSeatOverrides) ? candidate.rowSeatOverrides.flatMap((override) => isRecord(override) ? [{ rowStart: typeof override.rowStart === "string" ? override.rowStart : "", rowEnd: typeof override.rowEnd === "string" ? override.rowEnd : "", seats: migrateSelectableValues(override.seats, fallback.seats) }] : []) : [];
    return [{
      id: typeof candidate.id === "string" ? candidate.id : `seat-inventory-${index + 1}`,
      sections: stringValues(candidate.sections),
      levels,
      rows: migrateSelectableValues(candidate.rows, fallback.rows),
      seats: migrateSelectableValues(candidate.seats, fallback.seats),
      rowSeatOverrides,
    }];
  });
  return rules.length ? rules : seededRexallVenue.seatInventoryRules;
}

function migrateVenueSports(value: unknown): readonly VenueSportConfiguration[] {
  if (!Array.isArray(value)) return seededRexallVenue.sports;
  const sports = value.flatMap((candidate) => isRecord(candidate) && typeof candidate.sport === "string" ? [{ sport: candidate.sport, teamProfileIds: stringValues(candidate.teamProfileIds) }] : []);
  return sports.length ? sports : seededRexallVenue.sports;
}

function migrateVenueMapping(value: unknown): VenueMapping | null {
  if (!isRecord(value) || value.slug !== "rexall-place" || typeof value.name !== "string" || !Array.isArray(value.sections) || !Array.isArray(value.teamProfiles)) return null;
  const convention = storedConvention(value);
  const sections = value.sections.map((section) => migrateSection(section, convention)).filter((section): section is VenueSectionMapping => section !== null);
  const teamProfiles = value.teamProfiles.map((profile) => migrateProfile(profile, convention)).filter((profile): profile is TeamSeatingProfile => profile !== null);
  if (!sections.length) return null;
  return {
    id: typeof value.id === "string" ? value.id : seededRexallVenue.id,
    slug: "rexall-place",
    routingConventionVersion: venueRoutingConventionVersion,
    name: value.name,
    location: typeof value.location === "string" ? value.location : seededRexallVenue.location,
    sectionFormat: value.sectionFormat === "Mixed" ? "Mixed" : "Numeric",
    seatingChartImageUrl: typeof value.seatingChartImageUrl === "string" ? value.seatingChartImageUrl : seededRexallVenue.seatingChartImageUrl,
    seatingChartSourceLabel: typeof value.seatingChartSourceLabel === "string" ? value.seatingChartSourceLabel : seededRexallVenue.seatingChartSourceLabel,
    seatingChartSourceUrl: typeof value.seatingChartSourceUrl === "string" ? value.seatingChartSourceUrl : seededRexallVenue.seatingChartSourceUrl,
    sections,
    teamProfiles,
    sports: migrateVenueSports(value.sports),
    seatInventoryRules: migrateSeatInventoryRules(value.seatInventoryRules),
    updatedAt: typeof value.updatedAt === "string" ? value.updatedAt : seededRexallVenue.updatedAt,
  };
}

export function loadRexallVenue(): VenueMapping {
  try {
    const saved = window.localStorage.getItem(rexallStorageKey);
    if (!saved) return seededRexallVenue;
    const migrated = migrateVenueMapping(JSON.parse(saved) as unknown);
    if (!migrated) return seededRexallVenue;
    window.localStorage.setItem(rexallStorageKey, JSON.stringify(migrated));
    return migrated;
  } catch {
    return seededRexallVenue;
  }
}

export function saveRexallVenue(venue: VenueMapping): VenueMapping {
  const saved = { ...venue, updatedAt: new Date().toISOString() };
  window.localStorage.setItem(rexallStorageKey, JSON.stringify(saved));
  return saved;
}

function rangeMatches(value: string, start: string, end: string): boolean {
  if (!start && !end) return true;
  if (!value) return false;
  const numericValue = Number(value);
  const numericStart = Number(start);
  const numericEnd = Number(end);
  if (Number.isFinite(numericValue) && (!start || Number.isFinite(numericStart)) && (!end || Number.isFinite(numericEnd))) {
    return (!start || numericValue >= numericStart) && (!end || numericValue <= numericEnd);
  }
  const normalized = value.trim().toUpperCase();
  return (!start || normalized >= start.trim().toUpperCase()) && (!end || normalized <= end.trim().toUpperCase());
}

function exceptionMatches(rule: SectionException, row: string, seat: string | number): boolean {
  const rowMatches = rangeMatches(row, rule.rowStart, rule.rowEnd);
  const numericSeat = typeof seat === "number" ? seat : Number(seat);
  const hasSeatBoundary = rule.seatStart !== null || rule.seatEnd !== null;
  const seatMatches = !hasSeatBoundary || (Number.isFinite(numericSeat) && (rule.seatStart === null || numericSeat >= rule.seatStart) && (rule.seatEnd === null || numericSeat <= rule.seatEnd));
  return rowMatches && seatMatches;
}

function resolveAxis<T extends VenueLevel | VenueSide | VenueEnd>(section: VenueSectionMapping, row: string, seat: string | number, axis: "level" | "side" | "end"): { value: T; source: string } {
  const matchingRule = section.exceptions.find((rule) => exceptionMatches(rule, row, seat) && rule[axis] !== null);
  if (matchingRule) {
    const qualifiers = [matchingRule.rowStart || matchingRule.rowEnd ? `row ${matchingRule.rowStart || "first"}–${matchingRule.rowEnd || "last"}` : "", matchingRule.seatStart !== null || matchingRule.seatEnd !== null ? `seats ${matchingRule.seatStart ?? "first"}–${matchingRule.seatEnd ?? "last"}` : ""].filter(Boolean).join(", ");
    return { value: matchingRule[axis] as T, source: `Section ${section.section} ${qualifiers} exception` };
  }
  return { value: section[axis] as T, source: `Section ${section.section} mapping` };
}

export function resolveRexallSeat(venue: VenueMapping, sectionValue: string, row: string, seat: string | number) {
  const normalizedSection = sectionValue.trim().replace(/^section\s*/i, "");
  const section = venue.sections.find((candidate) => candidate.section.toLowerCase() === normalizedSection.toLowerCase());
  if (!section) return null;
  return {
    section,
    level: resolveAxis<VenueLevel>(section, row, seat, "level"),
    side: resolveAxis<VenueSide>(section, row, seat, "side"),
    end: resolveAxis<VenueEnd>(section, row, seat, "end"),
  };
}

function expandSelectableValues(configuration: VenueSelectableValues): readonly string[] {
  const values = [...configuration.values];
  for (const range of configuration.ranges) {
    const startNumber = Number(range.start);
    const endNumber = Number(range.end);
    if (Number.isInteger(startNumber) && Number.isInteger(endNumber)) {
      const direction = startNumber <= endNumber ? 1 : -1;
      for (let value = startNumber; direction > 0 ? value <= endNumber : value >= endNumber; value += direction) values.push(String(value));
      continue;
    }
    const start = range.start.trim().toUpperCase();
    const end = range.end.trim().toUpperCase();
    if (start.length === 1 && end.length === 1) {
      const direction = start.charCodeAt(0) <= end.charCodeAt(0) ? 1 : -1;
      for (let value = start.charCodeAt(0); direction > 0 ? value <= end.charCodeAt(0) : value >= end.charCodeAt(0); value += direction) values.push(String.fromCharCode(value));
    } else {
      values.push(range.start);
      if (range.end !== range.start) values.push(range.end);
    }
  }
  return [...new Set(values)];
}

function inventoryRuleFor(venue: VenueMapping, sectionValue: string) {
  const section = venue.sections.find((candidate) => candidate.section.toLowerCase() === sectionValue.trim().replace(/^section\s*/i, "").toLowerCase());
  if (!section) return null;
  const rule = venue.seatInventoryRules.find((candidate) => candidate.sections.includes(section.section))
    ?? venue.seatInventoryRules.find((candidate) => candidate.levels.includes(section.level));
  return rule ? { rule, section } : null;
}

export function validRexallRows(venue: VenueMapping, sectionValue: string): readonly string[] {
  const inventory = inventoryRuleFor(venue, sectionValue);
  return inventory ? expandSelectableValues(inventory.rule.rows) : [];
}

export function validRexallSeats(venue: VenueMapping, sectionValue: string, row: string): readonly string[] {
  const inventory = inventoryRuleFor(venue, sectionValue);
  if (!inventory) return [];
  const override = inventory.rule.rowSeatOverrides.find((candidate) => rangeMatches(row, candidate.rowStart, candidate.rowEnd));
  return expandSelectableValues(override?.seats ?? inventory.rule.seats);
}
