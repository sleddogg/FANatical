import { createBrowserRouter, RouterProvider } from "react-router-dom";
import { appRoutes } from "./routes";
import { IconTooltipProvider } from "../components/IconTooltipProvider";
import { supabaseBackendEnvironment } from "../lib/supabase/client";

const router = createBrowserRouter(appRoutes);

export function App() {
  return <>
    {supabaseBackendEnvironment.warning ? <aside className="hosted-backend-warning" role="alert">{supabaseBackendEnvironment.warning}</aside> : null}
    <IconTooltipProvider><RouterProvider router={router} /></IconTooltipProvider>
  </>;
}
