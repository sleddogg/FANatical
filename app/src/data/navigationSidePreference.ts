import { useCallback, useEffect, useState } from "react";
import { useAccountBootstrap } from "../features/account/AccountBootstrap";
import { loadAccountSettings, saveAccountSettings, subscribeToAccountChanges } from "../features/account/accountRepository";
import { useAuth } from "../features/account/AuthContext";
import { accountClientStateClearedEvent } from "../features/account/accountClientState";
import { loadNavigationSide, navigationSideChangeEvent, saveNavigationSide, type NavigationSide } from "./navigationSideStorage";

export { loadNavigationSide, navigationSideStorageKey, saveNavigationSide, type NavigationSide } from "./navigationSideStorage";

export function useNavigationSide() {
  const { configured, user } = useAuth();
  const prototypeMode = import.meta.env.DEV && !configured;
  const { ready, revision } = useAccountBootstrap();
  const [storedSide, setStoredSide] = useState<NavigationSide>(loadNavigationSide);
  const [loadedUserId, setLoadedUserId] = useState<string | null>(null);

  useEffect(() => {
    if (!prototypeMode) return;
    const syncFromStorage = () => setStoredSide(loadNavigationSide());
    const syncFromApp = (event: Event) => setStoredSide((event as CustomEvent<NavigationSide>).detail);
    window.addEventListener("storage", syncFromStorage);
    window.addEventListener(navigationSideChangeEvent, syncFromApp);
    return () => {
      window.removeEventListener("storage", syncFromStorage);
      window.removeEventListener(navigationSideChangeEvent, syncFromApp);
    };
  }, [prototypeMode]);

  useEffect(() => {
    const clear = () => {
      setLoadedUserId(null);
      setStoredSide("left");
    };
    window.addEventListener(accountClientStateClearedEvent, clear);
    return () => window.removeEventListener(accountClientStateClearedEvent, clear);
  }, []);

  useEffect(() => {
    if (!configured || !user || !ready) return;
    let current = true;
    const load = () => loadAccountSettings(user.id).then((settings) => {
      if (!current) return;
      setStoredSide(settings.navigationSide);
      setLoadedUserId(user.id);
    }).catch((error: unknown) => console.error("FANatical could not refresh Navigation Side.", error));
    void load();
    const focus = () => { void load(); };
    window.addEventListener("focus", focus);
    const unsubscribe = subscribeToAccountChanges(user.id, focus, ["user_settings"]);
    return () => { current = false; window.removeEventListener("focus", focus); unsubscribe(); };
  }, [configured, ready, revision, user]);

  const setSide = useCallback(async (nextSide: NavigationSide) => {
    setStoredSide(nextSide);
    if (configured && user) {
      setLoadedUserId(user.id);
      await saveAccountSettings(user.id, { navigationSide: nextSide });
    } else if (prototypeMode) saveNavigationSide(nextSide);
  }, [configured, prototypeMode, user]);
  const side = configured
    ? user && loadedUserId === user.id ? storedSide : "left"
    : prototypeMode ? storedSide : "left";
  return { side, setSide } as const;
}
