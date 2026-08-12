import { useEffect, useMemo, useState, type FormEvent, type KeyboardEvent } from "react";
import { useTeamContext } from "../../state/TeamContext";
import { CheerBuilder } from "./CheerBuilder";
import { CheerCheckInDialog } from "./CheerCheckInDialog";
import { CheerFinish } from "./CheerFinish";
import { CheerFollowPlayer } from "./CheerFollowPlayer";
import { CheerListenScreen } from "./CheerListenScreen";
import { CheerReadScreen } from "./CheerReadScreen";
import { loadCheerLibrary, saveCheerLibrary } from "./cheerStorage";
import { CHEER_PLAYBACK_BPM, estimateSyllables, lyricLines } from "./cheerUtils";
import { emptyCheerDraft, initialCheerLibrary } from "./mockCheerData";
import type { CheerCheckIn, CheerDraft, CheerLanguage, CheerPublicationStatus, CheerRecord, CheerSport, CheerStyle } from "./types";
import "./cheer.css";

type CheerView = "library" | "setup" | "lyrics" | "build" | "finish" | "read" | "listen" | "follow";
type LibraryFilter = "All" | "Bookmarked" | "My Cheers";
type CardMode = "Read" | "Listen" | "Follow";

const cheerStyles = ["Standard", "Echo", "Call & Response", "Fight Song", "Clap Pattern"] as const satisfies readonly CheerStyle[];
const cheerSports = ["Football", "Baseball", "Basketball", "Hockey", "Soccer", "Other"] as const satisfies readonly CheerSport[];
const checkInSessionKey = "fanatical.cheer.check-in";

function loadCheckIn(): CheerCheckIn | null {
  try {
    const value = window.sessionStorage.getItem(checkInSessionKey);
    if (!value) return null;
    const parsed = JSON.parse(value) as Partial<CheerCheckIn>;
    if ((parsed.level === "Upper" || parsed.level === "Lower") && (parsed.eastWest === "East" || parsed.eastWest === "West") && (parsed.northSouth === "North" || parsed.northSouth === "South")) return parsed as CheerCheckIn;
  } catch {
    // Invalid session mock data is safely ignored.
  }
  return null;
}

function cloneDraft(cheer: CheerRecord): CheerDraft {
  return {
    title: cheer.title,
    style: cheer.style,
    lyrics: cheer.lyrics,
    language: cheer.language,
    recordingUrl: cheer.recordingUrl,
    bpm: CHEER_PLAYBACK_BPM,
    measures: cheer.measures.map((measure) => ({ ...measure, actionSegments: [...measure.actionSegments], lyricSegments: [...measure.lyricSegments], restSegments: [...measure.restSegments] })),
    sport: cheer.sport,
    league: cheer.league,
    team: cheer.team,
    description: cheer.description ?? "",
    opponent: cheer.opponent,
  };
}

function CheerCard({ cheer, onOpen, onToggleBookmark, onEdit }: {
  readonly cheer: CheerRecord;
  readonly onOpen: (mode: CardMode) => void;
  readonly onToggleBookmark: () => void;
  readonly onEdit: () => void;
}) {
  return (
    <article className="cheer-library-card">
      <div className="cheer-library-card__body">
        <div><span className="eyebrow">{cheer.publicationStatus} · {cheer.style}</span><h2>{cheer.title}</h2><p>{cheer.description || "A fan-created Cheer ready to read, practice, and follow."}</p><small>{cheer.team || "League-wide"} · {cheer.sport}{cheer.league ? ` · ${cheer.league}` : ""} · {cheer.measures.length} {cheer.measures.length === 1 ? "measure" : "measures"}</small>{cheer.createdBy === "Demo User" ? <button className="cheer-edit" type="button" onClick={onEdit}>Edit Cheer</button> : null}</div>
        <button className="cheer-bookmark" type="button" aria-label={`${cheer.bookmarked ? "Remove bookmark from" : "Bookmark"} ${cheer.title}`} aria-pressed={cheer.bookmarked} onClick={onToggleBookmark}><span aria-hidden="true">{cheer.bookmarked ? "★" : "☆"}</span><span>{cheer.bookmarked ? "Saved" : "Bookmark"}</span></button>
      </div>
      <div className="cheer-library-card__actions" aria-label={`${cheer.title} actions`}>{(["Read", "Listen", "Follow"] as const).map((mode) => <button key={mode} type="button" onClick={() => onOpen(mode)}>{mode}</button>)}</div>
    </article>
  );
}

export function CheerPage() {
  const { selectedTeam } = useTeamContext();
  const [view, setView] = useState<CheerView>("library");
  const [draft, setDraft] = useState<CheerDraft>(emptyCheerDraft);
  const [cheers, setCheers] = useState<readonly CheerRecord[]>(() => initialCheerLibrary.map((cheer) => ({ ...cheer, teamId: selectedTeam.id })));
  const [persistenceReady, setPersistenceReady] = useState(false);
  const [editingCheerId, setEditingCheerId] = useState<string | null>(null);
  const [filter, setFilter] = useState<LibraryFilter>("All");
  const [filterOpen, setFilterOpen] = useState(false);
  const [activeCheerId, setActiveCheerId] = useState<string | null>(null);
  const [checkInOpen, setCheckInOpen] = useState(false);
  const [checkIn, setCheckIn] = useState<CheerCheckIn | null>(loadCheckIn);
  const [notice, setNotice] = useState("");
  const lines = useMemo(() => lyricLines(draft.lyrics), [draft.lyrics]);
  const editableLines = useMemo(() => draft.lyrics.split("\n"), [draft.lyrics]);
  const visibleCheers = useMemo(() => [...cheers]
    .filter((cheer) => filter === "All" || (filter === "Bookmarked" ? cheer.bookmarked : cheer.createdBy === "Demo User"))
    .sort((first, second) => Number(second.bookmarked) - Number(first.bookmarked) || Date.parse(second.createdAt) - Date.parse(first.createdAt)), [cheers, filter]);
  const activeCheer = activeCheerId ? cheers.find((cheer) => cheer.id === activeCheerId) ?? null : null;

  useEffect(() => {
    let active = true;
    void loadCheerLibrary().then((storedCheers) => {
      if (!active) return;
      if (storedCheers) setCheers(storedCheers);
      setPersistenceReady(true);
    });
    return () => { active = false; };
  }, []);

  useEffect(() => {
    if (persistenceReady) void saveCheerLibrary(cheers);
  }, [cheers, persistenceReady]);

  const updateActiveRecording = (recordingUrl: string | null) => {
    if (!activeCheerId) return;
    setCheers((current) => current.map((cheer) => cheer.id === activeCheerId ? { ...cheer, recordingUrl } : cheer));
  };

  const openLibraryScreen = (cheerId: string, mode: CardMode) => {
    setActiveCheerId(cheerId);
    setView(mode.toLowerCase() as "read" | "listen" | "follow");
  };

  const openCreate = () => {
    setDraft({ ...emptyCheerDraft, sport: selectedTeam.sport, league: selectedTeam.league, team: "", measures: emptyCheerDraft.measures.map((measure) => ({ ...measure, actionSegments: [], lyricSegments: [], restSegments: [] })) });
    setEditingCheerId(null);
    setNotice("");
    setView("setup");
  };

  const openEdit = (cheer: CheerRecord) => {
    setDraft(cloneDraft(cheer));
    setEditingCheerId(cheer.id);
    setNotice("");
    setView("setup");
  };

  const continueSetup = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setDraft((current) => ({
      ...current,
      title: String(formData.get("title") ?? "").trim(),
      style: String(formData.get("style") ?? "Standard") as CheerStyle,
      sport: editingCheerId ? current.sport : String(formData.get("sport") ?? "Other") as CheerSport,
    }));
    setView("lyrics");
  };

  const enterBuild = () => {
    if (!lines.length) {
      setNotice("Add at least one lyric line before building choreography.");
      return;
    }
    setNotice("");
    setView("build");
  };

  const saveCheer = (publicationStatus: CheerPublicationStatus) => {
    if (editingCheerId) {
      const edited = cheers.find((cheer) => cheer.id === editingCheerId);
      if (!edited) return;
      setCheers((current) => current.map((cheer) => cheer.id === editingCheerId ? { ...cheer, ...draft, bpm: CHEER_PLAYBACK_BPM, publicationStatus } : cheer));
    } else {
      const cheer: CheerRecord = {
        id: `cheer-local-${crypto.randomUUID()}`,
        ...draft,
        bpm: CHEER_PLAYBACK_BPM,
        teamId: selectedTeam.id,
        createdBy: "Demo User",
        createdAt: new Date().toISOString(),
        bookmarked: false,
        publicationStatus,
      };
      setCheers((current) => [cheer, ...current]);
    }
    setEditingCheerId(null);
    setView("library");
  };

  const back = () => {
    if (view === "read" || view === "listen" || view === "follow") {
      setView("library");
      setActiveCheerId(null);
    } else if (view === "finish") setView("build");
    else if (view === "build") setView("lyrics");
    else if (view === "lyrics") setView("setup");
    else {
      setView("library");
      setEditingCheerId(null);
      setNotice("");
    }
  };

  const updateLyricLine = (index: number, value: string) => {
    const next = [...editableLines];
    next[index] = value;
    setDraft((current) => ({ ...current, lyrics: next.join("\n") }));
    setNotice("");
  };

  const addLyricLine = (afterIndex = editableLines.length - 1) => {
    const next = [...editableLines];
    next.splice(afterIndex + 1, 0, "");
    setDraft((current) => ({ ...current, lyrics: next.join("\n") }));
    window.setTimeout(() => document.getElementById(`cheer-lyric-line-${afterIndex + 2}`)?.focus(), 0);
  };

  const removeLyricLine = (index: number) => {
    if (editableLines.length === 1) return;
    const next = editableLines.filter((_, candidateIndex) => candidateIndex !== index);
    setDraft((current) => ({ ...current, lyrics: next.join("\n") }));
  };

  const handleLyricKeyDown = (event: KeyboardEvent<HTMLInputElement>, index: number) => {
    if (event.key === "Enter") {
      event.preventDefault();
      addLyricLine(index);
    } else if (event.key === "Backspace" && !editableLines[index] && editableLines.length > 1) {
      event.preventDefault();
      removeLyricLine(index);
      window.setTimeout(() => document.getElementById(`cheer-lyric-line-${Math.max(1, index)}`)?.focus(), 0);
    }
  };

  const saveCheckIn = (selection: CheerCheckIn) => {
    window.sessionStorage.setItem(checkInSessionKey, JSON.stringify(selection));
    setCheckIn(selection);
    setCheckInOpen(false);
    setNotice("");
  };

  const clearCheckIn = () => {
    window.sessionStorage.removeItem(checkInSessionKey);
    setCheckIn(null);
    setCheckInOpen(false);
    setNotice("");
  };

  return (
    <div className="cheer-page">
      <header className="cheer-topbar">
        {view === "library" ? <button className="cheer-topbar__check-in" type="button" aria-label={checkIn ? `Change Check In: ${checkIn.level}, ${checkIn.eastWest}, ${checkIn.northSouth}` : "Check In"} onClick={() => setCheckInOpen(true)}>{checkIn ? `${checkIn.level} · ${checkIn.eastWest.charAt(0)} · ${checkIn.northSouth.charAt(0)}` : "Check In"}</button> : <button className="cheer-topbar__back" type="button" onClick={back}><span aria-hidden="true">←</span><span>{view === "read" || view === "listen" || view === "follow" ? "Cheer Library" : view === "finish" ? "Build" : view === "build" ? "Lyrics" : view === "lyrics" ? "Setup" : "Cheer"}</span></button>}
        <div><span className="eyebrow">{view === "library" ? selectedTeam.shortName : (activeCheer?.title ?? draft.title) || "New Cheer"}</span><h1>{view === "library" ? "Cheer" : view === "read" ? "Read" : view === "listen" ? "Listen" : view === "follow" ? "Follow" : view === "setup" ? editingCheerId ? "Edit Cheer" : "Add Cheer" : view === "lyrics" ? "Lyrics" : view === "build" ? "Build Cheer" : "Finish Cheer"}</h1></div>
        {view === "library" ? <div className="cheer-topbar__actions"><div className="cheer-filter"><button type="button" aria-label="Filter Cheer Library" aria-expanded={filterOpen} onClick={() => setFilterOpen((current) => !current)}>⌁</button>{filterOpen ? <div role="menu" aria-label="Cheer Library filters">{(["All", "Bookmarked", "My Cheers"] as const).map((option) => <button key={option} type="button" role="menuitemradio" aria-checked={filter === option} onClick={() => { setFilter(option); setFilterOpen(false); }}>{option}</button>)}</div> : null}</div><button type="button" aria-label="Add Cheer" onClick={openCreate}>+</button></div> : <span />}
      </header>

      {notice && view !== "library" ? <p className="cheer-page__notice" role="status">{notice}</p> : null}

      {view === "library" ? <main className="cheer-library" aria-labelledby="cheer-library-title"><header><div><span className="eyebrow">{filter}</span><h2 id="cheer-library-title">Cheer Library</h2></div><span>{visibleCheers.length}</span></header>{visibleCheers.length ? <div>{visibleCheers.map((cheer) => <CheerCard key={cheer.id} cheer={cheer} onEdit={() => openEdit(cheer)} onOpen={(mode) => openLibraryScreen(cheer.id, mode)} onToggleBookmark={() => setCheers((current) => current.map((candidate) => candidate.id === cheer.id ? { ...candidate, bookmarked: !candidate.bookmarked } : candidate))} />)}</div> : <div className="cheer-empty"><span aria-hidden="true">◇</span><h2>No Cheers match this filter</h2><p>Create a Cheer or return to All.</p></div>}</main> : null}

      {view === "read" && activeCheer ? <CheerReadScreen cheer={activeCheer} /> : null}
      {view === "listen" && activeCheer ? <CheerListenScreen cheer={activeCheer} onRecordingChange={updateActiveRecording} /> : null}
      {view === "follow" && activeCheer ? <CheerFollowPlayer cheer={activeCheer} /> : null}

      {view === "setup" ? <main className="cheer-setup"><form onSubmit={continueSetup}><div><span className="eyebrow">{editingCheerId ? "Restore and refine" : "Start small"}</span><h2>{editingCheerId ? "Edit Cheer identity" : "Name your Cheer"}</h2><p>Title, style, and sport stay connected to the same saved choreography.</p></div><label>Title<input name="title" required maxLength={100} defaultValue={draft.title} autoFocus /></label><label>Cheer Style<select name="style" defaultValue={draft.style}>{cheerStyles.map((style) => <option key={style}>{style}</option>)}</select></label>{editingCheerId ? <div className="cheer-setup__readonly"><span>Sport</span><strong>{draft.sport}</strong><small>Sport-specific choreography stays locked to this Cheer.</small></div> : <label>Sport<select name="sport" value={draft.sport} onChange={(event) => setDraft((current) => ({ ...current, sport: event.target.value as CheerSport }))}>{cheerSports.map((sport) => <option key={sport}>{sport}</option>)}</select></label>}<button className="cheer-primary-button" type="submit">Continue to Lyrics</button></form></main> : null}

      {view === "lyrics" ? <main className="cheer-lyrics-editor"><header><div><span className="eyebrow">Original source lyrics</span><h2>{draft.title}</h2><p>Write freely. Building or deleting measures will never alter these words.</p></div><label>Language<select value={draft.language} onChange={(event) => setDraft((current) => ({ ...current, language: event.target.value as CheerLanguage }))}><option>Auto</option><option>English</option><option>Other</option></select></label></header><section className="cheer-lyrics-lines" aria-labelledby="cheer-lyrics-lines-title"><header><strong id="cheer-lyrics-lines-title">Lyrics</strong><small>Enter creates a new line · estimates are helpers only</small></header>{editableLines.map((line, index) => { const estimate = estimateSyllables(line, draft.language); return <div key={`lyric-line-${index}`}><label htmlFor={`cheer-lyric-line-${index + 1}`}>Line {index + 1}</label><input id={`cheer-lyric-line-${index + 1}`} aria-label={`Lyric line ${index + 1}`} dir="auto" lang={draft.language === "English" ? "en" : undefined} value={line} placeholder={index === 0 ? "Write a chant or lyric line…" : "Next line…"} onKeyDown={(event) => handleLyricKeyDown(event, index)} onChange={(event) => updateLyricLine(index, event.target.value)} />{estimate !== null ? <small>≈ {estimate} {estimate === 1 ? "syllable" : "syllables"}</small> : <span />}{editableLines.length > 1 ? <button type="button" aria-label={`Remove lyric line ${index + 1}`} onClick={() => removeLyricLine(index)}>×</button> : null}</div>; })}<button type="button" onClick={() => addLyricLine()}>+ Add lyric line</button></section><div className="cheer-lyrics-editor__actions"><button className="cheer-primary-button" type="button" onClick={enterBuild}>Build</button></div></main> : null}

      {view === "build" ? <main><CheerBuilder draft={draft} onChange={setDraft} onFinish={() => setView("finish")} /></main> : null}
      {view === "finish" ? <CheerFinish draft={draft} onChange={setDraft} onFinish={saveCheer} /> : null}
      {checkInOpen ? <CheerCheckInDialog initial={checkIn} onSave={saveCheckIn} onClear={clearCheckIn} onClose={() => setCheckInOpen(false)} /> : null}
    </div>
  );
}
