import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type PropsWithChildren } from "react";
import { subscribeToAccountChanges } from "../account/accountRepository";
import { useAuth } from "../account/AuthContext";
import { accountClientStateClearedEvent } from "../account/accountClientState";
import { createCoalescedProfileMediaRefresh } from "../profileMedia/profileMediaRefresh";
import { activateRemoteProfileAvatar, deleteRemoteProfilePhoto, loadRemoteProfileAvatarLibrary, loadRemoteProfileAvatarSummary, uploadRemoteProfileAvatar } from "./profileAvatarRepository";
import type { ProfileAvatarCrop, ProfileAvatarRecord } from "./types";

type ProfileAvatarContextValue = Readonly<{
  avatar: ProfileAvatarRecord | null;
  photos: readonly ProfileAvatarRecord[];
  loading: boolean;
  resolveLibrary: () => Promise<void>;
  saveAvatar: (record: ProfileAvatarRecord) => Promise<void>;
  saveCrop: (crop: ProfileAvatarCrop) => Promise<void>;
  removePhoto: (photoId: string) => Promise<ProfileAvatarRecord | null>;
}>;

const ProfileAvatarContext = createContext<ProfileAvatarContextValue | null>(null);
const focusFreshnessMs = 5 * 60 * 1000;
const signedUrlRefreshMs = 55 * 60 * 1000;

export function ProfileAvatarProvider({ children }: PropsWithChildren) {
  const { configured, user } = useAuth();
  const userId = user?.id ?? null;
  const activeUserId = useRef(userId);
  const requestSequence = useRef(0);
  const libraryRequested = useRef(false);
  const lastLoadedAt = useRef(0);
  const [avatar, setAvatar] = useState<ProfileAvatarRecord | null>(null);
  const [photos, setPhotos] = useState<readonly ProfileAvatarRecord[]>([]);
  const [loading, setLoading] = useState(false);
  const [loadedUserId, setLoadedUserId] = useState<string | null>(null);
  activeUserId.current = userId;

  const load = useCallback(async (scope?: "active" | "library") => {
    const requestId = ++requestSequence.current;
    if (!configured || !userId) {
      if (requestId === requestSequence.current) {
        setAvatar(null);
        setPhotos([]);
        setLoading(false);
        setLoadedUserId(null);
        lastLoadedAt.current = Date.now();
      }
      return;
    }
    setLoading(true);
    const effectiveScope = scope ?? (libraryRequested.current ? "library" : "active");
    const library = effectiveScope === "library"
      ? await loadRemoteProfileAvatarLibrary(userId)
      : await loadRemoteProfileAvatarSummary(userId);
    if (requestId !== requestSequence.current || activeUserId.current !== userId) return;
    setAvatar(library.active);
    setPhotos(library.photos);
    setLoadedUserId(userId);
    setLoading(false);
    lastLoadedAt.current = Date.now();
  }, [configured, userId]);

  useEffect(() => {
    const clear = () => {
      requestSequence.current += 1;
      libraryRequested.current = false;
      setAvatar(null);
      setPhotos([]);
      setLoading(false);
      setLoadedUserId(null);
    };
    window.addEventListener(accountClientStateClearedEvent, clear);
    return () => window.removeEventListener(accountClientStateClearedEvent, clear);
  }, []);

  useEffect(() => {
    libraryRequested.current = false;
    requestSequence.current += 1;
    if (!configured || !userId) {
      setAvatar(null);
      setPhotos([]);
      setLoading(false);
      lastLoadedAt.current = Date.now();
      return;
    }
    const refresh = createCoalescedProfileMediaRefresh(async () => {
      try {
        await load();
      } catch (reason) {
        if (activeUserId.current === userId) {
          setLoading(false);
          console.warn("FANatical could not load the profile photo.", reason);
        }
      }
    });
    void refresh.runNow();
    const refreshSignedUrls = window.setInterval(() => { void refresh.runNow(); }, signedUrlRefreshMs);
    const focus = () => {
      if (Date.now() - lastLoadedAt.current >= focusFreshnessMs) void refresh.runNow();
    };
    window.addEventListener("focus", focus);
    const unsubscribe = subscribeToAccountChanges(userId, refresh.schedule, ["profiles", "profile_photos"]);
    return () => {
      requestSequence.current += 1;
      window.clearInterval(refreshSignedUrls);
      window.removeEventListener("focus", focus);
      refresh.dispose();
      unsubscribe();
    };
  }, [configured, load, userId]);

  const resolveLibrary = useCallback(async () => {
    libraryRequested.current = true;
    try {
      await load("library");
    } catch (reason) {
      if (activeUserId.current === userId) console.warn("FANatical could not load the saved profile photos.", reason);
    }
  }, [load, userId]);

  const saveAvatar = useCallback(async (record: ProfileAvatarRecord) => {
    if (!configured || !userId) throw new Error("Sign in to save a profile photo.");
    const saved = record.sourceBlob && record.displayBlob
      ? await uploadRemoteProfileAvatar(userId, record)
      : await activateRemoteProfileAvatar(userId, record);
    if (activeUserId.current !== userId) return;
      setAvatar(saved);
    setLoadedUserId(userId);
    setPhotos((current) => current.some((photo) => photo.id === saved.id)
      ? current.map((photo) => photo.id === saved.id ? saved : photo)
      : [...current, saved]);
  }, [configured, userId]);

  const saveCrop = useCallback(async (crop: ProfileAvatarCrop) => {
    if (!configured || !userId) throw new Error("Sign in to save profile photo positioning.");
    if (!avatar) return;
    const saved = await activateRemoteProfileAvatar(userId, { ...avatar, crop });
    if (activeUserId.current !== userId) return;
    setAvatar(saved);
    setLoadedUserId(userId);
    setPhotos((current) => current.map((photo) => photo.id === saved.id ? saved : photo));
  }, [avatar, configured, userId]);

  const removePhoto = useCallback(async (photoId: string) => {
    if (!configured || !userId) throw new Error("Sign in to remove a profile photo.");
    const library = await deleteRemoteProfilePhoto(userId, photoId);
    if (activeUserId.current !== userId) return null;
    libraryRequested.current = true;
    setAvatar(library.active);
    setPhotos(library.photos);
    setLoadedUserId(userId);
    return library.active;
  }, [configured, userId]);

  const value = useMemo<ProfileAvatarContextValue>(() => ({
    avatar: userId && loadedUserId === userId ? avatar : null,
    photos: userId && loadedUserId === userId ? photos : [],
    loading,
    resolveLibrary,
    saveAvatar,
    saveCrop,
    removePhoto,
  }), [avatar, loadedUserId, loading, photos, removePhoto, resolveLibrary, saveAvatar, saveCrop, userId]);
  return <ProfileAvatarContext.Provider value={value}>{children}</ProfileAvatarContext.Provider>;
}

export function useProfileAvatar() {
  const context = useContext(ProfileAvatarContext);
  if (!context) throw new Error("useProfileAvatar must be used within ProfileAvatarProvider.");
  return context;
}
