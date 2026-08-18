import { useEffect, useRef, useState, type FormEvent } from "react";
import type { ProfileRecord } from "./types";
import { useNavigationSide, type NavigationSide } from "../../data/navigationSidePreference";
import { ProfileVisualSettings } from "../profileVisual/ProfileVisualSettings";
import { useProfileVisual } from "../profileVisual/ProfileVisualContext";
import { AppIcon } from "../../components/AppIcon";

let localSportSequence = 0;

type ProfileEditDialogProps = {
  readonly profile: ProfileRecord;
  readonly onSave: (profile: ProfileRecord) => void | Promise<void>;
  readonly onClose: () => void;
  readonly accountBacked?: boolean;
  readonly onSignOut?: () => void | Promise<void>;
};

export function ProfileEditDialog({ profile, onSave, onClose, accountBacked = false, onSignOut }: ProfileEditDialogProps) {
  const [draft, setDraft] = useState(profile);
  const [visualEditorOpen, setVisualEditorOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const { images } = useProfileVisual();
  const { side: savedNavigationSide, setSide: saveNavigationSide } = useNavigationSide();
  const [navigationSide, setNavigationSide] = useState<NavigationSide>(savedNavigationSide);
  const closeButtonRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeButtonRef.current?.focus();
    const closeOnEscape = (event: KeyboardEvent) => event.key === "Escape" && onClose();
    window.addEventListener("keydown", closeOnEscape);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", closeOnEscape);
    };
  }, [onClose]);

  const updateField = (collection: "bio" | "fanIdentity", fieldId: string, value: string) => {
    setDraft((current) => ({
      ...current,
      [collection]: current[collection].map((field) => field.id === fieldId ? { ...field, value } : field),
    }));
  };

  const updateSport = (sportId: string, key: "sport" | "position" | "level" | "years" | "highlight", value: string) => {
    setDraft((current) => ({
      ...current,
      sportsPlayed: current.sportsPlayed.map((sport) => sport.id === sportId ? { ...sport, [key]: value } : sport),
    }));
  };

  const addSport = () => {
    localSportSequence += 1;
    setDraft((current) => ({
      ...current,
      sportsPlayed: [...current.sportsPlayed, {
        id: `profile-sport-local-${localSportSequence}`,
        sport: "",
        position: "",
        level: "",
        years: "",
        highlight: "",
      }],
    }));
  };

  const removeSport = (sportId: string) => {
    setDraft((current) => ({
      ...current,
      sportsPlayed: current.sportsPlayed.filter((sport) => sport.id !== sportId),
    }));
  };

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setBusy(true);
    setError("");
    try {
      await onSave({
        ...draft,
        displayName: draft.displayName.trim(),
        tagline: draft.tagline.trim(),
      });
      await saveNavigationSide(navigationSide);
      onClose();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Profile changes could not be saved.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="profile-dialog-layer">
      <button className="profile-dialog-backdrop" type="button" aria-label="Close profile editor" onClick={onClose} />
      <section className="profile-edit-dialog" role="dialog" aria-modal="true" aria-labelledby="profile-edit-title">
        <header>
          <div>
            <span className="eyebrow">Owner controls</span>
            <h2 id="profile-edit-title">{visualEditorOpen ? "Profile Visual" : "Edit Profile"}</h2>
            <p>{visualEditorOpen ? "Crop and manage the responsive images used on Home." : accountBacked ? "Profile and personal settings synchronize with your FANatical account." : "Prototype changes stay on this device until hosted accounts are configured."}</p>
          </div>
          <button ref={closeButtonRef} className="profile-icon-button" type="button" aria-label="Close profile editor" onClick={onClose}><AppIcon name="x-mark" /></button>
        </header>
        {visualEditorOpen ? <div className="profile-visual-manager"><button type="button" onClick={() => setVisualEditorOpen(false)}><AppIcon name="arrow-left" /> Back to Profile settings</button><ProfileVisualSettings /></div> : <form onSubmit={(event) => void submit(event)}>
          <fieldset>
            <legend>Profile identity</legend>
            <label>Display name<input required value={draft.displayName} onChange={(event) => setDraft((current) => ({ ...current, displayName: event.target.value }))} /></label>
            <label>Tagline<input maxLength={100} value={draft.tagline} onChange={(event) => setDraft((current) => ({ ...current, tagline: event.target.value }))} /></label>
            <div className="profile-featured-picker" role="radiogroup" aria-labelledby="profile-featured-picker-title">
              <strong id="profile-featured-picker-title">Featured FANfoto Category</strong>
              <div>
                {(["Game Face", "Fan Cave", "Memorabilia"] as const).map((category) => (
                  <label key={category}><input type="radio" name="featuredFanPhotoCategory" value={category} checked={draft.featuredFanPhotoCategory === category} onChange={() => setDraft((current) => ({ ...current, featuredFanPhotoCategory: category }))} /><span>{category}</span></label>
                ))}
              </div>
              <p>The featured category is centered when Profile opens. Its first curated FANfoto supplies the cover.</p>
            </div>
          </fieldset>
          <fieldset>
            <legend>Personal Settings</legend>
            <div className="profile-featured-picker" role="radiogroup" aria-labelledby="profile-navigation-side-title">
              <strong id="profile-navigation-side-title">Navigation Side</strong>
              <div>
                {(["left", "right"] as const).map((side) => (
                  <label key={side}><input type="radio" name="navigationSide" value={side} checked={navigationSide === side} onChange={() => setNavigationSide(side)} /><span>{side === "left" ? "Left" : "Right"}</span></label>
                ))}
              </div>
              <p>Choose which side of the Home profile visual holds the floating feature navigation.</p>
            </div>
          </fieldset>
          <fieldset>
            <legend>Profile visual</legend>
            <div className="profile-visual-summary">
              {(["mobile", "wide"] as const).map((variant) => {
                const image = images[variant];
                const label = variant === "mobile" ? "Mobile image" : "Wide image";
                return <div key={variant}><span><strong>{label}</strong><small>{image?.sourceFilename ?? "FANatical default"}</small></span><button type="button" aria-label={`${image ? "Manage" : "Add"} ${label}`} onClick={() => setVisualEditorOpen(true)}>{image ? "Manage" : "Add image"}</button></div>;
              })}
            </div>
          </fieldset>
          <fieldset>
            <legend>Bio</legend>
            <div className="profile-edit-dialog__field-grid">
              {draft.bio.map((field) => <label key={field.id}>{field.label}<input value={field.value} onChange={(event) => updateField("bio", field.id, event.target.value)} /></label>)}
            </div>
          </fieldset>
          <fieldset>
            <legend>Fan Identity</legend>
            <div className="profile-edit-dialog__field-grid">
              {draft.fanIdentity.filter((field) => field.id !== "primary-team" && field.id !== "secondary-teams").map((field) => <label key={field.id}>{field.label}<textarea rows={field.value.length > 45 ? 3 : 2} value={field.value} onChange={(event) => updateField("fanIdentity", field.id, event.target.value)} /></label>)}
            </div>
          </fieldset>
          <fieldset aria-labelledby="profile-edit-sports-title">
            <div className="profile-edit-dialog__section-heading"><h3 id="profile-edit-sports-title">Sports Played</h3><button type="button" aria-label="Add sport" onClick={addSport}><AppIcon name="plus" /></button></div>
            <div className="profile-edit-dialog__sports">
              {draft.sportsPlayed.map((sport) => (
                <section key={sport.id} aria-label={`Edit ${sport.sport || "new sport"}`}>
                  <button className="profile-edit-dialog__remove-sport" type="button" aria-label={`Remove ${sport.sport || "new sport"}`} onClick={() => removeSport(sport.id)}>Remove</button>
                  <label>Sport<input value={sport.sport} onChange={(event) => updateSport(sport.id, "sport", event.target.value)} /></label>
                  <label>Position / role<input value={sport.position} onChange={(event) => updateSport(sport.id, "position", event.target.value)} /></label>
                  <label>Level<input value={sport.level} onChange={(event) => updateSport(sport.id, "level", event.target.value)} /></label>
                  <label>Years<input value={sport.years} onChange={(event) => updateSport(sport.id, "years", event.target.value)} /></label>
                  <label className="profile-edit-dialog__wide-field">Highlight<input value={sport.highlight} onChange={(event) => updateSport(sport.id, "highlight", event.target.value)} /></label>
                </section>
              ))}
            </div>
          </fieldset>
          <div className="profile-edit-dialog__actions">
            {onSignOut ? <button className="profile-edit-dialog__sign-out" type="button" disabled={busy} onClick={() => void onSignOut()}>Sign out on this device</button> : null}
            <button type="button" disabled={busy} onClick={onClose}>Cancel</button>
            <button type="submit" disabled={busy}>{busy ? "Saving…" : "Save profile"}</button>
          </div>
          {error ? <p className="profile-edit-dialog__save-error" role="alert">{error}</p> : null}
        </form>}
      </section>
    </div>
  );
}
