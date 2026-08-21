import { useCallback, useEffect, useState } from "react";
import { useAccountBootstrap } from "../features/account/AccountBootstrap";
import { loadAccountSettings, saveAccountSettings, subscribeToAccountChanges } from "../features/account/accountRepository";
import { useAuth } from "../features/account/AuthContext";
import {
  loadThemePreference,
  saveThemePreference,
  themePreferenceChangeEvent,
} from "./themePreferenceStorage";
import type { ThemePreference } from "../theme/theme";

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
  const { ready, revision } = useAccountBootstrap();
  const [preference, setPreferenceState] = useState<ThemePreference>(loadThemePreference);

  useEffect(() => {
    const syncFromStorage = () => setPreferenceState(loadThemePreference());
    const syncFromApp = (event: Event) => setPreferenceState((event as CustomEvent<ThemePreference>).detail);
    window.addEventListener("storage", syncFromStorage);
    window.addEventListener(themePreferenceChangeEvent, syncFromApp);
    return () => {
      window.removeEventListener("storage", syncFromStorage);
      window.removeEventListener(themePreferenceChangeEvent, syncFromApp);
    };
  }, []);

  useEffect(() => {
    if (!configured || !user || !ready) return;
    let current = true;
    const load = () => loadAccountSettings(user.id).then((settings) => {
      if (!current) return;
      saveThemePreference(settings.themePreference);
      setPreferenceState(settings.themePreference);
    }).catch((error: unknown) => console.error("FANatical could not refresh App Theme.", error));
    void load();
    const focus = () => { void load(); };
    window.addEventListener("focus", focus);
    const unsubscribe = subscribeToAccountChanges(user.id, focus, ["user_settings"]);
    return () => { current = false; window.removeEventListener("focus", focus); unsubscribe(); };
  }, [configured, ready, revision, user]);

  const setPreference = useCallback(async (nextPreference: ThemePreference) => {
    saveThemePreference(nextPreference);
    if (configured && user) await saveAccountSettings(user.id, { themePreference: nextPreference });
  }, [configured, user]);

  return { preference, setPreference } as const;
}
