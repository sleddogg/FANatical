import { useEffect, useMemo, useRef, useState } from "react";
import type { FollowedSourcePreference, NewsContentType, NewsSource } from "./types";
import { AppIcon } from "../../components/AppIcon";
import { trapDialogFocus } from "./dialogKeyboard";

type SourceManagerTab = "add" | "manage" | "how-to";

type SourceManagerDialogProps = {
  readonly sourceCatalog: readonly NewsSource[];
  readonly preferences: readonly FollowedSourcePreference[];
  readonly onFollow: (source: NewsSource, contentTypes: readonly NewsContentType[]) => void;
  readonly onRemove: (sourceId: string) => void;
  readonly onToggleContentType: (sourceId: string, contentType: NewsContentType) => void;
  readonly onMute: (sourceId: string, duration: "week" | "month" | "unmute") => void;
  readonly onClose: () => void;
};

function getPreference(
  preferences: readonly FollowedSourcePreference[],
  sourceId: string,
) {
  return preferences.find((preference) => preference.sourceId === sourceId);
}

export function SourceManagerDialog({
  sourceCatalog,
  preferences,
  onFollow,
  onRemove,
  onToggleContentType,
  onMute,
  onClose,
}: SourceManagerDialogProps) {
  const [activeTab, setActiveTab] = useState<SourceManagerTab>("add");
  const [query, setQuery] = useState("");
  const [requestedSources, setRequestedSources] = useState<readonly string[]>([]);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const dialogRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeButtonRef.current?.focus();

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
      } else {
        trapDialogFocus(event, dialogRef.current);
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [onClose]);

  const normalizedQuery = query.trim().toLowerCase();
  const results = useMemo(
    () => sourceCatalog.filter((source) => (
      !normalizedQuery
      || source.name.toLowerCase().includes(normalizedQuery)
      || source.category.toLowerCase().includes(normalizedQuery)
      || source.sportTags.some((tag) => tag.includes(normalizedQuery))
    )),
    [normalizedQuery, sourceCatalog],
  );

  const followedSources = sourceCatalog.filter((source) => getPreference(preferences, source.id));
  const canRequestQuery = normalizedQuery.length > 1 && results.length === 0;
  const requested = requestedSources.some((name) => name.toLowerCase() === normalizedQuery);

  const requestSource = () => {
    const sourceName = query.trim();
    if (!sourceName || requested) {
      return;
    }
    setRequestedSources((current) => [...current, sourceName]);
  };

  return (
    <div className="source-manager-layer">
      <button className="news-layer-backdrop" type="button" aria-label="Close Source Manager" onClick={onClose} />
      <section ref={dialogRef} id="source-manager" className="source-manager" role="dialog" aria-modal="true" aria-labelledby="source-manager-title">
        <header className="source-manager__header">
          <div>
            <span className="eyebrow">Your News</span>
            <h2 id="source-manager-title">Source Manager</h2>
          </div>
          <button ref={closeButtonRef} className="news-icon-button" type="button" aria-label="Close Source Manager" onClick={onClose}><AppIcon name="x-mark" /></button>
        </header>

        <div className="source-manager__tabs" role="tablist" aria-label="Source Manager sections">
          {([
            ["add", "Add Source"],
            ["manage", "Manage Sources"],
            ["how-to", "How To"],
          ] as const).map(([id, label]) => (
            <button
              key={id}
              type="button"
              role="tab"
              aria-selected={activeTab === id}
              className={activeTab === id ? "source-manager__tab source-manager__tab--active" : "source-manager__tab"}
              onClick={() => setActiveTab(id)}
            >
              {label}
            </button>
          ))}
        </div>

        <div className="source-manager__body">
          {activeTab === "add" ? (
            <section className="source-manager__panel" role="tabpanel">
              <label className="source-search">
                <span>Search the FANatical Source Catalog</span>
                <input
                  type="search"
                  value={query}
                  placeholder="Source, creator, podcast, or sport"
                  onChange={(event) => setQuery(event.target.value)}
                />
              </label>

              <div className="source-catalog" aria-live="polite">
                {results.map((source) => {
                  const preference = getPreference(preferences, source.id);
                  const isAvailable = source.accessStatus === "usable";
                  return (
                    <article className="source-card" key={source.id}>
                      <span className="news-source-avatar" aria-hidden="true">{source.initials}</span>
                      <div className="source-card__copy">
                        <div className="source-card__heading">
                          <h3>{source.name}</h3>
                          <small>{source.category}</small>
                        </div>
                        <p>{source.description}</p>
                        <div className="source-card__types">
                          {source.contentTypes.map((contentType) => <span key={contentType}>{contentType}</span>)}
                        </div>
                      </div>
                      {preference ? (
                        <button className="source-card__action" type="button" disabled>Following</button>
                      ) : isAvailable ? (
                        <button className="source-card__action source-card__action--primary" type="button" onClick={() => onFollow(source, source.contentTypes)}>
                          Follow
                        </button>
                      ) : (
                        <button
                          className="source-card__action"
                          type="button"
                          onClick={() => setRequestedSources((current) => current.includes(source.name) ? current : [...current, source.name])}
                        >
                          {requestedSources.includes(source.name) ? "Requested" : "Request"}
                        </button>
                      )}
                    </article>
                  );
                })}

                {canRequestQuery ? (
                  <div className="source-request surface">
                    <AppIcon name="plus" />
                    <div>
                      <h3>Can’t find “{query.trim()}”?</h3>
                      <p>Request it for a future catalog review. This demo keeps the request only until you leave the page.</p>
                    </div>
                    <button className="source-card__action source-card__action--primary" type="button" disabled={requested} onClick={requestSource}>
                      {requested ? "Requested" : "Request Source"}
                    </button>
                  </div>
                ) : null}
              </div>
            </section>
          ) : null}

          {activeTab === "manage" ? (
            <section className="source-manager__panel" role="tabpanel">
              <div className="source-manager__intro">
                <h3>Followed sources</h3>
                <p>Choose the formats each source contributes, temporarily mute it, or remove it from your News feed.</p>
              </div>
              {followedSources.length ? followedSources.map((source) => {
                const preference = getPreference(preferences, source.id);
                if (!preference) {
                  return null;
                }
                const isMuted = Boolean(preference.mutedUntil && Date.parse(preference.mutedUntil) > Date.now());
                return (
                  <article className="managed-source" key={source.id}>
                    <div className="managed-source__heading">
                      <span className="news-source-avatar" aria-hidden="true">{source.initials}</span>
                      <div><h3>{source.name}</h3><small>{isMuted ? "Muted" : "Active in your feed"}</small></div>
                    </div>
                    <fieldset>
                      <legend>Content types</legend>
                      <div className="managed-source__types">
                        {source.contentTypes.map((contentType) => (
                          <label key={contentType}>
                            <input
                              type="checkbox"
                              checked={preference.contentTypes.includes(contentType)}
                              onChange={() => onToggleContentType(source.id, contentType)}
                            />
                            <span>{contentType}</span>
                          </label>
                        ))}
                      </div>
                    </fieldset>
                    <div className="managed-source__controls">
                      {isMuted ? (
                        <button type="button" onClick={() => onMute(source.id, "unmute")}>Unmute</button>
                      ) : (
                        <>
                          <button type="button" onClick={() => onMute(source.id, "week")}>Mute 1 week</button>
                          <button type="button" onClick={() => onMute(source.id, "month")}>Mute 1 month</button>
                        </>
                      )}
                      <button className="managed-source__remove" type="button" onClick={() => onRemove(source.id)}>Remove</button>
                    </div>
                  </article>
                );
              }) : <p className="news-empty-state">You are not following any sources yet.</p>}
            </section>
          ) : null}

          {activeTab === "how-to" ? (
            <section className="source-manager__panel source-how-to" role="tabpanel">
              <div><strong>1</strong><span><h3>Follow sources you trust</h3><p>Browse the mock catalog and add outlets, creators, podcasts, and shows to your News.</p></span></div>
              <div><strong>2</strong><span><h3>Control what they contribute</h3><p>Keep only the content types you want. Muting or removing a source updates the feed immediately.</p></span></div>
              <div><strong>3</strong><span><h3>Choose your context</h3><p>Team, league, sport, and All Followed News views use the same source preferences and stay newest-first.</p></span></div>
              <p className="source-how-to__note">Catalog search, follows, mutes, and requests are local mock interactions for this frontend task. Account sync will come with a backend later.</p>
            </section>
          ) : null}
        </div>
      </section>
    </div>
  );
}
