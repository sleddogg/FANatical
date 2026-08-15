import { useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { StatDashboard } from "../../components/StatDashboard";
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
import type { CreateFanMomentInput, FanMoment, ProfileRecord, ProfileTabId } from "./types";
import { buildSportsStatsSnapshot, fanScoreForUser, resolveFanbaseCompetition, sportsStatsUser } from "../stats/sportsStats";
import "../fanbase/fanbase.css";
import "./profile.css";

const photoCategories = ["Game Face", "Fan Cave", "Memorabilia"] as const satisfies readonly FanPhotoCategory[];
const featuredCategorySessionKey = "fanatical.profile.featuredFanPhotoCategory";

const profileTabs: readonly { id: ProfileTabId; label: string }[] = [
  { id: "bio", label: "Bio" },
  { id: "fan-identity", label: "Fan Identity" },
  { id: "sports-played", label: "Sports Played" },
  { id: "trophy-case", label: "Trophy Case" },
  { id: "moments", label: "Moments" },
];

type PhotoOrder = Record<FanPhotoCategory, string[]>;
let localMomentSequence = 0;

const profileStatIcons: Readonly<Record<(typeof profileStats)[number]["label"], string>> = {
  Streak: "🔥",
  Tier: "◆",
  "Fan Score": "★",
  "Fan Coins": "●",
  Rank: "↗",
  "Sport IQ": "◎",
};

function formatMomentDate(value: string) {
  return new Intl.DateTimeFormat(undefined, { year: "numeric", month: "long", day: "numeric" }).format(new Date(`${value}T12:00:00`));
}

function initialSessionProfile(): ProfileRecord {
  if (typeof window === "undefined") return initialProfile;
  const storedCategory = window.sessionStorage.getItem(featuredCategorySessionKey);
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
        <button className="profile-back-button" type="button" aria-label="Back to Profile" onClick={onBack}><span aria-hidden="true">←</span><span>Back to Profile</span></button>
        <div><span className="eyebrow">Profile FANfotos</span><h1>{category}</h1><p>Owner-curated display order</p></div>
        <button className="profile-edit-button" type="button" aria-label={`Add ${category} FANfoto`} onClick={onAddPhoto}><span aria-hidden="true">+</span><span>Add FANfoto</span></button>
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
                        <span><strong>{photo.title}</strong><small>@{photo.owner.username}{photo.images.length > 1 ? ` · ${photo.images.length} images` : ""}</small><small>★ {formatRating(photo.ratingTotal, photo.ratingCount)} · {photo.ratingCount} ratings</small></span>
                      </button>
                    </td>
                    <td className="profile-photo-order-table__recognition">{photo.rankingBadge ? <span>{photo.rankingBadge}</span> : <small>Not ranked</small>}</td>
                    <td className="profile-photo-order-table__move"><div><button type="button" aria-label={`Move ${photo.title} up`} disabled={index === 0} onClick={() => onMovePhoto(category, photo.id, -1)}>↑</button><button type="button" aria-label={`Move ${photo.title} down`} disabled={index === photos.length - 1} onClick={() => onMovePhoto(category, photo.id, 1)}>↓</button></div></td>
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
        <button className="profile-back-button" type="button" aria-label="Back to Moments" onClick={onBack}><span aria-hidden="true">←</span><span>Back to Moments</span></button>
        <div><span className="eyebrow">Moment</span><h1>{moment.title}</h1><p>{moment.type} · {formatMomentDate(moment.dateOccurred)}</p></div>
        <span />
      </header>
      <article className="profile-moment-detail">
        <header><span className="profile-moment-detail__type">{moment.type}</span><h2>{moment.title}</h2><time dateTime={moment.dateOccurred}>{formatMomentDate(moment.dateOccurred)}</time></header>
        <p className="profile-moment-detail__story">{moment.story}</p>
        {moment.location || moment.eventContext ? <dl>{moment.location ? <div><dt>Location</dt><dd>{moment.location}</dd></div> : null}{moment.eventContext ? <div><dt>Event context</dt><dd>{moment.eventContext}</dd></div> : null}</dl> : null}
        {photo ? <section className="profile-moment-detail__photo"><div><span className="eyebrow">Connected FANfoto</span><h3>{photo.title}</h3><p>{photo.category} · {photo.images.length > 1 ? `${photo.images.length} images` : "1 image"}</p></div><button type="button" aria-label={`Open connected FANfoto: ${photo.title}`} onClick={() => onOpenPhoto(photo)}><img src={photo.images[0]?.url} alt={photo.images[0]?.alt ?? ""} /><span>View FANfoto <b aria-hidden="true">→</b></span></button></section> : null}
      </article>
    </div>
  );
}

function ProfileTabContent({ tab, profile, photos, moments, onOpenPhoto, onOpenMoment, onAddMoment }: { readonly tab: ProfileTabId; readonly profile: ProfileRecord; readonly photos: readonly FanPhoto[]; readonly moments: readonly FanMoment[]; readonly onOpenPhoto: (photo: FanPhoto) => void; readonly onOpenMoment: (momentId: string) => void; readonly onAddMoment: () => void }) {
  if (tab === "bio" || tab === "fan-identity") {
    const fields = (tab === "bio" ? profile.bio : profile.fanIdentity).filter((field) => field.value.trim());
    return <section className="profile-details" aria-labelledby={`profile-${tab}-title`}><header><span className="eyebrow">{tab === "bio" ? "The person behind the fandom" : "Teams, traditions, and loyalties"}</span><h2 id={`profile-${tab}-title`}>{tab === "bio" ? "Bio" : "Fan Identity"}</h2></header><dl>{fields.map((field) => <div key={field.id}><dt>{field.label}</dt><dd>{field.value}</dd></div>)}</dl></section>;
  }

  if (tab === "sports-played") {
    return <section className="profile-details" aria-labelledby="profile-sports-title"><header><span className="eyebrow">Experience on the field</span><h2 id="profile-sports-title">Sports Played</h2></header><div className="profile-sports-grid">{profile.sportsPlayed.filter((sport) => sport.sport.trim()).map((sport) => { const context = [sport.position, sport.level].filter((value) => value.trim()).join(" · "); return <article key={sport.id}><div className="profile-sport-mark" aria-hidden="true">{sport.sport.slice(0, 1)}</div><div><h3>{sport.sport}</h3>{context ? <p>{context}</p> : null}{sport.years.trim() || sport.highlight.trim() ? <dl>{sport.years.trim() ? <div><dt>Years</dt><dd>{sport.years}</dd></div> : null}{sport.highlight.trim() ? <div><dt>Highlight</dt><dd>{sport.highlight}</dd></div> : null}</dl> : null}</div></article>; })}</div></section>;
  }

  if (tab === "trophy-case") {
    return <section className="profile-details" aria-labelledby="profile-trophies-title"><header><span className="eyebrow">Earned, pursued, remembered</span><h2 id="profile-trophies-title">Trophy Case</h2></header><div className="profile-trophy-grid">{profileTrophies.map((trophy) => <article className={`profile-trophy profile-trophy--${trophy.status}`} key={trophy.id}><div className="profile-trophy__icon" aria-hidden="true">{trophy.icon}</div><div><span>{trophy.status === "earned" ? "Earned" : trophy.status === "locked" ? "Locked" : "In progress"}</span><h3>{trophy.name}</h3><p>{trophy.description}</p>{trophy.earnedAt ? <small>Earned {trophy.earnedAt}</small> : null}{trophy.progress !== undefined ? <div className="profile-trophy__progress"><span style={{ width: `${trophy.progress}%` }} /><small>{trophy.progress}%</small></div> : null}</div></article>)}</div></section>;
  }

  const photoById = new Map(photos.map((photo) => [photo.id, photo]));
  return <section className="profile-details profile-details--moments" aria-labelledby="profile-moments-title"><header className="profile-moments-header"><h2 id="profile-moments-title">Moments <span>· The stories behind the score</span></h2><button type="button" onClick={onAddMoment}><span aria-hidden="true">+</span> Add Moment</button></header><div className="profile-moment-list">{moments.map((moment) => { const photo = moment.fanPhotoId ? photoById.get(moment.fanPhotoId) : undefined; return <article className="profile-moment-card" key={moment.id}>{photo ? <button className="profile-moment-card__thumbnail" type="button" aria-label={`Open connected FANfoto: ${photo.title}`} onClick={() => onOpenPhoto(photo)}><img src={photo.images[0]?.url} alt={photo.images[0]?.alt ?? ""} /></button> : <div className="profile-moment-card__thumbnail profile-moment-card__thumbnail--empty" aria-hidden="true">F</div>}<button className="profile-moment-card__story" type="button" aria-label={`Open Moment: ${moment.title}`} onClick={() => onOpenMoment(moment.id)}><span>{moment.type}</span><h3>{moment.title}</h3><time dateTime={moment.dateOccurred}>{formatMomentDate(moment.dateOccurred)}</time><p>{moment.story}</p>{moment.location || moment.eventContext ? <small>{[moment.location, moment.eventContext].filter(Boolean).join(" · ")}</small> : null}</button></article>; })}</div></section>;
}

export function ProfilePage() {
  const navigate = useNavigate();
  const location = useLocation();
  const fanbase = useFanbaseContext();
  const { selectedTeam } = useTeamContext();
  const { fanPhotos } = fanbase;
  const sportsStats = useMemo(() => sportsStatsUser(demoUser.id, buildSportsStatsSnapshot()), []);
  const selectedCompetition = resolveFanbaseCompetition(selectedTeam);
  const selectedFanScore = sportsStats ? fanScoreForUser(sportsStats, selectedCompetition.teamKey) : null;
  const displayProfileStats = profileStats.map((stat) => stat.label === "Fan Score"
    ? { ...stat, value: selectedFanScore?.toLocaleString() ?? "—", detail: `${selectedTeam.shortName} Fan Score` }
    : stat.label === "Sport IQ"
      ? { ...stat, value: sportsStats?.overallSportIq?.toString() ?? "—", detail: "Overall Sport IQ" }
      : stat);
  const [profile, setProfile] = useState<ProfileRecord>(initialSessionProfile);
  const [activeTab, setActiveTab] = useState<ProfileTabId>("bio");
  const [editing, setEditing] = useState(false);
  const [openPhoto, setOpenPhoto] = useState<FanPhoto | null>(null);
  const [openPhotoCategory, setOpenPhotoCategory] = useState<FanPhotoCategory | null>(null);
  const [createPhotoOpen, setCreatePhotoOpen] = useState(false);
  const [moments, setMoments] = useState<readonly FanMoment[]>(() => [...profileMoments]);
  const [openMomentId, setOpenMomentId] = useState<string | null>(null);
  const [momentCreateOpen, setMomentCreateOpen] = useState(false);
  const isOwner = true;
  const ownerPhotos = useMemo(() => fanPhotos.filter((photo) => photo.owner.id === demoUser.id), [fanPhotos]);
  const [photoOrder, setPhotoOrder] = useState<PhotoOrder>(() => buildInitialPhotoOrder(ownerPhotos));

  useEffect(() => {
    window.sessionStorage.setItem(featuredCategorySessionKey, profile.featuredFanPhotoCategory);
  }, [profile.featuredFanPhotoCategory]);

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
        <button className="profile-back-button" type="button" onClick={goBack}><span aria-hidden="true">←</span><span>Back</span></button>
        <div><span className="eyebrow">Profile</span><h1>{profile.displayName}</h1><p>{profile.tagline}</p></div>
        {isOwner ? <button className="profile-edit-button" type="button" onClick={() => setEditing(true)} aria-label="Edit profile"><span aria-hidden="true">✎</span><span>Edit</span></button> : <span />}
      </header>

      <ProfilePhotoShowcase photos={orderedOwnerPhotos} featuredCategory={profile.featuredFanPhotoCategory} onOpenCategory={setOpenPhotoCategory} />

      <section className="profile-stats-section" aria-labelledby="profile-stats-title">
        <header className="profile-section-heading"><div><h2 id="profile-stats-title">At a glance</h2></div></header>
        <StatDashboard label="Profile at a glance" primary={displayProfileStats.slice(0, 2).map((stat) => ({ ...stat, icon: profileStatIcons[stat.label] ?? "◆" }))} secondary={displayProfileStats.slice(2).map((stat) => ({ ...stat, icon: profileStatIcons[stat.label] ?? "◆", ...((stat.label === "Fan Score" || stat.label === "Sport IQ") ? { to: "/profile/stats" } : {}) }))} />
      </section>

      <section className="profile-tab-section">
        <div className="profile-tabs" role="tablist" aria-label="Profile sections">
          {profileTabs.map((tab) => <button key={tab.id} id={`profile-tab-${tab.id}`} type="button" role="tab" aria-selected={activeTab === tab.id} aria-controls="profile-tab-panel" onClick={() => setActiveTab(tab.id)}>{tab.label}</button>)}
        </div>
        <div id="profile-tab-panel" role="tabpanel" aria-labelledby={`profile-tab-${activeTab}`} tabIndex={0}>
          <ProfileTabContent tab={activeTab} profile={profile} photos={ownerPhotos} moments={sortedMoments} onOpenPhoto={setOpenPhoto} onOpenMoment={setOpenMomentId} onAddMoment={() => setMomentCreateOpen(true)} />
        </div>
      </section>

      {editing ? <ProfileEditDialog profile={profile} onSave={setProfile} onClose={() => setEditing(false)} /> : null}
      {momentCreateOpen ? <MomentCreateDialog photos={ownerPhotos} onCreate={createMoment} onClose={() => setMomentCreateOpen(false)} /> : null}
      {openPhoto ? <FanPhotoViewer photo={openPhoto} openedFromRatingQueue={false} onClose={() => setOpenPhoto(null)} /> : null}
    </div>
  );
}
