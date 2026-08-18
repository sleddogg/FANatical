import { AppIcon } from "./AppIcon";

export type IconName = "news" | "quiz" | "fanbase" | "cheer" | "profile";

type NavIconProps = {
  readonly name: IconName;
};

export function NavIcon({ name }: NavIconProps) {
  const iconNames = { news: "newspaper", quiz: "quiz", fanbase: "fanbase", cheer: "cheer", profile: "user" } as const;
  return <AppIcon className="nav-icon" name={iconNames[name]} />;
}
