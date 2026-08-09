import { Outlet } from "react-router-dom";
import { BottomNavigation } from "../components/BottomNavigation";

export function HomeLayout() {
  return (
    <div className="page-frame page-frame--home">
      <main id="main-content" className="home-container" tabIndex={-1}>
        <Outlet />
      </main>
      <BottomNavigation variant="home" />
    </div>
  );
}
