import fanaticalMark from "../assets/branding/fanatical.png";
import fanaticalCircleMark from "../assets/branding/fanatical-circle.png";
import type { ProfileImageShape } from "../data/profileImageShapeStorage";

export function BrandMark({ shape = "circle" }: { readonly shape?: ProfileImageShape }) {
  return <img className={`brand-mark brand-mark--${shape}`} src={shape === "circle" ? fanaticalCircleMark : fanaticalMark} alt="" aria-hidden="true" />;
}
