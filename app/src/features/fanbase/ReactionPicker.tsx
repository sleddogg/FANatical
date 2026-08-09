import type { ReactionSummary, ReactionType } from "./types";

const reactionIcons: Record<ReactionType, string> = {
  Like: "👍",
  Love: "♥",
  Fire: "🔥",
  "Mind Blown": "✦",
};

export const reactionTypes = Object.keys(reactionIcons) as ReactionType[];

type ReactionPickerProps = {
  readonly reactions: ReactionSummary;
  readonly viewerReaction: ReactionType | null;
  readonly onReact: (reaction: ReactionType) => void;
  readonly compact?: boolean;
};

export function ReactionPicker({ reactions, viewerReaction, onReact, compact = false }: ReactionPickerProps) {
  return (
    <div className={compact ? "fanbase-reactions fanbase-reactions--compact" : "fanbase-reactions"} aria-label="Reactions">
      {reactionTypes.map((reaction) => (
        <button
          key={reaction}
          type="button"
          aria-label={`${reaction}, ${reactions[reaction]} reactions`}
          aria-pressed={viewerReaction === reaction}
          onClick={() => onReact(reaction)}
        >
          <span aria-hidden="true">{reactionIcons[reaction]}</span>
          <small>{reactions[reaction]}</small>
        </button>
      ))}
    </div>
  );
}
