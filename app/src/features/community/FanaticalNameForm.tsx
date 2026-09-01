import { useState, type FormEvent } from "react";
import { setMyFanaticalName } from "./communityRepository";

export function FanaticalNameForm({
  currentName = "",
  onSaved,
}: {
  readonly currentName?: string;
  readonly onSaved: (fanaticalName: string) => void | Promise<void>;
}) {
  const [value, setValue] = useState(currentName);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setBusy(true);
    setError("");
    try {
      await setMyFanaticalName(value);
      await onSaved(value.trim());
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Fanatical Name could not be saved.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <form className="fanatical-name-form" onSubmit={(event) => void submit(event)}>
      <label htmlFor="fanatical-name-input">Fanatical Name</label>
      <p>Your public Community identity. Use 3–20 letters, numbers, or underscores; it cannot begin or end with an underscore.</p>
      <div>
        <input
          id="fanatical-name-input"
          value={value}
          minLength={3}
          maxLength={20}
          pattern="[A-Za-z0-9][A-Za-z0-9_]{1,18}[A-Za-z0-9]"
          autoComplete="username"
          disabled={busy}
          required
          onChange={(event) => setValue(event.target.value)}
        />
        <button type="submit" disabled={busy}>{busy ? "Saving…" : currentName ? "Change name" : "Claim name"}</button>
      </div>
      {currentName ? <small>Changing your name releases {currentName} immediately. Your existing comments remain yours and show your new name.</small> : null}
      {error ? <p className="community-error" role="alert">{error}</p> : null}
    </form>
  );
}
