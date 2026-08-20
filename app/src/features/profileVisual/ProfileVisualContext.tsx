import { createContext, useCallback, useContext, useEffect, useMemo, useState, type PropsWithChildren } from "react";
import { deleteProfileVisualImage, loadProfileVisualLibrary, storeProfileVisualImage } from "./profileVisualStorage";
import type { ProfileVisualImageRecord, ProfileVisualLibrary, ProfileVisualVariant } from "./types";
import { useAuth } from "../account/AuthContext";
import { subscribeToAccountChanges } from "../account/accountRepository";
import { activateRemoteProfileVisual, deleteRemoteProfileVisualImage, loadRemoteProfileVisualLibrary, uploadRemoteProfileVisual } from "./profileVisualRepository";

type ProfileVisualRecords = Readonly<Partial<Record<ProfileVisualVariant, ProfileVisualImageRecord>>>;

type ProfileVisualContextValue = Readonly<{
  images: ProfileVisualRecords;
  library: ProfileVisualLibrary;
  saveImage: (record: ProfileVisualImageRecord) => Promise<ProfileVisualImageRecord>;
  removeImage: (variant: ProfileVisualVariant, imageId: string) => Promise<ProfileVisualImageRecord | undefined>;
}>;

const emptyLibrary: ProfileVisualLibrary = { mobile: [], wide: [] };
const ProfileVisualContext = createContext<ProfileVisualContextValue | null>(null);

export function ProfileVisualProvider({ children }: PropsWithChildren) {
  const { configured, user } = useAuth();
  const [images, setImages] = useState<ProfileVisualRecords>({});
  const [library, setLibrary] = useState<ProfileVisualLibrary>(emptyLibrary);

  const load = useCallback(async () => {
    const result = configured
      ? user ? await loadRemoteProfileVisualLibrary(user.id) : { images: {}, library: emptyLibrary }
      : await loadProfileVisualLibrary();
    setImages(result.images);
    setLibrary(result.library);
    return result;
  }, [configured, user]);

  useEffect(() => {
    let current = true;
    const refresh = () => load().catch((reason: unknown) => {
      if (current) console.warn("FANatical could not load the Profile visual library.", reason);
    });
    void refresh();
    const focus = () => { void refresh(); };
    window.addEventListener("focus", focus);
    const unsubscribe = configured && user ? subscribeToAccountChanges(user.id, focus, ["profile_visuals", "profile_visual_images"]) : undefined;
    return () => { current = false; window.removeEventListener("focus", focus); unsubscribe?.(); };
  }, [configured, load, user]);

  const saveImage = useCallback(async (record: ProfileVisualImageRecord) => {
    if (configured && !user) throw new Error("Sign in to save a Profile visual.");
    const saved = configured && user
      ? record.sourceBlob && record.displayBlob
        ? await uploadRemoteProfileVisual(user.id, record)
        : await activateRemoteProfileVisual(user.id, record)
      : await storeProfileVisualImage(record);
    await load();
    return saved;
  }, [configured, load, user]);

  const removeImage = useCallback(async (variant: ProfileVisualVariant, imageId: string) => {
    if (configured && !user) throw new Error("Sign in to remove a Profile visual.");
    const result = configured && user
      ? await deleteRemoteProfileVisualImage(user.id, imageId)
      : (await deleteProfileVisualImage(variant, imageId), await loadProfileVisualLibrary());
    setImages(result.images);
    setLibrary(result.library);
    return result.images[variant];
  }, [configured, user]);

  const value = useMemo<ProfileVisualContextValue>(() => ({ images, library, saveImage, removeImage }), [images, library, removeImage, saveImage]);
  return <ProfileVisualContext.Provider value={value}>{children}</ProfileVisualContext.Provider>;
}

export function useProfileVisual() {
  const context = useContext(ProfileVisualContext);
  if (!context) throw new Error("useProfileVisual must be used within ProfileVisualProvider.");
  return context;
}
