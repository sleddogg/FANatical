import { NavLink } from "react-router-dom";
import { featureNavigation } from "../app/navigation";
import { BrandMark } from "./BrandMark";
import { FollowedTeamStrip } from "./FollowedTeamStrip";
import { NavIcon } from "./NavIcon";
import { useAuth } from "../features/account/AuthContext";
import { useProfileAvatar } from "../features/profileAvatar/ProfileAvatarContext";
import { ProfileNavigationControl } from "./ProfileNavigationControl";
import { useProfileImageShape } from "../data/profileImageShapePreference";

type BottomNavigationProps = {
  readonly variant: "home" | "inner";
};

export function BottomNavigation({ variant }: BottomNavigationProps) {
  const { user } = useAuth();
  const { avatar } = useProfileAvatar();
  const { shape } = useProfileImageShape();
  return (
    <nav className={`bottom-navigation bottom-navigation--${variant}`} aria-label={variant === "home" ? "Home navigation" : "Application navigation"}>
      <NavLink className="bottom-navigation__link" to="/" end aria-label="FANatical home">
        <BrandMark shape={shape} />
      </NavLink>

      {variant === "home" ? (
        <FollowedTeamStrip />
      ) : (
        <div className="bottom-navigation__feature-links">
          {featureNavigation.map((item) => (
            <NavLink key={item.path} className="bottom-navigation__link" to={item.path} aria-label={item.label}>
              <NavIcon name={item.icon} />
              <span className="visually-hidden">{item.label}</span>
            </NavLink>
          ))}
        </div>
      )}

      <div className="bottom-navigation__account-links">
        <ProfileNavigationControl signedIn={Boolean(user)} avatar={avatar} shape={shape} />
      </div>
    </nav>
  );
}
