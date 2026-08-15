import { loadRexallVenue, resolveRexallSeat, validRexallRows, validRexallSeats } from "../internal/venues/rexallVenueData";
import type { VenueMapping } from "../internal/venues/types";
import type { CheerCheckIn, CheerSport, GeneralLocationCheckIn, MappedVenueCheckIn } from "./types";

export const cheerCheckInStorageKey = "fanatical.cheer.check-in.v2";
export const cheerCheckInChangedEvent = "fanatical:cheer-check-in-changed";
const legacyCheckInSessionKey = "fanatical.cheer.check-in";

export type CheckInVenueOption = Readonly<{
  venue: VenueMapping;
  distanceKm: number | null;
}>;

export type MappedCheckInDraft = MappedVenueCheckIn["raw"];

export type TicketCapture = Readonly<{
  kind: "ticket-file";
  fileName: string;
  mediaType: string;
}>;

export type GeneralLocationRecord = Readonly<{
  id: string;
  name: string;
  locality: string;
  contextKey: string;
  category: "Park" | "Public Square" | "Community Field" | "Event Space";
  coordinates: Readonly<{ latitude: number; longitude: number }> | null;
}>;

// Recognition providers should return this neutral shape. Every provider result
// still passes through the same editable form and venue resolver before saving.
export type TicketExtractionCandidate = Partial<Pick<MappedCheckInDraft, "venueName" | "sport" | "teamEvent" | "section" | "row" | "seat">>;

const mockGeneralLocations: readonly GeneralLocationRecord[] = [{
  id: "location-churchill-square",
  name: "Sir Winston Churchill Square",
  locality: "Edmonton, Alberta",
  contextKey: "edmonton:churchill-square",
  category: "Public Square",
  coordinates: null,
}, {
  id: "location-hawrelak-park",
  name: "William Hawrelak Park",
  locality: "Edmonton, Alberta",
  contextKey: "edmonton:hawrelak-park",
  category: "Park",
  coordinates: null,
}, {
  id: "location-clarke-stadium-field",
  name: "Clarke Stadium Community Field",
  locality: "Edmonton, Alberta",
  contextKey: "edmonton:clarke-community-field",
  category: "Community Field",
  coordinates: null,
}, {
  id: "location-northlands-event-centre",
  name: "Northlands Community Event Space",
  locality: "Edmonton, Alberta",
  contextKey: "edmonton:northlands-community-event-space",
  category: "Event Space",
  coordinates: null,
}];

export function loadCheckInVenues(): readonly CheckInVenueOption[] {
  return [{ venue: loadRexallVenue(), distanceKm: null }];
}

export function loadGeneralLocations(): readonly GeneralLocationRecord[] {
  return mockGeneralLocations;
}

export function emptyMappedCheckInDraft(method: MappedCheckInDraft["method"]): MappedCheckInDraft {
  return { method, eventId: "", venueId: "", venueName: "", sport: "Other", teamEvent: "", section: "", row: "", seat: "" };
}

export function configuredVenueSports(venue: VenueMapping): readonly CheerSport[] {
  return venue.sports.map((configuration) => configuration.sport).filter((sport): sport is CheerSport => ["Football", "Baseball", "Basketball", "Hockey", "Soccer", "Other"].includes(sport));
}

export function configuredTeamEvents(venue: VenueMapping, sport: CheerSport) {
  const configuration = venue.sports.find((candidate) => candidate.sport === sport);
  if (!configuration) return [];
  return venue.teamProfiles
    .filter((profile) => configuration.teamProfileIds.includes(profile.id))
    .map((profile) => ({ ...profile, eventId: `mock-event:${venue.id}:${profile.id}:current` }));
}

function legacyMappedEventId(venue: VenueMapping, draft: Pick<MappedCheckInDraft, "sport" | "teamEvent">) {
  const configuredEvent = configuredTeamEvents(venue, draft.sport)
    .find((event) => event.teamName.toLocaleLowerCase() === draft.teamEvent.trim().toLocaleLowerCase());
  const eventSlug = draft.teamEvent.trim().toLocaleLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "venue-event";
  return configuredEvent?.eventId ?? `mock-event:${venue.id}:${eventSlug}:current`;
}

export function venueRows(venue: VenueMapping, section: string) {
  return validRexallRows(venue, section);
}

export function venueSeats(venue: VenueMapping, section: string, row: string) {
  return validRexallSeats(venue, section, row);
}

export function resolveMappedCheckIn(venue: VenueMapping, draft: MappedCheckInDraft): MappedVenueCheckIn | null {
  const resolution = resolveRexallSeat(venue, draft.section, draft.row, draft.seat);
  if (!resolution) return null;
  return {
    type: "MappedVenue",
    raw: { ...draft, eventId: draft.eventId || legacyMappedEventId(venue, draft), venueId: venue.id, venueName: venue.name },
    resolved: {
      level: resolution.level.value,
      side: resolution.side.value,
      end: resolution.end.value,
      sources: { level: resolution.level.source, side: resolution.side.source, end: resolution.end.source },
    },
    confirmedAt: new Date().toISOString(),
  };
}

export function resolveGeneralLocationCheckIn(location: GeneralLocationRecord): GeneralLocationCheckIn {
  return {
    type: "GeneralLocation",
    location: { id: location.id, name: location.name, locality: location.locality, contextKey: location.contextKey },
    routing: { mode: "AllOnly" },
    confirmedAt: new Date().toISOString(),
  };
}

function isMappedCheckIn(value: unknown): value is MappedVenueCheckIn {
  if (!value || typeof value !== "object") return false;
  const candidate = value as Partial<MappedVenueCheckIn>;
  return Boolean(candidate.raw && candidate.resolved
    && typeof candidate.raw.venueId === "string"
    && typeof candidate.raw.sport === "string"
    && typeof candidate.raw.teamEvent === "string"
    && typeof candidate.raw.section === "string"
    && typeof candidate.raw.row === "string"
    && typeof candidate.raw.seat === "string"
    && (candidate.resolved.level === "Upper" || candidate.resolved.level === "Lower" || candidate.resolved.level === "N/A")
    && (candidate.resolved.side === "Side A" || candidate.resolved.side === "Side B")
    && (candidate.resolved.end === "End A" || candidate.resolved.end === "End B"));
}

function isGeneralLocationCheckIn(value: unknown): value is GeneralLocationCheckIn {
  if (!value || typeof value !== "object") return false;
  const candidate = value as Partial<GeneralLocationCheckIn>;
  return Boolean(candidate.type === "GeneralLocation" && candidate.location
    && typeof candidate.location.id === "string"
    && typeof candidate.location.name === "string"
    && typeof candidate.location.contextKey === "string"
    && candidate.routing?.mode === "AllOnly");
}

function migrateStoredCheckIn(value: unknown): CheerCheckIn | null {
  if (isGeneralLocationCheckIn(value)) return value;
  if (isMappedCheckIn(value)) {
    const raw = value.raw as MappedVenueCheckIn["raw"] & { eventId?: string };
    const venue = loadCheckInVenues().find(({ venue: candidate }) => candidate.id === raw.venueId)?.venue;
    const eventId = raw.eventId || (venue ? legacyMappedEventId(venue, raw) : `mock-event:${raw.venueId}:${raw.teamEvent.trim().toLocaleLowerCase().replace(/[^a-z0-9]+/g, "-") || "venue-event"}:current`);
    return { ...value, type: "MappedVenue", raw: { ...raw, eventId } };
  }
  return null;
}

export function loadCheerCheckIn(): CheerCheckIn | null {
  try {
    const stored = window.localStorage.getItem(cheerCheckInStorageKey);
    if (!stored) return null;
    const migrated = migrateStoredCheckIn(JSON.parse(stored) as unknown);
    if (migrated) window.localStorage.setItem(cheerCheckInStorageKey, JSON.stringify(migrated));
    return migrated;
  } catch {
    return null;
  }
}

export function saveCheerCheckIn(checkIn: CheerCheckIn) {
  window.localStorage.setItem(cheerCheckInStorageKey, JSON.stringify(checkIn));
  window.sessionStorage.removeItem(legacyCheckInSessionKey);
  window.dispatchEvent(new Event(cheerCheckInChangedEvent));
}

export function clearCheerCheckIn() {
  window.localStorage.removeItem(cheerCheckInStorageKey);
  window.sessionStorage.removeItem(legacyCheckInSessionKey);
  window.dispatchEvent(new Event(cheerCheckInChangedEvent));
}
