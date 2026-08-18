import { useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { AppIcon } from "../../../components/AppIcon";
import { InternalVenueShell } from "./InternalVenueShell";
import { resolveRexallSeat } from "./rexallVenueData";
import type { SeatResolution } from "./types";
import { useRexallVenue } from "./useRexallVenue";
import "./internalVenue.css";

type TestInput = Readonly<{ profileId: string; section: string; row: string; seat: string }>;

export function RexallSeatResolverPage() {
  const [venue] = useRexallVenue();
  const [input, setInput] = useState<TestInput>(() => ({ profileId: venue.teamProfiles[1]?.id ?? venue.teamProfiles[0]?.id ?? "", section: "114", row: "12", seat: "8" }));
  const [resolution, setResolution] = useState<SeatResolution | null>(null);
  const [testedInput, setTestedInput] = useState<TestInput | null>(null);
  const [error, setError] = useState("");
  const profile = venue.teamProfiles.find((item) => item.id === testedInput?.profileId) ?? null;

  const resolve = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const seat = Number(input.seat);
    const next = Number.isFinite(seat) ? resolveRexallSeat(venue, input.section, input.row, seat) : null;
    setTestedInput(input);
    setResolution(next);
    setError(next ? "" : `Section ${input.section.trim() || "(blank)"} does not exist in the saved Rexall Place mapping.`);
  };

  return (
    <InternalVenueShell mode="tester">
      <main className="resolver-main">
        <header className="resolver-heading"><div><span className="internal-kicker">Physical Cheer routing</span><h1>{venue.name} Seat Resolver Tester</h1><p>Enter any section, row, and seat. This explains physical routing only—it does not validate a ticket or event configuration.</p></div><Link to="/internal/venues/rexall-place"><AppIcon name="arrow-left" /> Edit Venue Mapping</Link></header>
        <div className="resolver-layout">
          <form className="internal-panel resolver-form" onSubmit={resolve}>
            <header><span className="internal-kicker">Test input</span><h2>Resolve a seat</h2></header>
            <label>Team Profile<select required value={input.profileId} onChange={(event) => setInput({ ...input, profileId: event.target.value })}>{venue.teamProfiles.map((item) => <option key={item.id} value={item.id}>{item.teamName}</option>)}</select></label>
            <label>Section<input required list="rexall-sections" value={input.section} onChange={(event) => setInput({ ...input, section: event.target.value })} /><datalist id="rexall-sections">{venue.sections.map((section) => <option key={section.section} value={section.section} />)}</datalist></label>
            <div><label>Row<input required value={input.row} onChange={(event) => setInput({ ...input, row: event.target.value })} /></label><label>Seat<input required type="number" min="1" value={input.seat} onChange={(event) => setInput({ ...input, seat: event.target.value })} /></label></div>
            <button className="internal-primary" type="submit">Resolve Seat</button>
          </form>

          <section className="internal-panel resolver-result" aria-live="polite">
            {!testedInput ? <div className="resolver-placeholder"><AppIcon name="information-circle" /><h2>Ready to resolve</h2><p>The seeded example is Section 114 · Row 12 · Seat 8.</p></div> : null}
            {error ? <div className="resolver-placeholder resolver-placeholder--error"><AppIcon name="exclamation-triangle" /><h2>No mapping found</h2><p>{error}</p></div> : null}
            {resolution && testedInput ? <>
              <header><span className="internal-kicker">Seat</span><h2>Section {resolution.section.section} · Row {testedInput.row} · Seat {testedInput.seat}</h2></header>
              <div className="resolved-location"><span>Resolved location</span><strong>{resolution.level.value} · {resolution.side.value} · {resolution.end.value}</strong></div>
              <div className="resolved-profile"><span>Team profile</span><strong>{profile ? `${profile.teamName} · ${profile.levels}` : "No team profile selected"}</strong>{profile ? <small>{profile.sides === "Both" ? "Both sides" : profile.sides} · {profile.ends === "Both" ? "Both ends" : profile.ends}</small> : null}</div>
              <div className="resolver-explanation"><h3>Why this resolved</h3><dl><div><dt>Level</dt><dd><strong>{resolution.level.value}</strong><span>{resolution.level.source}</span></dd></div><div><dt>Side</dt><dd><strong>{resolution.side.value}</strong><span>{resolution.side.source}</span></dd></div><div><dt>End</dt><dd><strong>{resolution.end.value}</strong><span>{resolution.end.source}</span></dd></div></dl></div>
              <p className="resolver-note">The team profile is contextual only. It does not reject a physically resolvable seat outside the team’s normal seating usage.</p>
            </> : null}
          </section>
        </div>
      </main>
    </InternalVenueShell>
  );
}
