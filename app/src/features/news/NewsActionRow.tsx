import { AppIcon } from "../../components/AppIcon";
import type { FanSafeNewsItem } from "./types";

type NewsActionRowProps = {
  readonly item: FanSafeNewsItem;
  readonly onOutboundOpen: () => void;
  readonly onShare: () => void;
  readonly onDismiss?: () => void;
};

export function NewsActionRow({
  item,
  onOutboundOpen,
  onShare,
  onDismiss,
}: NewsActionRowProps) {
  return (
    <div className="news-actions news-actions--card" role="group" aria-label={`Actions for ${item.headline}`}>
      <a
        href={item.destinationUrl}
        target="_blank"
        rel="noopener noreferrer"
        aria-label={`Open ${item.headline} at ${item.publisher.name}`}
        onClick={onOutboundOpen}
      >
        <AppIcon name="arrow-top-right-on-square" />
        <small>Open</small>
      </a>
      <button type="button" aria-label={`Share ${item.headline}`} onClick={onShare}>
        <AppIcon name="share" />
        <small>Share</small>
      </button>
      {onDismiss ? (
        <button type="button" aria-label={`Dismiss ${item.headline}`} onClick={onDismiss}>
          <AppIcon name="x-mark" />
          <small>Dismiss</small>
        </button>
      ) : null}
    </div>
  );
}
