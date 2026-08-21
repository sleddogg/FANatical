import { createContext, useContext, useEffect, useMemo, useState, type PropsWithChildren } from "react";
import { loadFollowedTeams } from "../../data/followedTeams";
import { loadNavigationSide } from "../../data/navigationSideStorage";
import { loadProfileImageShape } from "../../data/profileImageShapeStorage";
import { loadHomeCustomization } from "../../data/homeCustomizationStorage";
import { loadThemePreference } from "../../data/themePreferenceStorage";
import { localSelectedTeamPreferenceStore } from "../../data/selectedTeamPreference";
import type { OfficialTeamId } from "../../data/officialSportsDatabase";
import { initialProfile } from "../profile/mockProfileData";
import { loadProfileVisualImages } from "../profileVisual/profileVisualStorage";
import { loadRemoteProfileVisuals, uploadRemoteProfileVisual } from "../profileVisual/profileVisualRepository";
import { loadAccountSettings, replaceAccountFollowedTeams, saveAccountSettings, saveOwnedProfile } from "./accountRepository";
import { useAuth } from "./AuthContext";

type BootstrapState = Readonly<{
  ready: boolean;
  error: string;
  revision: number;
}>;

const AccountBootstrapContext = createContext<BootstrapState>({ ready: true, error: "", revision: 0 });
const migrationVersion = 1;

async function migratePrototypeAccount(userId: string) {
  const settings = await loadAccountSettings(userId);
  if (settings.prototypeMigrationVersion >= migrationVersion) return;

  const followedTeamIds = loadFollowedTeams()
    .map((team) => team.officialTeamId)
    .filter((teamId): teamId is OfficialTeamId => Boolean(teamId));
  const selectedLegacyId = await localSelectedTeamPreferenceStore.loadSelectedTeamId();
  const selectedTeamId = loadFollowedTeams().find((team) => team.id === selectedLegacyId)?.officialTeamId ?? followedTeamIds[0] ?? null;

  await saveOwnedProfile(userId, { ...initialProfile, id: userId });
  await replaceAccountFollowedTeams(userId, followedTeamIds);
  await saveAccountSettings(userId, {
    navigationSide: loadNavigationSide(),
    profileImageShape: loadProfileImageShape(),
    homeCustomization: loadHomeCustomization(),
    themePreference: loadThemePreference(),
    selectedTeamId,
  });

  let localVisuals = [] as Awaited<ReturnType<typeof loadProfileVisualImages>>;
  try {
    localVisuals = await loadProfileVisualImages();
  } catch {
    // A browser without IndexedDB simply has no local media to migrate.
  }
  if (localVisuals.length) {
    const remoteVisuals = await loadRemoteProfileVisuals(userId);
    for (const visual of localVisuals) {
      if (!remoteVisuals.some((remote) => remote.variant === visual.variant)) await uploadRemoteProfileVisual(userId, visual);
    }
  }

  await saveAccountSettings(userId, { prototypeMigrationVersion: migrationVersion });
}

export function AccountBootstrapProvider({ children }: PropsWithChildren) {
  const { configured, loading, user } = useAuth();
  const [state, setState] = useState<BootstrapState>({ ready: !configured, error: "", revision: 0 });

  useEffect(() => {
    let current = true;
    if (!configured || loading || !user) {
      setState((previous) => ({ ready: !loading, error: "", revision: previous.revision }));
      return () => { current = false; };
    }
    setState((previous) => ({ ready: false, error: "", revision: previous.revision }));
    void migratePrototypeAccount(user.id).then(() => {
      if (current) setState((previous) => ({ ready: true, error: "", revision: previous.revision + 1 }));
    }).catch((reason: unknown) => {
      if (current) setState((previous) => ({ ready: true, error: reason instanceof Error ? reason.message : "Account data could not be synchronized.", revision: previous.revision }));
    });
    return () => { current = false; };
  }, [configured, loading, user]);

  const value = useMemo(() => state, [state]);
  return (
    <AccountBootstrapContext.Provider value={value}>
      {state.error ? <div className="account-sync-error" role="alert">Account sync needs attention: {state.error}</div> : null}
      {children}
    </AccountBootstrapContext.Provider>
  );
}

export function useAccountBootstrap() {
  return useContext(AccountBootstrapContext);
}
