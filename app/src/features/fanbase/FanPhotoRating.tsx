type FanPhotoRatingProps = {
  readonly label: string;
  readonly value: number | null;
  readonly onRate: (rating: number) => void;
  readonly compact?: boolean;
};

const ratingSteps = Array.from({ length: 10 }, (_, index) => (index + 1) / 2);

export function FanPhotoRating({ label, value, onRate, compact = false }: FanPhotoRatingProps) {
  return (
    <div className={`fan-photo-star-rating${compact ? " fan-photo-star-rating--compact" : ""}`} role="group" aria-label={label}>
      {[1, 2, 3, 4, 5].map((star) => (
        <span className="fan-photo-star-rating__star" key={star}>
          {ratingSteps.slice((star - 1) * 2, star * 2).map((rating, halfIndex) => (
            <button
              className={`fan-photo-star-rating__half fan-photo-star-rating__half--${halfIndex === 0 ? "left" : "right"}`}
              data-filled={value !== null && rating <= value ? "true" : undefined}
              key={rating}
              type="button"
              aria-label={`Rate ${rating} out of 5`}
              aria-pressed={value === rating}
              onClick={() => onRate(rating)}
            >
              <span aria-hidden="true">★</span>
            </button>
          ))}
        </span>
      ))}
    </div>
  );
}
