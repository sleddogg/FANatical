import type { NavigationSide } from "../data/navigationSidePreference";
import { homeOverlayPositions, type HomeCustomization, type HomeOverlayPosition } from "../data/homeCustomizationStorage";

export const homeOverlayPositionLabels: Readonly<Record<HomeOverlayPosition, string>> = {
  "top-left": "Top Left",
  "top-center": "Top Center",
  "top-right": "Top Right",
  "middle-left": "Middle Left",
  "middle-right": "Middle Right",
  "bottom-left": "Bottom Left",
  "bottom-center": "Bottom Center",
  "bottom-right": "Bottom Right",
};

export type HomeLayoutRectangle = Readonly<{ left: number; top: number; width: number; height: number }>;
type HomeOverlaySize = Readonly<{ width: number; height: number }>;

export type HomeOverlayMeasurements = Readonly<{
  container: Readonly<{ width: number; height: number }>;
  navigation: HomeLayoutRectangle;
  edge: number;
  textOverlay?: HomeOverlaySize;
  fanCard?: HomeOverlaySize;
}>;

export type ResolvedHomeOverlayPositions = Readonly<{
  textOverlay?: HomeOverlayPosition;
  fanCard?: HomeOverlayPosition;
}>;

export function positionConflictsWithNavigation(position: HomeOverlayPosition, navigationSide: NavigationSide) {
  return position === `middle-${navigationSide}`;
}

function row(position: HomeOverlayPosition) {
  return position.startsWith("top-") ? 0 : position.startsWith("middle-") ? 1 : 2;
}

function column(position: HomeOverlayPosition) {
  return position.endsWith("-left") ? 0 : position.endsWith("-center") ? 1 : 2;
}

function candidatePositions(preferred: HomeOverlayPosition) {
  return [...homeOverlayPositions].sort((first, second) => {
    const firstDistance = Math.abs(row(first) - row(preferred)) + Math.abs(column(first) - column(preferred));
    const secondDistance = Math.abs(row(second) - row(preferred)) + Math.abs(column(second) - column(preferred));
    return firstDistance - secondDistance;
  });
}

function firstAvailableAnchor(preferred: HomeOverlayPosition, navigationSide: NavigationSide, occupied: readonly HomeOverlayPosition[]) {
  return candidatePositions(preferred).find((position) => !positionConflictsWithNavigation(position, navigationSide) && !occupied.includes(position)) ?? preferred;
}

export function resolveSavedHomeCustomizationPositions(customization: HomeCustomization, navigationSide: NavigationSide): HomeCustomization {
  const occupied: HomeOverlayPosition[] = [];
  const textPosition = customization.textOverlay.enabled
    ? firstAvailableAnchor(customization.textOverlay.position, navigationSide, occupied)
    : customization.textOverlay.position;
  if (customization.textOverlay.enabled) occupied.push(textPosition);
  const fanCardPosition = customization.fanCard.enabled
    ? firstAvailableAnchor(customization.fanCard.position, navigationSide, occupied)
    : customization.fanCard.position;
  return {
    textOverlay: { ...customization.textOverlay, position: textPosition },
    fanCard: { ...customization.fanCard, position: fanCardPosition },
  };
}

function rectangleFor(position: HomeOverlayPosition, size: HomeOverlaySize, container: HomeOverlayMeasurements["container"], edge: number): HomeLayoutRectangle {
  const left = position.endsWith("-left")
    ? edge
    : position.endsWith("-right")
      ? container.width - edge - size.width
      : (container.width - size.width) / 2;
  const top = position.startsWith("top-")
    ? edge
    : position.startsWith("bottom-")
      ? container.height - edge - size.height
      : (container.height - size.height) / 2;
  return { left, top, width: size.width, height: size.height };
}

export function rectanglesOverlap(first: HomeLayoutRectangle, second: HomeLayoutRectangle, gap = 8) {
  return first.left < second.left + second.width + gap
    && first.left + first.width + gap > second.left
    && first.top < second.top + second.height + gap
    && first.top + first.height + gap > second.top;
}

function firstSafePosition(preferred: HomeOverlayPosition, size: HomeOverlaySize, measurements: HomeOverlayMeasurements, occupied: readonly HomeLayoutRectangle[]) {
  const safe = candidatePositions(preferred).find((position) => {
    const rectangle = rectangleFor(position, size, measurements.container, measurements.edge);
    return !rectanglesOverlap(rectangle, measurements.navigation) && occupied.every((item) => !rectanglesOverlap(rectangle, item));
  });
  return safe ?? preferred;
}

export function resolveHomeOverlayPositions(
  preferred: ResolvedHomeOverlayPositions,
  measurements: HomeOverlayMeasurements,
): ResolvedHomeOverlayPositions {
  const occupied: HomeLayoutRectangle[] = [];
  const resolved: { textOverlay?: HomeOverlayPosition; fanCard?: HomeOverlayPosition } = {};
  if (preferred.textOverlay && measurements.textOverlay) {
    resolved.textOverlay = firstSafePosition(preferred.textOverlay, measurements.textOverlay, measurements, occupied);
    occupied.push(rectangleFor(resolved.textOverlay, measurements.textOverlay, measurements.container, measurements.edge));
  }
  if (preferred.fanCard && measurements.fanCard) {
    resolved.fanCard = firstSafePosition(preferred.fanCard, measurements.fanCard, measurements, occupied);
  }
  return resolved;
}
