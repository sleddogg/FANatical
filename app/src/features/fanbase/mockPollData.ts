import { demoUser } from "./mockFanbaseData";
import type { FanPoll, PollScope } from "./types";

const hoursAgo = (hours: number) => new Date(Date.now() - hours * 3_600_000).toISOString();

function mockPoll(input: {
  id: string;
  question: string;
  options: readonly string[];
  scope: PollScope;
  topics: readonly string[];
  hoursOld: number;
  velocity: number;
  baseVotes: number;
  linkedPreviousPollId?: string;
  viewerOptionIndex?: number;
}): FanPoll {
  return {
    id: input.id,
    question: input.question,
    options: input.options.map((label, index) => ({
      id: `${input.id}-option-${index + 1}`,
      label,
      voteCount: input.baseVotes + ((index * 17 + input.id.length * 3) % 61),
    })),
    scope: input.scope,
    topics: input.topics,
    linkedPreviousPollId: input.linkedPreviousPollId ?? null,
    createdBy: demoUser,
    createdAt: hoursAgo(input.hoursOld),
    recentVotesPerHour: input.velocity,
    viewerOptionId: input.viewerOptionIndex === undefined ? null : `${input.id}-option-${input.viewerOptionIndex + 1}`,
  };
}

const patriotsScope = { kind: "team", sportId: "football", leagueId: "football-nfl", teamId: "football-nfl-new-england-patriots" } as const satisfies PollScope;
const redSoxScope = { kind: "team", sportId: "baseball", leagueId: "baseball-mlb", teamId: "baseball-mlb-boston-red-sox" } as const satisfies PollScope;
const oilersScope = { kind: "team", sportId: "hockey", leagueId: "hockey-nhl", teamId: "hockey-nhl-edmonton-oilers" } as const satisfies PollScope;
const hockeyScope = { kind: "sport", sportId: "hockey", leagueId: null, teamId: null } as const satisfies PollScope;
const nhlScope = { kind: "league", sportId: "hockey", leagueId: "hockey-nhl", teamId: null } as const satisfies PollScope;
const footballScope = { kind: "sport", sportId: "football", leagueId: null, teamId: null } as const satisfies PollScope;

const patriotsQuestions = [
  ["Which unit will define the Patriots' season?", ["Offense", "Defense", "Special teams", "Coaching"]],
  ["Which offensive identity should New England lean into?", ["Power run", "Quick passing", "Play action", "Balanced attack"]],
  ["What matters most in the next divisional matchup?", ["Protect the ball", "Win third down", "Pressure the quarterback", "Field position"]],
  ["Who deserves more snaps this week?", ["Young receivers", "Pass rushers", "Backup backs", "Extra tight ends"]],
  ["Which home-game tradition brings the most energy?", ["Player introductions", "Third-down noise", "Touchdown celebration", "Fourth-quarter rally"]],
  ["What should be the draft-day priority?", ["Offensive line", "Receiver", "Cornerback", "Edge rusher"]],
  ["Which phase improved most this month?", ["Run game", "Pass defense", "Red zone", "Special teams"]],
  ["What is the toughest remaining road game?", ["Division rival", "Prime-time game", "Short-week trip", "Cold-weather matchup"]],
  ["Which game-day factor creates the biggest edge?", ["Crowd noise", "Weather", "Preparation", "Turnovers"]],
  ["What should lead the opening drive?", ["Deep shot", "Screen pass", "Play action", "Power run"]],
  ["Which defensive look should appear more often?", ["Heavy front", "Nickel", "Man coverage", "Disguised zone"]],
  ["How confident are you in the playoff push?", ["Very confident", "Cautiously optimistic", "Need to see more", "Long shot"]],
] as const;

const patriotsPolls = patriotsQuestions.map(([question, options], index) => mockPoll({
  id: `poll-patriots-${index + 1}`,
  question,
  options,
  scope: patriotsScope,
  topics: ["patriots", "football", index % 2 ? "game-day" : "team-direction"],
  hoursOld: index === 10 ? 24 * 20 : index * 8 + 2,
  velocity: index === 10 ? 8 : Math.max(1, 24 - index * 1.5),
  baseVotes: 80 + index * 13,
  ...(index === 11 ? { viewerOptionIndex: 1 } : {}),
}));

export const initialPolls: readonly FanPoll[] = [
  ...patriotsPolls,
  mockPoll({ id: "poll-red-sox-lineup", question: "Which lineup trait matters most for the Red Sox down the stretch?", options: ["On-base rate", "Power", "Speed", "Depth"], scope: redSoxScope, topics: ["red sox", "lineup", "playoffs"], hoursOld: 7, velocity: 14, baseVotes: 118 }),
  mockPoll({ id: "poll-red-sox-fenway", question: "What is the best part of a night game at Fenway?", options: ["The atmosphere", "The history", "The view", "The traditions"], scope: redSoxScope, topics: ["red sox", "fenway", "game-day"], hoursOld: 36, velocity: 5, baseVotes: 210 }),
  mockPoll({ id: "poll-oilers-offseason-old", question: "How did the Oilers do this offseason?", options: ["Excellent", "Good", "Mixed", "Needs work"], scope: oilersScope, topics: ["oilers", "offseason", "roster"], hoursOld: 24 * 90, velocity: 0.2, baseVotes: 620, viewerOptionIndex: 1 }),
  mockPoll({ id: "poll-oilers-offseason-followup", question: "Three months later, how do you feel about those Oilers offseason moves?", options: ["Better than before", "About the same", "More concerned", "Still undecided"], scope: oilersScope, topics: ["oilers", "offseason", "roster", "follow-up"], hoursOld: 4, velocity: 26, baseVotes: 175, linkedPreviousPollId: "poll-oilers-offseason-old" }),
  mockPoll({ id: "poll-oilers-power-play", question: "What should the Oilers prioritize on the next power play?", options: ["More movement", "Shoot sooner", "Net-front traffic", "Work below the goal line"], scope: oilersScope, topics: ["oilers", "power play", "strategy"], hoursOld: 12, velocity: 18, baseVotes: 130 }),
  mockPoll({ id: "poll-hockey-overtime", question: "What is the best regular-season overtime format for hockey?", options: ["Keep 3-on-3", "Longer 3-on-3", "Go directly to shootout", "Bring back ties"], scope: hockeyScope, topics: ["hockey", "overtime", "rules"], hoursOld: 18, velocity: 21, baseVotes: 450 }),
  mockPoll({ id: "poll-hockey-goalie", question: "Which goalie skill is hardest to teach?", options: ["Positioning", "Rebound control", "Puck tracking", "Playing the puck"], scope: hockeyScope, topics: ["hockey", "goalies", "skills"], hoursOld: 80, velocity: 4, baseVotes: 190 }),
  mockPoll({ id: "poll-nhl-playoff-format", question: "Should the NHL change its playoff format?", options: ["Keep it", "Return to 1–8", "Division winners plus wild cards", "Expand the field"], scope: nhlScope, topics: ["nhl", "playoffs", "format"], hoursOld: 6, velocity: 29, baseVotes: 740 }),
  mockPoll({ id: "poll-nhl-expansion", question: "What should matter most in future NHL expansion?", options: ["Market demand", "Arena readiness", "Geography", "Ownership strength"], scope: nhlScope, topics: ["nhl", "expansion", "cities"], hoursOld: 55, velocity: 9, baseVotes: 520 }),
  mockPoll({ id: "poll-football-replay", question: "Which part of football replay needs the clearest standard?", options: ["Catch rules", "Pass interference", "Spotting the ball", "Quarterback contact"], scope: footballScope, topics: ["football", "replay", "rules"], hoursOld: 30, velocity: 11, baseVotes: 350 }),
];
