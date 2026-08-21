import { createContext, useContext, useEffect, useMemo, useState, type PropsWithChildren } from "react";
import { findCatalogTeam, loadTeamCatalog, type TeamCatalogSnapshot } from "../data/teamCatalogRepository";
import { useThemePreference } from "../data/themePreference";
import type { FollowedTeam } from "../domain/team";
import { isSupabaseConfigured } from "../lib/supabase/client";
import { resolveTheme, themeCssProperties, type ResolvedTheme } from "../theme/theme";
import { useTeamContext } from "./TeamContext";

const ThemeContext = createContext<ResolvedTheme | undefined>(undefined);

function colorsForTeam(team: FollowedTeam | undefined, catalog: TeamCatalogSnapshot | null) {
  if (!team) return null;
  const catalogTeam = catalog ? findCatalogTeam(catalog, team.officialTeamId) : null;
  return catalogTeam?.colorsStatus === "verified" ? catalogTeam.colors : team.colors;
}

export function ThemeProvider({ children }: PropsWithChildren) {
  const { preference } = useThemePreference();
  const { followedTeams, selectedTeam } = useTeamContext();
  const [catalog, setCatalog] = useState<TeamCatalogSnapshot | null>(null);
  const favoriteTeam = followedTeams[0];

  useEffect(() => {
    if (!isSupabaseConfigured) return;
    let current = true;
    void loadTeamCatalog().then((snapshot) => {
      if (current) setCatalog(snapshot);
    });
    return () => { current = false; };
  }, []);

  const theme = useMemo(() => resolveTheme(
    preference,
    colorsForTeam(favoriteTeam, catalog),
    colorsForTeam(selectedTeam, catalog),
    favoriteTeam?.name ?? "Favorite Team",
    selectedTeam.name,
  ), [catalog, favoriteTeam, preference, selectedTeam]);

  return (
    <ThemeContext.Provider value={theme}>
      <div
        className="application-shell"
        data-theme-source={theme.source}
        data-theme-order={theme.order}
        data-theme-active={theme.active ? "true" : "false"}
        style={themeCssProperties(theme)}
      >
        {children}
      </div>
    </ThemeContext.Provider>
  );
}

export function useAppTheme() {
  const context = useContext(ThemeContext);
  if (!context) throw new Error("useAppTheme must be used within a ThemeProvider.");
  return context;
}
