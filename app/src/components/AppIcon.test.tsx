import { render } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { AppIcon, type AppIconName } from "./AppIcon";

const representativeIcons: readonly AppIconName[] = [
  "arrow-left",
  "plus",
  "fire",
  "calendar-days",
  "check-circle",
  "chart-bar",
  "newspaper",
  "quiz",
  "fanbase",
  "cheer",
  "user",
];

const materialDesignIcons: readonly AppIconName[] = [
  "mdi-baseball-bat",
  "mdi-baseball-outline",
  "mdi-basketball",
  "mdi-football",
  "mdi-football-australian",
  "mdi-football-helmet",
  "mdi-hockey-puck",
  "mdi-hockey-sticks",
  "mdi-locker-multiple",
  "mdi-rugby",
  "mdi-soccer",
  "mdi-strategy",
];

describe("AppIcon", () => {
  it.each(representativeIcons)("renders %s as an inline SVG shape", (name) => {
    const { container } = render(<AppIcon name={name} />);
    const wrapper = container.querySelector(".app-icon");
    const svg = wrapper?.querySelector("svg");

    expect(wrapper).toHaveAttribute("aria-hidden", "true");
    expect(svg).toBeInTheDocument();
    expect(svg).toHaveAttribute("viewBox", "0 0 24 24");
    expect(svg?.querySelector("path, rect, circle, polygon, polyline, line")).toBeInTheDocument();
    expect(wrapper).not.toHaveStyle({ backgroundColor: "currentColor" });
  });

  it.each(materialDesignIcons)("renders %s with the shared currentColor behavior", (name) => {
    const { container } = render(<AppIcon name={name} />);
    const svg = container.querySelector(".app-icon > svg");

    expect(svg).toHaveAttribute("viewBox", "0 0 24 24");
    expect(svg).toHaveAttribute("fill", "currentColor");
    expect(svg?.querySelector("path")).toBeInTheDocument();
  });
});
