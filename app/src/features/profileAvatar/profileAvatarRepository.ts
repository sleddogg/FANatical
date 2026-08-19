import { requireSupabase } from "../../lib/supabase/client";
import { createUuid } from "../../lib/uuid";
import { clampProfileAvatarCrop, type ProfileAvatarCrop, type ProfileAvatarRecord } from "./types";

type AvatarRow = Readonly<{
  avatar_path: unknown;
  avatar_customization: unknown;
  updated_at: unknown;
}>;

type AvatarCustomization = Readonly<{
  sourcePath: string;
  displayPath: string;
  sourceFilename: string;
  sourceMediaType: string;
  sourceWidth: number;
  sourceHeight: number;
  focalX: number;
  focalY: number;
  zoom: number;
}>;

const bucket = "profile-media";

function text(value: unknown) {
  return typeof value === "string" ? value : "";
}

function number(value: unknown, fallback: number) {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function parseCustomization(value: unknown): AvatarCustomization | null {
  if (!value || typeof value !== "object") return null;
  const row = value as Record<string, unknown>;
  const sourcePath = text(row.sourcePath);
  const displayPath = text(row.displayPath);
  if (!sourcePath || !displayPath) return null;
  return {
    sourcePath,
    displayPath,
    sourceFilename: text(row.sourceFilename) || "Profile photo",
    sourceMediaType: text(row.sourceMediaType) || "image/jpeg",
    sourceWidth: Math.max(1, number(row.sourceWidth, 1)),
    sourceHeight: Math.max(1, number(row.sourceHeight, 1)),
    focalX: number(row.focalX, 0.5),
    focalY: number(row.focalY, 0.5),
    zoom: number(row.zoom, 1),
  };
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

function customizationFor(record: ProfileAvatarRecord, sourcePath: string, displayPath: string): AvatarCustomization {
  const crop = clampProfileAvatarCrop(record.crop);
  return {
    sourcePath,
    displayPath,
    sourceFilename: record.sourceFilename,
    sourceMediaType: record.sourceMediaType,
    sourceWidth: record.width,
    sourceHeight: record.height,
    focalX: crop.focalX,
    focalY: crop.focalY,
    zoom: crop.zoom,
  };
}

export async function loadRemoteProfileAvatar(userId: string): Promise<ProfileAvatarRecord | null> {
  const result = await requireSupabase().from("profiles").select("avatar_path, avatar_customization, updated_at").eq("user_id", userId).maybeSingle();
  if (result.error) throw new Error(result.error.message);
  const row = result.data as AvatarRow | null;
  const customization = parseCustomization(row?.avatar_customization);
  const displayPath = text(row?.avatar_path) || customization?.displayPath;
  if (!customization || !displayPath) return null;
  return {
    sourceFilename: customization.sourceFilename,
    sourceMediaType: customization.sourceMediaType,
    sourcePath: customization.sourcePath,
    displayPath,
    displayUrl: await signedUrl(displayPath),
    width: customization.sourceWidth,
    height: customization.sourceHeight,
    crop: clampProfileAvatarCrop({ focalX: customization.focalX, focalY: customization.focalY, zoom: customization.zoom }),
    updatedAt: text(row?.updated_at) || new Date().toISOString(),
  };
}

export async function uploadRemoteProfileAvatar(userId: string, record: ProfileAvatarRecord, previous: ProfileAvatarRecord | null): Promise<ProfileAvatarRecord> {
  if (!record.sourceBlob || !record.displayBlob) throw new Error("The selected profile photo is not available for upload.");
  const client = requireSupabase();
  const version = `${Date.now()}-${createUuid()}`;
  const folder = `${userId}/avatar`;
  const sourcePath = `${folder}/${version}-source.${safeExtension(record.sourceBlob, record.sourceFilename)}`;
  const displayPath = `${folder}/${version}-display.webp`;
  const createdPaths: string[] = [];

  try {
    const sourceUpload = await client.storage.from(bucket).upload(sourcePath, record.sourceBlob, { contentType: record.sourceMediaType, upsert: false });
    if (sourceUpload.error) throw new Error(sourceUpload.error.message);
    createdPaths.push(sourcePath);

    const displayUpload = await client.storage.from(bucket).upload(displayPath, record.displayBlob, { contentType: "image/webp", upsert: false });
    if (displayUpload.error) throw new Error(displayUpload.error.message);
    createdPaths.push(displayPath);

    const save = await client.from("profiles").update({
      avatar_path: displayPath,
      avatar_customization: customizationFor(record, sourcePath, displayPath),
    }).eq("user_id", userId);
    if (save.error) throw new Error(save.error.message);
  } catch (reason) {
    if (createdPaths.length) await client.storage.from(bucket).remove(createdPaths);
    throw reason;
  }

  const oldPaths = [previous?.sourcePath, previous?.displayPath].filter((path): path is string => Boolean(path) && path !== sourcePath && path !== displayPath);
  if (oldPaths.length) {
    const removal = await client.storage.from(bucket).remove(oldPaths);
    if (removal.error) console.warn("The profile photo was saved, but old media cleanup must be retried.", removal.error);
  }

  return {
    ...record,
    sourcePath,
    displayPath,
    displayUrl: await signedUrl(displayPath),
    updatedAt: new Date().toISOString(),
  };
}

export async function saveRemoteProfileAvatarCrop(userId: string, record: ProfileAvatarRecord, crop: ProfileAvatarCrop): Promise<ProfileAvatarRecord> {
  if (!record.sourcePath || !record.displayPath) throw new Error("The saved profile photo could not be found.");
  const next = { ...record, crop: clampProfileAvatarCrop(crop), updatedAt: new Date().toISOString() };
  const result = await requireSupabase().from("profiles").update({
    avatar_path: record.displayPath,
    avatar_customization: customizationFor(next, record.sourcePath, record.displayPath),
  }).eq("user_id", userId);
  if (result.error) throw new Error(result.error.message);
  return next;
}

export async function deleteRemoteProfileAvatar(userId: string, record: ProfileAvatarRecord) {
  const client = requireSupabase();
  const result = await client.from("profiles").update({ avatar_path: null, avatar_customization: {} }).eq("user_id", userId);
  if (result.error) throw new Error(result.error.message);
  const paths = [record.sourcePath, record.displayPath].filter((path): path is string => Boolean(path));
  if (paths.length) {
    const removal = await client.storage.from(bucket).remove(paths);
    if (removal.error) console.warn("The profile photo reference was removed, but media cleanup must be retried.", removal.error);
  }
}
