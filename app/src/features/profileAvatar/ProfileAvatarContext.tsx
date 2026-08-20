import { createContext, useCallback, useContext, useEffect, useMemo, useState, type PropsWithChildren } from "react";
import { subscribeToAccountChanges } from "../account/accountRepository";
import { useAuth } from "../account/AuthContext";
import { activateRemoteProfileAvatar, deleteRemoteProfilePhoto, loadRemoteProfileAvatarLibrary, uploadRemoteProfileAvatar } from "./profileAvatarRepository";
import type { ProfileAvatarCrop, ProfileAvatarRecord } from "./types";

type ProfileAvatarContextValue = Readonly<{
  avatar: ProfileAvatarRecord | null;
  photos: readonly ProfileAvatarRecord[];
  loading: boolean;
  saveAvatar: (record: ProfileAvatarRecord) => Promise<void>;
  saveCrop: (crop: ProfileAvatarCrop) => Promise<void>;
  removePhoto: (photoId: string) => Promise<ProfileAvatarRecord | null>;
}>;

const ProfileAvatarContext = createContext<ProfileAvatarContextValue | null>(null);

export function ProfileAvatarProvider({ children }: PropsWithChildren) {
  const { configured, user } = useAuth();
  const [avatar, setAvatar] = useState<ProfileAvatarRecord | null>(null);
  const [photos, setPhotos] = useState<readonly ProfileAvatarRecord[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let current = true;
    if (!configured || !user) {
      setAvatar(null);
      setPhotos([]);
      setLoading(false);
      return () => { current = false; };
    }

    setAvatar(null);
    const load = () => {
      setLoading(true);
      return loadRemoteProfileAvatarLibrary(user.id).then((library) => {
        if (current) {
          setAvatar(library.active);
          setPhotos(library.photos);
        }
      }).catch((reason: unknown) => {
        console.warn("FANatical could not load the profile photo.", reason);
      }).finally(() => {
        if (current) setLoading(false);
      });
    };

    void load();
    const refreshSignedUrl = window.setInterval(() => { void load(); }, 50 * 60 * 1000);
    const focus = () => { void load(); };
    window.addEventListener("focus", focus);
    const unsubscribe = subscribeToAccountChanges(user.id, focus, ["profiles", "profile_photos"]);
    return () => {
      current = false;
      window.clearInterval(refreshSignedUrl);
      window.removeEventListener("focus", focus);
      unsubscribe();
    };
  }, [configured, user]);

  const saveAvatar = useCallback(async (record: ProfileAvatarRecord) => {
    if (!configured || !user) throw new Error("Sign in to save a profile photo.");
    const saved = record.sourceBlob && record.displayBlob
      ? await uploadRemoteProfileAvatar(user.id, record)
      : await activateRemoteProfileAvatar(user.id, record);
    setAvatar(saved);
    setPhotos((current) => current.some((photo) => photo.id === saved.id)
      ? current.map((photo) => photo.id === saved.id ? saved : photo)
      : [...current, saved]);
  }, [configured, user]);

  const saveCrop = useCallback(async (crop: ProfileAvatarCrop) => {
    if (!configured || !user) throw new Error("Sign in to save profile photo positioning.");
    if (!avatar) return;
    const saved = await activateRemoteProfileAvatar(user.id, { ...avatar, crop });
    setAvatar(saved);
    setPhotos((current) => current.map((photo) => photo.id === saved.id ? saved : photo));
  }, [avatar, configured, user]);

  const removePhoto = useCallback(async (photoId: string) => {
    if (!configured || !user) throw new Error("Sign in to remove a profile photo.");
    const library = await deleteRemoteProfilePhoto(user.id, photoId);
    setAvatar(library.active);
    setPhotos(library.photos);
    return library.active;
  }, [configured, user]);

  const value = useMemo<ProfileAvatarContextValue>(() => ({ avatar, photos, loading, saveAvatar, saveCrop, removePhoto }), [avatar, loading, photos, removePhoto, saveAvatar, saveCrop]);
  return <ProfileAvatarContext.Provider value={value}>{children}</ProfileAvatarContext.Provider>;
}

export function useProfileAvatar() {
  const context = useContext(ProfileAvatarContext);
  if (!context) throw new Error("useProfileAvatar must be used within ProfileAvatarProvider.");
  return context;
}
