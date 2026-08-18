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
});
