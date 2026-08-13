export type VenueLevel = "Upper" | "Lower" | "N/A";
export type VenueSide = "Side A" | "Side B";
export type VenueEnd = "End A" | "End B";

export type SectionException = Readonly<{
  id: string;
  rowStart: string;
  rowEnd: string;
  seatStart: number | null;
  seatEnd: number | null;
  level: VenueLevel | null;
  side: VenueSide | null;
  end: VenueEnd | null;
}>;

export type VenueSectionMapping = Readonly<{
  section: string;
  level: VenueLevel;
  side: VenueSide;
  end: VenueEnd;
  exceptions: readonly SectionException[];
}>;

export type TeamLevelUse = "Upper + Lower" | "Upper only" | "Lower only" | "N/A";
export type TeamSideUse = "Both" | "Side A only" | "Side B only";
export type TeamEndUse = "Both" | "End A only" | "End B only";

export type TeamSeatingProfile = Readonly<{
  id: string;
  teamName: string;
  levels: TeamLevelUse;
  sides: TeamSideUse;
  ends: TeamEndUse;
}>;

export type VenueValueRange = Readonly<{
  start: string;
  end: string;
}>;

export type VenueSelectableValues = Readonly<{
  values: readonly string[];
  ranges: readonly VenueValueRange[];
}>;

export type VenueRowSeatOverride = Readonly<{
  rowStart: string;
  rowEnd: string;
  seats: VenueSelectableValues;
}>;

// Ticket inventory is intentionally range-based. A venue can describe valid rows
// and seats without creating a physical routing record for every individual seat.
export type VenueSeatInventoryRule = Readonly<{
  id: string;
  sections: readonly string[];
  levels: readonly VenueLevel[];
  rows: VenueSelectableValues;
  seats: VenueSelectableValues;
  rowSeatOverrides: readonly VenueRowSeatOverride[];
}>;

export type VenueSportConfiguration = Readonly<{
  sport: string;
  teamProfileIds: readonly string[];
}>;

export type VenueMapping = Readonly<{
  id: string;
  slug: string;
  routingConventionVersion: number;
  name: string;
  location: string;
  sectionFormat: "Numeric" | "Mixed";
  seatingChartImageUrl: string;
  seatingChartSourceLabel: string;
  seatingChartSourceUrl: string;
  sections: readonly VenueSectionMapping[];
  teamProfiles: readonly TeamSeatingProfile[];
  sports: readonly VenueSportConfiguration[];
  seatInventoryRules: readonly VenueSeatInventoryRule[];
  updatedAt: string;
}>;

export type ResolvedAxis<T extends string> = Readonly<{
  value: T;
  source: string;
}>;

export type SeatResolution = Readonly<{
  section: VenueSectionMapping;
  level: ResolvedAxis<VenueLevel>;
  side: ResolvedAxis<VenueSide>;
  end: ResolvedAxis<VenueEnd>;
}>; 
