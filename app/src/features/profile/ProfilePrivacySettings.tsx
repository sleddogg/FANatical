import type { ProfilePersonalField, ProfileVisibility } from "./types";

const personalFields: readonly Readonly<{ id: ProfilePersonalField; label: string }>[] = [
  { id: "given_name", label: "Given name" },
  { id: "nickname", label: "Nickname" },
  { id: "birthplace", label: "Birthplace" },
  { id: "height", label: "Height" },
  { id: "weight", label: "Weight" },
  { id: "jersey_number", label: "Jersey number" },
];

export function ProfilePrivacySettings({
  value,
  disabled = false,
  personalFieldVisibility = {},
  onChange,
  onPersonalFieldChange,
}: {
  readonly value: ProfileVisibility;
  readonly disabled?: boolean;
  readonly personalFieldVisibility?: Readonly<Partial<Record<ProfilePersonalField, boolean>>>;
  readonly onChange: (visibility: ProfileVisibility) => void;
  readonly onPersonalFieldChange?: (field: ProfilePersonalField, visible: boolean) => void;
}) {
  return (
    <fieldset>
      <legend>Profile privacy</legend>
      <div className="profile-featured-picker profile-privacy-settings" role="radiogroup" aria-labelledby="profile-privacy-title">
        <strong id="profile-privacy-title">Who can view your Profile?</strong>
        <div>
          <label>
            <input type="radio" name="profileVisibility" value="members_visible" checked={value === "members_visible"} disabled={disabled} onChange={() => onChange("members_visible")} />
            <span>Members-visible</span>
          </label>
          <label>
            <input type="radio" name="profileVisibility" value="private" checked={value === "private"} disabled={disabled} onChange={() => onChange("private")} />
            <span>Private profile</span>
          </label>
        </div>
        <p><strong>Members-visible:</strong> Signed-in fans can view your approved Profile fields. <strong>Private:</strong> comments still show only your current Fanatical Name and display avatar.</p>
        <div className="profile-privacy-fields">
          <strong>Optional fields visible to members</strong>
          {personalFields.map((field) => (
            <label key={field.id}>
              <input type="checkbox" checked={personalFieldVisibility[field.id] === true} disabled={disabled} onChange={(event) => onPersonalFieldChange?.(field.id, event.target.checked)} />
              <span>{field.label}</span>
            </label>
          ))}
          <small>Email, phone, exact date of birth, account UUID, and security data are never included.</small>
        </div>
        {disabled ? <p>Sign in to save profile privacy to your FANatical account.</p> : null}
      </div>
    </fieldset>
  );
}
