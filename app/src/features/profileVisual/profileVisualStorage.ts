import { createUuid } from "../../lib/uuid";
import { defaultProfileVisualCrop, type ProfileVisualImageRecord, type ProfileVisualLibrary, type ProfileVisualVariant } from "./types";

const databaseName = "fanatical-profile-media";
const databaseVersion = 2;
const legacyImageStore = "profile-visual-images";
const libraryStore = "profile-visual-library";
const supportedTypes = new Set(["image/jpeg", "image/png", "image/webp"]);

type StoredProfileVisual = ProfileVisualImageRecord & Readonly<{ id: string; active: boolean }>;

function openDatabase() {
  return new Promise<IDBDatabase>((resolve, reject) => {
    if (!window.indexedDB) return reject(new Error("Persistent image storage is unavailable in this browser."));
    const request = window.indexedDB.open(databaseName, databaseVersion);
    request.onerror = () => reject(request.error ?? new Error("Could not open persistent image storage."));
    request.onupgradeneeded = () => {
      const database = request.result;
      const nextStore = database.objectStoreNames.contains(libraryStore)
        ? request.transaction!.objectStore(libraryStore)
        : database.createObjectStore(libraryStore, { keyPath: "id" });
      if (database.objectStoreNames.contains(legacyImageStore)) {
        const legacyStore = request.transaction!.objectStore(legacyImageStore);
        const cursor = legacyStore.openCursor();
        cursor.onsuccess = () => {
          const entry = cursor.result;
          if (!entry) return;
          const record = entry.value as ProfileVisualImageRecord;
          nextStore.put({ ...record, id: record.id ?? createUuid(), active: true });
          entry.continue();
        };
      }
    };
    request.onsuccess = () => resolve(request.result);
  });
}

async function allStoredVisuals(): Promise<readonly StoredProfileVisual[]> {
  const database = await openDatabase();
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(libraryStore, "readonly");
    const request = transaction.objectStore(libraryStore).getAll();
    request.onsuccess = () => resolve(request.result as StoredProfileVisual[]);
    request.onerror = () => reject(request.error);
    transaction.oncomplete = () => database.close();
    transaction.onerror = () => { database.close(); reject(transaction.error ?? new Error("Profile image storage failed.")); };
  });
}

function publicRecord(record: StoredProfileVisual): ProfileVisualImageRecord {
  const { active: _active, ...rest } = record;
  return { ...rest, sourceFilename: rest.sourceFilename || "Uploaded image" };
}

export async function loadProfileVisualLibrary(): Promise<Readonly<{
  images: Readonly<Partial<Record<ProfileVisualVariant, ProfileVisualImageRecord>>>;
  library: ProfileVisualLibrary;
}>> {
  if (!window.indexedDB) return { images: {}, library: { mobile: [], wide: [] } };
  const records = await allStoredVisuals();
  const images: Partial<Record<ProfileVisualVariant, ProfileVisualImageRecord>> = {};
  for (const stored of records) if (stored.active) images[stored.variant] = publicRecord(stored);
  return {
    images,
    library: {
      mobile: records.filter((record) => record.variant === "mobile").map(publicRecord),
      wide: records.filter((record) => record.variant === "wide").map(publicRecord),
    },
  };
}

export async function loadProfileVisualImages() {
  return Object.values((await loadProfileVisualLibrary()).images).filter((record): record is ProfileVisualImageRecord => Boolean(record));
}

export async function storeProfileVisualImage(record: ProfileVisualImageRecord): Promise<ProfileVisualImageRecord> {
  const database = await openDatabase();
  const records = await allStoredVisuals();
  const sameVariant = records.filter((item) => item.variant === record.variant);
  if (!record.id && sameVariant.length >= 3) {
    database.close();
    throw new Error(`You already have three saved ${record.variant} visuals. Remove one before adding another.`);
  }
  const id = record.id ?? createUuid();
  const saved: StoredProfileVisual = { ...record, id, active: true, updatedAt: new Date().toISOString() };
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(libraryStore, "readwrite");
    const store = transaction.objectStore(libraryStore);
    for (const item of sameVariant) if (item.id !== id && item.active) store.put({ ...item, active: false });
    store.put(saved);
    transaction.oncomplete = () => { database.close(); resolve(publicRecord(saved)); };
    transaction.onerror = () => { database.close(); reject(transaction.error ?? new Error("Profile image storage failed.")); };
  });
}

export async function deleteProfileVisualImage(variant: ProfileVisualVariant, imageId?: string) {
  if (!imageId) return;
  const database = await openDatabase();
  const records = await allStoredVisuals();
  const removed = records.find((record) => record.id === imageId && record.variant === variant);
  if (!removed) { database.close(); return; }
  const fallback = removed.active
    ? records.filter((record) => record.variant === variant && record.id !== imageId).sort((first, second) => Date.parse(second.updatedAt) - Date.parse(first.updatedAt))[0]
    : undefined;
  return new Promise<void>((resolve, reject) => {
    const transaction = database.transaction(libraryStore, "readwrite");
    const store = transaction.objectStore(libraryStore);
    store.delete(imageId);
    if (fallback) store.put({ ...fallback, active: true });
    transaction.oncomplete = () => { database.close(); resolve(); };
    transaction.onerror = () => { database.close(); reject(transaction.error ?? new Error("Profile image storage failed.")); };
  });
}

function canvasBlob(canvas: HTMLCanvasElement) {
  return new Promise<Blob>((resolve, reject) => canvas.toBlob((blob) => blob ? resolve(blob) : reject(new Error("The selected image could not be processed.")), "image/webp", 0.88));
}

export async function prepareProfileVisualImage(variant: ProfileVisualVariant, file: File): Promise<ProfileVisualImageRecord> {
  if (!supportedTypes.has(file.type)) throw new Error("Choose a JPEG, PNG, or WebP image.");
  if (!file.size) throw new Error("The selected image is empty or invalid.");
  if (typeof createImageBitmap !== "function") throw new Error("This browser cannot safely process the selected image.");

  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(file, { imageOrientation: "from-image" });
  } catch {
    throw new Error("The selected image could not be decoded.");
  }

  try {
    const maximumDimension = 2560;
    const scale = Math.min(1, maximumDimension / Math.max(bitmap.width, bitmap.height));
    const displayWidth = Math.max(1, Math.round(bitmap.width * scale));
    const displayHeight = Math.max(1, Math.round(bitmap.height * scale));
    const canvas = document.createElement("canvas");
    canvas.width = displayWidth;
    canvas.height = displayHeight;
    const context = canvas.getContext("2d");
    if (!context) throw new Error("The selected image could not be processed.");
    context.drawImage(bitmap, 0, 0, displayWidth, displayHeight);
    const displayBlob = await canvasBlob(canvas);
    return { variant, sourceFilename: file.name, sourceMediaType: file.type, sourceBlob: file, displayBlob, width: bitmap.width, height: bitmap.height, crop: defaultProfileVisualCrop, updatedAt: new Date().toISOString() };
  } finally {
    bitmap.close();
  }
}
