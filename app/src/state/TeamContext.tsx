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

type TeamContextValue = Readonly<{
  followedTeams: readonly FollowedTeam[];
  selectedTeam: FollowedTeam;
  selectedTeamId: TeamId;
  selectTeam: (teamId: TeamId) => void;
  addFollowedTeam: (teamId: OfficialTeamId) => "added" | "duplicate" | "unavailable";
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
  const [followedTeams, setFollowedTeams] = useState<readonly FollowedTeam[]>(loadFollowedTeams);
  const [selectedTeamId, setSelectedTeamId] = useState<TeamId>(defaultSelectedTeamId);
  const selectionChangedInSession = useRef(false);

  useEffect(() => {
    let isCurrent = true;

    void preferenceStore.loadSelectedTeamId().then((storedTeamId) => {
      if (isCurrent && !selectionChangedInSession.current && storedTeamId && followedTeams.some((team) => team.id === storedTeamId)) {
        setSelectedTeamId(storedTeamId);
      }
    });

    return () => {
      isCurrent = false;
    };
  }, [followedTeams, preferenceStore]);

  const selectTeam = useCallback(
    (teamId: TeamId) => {
      if (!followedTeams.some((team) => team.id === teamId)) {
        return;
      }

      selectionChangedInSession.current = true;
      setSelectedTeamId(teamId);
      void preferenceStore.saveSelectedTeamId(teamId);
    },
    [followedTeams, preferenceStore],
  );

  const addFollowedTeam = useCallback((teamId: OfficialTeamId) => {
    if (followedTeams.some((team) => team.officialTeamId === teamId)) return "duplicate";
    const persistedIds = [...loadPersistedFollowedTeamIds(), teamId];
    savePersistedFollowedTeamIds(persistedIds);
    const nextTeams = loadFollowedTeams();
    if (!nextTeams.some((team) => team.officialTeamId === teamId)) return "unavailable";
    setFollowedTeams(nextTeams);
    return "added";
  }, [followedTeams]);

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
