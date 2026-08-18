import { useEffect, useRef, useState, type FormEvent } from "react";
import { useAuth } from "./AuthContext";
import { AppIcon } from "../../components/AppIcon";

type AccountDialogMode = "sign-in" | "create";

export function AccountDialog({ onClose, initialMode = "sign-in" }: { readonly onClose: () => void; readonly initialMode?: AccountDialogMode }) {
  const { signIn, signUp } = useAuth();
  const [mode, setMode] = useState<AccountDialogMode>(initialMode);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const closeRef = useRef<HTMLButtonElement>(null);
  const dialogRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const returnFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    closeRef.current?.focus();
    return () => returnFocus?.focus();
  }, []);
  useEffect(() => {
    const handleKeys = (event: KeyboardEvent) => {
      if (event.key === "Escape" && !busy) onClose();
      if (event.key !== "Tab") return;
      const focusable = [...(dialogRef.current?.querySelectorAll<HTMLElement>('button:not([disabled]), input:not([disabled]), [href], [tabindex]:not([tabindex="-1"])') ?? [])];
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (!first || !last) return;
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    };
    window.addEventListener("keydown", handleKeys);
    return () => window.removeEventListener("keydown", handleKeys);
  }, [busy, onClose]);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setBusy(true);
    setError("");
    setMessage("");
    try {
      if (mode === "sign-in") {
        await signIn(email, password);
        onClose();
      } else {
        const result = await signUp({ email, password, displayName });
        if (result === "signed-in") onClose();
        else setMessage("Check your email to confirm your FANatical account, then sign in on this device.");
      }
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "The account request could not be completed.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="account-dialog-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget && !busy) onClose(); }}>
      <section ref={dialogRef} className="account-dialog" role="dialog" aria-modal="true" aria-labelledby="account-dialog-title">
        <header><div><span className="eyebrow">FANatical account</span><h2 id="account-dialog-title">{mode === "sign-in" ? "Sign In" : "Create Account"}</h2></div><button ref={closeRef} type="button" aria-label="Close account dialog" disabled={busy} onClick={onClose}><AppIcon name="x-mark" /></button></header>
        <div className="account-dialog__modes" role="tablist" aria-label="Account action">
          <button type="button" role="tab" aria-selected={mode === "sign-in"} onClick={() => { setMode("sign-in"); setError(""); setMessage(""); }}>Sign In</button>
          <button type="button" role="tab" aria-selected={mode === "create"} onClick={() => { setMode("create"); setError(""); setMessage(""); }}>Create Account</button>
        </div>
        <form onSubmit={(event) => void submit(event)}>
          {mode === "create" ? <label>Display name<input autoComplete="name" value={displayName} required onChange={(event) => setDisplayName(event.target.value)} /></label> : null}
          <label>Email<input type="email" inputMode="email" autoComplete="email" value={email} required onChange={(event) => setEmail(event.target.value)} /></label>
          <label>Password<input type="password" autoComplete={mode === "sign-in" ? "current-password" : "new-password"} minLength={8} value={password} required onChange={(event) => setPassword(event.target.value)} /></label>
          {error ? <p className="account-dialog__error" role="alert">{error}</p> : null}
          {message ? <p className="account-dialog__message" role="status">{message}</p> : null}
          <button className="account-dialog__submit" type="submit" disabled={busy}>{busy ? "Working…" : mode === "sign-in" ? "Sign In" : "Create Account"}</button>
        </form>
        <p className="account-dialog__device-note">Signing in here does not sign you out on your other FANatical devices.</p>
      </section>
    </div>
  );
}
