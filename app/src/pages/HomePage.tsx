import { useLayoutEffect, useRef, useState } from "react";
import { NavLink } from "react-router-dom";
import { featureNavigation } from "../app/navigation";
import { NavIcon } from "../components/NavIcon";
import { useNavigationSide } from "../data/navigationSidePreference";
import { ProfileVisualMedia } from "../features/profileVisual/ProfileVisualMedia";
import { useProfileVisual } from "../features/profileVisual/ProfileVisualContext";

export function HomePage() {
  const { side } = useNavigationSide();
  const { images } = useProfileVisual();
  const frameRef = useRef<HTMLElement>(null);
  const [visualLayout, setVisualLayout] = useState<"mobile" | "wide">("mobile");

  useLayoutEffect(() => {
    const frame = frameRef.current;
    if (!frame) return;
    const measure = () => {
      const { width, height } = frame.getBoundingClientRect();
      if (height > 0) setVisualLayout(width / height >= 4 / 3 ? "wide" : "mobile");
    };
    measure();
    window.addEventListener("resize", measure);
    const observer = typeof ResizeObserver === "undefined" ? null : new ResizeObserver(measure);
    observer?.observe(frame);
    return () => { window.removeEventListener("resize", measure); observer?.disconnect(); };
  }, []);

  const activeImage = visualLayout === "wide" ? images.wide ?? images.mobile : images.mobile ?? images.wide;

  return (
    <section className="home-hero" aria-labelledby="home-title" data-profile-visual-layout={visualLayout} data-has-custom-image={Boolean(activeImage)} ref={frameRef}>
      {activeImage ? <ProfileVisualMedia className="home-hero__profile-visual" record={activeImage} /> : null}
      <nav className={`home-hero__shortcuts home-hero__shortcuts--${side}`} aria-label="Feature shortcuts">
        {featureNavigation.map((item) => (
          <NavLink key={item.path} className="home-hero__shortcut" to={item.path} aria-label={item.label}>
            <NavIcon name={item.icon} />
            <span className="home-hero__shortcut-tooltip" aria-hidden="true">{item.label}</span>
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
