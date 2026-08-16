import { defaultProfileVisualCrop, type ProfileVisualImageRecord, type ProfileVisualVariant } from "./types";

const databaseName = "fanatical-profile-media";
const databaseVersion = 1;
const imageStore = "profile-visual-images";
const supportedTypes = new Set(["image/jpeg", "image/png", "image/webp"]);

function openDatabase() {
  return new Promise<IDBDatabase>((resolve, reject) => {
    if (!window.indexedDB) return reject(new Error("Persistent image storage is unavailable in this browser."));
    const request = window.indexedDB.open(databaseName, databaseVersion);
    request.onerror = () => reject(request.error ?? new Error("Could not open persistent image storage."));
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains(imageStore)) request.result.createObjectStore(imageStore, { keyPath: "variant" });
    };
    request.onsuccess = () => resolve(request.result);
  });
}

async function withStore<T>(mode: IDBTransactionMode, run: (store: IDBObjectStore, resolve: (value: T) => void, reject: (reason?: unknown) => void) => void) {
  const database = await openDatabase();
  return new Promise<T>((resolve, reject) => {
    const transaction = database.transaction(imageStore, mode);
    transaction.oncomplete = () => database.close();
    transaction.onerror = () => { database.close(); reject(transaction.error ?? new Error("Profile image storage failed.")); };
    run(transaction.objectStore(imageStore), resolve, reject);
  });
}

export async function loadProfileVisualImages() {
  return withStore<readonly ProfileVisualImageRecord[]>("readonly", (store, resolve, reject) => {
    const request = store.getAll();
    request.onsuccess = () => resolve((request.result as ProfileVisualImageRecord[]).map((record) => ({
      ...record,
      sourceFilename: record.sourceFilename || "Uploaded image",
    })));
    request.onerror = () => reject(request.error);
  });
}

export async function storeProfileVisualImage(record: ProfileVisualImageRecord) {
  return withStore<void>("readwrite", (store, resolve, reject) => {
    const request = store.put(record);
    request.onsuccess = () => resolve();
    request.onerror = () => reject(request.error);
  });
}

export async function deleteProfileVisualImage(variant: ProfileVisualVariant) {
  return withStore<void>("readwrite", (store, resolve, reject) => {
    const request = store.delete(variant);
    request.onsuccess = () => resolve();
    request.onerror = () => reject(request.error);
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
    return { variant, sourceFilename: file.name, sourceBlob: file, displayBlob, width: bitmap.width, height: bitmap.height, crop: defaultProfileVisualCrop, updatedAt: new Date().toISOString() };
  } finally {
    bitmap.close();
  }
}
