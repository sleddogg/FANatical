import { requireSupabase } from "../../lib/supabase/client";
import { createUuid } from "../../lib/uuid";
import { cachedProfileMediaSignedUrl, evictProfileMediaSignedUrls, profileMediaBucket, resolveProfileMediaSignedUrl, resolveProfileMediaSignedUrls } from "../profileMedia/profileMediaSignedUrlCache";
import { clampProfileAvatarCrop, type ProfileAvatarRecord } from "./types";

type ProfileRow = Readonly<{ active_profile_photo_id: unknown }>;
type ProfileMediaNamespaceRow = Readonly<{ media_namespace: unknown }>;

type ProfilePhotoRow = Readonly<{
  id: unknown;
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

export type ProfileAvatarLibrary = Readonly<{
  photos: readonly ProfileAvatarRecord[];
  active: ProfileAvatarRecord | null;
}>;

function text(value: unknown) {
  return typeof value === "string" ? value : "";
}

function number(value: unknown, fallback: number) {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function safeExtension(file: Blob, filename: string) {
  const fromName = filename.toLowerCase().match(/\.(jpe?g|png|webp)$/)?.[1];
  if (fromName === "jpeg") return "jpg";
  if (fromName) return fromName;
  if (file.type === "image/png") return "png";
  if (file.type === "image/webp") return "webp";
  return "jpg";
}

function recordFromRow(row: ProfilePhotoRow, displayUrl?: string): ProfileAvatarRecord {
  const displayPath = text(row.display_path);
  return {
    id: text(row.id),
    sourceFilename: text(row.source_filename) || "Profile photo",
    sourceMediaType: text(row.source_media_type) || "image/jpeg",
    sourcePath: text(row.source_path),
    displayPath,
    ...(displayUrl ? { displayUrl } : {}),
    width: Math.max(1, number(row.source_width, 1)),
    height: Math.max(1, number(row.source_height, 1)),
    crop: clampProfileAvatarCrop({
      focalX: number(row.focal_x, 0.5),
      focalY: number(row.focal_y, 0.5),
      zoom: number(row.zoom, 1),
    }),
    updatedAt: text(row.updated_at) || new Date().toISOString(),
  };
}

export async function loadRemoteProfileAvatarLibrary(userId: string): Promise<ProfileAvatarLibrary> {
  return loadRemoteProfileAvatarLibraryWithScope(userId, "library");
}

export async function loadRemoteProfileAvatarSummary(userId: string): Promise<ProfileAvatarLibrary> {
  return loadRemoteProfileAvatarLibraryWithScope(userId, "active");
}

async function loadRemoteProfileAvatarLibraryWithScope(userId: string, scope: "active" | "library"): Promise<ProfileAvatarLibrary> {
  const client = requireSupabase();
  const [profileResult, photosResult] = await Promise.all([
    client.from("profiles").select("active_profile_photo_id").eq("user_id", userId).maybeSingle(),
    client.from("profile_photos").select("*").eq("user_id", userId).order("created_at", { ascending: true }),
  ]);
  if (profileResult.error) throw new Error(profileResult.error.message);
  if (photosResult.error) throw new Error(photosResult.error.message);
  const rows = (photosResult.data ?? []) as ProfilePhotoRow[];
  const activeId = text((profileResult.data as ProfileRow | null)?.active_profile_photo_id);
  const pathsToResolve = rows
    .filter((row) => scope === "library" || text(row.id) === activeId)
    .map((row) => text(row.display_path))
    .filter(Boolean);
  const resolvedUrls = await resolveProfileMediaSignedUrls(userId, profileMediaBucket, pathsToResolve);
  const photos = rows.map((row) => {
    const displayPath = text(row.display_path);
    return recordFromRow(row, resolvedUrls.get(displayPath) ?? cachedProfileMediaSignedUrl(userId, profileMediaBucket, displayPath));
  });
  return { photos, active: photos.find((photo) => photo.id === activeId) ?? null };
}

async function activatePhoto(record: ProfileAvatarRecord) {
  if (!record.id) throw new Error("The saved profile photo could not be found.");
  const crop = clampProfileAvatarCrop(record.crop);
  const result = await requireSupabase().rpc("activate_my_profile_photo", {
    photo_id_value: record.id,
    focal_x_value: crop.focalX,
    focal_y_value: crop.focalY,
    zoom_value: crop.zoom,
  });
  if (result.error) throw new Error(result.error.message);
  return { ...record, crop, updatedAt: new Date().toISOString() };
}

export async function uploadRemoteProfileAvatar(userId: string, record: ProfileAvatarRecord): Promise<ProfileAvatarRecord> {
  if (!record.sourceBlob || !record.displayBlob) throw new Error("The selected profile photo is not available for upload.");
  const client = requireSupabase();
  const [count, profileResult] = await Promise.all([
    client.from("profile_photos").select("id", { count: "exact", head: true }).eq("user_id", userId),
    client.from("profiles").select("media_namespace").eq("user_id", userId).maybeSingle(),
  ]);
  if (count.error) throw new Error(count.error.message);
  if (profileResult.error) throw new Error(profileResult.error.message);
  if ((count.count ?? 0) >= 3) throw new Error("You already have three saved profile photos. Remove one before adding another.");
  const mediaNamespace = text((profileResult.data as ProfileMediaNamespaceRow | null)?.media_namespace);
  if (!/^fan-media-[0-9a-f]{32}$/.test(mediaNamespace)) throw new Error("The account avatar namespace is unavailable.");

  const id = createUuid();
  const version = `${Date.now()}-${id}`;
  const folder = `${userId}/avatar`;
  const sourcePath = `${folder}/${version}-source.${safeExtension(record.sourceBlob, record.sourceFilename)}`;
  const displayPath = `${mediaNamespace}/avatar/${version}-display.webp`;
  const createdPaths: string[] = [];
  let inserted = false;

  try {
    const sourceUpload = await client.storage.from(profileMediaBucket).upload(sourcePath, record.sourceBlob, { contentType: record.sourceMediaType, upsert: false });
    if (sourceUpload.error) throw new Error(sourceUpload.error.message);
    createdPaths.push(sourcePath);

    const displayUpload = await client.storage.from(profileMediaBucket).upload(displayPath, record.displayBlob, { contentType: "image/webp", upsert: false });
    if (displayUpload.error) throw new Error(displayUpload.error.message);
    createdPaths.push(displayPath);

    const crop = clampProfileAvatarCrop(record.crop);
    const insert = await client.from("profile_photos").insert({
      id,
      user_id: userId,
      source_path: sourcePath,
      display_path: displayPath,
      source_filename: record.sourceFilename,
      source_media_type: record.sourceMediaType,
      source_width: record.width,
      source_height: record.height,
      focal_x: crop.focalX,
      focal_y: crop.focalY,
      zoom: crop.zoom,
    });
    if (insert.error) throw new Error(insert.error.message);
    inserted = true;

    return await activatePhoto({
      ...record,
      id,
      sourcePath,
      displayPath,
      displayUrl: await resolveProfileMediaSignedUrl(userId, profileMediaBucket, displayPath),
      crop,
      updatedAt: new Date().toISOString(),
    });
  } catch (reason) {
    if (inserted) await client.from("profile_photos").delete().eq("id", id).eq("user_id", userId);
    if (createdPaths.length) await client.storage.from(profileMediaBucket).remove(createdPaths);
    throw reason;
  }
}

export async function activateRemoteProfileAvatar(_userId: string, record: ProfileAvatarRecord): Promise<ProfileAvatarRecord> {
  return activatePhoto(record);
}

export async function deleteRemoteProfilePhoto(userId: string, photoId: string): Promise<ProfileAvatarLibrary> {
  const client = requireSupabase();
  const result = await client.rpc("remove_my_profile_photo", { photo_id_value: photoId });
  if (result.error) throw new Error(result.error.message);
  const paths = result.data && typeof result.data === "object"
    ? [text((result.data as Record<string, unknown>).sourcePath), text((result.data as Record<string, unknown>).displayPath)].filter(Boolean)
    : [];
  if (paths.length) {
    const removal = await client.storage.from(profileMediaBucket).remove(paths);
    if (removal.error) console.warn("The profile photo was removed, but owned media cleanup must be retried.", removal.error);
    evictProfileMediaSignedUrls(userId, profileMediaBucket, paths);
  }
  return loadRemoteProfileAvatarLibrary(userId);
}
