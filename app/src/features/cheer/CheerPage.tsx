import { useEffect, useMemo, useState, type FormEvent, type KeyboardEvent } from "react";
import { useNavigate } from "react-router-dom";
import { findOfficialSportByName, isValidOfficialSelection } from "../../data/officialSportsDatabase";
import { createUuid } from "../../lib/uuid";
import { useTeamContext } from "../../state/TeamContext";
import { AppIcon } from "../../components/AppIcon";
import { CheerBuilder } from "./CheerBuilder";
import { CheerCheckInDialog } from "./CheerCheckInDialog";
import { CheerFinish } from "./CheerFinish";
import { CheerFollowPlayer } from "./CheerFollowPlayer";
import { CheerLibraryFilter } from "./CheerLibraryFilter";
import { CheerLaunchSetupDialog } from "./CheerLaunchSetupDialog";
import { CheerListenScreen } from "./CheerListenScreen";
import { CheerReadScreen } from "./CheerReadScreen";
import { loadCheerLibrary, saveCheerLibrary } from "./cheerStorage";
import { clearCheerCheckIn, loadCheerCheckIn, saveCheerCheckIn } from "./cheerCheckIn";
import { allCheersFilter, availableNowFilter, cheerLibraryFilterLabel, filterCheers, hasLiveTeamGameContext, isCheerLaunchEligible, type CheerLibraryFilter as LibraryFilter } from "./cheerLibrary";
import { cheerSportOptions, requiredSportForRouting } from "./cheerRouting";
import { createCheerProposal, launchContext, loadCheerProposals, pruneStoredCheerProposals, saveCheerProposals, type CheerGameMoment, type CheerLaunchMode, type CheerProposal, type CheerTargetSelection } from "./cheerLaunch";
import { preloadAvailableLiveVariants, withPublishTimeLiveVariants } from "./cheerLiveVariants";
import { CHEER_PLAYBACK_BPM, estimateSyllables, lyricLines } from "./cheerUtils";
import { emptyCheerDraft, seededCheerLibrary } from "./mockCheerData";
import type { CheerCheckIn, CheerDraft, CheerLanguage, CheerPublicationStatus, CheerRecord, CheerSport, CheerStyle } from "./types";
import "./cheer.css";

type CheerView = "library" | "setup" | "lyrics" | "build" | "finish" | "read" | "listen" | "follow";
type CardMode = "Read" | "Listen" | "Follow";

const cheerStyles = ["Standard", "Echo", "Call & Response", "Fight Song", "Clap Pattern"] as const satisfies readonly CheerStyle[];
const currentCheerCreator: CheerRecord["createdBy"] = "Demo User";

function isOwnedCheer(cheer: CheerRecord) {
  return cheer.createdBy === currentCheerCreator;
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
    sportId: cheer.sportId,
    leagueId: cheer.leagueId,
    teamId: cheer.teamId,
    sport: cheer.sport,
    league: cheer.league,
    team: cheer.team,
    description: cheer.description ?? "",
    opponent: cheer.opponent,
  };
}

function CheerCard({ cheer, isOwner, launchEligible, onOpen, onLaunch, onToggleBookmark, onEdit, onDelete, onContactCreator }: {
  readonly cheer: CheerRecord;
  readonly isOwner: boolean;
  readonly launchEligible: boolean;
  readonly onOpen: (mode: CardMode) => void;
  readonly onLaunch: () => void;
  readonly onToggleBookmark: () => void;
  readonly onEdit: () => void;
  readonly onDelete: () => void;
  readonly onContactCreator: () => void;
}) {
  return (
    <article className="cheer-library-card">
      <div className="cheer-library-card__body">
        <div><span className="eyebrow">{cheer.publicationStatus} · {cheer.style}</span><h2>{cheer.title}</h2><p>{cheer.description || "A fan-created Cheer ready to read, practice, and follow."}</p><small>{cheer.team || "League-wide"} · {cheer.sport}{cheer.league ? ` · ${cheer.league}` : ""} · {cheer.measures.length} {cheer.measures.length === 1 ? "measure" : "measures"}</small>{isOwner ? <div className="cheer-owner-actions"><button className="cheer-edit" type="button" onClick={onEdit}>Edit Cheer</button><button className="cheer-delete" type="button" onClick={onDelete}>Delete Cheer</button></div> : cheer.publicationStatus === "Published" ? <button className="cheer-contact-creator" type="button" onClick={onContactCreator}>Contact Creator</button> : null}</div>
        <button className="cheer-bookmark" type="button" aria-label={`${cheer.bookmarked ? "Remove bookmark from" : "Bookmark"} ${cheer.title}`} aria-pressed={cheer.bookmarked} onClick={onToggleBookmark}><AppIcon name={cheer.bookmarked ? "bookmark-solid" : "bookmark"} /><span>{cheer.bookmarked ? "Saved" : "Bookmark"}</span></button>
      </div>
      <div className={`cheer-library-card__actions${launchEligible ? " cheer-library-card__actions--launch" : ""}`} aria-label={`${cheer.title} actions`}>{launchEligible ? <button className="cheer-library-card__launch" type="button" onClick={onLaunch}>Launch</button> : null}{(["Read", "Listen", "Follow"] as const).map((mode) => <button key={mode} type="button" onClick={() => onOpen(mode)}>{mode}</button>)}</div>
    </article>
  );
}

function DeleteCheerDialog({ cheer, onCancel, onConfirm }: {
  readonly cheer: CheerRecord;
  readonly onCancel: () => void;
  readonly onConfirm: () => void;
}) {
  return <div className="cheer-dialog-layer"><button className="cheer-dialog-backdrop" type="button" aria-label="Cancel deleting Cheer" onClick={onCancel} /><section className="cheer-delete-dialog" role="dialog" aria-modal="true" aria-labelledby="delete-cheer-title" aria-describedby="delete-cheer-description"><span className="eyebrow">Creator controls</span><h2 id="delete-cheer-title">Delete this Cheer?</h2><p id="delete-cheer-description"><strong>{cheer.title}</strong> will be permanently removed. This cannot be undone.</p><div><button type="button" onClick={onCancel} autoFocus>Cancel</button><button type="button" onClick={onConfirm}>Delete Cheer</button></div></section></div>;
}

function ContactCreatorDialog({ cheer, onClose }: {
  readonly cheer: CheerRecord;
  readonly onClose: () => void;
}) {
  return <div className="cheer-dialog-layer"><button className="cheer-dialog-backdrop" type="button" aria-label="Close Contact Creator" onClick={onClose} /><section className="cheer-delete-dialog cheer-contact-dialog" role="dialog" aria-modal="true" aria-labelledby="contact-creator-title" aria-describedby="contact-creator-description"><span className="eyebrow">Collaboration</span><h2 id="contact-creator-title">Contact Creator</h2><p id="contact-creator-description">Use this space to suggest a new verse, offer a correction or better recording, or share another idea for <strong>{cheer.title}</strong>.</p><p>Creator messaging is not connected yet. FANatical will route collaboration here without exposing private contact information.</p><div><button type="button" onClick={onClose} autoFocus>Close</button></div></section></div>;
}

export function CheerPage() {
  const navigate = useNavigate();
  const { selectedTeam, followedTeams } = useTeamContext();
  const [view, setView] = useState<CheerView>("library");
  const [draft, setDraft] = useState<CheerDraft>(emptyCheerDraft);
  const [cheers, setCheers] = useState<readonly CheerRecord[]>(seededCheerLibrary);
  const [persistenceReady, setPersistenceReady] = useState(false);
  const [editingCheerId, setEditingCheerId] = useState<string | null>(null);
  const [checkIn, setCheckIn] = useState<CheerCheckIn | null>(loadCheerCheckIn);
  const [filter, setFilter] = useState<LibraryFilter>(() => hasLiveTeamGameContext(checkIn) ? availableNowFilter : allCheersFilter);
  const [filterOpen, setFilterOpen] = useState(false);
  const [activeCheerId, setActiveCheerId] = useState<string | null>(null);
  const [deleteCheerId, setDeleteCheerId] = useState<string | null>(null);
  const [contactCheerId, setContactCheerId] = useState<string | null>(null);
  const [launchCheerId, setLaunchCheerId] = useState<string | null>(null);
  const [liveProposals, setLiveProposals] = useState<readonly CheerProposal[]>(pruneStoredCheerProposals);
  const [checkInOpen, setCheckInOpen] = useState(false);
  const [notice, setNotice] = useState("");
  const lines = useMemo(() => lyricLines(draft.lyrics), [draft.lyrics]);
  const editableLines = useMemo(() => draft.lyrics.split("\n"), [draft.lyrics]);
  const visibleCheers = useMemo(() => filterCheers(cheers, filter, checkIn, currentCheerCreator)
    .sort((first, second) => Number(second.bookmarked) - Number(first.bookmarked) || Date.parse(second.createdAt) - Date.parse(first.createdAt)), [cheers, checkIn, filter]);
  const availableCheers = useMemo(() => filterCheers(cheers, availableNowFilter, checkIn, currentCheerCreator), [cheers, checkIn]);
  const availableLiveProposals = useMemo(() => {
    if (!checkIn) return [];
    const context = launchContext(checkIn);
    return liveProposals.filter((proposal) => proposal.eventId === context.eventId
      && cheers.some((cheer) => cheer.id === proposal.cheerId && isCheerLaunchEligible(cheer, checkIn)));
  }, [checkIn, cheers, liveProposals]);
  const filterLabel = cheerLibraryFilterLabel(filter);
  const activeCheer = activeCheerId ? cheers.find((cheer) => cheer.id === activeCheerId) ?? null : null;
  const cheerPendingDeletion = deleteCheerId ? cheers.find((cheer) => cheer.id === deleteCheerId) ?? null : null;
  const cheerPendingContact = contactCheerId ? cheers.find((cheer) => cheer.id === contactCheerId) ?? null : null;
  const cheerPendingLaunch = launchCheerId ? cheers.find((cheer) => cheer.id === launchCheerId) ?? null : null;
  const requiredSport = useMemo(() => requiredSportForRouting(draft.measures), [draft.measures]);

  useEffect(() => {
    let active = true;
    void loadCheerLibrary().then((storedCheers) => {
      if (!active) return;
      if (storedCheers) setCheers([...storedCheers, ...seededCheerLibrary.filter((seed) => !storedCheers.some((cheer) => cheer.id === seed.id))]);
      setPersistenceReady(true);
    });
    return () => { active = false; };
  }, []);

  useEffect(() => {
    if (persistenceReady) void saveCheerLibrary(cheers);
  }, [cheers, persistenceReady]);

  useEffect(() => {
    preloadAvailableLiveVariants(availableCheers, checkIn);
  }, [availableCheers, checkIn]);

  useEffect(() => {
    const refresh = () => setLiveProposals(pruneStoredCheerProposals());
    refresh();
    const interval = window.setInterval(refresh, 1_000);
    return () => window.clearInterval(interval);
  }, []);

  const updateActiveRecording = (recordingUrl: string | null) => {
    if (!activeCheerId) return;
    setCheers((current) => current.map((cheer) => cheer.id === activeCheerId ? { ...cheer, recordingUrl } : cheer));
  };

  const openLibraryScreen = (cheerId: string, mode: CardMode) => {
    setActiveCheerId(cheerId);
    setView(mode.toLowerCase() as "read" | "listen" | "follow");
  };

  const openCreate = () => {
    const sport = findOfficialSportByName(selectedTeam.sport);
    setDraft({ ...emptyCheerDraft, sport: selectedTeam.sport, sportId: sport?.id ?? emptyCheerDraft.sportId, leagueId: null, teamId: null, league: "", team: "", measures: emptyCheerDraft.measures.map((measure) => ({ ...measure, actionSegments: [], lyricSegments: [], restSegments: [] })) });
    setEditingCheerId(null);
    setNotice("");
    setView("setup");
  };

  const openEdit = (cheer: CheerRecord) => {
    if (!isOwnedCheer(cheer)) return;
    setDraft(cloneDraft(cheer));
    setEditingCheerId(cheer.id);
    setNotice("");
    setView("setup");
  };

  const requestDeleteCheer = (cheer: CheerRecord) => {
    if (!isOwnedCheer(cheer)) return;
    setDeleteCheerId(cheer.id);
  };

  const deleteCheer = () => {
    if (!deleteCheerId) return;
    const cheer = cheers.find((candidate) => candidate.id === deleteCheerId);
    if (!cheer || !isOwnedCheer(cheer)) {
      setDeleteCheerId(null);
      return;
    }
    setCheers((current) => current.filter((candidate) => candidate.id !== deleteCheerId));
    if (activeCheerId === deleteCheerId) {
      setActiveCheerId(null);
      setView("library");
    }
    if (editingCheerId === deleteCheerId) {
      setEditingCheerId(null);
      setDraft(emptyCheerDraft);
      setView("library");
    }
    setDeleteCheerId(null);
  };

  const requestContactCreator = (cheer: CheerRecord) => {
    if (isOwnedCheer(cheer) || cheer.publicationStatus !== "Published") return;
    setContactCheerId(cheer.id);
  };

  const continueSetup = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    const sport = requiredSport ?? String(formData.get("sport") ?? draft.sport) as CheerSport;
    const officialSport = findOfficialSportByName(sport);
    setDraft((current) => ({
      ...current,
      title: String(formData.get("title") ?? "").trim(),
      style: String(formData.get("style") ?? "Standard") as CheerStyle,
      sport,
      sportId: officialSport?.id ?? current.sportId,
      leagueId: current.sport === sport ? current.leagueId : null,
      teamId: current.sport === sport ? current.teamId : null,
      league: current.sport === sport ? current.league : "",
      team: current.sport === sport ? current.team : "",
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
    if (!isValidOfficialSelection(draft.sportId, draft.leagueId, draft.teamId)) {
      setNotice("Choose a valid Sport, League, and Team combination before saving.");
      return;
    }
    if (editingCheerId) {
      const edited = cheers.find((cheer) => cheer.id === editingCheerId);
      if (!edited || !isOwnedCheer(edited)) return;
      setCheers((current) => current.map((cheer) => cheer.id === editingCheerId ? withPublishTimeLiveVariants({ ...cheer, ...draft, bpm: CHEER_PLAYBACK_BPM, publicationStatus }) : cheer));
    } else {
      const cheer = withPublishTimeLiveVariants({
        id: `cheer-local-${createUuid()}`,
        ...draft,
        bpm: CHEER_PLAYBACK_BPM,
        createdBy: currentCheerCreator,
        createdAt: new Date().toISOString(),
        bookmarked: false,
        publicationStatus,
      });
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
    saveCheerCheckIn(selection);
    setCheckIn(selection);
    if (hasLiveTeamGameContext(selection)) setFilter(availableNowFilter);
    setCheckInOpen(false);
    setNotice("");
  };

  const clearCheckIn = () => {
    clearCheerCheckIn();
    setCheckIn(null);
    if (filter.kind === "available") setFilter(allCheersFilter);
    setCheckInOpen(false);
    setNotice("");
  };

  const createLaunchProposal = (mode: CheerLaunchMode, gameMoment: CheerGameMoment | null, targetSelection: CheerTargetSelection | null) => {
    if (!cheerPendingLaunch || !checkIn || !isCheerLaunchEligible(cheerPendingLaunch, checkIn)) {
      return "This Cheer is no longer eligible for the current Check-In.";
    }
    const result = createCheerProposal(loadCheerProposals(), { cheer: cheerPendingLaunch, checkIn, mode, gameMoment, targetSelection });
    if (result.error) return result.error;
    saveCheerProposals(result.proposals);
    setLiveProposals(result.proposals);
    setLaunchCheerId(null);
    navigate("/cheer/launch");
    return null;
  };

  const checkInLabel = checkIn?.type === "MappedVenue"
    ? `Sec ${checkIn.raw.section} · R${checkIn.raw.row} · S${checkIn.raw.seat}`
    : checkIn?.location.name ?? "Check In";
  const checkInAriaLabel = checkIn?.type === "MappedVenue"
    ? `Change Check In: ${checkIn.raw.venueName}, Section ${checkIn.raw.section}, Row ${checkIn.raw.row}, Seat ${checkIn.raw.seat}`
    : checkIn ? `Change Check In: ${checkIn.location.name}` : "Check In";

  return (
    <div className="cheer-page">
      <header className="cheer-topbar">
        {view === "library" ? <button className="cheer-topbar__check-in" type="button" aria-label={checkInAriaLabel} onClick={() => setCheckInOpen(true)}>{checkIn ? <AppIcon name="ticket" /> : null}{checkInLabel}</button> : <button className="cheer-topbar__back" type="button" onClick={back}><AppIcon name="arrow-left" /><span>{view === "read" || view === "listen" || view === "follow" ? "Cheer Library" : view === "finish" ? "Build" : view === "build" ? "Lyrics" : view === "lyrics" ? "Setup" : "Cheer"}</span></button>}
        <div>{view === "library" ? <><h1>Cheer Library</h1><h2 className="cheer-topbar__filter" id="cheer-library-filter-title">{filterLabel}</h2></> : <><span className="eyebrow">{(activeCheer?.title ?? draft.title) || "New Cheer"}</span><h1>{view === "read" ? "Read" : view === "listen" ? "Listen" : view === "follow" ? "Follow" : view === "setup" ? editingCheerId ? "Edit Cheer" : "Add Cheer" : view === "lyrics" ? "Lyrics" : view === "build" ? "Build Cheer" : "Finish Cheer"}</h1></>}</div>
        {view === "library" ? <div className="cheer-topbar__actions"><div className="cheer-filter"><button type="button" aria-label="Filter Cheer Library" aria-expanded={filterOpen} onClick={() => setFilterOpen((current) => !current)}><AppIcon name="adjustments-horizontal" /></button>{filterOpen ? <CheerLibraryFilter activeFilter={filter} followedTeams={followedTeams} onApply={(nextFilter) => { setFilter(nextFilter); setFilterOpen(false); }} /> : null}</div><button type="button" aria-label="Add Cheer" onClick={openCreate}><AppIcon name="plus" /></button></div> : <span />}
      </header>

      {notice && view !== "library" ? <p className="cheer-page__notice" role="status">{notice}</p> : null}

      {view === "library" ? <main className="cheer-library" aria-labelledby="cheer-library-filter-title">{availableLiveProposals.length ? <button className="cheer-live-banner" type="button" onClick={() => navigate("/cheer/launch")}><span>LIVE CHEERS</span><small>{availableLiveProposals.length} active {availableLiveProposals.length === 1 ? "Cheer" : "Cheers"} <AppIcon name="arrow-right" /></small></button> : null}{visibleCheers.length ? <div>{visibleCheers.map((cheer) => { const launchEligible = isCheerLaunchEligible(cheer, checkIn); return <CheerCard key={cheer.id} cheer={cheer} isOwner={isOwnedCheer(cheer)} launchEligible={launchEligible} onLaunch={() => launchEligible && setLaunchCheerId(cheer.id)} onEdit={() => openEdit(cheer)} onDelete={() => requestDeleteCheer(cheer)} onContactCreator={() => requestContactCreator(cheer)} onOpen={(mode) => openLibraryScreen(cheer.id, mode)} onToggleBookmark={() => setCheers((current) => current.map((candidate) => candidate.id === cheer.id ? { ...candidate, bookmarked: !candidate.bookmarked } : candidate))} />; })}</div> : <div className="cheer-empty"><AppIcon name="information-circle" /><h2>{filter.kind === "available" ? "No Cheers are available now" : "No Cheers match this filter"}</h2><p>{filter.kind === "available" && !hasLiveTeamGameContext(checkIn) ? "Check into a current team or game to see launchable Cheers." : "Choose another filter or create a Cheer."}</p></div>}</main> : null}

      {view === "read" && activeCheer ? <CheerReadScreen cheer={activeCheer} /> : null}
      {view === "listen" && activeCheer ? <CheerListenScreen cheer={activeCheer} onRecordingChange={updateActiveRecording} /> : null}
      {view === "follow" && activeCheer ? <CheerFollowPlayer cheer={activeCheer} /> : null}

      {view === "setup" ? <main className="cheer-setup"><form onSubmit={continueSetup}><div><span className="eyebrow">{editingCheerId ? "Restore and refine" : "Start small"}</span><h2>{editingCheerId ? "Edit Cheer identity" : "Name your Cheer"}</h2><p>Title, style, and sport stay connected to the same saved choreography.</p></div><label>Title<input name="title" required maxLength={100} defaultValue={draft.title} autoFocus /></label><label>Cheer Style<select name="style" defaultValue={draft.style}>{cheerStyles.map((style) => <option key={style}>{style}</option>)}</select></label>{requiredSport ? <div className="cheer-setup__readonly"><span>Sport</span><strong>{requiredSport}</strong><small>Locked by sport-specific WHO routing in this Cheer.</small></div> : <label>Sport<select name="sport" value={draft.sport} onChange={(event) => { const sport = event.target.value as CheerSport; const officialSport = findOfficialSportByName(sport); setDraft((current) => ({ ...current, sport, sportId: officialSport?.id ?? current.sportId, leagueId: null, teamId: null, league: "", team: "" })); }}>{cheerSportOptions.map((sport) => <option key={sport}>{sport}</option>)}</select></label>}<button className="cheer-primary-button" type="submit">Continue to Lyrics</button></form></main> : null}

      {view === "lyrics" ? <main className="cheer-lyrics-editor"><header><div><span className="eyebrow">Original source lyrics</span><h2>{draft.title}</h2><p>Write freely. Building or deleting measures will never alter these words.</p></div><label>Language<select value={draft.language} onChange={(event) => setDraft((current) => ({ ...current, language: event.target.value as CheerLanguage }))}><option>Auto</option><option>English</option><option>Other</option></select></label></header><div className="cheer-lyrics-editor__actions"><button className="cheer-primary-button" type="button" onClick={enterBuild}>Build</button></div><section className="cheer-lyrics-lines" aria-labelledby="cheer-lyrics-lines-title"><header><strong id="cheer-lyrics-lines-title">Original Lyrics</strong><small>Enter creates a new line · estimates are helpers only</small></header>{editableLines.map((line, index) => { const estimate = estimateSyllables(line, draft.language); return <div key={`lyric-line-${index}`}><label htmlFor={`cheer-lyric-line-${index + 1}`}>Line {index + 1}</label><input id={`cheer-lyric-line-${index + 1}`} aria-label={`Lyric line ${index + 1}`} dir="auto" lang={draft.language === "English" ? "en" : undefined} value={line} placeholder={index === 0 ? "Write a chant or lyric line…" : "Next line…"} onKeyDown={(event) => handleLyricKeyDown(event, index)} onChange={(event) => updateLyricLine(index, event.target.value)} />{estimate !== null ? <small>≈ {estimate} {estimate === 1 ? "syllable" : "syllables"}</small> : <span />}{editableLines.length > 1 ? <button type="button" aria-label={`Remove lyric line ${index + 1}`} onClick={() => removeLyricLine(index)}><AppIcon name="x-mark" /></button> : null}</div>; })}<button type="button" onClick={() => addLyricLine()}><AppIcon name="plus" /> Add lyric line</button></section></main> : null}

      {view === "build" ? <main><CheerBuilder draft={draft} onChange={setDraft} onFinish={() => setView("finish")} /></main> : null}
      {view === "finish" ? <CheerFinish draft={draft} requiredSport={requiredSport} onChange={setDraft} onFinish={saveCheer} /> : null}
      {checkInOpen ? <CheerCheckInDialog initial={checkIn} onSave={saveCheckIn} onClear={clearCheckIn} onClose={() => setCheckInOpen(false)} /> : null}
      {cheerPendingDeletion ? <DeleteCheerDialog cheer={cheerPendingDeletion} onCancel={() => setDeleteCheerId(null)} onConfirm={deleteCheer} /> : null}
      {cheerPendingContact ? <ContactCreatorDialog cheer={cheerPendingContact} onClose={() => setContactCheerId(null)} /> : null}
      {cheerPendingLaunch && checkIn ? <CheerLaunchSetupDialog cheer={cheerPendingLaunch} checkIn={checkIn} onCancel={() => setLaunchCheerId(null)} onLaunch={createLaunchProposal} /> : null}
    </div>
  );
}
