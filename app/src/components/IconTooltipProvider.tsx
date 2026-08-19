import { useEffect, useRef, useState, type PropsWithChildren } from "react";
import { createPortal } from "react-dom";

const hoverDelay = 1000;
const controlSelector = "button[aria-label], a[aria-label]";
const iconSelector = ".app-icon, .brand-mark, .profile-avatar-media, .team-badge";

type TooltipState = Readonly<{
  label: string;
  left: number;
  top: number;
  placement: "above" | "below";
}>;

function closestControl(target: EventTarget | null): HTMLElement | null {
  return target instanceof Element ? target.closest<HTMLElement>(controlSelector) : null;
}

function hasVisibleText(control: HTMLElement) {
  const walker = document.createTreeWalker(control, NodeFilter.SHOW_TEXT);
  let node = walker.nextNode();
  while (node) {
    const parent = node.parentElement;
    if (node.textContent?.trim() && !parent?.closest(".visually-hidden, [aria-hidden='true']")) return true;
    node = walker.nextNode();
  }
  return false;
}

function isIconOnlyControl(control: HTMLElement) {
  if (control.matches("[class*='backdrop']")) return false;
  if (hasVisibleText(control)) return false;
  return Boolean(control.dataset.tooltipLabel || control.querySelector(iconSelector) || control.childElementCount === 0);
}

function tooltipFor(control: HTMLElement): TooltipState | null {
  if (!isIconOnlyControl(control)) return null;
  const label = control.dataset.tooltipLabel || control.getAttribute("aria-label")?.trim();
  if (!label) return null;
  const bounds = control.getBoundingClientRect();
  const safeHalfWidth = Math.min(144, Math.max(0, (window.innerWidth - 32) / 2));
  const left = Math.min(window.innerWidth - 16 - safeHalfWidth, Math.max(16 + safeHalfWidth, bounds.left + bounds.width / 2));
  const placement = bounds.top >= 56 ? "above" : "below";
  return {
    label,
    left,
    top: placement === "above" ? bounds.top - 8 : bounds.bottom + 8,
    placement,
  };
}

export function IconTooltipProvider({ children }: PropsWithChildren) {
  const [tooltip, setTooltip] = useState<TooltipState | null>(null);
  const hoverTimer = useRef<number | null>(null);
  const hoveredControl = useRef<HTMLElement | null>(null);
  const keyboardModality = useRef(false);

  useEffect(() => {
    const cancelHover = () => {
      if (hoverTimer.current !== null) window.clearTimeout(hoverTimer.current);
      hoverTimer.current = null;
      hoveredControl.current = null;
    };
    const hide = () => {
      cancelHover();
      setTooltip(null);
    };
    const show = (control: HTMLElement) => setTooltip(tooltipFor(control));

    const pointerOver = (event: PointerEvent) => {
      if (event.pointerType && event.pointerType !== "mouse") return;
      const control = closestControl(event.target);
      if (!control || !isIconOnlyControl(control) || control === hoveredControl.current) return;
      cancelHover();
      hoveredControl.current = control;
      hoverTimer.current = window.setTimeout(() => {
        if (hoveredControl.current === control) show(control);
        hoverTimer.current = null;
      }, hoverDelay);
    };
    const pointerOut = (event: PointerEvent) => {
      const control = closestControl(event.target);
      if (!control || control !== hoveredControl.current) return;
      if (event.relatedTarget instanceof Node && control.contains(event.relatedTarget)) return;
      hide();
    };
    const pointerDown = () => {
      keyboardModality.current = false;
      hide();
    };
    const keyDown = (event: KeyboardEvent) => {
      if (event.metaKey || event.ctrlKey || event.altKey) return;
      keyboardModality.current = true;
    };
    const focusIn = (event: FocusEvent) => {
      if (!keyboardModality.current) return;
      const control = closestControl(event.target);
      if (control) show(control);
    };
    const focusOut = (event: FocusEvent) => {
      const control = closestControl(event.target);
      if (control) hide();
    };

    document.addEventListener("pointerover", pointerOver);
    document.addEventListener("pointerout", pointerOut);
    document.addEventListener("pointerdown", pointerDown, true);
    document.addEventListener("click", hide, true);
    document.addEventListener("keydown", keyDown, true);
    document.addEventListener("focusin", focusIn);
    document.addEventListener("focusout", focusOut);
    window.addEventListener("blur", hide);
    window.addEventListener("resize", hide);
    window.addEventListener("scroll", hide, true);
    return () => {
      cancelHover();
      document.removeEventListener("pointerover", pointerOver);
      document.removeEventListener("pointerout", pointerOut);
      document.removeEventListener("pointerdown", pointerDown, true);
      document.removeEventListener("click", hide, true);
      document.removeEventListener("keydown", keyDown, true);
      document.removeEventListener("focusin", focusIn);
      document.removeEventListener("focusout", focusOut);
      window.removeEventListener("blur", hide);
      window.removeEventListener("resize", hide);
      window.removeEventListener("scroll", hide, true);
    };
  }, []);

  return <>{children}{tooltip ? createPortal(
    <span className="app-icon-tooltip" role="tooltip" data-placement={tooltip.placement} style={{ left: tooltip.left, top: tooltip.top }}>{tooltip.label}</span>,
    document.body,
  ) : null}</>;
}
