export type ProfileImageShape = "circle" | "square";

export const profileImageShapeStorageKey = "fanatical.profile-image-shape.v1";
export const profileImageShapeChangeEvent = "fanatical:profile-image-shape-change";

export function loadProfileImageShape(): ProfileImageShape {
  if (typeof window === "undefined") return "circle";
  return window.localStorage.getItem(profileImageShapeStorageKey) === "square" ? "square" : "circle";
}

export function saveProfileImageShape(shape: ProfileImageShape) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(profileImageShapeStorageKey, shape);
  window.dispatchEvent(new CustomEvent<ProfileImageShape>(profileImageShapeChangeEvent, { detail: shape }));
}
