import { useEffect, useRef, useState, type ChangeEvent, type KeyboardEvent, type PointerEvent } from "react";
import { useProfileVisual } from "./ProfileVisualContext";
import { cropImageStyle, useProfileVisualUrl } from "./ProfileVisualMedia";
import { clampProfileVisualCrop, defaultProfileVisualCrop, type ProfileVisualCrop, type ProfileVisualImageRecord, type ProfileVisualVariant } from "./types";

function cropsMatch(first: ProfileVisualCrop, second: ProfileVisualCrop) {
  return first.focalX === second.focalX && first.focalY === second.focalY && first.zoom === second.zoom;
}

function ProfileVisualEditor({ variant, record }: { readonly variant: ProfileVisualVariant; readonly record: ProfileVisualImageRecord | undefined }) {
  const title = variant === "mobile" ? "Mobile image" : "Wide image";
  const { replaceImage, removeImage, saveCrop } = useProfileVisual();
  const [crop, setCrop] = useState(record?.crop ?? defaultProfileVisualCrop);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const dragPoint = useRef<{ x: number; y: number } | null>(null);
  const previewUrl = useProfileVisualUrl(record?.displayBlob, record?.displayUrl);
  const instructionId = `profile-visual-${variant}-instructions`;

  useEffect(() => setCrop(record?.crop ?? defaultProfileVisualCrop), [record]);

  const updateCrop = (next: ProfileVisualCrop) => setCrop(clampProfileVisualCrop(next));

  const upload = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    setBusy(true);
    setError("");
    try {
      await replaceImage(variant, file);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "The selected image could not be saved.");
    } finally {
      setBusy(false);
    }
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

  const persistCrop = async () => {
    setBusy(true);
    setError("");
    try {
      await saveCrop(variant, crop);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "The crop could not be saved.");
    } finally {
      setBusy(false);
    }
  };

  const remove = async () => {
    if (!window.confirm(`Remove ${title}? The remaining image or FANatical default will be used instead.`)) return;
    setBusy(true);
    setError("");
    try {
      await removeImage(variant);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "The image could not be removed.");
    } finally {
      setBusy(false);
    }
  };

  const beginDrag = (event: PointerEvent<HTMLDivElement>) => {
    if (!record) return;
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

  return (
    <section className={`profile-visual-editor profile-visual-editor--${variant}`} aria-labelledby={`profile-visual-${variant}-title`}>
      <header><h4 id={`profile-visual-${variant}-title`}>{title}</h4><span>{record ? "Custom" : "Default"}</span></header>
      <div className="profile-visual-editor__preview" role="group" aria-label={`${title} crop area`} aria-describedby={instructionId} tabIndex={record ? 0 : -1} onKeyDown={moveWithKeyboard} onPointerDown={beginDrag} onPointerMove={drag} onPointerUp={endDrag} onPointerCancel={endDrag}>
        {previewUrl ? <img src={previewUrl} alt="" aria-hidden="true" draggable={false} style={cropImageStyle(crop)} /> : <div className="profile-visual-editor__default" aria-hidden="true"><strong>FANatical</strong><span>Your home for fandom.</span></div>}
      </div>
      <p className="profile-visual-editor__instructions" id={instructionId}>{record ? "Drag to reposition. With the crop area focused, use Arrow keys to move; hold Shift for larger steps." : "Upload an image to customize this profile visual."}</p>
      {record ? <label className="profile-visual-editor__zoom">Zoom <input type="range" min="1" max="3" step="0.01" value={crop.zoom} aria-label={`${title} Zoom`} onChange={(event) => updateCrop({ ...crop, zoom: Number(event.target.value) })} /><output>{Math.round(crop.zoom * 100)}%</output></label> : null}
      {error ? <p className="profile-visual-editor__error" role="alert">{error}</p> : null}
      <div className="profile-visual-editor__controls">
        <label className="profile-visual-editor__upload"><input className="visually-hidden" type="file" accept="image/jpeg,image/png,image/webp" aria-label={`${record ? "Replace" : "Upload"} ${title}`} disabled={busy} onChange={upload} /><span>{busy ? "Processing…" : record ? "Replace image" : "Upload image"}</span></label>
        {record ? <><button type="button" disabled={busy} onClick={() => setCrop(defaultProfileVisualCrop)}>Reset crop</button><button type="button" disabled={busy || cropsMatch(crop, record.crop)} onClick={() => void persistCrop()}>Save crop</button><button className="profile-visual-editor__remove" type="button" disabled={busy} onClick={() => void remove()}>Remove image</button></> : null}
      </div>
    </section>
  );
}

export function ProfileVisualSettings() {
  const { images } = useProfileVisual();
  return <div className="profile-visual-settings"><ProfileVisualEditor variant="mobile" record={images.mobile} /><ProfileVisualEditor variant="wide" record={images.wide} /></div>;
}
