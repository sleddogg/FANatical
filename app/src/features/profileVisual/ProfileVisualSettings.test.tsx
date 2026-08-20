import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { ProfileVisualImageRecord, ProfileVisualLibrary } from "./types";

const mocks = vi.hoisted(() => ({
  images: {} as Partial<Record<"mobile" | "wide", ProfileVisualImageRecord>>,
  library: { mobile: [], wide: [] } as ProfileVisualLibrary,
  saveImage: vi.fn(),
  removeImage: vi.fn(),
  prepareImage: vi.fn(),
}));

const dataUrl = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg'/%3E";
const mobile: ProfileVisualImageRecord = {
  id: "mobile-1",
  variant: "mobile",
  sourceFilename: "mobile.jpg",
  sourceMediaType: "image/jpeg",
  displayUrl: dataUrl,
  sourcePath: "user/profile-visual/mobile/source.jpg",
  displayPath: "user/profile-visual/mobile/display.webp",
  width: 1200,
  height: 1600,
  crop: { focalX: 0.5, focalY: 0.5, zoom: 1 },
  updatedAt: "2026-08-20T00:00:00.000Z",
};
const wide: ProfileVisualImageRecord = {
  ...mobile,
  id: "wide-1",
  variant: "wide",
  sourceFilename: "wide.jpg",
  sourcePath: "user/profile-visual/wide/source.jpg",
  displayPath: "user/profile-visual/wide/display.webp",
  width: 1600,
  height: 900,
};

vi.mock("./ProfileVisualContext", () => ({
  useProfileVisual: () => ({
    images: mocks.images,
    library: mocks.library,
    saveImage: mocks.saveImage,
    removeImage: mocks.removeImage,
  }),
}));

vi.mock("./profileVisualStorage", () => ({
  prepareProfileVisualImage: mocks.prepareImage,
}));

import { ProfileVisualSettings } from "./ProfileVisualSettings";

describe("ProfileVisualSettings", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.images = { mobile, wide };
    mocks.library = { mobile: [mobile], wide: [wide] };
    mocks.saveImage.mockImplementation(async (record: ProfileVisualImageRecord) => ({ ...record, id: record.id ?? "saved-image" }));
    mocks.removeImage.mockResolvedValue(undefined);
  });

  it("keeps a first-attempt mobile picker selection through an active-record refresh and saves only on command", async () => {
    const user = userEvent.setup();
    const { id: _existingId, ...mobileWithoutId } = mobile;
    const replacement: ProfileVisualImageRecord = {
      ...mobileWithoutId,
      sourceFilename: "phone-camera.jpg",
      sourceBlob: new Blob(["source"], { type: "image/jpeg" }),
      displayUrl: dataUrl,
      crop: { focalX: 0.5, focalY: 0.5, zoom: 1 },
    };
    mocks.prepareImage.mockResolvedValueOnce(replacement);
    const view = render(<ProfileVisualSettings />);

    await user.upload(screen.getByLabelText("Choose Mobile Visual"), new File(["image"], "phone-camera.jpg", { type: "image/jpeg" }));
    expect(mocks.prepareImage).toHaveBeenCalledWith("mobile", expect.objectContaining({ name: "phone-camera.jpg" }));
    expect(mocks.saveImage).not.toHaveBeenCalled();

    mocks.images = { mobile: { ...mobile, updatedAt: "2026-08-20T00:00:01.000Z" }, wide };
    view.rerender(<ProfileVisualSettings />);
    await user.click(screen.getAllByRole("button", { name: "Save image" })[0]!);

    expect(mocks.saveImage).toHaveBeenCalledWith(expect.objectContaining({ sourceFilename: "phone-camera.jpg" }));
  });

  it("keeps a first-attempt Wide picker selection through an active-record refresh", async () => {
    const user = userEvent.setup();
    const { id: _existingId, ...wideWithoutId } = wide;
    mocks.prepareImage.mockResolvedValueOnce({
      ...wideWithoutId,
      sourceFilename: "wide-from-files.png",
      sourceBlob: new Blob(["source"], { type: "image/png" }),
      displayUrl: dataUrl,
    });
    const view = render(<ProfileVisualSettings />);

    await user.upload(screen.getByLabelText("Choose Wide Visual"), new File(["image"], "wide-from-files.png", { type: "image/png" }));
    window.dispatchEvent(new Event("focus"));
    mocks.images = { mobile, wide: { ...wide, updatedAt: "2026-08-20T00:00:01.000Z" } };
    view.rerender(<ProfileVisualSettings />);
    await user.click(screen.getAllByRole("button", { name: "Save image" })[1]!);

    expect(mocks.saveImage).toHaveBeenCalledWith(expect.objectContaining({ sourceFilename: "wide-from-files.png" }));
  });

  it("keeps Mobile and Wide libraries independent and blocks a fourth image in either role", () => {
    mocks.library = {
      mobile: [mobile, { ...mobile, id: "mobile-2" }, { ...mobile, id: "mobile-3" }],
      wide: [wide, { ...wide, id: "wide-2" }, { ...wide, id: "wide-3" }],
    };
    render(<ProfileVisualSettings />);

    expect(screen.getByLabelText("Choose Mobile Visual")).toBeDisabled();
    expect(screen.getByLabelText("Choose Wide Visual")).toBeDisabled();
    expect(screen.getAllByText("Three-image limit reached. Remove a saved image before choosing another.")).toHaveLength(2);
  });

  it("keeps a compatibility thumbnail contained when a pre-library record has no image id", () => {
    const { id: _mobileId, ...legacyMobile } = mobile;
    mocks.images = { mobile: legacyMobile, wide };
    mocks.library = { mobile: [legacyMobile], wide: [wide] };
    render(<ProfileVisualSettings />);

    const select = screen.getByRole("button", { name: "Edit saved Mobile Visual mobile.jpg" });
    expect(select).toHaveClass("profile-saved-image-library__select");
    expect(screen.queryByRole("button", { name: "Remove saved Mobile Visual mobile.jpg" })).not.toBeInTheDocument();
    expect(screen.getByRole("region", { name: "Saved Mobile images" })).toContainElement(select);
  });

  it("loads a saved role image with its crop without activating it until Save", async () => {
    const user = userEvent.setup();
    const second = { ...mobile, id: "mobile-2", sourceFilename: "mobile-two.webp", crop: { focalX: 0.25, focalY: 0.75, zoom: 1.6 } };
    mocks.library = { mobile: [mobile, second], wide: [wide] };
    render(<ProfileVisualSettings />);

    await user.click(screen.getByRole("button", { name: "Edit saved Mobile Visual mobile-two.webp" }));
    expect(mocks.saveImage).not.toHaveBeenCalled();
    expect(screen.getByRole("slider", { name: "Mobile Visual Zoom" })).toHaveValue("1.6");

    await user.click(screen.getAllByRole("button", { name: "Save image" })[0]!);
    expect(mocks.saveImage).toHaveBeenCalledWith(expect.objectContaining({ id: "mobile-2" }));
  });

  it("cancels a working visual without saving or changing the active image", async () => {
    const user = userEvent.setup();
    const second = { ...wide, id: "wide-2", sourceFilename: "wide-two.webp" };
    mocks.library = { mobile: [mobile], wide: [wide, second] };
    render(<ProfileVisualSettings />);

    await user.click(screen.getByRole("button", { name: "Edit saved Wide Visual wide-two.webp" }));
    await user.click(screen.getAllByRole("button", { name: "Cancel changes" })[1]!);
    expect(mocks.saveImage).not.toHaveBeenCalled();
    expect(screen.getByRole("button", { name: "Edit saved Wide Visual wide.jpg" })).toHaveAttribute("aria-pressed", "true");
  });

  it("requires confirmation before removing a saved role image", async () => {
    const user = userEvent.setup();
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    render(<ProfileVisualSettings />);

    await user.click(screen.getByRole("button", { name: "Remove saved Mobile Visual mobile.jpg" }));
    expect(confirm).toHaveBeenCalledWith(expect.stringContaining("active Mobile Visual"));
    expect(mocks.removeImage).not.toHaveBeenCalled();
  });
});
