import { useEffect, useMemo, useRef, useState } from "react";
import { AppIcon } from "../../components/AppIcon";
import { trapDialogFocus } from "./dialogKeyboard";
import {
  followNewsTarget,
  muteNewsFollow,
  searchNewsFollowTargets,
  setNewsFollowScopes,
  unfollowNewsTarget,
  unmuteNewsFollow,
} from "./newsRepository";
import type {
  NewsDemoSelection,
  NewsFollowingEntry,
  NewsFollowTarget,
  NewsNavigationEntry,
} from "./types";

type AddToFeedTab = "add" | "following" | "how-to";

type AddToFeedDialogProps = {
  readonly signedIn: boolean;
  readonly following: readonly NewsFollowingEntry[];
  readonly demoUniverse: readonly NewsFollowTarget[];
  readonly demoSelections: readonly NewsDemoSelection[];
  readonly navigation: readonly NewsNavigationEntry[];
  readonly discoveryTeamId: string | null;
  readonly discoveryTeamName: string;
  readonly onAccountChanged: () => Promise<void>;
  readonly onDemoSelectionsChange: (selections: readonly NewsDemoSelection[]) => void;
  readonly onClose: () => void;
};

function targetKey(target: NewsDemoSelection) {
  return `${target.targetType}:${target.targetId}`;
}

function identityLabel(target: NewsFollowTarget) {
  if (target.targetType === "author") return "Author";
  if (target.targetType === "organization") return "Organizational contributor";
  return "Show";
}

function formatMuteExpiry(value: string) {
  return new Intl.DateTimeFormat("en", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(new Date(value));
}

type ScopeEditorProps = {
  readonly entry: NewsFollowingEntry;
  readonly navigation: readonly NewsNavigationEntry[];
  readonly disabled: boolean;
  readonly onSave: (
    entry: NewsFollowingEntry,
    sportScopeIds: readonly string[],
    teamScopeIds: readonly string[],
  ) => Promise<void>;
};

function ScopeEditor({ entry, navigation, disabled, onSave }: ScopeEditorProps) {
  const [sportScopes, setSportScopes] = useState<readonly string[]>(entry.sportScopeIds);
  const [teamScopes, setTeamScopes] = useState<readonly string[]>(entry.teamScopeIds);
  const sports = navigation.filter((candidate) => candidate.filterType === "sport");
  const teams = navigation.filter((candidate) => candidate.filterType === "team");

  const addScope = (
    value: string,
    scopes: readonly string[],
    save: (next: readonly string[]) => void,
  ) => {
    if (value && !scopes.includes(value)) save([...scopes, value]);
  };

  const scopeName = (kind: "sport" | "team", id: string) => (
    navigation.find((candidate) => candidate.filterType === kind && candidate.targetId === id)?.displayName ?? id
  );

  const changed = sportScopes.join("\u0000") !== entry.sportScopeIds.join("\u0000")
    || teamScopes.join("\u0000") !== entry.teamScopeIds.join("\u0000");

  return (
    <fieldset className="managed-source__scope-editor">
      <legend>Coverage scopes</legend>
      <p>{sportScopes.length || teamScopes.length ? "Selected scopes match with OR." : "All coverage"}</p>
      <div className="managed-source__scope-selects">
        <label>
          <span>Add Sport scope</span>
          <select value="" disabled={disabled} onChange={(event) => addScope(event.target.value, sportScopes, setSportScopes)}>
            <option value="">Choose Sport</option>
            {sports.filter((sport) => !sportScopes.includes(sport.targetId)).map((sport) => (
              <option key={sport.targetId} value={sport.targetId}>{sport.displayName}</option>
            ))}
          </select>
        </label>
        <label>
          <span>Add Team scope</span>
          <select value="" disabled={disabled} onChange={(event) => addScope(event.target.value, teamScopes, setTeamScopes)}>
            <option value="">Choose Team</option>
            {teams.filter((team) => !teamScopes.includes(team.targetId)).map((team) => (
              <option key={team.targetId} value={team.targetId}>{team.displayName}</option>
            ))}
          </select>
        </label>
      </div>
      <div className="managed-source__scope-tags" aria-label="Selected coverage scopes">
        {sportScopes.map((id) => (
          <button key={`sport-${id}`} type="button" disabled={disabled} onClick={() => setSportScopes((current) => current.filter((candidate) => candidate !== id))}>
            {scopeName("sport", id)} <AppIcon name="x-mark" />
          </button>
        ))}
        {teamScopes.map((id) => (
          <button key={`team-${id}`} type="button" disabled={disabled} onClick={() => setTeamScopes((current) => current.filter((candidate) => candidate !== id))}>
            {scopeName("team", id)} <AppIcon name="x-mark" />
          </button>
        ))}
      </div>
      {sportScopes.length || teamScopes.length ? (
        <button className="news-secondary-button" type="button" disabled={disabled} onClick={() => { setSportScopes([]); setTeamScopes([]); }}>
          Use All coverage
        </button>
      ) : null}
      <button className="news-primary-button" type="button" disabled={disabled || !changed} onClick={() => onSave(entry, sportScopes, teamScopes)}>
        Save scopes
      </button>
    </fieldset>
  );
}

export function AddToFeedDialog({
  signedIn,
  following,
  demoUniverse,
  demoSelections,
  navigation,
  discoveryTeamId,
  discoveryTeamName,
  onAccountChanged,
  onDemoSelectionsChange,
  onClose,
}: AddToFeedDialogProps) {
  const [activeTab, setActiveTab] = useState<AddToFeedTab>("add");
  const [query, setQuery] = useState("");
  const [teamDiscovery, setTeamDiscovery] = useState(false);
  const [results, setResults] = useState<readonly NewsFollowTarget[]>([]);
  const [loadingResults, setLoadingResults] = useState(signedIn);
  const [busyKey, setBusyKey] = useState("");
  const [error, setError] = useState("");
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const dialogRef = useRef<HTMLElement>(null);
  const followedKeys = useMemo(() => new Set(following.map(targetKey)), [following]);
  const demoKeys = useMemo(() => new Set(demoSelections.map(targetKey)), [demoSelections]);

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeButtonRef.current?.focus();
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
      else trapDialogFocus(event, dialogRef.current);
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [onClose]);

  useEffect(() => {
    if (!signedIn) return;
    let current = true;
    void Promise.resolve().then(async () => {
      if (!current) return;
      setLoadingResults(true);
      setError("");
      try {
        const next = await searchNewsFollowTargets("", teamDiscovery ? discoveryTeamId : null);
        if (current) setResults(next);
      } catch (reason) {
        if (current) setError(reason instanceof Error ? reason.message : "Add to Feed could not be loaded.");
      } finally {
        if (current) setLoadingResults(false);
      }
    });
    return () => { current = false; };
  }, [discoveryTeamId, signedIn, teamDiscovery]);

  const runSearch = async () => {
    setLoadingResults(true);
    setError("");
    try {
      setResults(await searchNewsFollowTargets(query, teamDiscovery ? discoveryTeamId : null));
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Add to Feed search failed.");
    } finally {
      setLoadingResults(false);
    }
  };

  const runAccountAction = async (keyValue: string, action: () => Promise<void>) => {
    setBusyKey(keyValue);
    setError("");
    try {
      await action();
      await onAccountChanged();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Your News preference could not be saved.");
    } finally {
      setBusyKey("");
    }
  };

  const toggleDemoTarget = (target: NewsFollowTarget) => {
    const keyValue = targetKey(target);
    onDemoSelectionsChange(demoKeys.has(keyValue)
      ? demoSelections.filter((selection) => targetKey(selection) !== keyValue)
      : [...demoSelections, { targetType: target.targetType, targetId: target.targetId }]);
  };

  const addResults = signedIn ? results : demoUniverse;
  const managedDemoTargets = demoUniverse.filter((target) => demoKeys.has(targetKey(target)));

  return (
    <div className="source-manager-layer">
      <button className="news-layer-backdrop" type="button" aria-label="Close Add to Feed" onClick={onClose} />
      <section ref={dialogRef} id="add-to-feed" className="source-manager" role="dialog" aria-modal="true" aria-labelledby="add-to-feed-title">
        <header className="source-manager__header">
          <div>
            <span className="eyebrow">Your News</span>
            <h2 id="add-to-feed-title">Add to Feed</h2>
          </div>
          <button ref={closeButtonRef} className="news-icon-button" type="button" aria-label="Close Add to Feed" onClick={onClose}><AppIcon name="x-mark" /></button>
        </header>

        <div className="source-manager__tabs" role="tablist" aria-label="Add to Feed sections">
          {([[
            "add", "Add to Feed",
          ], [
            "following", "Following",
          ], [
            "how-to", "How It Works",
          ]] as const).map(([id, label]) => (
            <button key={id} type="button" role="tab" aria-selected={activeTab === id} className={activeTab === id ? "source-manager__tab source-manager__tab--active" : "source-manager__tab"} onClick={() => setActiveTab(id)}>
              {label}
            </button>
          ))}
        </div>

        <div className="source-manager__body">
          {error ? <p className="news-inline-error" role="alert">{error}</p> : null}

          {activeTab === "add" ? (
            <section className="source-manager__panel" role="tabpanel">
              <div className="source-manager__intro">
                <h3>{signedIn ? "Find a contributor or Show" : "Choose from the Demo universe"}</h3>
                <p>{signedIn
                  ? "Follow individual Authors, genuine organizational contributors, and Shows. Publishers and Teams are not follow targets."
                  : "These real identities are the complete staff-approved Demo universe. Your choices stay only in this browser runtime."}</p>
              </div>
              {signedIn ? (
                <form className="source-search" role="search" onSubmit={(event) => { event.preventDefault(); void runSearch(); }}>
                  <label htmlFor="news-follow-search">Search Add to Feed</label>
                  <div className="source-search__row">
                    <input id="news-follow-search" type="search" value={query} onChange={(event) => setQuery(event.target.value)} />
                    <button className="news-primary-button" type="submit" disabled={loadingResults}>Search</button>
                  </div>
                  {discoveryTeamId ? (
                    <label className="source-search__team-context">
                      <input type="checkbox" checked={teamDiscovery} onChange={(event) => setTeamDiscovery(event.target.checked)} />
                      <span>Show identities with published work for {discoveryTeamName}</span>
                    </label>
                  ) : null}
                </form>
              ) : null}
              {loadingResults ? <p className="news-loading-state" role="status">Loading Add to Feed…</p> : null}
              {!loadingResults ? (
                <div className="source-catalog">
                  {addResults.map((target) => {
                    const keyValue = targetKey(target);
                    const active = signedIn ? followedKeys.has(keyValue) : demoKeys.has(keyValue);
                    return (
                      <article className="source-card" key={keyValue}>
                        <span className="news-source-avatar" aria-hidden="true">{target.displayName.slice(0, 2).toUpperCase()}</span>
                        <div>
                          <div className="source-card__heading"><h3>{target.displayName}</h3><small>{identityLabel(target)}</small></div>
                          <p>{signedIn ? "Add this identity's attributed work to your personal feed." : "Available in the configured Demo universe."}</p>
                        </div>
                        <button
                          className="source-card__action source-card__action--primary"
                          type="button"
                          disabled={signedIn ? active || Boolean(busyKey) : false}
                          aria-pressed={!signedIn ? active : undefined}
                          onClick={() => signedIn
                            ? void runAccountAction(keyValue, () => followNewsTarget(target))
                            : toggleDemoTarget(target)}
                        >
                          {signedIn ? (active ? "Following" : busyKey === keyValue ? "Adding…" : "Add") : active ? "Following" : "Follow"}
                        </button>
                      </article>
                    );
                  })}
                  {!addResults.length ? <p className="news-empty-panel">No eligible identity matches this view.</p> : null}
                </div>
              ) : null}
            </section>
          ) : null}

          {activeTab === "following" ? (
            <section className="source-manager__panel" role="tabpanel">
              <div className="source-manager__intro">
                <h3>Following</h3>
                <p>{signedIn
                  ? "Manage All, Sport, or Team coverage, temporary mute, unmute, and unfollow."
                  : "Demo follows are temporary, have no scopes or mute, and are never saved to an account."}</p>
              </div>
              {signedIn ? following.map((entry) => {
                const keyValue = targetKey(entry);
                const followId = entry.followIds[0];
                const busy = Boolean(busyKey);
                return (
                  <article className="managed-source" key={keyValue}>
                    <div className="managed-source__heading">
                      <span className="news-source-avatar" aria-hidden="true">{entry.displayName.slice(0, 2).toUpperCase()}</span>
                      <div>
                        <h3>{entry.displayName}</h3>
                        <small>{entry.mutedUntil ? `Muted through ${formatMuteExpiry(entry.mutedUntil)}` : identityLabel(entry)}</small>
                      </div>
                    </div>
                    {entry.needsReselection ? <p className="news-inline-warning" role="status">This Author identity is unavailable or changed after governed identity history. You can still mute it or unfollow it, then choose the intended current Author again.</p> : null}
                    <ScopeEditor
                      key={`${keyValue}:${entry.sportScopeIds.join(",")}:${entry.teamScopeIds.join(",")}`}
                      entry={entry}
                      navigation={navigation}
                      disabled={busy || !followId || entry.needsReselection}
                      onSave={(selected, sports, teams) => runAccountAction(`${keyValue}:scopes`, () => setNewsFollowScopes(selected.followIds, sports, teams))}
                    />
                    <div className="managed-source__controls">
                      {entry.mutedUntil ? (
                        <button type="button" disabled={busy || !followId} onClick={() => followId && void runAccountAction(`${keyValue}:unmute`, () => unmuteNewsFollow(followId))}>Unmute now</button>
                      ) : (
                        <>
                          <button type="button" disabled={busy || !followId} onClick={() => followId && void runAccountAction(`${keyValue}:mute-7`, () => muteNewsFollow(followId, "7_days"))}>Mute 7 days</button>
                          <button type="button" disabled={busy || !followId} onClick={() => followId && void runAccountAction(`${keyValue}:mute-30`, () => muteNewsFollow(followId, "30_days"))}>Mute 30 days</button>
                        </>
                      )}
                      <button className="managed-source__remove" type="button" disabled={busy || !followId} onClick={() => followId && void runAccountAction(`${keyValue}:remove`, () => unfollowNewsTarget(followId))}>Unfollow</button>
                    </div>
                  </article>
                );
              }) : managedDemoTargets.map((target) => (
                <article className="managed-source" key={targetKey(target)}>
                  <div className="managed-source__heading">
                    <span className="news-source-avatar" aria-hidden="true">{target.displayName.slice(0, 2).toUpperCase()}</span>
                    <div><h3>{target.displayName}</h3><small>{identityLabel(target)} · Demo only</small></div>
                  </div>
                  <div className="managed-source__controls">
                    <button className="managed-source__remove" type="button" onClick={() => toggleDemoTarget(target)}>Unfollow</button>
                  </div>
                </article>
              ))}
              {(signedIn ? following : managedDemoTargets).length === 0 ? <p className="news-empty-panel">You are not following any News identities.</p> : null}
            </section>
          ) : null}

          {activeTab === "how-to" ? (
            <section className="source-manager__panel source-how-to" role="tabpanel">
              <div><strong>1</strong><span><h3>Choose an identity</h3><p>Follow an individual Author, organizational contributor, or Show—not a publisher or Team.</p></span></div>
              <div><strong>2</strong><span><h3>Set optional coverage</h3><p>Signed-in fans may leave coverage at All or choose several Sport and Team scopes. Selected scopes match with OR.</p></span></div>
              <div><strong>3</strong><span><h3>Keep the feed chronological</h3><p>Temporary page filters narrow already-eligible Items and never change your global selected Team.</p></span></div>
              {!signedIn ? <p className="source-how-to__note">Demo mode — sign in to save your feed.</p> : null}
            </section>
          ) : null}
        </div>
      </section>
    </div>
  );
}
