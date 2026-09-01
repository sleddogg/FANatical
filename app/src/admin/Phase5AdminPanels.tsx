import { useCallback, useEffect, useRef, useState, type FormEvent } from "react";
import {
  loadCommunityModerationQueue,
  loadActiveCommunityPostingRestrictions,
  loadNewsRequestQueue,
  liftCommunityPostingRestriction,
  moderateCommunityReport,
  resolveNewsRequest,
  searchNewsRequestFollowTargets,
  type CommunityModerationQueueEntry,
  type ActiveCommunityPostingRestriction,
  type NewsRequestFollowTarget,
  type NewsRequestQueueEntry,
} from "./phase5aAdminRepository";

export function CommunityModerationPanel() {
  const [reports, setReports] = useState<readonly CommunityModerationQueueEntry[]>([]);
  const [restrictions, setRestrictions] = useState<readonly ActiveCommunityPostingRestriction[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const refreshEpoch = useRef(0);

  const refresh = useCallback(async () => {
    const epoch = ++refreshEpoch.current;
    setLoading(true);
    setError("");
    setReports([]);
    setRestrictions([]);
    try {
      const [nextReports, nextRestrictions] = await Promise.all([
        loadCommunityModerationQueue(),
        loadActiveCommunityPostingRestrictions(),
      ]);
      if (epoch === refreshEpoch.current) {
        setReports(nextReports);
        setRestrictions(nextRestrictions);
      }
    } catch (reason) {
      if (epoch === refreshEpoch.current) {
        setReports([]);
        setRestrictions([]);
        setError(reason instanceof Error ? reason.message : "Community moderation could not be loaded.");
      }
    } finally {
      if (epoch === refreshEpoch.current) setLoading(false);
    }
  }, []);

  useEffect(() => {
    void Promise.resolve().then(refresh);
    return () => { refreshEpoch.current += 1; };
  }, [refresh]);
  return (
    <section className="admin-review" aria-labelledby="community-moderation-title">
      <header className="admin-review__header"><div><p className="admin-kicker">Explicit permission</p><h2 id="community-moderation-title">Community moderation</h2><p>Reports and append-only moderation actions. Catalog wildcard access does not authorize this queue.</p></div><button className="admin-button admin-button--secondary" type="button" onClick={() => void refresh()}>Refresh</button></header>
      {loading ? <p role="status">Loading Community reports…</p> : null}
      {error ? <p className="admin-message admin-message--error" role="alert">{error}</p> : null}
      <h3>Pending reports</h3>
      {!loading && !reports.length ? <p className="admin-review-empty">No pending Community reports.</p> : null}
      {reports.map((report) => <ModerationCard key={report.reportId} report={report} onDone={refresh} />)}
      <h3>Active posting restrictions</h3>
      {!loading && !restrictions.length ? <p className="admin-review-empty">No active Community posting restrictions.</p> : null}
      {restrictions.map((restriction) => <RestrictionCard key={restriction.restrictionId} restriction={restriction} onDone={refresh} />)}
    </section>
  );
}

function RestrictionCard({ restriction, onDone }: { readonly restriction: ActiveCommunityPostingRestriction; readonly onDone: () => Promise<void> }) {
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  return (
    <article className="admin-review-case">
      <header className="admin-review-case__header">
        <div>
          <p className="admin-kicker">Restriction {restriction.ordinal}</p>
          <h3>{restriction.fanaticalName}</h3>
          <p>{restriction.reason}</p>
          <small>Active until {new Date(restriction.endsAt).toLocaleString()}</small>
        </div>
      </header>
      <form className="admin-review-answer" onSubmit={(event: FormEvent) => {
        event.preventDefault();
        setBusy(true);
        setMessage("");
        void liftCommunityPostingRestriction(restriction.restrictionId, reason)
          .then(async () => { setMessage("Posting restriction lifted."); await onDone(); })
          .catch((failure: unknown) => setMessage(failure instanceof Error ? failure.message : "Restriction lift failed."))
          .finally(() => setBusy(false));
      }}>
        <label>Lift reason<textarea required rows={2} value={reason} onChange={(event) => setReason(event.target.value)} /></label>
        {message ? <p role="status">{message}</p> : null}
        <button className="admin-button" type="submit" disabled={busy || !reason.trim()}>{busy ? "Lifting…" : "Lift restriction"}</button>
      </form>
    </article>
  );
}

function ModerationCard({ report, onDone }: { readonly report: CommunityModerationQueueEntry; readonly onDone: () => Promise<void> }) {
  const [action, setAction] = useState<"dismiss" | "tombstone" | "restrict">("dismiss");
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  return <article className="admin-review-case"><header className="admin-review-case__header"><div><p className="admin-kicker">{report.reason} · reported by {report.reporterFanaticalName ?? "fan with no current name"}</p><h3>{report.authorFanaticalName ?? "Author with no current name"}</h3><p>{report.commentBody}</p></div><span>{report.priorRestrictionCount} prior restrictions</span></header>{report.explanation ? <p><strong>Explanation:</strong> {report.explanation}</p> : null}<form className="admin-review-answer" onSubmit={(event: FormEvent) => { event.preventDefault(); setBusy(true); setMessage(""); void moderateCommunityReport(report.reportId, action, reason).then(async () => { setMessage("Moderation action recorded."); await onDone(); }).catch((failure: unknown) => setMessage(failure instanceof Error ? failure.message : "Action failed.")).finally(() => setBusy(false)); }}><label>Action<select value={action} onChange={(event) => setAction(event.target.value as typeof action)}><option value="dismiss">Dismiss report</option><option value="tombstone">Remove comment</option><option value="restrict">Restrict Community posting</option></select></label><label>Reason<textarea required rows={2} value={reason} onChange={(event) => setReason(event.target.value)} /></label>{message ? <p role="status">{message}</p> : null}<button className="admin-button" type="submit" disabled={busy}>{busy ? "Recording…" : "Record action"}</button></form></article>;
}

export function NewsRequestResolutionPanel() {
  const [requests, setRequests] = useState<readonly NewsRequestQueueEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const refreshEpoch = useRef(0);
  const refresh = useCallback(async () => {
    const epoch = ++refreshEpoch.current;
    setLoading(true);
    setError("");
    setRequests([]);
    try {
      const next = await loadNewsRequestQueue();
      if (epoch === refreshEpoch.current) setRequests(next);
    } catch (reason) {
      if (epoch === refreshEpoch.current) {
        setRequests([]);
        setError(reason instanceof Error ? reason.message : "News Requests could not be loaded.");
      }
    } finally {
      if (epoch === refreshEpoch.current) setLoading(false);
    }
  }, []);
  useEffect(() => {
    void Promise.resolve().then(refresh);
    return () => { refreshEpoch.current += 1; };
  }, [refresh]);
  return <section className="admin-review" aria-labelledby="news-request-resolution-title"><header className="admin-review__header"><div><p className="admin-kicker">Add to Feed</p><h2 id="news-request-resolution-title">Request resolution</h2><p>Resolve shared candidates without creating a News identity-decision action or automatically Following for requesters.</p></div><button className="admin-button admin-button--secondary" type="button" onClick={() => void refresh()}>Refresh</button></header>{loading ? <p role="status">Loading Requests…</p> : null}{error ? <p className="admin-message admin-message--error" role="alert">{error}</p> : null}{!loading && !requests.length ? <p className="admin-review-empty">No pending Requests.</p> : null}{requests.map((request) => <RequestCard key={request.targetId} request={request} onDone={refresh} />)}</section>;
}

function RequestCard({ request, onDone }: { readonly request: NewsRequestQueueEntry; readonly onDone: () => Promise<void> }) {
  const [outcome, setOutcome] = useState<"available" | "unable">("unable");
  const [followTarget, setFollowTarget] = useState<NewsRequestFollowTarget | null>(null);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  return <article className="admin-review-case"><header className="admin-review-case__header"><div><p className="admin-kicker">{request.inputKind} · {request.requesterCount} requesters</p><h3>{request.displayInput}</h3><small>{new Date(request.createdAt).toLocaleString()}</small></div></header><form className="admin-review-answer" onSubmit={(event: FormEvent) => { event.preventDefault(); if (outcome === "available" && !followTarget) { setMessage("Choose the current followable News identity first."); return; } setBusy(true); setMessage(""); void resolveNewsRequest(request.targetId, outcome, reason, followTarget ? { type: followTarget.targetType, id: followTarget.targetId } : undefined).then(async () => { setMessage("Request outcome recorded and each requester notified once."); await onDone(); }).catch((failure: unknown) => setMessage(failure instanceof Error ? failure.message : "Resolution failed.")).finally(() => setBusy(false)); }}><label>Outcome<select value={outcome} onChange={(event) => { const next = event.target.value as typeof outcome; setOutcome(next); if (next === "unable") setFollowTarget(null); }}><option value="unable">Unable to add</option><option value="available">Available</option></select></label>{outcome === "available" ? <NewsRequestTargetPicker initialQuery={request.displayInput} selected={followTarget} onSelect={setFollowTarget} /> : null}<label>Short staff reason<textarea required rows={2} value={reason} onChange={(event) => setReason(event.target.value)} /></label>{message ? <p role="status">{message}</p> : null}<button className="admin-button" type="submit" disabled={busy || (outcome === "available" && !followTarget)}>{busy ? "Resolving…" : "Resolve Request"}</button></form></article>;
}

function NewsRequestTargetPicker({
  initialQuery,
  selected,
  onSelect,
}: {
  readonly initialQuery: string;
  readonly selected: NewsRequestFollowTarget | null;
  readonly onSelect: (target: NewsRequestFollowTarget) => void;
}) {
  const [query, setQuery] = useState(initialQuery);
  const [results, setResults] = useState<readonly NewsRequestFollowTarget[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const searchEpoch = useRef(0);

  const search = useCallback(async () => {
    const epoch = ++searchEpoch.current;
    setLoading(true);
    setError("");
    setResults([]);
    try {
      const next = await searchNewsRequestFollowTargets(query);
      if (epoch === searchEpoch.current) setResults(next);
    } catch (reason) {
      if (epoch === searchEpoch.current) {
        setResults([]);
        setError(reason instanceof Error ? reason.message : "Current News targets could not be loaded.");
      }
    } finally {
      if (epoch === searchEpoch.current) setLoading(false);
    }
  }, [query]);

  useEffect(() => {
    void Promise.resolve().then(search);
    return () => { searchEpoch.current += 1; };
  }, [search]);

  return <fieldset><legend>Current followable News identity</legend><label>Search by name<input type="search" value={query} onChange={(event) => setQuery(event.target.value)} /></label><button className="admin-button admin-button--secondary" type="button" disabled={loading} onClick={() => void search()}>{loading ? "Searching…" : "Search"}</button>{error ? <p className="admin-message admin-message--error" role="alert">{error}</p> : null}<div className="admin-review-answer" role="list" aria-label="Current followable News identities">{results.map((target) => <div role="listitem" key={`${target.targetType}:${target.targetId}`}><button className="admin-button admin-button--secondary" type="button" aria-pressed={selected?.targetId === target.targetId && selected.targetType === target.targetType} onClick={() => onSelect(target)}>{target.displayName} · {target.targetType}</button></div>)}</div>{!loading && !error && !results.length ? <p>No current followable identity matches.</p> : null}{selected ? <p role="status">Selected: {selected.displayName} ({selected.targetType})</p> : null}</fieldset>;
}
