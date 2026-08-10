import { demoUser } from "../fanbase/mockFanbaseData";
import type { FanMoment, ProfileRecord, ProfileStat, Trophy } from "./types";

export const initialProfile: ProfileRecord = {
  id: demoUser.id,
  displayName: demoUser.username,
  handle: `@${demoUser.username}`,
  tagline: "Home teams, road trips, and every story in between.",
  featuredFanPhotoCategory: "Fan Cave",
  bio: [
    { id: "fanatical-name", label: "FANatical name", value: "North Star" },
    { id: "given-name", label: "Given name", value: "Alex Mercer" },
    { id: "nickname", label: "Nickname", value: "Sleddogg" },
    { id: "birthplace", label: "Birthplace", value: "Edmonton, Alberta" },
    { id: "jersey-number", label: "Jersey number", value: "12" },
    { id: "height", label: "Height", value: "5′ 11″" },
    { id: "weight", label: "Weight", value: "" },
  ],
  fanIdentity: [
    { id: "primary-team", label: "Primary team", value: "New England Patriots" },
    { id: "fan-since", label: "Fan since", value: "1996" },
    { id: "secondary-teams", label: "Other teams", value: "Boston Red Sox · Boston Celtics" },
    { id: "favorite-players", label: "Favorite players", value: "Tom Brady · David Ortiz · Larry Bird" },
    { id: "game-day-ritual", label: "Game-day ritual", value: "Same lucky jersey, coffee before kickoff, no seat changes after a score." },
    { id: "superstition", label: "Fan superstition", value: "The rally cap stays on until the final out." },
  ],
  sportsPlayed: [
    { id: "hockey", sport: "Hockey", position: "Left wing", level: "Community league", years: "2002–2012", highlight: "Three-time winter tournament finalist" },
    { id: "football", sport: "Football", position: "Safety", level: "High school", years: "2007–2010", highlight: "Defensive player of the year, 2010" },
    { id: "softball", sport: "Softball", position: "Shortstop", level: "Recreational", years: "2018–present", highlight: "Summer league champion, 2024" },
  ],
};

export const profileStats: readonly ProfileStat[] = [
  { label: "Streak", value: "19 days", detail: "Personal best: 43" },
  { label: "Tier", value: "All-Pro", detail: "1,240 to Elite" },
  { label: "Fan Score", value: "18,460", detail: "+380 this week" },
  { label: "Fan Coins", value: "2,875", detail: "Available balance" },
  { label: "Rank", value: "#184", detail: "Top 4% of fans" },
  { label: "Engagement", value: "92%", detail: "Very active" },
];

export const profileTrophies: readonly Trophy[] = [
  { id: "founding-fan", name: "Founding Fan", description: "Joined FANatical during the early access season.", icon: "F", status: "earned", earnedAt: "May 2025" },
  { id: "road-warrior", name: "Road Warrior", description: "Shared stories from five away games.", icon: "↗", status: "earned", earnedAt: "Oct 2025" },
  { id: "photo-finish", name: "Photo Finish", description: "Earned a Top 10 FANfoto ranking.", icon: "▧", status: "earned", earnedAt: "Feb 2026" },
  { id: "conversation-starter", name: "Conversation Starter", description: "Started 25 community conversations.", icon: "◇", status: "progress", progress: 72 },
  { id: "perfect-ten", name: "Perfect Ten", description: "Score 100% on ten quizzes.", icon: "10", status: "progress", progress: 40 },
  { id: "superfan", name: "Superfan Season", description: "Maintain a 100-day activity streak.", icon: "★", status: "locked" },
  { id: "collector", name: "Curator", description: "Share 20 memorabilia stories.", icon: "C", status: "locked" },
  { id: "captain", name: "Team Captain", description: "Help a FANbase group reach 250 members.", icon: "◆", status: "locked" },
];

export const profileMoments: readonly FanMoment[] = [
  {
    id: "mask-story",
    title: "The mask that started the collection",
    type: "Memory",
    dateOccurred: "2026-02-03",
    createdAt: "2026-02-04T18:20:00.000Z",
    story: "I found this hand-painted mask at a tiny winter market. Four road trips later, it still comes with me whenever the Patriots play under the lights.",
    location: "Boston Winter Market",
    eventContext: "Rivalry weekend",
    fanPhotoId: "photo-pats-mask",
  },
  {
    id: "championship-banners",
    title: "A night beneath the banners",
    type: "Game day",
    dateOccurred: "2026-01-18",
    createdAt: "2026-01-20T03:10:00.000Z",
    story: "My dad pointed out every Celtics banner before tipoff and told me where he was when each one was won. The game was great; that conversation was better.",
    location: "TD Garden · Boston",
    eventContext: "Celtics home game",
    fanPhotoId: "photo-celtics-championship-banners",
  },
  {
    id: "first-road-game",
    title: "First road game with the crew",
    type: "Road trip",
    dateOccurred: "2025-10-12",
    createdAt: "2025-10-14T22:45:00.000Z",
    story: "Six fans, one borrowed van, and a playlist that lasted across two borders. We lost our voices before halftime and made friends in every row around us.",
    location: "Highmark Stadium · Orchard Park",
    eventContext: "Patriots at Bills",
  },
];
