import { useCallback, useEffect, useState } from "react";
import { hideCommunityFan, loadMyHiddenFans, unhideCommunityIntent } from "./communityRepository";
import type { HiddenFan } from "./types";

export function HiddenFansSettings({ disabled = false }: { readonly disabled?: boolean }) {
  const [fans, setFans] = useState<readonly HiddenFan[]>([]);
  const [loading, setLoading] = useState(!disabled);
  const [busy, setBusy] = useState("");
  const [error, setError] = useState("");
  const [fanaticalName, setFanaticalName] = useState("");

  const load = useCallback(async () => {
    if (disabled) return;
    setLoading(true);
    setError("");
    try {
      setFans(await loadMyHiddenFans());
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Hidden fans could not be loaded.");
    } finally {
      setLoading(false);
    }
  }, [disabled]);

  useEffect(() => { void load(); }, [load]);

  const hideFan = async () => {
    const currentName = fanaticalName.trim();
    if (!currentName) return;
    setBusy("hide");
    setError("");
    try {
      await hideCommunityFan(currentName);
      setFanaticalName("");
      await load();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Fan could not be hidden.");
    } finally {
      setBusy("");
    }
  };

  return (
    <fieldset className="hidden-fans-settings">
      <legend>Hidden fans</legend>
      <p>Hiding is reciprocal while either fan keeps their own Hide intent. You can remove only your own intent.</p>
      {disabled ? <p>Sign in to manage Hidden fans.</p> : null}
      {!disabled ? (
        <div className="hidden-fans-settings__hide">
          <label htmlFor="hidden-fan-name">Hide by current Fanatical Name</label>
          <div>
            <input
              id="hidden-fan-name"
              type="text"
              minLength={3}
              maxLength={20}
              pattern="[A-Za-z0-9][A-Za-z0-9_]{1,18}[A-Za-z0-9]"
              autoComplete="off"
              value={fanaticalName}
              disabled={Boolean(busy)}
              onChange={(event) => setFanaticalName(event.target.value)}
              onKeyDown={(event) => {
                if (event.key !== "Enter") return;
                event.preventDefault();
                void hideFan();
              }}
            />
            <button type="button" disabled={Boolean(busy) || !fanaticalName.trim()} onClick={() => void hideFan()}>{busy === "hide" ? "Hiding…" : "Hide"}</button>
          </div>
          <small>The current owner is resolved when you submit. A later fan who reclaims a released name does not inherit this Hide.</small>
        </div>
      ) : null}
      {loading ? <p role="status">Loading Hidden fans…</p> : null}
      {error ? <p role="alert">{error}</p> : null}
      {!disabled && !loading && !error && !fans.length ? <p>You have not hidden anyone.</p> : null}
      {fans.length ? <ul>{fans.map((fan) => (
        <li key={fan.hideIntentId}>
          <span><strong>{fan.fanaticalName ?? "Fanatical Name no longer claimed"}</strong><small>{fan.alsoHidesYou ? "They also have their own Hide intent." : "Your Hide intent keeps both accounts separated."}</small></span>
          <button type="button" disabled={Boolean(busy)} onClick={() => {
            setBusy(fan.hideIntentId);
            setError("");
            void unhideCommunityIntent(fan.hideIntentId).then(load).catch((reason: unknown) => setError(reason instanceof Error ? reason.message : "Fan could not be unhidden.")).finally(() => setBusy(""));
          }}>{busy === fan.hideIntentId ? "Unhiding…" : "Unhide"}</button>
        </li>
      ))}</ul> : null}
    </fieldset>
  );
}
