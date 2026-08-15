import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createMemoryRouter, RouterProvider } from "react-router-dom";
import { describe, expect, it } from "vitest";
import { appRoutes } from "../../app/routes";

describe("Personal Sports Stats", () => {
  it("opens from the Profile headline stats and keeps Trophy details separate", async () => {
    const user = userEvent.setup();
    const router = createMemoryRouter(appRoutes, { initialEntries: ["/profile"] });
    render(<RouterProvider router={router} />);

    await user.click(screen.getByRole("link", { name: "View Fan Score details" }));
    expect(screen.getByRole("heading", { name: "NorthStarFan Sports Stats", level: 1 })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Overall Sport IQ" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Fan Score" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Sport IQ breakdown" })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Trophy Case" })).not.toBeInTheDocument();
  });
});
