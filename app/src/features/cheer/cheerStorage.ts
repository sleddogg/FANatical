import type { CheerRecord } from "./types";
import { migrateLegacyAudience } from "./cheerRouting";

const databaseName = "fanatical-cheer";
const databaseVersion = 1;
const storeName = "cheer-library";
const libraryKey = "records";
const fallbackStorageKey = "fanatical.cheer.library";

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
  return {
    ...cheer,
    measures: cheer.measures.map((measure) => ({
      ...measure,
      actionSegments: measure.actionSegments.map((segment) => ({ ...segment, audience: migrateLegacyAudience(segment.audience, cheer.sport) })),
      lyricSegments: measure.lyricSegments.map((segment) => ({ ...segment, audience: migrateLegacyAudience(segment.audience, cheer.sport) })),
      restSegments: measure.restSegments.map((segment) => ({ ...segment, audience: migrateLegacyAudience(segment.audience, cheer.sport) })),
    })),
  };
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
  } catch {
    saveFallback(cheers);
  }
}
