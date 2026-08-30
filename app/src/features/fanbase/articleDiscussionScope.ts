import { findFollowedTeam } from "../../data/followedTeams";
import type { TeamId } from "../../domain/team";
import type {
  ArticleDiscussionItem,
  ArticleDiscussionScope,
} from "./articleDiscussionTypes";

/** Canonical ownership comes from the Article Discussion fixture, not the viewer's current FANbase. */
export function articleDiscussionScopeForItem(
  item: ArticleDiscussionItem,
): ArticleDiscussionScope {
  if (item.discussionScope) return item.discussionScope;
  if (item.teamIds.length === 1) return { kind: "team", teamId: item.teamIds[0]! };
  return { kind: "league", leagueId: item.league };
}

export function articleDiscussionScopeMatchesTeam(
  scope: ArticleDiscussionScope,
  teamId: TeamId,
) {
  if (scope.kind === "team") return scope.teamId === teamId;
  const team = findFollowedTeam(teamId);
  if (!team) return false;
  return scope.kind === "league"
    ? team.league.toLocaleLowerCase() === scope.leagueId
    : team.sport.toLocaleLowerCase() === scope.sportId;
}
