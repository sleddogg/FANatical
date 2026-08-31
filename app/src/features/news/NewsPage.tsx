import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { AppIcon, type AppIconName } from "../../components/AppIcon";
import { TeamBadge } from "../../components/TeamBadge";
import { useAuth } from "../account/AuthContext";
import { useAppTheme } from "../../state/ThemeContext";
import { useTeamContext } from "../../state/TeamContext";
import { NewsCard } from "./NewsCard";
import { NewsFilterMenu } from "./NewsFilterMenu";
import { AddToFeedDialog } from "./SourceManagerDialog";
import {
  dismissNewsItem,
  loadMyNewsFollowing,
  loadNewsDemoFeed,
  loadNewsDemoUniverse,
  loadNewsNavigation,
  loadMyNewsZeroFollowExample,
  loadPersonalNewsFeed,
  recordNewsOutboundOpen,
  undoNewsItemDismissal,
} from "./newsRepository";
import {
  loadNewsDemoSelections,
  saveNewsDemoSelections,
} from "./newsDemoState";
import type {
  FanSafeNewsItem,
  NewsDemoSelection,
  NewsFollowingEntry,
  NewsFollowTarget,
  NewsNavigationEntry,
  NewsTemporaryFilter,
} from "./types";
import "./news.css";

type LoadState = "loading" | "ready" | "error";

type Notice = Readonly<{
  message: string;
  dismissedItem?: FanSafeNewsItem;
  dismissedIndex?: number;
}>;

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

type NewsFilterSelection = Readonly<{
  userId: string | null;
  followsTeamContext: boolean;
  value: NewsTemporaryFilter;
}>;

function allNewsFilter(signedIn: boolean): Extract<NewsTemporaryFilter, { kind: "all" }> {
  return { kind: "all", displayName: signedIn ? "All Followed News" : "All Demo News" };
}

function initialFilter(signedIn: boolean, teamId: string | null, teamName: string): NewsTemporaryFilter {
  return signedIn && teamId
    ? { kind: "team", targetId: teamId, displayName: teamName }
    : allNewsFilter(signedIn);
}

function NewsLoadingState() {
  return (
    <div className="news-loading" role="status" aria-label="Loading News">
      {[0, 1, 2].map((position) => <span key={position} className="news-loading__card" />)}
      <span className="visually-hidden">Loading News…</span>
    </div>
  );
}

function ZeroFollowExample({ teamName, onAdd }: { readonly teamName: string; readonly onAdd: () => void }) {
  return (
    <article className="news-example-card surface" aria-labelledby="news-example-title">
      <span className="news-example-card__stamp">EXAMPLE</span>
      <span className="news-example-card__icon"><AppIcon name="newspaper" /></span>
      <div>
        <p className="eyebrow">Your {teamName} News could appear here</p>
        <h2 id="news-example-title">Build a chronological feed around the people and Shows you choose.</h2>
        <p>This controlled example is not a real feed Item and creates no follow or eligibility.</p>
      </div>
      <button className="news-primary-button" type="button" onClick={onAdd}><AppIcon name="plus" /> Add to Feed</button>
    </article>
  );
}

function RealZeroFollowExample({
  item,
  onAdd,
  onOutboundOpen,
  onShare,
}: {
  readonly item: FanSafeNewsItem;
  readonly onAdd: () => void;
  readonly onOutboundOpen: (selected: FanSafeNewsItem) => void;
  readonly onShare: (selected: FanSafeNewsItem) => void;
}) {
  return (
    <section className="news-real-example" aria-label="Zero-follow News example">
      <div className="news-real-example__heading">
        <span className="news-example-card__stamp">EXAMPLE</span>
        <p>This real official-Team Item is an onboarding example. It creates no follow or feed eligibility.</p>
        <button className="news-primary-button" type="button" onClick={onAdd}><AppIcon name="plus" /> Add to Feed</button>
      </div>
      <NewsCard item={item} onOutboundOpen={onOutboundOpen} onShare={onShare} />
    </section>
  );
}

export function NewsPage() {
  const { configured, loading: authLoading, user } = useAuth();
  const { selectedTeam } = useTeamContext();
  const theme = useAppTheme();
  const signedIn = Boolean(user);
  const authUserId = user?.id ?? null;
  const selectedTeamPublicId = selectedTeam.officialTeamId;
  const [filterSelection, setFilterSelection] = useState<NewsFilterSelection>(() => ({
    userId: authUserId,
    followsTeamContext: signedIn,
    value: initialFilter(signedIn, selectedTeamPublicId, selectedTeam.name),
  }));
  const authUserIdRef = useRef(authUserId);
  const contextFilter = useMemo(
    () => initialFilter(signedIn, selectedTeamPublicId, selectedTeam.name),
    [selectedTeam.name, selectedTeamPublicId, signedIn],
  );
  const filter = filterSelection.userId !== authUserId || (signedIn && filterSelection.followsTeamContext)
    ? contextFilter
    : filterSelection.value;
  const [navigation, setNavigation] = useState<readonly NewsNavigationEntry[]>([]);
  const [following, setFollowing] = useState<readonly NewsFollowingEntry[]>([]);
  const [demoUniverse, setDemoUniverse] = useState<readonly NewsFollowTarget[]>([]);
  const [demoSelections, setDemoSelections] = useState<readonly NewsDemoSelection[]>([]);
  const [items, setItems] = useState<readonly FanSafeNewsItem[]>([]);
  const [exampleItem, setExampleItem] = useState<FanSafeNewsItem | null>(null);
  const [loadState, setLoadState] = useState<LoadState>("loading");
  const [error, setError] = useState("");
  const [revision, setRevision] = useState(0);
  const [filterOpen, setFilterOpen] = useState(false);
  const [addToFeedOpen, setAddToFeedOpen] = useState(false);
  const [notice, setNotice] = useState<Notice | null>(null);
  const filterTriggerRef = useRef<HTMLButtonElement>(null);
  const addToFeedTriggerRef = useRef<HTMLButtonElement>(null);
  const pendingDismissalsRef = useRef(new Map<string, Promise<void>>());

  const closeFilter = useCallback(() => {
    setFilterOpen(false);
    window.requestAnimationFrame(() => filterTriggerRef.current?.focus());
  }, []);

  const closeAddToFeed = useCallback(() => {
    setAddToFeedOpen(false);
    window.requestAnimationFrame(() => addToFeedTriggerRef.current?.focus());
  }, []);

  useEffect(() => {
    if (authLoading || authUserIdRef.current === authUserId) return;
    authUserIdRef.current = authUserId;
    setFilterSelection({
      userId: authUserId,
      followsTeamContext: signedIn,
      value: initialFilter(signedIn, selectedTeamPublicId, selectedTeam.name),
    });
  }, [authLoading, authUserId, selectedTeam.name, selectedTeamPublicId, signedIn]);

  useEffect(() => {
    if (authLoading || !configured) return;
    let current = true;
    void loadNewsNavigation().then((next) => {
      if (current) setNavigation(next);
    }).catch((reason: unknown) => {
      if (current) setError(reason instanceof Error ? reason.message : "News filters could not be loaded.");
    });
    return () => { current = false; };
  }, [authLoading, configured]);

  useEffect(() => {
    let current = true;
    if (authLoading || !configured) {
      return () => { current = false; };
    }
    const load = async () => {
      if (!current) return;
      setLoadState("loading");
      setError("");
      if (user) {
        const nextFollowing = await loadMyNewsFollowing();
        if (!current) return;
        setFollowing(nextFollowing);
        setDemoUniverse([]);
        setDemoSelections([]);
        const nextExample = !nextFollowing.length && selectedTeamPublicId
          ? await loadMyNewsZeroFollowExample(selectedTeamPublicId)
          : null;
        if (!current) return;
        setExampleItem(nextExample);
        const nextItems = nextFollowing.length ? await loadPersonalNewsFeed(filter) : [];
        if (!current) return;
        setItems(nextItems);
      } else {
        const universe = await loadNewsDemoUniverse();
        if (!current) return;
        const selections = loadNewsDemoSelections(universe);
        setFollowing([]);
        setExampleItem(null);
        setDemoUniverse(universe);
        setDemoSelections(selections);
        const nextItems = selections.length ? await loadNewsDemoFeed(selections, filter) : [];
        if (!current) return;
        setItems(nextItems);
      }
      setLoadState("ready");
    };
    void Promise.resolve().then(load).catch((reason: unknown) => {
      if (!current) return;
      setItems([]);
      setLoadState("error");
      setError(reason instanceof Error ? reason.message : "News could not be loaded.");
    });
    return () => { current = false; };
  }, [authLoading, configured, filter, revision, selectedTeamPublicId, user]);

  const refreshAccountNews = useCallback(async () => {
    setRevision((current) => current + 1);
  }, []);

  const updateDemoSelections = (selections: readonly NewsDemoSelection[]) => {
    saveNewsDemoSelections(selections);
    setDemoSelections(selections);
    setRevision((current) => current + 1);
  };

  const outboundOpen = (item: FanSafeNewsItem) => {
    // The anchor performs browser navigation directly. This request is started
    // without being awaited, so analytics can never delay the publisher open.
    void recordNewsOutboundOpen(item.id, item.destinationUrl).catch((reason: unknown) => {
      console.warn("FANatical could not record a News outbound open.", reason);
    });
  };

  const share = async (item: FanSafeNewsItem) => {
    try {
      if (navigator.share) {
        await navigator.share({ title: item.headline, url: item.destinationUrl });
        setNotice({ message: "News Item shared." });
      } else if (navigator.clipboard) {
        await navigator.clipboard.writeText(item.destinationUrl);
        setNotice({ message: "Publisher link copied." });
      } else {
        setNotice({ message: "Copy the publisher link from the opened page." });
      }
    } catch (reason) {
      if (reason instanceof DOMException && reason.name === "AbortError") return;
      setNotice({ message: "The publisher link could not be shared." });
    }
  };

  const dismiss = async (item: FanSafeNewsItem) => {
    const index = items.findIndex((candidate) => candidate.id === item.id);
    const pendingDismissal = dismissNewsItem(item.id);
    pendingDismissalsRef.current.set(item.id, pendingDismissal);
    setItems((current) => current.filter((candidate) => candidate.id !== item.id));
    setNotice({ message: "News Item dismissed.", dismissedItem: item, dismissedIndex: Math.max(0, index) });
    try {
      await pendingDismissal;
    } catch (reason) {
      setItems((current) => {
        if (current.some((candidate) => candidate.id === item.id)) return current;
        const restored = [...current];
        restored.splice(Math.max(0, index), 0, item);
        return restored;
      });
      setNotice({ message: reason instanceof Error ? reason.message : "The News Item could not be dismissed." });
    } finally {
      if (pendingDismissalsRef.current.get(item.id) === pendingDismissal) {
        pendingDismissalsRef.current.delete(item.id);
      }
    }
  };

  const undoDismiss = async () => {
    const dismissedItem = notice?.dismissedItem;
    const dismissedIndex = notice?.dismissedIndex;
    if (!dismissedItem || dismissedIndex === undefined) return;
    setItems((current) => {
      if (current.some((candidate) => candidate.id === dismissedItem.id)) return current;
      const restored = [...current];
      restored.splice(Math.min(dismissedIndex, restored.length), 0, dismissedItem);
      return restored;
    });
    setNotice({ message: "Dismiss undone." });
    const pendingDismissal = pendingDismissalsRef.current.get(dismissedItem.id);
    if (pendingDismissal) {
      try {
        await pendingDismissal;
      } catch {
        // The Dismiss handler restores the Item and reports its own failure.
        return;
      }
    }
    try {
      await undoNewsItemDismissal(dismissedItem.id);
      setRevision((current) => current + 1);
    } catch (reason) {
      setItems((current) => current.filter((candidate) => candidate.id !== dismissedItem.id));
      setNotice({ message: reason instanceof Error ? reason.message : "Dismiss could not be undone." });
    }
  };

  const applyFilter = (nextFilter: NewsTemporaryFilter) => {
    setFilterSelection({ userId: authUserId, followsTeamContext: false, value: nextFilter });
    closeFilter();
  };

  const filterIcon = filter.kind === "sport"
    ? sportIcons[filter.targetId.toLowerCase()] ?? "newspaper"
    : null;
  const filterUsesSelectedTeam = filter.kind === "team" && filter.targetId === selectedTeamPublicId;
  const visibleLoadState: LoadState = authLoading ? "loading" : configured ? loadState : "error";
  const visibleError = configured ? error : "News is unavailable because the FANatical data service is not configured.";
  const showZeroFollow = signedIn && visibleLoadState === "ready" && following.length === 0;
  const showFilterZero = signedIn && visibleLoadState === "ready" && following.length > 0 && items.length === 0;
  const showDemoZero = !signedIn && visibleLoadState === "ready" && demoUniverse.length > 0 && demoSelections.length === 0;

  return (
    <div className="news-page" data-news-theme-active={theme.active ? "true" : "false"}>
      <header className="news-header">
        <button
          ref={filterTriggerRef}
          className="news-filter-trigger"
          type="button"
          aria-label={`Filter News. Current context: ${filter.displayName}`}
          aria-expanded={filterOpen}
          aria-controls="news-filter-menu"
          disabled={!navigation.length}
          onClick={() => setFilterOpen(true)}
        >
          <AppIcon className="news-filter-trigger__icon" name="bars-3" />
          {filterUsesSelectedTeam ? <TeamBadge team={selectedTeam} /> : null}
          {filterIcon ? <AppIcon className="news-filter-trigger__context-icon" name={filterIcon} /> : null}
          {!filterUsesSelectedTeam && !filterIcon ? <span className="news-filter-trigger__context-text">{filter.kind === "all" ? "All" : filter.displayName}</span> : null}
        </button>
        <div className="news-header__title">
          <h1>News</h1>
          <p>{filter.displayName}</p>
        </div>
        <button ref={addToFeedTriggerRef} className="news-add-feed" type="button" aria-expanded={addToFeedOpen} aria-controls="add-to-feed" onClick={() => setAddToFeedOpen(true)}>
          <AppIcon name="plus" /><span>Add to Feed</span>
        </button>
      </header>

      {!signedIn && !authLoading && configured ? (
        <div className="news-demo-banner" role="status">
          <AppIcon name="information-circle" />
          <span>Demo mode — sign in to save your feed.</span>
          <Link to="/profile">Sign in</Link>
        </div>
      ) : null}

      <div className="news-feed-field">
        <div className="news-feed-field__content">
          {visibleLoadState === "loading" ? <NewsLoadingState /> : null}
          {visibleLoadState === "error" ? (
            <div className="news-empty-state surface" role="alert">
              <AppIcon name="exclamation-triangle" />
              <h2>News could not load</h2>
              <p>{visibleError}</p>
              {configured ? <button className="news-primary-button" type="button" onClick={() => setRevision((current) => current + 1)}>Try again</button> : null}
            </div>
          ) : null}
          {showZeroFollow && exampleItem ? (
            <RealZeroFollowExample
              item={exampleItem}
              onAdd={() => setAddToFeedOpen(true)}
              onOutboundOpen={outboundOpen}
              onShare={(selected) => { void share(selected); }}
            />
          ) : null}
          {showZeroFollow && !exampleItem ? <ZeroFollowExample teamName={selectedTeam.name} onAdd={() => setAddToFeedOpen(true)} /> : null}
          {showFilterZero ? (
            <div className="news-empty-state surface">
              <AppIcon name="information-circle" />
              <h2>No News matches this filter</h2>
              <p>Your follows are still active. Choose another temporary filter or return to All Followed News.</p>
              <button className="news-primary-button" type="button" onClick={() => setFilterSelection({ userId: authUserId, followsTeamContext: false, value: allNewsFilter(true) })}>Show All Followed News</button>
            </div>
          ) : null}
          {showDemoZero ? (
            <div className="news-empty-state surface">
              <AppIcon name="information-circle" />
              <h2>No Demo identities selected</h2>
              <p>Choose one or more identities from the configured Demo universe.</p>
              <button className="news-primary-button" type="button" onClick={() => setAddToFeedOpen(true)}>Choose Demo identities</button>
            </div>
          ) : null}
          {visibleLoadState === "ready" && items.length ? (
            <div className="news-feed" aria-label="Chronological News feed">
              {items.map((item) => (
                <NewsCard
                  key={item.id}
                  item={item}
                  onOutboundOpen={outboundOpen}
                  onShare={(selected) => { void share(selected); }}
                  {...(signedIn ? { onDismiss: (selected: FanSafeNewsItem) => { void dismiss(selected); } } : {})}
                />
              ))}
            </div>
          ) : null}
          {!signedIn && visibleLoadState === "ready" && demoUniverse.length === 0 ? (
            <div className="news-empty-state surface">
              <AppIcon name="information-circle" />
              <h2>Demo Mode is not configured yet</h2>
              <p>No staff-approved Demo identities are currently available.</p>
            </div>
          ) : null}
        </div>
      </div>

      <div className={notice ? "news-notice news-notice--visible" : "news-notice"} role="status" aria-live="polite">
        {notice?.message}
        {notice?.dismissedItem ? <button type="button" onClick={() => { void undoDismiss(); }}>Undo</button> : null}
        {notice ? <button type="button" aria-label="Dismiss message" onClick={() => setNotice(null)}><AppIcon name="x-mark" /></button> : null}
      </div>

      {filterOpen ? (
        <NewsFilterMenu currentFilter={filter} allFilter={allNewsFilter(signedIn)} navigation={navigation} onApply={applyFilter} onClose={closeFilter} />
      ) : null}

      {addToFeedOpen ? (
        <AddToFeedDialog
          signedIn={signedIn}
          following={following}
          demoUniverse={demoUniverse}
          demoSelections={demoSelections}
          navigation={navigation}
          discoveryTeamId={selectedTeamPublicId}
          discoveryTeamName={selectedTeam.name}
          onAccountChanged={refreshAccountNews}
          onDemoSelectionsChange={updateDemoSelections}
          onClose={closeAddToFeed}
        />
      ) : null}
    </div>
  );
}
