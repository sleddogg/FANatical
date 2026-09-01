import { fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { ProfileAvatarRecord } from "./types";

const mocks = vi.hoisted(() => ({
  avatar: null as ProfileAvatarRecord | null,
  photos: [] as ProfileAvatarRecord[],
  saveAvatar: vi.fn(),
  removePhoto: vi.fn(),
  resolveLibrary: vi.fn(),
  prepareImage: vi.fn(),
}));

const avatar: ProfileAvatarRecord = {
  id: "photo-1",
  sourceFilename: "portrait.jpg",
  sourceMediaType: "image/jpeg",
  displayUrl: "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg'/%3E",
  sourcePath: "user/avatar/source.jpg",
  displayPath: "user/avatar/display.webp",
  width: 1200,
  height: 1800,
  crop: { focalX: 0.5, focalY: 0.5, zoom: 1 },
  updatedAt: "2026-08-18T00:00:00.000Z",
};

vi.mock("./ProfileAvatarContext", () => ({
  useProfileAvatar: () => ({
    avatar: mocks.avatar,
    photos: mocks.photos,
    loading: false,
    resolveLibrary: mocks.resolveLibrary,
    saveAvatar: mocks.saveAvatar,
    saveCrop: vi.fn(),
    removePhoto: mocks.removePhoto,
  }),
}));

vi.mock("./profileAvatarImage", () => ({
  prepareProfileAvatarImage: mocks.prepareImage,
}));

import { ProfileAvatarEditor } from "./ProfileAvatarEditor";

describe("ProfileAvatarEditor", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.avatar = avatar;
    mocks.photos = [avatar];
    mocks.removePhoto.mockResolvedValue(null);
    mocks.resolveLibrary.mockResolvedValue(undefined);
  });

  it("shows the fixed circular preview and saves zoom changes", async () => {
    const user = userEvent.setup();
    const onDone = vi.fn();
    render(<ProfileAvatarEditor onDone={onDone} onCancel={vi.fn()} />);

    expect(screen.getByRole("group", { name: "Profile photo positioning area" })).toBeInTheDocument();
    expect(screen.getByLabelText("Choose another photo")).toHaveAttribute("accept", "image/jpeg,image/png,image/webp");
    fireEvent.change(screen.getByRole("slider", { name: "Profile photo zoom" }), { target: { value: "2.25" } });
    await user.click(screen.getByRole("button", { name: "Save photo" }));

    expect(mocks.saveAvatar).toHaveBeenCalledWith(expect.objectContaining({ crop: expect.objectContaining({ zoom: 2.25 }) }));
    expect(onDone).toHaveBeenCalledOnce();
  });

  it("cancels without saving", async () => {
    const user = userEvent.setup();
    const onCancel = vi.fn();
    render(<ProfileAvatarEditor onDone={vi.fn()} onCancel={onCancel} />);
    await user.click(screen.getByRole("button", { name: "Cancel" }));
    expect(onCancel).toHaveBeenCalledOnce();
    expect(mocks.saveAvatar).not.toHaveBeenCalled();
  });

  it("moves the shape setting into the editor and updates the preview before saving", async () => {
    const user = userEvent.setup();
    render(<ProfileAvatarEditor onDone={vi.fn()} onCancel={vi.fn()} />);

    const frame = screen.getByRole("group", { name: "Profile photo positioning area" });
    expect(screen.getByRole("radio", { name: "Circle" })).toBeChecked();
    expect(frame).toHaveClass("profile-avatar-editor__frame--circle");

    await user.click(screen.getByRole("radio", { name: "Square" }));
    expect(frame).toHaveClass("profile-avatar-editor__frame--square");
    await user.click(screen.getByRole("button", { name: "Save photo" }));

    expect(window.localStorage.getItem("fanatical.profile-image-shape.v1")).toBe("square");
    expect(mocks.saveAvatar).not.toHaveBeenCalled();
  });

  it("keeps a first-attempt picker photo when focus/session refreshes the saved avatar", async () => {
    const user = userEvent.setup();
    const replacement: ProfileAvatarRecord = {
      ...avatar,
      sourceFilename: "replacement.png",
      sourceMediaType: "image/png",
      displayUrl: "data:image/svg+xml,%3Csvg%20id='replacement'%20xmlns='http://www.w3.org/2000/svg'/%3E",
      updatedAt: "2026-08-20T00:00:00.000Z",
    };
    mocks.prepareImage.mockResolvedValueOnce(replacement);
    const view = render(<ProfileAvatarEditor onDone={vi.fn()} onCancel={vi.fn()} />);

    await user.upload(screen.getByLabelText("Choose another photo"), new File(["image"], "replacement.png", { type: "image/png" }));
    expect(mocks.prepareImage).toHaveBeenCalledWith(expect.objectContaining({ name: "replacement.png", type: "image/png" }));

    window.dispatchEvent(new Event("focus"));
    mocks.avatar = { ...avatar, updatedAt: "2026-08-20T00:00:01.000Z" };
    view.rerender(<ProfileAvatarEditor onDone={vi.fn()} onCancel={vi.fn()} />);
    await user.click(screen.getByRole("button", { name: "Save photo" }));

    expect(mocks.saveAvatar).toHaveBeenCalledWith(expect.objectContaining({ sourceFilename: "replacement.png" }));
  });

  it("keeps the mobile picker file attached until asynchronous decoding finishes", async () => {
    let finishPreparing!: (record: ProfileAvatarRecord) => void;
    mocks.prepareImage.mockImplementationOnce(() => new Promise<ProfileAvatarRecord>((resolve) => {
      finishPreparing = resolve;
    }));
    render(<ProfileAvatarEditor onDone={vi.fn()} onCancel={vi.fn()} />);
    const input = screen.getByLabelText("Choose another photo") as HTMLInputElement;
    const upload = userEvent.upload(input, new File(["image"], "camera.jpg", { type: "image/jpeg" }));

    await screen.findByText("Processing…");
    expect(input.files).toHaveLength(1);
    finishPreparing({ ...avatar, sourceFilename: "camera.jpg", sourceBlob: new Blob(["image"]), displayBlob: new Blob(["preview"]) });
    await upload;
    expect(input.value).toBe("");
    expect(screen.getByRole("button", { name: "Save photo" })).toBeEnabled();
  });

  it("loads a saved thumbnail as the working photo without activating it before Save", async () => {
    const user = userEvent.setup();
    const second = { ...avatar, id: "photo-2", sourceFilename: "second.webp", displayUrl: "data:image/svg+xml,%3Csvg%20id='second'%20xmlns='http://www.w3.org/2000/svg'/%3E", crop: { focalX: 0.3, focalY: 0.7, zoom: 1.4 } };
    mocks.photos = [avatar, second];
    render(<ProfileAvatarEditor onDone={vi.fn()} onCancel={vi.fn()} />);

    expect(screen.getByText("Active")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Edit saved photo second.webp" }));
    expect(mocks.saveAvatar).not.toHaveBeenCalled();
    expect(screen.getByRole("slider", { name: "Profile photo zoom" })).toHaveValue("1.4");

    await user.click(screen.getByRole("button", { name: "Save photo" }));
    expect(mocks.saveAvatar).toHaveBeenCalledWith(expect.objectContaining({ id: "photo-2", sourceFilename: "second.webp" }));
  });

  it("blocks a fourth upload and explains how to free a slot", () => {
    mocks.photos = [avatar, { ...avatar, id: "photo-2" }, { ...avatar, id: "photo-3" }];
    render(<ProfileAvatarEditor onDone={vi.fn()} onCancel={vi.fn()} />);

    expect(screen.getByText("Three-photo limit reached. Remove a saved photo before choosing another.")).toBeInTheDocument();
    expect(screen.getByLabelText("Choose another photo")).toBeDisabled();
  });

  it("requires confirmation before removing a saved photo", async () => {
    const user = userEvent.setup();
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    render(<ProfileAvatarEditor onDone={vi.fn()} onCancel={vi.fn()} />);

    await user.click(screen.getByRole("button", { name: "Remove saved photo portrait.jpg" }));
    expect(confirm).toHaveBeenCalledWith(expect.stringContaining("active profile photo"));
    expect(mocks.removePhoto).not.toHaveBeenCalled();
  });
});
