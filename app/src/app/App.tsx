import { createBrowserRouter, RouterProvider } from "react-router-dom";
import { appRoutes } from "./routes";
import { IconTooltipProvider } from "../components/IconTooltipProvider";

const router = createBrowserRouter(appRoutes);

export function App() {
  return <IconTooltipProvider><RouterProvider router={router} /></IconTooltipProvider>;
}
