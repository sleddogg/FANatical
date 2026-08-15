import type { CSSProperties } from "react";
import type { PopulatedTeamColors, TeamColors } from "../data/officialSportsDatabase";

type TeamBadgeIdentity = Readonly<{
  name: string;
  colors: TeamColors;
}>;

type TeamBadgeProps = Readonly<{
  team: TeamBadgeIdentity;
  className?: string;
}>;

function rgb(hex: string) {
  const value = hex.slice(1);
  return [0, 2, 4].map((offset) => Number.parseInt(value.slice(offset, offset + 2), 16) / 255);
}

function relativeLuminance(hex: string) {
  const [red = 0, green = 0, blue = 0] = rgb(hex).map((channel) => channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4);
  return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
}

export function colorContrast(first: string, second: string) {
  const brighter = Math.max(relativeLuminance(first), relativeLuminance(second));
  const darker = Math.min(relativeLuminance(first), relativeLuminance(second));
  return (brighter + 0.05) / (darker + 0.05);
}

export function teamInitials(name: string) {
  return name.split(/\s+/).filter(Boolean).map((word) => word[0]).join("").slice(0, 3).toUpperCase();
}

export function teamBadgePalette(colors: PopulatedTeamColors) {
  const primaryLuminance = relativeLuminance(colors.primary);
  const secondaryLuminance = relativeLuminance(colors.secondary);
  const center = primaryLuminance <= secondaryLuminance ? colors.primary : colors.secondary;
  const ring = center === colors.primary ? colors.secondary : colors.primary;
  const textCandidates = [colors.tertiary, colors.quaternary, colors.quinary, "#FFFFFF", "#000000"]
    .filter((color): color is string => color !== null);
  const text = textCandidates.reduce((best, candidate) => colorContrast(candidate, center) > colorContrast(best, center) ? candidate : best);
  return { center, ring, text };
}

export function TeamBadge({ team, className = "" }: TeamBadgeProps) {
  const initials = teamInitials(team.name);
  const palette = team.colors.primary && team.colors.secondary
    ? teamBadgePalette(team.colors as PopulatedTeamColors)
    : { center: "#111111", ring: "#767676", text: "#FFFFFF" };
  const style = {
    "--team-badge-center": palette.center,
    "--team-badge-ring": palette.ring,
    "--team-badge-text": palette.text,
  } as CSSProperties;

  return <span className={`team-badge${className ? ` ${className}` : ""}`} style={style} data-initial-count={initials.length} aria-hidden="true">{initials}</span>;
}
