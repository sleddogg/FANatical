import type { RouteObject } from "react-router-dom";
import { RootShell } from "../layouts/RootShell";
import { HomeLayout } from "../layouts/HomeLayout";
import { InnerPageLayout } from "../layouts/InnerPageLayout";
import { HomePage } from "../pages/HomePage";
import { NotFoundPage } from "../pages/NotFoundPage";
import { PlaceholderPage } from "../pages/PlaceholderPage";
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
          ...featureNavigation.map((item) => ({
            path: item.path.slice(1),
            element: <PlaceholderPage title={item.label} description={item.description} />,
          })),
          {
            path: "profile",
            element: (
              <PlaceholderPage
                title="Profile"
                description="Fan identity and profile controls will live here."
              />
            ),
          },
        ],
      },
      { path: "*", element: <NotFoundPage /> },
    ],
  },
];
