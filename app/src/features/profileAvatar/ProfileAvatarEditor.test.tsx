import { fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { ProfileAvatarRecord } from "./types";

const mocks = vi.hoisted(() => ({
  saveAvatar: vi.fn(),
  removeAvatar: vi.fn(),
}));

const avatar: ProfileAvatarRecord = {
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
    avatar,
    loading: false,
    saveAvatar: mocks.saveAvatar,
    saveCrop: vi.fn(),
    removeAvatar: mocks.removeAvatar,
  }),
}));

import { ProfileAvatarEditor } from "./ProfileAvatarEditor";

describe("ProfileAvatarEditor", () => {
  beforeEach(() => vi.clearAllMocks());

  it("shows the fixed circular preview and saves zoom changes", async () => {
    const user = userEvent.setup();
    const onDone = vi.fn();
    render(<ProfileAvatarEditor onDone={onDone} onCancel={vi.fn()} />);

    expect(screen.getByRole("group", { name: "Profile photo positioning area" })).toBeInTheDocument();
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
});
