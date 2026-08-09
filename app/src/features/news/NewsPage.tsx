import { useCallback, useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate, useSearchParams } from "react-router-dom";
import { useTeamContext } from "../../state/TeamContext";
import { NewsCard } from "./NewsCard";
import { NewsFilterMenu } from "./NewsFilterMenu";
import { NewsItemOverlay } from "./NewsItemOverlay";
import { SourceManagerDialog } from "./SourceManagerDialog";
import {
  createInitialFollowedSourcePreferences,
  mockNewsItems,
  mockSourceCatalog,
} from "./mockNewsData";
import {
  filterNewsItems,
  getFeedContextLabel,
  getSourceForItem,
} from "./newsFiltering";
import type {
  FollowedSourcePreference,
  NewsContentType,
  NewsFeedContext,
  NewsSource,
} from "./types";
import "./news.css";

type OverlayLocationState = Readonly<{ newsItemOverlay?: boolean }>;

export function NewsPage() {
  const { followedTeams, selectedTeamId, selectTeam } = useTeamContext();
  const [feedContext, setFeedContext] = useState<NewsFeedContext>({ kind: "team", teamId: selectedTeamId });
  const [sourcePreferences, setSourcePreferences] = useState<FollowedSourcePreference[]>(createInitialFollowedSourcePreferences);
  const [filterOpen, setFilterOpen] = useState(false);
  const [sourceManagerOpen, setSourceManagerOpen] = useState(false);
  const [reactedItemIds, setReactedItemIds] = useState<ReadonlySet<string>>(() => new Set());
  const [notice, setNotice] = useState("");
  const [searchParams, setSearchParams] = useSearchParams();
  const location = useLocation();
  const navigate = useNavigate();

  useEffect(() => {
    setFeedContext((current) => current.kind === "team"
      ? { kind: "team", teamId: selectedTeamId }
      : current);
  }, [selectedTeamId]);

  const visibleItems = useMemo(
    () => filterNewsItems(mockNewsItems, feedContext, sourcePreferences),
    [feedContext, sourcePreferences],
  );

  const selectedItemId = searchParams.get("item");
  const selectedItem = mockNewsItems.find((item) => item.id === selectedItemId);
  const selectedItemSource = selectedItem ? getSourceForItem(selectedItem, mockSourceCatalog) : undefined;

  const applyFilter = (context: NewsFeedContext) => {
    if (context.kind === "team") {
      selectTeam(context.teamId);
    }
    setFeedContext(context);
    setFilterOpen(false);
  };

  const openItem = (itemId: string) => {
    const nextSearchParams = new URLSearchParams(searchParams);
    nextSearchParams.set("item", itemId);
    setSearchParams(nextSearchParams, { state: { newsItemOverlay: true } satisfies OverlayLocationState });
  };

  const closeItem = useCallback(() => {
    const state = location.state as OverlayLocationState | null;
    if (state?.newsItemOverlay) {
      navigate(-1);
      return;
    }

    const nextSearchParams = new URLSearchParams(searchParams);
    nextSearchParams.delete("item");
    setSearchParams(nextSearchParams, { replace: true });
  }, [location.state, navigate, searchParams, setSearchParams]);

  const toggleReaction = (itemId: string) => {
    setReactedItemIds((current) => {
      const next = new Set(current);
      if (next.has(itemId)) {
        next.delete(itemId);
      } else {
        next.add(itemId);
      }
      return next;
    });
  };

  const showNotice = (message: string) => setNotice(message);

  const followSource = (source: NewsSource, contentTypes: readonly NewsContentType[]) => {
    setSourcePreferences((current) => current.some((preference) => preference.sourceId === source.id)
      ? current
      : [...current, { sourceId: source.id, contentTypes: [...contentTypes], mutedUntil: null }]);
  };

  const removeSource = (sourceId: string) => {
    setSourcePreferences((current) => current.filter((preference) => preference.sourceId !== sourceId));
  };

  const toggleSourceContentType = (sourceId: string, contentType: NewsContentType) => {
    setSourcePreferences((current) => current.map((preference) => {
      if (preference.sourceId !== sourceId) {
        return preference;
      }
      const contentTypes = preference.contentTypes.includes(contentType)
        ? preference.contentTypes.filter((type) => type !== contentType)
        : [...preference.contentTypes, contentType];
      return { ...preference, contentTypes };
    }));
  };

  const muteSource = (sourceId: string, duration: "week" | "month" | "unmute") => {
    const durationInDays = duration === "week" ? 7 : 30;
    const mutedUntil = duration === "unmute"
      ? null
      : new Date(Date.now() + durationInDays * 24 * 60 * 60 * 1000).toISOString();
    setSourcePreferences((current) => current.map((preference) => (
      preference.sourceId === sourceId ? { ...preference, mutedUntil } : preference
    )));
  };

  return (
    <div className="news-page">
      <header className="news-header">
        <button className="news-filter-trigger" type="button" aria-label="Open News filters" aria-expanded={filterOpen} onClick={() => setFilterOpen(true)}>
          <span className="news-filter-trigger__icon" aria-hidden="true">☰</span>
          <span>Filter</span>
        </button>
        <div className="news-header__title">
          <span className="eyebrow">FANatical feed</span>
          <h1>News</h1>
          <p>{getFeedContextLabel(feedContext)}</p>
        </div>
        <button className="news-add-feed" type="button" onClick={() => setSourceManagerOpen(true)}>
          <span aria-hidden="true">＋</span><span>Add Feed</span>
        </button>
      </header>

      <div className="news-feed-heading">
        <div>
          <h2>Latest</h2>
          <p>News from your followed sources, always in chronological order.</p>
        </div>
        <span>{visibleItems.length} item{visibleItems.length === 1 ? "" : "s"}</span>
      </div>

      {visibleItems.length ? (
        <div className="news-feed">
          {visibleItems.map((item) => {
            const source = getSourceForItem(item, mockSourceCatalog);
            if (!source) {
              return null;
            }
            return (
              <NewsCard
                key={item.id}
                item={item}
                source={source}
                reacted={reactedItemIds.has(item.id)}
                onOpen={() => openItem(item.id)}
                onReaction={() => toggleReaction(item.id)}
                onDiscussion={() => showNotice("News discussions will open a connected FANbase thread in a later feature task.")}
                onShare={() => showNotice("Sharing is represented here as a safe frontend placeholder.")}
              />
            );
          })}
        </div>
      ) : (
        <div className="news-empty-state surface">
          <span aria-hidden="true">⌁</span>
          <h2>No News in this view</h2>
          <p>Try another context or manage your followed sources and content types.</p>
        </div>
      )}

      <div className={notice ? "news-notice news-notice--visible" : "news-notice"} role="status" aria-live="polite">
        {notice}
        {notice ? <button type="button" aria-label="Dismiss message" onClick={() => setNotice("")}>×</button> : null}
      </div>

      {filterOpen ? (
        <NewsFilterMenu followedTeams={followedTeams} onApply={applyFilter} onClose={() => setFilterOpen(false)} />
      ) : null}

      {sourceManagerOpen ? (
        <SourceManagerDialog
          sourceCatalog={mockSourceCatalog}
          preferences={sourcePreferences}
          onFollow={followSource}
          onRemove={removeSource}
          onToggleContentType={toggleSourceContentType}
          onMute={muteSource}
          onClose={() => setSourceManagerOpen(false)}
        />
      ) : null}

      {selectedItem && selectedItemSource ? (
        <NewsItemOverlay
          item={selectedItem}
          source={selectedItemSource}
          reacted={reactedItemIds.has(selectedItem.id)}
          onClose={closeItem}
          onReaction={() => toggleReaction(selectedItem.id)}
          onDiscussion={() => showNotice("News discussions will open a connected FANbase thread in a later feature task.")}
          onShare={() => showNotice("Sharing is represented here as a safe frontend placeholder.")}
          onExternalContinue={() => showNotice("External destinations are not connected in this mock frontend.")}
        />
      ) : null}
    </div>
  );
}
