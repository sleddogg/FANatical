import type { TeamId } from "../../domain/team";

export type FanbaseAreaId =
  | "article-comments"
  | "locker-room"
  | "game-threads"
  | "fan-photos"
  | "events"
  | "groups";

export type ReactionType = "Like" | "Love" | "Fire" | "Mind Blown";
export type FanPhotoCategory = "Game Face" | "Fan Cave" | "Memorabilia";
export type GroupVisibility = "Public" | "Private" | "Invite Only";

export type CommunityUser = Readonly<{
  id: string;
  username: string;
  initials: string;
}>;

export type ReactionSummary = Readonly<Record<ReactionType, number>>;

export type CommunityComment = Readonly<{
  id: string;
  author: CommunityUser;
  body: string;
  createdAt: string;
  parentId: string | null;
  reactions: ReactionSummary;
  viewerReaction: ReactionType | null;
  reported: boolean;
}>;

export type DiscussionThread = Readonly<{
  id: string;
  kind: "article" | "locker" | "game" | "group";
  teamId: TeamId;
  newsItemId?: string;
  title?: string;
  body?: string;
  category?: string;
  creator?: CommunityUser;
  createdAt: string;
  priorCommentCount: number;
  comments: readonly CommunityComment[];
  reactions: ReactionSummary;
  viewerReaction: ReactionType | null;
  reported: boolean;
}>;

export type GameThread = Readonly<{
  id: string;
  threadId: string;
  teamId: TeamId;
  opponent: string;
  venue: string;
  startsAt: string;
  endsAt: string;
}>;

export type FanPhoto = Readonly<{
  id: string;
  teamId: TeamId;
  owner: CommunityUser;
  category: FanPhotoCategory;
  title: string;
  details: string;
  imageUrl: string;
  imageAlt: string;
  accent: string;
  createdAt: string;
  ratingTotal: number;
  ratingCount: number;
  viewerRating: number | null;
  reactions: ReactionSummary;
  viewerReaction: ReactionType | null;
  comments: readonly CommunityComment[];
  rankingBadge?: "Top 10" | "Top 50" | "Top 100" | "Legendary";
  reported: boolean;
}>

export type FanEvent = Readonly<{
  id: string;
  teamId: TeamId;
  title: string;
  eventType: "Watch Party" | "Meetup" | "Rivalry Event" | "Online";
  startsAt: string;
  location: string;
  host: string;
  visibility: "Public" | "Private";
  description: string;
  joinCount: number;
  joined: boolean;
  saved: boolean;
  reported: boolean;
}>;

export type FanGroup = Readonly<{
  id: string;
  teamId: TeamId;
  name: string;
  description: string;
  visibility: GroupVisibility;
  memberCount: number;
  joined: boolean;
  latestActivity: string;
  threadId: string;
  reported: boolean;
}>;

export type CreateLockerRoomInput = Readonly<{
  teamId: TeamId;
  title: string;
  category: string;
  body: string;
}>;

export type CreateFanPhotoInput = Readonly<{
  teamId: TeamId;
  title: string;
  category: FanPhotoCategory;
  details: string;
}>;

export type CreateEventInput = Readonly<{
  teamId: TeamId;
  title: string;
  eventType: FanEvent["eventType"];
  startsAt: string;
  location: string;
  visibility: FanEvent["visibility"];
  description: string;
}>;

export type CreateGroupInput = Readonly<{
  teamId: TeamId;
  name: string;
  visibility: GroupVisibility;
  description: string;
}>;

export type GameThreadStatus = "Scheduled" | "Live" | "Post-game" | "Archived";
