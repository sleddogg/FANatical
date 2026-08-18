import { useState } from "react";
import { formatEventDate } from "./fanbaseFormatting";
import type { DiscussionThread, GameThread, GameThreadStatus } from "./types";
import { AppIcon } from "../../components/AppIcon";

type GameThreadContextCardProps = {
  readonly game: GameThread;
  readonly thread: DiscussionThread;
  readonly teamName: string;
  readonly status: GameThreadStatus;
  readonly onReport: () => void;
};

export function formatGameStatusLabel(status: GameThreadStatus) {
  return status === "Post-game" ? "Post-Game" : status;
}

export function GameThreadContextCard({ game, thread, teamName, status, onReport }: GameThreadContextCardProps) {
  const [shareNotice, setShareNotice] = useState("");
  const statusLabel = formatGameStatusLabel(status);

  return (
    <article className="game-context-card surface">
      <span className={`fanbase-status fanbase-status--${status.toLowerCase().replace("-", "")} game-context-card__status`}>{statusLabel}</span>
      <div className="game-context-card__content">
        <span className="eyebrow">Game Thread</span>
        <h2>{teamName} <small>vs.</small> {game.opponent}</h2>
        <dl>
          <div><dt>Date and time</dt><dd>{formatEventDate(game.startsAt)}</dd></div>
          <div><dt>Stadium / location</dt><dd>{game.venue}</dd></div>
        </dl>
      </div>
      <div className="game-context-card__actions">
        <button type="button" onClick={() => setShareNotice("Sharing is represented as a local frontend placeholder.")}><AppIcon name="share" /><span>Share</span></button>
        <button type="button" onClick={onReport}>{thread.reported ? "Reported" : "Report"}</button>
      </div>
      <div className="game-context-card__notice" role="status" aria-live="polite">{shareNotice}</div>
    </article>
  );
}
