import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createMemoryRouter, RouterProvider } from "react-router-dom";
import { beforeEach, describe, expect, it } from "vitest";
import { appRoutes } from "../../../app/routes";
import { rexallStorageKey } from "./rexallVenueData";

describe("internal venue routes", () => {
  beforeEach(() => window.localStorage.removeItem(rexallStorageKey));

  it("opens the mapping outside fan navigation and links to the tester", async () => {
    const user = userEvent.setup();
    const router = createMemoryRouter(appRoutes, { initialEntries: ["/internal/venues/rexall-place"] });
    render(<RouterProvider router={router} />);
    expect(screen.getByRole("heading", { name: "Rexall Place", level: 1 })).toBeInTheDocument();
    expect(screen.queryByRole("navigation", { name: "Primary" })).not.toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Mapping overview" })).toBeInTheDocument();
    expect(screen.getByText(/upper long side = Side A, lower long side = Side B, left half = End A, right half = End B/)).toBeInTheDocument();
    await user.click(screen.getByRole("link", { name: /Open Seat Resolver Tester/ }));
    expect(await screen.findByRole("heading", { name: "Rexall Place Seat Resolver Tester" })).toBeInTheDocument();
  });

  it("resolves the seeded seat and shows rule-level explanations", async () => {
    const user = userEvent.setup();
    const router = createMemoryRouter(appRoutes, { initialEntries: ["/internal/venues/rexall-place/test"] });
    render(<RouterProvider router={router} />);
    await user.click(screen.getByRole("button", { name: "Resolve Seat" }));
    expect(screen.getByText("Lower · Side A · End A")).toBeInTheDocument();
    expect(screen.getByText("Edmonton Oil Kings · Lower only")).toBeInTheDocument();
    expect(screen.getByText("Both sides · Both ends")).toBeInTheDocument();
    expect(screen.getAllByText("Section 114 mapping")).toHaveLength(3);
  });
});
