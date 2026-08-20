import { useCallback, useEffect, useState } from "react";
import { useAccountBootstrap } from "../features/account/AccountBootstrap";
import { loadAccountSettings, saveAccountSettings, subscribeToAccountChanges } from "../features/account/accountRepository";
import { useAuth } from "../features/account/AuthContext";
import {
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
  const { ready, revision } = useAccountBootstrap();
  const [customization, setCustomizationState] = useState<HomeCustomization>(loadHomeCustomization);

  useEffect(() => {
    const syncFromStorage = () => setCustomizationState(loadHomeCustomization());
    const syncFromApp = (event: Event) => setCustomizationState((event as CustomEvent<HomeCustomization>).detail);
    window.addEventListener("storage", syncFromStorage);
    window.addEventListener(homeCustomizationChangeEvent, syncFromApp);
    return () => {
      window.removeEventListener("storage", syncFromStorage);
      window.removeEventListener(homeCustomizationChangeEvent, syncFromApp);
    };
  }, []);

  useEffect(() => {
    if (!configured || !user || !ready) return;
    let current = true;
    const load = () => loadAccountSettings(user.id).then((settings) => {
      if (!current) return;
      saveHomeCustomization(settings.homeCustomization);
      setCustomizationState(settings.homeCustomization);
    }).catch((error: unknown) => console.error("FANatical could not refresh Home Customization.", error));
    void load();
    const focus = () => { void load(); };
    window.addEventListener("focus", focus);
    const unsubscribe = subscribeToAccountChanges(user.id, focus, ["user_settings"]);
    return () => { current = false; window.removeEventListener("focus", focus); unsubscribe(); };
  }, [configured, ready, revision, user]);

  const setCustomization = useCallback(async (nextCustomization: HomeCustomization) => {
    saveHomeCustomization(nextCustomization);
    if (configured && user) await saveAccountSettings(user.id, { homeCustomization: nextCustomization });
  }, [configured, user]);

  return { customization, setCustomization } as const;
}
