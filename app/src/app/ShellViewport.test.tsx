import { render, screen } from "@testing-library/react";
import { createMemoryRouter, RouterProvider } from "react-router-dom";
import { describe, expect, it } from "vitest";
import { appRoutes } from "./routes";

const representativeWidths = [
  ["phone", 390],
  ["tablet", 768],
  ["laptop", 1280],
  ["desktop", 1920],
] as const;

describe("responsive shell baseline", () => {
  it.each(representativeWidths)("renders the core shell at %s width", (_label, width) => {
    Object.defineProperty(window, "innerWidth", { configurable: true, value: width });
    window.dispatchEvent(new Event("resize"));

    const router = createMemoryRouter(appRoutes, { initialEntries: ["/"] });
    render(<RouterProvider router={router} />);

    expect(screen.getByRole("main")).toBeInTheDocument();
    expect(screen.getByRole("navigation", { name: "Feature shortcuts" })).toBeInTheDocument();
    expect(screen.getByRole("navigation", { name: "Home navigation" })).toBeInTheDocument();
  });
});
