import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  user: { id: "user-a" } as { id: string } | null,
  subscriptions: [] as Array<{ callback: () => void; tables: readonly string[] }>,
  avatarSummary: vi.fn(),
  avatarLibrary: vi.fn(),
  deleteAvatar: vi.fn(),
  visualSummary: vi.fn(),
  visualLibrary: vi.fn(),
  deleteVisual: vi.fn(),
}));

vi.mock("../account/AuthContext", () => ({
  useAuth: () => ({ configured: true, loading: false, user: mocks.user }),
}));

vi.mock("../account/accountRepository", () => ({
  subscribeToAccountChanges: (_userId: string, callback: () => void, tables: readonly string[]) => {
    mocks.subscriptions.push({ callback, tables });
    return vi.fn();
  },
}));

vi.mock("../profileAvatar/profileAvatarRepository", () => ({
  activateRemoteProfileAvatar: vi.fn(),
  deleteRemoteProfilePhoto: mocks.deleteAvatar,
  loadRemoteProfileAvatarLibrary: mocks.avatarLibrary,
  loadRemoteProfileAvatarSummary: mocks.avatarSummary,
  uploadRemoteProfileAvatar: vi.fn(),
}));

vi.mock("../profileVisual/profileVisualRepository", () => ({
  activateRemoteProfileVisual: vi.fn(),
  deleteRemoteProfileVisualImage: mocks.deleteVisual,
  loadRemoteProfileVisualLibrary: mocks.visualLibrary,
  loadRemoteProfileVisualSummary: mocks.visualSummary,
  uploadRemoteProfileVisual: vi.fn(),
}));

vi.mock("../profileVisual/profileVisualStorage", () => ({
  deleteProfileVisualImage: vi.fn(),
  loadProfileVisualLibrary: vi.fn(),
  storeProfileVisualImage: vi.fn(),
}));

import { ProfileAvatarProvider, useProfileAvatar } from "../profileAvatar/ProfileAvatarContext";
import type { ProfileAvatarRecord } from "../profileAvatar/types";
import { ProfileVisualProvider, useProfileVisual } from "../profileVisual/ProfileVisualContext";
import type { ProfileVisualImageRecord, ProfileVisualLibrary } from "../profileVisual/types";

function avatar(id: string, displayUrl = `signed:${id}`): ProfileAvatarRecord {
  return {
    id,
    sourceFilename: `${id}.jpg`,
    sourceMediaType: "image/jpeg",
    displayUrl,
    displayPath: `${id}.webp`,
    width: 100,
    height: 100,
    crop: { focalX: 0.5, focalY: 0.5, zoom: 1 },
    updatedAt: "2026-08-22T00:00:00Z",
  };
}

function visual(id: string, variant: "mobile" | "wide", displayUrl = `signed:${id}`): ProfileVisualImageRecord {
  return {
    id,
    variant,
    sourceFilename: `${id}.jpg`,
    displayUrl,
    displayPath: `${id}.webp`,
    width: 100,
    height: 100,
    crop: { focalX: 0.5, focalY: 0.5, zoom: 1 },
    updatedAt: "2026-08-22T00:00:00Z",
  };
}

const avatarA = avatar("avatar-a");
const avatarB = avatar("avatar-b");
const avatarInactive = avatar("avatar-inactive", "");
const visualMobile = visual("visual-mobile", "mobile");
const visualWide = visual("visual-wide", "wide");
const visualInactive = visual("visual-inactive", "wide", "");

function AvatarProbe() {
  const { avatar: active, photos, removePhoto, resolveLibrary } = useProfileAvatar();
  return (
    <>
      <output data-testid="avatar-active">{active?.id ?? "none"}</output>
      <output data-testid="avatar-library">{photos.map((photo) => `${photo.id}:${Boolean(photo.displayUrl)}`).join(",")}</output>
      <button type="button" onClick={() => { void resolveLibrary(); }}>Resolve avatar library</button>
      <button type="button" onClick={() => { void removePhoto(active?.id ?? ""); }}>Delete active avatar</button>
    </>
  );
}

function VisualProbe() {
  const { images, library, resolveLibrary } = useProfileVisual();
  return (
    <>
      <output data-testid="visual-active">{`${images.mobile?.id ?? "none"}|${images.wide?.id ?? "none"}`}</output>
      <output data-testid="visual-library">{library.wide.map((image) => `${image.id}:${Boolean(image.displayUrl)}`).join(",")}</output>
      <button type="button" onClick={() => { void resolveLibrary(); }}>Resolve visual library</button>
    </>
  );
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((resolveValue) => { resolve = resolveValue; });
  return { promise, resolve };
}

describe("profile media provider lifecycle containment", () => {
  beforeEach(() => {
    mocks.user = { id: "user-a" };
    mocks.subscriptions.length = 0;
    mocks.avatarSummary.mockReset().mockResolvedValue({ active: avatarA, photos: [avatarA, avatarInactive] });
    mocks.avatarLibrary.mockReset().mockResolvedValue({ active: avatarA, photos: [avatarA, avatar("avatar-inactive")] });
    mocks.deleteAvatar.mockReset().mockResolvedValue({ active: avatarB, photos: [avatarB] });
    const activeVisuals = { mobile: visualMobile, wide: visualWide };
    const summaryLibrary: ProfileVisualLibrary = { mobile: [visualMobile], wide: [visualWide, visualInactive] };
    const fullLibrary: ProfileVisualLibrary = { mobile: [visualMobile], wide: [visualWide, visual("visual-inactive", "wide")] };
    mocks.visualSummary.mockReset().mockResolvedValue({ images: activeVisuals, library: summaryLibrary });
    mocks.visualLibrary.mockReset().mockResolvedValue({ images: activeVisuals, library: fullLibrary });
    mocks.deleteVisual.mockReset();
  });

  afterEach(() => vi.useRealTimers());

  it("does not reload for a new Auth User object with the same ID or for a fresh focus cycle", async () => {
    const view = render(<ProfileAvatarProvider><AvatarProbe /></ProfileAvatarProvider>);
    await waitFor(() => expect(mocks.avatarSummary).toHaveBeenCalledOnce());

    mocks.user = { id: "user-a" };
    view.rerender(<ProfileAvatarProvider><AvatarProbe /></ProfileAvatarProvider>);
    window.dispatchEvent(new Event("focus"));
    await act(async () => undefined);

    expect(mocks.avatarSummary).toHaveBeenCalledOnce();
  });

  it("keeps remote-device Realtime updates and coalesces a related event burst into one refresh", async () => {
    render(<ProfileAvatarProvider><AvatarProbe /></ProfileAvatarProvider>);
    await waitFor(() => expect(mocks.avatarSummary).toHaveBeenCalledOnce());
    const subscription = mocks.subscriptions.find(({ tables }) => tables.includes("profile_photos"));
    expect(subscription).toBeDefined();

    vi.useFakeTimers();
    act(() => {
      subscription!.callback();
      subscription!.callback();
      subscription!.callback();
    });
    await act(async () => { await vi.advanceTimersByTimeAsync(100); });

    expect(mocks.avatarSummary).toHaveBeenCalledTimes(2);
  });

  it("resolves inactive avatar media only when the editor asks for the full library", async () => {
    render(<ProfileAvatarProvider><AvatarProbe /></ProfileAvatarProvider>);
    await waitFor(() => expect(screen.getByTestId("avatar-library")).toHaveTextContent("avatar-inactive:false"));
    expect(mocks.avatarLibrary).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole("button", { name: "Resolve avatar library" }));
    await waitFor(() => expect(screen.getByTestId("avatar-library")).toHaveTextContent("avatar-inactive:true"));
    expect(mocks.avatarLibrary).toHaveBeenCalledOnce();
  });

  it("ignores a stale avatar response after authenticated identity changes", async () => {
    const oldLoad = deferred<{ active: ProfileAvatarRecord; photos: ProfileAvatarRecord[] }>();
    mocks.avatarSummary.mockImplementation((userId: string) => userId === "user-a"
      ? oldLoad.promise
      : Promise.resolve({ active: avatarB, photos: [avatarB] }));
    const view = render(<ProfileAvatarProvider><AvatarProbe /></ProfileAvatarProvider>);
    await waitFor(() => expect(mocks.avatarSummary).toHaveBeenCalledWith("user-a"));

    mocks.user = { id: "user-b" };
    view.rerender(<ProfileAvatarProvider><AvatarProbe /></ProfileAvatarProvider>);
    await waitFor(() => expect(screen.getByTestId("avatar-active")).toHaveTextContent("avatar-b"));
    await act(async () => { oldLoad.resolve({ active: avatarA, photos: [avatarA] }); });

    expect(screen.getByTestId("avatar-active")).toHaveTextContent("avatar-b");
  });

  it("uses the repository-selected fallback after deleting active avatar media", async () => {
    render(<ProfileAvatarProvider><AvatarProbe /></ProfileAvatarProvider>);
    await waitFor(() => expect(screen.getByTestId("avatar-active")).toHaveTextContent("avatar-a"));
    fireEvent.click(screen.getByRole("button", { name: "Delete active avatar" }));
    await waitFor(() => expect(screen.getByTestId("avatar-active")).toHaveTextContent("avatar-b"));
  });

  it("boots visuals from the active summary and lazily resolves inactive editor thumbnails", async () => {
    render(<ProfileVisualProvider><VisualProbe /></ProfileVisualProvider>);
    await waitFor(() => expect(screen.getByTestId("visual-active")).toHaveTextContent("visual-mobile|visual-wide"));
    expect(screen.getByTestId("visual-library")).toHaveTextContent("visual-inactive:false");
    expect(mocks.visualLibrary).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole("button", { name: "Resolve visual library" }));
    await waitFor(() => expect(screen.getByTestId("visual-library")).toHaveTextContent("visual-inactive:true"));
    expect(mocks.visualLibrary).toHaveBeenCalledOnce();
  });
});
