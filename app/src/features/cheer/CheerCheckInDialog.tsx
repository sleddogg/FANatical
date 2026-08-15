import { useEffect, useMemo, useState, type FormEvent } from "react";
import {
  configuredTeamEvents,
  configuredVenueSports,
  emptyMappedCheckInDraft,
  loadCheckInVenues,
  loadGeneralLocations,
  resolveGeneralLocationCheckIn,
  resolveMappedCheckIn,
  venueRows,
  venueSeats,
  type GeneralLocationRecord,
  type MappedCheckInDraft,
  type TicketCapture,
} from "./cheerCheckIn";
import type { CheerCheckIn, CheerSport, MappedVenueCheckIn } from "./types";

type CheckInStage = "choice" | "upload" | "mappedDetails" | "mappedReview" | "generalDetails" | "generalReview";

function ValuePicker({ label, values, selected, expanded, onExpand, onSelect }: {
  readonly label: "Row" | "Seat";
  readonly values: readonly string[];
  readonly selected: string;
  readonly expanded: boolean;
  readonly onExpand: () => void;
  readonly onSelect: (value: string) => void;
}) {
  if (selected && !expanded) {
    return <button className="cheer-check-in__selected-value" type="button" aria-label={`Change ${label}, currently ${selected}`} onClick={onExpand}><small>{label}</small><strong>{selected}</strong></button>;
  }
  return (
    <fieldset className="cheer-check-in__picker">
      <legend>{label}</legend>
      <div>{values.map((value) => <button key={value} type="button" aria-label={`${label} ${value}`} aria-pressed={selected === value} onClick={() => onSelect(value)}>{value}</button>)}</div>
    </fieldset>
  );
}

export function CheerCheckInDialog({ initial, onSave, onClear, onClose }: {
  readonly initial: CheerCheckIn | null;
  readonly onSave: (selection: CheerCheckIn) => void;
  readonly onClear: () => void;
  readonly onClose: () => void;
}) {
  const venues = useMemo(loadCheckInVenues, []);
  const generalLocations = useMemo(loadGeneralLocations, []);
  const initialMapped = initial?.type === "MappedVenue" ? initial : null;
  const initialGeneral = initial?.type === "GeneralLocation" ? initial : null;
  const [stage, setStage] = useState<CheckInStage>(initialMapped ? "mappedReview" : initialGeneral ? "generalReview" : "choice");
  const [draft, setDraft] = useState<MappedCheckInDraft>(initialMapped?.raw ?? emptyMappedCheckInDraft("Manual"));
  const [mappedCandidate, setMappedCandidate] = useState<MappedVenueCheckIn | null>(initialMapped);
  const [generalLocationName, setGeneralLocationName] = useState(initialGeneral?.location.name ?? "");
  const [generalCandidate, setGeneralCandidate] = useState<GeneralLocationRecord | null>(() => initialGeneral ? generalLocations.find((location) => location.id === initialGeneral.location.id) ?? null : null);
  const [capture, setCapture] = useState<TicketCapture | null>(null);
  const [rowExpanded, setRowExpanded] = useState(!initialMapped);
  const [seatExpanded, setSeatExpanded] = useState(!initialMapped);
  const [sectionCommitted, setSectionCommitted] = useState(false);
  const [error, setError] = useState("");

  const selectedVenue = venues.find(({ venue }) => venue.id === draft.venueId)?.venue
    ?? venues.find(({ venue }) => venue.name.toLowerCase() === draft.venueName.trim().toLowerCase())?.venue
    ?? null;
  const sports = selectedVenue ? configuredVenueSports(selectedVenue) : [];
  const teamEvents = selectedVenue ? configuredTeamEvents(selectedVenue, draft.sport) : [];
  const normalizedSectionInput = draft.section.trim().replace(/^section\s*/i, "").toLowerCase();
  const section = selectedVenue?.sections.find((item) => item.section.toLowerCase() === normalizedSectionInput) ?? null;
  const sectionCouldMatch = Boolean(selectedVenue?.sections.some((item) => item.section.toLowerCase().startsWith(normalizedSectionInput)));
  const rows = selectedVenue && section ? venueRows(selectedVenue, section.section) : [];
  const seats = selectedVenue && section && rows.includes(draft.row) ? venueSeats(selectedVenue, section.section, draft.row) : [];
  const sectionInvalid = Boolean(selectedVenue && normalizedSectionInput && !section && (sectionCommitted || !sectionCouldMatch));
  const matchedGeneralLocation = generalLocations.find((location) => location.name.toLowerCase() === generalLocationName.trim().toLowerCase()) ?? null;

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const onKeyDown = (event: KeyboardEvent) => event.key === "Escape" && onClose();
    window.addEventListener("keydown", onKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [onClose]);

  const chooseMappedMethod = (method: MappedCheckInDraft["method"]) => {
    setDraft(initialMapped?.raw ?? emptyMappedCheckInDraft(method));
    setMappedCandidate(null);
    setRowExpanded(!initialMapped);
    setSeatExpanded(!initialMapped);
    setSectionCommitted(false);
    setError("");
    setStage(method === "Image" ? "upload" : "mappedDetails");
  };

  const updateVenue = (venueName: string) => {
    const match = venues.find(({ venue }) => venue.name.toLowerCase() === venueName.trim().toLowerCase())?.venue ?? null;
    const venueSports = match ? configuredVenueSports(match) : [];
    setDraft((current) => ({
      ...current,
      venueId: match?.id ?? "",
      venueName,
      eventId: "",
      sport: venueSports.includes(current.sport) ? current.sport : venueSports[0] ?? "Other",
      teamEvent: "",
      section: "",
      row: "",
      seat: "",
    }));
    setRowExpanded(true);
    setSeatExpanded(true);
    setSectionCommitted(false);
    setError("");
  };

  const updateSection = (value: string) => {
    setDraft((current) => ({ ...current, section: value.replace(/^section\s*/i, ""), row: "", seat: "" }));
    setRowExpanded(true);
    setSeatExpanded(true);
    setSectionCommitted(false);
    setError("");
  };

  const reviewMapped = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!selectedVenue) return setError("Choose a configured venue from the search results.");
    if (!sports.includes(draft.sport)) return setError("Choose a sport configured for this venue.");
    if (teamEvents.length && !teamEvents.some((team) => team.teamName === draft.teamEvent)) return setError("Choose a Team / Event configured for this venue and sport.");
    if (!section) {
      setSectionCommitted(true);
      return setError("Choose a valid section for this venue.");
    }
    if (!rows.includes(draft.row)) return setError("Choose a valid row for this section.");
    if (!seats.includes(draft.seat)) return setError("Choose a valid seat for this row.");
    const resolved = resolveMappedCheckIn(selectedVenue, { ...draft, section: section.section });
    if (!resolved) return setError("This seat could not be resolved from the saved venue mapping.");
    setMappedCandidate(resolved);
    setError("");
    setStage("mappedReview");
  };

  const reviewGeneral = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!matchedGeneralLocation) return setError("Choose a named location from the shared location results.");
    setGeneralCandidate(matchedGeneralLocation);
    setError("");
    setStage("generalReview");
  };

  const back = () => {
    setError("");
    if (stage === "mappedReview") setStage("mappedDetails");
    else if (stage === "generalReview") setStage("generalDetails");
    else if (stage === "mappedDetails" && draft.method === "Image") setStage("upload");
    else setStage("choice");
  };

  return (
    <div className="cheer-dialog-layer">
      <button className="cheer-dialog-backdrop" type="button" aria-label="Close Check In" onClick={onClose} />
      <section className="cheer-check-in" role="dialog" aria-modal="true" aria-labelledby="cheer-check-in-title">
        <header><div><span className="eyebrow">Shared Cheer context</span><h2 id="cheer-check-in-title">Check In</h2></div><button type="button" aria-label="Close Check In" onClick={onClose}>×</button></header>

        {stage === "choice" ? <div className="cheer-check-in__choice">
          <p>Check into a mapped venue seat or a shared named location.</p>
          <div className="cheer-check-in__choice-label"><strong>Mapped sports venue</strong><small>Uses the venue’s saved seating and routing rules</small></div>
          <button className="cheer-check-in__method cheer-check-in__method--primary" type="button" aria-label="Take Photo / Upload Screenshot" onClick={() => chooseMappedMethod("Image")}><span aria-hidden="true">▣</span><strong>Take Photo / Upload Screenshot</strong><small>Ticket screenshot, digital-ticket image, PDF, or physical-ticket photo</small></button>
          <button className="cheer-check-in__method" type="button" aria-label="Enter Manually" onClick={() => chooseMappedMethod("Manual")}><span aria-hidden="true">⌨</span><strong>Enter Manually</strong><small>Choose venue, sport, event, section, row, and seat</small></button>
          <div className="cheer-check-in__choice-label"><strong>General location</strong><small>For parks, rallies, watch parties, fields, and community events</small></div>
          <button className="cheer-check-in__method" type="button" aria-label="Choose General Location" onClick={() => { setError(""); setStage("generalDetails"); }}><span aria-hidden="true">◎</span><strong>Choose General Location</strong><small>Join a shared named place with All-only Cheer routing</small></button>
          {initial ? <button className="cheer-check-in__checkout" type="button" onClick={onClear}>Check Out</button> : null}
        </div> : null}

        {stage === "upload" ? <div className="cheer-check-in__upload"><button className="cheer-check-in__back" type="button" onClick={back}>← Check-In options</button><h3>Take Photo / Upload Screenshot</h3><p>Choose a screenshot, digital-ticket image, PDF, or photo of a physical ticket.</p><label><span>Ticket file</span><input type="file" accept="image/*,.pdf,application/pdf" onChange={(event) => { const file = event.target.files?.[0]; setCapture(file ? { kind: "ticket-file", fileName: file.name, mediaType: file.type || "application/octet-stream" } : null); }} /></label>{capture ? <div className="cheer-check-in__file"><strong>{capture.fileName}</strong><small>{capture.mediaType}</small></div> : null}<aside><strong>Ticket recognition is not enabled yet.</strong><span>This file is ready for a future provider-agnostic extraction layer. For now, continue and confirm or enter the ticket details yourself.</span></aside><button className="cheer-primary-button" type="button" disabled={!capture} onClick={() => { setDraft(emptyMappedCheckInDraft("Image")); setStage("mappedDetails"); }}>Continue to Confirm / Edit</button></div> : null}

        {stage === "mappedDetails" ? <form className="cheer-check-in__details" onSubmit={reviewMapped}>
          <button className="cheer-check-in__back" type="button" onClick={back}>← {draft.method === "Image" ? "Ticket file" : "Check-In options"}</button>
          <div><h3>{draft.method === "Image" ? "Confirm / Edit ticket details" : "Enter Manually"}</h3><p>Seat information is validated against the selected venue configuration.</p></div>
          <label>Venue<input required list="check-in-venues" value={draft.venueName} placeholder="Search venues" autoComplete="off" onChange={(event) => updateVenue(event.target.value)} /><datalist id="check-in-venues">{venues.map(({ venue }) => <option key={venue.id} value={venue.name}>{venue.location}</option>)}</datalist><small>{selectedVenue ? selectedVenue.location : "Nearby sorting can be added to this venue search later."}</small></label>
          <label>Sport<select required disabled={!selectedVenue} value={sports.includes(draft.sport) ? draft.sport : ""} onChange={(event) => setDraft((current) => ({ ...current, sport: event.target.value as CheerSport, eventId: "", teamEvent: "" }))}><option value="" disabled>Choose sport</option>{sports.map((sport) => <option key={sport}>{sport}</option>)}</select></label>
          {teamEvents.length ? <label>Team / Event<select required value={draft.teamEvent} onChange={(event) => { const selected = teamEvents.find((team) => team.teamName === event.target.value); setDraft((current) => ({ ...current, eventId: selected?.eventId ?? "", teamEvent: event.target.value })); }}><option value="" disabled>Choose Team / Event</option>{teamEvents.map((team) => <option key={team.eventId} value={team.teamName}>{team.teamName}</option>)}</select></label> : <label>Team / Event <small>Optional</small><input value={draft.teamEvent} placeholder="Team, matchup, or event" onChange={(event) => setDraft((current) => ({ ...current, eventId: "", teamEvent: event.target.value }))} /></label>}
          <label>Section<input required disabled={!selectedVenue} inputMode={selectedVenue?.sectionFormat === "Numeric" ? "numeric" : "text"} pattern={selectedVenue?.sectionFormat === "Numeric" ? "[0-9]*" : undefined} value={draft.section} placeholder="Enter section" autoComplete="off" onChange={(event) => updateSection(event.target.value)} onBlur={() => setSectionCommitted(true)} onKeyDown={(event) => { if (event.key === "Enter") { event.preventDefault(); setSectionCommitted(true); } }} /></label>
          {sectionInvalid ? <p className="cheer-check-in__field-error">Choose a valid section for this venue.</p> : null}
          {section ? <ValuePicker label="Row" values={rows} selected={draft.row} expanded={rowExpanded || !draft.row} onExpand={() => setRowExpanded(true)} onSelect={(row) => { setDraft((current) => ({ ...current, row, seat: "" })); setRowExpanded(false); setSeatExpanded(true); }} /> : null}
          {draft.row && rows.includes(draft.row) ? <ValuePicker label="Seat" values={seats} selected={draft.seat} expanded={seatExpanded || !draft.seat} onExpand={() => setSeatExpanded(true)} onSelect={(seat) => { setDraft((current) => ({ ...current, seat })); setSeatExpanded(false); }} /> : null}
          {error ? <p className="cheer-check-in__error" role="alert">{error}</p> : null}
          <div className="cheer-check-in__actions">{initial ? <button type="button" onClick={onClear}>Check Out</button> : null}<button className="cheer-primary-button" type="submit">Review Check-In</button></div>
        </form> : null}

        {stage === "mappedReview" && mappedCandidate ? <div className="cheer-check-in__review">
          <button className="cheer-check-in__back" type="button" onClick={back}>← Edit details</button>
          <div><span className="eyebrow">Confirm before checking in</span><h3>Review Check-In</h3></div>
          <dl><div><dt>Venue</dt><dd>{mappedCandidate.raw.venueName}</dd></div><div><dt>Sport / Team/Event</dt><dd>{mappedCandidate.raw.sport}{mappedCandidate.raw.teamEvent ? ` · ${mappedCandidate.raw.teamEvent}` : ""}</dd></div><div><dt>Seat</dt><dd>Section {mappedCandidate.raw.section} · Row {mappedCandidate.raw.row} · Seat {mappedCandidate.raw.seat}</dd></div></dl>
          <div className="cheer-check-in__actions">{initial ? <button type="button" onClick={onClear}>Check Out</button> : null}<button type="button" onClick={() => setStage("mappedDetails")}>Edit</button><button className="cheer-primary-button" type="button" onClick={() => onSave(mappedCandidate)}>Confirm Check-In</button></div>
        </div> : null}

        {stage === "generalDetails" ? <form className="cheer-check-in__details" onSubmit={reviewGeneral}>
          <button className="cheer-check-in__back" type="button" onClick={back}>← Check-In options</button>
          <div><h3>Choose General Location</h3><p>Select the shared named place where your crowd is gathering. Physical presence verification can be added later.</p></div>
          <label>Named location<input aria-label="Named location" required list="check-in-general-locations" value={generalLocationName} placeholder="Search shared locations" autoComplete="off" onChange={(event) => { setGeneralLocationName(event.target.value); setError(""); }} /><datalist id="check-in-general-locations">{generalLocations.map((location) => <option key={location.id} value={location.name}>{location.locality} · {location.category}</option>)}</datalist><small>{matchedGeneralLocation ? `${matchedGeneralLocation.locality} · ${matchedGeneralLocation.category}` : "Nearby sorting and geolocation can be added later."}</small></label>
          {error ? <p className="cheer-check-in__error" role="alert">{error}</p> : null}
          <div className="cheer-check-in__actions">{initial ? <button type="button" onClick={onClear}>Check Out</button> : null}<button className="cheer-primary-button" type="submit">Review Location</button></div>
        </form> : null}

        {stage === "generalReview" && (generalCandidate || initialGeneral) ? <div className="cheer-check-in__review">
          <button className="cheer-check-in__back" type="button" onClick={back}>← Change location</button>
          <div><span className="eyebrow">Confirm shared location</span><h3>Review Location</h3><p>{generalCandidate?.locality ?? initialGeneral?.location.locality}</p></div>
          <dl><div><dt>Location</dt><dd>{generalCandidate?.name ?? initialGeneral?.location.name}</dd></div><div><dt>Cheer routing</dt><dd>Whole crowd</dd></div></dl>
          <div className="cheer-check-in__actions">{initial ? <button type="button" onClick={onClear}>Check Out</button> : null}<button type="button" onClick={() => setStage("generalDetails")}>Edit</button>{generalCandidate ? <button className="cheer-primary-button" type="button" onClick={() => onSave(resolveGeneralLocationCheckIn(generalCandidate))}>Confirm Check-In</button> : null}</div>
        </div> : null}
      </section>
    </div>
  );
}
