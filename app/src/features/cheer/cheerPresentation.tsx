import backboardLeftImage from "../../../../reference/cheer/backboardleft.png";
import backboardRightImage from "../../../../reference/cheer/backboardright.png";
import uprightLeftImage from "../../../../reference/cheer/uprightleft.png";
import uprightRightImage from "../../../../reference/cheer/uprightright.png";
import type { CheerAction, CheerDuration, CheerTimingType, CrowdAssignment } from "./types";

const noteSymbols: Readonly<Record<CheerDuration, string>> = {
  Whole: "𝅝", "Dotted Half": "𝅗𝅥·", Half: "𝅗𝅥", Quarter: "♩", Eighth: "♪", Sixteenth: "𝅘𝅥𝅯",
};

const restSymbols: Readonly<Record<CheerDuration, string>> = {
  Whole: "𝄻", "Dotted Half": "𝄼·", Half: "𝄼", Quarter: "𝄽", Eighth: "𝄾", Sixteenth: "𝄿",
};

const actionIcons: Readonly<Record<CheerAction, string>> = { Clap: "👏", Stomp: "🦶", Wave: "🌊", None: "—" };

export function cheerDurationSymbol(duration: CheerDuration, timingType: CheerTimingType) {
  return timingType === "Rest" ? restSymbols[duration] : noteSymbols[duration];
}

export function cheerActionIcon(action: CheerAction) {
  return actionIcons[action];
}

export function cheerAudienceImage(audience: CrowdAssignment) {
  if (audience === "Backboard Left") return backboardLeftImage;
  if (audience === "Backboard Right") return backboardRightImage;
  if (audience === "Uprights Left") return uprightLeftImage;
  if (audience === "Uprights Right") return uprightRightImage;
  return null;
}

export const cheerSportAudienceLegend = [
  { image: backboardLeftImage, title: "Backboard Left", context: "Basketball · fans behind the left backboard" },
  { image: backboardRightImage, title: "Backboard Right", context: "Basketball · fans behind the right backboard" },
  { image: uprightLeftImage, title: "Uprights Left", context: "Football · fans behind the left uprights" },
  { image: uprightRightImage, title: "Uprights Right", context: "Football · fans behind the right uprights" },
] as const;
