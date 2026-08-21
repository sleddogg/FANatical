import { defaultThemePreference, normalizeThemePreference, type ThemePreference } from "../theme/theme";

export const themePreferenceStorageKey = "fanatical.theme-preference.v1";
export const themePreferenceChangeEvent = "fanatical:theme-preference-change";

export function loadThemePreference(): ThemePreference {
  if (typeof window === "undefined") return defaultThemePreference;
  try {
    return normalizeThemePreference(JSON.parse(window.localStorage.getItem(themePreferenceStorageKey) ?? "null"));
  } catch {
    return defaultThemePreference;
  }
}

export function saveThemePreference(value: ThemePreference) {
  const normalized = normalizeThemePreference(value);
  window.localStorage.setItem(themePreferenceStorageKey, JSON.stringify(normalized));
  window.dispatchEvent(new CustomEvent<ThemePreference>(themePreferenceChangeEvent, { detail: normalized }));
}
