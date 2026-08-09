import { Outlet } from "react-router-dom";
import { TeamProvider } from "../state/TeamContext";

export function RootShell() {
  return (
    <TeamProvider>
      <div className="application-shell">
        <a className="skip-link" href="#main-content">
          Skip to main content
        </a>
        <Outlet />
      </div>
    </TeamProvider>
  );
}
