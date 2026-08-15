import { isValidOfficialSelection } from "../../data/officialSportsDatabase";
import type { FanPoll, PollScope } from "./types";

const pollStorageKey = "fanatical.fanbase.polls.v1";

function isPollScope(value: unknown): value is PollScope {
  if (!value || typeof value !== "object") return false;
  const scope = value as Partial<PollScope>;
  if (scope.kind !== "sport" && scope.kind !== "league" && scope.kind !== "team") return false;
  if (typeof scope.sportId !== "string") return false;
  const leagueId = typeof scope.leagueId === "string" ? scope.leagueId : null;
  const teamId = typeof scope.teamId === "string" ? scope.teamId : null;
  if (!isValidOfficialSelection(scope.sportId, leagueId, teamId)) return false;
  return scope.kind === "sport" ? leagueId === null && teamId === null : scope.kind === "league" ? leagueId !== null && teamId === null : leagueId !== null && teamId !== null;
}

function isFanPoll(value: unknown): value is FanPoll {
  if (!value || typeof value !== "object") return false;
  const poll = value as Partial<FanPoll>;
  return typeof poll.id === "string"
    && typeof poll.question === "string"
    && isPollScope(poll.scope)
    && Array.isArray(poll.options)
    && poll.options.length >= 2
    && poll.options.every((option) => option && typeof option.id === "string" && typeof option.label === "string" && typeof option.voteCount === "number")
    && Array.isArray(poll.topics)
    && poll.topics.every((topic) => typeof topic === "string")
    && typeof poll.createdAt === "string"
    && typeof poll.recentVotesPerHour === "number"
    && (poll.viewerOptionId === null || typeof poll.viewerOptionId === "string");
}

export function loadPolls(seedPolls: readonly FanPoll[]) {
  try {
    const parsed: unknown = JSON.parse(window.localStorage.getItem(pollStorageKey) ?? "null");
    if (!Array.isArray(parsed)) return [...seedPolls];
    const stored = parsed.filter(isFanPoll);
    return [...stored, ...seedPolls.filter((seed) => !stored.some((poll) => poll.id === seed.id))];
  } catch {
    return [...seedPolls];
  }
}

export function savePolls(polls: readonly FanPoll[]) {
  try {
    window.localStorage.setItem(pollStorageKey, JSON.stringify(polls));
  } catch {
    // Keep the in-memory Poll experience functional when browser storage is unavailable.
  }
}

