export const homeOverlayPositions = [
  "top-left",
  "top-center",
  "top-right",
  "middle-left",
  "middle-right",
  "bottom-left",
  "bottom-center",
  "bottom-right",
] as const;

export type HomeOverlayPosition = (typeof homeOverlayPositions)[number];
export type FanCardLayout = "grid" | "stack";

export type HomeCustomization = Readonly<{
  textOverlay: Readonly<{
    enabled: boolean;
    bigText: string;
    smallText: string;
    position: HomeOverlayPosition;
  }>;
  fanCard: Readonly<{
    enabled: boolean;
    fieldIds: readonly string[];
    layout: FanCardLayout;
    position: HomeOverlayPosition;
  }>;
}>;

export const defaultHomeCustomization: HomeCustomization = {
  textOverlay: {
    enabled: true,
    bigText: "Your home for fandom.",
    smallText: "News, knowledge, community and game-day energy in one connected place.",
    position: "bottom-left",
  },
  fanCard: {
    enabled: false,
    fieldIds: [],
    layout: "grid",
    position: "bottom-right",
  },
};

export const homeCustomizationStorageKey = "fanatical.home-customization.v1";
export const homeCustomizationChangeEvent = "fanatical:home-customization-change";

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function position(value: unknown, fallback: HomeOverlayPosition): HomeOverlayPosition {
  return typeof value === "string" && homeOverlayPositions.includes(value as HomeOverlayPosition)
    ? value as HomeOverlayPosition
    : fallback;
}

export function normalizeHomeCustomization(value: unknown): HomeCustomization {
  const root = isRecord(value) ? value : {};
  const textOverlay = isRecord(root.textOverlay) ? root.textOverlay : {};
  const fanCard = isRecord(root.fanCard) ? root.fanCard : {};
  const fieldIds = Array.isArray(fanCard.fieldIds)
    ? [...new Set(fanCard.fieldIds.filter((fieldId): fieldId is string => typeof fieldId === "string" && Boolean(fieldId.trim())).map((fieldId) => fieldId.trim()))].slice(0, 4)
    : defaultHomeCustomization.fanCard.fieldIds;

  return {
    textOverlay: {
      enabled: typeof textOverlay.enabled === "boolean" ? textOverlay.enabled : defaultHomeCustomization.textOverlay.enabled,
      bigText: typeof textOverlay.bigText === "string" ? textOverlay.bigText.slice(0, 30) : defaultHomeCustomization.textOverlay.bigText,
      smallText: typeof textOverlay.smallText === "string" ? textOverlay.smallText.slice(0, 70) : defaultHomeCustomization.textOverlay.smallText,
      position: position(textOverlay.position, defaultHomeCustomization.textOverlay.position),
    },
    fanCard: {
      enabled: typeof fanCard.enabled === "boolean" ? fanCard.enabled : defaultHomeCustomization.fanCard.enabled,
      fieldIds,
      layout: fanCard.layout === "stack" ? "stack" : "grid",
      position: position(fanCard.position, defaultHomeCustomization.fanCard.position),
    },
  };
}

export function loadHomeCustomization(): HomeCustomization {
  if (typeof window === "undefined") return defaultHomeCustomization;
  try {
    return normalizeHomeCustomization(JSON.parse(window.localStorage.getItem(homeCustomizationStorageKey) ?? "null"));
  } catch {
    return defaultHomeCustomization;
  }
}

export function saveHomeCustomization(value: HomeCustomization) {
  const normalized = normalizeHomeCustomization(value);
  window.localStorage.setItem(homeCustomizationStorageKey, JSON.stringify(normalized));
  window.dispatchEvent(new CustomEvent<HomeCustomization>(homeCustomizationChangeEvent, { detail: normalized }));
}
