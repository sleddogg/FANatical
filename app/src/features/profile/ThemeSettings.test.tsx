import { fireEvent, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useState } from "react";
import { describe, expect, it } from "vitest";
import { officialTeamToFollowedTeam } from "../../data/followedTeams";
import { defaultThemePreference, type ThemePreference } from "../../theme/theme";
import { ThemeSettings } from "./ThemeSettings";

const oilers = officialTeamToFollowedTeam("hockey-nhl-edmonton-oilers")!;
const patriots = officialTeamToFollowedTeam("football-nfl-new-england-patriots")!;

function ThemeSettingsHarness() {
  const [value, setValue] = useState<ThemePreference>({ ...defaultThemePreference, source: "custom" });
  return <ThemeSettings value={value} favoriteTeam={oilers} currentTeam={patriots} onChange={setValue} />;
}

describe("Theme Settings", () => {
  it("edits custom colors and applies the shared swap setting", async () => {
    const user = userEvent.setup();
    render(<ThemeSettingsHarness />);

    fireEvent.change(screen.getByLabelText("Choose Custom Color 1"), { target: { value: "#123456" } });
    expect(screen.getByLabelText("Choose Custom Color 1")).toHaveValue("#123456");

    await user.click(screen.getByRole("radio", { name: "Swapped" }));
    expect(screen.getByRole("radio", { name: "Swapped" })).toBeChecked();
    const preview = screen.getByLabelText("Custom theme color scale preview");
    expect(preview).toHaveTextContent("#D14520");
    expect(preview).toHaveTextContent("#123456");
    expect(within(preview).getAllByText("15")).toHaveLength(2);
    expect(within(preview).getAllByText("40")).toHaveLength(2);
    expect(within(preview).getAllByText("80")).toHaveLength(2);
    expect(within(preview).getAllByText("100")).toHaveLength(2);
    expect(within(preview).queryByText("5")).not.toBeInTheDocument();
    expect(within(preview).queryByText("50")).not.toBeInTheDocument();
  });
});
