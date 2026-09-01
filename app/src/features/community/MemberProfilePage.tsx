import { useCallback, useEffect, useRef, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { AppIcon } from "../../components/AppIcon";
import { useAuth } from "../account/AuthContext";
import { CommunityAvatar } from "./CommunityAvatar";
import { loadMemberProfile } from "./communityRepository";
import type { MemberProfile } from "./types";
import "./community.css";

const personalLabels: Readonly<Record<string, string>> = {
  given_name: "Given name",
  nickname: "Nickname",
  birthplace: "Birthplace",
  height: "Height",
  weight: "Weight",
  jersey_number: "Jersey number",
};

function MemberProfileScreen() {
  const { fanaticalName = "" } = useParams();
  const { configured, loading: authLoading, user } = useAuth();
  const navigate = useNavigate();
  const [profile, setProfile] = useState<MemberProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const requestEpoch = useRef(0);

  const refresh = useCallback(async () => {
    if (authLoading) return;
    const epoch = ++requestEpoch.current;
    setError("");
    setProfile(null);
    if (!configured || !user) {
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      const next = await loadMemberProfile(fanaticalName);
      if (epoch === requestEpoch.current) setProfile(next);
    } catch (reason) {
      if (epoch === requestEpoch.current) {
        setError(reason instanceof Error ? reason.message : "Profile could not be loaded.");
      }
    } finally {
      if (epoch === requestEpoch.current) setLoading(false);
    }
  }, [authLoading, configured, fanaticalName, user]);

  useEffect(() => {
    void Promise.resolve().then(() => refresh());
    const handleFocus = () => { void refresh(); };
    const handleVisibility = () => { if (document.visibilityState === "visible") void refresh(); };
    window.addEventListener("focus", handleFocus);
    document.addEventListener("visibilitychange", handleVisibility);
    return () => {
      window.removeEventListener("focus", handleFocus);
      document.removeEventListener("visibilitychange", handleVisibility);
      requestEpoch.current += 1;
    };
  }, [refresh]);

  if (authLoading || loading) return <section className="member-profile-page" aria-busy="true"><p>Loading Profile…</p></section>;
  if (!user) return <section className="member-profile-page"><h1>Member Profile</h1><p>Profiles are available only to signed-in fans.</p><Link to="/profile">Sign in</Link></section>;
  if (error) return <section className="member-profile-page"><p className="community-error" role="alert">{error}</p></section>;
  if (!profile) return <section className="member-profile-page"><h1>Profile unavailable</h1><p>This current Fanatical Name is not viewable.</p></section>;

  return (
    <section className="member-profile-page">
      <header>
        <button type="button" aria-label="Back" onClick={() => navigate(-1)}><AppIcon name="arrow-left" /></button>
        <CommunityAvatar avatar={profile.avatar} fanaticalName={profile.fanaticalName} />
        <div><span className="eyebrow">Fan Profile</span><h1>{profile.fanaticalName}</h1>{profile.displayName ? <p>{profile.displayName}</p> : null}</div>
      </header>
      {profile.isPrivate ? <div className="member-profile-private surface"><AppIcon name="lock-closed" /><h2>Private Profile</h2><p>This fan shares only their current Fanatical Name and display avatar.</p></div> : (
        <div className="member-profile-details surface">
          {profile.tagline ? <p className="member-profile-tagline">{profile.tagline}</p> : null}
          {Object.keys(profile.personalFields).length ? <dl>{Object.entries(profile.personalFields).map(([key, value]) => <div key={key}><dt>{personalLabels[key] ?? key}</dt><dd>{value}</dd></div>)}</dl> : <p>No optional personal fields are shared.</p>}
        </div>
      )}
    </section>
  );
}

export function MemberProfilePage() {
  const { fanaticalName = "" } = useParams();
  const { user } = useAuth();
  return <MemberProfileScreen key={`${user?.id ?? "signed-out"}:${fanaticalName}`} />;
}
