import { fanPhotoImages } from "./fanPhotoAssets";
import type {
  CommunityComment,
  CommunityUser,
  DiscussionThread,
  FanEvent,
  FanGroup,
  FanPhoto,
  ReactionSummary,
} from "./types";

const relativeDate = (hoursFromNow: number) => new Date(Date.now() + hoursFromNow * 60 * 60 * 1000).toISOString();

export const demoUser: CommunityUser = { id: "demo-fan", username: "NorthStarFan", initials: "NF" };

const users = {
  maya: { id: "maya-84", username: "Maya84", initials: "M8" },
  green: { id: "green-line", username: "GreenLine", initials: "GL" },
  fenway: { id: "fenway-faithful", username: "FenwayFaithful", initials: "FF" },
  coach: { id: "coach-view", username: "CoachView", initials: "CV" },
  road: { id: "road-game-rob", username: "RoadGameRob", initials: "RR" },
} as const satisfies Record<string, CommunityUser>;

export const emptyReactions = (): ReactionSummary => ({ Like: 0, Love: 0, Fire: 0, "Mind Blown": 0 });

function comment(
  id: string,
  author: CommunityUser,
  body: string,
  hoursAgo: number,
  reactions: Partial<ReactionSummary> = {},
  parentId: string | null = null,
): CommunityComment {
  return {
    id,
    author,
    body,
    createdAt: relativeDate(-hoursAgo),
    parentId,
    reactions: { ...emptyReactions(), ...reactions },
    viewerReaction: null,
    reported: false,
  };
}

export const initialDiscussionThreads: readonly DiscussionThread[] = [
  {
    id: "article:patriots-camp-tempo",
    kind: "article",
    teamId: "new-england-patriots",
    newsItemId: "patriots-camp-tempo",
    createdAt: relativeDate(-0.4),
    priorCommentCount: 84,
    comments: [
      comment("comment-pats-1", users.coach, "The faster install matters less than how cleanly they communicate when the look changes late.", 0.32, { Like: 8, "Mind Blown": 2 }),
      comment("comment-pats-2", users.maya, "I want to see this pace carry into the red-zone periods next.", 0.18, { Love: 4, Fire: 3 }),
    ],
    reactions: { Like: 42, Love: 18, Fire: 31, "Mind Blown": 7 },
    viewerReaction: null,
    reported: false,
  },
  {
    id: "article:red-sox-bullpen-plan",
    kind: "article",
    teamId: "boston-red-sox",
    newsItemId: "red-sox-bullpen-plan",
    createdAt: relativeDate(-1.6),
    priorCommentCount: 63,
    comments: [comment("comment-sox-1", users.fenway, "Using the best arm in the eighth makes sense when that is where the heart of the order lands.", 1.2, { Like: 12 })],
    reactions: { Like: 35, Love: 9, Fire: 14, "Mind Blown": 3 },
    viewerReaction: null,
    reported: false,
  },
  {
    id: "article:celtics-rotation-options",
    kind: "article",
    teamId: "boston-celtics",
    newsItemId: "celtics-rotation-options",
    createdAt: relativeDate(-2.9),
    priorCommentCount: 107,
    comments: [
      comment("comment-celts-1", users.green, "The second group has enough creation without sacrificing the defensive identity.", 2.4, { Like: 14, Fire: 6 }),
      comment("comment-celts-2", demoUser, "Rebounding will decide whether the smaller look can close games.", 2.1, { Love: 5 }),
    ],
    reactions: { Like: 51, Love: 22, Fire: 48, "Mind Blown": 11 },
    viewerReaction: null,
    reported: false,
  },
  {
    id: "locker-pats-play-action",
    kind: "locker",
    teamId: "new-england-patriots",
    title: "Which play-action package should lead the opening drive?",
    body: "The personnel groupings are starting to take shape. What would you script first?",
    category: "Coaching Tactics",
    creator: users.coach,
    createdAt: relativeDate(-1.1),
    priorCommentCount: 18,
    comments: [comment("locker-pats-comment-1", users.maya, "Start condensed, force the defense to declare, then create the shot outside.", 0.7, { Like: 6 })],
    reactions: { Like: 21, Love: 3, Fire: 8, "Mind Blown": 2 },
    viewerReaction: null,
    reported: false,
  },
  {
    id: "locker-pats-roster",
    kind: "locker",
    teamId: "new-england-patriots",
    title: "The final roster spot nobody is talking about",
    body: "Special teams could decide this one. Make the case for your pick.",
    category: "Roster Talk",
    creator: users.road,
    createdAt: relativeDate(-5),
    priorCommentCount: 37,
    comments: [],
    reactions: { Like: 17, Love: 2, Fire: 11, "Mind Blown": 5 },
    viewerReaction: null,
    reported: false,
  },
  {
    id: "locker-sox-lineup",
    kind: "locker",
    teamId: "boston-red-sox",
    title: "Build your ideal late-game defensive lineup",
    body: "Assume a one-run lead and the bottom third of the order due up.",
    category: "General Team Talk",
    creator: users.fenway,
    createdAt: relativeDate(-3),
    priorCommentCount: 24,
    comments: [],
    reactions: { Like: 15, Love: 4, Fire: 5, "Mind Blown": 1 },
    viewerReaction: null,
    reported: false,
  },
  {
    id: "locker-celtics-bench",
    kind: "locker",
    teamId: "boston-celtics",
    title: "Who anchors the second unit this season?",
    body: "There are several workable combinations. Which one has the best balance?",
    category: "Lineups",
    creator: users.green,
    createdAt: relativeDate(-4),
    priorCommentCount: 41,
    comments: [],
    reactions: { Like: 24, Love: 11, Fire: 13, "Mind Blown": 4 },
    viewerReaction: null,
    reported: false,
  },
  {
    id: "game-pats-jets-thread",
    kind: "game",
    teamId: "new-england-patriots",
    title: "Patriots vs. Jets",
    category: "Game Thread",
    createdAt: relativeDate(-2),
    priorCommentCount: 423,
    comments: [
      comment("game-pats-comment-1", users.road, "The pressure package changed the whole drive.", 0.1, { Fire: 18 }),
      comment("game-pats-comment-2", users.coach, "Watch the safety rotate late—the quarterback has to reset his read after the snap.", 0.16, { Like: 12, "Mind Blown": 4 }),
      comment("game-pats-comment-3", users.maya, "That third-down conversion felt huge. The crowd finally sounds settled in.", 0.23, { Love: 7, Fire: 5 }),
      comment("game-pats-comment-4", users.road, "Exactly. The motion created the leverage before the ball was even snapped.", 0.2, { Like: 5 }, "game-pats-comment-2"),
      comment("game-pats-comment-5", users.green, "Special teams field position is quietly deciding this quarter.", 0.31, { Like: 9 }),
      comment("game-pats-comment-6", users.fenway, "Need one composed drive here—no need to chase the big play on first down.", 0.38, { Like: 6, Fire: 2 }),
    ],
    reactions: { Like: 64, Love: 21, Fire: 87, "Mind Blown": 13 },
    viewerReaction: null,
    reported: false,
  },
  {
    id: "game-pats-next-thread",
    kind: "game",
    teamId: "new-england-patriots",
    title: "Patriots at Bills",
    category: "Game Thread",
    createdAt: relativeDate(-1),
    priorCommentCount: 20,
    comments: [
      comment("game-pats-next-comment-1", users.coach, "The weather could make field position and protection calls the whole story.", 0.6, { Like: 8 }),
      comment("game-pats-next-comment-2", users.road, "Anyone else heading to the road meetup before kickoff?", 0.4, { Love: 4 }),
      comment("game-pats-next-comment-3", users.maya, "I want an aggressive opening script before the noise becomes a factor.", 0.2, { Fire: 6 }),
    ],
    reactions: { Like: 12, Love: 4, Fire: 9, "Mind Blown": 1 },
    viewerReaction: null,
    reported: false,
  },
  {
    id: "game-pats-recent-thread",
    kind: "game",
    teamId: "new-england-patriots",
    title: "Patriots vs. Bills",
    category: "Game Thread",
    createdAt: relativeDate(-18),
    priorCommentCount: 608,
    comments: [
      comment("game-pats-recent-comment-1", users.maya, "After a rewatch, the final drive was much more disciplined than it felt live.", 12.2, { Like: 14 }),
      comment("game-pats-recent-comment-2", users.coach, "The adjustment at halftime opened the middle without abandoning the run.", 12.6, { "Mind Blown": 5, Fire: 7 }),
      comment("game-pats-recent-comment-3", users.road, "Still thinking about that sideline catch. Complete control all the way down.", 13, { Love: 11 }),
      comment("game-pats-recent-comment-4", users.green, "This is the kind of win that looks better when the details settle.", 13.3, { Like: 9 }),
    ],
    reactions: { Like: 83, Love: 19, Fire: 102, "Mind Blown": 24 },
    viewerReaction: null,
    reported: false,
  },
  {
    id: "game-pats-dolphins-thread",
    kind: "game",
    teamId: "new-england-patriots",
    title: "Patriots vs. Dolphins",
    category: "Game Thread",
    createdAt: relativeDate(-72),
    priorCommentCount: 771,
    comments: [
      comment("game-pats-archive-comment-1", users.road, "The archived thread still captures how wild that fourth quarter felt.", 70, { Love: 8 }),
      comment("game-pats-archive-comment-2", users.coach, "The final defensive series remains the cleanest situational work of the game.", 70.4, { Like: 12 }),
      comment("game-pats-archive-comment-3", users.maya, "A stressful one, but a great conversation to revisit.", 71, { Fire: 4 }),
    ],
    reactions: { Like: 92, Love: 26, Fire: 118, "Mind Blown": 31 },
    viewerReaction: null,
    reported: false,
  },
  {
    id: "game-sox-yankees-thread",
    kind: "game",
    teamId: "boston-red-sox",
    title: "Red Sox at Yankees",
    category: "Game Thread",
    createdAt: relativeDate(-1),
    priorCommentCount: 351,
    comments: [],
    reactions: { Like: 55, Love: 17, Fire: 71, "Mind Blown": 19 },
    viewerReaction: null,
    reported: false,
  },
  {
    id: "game-celtics-knicks-thread",
    kind: "game",
    teamId: "boston-celtics",
    title: "Celtics vs. Knicks",
    category: "Game Thread",
    createdAt: relativeDate(-1),
    priorCommentCount: 296,
    comments: [],
    reactions: { Like: 48, Love: 24, Fire: 67, "Mind Blown": 15 },
    viewerReaction: null,
    reported: false,
  },
  {
    id: "group-pats-road-crew-thread",
    kind: "group",
    teamId: "new-england-patriots",
    title: "New England Road Crew",
    category: "Group",
    createdAt: relativeDate(-48),
    priorCommentCount: 76,
    comments: [comment("group-road-1", users.road, "I added the updated meetup point to the trip notes.", 1.4, { Like: 5 })],
    reactions: emptyReactions(),
    viewerReaction: null,
    reported: false,
  },
  {
    id: "group-pats-family-thread",
    kind: "group",
    teamId: "new-england-patriots",
    title: "Sunday Family Huddle",
    category: "Group",
    createdAt: relativeDate(-72),
    priorCommentCount: 28,
    comments: [comment("group-family-1", users.maya, "Picks are due before the early window starts.", 5, { Like: 3 })],
    reactions: emptyReactions(),
    viewerReaction: null,
    reported: false,
  },
  {
    id: "group-pats-film-thread",
    kind: "group",
    teamId: "new-england-patriots",
    title: "Foxborough Film Club",
    category: "Group",
    createdAt: relativeDate(-96),
    priorCommentCount: 143,
    comments: [comment("group-film-1", users.coach, "The third-down cut is posted for tonight's review.", 0.8, { "Mind Blown": 7 })],
    reactions: emptyReactions(),
    viewerReaction: null,
    reported: false,
  },
  {
    id: "group-sox-local-thread",
    kind: "group",
    teamId: "boston-red-sox",
    title: "Fenway Faithful",
    category: "Group",
    createdAt: relativeDate(-120),
    priorCommentCount: 216,
    comments: [comment("group-sox-1", users.fenway, "Two seats just opened in our section for Friday.", 0.6, { Love: 6 })],
    reactions: emptyReactions(),
    viewerReaction: null,
    reported: false,
  },
  {
    id: "group-celtics-green-thread",
    kind: "group",
    teamId: "boston-celtics",
    title: "Green Line Supporters",
    category: "Group",
    createdAt: relativeDate(-144),
    priorCommentCount: 304,
    comments: [comment("group-celts-1", users.green, "Watch-party poll is open through tomorrow.", 0.4, { Fire: 9 })],
    reactions: emptyReactions(),
    viewerReaction: null,
    reported: false,
  },
];

export const initialGameThreads = [
  { id: "game-pats-jets", threadId: "game-pats-jets-thread", teamId: "new-england-patriots", opponent: "New York Jets", venue: "Gillette Stadium", startsAt: relativeDate(-2), endsAt: relativeDate(1) },
  { id: "game-pats-next", threadId: "game-pats-next-thread", teamId: "new-england-patriots", opponent: "Buffalo Bills", venue: "Highmark Stadium", startsAt: relativeDate(30), endsAt: relativeDate(33) },
  { id: "game-pats-recent", threadId: "game-pats-recent-thread", teamId: "new-england-patriots", opponent: "Buffalo Bills", venue: "Gillette Stadium", startsAt: relativeDate(-15), endsAt: relativeDate(-12) },
  { id: "game-pats-archive", threadId: "game-pats-dolphins-thread", teamId: "new-england-patriots", opponent: "Miami Dolphins", venue: "Hard Rock Stadium", startsAt: relativeDate(-76), endsAt: relativeDate(-73) },
  { id: "game-sox-yankees", threadId: "game-sox-yankees-thread", teamId: "boston-red-sox", opponent: "New York Yankees", venue: "Fenway Park", startsAt: relativeDate(8), endsAt: relativeDate(12) },
  { id: "game-celtics-knicks", threadId: "game-celtics-knicks-thread", teamId: "boston-celtics", opponent: "New York Knicks", venue: "TD Garden", startsAt: relativeDate(-4), endsAt: relativeDate(-1) },
] as const;

type FanPhotoSeed = Readonly<{
  id: string;
  teamId: FanPhoto["teamId"];
  owner: CommunityUser;
  category: FanPhoto["category"];
  title: string;
  details: string;
  images: FanPhoto["images"];
  hoursAgo: number;
  ratingTotal: number;
  ratingCount: number;
  reactions?: Partial<ReactionSummary>;
  comments?: readonly CommunityComment[];
  rankingBadge?: FanPhoto["rankingBadge"];
}>;

function fanPhoto(seed: FanPhotoSeed): FanPhoto {
  return {
    id: seed.id,
    teamId: seed.teamId,
    owner: seed.owner,
    category: seed.category,
    title: seed.title,
    details: seed.details,
    images: seed.images,
    createdAt: relativeDate(-seed.hoursAgo),
    ratingTotal: seed.ratingTotal,
    ratingCount: seed.ratingCount,
    viewerRating: null,
    reactions: { ...emptyReactions(), ...seed.reactions },
    viewerReaction: null,
    comments: seed.comments ?? [],
    ...(seed.rankingBadge ? { rankingBadge: seed.rankingBadge } : {}),
    reported: false,
  };
}

export const initialFanPhotos: readonly FanPhoto[] = [
  fanPhoto({ id: "photo-pats-game-face", teamId: "new-england-patriots", owner: users.maya, category: "Game Face", title: "Ready before sunrise", details: "The full game-day look was ready before the first tailgate grill fired up.", images: [fanPhotoImages.gameFaceAsu], hoursAgo: 20, ratingTotal: 226, ratingCount: 51, reactions: { Like: 32, Love: 18, Fire: 24, "Mind Blown": 4 }, comments: [comment("photo-pats-comment", users.road, "That is game-day commitment.", 16, { Fire: 5 })], rankingBadge: "Top 10" }),
  fanPhoto({ id: "photo-pats-game-face-stands", teamId: "new-england-patriots", owner: demoUser, category: "Game Face", title: "All in from the stands", details: "A favorite crowd shot from a rivalry weekend that turned into an instant tradition.", images: [fanPhotoImages.gameFaceStands], hoursAgo: 8, ratingTotal: 169, ratingCount: 39, reactions: { Like: 21, Love: 12, Fire: 17 } }),
  fanPhoto({ id: "photo-pats-game-face-bucs", teamId: "new-england-patriots", owner: users.coach, category: "Game Face", title: "Built for kickoff", details: "The outfit takes longer to assemble than the drive to the stadium.", images: [fanPhotoImages.gameFaceBucs], hoursAgo: 30, ratingTotal: 286, ratingCount: 64, reactions: { Like: 41, Love: 19, Fire: 35, "Mind Blown": 8 }, rankingBadge: "Top 50" }),
  fanPhoto({ id: "photo-pats-game-face-pair", teamId: "new-england-patriots", owner: users.road, category: "Game Face", title: "Double coverage", details: "Two longtime seat neighbors, one coordinated game-day plan.", images: [fanPhotoImages.gameFaceEaglesPair], hoursAgo: 54, ratingTotal: 190, ratingCount: 44, reactions: { Like: 24, Love: 20, Fire: 14 } }),
  fanPhoto({ id: "photo-pats-game-face-solo", teamId: "new-england-patriots", owner: demoUser, category: "Game Face", title: "The lucky game-day fit", details: "Every layer has a story, and none of it gets washed during a winning streak.", images: [fanPhotoImages.gameFaceEagles], hoursAgo: 72, ratingTotal: 247, ratingCount: 56, reactions: { Like: 30, Love: 26, Fire: 22 }, rankingBadge: "Top 100" }),
  fanPhoto({ id: "photo-sox-game-face", teamId: "boston-red-sox", owner: users.fenway, category: "Game Face", title: "Road-game character", details: "A full crowd-ready look built one season at a time.", images: [fanPhotoImages.gameFaceRaiders], hoursAgo: 41, ratingTotal: 231, ratingCount: 52, reactions: { Like: 37, Fire: 29 }, rankingBadge: "Top 50" }),
  fanPhoto({ id: "photo-celtics-game-face", teamId: "boston-celtics", owner: users.green, category: "Game Face", title: "Game Face from head to toe", details: "Playoff-night colors from the lucky scarf to the sneakers.", images: [fanPhotoImages.gameFaceSeahawks], hoursAgo: 26, ratingTotal: 248, ratingCount: 55, reactions: { Like: 44, Love: 31, Fire: 28, "Mind Blown": 6 }, rankingBadge: "Top 10" }),
  fanPhoto({ id: "photo-pats-game-face-vikings", teamId: "new-england-patriots", owner: users.maya, category: "Game Face", title: "Sunday alter ego", details: "The character only appears on game day—and never misses kickoff.", images: [fanPhotoImages.gameFaceVikings], hoursAgo: 91, ratingTotal: 151, ratingCount: 35, reactions: { Like: 18, Love: 9, Fire: 16 } }),

  fanPhoto({ id: "photo-pats-fan-cave", teamId: "new-england-patriots", owner: demoUser, category: "Fan Cave", title: "Sunday film room", details: "Multiple screens, old stadium seats, and years of carefully lit memorabilia.", images: [fanPhotoImages.fanCaveFootball], hoursAgo: 44, ratingTotal: 269, ratingCount: 61, reactions: { Like: 38, Love: 22, Fire: 19, "Mind Blown": 13 }, rankingBadge: "Top 10" }),
  fanPhoto({ id: "photo-pats-fan-cave-collection", teamId: "new-england-patriots", owner: users.coach, category: "Fan Cave", title: "Wall-to-wall football history", details: "A basement project that became a living archive of memorable seasons.", images: [fanPhotoImages.fanCaveGiants], hoursAgo: 63, ratingTotal: 176, ratingCount: 42, reactions: { Like: 28, Love: 16, "Mind Blown": 9 } }),
  fanPhoto({ id: "photo-pats-fan-cave-hockey", teamId: "new-england-patriots", owner: users.road, category: "Fan Cave", title: "The blue-line room", details: "Framed keepsakes and a front-row seat for every broadcast.", images: [fanPhotoImages.fanCaveOilers], hoursAgo: 77, ratingTotal: 244, ratingCount: 56, reactions: { Like: 31, Love: 20, Fire: 12 }, rankingBadge: "Top 50" }),
  fanPhoto({ id: "photo-sox-fan-cave", teamId: "boston-red-sox", owner: users.fenway, category: "Fan Cave", title: "The hometown corner", details: "Scorecards, caps, and a radio that still calls every game.", images: [fanPhotoImages.fanCavePackers], hoursAgo: 31, ratingTotal: 211, ratingCount: 48, reactions: { Like: 38, Love: 25, Fire: 11, "Mind Blown": 4 } }),
  fanPhoto({ id: "photo-pats-fan-cave-pool", teamId: "new-england-patriots", owner: users.maya, category: "Fan Cave", title: "Halftime at the pool table", details: "Part watch room, part friendly competition, always ready for a crowd.", images: [fanPhotoImages.fanCavePool], hoursAgo: 18, ratingTotal: 140, ratingCount: 33, reactions: { Like: 17, Love: 12, Fire: 8 } }),
  fanPhoto({ id: "photo-celtics-fan-cave", teamId: "boston-celtics", owner: users.green, category: "Fan Cave", title: "A room for every era", details: "The collection grew until the room became part museum and part watch party.", images: [fanPhotoImages.fanCaveCommanders], hoursAgo: 58, ratingTotal: 225, ratingCount: 51, reactions: { Like: 29, Love: 18, "Mind Blown": 11 }, rankingBadge: "Top 100" }),
  fanPhoto({ id: "photo-pats-fan-cave-jerseys", teamId: "new-england-patriots", owner: demoUser, category: "Fan Cave", title: "Jerseys tell the story", details: "Every wall marks a different favorite season and a different game-day memory.", images: [fanPhotoImages.fanCaveToronto], hoursAgo: 102, ratingTotal: 193, ratingCount: 45, reactions: { Like: 23, Love: 21, Fire: 7 } }),

  fanPhoto({ id: "photo-pats-mask", teamId: "new-england-patriots", owner: demoUser, category: "Memorabilia", title: "Four views of a handmade mask", details: "A custom-painted display piece photographed from every side. All four images belong to this one FANfoto entry.", images: [fanPhotoImages.memorabiliaMaskFront, fanPhotoImages.memorabiliaMaskSide, fanPhotoImages.memorabiliaMaskBack, fanPhotoImages.memorabiliaMaskDetail], hoursAgo: 11, ratingTotal: 278, ratingCount: 62, reactions: { Like: 36, Love: 25, Fire: 31, "Mind Blown": 17 }, comments: [comment("photo-mask-comment", users.coach, "The detail work around the sides is incredible.", 7, { "Mind Blown": 6 })], rankingBadge: "Top 10" }),
  fanPhoto({ id: "photo-pats-opening-ticket", teamId: "new-england-patriots", owner: users.road, category: "Memorabilia", title: "Opening-night metal ticket", details: "A weighty keepsake that brings back the energy of a building's first regular-season game.", images: [fanPhotoImages.memorabiliaOpeningNight], hoursAgo: 68, ratingTotal: 197, ratingCount: 46, reactions: { Like: 29, Love: 21, Fire: 8, "Mind Blown": 3 } }),
  fanPhoto({ id: "photo-pats-goalie-mask", teamId: "new-england-patriots", owner: users.maya, category: "Memorabilia", title: "Signed miniature mask", details: "A small shelf piece with a signature that still looks fresh.", images: [fanPhotoImages.memorabiliaGoalieMask], hoursAgo: 83, ratingTotal: 216, ratingCount: 50, reactions: { Like: 24, Love: 16, Fire: 9 }, rankingBadge: "Top 100" }),
  fanPhoto({ id: "photo-pats-golf-bag", teamId: "new-england-patriots", owner: demoUser, category: "Memorabilia", title: "Miniature golf bag collectible", details: "An unusual team crossover that always gets a second look on the display shelf.", images: [fanPhotoImages.memorabiliaGolfBag], hoursAgo: 36, ratingTotal: 123, ratingCount: 29, reactions: { Like: 16, Love: 8, "Mind Blown": 5 } }),
  fanPhoto({ id: "photo-sox-farewell-set", teamId: "boston-red-sox", owner: users.fenway, category: "Memorabilia", title: "Farewell-night archive", details: "Ticket, attendance certificate, and commemorative piece kept together as one story.", images: [fanPhotoImages.memorabiliaFarewell], hoursAgo: 112, ratingTotal: 262, ratingCount: 59, reactions: { Like: 30, Love: 33, Fire: 8 }, rankingBadge: "Top 50" }),
  fanPhoto({ id: "photo-pats-jersey-history", teamId: "new-england-patriots", owner: users.coach, category: "Memorabilia", title: "A history told in jerseys", details: "Framed artwork that tracks the team's look across decades.", images: [fanPhotoImages.memorabiliaJerseyHistory], hoursAgo: 125, ratingTotal: 171, ratingCount: 40, reactions: { Like: 18, Love: 14, "Mind Blown": 7 } }),
  fanPhoto({ id: "photo-celtics-banner-night", teamId: "boston-celtics", owner: users.green, category: "Memorabilia", title: "Banner-night display", details: "A framed record of championship seasons and the nights they were celebrated.", images: [fanPhotoImages.memorabiliaBannerNight], hoursAgo: 141, ratingTotal: 301, ratingCount: 67, reactions: { Like: 42, Love: 31, Fire: 20, "Mind Blown": 15 }, rankingBadge: "Top 10" }),
  fanPhoto({ id: "photo-pats-framed-stars", teamId: "new-england-patriots", owner: users.road, category: "Memorabilia", title: "Two generations in one frame", details: "A carefully assembled tribute to the stars who defined different eras.", images: [fanPhotoImages.memorabiliaFramedStars], hoursAgo: 97, ratingTotal: 235, ratingCount: 53, reactions: { Like: 29, Love: 27, Fire: 11 }, rankingBadge: "Top 50" }),
  fanPhoto({ id: "photo-pats-season-cards", teamId: "new-england-patriots", owner: demoUser, category: "Memorabilia", title: "A decade of season cards", details: "Kept in one place, these cards make the passage of seasons feel tangible.", images: [fanPhotoImages.memorabiliaSeasonCards], hoursAgo: 49, ratingTotal: 156, ratingCount: 37, reactions: { Like: 19, Love: 17, Fire: 4 } }),
  fanPhoto({ id: "photo-pats-gretzky-card", teamId: "new-england-patriots", owner: users.maya, category: "Memorabilia", title: "The card at the center of the collection", details: "Protected from day one and still the first piece visitors ask to see.", images: [fanPhotoImages.memorabiliaGretzkyCard], hoursAgo: 155, ratingTotal: 284, ratingCount: 63, reactions: { Like: 37, Love: 24, Fire: 16, "Mind Blown": 12 }, rankingBadge: "Top 50" }),
  fanPhoto({ id: "photo-celtics-championship-banners", teamId: "boston-celtics", owner: demoUser, category: "Memorabilia", title: "Championship banners at home", details: "A compact framed collection honoring every title year.", images: [fanPhotoImages.memorabiliaChampionshipBanners], hoursAgo: 88, ratingTotal: 183, ratingCount: 43, reactions: { Like: 20, Love: 22, Fire: 9 } }),
];

export const initialEvents: readonly FanEvent[] = [
  { id: "event-pats-watch", teamId: "new-england-patriots", title: "Opening Night Watch Party", eventType: "Watch Party", startsAt: relativeDate(72), location: "Harbor Street Social · Boston", host: "Boston North Fans", visibility: "Public", description: "Big screens, reserved FANatical section, and a pregame prediction board.", joinCount: 84, joined: false, saved: false, reported: false },
  { id: "event-pats-meetup", teamId: "new-england-patriots", title: "Road Crew Planning Meetup", eventType: "Meetup", startsAt: relativeDate(124), location: "Online", host: "New England Road Crew", visibility: "Private", description: "Coordinate travel, tickets, and the group tailgate for the next away game.", joinCount: 26, joined: true, saved: true, reported: false },
  { id: "event-sox-rivalry", teamId: "boston-red-sox", title: "Rivalry Series Patio Night", eventType: "Rivalry Event", startsAt: relativeDate(48), location: "Back Bay Baseball Club", host: "Fenway Faithful", visibility: "Public", description: "A three-inning trivia sprint before first pitch and a shared game watch.", joinCount: 119, joined: false, saved: false, reported: false },
  { id: "event-celtics-online", teamId: "boston-celtics", title: "Rotation Roundtable", eventType: "Online", startsAt: relativeDate(36), location: "Online", host: "Green Line Supporters", visibility: "Public", description: "A casual video meetup to compare lineup ideas before the season starts.", joinCount: 63, joined: false, saved: true, reported: false },
];

export const initialGroups: readonly FanGroup[] = [
  { id: "group-pats-road-crew", teamId: "new-england-patriots", name: "New England Road Crew", description: "Away-game travel plans, ticket tips, and meetup coordination.", visibility: "Public", memberCount: 318, joined: true, latestActivity: relativeDate(-1.4), threadId: "group-pats-road-crew-thread", reported: false },
  { id: "group-pats-family", teamId: "new-england-patriots", name: "Sunday Family Huddle", description: "A small private group for family picks and game-day photos.", visibility: "Private", memberCount: 9, joined: true, latestActivity: relativeDate(-5), threadId: "group-pats-family-thread", reported: false },
  { id: "group-pats-film", teamId: "new-england-patriots", name: "Foxborough Film Club", description: "Public weekly breakdowns without the hot-take noise.", visibility: "Public", memberCount: 542, joined: false, latestActivity: relativeDate(-0.8), threadId: "group-pats-film-thread", reported: false },
  { id: "group-sox-local", teamId: "boston-red-sox", name: "Fenway Faithful", description: "Local game talk and last-minute meetup planning.", visibility: "Public", memberCount: 741, joined: false, latestActivity: relativeDate(-0.6), threadId: "group-sox-local-thread", reported: false },
  { id: "group-celtics-green", teamId: "boston-celtics", name: "Green Line Supporters", description: "City-wide Celtics chat, events, and road-game watches.", visibility: "Public", memberCount: 886, joined: true, latestActivity: relativeDate(-0.4), threadId: "group-celtics-green-thread", reported: false },
];
