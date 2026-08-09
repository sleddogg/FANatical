import { NavLink } from "react-router-dom";
import { featureNavigation } from "../app/navigation";
import { BrandMark } from "./BrandMark";
import { FollowedTeamStrip } from "./FollowedTeamStrip";
import { NavIcon } from "./NavIcon";

type BottomNavigationProps = {
  readonly variant: "home" | "inner";
};

function navClassName({ isActive }: { isActive: boolean }) {
  return `bottom-navigation__link${isActive ? " bottom-navigation__link--active" : ""}`;
}

export function BottomNavigation({ variant }: BottomNavigationProps) {
  return (
    <nav className="bottom-navigation" aria-label={variant === "home" ? "Home navigation" : "Application navigation"}>
      <NavLink className={navClassName} to="/" end aria-label="FANatical home">
        <BrandMark />
      </NavLink>

      {variant === "home" ? (
        <FollowedTeamStrip />
      ) : (
        <div className="bottom-navigation__feature-links">
          {featureNavigation.map((item) => (
            <NavLink key={item.path} className={navClassName} to={item.path} aria-label={item.label}>
              <NavIcon name={item.icon} />
              <span className="visually-hidden">{item.label}</span>
            </NavLink>
          ))}
        </div>
      )}

      <NavLink className={navClassName} to="/profile" aria-label="Profile">
        <NavIcon name="profile" />
        <span className="visually-hidden">Profile</span>
      </NavLink>
    </nav>
  );
}
