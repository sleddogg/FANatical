import { useEffect, useRef, useState, type ChangeEvent, type KeyboardEvent, type PointerEvent } from "react";
import { AppIcon } from "../../components/AppIcon";
import { SavedImageLibrary } from "../profile/SavedImageLibrary";
import { useProfileVisual } from "./ProfileVisualContext";
import { cropImageStyle, ProfileVisualMedia, useProfileVisualUrl } from "./ProfileVisualMedia";
import { prepareProfileVisualImage } from "./profileVisualStorage";
import { clampProfileVisualCrop, defaultProfileVisualCrop, type ProfileVisualCrop, type ProfileVisualImageRecord, type ProfileVisualVariant } from "./types";

function cropsMatch(first: ProfileVisualCrop, second: ProfileVisualCrop) {
  return first.focalX === second.focalX && first.focalY === second.focalY && first.zoom === second.zoom;
}

function ProfileVisualEditor({ variant, record, photos }: {
  readonly variant: ProfileVisualVariant;
  readonly record: ProfileVisualImageRecord | undefined;
  readonly photos: readonly ProfileVisualImageRecord[];
}) {
  const title = variant === "mobile" ? "Mobile Visual" : "Wide Visual";
  const { saveImage, removeImage } = useProfileVisual();
  const [draft, setDraft] = useState<ProfileVisualImageRecord | undefined>(record);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const dragPoint = useRef<{ x: number; y: number } | null>(null);
  const draftChanged = useRef(false);
  const previewUrl = useProfileVisualUrl(draft?.displayBlob, draft?.displayUrl);
  const crop = draft?.crop ?? defaultProfileVisualCrop;
  const instructionId = `profile-visual-${variant}-instructions`;

  useEffect(() => {
    if (!draftChanged.current) setDraft(record);
  }, [record]);

  const updateCrop = (next: ProfileVisualCrop) => {
    draftChanged.current = true;
    setDraft((current) => current ? { ...current, crop: clampProfileVisualCrop(next) } : current);
  };

  const upload = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    draftChanged.current = true;
    setBusy(true);
    setError("");
    try {
      setDraft(await prepareProfileVisualImage(variant, file));
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "The selected image could not be prepared.");
    } finally {
      setBusy(false);
    }
  };

  const selectSavedPhoto = (photo: ProfileVisualImageRecord) => {
    draftChanged.current = true;
    setError("");
    setDraft(photo);
  };

  const moveWithKeyboard = (event: KeyboardEvent<HTMLDivElement>) => {
    const step = event.shiftKey ? 0.08 : 0.02;
    let nextCrop: ProfileVisualCrop;
    if (event.key === "ArrowLeft") nextCrop = { ...crop, focalX: crop.focalX + step };
    else if (event.key === "ArrowRight") nextCrop = { ...crop, focalX: crop.focalX - step };
    else if (event.key === "ArrowUp") nextCrop = { ...crop, focalY: crop.focalY + step };
    else if (event.key === "ArrowDown") nextCrop = { ...crop, focalY: crop.focalY - step };
    else return;
    event.preventDefault();
    updateCrop(nextCrop);
  };

  const save = async () => {
    if (!draft) return;
    setBusy(true);
    setError("");
    try {
      const saved = await saveImage(draft);
      draftChanged.current = false;
      setDraft(saved);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "The image could not be saved.");
    } finally {
      setBusy(false);
    }
  };

  const cancel = () => {
    draftChanged.current = false;
    setError("");
    setDraft(record);
  };

  const remove = async (photo: ProfileVisualImageRecord) => {
    if (!photo.id) return;
    const active = photo.id === record?.id;
    const message = active
      ? `Remove this active ${title}? Another saved image will become active, or the FANatical default will be shown if none remain.`
      : `Remove this saved ${title}? This cannot be undone.`;
    if (!window.confirm(message)) return;
    setBusy(true);
    setError("");
    try {
      const nextActive = await removeImage(variant, photo.id);
      if (draft?.id === photo.id) {
        draftChanged.current = false;
        setDraft(nextActive);
      }
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "The saved image could not be removed.");
    } finally {
      setBusy(false);
    }
  };

  const beginDrag = (event: PointerEvent<HTMLDivElement>) => {
    if (!draft) return;
    event.currentTarget.setPointerCapture(event.pointerId);
    dragPoint.current = { x: event.clientX, y: event.clientY };
  };

  const drag = (event: PointerEvent<HTMLDivElement>) => {
    const previous = dragPoint.current;
    if (!previous) return;
    const bounds = event.currentTarget.getBoundingClientRect();
    if (!bounds.width || !bounds.height) return;
    updateCrop({
      ...crop,
      focalX: crop.focalX - (event.clientX - previous.x) / bounds.width / crop.zoom,
      focalY: crop.focalY - (event.clientY - previous.y) / bounds.height / crop.zoom,
    });
    dragPoint.current = { x: event.clientX, y: event.clientY };
  };

  const endDrag = (event: PointerEvent<HTMLDivElement>) => {
    dragPoint.current = null;
    if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId);
  };

  const changed = Boolean(draft && (
    draft.sourceBlob
    || draft.id !== record?.id
    || !record
    || !cropsMatch(draft.crop, record.crop)
  ));

  return (
    <section className={`profile-visual-editor profile-visual-editor--${variant}`} aria-labelledby={`profile-visual-${variant}-title`}>
      <header><h4 id={`profile-visual-${variant}-title`}>{title}</h4><span>{draft ? "Preview" : "Default"}</span></header>
      <div className="profile-visual-editor__preview" role="group" aria-label={`${title} crop area`} aria-describedby={instructionId} tabIndex={draft ? 0 : -1} onKeyDown={moveWithKeyboard} onPointerDown={beginDrag} onPointerMove={drag} onPointerUp={endDrag} onPointerCancel={endDrag}>
        {previewUrl ? <img src={previewUrl} alt="" aria-hidden="true" draggable={false} style={cropImageStyle(crop)} /> : <div className="profile-visual-editor__default" aria-hidden="true"><strong>FANatical</strong><span>Your home for fandom.</span></div>}
      </div>
      <SavedImageLibrary
        id={`profile-visual-${variant}-library-title`}
        title={`Saved ${variant === "mobile" ? "Mobile" : "Wide"} images`}
        items={photos}
        maximum={3}
        busy={busy}
        emptyMessage={`No saved ${variant === "mobile" ? "Mobile" : "Wide"} images yet.`}
        limitMessage="Three-image limit reached. Remove a saved image before choosing another."
        previewClassName={`profile-saved-image-library__preview--${variant}`}
        itemKey={(photo) => photo.id ?? photo.displayPath ?? `${variant}-${photo.sourceFilename}`}
        isActive={(photo) => photo.id === record?.id}
        isSelected={(photo) => photo.id === draft?.id && !draft?.sourceBlob}
        selectLabel={(photo) => `Edit saved ${title} ${photo.sourceFilename}`}
        removeLabel={(photo) => photo.id ? `Remove saved ${title} ${photo.sourceFilename}` : null}
        renderPreview={(photo) => <ProfileVisualMedia record={photo} />}
        onSelect={selectSavedPhoto}
        onRemove={(photo) => void remove(photo)}
      />
      <p className="profile-visual-editor__instructions" id={instructionId}>{draft ? "Drag to reposition. With the crop area focused, use Arrow keys to move; hold Shift for larger steps." : "Upload an image to customize this profile visual."}</p>
      {draft ? <label className="profile-visual-editor__zoom">Zoom <input type="range" min="1" max="3" step="0.01" value={crop.zoom} aria-label={`${title} Zoom`} onChange={(event) => updateCrop({ ...crop, zoom: Number(event.target.value) })} /><output>{Math.round(crop.zoom * 100)}%</output></label> : null}
      {error ? <p className="profile-visual-editor__error" role="alert">{error}</p> : null}
      <div className="profile-visual-editor__controls">
        <label className={`profile-visual-editor__upload${photos.length >= 3 ? " profile-visual-editor__upload--disabled" : ""}`}><input className="visually-hidden" type="file" accept="image/jpeg,image/png,image/webp" aria-label={`Choose ${title}`} disabled={busy || photos.length >= 3} onChange={upload} /><span><AppIcon name="arrow-up-tray" />{busy ? "Processing…" : draft ? "Choose another image" : "Choose image"}</span></label>
        {draft ? <button type="button" disabled={busy} onClick={() => updateCrop(defaultProfileVisualCrop)}>Reset crop</button> : null}
        <button type="button" disabled={busy || !changed} onClick={cancel}>Cancel changes</button>
        <button className="profile-visual-editor__save" type="button" disabled={busy || !changed} onClick={() => void save()}>{busy ? "Saving…" : "Save image"}</button>
      </div>
    </section>
  );
}

export function ProfileVisualSettings() {
  const { images, library, resolveLibrary } = useProfileVisual();
  useEffect(() => { void resolveLibrary(); }, [resolveLibrary]);
  return <div className="profile-visual-settings">
    <ProfileVisualEditor variant="mobile" record={images.mobile} photos={library.mobile} />
    <ProfileVisualEditor variant="wide" record={images.wide} photos={library.wide} />
  </div>;
}
