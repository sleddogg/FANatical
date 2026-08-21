import type { CSSProperties } from "react";
import type { TeamColors } from "../data/officialSportsDatabase";

export const themeSources = ["none", "favorite-team", "current-team", "custom"] as const;
export const themeOrders = ["normal", "swapped"] as const;
export const themeStrengths = [15, 40, 80, 100] as const;

export type ThemeSource = (typeof themeSources)[number];
export type ThemeOrder = (typeof themeOrders)[number];
export type ThemeStrength = (typeof themeStrengths)[number];

export type ThemePreference = Readonly<{
  source: ThemeSource;
  order: ThemeOrder;
  customColor1: string;
  customColor2: string;
}>;

export type ThemeColorScale = Readonly<Record<ThemeStrength, string>>;
export type ThemeForegroundScale = Readonly<Record<ThemeStrength, string>>;

export type ResolvedTheme = Readonly<{
  source: ThemeSource;
  order: ThemeOrder;
  active: boolean;
  sourceLabel: string;
  color1: string;
  color2: string;
  color1Scale: ThemeColorScale;
  color2Scale: ThemeColorScale;
  color1Foreground: ThemeForegroundScale;
  color2Foreground: ThemeForegroundScale;
  unavailableReason: string | null;
}>;

export type ThemeCssProperties = CSSProperties & Record<`--theme-${string}`, string>;

export const defaultThemePreference: ThemePreference = {
  source: "none",
  order: "normal",
  customColor1: "#00205B",
  customColor2: "#D14520",
};

const neutralColor1 = "#111111";
const neutralColor2 = "#686865";
const lightForeground = "#FFFFFF";
const darkForeground = "#111111";
const lighterTarget = 0.80;

type DerivedThemeStrength = Exclude<ThemeStrength, 100>;

const strengthDerivation = {
  15: { lightnessProgress: 0.32, chromaRetention: 0.78 },
  40: { lightnessProgress: 0.16, chromaRetention: 0.88 },
  80: { lightnessProgress: 0.05, chromaRetention: 0.95 },
} as const satisfies Readonly<Record<DerivedThemeStrength, Readonly<{ lightnessProgress: number; chromaRetention: number }>>>;

// In OKLCH: L' = L + max(0, target - L) * progress, C' = C * retention, h' = h.

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

export function isHexColor(value: unknown): value is string {
  return typeof value === "string" && /^#[0-9A-Fa-f]{6}$/.test(value);
}

export function normalizeHexColor(value: unknown, fallback: string): string {
  return isHexColor(value) ? value.toUpperCase() : fallback;
}

export function normalizeThemePreference(value: unknown): ThemePreference {
  const record = isRecord(value) ? value : {};
  const source = typeof record.source === "string" && themeSources.includes(record.source as ThemeSource)
    ? record.source as ThemeSource
    : defaultThemePreference.source;
  return {
    source,
    order: record.order === "swapped" ? "swapped" : "normal",
    customColor1: normalizeHexColor(record.customColor1, defaultThemePreference.customColor1),
    customColor2: normalizeHexColor(record.customColor2, defaultThemePreference.customColor2),
  };
}

function hexChannels(hex: string): readonly [number, number, number] {
  return [
    Number.parseInt(hex.slice(1, 3), 16),
    Number.parseInt(hex.slice(3, 5), 16),
    Number.parseInt(hex.slice(5, 7), 16),
  ];
}

function channelsHex(channels: readonly [number, number, number]): string {
  return `#${channels.map((channel) => Math.round(Math.min(255, Math.max(0, channel))).toString(16).padStart(2, "0")).join("")}`.toUpperCase();
}

function srgbToLinear(channel: number): number {
  const normalized = channel / 255;
  return normalized <= 0.04045 ? normalized / 12.92 : ((normalized + 0.055) / 1.055) ** 2.4;
}

function linearToSrgb(channel: number): number {
  const normalized = channel <= 0.0031308 ? 12.92 * channel : 1.055 * channel ** (1 / 2.4) - 0.055;
  return normalized * 255;
}

type Oklch = Readonly<{ lightness: number; chroma: number; hue: number }>;
type LinearRgb = readonly [number, number, number];

function hexToOklch(hex: string): Oklch {
  const [red, green, blue] = hexChannels(hex).map(srgbToLinear) as [number, number, number];
  const long = Math.cbrt(0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue);
  const medium = Math.cbrt(0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue);
  const short = Math.cbrt(0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue);
  const lightness = 0.2104542553 * long + 0.793617785 * medium - 0.0040720468 * short;
  const a = 1.9779984951 * long - 2.428592205 * medium + 0.4505937099 * short;
  const b = 0.0259040371 * long + 0.7827717662 * medium - 0.808675766 * short;
  return { lightness, chroma: Math.hypot(a, b), hue: Math.atan2(b, a) };
}

function oklchToLinearRgb({ lightness, chroma, hue }: Oklch): LinearRgb {
  const a = chroma * Math.cos(hue);
  const b = chroma * Math.sin(hue);
  const longRoot = lightness + 0.3963377774 * a + 0.2158037573 * b;
  const mediumRoot = lightness - 0.1055613458 * a - 0.0638541728 * b;
  const shortRoot = lightness - 0.0894841775 * a - 1.291485548 * b;
  const long = longRoot ** 3;
  const medium = mediumRoot ** 3;
  const short = shortRoot ** 3;
  return [
    4.0767416621 * long - 3.3077115913 * medium + 0.2309699292 * short,
    -1.2684380046 * long + 2.6097574011 * medium - 0.3413193965 * short,
    -0.0041960863 * long - 0.7034186147 * medium + 1.707614701 * short,
  ];
}

function isInSrgbGamut(channels: LinearRgb): boolean {
  return channels.every((channel) => channel >= -1e-7 && channel <= 1.0000001);
}

function oklchToHex(color: Oklch): string {
  let mapped = color;
  let channels = oklchToLinearRgb(mapped);
  if (!isInSrgbGamut(channels)) {
    let lowerChroma = 0;
    let upperChroma = color.chroma;
    for (let iteration = 0; iteration < 24; iteration += 1) {
      const candidateChroma = (lowerChroma + upperChroma) / 2;
      const candidate = { ...color, chroma: candidateChroma };
      if (isInSrgbGamut(oklchToLinearRgb(candidate))) lowerChroma = candidateChroma;
      else upperChroma = candidateChroma;
    }
    mapped = { ...color, chroma: lowerChroma };
    channels = oklchToLinearRgb(mapped);
  }
  return channelsHex(channels.map(linearToSrgb) as [number, number, number]);
}

export function deriveThemeColor(color: string, strength: ThemeStrength): string {
  const normalized = normalizeHexColor(color, neutralColor1);
  if (strength === 100) return normalized;
  const source = hexToOklch(normalized);
  const derivation = strengthDerivation[strength];
  return oklchToHex({
    lightness: source.lightness + Math.max(0, lighterTarget - source.lightness) * derivation.lightnessProgress,
    chroma: source.chroma * derivation.chromaRetention,
    hue: source.hue,
  });
}

function relativeLuminance(hex: string): number {
  const channels = hexChannels(hex).map((channel) => {
    const normalized = channel / 255;
    return normalized <= 0.04045 ? normalized / 12.92 : ((normalized + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * channels[0]! + 0.7152 * channels[1]! + 0.0722 * channels[2]!;
}

function contrastRatio(first: string, second: string): number {
  const firstLuminance = relativeLuminance(first);
  const secondLuminance = relativeLuminance(second);
  return (Math.max(firstLuminance, secondLuminance) + 0.05) / (Math.min(firstLuminance, secondLuminance) + 0.05);
}

export function readableForeground(background: string): string {
  return contrastRatio(background, darkForeground) >= contrastRatio(background, lightForeground)
    ? darkForeground
    : lightForeground;
}

export function buildThemeColorScale(color: string): ThemeColorScale {
  return Object.fromEntries(themeStrengths.map((strength) => [strength, deriveThemeColor(color, strength)])) as unknown as ThemeColorScale;
}

function buildForegroundScale(scale: ThemeColorScale): ThemeForegroundScale {
  return Object.fromEntries(themeStrengths.map((strength) => [strength, readableForeground(scale[strength])])) as unknown as ThemeForegroundScale;
}

function populatedTeamColors(colors: TeamColors | null | undefined): readonly [string, string] | null {
  return colors?.primary && colors.secondary ? [colors.primary, colors.secondary] : null;
}

export function resolveTheme(
  preferenceValue: ThemePreference,
  favoriteTeamColors?: TeamColors | null,
  currentTeamColors?: TeamColors | null,
  favoriteTeamName = "Favorite Team",
  currentTeamName = "Current Team",
): ResolvedTheme {
  const preference = normalizeThemePreference(preferenceValue);
  let sourceColors: readonly [string, string] = [neutralColor1, neutralColor2];
  let sourceLabel = "FANatical neutral";
  let unavailableReason: string | null = null;
  let active = preference.source !== "none";

  if (preference.source === "favorite-team") {
    const colors = populatedTeamColors(favoriteTeamColors);
    if (colors) {
      sourceColors = colors;
      sourceLabel = favoriteTeamName;
    } else {
      active = false;
      unavailableReason = `${favoriteTeamName} does not have two available team colors yet.`;
    }
  } else if (preference.source === "current-team") {
    const colors = populatedTeamColors(currentTeamColors);
    if (colors) {
      sourceColors = colors;
      sourceLabel = currentTeamName;
    } else {
      active = false;
      unavailableReason = `${currentTeamName} does not have two available team colors yet.`;
    }
  } else if (preference.source === "custom") {
    sourceColors = [preference.customColor1, preference.customColor2];
    sourceLabel = "Custom";
  }

  const [color1, color2] = preference.order === "swapped" && active
    ? [sourceColors[1], sourceColors[0]]
    : sourceColors;
  const color1Scale = buildThemeColorScale(color1);
  const color2Scale = buildThemeColorScale(color2);
  return {
    source: preference.source,
    order: preference.order,
    active,
    sourceLabel,
    color1,
    color2,
    color1Scale,
    color2Scale,
    color1Foreground: buildForegroundScale(color1Scale),
    color2Foreground: buildForegroundScale(color2Scale),
    unavailableReason,
  };
}

export function themeCssProperties(theme: ResolvedTheme): ThemeCssProperties {
  const properties: ThemeCssProperties = {
    "--theme-color-1": theme.color1,
    "--theme-color-2": theme.color2,
  };
  for (const strength of themeStrengths) {
    properties[`--theme-color-1-${strength}`] = theme.color1Scale[strength];
    properties[`--theme-color-2-${strength}`] = theme.color2Scale[strength];
    properties[`--theme-color-1-${strength}-foreground`] = theme.color1Foreground[strength];
    properties[`--theme-color-2-${strength}-foreground`] = theme.color2Foreground[strength];
  }
  return properties;
}
