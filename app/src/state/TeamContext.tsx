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
  followedTeamsFromOfficialIds,
  followedTeams as seededFollowedTeams,
  loadFollowedTeams,
  loadPersistedFollowedTeamIds,
  savePersistedFollowedTeamIds,
} from "../data/followedTeams";
import {
  localSelectedTeamPreferenceStore,
  type SelectedTeamPreferenceStore,
} from "../data/selectedTeamPreference";
import type { FollowedTeam, TeamId } from "../domain/team";
import type { OfficialTeamId } from "../data/officialSportsDatabase";
import { useAuth } from "../features/account/AuthContext";
import { useAccountBootstrap } from "../features/account/AccountBootstrap";
import { addAccountFollowedTeam, loadAccountTeamState, saveAccountSettings, subscribeToAccountChanges } from "../features/account/accountRepository";

type TeamContextValue = Readonly<{
  followedTeams: readonly FollowedTeam[];
  selectedTeam: FollowedTeam;
  selectedTeamId: TeamId;
  selectTeam: (teamId: TeamId) => void;
  addFollowedTeam: (teamId: OfficialTeamId) => Promise<"added" | "duplicate" | "unavailable">;
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
  const { ready, revision } = useAccountBootstrap();
  const [followedTeams, setFollowedTeams] = useState<readonly FollowedTeam[]>(loadFollowedTeams);
  const [selectedTeamId, setSelectedTeamId] = useState<TeamId>(defaultSelectedTeamId);
  const selectionChangedInSession = useRef(false);

  useEffect(() => {
    if (!configured || !user || !ready) return;
    let current = true;
    const load = () => loadAccountTeamState(user.id).then((state) => {
      if (!current) return;
      const nextTeams = followedTeamsFromOfficialIds(state.followedTeamIds);
      setFollowedTeams(nextTeams.length ? nextTeams : loadFollowedTeams());
      if (!selectionChangedInSession.current && state.selectedTeamId) {
        const selected = nextTeams.find((team) => team.officialTeamId === state.selectedTeamId);
        if (selected) setSelectedTeamId(selected.id);
      }
    }).catch((error: unknown) => console.error("FANatical could not refresh followed teams.", error));
    void load();
    const focus = () => { void load(); };
    window.addEventListener("focus", focus);
    const unsubscribe = subscribeToAccountChanges(user.id, focus, ["user_followed_teams", "user_settings"]);
    return () => { current = false; window.removeEventListener("focus", focus); unsubscribe(); };
  }, [configured, ready, revision, user]);

  useEffect(() => {
    if (configured && user) return;
    let isCurrent = true;

    void preferenceStore.loadSelectedTeamId().then((storedTeamId) => {
      if (isCurrent && !selectionChangedInSession.current && storedTeamId && followedTeams.some((team) => team.id === storedTeamId)) {
        setSelectedTeamId(storedTeamId);
      }
    });

    return () => {
      isCurrent = false;
    };
  }, [configured, followedTeams, preferenceStore, user]);

  useEffect(() => {
    if (!configured) setFollowedTeams(loadFollowedTeams());
    else if (!user) setFollowedTeams(seededFollowedTeams);
  }, [configured, user]);

  const selectTeam = useCallback(
    (teamId: TeamId) => {
      if (!followedTeams.some((team) => team.id === teamId)) {
        return;
      }

      selectionChangedInSession.current = true;
      setSelectedTeamId(teamId);
      const selected = followedTeams.find((team) => team.id === teamId);
      if (configured && user && selected?.officialTeamId) void saveAccountSettings(user.id, { selectedTeamId: selected.officialTeamId });
      else void preferenceStore.saveSelectedTeamId(teamId);
    },
    [configured, followedTeams, preferenceStore, user],
  );

  const addFollowedTeam = useCallback(async (teamId: OfficialTeamId) => {
    if (followedTeams.some((team) => team.officialTeamId === teamId)) return "duplicate";
    if (configured && user) {
      const result = await addAccountFollowedTeam(user.id, teamId, followedTeams.length);
      if (result === "duplicate") return result;
      const nextTeams = followedTeamsFromOfficialIds([...followedTeams.map((team) => team.officialTeamId).filter((id): id is OfficialTeamId => Boolean(id)), teamId]);
      setFollowedTeams(nextTeams);
      return "added";
    }
    const persistedIds = [...loadPersistedFollowedTeamIds(), teamId];
    savePersistedFollowedTeamIds(persistedIds);
    const nextTeams = loadFollowedTeams();
    if (!nextTeams.some((team) => team.officialTeamId === teamId)) return "unavailable";
    setFollowedTeams(nextTeams);
    return "added";
  }, [configured, followedTeams, user]);

  const selectedTeam = followedTeams.find((team) => team.id === selectedTeamId) ?? defaultSelectedTeam;
  const value = useMemo<TeamContextValue>(
    () => ({ followedTeams, selectedTeam, selectedTeamId, selectTeam, addFollowedTeam }),
    [addFollowedTeam, followedTeams, selectTeam, selectedTeam, selectedTeamId],
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
