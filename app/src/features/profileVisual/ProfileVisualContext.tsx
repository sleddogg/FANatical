import { createContext, useCallback, useContext, useEffect, useMemo, useState, type PropsWithChildren } from "react";
import { deleteProfileVisualImage, loadProfileVisualImages, prepareProfileVisualImage, storeProfileVisualImage } from "./profileVisualStorage";
import { clampProfileVisualCrop, type ProfileVisualCrop, type ProfileVisualImageRecord, type ProfileVisualVariant } from "./types";
import { useAuth } from "../account/AuthContext";
import { subscribeToAccountChanges } from "../account/accountRepository";
import { deleteRemoteProfileVisual, loadRemoteProfileVisuals, saveRemoteProfileVisualCrop, uploadRemoteProfileVisual } from "./profileVisualRepository";

type ProfileVisualRecords = Readonly<Partial<Record<ProfileVisualVariant, ProfileVisualImageRecord>>>;

type ProfileVisualContextValue = Readonly<{
  images: ProfileVisualRecords;
  replaceImage: (variant: ProfileVisualVariant, file: File) => Promise<void>;
  removeImage: (variant: ProfileVisualVariant) => Promise<void>;
  saveCrop: (variant: ProfileVisualVariant, crop: ProfileVisualCrop) => Promise<void>;
}>;

const ProfileVisualContext = createContext<ProfileVisualContextValue | null>(null);

export function ProfileVisualProvider({ children }: PropsWithChildren) {
  const { configured, user } = useAuth();
  const [images, setImages] = useState<ProfileVisualRecords>({});

  useEffect(() => {
    let current = true;
    const load = () => (configured ? user ? loadRemoteProfileVisuals(user.id) : Promise.resolve([]) : loadProfileVisualImages()).then((records) => {
      if (current) setImages(Object.fromEntries(records.map((record) => [record.variant, record])));
    }).catch(() => {
      // Default artwork remains available when persistent browser media storage is unsupported.
    });
    void load();
    const focus = () => { void load(); };
    window.addEventListener("focus", focus);
    const unsubscribe = configured && user ? subscribeToAccountChanges(user.id, focus, ["profile_visuals"]) : undefined;
    return () => { current = false; window.removeEventListener("focus", focus); unsubscribe?.(); };
  }, [configured, user]);

  const replaceImage = useCallback(async (variant: ProfileVisualVariant, file: File) => {
    if (configured && !user) throw new Error("Sign in to save a Profile visual.");
    const record = await prepareProfileVisualImage(variant, file);
    if (configured && user) {
      const remote = await uploadRemoteProfileVisual(user.id, record, images[variant]);
      setImages((current) => ({ ...current, [variant]: remote }));
    } else {
      await storeProfileVisualImage(record);
      setImages((current) => ({ ...current, [variant]: record }));
    }
  }, [configured, images, user]);

  const removeImage = useCallback(async (variant: ProfileVisualVariant) => {
    if (configured && !user) throw new Error("Sign in to remove a Profile visual.");
    const currentRecord = images[variant];
    if (configured && user && currentRecord) await deleteRemoteProfileVisual(user.id, currentRecord);
    else await deleteProfileVisualImage(variant);
    setImages((current) => {
      const next = { ...current };
      delete next[variant];
      return next;
    });
  }, [configured, images, user]);

  const saveCrop = useCallback(async (variant: ProfileVisualVariant, crop: ProfileVisualCrop) => {
    if (configured && !user) throw new Error("Sign in to save a Profile visual crop.");
    const current = images[variant];
    if (!current) return;
    const next = { ...current, crop: clampProfileVisualCrop(crop), updatedAt: new Date().toISOString() };
    if (configured && user) await saveRemoteProfileVisualCrop(user.id, variant, next.crop);
    else await storeProfileVisualImage(next);
    setImages((records) => ({ ...records, [variant]: next }));
  }, [configured, images, user]);

  const value = useMemo<ProfileVisualContextValue>(() => ({ images, replaceImage, removeImage, saveCrop }), [images, removeImage, replaceImage, saveCrop]);
  return <ProfileVisualContext.Provider value={value}>{children}</ProfileVisualContext.Provider>;
}

export function useProfileVisual() {
  const context = useContext(ProfileVisualContext);
  if (!context) throw new Error("useProfileVisual must be used within ProfileVisualProvider.");
  return context;
}
