import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { NavLink } from "react-router-dom";
import { featureNavigation } from "../app/navigation";
import { NavIcon } from "../components/NavIcon";
import { useHomeCustomization } from "../data/homeCustomizationPreference";
import { useNavigationSide } from "../data/navigationSidePreference";
import { useAccountBootstrap } from "../features/account/AccountBootstrap";
import { loadOwnedProfile, subscribeToAccountChanges } from "../features/account/accountRepository";
import { useAuth } from "../features/account/AuthContext";
import { initialProfile } from "../features/profile/mockProfileData";
import type { ProfileField, ProfileRecord } from "../features/profile/types";
import { ProfileVisualMedia } from "../features/profileVisual/ProfileVisualMedia";
import { useProfileVisual } from "../features/profileVisual/ProfileVisualContext";
import { resolveHomeOverlayPositions, type ResolvedHomeOverlayPositions } from "./homeOverlayLayout";

function equalPositions(first: ResolvedHomeOverlayPositions, second: ResolvedHomeOverlayPositions) {
  return first.textOverlay === second.textOverlay && first.fanCard === second.fanCard;
}

export function HomePage() {
  const { configured, user } = useAuth();
  const { ready, revision } = useAccountBootstrap();
  const { side } = useNavigationSide();
  const { customization } = useHomeCustomization();
  const { images } = useProfileVisual();
  const frameRef = useRef<HTMLElement>(null);
  const navigationRef = useRef<HTMLElement>(null);
  const textOverlayRef = useRef<HTMLDivElement>(null);
  const fanCardRef = useRef<HTMLDivElement>(null);
  const [profile, setProfile] = useState<ProfileRecord>(initialProfile);
  const [visualLayout, setVisualLayout] = useState<"mobile" | "wide">("mobile");
  const preferredPositions = useMemo<ResolvedHomeOverlayPositions>(() => ({
    ...(customization.textOverlay.enabled ? { textOverlay: customization.textOverlay.position } : {}),
    ...(customization.fanCard.enabled ? { fanCard: customization.fanCard.position } : {}),
  }), [customization]);
  const [resolvedPositions, setResolvedPositions] = useState<ResolvedHomeOverlayPositions>(preferredPositions);

  useEffect(() => {
    if (!configured || !user || !ready) {
      if (!user) setProfile(initialProfile);
      return;
    }
    let current = true;
    const load = () => loadOwnedProfile(user.id).then((record) => {
      if (current && record) setProfile(record);
    }).catch((error: unknown) => console.error("FANatical could not refresh the Home Fan Card Profile fields.", error));
    void load();
    const unsubscribe = subscribeToAccountChanges(user.id, load, ["profiles", "fan_identities"]);
    return () => { current = false; unsubscribe(); };
  }, [configured, ready, revision, user]);

  const fanCardFields = useMemo(() => {
    const profileFields = new Map([...profile.bio, ...profile.fanIdentity].map((field) => [field.id, field]));
    return customization.fanCard.fieldIds
      .map((fieldId) => profileFields.get(fieldId))
      .filter((field): field is ProfileField => Boolean(field?.value.trim()));
  }, [customization.fanCard.fieldIds, profile]);

  const measureLayout = useCallback(() => {
    const frame = frameRef.current;
    const navigation = navigationRef.current;
    if (!frame || !navigation) return;
    const frameRectangle = frame.getBoundingClientRect();
    const navigationRectangle = navigation.getBoundingClientRect();
    if (frameRectangle.height <= 0 || frameRectangle.width <= 0) return;
    setVisualLayout(frameRectangle.width / frameRectangle.height >= 4 / 3 ? "wide" : "mobile");
    const textRectangle = textOverlayRef.current?.getBoundingClientRect();
    const fanCardRectangle = fanCardRef.current?.getBoundingClientRect();
    const next = resolveHomeOverlayPositions(preferredPositions, {
      container: { width: frameRectangle.width, height: frameRectangle.height },
      navigation: {
        left: navigationRectangle.left - frameRectangle.left,
        top: navigationRectangle.top - frameRectangle.top,
        width: navigationRectangle.width,
        height: navigationRectangle.height,
      },
      edge: Math.max(16, Math.min(frameRectangle.width * 0.04, 32)),
      ...(textRectangle ? { textOverlay: { width: textRectangle.width, height: textRectangle.height } } : {}),
      ...(fanCardRectangle ? { fanCard: { width: fanCardRectangle.width, height: fanCardRectangle.height } } : {}),
    });
    setResolvedPositions((current) => equalPositions(current, next) ? current : next);
  }, [preferredPositions]);

  useLayoutEffect(() => {
    measureLayout();
    window.addEventListener("resize", measureLayout);
    const observer = typeof ResizeObserver === "undefined" ? null : new ResizeObserver(measureLayout);
    if (frameRef.current) observer?.observe(frameRef.current);
    if (navigationRef.current) observer?.observe(navigationRef.current);
    if (textOverlayRef.current) observer?.observe(textOverlayRef.current);
    if (fanCardRef.current) observer?.observe(fanCardRef.current);
    return () => { window.removeEventListener("resize", measureLayout); observer?.disconnect(); };
  }, [fanCardFields, measureLayout]);

  const activeImage = visualLayout === "wide" ? images.wide ?? images.mobile : images.mobile ?? images.wide;
  const showTextOverlay = customization.textOverlay.enabled;
  const showFanCard = customization.fanCard.enabled && fanCardFields.length > 0;

  return (
    <section className="home-hero" aria-label="FANatical Home" data-profile-visual-layout={visualLayout} data-has-custom-image={Boolean(activeImage)} ref={frameRef}>
      {activeImage ? <ProfileVisualMedia className="home-hero__profile-visual" record={activeImage} /> : null}
      <nav ref={navigationRef} className={`home-hero__shortcuts home-hero__shortcuts--${side}`} aria-label="Feature shortcuts">
        {featureNavigation.map((item) => (
          <NavLink key={item.path} className="home-hero__shortcut" to={item.path} aria-label={item.label}>
            <NavIcon name={item.icon} />
            <span className="visually-hidden">{item.label}</span>
          </NavLink>
        ))}
      </nav>

      {showTextOverlay ? <div ref={textOverlayRef} className="home-hero__overlay home-hero__text-overlay" data-position={resolvedPositions.textOverlay ?? customization.textOverlay.position} data-requested-position={customization.textOverlay.position}>
        {customization.textOverlay.bigText ? <h1 id="home-title">{customization.textOverlay.bigText}</h1> : null}
        {customization.textOverlay.smallText ? <p>{customization.textOverlay.smallText}</p> : null}
      </div> : null}

      {showFanCard ? <div ref={fanCardRef} className={`home-hero__overlay home-hero__fan-card home-hero__fan-card--${customization.fanCard.layout}`} data-position={resolvedPositions.fanCard ?? customization.fanCard.position} data-requested-position={customization.fanCard.position} aria-label="Fan Card">
        <ul>{fanCardFields.map((field) => <li key={field.id}>{field.value}</li>)}</ul>
      </div> : null}
    </section>
  );
}
