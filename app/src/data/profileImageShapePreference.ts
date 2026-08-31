import { useCallback, useEffect, useState } from "react";
import { useAccountBootstrap } from "../features/account/AccountBootstrap";
import { loadAccountSettings, saveAccountSettings, subscribeToAccountChanges } from "../features/account/accountRepository";
import { useAuth } from "../features/account/AuthContext";
import { accountClientStateClearedEvent } from "../features/account/accountClientState";
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
  const prototypeMode = import.meta.env.DEV && !configured;
  const { ready, revision } = useAccountBootstrap();
  const [storedShape, setStoredShape] = useState<ProfileImageShape>(loadProfileImageShape);
  const [loadedUserId, setLoadedUserId] = useState<string | null>(null);

  useEffect(() => {
    if (!prototypeMode) return;
    const syncFromStorage = () => setStoredShape(loadProfileImageShape());
    const syncFromApp = (event: Event) => setStoredShape((event as CustomEvent<ProfileImageShape>).detail);
    window.addEventListener("storage", syncFromStorage);
    window.addEventListener(profileImageShapeChangeEvent, syncFromApp);
    return () => {
      window.removeEventListener("storage", syncFromStorage);
      window.removeEventListener(profileImageShapeChangeEvent, syncFromApp);
    };
  }, [prototypeMode]);

  useEffect(() => {
    const clear = () => {
      setLoadedUserId(null);
      setStoredShape("circle");
    };
    window.addEventListener(accountClientStateClearedEvent, clear);
    return () => window.removeEventListener(accountClientStateClearedEvent, clear);
  }, []);

  useEffect(() => {
    if (!configured || !user || !ready) return;
    let current = true;
    const load = () => loadAccountSettings(user.id).then((settings) => {
      if (!current) return;
      setStoredShape(settings.profileImageShape);
      setLoadedUserId(user.id);
    }).catch((error: unknown) => console.error("FANatical could not refresh Profile Image Shape.", error));
    void load();
    const focus = () => { void load(); };
    window.addEventListener("focus", focus);
    const unsubscribe = subscribeToAccountChanges(user.id, focus, ["user_settings"]);
    return () => { current = false; window.removeEventListener("focus", focus); unsubscribe(); };
  }, [configured, ready, revision, user]);

  const setShape = useCallback(async (nextShape: ProfileImageShape) => {
    setStoredShape(nextShape);
    if (configured && user) {
      setLoadedUserId(user.id);
      await saveAccountSettings(user.id, { profileImageShape: nextShape });
    } else if (prototypeMode) saveProfileImageShape(nextShape);
  }, [configured, prototypeMode, user]);

  const shape = configured
    ? user && loadedUserId === user.id ? storedShape : "circle"
    : prototypeMode ? storedShape : "circle";
  return { shape, setShape } as const;
}
