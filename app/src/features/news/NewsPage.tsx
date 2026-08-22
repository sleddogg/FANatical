import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useLocation, useNavigate, useSearchParams } from "react-router-dom";
import { useTeamContext } from "../../state/TeamContext";
import { useAppTheme } from "../../state/ThemeContext";
import { AppIcon, type AppIconName } from "../../components/AppIcon";
import { TeamBadge } from "../../components/TeamBadge";
import { useFanbaseContext } from "../fanbase/FanbaseContext";
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
  findThemeTeamForNewsContext,
  getFeedContextLabel,
  getFeedContextName,
  getSourceForItem,
} from "./newsFiltering";
import type {
  FollowedSourcePreference,
  NewsContentType,
  NewsFeedContext,
  NewsSource,
  SportId,
} from "./types";
import "./news.css";

type OverlayLocationState = Readonly<{
  newsItemOverlay?: boolean;
  articleDiscussionPath?: string;
}>;

const sportContextIcons: Readonly<Record<SportId, AppIconName>> = {
  football: "mdi-football",
  baseball: "mdi-baseball-outline",
  basketball: "mdi-basketball",
};

export function NewsPage() {
  const { followedTeams, selectedTeam, selectedTeamId, selectTeam } = useTeamContext();
  const theme = useAppTheme();
  const { getArticleCommentCount } = useFanbaseContext();
  const [feedContext, setFeedContext] = useState<NewsFeedContext>({ kind: "team", teamId: selectedTeamId });
  const [sourcePreferences, setSourcePreferences] = useState<FollowedSourcePreference[]>(createInitialFollowedSourcePreferences);
  const [filterOpen, setFilterOpen] = useState(false);
  const [sourceManagerOpen, setSourceManagerOpen] = useState(false);
  const [reactedItemIds, setReactedItemIds] = useState<ReadonlySet<string>>(() => new Set());
  const [notice, setNotice] = useState("");
  const filterTriggerRef = useRef<HTMLButtonElement>(null);
  const addFeedTriggerRef = useRef<HTMLButtonElement>(null);
  const lastItemTriggerRef = useRef<HTMLButtonElement>(null);
  const itemOverlayWasOpenRef = useRef(false);
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
  const overlayLocationState = location.state as OverlayLocationState | null;
  const articleDiscussionPath = overlayLocationState?.articleDiscussionPath;
  const feedContextName = getFeedContextName(feedContext, followedTeams);
  const feedContextTeam = feedContext.kind === "team"
    ? followedTeams.find((team) => team.id === feedContext.teamId)
    : undefined;
  const newsThemeTeam = findThemeTeamForNewsContext(feedContext, selectedTeam, followedTeams);
  const newsThemeActive = theme.active && (theme.source !== "current-team" || Boolean(newsThemeTeam));

  const closeFilter = useCallback(() => {
    setFilterOpen(false);
    window.requestAnimationFrame(() => filterTriggerRef.current?.focus());
  }, []);

  const closeSourceManager = useCallback(() => {
    setSourceManagerOpen(false);
    window.requestAnimationFrame(() => addFeedTriggerRef.current?.focus());
  }, []);

  useEffect(() => {
    if (itemOverlayWasOpenRef.current && !selectedItem) {
      window.requestAnimationFrame(() => lastItemTriggerRef.current?.focus());
    }
    itemOverlayWasOpenRef.current = Boolean(selectedItem);
  }, [selectedItem]);

  const applyFilter = (context: NewsFeedContext) => {
    if (context.kind === "team") {
      selectTeam(context.teamId);
    } else if (theme.source === "current-team" && (context.kind === "league" || context.kind === "sport")) {
      const relevantTeam = findThemeTeamForNewsContext(context, selectedTeam, followedTeams);
      if (relevantTeam && relevantTeam.id !== selectedTeamId) selectTeam(relevantTeam.id);
    }
    setFeedContext(context);
    closeFilter();
  };

  const openItem = (itemId: string, trigger: HTMLButtonElement) => {
    lastItemTriggerRef.current = trigger;
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

  const openArticleDiscussion = (itemId: string) => {
    navigate(`/fanbase?area=article-comments&item=${itemId}`);
  };

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
    <div className="news-page" data-news-theme-active={newsThemeActive ? "true" : "false"}>
      <header className="news-header">
        <button
          ref={filterTriggerRef}
          className="news-filter-trigger"
          type="button"
          aria-label={`Filter News. Current context: ${feedContextName}`}
          aria-expanded={filterOpen}
          aria-controls="news-filter-menu"
          data-tooltip-label="Filter News"
          onClick={() => setFilterOpen(true)}
        >
          <AppIcon className="news-filter-trigger__icon" name="bars-3" />
          {feedContext.kind === "team" && feedContextTeam ? <TeamBadge team={feedContextTeam} /> : null}
          {feedContext.kind === "sport" ? <AppIcon className="news-filter-trigger__context-icon" name={sportContextIcons[feedContext.sportId]} /> : null}
          {feedContext.kind === "league" ? <span className="news-filter-trigger__context-text">{feedContextName}</span> : null}
          {feedContext.kind === "all" ? <span className="news-filter-trigger__context-text">All</span> : null}
        </button>
        <div className="news-header__title">
          <h1>News</h1>
          <p>{getFeedContextLabel(feedContext, followedTeams)}</p>
        </div>
        <button ref={addFeedTriggerRef} className="news-add-feed" type="button" aria-expanded={sourceManagerOpen} aria-controls="source-manager" onClick={() => setSourceManagerOpen(true)}>
          <AppIcon name="plus" /><span>Add Feed</span>
        </button>
      </header>

      <div className="news-feed-field">
        <div className="news-feed-field__content">
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
                    discussionCount={getArticleCommentCount(item.id)}
                    reacted={reactedItemIds.has(item.id)}
                    onOpen={(trigger) => openItem(item.id, trigger)}
                    onReaction={() => toggleReaction(item.id)}
                    onDiscussion={() => openArticleDiscussion(item.id)}
                    onShare={() => showNotice("Sharing is represented here as a safe frontend placeholder.")}
                  />
                );
              })}
            </div>
          ) : (
            <div className="news-empty-state surface">
              <AppIcon name="information-circle" />
              <h2>No News in this view</h2>
              <p>Try another context or manage your followed sources and content types.</p>
            </div>
          )}
        </div>
      </div>

      <div className={notice ? "news-notice news-notice--visible" : "news-notice"} role="status" aria-live="polite">
        {notice}
        {notice ? <button type="button" aria-label="Dismiss message" onClick={() => setNotice("")}><AppIcon name="x-mark" /></button> : null}
      </div>

      {filterOpen ? (
        <NewsFilterMenu followedTeams={followedTeams} onApply={applyFilter} onClose={closeFilter} />
      ) : null}

      {sourceManagerOpen ? (
        <SourceManagerDialog
          sourceCatalog={mockSourceCatalog}
          preferences={sourcePreferences}
          onFollow={followSource}
          onRemove={removeSource}
          onToggleContentType={toggleSourceContentType}
          onMute={muteSource}
          onClose={closeSourceManager}
        />
      ) : null}

      {selectedItem && selectedItemSource ? (
        <NewsItemOverlay
          item={selectedItem}
          source={selectedItemSource}
          discussionCount={getArticleCommentCount(selectedItem.id)}
          reacted={reactedItemIds.has(selectedItem.id)}
          contextActionLabel={articleDiscussionPath ? "Back to Discussion" : "Discussion"}
          onClose={closeItem}
          onContextAction={() => articleDiscussionPath ? navigate(-1) : openArticleDiscussion(selectedItem.id)}
          onReaction={() => toggleReaction(selectedItem.id)}
          onDiscussion={() => articleDiscussionPath ? navigate(articleDiscussionPath) : openArticleDiscussion(selectedItem.id)}
          onShare={() => showNotice("Sharing is represented here as a safe frontend placeholder.")}
          onExternalContinue={() => showNotice("External destinations are not connected in this mock frontend.")}
        />
      ) : null}
    </div>
  );
}
