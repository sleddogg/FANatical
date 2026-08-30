import type { TeamId } from "../../domain/team";
import type { OfficialLeagueId, OfficialSportId, OfficialTeamId } from "../../data/officialSportsDatabase";
import type { ArticleDiscussionScope } from "./articleDiscussionTypes";

export type FanbaseAreaId =
  | "article-comments"
  | "locker-room"
  | "game-threads"
  | "fan-photos"
  | "events"
  | "groups"
  | "polls"
  | "leaderboards";

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
  teamId: TeamId | null;
  discussionScope?: ArticleDiscussionScope;
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
  sportId: OfficialSportId;
  leagueId: OfficialLeagueId | null;
  opponent: string;
  venue: string;
  startsAt: string;
  endsAt: string;
  finalResult: Readonly<{
    teamAScore: number;
    teamBScore: number;
    outcome: GamePredictionOutcome;
    finalizedAt: string;
  }> | null;
}>;

export type FanPhotoImage = Readonly<{
  id: string;
  url: string;
  alt: string;
}>;

export type FanPhoto = Readonly<{
  id: string;
  teamId: TeamId;
  owner: CommunityUser;
  category: FanPhotoCategory;
  title: string;
  details: string;
  images: readonly FanPhotoImage[];
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

export type FanEventLocation = Readonly<{
  label: string;
  venueId?: string;
  coordinates?: Readonly<{ latitude: number; longitude: number }>;
}>;

export type FanEvent = Readonly<{
  id: string;
  teamId: TeamId;
  title: string;
  eventType: "Watch Party" | "Meetup" | "Rivalry Event" | "Online Event";
  startsAt: string;
  location: FanEventLocation;
  host: string;
  visibility: "Public" | "Private";
  description: string;
  invitedUserIds: readonly CommunityUser["id"][];
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
  viewerRole: "Owner" | "Moderator" | "Member" | null;
  memberUserIds: readonly CommunityUser["id"][];
  invitedUserIds: readonly CommunityUser["id"][];
  moderatorUserIds: readonly CommunityUser["id"][];
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
  location: FanEventLocation;
  visibility: FanEvent["visibility"];
  description: string;
  invitedUserIds: readonly CommunityUser["id"][];
}>;

export type CreateGroupInput = Readonly<{
  teamId: TeamId;
  name: string;
  visibility: GroupVisibility;
  description: string;
  invitedUserIds: readonly CommunityUser["id"][];
}>;

export type GameThreadStatus = "Scheduled" | "Live" | "Post-game" | "Archived";
export type GamePredictionOutcome = "Regulation" | "Overtime" | "Tie" | "Extra Innings" | "Shootout" | "Draw";

export type PollScope =
  | Readonly<{ kind: "sport"; sportId: OfficialSportId; leagueId: null; teamId: null }>
  | Readonly<{ kind: "league"; sportId: OfficialSportId; leagueId: OfficialLeagueId; teamId: null }>
  | Readonly<{ kind: "team"; sportId: OfficialSportId; leagueId: OfficialLeagueId; teamId: OfficialTeamId }>;

export type PollOption = Readonly<{
  id: string;
  label: string;
  voteCount: number;
}>;

export type FanPoll = Readonly<{
  id: string;
  question: string;
  options: readonly PollOption[];
  scope: PollScope;
  topics: readonly string[];
  linkedPreviousPollId: string | null;
  createdBy: CommunityUser;
  createdAt: string;
  recentVotesPerHour: number;
  viewerOptionId: string | null;
}>;

export type CreatePollInput = Readonly<{
  question: string;
  options: readonly string[];
  scope: PollScope;
  topics: readonly string[];
  linkedPreviousPollId: string | null;
}>;
