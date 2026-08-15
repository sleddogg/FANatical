import { findOfficialLeague, findOfficialSportById, findOfficialSportByName, findOfficialTeam, leaguesForSport, officialTeams, type OfficialLeagueId, type OfficialSportId, type OfficialTeamId } from "../../data/officialSportsDatabase";
import { checkInSupportsAudienceZones } from "./cheerAudienceEligibility";
import { audienceMatchesCheckIn } from "./cheerUtils";
import type { CheerCheckIn, CheerRecord, MappedVenueCheckIn } from "./types";

export type CheerLibraryFilter =
  | Readonly<{ kind: "available" }>
  | Readonly<{ kind: "all" }>
  | Readonly<{ kind: "bookmarks" }>
  | Readonly<{ kind: "mine" }>
  | Readonly<{ kind: "sport"; sportId: OfficialSportId }>
  | Readonly<{ kind: "league"; leagueId: OfficialLeagueId }>
  | Readonly<{ kind: "team"; teamId: OfficialTeamId }>;

export const allCheersFilter: CheerLibraryFilter = { kind: "all" };
export const availableNowFilter: CheerLibraryFilter = { kind: "available" };

export function hasLiveTeamGameContext(checkIn: CheerCheckIn | null): checkIn is MappedVenueCheckIn {
  return checkIn?.type === "MappedVenue" && Boolean(checkIn.raw.teamEvent.trim());
}

function resolveCheckInTeam(checkIn: MappedVenueCheckIn) {
  const sport = findOfficialSportByName(checkIn.raw.sport);
  if (!sport) return null;
  const leagueIds = new Set(leaguesForSport(sport.id).map((league) => league.id));
  const normalizedEvent = checkIn.raw.teamEvent.trim().toLocaleLowerCase();
  return officialTeams.find((team) => leagueIds.has(team.parentLeagueId) && team.displayName.toLocaleLowerCase() === normalizedEvent)
    ?? officialTeams.find((team) => leagueIds.has(team.parentLeagueId) && normalizedEvent.includes(team.displayName.toLocaleLowerCase()))
    ?? null;
}

export function isCheerLaunchEligible(cheer: CheerRecord, checkIn: CheerCheckIn | null) {
  if (!hasLiveTeamGameContext(checkIn) || cheer.publicationStatus !== "Published") return false;
  const sport = findOfficialSportByName(checkIn.raw.sport);
  if (!sport || cheer.sportId !== sport.id) return false;

  const team = resolveCheckInTeam(checkIn);
  const league = team ? findOfficialLeague(team.parentLeagueId) : null;
  if (cheer.teamId && cheer.teamId !== team?.id) return false;
  if (!cheer.teamId && cheer.leagueId && cheer.leagueId !== league?.id) return false;
  if (cheer.opponent.trim() && !checkIn.raw.teamEvent.toLocaleLowerCase().includes(cheer.opponent.trim().toLocaleLowerCase())) return false;
  if (!checkInSupportsAudienceZones(cheer, checkIn)) return false;

  const routedSegments = cheer.measures.flatMap((measure) => [...measure.actionSegments, ...measure.lyricSegments, ...measure.restSegments]);
  return routedSegments.some((segment) => audienceMatchesCheckIn(segment.audience, checkIn));
}

export function filterCheers(cheers: readonly CheerRecord[], filter: CheerLibraryFilter, checkIn: CheerCheckIn | null, currentCreator: CheerRecord["createdBy"]) {
  return cheers.filter((cheer) => {
    switch (filter.kind) {
      case "available": return isCheerLaunchEligible(cheer, checkIn);
      case "all": return true;
      case "bookmarks": return cheer.bookmarked;
      case "mine": return cheer.createdBy === currentCreator;
      case "sport": return cheer.sportId === filter.sportId && cheer.leagueId === null && cheer.teamId === null;
      case "league": return cheer.leagueId === filter.leagueId && cheer.teamId === null;
      case "team": return cheer.teamId === filter.teamId;
    }
  });
}

export function cheerLibraryFilterLabel(filter: CheerLibraryFilter) {
  switch (filter.kind) {
    case "available": return "Available Now";
    case "all": return "All Cheers";
    case "bookmarks": return "Bookmarks";
    case "mine": return "My Cheers";
    case "sport": return findOfficialSportById(filter.sportId)?.displayName ?? "Sport";
    case "league": return findOfficialLeague(filter.leagueId)?.displayName ?? "League";
    case "team": return findOfficialTeam(filter.teamId)?.displayName ?? "Team";
  }
}
