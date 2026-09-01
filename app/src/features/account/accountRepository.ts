import type { RealtimeChannel } from "@supabase/supabase-js";
import type { Database, Json } from "../../lib/supabase/database.types";
import { requireSupabase } from "../../lib/supabase/client";
import { createUuid } from "../../lib/uuid";
import type { OfficialTeamId } from "../../data/officialSportsDatabase";
import type { NavigationSide } from "../../data/navigationSideStorage";
import type { ProfileImageShape } from "../../data/profileImageShapeStorage";
import { normalizeHomeCustomization, type HomeCustomization } from "../../data/homeCustomizationStorage";
import { normalizeThemePreference, type ThemePreference } from "../../theme/theme";
import { clearProfileMediaSignedUrls } from "../profileMedia/profileMediaSignedUrlCache";
import type { ProfileField, ProfilePersonalField, ProfileRecord, ProfileVisibility, SportExperience } from "../profile/types";

type UnknownRow = Record<string, unknown>;

export type AccountTeamState = Readonly<{
  followedTeamIds: readonly string[];
  selectedTeamId: string | null;
}>;

export type AccountSettings = Readonly<{
  navigationSide: NavigationSide;
  profileImageShape: ProfileImageShape;
  homeCustomization: HomeCustomization;
  themePreference: ThemePreference;
  selectedTeamId: string | null;
  prototypeMigrationVersion: number;
}>;

function text(row: UnknownRow | null, key: string) {
  const value = row?.[key];
  return typeof value === "string" ? value : "";
}

function optionalText(row: UnknownRow | null, key: string) {
  const value = text(row, key);
  return value || null;
}

function requireNoError(error: { message: string } | null, fallback: string) {
  if (error) throw new Error(error.message || fallback);
}

function field(fields: readonly ProfileField[], id: string) {
  return fields.find((candidate) => candidate.id === id)?.value.trim() ?? "";
}

function profileFields(profileRow: UnknownRow): readonly ProfileField[] {
  return [
    { id: "given-name", label: "Given name", value: text(profileRow, "given_name") },
    { id: "nickname", label: "Nickname", value: text(profileRow, "nickname") },
    { id: "birthplace", label: "Birthplace", value: text(profileRow, "birthplace") },
    { id: "jersey-number", label: "Jersey number", value: text(profileRow, "jersey_number") },
    { id: "height", label: "Height", value: text(profileRow, "height") },
    { id: "weight", label: "Weight", value: text(profileRow, "weight") },
  ];
}

function fanIdentityFields(identityRow: UnknownRow | null): readonly ProfileField[] {
  const additional = identityRow?.additional_identity && typeof identityRow.additional_identity === "object"
    ? identityRow.additional_identity as Record<string, unknown>
    : {};
  const additionalText = (key: string) => typeof additional[key] === "string" ? additional[key] : "";
  return [
    { id: "primary-team", label: "Primary team", value: additionalText("primary-team") },
    { id: "fan-since", label: "Fan since", value: text(identityRow, "fan_since") },
    { id: "secondary-teams", label: "Other teams", value: additionalText("secondary-teams") },
    { id: "favorite-players", label: "Favorite players", value: text(identityRow, "favorite_players") },
    { id: "game-day-ritual", label: "Game-day ritual", value: text(identityRow, "game_day_ritual") },
    { id: "superstition", label: "Fan superstition", value: text(identityRow, "superstition") },
  ];
}

function sportExperience(row: UnknownRow): SportExperience {
  return {
    id: text(row, "client_key") || text(row, "id"),
    sport: text(row, "sport"),
    position: text(row, "position"),
    level: text(row, "level"),
    years: text(row, "years"),
    highlight: text(row, "highlight"),
  };
}

function profileVisibility(row: UnknownRow | null): ProfileVisibility {
  return text(row, "visibility") === "members_visible" ? "members_visible" : "private";
}

function personalFieldVisibility(row: UnknownRow | null): Readonly<Partial<Record<ProfilePersonalField, boolean>>> {
  const value = row?.personal_field_visibility;
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const allowed = ["given_name", "nickname", "birthplace", "height", "weight", "jersey_number"] as const;
  return Object.fromEntries(allowed.filter((key) => (value as UnknownRow)[key] === true).map((key) => [key, true]));
}

function profileRecord(userId: string, profileRow: UnknownRow, identityRow: UnknownRow | null, sportsRows: readonly UnknownRow[]): ProfileRecord {
  const category = text(profileRow, "featured_fan_photo_category");
  return {
    id: userId,
    visibility: profileVisibility(profileRow),
    personalFieldVisibility: personalFieldVisibility(profileRow),
    displayName: text(profileRow, "display_name"),
    handle: text(profileRow, "handle"),
    tagline: text(profileRow, "tagline"),
    featuredFanPhotoCategory: category === "Game Face" || category === "Memorabilia" ? category : "Fan Cave",
    bio: profileFields(profileRow),
    fanIdentity: fanIdentityFields(identityRow),
    sportsPlayed: sportsRows.map(sportExperience),
  };
}

export async function loadOwnedProfile(userId: string): Promise<ProfileRecord | null> {
  const client = requireSupabase();
  const [profileResult, identityResult, sportsResult] = await Promise.all([
    client.from("profiles").select("*").eq("user_id", userId).maybeSingle(),
    client.from("fan_identities").select("*").eq("user_id", userId).maybeSingle(),
    client.from("sports_played").select("*").eq("user_id", userId).order("sort_order"),
  ]);
  requireNoError(profileResult.error, "Profile could not be loaded.");
  requireNoError(identityResult.error, "Fan identity could not be loaded.");
  requireNoError(sportsResult.error, "Sports Played could not be loaded.");
  if (!profileResult.data) return null;
  const profileRow = profileResult.data as UnknownRow;
  const identityRow = identityResult.data as UnknownRow | null;
  return profileRecord(userId, profileRow, identityRow, sportsResult.data as UnknownRow[] | null ?? []);
}

export async function saveOwnedProfile(userId: string, profile: ProfileRecord, previousVisibility?: ProfileVisibility) {
  if (profile.id !== userId) throw new Error("Profile ownership does not match the authenticated account.");
  const client = requireSupabase();
  const result = await client.rpc("save_my_profile", {
    profile_data: {
      display_name: profile.displayName.trim(),
      visibility: profile.visibility,
      personal_field_visibility: profile.personalFieldVisibility ?? {},
      handle: profile.handle.trim(),
      given_name: field(profile.bio, "given-name"),
      nickname: field(profile.bio, "nickname"),
      tagline: profile.tagline.trim(),
      birthplace: field(profile.bio, "birthplace"),
      jersey_number: field(profile.bio, "jersey-number"),
      height: field(profile.bio, "height"),
      weight: field(profile.bio, "weight"),
      featured_fan_photo_category: profile.featuredFanPhotoCategory,
    },
    identity_data: {
      fan_since: field(profile.fanIdentity, "fan-since"),
      favorite_players: field(profile.fanIdentity, "favorite-players"),
      game_day_ritual: field(profile.fanIdentity, "game-day-ritual"),
      superstition: field(profile.fanIdentity, "superstition"),
      additional_identity: {
        "primary-team": field(profile.fanIdentity, "primary-team"),
        "secondary-teams": field(profile.fanIdentity, "secondary-teams"),
      },
    },
    sports_data: profile.sportsPlayed.map((sport) => ({
      client_key: sport.id,
      sport: sport.sport.trim(),
      position: sport.position.trim(),
      level: sport.level.trim(),
      years: sport.years.trim(),
      highlight: sport.highlight.trim(),
    })),
  });
  requireNoError(result.error, "Profile could not be saved.");
  if (previousVisibility !== undefined && previousVisibility !== profile.visibility) clearProfileMediaSignedUrls(userId);
}

export async function loadAccountSettings(userId: string): Promise<AccountSettings> {
  const result = await requireSupabase().from("user_settings").select("navigation_side, selected_team_id, preferences, prototype_migration_version").eq("user_id", userId).maybeSingle();
  requireNoError(result.error, "Personal settings could not be loaded.");
  const row = result.data as UnknownRow | null;
  const preferences = row?.preferences && typeof row.preferences === "object" && !Array.isArray(row.preferences)
    ? row.preferences as UnknownRow
    : {};
  return {
    navigationSide: text(row, "navigation_side") === "right" ? "right" : "left",
    profileImageShape: text(preferences, "profileImageShape") === "square" ? "square" : "circle",
    homeCustomization: normalizeHomeCustomization(preferences.homeCustomization),
    themePreference: normalizeThemePreference(preferences.themePreference),
    selectedTeamId: optionalText(row, "selected_team_id"),
    prototypeMigrationVersion: typeof row?.prototype_migration_version === "number" ? row.prototype_migration_version : 0,
  };
}

export async function saveAccountSettings(userId: string, values: Partial<{ navigationSide: NavigationSide; profileImageShape: ProfileImageShape; homeCustomization: HomeCustomization; themePreference: ThemePreference; selectedTeamId: OfficialTeamId | null; prototypeMigrationVersion: number }>) {
  const client = requireSupabase();
  const row: Database["public"]["Tables"]["user_settings"]["Insert"] = { user_id: userId };
  if (values.navigationSide !== undefined) row.navigation_side = values.navigationSide;
  if (values.selectedTeamId !== undefined) row.selected_team_id = values.selectedTeamId;
  if (values.prototypeMigrationVersion !== undefined) row.prototype_migration_version = values.prototypeMigrationVersion;
  if (values.profileImageShape !== undefined || values.homeCustomization !== undefined || values.themePreference !== undefined) {
    const current = await client.from("user_settings").select("preferences").eq("user_id", userId).maybeSingle();
    requireNoError(current.error, "Personal settings could not be loaded.");
    const currentRow = current.data as UnknownRow | null;
    const preferences = currentRow?.preferences && typeof currentRow.preferences === "object" && !Array.isArray(currentRow.preferences)
      ? currentRow.preferences as UnknownRow
      : {};
    row.preferences = {
      ...preferences,
      ...(values.profileImageShape !== undefined ? { profileImageShape: values.profileImageShape } : {}),
      ...(values.homeCustomization !== undefined ? { homeCustomization: normalizeHomeCustomization(values.homeCustomization) } : {}),
      ...(values.themePreference !== undefined ? { themePreference: normalizeThemePreference(values.themePreference) } : {}),
    } as Json;
  }
  const result = await client.from("user_settings").upsert(row, { onConflict: "user_id" });
  requireNoError(result.error, "Personal settings could not be saved.");
}

export async function loadAccountTeamState(userId: string): Promise<AccountTeamState> {
  const [teams, settings] = await Promise.all([
    requireSupabase().from("user_followed_teams").select("team_id").eq("user_id", userId).order("sort_order"),
    loadAccountSettings(userId),
  ]);
  requireNoError(teams.error, "Followed teams could not be loaded.");
  return {
    followedTeamIds: (teams.data as UnknownRow[] | null ?? []).map((row) => text(row, "team_id")).filter(Boolean),
    selectedTeamId: settings.selectedTeamId,
  };
}

export async function replaceAccountFollowedTeams(userId: string, teamIds: readonly OfficialTeamId[]) {
  if (!userId) throw new Error("Authentication is required to update followed teams.");
  const uniqueIds = [...new Set(teamIds)];
  const result = await requireSupabase().rpc("replace_my_followed_teams", { team_ids: uniqueIds });
  requireNoError(result.error, "Followed teams could not be updated.");
}

export async function addAccountFollowedTeam(userId: string, teamId: OfficialTeamId, sortOrder: number) {
  const result = await requireSupabase().from("user_followed_teams").insert({ user_id: userId, team_id: teamId, sort_order: sortOrder });
  if (result.error?.code === "23505") return "duplicate" as const;
  requireNoError(result.error, "The team could not be followed.");
  return "added" as const;
}

const synchronizedTables = ["profiles", "fan_identities", "sports_played", "user_followed_teams", "user_settings", "profile_visuals", "profile_photos", "profile_visual_images"] as const;
export type AccountTable = (typeof synchronizedTables)[number];

export function subscribeToAccountChanges(userId: string, callback: () => void, tables: readonly AccountTable[] = synchronizedTables): () => void {
  const client = requireSupabase();
  let channel: RealtimeChannel = client.channel(`account:${userId}:${tables.join("-")}:${createUuid()}`);
  for (const table of tables) {
    channel = channel.on("postgres_changes", { event: "*", schema: "public", table, filter: `user_id=eq.${userId}` }, callback);
  }
  void channel.subscribe();
  return () => { void client.removeChannel(channel); };
}
