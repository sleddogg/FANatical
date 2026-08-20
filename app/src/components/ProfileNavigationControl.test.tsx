import { fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { describe, expect, it } from "vitest";
import type { ProfileAvatarRecord } from "../features/profileAvatar/types";
import { ProfileNavigationControl } from "./ProfileNavigationControl";
import { IconTooltipProvider } from "./IconTooltipProvider";

const avatar: ProfileAvatarRecord = {
  sourceFilename: "fan.jpg",
  sourceMediaType: "image/jpeg",
  displayUrl: "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg'/%3E",
  sourcePath: "user/avatar/source.jpg",
  displayPath: "user/avatar/display.webp",
  width: 1200,
  height: 1600,
  crop: { focalX: 0.4, focalY: 0.6, zoom: 1.5 },
  updatedAt: "2026-08-18T00:00:00.000Z",
};

function renderControl(signedIn: boolean, record: ProfileAvatarRecord | null) {
  return render(
    <MemoryRouter>
      <IconTooltipProvider>
        <ProfileNavigationControl signedIn={signedIn} avatar={record} />
        <Routes><Route path="/profile" element={<h1>Profile destination</h1>} /></Routes>
      </IconTooltipProvider>
    </MemoryRouter>,
  );
}

describe("ProfileNavigationControl", () => {
  it("uses the User icon and Sign In name while logged out", () => {
    renderControl(false, avatar);
    const control = screen.getByRole("link", { name: "Sign In" });
    expect(control.querySelector(".app-icon")).toBeInTheDocument();
    expect(control.querySelector("img")).not.toBeInTheDocument();
    expect(control).toHaveAttribute("data-tooltip-label", "Profile");
  });

  it("uses the User icon for a signed-in account without a photo", () => {
    renderControl(true, null);
    expect(screen.getByRole("link", { name: "Profile" }).querySelector(".app-icon")).toBeInTheDocument();
  });

  it("uses the positioned avatar and keeps Profile navigation intact", async () => {
    const user = userEvent.setup();
    renderControl(true, avatar);
    const control = screen.getByRole("link", { name: "Profile" });
    const image = control.querySelector("img");
    expect(image).toHaveStyle({ objectPosition: "40% 60%", transform: "scale(1.5)" });
    await user.click(control);
    expect(screen.getByRole("heading", { name: "Profile destination" })).toBeInTheDocument();
  });

  it("applies the selected display shape without changing the avatar image", () => {
    render(
      <MemoryRouter>
        <ProfileNavigationControl signedIn avatar={avatar} shape="square" />
      </MemoryRouter>,
    );
    const media = screen.getByRole("link", { name: "Profile" }).querySelector(".profile-avatar-media");
    expect(media).toHaveClass("profile-avatar-media--square");
    expect(media?.querySelector("img")).toBeInTheDocument();
  });

  it("does not show the Profile tooltip from touch-generated focus", () => {
    renderControl(true, avatar);
    const control = screen.getByRole("link", { name: "Profile" });
    fireEvent.pointerDown(control, { pointerType: "touch" });
    fireEvent.focusIn(control);
    fireEvent.pointerOver(control, { pointerType: "touch" });
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
  });

  it("shows the Profile tooltip for keyboard focus", () => {
    renderControl(true, avatar);
    const control = screen.getByRole("link", { name: "Profile" });
    fireEvent.keyDown(document, { key: "Tab" });
    fireEvent.focusIn(control);
    expect(screen.getByRole("tooltip")).toHaveTextContent("Profile");
  });
});
