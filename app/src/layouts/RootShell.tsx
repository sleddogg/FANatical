import { Outlet } from "react-router-dom";
import { FanbaseProvider } from "../features/fanbase/FanbaseContext";
import { LiveCheerNotificationProvider } from "../features/cheer/LiveCheerNotifications";
import { TeamProvider } from "../state/TeamContext";
import { ProfileVisualProvider } from "../features/profileVisual/ProfileVisualContext";
import { AuthProvider } from "../features/account/AuthContext";
import { AccountBootstrapProvider } from "../features/account/AccountBootstrap";
import { ProfileAvatarProvider } from "../features/profileAvatar/ProfileAvatarContext";
import { ThemeProvider } from "../state/ThemeContext";
import { NotificationProvider } from "../features/notifications/NotificationContext";
import { supabaseBackendEnvironment } from "../lib/supabase/client";

export function RootShell() {
  return (
    <AuthProvider>
      <AccountBootstrapProvider>
        <NotificationProvider>
          <ProfileAvatarProvider>
          <TeamProvider>
            <ThemeProvider>
              <ProfileVisualProvider>
                <FanbaseProvider>
                  <LiveCheerNotificationProvider>
                    <a className="skip-link" href="#main-content">Skip to main content</a>
                    {supabaseBackendEnvironment.kind === "local" ? (
                      <div className="local-build-marker">
                        Phase 5A local acceptance · 2026-08-31
                      </div>
                    ) : null}
                    <Outlet />
                  </LiveCheerNotificationProvider>
                </FanbaseProvider>
              </ProfileVisualProvider>
            </ThemeProvider>
          </TeamProvider>
          </ProfileAvatarProvider>
        </NotificationProvider>
      </AccountBootstrapProvider>
    </AuthProvider>
  );
}
