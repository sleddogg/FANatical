import { useEffect, useRef, useState, type ChangeEvent, type KeyboardEvent, type PointerEvent } from "react";
import { AppIcon } from "../../components/AppIcon";
import { useProfileAvatar } from "./ProfileAvatarContext";
import { prepareProfileAvatarImage } from "./profileAvatarImage";
import { profileAvatarImageStyle, useProfileAvatarUrl } from "./ProfileAvatarMedia";
import { clampProfileAvatarCrop, defaultProfileAvatarCrop, panProfileAvatarCrop, pinchProfileAvatarCrop, type ProfileAvatarCrop, type ProfileAvatarRecord } from "./types";

type Point = Readonly<{ x: number; y: number }>;

function distance(first: Point, second: Point) {
  return Math.hypot(second.x - first.x, second.y - first.y);
}

function midpoint(first: Point, second: Point): Point {
  return { x: (first.x + second.x) / 2, y: (first.y + second.y) / 2 };
}

function cropsMatch(first: ProfileAvatarCrop, second: ProfileAvatarCrop) {
  return first.focalX === second.focalX && first.focalY === second.focalY && first.zoom === second.zoom;
}

export function ProfileAvatarEditor({ onDone, onCancel }: { readonly onDone: () => void; readonly onCancel: () => void }) {
  const { avatar, saveAvatar, removeAvatar } = useProfileAvatar();
  const [draft, setDraft] = useState<ProfileAvatarRecord | null>(avatar);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const pointers = useRef(new Map<number, Point>());
  const lastPoint = useRef<Point | null>(null);
  const pinch = useRef<{ distance: number; midpoint: Point; crop: ProfileAvatarCrop } | null>(null);
  const previewUrl = useProfileAvatarUrl(draft);
  const crop = draft?.crop ?? defaultProfileAvatarCrop;

  useEffect(() => setDraft(avatar), [avatar]);

  const updateCrop = (next: ProfileAvatarCrop) => setDraft((current) => current ? { ...current, crop: clampProfileAvatarCrop(next) } : current);

  const upload = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file) return;
    setBusy(true);
    setError("");
    try {
      setDraft(await prepareProfileAvatarImage(file));
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "The selected profile photo could not be prepared.");
    } finally {
      setBusy(false);
    }
  };

  const moveBy = (deltaX: number, deltaY: number, bounds: DOMRect) => {
    if (!bounds.width || !bounds.height) return;
    setDraft((current) => current ? {
      ...current,
      crop: panProfileAvatarCrop(current.crop, deltaX, deltaY, bounds.width, bounds.height),
    } : current);
  };

  const beginPointer = (event: PointerEvent<HTMLDivElement>) => {
    if (!draft) return;
    event.currentTarget.setPointerCapture(event.pointerId);
    const point = { x: event.clientX, y: event.clientY };
    pointers.current.set(event.pointerId, point);
    lastPoint.current = point;
    const active = [...pointers.current.values()];
    if (active.length === 2) pinch.current = { distance: distance(active[0]!, active[1]!), midpoint: midpoint(active[0]!, active[1]!), crop };
  };

  const movePointer = (event: PointerEvent<HTMLDivElement>) => {
    if (!pointers.current.has(event.pointerId) || !draft) return;
    const point = { x: event.clientX, y: event.clientY };
    pointers.current.set(event.pointerId, point);
    const active = [...pointers.current.values()];
    const bounds = event.currentTarget.getBoundingClientRect();
    if (active.length === 2 && pinch.current) {
      const currentMidpoint = midpoint(active[0]!, active[1]!);
      const ratio = pinch.current.distance ? distance(active[0]!, active[1]!) / pinch.current.distance : 1;
      updateCrop(pinchProfileAvatarCrop(
        pinch.current.crop,
        ratio,
        currentMidpoint.x - pinch.current.midpoint.x,
        currentMidpoint.y - pinch.current.midpoint.y,
        bounds.width,
        bounds.height,
      ));
    } else if (active.length === 1 && lastPoint.current) {
      moveBy(point.x - lastPoint.current.x, point.y - lastPoint.current.y, bounds);
      lastPoint.current = point;
    }
  };

  const endPointer = (event: PointerEvent<HTMLDivElement>) => {
    pointers.current.delete(event.pointerId);
    pinch.current = null;
    lastPoint.current = [...pointers.current.values()][0] ?? null;
    if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId);
  };

  const moveWithKeyboard = (event: KeyboardEvent<HTMLDivElement>) => {
    const step = event.shiftKey ? 0.08 : 0.02;
    let next: ProfileAvatarCrop;
    if (event.key === "ArrowLeft") next = { ...crop, focalX: crop.focalX + step };
    else if (event.key === "ArrowRight") next = { ...crop, focalX: crop.focalX - step };
    else if (event.key === "ArrowUp") next = { ...crop, focalY: crop.focalY + step };
    else if (event.key === "ArrowDown") next = { ...crop, focalY: crop.focalY - step };
    else return;
    event.preventDefault();
    updateCrop(next);
  };

  const save = async () => {
    if (!draft) return;
    setBusy(true);
    setError("");
    try {
      await saveAvatar(draft);
      onDone();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "The profile photo could not be saved.");
    } finally {
      setBusy(false);
    }
  };

  const remove = async () => {
    if (!avatar || !window.confirm("Remove this profile photo? The User icon will be shown instead.")) return;
    setBusy(true);
    setError("");
    try {
      await removeAvatar();
      onDone();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "The profile photo could not be removed.");
    } finally {
      setBusy(false);
    }
  };

  const changed = Boolean(draft && (draft !== avatar || !avatar || !cropsMatch(draft.crop, avatar.crop)));

  return (
    <section className="profile-avatar-editor" aria-labelledby="profile-avatar-editor-title">
      <header><div><h3 id="profile-avatar-editor-title">Profile photo</h3><p>Move and zoom the original image behind the fixed circle.</p></div><span>{draft ? "Preview" : "No photo"}</span></header>
      <div className="profile-avatar-editor__stage">
        <div
          className="profile-avatar-editor__frame"
          role="group"
          aria-label="Profile photo positioning area"
          aria-describedby="profile-avatar-editor-instructions"
          tabIndex={draft ? 0 : -1}
          onKeyDown={moveWithKeyboard}
          onPointerDown={beginPointer}
          onPointerMove={movePointer}
          onPointerUp={endPointer}
          onPointerCancel={endPointer}
        >
          {draft && previewUrl
            ? <img src={previewUrl} alt="" aria-hidden="true" draggable={false} style={profileAvatarImageStyle(draft.crop)} />
            : <AppIcon name="user" />}
        </div>
      </div>
      <p id="profile-avatar-editor-instructions">Drag to reposition. Use two fingers to pinch on touch screens, or use the Zoom slider. Arrow keys also reposition the image.</p>
      {draft ? <label className="profile-avatar-editor__zoom">Zoom<input type="range" min="1" max="4" step="0.01" value={crop.zoom} aria-label="Profile photo zoom" onChange={(event) => updateCrop({ ...crop, zoom: Number(event.target.value) })} /><output>{Math.round(crop.zoom * 100)}%</output></label> : null}
      {error ? <p className="profile-avatar-editor__error" role="alert">{error}</p> : null}
      <div className="profile-avatar-editor__actions">
        <label className="profile-avatar-editor__upload"><input className="visually-hidden" type="file" accept="image/jpeg,image/png,image/webp" disabled={busy} onChange={upload} /><span><AppIcon name="camera" />{busy ? "Processing…" : draft ? "Choose another photo" : "Choose photo"}</span></label>
        {draft ? <button type="button" disabled={busy} onClick={() => updateCrop(defaultProfileAvatarCrop)}>Reset</button> : null}
        {avatar ? <button className="profile-avatar-editor__remove" type="button" disabled={busy} onClick={() => void remove()}>Remove photo</button> : null}
        <button type="button" disabled={busy} onClick={onCancel}>Cancel</button>
        <button className="profile-avatar-editor__save" type="button" disabled={busy || !draft || !changed} onClick={() => void save()}>{busy ? "Saving…" : "Save photo"}</button>
      </div>
    </section>
  );
}
