import { useCallback, useEffect, useRef, useState } from "react";
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
  const requestSequence = useRef(0);

  useEffect(() => {
    const syncFromStorage = () => setStoredPreference(loadThemePreference());
    const syncFromApp = (event: Event) => {
      requestSequence.current += 1;
      setStoredPreference((event as CustomEvent<ThemePreference>).detail);
      setLoadedUserId(configured && user ? user.id : null);
    };
    if (prototypeMode) window.addEventListener("storage", syncFromStorage);
    window.addEventListener(themePreferenceChangeEvent, syncFromApp);
    return () => {
      if (prototypeMode) window.removeEventListener("storage", syncFromStorage);
      window.removeEventListener(themePreferenceChangeEvent, syncFromApp);
    };
  }, [configured, prototypeMode, user]);

  useEffect(() => {
    const clear = () => {
      requestSequence.current += 1;
      setLoadedUserId(null);
      setStoredPreference(defaultThemePreference);
    };
    window.addEventListener(accountClientStateClearedEvent, clear);
    return () => window.removeEventListener(accountClientStateClearedEvent, clear);
  }, []);

  useEffect(() => {
    if (!configured || !user || !ready) return;
    let current = true;
    const load = () => {
      const requestId = ++requestSequence.current;
      return loadAccountSettings(user.id).then((settings) => {
        if (!current || requestId !== requestSequence.current) return;
        setStoredPreference(settings.themePreference);
        setLoadedUserId(user.id);
      }).catch((error: unknown) => console.error("FANatical could not refresh App Theme.", error));
    };
    void load();
    const focus = () => { void load(); };
    window.addEventListener("focus", focus);
    const unsubscribe = subscribeToAccountChanges(user.id, focus, ["user_settings"]);
    return () => { current = false; requestSequence.current += 1; window.removeEventListener("focus", focus); unsubscribe(); };
  }, [configured, ready, revision, user]);

  const setPreference = useCallback(async (nextPreference: ThemePreference) => {
    requestSequence.current += 1;
    setStoredPreference(nextPreference);
    if (configured && user) {
      setLoadedUserId(user.id);
      await saveAccountSettings(user.id, { themePreference: nextPreference });
      requestSequence.current += 1;
      setStoredPreference(nextPreference);
      setLoadedUserId(user.id);
      window.dispatchEvent(new CustomEvent<ThemePreference>(themePreferenceChangeEvent, { detail: nextPreference }));
    } else if (prototypeMode) saveThemePreference(nextPreference);
  }, [configured, prototypeMode, user]);

  const preference = configured
    ? user && loadedUserId === user.id ? storedPreference : defaultThemePreference
    : prototypeMode ? storedPreference : defaultThemePreference;
  return { preference, setPreference } as const;
}
