export type IconName = "news" | "quiz" | "fanbase" | "cheer" | "profile";

type NavIconProps = {
  readonly name: IconName;
};

export function NavIcon({ name }: NavIconProps) {
  const commonProps = {
    "aria-hidden": true,
    className: "nav-icon",
    fill: "none",
    focusable: false,
    stroke: "currentColor",
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
    strokeWidth: 1.8,
    viewBox: "0 0 24 24",
  };

  switch (name) {
    case "news":
      return (
        <svg {...commonProps}>
          <path d="M4 5.5h12.5v13H5.75A1.75 1.75 0 0 1 4 16.75V5.5Z" />
          <path d="M16.5 8H20v8.75a1.75 1.75 0 0 1-1.75 1.75M7 9h6.5M7 12h6.5M7 15h4" />
        </svg>
      );
    case "quiz":
      return (
        <svg {...commonProps}>
          <path d="M4.5 5.5h4v4h-4zM4.5 14.5h4v4h-4zM12 7.5h7.5M12 16.5h7.5M5.5 7.2l1 1 2-2.3" />
        </svg>
      );
    case "fanbase":
      return (
        <svg {...commonProps}>
          <path d="M8.5 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM15.8 10a2.5 2.5 0 1 0 0-5M3 19a5.5 5.5 0 0 1 11 0M14 13.3a4.8 4.8 0 0 1 7 4.2" />
        </svg>
      );
    case "cheer":
      return (
        <svg {...commonProps}>
          <path d="m4 13 10-5v8L4 12v1ZM14 10.5h2.5a2.5 2.5 0 0 1 0 5H14M6.5 14l1.2 5h3.6L10 15.4M19.5 7.5 21 6M20 11h2" />
        </svg>
      );
    case "profile":
      return (
        <svg {...commonProps}>
          <circle cx="12" cy="8" r="3.5" />
          <path d="M5 20a7 7 0 0 1 14 0" />
        </svg>
      );
  }
}
