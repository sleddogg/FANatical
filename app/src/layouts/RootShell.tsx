import { Outlet } from "react-router-dom";
import { FanbaseProvider } from "../features/fanbase/FanbaseContext";
import { LiveCheerNotificationProvider } from "../features/cheer/LiveCheerNotifications";
import { TeamProvider } from "../state/TeamContext";
import { ProfileVisualProvider } from "../features/profileVisual/ProfileVisualContext";
import { AuthProvider } from "../features/account/AuthContext";
import { AccountBootstrapProvider } from "../features/account/AccountBootstrap";
import { ProfileAvatarProvider } from "../features/profileAvatar/ProfileAvatarContext";

export function RootShell() {
  return (
    <AuthProvider>
      <AccountBootstrapProvider>
        <ProfileAvatarProvider>
          <TeamProvider>
            <ProfileVisualProvider>
              <FanbaseProvider>
                <LiveCheerNotificationProvider><div className="application-shell">
                  <a className="skip-link" href="#main-content">Skip to main content</a>
                  <Outlet />
                </div></LiveCheerNotificationProvider>
              </FanbaseProvider>
            </ProfileVisualProvider>
          </TeamProvider>
        </ProfileAvatarProvider>
      </AccountBootstrapProvider>
    </AuthProvider>
  );
}
