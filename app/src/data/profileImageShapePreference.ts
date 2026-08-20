import { useCallback, useEffect, useState } from "react";
import { useAccountBootstrap } from "../features/account/AccountBootstrap";
import { loadAccountSettings, saveAccountSettings, subscribeToAccountChanges } from "../features/account/accountRepository";
import { useAuth } from "../features/account/AuthContext";
import {
  loadProfileImageShape,
  profileImageShapeChangeEvent,
  saveProfileImageShape,
  type ProfileImageShape,
} from "./profileImageShapeStorage";

export {
  loadProfileImageShape,
  profileImageShapeStorageKey,
  saveProfileImageShape,
  type ProfileImageShape,
} from "./profileImageShapeStorage";

export function useProfileImageShape() {
  const { configured, user } = useAuth();
  const { ready, revision } = useAccountBootstrap();
  const [shape, setShapeState] = useState<ProfileImageShape>(loadProfileImageShape);

  useEffect(() => {
    const syncFromStorage = () => setShapeState(loadProfileImageShape());
    const syncFromApp = (event: Event) => setShapeState((event as CustomEvent<ProfileImageShape>).detail);
    window.addEventListener("storage", syncFromStorage);
    window.addEventListener(profileImageShapeChangeEvent, syncFromApp);
    return () => {
      window.removeEventListener("storage", syncFromStorage);
      window.removeEventListener(profileImageShapeChangeEvent, syncFromApp);
    };
  }, []);

  useEffect(() => {
    if (!configured || !user || !ready) return;
    let current = true;
    const load = () => loadAccountSettings(user.id).then((settings) => {
      if (!current) return;
      saveProfileImageShape(settings.profileImageShape);
      setShapeState(settings.profileImageShape);
    }).catch((error: unknown) => console.error("FANatical could not refresh Profile Image Shape.", error));
    void load();
    const focus = () => { void load(); };
    window.addEventListener("focus", focus);
    const unsubscribe = subscribeToAccountChanges(user.id, focus, ["user_settings"]);
    return () => { current = false; window.removeEventListener("focus", focus); unsubscribe(); };
  }, [configured, ready, revision, user]);

  const setShape = useCallback(async (nextShape: ProfileImageShape) => {
    saveProfileImageShape(nextShape);
    if (configured && user) await saveAccountSettings(user.id, { profileImageShape: nextShape });
  }, [configured, user]);

  return { shape, setShape } as const;
}
