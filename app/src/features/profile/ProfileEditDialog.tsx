import { useEffect, useRef, useState, type FormEvent } from "react";
import type { ProfileRecord } from "./types";
import { useNavigationSide, type NavigationSide } from "../../data/navigationSidePreference";
import { useProfileImageShape } from "../../data/profileImageShapePreference";
import { ProfileVisualSettings } from "../profileVisual/ProfileVisualSettings";
import { useProfileVisual } from "../profileVisual/ProfileVisualContext";
import { AppIcon } from "../../components/AppIcon";
import { ProfileAvatarEditor } from "../profileAvatar/ProfileAvatarEditor";
import { useProfileAvatar } from "../profileAvatar/ProfileAvatarContext";
import { ProfileAvatarMedia } from "../profileAvatar/ProfileAvatarMedia";
import { useHomeCustomization } from "../../data/homeCustomizationPreference";
import { resolveSavedHomeCustomizationPositions } from "../../pages/homeOverlayLayout";
import { HomeCustomizationSettings } from "./HomeCustomizationSettings";
import { useThemePreference } from "../../data/themePreference";
import { useTeamContext } from "../../state/TeamContext";
import { ThemeSettings } from "./ThemeSettings";
import { ProfilePrivacySettings } from "./ProfilePrivacySettings";
import { HiddenFansSettings } from "../community/HiddenFansSettings";

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
  const [mediaEditor, setMediaEditor] = useState<"avatar" | "visual" | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [fieldErrors, setFieldErrors] = useState<Readonly<{ handle?: string; displayName?: string }>>({});
  const { images } = useProfileVisual();
  const { avatar } = useProfileAvatar();
  const { side: savedNavigationSide, setSide: saveNavigationSide } = useNavigationSide();
  const { shape: profileImageShape } = useProfileImageShape();
  const { customization: savedHomeCustomization, setCustomization: saveHomeCustomization } = useHomeCustomization();
  const { preference: savedThemePreference, setPreference: saveThemePreference } = useThemePreference();
  const { followedTeams, selectedTeam } = useTeamContext();
  const [navigationSide, setNavigationSide] = useState<NavigationSide>(savedNavigationSide);
  const [homeCustomization, setHomeCustomization] = useState(savedHomeCustomization);
  const [themePreference, setThemePreference] = useState(savedThemePreference);
  const navigationSideDirtyRef = useRef(false);
  const homeCustomizationDirtyRef = useRef(false);
  const themePreferenceDirtyRef = useRef(false);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const handleInputRef = useRef<HTMLInputElement>(null);
  const displayNameInputRef = useRef<HTMLInputElement>(null);
  const onCloseRef = useRef(onClose);
  onCloseRef.current = onClose;

  useEffect(() => {
    if (!navigationSideDirtyRef.current) setNavigationSide(savedNavigationSide);
  }, [savedNavigationSide]);

  useEffect(() => {
    if (!homeCustomizationDirtyRef.current) setHomeCustomization(savedHomeCustomization);
  }, [savedHomeCustomization]);

  useEffect(() => {
    if (!themePreferenceDirtyRef.current) setThemePreference(savedThemePreference);
  }, [savedThemePreference]);

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeButtonRef.current?.focus();
    const closeOnEscape = (event: KeyboardEvent) => event.key === "Escape" && onCloseRef.current();
    window.addEventListener("keydown", closeOnEscape);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", closeOnEscape);
    };
  }, []);

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

  const changeHomeCustomization = (next: typeof homeCustomization) => {
    homeCustomizationDirtyRef.current = true;
    setHomeCustomization(next);
  };

  const changeNavigationSide = (side: NavigationSide) => {
    navigationSideDirtyRef.current = true;
    homeCustomizationDirtyRef.current = true;
    setNavigationSide(side);
    setHomeCustomization((current) => resolveSavedHomeCustomizationPositions(current, side));
  };

  const changeThemePreference = (next: typeof themePreference) => {
    themePreferenceDirtyRef.current = true;
    setThemePreference(next);
  };

  const clearFieldError = (field: "handle" | "displayName") => {
    setFieldErrors((current) => {
      if (!current[field]) return current;
      const next: { handle?: string; displayName?: string } = { ...current };
      delete next[field];
      return next;
    });
  };

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const nextFieldErrors: { handle?: string; displayName?: string } = {};
    const normalizedHandle = draft.handle.trim();
    if (normalizedHandle && !/^[A-Za-z0-9][A-Za-z0-9_]{1,18}[A-Za-z0-9]$/.test(normalizedHandle)) {
      nextFieldErrors.handle = "Use 3–20 letters, numbers, or underscores, beginning and ending with a letter or number.";
    }
    if (!draft.displayName.trim()) nextFieldErrors.displayName = "Enter a display name before saving.";
    setFieldErrors(nextFieldErrors);
    if (nextFieldErrors.handle || nextFieldErrors.displayName) {
      setError("Review the highlighted Profile identity field and try again.");
      window.requestAnimationFrame(() => {
        (nextFieldErrors.handle ? handleInputRef.current : displayNameInputRef.current)?.focus();
      });
      return;
    }
    setBusy(true);
    setError("");
    try {
      await onSave({
        ...draft,
        displayName: draft.displayName.trim(),
        tagline: draft.tagline.trim(),
      });
      await saveNavigationSide(navigationSide);
      await saveHomeCustomization(resolveSavedHomeCustomizationPositions(homeCustomization, navigationSide));
      await saveThemePreference(themePreference);
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
            <h2 id="profile-edit-title">{mediaEditor === "visual" ? "Profile Visual" : mediaEditor === "avatar" ? "Profile Photo" : "Edit Profile"}</h2>
            <p>{mediaEditor === "visual" ? "Crop and manage the responsive images used on Home." : mediaEditor === "avatar" ? "Position the image exactly as it will appear throughout FANatical." : accountBacked ? "Profile and personal settings synchronize with your FANatical account." : "Prototype changes stay on this device until hosted accounts are configured."}</p>
          </div>
          <button ref={closeButtonRef} className="profile-icon-button" type="button" aria-label="Close profile editor" onClick={onClose}><AppIcon name="x-mark" /></button>
        </header>
        {mediaEditor === "visual" ? <div className="profile-visual-manager"><button type="button" onClick={() => setMediaEditor(null)}><AppIcon name="arrow-left" /> Back to Profile settings</button><ProfileVisualSettings /></div> : mediaEditor === "avatar" ? <div className="profile-avatar-manager"><ProfileAvatarEditor onDone={() => setMediaEditor(null)} onCancel={() => setMediaEditor(null)} /></div> : <form noValidate onSubmit={(event) => void submit(event)}>
          <fieldset>
            <legend>Profile identity</legend>
            <label>Fanatical Name<input ref={handleInputRef} minLength={3} maxLength={20} pattern="[A-Za-z0-9][A-Za-z0-9_]{1,18}[A-Za-z0-9]" aria-invalid={Boolean(fieldErrors.handle)} aria-describedby={fieldErrors.handle ? "profile-handle-error" : undefined} value={draft.handle} onChange={(event) => { setDraft((current) => ({ ...current, handle: event.target.value })); clearFieldError("handle"); }} /><small>Your public Community identity. Leave blank to release it. Changing or releasing it does not move your history.</small>{fieldErrors.handle ? <small id="profile-handle-error" className="profile-edit-dialog__field-error">{fieldErrors.handle}</small> : null}</label>
            <label>Display name<input ref={displayNameInputRef} required aria-invalid={Boolean(fieldErrors.displayName)} aria-describedby={fieldErrors.displayName ? "profile-display-name-error" : undefined} value={draft.displayName} onChange={(event) => { setDraft((current) => ({ ...current, displayName: event.target.value })); clearFieldError("displayName"); }} />{fieldErrors.displayName ? <small id="profile-display-name-error" className="profile-edit-dialog__field-error">{fieldErrors.displayName}</small> : null}</label>
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
            <legend>Profile photo</legend>
            <div className="profile-avatar-summary">
              <ProfileAvatarMedia avatar={avatar} shape={profileImageShape} />
              <span><strong>{avatar ? "Custom profile photo" : "User icon"}</strong><small>{avatar?.sourceFilename ?? (accountBacked ? "Add a photo for your FANatical account" : "Sign in to add a profile photo")}</small></span>
              <button type="button" disabled={!accountBacked} onClick={() => setMediaEditor("avatar")}>{avatar ? "Edit photo" : "Add photo"}</button>
            </div>
          </fieldset>
          <fieldset>
            <legend>Personal Settings</legend>
            <div className="profile-featured-picker" role="radiogroup" aria-labelledby="profile-navigation-side-title">
              <strong id="profile-navigation-side-title">Navigation Side</strong>
              <div>
                {(["left", "right"] as const).map((side) => (
                  <label key={side}><input type="radio" name="navigationSide" value={side} checked={navigationSide === side} onChange={() => changeNavigationSide(side)} /><span>{side === "left" ? "Left" : "Right"}</span></label>
                ))}
              </div>
              <p>Choose which side of the Home profile visual holds the floating feature navigation.</p>
            </div>
          </fieldset>
          <ProfilePrivacySettings
            value={draft.visibility}
            disabled={!accountBacked}
            {...(draft.personalFieldVisibility ? { personalFieldVisibility: draft.personalFieldVisibility } : {})}
            onChange={(visibility) => setDraft((current) => ({ ...current, visibility }))}
            onPersonalFieldChange={(field, visible) => setDraft((current) => ({ ...current, personalFieldVisibility: { ...current.personalFieldVisibility, [field]: visible } }))}
          />
          <HiddenFansSettings disabled={!accountBacked} />
          <ThemeSettings value={themePreference} favoriteTeam={followedTeams[0]} currentTeam={selectedTeam} onChange={changeThemePreference} />
          <HomeCustomizationSettings profile={draft} value={homeCustomization} navigationSide={navigationSide} onChange={changeHomeCustomization} />
          <fieldset>
            <legend>Profile visual</legend>
            <div className="profile-visual-summary">
              {(["mobile", "wide"] as const).map((variant) => {
                const image = images[variant];
                const label = variant === "mobile" ? "Mobile image" : "Wide image";
                return <div key={variant}><span><strong>{label}</strong><small>{image?.sourceFilename ?? "FANatical default"}</small></span><button type="button" aria-label={`${image ? "Manage" : "Add"} ${label}`} onClick={() => setMediaEditor("visual")}>{image ? "Manage" : "Add image"}</button></div>;
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
