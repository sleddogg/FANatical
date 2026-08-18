import adjustmentsHorizontal from "../assets/icons/adjustments-horizontal-outline.svg?raw";
import arrowDown from "../assets/icons/arrow-down-outline.svg?raw";
import arrowLeft from "../assets/icons/arrow-left-outline.svg?raw";
import arrowPath from "../assets/icons/arrow-path-outline.svg?raw";
import arrowRight from "../assets/icons/arrow-right-outline.svg?raw";
import arrowTopRightOnSquare from "../assets/icons/arrow-top-right-on-square-outline.svg?raw";
import arrowUp from "../assets/icons/arrow-up-outline.svg?raw";
import arrowUpTray from "../assets/icons/arrow-up-tray-outline.svg?raw";
import arrowUturnRight from "../assets/icons/arrow-uturn-right-outline.svg?raw";
import arrowsPointingIn from "../assets/icons/arrows-pointing-in-outline.svg?raw";
import arrowsPointingOut from "../assets/icons/arrows-pointing-out-outline.svg?raw";
import arrowsUpDown from "../assets/icons/arrows-up-down-outline.svg?raw";
import bars3 from "../assets/icons/bars-3-outline.svg?raw";
import bookmark from "../assets/icons/bookmark-outline.svg?raw";
import bookmarkSolid from "../assets/icons/bookmark-solid.svg?raw";
import calendarDays from "../assets/icons/calendar-days-outline.svg?raw";
import camera from "../assets/icons/camera-outline.svg?raw";
import chartBar from "../assets/icons/chart-bar-outline.svg?raw";
import chartBarSquare from "../assets/icons/chart-bar-square-outline.svg?raw";
import chatBubbleLeftRight from "../assets/icons/chat-bubble-left-right-outline.svg?raw";
import check from "../assets/icons/check-outline.svg?raw";
import checkCircle from "../assets/icons/check-circle-outline.svg?raw";
import cheer from "../assets/icons/cheer.svg?raw";
import chevronDown from "../assets/icons/chevron-down-outline.svg?raw";
import chevronLeft from "../assets/icons/chevron-left-outline.svg?raw";
import chevronRight from "../assets/icons/chevron-right-outline.svg?raw";
import clock from "../assets/icons/clock-outline.svg?raw";
import exclamationTriangle from "../assets/icons/exclamation-triangle-outline.svg?raw";
import eye from "../assets/icons/eye-outline.svg?raw";
import fanbase from "../assets/icons/fanbase.svg?raw";
import fire from "../assets/icons/fire-outline.svg?raw";
import heart from "../assets/icons/heart-outline.svg?raw";
import heartSolid from "../assets/icons/heart-solid.svg?raw";
import informationCircle from "../assets/icons/information-circle-outline.svg?raw";
import lockClosed from "../assets/icons/lock-closed-outline.svg?raw";
import mapPin from "../assets/icons/map-pin-outline.svg?raw";
import newspaper from "../assets/icons/newspaper-outline.svg?raw";
import pencilSquare from "../assets/icons/pencil-square-outline.svg?raw";
import photo from "../assets/icons/photo-outline.svg?raw";
import plus from "../assets/icons/plus-outline.svg?raw";
import quiz from "../assets/icons/quiz.svg?raw";
import share from "../assets/icons/share-outline.svg?raw";
import sparkles from "../assets/icons/sparkles-outline.svg?raw";
import squares2X2 from "../assets/icons/squares-2x2-outline.svg?raw";
import star from "../assets/icons/star-outline.svg?raw";
import starSolid from "../assets/icons/star-solid.svg?raw";
import ticket from "../assets/icons/ticket-outline.svg?raw";
import trophy from "../assets/icons/trophy-outline.svg?raw";
import user from "../assets/icons/user-outline.svg?raw";
import userGroup from "../assets/icons/user-group-outline.svg?raw";
import xMark from "../assets/icons/x-mark-outline.svg?raw";

const iconSources = {
  "adjustments-horizontal": adjustmentsHorizontal,
  "arrow-down": arrowDown,
  "arrow-left": arrowLeft,
  "arrow-path": arrowPath,
  "arrow-right": arrowRight,
  "arrow-top-right-on-square": arrowTopRightOnSquare,
  "arrow-up": arrowUp,
  "arrow-up-tray": arrowUpTray,
  "arrow-uturn-right": arrowUturnRight,
  "arrows-pointing-in": arrowsPointingIn,
  "arrows-pointing-out": arrowsPointingOut,
  "arrows-up-down": arrowsUpDown,
  "bars-3": bars3,
  bookmark,
  "bookmark-solid": bookmarkSolid,
  "calendar-days": calendarDays,
  camera,
  "chart-bar": chartBar,
  "chart-bar-square": chartBarSquare,
  "chat-bubble-left-right": chatBubbleLeftRight,
  check,
  "check-circle": checkCircle,
  cheer,
  "chevron-down": chevronDown,
  "chevron-left": chevronLeft,
  "chevron-right": chevronRight,
  clock,
  "exclamation-triangle": exclamationTriangle,
  eye,
  fanbase,
  fire,
  heart,
  "heart-solid": heartSolid,
  "information-circle": informationCircle,
  "lock-closed": lockClosed,
  "map-pin": mapPin,
  newspaper,
  "pencil-square": pencilSquare,
  photo,
  plus,
  quiz,
  share,
  sparkles,
  "squares-2x2": squares2X2,
  star,
  "star-solid": starSolid,
  ticket,
  trophy,
  user,
  "user-group": userGroup,
  "x-mark": xMark,
} as const;

export type AppIconName = keyof typeof iconSources;

type AppIconProps = Readonly<{
  name: AppIconName;
  className?: string;
}>;

export function AppIcon({ name, className }: AppIconProps) {
  return (
    <span
      className={`app-icon${className ? ` ${className}` : ""}`}
      aria-hidden="true"
      dangerouslySetInnerHTML={{ __html: iconSources[name] }}
    />
  );
}
