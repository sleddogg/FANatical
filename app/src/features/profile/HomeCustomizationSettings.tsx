import { AppIcon } from "../../components/AppIcon";
import type { NavigationSide } from "../../data/navigationSidePreference";
import { homeOverlayPositions, type HomeCustomization, type HomeOverlayPosition } from "../../data/homeCustomizationStorage";
import { homeOverlayPositionLabels, positionConflictsWithNavigation } from "../../pages/homeOverlayLayout";
import type { ProfileField, ProfileRecord } from "./types";

type HomeCustomizationSettingsProps = Readonly<{
  profile: ProfileRecord;
  value: HomeCustomization;
  navigationSide: NavigationSide;
  onChange: (value: HomeCustomization) => void;
}>;

const compactBioFieldIds = ["fanatical-name", "given-name", "nickname", "birthplace", "jersey-number", "height", "weight"] as const;
const compactFanIdentityFieldIds = ["fan-since"] as const;

function eligibleFields(profile: ProfileRecord): readonly ProfileField[] {
  return [
    ...compactBioFieldIds.map((id) => profile.bio.find((field) => field.id === id)).filter((field): field is ProfileField => Boolean(field)),
    ...compactFanIdentityFieldIds.map((id) => profile.fanIdentity.find((field) => field.id === id)).filter((field): field is ProfileField => Boolean(field)),
  ];
}

function OverlayToggle({ id, label, checked, onChange }: { readonly id: string; readonly label: string; readonly checked: boolean; readonly onChange: (checked: boolean) => void }) {
  return (
    <label className="home-customization-toggle" htmlFor={id}>
      <input id={id} aria-label={label} type="checkbox" role="switch" checked={checked} onChange={(event) => onChange(event.target.checked)} />
      <span aria-hidden="true" />
      <strong>{checked ? "Enabled" : "Disabled"}</strong>
    </label>
  );
}

function PositionSelector({
  id,
  label,
  value,
  navigationSide,
  occupiedPosition,
  onChange,
}: {
  readonly id: string;
  readonly label: string;
  readonly value: HomeOverlayPosition;
  readonly navigationSide: NavigationSide;
  readonly occupiedPosition?: HomeOverlayPosition;
  readonly onChange: (position: HomeOverlayPosition) => void;
}) {
  return (
    <div className="home-position-picker" role="radiogroup" aria-labelledby={`${id}-label`}>
      <strong id={`${id}-label`}>{label}</strong>
      <div className="home-position-picker__grid">
        {homeOverlayPositions.map((position) => {
          const navigationConflict = positionConflictsWithNavigation(position, navigationSide);
          const overlayConflict = occupiedPosition === position;
          const unavailableReason = navigationConflict
            ? `Unavailable because the ${navigationSide} feature navigation occupies this area.`
            : overlayConflict
              ? "Unavailable because the other Home overlay uses this position."
              : "";
          return (
            <button
              key={position}
              className={`home-position-picker__option home-position-picker__option--${position}`}
              type="button"
              role="radio"
              aria-checked={value === position}
              aria-disabled={Boolean(unavailableReason)}
              aria-describedby={unavailableReason ? `${id}-${position}-reason` : undefined}
              onClick={() => { if (!unavailableReason) onChange(position); }}
            >
              <span aria-hidden="true" />
              <small>{homeOverlayPositionLabels[position]}</small>
              {unavailableReason ? <span className="visually-hidden" id={`${id}-${position}-reason`}>{unavailableReason}</span> : null}
            </button>
          );
        })}
      </div>
      <p>Only positions occupied by the feature navigation or the other overlay are unavailable here. Home also checks the rendered elements before display.</p>
    </div>
  );
}

export function HomeCustomizationSettings({ profile, value, navigationSide, onChange }: HomeCustomizationSettingsProps) {
  const fields = eligibleFields(profile);
  const selectedFields = value.fanCard.fieldIds.map((fieldId) => fields.find((field) => field.id === fieldId)).filter((field): field is ProfileField => Boolean(field));
  const selectedFieldIds = selectedFields.map((field) => field.id);
  const selectedIds = new Set(selectedFields.map((field) => field.id));
  const updateText = (patch: Partial<HomeCustomization["textOverlay"]>) => onChange({
    ...value,
    textOverlay: { ...value.textOverlay, ...patch },
  });
  const updateFanCard = (patch: Partial<HomeCustomization["fanCard"]>) => onChange({
    ...value,
    fanCard: { ...value.fanCard, ...patch },
  });
  const toggleField = (fieldId: string) => {
    const next = selectedIds.has(fieldId)
      ? selectedFieldIds.filter((id) => id !== fieldId)
      : [...selectedFieldIds, fieldId].slice(0, 4);
    updateFanCard({ fieldIds: next });
  };
  const moveField = (fieldId: string, direction: -1 | 1) => {
    const next = [...selectedFieldIds];
    const currentIndex = next.indexOf(fieldId);
    const targetIndex = currentIndex + direction;
    if (currentIndex < 0 || targetIndex < 0 || targetIndex >= next.length) return;
    [next[currentIndex], next[targetIndex]] = [next[targetIndex]!, next[currentIndex]!];
    updateFanCard({ fieldIds: next });
  };

  return (
    <fieldset className="home-customization-settings">
      <legend>Home Customization</legend>
      <p className="profile-edit-dialog__note">Choose optional, responsive content for the Home image. Positioning stays constrained to eight safe anchors.</p>

      <section className="home-customization-panel" aria-labelledby="home-text-overlay-title">
        <header><div><h3 id="home-text-overlay-title">Text Overlay</h3><p>Customize the current Home message.</p></div><OverlayToggle id="home-text-overlay-enabled" label="Enable Text Overlay" checked={value.textOverlay.enabled} onChange={(enabled) => updateText({ enabled })} /></header>
        <div className="home-customization-copy-fields" aria-disabled={!value.textOverlay.enabled}>
          <label>Big text<span className="home-customization-input"><input aria-label="Big text" aria-describedby="home-big-text-count" maxLength={30} disabled={!value.textOverlay.enabled} value={value.textOverlay.bigText} onChange={(event) => updateText({ bigText: event.target.value })} /><small id="home-big-text-count" aria-live="polite">{value.textOverlay.bigText.length} / 30</small></span></label>
          <label>Small text<span className="home-customization-input"><textarea aria-label="Small text" aria-describedby="home-small-text-count" rows={2} maxLength={70} disabled={!value.textOverlay.enabled} value={value.textOverlay.smallText} onChange={(event) => updateText({ smallText: event.target.value })} /><small id="home-small-text-count" aria-live="polite">{value.textOverlay.smallText.length} / 70</small></span></label>
        </div>
        {value.textOverlay.enabled ? <PositionSelector id="home-text-position" label="Text position" value={value.textOverlay.position} navigationSide={navigationSide} {...(value.fanCard.enabled ? { occupiedPosition: value.fanCard.position } : {})} onChange={(position) => updateText({ position })} /> : null}
      </section>

      <section className="home-customization-panel" aria-labelledby="home-fan-card-title">
        <header><div><h3 id="home-fan-card-title">Fan Card</h3><p>Show up to four compact Profile details.</p></div><OverlayToggle id="home-fan-card-enabled" label="Enable Fan Card" checked={value.fanCard.enabled} onChange={(enabled) => updateFanCard({ enabled })} /></header>
        {value.fanCard.enabled ? <>
          <div className="home-fan-card-fields" aria-labelledby="home-fan-card-fields-title">
            <strong id="home-fan-card-fields-title">Profile fields</strong>
            <div>
              {fields.map((field) => {
                const order = selectedFieldIds.indexOf(field.id);
                const unavailable = order < 0 && selectedFieldIds.length >= 4;
                const fieldValue = field.value.trim() || "Empty on Profile";
                return <button key={field.id} type="button" aria-label={order >= 0 ? `${field.label}, selected ${order + 1} of 4, ${fieldValue}` : `Select ${field.label}, ${fieldValue}`} aria-pressed={order >= 0} disabled={unavailable} onClick={() => toggleField(field.id)}><span>{order >= 0 ? order + 1 : ""}</span><strong>{field.label}</strong><small>{fieldValue}</small></button>;
              })}
            </div>
            <p>{selectedFieldIds.length} of 4 selected. Empty values remain selectable but will not appear on Home.</p>
          </div>

          <div className="home-fan-card-order" aria-labelledby="home-fan-card-order-title">
            <strong id="home-fan-card-order-title">Selected field order</strong>
            {selectedFields.length ? <ol>{selectedFields.map((field, index) => <li key={field.id}><span>{index + 1}</span><div><strong>{field.label}</strong><small>{field.value.trim() || "Empty on Profile · hidden on Home"}</small></div><div><button type="button" aria-label={`Move ${field.label} up`} disabled={index === 0} onClick={() => moveField(field.id, -1)}><AppIcon name="arrow-up" /></button><button type="button" aria-label={`Move ${field.label} down`} disabled={index === selectedFields.length - 1} onClick={() => moveField(field.id, 1)}><AppIcon name="arrow-down" /></button><button type="button" aria-label={`Remove ${field.label} from Fan Card`} onClick={() => toggleField(field.id)}><AppIcon name="x-mark" /></button></div></li>)}</ol> : <p>No fields selected yet.</p>}
          </div>

          <div className="profile-featured-picker home-fan-card-layout" role="radiogroup" aria-labelledby="home-fan-card-layout-title">
            <strong id="home-fan-card-layout-title">Layout</strong>
            <div>{(["grid", "stack"] as const).map((layout) => <label key={layout}><input type="radio" name="homeFanCardLayout" value={layout} checked={value.fanCard.layout === layout} onChange={() => updateFanCard({ layout })} /><span>{layout === "grid" ? "Grid" : "Stack"}</span></label>)}</div>
          </div>
          <PositionSelector id="home-fan-card-position" label="Fan Card position" value={value.fanCard.position} navigationSide={navigationSide} {...(value.textOverlay.enabled ? { occupiedPosition: value.textOverlay.position } : {})} onChange={(position) => updateFanCard({ position })} />
        </> : null}
      </section>
    </fieldset>
  );
}
