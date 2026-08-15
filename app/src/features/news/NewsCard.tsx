import { formatPublishedAt } from "./newsFiltering";
import { NewsActionRow } from "./NewsActionRow";
import type { NewsItem, NewsSource } from "./types";
import { TeamBadge } from "../../components/TeamBadge";
import { findFollowedTeam } from "../../data/followedTeams";

type NewsCardProps = {
  readonly item: NewsItem;
  readonly source: NewsSource;
  readonly discussionCount: number;
  readonly reacted: boolean;
  readonly onOpen: () => void;
  readonly onReaction: () => void;
  readonly onDiscussion: () => void;
  readonly onShare: () => void;
};

export function NewsCard({
  item,
  source,
  discussionCount,
  reacted,
  onOpen,
  onReaction,
  onDiscussion,
  onShare,
}: NewsCardProps) {
  const team = item.teamIds.length === 1 ? findFollowedTeam(item.teamIds[0]!) : undefined;

  return (
    <article className="news-card">
      <button className="news-card__open" type="button" aria-label={`Open ${item.headline}`} onClick={onOpen}>
        <div className="news-card__copy">
          <div className="news-card__source-row">
            <span className="news-source-avatar" aria-hidden="true">{source.initials}</span>
            <strong>{source.name}</strong>
            <span className="news-content-type">{item.contentType}</span>
            {item.viewType === "external" ? <span className="news-external-label">External ↗</span> : null}
          </div>
          <h2>{item.headline}</h2>
          <p className="news-card__summary">{item.summary}</p>
          <p className="news-card__meta">
            {item.byline ? `By ${item.byline} · ` : ""}{formatPublishedAt(item.publishedAt)}
          </p>
        </div>
        {item.imageUrl ? (
          <span className="news-card__image">
            <img src={item.imageUrl} alt={item.imageAlt ?? ""} />
          </span>
        ) : team ? <span className="news-card__image news-card__image--team"><TeamBadge team={team} /></span> : null}
      </button>

      <NewsActionRow
        item={item}
        discussionCount={discussionCount}
        reacted={reacted}
        variant="card"
        onReaction={onReaction}
        onDiscussion={onDiscussion}
        onShare={onShare}
      />
    </article>
  );
}
