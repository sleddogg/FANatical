import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { InternalVenueShell } from "./InternalVenueShell";
import type { SectionException, TeamSeatingProfile, VenueEnd, VenueLevel, VenueSectionMapping, VenueSide } from "./types";
import { useRexallVenue } from "./useRexallVenue";
import "./internalVenue.css";

const levels = ["Upper", "Lower", "N/A"] as const satisfies readonly VenueLevel[];
const sideValues = ["Side A", "Side B"] as const satisfies readonly VenueSide[];
const endValues = ["End A", "End B"] as const satisfies readonly VenueEnd[];
const levelUses = ["Upper + Lower", "Upper only", "Lower only", "N/A"] as const;
const sideUses = ["Both", "Side A only", "Side B only"] as const;
const endUses = ["Both", "End A only", "End B only"] as const;

function newId(prefix: string) {
  return `${prefix}-${typeof crypto.randomUUID === "function" ? crypto.randomUUID() : Date.now()}`;
}

function SectionGroups({ sections }: { readonly sections: readonly VenueSectionMapping[] }) {
  const groups = [
    ["Upper Sections", sections.filter((item) => item.level === "Upper")],
    ["Lower Sections", sections.filter((item) => item.level === "Lower")],
    ["Side A Sections", sections.filter((item) => item.side === "Side A")],
    ["Side B Sections", sections.filter((item) => item.side === "Side B")],
    ["End A Sections", sections.filter((item) => item.end === "End A")],
    ["End B Sections", sections.filter((item) => item.end === "End B")],
  ] as const;
  return <div className="venue-groups">{groups.map(([label, items]) => <section key={label}><header><h3>{label}</h3><span>{items.length}</span></header><p>{items.map((item) => item.section).join(" · ") || "None"}</p></section>)}</div>;
}

function ExceptionEditor({ section, onChange, onClose }: { readonly section: VenueSectionMapping; readonly onChange: (exceptions: readonly SectionException[]) => void; readonly onClose: () => void }) {
  const update = (id: string, patch: Partial<SectionException>) => onChange(section.exceptions.map((rule) => rule.id === id ? { ...rule, ...patch } : rule));
  const add = () => onChange([...section.exceptions, {
    id: newId(`section-${section.section}-exception`), rowStart: "", rowEnd: "", seatStart: 1, seatEnd: 10,
    level: null, side: null, end: section.end === "End A" ? "End B" : "End A",
  }]);
  return (
    <div className="internal-modal" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <section role="dialog" aria-modal="true" aria-labelledby="exception-editor-title" className="internal-dialog internal-dialog--wide">
        <header><div><span className="internal-kicker">Boundary routing</span><h2 id="exception-editor-title">Section {section.section} exceptions</h2><p>Use a row range, seat range, or both. The first matching override for each axis wins.</p></div><button type="button" aria-label="Close exceptions" onClick={onClose}>×</button></header>
        <div className="exception-list">
          {section.exceptions.map((rule, index) => <article key={rule.id}>
            <header><strong>Rule {index + 1}</strong><button type="button" onClick={() => onChange(section.exceptions.filter((item) => item.id !== rule.id))}>Delete</button></header>
            <div className="exception-grid">
              <label>Row from<input value={rule.rowStart} placeholder="Any" onChange={(event) => update(rule.id, { rowStart: event.target.value })} /></label>
              <label>Row to<input value={rule.rowEnd} placeholder="Any" onChange={(event) => update(rule.id, { rowEnd: event.target.value })} /></label>
              <label>Seat from<input type="number" min="1" value={rule.seatStart ?? ""} placeholder="Any" onChange={(event) => update(rule.id, { seatStart: event.target.value ? Number(event.target.value) : null })} /></label>
              <label>Seat to<input type="number" min="1" value={rule.seatEnd ?? ""} placeholder="Any" onChange={(event) => update(rule.id, { seatEnd: event.target.value ? Number(event.target.value) : null })} /></label>
              <label>Level override<select value={rule.level ?? ""} onChange={(event) => update(rule.id, { level: event.target.value ? event.target.value as VenueLevel : null })}><option value="">No override</option>{levels.map((value) => <option key={value}>{value}</option>)}</select></label>
              <label>Side override<select value={rule.side ?? ""} onChange={(event) => update(rule.id, { side: event.target.value ? event.target.value as VenueSide : null })}><option value="">No override</option>{sideValues.map((value) => <option key={value}>{value}</option>)}</select></label>
              <label>End override<select value={rule.end ?? ""} onChange={(event) => update(rule.id, { end: event.target.value ? event.target.value as VenueEnd : null })}><option value="">No override</option>{endValues.map((value) => <option key={value}>{value}</option>)}</select></label>
            </div>
          </article>)}
          {!section.exceptions.length ? <div className="internal-empty"><strong>No exceptions</strong><p>This section currently resolves entirely from its physical section mapping.</p></div> : null}
        </div>
        <footer><span>Changes save immediately.</span><button type="button" onClick={add}>+ Add Exception Rule</button><button className="internal-primary" type="button" onClick={onClose}>Done</button></footer>
      </section>
    </div>
  );
}

function ProfileEditor({ profile, onSave, onClose }: { readonly profile: TeamSeatingProfile; readonly onSave: (profile: TeamSeatingProfile) => void; readonly onClose: () => void }) {
  const [draft, setDraft] = useState(profile);
  return <div className="internal-modal" role="presentation"><form className="internal-dialog" onSubmit={(event) => { event.preventDefault(); if (draft.teamName.trim()) onSave({ ...draft, teamName: draft.teamName.trim() }); }}><header><div><span className="internal-kicker">Team Seating Profile</span><h2>{profile.teamName ? `Edit ${profile.teamName}` : "Add Team Profile"}</h2></div><button type="button" aria-label="Close team profile" onClick={onClose}>×</button></header><div className="profile-form"><label>Team name<input required value={draft.teamName} onChange={(event) => setDraft({ ...draft, teamName: event.target.value })} /></label><label>Levels normally used<select value={draft.levels} onChange={(event) => setDraft({ ...draft, levels: event.target.value as TeamSeatingProfile["levels"] })}>{levelUses.map((value) => <option key={value}>{value}</option>)}</select></label><label>Sides normally used<select value={draft.sides} onChange={(event) => setDraft({ ...draft, sides: event.target.value as TeamSeatingProfile["sides"] })}>{sideUses.map((value) => <option key={value}>{value}</option>)}</select></label><label>Ends normally used<select value={draft.ends} onChange={(event) => setDraft({ ...draft, ends: event.target.value as TeamSeatingProfile["ends"] })}>{endUses.map((value) => <option key={value}>{value}</option>)}</select></label></div><footer><button type="button" onClick={onClose}>Cancel</button><button className="internal-primary" type="submit">Save Profile</button></footer></form></div>;
}

export function RexallVenuePage() {
  const [venue, setVenue] = useRexallVenue();
  const [referenceDraft, setReferenceDraft] = useState(() => ({ name: venue.name, location: venue.location, seatingChartImageUrl: venue.seatingChartImageUrl, seatingChartSourceLabel: venue.seatingChartSourceLabel, seatingChartSourceUrl: venue.seatingChartSourceUrl }));
  const [exceptionSection, setExceptionSection] = useState<string | null>(null);
  const [profileDraft, setProfileDraft] = useState<TeamSeatingProfile | null>(null);
  const selectedExceptionSection = useMemo(() => venue.sections.find((section) => section.section === exceptionSection) ?? null, [exceptionSection, venue.sections]);
  const updateSection = (sectionId: string, patch: Partial<VenueSectionMapping>) => setVenue((current) => ({ ...current, sections: current.sections.map((section) => section.section === sectionId ? { ...section, ...patch } : section) }));

  return (
    <InternalVenueShell mode="mapping">
      <main className="internal-venue-main">
        <section className="venue-hero">
          <div><span className="internal-kicker">Seeded working venue</span><h1>{venue.name}</h1><p>{venue.location}</p><div className="venue-hero__actions"><Link className="internal-primary" to="/internal/venues/rexall-place/test">Open Seat Resolver Tester →</Link><span>Saved locally · Updated {new Date(venue.updatedAt).toLocaleString()}</span></div></div>
          <figure><img src={venue.seatingChartImageUrl} alt={`${venue.name} reference seating chart`} /><figcaption>Reference: <a href={venue.seatingChartSourceUrl} target="_blank" rel="noreferrer">{venue.seatingChartSourceLabel}</a></figcaption></figure>
        </section>

        <details className="internal-panel reference-editor"><summary>Edit venue + seating-chart reference</summary><form onSubmit={(event) => { event.preventDefault(); setVenue((current) => ({ ...current, ...referenceDraft })); }}><label>Venue name<input value={referenceDraft.name} onChange={(event) => setReferenceDraft({ ...referenceDraft, name: event.target.value })} /></label><label>Location<input value={referenceDraft.location} onChange={(event) => setReferenceDraft({ ...referenceDraft, location: event.target.value })} /></label><label>Chart image URL<input type="url" value={referenceDraft.seatingChartImageUrl} onChange={(event) => setReferenceDraft({ ...referenceDraft, seatingChartImageUrl: event.target.value })} /></label><label>Source label<input value={referenceDraft.seatingChartSourceLabel} onChange={(event) => setReferenceDraft({ ...referenceDraft, seatingChartSourceLabel: event.target.value })} /></label><label>Source URL<input type="url" value={referenceDraft.seatingChartSourceUrl} onChange={(event) => setReferenceDraft({ ...referenceDraft, seatingChartSourceUrl: event.target.value })} /></label><button className="internal-primary" type="submit">Save Reference</button></form></details>

        <section className="internal-panel"><header className="internal-section-heading"><div><span className="internal-kicker">Physical routing</span><h2>Mapping overview</h2><p>Grouped values update whenever a section mapping changes. Team profiles never alter this shared physical map.</p></div><span>{venue.sections.length} sections</span></header><aside className="venue-mapping-rule"><strong>Venue mapping convention</strong><span>Orient the playing surface’s long axis horizontally: upper long side = Side A, lower long side = Side B, left half = End A, right half = End B. Confirm each venue against its sport-appropriate images in <code>reference/cheer/routing/</code>.</span></aside><SectionGroups sections={venue.sections} /></section>

        <section className="internal-panel"><header className="internal-section-heading"><div><span className="internal-kicker">Editable source of truth</span><h2>Section-by-section mapping</h2><p>Exception badges identify sections whose row or seat rules may override the section defaults.</p></div></header><div className="internal-table-wrap"><table className="venue-mapping-table"><thead><tr><th>Section</th><th>Level</th><th>Side</th><th>End</th><th>Exceptions</th></tr></thead><tbody>{venue.sections.map((section) => <tr key={section.section}><th scope="row">{section.section}</th><td><select aria-label={`Section ${section.section} level`} value={section.level} onChange={(event) => updateSection(section.section, { level: event.target.value as VenueLevel })}>{levels.map((value) => <option key={value}>{value}</option>)}</select></td><td><select aria-label={`Section ${section.section} side`} value={section.side} onChange={(event) => updateSection(section.section, { side: event.target.value as VenueSide })}>{sideValues.map((value) => <option key={value}>{value}</option>)}</select></td><td><select aria-label={`Section ${section.section} end`} value={section.end} onChange={(event) => updateSection(section.section, { end: event.target.value as VenueEnd })}>{endValues.map((value) => <option key={value}>{value}</option>)}</select></td><td><button className={section.exceptions.length ? "exception-button exception-button--active" : "exception-button"} type="button" onClick={() => setExceptionSection(section.section)}>{section.exceptions.length ? `${section.exceptions.length} ${section.exceptions.length === 1 ? "rule" : "rules"}` : "Add rule"}</button></td></tr>)}</tbody></table></div></section>

        <section className="internal-panel"><header className="internal-section-heading"><div><span className="internal-kicker">Event context, not physical mapping</span><h2>Team Seating Profiles</h2><p>Profiles describe the portions of Rexall Place a team normally uses. Resolver output remains physical.</p></div><button className="internal-primary" type="button" onClick={() => setProfileDraft({ id: newId("team-profile"), teamName: "", levels: "Upper + Lower", sides: "Both", ends: "Both" })}>+ Add Team Profile</button></header><div className="team-profile-grid">{venue.teamProfiles.map((profile) => <article key={profile.id}><div><span className="team-profile-mark" aria-hidden="true">{profile.teamName.split(" ").map((word) => word[0]).join("").slice(0, 2)}</span><div><h3>{profile.teamName}</h3><p>{profile.levels} · {profile.sides === "Both" ? "Both sides" : profile.sides} · {profile.ends === "Both" ? "Both ends" : profile.ends}</p></div></div><div><button type="button" onClick={() => setProfileDraft(profile)}>Edit</button><button type="button" onClick={() => { if (window.confirm(`Delete ${profile.teamName}?`)) setVenue((current) => ({ ...current, teamProfiles: current.teamProfiles.filter((item) => item.id !== profile.id) })); }}>Delete</button></div></article>)}</div></section>
      </main>
      {selectedExceptionSection ? <ExceptionEditor section={selectedExceptionSection} onChange={(exceptions) => updateSection(selectedExceptionSection.section, { exceptions })} onClose={() => setExceptionSection(null)} /> : null}
      {profileDraft ? <ProfileEditor profile={profileDraft} onClose={() => setProfileDraft(null)} onSave={(profile) => { setVenue((current) => ({ ...current, teamProfiles: current.teamProfiles.some((item) => item.id === profile.id) ? current.teamProfiles.map((item) => item.id === profile.id ? profile : item) : [...current.teamProfiles, profile] })); setProfileDraft(null); }} /> : null}
    </InternalVenueShell>
  );
}
