import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type PropsWithChildren } from "react";
import { subscribeToAccountChanges } from "../account/accountRepository";
import { useAuth } from "../account/AuthContext";
import { createCoalescedProfileMediaRefresh } from "../profileMedia/profileMediaRefresh";
import { deleteProfileVisualImage, loadProfileVisualLibrary, storeProfileVisualImage } from "./profileVisualStorage";
import { activateRemoteProfileVisual, deleteRemoteProfileVisualImage, loadRemoteProfileVisualLibrary, loadRemoteProfileVisualSummary, uploadRemoteProfileVisual } from "./profileVisualRepository";
import type { ProfileVisualImageRecord, ProfileVisualLibrary, ProfileVisualVariant } from "./types";

type ProfileVisualRecords = Readonly<Partial<Record<ProfileVisualVariant, ProfileVisualImageRecord>>>;

type ProfileVisualContextValue = Readonly<{
  images: ProfileVisualRecords;
  library: ProfileVisualLibrary;
  resolveLibrary: () => Promise<void>;
  saveImage: (record: ProfileVisualImageRecord) => Promise<ProfileVisualImageRecord>;
  removeImage: (variant: ProfileVisualVariant, imageId: string) => Promise<ProfileVisualImageRecord | undefined>;
}>;

const emptyLibrary: ProfileVisualLibrary = { mobile: [], wide: [] };
const ProfileVisualContext = createContext<ProfileVisualContextValue | null>(null);
const focusFreshnessMs = 5 * 60 * 1000;
const signedUrlRefreshMs = 55 * 60 * 1000;

export function ProfileVisualProvider({ children }: PropsWithChildren) {
  const { configured, user } = useAuth();
  const userId = user?.id ?? null;
  const activeUserId = useRef(userId);
  const requestSequence = useRef(0);
  const libraryRequested = useRef(false);
  const lastLoadedAt = useRef(0);
  const [images, setImages] = useState<ProfileVisualRecords>({});
  const [library, setLibrary] = useState<ProfileVisualLibrary>(emptyLibrary);
  activeUserId.current = userId;

  const load = useCallback(async (scope?: "active" | "library") => {
    const requestId = ++requestSequence.current;
    const effectiveScope = scope ?? (libraryRequested.current ? "library" : "active");
    const result = configured
      ? userId
        ? effectiveScope === "library" ? await loadRemoteProfileVisualLibrary(userId) : await loadRemoteProfileVisualSummary(userId)
        : { images: {}, library: emptyLibrary }
      : await loadProfileVisualLibrary();
    if (requestId !== requestSequence.current || activeUserId.current !== userId) return result;
    setImages(result.images);
    setLibrary(result.library);
    lastLoadedAt.current = Date.now();
    return result;
  }, [configured, userId]);

  useEffect(() => {
    libraryRequested.current = false;
    requestSequence.current += 1;
    const refresh = createCoalescedProfileMediaRefresh(async () => {
      try {
        await load();
      } catch (reason) {
        if (activeUserId.current === userId) console.warn("FANatical could not load the Profile visual library.", reason);
      }
    });
    void refresh.runNow();
    const refreshSignedUrls = configured && userId
      ? window.setInterval(() => { void refresh.runNow(); }, signedUrlRefreshMs)
      : undefined;
    const focus = () => {
      if (Date.now() - lastLoadedAt.current >= focusFreshnessMs) void refresh.runNow();
    };
    window.addEventListener("focus", focus);
    const unsubscribe = configured && userId
      ? subscribeToAccountChanges(userId, refresh.schedule, ["profile_visuals", "profile_visual_images"])
      : undefined;
    return () => {
      requestSequence.current += 1;
      if (refreshSignedUrls !== undefined) window.clearInterval(refreshSignedUrls);
      window.removeEventListener("focus", focus);
      refresh.dispose();
      unsubscribe?.();
    };
  }, [configured, load, userId]);

  const resolveLibrary = useCallback(async () => {
    libraryRequested.current = true;
    try {
      await load("library");
    } catch (reason) {
      if (activeUserId.current === userId) console.warn("FANatical could not load the saved Profile visuals.", reason);
    }
  }, [load, userId]);

  const saveImage = useCallback(async (record: ProfileVisualImageRecord) => {
    if (configured && !userId) throw new Error("Sign in to save a Profile visual.");
    const saved = configured && userId
      ? record.sourceBlob && record.displayBlob
        ? await uploadRemoteProfileVisual(userId, record)
        : await activateRemoteProfileVisual(userId, record)
      : await storeProfileVisualImage(record);
    if (activeUserId.current !== userId) return saved;
    setImages((current) => ({ ...current, [saved.variant]: saved }));
    setLibrary((current) => ({
      ...current,
      [saved.variant]: current[saved.variant].some((candidate) => candidate.id === saved.id)
        ? current[saved.variant].map((candidate) => candidate.id === saved.id ? saved : candidate)
        : [...current[saved.variant], saved],
    }));
    return saved;
  }, [configured, userId]);

  const removeImage = useCallback(async (variant: ProfileVisualVariant, imageId: string) => {
    if (configured && !userId) throw new Error("Sign in to remove a Profile visual.");
    const result = configured && userId
      ? await deleteRemoteProfileVisualImage(userId, imageId)
      : (await deleteProfileVisualImage(variant, imageId), await loadProfileVisualLibrary());
    if (activeUserId.current !== userId) return undefined;
    libraryRequested.current = true;
    setImages(result.images);
    setLibrary(result.library);
    return result.images[variant];
  }, [configured, userId]);

  const value = useMemo<ProfileVisualContextValue>(() => ({ images, library, resolveLibrary, saveImage, removeImage }), [images, library, removeImage, resolveLibrary, saveImage]);
  return <ProfileVisualContext.Provider value={value}>{children}</ProfileVisualContext.Provider>;
}

export function useProfileVisual() {
  const context = useContext(ProfileVisualContext);
  if (!context) throw new Error("useProfileVisual must be used within ProfileVisualProvider.");
  return context;
}
