import { Outlet } from "react-router-dom";
import { FanbaseProvider } from "../features/fanbase/FanbaseContext";
import { LiveCheerNotificationProvider } from "../features/cheer/LiveCheerNotifications";
import { TeamProvider } from "../state/TeamContext";

export function RootShell() {
  return (
    <TeamProvider>
      <FanbaseProvider>
        <LiveCheerNotificationProvider><div className="application-shell">
          <a className="skip-link" href="#main-content">Skip to main content</a>
          <Outlet />
        </div></LiveCheerNotificationProvider>
      </FanbaseProvider>
    </TeamProvider>
  );
}
