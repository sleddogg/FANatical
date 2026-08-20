import { render, screen, within } from "@testing-library/react";
import { createMemoryRouter, RouterProvider } from "react-router-dom";
import { beforeEach, describe, expect, it } from "vitest";
import { appRoutes } from "../app/routes";
import { homeCustomizationStorageKey, saveHomeCustomization } from "../data/homeCustomizationStorage";

function renderHome(layout: "grid" | "stack") {
  saveHomeCustomization({
    textOverlay: { enabled: true, bigText: "Prime Fan", smallText: "FPI OG", position: "top-right" },
    fanCard: {
      enabled: true,
      fieldIds: ["nickname", "jersey-number", "height", "fan-since"],
      layout,
      position: "bottom-left",
    },
  });
  const router = createMemoryRouter(appRoutes, { initialEntries: ["/"] });
  render(<RouterProvider router={router} />);
}

describe("Home overlays", () => {
  beforeEach(() => window.localStorage.removeItem(homeCustomizationStorageKey));

  it("renders only Big and Small text without the FANatical eyebrow", () => {
    renderHome("stack");
    const heading = screen.getByRole("heading", { name: "Prime Fan" });
    const overlay = heading.closest(".home-hero__text-overlay");

    expect(overlay).toHaveTextContent("Prime Fan");
    expect(overlay).toHaveTextContent("FPI OG");
    expect(overlay).not.toHaveTextContent("FANatical");
  });

  it.each(["stack", "grid"] as const)("renders a value-only %s Fan Card", (layout) => {
    renderHome(layout);
    const fanCard = screen.getByLabelText("Fan Card");

    expect(fanCard).toHaveClass(`home-hero__fan-card--${layout}`);
    expect(within(fanCard).getByText("Sleddogg")).toBeInTheDocument();
    expect(within(fanCard).getByText("12")).toBeInTheDocument();
    expect(within(fanCard).getByText("5′ 11″")).toBeInTheDocument();
    expect(within(fanCard).getByText("1996")).toBeInTheDocument();
    expect(within(fanCard).queryByText("Nickname")).not.toBeInTheDocument();
    expect(within(fanCard).queryByText("Jersey number")).not.toBeInTheDocument();
    expect(within(fanCard).queryByText("Height")).not.toBeInTheDocument();
    expect(within(fanCard).queryByText("Fan since")).not.toBeInTheDocument();
  });
});
