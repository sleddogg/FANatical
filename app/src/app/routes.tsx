import type { RouteObject } from "react-router-dom";
import { RootShell } from "../layouts/RootShell";
import { HomeLayout } from "../layouts/HomeLayout";
import { InnerPageLayout } from "../layouts/InnerPageLayout";
import { HomePage } from "../pages/HomePage";
import { NotFoundPage } from "../pages/NotFoundPage";
import { PlaceholderPage } from "../pages/PlaceholderPage";
import { NewsPage } from "../features/news/NewsPage";
import { FanbasePage } from "../features/fanbase/FanbasePage";
import { QuizPage } from "../features/quiz/QuizPage";
import { ProfilePage } from "../features/profile/ProfilePage";
import { CheerPage } from "../features/cheer/CheerPage";
import { featureNavigation } from "./navigation";

export const appRoutes: RouteObject[] = [
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
          ...featureNavigation.filter((item) => item.path !== "/news" && item.path !== "/fanbase" && item.path !== "/quiz" && item.path !== "/cheer").map((item) => ({
            path: item.path.slice(1),
            element: <PlaceholderPage title={item.label} description={item.description} />,
          })),
          {
            path: "profile",
            element: <ProfilePage />,
          },
        ],
      },
      { path: "*", element: <NotFoundPage /> },
    ],
  },
];
