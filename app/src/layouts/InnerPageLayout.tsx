import { Outlet } from "react-router-dom";
import { BottomNavigation } from "../components/BottomNavigation";

export function InnerPageLayout() {
  return (
    <div className="page-frame page-frame--inner">
      <main id="main-content" className="content-container" tabIndex={-1}>
        <Outlet />
      </main>
      <BottomNavigation variant="inner" />
    </div>
  );
}
