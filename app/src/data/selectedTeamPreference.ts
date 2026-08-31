import type { TeamId } from "../domain/team";
import { isFollowedTeamId } from "./followedTeams";

export interface SelectedTeamPreferenceStore {
  loadSelectedTeamId(): Promise<TeamId | null>;
  saveSelectedTeamId(teamId: TeamId): Promise<void>;
}

export const selectedTeamStorageKey = "fanatical.selected-team-id";

export const localSelectedTeamPreferenceStore: SelectedTeamPreferenceStore = {
  async loadSelectedTeamId() {
    try {
      const storedTeamId = window.localStorage.getItem(selectedTeamStorageKey);
      return isFollowedTeamId(storedTeamId) ? storedTeamId : null;
    } catch {
      return null;
    }
  },

  async saveSelectedTeamId(teamId) {
    try {
      window.localStorage.setItem(selectedTeamStorageKey, teamId);
    } catch {
      // The shared in-memory state remains usable when browser storage is unavailable.
    }
  },
};
