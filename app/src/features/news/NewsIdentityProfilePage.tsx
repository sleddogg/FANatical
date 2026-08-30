import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { AppIcon } from "../../components/AppIcon";
import { useAuth } from "../account/AuthContext";
import { NewsCard } from "./NewsCard";
import { newsIdentityProfilePath } from "./newsPresentation";
import {
  followNewsTarget,
  loadMyNewsFollowing,
  loadNewsIdentityItems,
  loadNewsIdentityProfile,
  recordNewsOutboundOpen,
} from "./newsRepository";
import type {
  FanSafeNewsItem,
  NewsIdentityProfile,
  NewsIdentityTargetType,
} from "./types";
import "./news.css";

type NewsIdentityProfilePageProps = {
  readonly targetType: NewsIdentityTargetType;
};

function typeLabel(type: NewsIdentityTargetType) {
  if (type === "author") return "Author";
  if (type === "organization") return "Organizational contributor";
  return "Show";
}

export function NewsIdentityProfilePage({ targetType }: NewsIdentityProfilePageProps) {
  const { identityId = "" } = useParams();
  const { configured, loading: authLoading, user } = useAuth();
  const navigate = useNavigate();
  const [profile, setProfile] = useState<NewsIdentityProfile | null>(null);
  const [items, setItems] = useState<readonly FanSafeNewsItem[]>([]);
  const [following, setFollowing] = useState(false);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    let current = true;
    if (authLoading) return () => { current = false; };
    if (!configured) {
      return () => { current = false; };
    }
    const load = async () => {
      if (!current) return;
      setLoading(true);
      setError("");
      const [nextProfile, nextItems, nextFollowing] = await Promise.all([
        loadNewsIdentityProfile(targetType, identityId),
        loadNewsIdentityItems(targetType, identityId),
        user ? loadMyNewsFollowing() : Promise.resolve([]),
      ]);
      if (!current) return;
      if (nextProfile.targetType !== targetType || nextProfile.targetId !== identityId) {
        navigate(newsIdentityProfilePath(nextProfile.targetType, nextProfile.targetId), { replace: true });
        return;
      }
      setProfile(nextProfile);
      setItems(nextItems);
      setFollowing(nextFollowing.some((entry) => entry.targetType === nextProfile.targetType && entry.targetId === nextProfile.targetId));
      setLoading(false);
    };
    void Promise.resolve().then(load).catch((reason: unknown) => {
      if (!current) return;
      setLoading(false);
      setError(reason instanceof Error ? reason.message : "The contributor profile could not be loaded.");
    });
    return () => { current = false; };
  }, [authLoading, configured, identityId, navigate, targetType, user]);

  const addToFeed = async () => {
    if (!profile) return;
    setBusy(true);
    setMessage("");
    try {
      await followNewsTarget(profile);
      setFollowing(true);
      setMessage(`${profile.displayName} was added to your feed.`);
    } catch (reason) {
      setMessage(reason instanceof Error ? reason.message : "This identity could not be added to your feed.");
    } finally {
      setBusy(false);
    }
  };

  const outboundOpen = (item: FanSafeNewsItem) => {
    void recordNewsOutboundOpen(item.id, item.destinationUrl).catch((reason: unknown) => {
      console.warn("FANatical could not record a News outbound open.", reason);
    });
  };

  const share = async (item: FanSafeNewsItem) => {
    try {
      if (navigator.share) await navigator.share({ title: item.headline, url: item.destinationUrl });
      else if (navigator.clipboard) await navigator.clipboard.writeText(item.destinationUrl);
      setMessage("Publisher link shared.");
    } catch (reason) {
      if (reason instanceof DOMException && reason.name === "AbortError") return;
      setMessage("The publisher link could not be shared.");
    }
  };

  const visibleLoading = authLoading || (configured && loading);
  const visibleError = configured ? error : "News is unavailable because the FANatical data service is not configured.";

  return (
    <div className="news-profile-page">
      <Link className="news-profile-page__back" to="/news"><AppIcon name="arrow-left" /> Back to News</Link>
      {visibleLoading ? <p className="news-loading-state" role="status">Loading contributor profile…</p> : null}
      {visibleError ? <div className="news-empty-state surface" role="alert"><AppIcon name="exclamation-triangle" /><h1>Profile unavailable</h1><p>{visibleError}</p></div> : null}
      {profile && !visibleLoading && !visibleError ? (
        <>
          <header className="news-profile-header surface">
            <span className="news-profile-header__avatar" aria-hidden="true">{profile.displayName.slice(0, 2).toUpperCase()}</span>
            <div><span className="eyebrow">{typeLabel(profile.targetType)}</span><h1>{profile.displayName}</h1><p>Published News currently attributed to this identity.</p></div>
            {user ? (
              <button className="news-primary-button" type="button" disabled={following || busy} onClick={() => { void addToFeed(); }}>
                <AppIcon name={following ? "check" : "plus"} /> {following ? "Following" : busy ? "Adding…" : "Add to Feed"}
              </button>
            ) : <Link className="news-primary-link" to="/profile">Sign in to follow</Link>}
          </header>
          {message ? <p className="news-profile-message" role="status">{message}</p> : null}
          {items.length ? (
            <div className="news-feed" aria-label={`${profile.displayName} News Items`}>
              {items.map((item) => (
                <NewsCard key={item.id} item={item} onOutboundOpen={outboundOpen} onShare={(selected) => { void share(selected); }} />
              ))}
            </div>
          ) : (
            <div className="news-empty-state surface"><AppIcon name="information-circle" /><h2>No published Items</h2><p>No fan-safe published News Items are currently available for this profile.</p></div>
          )}
        </>
      ) : null}
    </div>
  );
}
