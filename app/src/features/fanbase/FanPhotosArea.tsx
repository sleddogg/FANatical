import { createPortal } from "react-dom";
import {
  useEffect,
  useRef,
  useState,
  type FormEvent,
  type TouchEvent,
} from "react";
import type { TeamId } from "../../domain/team";
import { demoUser } from "./mockFanbaseData";
import { useFanbaseContext } from "./FanbaseContext";
import { formatFanbaseTime, formatRating, totalReactions } from "./fanbaseFormatting";
import { FanPhotoRankings } from "./FanPhotoRankings";
import { FanPhotoRating } from "./FanPhotoRating";
import { ReactionPicker } from "./ReactionPicker";
import type { FanPhoto, FanPhotoCategory } from "./types";

export const FAN_PHOTO_RATING_ELIGIBILITY_THRESHOLD = 50;

const categories = ["Game Face", "Fan Cave", "Memorabilia"] as const satisfies readonly FanPhotoCategory[];

const categoryDescriptions: Readonly<Record<FanPhotoCategory, string>> = {
  "Game Face": "The outfits, paint, signs, and rituals that turn game day into a statement.",
  "Fan Cave": "The rooms and spaces fans build around the teams they love.",
  Memorabilia: "Collectibles with a story, from handmade pieces to treasured keepsakes.",
};

type FanPhotosAreaProps = {
  readonly teamId: TeamId;
  readonly itemId: string | null;
  readonly category: FanPhotoCategory | null;
  readonly onOpenCategory: (category: FanPhotoCategory) => void;
  readonly onOpenItem: (itemId: string) => void;
  readonly onOpenRatingItem: (itemId: string) => void;
  readonly onCloseItem: () => void;
  readonly itemOrigin: "rating-queue" | null;
};

export function FanPhotoCategoryHub({
  photos,
  onOpenCategory,
  initialCategory = "Fan Cave",
  introduction = "Swipe or select a category to browse, rate, and celebrate how fans show up.",
  centerInitialCategory = false,
  minimal = false,
}: {
  readonly photos: readonly FanPhoto[];
  readonly onOpenCategory: (category: FanPhotoCategory) => void;
  readonly initialCategory?: FanPhotoCategory;
  readonly introduction?: string;
  readonly centerInitialCategory?: boolean;
  readonly minimal?: boolean;
}) {
  const scrollerRef = useRef<HTMLDivElement>(null);
  const categoryIndex = categories.indexOf(initialCategory);
  const displayedCategories: readonly FanPhotoCategory[] = centerInitialCategory
    ? [categories[(categoryIndex + categories.length - 1) % categories.length]!, initialCategory, categories[(categoryIndex + 1) % categories.length]!]
    : categories;
  const initialIndex = centerInitialCategory ? 1 : categoryIndex;
  const [activeIndex, setActiveIndex] = useState(initialIndex);

  const moveTo = (nextIndex: number) => {
    const clampedIndex = Math.max(0, Math.min(displayedCategories.length - 1, nextIndex));
    const card = scrollerRef.current?.querySelector<HTMLElement>(`[data-category-index="${clampedIndex}"]`);
    card?.scrollIntoView?.({ behavior: "smooth", block: "nearest", inline: "center" });
    setActiveIndex(clampedIndex);
  };

  useEffect(() => {
    const initialCard = scrollerRef.current?.querySelector<HTMLElement>(`[data-category-index="${initialIndex}"]`);
    initialCard?.scrollIntoView?.({ block: "nearest", inline: "center" });
    setActiveIndex(initialIndex);
  }, [initialIndex]);

  const updateActiveCard = () => {
    const scroller = scrollerRef.current;
    if (!scroller) return;
    const scrollerCenter = scroller.getBoundingClientRect().left + scroller.clientWidth / 2;
    const cards = Array.from(scroller.querySelectorAll<HTMLElement>("[data-category-index]"));
    const closest = cards.reduce((best, card, index) => {
      const bounds = card.getBoundingClientRect();
      const distance = Math.abs(bounds.left + bounds.width / 2 - scrollerCenter);
      return distance < best.distance ? { index, distance } : best;
    }, { index: 0, distance: Number.POSITIVE_INFINITY });
    setActiveIndex(closest.index);
  };

  return (
    <section className="fan-photo-category-hub" aria-label="Fan Photo categories">
      {introduction ? <div className="fan-photo-category-hub__intro"><p>{introduction}</p></div> : null}
      <div className="fan-photo-category-carousel-shell">
        <button className="fan-photo-carousel-arrow fan-photo-carousel-arrow--previous" type="button" aria-label="Previous Fan Photo category" disabled={activeIndex === 0} onClick={() => moveTo(activeIndex - 1)}>‹</button>
        <div ref={scrollerRef} className="fan-photo-category-carousel" onScroll={updateActiveCard}>
          {displayedCategories.map((category, index) => {
            const cover = photos.find((photo) => photo.category === category)?.images[0];
            return (
              <button
                className="fan-photo-category-card"
                data-category-index={index}
                key={category}
                type="button"
                aria-label={`Open ${category} Fan Photos`}
                aria-current={activeIndex === index ? "true" : undefined}
                onClick={() => activeIndex === index ? onOpenCategory(category) : moveTo(index)}
              >
                {cover ? <img src={cover.url} alt="" /> : <span className="fan-photo-category-card__empty" aria-hidden="true">▧</span>}
                <span className="fan-photo-category-card__shade" />
                <span className="fan-photo-category-card__copy">{minimal ? null : <small>{photos.filter((photo) => photo.category === category).length} FANfotos</small>}<strong>{category}</strong>{minimal ? null : <><span>{categoryDescriptions[category]}</span><b>Explore <span aria-hidden="true">→</span></b></>}</span>
              </button>
            );
          })}
        </div>
        <button className="fan-photo-carousel-arrow fan-photo-carousel-arrow--next" type="button" aria-label="Next Fan Photo category" disabled={activeIndex === displayedCategories.length - 1} onClick={() => moveTo(activeIndex + 1)}>›</button>
      </div>
      <div className="fan-photo-carousel-dots" aria-label={`Showing ${displayedCategories[activeIndex]} category`}>
        {displayedCategories.map((category, index) => <button key={category} type="button" aria-label={`Show ${category}`} aria-pressed={activeIndex === index} onClick={() => moveTo(index)} />)}
      </div>
    </section>
  );
}

function FanPhotoRatingQueue({ photos, onOpen }: { readonly photos: readonly FanPhoto[]; readonly onOpen: (itemId: string) => void }) {
  const queue = photos.filter((photo) => photo.owner.id !== demoUser.id && photo.viewerRating === null).slice(0, 4);

  return (
    <section className="fan-photo-rating-queue" aria-labelledby="fan-photo-rating-queue-title">
      <header><div><h3 id="fan-photo-rating-queue-title">Photos to Rate</h3><p>Open a FANfoto to rate it. Rated photos leave your queue and another takes its place.</p></div></header>
      {queue.length ? (
        <div className="fan-photo-rating-queue__scroller">
          {queue.map((photo) => (
            <article className="fan-photo-rating-card" key={photo.id}>
              <button className="fan-photo-rating-card__photo" type="button" aria-label={`Open ${photo.title}`} onClick={() => onOpen(photo.id)}><img src={photo.images[0]?.url} alt="" /></button>
              <div className="fan-photo-rating-card__identity"><strong>{photo.title}</strong><small>@{photo.owner.username}</small></div>
            </article>
          ))}
        </div>
      ) : <p className="fan-photo-shelf__empty">You have rated every available FANfoto in this category.</p>}
    </section>
  );
}

function FanPhotoCategoryPage({ photos, teamId, onOpenItem, onOpenRatingItem }: { readonly photos: readonly FanPhoto[]; readonly teamId: TeamId; readonly onOpenItem: (itemId: string) => void; readonly onOpenRatingItem: (itemId: string) => void }) {
  return (
    <div className="fan-photo-category-page">
      <FanPhotoRatingQueue photos={photos} onOpen={onOpenRatingItem} />
      <FanPhotoRankings photos={photos} teamId={teamId} eligibilityThreshold={FAN_PHOTO_RATING_ELIGIBILITY_THRESHOLD} onOpenItem={onOpenItem} />
    </div>
  );
}

export function FanPhotoViewer({ photo, openedFromRatingQueue, onClose }: { readonly photo: FanPhoto; readonly openedFromRatingQueue: boolean; readonly onClose: () => void }) {
  const fanbase = useFanbaseContext();
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const touchStartX = useRef<number | null>(null);
  const flippedRef = useRef(false);
  const onCloseRef = useRef(onClose);
  const [imageIndex, setImageIndex] = useState(0);
  const [flipped, setFlipped] = useState(false);
  const [commentBody, setCommentBody] = useState("");
  const [shareMessage, setShareMessage] = useState("");
  const hasMultipleImages = photo.images.length > 1;
  const currentImage = photo.images[imageIndex] ?? photo.images[0];
  const flipLocked = openedFromRatingQueue && photo.viewerRating === null;

  flippedRef.current = flipped;
  onCloseRef.current = onClose;

  const moveImage = (direction: -1 | 1) => {
    if (!hasMultipleImages) return;
    setImageIndex((current) => (current + direction + photo.images.length) % photo.images.length);
  };

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    const pageFrame = document.querySelector<HTMLElement>(".page-frame--inner");
    const previousAriaHidden = pageFrame?.getAttribute("aria-hidden");
    const previouslyInert = pageFrame?.hasAttribute("inert") ?? false;
    document.body.style.overflow = "hidden";
    pageFrame?.setAttribute("aria-hidden", "true");
    pageFrame?.setAttribute("inert", "");
    closeButtonRef.current?.focus();

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onCloseRef.current();
        return;
      }
      if (!flippedRef.current && hasMultipleImages && event.key === "ArrowLeft") {
        setImageIndex((current) => (current - 1 + photo.images.length) % photo.images.length);
      }
      if (!flippedRef.current && hasMultipleImages && event.key === "ArrowRight") {
        setImageIndex((current) => (current + 1) % photo.images.length);
      }
      if (event.key === "Tab") {
        const viewer = document.querySelector<HTMLElement>(".fan-photo-viewer");
        const focusable = Array.from(viewer?.querySelectorAll<HTMLElement>("button:not(:disabled), textarea, a[href]") ?? []).filter((element) => !element.closest("[inert]"));
        if (!focusable.length) return;
        const first = focusable[0]!;
        const last = focusable[focusable.length - 1]!;
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      if (previousAriaHidden == null) pageFrame?.removeAttribute("aria-hidden");
      else pageFrame?.setAttribute("aria-hidden", previousAriaHidden);
      if (!previouslyInert) pageFrame?.removeAttribute("inert");
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, [hasMultipleImages, photo.id, photo.images.length]);

  const submitComment = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!commentBody.trim()) return;
    fanbase.addFanPhotoComment(photo.id, commentBody);
    setCommentBody("");
  };

  const handleTouchEnd = (event: TouchEvent<HTMLElement>) => {
    const start = touchStartX.current;
    touchStartX.current = null;
    if (start === null || flipped) return;
    const touch = event.changedTouches[0];
    if (!touch) return;
    const difference = touch.clientX - start;
    if (Math.abs(difference) > 45) moveImage(difference < 0 ? 1 : -1);
  };

  return createPortal(
    <section className="fan-photo-viewer" role="dialog" aria-modal="true" aria-label={photo.title}>
      <div className={`fan-photo-viewer__card${flipped ? " fan-photo-viewer__card--flipped" : ""}`}>
        <div className="fan-photo-viewer__face fan-photo-viewer__front" aria-hidden={flipped} inert={flipped} onTouchStart={(event) => { touchStartX.current = event.touches[0]?.clientX ?? null; }} onTouchEnd={handleTouchEnd}>
          {currentImage ? <img src={currentImage.url} alt={currentImage.alt} draggable="false" /> : null}
          {hasMultipleImages ? (
            <>
              <button className="fan-photo-viewer__image-arrow fan-photo-viewer__image-arrow--previous" type="button" aria-label="Previous image" onClick={() => moveImage(-1)}>‹</button>
              <button className="fan-photo-viewer__image-arrow fan-photo-viewer__image-arrow--next" type="button" aria-label="Next image" onClick={() => moveImage(1)}>›</button>
              <span className="fan-photo-viewer__image-position" aria-live="polite">{imageIndex + 1} / {photo.images.length}</span>
            </>
          ) : null}
        </div>

        <div className="fan-photo-viewer__face fan-photo-viewer__back" aria-hidden={!flipped} inert={!flipped}>
          <article className="fan-photo-viewer__info">
            <div className="fan-photo-viewer__owner"><span className="community-avatar">{photo.owner.initials}</span><div><strong>@{photo.owner.username}</strong><small>{photo.category} · {formatFanbaseTime(photo.createdAt)}</small></div></div>
            <span className="eyebrow">FANfoto story</span>
            <h2>{photo.title}</h2>
            <p>{photo.details}</p>
            <dl>
              <div><dt>Rating</dt><dd>★ {formatRating(photo.ratingTotal, photo.ratingCount)}</dd></div>
              <div><dt>Ratings</dt><dd>{photo.ratingCount}</dd></div>
              <div><dt>Recognition</dt><dd>{photo.rankingBadge ?? (photo.ratingCount >= FAN_PHOTO_RATING_ELIGIBILITY_THRESHOLD ? "Ranking eligible" : `${FAN_PHOTO_RATING_ELIGIBILITY_THRESHOLD - photo.ratingCount} ratings to qualify`)}</dd></div>
              <div><dt>Images</dt><dd>{photo.images.length}</dd></div>
            </dl>
            <div className="fan-photo-viewer__reactions"><span>Reactions · {totalReactions(photo.reactions)}</span><ReactionPicker reactions={photo.reactions} viewerReaction={photo.viewerReaction} onReact={(reaction) => fanbase.reactToFanPhoto(photo.id, reaction)} /></div>
            <section className="fan-photo-viewer__comments" aria-labelledby="fan-photo-comments-title">
              <h3 id="fan-photo-comments-title">Comments <span>{photo.comments.length}</span></h3>
              {photo.comments.length ? photo.comments.map((comment) => <article key={comment.id}><span className="community-avatar">{comment.author.initials}</span><div><strong>@{comment.author.username}</strong><small>{formatFanbaseTime(comment.createdAt)}</small><p>{comment.body}</p></div></article>) : <p>No comments yet. Start the conversation.</p>}
              <form onSubmit={submitComment}><label><span>Add a comment</span><textarea required rows={2} value={commentBody} onChange={(event) => setCommentBody(event.target.value)} /></label><button type="submit">Post</button></form>
            </section>
            <button className="fan-photo-viewer__report" type="button" onClick={() => fanbase.reportFanPhoto(photo.id)}>{photo.reported ? "Reported" : "Report FANfoto"}</button>
          </article>
        </div>
      </div>

      {photo.rankingBadge ? <span className="fan-photo-viewer__ranking">{photo.rankingBadge}</span> : null}
      <button ref={closeButtonRef} className="fan-photo-viewer__close" type="button" aria-label="Close FANfoto" onClick={onClose}>×</button>
      <div className="fan-photo-viewer__bottom-actions">
        <button type="button" onClick={() => setShareMessage("Sharing is represented as a local frontend placeholder.")}><span aria-hidden="true">↗</span> Share</button>
        {!flipped ? <FanPhotoRating label="Rate this FANfoto" value={photo.viewerRating} compact onRate={(rating) => fanbase.rateFanPhoto(photo.id, rating)} /> : <span />}
        <button
          type="button"
          disabled={flipLocked}
          aria-label={flipLocked ? "Rate this FANfoto to unlock details" : flipped ? "Photo" : "Flip"}
          title={flipLocked ? "Rate this FANfoto to unlock details" : undefined}
          onClick={() => setFlipped((current) => !current)}
        ><span aria-hidden="true">{flipLocked ? "🔒" : "↻"}</span> {flipped ? "Photo" : "Flip"}</button>
      </div>
      {shareMessage ? <p className="fan-photo-viewer__status" role="status">{shareMessage}</p> : null}
    </section>,
    document.body,
  );
}

export function FanPhotosArea({ teamId, itemId, category, onOpenCategory, onOpenItem, onOpenRatingItem, onCloseItem, itemOrigin }: FanPhotosAreaProps) {
  const fanbase = useFanbaseContext();
  const teamPhotos = fanbase.fanPhotos.filter((photo) => photo.teamId === teamId);
  const selectedPhoto = itemId ? teamPhotos.find((photo) => photo.id === itemId) : undefined;

  return (
    <>
      {category ? <FanPhotoCategoryPage photos={teamPhotos.filter((photo) => photo.category === category)} teamId={teamId} onOpenItem={onOpenItem} onOpenRatingItem={onOpenRatingItem} /> : <FanPhotoCategoryHub photos={teamPhotos} onOpenCategory={onOpenCategory} />}
      {selectedPhoto ? <FanPhotoViewer key={selectedPhoto.id} photo={selectedPhoto} openedFromRatingQueue={itemOrigin === "rating-queue"} onClose={onCloseItem} /> : null}
    </>
  );
}
