import { useCallback, useEffect, useState } from "react";
import { useAccountBootstrap } from "../features/account/AccountBootstrap";
import { loadAccountSettings, saveAccountSettings, subscribeToAccountChanges } from "../features/account/accountRepository";
import { useAuth } from "../features/account/AuthContext";
import { loadNavigationSide, navigationSideChangeEvent, saveNavigationSide, type NavigationSide } from "./navigationSideStorage";

export { loadNavigationSide, navigationSideStorageKey, saveNavigationSide, type NavigationSide } from "./navigationSideStorage";

export function useNavigationSide() {
  const { configured, user } = useAuth();
  const { ready, revision } = useAccountBootstrap();
  const [side, setSideState] = useState<NavigationSide>(loadNavigationSide);

  useEffect(() => {
    const syncFromStorage = () => setSideState(loadNavigationSide());
    const syncFromApp = (event: Event) => setSideState((event as CustomEvent<NavigationSide>).detail);
    window.addEventListener("storage", syncFromStorage);
    window.addEventListener(navigationSideChangeEvent, syncFromApp);
    return () => {
      window.removeEventListener("storage", syncFromStorage);
      window.removeEventListener(navigationSideChangeEvent, syncFromApp);
    };
  }, []);

  useEffect(() => {
    if (!configured || !user || !ready) return;
    let current = true;
    const load = () => loadAccountSettings(user.id).then((settings) => {
      if (!current) return;
      saveNavigationSide(settings.navigationSide);
      setSideState(settings.navigationSide);
    }).catch((error: unknown) => console.error("FANatical could not refresh Navigation Side.", error));
    void load();
    const focus = () => { void load(); };
    window.addEventListener("focus", focus);
    const unsubscribe = subscribeToAccountChanges(user.id, focus, ["user_settings"]);
    return () => { current = false; window.removeEventListener("focus", focus); unsubscribe(); };
  }, [configured, ready, revision, user]);

  const setSide = useCallback(async (nextSide: NavigationSide) => {
    saveNavigationSide(nextSide);
    if (configured && user) await saveAccountSettings(user.id, { navigationSide: nextSide });
  }, [configured, user]);
  return { side, setSide } as const;
}
