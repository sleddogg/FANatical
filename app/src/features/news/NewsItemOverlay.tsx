import { useEffect, useRef } from "react";
import { formatPublishedAt } from "./newsFiltering";
import { NewsActionRow } from "./NewsActionRow";
import type { NewsItem, NewsSource } from "./types";

type NewsItemOverlayProps = {
  readonly item: NewsItem;
  readonly source: NewsSource;
  readonly reacted: boolean;
  readonly onClose: () => void;
  readonly onReaction: () => void;
  readonly onDiscussion: () => void;
  readonly onShare: () => void;
  readonly onExternalContinue: () => void;
};

export function NewsItemOverlay({
  item,
  source,
  reacted,
  onClose,
  onReaction,
  onDiscussion,
  onShare,
  onExternalContinue,
}: NewsItemOverlayProps) {
  const closeButtonRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeButtonRef.current?.focus();

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [onClose]);

  return (
    <section className="news-item-overlay" role="dialog" aria-modal="true" aria-labelledby="news-item-title">
      <header className="news-item-overlay__topbar">
        <div className="news-item-overlay__brand">
          <span className="news-source-avatar" aria-hidden="true">{source.initials}</span>
          <span><strong>{source.name}</strong><small>{item.contentType}</small></span>
        </div>
        <button ref={closeButtonRef} className="news-item-overlay__close" type="button" aria-label="Close News item" onClick={onClose}>
          ×
        </button>
      </header>

      <div className="news-item-overlay__scroll">
        <article className="news-item-detail">
          <div className="news-item-detail__header">
            <span className="eyebrow">{item.viewType === "local" ? "FANatical in-app view" : "Source-controlled item"}</span>
            <h1 id="news-item-title">{item.headline}</h1>
            <p className="news-item-detail__dek">{item.summary}</p>
            <p className="news-item-detail__meta">
              {item.byline ? `By ${item.byline} · ` : ""}{source.name} · {formatPublishedAt(item.publishedAt)}
            </p>
          </div>

          {item.imageUrl ? (
            <div className="news-item-detail__image">
              <img src={item.imageUrl} alt={item.imageAlt ?? ""} />
            </div>
          ) : null}

          {item.viewType === "local" ? (
            <div className="news-item-detail__body">
              {item.body.map((paragraph) => <p key={paragraph}>{paragraph}</p>)}
            </div>
          ) : (
            <div className="news-item-detail__external surface">
              <span aria-hidden="true">↗</span>
              <h2>This item stays with its source</h2>
              <p>
                Podcasts, videos, paywalled stories, and other source-controlled formats open at their original destination.
              </p>
              <button className="button button--primary" type="button" onClick={onExternalContinue}>
                Continue to {item.externalDestination ?? source.name}
              </button>
              <small>Demo only—no external publisher is connected.</small>
            </div>
          )}

          <NewsActionRow
            item={item}
            reacted={reacted}
            variant="detail"
            onReaction={onReaction}
            onDiscussion={onDiscussion}
            onShare={onShare}
          />
        </article>
      </div>
    </section>
  );
}
