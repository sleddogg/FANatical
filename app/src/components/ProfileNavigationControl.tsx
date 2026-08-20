import { NavLink } from "react-router-dom";
import { ProfileAvatarMedia } from "../features/profileAvatar/ProfileAvatarMedia";
import type { ProfileAvatarRecord } from "../features/profileAvatar/types";
import type { ProfileImageShape } from "../data/profileImageShapeStorage";

export function ProfileNavigationControl({ signedIn, avatar, shape = "circle" }: { readonly signedIn: boolean; readonly avatar: ProfileAvatarRecord | null; readonly shape?: ProfileImageShape }) {
  const accessibleLabel = signedIn ? "Profile" : "Sign In";
  return (
    <NavLink className="bottom-navigation__link" to="/profile" aria-label={accessibleLabel} data-tooltip-label="Profile">
      <ProfileAvatarMedia avatar={signedIn ? avatar : null} shape={shape} />
    </NavLink>
  );
}
