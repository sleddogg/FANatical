import { officialLeagues, officialSports, officialTeams, type TeamColors } from "./officialSportsDatabase";
import { isSupabaseConfigured, requireSupabase } from "../lib/supabase/client";

type UnknownRow = Record<string, unknown>;

export type CatalogDataStatus = "imported_unverified" | "verified" | null;

export type CatalogSport = Readonly<{
  id: string;
  displayName: string;
  active: boolean;
}>;

export type CatalogLeague = Readonly<{
  id: string;
  displayName: string;
  shortName: string | null;
  parentSportId: string;
  active: boolean;
  dataStatus: CatalogDataStatus;
}>;

export type CatalogTeam = Readonly<{
  canonicalTeamId: string | null;
  legacyFrontendTeamId: string | null;
  displayName: string;
  shortName: string;
  abbreviation: string | null;
  parentSportId: string;
  parentLeagueId: string;
  colors: TeamColors;
  identityStatus: CatalogDataStatus;
  leagueStatus: CatalogDataStatus;
  catalogReady: boolean;
  liveCheerReady: boolean;
}>;

export type TeamCatalogSnapshot = Readonly<{
  source: "backend" | "compatibility-fallback";
  sports: readonly CatalogSport[];
  leagues: readonly CatalogLeague[];
  teams: readonly CatalogTeam[];
  fallbackReason: string | null;
}>;

function text(row: UnknownRow, key: string) {
  return typeof row[key] === "string" ? row[key] as string : "";
}

function optionalText(row: UnknownRow, key: string) {
  return text(row, key) || null;
}

function boolean(row: UnknownRow, key: string) {
  return row[key] === true;
}

function dataStatus(row: UnknownRow, key: string): CatalogDataStatus {
  const value = row[key];
  return value === "verified" || value === "imported_unverified" ? value : null;
}

function externalIdentifiers(row: UnknownRow): readonly UnknownRow[] {
  const value = row.external_identifiers;
  return Array.isArray(value) ? value.filter((item): item is UnknownRow => Boolean(item) && typeof item === "object") : [];
}

function colors(row: UnknownRow): TeamColors {
  const primary = optionalText(row, "primary_color");
  const secondary = optionalText(row, "secondary_color");
  if (!primary || !secondary) {
    return { primary: null, secondary: null, tertiary: null, quaternary: null, quinary: null };
  }
  return {
    primary,
    secondary,
    tertiary: optionalText(row, "tertiary_color"),
    quaternary: optionalText(row, "quaternary_color"),
    quinary: optionalText(row, "quinary_color"),
  };
}

function compatibilitySnapshot(reason: string | null): TeamCatalogSnapshot {
  const sports: readonly CatalogSport[] = officialSports
    .filter((sport) => sport.id !== "generic" && sport.id !== "other")
    .map((sport) => ({ id: sport.id, displayName: sport.displayName, active: true }));
  const leagues: readonly CatalogLeague[] = officialLeagues.map((league) => ({
    id: league.id,
    displayName: league.displayName,
    shortName: league.displayName,
    parentSportId: league.parentSportId,
    active: true,
    dataStatus: null,
  }));
  const teams: readonly CatalogTeam[] = officialTeams.map((team) => {
    const league = officialLeagues.find((candidate) => candidate.id === team.parentLeagueId);
    return {
      canonicalTeamId: null,
      legacyFrontendTeamId: team.id,
      displayName: team.displayName,
      shortName: team.displayName,
      abbreviation: null,
      parentSportId: league?.parentSportId ?? "other",
      parentLeagueId: team.parentLeagueId,
      colors: team.colors,
      identityStatus: null,
      leagueStatus: null,
      catalogReady: false,
      liveCheerReady: false,
    };
  });
  return { source: "compatibility-fallback", sports, leagues, teams, fallbackReason: reason };
}

export function teamCatalogSnapshotFromRows(
  sportRows: readonly UnknownRow[],
  leagueRows: readonly UnknownRow[],
  teamRows: readonly UnknownRow[],
  readinessRows: readonly UnknownRow[],
): TeamCatalogSnapshot {
  const readinessByTeamId = new Map(readinessRows.map((row) => [text(row, "team_id"), row]));
  const sports = sportRows.map((row): CatalogSport => ({
    id: text(row, "sport_id"),
    displayName: text(row, "display_name"),
    active: boolean(row, "active"),
  }));
  const leagues = leagueRows.map((row): CatalogLeague => ({
    id: text(row, "league_id"),
    displayName: text(row, "display_name"),
    shortName: optionalText(row, "short_name"),
    parentSportId: text(row, "sport_id"),
    active: boolean(row, "active"),
    dataStatus: dataStatus(row, "seed_status"),
  }));
  const teams = teamRows.flatMap((row): readonly CatalogTeam[] => {
    const canonicalTeamId = text(row, "team_id");
    const parentLeagueId = text(row, "primary_league_id");
    const displayName = text(row, "display_name");
    if (!canonicalTeamId || !parentLeagueId || !displayName) return [];
    const legacyFrontendTeamId = externalIdentifiers(row)
      .find((identifier) => text(identifier, "namespace") === "legacy_frontend_id");
    const readiness = readinessByTeamId.get(canonicalTeamId) ?? {};
    return [{
      canonicalTeamId,
      legacyFrontendTeamId: legacyFrontendTeamId ? optionalText(legacyFrontendTeamId, "identifier") : null,
      displayName,
      shortName: text(row, "short_name") || displayName,
      abbreviation: optionalText(row, "abbreviation"),
      parentSportId: text(row, "sport_id"),
      parentLeagueId,
      colors: colors(row),
      identityStatus: dataStatus(row, "identity_status"),
      leagueStatus: dataStatus(row, "primary_league_status"),
      catalogReady: boolean(readiness, "catalog_ready"),
      liveCheerReady: boolean(readiness, "live_cheer_ready"),
    }];
  });
  return { source: "backend", sports, leagues, teams, fallbackReason: null };
}

export async function loadTeamCatalog(): Promise<TeamCatalogSnapshot> {
  if (!isSupabaseConfigured) return compatibilitySnapshot("Supabase is not configured.");
  try {
    const client = requireSupabase();
    const [sports, leagues, teams, readiness] = await Promise.all([
      client.from("catalog_sports").select("sport_id, display_name, active").order("display_name"),
      client.from("catalog_leagues").select("league_id, display_name, short_name, active, seed_status, catalog_sports!inner(sport_id)").order("display_name"),
      client.from("team_catalog_read_model").select("*").order("display_name"),
      client.from("team_readiness").select("team_id, catalog_ready, live_cheer_ready"),
    ]);
    const firstError = sports.error ?? leagues.error ?? teams.error ?? readiness.error;
    if (firstError) throw new Error(firstError.message);
    const leagueRows = (leagues.data as UnknownRow[] | null ?? []).map((row) => {
      const joinedSport = row.catalog_sports;
      const sportRow = joinedSport && typeof joinedSport === "object" && !Array.isArray(joinedSport) ? joinedSport as UnknownRow : {};
      return { ...row, sport_id: text(sportRow, "sport_id") };
    });
    return teamCatalogSnapshotFromRows(
      sports.data as UnknownRow[] | null ?? [],
      leagueRows,
      teams.data as UnknownRow[] | null ?? [],
      readiness.data as UnknownRow[] | null ?? [],
    );
  } catch (error) {
    const reason = error instanceof Error ? error.message : "The canonical team catalog could not be loaded.";
    return compatibilitySnapshot(reason);
  }
}

export function findCatalogTeam(snapshot: TeamCatalogSnapshot, identifier: string | null | undefined) {
  if (!identifier) return null;
  return snapshot.teams.find((team) => team.canonicalTeamId === identifier || team.legacyFrontendTeamId === identifier) ?? null;
}

