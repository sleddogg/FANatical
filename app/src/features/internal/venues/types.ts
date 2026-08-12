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

export type VenueMapping = Readonly<{
  id: string;
  slug: string;
  routingConventionVersion: number;
  name: string;
  location: string;
  seatingChartImageUrl: string;
  seatingChartSourceLabel: string;
  seatingChartSourceUrl: string;
  sections: readonly VenueSectionMapping[];
  teamProfiles: readonly TeamSeatingProfile[];
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
