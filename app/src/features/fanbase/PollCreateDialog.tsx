import { useMemo, useState } from "react";
import {
  leaguesForSport,
  officialSports,
  teamsForLeague,
  type OfficialLeagueId,
  type OfficialSportId,
  type OfficialTeamId,
} from "../../data/officialSportsDatabase";
import { generatePollTopics, pollScopeLabel, searchPolls } from "./polls";
import type { CreatePollInput, FanPoll, PollScope } from "./types";
import { AppIcon } from "../../components/AppIcon";

const blankOptions = ["", "", "", ""];

function topicsFromText(value: string) {
  return [...new Set(value.split(",").map((topic) => topic.trim().toLocaleLowerCase()).filter(Boolean))].slice(0, 12);
}

export function PollCreateDialog({ polls, initialScope, onCreate, onClose }: {
  readonly polls: readonly FanPoll[];
  readonly initialScope: PollScope;
  readonly onCreate: (input: CreatePollInput) => string;
  readonly onClose: (createdPollId?: string) => void;
}) {
  const [question, setQuestion] = useState("");
  const [options, setOptions] = useState<string[]>(blankOptions);
  const [scopeKind, setScopeKind] = useState<PollScope["kind"]>(initialScope.kind);
  const [sportId, setSportId] = useState<OfficialSportId>(initialScope.sportId);
  const [leagueId, setLeagueId] = useState<OfficialLeagueId | null>(initialScope.leagueId);
  const [teamId, setTeamId] = useState<OfficialTeamId | null>(initialScope.teamId);
  const [topicsCustomized, setTopicsCustomized] = useState(false);
  const [topicText, setTopicText] = useState("");
  const [linkSearchOpen, setLinkSearchOpen] = useState(false);
  const [linkQuery, setLinkQuery] = useState("");
  const [linkedPreviousPollId, setLinkedPreviousPollId] = useState<string | null>(null);
  const [error, setError] = useState("");
  const leagues = leaguesForSport(sportId);
  const teams = teamsForLeague(leagueId);
  const generatedTopics = useMemo(() => generatePollTopics(question, options), [options, question]);
  const displayedTopics = topicsCustomized ? topicText : generatedTopics.join(", ");
  const linkedPoll = linkedPreviousPollId ? polls.find((poll) => poll.id === linkedPreviousPollId) ?? null : null;
  const linkResults = useMemo(() => linkQuery.trim() ? searchPolls(polls, linkQuery).slice(0, 8) : [...polls].sort((first, second) => Date.parse(second.createdAt) - Date.parse(first.createdAt)).slice(0, 6), [linkQuery, polls]);

  const updateSport = (nextSportId: OfficialSportId) => {
    setSportId(nextSportId);
    setLeagueId(null);
    setTeamId(null);
    if (scopeKind !== "sport" && !leaguesForSport(nextSportId).length) setScopeKind("sport");
  };

  const updateScopeKind = (nextKind: PollScope["kind"]) => {
    setScopeKind(nextKind);
    if (nextKind === "sport") {
      setLeagueId(null);
      setTeamId(null);
    } else if (nextKind === "league") {
      setTeamId(null);
    }
  };

  const selectedScope = (): PollScope | null => {
    if (scopeKind === "sport") return { kind: "sport", sportId, leagueId: null, teamId: null };
    if (!leagueId) return null;
    if (scopeKind === "league") return { kind: "league", sportId, leagueId, teamId: null };
    return teamId ? { kind: "team", sportId, leagueId, teamId } : null;
  };

  const submit = () => {
    const scope = selectedScope();
    const completeOptions = options.map((option) => option.trim()).filter(Boolean);
    if (!question.trim()) return setError("Add a Poll question.");
    if (completeOptions.length < 2 || completeOptions.length !== options.length) return setError("Complete every answer option, with at least two choices.");
    if (new Set(completeOptions.map((option) => option.toLocaleLowerCase())).size !== completeOptions.length) return setError("Each answer option must be different.");
    if (!scope) return setError(scopeKind === "team" ? "Choose a League and Team." : "Choose a League.");
    const topics = topicsCustomized ? topicsFromText(topicText) : generatedTopics;
    const createdPollId = onCreate({ question: question.trim(), options: completeOptions, scope, topics, linkedPreviousPollId });
    onClose(createdPollId);
  };

  return (
    <div className="fanbase-dialog-layer poll-dialog-layer" role="presentation">
      <button className="fanbase-backdrop" type="button" aria-label="Cancel Create Poll" onClick={() => onClose()} />
      <section className="poll-dialog poll-create-dialog" role="dialog" aria-modal="true" aria-labelledby="create-poll-title">
        <header><div><span className="eyebrow">FANbase Polls</span><small>One Poll, one canonical scope</small></div><h2 id="create-poll-title">Create Poll</h2><button type="button" aria-label="Cancel Create Poll" onClick={() => onClose()}><AppIcon name="x-mark" /></button></header>
        <div className="poll-create-dialog__body">
          <label><span>Poll question</span><textarea rows={3} value={question} placeholder="What do you want fans to decide?" onChange={(event) => setQuestion(event.target.value)} /></label>

          <fieldset className="poll-create-options"><legend>Answer options</legend>{options.map((option, index) => <div className="poll-create-option-row" key={index}><label><span>Option {index + 1}</span><input value={option} onChange={(event) => setOptions((current) => current.map((value, optionIndex) => optionIndex === index ? event.target.value : value))} /></label>{options.length > 2 ? <button type="button" aria-label={`Remove option ${index + 1}`} onClick={() => setOptions((current) => current.filter((_, optionIndex) => optionIndex !== index))}><AppIcon name="x-mark" /></button> : null}</div>)}{options.length < 6 ? <button className="poll-create-add-option" type="button" onClick={() => setOptions((current) => [...current, ""])}><AppIcon name="plus" /> Add option</button> : null}</fieldset>

          <fieldset className="poll-create-scope"><legend>Poll scope</legend><div className="poll-create-scope__kinds">{(["sport", "league", "team"] as const).map((kind) => <button key={kind} type="button" aria-pressed={scopeKind === kind} disabled={kind !== "sport" && !leagues.length} onClick={() => updateScopeKind(kind)}>{kind === "sport" ? "Sport-wide" : kind === "league" ? "League-wide" : "Team-specific"}</button>)}</div><div className="poll-create-scope__fields"><label><span>Sport</span><select value={sportId} onChange={(event) => updateSport(event.target.value as OfficialSportId)}>{officialSports.filter((sport) => sport.id !== "generic" && sport.id !== "other").map((sport) => <option key={sport.id} value={sport.id}>{sport.displayName}</option>)}</select></label>{scopeKind !== "sport" ? <label><span>League</span><select value={leagueId ?? ""} onChange={(event) => { const nextLeagueId = event.target.value as OfficialLeagueId; setLeagueId(nextLeagueId || null); setTeamId(null); }}><option value="">Choose a League</option>{leagues.map((league) => <option key={league.id} value={league.id}>{league.displayName}</option>)}</select></label> : null}{scopeKind === "team" ? <label><span>Team</span><select value={teamId ?? ""} disabled={!leagueId} onChange={(event) => setTeamId((event.target.value || null) as OfficialTeamId | null)}><option value="">Choose a Team</option>{teams.map((team) => <option key={team.id} value={team.id}>{team.displayName}</option>)}</select></label> : null}</div>{selectedScope() ? <small className="poll-create-scope__summary">Publishing to {pollScopeLabel(selectedScope()!)}</small> : null}</fieldset>

          <label><span>Search topics</span><input value={displayedTopics} placeholder="Topics are generated from the Poll" onChange={(event) => { setTopicsCustomized(true); setTopicText(event.target.value); }} /></label><small className="poll-topic-help">Generated automatically from the question and answers. Separate edits with commas.{topicsCustomized ? <button type="button" onClick={() => { setTopicsCustomized(false); setTopicText(""); }}>Use suggestions</button> : null}</small>

          <section className="poll-link-previous"><button type="button" aria-expanded={linkSearchOpen} onClick={() => setLinkSearchOpen((current) => !current)}>{linkedPoll ? "Change linked Poll" : <><AppIcon name="plus" /> Link Previous Poll</>}</button>{linkedPoll ? <div className="poll-linked-selection"><span>Linked previous Poll</span><strong>{linkedPoll.question}</strong><small>{pollScopeLabel(linkedPoll.scope)}</small><button type="button" onClick={() => setLinkedPreviousPollId(null)}>Remove</button></div> : null}{linkSearchOpen ? <div className="poll-link-search"><label><span>Search Polls</span><input type="search" value={linkQuery} placeholder="Question, answer, or topic" onChange={(event) => setLinkQuery(event.target.value)} /></label><div>{linkResults.map((poll) => <button key={poll.id} type="button" aria-pressed={linkedPreviousPollId === poll.id} onClick={() => { setLinkedPreviousPollId(poll.id); setLinkSearchOpen(false); }}><strong>{poll.question}</strong><span>{pollScopeLabel(poll.scope)}</span></button>)}{!linkResults.length ? <p>No related Polls found.</p> : null}</div></div> : null}</section>
          {error ? <p className="poll-form-error" role="alert">{error}</p> : null}
        </div>
        <footer><button type="button" onClick={() => onClose()}>Cancel</button><button className="fanbase-primary-button" type="button" onClick={submit}>Publish Poll</button></footer>
      </section>
    </div>
  );
}
