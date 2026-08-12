import backboardLeftImage from "../../../../reference/cheer/backboardleft.png";
import backboardRightImage from "../../../../reference/cheer/backboardright.png";
import baseballRoutingReference from "../../../../reference/cheer/baseball routing.png";
import sideEndRoutingReference from "../../../../reference/cheer/side and end routing.png";
import upperLowerRoutingReference from "../../../../reference/cheer/upper lower routing.png";
import uprightLeftImage from "../../../../reference/cheer/uprightleft.png";
import uprightRightImage from "../../../../reference/cheer/uprightright.png";
import baseballFirstBaseImage from "../../../../reference/cheer/routing/baseball first base side.png";
import baseballOutfieldImage from "../../../../reference/cheer/routing/baseball outfield.png";
import baseballSideAImage from "../../../../reference/cheer/routing/baseball side A.png";
import baseballSideBImage from "../../../../reference/cheer/routing/baseball side B.png";
import baseballThirdBaseImage from "../../../../reference/cheer/routing/baseball third base side.png";
import basketballEndAImage from "../../../../reference/cheer/routing/basketball end A.png";
import basketballEndBImage from "../../../../reference/cheer/routing/basketball end B.png";
import basketballSideAImage from "../../../../reference/cheer/routing/basketball side A.png";
import basketballSideBImage from "../../../../reference/cheer/routing/basketball side B.png";
import lowerImage from "../../../../reference/cheer/routing/crowd lower.png";
import footballSideAImage from "../../../../reference/cheer/routing/ChatGPT Image Aug 11, 2026, 10_23_53 PM.png";
import footballSideBImage from "../../../../reference/cheer/routing/ChatGPT Image Aug 11, 2026, 10_24_00 PM.png";
import footballEndAImage from "../../../../reference/cheer/routing/ChatGPT Image Aug 11, 2026, 10_24_06 PM.png";
import footballEndBImage from "../../../../reference/cheer/routing/ChatGPT Image Aug 11, 2026, 10_24_11 PM.png";
import hockeyEndAImage from "../../../../reference/cheer/routing/hockey end A.png";
import hockeyEndBImage from "../../../../reference/cheer/routing/hockey end B.png";
import hockeySideAImage from "../../../../reference/cheer/routing/hockey side A.png";
import hockeySideBImage from "../../../../reference/cheer/routing/hockey side B.png";
import soccerEndAImage from "../../../../reference/cheer/routing/soccer end A.png";
import soccerEndBImage from "../../../../reference/cheer/routing/soccer end B.png";
import soccerSideAImage from "../../../../reference/cheer/routing/soccer side A.png";
import soccerSideBImage from "../../../../reference/cheer/routing/soccer side B.png";
import upperImage from "../../../../reference/cheer/routing/crowd upper.png";
import type { CheerSport, CrowdAssignment } from "./types";

const universalAudiences = ["All", "Upper", "Lower"] as const satisfies readonly CrowdAssignment[];
const sideEndAudiences = ["Side A", "Side B", "End A", "End B"] as const satisfies readonly CrowdAssignment[];

const sportAudiences: Readonly<Record<CheerSport, readonly CrowdAssignment[]>> = {
  Soccer: [...universalAudiences, ...sideEndAudiences],
  Hockey: [...universalAudiences, ...sideEndAudiences],
  Basketball: [...universalAudiences, ...sideEndAudiences, "Backboard Left", "Backboard Right"],
  Football: [...universalAudiences, ...sideEndAudiences, "Uprights Left", "Uprights Right"],
  Baseball: [...universalAudiences, "Side A", "Side B", "First Base Side", "Third Base Side", "Outfield"],
  Other: universalAudiences,
};

const universalImages: Partial<Record<CrowdAssignment, string>> = {
  Upper: upperImage,
  Lower: lowerImage,
};

const sportImages: Readonly<Record<CheerSport, Partial<Record<CrowdAssignment, string>>>> = {
  Soccer: { "Side A": soccerSideAImage, "Side B": soccerSideBImage, "End A": soccerEndAImage, "End B": soccerEndBImage },
  Hockey: { "Side A": hockeySideAImage, "Side B": hockeySideBImage, "End A": hockeyEndAImage, "End B": hockeyEndBImage },
  Basketball: { "Side A": basketballSideAImage, "Side B": basketballSideBImage, "End A": basketballEndAImage, "End B": basketballEndBImage, "Backboard Left": backboardLeftImage, "Backboard Right": backboardRightImage },
  Football: { "Side A": footballSideAImage, "Side B": footballSideBImage, "End A": footballEndAImage, "End B": footballEndBImage, "Uprights Left": uprightLeftImage, "Uprights Right": uprightRightImage },
  Baseball: { "Side A": baseballSideAImage, "Side B": baseballSideBImage, "First Base Side": baseballFirstBaseImage, "Third Base Side": baseballThirdBaseImage, Outfield: baseballOutfieldImage },
  Other: {},
};

export function cheerAudienceOptions(sport: CheerSport): readonly CrowdAssignment[] {
  return sportAudiences[sport];
}

export function cheerAudienceImage(audience: CrowdAssignment, sport: CheerSport) {
  return universalImages[audience] ?? sportImages[sport][audience] ?? null;
}

export function migrateLegacyAudience(audience: CrowdAssignment, sport: CheerSport): CrowdAssignment {
  if (audience !== "North" && audience !== "South" && audience !== "East" && audience !== "West") return audience;
  if (sport === "Other") return "All";
  if (sport === "Baseball") {
    if (audience === "East") return "First Base Side";
    if (audience === "West") return "Third Base Side";
    return audience === "North" ? "Outfield" : "All";
  }
  if (audience === "North") return "Side A";
  if (audience === "South") return "Side B";
  return audience === "West" ? "End A" : "End B";
}

export const cheerRoutingReferences = [
  { image: sideEndRoutingReference, title: "Side and End routing", description: "Side A and Side B divide the venue along the playing surface’s long sides. End A and End B divide it across the opposite axis." },
  { image: upperLowerRoutingReference, title: "Upper and Lower routing", description: "Upper and Lower divide the seating bowl by level." },
  { image: baseballRoutingReference, title: "Baseball routing", description: "Baseball adds First Base Side, Third Base Side, and Outfield routes alongside Side A and Side B." },
] as const;

export const cheerSportAudienceLegend = [
  { image: backboardLeftImage, title: "Backboard Left", context: "Basketball · fans behind the left backboard" },
  { image: backboardRightImage, title: "Backboard Right", context: "Basketball · fans behind the right backboard" },
  { image: uprightLeftImage, title: "Uprights Left", context: "Football · fans behind the left uprights" },
  { image: uprightRightImage, title: "Uprights Right", context: "Football · fans behind the right uprights" },
] as const;
