import { useEffect, useState, type FormEvent } from "react";
import { AuthProvider, useAuth } from "../features/account/AuthContext";
import { supabase } from "../lib/supabase/client";
import { formatStaffRole, parseStaffAccess, type StaffAccess } from "./adminAccess";

type AccessState =
  | Readonly<{ status: "loading" }>
  | Readonly<{ status: "denied" }>
  | Readonly<{ status: "granted"; access: StaffAccess }>
  | Readonly<{ status: "error"; message: string }>;

const adminAreas = [
  ["Venue management", "Venue mappings, seating profiles, routing rules, exceptions, and seat-resolution testing."],
  ["Live operations", "Live Cheer event operations and proposal oversight."],
  ["Sports catalog", "Canonical sports, leagues, teams, and venue relationships."],
  ["Content review", "Quiz, Cheer, community, and moderation workflows."],
  ["Users and trophies", "Account support, staff-authorized user tools, and trophy administration."],
] as const;

function AdminSignIn() {
  const { configured, signIn } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      await signIn(email, password);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Sign in failed.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="admin-auth" id="main-content">
      <section className="admin-auth__panel" aria-labelledby="admin-sign-in-title">
        <p className="admin-kicker">Private operations</p>
        <h1 id="admin-sign-in-title">FANatical Admin</h1>
        <p>Sign in with an authorized FANatical staff account.</p>
        {!configured ? (
          <p className="admin-message admin-message--error" role="alert">
            Hosted Supabase environment variables are not configured for this deployment.
          </p>
        ) : (
          <form className="admin-form" onSubmit={(event) => void handleSubmit(event)}>
            <label>
              Email
              <input type="email" autoComplete="username" value={email} onChange={(event) => setEmail(event.target.value)} required />
            </label>
            <label>
              Password
              <input type="password" autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} required />
            </label>
            {error ? <p className="admin-message admin-message--error" role="alert">{error}</p> : null}
            <button className="admin-button" type="submit" disabled={submitting}>
              {submitting ? "Signing in…" : "Sign In"}
            </button>
          </form>
        )}
      </section>
    </main>
  );
}

function AdminGate() {
  const { loading: authLoading, user, signOut } = useAuth();
  const [accessState, setAccessState] = useState<AccessState>({ status: "loading" });

  useEffect(() => {
    if (authLoading) return;
    if (!user || !supabase) {
      setAccessState({ status: "denied" });
      return;
    }

    let current = true;
    setAccessState({ status: "loading" });
    void supabase
      .from("staff_roles")
      .select("user_id, role, permissions, is_active")
      .eq("user_id", user.id)
      .eq("is_active", true)
      .maybeSingle()
      .then(({ data, error }) => {
        if (!current) return;
        if (error) {
          setAccessState({ status: "error", message: "FANatical could not verify this account's staff access." });
          return;
        }
        const access = parseStaffAccess(data);
        setAccessState(access ? { status: "granted", access } : { status: "denied" });
      });

    return () => {
      current = false;
    };
  }, [authLoading, user]);

  if (authLoading || (user && accessState.status === "loading")) {
    return <main className="admin-status" id="main-content"><p>Verifying staff access…</p></main>;
  }

  if (!user) return <AdminSignIn />;

  if (accessState.status !== "granted") {
    return (
      <main className="admin-status" id="main-content">
        <section className="admin-auth__panel">
          <p className="admin-kicker">Access restricted</p>
          <h1>Staff authorization required</h1>
          <p>{accessState.status === "error" ? accessState.message : "This FANatical account does not have an active staff assignment."}</p>
          <p className="admin-account">Signed in as {user.email ?? "FANatical user"}</p>
          <button className="admin-button admin-button--secondary" type="button" onClick={() => void signOut()}>Sign Out</button>
        </section>
      </main>
    );
  }

  return (
    <div className="admin-shell">
      <header className="admin-header">
        <div>
          <p className="admin-kicker">Private operations</p>
          <h1>FANatical Admin</h1>
        </div>
        <div className="admin-header__account">
          <span>{formatStaffRole(accessState.access.role)} · {user.email ?? "FANatical user"}</span>
          <button className="admin-button admin-button--secondary" type="button" onClick={() => void signOut()}>Sign Out</button>
        </div>
      </header>
      <main className="admin-main" id="main-content">
        <section className="admin-intro">
          <p className="admin-kicker">Foundation active</p>
          <h2>Authorized operations workspace</h2>
          <p>Admin capabilities will be added here behind database-enforced role and permission checks.</p>
        </section>
        <section className="admin-grid" aria-label="Planned admin areas">
          {adminAreas.map(([title, description]) => (
            <article className="admin-card" key={title}>
              <h2>{title}</h2>
              <p>{description}</p>
              <span>Foundation only</span>
            </article>
          ))}
        </section>
      </main>
    </div>
  );
}

export function AdminApp() {
  return <AuthProvider><AdminGate /></AuthProvider>;
}
