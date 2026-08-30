import type { RouteObject } from "react-router-dom";
import { RootShell } from "../layouts/RootShell";
import { HomeLayout } from "../layouts/HomeLayout";
import { InnerPageLayout } from "../layouts/InnerPageLayout";
import { HomePage } from "../pages/HomePage";
import { NotFoundPage } from "../pages/NotFoundPage";
import { PlaceholderPage } from "../pages/PlaceholderPage";
import { NewsPage } from "../features/news/NewsPage";
import { NewsIdentityProfilePage } from "../features/news/NewsIdentityProfilePage";
import { FanbasePage } from "../features/fanbase/FanbasePage";
import { QuizPage } from "../features/quiz/QuizPage";
import { ProfilePage } from "../features/profile/ProfilePage";
import { PersonalSportsStatsPage } from "../features/profile/PersonalSportsStatsPage";
import { CheerPage } from "../features/cheer/CheerPage";
import { CheerLaunchPage } from "../features/cheer/CheerLaunchPage";
import { CheerLivePage } from "../features/cheer/CheerLivePage";
import { RexallSeatResolverPage } from "../features/internal/venues/RexallSeatResolverPage";
import { RexallVenuePage } from "../features/internal/venues/RexallVenuePage";
import { featureNavigation } from "./navigation";

export const appRoutes: RouteObject[] = [
  ...(import.meta.env.DEV
    ? [
        {
          path: "/internal/venues/rexall-place",
          element: <RexallVenuePage />,
        },
        {
          path: "/internal/venues/rexall-place/test",
          element: <RexallSeatResolverPage />,
        },
      ]
    : []),
  {
    path: "/",
    element: <RootShell />,
    children: [
      {
        element: <HomeLayout />,
        children: [{ index: true, element: <HomePage /> }],
      },
      {
        element: <InnerPageLayout />,
        children: [
          {
            path: "news",
            element: <NewsPage />,
          },
          {
            path: "news/authors/:identityId",
            element: <NewsIdentityProfilePage targetType="author" />,
          },
          {
            path: "news/organizations/:identityId",
            element: <NewsIdentityProfilePage targetType="organization" />,
          },
          {
            path: "news/shows/:identityId",
            element: <NewsIdentityProfilePage targetType="show" />,
          },
          {
            path: "fanbase",
            element: <FanbasePage />,
          },
          {
            path: "quiz",
            element: <QuizPage />,
          },
          {
            path: "cheer",
            element: <CheerPage />,
          },
          {
            path: "cheer/launch",
            element: <CheerLaunchPage />,
          },
          ...featureNavigation.filter((item) => item.path !== "/news" && item.path !== "/fanbase" && item.path !== "/quiz" && item.path !== "/cheer").map((item) => ({
            path: item.path.slice(1),
            element: <PlaceholderPage title={item.label} description={item.description} />,
          })),
          {
            path: "profile/stats",
            element: <PersonalSportsStatsPage />,
          },
          {
            path: "profile",
            element: <ProfilePage />,
          },
        ],
      },
      {
        path: "cheer/live/:proposalId",
        element: <CheerLivePage />,
      },
      { path: "*", element: <NotFoundPage /> },
    ],
  },
];
