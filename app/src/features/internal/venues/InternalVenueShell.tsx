import type { ReactNode } from "react";
import { Link } from "react-router-dom";

export function InternalVenueShell({ mode, children }: { readonly mode: "mapping" | "tester"; readonly children: ReactNode }) {
  return (
    <div className="internal-venue-shell">
      <header className="internal-venue-topbar">
        <div><span className="internal-kicker">FANatical Internal Tools</span><strong>Venue Mapping + Seat Resolver</strong></div>
        <nav aria-label="Rexall Place internal tools">
          <Link aria-current={mode === "mapping" ? "page" : undefined} to="/internal/venues/rexall-place">Venue Mapping</Link>
          <Link aria-current={mode === "tester" ? "page" : undefined} to="/internal/venues/rexall-place/test">Seat Resolver Tester</Link>
        </nav>
      </header>
      {children}
    </div>
  );
}
