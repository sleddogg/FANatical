import type { CheerRecord } from "./types";

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

function loadFallback(): readonly CheerRecord[] | null {
  try {
    const stored = window.localStorage.getItem(fallbackStorageKey);
    if (!stored) return null;
    const parsed: unknown = JSON.parse(stored);
    return isCheerLibrary(parsed) ? parsed : null;
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
    return isCheerLibrary(result) ? result : null;
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
