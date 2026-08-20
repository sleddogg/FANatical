import { render } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { BrandMark } from "./BrandMark";

describe("BrandMark", () => {
  it("uses the circular production mark only for Circle mode", () => {
    const view = render(<BrandMark shape="circle" />);
    expect(view.container.querySelector("img")).toHaveAttribute("src", expect.stringContaining("fanatical-circle.png"));

    view.rerender(<BrandMark shape="square" />);
    expect(view.container.querySelector("img")).toHaveAttribute("src", expect.stringContaining("fanatical.png"));
  });
});
