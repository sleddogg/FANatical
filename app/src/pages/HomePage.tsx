import { NavLink } from "react-router-dom";
import { featureNavigation } from "../app/navigation";
import { NavIcon } from "../components/NavIcon";

export function HomePage() {
  return (
    <section className="home-hero" aria-labelledby="home-title">
      <nav className="home-hero__shortcuts" aria-label="Feature shortcuts">
        {featureNavigation.map((item) => (
          <NavLink key={item.path} className="home-hero__shortcut" to={item.path} aria-label={item.label}>
            <NavIcon name={item.icon} />
            <span className="visually-hidden">{item.label}</span>
          </NavLink>
        ))}
      </nav>

      <div className="home-hero__content">
        <span className="home-hero__eyebrow">FANatical</span>
        <h1 id="home-title">Your home for fandom.</h1>
        <p>News, knowledge, community, and game-day energy in one connected place.</p>
      </div>
    </section>
  );
}
