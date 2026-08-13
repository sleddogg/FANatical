import type { CheerAction, CheerDuration, CheerTimingType } from "./types";

export { cheerAudienceImage, cheerSportAudienceLegend } from "./cheerRouting";

const noteSymbols: Readonly<Record<CheerDuration, string>> = {
  Whole: "𝅝", "Dotted Half": "𝅗𝅥·", Half: "𝅗𝅥", "One and a Half": "♩·", "One and a Quarter": "♩+𝅘𝅥𝅯", Quarter: "♩", "Three Quarter": "♪·", Eighth: "♪", Sixteenth: "𝅘𝅥𝅯",
};

const restSymbols: Readonly<Record<CheerDuration, string>> = {
  Whole: "𝄻", "Dotted Half": "𝄼·", Half: "𝄼", "One and a Half": "𝄽·", "One and a Quarter": "𝄽+𝄿", Quarter: "𝄽", "Three Quarter": "𝄾·", Eighth: "𝄾", Sixteenth: "𝄿",
};

const actionIcons: Readonly<Record<CheerAction, string>> = { Clap: "👏", Stomp: "🦶", Wave: "🌊", None: "—" };

export function cheerDurationSymbol(duration: CheerDuration, timingType: CheerTimingType) {
  return timingType === "Rest" ? restSymbols[duration] : noteSymbols[duration];
}

export function cheerActionIcon(action: CheerAction) {
  return actionIcons[action];
}
