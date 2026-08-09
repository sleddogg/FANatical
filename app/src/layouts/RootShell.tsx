import { Outlet } from "react-router-dom";

export function RootShell() {
  return (
    <div className="application-shell">
      <a className="skip-link" href="#main-content">
        Skip to main content
      </a>
      <Outlet />
    </div>
  );
}
