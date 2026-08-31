import { useCallback, useEffect, useState } from "react";
import { useAccountBootstrap } from "../features/account/AccountBootstrap";
import { loadAccountSettings, saveAccountSettings, subscribeToAccountChanges } from "../features/account/accountRepository";
import { useAuth } from "../features/account/AuthContext";
import { accountClientStateClearedEvent } from "../features/account/accountClientState";
import {
  loadThemePreference,
  saveThemePreference,
  themePreferenceChangeEvent,
} from "./themePreferenceStorage";
import { defaultThemePreference, type ThemePreference } from "../theme/theme";

export {
  defaultThemePreference,
  normalizeThemePreference,
  themeOrders,
  themeSources,
  type ThemeOrder,
  type ThemePreference,
  type ThemeSource,
} from "../theme/theme";
export { loadThemePreference, saveThemePreference, themePreferenceStorageKey } from "./themePreferenceStorage";

export function useThemePreference() {
  const { configured, user } = useAuth();
  const prototypeMode = import.meta.env.DEV && !configured;
  const { ready, revision } = useAccountBootstrap();
  const [storedPreference, setStoredPreference] = useState<ThemePreference>(loadThemePreference);
  const [loadedUserId, setLoadedUserId] = useState<string | null>(null);

  useEffect(() => {
    if (!prototypeMode) return;
    const syncFromStorage = () => setStoredPreference(loadThemePreference());
    const syncFromApp = (event: Event) => setStoredPreference((event as CustomEvent<ThemePreference>).detail);
    window.addEventListener("storage", syncFromStorage);
    window.addEventListener(themePreferenceChangeEvent, syncFromApp);
    return () => {
      window.removeEventListener("storage", syncFromStorage);
      window.removeEventListener(themePreferenceChangeEvent, syncFromApp);
    };
  }, [prototypeMode]);

  useEffect(() => {
    const clear = () => {
      setLoadedUserId(null);
      setStoredPreference(defaultThemePreference);
    };
    window.addEventListener(accountClientStateClearedEvent, clear);
    return () => window.removeEventListener(accountClientStateClearedEvent, clear);
  }, []);

  useEffect(() => {
    if (!configured || !user || !ready) return;
    let current = true;
    const load = () => loadAccountSettings(user.id).then((settings) => {
      if (!current) return;
      setStoredPreference(settings.themePreference);
      setLoadedUserId(user.id);
    }).catch((error: unknown) => console.error("FANatical could not refresh App Theme.", error));
    void load();
    const focus = () => { void load(); };
    window.addEventListener("focus", focus);
    const unsubscribe = subscribeToAccountChanges(user.id, focus, ["user_settings"]);
    return () => { current = false; window.removeEventListener("focus", focus); unsubscribe(); };
  }, [configured, ready, revision, user]);

  const setPreference = useCallback(async (nextPreference: ThemePreference) => {
    setStoredPreference(nextPreference);
    if (configured && user) {
      setLoadedUserId(user.id);
      await saveAccountSettings(user.id, { themePreference: nextPreference });
    } else if (prototypeMode) saveThemePreference(nextPreference);
  }, [configured, prototypeMode, user]);

  const preference = configured
    ? user && loadedUserId === user.id ? storedPreference : defaultThemePreference
    : prototypeMode ? storedPreference : defaultThemePreference;
  return { preference, setPreference } as const;
}
