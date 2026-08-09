import type { IconName } from "../components/NavIcon";

export type FeatureNavigationItem = {
  readonly label: "News" | "Quiz" | "FANbase" | "Cheer";
  readonly path: "/news" | "/quiz" | "/fanbase" | "/cheer";
  readonly icon: IconName;
  readonly description: string;
};

export const featureNavigation: readonly FeatureNavigationItem[] = [
  {
    label: "News",
    path: "/news",
    icon: "news",
    description: "Your customizable sports news feed will live here.",
  },
  {
    label: "Quiz",
    path: "/quiz",
    icon: "quiz",
    description: "Sports knowledge and quiz experiences will live here.",
  },
  {
    label: "FANbase",
    path: "/fanbase",
    icon: "fanbase",
    description: "Community discussions and fan activity will live here.",
  },
  {
    label: "Cheer",
    path: "/cheer",
    icon: "cheer",
    description: "The Cheer Library and live fan experiences will live here.",
  },
] as const;
