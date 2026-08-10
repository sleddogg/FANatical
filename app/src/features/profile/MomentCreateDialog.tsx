import { useEffect, useRef, type FormEvent } from "react";
import type { FanPhoto } from "../fanbase/types";
import type { CreateFanMomentInput } from "./types";

function formValue(formData: FormData, name: string) {
  return String(formData.get(name) ?? "").trim();
}

export function MomentCreateDialog({
  photos,
  onCreate,
  onClose,
}: {
  readonly photos: readonly FanPhoto[];
  readonly onCreate: (input: CreateFanMomentInput) => void;
  readonly onClose: () => void;
}) {
  const closeButtonRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    closeButtonRef.current?.focus();
    const closeOnEscape = (event: KeyboardEvent) => event.key === "Escape" && onClose();
    window.addEventListener("keydown", closeOnEscape);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", closeOnEscape);
    };
  }, [onClose]);

  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    const fanPhotoId = formValue(formData, "fanPhotoId");
    const location = formValue(formData, "location");
    const eventContext = formValue(formData, "eventContext");
    onCreate({
      title: formValue(formData, "title"),
      type: formValue(formData, "type"),
      dateOccurred: formValue(formData, "dateOccurred"),
      story: formValue(formData, "story"),
      ...(location ? { location } : {}),
      ...(eventContext ? { eventContext } : {}),
      ...(fanPhotoId ? { fanPhotoId } : {}),
    });
  };

  return (
    <div className="profile-dialog-layer">
      <button className="profile-dialog-backdrop" type="button" aria-label="Close Add Moment" onClick={onClose} />
      <section className="profile-edit-dialog profile-moment-dialog" role="dialog" aria-modal="true" aria-labelledby="profile-moment-create-title">
        <header>
          <div><span className="eyebrow">Profile story</span><h2 id="profile-moment-create-title">Add Moment</h2><p>Capture when the memory happened—not just when it was added.</p></div>
          <button ref={closeButtonRef} className="profile-icon-button" type="button" aria-label="Close Add Moment" onClick={onClose}>×</button>
        </header>
        <form onSubmit={submit}>
          <fieldset>
            <legend>Moment</legend>
            <label>Title<input name="title" required maxLength={100} /></label>
            <div className="profile-edit-dialog__paired-fields">
              <label>Type / context<select name="type" defaultValue="Game day"><option>Game day</option><option>Memory</option><option>Road trip</option><option>Tradition</option><option>Milestone</option><option>Fan connection</option></select></label>
              <label>Moment Date / Date Occurred<input name="dateOccurred" type="date" required /></label>
            </div>
            <label>Full story / memory<textarea name="story" required rows={7} maxLength={2400} /></label>
            <div className="profile-edit-dialog__paired-fields">
              <label>Location <small>Optional</small><input name="location" maxLength={140} /></label>
              <label>Event context <small>Optional</small><input name="eventContext" maxLength={140} /></label>
            </div>
            <label>Connected FANfoto <small>Optional · your existing canonical FANfotos</small><select name="fanPhotoId" defaultValue=""><option value="">No connected FANfoto</option>{photos.map((photo) => <option key={photo.id} value={photo.id}>{photo.category} · {photo.title}</option>)}</select></label>
          </fieldset>
          <div className="profile-edit-dialog__actions"><button type="button" onClick={onClose}>Cancel</button><button type="submit">Save Moment</button></div>
        </form>
      </section>
    </div>
  );
}
