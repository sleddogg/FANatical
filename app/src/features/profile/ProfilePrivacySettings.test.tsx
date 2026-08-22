import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { ProfilePrivacySettings } from "./ProfilePrivacySettings";

describe("ProfilePrivacySettings", () => {
  it("explains both supported audiences and lets the owner choose Private", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(<ProfilePrivacySettings value="public" onChange={onChange} />);

    expect(screen.getByRole("radiogroup", { name: "Who can view your Profile?" })).toBeInTheDocument();
    expect(screen.getByRole("radio", { name: "Public profile" })).toBeChecked();
    expect(screen.getByText(/Others can view your Profile and its display media/)).toBeInTheDocument();
    expect(screen.getByText(/Only you can view your Profile for now/)).toBeInTheDocument();

    await user.click(screen.getByRole("radio", { name: "Private profile" }));
    expect(onChange).toHaveBeenCalledWith("private");
  });

  it("requires an account-backed editor before privacy can be changed", () => {
    render(<ProfilePrivacySettings value="public" disabled onChange={vi.fn()} />);
    expect(screen.getByRole("radio", { name: "Public profile" })).toBeDisabled();
    expect(screen.getByRole("radio", { name: "Private profile" })).toBeDisabled();
    expect(screen.getByText("Sign in to save profile privacy to your FANatical account.")).toBeInTheDocument();
  });
});
