import { useState } from "react";
import { Link } from "react-router-dom";
import { AppIcon, type AppIconName } from "../../components/AppIcon";
import { NewsActionRow } from "./NewsActionRow";
import type { DiscussionOrigin } from "../community/types";
import { formatFanSafeNewsPublishedAt, newsIdentityProfilePath } from "./newsPresentation";
import type {
  FanSafeNewsItem,
  NewsByline,
} from "./types";

type NewsCardProps = {
  readonly item: FanSafeNewsItem;
  readonly onOutboundOpen: (item: FanSafeNewsItem) => void;
  readonly onShare: (item: FanSafeNewsItem) => void;
  readonly onDismiss?: (item: FanSafeNewsItem) => void;
  readonly discussionOrigin?: DiscussionOrigin | null;
};

const sportIcons: Readonly<Record<string, AppIconName>> = {
  baseball: "mdi-baseball-outline",
  basketball: "mdi-basketball",
  football: "mdi-football",
  hockey: "mdi-hockey-puck",
  golf: "trophy",
  rugby: "mdi-rugby",
  soccer: "mdi-soccer",
  tennis: "trophy",
};

function initials(name: string) {
  return name.split(/\s+/).filter(Boolean).map((part) => part[0]).join("").slice(0, 2).toUpperCase();
}

function Byline({ byline }: { readonly byline: NewsByline }) {
  return byline.targetType && byline.targetId
    ? <Link to={newsIdentityProfilePath(byline.targetType, byline.targetId)}>{byline.rawAttribution}</Link>
    : <span>{byline.rawAttribution}</span>;
}

function NewsPreview({ item, onOutboundOpen }: { readonly item: FanSafeNewsItem; readonly onOutboundOpen: () => void }) {
  const [failed, setFailed] = useState(false);
  const sport = item.classifications.find((classification) => classification.targetType === "sport");
  const icon = sportIcons[sport?.targetId.toLowerCase() ?? ""] ?? "newspaper";
  if (item.preview && !failed) {
    return (
      <a className="news-card__image" href={item.destinationUrl} target="_blank" rel="noopener noreferrer" aria-label={`Open preview for ${item.headline} at ${item.publisher.name}`} onClick={onOutboundOpen}>
        <img src={item.preview.url} alt={item.preview.alt} referrerPolicy="no-referrer" onError={() => setFailed(true)} />
      </a>
    );
  }
  return (
    <a className="news-card__image news-card__image--fallback" href={item.destinationUrl} target="_blank" rel="noopener noreferrer" aria-label={`Open ${sport ? `${sport.displayName} News` : "News"}: ${item.headline} at ${item.publisher.name}`} onClick={onOutboundOpen}>
      <AppIcon name={icon} />
    </a>
  );
}

export function NewsCard({ item, onOutboundOpen, onShare, onDismiss, discussionOrigin = null }: NewsCardProps) {
  const typeLabel = item.itemKind === "podcast_episode" ? "Podcast" : "Written";
  return (
    <article className={`news-card news-card--${item.itemKind.replace("_", "-")}`}>
      <div className="news-card__open">
        <div className="news-card__copy">
          <div className="news-card__source-row">
            <span className="news-source-avatar" aria-hidden="true">{initials(item.publisher.name) || "N"}</span>
            <strong>{item.publisher.name}</strong>
            <span className="news-content-type">{typeLabel}</span>
            <span className="news-external-label">Publisher <AppIcon name="arrow-top-right-on-square" /></span>
          </div>
          {item.show ? (
            <p className="news-card__show">
              <AppIcon name="sparkles" />
              <Link to={newsIdentityProfilePath("show", item.show.id)}>{item.show.name}</Link>
            </p>
          ) : null}
          <h2>
            <a
              className="news-card__headline"
              href={item.destinationUrl}
              target="_blank"
              rel="noopener noreferrer"
              onClick={() => onOutboundOpen(item)}
            >
              {item.headline}
            </a>
          </h2>
          <p className="news-card__summary">{item.summary}</p>
          <p className="news-card__meta">
            {item.bylines.length ? (
              <>
                By {item.bylines.map((byline, index) => (
                  <span key={`${byline.rawAttribution}-${index}`}>
                    {index ? ", " : ""}<Byline byline={byline} />
                  </span>
                ))} · {" "}
              </>
            ) : null}
            {formatFanSafeNewsPublishedAt(item.publishedAt, item.serverTime)}
          </p>
        </div>
        <NewsPreview item={item} onOutboundOpen={() => onOutboundOpen(item)} />
      </div>
      <NewsActionRow
        item={item}
        onOutboundOpen={() => onOutboundOpen(item)}
        onShare={() => onShare(item)}
        discussionOrigin={discussionOrigin}
        {...(onDismiss ? { onDismiss: () => onDismiss(item) } : {})}
      />
    </article>
  );
}
