import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type PropsWithChildren,
} from "react";
import {
  defaultSelectedTeamId,
  followedTeamsFromCatalogIdentifiers,
  followedTeamsFromOfficialIds,
  frontendOfficialTeamIdForCatalogIdentifier,
  followedTeams as seededFollowedTeams,
  loadFollowedTeams,
  savePersistedFollowedTeamIds,
} from "../data/followedTeams";
import { loadTeamCatalog } from "../data/teamCatalogRepository";
import {
  localSelectedTeamPreferenceStore,
  type SelectedTeamPreferenceStore,
} from "../data/selectedTeamPreference";
import type { FollowedTeam, TeamId } from "../domain/team";
import type { OfficialTeamId } from "../data/officialSportsDatabase";
import { useAuth } from "../features/account/AuthContext";
import { accountClientStateClearedEvent } from "../features/account/accountClientState";
import { useAccountBootstrap } from "../features/account/AccountBootstrap";
import { loadAccountTeamState, replaceAccountFollowedTeams, saveAccountSettings, subscribeToAccountChanges } from "../features/account/accountRepository";

type TeamContextValue = Readonly<{
  followedTeams: readonly FollowedTeam[];
  selectedTeam: FollowedTeam;
  selectedTeamId: TeamId;
  selectTeam: (teamId: TeamId) => void;
  addFollowedTeam: (teamId: OfficialTeamId) => Promise<"added" | "duplicate" | "unavailable">;
  replaceFollowedTeams: (teamIds: readonly OfficialTeamId[]) => Promise<void>;
}>;

type TeamProviderProps = PropsWithChildren<{
  readonly preferenceStore?: SelectedTeamPreferenceStore;
}>;

const TeamContext = createContext<TeamContextValue | undefined>(undefined);

function requireFollowedTeam(teams: readonly FollowedTeam[], teamId: TeamId): FollowedTeam {
  const team = teams.find((candidate) => candidate.id === teamId);

  if (!team) {
    throw new Error(`Followed team ${teamId} does not exist in the team catalog.`);
  }

  return team;
}

const defaultSelectedTeam = requireFollowedTeam(seededFollowedTeams, defaultSelectedTeamId);

export function TeamProvider({
  children,
  preferenceStore = localSelectedTeamPreferenceStore,
}: TeamProviderProps) {
  const { configured, user } = useAuth();
  const prototypeMode = import.meta.env.DEV && !configured;
  const { ready, revision } = useAccountBootstrap();
  const [storedFollowedTeams, setStoredFollowedTeams] = useState<readonly FollowedTeam[]>(() => prototypeMode ? loadFollowedTeams() : seededFollowedTeams);
  const [storedSelectedTeamId, setStoredSelectedTeamId] = useState<TeamId>(defaultSelectedTeamId);
  const [loadedUserId, setLoadedUserId] = useState<string | null>(null);
  const selectionChangedInSession = useRef(false);

  const followedTeams = configured && user && loadedUserId !== user.id ? seededFollowedTeams : storedFollowedTeams;
  const selectedTeamId = configured && user && loadedUserId !== user.id ? defaultSelectedTeamId : storedSelectedTeamId;

  useEffect(() => {
    const clear = () => {
      selectionChangedInSession.current = false;
      setLoadedUserId(null);
      setStoredFollowedTeams(seededFollowedTeams);
      setStoredSelectedTeamId(defaultSelectedTeamId);
    };
    window.addEventListener(accountClientStateClearedEvent, clear);
    return () => window.removeEventListener(accountClientStateClearedEvent, clear);
  }, []);

  useEffect(() => {
    if (!configured || !user || !ready) return;
    let current = true;
    const load = () => Promise.all([loadAccountTeamState(user.id), loadTeamCatalog()]).then(([state, catalog]) => {
      if (!current) return;
      const nextTeams = followedTeamsFromCatalogIdentifiers(state.followedTeamIds, catalog);
      setStoredFollowedTeams(nextTeams);
      setStoredSelectedTeamId((currentId) => {
        if (selectionChangedInSession.current && nextTeams.some((team) => team.id === currentId)) {
          return currentId;
        }
        const selectedFrontendId = frontendOfficialTeamIdForCatalogIdentifier(state.selectedTeamId, catalog);
        const selected = nextTeams.find((team) => team.officialTeamId === selectedFrontendId) ?? nextTeams[0];
        return selected?.id ?? defaultSelectedTeamId;
      });
      setLoadedUserId(user.id);
    }).catch((error: unknown) => console.error("FANatical could not refresh followed teams.", error));
    void load();
    const focus = () => { void load(); };
    window.addEventListener("focus", focus);
    const unsubscribe = subscribeToAccountChanges(user.id, focus, ["user_followed_teams", "user_settings"]);
    return () => { current = false; window.removeEventListener("focus", focus); unsubscribe(); };
  }, [configured, ready, revision, user]);

  useEffect(() => {
    if (!prototypeMode || user) return;
    let isCurrent = true;

    void preferenceStore.loadSelectedTeamId().then((storedTeamId) => {
      if (isCurrent && !selectionChangedInSession.current && storedTeamId && followedTeams.some((team) => team.id === storedTeamId)) {
        setStoredSelectedTeamId(storedTeamId);
      }
    });

    return () => {
      isCurrent = false;
    };
  }, [followedTeams, preferenceStore, prototypeMode, user]);

  useEffect(() => {
    if (prototypeMode) setStoredFollowedTeams(loadFollowedTeams());
  }, [prototypeMode, user]);

  const selectTeam = useCallback(
    (teamId: TeamId) => {
      if (!followedTeams.some((team) => team.id === teamId)) {
        return;
      }

      selectionChangedInSession.current = true;
      setStoredSelectedTeamId(teamId);
      const selected = followedTeams.find((team) => team.id === teamId);
      if (configured && user && selected?.officialTeamId) void saveAccountSettings(user.id, { selectedTeamId: selected.officialTeamId });
      else if (prototypeMode) void preferenceStore.saveSelectedTeamId(teamId);
    },
    [configured, followedTeams, preferenceStore, prototypeMode, user],
  );

  const persistFollowedTeams = useCallback(async (teamIds: readonly OfficialTeamId[]) => {
    const uniqueIds = [...new Set(teamIds)].filter((teamId) => Boolean(followedTeamsFromOfficialIds([teamId]).length));
    if (configured && user) {
      await replaceAccountFollowedTeams(user.id, uniqueIds);
    } else {
      if (prototypeMode) savePersistedFollowedTeamIds(uniqueIds);
    }
    const nextTeams = followedTeamsFromOfficialIds(uniqueIds);
    setStoredFollowedTeams(nextTeams);

    if (!nextTeams.some((team) => team.id === selectedTeamId)) {
      const nextSelected = nextTeams[0];
      selectionChangedInSession.current = true;
      setStoredSelectedTeamId(nextSelected?.id ?? defaultSelectedTeamId);
      if (configured && user) await saveAccountSettings(user.id, { selectedTeamId: nextSelected?.officialTeamId ?? null });
      else if (prototypeMode && nextSelected) await preferenceStore.saveSelectedTeamId(nextSelected.id);
    }
  }, [configured, preferenceStore, prototypeMode, selectedTeamId, user]);

  const addFollowedTeam = useCallback(async (teamId: OfficialTeamId) => {
    if (followedTeams.some((team) => team.officialTeamId === teamId)) return "duplicate";
    const nextIds = [...followedTeams.map((team) => team.officialTeamId).filter((id): id is OfficialTeamId => Boolean(id)), teamId];
    if (followedTeamsFromOfficialIds(nextIds).length !== nextIds.length) return "unavailable";
    await persistFollowedTeams(nextIds);
    return "added";
  }, [followedTeams, persistFollowedTeams]);

  const selectedTeam = followedTeams.find((team) => team.id === selectedTeamId) ?? defaultSelectedTeam;
  const value = useMemo<TeamContextValue>(
    () => ({ followedTeams, selectedTeam, selectedTeamId, selectTeam, addFollowedTeam, replaceFollowedTeams: persistFollowedTeams }),
    [addFollowedTeam, followedTeams, persistFollowedTeams, selectTeam, selectedTeam, selectedTeamId],
  );

  return <TeamContext.Provider value={value}>{children}</TeamContext.Provider>;
}

export function useTeamContext() {
  const context = useContext(TeamContext);

  if (!context) {
    throw new Error("useTeamContext must be used within a TeamProvider.");
  }

  return context;
}
