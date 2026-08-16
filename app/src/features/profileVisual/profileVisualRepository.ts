import { requireSupabase } from "../../lib/supabase/client";
import { createUuid } from "../../lib/uuid";
import { clampProfileVisualCrop, type ProfileVisualCrop, type ProfileVisualImageRecord, type ProfileVisualVariant } from "./types";

type VisualRow = Readonly<{
  variant: ProfileVisualVariant;
  source_path: string;
  display_path: string;
  source_filename: string;
  source_width: number;
  source_height: number;
  focal_x: number;
  focal_y: number;
  zoom: number;
  updated_at: string;
}>;

const bucket = "profile-media";

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
  return {
    variant: row.variant,
    sourceFilename: row.source_filename,
    sourcePath: row.source_path,
    displayPath: row.display_path,
    displayUrl: await signedUrl(row.display_path),
    width: row.source_width,
    height: row.source_height,
    crop: clampProfileVisualCrop({ focalX: row.focal_x, focalY: row.focal_y, zoom: row.zoom }),
    updatedAt: row.updated_at,
  };
}

export async function loadRemoteProfileVisuals(userId: string): Promise<readonly ProfileVisualImageRecord[]> {
  const result = await requireSupabase().from("profile_visuals").select("variant, source_path, display_path, source_filename, source_width, source_height, focal_x, focal_y, zoom, updated_at").eq("user_id", userId);
  if (result.error) throw new Error(result.error.message);
  return Promise.all(((result.data ?? []) as VisualRow[]).map(rowToRecord));
}

export async function uploadRemoteProfileVisual(userId: string, record: ProfileVisualImageRecord, previous?: ProfileVisualImageRecord): Promise<ProfileVisualImageRecord> {
  if (!record.sourceBlob || !record.displayBlob) throw new Error("The selected profile image is not available for upload.");
  const client = requireSupabase();
  const version = `${Date.now()}-${createUuid()}`;
  const folder = `${userId}/profile-visual/${record.variant}`;
  const sourcePath = `${folder}/${version}-source.${safeExtension(record.sourceBlob, record.sourceFilename)}`;
  const displayPath = `${folder}/${version}-display.webp`;
  const sourceUpload = await client.storage.from(bucket).upload(sourcePath, record.sourceBlob, { contentType: record.sourceBlob.type, upsert: false });
  if (sourceUpload.error) throw new Error(sourceUpload.error.message);
  const displayUpload = await client.storage.from(bucket).upload(displayPath, record.displayBlob, { contentType: "image/webp", upsert: false });
  if (displayUpload.error) {
    await client.storage.from(bucket).remove([sourcePath]);
    throw new Error(displayUpload.error.message);
  }
  const save = await client.from("profile_visuals").upsert({
    user_id: userId,
    variant: record.variant,
    source_path: sourcePath,
    display_path: displayPath,
    source_filename: record.sourceFilename,
    source_media_type: record.sourceBlob.type,
    source_width: record.width,
    source_height: record.height,
    focal_x: record.crop.focalX,
    focal_y: record.crop.focalY,
    zoom: record.crop.zoom,
  }, { onConflict: "user_id,variant" });
  if (save.error) {
    await client.storage.from(bucket).remove([sourcePath, displayPath]);
    throw new Error(save.error.message);
  }
  if (previous?.sourcePath || previous?.displayPath) {
    const oldPaths = [previous.sourcePath, previous.displayPath].filter((path): path is string => Boolean(path));
    if (oldPaths.length) await client.storage.from(bucket).remove(oldPaths);
  }
  return { ...record, sourcePath, displayPath, displayUrl: await signedUrl(displayPath), updatedAt: new Date().toISOString() };
}

export async function saveRemoteProfileVisualCrop(userId: string, variant: ProfileVisualVariant, crop: ProfileVisualCrop) {
  const next = clampProfileVisualCrop(crop);
  const result = await requireSupabase().from("profile_visuals").update({ focal_x: next.focalX, focal_y: next.focalY, zoom: next.zoom }).eq("user_id", userId).eq("variant", variant);
  if (result.error) throw new Error(result.error.message);
}

export async function deleteRemoteProfileVisual(userId: string, record: ProfileVisualImageRecord) {
  const client = requireSupabase();
  const result = await client.from("profile_visuals").delete().eq("user_id", userId).eq("variant", record.variant);
  if (result.error) throw new Error(result.error.message);
  const paths = [record.sourcePath, record.displayPath].filter((path): path is string => Boolean(path));
  if (paths.length) {
    const removal = await client.storage.from(bucket).remove(paths);
    if (removal.error) console.warn("The profile visual record was removed, but old media cleanup must be retried.", removal.error);
  }
}
