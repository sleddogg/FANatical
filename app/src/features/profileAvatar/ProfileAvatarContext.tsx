import { createContext, useCallback, useContext, useEffect, useMemo, useState, type PropsWithChildren } from "react";
import { subscribeToAccountChanges } from "../account/accountRepository";
import { useAuth } from "../account/AuthContext";
import { deleteRemoteProfileAvatar, loadRemoteProfileAvatar, saveRemoteProfileAvatarCrop, uploadRemoteProfileAvatar } from "./profileAvatarRepository";
import type { ProfileAvatarCrop, ProfileAvatarRecord } from "./types";

type ProfileAvatarContextValue = Readonly<{
  avatar: ProfileAvatarRecord | null;
  loading: boolean;
  saveAvatar: (record: ProfileAvatarRecord) => Promise<void>;
  saveCrop: (crop: ProfileAvatarCrop) => Promise<void>;
  removeAvatar: () => Promise<void>;
}>;

const ProfileAvatarContext = createContext<ProfileAvatarContextValue | null>(null);

export function ProfileAvatarProvider({ children }: PropsWithChildren) {
  const { configured, user } = useAuth();
  const [avatar, setAvatar] = useState<ProfileAvatarRecord | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let current = true;
    if (!configured || !user) {
      setAvatar(null);
      setLoading(false);
      return () => { current = false; };
    }

    setAvatar(null);
    const load = () => {
      setLoading(true);
      return loadRemoteProfileAvatar(user.id).then((record) => {
        if (current) setAvatar(record);
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
    const unsubscribe = subscribeToAccountChanges(user.id, focus, ["profiles"]);
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
      ? await uploadRemoteProfileAvatar(user.id, record, avatar)
      : await saveRemoteProfileAvatarCrop(user.id, record, record.crop);
    setAvatar(saved);
  }, [avatar, configured, user]);

  const saveCrop = useCallback(async (crop: ProfileAvatarCrop) => {
    if (!configured || !user) throw new Error("Sign in to save profile photo positioning.");
    if (!avatar) return;
    setAvatar(await saveRemoteProfileAvatarCrop(user.id, avatar, crop));
  }, [avatar, configured, user]);

  const removeAvatar = useCallback(async () => {
    if (!configured || !user) throw new Error("Sign in to remove a profile photo.");
    if (!avatar) return;
    await deleteRemoteProfileAvatar(user.id, avatar);
    setAvatar(null);
  }, [avatar, configured, user]);

  const value = useMemo<ProfileAvatarContextValue>(() => ({ avatar, loading, saveAvatar, saveCrop, removeAvatar }), [avatar, loading, removeAvatar, saveAvatar, saveCrop]);
  return <ProfileAvatarContext.Provider value={value}>{children}</ProfileAvatarContext.Provider>;
}

export function useProfileAvatar() {
  const context = useContext(ProfileAvatarContext);
  if (!context) throw new Error("useProfileAvatar must be used within ProfileAvatarProvider.");
  return context;
}
