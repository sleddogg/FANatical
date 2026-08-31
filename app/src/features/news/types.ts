// Phase 4 fan-safe production News contracts. FANbase's explicitly deferred
// Article Discussion fixture owns its separate local prototype types.
export type NewsIdentityTargetType = "author" | "organization" | "show";
export type FanSafeNewsItemKind = "written" | "podcast_episode";
export type NewsClassificationType = "sport" | "competition" | "competition_edition" | "team";

export type NewsByline = Readonly<{
  rawAttribution: string;
  targetType: NewsIdentityTargetType | null;
  targetId: string | null;
}>;

export type NewsClassification = Readonly<{
  targetType: NewsClassificationType;
  targetId: string;
  displayName: string;
}>;

export type FanSafeNewsItem = Readonly<{
  id: string;
  itemKind: FanSafeNewsItemKind;
  headline: string;
  summary: string;
  publishedAt: string;
  serverTime: string;
  destinationUrl: string;
  publisher: Readonly<{
    id: string;
    name: string;
  }>;
  show: Readonly<{
    id: string;
    name: string;
  }> | null;
  preview: Readonly<{
    url: string;
    kind: string;
    alt: string;
  }> | null;
  bylines: readonly NewsByline[];
  classifications: readonly NewsClassification[];
}>;

export type NewsTemporaryFilter =
  | Readonly<{ kind: "all"; displayName: "All Followed News" | "All Demo News" }>
  | Readonly<{
      kind: "sport" | "competition" | "team";
      targetId: string;
      displayName: string;
    }>;

export type NewsFollowTarget = Readonly<{
  targetType: NewsIdentityTargetType;
  targetId: string;
  displayName: string;
}>;

export type NewsFollowingEntry = NewsFollowTarget & Readonly<{
  followIds: readonly string[];
  mutedUntil: string | null;
  needsReselection: boolean;
  sportScopeIds: readonly string[];
  teamScopeIds: readonly string[];
}>;

export type NewsNavigationEntry = Readonly<{
  filterType: "sport" | "competition" | "team";
  targetId: string;
  displayName: string;
  sportId: string;
}>;

export type NewsIdentityProfile = NewsFollowTarget;

export type NewsDemoSelection = Readonly<{
  targetType: NewsIdentityTargetType;
  targetId: string;
}>;
