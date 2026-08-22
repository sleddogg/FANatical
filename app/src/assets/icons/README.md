# FANatical icon assets

This folder contains three distinct asset groups.

## Original FANatical artwork

These files are original FANatical navigation artwork and are not derived from Heroicons:

- `quiz.svg`
- `fanbase.svg`
- `cheer.svg`

## Tailwind Labs Heroicons

All files ending in `-outline.svg` or `-solid.svg` in the table below are unmodified optimized SVG copies from the official Tailwind Labs Heroicons repository.

- Project: Heroicons
- Release: `v2.2.0`
- Upstream commit: `0435d4ca364a608cc75e2f8683d374e55abbae26`
- Official repository: <https://github.com/tailwindlabs/heroicons>
- Upstream source paths: `optimized/24/outline/` and `optimized/24/solid/`
- License: MIT; see `HEROICONS-LICENSE.txt`

Local filenames include the Heroicons style so outline and solid variants can coexist without ambiguity.

| Heroicons identity | Style | Local file |
| --- | --- | --- |
| `NewspaperIcon` | 24 outline | `newspaper-outline.svg` |
| `UserIcon` | 24 outline | `user-outline.svg` |
| `PlusIcon` | 24 outline | `plus-outline.svg` |
| `ArrowLeftIcon` | 24 outline | `arrow-left-outline.svg` |
| `ArrowRightIcon` | 24 outline | `arrow-right-outline.svg` |
| `ChevronLeftIcon` | 24 outline | `chevron-left-outline.svg` |
| `ChevronRightIcon` | 24 outline | `chevron-right-outline.svg` |
| `ChevronDownIcon` | 24 outline | `chevron-down-outline.svg` |
| `ArrowUpIcon` | 24 outline | `arrow-up-outline.svg` |
| `ArrowDownIcon` | 24 outline | `arrow-down-outline.svg` |
| `ArrowsUpDownIcon` | 24 outline | `arrows-up-down-outline.svg` |
| `XMarkIcon` | 24 outline | `x-mark-outline.svg` |
| `Bars3Icon` | 24 outline | `bars-3-outline.svg` |
| `AdjustmentsHorizontalIcon` | 24 outline | `adjustments-horizontal-outline.svg` |
| `PencilSquareIcon` | 24 outline | `pencil-square-outline.svg` |
| `CheckIcon` | 24 outline | `check-outline.svg` |
| `CheckCircleIcon` | 24 outline | `check-circle-outline.svg` |
| `ShareIcon` | 24 outline | `share-outline.svg` |
| `ArrowTopRightOnSquareIcon` | 24 outline | `arrow-top-right-on-square-outline.svg` |
| `ArrowPathIcon` | 24 outline | `arrow-path-outline.svg` |
| `ArrowUturnRightIcon` | 24 outline | `arrow-uturn-right-outline.svg` |
| `ArrowsPointingOutIcon` | 24 outline | `arrows-pointing-out-outline.svg` |
| `ArrowsPointingInIcon` | 24 outline | `arrows-pointing-in-outline.svg` |
| `ArrowUpTrayIcon` | 24 outline | `arrow-up-tray-outline.svg` |
| `CameraIcon` | 24 outline | `camera-outline.svg` |
| `PhotoIcon` | 24 outline | `photo-outline.svg` |
| `LockClosedIcon` | 24 outline | `lock-closed-outline.svg` |
| `MapPinIcon` | 24 outline | `map-pin-outline.svg` |
| `TicketIcon` | 24 outline | `ticket-outline.svg` |
| `HeartIcon` | 24 outline | `heart-outline.svg` |
| `HeartIcon` | 24 solid | `heart-solid.svg` |
| `BookmarkIcon` | 24 outline | `bookmark-outline.svg` |
| `BookmarkIcon` | 24 solid | `bookmark-solid.svg` |
| `ChatBubbleLeftRightIcon` | 24 outline | `chat-bubble-left-right-outline.svg` |
| `EyeIcon` | 24 outline | `eye-outline.svg` |
| `StarIcon` | 24 outline | `star-outline.svg` |
| `StarIcon` | 24 solid | `star-solid.svg` |
| `CalendarDaysIcon` | 24 outline | `calendar-days-outline.svg` |
| `UserGroupIcon` | 24 outline | `user-group-outline.svg` |
| `ChartBarIcon` | 24 outline | `chart-bar-outline.svg` |
| `ChartBarSquareIcon` | 24 outline | `chart-bar-square-outline.svg` |
| `TrophyIcon` | 24 outline | `trophy-outline.svg` |
| `Squares2X2Icon` | 24 outline | `squares-2x2-outline.svg` |
| `FireIcon` | 24 outline | `fire-outline.svg` |
| `ClockIcon` | 24 outline | `clock-outline.svg` |
| `SparklesIcon` | 24 outline | `sparkles-outline.svg` |
| `InformationCircleIcon` | 24 outline | `information-circle-outline.svg` |
| `ExclamationTriangleIcon` | 24 outline | `exclamation-triangle-outline.svg` |

The Heroicons-derived files retain their upstream `24 × 24` view boxes and `currentColor` paint behavior. They are vendored assets only and are not yet wired into the FANatical UI.

## Pictogrammers / Material Design Icons

The files prefixed with `mdi-` below are vendored from the official Pictogrammers Material Design Icons SVG distribution.

- Project: Material Design Icons
- Publisher: Pictogrammers
- Distribution: `@mdi/svg`
- Release: `v7.4.47`
- Pinned source revision: `9e04201d4557e729822fb57f62a316c3dea1d4a8`
- Official repository: <https://github.com/Templarian/MaterialDesign-SVG>
- Pinned source location: <https://github.com/Templarian/MaterialDesign-SVG/tree/v7.4.47/svg>
- Upstream source path: `svg/`
- Package artifact: `@mdi/svg@7.4.47` (`sha512-WQ2gDll12T9WD34fdRFgQVgO8bag3gavrAgJ0frN4phlwdJARpE6gO1YvLEMJR0KKgoc+/Ea/A0Pp11I00xBvw==`)
- Icon license: Apache License 2.0; see `PICTOGRAMMERS-MDI-LICENSE.txt`

| Upstream MDI icon name | Upstream file | Local FANatical file |
| --- | --- | --- |
| `hockey-sticks` | `svg/hockey-sticks.svg` | `mdi-hockey-sticks.svg` |
| `hockey-puck` | `svg/hockey-puck.svg` | `mdi-hockey-puck.svg` |
| `baseball-outline` | `svg/baseball-outline.svg` | `mdi-baseball-outline.svg` |
| `baseball-bat` | `svg/baseball-bat.svg` | `mdi-baseball-bat.svg` |
| `basketball` | `svg/basketball.svg` | `mdi-basketball.svg` |
| `football` | `svg/football.svg` | `mdi-football.svg` |
| `football-helmet` | `svg/football-helmet.svg` | `mdi-football-helmet.svg` |
| `soccer` | `svg/soccer.svg` | `mdi-soccer.svg` |
| `rugby` | `svg/rugby.svg` | `mdi-rugby.svg` |
| `football-australian` | `svg/football-australian.svg` | `mdi-football-australian.svg` |
| `strategy` | `svg/strategy.svg` | `mdi-strategy.svg` |
| `locker-multiple` | `svg/locker-multiple.svg` | `mdi-locker-multiple.svg` |

These assets retain the upstream IDs, `24 × 24` view boxes, and path geometry. FANatical adds only `fill="currentColor"` to each root SVG for compatibility with the shared `AppIcon` color behavior. They are registered under matching `mdi-` icon keys for use through the shared `AppIcon` component.
