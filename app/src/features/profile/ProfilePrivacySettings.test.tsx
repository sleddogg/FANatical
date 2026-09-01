import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { ProfilePrivacySettings } from "./ProfilePrivacySettings";

describe("ProfilePrivacySettings", () => {
  it("explains both signed-in audiences and lets the owner choose Private", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(<ProfilePrivacySettings value="members_visible" onChange={onChange} />);

    expect(screen.getByRole("radiogroup", { name: "Who can view your Profile?" })).toBeInTheDocument();
    expect(screen.getByRole("radio", { name: "Members-visible" })).toBeChecked();
    expect(screen.getByText(/Signed-in fans can view your approved Profile fields/)).toBeInTheDocument();
    expect(screen.getByText(/comments still show only your current Fanatical Name and display avatar/)).toBeInTheDocument();

    await user.click(screen.getByRole("radio", { name: "Private profile" }));
    expect(onChange).toHaveBeenCalledWith("private");
  });

  it("requires an account-backed editor before privacy can be changed", () => {
    render(<ProfilePrivacySettings value="members_visible" disabled onChange={vi.fn()} />);
    expect(screen.getByRole("radio", { name: "Members-visible" })).toBeDisabled();
    expect(screen.getByRole("radio", { name: "Private profile" })).toBeDisabled();
    expect(screen.getByText("Sign in to save profile privacy to your FANatical account.")).toBeInTheDocument();
  });
});
