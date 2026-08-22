import type { ProfileVisibility } from "./types";

export function ProfilePrivacySettings({
  value,
  disabled = false,
  onChange,
}: {
  readonly value: ProfileVisibility;
  readonly disabled?: boolean;
  readonly onChange: (visibility: ProfileVisibility) => void;
}) {
  return (
    <fieldset>
      <legend>Profile privacy</legend>
      <div className="profile-featured-picker profile-privacy-settings" role="radiogroup" aria-labelledby="profile-privacy-title">
        <strong id="profile-privacy-title">Who can view your Profile?</strong>
        <div>
          <label>
            <input type="radio" name="profileVisibility" value="public" checked={value === "public"} disabled={disabled} onChange={() => onChange("public")} />
            <span>Public profile</span>
          </label>
          <label>
            <input type="radio" name="profileVisibility" value="private" checked={value === "private"} disabled={disabled} onChange={() => onChange("private")} />
            <span>Private profile</span>
          </label>
        </div>
        <p><strong>Public:</strong> Others can view your Profile and its display media. <strong>Private:</strong> Only you can view your Profile for now.</p>
        {disabled ? <p>Sign in to save profile privacy to your FANatical account.</p> : null}
      </div>
    </fieldset>
  );
}
