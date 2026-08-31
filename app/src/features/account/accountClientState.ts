import { followedTeamsStorageKey } from "../../data/followedTeams";
import { homeCustomizationStorageKey } from "../../data/homeCustomizationStorage";
import { navigationSideStorageKey } from "../../data/navigationSideStorage";
import { profileImageShapeStorageKey } from "../../data/profileImageShapeStorage";
import { selectedTeamStorageKey } from "../../data/selectedTeamPreference";
import { themePreferenceStorageKey } from "../../data/themePreferenceStorage";
import { clearNewsDemoState } from "../news/newsDemoState";
import { clearProfileMediaSignedUrls } from "../profileMedia/profileMediaSignedUrlCache";
import { clearProfileVisualStorage } from "../profileVisual/profileVisualStorage";

export const accountClientStateClearedEvent = "fanatical:account-client-state-cleared";
export const profileFeaturedCategorySessionKey = "fanatical.profile.featuredFanPhotoCategory";

export const accountDerivedLocalStorageKeys = Object.freeze([
  followedTeamsStorageKey,
  selectedTeamStorageKey,
  homeCustomizationStorageKey,
  themePreferenceStorageKey,
  navigationSideStorageKey,
  profileImageShapeStorageKey,
]);

export const accountDerivedSessionStorageKeys = Object.freeze([
  profileFeaturedCategorySessionKey,
]);

function removeKeys(storage: Storage, keys: readonly string[]) {
  for (const key of keys) {
    try {
      storage.removeItem(key);
    } catch {
      // Continue clearing memory and every other available browser store.
    }
  }
}

/**
 * The single browser-side boundary for an account identity transition.
 * Durable Supabase records are deliberately untouched; only unowned browser
 * presentation state and memory caches are removed.
 */
export async function clearAccountDerivedClientState() {
  if (typeof window === "undefined") return;

  try {
    removeKeys(window.localStorage, accountDerivedLocalStorageKeys);
  } catch {
    // Some hardened browsers deny access to the Storage object itself.
  }
  try {
    removeKeys(window.sessionStorage, accountDerivedSessionStorageKeys);
  } catch {
    // Memory cleanup and neutral rendering must still proceed.
  }
  clearNewsDemoState();
  clearProfileMediaSignedUrls();
  window.dispatchEvent(new Event(accountClientStateClearedEvent));

  try {
    await clearProfileVisualStorage();
  } catch (error) {
    console.warn("FANatical could not clear legacy browser Profile visuals during an account transition.", error);
  }
}
