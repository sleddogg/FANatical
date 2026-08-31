import { useCallback, useEffect, useState } from "react";
import { useAccountBootstrap } from "../features/account/AccountBootstrap";
import { loadAccountSettings, saveAccountSettings, subscribeToAccountChanges } from "../features/account/accountRepository";
import { useAuth } from "../features/account/AuthContext";
import { accountClientStateClearedEvent } from "../features/account/accountClientState";
import {
  defaultHomeCustomization,
  homeCustomizationChangeEvent,
  loadHomeCustomization,
  saveHomeCustomization,
  type HomeCustomization,
} from "./homeCustomizationStorage";

export {
  defaultHomeCustomization,
  homeCustomizationStorageKey,
  homeOverlayPositions,
  loadHomeCustomization,
  normalizeHomeCustomization,
  saveHomeCustomization,
  type FanCardLayout,
  type HomeCustomization,
  type HomeOverlayPosition,
} from "./homeCustomizationStorage";

export function useHomeCustomization() {
  const { configured, user } = useAuth();
  const prototypeMode = import.meta.env.DEV && !configured;
  const { ready, revision } = useAccountBootstrap();
  const [storedCustomization, setStoredCustomization] = useState<HomeCustomization>(loadHomeCustomization);
  const [loadedUserId, setLoadedUserId] = useState<string | null>(null);

  useEffect(() => {
    if (!prototypeMode) return;
    const syncFromStorage = () => setStoredCustomization(loadHomeCustomization());
    const syncFromApp = (event: Event) => setStoredCustomization((event as CustomEvent<HomeCustomization>).detail);
    window.addEventListener("storage", syncFromStorage);
    window.addEventListener(homeCustomizationChangeEvent, syncFromApp);
    return () => {
      window.removeEventListener("storage", syncFromStorage);
      window.removeEventListener(homeCustomizationChangeEvent, syncFromApp);
    };
  }, [prototypeMode]);

  useEffect(() => {
    const clear = () => {
      setLoadedUserId(null);
      setStoredCustomization(defaultHomeCustomization);
    };
    window.addEventListener(accountClientStateClearedEvent, clear);
    return () => window.removeEventListener(accountClientStateClearedEvent, clear);
  }, []);

  useEffect(() => {
    if (!configured || !user || !ready) return;
    let current = true;
    const load = () => loadAccountSettings(user.id).then((settings) => {
      if (!current) return;
      setStoredCustomization(settings.homeCustomization);
      setLoadedUserId(user.id);
    }).catch((error: unknown) => console.error("FANatical could not refresh Home Customization.", error));
    void load();
    const focus = () => { void load(); };
    window.addEventListener("focus", focus);
    const unsubscribe = subscribeToAccountChanges(user.id, focus, ["user_settings"]);
    return () => { current = false; window.removeEventListener("focus", focus); unsubscribe(); };
  }, [configured, ready, revision, user]);

  const setCustomization = useCallback(async (nextCustomization: HomeCustomization) => {
    setStoredCustomization(nextCustomization);
    if (configured && user) {
      setLoadedUserId(user.id);
      await saveAccountSettings(user.id, { homeCustomization: nextCustomization });
    } else if (prototypeMode) saveHomeCustomization(nextCustomization);
  }, [configured, prototypeMode, user]);

  const customization = configured
    ? user && loadedUserId === user.id ? storedCustomization : defaultHomeCustomization
    : prototypeMode ? storedCustomization : defaultHomeCustomization;
  return { customization, setCustomization } as const;
}
