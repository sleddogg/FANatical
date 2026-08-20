import type { ReactNode } from "react";
import { AppIcon } from "../../components/AppIcon";

type SavedImageLibraryProps<Item> = Readonly<{
  id: string;
  title: string;
  items: readonly Item[];
  maximum: number;
  busy: boolean;
  emptyMessage: string;
  limitMessage: string;
  previewClassName: string;
  itemKey: (item: Item) => string;
  isActive: (item: Item) => boolean;
  isSelected: (item: Item) => boolean;
  selectLabel: (item: Item) => string;
  removeLabel: (item: Item) => string | null;
  renderPreview: (item: Item) => ReactNode;
  onSelect: (item: Item) => void;
  onRemove: (item: Item) => void;
}>;

export function SavedImageLibrary<Item>({
  id,
  title,
  items,
  maximum,
  busy,
  emptyMessage,
  limitMessage,
  previewClassName,
  itemKey,
  isActive,
  isSelected,
  selectLabel,
  removeLabel,
  renderPreview,
  onSelect,
  onRemove,
}: SavedImageLibraryProps<Item>) {
  return (
    <section className="profile-saved-image-library" aria-labelledby={id}>
      <header><strong id={id}>{title}</strong><small>{items.length} of {maximum}</small></header>
      {items.length ? <div className="profile-saved-image-library__items">
        {items.map((item) => {
          const active = isActive(item);
          const selected = isSelected(item);
          const removeAccessibleName = removeLabel(item);
          return <article key={itemKey(item)} className={selected ? "profile-saved-image-library__item profile-saved-image-library__item--selected" : "profile-saved-image-library__item"}>
            <button className="profile-saved-image-library__select" type="button" aria-label={selectLabel(item)} aria-pressed={selected} disabled={busy} onClick={() => onSelect(item)}>
              <span className={`profile-saved-image-library__preview ${previewClassName}`}>{renderPreview(item)}</span>
              {active ? <span className="profile-saved-image-library__active"><AppIcon name="check-circle" /> Active</span> : null}
            </button>
            {removeAccessibleName ? <button className="profile-saved-image-library__remove" type="button" aria-label={removeAccessibleName} disabled={busy} onClick={() => onRemove(item)}><AppIcon name="x-mark" /></button> : null}
          </article>;
        })}
      </div> : <p>{emptyMessage}</p>}
      {items.length >= maximum ? <p className="profile-saved-image-library__limit" role="status">{limitMessage}</p> : null}
    </section>
  );
}
