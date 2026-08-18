import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { AdminApp } from "./AdminApp";
import "../styles/tokens.css";
import "../styles/global.css";
import "./admin.css";

const rootElement = document.getElementById("root");

if (!rootElement) throw new Error("FANatical Admin could not find the application root.");

document.title = "FANatical Admin";

createRoot(rootElement).render(
  <StrictMode>
    <AdminApp />
  </StrictMode>,
);
