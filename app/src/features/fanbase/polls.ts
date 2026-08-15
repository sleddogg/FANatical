import {
  findOfficialLeague,
  findOfficialSportById,
  findOfficialSportByName,
  findOfficialTeam,
  officialTeams,
} from "../../data/officialSportsDatabase";
import type { FollowedTeam } from "../../domain/team";
import type { FanPoll, PollScope } from "./types";

const pollTopicStopWords = new Set([
  "about", "after", "again", "against", "and", "are", "could", "does", "for", "from", "have", "how", "into", "most", "should", "that", "the", "their", "these", "they", "this", "what", "when", "where", "which", "who", "why", "will", "with", "would", "you", "your",
]);

export function pollScopeKey(scope: PollScope) {
  if (scope.kind === "team") return `team:${scope.teamId}`;
  if (scope.kind === "league") return `league:${scope.leagueId}`;
  return `sport:${scope.sportId}`;
}

export function pollScopeEquals(first: PollScope, second: PollScope) {
  return pollScopeKey(first) === pollScopeKey(second);
}

export function pollScopeLabel(scope: PollScope) {
  if (scope.kind === "team") return findOfficialTeam(scope.teamId)?.displayName ?? "Team polls";
  if (scope.kind === "league") return findOfficialLeague(scope.leagueId)?.displayName ?? "League polls";
  return findOfficialSportById(scope.sportId)?.displayName ?? "Sport polls";
}

export function pollScopeForFollowedTeam(team: FollowedTeam): PollScope {
  const officialTeam = officialTeams.find((candidate) => candidate.displayName === team.name);
  const league = officialTeam ? findOfficialLeague(officialTeam.parentLeagueId) : null;
  if (officialTeam && league) {
    return { kind: "team", sportId: league.parentSportId, leagueId: league.id, teamId: officialTeam.id };
  }
  const sport = findOfficialSportByName(team.sport) ?? findOfficialSportById("other")!;
  return { kind: "sport", sportId: sport.id, leagueId: null, teamId: null };
}

export function pollsForScope(polls: readonly FanPoll[], scope: PollScope) {
  const key = pollScopeKey(scope);
  return polls.filter((poll) => pollScopeKey(poll.scope) === key);
}

export function pollTotalVotes(poll: FanPoll) {
  return poll.options.reduce((total, option) => total + option.voteCount, 0);
}

export function pollTrendingScore(poll: FanPoll, now = Date.now()) {
  const ageHours = Math.max(0, (now - Date.parse(poll.createdAt)) / 3_600_000);
  const recency = Math.max(0, 1 - ageHours / (14 * 24));
  const velocity = Math.min(1, Math.max(0, poll.recentVotesPerHour) / 30);
  return velocity * 0.7 + recency * 0.3;
}

export function activePollsForScope(polls: readonly FanPoll[], scope: PollScope, now = Date.now(), limit = 10) {
  return pollsForScope(polls, scope)
    .filter((poll) => poll.viewerOptionId === null)
    .filter((poll) => {
      const ageHours = Math.max(0, (now - Date.parse(poll.createdAt)) / 3_600_000);
      return ageHours <= 14 * 24 || poll.recentVotesPerHour >= 2;
    })
    .sort((first, second) => pollTrendingScore(second, now) - pollTrendingScore(first, now))
    .slice(0, limit);
}

export function generatePollTopics(question: string, options: readonly string[]) {
  const words = `${question} ${options.join(" ")}`
    .toLocaleLowerCase()
    .match(/[a-z0-9]+(?:'[a-z0-9]+)?/g) ?? [];
  return [...new Set(words.filter((word) => word.length >= 3 && !pollTopicStopWords.has(word)))].slice(0, 10);
}

export function searchPolls(polls: readonly FanPoll[], query: string) {
  const terms = generatePollTopics(query, []);
  if (!terms.length) return [];
  return polls
    .filter((poll) => {
      const searchable = `${poll.question} ${poll.options.map((option) => option.label).join(" ")} ${poll.topics.join(" ")}`.toLocaleLowerCase();
      return terms.every((term) => searchable.includes(term));
    })
    .sort((first, second) => Date.parse(second.createdAt) - Date.parse(first.createdAt));
}
