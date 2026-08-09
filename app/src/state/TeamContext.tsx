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
  findFollowedTeam,
  followedTeams,
} from "../data/followedTeams";
import {
  localSelectedTeamPreferenceStore,
  type SelectedTeamPreferenceStore,
} from "../data/selectedTeamPreference";
import type { FollowedTeam, TeamId } from "../domain/team";

type TeamContextValue = Readonly<{
  followedTeams: readonly FollowedTeam[];
  selectedTeam: FollowedTeam;
  selectedTeamId: TeamId;
  selectTeam: (teamId: TeamId) => void;
}>;

type TeamProviderProps = PropsWithChildren<{
  readonly preferenceStore?: SelectedTeamPreferenceStore;
}>;

const TeamContext = createContext<TeamContextValue | undefined>(undefined);

function requireFollowedTeam(teamId: TeamId): FollowedTeam {
  const team = findFollowedTeam(teamId);

  if (!team) {
    throw new Error(`Followed team ${teamId} does not exist in the team catalog.`);
  }

  return team;
}

const defaultSelectedTeam = requireFollowedTeam(defaultSelectedTeamId);

export function TeamProvider({
  children,
  preferenceStore = localSelectedTeamPreferenceStore,
}: TeamProviderProps) {
  const [selectedTeamId, setSelectedTeamId] = useState<TeamId>(defaultSelectedTeamId);
  const selectionChangedInSession = useRef(false);

  useEffect(() => {
    let isCurrent = true;

    void preferenceStore.loadSelectedTeamId().then((storedTeamId) => {
      if (isCurrent && !selectionChangedInSession.current && storedTeamId && findFollowedTeam(storedTeamId)) {
        setSelectedTeamId(storedTeamId);
      }
    });

    return () => {
      isCurrent = false;
    };
  }, [preferenceStore]);

  const selectTeam = useCallback(
    (teamId: TeamId) => {
      if (!findFollowedTeam(teamId)) {
        return;
      }

      selectionChangedInSession.current = true;
      setSelectedTeamId(teamId);
      void preferenceStore.saveSelectedTeamId(teamId);
    },
    [preferenceStore],
  );

  const selectedTeam = findFollowedTeam(selectedTeamId) ?? defaultSelectedTeam;
  const value = useMemo<TeamContextValue>(
    () => ({ followedTeams, selectedTeam, selectedTeamId, selectTeam }),
    [selectTeam, selectedTeam, selectedTeamId],
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
