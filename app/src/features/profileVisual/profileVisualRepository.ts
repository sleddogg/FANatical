import { requireSupabase } from "../../lib/supabase/client";
import { createUuid } from "../../lib/uuid";
import { clampProfileVisualCrop, type ProfileVisualImageRecord, type ProfileVisualLibrary, type ProfileVisualVariant } from "./types";

type VisualRow = Readonly<{
  id?: unknown;
  variant: unknown;
  source_path: unknown;
  display_path: unknown;
  source_filename: unknown;
  source_media_type: unknown;
  source_width: unknown;
  source_height: unknown;
  focal_x: unknown;
  focal_y: unknown;
  zoom: unknown;
  updated_at: unknown;
}>;

type RemovedVisual = Readonly<{ sourcePath?: unknown; displayPath?: unknown }>;

export type RemoteProfileVisualLibrary = Readonly<{
  images: Readonly<Partial<Record<ProfileVisualVariant, ProfileVisualImageRecord>>>;
  library: ProfileVisualLibrary;
}>;

const bucket = "profile-media";

function text(value: unknown) {
  return typeof value === "string" ? value : "";
}

function number(value: unknown, fallback: number) {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function variant(value: unknown): ProfileVisualVariant {
  return value === "wide" ? "wide" : "mobile";
}

function safeExtension(file: Blob, filename: string) {
  const fromName = filename.toLowerCase().match(/\.(jpe?g|png|webp)$/)?.[1];
  if (fromName === "jpeg") return "jpg";
  if (fromName) return fromName;
  if (file.type === "image/png") return "png";
  if (file.type === "image/webp") return "webp";
  return "jpg";
}

async function signedUrl(path: string) {
  const result = await requireSupabase().storage.from(bucket).createSignedUrl(path, 60 * 60);
  if (result.error) throw new Error(result.error.message);
  return result.data.signedUrl;
}

async function rowToRecord(row: VisualRow): Promise<ProfileVisualImageRecord> {
  const displayPath = text(row.display_path);
  return {
    ...(text(row.id) ? { id: text(row.id) } : {}),
    variant: variant(row.variant),
    sourceFilename: text(row.source_filename) || "Profile visual",
    sourceMediaType: text(row.source_media_type) || "image/jpeg",
    sourcePath: text(row.source_path),
    displayPath,
    displayUrl: await signedUrl(displayPath),
    width: Math.max(1, number(row.source_width, 1)),
    height: Math.max(1, number(row.source_height, 1)),
    crop: clampProfileVisualCrop({
      focalX: number(row.focal_x, 0.5),
      focalY: number(row.focal_y, 0.5),
      zoom: number(row.zoom, 1),
    }),
    updatedAt: text(row.updated_at) || new Date().toISOString(),
  };
}

export async function loadRemoteProfileVisualLibrary(userId: string): Promise<RemoteProfileVisualLibrary> {
  const client = requireSupabase();
  const [activeResult, libraryResult] = await Promise.all([
    client.from("profile_visuals").select("variant, source_path, display_path, source_filename, source_media_type, source_width, source_height, focal_x, focal_y, zoom, updated_at").eq("user_id", userId),
    client.from("profile_visual_images").select("id, variant, source_path, display_path, source_filename, source_media_type, source_width, source_height, focal_x, focal_y, zoom, updated_at").eq("user_id", userId).order("created_at", { ascending: true }),
  ]);
  if (activeResult.error) throw new Error(activeResult.error.message);
  if (libraryResult.error) {
    const missingLibrary = libraryResult.error.code === "PGRST205" || libraryResult.error.code === "42P01";
    if (!missingLibrary) throw new Error(libraryResult.error.message);
    const activeRecords = await Promise.all(((activeResult.data ?? []) as VisualRow[]).map(rowToRecord));
    const images: Partial<Record<ProfileVisualVariant, ProfileVisualImageRecord>> = {};
    for (const record of activeRecords) images[record.variant] = record;
    return {
      images,
      library: {
        mobile: activeRecords.filter((record) => record.variant === "mobile"),
        wide: activeRecords.filter((record) => record.variant === "wide"),
      },
    };
  }
  const libraryRecords = await Promise.all(((libraryResult.data ?? []) as VisualRow[]).map(rowToRecord));
  const activeRows = (activeResult.data ?? []) as VisualRow[];
  const images: Partial<Record<ProfileVisualVariant, ProfileVisualImageRecord>> = {};
  for (const activeRow of activeRows) {
    const activeVariant = variant(activeRow.variant);
    const activePath = text(activeRow.display_path);
    images[activeVariant] = libraryRecords.find((record) => record.variant === activeVariant && record.displayPath === activePath)
      ?? await rowToRecord(activeRow);
  }
  return {
    images,
    library: {
      mobile: libraryRecords.filter((record) => record.variant === "mobile"),
      wide: libraryRecords.filter((record) => record.variant === "wide"),
    },
  };
}

export async function loadRemoteProfileVisuals(userId: string): Promise<readonly ProfileVisualImageRecord[]> {
  return Object.values((await loadRemoteProfileVisualLibrary(userId)).images).filter((record): record is ProfileVisualImageRecord => Boolean(record));
}

async function activateVisual(record: ProfileVisualImageRecord): Promise<ProfileVisualImageRecord> {
  if (!record.id) throw new Error("The saved Profile visual could not be found.");
  const crop = clampProfileVisualCrop(record.crop);
  const result = await requireSupabase().rpc("activate_my_profile_visual", {
    image_id_value: record.id,
    focal_x_value: crop.focalX,
    focal_y_value: crop.focalY,
    zoom_value: crop.zoom,
  });
  if (result.error) throw new Error(result.error.message);
  return { ...record, crop, updatedAt: new Date().toISOString() };
}

export async function uploadRemoteProfileVisual(userId: string, record: ProfileVisualImageRecord): Promise<ProfileVisualImageRecord> {
  if (!record.sourceBlob || !record.displayBlob) throw new Error("The selected profile image is not available for upload.");
  const client = requireSupabase();
  const count = await client.from("profile_visual_images").select("id", { count: "exact", head: true }).eq("user_id", userId).eq("variant", record.variant);
  if (count.error) throw new Error(count.error.message);
  if ((count.count ?? 0) >= 3) throw new Error(`You already have three saved ${record.variant} visuals. Remove one before adding another.`);

  const id = createUuid();
  const version = `${Date.now()}-${id}`;
  const folder = `${userId}/profile-visual/${record.variant}`;
  const sourcePath = `${folder}/${version}-source.${safeExtension(record.sourceBlob, record.sourceFilename)}`;
  const displayPath = `${folder}/${version}-display.webp`;
  const createdPaths: string[] = [];
  let inserted = false;

  try {
    const sourceMediaType = record.sourceMediaType || record.sourceBlob.type;
    const sourceUpload = await client.storage.from(bucket).upload(sourcePath, record.sourceBlob, { contentType: sourceMediaType, upsert: false });
    if (sourceUpload.error) throw new Error(sourceUpload.error.message);
    createdPaths.push(sourcePath);

    const displayUpload = await client.storage.from(bucket).upload(displayPath, record.displayBlob, { contentType: "image/webp", upsert: false });
    if (displayUpload.error) throw new Error(displayUpload.error.message);
    createdPaths.push(displayPath);

    const crop = clampProfileVisualCrop(record.crop);
    const insert = await client.from("profile_visual_images").insert({
      id,
      user_id: userId,
      variant: record.variant,
      source_path: sourcePath,
      display_path: displayPath,
      source_filename: record.sourceFilename,
      source_media_type: sourceMediaType,
      source_width: record.width,
      source_height: record.height,
      focal_x: crop.focalX,
      focal_y: crop.focalY,
      zoom: crop.zoom,
    });
    if (insert.error) throw new Error(insert.error.message);
    inserted = true;

    return await activateVisual({
      ...record,
      id,
      sourceMediaType,
      sourcePath,
      displayPath,
      displayUrl: await signedUrl(displayPath),
      crop,
      updatedAt: new Date().toISOString(),
    });
  } catch (reason) {
    if (inserted) await client.from("profile_visual_images").delete().eq("id", id).eq("user_id", userId);
    if (createdPaths.length) await client.storage.from(bucket).remove(createdPaths);
    throw reason;
  }
}

export async function activateRemoteProfileVisual(_userId: string, record: ProfileVisualImageRecord): Promise<ProfileVisualImageRecord> {
  return activateVisual(record);
}

export async function deleteRemoteProfileVisualImage(userId: string, imageId: string): Promise<RemoteProfileVisualLibrary> {
  const client = requireSupabase();
  const result = await client.rpc("remove_my_profile_visual", { image_id_value: imageId });
  if (result.error) throw new Error(result.error.message);
  const removed = result.data && typeof result.data === "object" ? result.data as RemovedVisual : {};
  const paths = [text(removed.sourcePath), text(removed.displayPath)].filter(Boolean);
  if (paths.length) {
    const removal = await client.storage.from(bucket).remove(paths);
    if (removal.error) console.warn("The Profile visual was removed, but owned media cleanup must be retried.", removal.error);
  }
  return loadRemoteProfileVisualLibrary(userId);
}
