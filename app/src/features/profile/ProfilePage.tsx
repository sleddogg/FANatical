import { useEffect, useMemo, useState, type ReactNode } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { StatDashboard } from "../../components/StatDashboard";
import { AppIcon } from "../../components/AppIcon";
import { TeamBadge } from "../../components/TeamBadge";
import { useTeamContext } from "../../state/TeamContext";
import { FanbaseCreateDialog } from "../fanbase/FanbaseCreateDialog";
import { FanPhotoCategoryHub, FanPhotoViewer } from "../fanbase/FanPhotosArea";
import { useFanbaseContext } from "../fanbase/FanbaseContext";
import { formatRating } from "../fanbase/fanbaseFormatting";
import { demoUser } from "../fanbase/mockFanbaseData";
import type { FanPhoto, FanPhotoCategory } from "../fanbase/types";
import { initialProfile, profileMoments, profileStats, profileTrophies } from "./mockProfileData";
import { MomentCreateDialog } from "./MomentCreateDialog";
import { ProfileEditDialog } from "./ProfileEditDialog";
import { ProfileAddTeamDialog } from "./ProfileAddTeamDialog";
import type { FollowedTeam } from "../../domain/team";
import type { OfficialTeamId } from "../../data/officialSportsDatabase";
import type { CreateFanMomentInput, FanMoment, ProfileRecord, ProfileTabId } from "./types";
import { buildSportsStatsSnapshot, fanScoreForUser, resolveFanbaseCompetition, sportsStatsUser } from "../stats/sportsStats";
import { AccountDialog } from "../account/AccountDialog";
import { useAuth } from "../account/AuthContext";
import { accountClientStateClearedEvent, profileFeaturedCategorySessionKey } from "../account/accountClientState";
import { useAccountBootstrap } from "../account/AccountBootstrap";
import { loadOwnedProfile, saveOwnedProfile, subscribeToAccountChanges } from "../account/accountRepository";
import "../fanbase/fanbase.css";
import "./profile.css";

const photoCategories = ["Game Face", "Fan Cave", "Memorabilia"] as const satisfies readonly FanPhotoCategory[];

const profileTabs: readonly { id: ProfileTabId; label: string }[] = [
  { id: "bio", label: "Bio" },
  { id: "fan-identity", label: "Fan Identity" },
  { id: "sports-played", label: "Sports Played" },
  { id: "trophy-case", label: "Trophy Case" },
  { id: "moments", label: "Moments" },
];

type PhotoOrder = Record<FanPhotoCategory, string[]>;
let localMomentSequence = 0;

const profileStatIcons: Readonly<Record<(typeof profileStats)[number]["label"], ReactNode>> = {
  Streak: <AppIcon name="fire" />,
  Tier: <AppIcon name="trophy" />,
  "Fan Score": <AppIcon name="star" />,
  "Fan Coins": "●",
  Rank: <AppIcon name="chart-bar" />,
  "Sport IQ": <AppIcon name="chart-bar" />,
};

function formatMomentDate(value: string) {
  return new Intl.DateTimeFormat(undefined, { year: "numeric", month: "long", day: "numeric" }).format(new Date(`${value}T12:00:00`));
}

function initialSessionProfile(): ProfileRecord {
  if (typeof window === "undefined") return initialProfile;
  const storedCategory = window.sessionStorage.getItem(profileFeaturedCategorySessionKey);
  return photoCategories.includes(storedCategory as FanPhotoCategory)
    ? { ...initialProfile, featuredFanPhotoCategory: storedCategory as FanPhotoCategory }
    : initialProfile;
}

function buildInitialPhotoOrder(photos: readonly FanPhoto[]): PhotoOrder {
  return {
    "Game Face": photos.filter((photo) => photo.category === "Game Face").map((photo) => photo.id),
    "Fan Cave": photos.filter((photo) => photo.category === "Fan Cave").map((photo) => photo.id),
    Memorabilia: photos.filter((photo) => photo.category === "Memorabilia").map((photo) => photo.id),
  };
}

function ProfilePhotoShowcase({
  photos,
  featuredCategory,
  onOpenCategory,
}: {
  readonly photos: readonly FanPhoto[];
  readonly featuredCategory: FanPhotoCategory;
  readonly onOpenCategory: (category: FanPhotoCategory) => void;
}) {
  return (
    <section className="profile-fanfotos" aria-label="Profile FANfoto categories">
      <FanPhotoCategoryHub
        key={featuredCategory}
        photos={photos}
        initialCategory={featuredCategory}
        introduction=""
        centerInitialCategory
        minimal
        onOpenCategory={onOpenCategory}
      />
    </section>
  );
}

function ProfilePhotoCategoryScreen({
  category,
  photos,
  onBack,
  onAddPhoto,
  onOpenPhoto,
  onMovePhoto,
}: {
  readonly category: FanPhotoCategory;
  readonly photos: readonly FanPhoto[];
  readonly onBack: () => void;
  readonly onAddPhoto: () => void;
  readonly onOpenPhoto: (photo: FanPhoto) => void;
  readonly onMovePhoto: (category: FanPhotoCategory, photoId: string, direction: -1 | 1) => void;
}) {
  return (
    <div className="profile-page profile-page--photo-category">
      <header className="profile-topbar">
        <button className="profile-back-button" type="button" aria-label="Back to Profile" onClick={onBack}><AppIcon name="arrow-left" /><span>Back to Profile</span></button>
        <div><span className="eyebrow">Profile FANfotos</span><h1>{category}</h1><p>Owner-curated display order</p></div>
        <button className="profile-edit-button" type="button" aria-label={`Add ${category} FANfoto`} onClick={onAddPhoto}><AppIcon name="plus" /><span>Add FANfoto</span></button>
      </header>
      <section className="fan-photo-rankings profile-photo-order" aria-labelledby="profile-photo-order-title">
        <header className="fan-photo-rankings__intro">
          <div><h2 id="profile-photo-order-title">Profile display order</h2><p>Use the arrows to arrange this category. Position #1 automatically becomes its carousel cover.</p></div>
          <span>{photos.length}</span>
        </header>
        {photos.length ? (
          <div className="fan-photo-ranking-viewport">
            <table className="fan-photo-ranking-table profile-photo-order-table">
              <thead><tr><th className="fan-photo-ranking-table__rated" scope="col">Order</th><th className="fan-photo-ranking-table__identity" scope="col">FANfoto</th><th scope="col">Recognition</th><th scope="col">Move</th></tr></thead>
              <tbody>
                {photos.map((photo, index) => (
                  <tr key={photo.id} data-fan-photo-id={photo.id}>
                    <td className="fan-photo-ranking-table__rated"><strong>#{index + 1}</strong>{index === 0 ? <small>Cover</small> : null}</td>
                    <td className="fan-photo-ranking-table__identity">
                      <button type="button" aria-label={`Open ${photo.title}`} onClick={() => onOpenPhoto(photo)}>
                        <img src={photo.images[0]?.url} alt="" />
                        <span><strong>{photo.title}</strong><small>@{photo.owner.username}{photo.images.length > 1 ? ` · ${photo.images.length} images` : ""}</small><small><AppIcon name="star-solid" /> {formatRating(photo.ratingTotal, photo.ratingCount)} · {photo.ratingCount} ratings</small></span>
                      </button>
                    </td>
                    <td className="profile-photo-order-table__recognition">{photo.rankingBadge ? <span>{photo.rankingBadge}</span> : <small>Not ranked</small>}</td>
                    <td className="profile-photo-order-table__move"><div><button type="button" aria-label={`Move ${photo.title} up`} disabled={index === 0} onClick={() => onMovePhoto(category, photo.id, -1)}><AppIcon name="arrow-up" /></button><button type="button" aria-label={`Move ${photo.title} down`} disabled={index === photos.length - 1} onClick={() => onMovePhoto(category, photo.id, 1)}><AppIcon name="arrow-down" /></button></div></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : <p className="fan-photo-shelf__empty">No {category} FANfotos have been added to this Profile yet.</p>}
      </section>
    </div>
  );
}

function MomentDetailScreen({ moment, photo, onBack, onOpenPhoto }: { readonly moment: FanMoment; readonly photo?: FanPhoto; readonly onBack: () => void; readonly onOpenPhoto: (photo: FanPhoto) => void }) {
  return (
    <div className="profile-page profile-page--moment-detail">
      <header className="profile-topbar">
        <button className="profile-back-button" type="button" aria-label="Back to Moments" onClick={onBack}><AppIcon name="arrow-left" /><span>Back to Moments</span></button>
        <div><span className="eyebrow">Moment</span><h1>{moment.title}</h1><p>{moment.type} · {formatMomentDate(moment.dateOccurred)}</p></div>
        <span />
      </header>
      <article className="profile-moment-detail">
        <header><span className="profile-moment-detail__type">{moment.type}</span><h2>{moment.title}</h2><time dateTime={moment.dateOccurred}>{formatMomentDate(moment.dateOccurred)}</time></header>
        <p className="profile-moment-detail__story">{moment.story}</p>
        {moment.location || moment.eventContext ? <dl>{moment.location ? <div><dt>Location</dt><dd>{moment.location}</dd></div> : null}{moment.eventContext ? <div><dt>Event context</dt><dd>{moment.eventContext}</dd></div> : null}</dl> : null}
        {photo ? <section className="profile-moment-detail__photo"><div><span className="eyebrow">Connected FANfoto</span><h3>{photo.title}</h3><p>{photo.category} · {photo.images.length > 1 ? `${photo.images.length} images` : "1 image"}</p></div><button type="button" aria-label={`Open connected FANfoto: ${photo.title}`} onClick={() => onOpenPhoto(photo)}><img src={photo.images[0]?.url} alt={photo.images[0]?.alt ?? ""} /><span>View FANfoto <AppIcon name="arrow-right" /></span></button></section> : null}
      </article>
    </div>
  );
}

function ProfileTabContent({ tab, profile, photos, moments, followedTeams, onOpenPhoto, onOpenMoment, onAddMoment, onAddTeam }: { readonly tab: ProfileTabId; readonly profile: ProfileRecord; readonly photos: readonly FanPhoto[]; readonly moments: readonly FanMoment[]; readonly followedTeams: readonly FollowedTeam[]; readonly onOpenPhoto: (photo: FanPhoto) => void; readonly onOpenMoment: (momentId: string) => void; readonly onAddMoment: () => void; readonly onAddTeam: () => void }) {
  if (tab === "bio") {
    const fields = profile.bio.filter((field) => field.value.trim());
    return <section className="profile-details" aria-labelledby="profile-bio-title"><header><span className="eyebrow">The person behind the fandom</span><h2 id="profile-bio-title">Bio</h2></header><dl>{fields.map((field) => <div key={field.id}><dt>{field.label}</dt><dd>{field.value}</dd></div>)}</dl></section>;
  }

  if (tab === "fan-identity") {
    const fields = profile.fanIdentity.filter((field) => field.value.trim() && field.id !== "primary-team" && field.id !== "secondary-teams");
    return <section className="profile-details profile-details--fan-identity" aria-labelledby="profile-fan-identity-title"><header className="profile-fan-identity-heading"><div><span className="eyebrow">Teams, traditions, and loyalties</span><h2 id="profile-fan-identity-title">Fan Identity</h2></div><button type="button" onClick={onAddTeam}><AppIcon name="plus" /> Add Team</button></header><div className="profile-followed-teams" aria-label="Profile followed teams">{followedTeams.map((team, index) => <article key={team.id}><TeamBadge team={team} /><div><strong>{team.name}</strong><small>{team.league} · {team.sport}</small></div>{index === 0 ? <span>Primary</span> : null}</article>)}</div><dl>{fields.map((field) => <div key={field.id}><dt>{field.label}</dt><dd>{field.value}</dd></div>)}</dl></section>;
  }

  if (tab === "sports-played") {
    return <section className="profile-details" aria-labelledby="profile-sports-title"><header><span className="eyebrow">Experience on the field</span><h2 id="profile-sports-title">Sports Played</h2></header><div className="profile-sports-grid">{profile.sportsPlayed.filter((sport) => sport.sport.trim()).map((sport) => { const context = [sport.position, sport.level].filter((value) => value.trim()).join(" · "); return <article key={sport.id}><div className="profile-sport-mark" aria-hidden="true">{sport.sport.slice(0, 1)}</div><div><h3>{sport.sport}</h3>{context ? <p>{context}</p> : null}{sport.years.trim() || sport.highlight.trim() ? <dl>{sport.years.trim() ? <div><dt>Years</dt><dd>{sport.years}</dd></div> : null}{sport.highlight.trim() ? <div><dt>Highlight</dt><dd>{sport.highlight}</dd></div> : null}</dl> : null}</div></article>; })}</div></section>;
  }

  if (tab === "trophy-case") {
    return <section className="profile-details" aria-labelledby="profile-trophies-title"><header><span className="eyebrow">Earned, pursued, remembered</span><h2 id="profile-trophies-title">Trophy Case</h2></header><div className="profile-trophy-grid">{profileTrophies.map((trophy) => <article className={`profile-trophy profile-trophy--${trophy.status}`} key={trophy.id}><div className="profile-trophy__icon" aria-hidden="true">{trophy.icon}</div><div><span>{trophy.status === "earned" ? "Earned" : trophy.status === "locked" ? "Locked" : "In progress"}</span><h3>{trophy.name}</h3><p>{trophy.description}</p>{trophy.earnedAt ? <small>Earned {trophy.earnedAt}</small> : null}{trophy.progress !== undefined ? <div className="profile-trophy__progress"><span style={{ width: `${trophy.progress}%` }} /><small>{trophy.progress}%</small></div> : null}</div></article>)}</div></section>;
  }

  const photoById = new Map(photos.map((photo) => [photo.id, photo]));
  return <section className="profile-details profile-details--moments" aria-labelledby="profile-moments-title"><header className="profile-moments-header"><h2 id="profile-moments-title">Moments <span>· The stories behind the score</span></h2><button type="button" onClick={onAddMoment}><AppIcon name="plus" /> Add Moment</button></header><div className="profile-moment-list">{moments.map((moment) => { const photo = moment.fanPhotoId ? photoById.get(moment.fanPhotoId) : undefined; return <article className="profile-moment-card" key={moment.id}>{photo ? <button className="profile-moment-card__thumbnail" type="button" aria-label={`Open connected FANfoto: ${photo.title}`} onClick={() => onOpenPhoto(photo)}><img src={photo.images[0]?.url} alt={photo.images[0]?.alt ?? ""} /></button> : <div className="profile-moment-card__thumbnail profile-moment-card__thumbnail--empty" aria-hidden="true">F</div>}<button className="profile-moment-card__story" type="button" aria-label={`Open Moment: ${moment.title}`} onClick={() => onOpenMoment(moment.id)}><span>{moment.type}</span><h3>{moment.title}</h3><time dateTime={moment.dateOccurred}>{formatMomentDate(moment.dateOccurred)}</time><p>{moment.story}</p>{moment.location || moment.eventContext ? <small>{[moment.location, moment.eventContext].filter(Boolean).join(" · ")}</small> : null}</button></article>; })}</div></section>;
}

export function ProfilePage() {
  const { configured, loading: authLoading, user, signOut } = useAuth();
  const prototypeMode = import.meta.env.DEV && !configured;
  const { ready, revision } = useAccountBootstrap();
  const navigate = useNavigate();
  const location = useLocation();
  const fanbase = useFanbaseContext();
  const { selectedTeam, followedTeams, addFollowedTeam } = useTeamContext();
  const { fanPhotos } = fanbase;
  const sportsStats = useMemo(() => sportsStatsUser(demoUser.id, buildSportsStatsSnapshot()), []);
  const selectedCompetition = resolveFanbaseCompetition(selectedTeam);
  const selectedFanScore = sportsStats ? fanScoreForUser(sportsStats, selectedCompetition.teamKey) : null;
  const displayProfileStats = profileStats.map((stat) => stat.label === "Fan Score"
    ? { ...stat, value: selectedFanScore?.toLocaleString() ?? "—", detail: `${selectedTeam.shortName} Fan Score` }
    : stat.label === "Sport IQ"
      ? { ...stat, value: sportsStats?.overallSportIq?.toString() ?? "—", detail: "Overall Sport IQ" }
      : stat);
  const [storedProfile, setProfile] = useState<ProfileRecord | null>(() => prototypeMode ? initialSessionProfile() : null);
  const [loadedUserId, setLoadedUserId] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<ProfileTabId>("bio");
  const [editing, setEditing] = useState(false);
  const [openPhoto, setOpenPhoto] = useState<FanPhoto | null>(null);
  const [openPhotoCategory, setOpenPhotoCategory] = useState<FanPhotoCategory | null>(null);
  const [createPhotoOpen, setCreatePhotoOpen] = useState(false);
  const [moments, setMoments] = useState<readonly FanMoment[]>(() => [...profileMoments]);
  const [openMomentId, setOpenMomentId] = useState<string | null>(null);
  const [momentCreateOpen, setMomentCreateOpen] = useState(false);
  const [addTeamOpen, setAddTeamOpen] = useState(false);
  const [accountDialogMode, setAccountDialogMode] = useState<"sign-in" | "create" | null>(null);
  const [accountActionBusy, setAccountActionBusy] = useState(false);
  const [accountActionError, setAccountActionError] = useState("");
  const [profileError, setProfileError] = useState("");
  const isOwner = !configured || Boolean(user);
  const ownerPhotos = useMemo(() => fanPhotos.filter((photo) => photo.owner.id === demoUser.id), [fanPhotos]);
  const [photoOrder, setPhotoOrder] = useState<PhotoOrder>(() => buildInitialPhotoOrder(ownerPhotos));

  useEffect(() => {
    if (prototypeMode && storedProfile) window.sessionStorage.setItem(profileFeaturedCategorySessionKey, storedProfile.featuredFanPhotoCategory);
  }, [prototypeMode, storedProfile]);

  useEffect(() => {
    setPhotoOrder((current) => {
      const next = { ...current };
      for (const category of photoCategories) {
        const availableIds = ownerPhotos.filter((photo) => photo.category === category).map((photo) => photo.id);
        next[category] = [...current[category].filter((id) => availableIds.includes(id)), ...availableIds.filter((id) => !current[category].includes(id))];
      }
      return next;
    });
  }, [ownerPhotos]);

  useEffect(() => {
    if (!configured || !user) return;
    if (!ready) return;
    let current = true;
    const load = () => loadOwnedProfile(user.id).then((record) => {
      if (!current || !record) return;
      setProfile(record);
      setLoadedUserId(user.id);
      setProfileError("");
    }).catch((reason: unknown) => {
      if (current) setProfileError(reason instanceof Error ? reason.message : "Profile could not be refreshed.");
    });
    void load();
    const refreshOnFocus = () => { void load(); };
    const refreshOnVisibility = () => { if (document.visibilityState === "visible") void load(); };
    window.addEventListener("focus", refreshOnFocus);
    document.addEventListener("visibilitychange", refreshOnVisibility);
    const unsubscribe = subscribeToAccountChanges(user.id, refreshOnFocus, ["profiles", "fan_identities", "sports_played"]);
    return () => {
      current = false;
      window.removeEventListener("focus", refreshOnFocus);
      document.removeEventListener("visibilitychange", refreshOnVisibility);
      unsubscribe();
    };
  }, [configured, ready, revision, user]);

  useEffect(() => {
    const clear = () => {
      setProfile(prototypeMode ? initialSessionProfile() : null);
      setLoadedUserId(null);
      setEditing(false);
      setOpenPhoto(null);
      setOpenPhotoCategory(null);
      setCreatePhotoOpen(false);
      setOpenMomentId(null);
      setMomentCreateOpen(false);
      setAddTeamOpen(false);
    };
    window.addEventListener(accountClientStateClearedEvent, clear);
    return () => window.removeEventListener(accountClientStateClearedEvent, clear);
  }, [prototypeMode]);

  const profile = configured
    ? !authLoading && user && ready && loadedUserId === user.id ? storedProfile : null
    : prototypeMode ? storedProfile ?? initialProfile : null;

  const photoById = useMemo(() => new Map(ownerPhotos.map((photo) => [photo.id, photo])), [ownerPhotos]);
  const orderedOwnerPhotos = useMemo(() => photoCategories.flatMap((category) => photoOrder[category].map((id) => photoById.get(id)).filter((photo): photo is FanPhoto => Boolean(photo))), [photoById, photoOrder]);
  const openCategoryPhotos = openPhotoCategory ? orderedOwnerPhotos.filter((photo) => photo.category === openPhotoCategory) : [];
  const sortedMoments = useMemo(() => [...moments].sort((first, second) => Date.parse(second.dateOccurred) - Date.parse(first.dateOccurred)), [moments]);
  const openMoment = openMomentId ? moments.find((moment) => moment.id === openMomentId) : undefined;
  const openMomentPhoto = openMoment?.fanPhotoId ? photoById.get(openMoment.fanPhotoId) : undefined;

  const goBack = () => location.key === "default" ? navigate("/") : navigate(-1);
  const movePhoto = (category: FanPhotoCategory, photoId: string, direction: -1 | 1) => {
    setPhotoOrder((current) => {
      const order = [...current[category]];
      const currentIndex = order.indexOf(photoId);
      const targetIndex = currentIndex + direction;
      if (currentIndex < 0 || targetIndex < 0 || targetIndex >= order.length) return current;
      const targetPhotoId = order[targetIndex];
      if (!targetPhotoId) return current;
      order[targetIndex] = photoId;
      order[currentIndex] = targetPhotoId;
      return { ...current, [category]: order };
    });
  };

  const createMoment = (input: CreateFanMomentInput) => {
    localMomentSequence += 1;
    const moment: FanMoment = {
      id: `profile-moment-local-${localMomentSequence}`,
      title: input.title.trim(),
      type: input.type.trim(),
      dateOccurred: input.dateOccurred,
      createdAt: new Date().toISOString(),
      story: input.story.trim(),
      ...(input.location ? { location: input.location.trim() } : {}),
      ...(input.eventContext ? { eventContext: input.eventContext.trim() } : {}),
      ...(input.fanPhotoId ? { fanPhotoId: input.fanPhotoId } : {}),
    };
    setMoments((current) => [...current, moment]);
    setMomentCreateOpen(false);
  };

  const addTeam = async (teamId: OfficialTeamId) => {
    if (await addFollowedTeam(teamId) === "added") setAddTeamOpen(false);
  };

  const saveProfile = async (nextProfile: ProfileRecord) => {
    const ownedProfile = user ? { ...nextProfile, id: user.id } : nextProfile;
    if (configured && user) {
      await saveOwnedProfile(user.id, ownedProfile, storedProfile?.visibility ?? initialProfile.visibility);
    }
    setProfile(ownedProfile);
  };

  const signOutHere = async () => {
    setAccountActionBusy(true);
    setAccountActionError("");
    try {
      await signOut();
      setEditing(false);
      navigate("/", { replace: true });
    } catch (reason) {
      setAccountActionError(reason instanceof Error ? reason.message : "This device could not be signed out.");
    } finally {
      setAccountActionBusy(false);
    }
  };

  if (configured && authLoading) {
    return <div className="profile-page profile-page--auth-neutral" aria-busy="true" />;
  }

  if (!configured && !prototypeMode) {
    return <div className="profile-page profile-page--auth-neutral" />;
  }

  if (configured && !user) {
    return (
      <div className="profile-page profile-page--signed-out">
        <div className="profile-account-panel__actions">
          <button type="button" onClick={() => setAccountDialogMode("sign-in")}>Sign In</button>
          <button type="button" onClick={() => setAccountDialogMode("create")}>Create Account</button>
        </div>
        {accountDialogMode ? <AccountDialog initialMode={accountDialogMode} onClose={() => setAccountDialogMode(null)} /> : null}
      </div>
    );
  }

  if (!profile) {
    return <div className="profile-page profile-page--auth-neutral" aria-busy="true" />;
  }

  if (openMoment) {
    return (
      <>
        <MomentDetailScreen moment={openMoment} {...(openMomentPhoto ? { photo: openMomentPhoto } : {})} onBack={() => setOpenMomentId(null)} onOpenPhoto={setOpenPhoto} />
        {openPhoto ? <FanPhotoViewer photo={openPhoto} openedFromRatingQueue={false} onClose={() => setOpenPhoto(null)} /> : null}
      </>
    );
  }

  if (openPhotoCategory) {
    return (
      <>
        <ProfilePhotoCategoryScreen category={openPhotoCategory} photos={openCategoryPhotos} onBack={() => setOpenPhotoCategory(null)} onAddPhoto={() => setCreatePhotoOpen(true)} onOpenPhoto={setOpenPhoto} onMovePhoto={movePhoto} />
        {createPhotoOpen ? <FanbaseCreateDialog team={selectedTeam} initialCreationType="photo" initialPhotoCategory={openPhotoCategory} onCreateLocker={fanbase.createLockerRoomThread} onCreatePhoto={fanbase.createFanPhoto} onCreateEvent={fanbase.createEvent} onCreateGroup={fanbase.createGroup} onCreated={() => setCreatePhotoOpen(false)} onClose={() => setCreatePhotoOpen(false)} /> : null}
        {openPhoto ? <FanPhotoViewer photo={openPhoto} openedFromRatingQueue={false} onClose={() => setOpenPhoto(null)} /> : null}
      </>
    );
  }

  return (
    <div className="profile-page">
      <header className="profile-topbar">
        <button className="profile-back-button" type="button" onClick={goBack}><AppIcon name="arrow-left" /><span>Back</span></button>
        <div><span className="eyebrow">Profile</span><h1>{profile.displayName}</h1><p>{profile.tagline}</p></div>
        {authLoading ? <span aria-hidden="true" /> : isOwner ? <button className="profile-edit-button" type="button" onClick={() => setEditing(true)} aria-label="Edit profile"><AppIcon name="pencil-square" /><span>Edit</span></button> : <button className="profile-edit-button" type="button" onClick={() => setAccountDialogMode("sign-in")} aria-label="Sign in to FANatical"><AppIcon name="arrow-right" /><span>Sign In</span></button>}
      </header>

      {configured ? (
        <section className="profile-account-panel" aria-labelledby="profile-account-title">
          {authLoading ? (
            <div className="profile-account-panel__identity">
              <span className="eyebrow">FANatical account</span>
              <h2 id="profile-account-title">Checking account…</h2>
            </div>
          ) : user ? (
            <>
              <div className="profile-account-panel__identity">
                <span className="eyebrow">FANatical account</span>
                <h2 id="profile-account-title">Signed in</h2>
                <p>{user.email ?? "Authenticated FANatical account"}</p>
              </div>
              <button className="profile-account-panel__sign-out" type="button" disabled={accountActionBusy} onClick={() => void signOutHere()}>{accountActionBusy ? "Signing Out…" : "Sign Out"}</button>
            </>
          ) : (
            <>
              <div className="profile-account-panel__identity">
                <span className="eyebrow">FANatical account</span>
                <h2 id="profile-account-title">Make this Profile yours</h2>
                <p>Sign in to your account or create your FANatical identity.</p>
              </div>
              <div className="profile-account-panel__actions">
                <button type="button" onClick={() => setAccountDialogMode("sign-in")}>Sign In</button>
                <button type="button" onClick={() => setAccountDialogMode("create")}>Create Account</button>
              </div>
            </>
          )}
        </section>
      ) : null}

      {accountActionError ? <p className="profile-account-error" role="alert">Account action needs attention: {accountActionError}</p> : null}
      {profileError ? <p className="profile-account-error" role="alert">Profile sync needs attention: {profileError}</p> : null}

      <ProfilePhotoShowcase photos={orderedOwnerPhotos} featuredCategory={profile.featuredFanPhotoCategory} onOpenCategory={setOpenPhotoCategory} />

      <section className="profile-stats-section" aria-labelledby="profile-stats-title">
        <header className="profile-section-heading"><div><h2 id="profile-stats-title">At a glance</h2></div></header>
        <StatDashboard label="Profile at a glance" primary={displayProfileStats.slice(0, 2).map((stat) => ({ ...stat, icon: profileStatIcons[stat.label] ?? <AppIcon name="information-circle" /> }))} secondary={displayProfileStats.slice(2).map((stat) => ({ ...stat, icon: profileStatIcons[stat.label] ?? <AppIcon name="information-circle" />, ...((stat.label === "Fan Score" || stat.label === "Sport IQ") ? { to: "/profile/stats" } : {}) }))} />
      </section>

      <section className="profile-tab-section">
        <div className="profile-tabs" role="tablist" aria-label="Profile sections">
          {profileTabs.map((tab) => <button key={tab.id} id={`profile-tab-${tab.id}`} type="button" role="tab" aria-selected={activeTab === tab.id} aria-controls="profile-tab-panel" onClick={() => setActiveTab(tab.id)}>{tab.label}</button>)}
        </div>
        <div id="profile-tab-panel" role="tabpanel" aria-labelledby={`profile-tab-${activeTab}`} tabIndex={0}>
          <ProfileTabContent tab={activeTab} profile={profile} photos={ownerPhotos} moments={sortedMoments} followedTeams={followedTeams} onOpenPhoto={setOpenPhoto} onOpenMoment={setOpenMomentId} onAddMoment={() => setMomentCreateOpen(true)} onAddTeam={() => setAddTeamOpen(true)} />
        </div>
      </section>

      {editing ? <ProfileEditDialog profile={profile} accountBacked={Boolean(configured && user)} onSave={saveProfile} onClose={() => setEditing(false)} {...(configured && user ? { onSignOut: signOutHere } : {})} /> : null}
      {accountDialogMode ? <AccountDialog initialMode={accountDialogMode} onClose={() => setAccountDialogMode(null)} /> : null}
      {addTeamOpen ? <ProfileAddTeamDialog followedTeams={followedTeams} onAdd={addTeam} onClose={() => setAddTeamOpen(false)} /> : null}
      {momentCreateOpen ? <MomentCreateDialog photos={ownerPhotos} onCreate={createMoment} onClose={() => setMomentCreateOpen(false)} /> : null}
      {openPhoto ? <FanPhotoViewer photo={openPhoto} openedFromRatingQueue={false} onClose={() => setOpenPhoto(null)} /> : null}
    </div>
  );
}
