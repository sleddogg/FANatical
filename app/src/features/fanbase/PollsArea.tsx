import { useEffect, useMemo, useRef, useState } from "react";
import type { TeamId } from "../../domain/team";
import { findFollowedTeam } from "../../data/followedTeams";
import { useFanbaseContext } from "./FanbaseContext";
import { PollScopeSelector } from "./PollScopeSelector";
import {
  activePollsForScope,
  pollScopeEquals,
  pollScopeForFollowedTeam,
  pollScopeLabel,
  pollsForScope,
  pollTotalVotes,
  searchPolls,
} from "./polls";
import type { FanPoll, PollScope } from "./types";

type PollView = "active" | "browse";

function formatPollDate(value: string) {
  return new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric", year: "numeric" }).format(new Date(value));
}

function PollResults({ poll }: { readonly poll: FanPoll }) {
  const totalVotes = pollTotalVotes(poll);
  return <div className="poll-results" aria-label={`Results for ${poll.question}`}>{poll.options.map((option) => { const percentage = totalVotes ? Math.round(option.voteCount / totalVotes * 100) : 0; return <div key={option.id} className={option.id === poll.viewerOptionId ? "poll-result poll-result--selected" : "poll-result"}><div><strong>{option.label}</strong><span>{percentage}%</span></div><span className="poll-result__track"><span style={{ width: `${percentage}%` }} /></span><small>{option.voteCount.toLocaleString()} votes{option.id === poll.viewerOptionId ? " · Your vote" : ""}</small></div>; })}<p>{totalVotes.toLocaleString()} total votes</p></div>;
}

function PollCard({ poll, resultsVisible, onVote, onShare, onOpenPrevious }: {
  readonly poll: FanPoll;
  readonly resultsVisible: boolean;
  readonly onVote: (optionId: string) => void;
  readonly onShare: () => void;
  readonly onOpenPrevious: (pollId: string) => void;
}) {
  return (
    <article className="poll-card surface">
      <header><span>{pollScopeLabel(poll.scope)}</span><time dateTime={poll.createdAt}>{formatPollDate(poll.createdAt)}</time></header>
      <h2>{poll.question}</h2>
      {resultsVisible || poll.viewerOptionId ? <PollResults poll={poll} /> : <div className="poll-options" aria-label="Poll answers">{poll.options.map((option) => <button key={option.id} type="button" onClick={() => onVote(option.id)}>{option.label}</button>)}</div>}
      <footer>
        <div className="poll-topics" aria-label="Poll topics">{poll.topics.slice(0, 4).map((topic) => <span key={topic}>{topic}</span>)}</div>
        <div className="poll-actions">{poll.linkedPreviousPollId ? <button type="button" onClick={() => onOpenPrevious(poll.linkedPreviousPollId!)}>Previous Poll</button> : null}<button type="button" onClick={onShare}>Share</button></div>
      </footer>
    </article>
  );
}

function RelatedPollDialog({ poll, onClose }: { readonly poll: FanPoll; readonly onClose: () => void }) {
  return <div className="fanbase-dialog-layer poll-dialog-layer" role="presentation"><button className="fanbase-backdrop" type="button" aria-label="Close previous Poll results" onClick={onClose} /><section className="poll-dialog poll-related-dialog" role="dialog" aria-modal="true" aria-labelledby="related-poll-title"><header><div><span className="eyebrow">Previous Poll</span><small>{pollScopeLabel(poll.scope)}</small></div><h2 id="related-poll-title">Compare results</h2><button type="button" aria-label="Close previous Poll results" onClick={onClose}>×</button></header><div className="poll-related-dialog__body"><h3>{poll.question}</h3><PollResults poll={poll} /></div></section></div>;
}

export function PollsArea({ teamId, itemId }: { readonly teamId: TeamId; readonly itemId: string | null }) {
  const fanbase = useFanbaseContext();
  const followedTeam = findFollowedTeam(teamId);
  const defaultScope = useMemo<PollScope>(() => pollScopeForFollowedTeam(followedTeam ?? findFollowedTeam("new-england-patriots")!), [followedTeam]);
  const selectedPoll = itemId ? fanbase.polls.find((poll) => poll.id === itemId) ?? null : null;
  const [scope, setScope] = useState<PollScope>(() => selectedPoll?.scope ?? defaultScope);
  const [view, setView] = useState<PollView>("active");
  const [scopeOpen, setScopeOpen] = useState(false);
  const [browseQuery, setBrowseQuery] = useState("");
  const [revealedPollId, setRevealedPollId] = useState<string | null>(null);
  const [relatedPollId, setRelatedPollId] = useState<string | null>(null);
  const [notice, setNotice] = useState("");
  const revealTimer = useRef<number | null>(null);

  useEffect(() => {
    if (selectedPoll) setScope(selectedPoll.scope);
    else setScope(defaultScope);
  }, [defaultScope, selectedPoll]);

  useEffect(() => () => {
    if (revealTimer.current !== null) window.clearTimeout(revealTimer.current);
  }, []);

  const scopedPolls = useMemo(() => pollsForScope(fanbase.polls, scope), [fanbase.polls, scope]);
  const activePolls = useMemo(() => {
    const unanswered = activePollsForScope(fanbase.polls, scope);
    const revealed = revealedPollId ? fanbase.polls.find((poll) => poll.id === revealedPollId && pollScopeEquals(poll.scope, scope)) : null;
    return revealed ? [revealed, ...unanswered.filter((poll) => poll.id !== revealed.id)].slice(0, 10) : unanswered;
  }, [fanbase.polls, revealedPollId, scope]);
  const browsePolls = useMemo(() => {
    const matching = browseQuery.trim() ? searchPolls(scopedPolls, browseQuery) : [...scopedPolls];
    return matching.sort((first, second) => Date.parse(second.createdAt) - Date.parse(first.createdAt));
  }, [browseQuery, scopedPolls]);
  const relatedPoll = relatedPollId ? fanbase.polls.find((poll) => poll.id === relatedPollId) ?? null : null;

  const vote = (pollId: string, optionId: string) => {
    fanbase.voteInPoll(pollId, optionId);
    setRevealedPollId(pollId);
    if (revealTimer.current !== null) window.clearTimeout(revealTimer.current);
    revealTimer.current = window.setTimeout(() => setRevealedPollId((current) => current === pollId ? null : current), 1_800);
  };

  const share = async (poll: FanPoll) => {
    const url = `${window.location.origin}/fanbase?area=polls&item=${encodeURIComponent(poll.id)}`;
    try {
      if (navigator.share) await navigator.share({ title: "FANatical Poll", text: poll.question, url });
      else if (navigator.clipboard) await navigator.clipboard.writeText(url);
      setNotice("Poll link ready to share.");
    } catch {
      setNotice("Sharing was cancelled.");
    }
  };

  if (selectedPoll) {
    return <section className="polls-area polls-area--detail"><div className="poll-detail-context"><span className="eyebrow">Shared FANbase Poll</span><strong>{pollScopeLabel(selectedPoll.scope)}</strong><span>One canonical Poll record · {selectedPoll.createdBy.username}</span></div><PollCard poll={selectedPoll} resultsVisible={selectedPoll.viewerOptionId !== null || revealedPollId === selectedPoll.id} onVote={(optionId) => vote(selectedPoll.id, optionId)} onShare={() => void share(selectedPoll)} onOpenPrevious={setRelatedPollId} />{selectedPoll.linkedPreviousPollId ? <section className="poll-follow-up-context"><span className="eyebrow">Follow-up Poll</span><p>This question continues an earlier fan conversation. Open the previous results to compare how opinion changed.</p><button type="button" onClick={() => setRelatedPollId(selectedPoll.linkedPreviousPollId)}>Compare previous results</button></section> : null}<p className="poll-share-notice" role="status">{notice}</p>{relatedPoll ? <RelatedPollDialog poll={relatedPoll} onClose={() => setRelatedPollId(null)} /> : null}</section>;
  }

  const visiblePolls = view === "active" ? activePolls : browsePolls;
  return (
    <section className="polls-area">
      <div className="polls-toolbar surface">
        <div><span className="eyebrow">Poll scope</span><h2>{pollScopeLabel(scope)}</h2><p>{scope.kind === "team" ? "Team-specific Polls" : scope.kind === "league" ? "League-wide Polls" : "Sport-wide Polls"}</p></div>
        <button type="button" onClick={() => setScopeOpen(true)}>Change Poll scope <span aria-hidden="true">⌄</span></button>
      </div>
      <div className="poll-view-tabs" role="tablist" aria-label="Poll views"><button type="button" role="tab" aria-selected={view === "active"} onClick={() => setView("active")}>Active</button><button type="button" role="tab" aria-selected={view === "browse"} onClick={() => setView("browse")}>Browse</button></div>
      {view === "active" ? <div className="poll-view-intro"><div><span className="eyebrow">Trending now</span><h2>Unanswered Polls</h2></div><p>Recent questions with active voting rise to the top. Vote to reveal results and bring another Poll into your queue.</p></div> : <label className="poll-browse-search"><span>Search Polls</span><input type="search" value={browseQuery} placeholder={`Search ${pollScopeLabel(scope)} Polls`} onChange={(event) => setBrowseQuery(event.target.value)} /></label>}
      <div className="poll-list" aria-live="polite">{visiblePolls.map((poll) => <PollCard key={poll.id} poll={poll} resultsVisible={poll.viewerOptionId !== null || revealedPollId === poll.id} onVote={(optionId) => vote(poll.id, optionId)} onShare={() => void share(poll)} onOpenPrevious={setRelatedPollId} />)}{!visiblePolls.length ? <div className="fanbase-empty surface"><span aria-hidden="true">◌</span><p>{view === "active" ? "You’re caught up for this scope. Browse the Poll history or try another team, league, or sport." : "No Polls match that search in this scope."}</p></div> : null}</div>
      <p className="poll-share-notice" role="status">{notice}</p>
      {scopeOpen ? <PollScopeSelector currentScope={scope} onSelect={(nextScope) => { setScope(nextScope); setBrowseQuery(""); setRevealedPollId(null); setScopeOpen(false); }} onClose={() => setScopeOpen(false)} /> : null}
      {relatedPoll ? <RelatedPollDialog poll={relatedPoll} onClose={() => setRelatedPollId(null)} /> : null}
    </section>
  );
}

