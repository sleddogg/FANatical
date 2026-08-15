import type { CheerCheckIn, CheerLiveMeasure, CheerLiveRouting, CheerLiveRoutingDimension, CheerLiveVariant, CheerRecord, CrowdAssignment, MappedVenueCheckIn } from "./types";

export const liveVariantCacheKey = "fanatical.cheer.preloaded-live-variants.v1";

export type PreloadedLiveVariant = Readonly<{
  cheerId: string;
  checkInKey: string;
  variant: CheerLiveVariant;
  cachedAt: string;
}>;

const levelAudiences = new Set<CrowdAssignment>(["Upper", "Lower"]);
const sideAudiences = new Set<CrowdAssignment>(["Side A", "Side B"]);
const endAudiences = new Set<CrowdAssignment>(["End A", "End B"]);

function routedAudiences(cheer: CheerRecord) {
  return cheer.measures.flatMap((measure) => [...measure.actionSegments, ...measure.lyricSegments].map((segment) => segment.audience));
}

export function liveRoutingDimensions(cheer: CheerRecord): readonly CheerLiveRoutingDimension[] {
  const audiences = routedAudiences(cheer);
  return [
    audiences.some((audience) => levelAudiences.has(audience)) ? "Level" : null,
    audiences.some((audience) => sideAudiences.has(audience)) ? "Side" : null,
    audiences.some((audience) => endAudiences.has(audience)) ? "End" : null,
  ].filter((dimension): dimension is CheerLiveRoutingDimension => dimension !== null);
}

function routingCombinations(dimensions: readonly CheerLiveRoutingDimension[]): readonly CheerLiveRouting[] {
  const levels: CheerLiveRouting["level"][] = dimensions.includes("Level") ? ["Upper", "Lower"] : [null];
  const sides: CheerLiveRouting["side"][] = dimensions.includes("Side") ? ["Side A", "Side B"] : [null];
  const ends: CheerLiveRouting["end"][] = dimensions.includes("End") ? ["End A", "End B"] : [null];
  return levels.flatMap((level) => sides.flatMap((side) => ends.map((end) => ({ level, side, end }))));
}

function segmentMatchesRouting(audience: CrowdAssignment, routing: CheerLiveRouting) {
  if (audience === "All") return true;
  if (levelAudiences.has(audience)) return routing.level === audience;
  if (sideAudiences.has(audience)) return routing.side === audience;
  if (endAudiences.has(audience)) return routing.end === audience;
  // Other sport-specific dimensions will become explicit axes in later passes.
  // Until then they remain in every generated variant rather than being lost.
  return true;
}

function variantMeasure(cheer: CheerRecord, routing: CheerLiveRouting): readonly CheerLiveMeasure[] {
  return cheer.measures.map((measure) => ({
    id: measure.id,
    actionSegments: measure.actionSegments.filter((segment) => segmentMatchesRouting(segment.audience, routing)).map(({ audience, ...segment }) => ({ ...segment, sourceAudience: audience })),
    lyricSegments: measure.lyricSegments.filter((segment) => segmentMatchesRouting(segment.audience, routing)).map(({ audience, ...segment }) => ({ ...segment, sourceAudience: audience })),
    restSegments: measure.restSegments.map(({ audience, ...segment }) => ({ ...segment, sourceAudience: audience })),
  }));
}

function routingId(routing: CheerLiveRouting) {
  return [routing.level ?? "all-levels", routing.side ?? "all-sides", routing.end ?? "all-ends"].join("_").toLocaleLowerCase().replaceAll(" ", "-");
}

export function generateLiveVariants(cheer: CheerRecord, generatedAt = new Date().toISOString()): readonly CheerLiveVariant[] {
  const routingDimensions = liveRoutingDimensions(cheer);
  return routingCombinations(routingDimensions).map((routing) => ({
    id: `${cheer.id}:live:${routingId(routing)}`,
    routingDimensions,
    routing,
    measures: variantMeasure(cheer, routing),
    generatedAt,
  }));
}

export function withPublishTimeLiveVariants(cheer: CheerRecord): CheerRecord {
  const isTargetCheer = cheer.title.trim().toLocaleLowerCase() === "test";
  if (!isTargetCheer || cheer.publicationStatus !== "Published") {
    return cheer.liveVariants?.length ? { ...cheer, liveVariants: [] } : cheer;
  }
  return { ...cheer, liveVariants: generateLiveVariants(cheer) };
}

export function checkInVariantKey(checkIn: MappedVenueCheckIn) {
  return `${checkIn.raw.venueId}:${checkIn.raw.section}:${checkIn.raw.row}:${checkIn.raw.seat}:${checkIn.resolved.level}:${checkIn.resolved.side}:${checkIn.resolved.end}`;
}

export function selectLiveVariant(cheer: CheerRecord, checkIn: CheerCheckIn): CheerLiveVariant | null {
  if (checkIn.type !== "MappedVenue") return cheer.liveVariants?.find((variant) => !variant.routingDimensions.length) ?? null;
  return cheer.liveVariants?.find((variant) => (
    (variant.routing.level === null || variant.routing.level === checkIn.resolved.level)
    && (variant.routing.side === null || variant.routing.side === checkIn.resolved.side)
    && (variant.routing.end === null || variant.routing.end === checkIn.resolved.end)
  )) ?? null;
}

export function hasPlayableLiveVariant(cheer: CheerRecord, checkIn: CheerCheckIn | null) {
  if (!checkIn) return false;
  const variant = selectLiveVariant(cheer, checkIn);
  return Boolean(variant?.measures.length);
}

const targetRelativeAudiences = new Set<CrowdAssignment>(["Backboard Left", "Backboard Right", "Uprights Left", "Uprights Right"]);

export function resolveTargetRelativeLiveVariant(
  cheer: CheerRecord,
  variant: CheerLiveVariant,
  checkIn: CheerCheckIn,
  targetEnd: CheerLiveRouting["end"],
): CheerLiveVariant {
  if (!targetEnd) return variant;
  const audienceBySegmentId = new Map(cheer.measures.flatMap((measure) => [
    ...measure.actionSegments,
    ...measure.lyricSegments,
    ...measure.restSegments,
  ]).map((segment) => [segment.id, segment.audience] as const));
  const fanIsInTargetEnd = checkIn.type === "MappedVenue" && checkIn.resolved.end === targetEnd;
  const belongsInFanVariant = (segment: { readonly id: string; readonly sourceAudience?: CrowdAssignment }) => {
    const audience = segment.sourceAudience ?? audienceBySegmentId.get(segment.id);
    return !audience || !targetRelativeAudiences.has(audience) || fanIsInTargetEnd;
  };
  return {
    ...variant,
    measures: variant.measures.map((measure) => ({
      ...measure,
      actionSegments: measure.actionSegments.filter(belongsInFanVariant),
      lyricSegments: measure.lyricSegments.filter(belongsInFanVariant),
      // A Rest is a whole-timeline pause, not an audience-targeted instruction.
      restSegments: measure.restSegments,
    })),
  };
}

export function preloadAvailableLiveVariants(cheers: readonly CheerRecord[], checkIn: CheerCheckIn | null) {
  if (!checkIn || checkIn.type !== "MappedVenue") {
    window.sessionStorage.removeItem(liveVariantCacheKey);
    return [];
  }
  const checkInKey = checkInVariantKey(checkIn);
  const cached = cheers.flatMap((cheer): PreloadedLiveVariant[] => {
    const variant = selectLiveVariant(cheer, checkIn);
    return variant ? [{ cheerId: cheer.id, checkInKey, variant, cachedAt: new Date().toISOString() }] : [];
  });
  window.sessionStorage.setItem(liveVariantCacheKey, JSON.stringify(cached));
  return cached;
}

export function loadPreloadedLiveVariant(cheerId: string, checkIn: CheerCheckIn | null): CheerLiveVariant | null {
  if (!checkIn || checkIn.type !== "MappedVenue") return null;
  try {
    const parsed: unknown = JSON.parse(window.sessionStorage.getItem(liveVariantCacheKey) ?? "[]");
    if (!Array.isArray(parsed)) return null;
    const candidate = parsed.find((entry) => entry && typeof entry === "object" && (entry as PreloadedLiveVariant).cheerId === cheerId && (entry as PreloadedLiveVariant).checkInKey === checkInVariantKey(checkIn)) as PreloadedLiveVariant | undefined;
    return candidate?.variant ?? null;
  } catch {
    return null;
  }
}
