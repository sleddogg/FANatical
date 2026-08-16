export type NavigationSide = "left" | "right";

export const navigationSideStorageKey = "fanatical.navigation-side.v1";
export const navigationSideChangeEvent = "fanatical:navigation-side-change";

export function loadNavigationSide(): NavigationSide {
  if (typeof window === "undefined") return "left";
  return window.localStorage.getItem(navigationSideStorageKey) === "right" ? "right" : "left";
}

export function saveNavigationSide(side: NavigationSide) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(navigationSideStorageKey, side);
  window.dispatchEvent(new CustomEvent<NavigationSide>(navigationSideChangeEvent, { detail: side }));
}
