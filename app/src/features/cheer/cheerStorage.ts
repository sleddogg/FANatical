import type { CheerRecord } from "./types";
import { findOfficialLeague, findOfficialLeagueByName, findOfficialSportById, findOfficialSportByName, findOfficialTeam, findOfficialTeamByName } from "../../data/officialSportsDatabase";
import { migrateLegacyAudience } from "./cheerRouting";
import { withPublishTimeLiveVariants } from "./cheerLiveVariants";

const databaseName = "fanatical-cheer";
const databaseVersion = 1;
const storeName = "cheer-library";
const libraryKey = "records";
const fallbackStorageKey = "fanatical.cheer.library";
export const cheerLibraryChangedEvent = "fanatical:cheer-library-changed";

function announceLibraryChange() {
  window.dispatchEvent(new Event(cheerLibraryChangedEvent));
}

function isCheerLibrary(value: unknown): value is readonly CheerRecord[] {
  return Array.isArray(value) && value.every((record) => {
    if (!record || typeof record !== "object") return false;
    const candidate = record as Partial<CheerRecord>;
    return typeof candidate.id === "string"
      && typeof candidate.title === "string"
      && typeof candidate.recordingUrl !== "undefined"
      && Array.isArray(candidate.measures)
      && (candidate.publicationStatus === "Draft" || candidate.publicationStatus === "Published");
  });
}

function migrateStoredCheer(cheer: CheerRecord): CheerRecord {
  const stored = cheer as CheerRecord & { sportId?: unknown; leagueId?: unknown; teamId?: unknown };
  const sport = findOfficialSportById(typeof stored.sportId === "string" ? stored.sportId : null)
    ?? findOfficialSportByName(cheer.sport)
    ?? findOfficialSportByName("Football")!;
  const hasControlledMetadata = typeof stored.sportId === "string" && Object.prototype.hasOwnProperty.call(stored, "leagueId");
  const normalizedTitle = cheer.title.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
  const canRetainSeedClassification = cheer.id === "cheer-d-fence" || normalizedTitle === "defense" || normalizedTitle === "d fence clap clap";
  const storedLeague = hasControlledMetadata
    ? findOfficialLeague(typeof stored.leagueId === "string" ? stored.leagueId : null)
    : canRetainSeedClassification ? findOfficialLeagueByName(sport.id, cheer.league) : null;
  const league = storedLeague?.parentSportId === sport.id ? storedLeague : null;
  const storedTeam = hasControlledMetadata
    ? findOfficialTeam(typeof stored.teamId === "string" ? stored.teamId : null)
    : canRetainSeedClassification && league ? findOfficialTeamByName(league.id, cheer.team) : null;
  const team = storedTeam?.parentLeagueId === league?.id ? storedTeam : null;

  const migrated: CheerRecord = {
    ...cheer,
    sportId: sport.id,
    leagueId: league?.id ?? null,
    teamId: team?.id ?? null,
    sport: sport.displayName,
    league: league?.displayName ?? "",
    team: team?.displayName ?? "",
    measures: cheer.measures.map((measure) => ({
      ...measure,
      actionSegments: measure.actionSegments.map((segment) => ({ ...segment, audience: migrateLegacyAudience(segment.audience, sport.displayName) })),
      lyricSegments: measure.lyricSegments.map((segment) => ({ ...segment, audience: migrateLegacyAudience(segment.audience, sport.displayName) })),
      restSegments: measure.restSegments.map((segment) => ({ ...segment, audience: migrateLegacyAudience(segment.audience, sport.displayName) })),
    })),
  };
  // One targeted migration seeds the existing published `test` Cheer. Other
  // stored Cheers are deliberately not backfilled in this pass.
  return migrated.title.trim().toLocaleLowerCase() === "test"
    && migrated.publicationStatus === "Published"
    && !migrated.liveVariants?.length
    ? withPublishTimeLiveVariants(migrated)
    : migrated;
}

function migrateStoredLibrary(value: unknown): readonly CheerRecord[] | null {
  return isCheerLibrary(value) ? value.map(migrateStoredCheer) : null;
}

function loadFallback(): readonly CheerRecord[] | null {
  try {
    const stored = window.localStorage.getItem(fallbackStorageKey);
    if (!stored) return null;
    const parsed: unknown = JSON.parse(stored);
    return migrateStoredLibrary(parsed);
  } catch {
    return null;
  }
}

function saveFallback(cheers: readonly CheerRecord[]) {
  window.localStorage.setItem(fallbackStorageKey, JSON.stringify(cheers));
}

function openDatabase(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = window.indexedDB.open(databaseName, databaseVersion);
    request.addEventListener("upgradeneeded", () => {
      if (!request.result.objectStoreNames.contains(storeName)) request.result.createObjectStore(storeName);
    });
    request.addEventListener("success", () => resolve(request.result));
    request.addEventListener("error", () => reject(request.error));
  });
}

export async function loadCheerLibrary(): Promise<readonly CheerRecord[] | null> {
  if (!("indexedDB" in window)) return loadFallback();
  try {
    const database = await openDatabase();
    const result = await new Promise<unknown>((resolve, reject) => {
      const request = database.transaction(storeName, "readonly").objectStore(storeName).get(libraryKey);
      request.addEventListener("success", () => resolve(request.result));
      request.addEventListener("error", () => reject(request.error));
    });
    database.close();
    return migrateStoredLibrary(result);
  } catch {
    return loadFallback();
  }
}

export async function saveCheerLibrary(cheers: readonly CheerRecord[]): Promise<void> {
  if (!("indexedDB" in window)) {
    saveFallback(cheers);
    announceLibraryChange();
    return;
  }
  try {
    const database = await openDatabase();
    await new Promise<void>((resolve, reject) => {
      const transaction = database.transaction(storeName, "readwrite");
      transaction.objectStore(storeName).put(cheers, libraryKey);
      transaction.addEventListener("complete", () => resolve());
      transaction.addEventListener("error", () => reject(transaction.error));
      transaction.addEventListener("abort", () => reject(transaction.error));
    });
    database.close();
    announceLibraryChange();
  } catch {
    saveFallback(cheers);
    announceLibraryChange();
  }
}
