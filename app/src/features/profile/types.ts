export type ProfileTabId = "bio" | "fan-identity" | "sports-played" | "trophy-case" | "moments";
export type ProfileVisibility = "public" | "private";

export type ProfileField = Readonly<{
  id: string;
  label: string;
  value: string;
}>;

export type SportExperience = Readonly<{
  id: string;
  sport: string;
  position: string;
  level: string;
  years: string;
  highlight: string;
}>;

export type ProfileRecord = Readonly<{
  id: string;
  visibility: ProfileVisibility;
  displayName: string;
  handle: string;
  tagline: string;
  featuredFanPhotoCategory: "Game Face" | "Fan Cave" | "Memorabilia";
  bio: readonly ProfileField[];
  fanIdentity: readonly ProfileField[];
  sportsPlayed: readonly SportExperience[];
}>;

export type ProfileStat = Readonly<{
  label: string;
  value: string;
  detail: string;
}>;

export type Trophy = Readonly<{
  id: string;
  name: string;
  description: string;
  icon: string;
  status: "earned" | "locked" | "progress";
  progress?: number;
  earnedAt?: string;
}>;

export type FanMoment = Readonly<{
  id: string;
  title: string;
  type: string;
  dateOccurred: string;
  createdAt: string;
  story: string;
  location?: string;
  eventContext?: string;
  fanPhotoId?: string;
}>;

export type CreateFanMomentInput = Readonly<{
  title: string;
  type: string;
  dateOccurred: string;
  story: string;
  location?: string;
  eventContext?: string;
  fanPhotoId?: string;
}>;
