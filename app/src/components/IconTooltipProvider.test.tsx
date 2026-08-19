import { act, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AppIcon } from "./AppIcon";
import { IconTooltipProvider } from "./IconTooltipProvider";

function renderControls() {
  render(
    <IconTooltipProvider>
      <button type="button" aria-label="Add item"><AppIcon name="plus" /></button>
      <button type="button" aria-label="Save item"><AppIcon name="check" /><span>Save</span></button>
    </IconTooltipProvider>,
  );
}

describe("IconTooltipProvider", () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it("waits for one continuous second of mouse hover", () => {
    renderControls();
    const add = screen.getByRole("button", { name: "Add item" });
    fireEvent.pointerOver(add, { pointerType: "mouse" });
    act(() => vi.advanceTimersByTime(999));
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
    act(() => vi.advanceTimersByTime(1));
    expect(screen.getByRole("tooltip")).toHaveTextContent("Add item");
  });

  it("cancels hover before the delay and ignores text buttons", () => {
    renderControls();
    const add = screen.getByRole("button", { name: "Add item" });
    fireEvent.pointerOver(add, { pointerType: "mouse" });
    fireEvent.pointerOut(add, { pointerType: "mouse" });
    act(() => vi.advanceTimersByTime(1000));
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();

    fireEvent.pointerOver(screen.getByRole("button", { name: "Save item" }), { pointerType: "mouse" });
    act(() => vi.advanceTimersByTime(1000));
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
  });

  it("shows immediately for intentional keyboard focus", () => {
    renderControls();
    const add = screen.getByRole("button", { name: "Add item" });
    fireEvent.keyDown(document, { key: "Tab" });
    fireEvent.focusIn(add);
    expect(screen.getByRole("tooltip")).toHaveTextContent("Add item");
  });

  it("does not show or retain a tooltip after a touch tap and focus", () => {
    renderControls();
    const add = screen.getByRole("button", { name: "Add item" });
    fireEvent.pointerDown(add, { pointerType: "touch" });
    fireEvent.focusIn(add);
    fireEvent.pointerOver(add, { pointerType: "touch" });
    act(() => vi.advanceTimersByTime(1500));
    expect(screen.queryByRole("tooltip")).not.toBeInTheDocument();
    expect(add).toHaveAccessibleName("Add item");
  });
});
