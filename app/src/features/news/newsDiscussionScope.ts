import { findFollowedTeam } from "../../data/followedTeams";
import type { TeamId } from "../../domain/team";
import type { NewsDiscussionScope, NewsItem } from "./types";

/** Canonical ownership comes from the News Item, never the viewer's current FANbase. */
export function newsItemDiscussionScope(item: NewsItem): NewsDiscussionScope {
  if (item.discussionScope) return item.discussionScope;
  if (item.teamIds.length === 1) return { kind: "team", teamId: item.teamIds[0]! };
  return { kind: "league", leagueId: item.league };
}

export function newsDiscussionScopeMatchesTeam(scope: NewsDiscussionScope, teamId: TeamId) {
  if (scope.kind === "team") return scope.teamId === teamId;
  const team = findFollowedTeam(teamId);
  if (!team) return false;
  return scope.kind === "league"
    ? team.league.toLocaleLowerCase() === scope.leagueId
    : team.sport.toLocaleLowerCase() === scope.sportId;
}
