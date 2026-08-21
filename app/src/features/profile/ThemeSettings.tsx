import type { FollowedTeam } from "../../domain/team";
import {
  normalizeHexColor,
  resolveTheme,
  themeOrders,
  themeSources,
  themeStrengths,
  type ThemePreference,
  type ThemeSource,
} from "../../theme/theme";

type ThemeSettingsProps = Readonly<{
  value: ThemePreference;
  favoriteTeam: FollowedTeam | undefined;
  currentTeam: FollowedTeam;
  onChange: (value: ThemePreference) => void;
}>;

const sourceLabels: Readonly<Record<ThemeSource, string>> = {
  none: "None",
  "favorite-team": "Favorite Team",
  "current-team": "Current Team",
  custom: "Custom",
};

function sourceDescription(source: ThemeSource, favoriteTeam: FollowedTeam | undefined, currentTeam: FollowedTeam) {
  if (source === "none") return "Use FANatical's neutral default styling.";
  if (source === "favorite-team") return favoriteTeam ? `Always use ${favoriteTeam.name}.` : "Choose a primary team first.";
  if (source === "current-team") return `Follow the current team context, now ${currentTeam.name}.`;
  return "Choose your own Color 1 and Color 2.";
}

export function ThemeSettings({ value, favoriteTeam, currentTeam, onChange }: ThemeSettingsProps) {
  const preview = resolveTheme(
    value,
    favoriteTeam?.colors,
    currentTeam.colors,
    favoriteTeam?.name ?? "Favorite Team",
    currentTeam.name,
  );
  const update = (patch: Partial<ThemePreference>) => onChange({ ...value, ...patch });

  return (
    <fieldset className="theme-settings">
      <legend>App Theme</legend>
      <p className="profile-edit-dialog__note">Choose the two shared colors that Home and every page can use as styling is added.</p>

      <div className="profile-featured-picker" role="radiogroup" aria-labelledby="theme-source-title">
        <strong id="theme-source-title">Theme Source</strong>
        <div className="theme-source-options">
          {themeSources.map((source) => (
            <label key={source}>
              <input
                type="radio"
                name="themeSource"
                value={source}
                checked={value.source === source}
                disabled={source === "favorite-team" && !favoriteTeam}
                onChange={() => update({ source })}
              />
              <span><strong>{sourceLabels[source]}</strong><small>{sourceDescription(source, favoriteTeam, currentTeam)}</small></span>
            </label>
          ))}
        </div>
      </div>

      {value.source === "custom" ? (
        <div className="theme-custom-colors" aria-label="Custom theme colors">
          {([1, 2] as const).map((colorNumber) => {
            const key = colorNumber === 1 ? "customColor1" : "customColor2";
            const color = value[key];
            return (
              <label key={key}>
                <span>Color {colorNumber}</span>
                <span className="theme-color-picker">
                  <input type="color" value={color} aria-label={`Choose Custom Color ${colorNumber}`} onChange={(event) => update({ [key]: normalizeHexColor(event.target.value, color) })} />
                  <code>{color}</code>
                </span>
              </label>
            );
          })}
        </div>
      ) : null}

      {value.source !== "none" ? (
        <div className="profile-featured-picker" role="radiogroup" aria-labelledby="theme-order-title">
          <strong id="theme-order-title">Color Order</strong>
          <div>
            {themeOrders.map((order) => (
              <label key={order}>
                <input type="radio" name="themeOrder" value={order} checked={value.order === order} onChange={() => update({ order })} />
                <span>{order === "normal" ? "Normal" : "Swapped"}</span>
              </label>
            ))}
          </div>
          <p>Pages always receive Color 1 and Color 2 after this choice is applied.</p>
        </div>
      ) : null}

      <div className="theme-scale-preview" aria-label={`${preview.sourceLabel} theme color scale preview`}>
        {([1, 2] as const).map((colorNumber) => {
          const scale = colorNumber === 1 ? preview.color1Scale : preview.color2Scale;
          const foreground = colorNumber === 1 ? preview.color1Foreground : preview.color2Foreground;
          return (
            <section key={colorNumber}>
              <header><strong>Color {colorNumber}</strong><code>{colorNumber === 1 ? preview.color1 : preview.color2}</code></header>
              <div>{themeStrengths.map((strength) => <span key={strength} style={{ backgroundColor: scale[strength], color: foreground[strength] }}>{strength}</span>)}</div>
            </section>
          );
        })}
      </div>
      {preview.unavailableReason ? <p className="theme-settings__warning" role="status">{preview.unavailableReason} FANatical neutral colors will be used until colors are available.</p> : null}
    </fieldset>
  );
}
