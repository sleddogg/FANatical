import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type PropsWithChildren,
} from "react";
import { fanPhotoCategoryCoverImages } from "./fanPhotoAssets";
import { initialPolls } from "./mockPollData";
import { loadPolls, savePolls } from "./pollStorage";
import {
  demoUser,
  emptyReactions,
  initialDiscussionThreads,
  initialEvents,
  initialFanPhotos,
  initialGameThreads,
  initialGroups,
} from "./mockFanbaseData";
import type {
  CommunityComment,
  CreateEventInput,
  CreateFanPhotoInput,
  CreateGroupInput,
  CreateLockerRoomInput,
  CreatePollInput,
  DiscussionThread,
  FanEvent,
  FanGroup,
  FanPhoto,
  GameThread,
  GameThreadStatus,
  FanPoll,
  ReactionSummary,
  ReactionType,
} from "./types";
import type { ArticleDiscussionScope } from "./articleDiscussionTypes";

type FanbaseContextValue = Readonly<{
  threads: readonly DiscussionThread[];
  gameThreads: readonly GameThread[];
  fanPhotos: readonly FanPhoto[];
  events: readonly FanEvent[];
  groups: readonly FanGroup[];
  polls: readonly FanPoll[];
  getArticleThread: (newsItemId: string) => DiscussionThread | undefined;
  getArticleCommentCount: (newsItemId: string) => number;
  addArticleComment: (newsItemId: string, scope: ArticleDiscussionScope, body: string, parentId?: string | null) => string;
  addComment: (threadId: string, body: string, parentId?: string | null) => void;
  reactToThread: (threadId: string, reaction: ReactionType) => void;
  reactToComment: (threadId: string, commentId: string, reaction: ReactionType) => void;
  reportThread: (threadId: string) => void;
  reportComment: (threadId: string, commentId: string) => void;
  createLockerRoomThread: (input: CreateLockerRoomInput) => string;
  createFanPhoto: (input: CreateFanPhotoInput) => string;
  rateFanPhoto: (photoId: string, rating: number) => void;
  reactToFanPhoto: (photoId: string, reaction: ReactionType) => void;
  addFanPhotoComment: (photoId: string, body: string) => void;
  reportFanPhoto: (photoId: string) => void;
  createEvent: (input: CreateEventInput) => string;
  toggleEventJoined: (eventId: string) => void;
  toggleEventSaved: (eventId: string) => void;
  invitePeopleToEvent: (eventId: string, userIds: readonly string[]) => void;
  reportEvent: (eventId: string) => void;
  createGroup: (input: CreateGroupInput) => string;
  toggleGroupJoined: (groupId: string) => void;
  invitePeopleToGroup: (groupId: string, userIds: readonly string[]) => void;
  addGroupModerators: (groupId: string, userIds: readonly string[]) => void;
  reportGroup: (groupId: string) => void;
  voteInPoll: (pollId: string, optionId: string) => void;
  createPoll: (input: CreatePollInput) => string;
}>;

const FanbaseContext = createContext<FanbaseContextValue | undefined>(undefined);
let localRecordSequence = 0;

function createLocalId(prefix: string) {
  localRecordSequence += 1;
  return `${prefix}-local-${localRecordSequence}`;
}

function createComment(body: string, parentId: string | null = null): CommunityComment {
  return {
    id: createLocalId("comment"),
    author: demoUser,
    body: body.trim(),
    createdAt: new Date().toISOString(),
    parentId,
    reactions: emptyReactions(),
    viewerReaction: null,
    reported: false,
  };
}

function toggleReaction(
  reactions: ReactionSummary,
  viewerReaction: ReactionType | null,
  selectedReaction: ReactionType,
) {
  const nextReactions = { ...reactions };
  if (viewerReaction) {
    nextReactions[viewerReaction] = Math.max(0, nextReactions[viewerReaction] - 1);
  }
  if (viewerReaction === selectedReaction) {
    return { reactions: nextReactions, viewerReaction: null };
  }
  nextReactions[selectedReaction] += 1;
  return { reactions: nextReactions, viewerReaction: selectedReaction };
}

export function getThreadCommentCount(thread: DiscussionThread | undefined) {
  return thread ? thread.priorCommentCount + thread.comments.length : 0;
}

export function getGameThreadStatus(game: GameThread, currentTime = Date.now()): GameThreadStatus {
  const startsAt = Date.parse(game.startsAt);
  const endsAt = Date.parse(game.endsAt);
  if (currentTime < startsAt) {
    return "Scheduled";
  }
  if (currentTime <= endsAt) {
    return "Live";
  }
  if (currentTime <= endsAt + 24 * 60 * 60 * 1000) {
    return "Post-game";
  }
  return "Archived";
}

export function FanbaseProvider({ children }: PropsWithChildren) {
  const [threads, setThreads] = useState<DiscussionThread[]>(() => [...initialDiscussionThreads]);
  const [fanPhotos, setFanPhotos] = useState<FanPhoto[]>(() => [...initialFanPhotos]);
  const [events, setEvents] = useState<FanEvent[]>(() => [...initialEvents]);
  const [groups, setGroups] = useState<FanGroup[]>(() => [...initialGroups]);
  const [polls, setPolls] = useState<FanPoll[]>(() => loadPolls(initialPolls));

  useEffect(() => {
    savePolls(polls);
  }, [polls]);

  const getArticleThread = useCallback(
    (newsItemId: string) => threads.find((thread) => thread.kind === "article" && thread.newsItemId === newsItemId),
    [threads],
  );

  const getArticleCommentCount = useCallback(
    (newsItemId: string) => getThreadCommentCount(getArticleThread(newsItemId)),
    [getArticleThread],
  );

  const addArticleComment = useCallback((
    newsItemId: string,
    scope: ArticleDiscussionScope,
    body: string,
    parentId: string | null = null,
  ) => {
    const threadId = `article:${newsItemId}`;
    const nextComment = createComment(body, parentId);
    setThreads((current) => {
      const existingThread = current.find((thread) => thread.kind === "article" && thread.newsItemId === newsItemId);
      if (existingThread) {
        return current.map((thread) => thread.id === existingThread.id
          ? { ...thread, comments: [...thread.comments, nextComment] }
          : thread);
      }
      return [{
        id: threadId,
        kind: "article",
        teamId: scope.kind === "team" ? scope.teamId : null,
        discussionScope: scope,
        newsItemId,
        createdAt: new Date().toISOString(),
        priorCommentCount: 0,
        comments: [nextComment],
        reactions: emptyReactions(),
        viewerReaction: null,
        reported: false,
      }, ...current];
    });
    return threadId;
  }, []);

  const addComment = useCallback((threadId: string, body: string, parentId: string | null = null) => {
    const nextComment = createComment(body, parentId);
    setThreads((current) => current.map((thread) => thread.id === threadId
      ? { ...thread, comments: [...thread.comments, nextComment] }
      : thread));
  }, []);

  const reactToThread = useCallback((threadId: string, reaction: ReactionType) => {
    setThreads((current) => current.map((thread) => thread.id === threadId
      ? { ...thread, ...toggleReaction(thread.reactions, thread.viewerReaction, reaction) }
      : thread));
  }, []);

  const reactToComment = useCallback((threadId: string, commentId: string, reaction: ReactionType) => {
    setThreads((current) => current.map((thread) => thread.id === threadId
      ? {
          ...thread,
          comments: thread.comments.map((comment) => comment.id === commentId
            ? { ...comment, ...toggleReaction(comment.reactions, comment.viewerReaction, reaction) }
            : comment),
        }
      : thread));
  }, []);

  const reportThread = useCallback((threadId: string) => {
    setThreads((current) => current.map((thread) => thread.id === threadId ? { ...thread, reported: true } : thread));
  }, []);

  const reportComment = useCallback((threadId: string, commentId: string) => {
    setThreads((current) => current.map((thread) => thread.id === threadId
      ? { ...thread, comments: thread.comments.map((comment) => comment.id === commentId ? { ...comment, reported: true } : comment) }
      : thread));
  }, []);

  const createLockerRoomThread = useCallback((input: CreateLockerRoomInput) => {
    const id = createLocalId("locker");
    setThreads((current) => [{
      id,
      kind: "locker",
      teamId: input.teamId,
      title: input.title.trim(),
      body: input.body.trim(),
      category: input.category,
      creator: demoUser,
      createdAt: new Date().toISOString(),
      priorCommentCount: 0,
      comments: [],
      reactions: emptyReactions(),
      viewerReaction: null,
      reported: false,
    }, ...current]);
    return id;
  }, []);

  const createFanPhoto = useCallback((input: CreateFanPhotoInput) => {
    const id = createLocalId("photo");
    const mockImage = fanPhotoCategoryCoverImages[input.category];
    setFanPhotos((current) => [{
      id,
      teamId: input.teamId,
      owner: demoUser,
      category: input.category,
      title: input.title.trim(),
      details: input.details.trim(),
      images: [{ ...mockImage, id: `${id}-image` }],
      createdAt: new Date().toISOString(),
      ratingTotal: 0,
      ratingCount: 0,
      viewerRating: null,
      reactions: emptyReactions(),
      viewerReaction: null,
      comments: [],
      reported: false,
    }, ...current]);
    return id;
  }, []);

  const rateFanPhoto = useCallback((photoId: string, rating: number) => {
    if (rating < 0.5 || rating > 5 || !Number.isInteger(rating * 2)) {
      return;
    }
    setFanPhotos((current) => current.map((photo) => {
      if (photo.id !== photoId) {
        return photo;
      }
      const previousRating = photo.viewerRating ?? 0;
      return {
        ...photo,
        ratingTotal: photo.ratingTotal - previousRating + rating,
        ratingCount: photo.viewerRating === null ? photo.ratingCount + 1 : photo.ratingCount,
        viewerRating: rating,
      };
    }));
  }, []);

  const reactToFanPhoto = useCallback((photoId: string, reaction: ReactionType) => {
    setFanPhotos((current) => current.map((photo) => photo.id === photoId
      ? { ...photo, ...toggleReaction(photo.reactions, photo.viewerReaction, reaction) }
      : photo));
  }, []);

  const addFanPhotoComment = useCallback((photoId: string, body: string) => {
    setFanPhotos((current) => current.map((photo) => photo.id === photoId
      ? { ...photo, comments: [...photo.comments, createComment(body)] }
      : photo));
  }, []);

  const reportFanPhoto = useCallback((photoId: string) => {
    setFanPhotos((current) => current.map((photo) => photo.id === photoId ? { ...photo, reported: true } : photo));
  }, []);

  const createEvent = useCallback((input: CreateEventInput) => {
    const id = createLocalId("event");
    setEvents((current) => [{
      id,
      teamId: input.teamId,
      title: input.title.trim(),
      eventType: input.eventType,
      startsAt: input.startsAt,
      location: { ...input.location, label: input.location.label.trim() },
      host: demoUser.username,
      visibility: input.visibility,
      description: input.description.trim(),
      invitedUserIds: [...input.invitedUserIds],
      joinCount: 1,
      joined: true,
      saved: false,
      reported: false,
    }, ...current]);
    return id;
  }, []);

  const toggleEventJoined = useCallback((eventId: string) => {
    setEvents((current) => current.map((event) => event.id === eventId
      ? { ...event, joined: !event.joined, joinCount: Math.max(0, event.joinCount + (event.joined ? -1 : 1)) }
      : event));
  }, []);

  const toggleEventSaved = useCallback((eventId: string) => {
    setEvents((current) => current.map((event) => event.id === eventId ? { ...event, saved: !event.saved } : event));
  }, []);

  const invitePeopleToEvent = useCallback((eventId: string, userIds: readonly string[]) => {
    setEvents((current) => current.map((event) => event.id === eventId
      ? { ...event, invitedUserIds: [...new Set([...event.invitedUserIds, ...userIds])] }
      : event));
  }, []);

  const reportEvent = useCallback((eventId: string) => {
    setEvents((current) => current.map((event) => event.id === eventId ? { ...event, reported: true } : event));
  }, []);

  const createGroup = useCallback((input: CreateGroupInput) => {
    const id = createLocalId("group");
    const threadId = `${id}-thread`;
    setThreads((current) => [{
      id: threadId,
      kind: "group",
      teamId: input.teamId,
      title: input.name.trim(),
      category: "Group",
      creator: demoUser,
      createdAt: new Date().toISOString(),
      priorCommentCount: 0,
      comments: [],
      reactions: emptyReactions(),
      viewerReaction: null,
      reported: false,
    }, ...current]);
    setGroups((current) => [{
      id,
      teamId: input.teamId,
      name: input.name.trim(),
      description: input.description.trim(),
      visibility: input.visibility,
      memberCount: 1,
      joined: true,
      viewerRole: "Owner",
      memberUserIds: [demoUser.id],
      invitedUserIds: [...input.invitedUserIds],
      moderatorUserIds: [],
      latestActivity: new Date().toISOString(),
      threadId,
      reported: false,
    }, ...current]);
    return id;
  }, []);

  const toggleGroupJoined = useCallback((groupId: string) => {
    setGroups((current) => current.map((group) => group.id === groupId
      ? {
          ...group,
          joined: !group.joined,
          viewerRole: group.joined ? null : "Member",
          memberUserIds: group.joined ? group.memberUserIds.filter((id) => id !== demoUser.id) : [...new Set([...group.memberUserIds, demoUser.id])],
          memberCount: Math.max(0, group.memberCount + (group.joined ? -1 : 1)),
        }
      : group));
  }, []);

  const invitePeopleToGroup = useCallback((groupId: string, userIds: readonly string[]) => {
    setGroups((current) => current.map((group) => group.id === groupId
      ? { ...group, invitedUserIds: [...new Set([...group.invitedUserIds, ...userIds])], latestActivity: new Date().toISOString() }
      : group));
  }, []);

  const addGroupModerators = useCallback((groupId: string, userIds: readonly string[]) => {
    setGroups((current) => current.map((group) => {
      if (group.id !== groupId) return group;
      const newMemberIds = userIds.filter((id) => !group.memberUserIds.includes(id));
      return {
        ...group,
        memberUserIds: [...new Set([...group.memberUserIds, ...userIds])],
        moderatorUserIds: [...new Set([...group.moderatorUserIds, ...userIds])],
        invitedUserIds: group.invitedUserIds.filter((id) => !userIds.includes(id)),
        memberCount: group.memberCount + newMemberIds.length,
        latestActivity: new Date().toISOString(),
      };
    }));
  }, []);

  const reportGroup = useCallback((groupId: string) => {
    setGroups((current) => current.map((group) => group.id === groupId ? { ...group, reported: true } : group));
  }, []);

  const voteInPoll = useCallback((pollId: string, optionId: string) => {
    setPolls((current) => current.map((poll) => {
      if (poll.id !== pollId || poll.viewerOptionId !== null || !poll.options.some((option) => option.id === optionId)) return poll;
      return {
        ...poll,
        viewerOptionId: optionId,
        options: poll.options.map((option) => option.id === optionId ? { ...option, voteCount: option.voteCount + 1 } : option),
      };
    }));
  }, []);

  const createPoll = useCallback((input: CreatePollInput) => {
    const id = createLocalId("poll");
    setPolls((current) => [{
      id,
      question: input.question.trim(),
      options: input.options.map((label, index) => ({ id: `${id}-option-${index + 1}`, label: label.trim(), voteCount: 0 })),
      scope: input.scope,
      topics: [...input.topics],
      linkedPreviousPollId: input.linkedPreviousPollId,
      createdBy: demoUser,
      createdAt: new Date().toISOString(),
      recentVotesPerHour: 0,
      viewerOptionId: null,
    }, ...current]);
    return id;
  }, []);

  const value = useMemo<FanbaseContextValue>(() => ({
    threads,
    gameThreads: initialGameThreads,
    fanPhotos,
    events,
    groups,
    polls,
    getArticleThread,
    getArticleCommentCount,
    addArticleComment,
    addComment,
    reactToThread,
    reactToComment,
    reportThread,
    reportComment,
    createLockerRoomThread,
    createFanPhoto,
    rateFanPhoto,
    reactToFanPhoto,
    addFanPhotoComment,
    reportFanPhoto,
    createEvent,
    toggleEventJoined,
    toggleEventSaved,
    invitePeopleToEvent,
    reportEvent,
    createGroup,
    toggleGroupJoined,
    invitePeopleToGroup,
    addGroupModerators,
    reportGroup,
    voteInPoll,
    createPoll,
  }), [
    addArticleComment,
    addComment,
    addFanPhotoComment,
    createEvent,
    createFanPhoto,
    createGroup,
    createLockerRoomThread,
    createPoll,
    events,
    fanPhotos,
    getArticleCommentCount,
    getArticleThread,
    groups,
    polls,
    invitePeopleToEvent,
    invitePeopleToGroup,
    addGroupModerators,
    rateFanPhoto,
    reactToComment,
    reactToFanPhoto,
    reactToThread,
    reportComment,
    reportEvent,
    reportFanPhoto,
    reportGroup,
    reportThread,
    threads,
    toggleEventJoined,
    toggleEventSaved,
    toggleGroupJoined,
    voteInPoll,
  ]);

  return <FanbaseContext.Provider value={value}>{children}</FanbaseContext.Provider>;
}

export function useFanbaseContext() {
  const context = useContext(FanbaseContext);
  if (!context) {
    throw new Error("useFanbaseContext must be used within a FanbaseProvider.");
  }
  return context;
}
