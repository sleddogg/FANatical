import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  testIgnore: "admin-news-identity-review.spec.ts",
  fullyParallel: true,
  reporter: "list",
  use: {
    baseURL: "http://127.0.0.1:4173",
    trace: "on-first-retry",
  },
  webServer: {
    // The 0.0.0.0 binding is intentional: one development app serves trusted-LAN
    // desktop/phone acceptance while it runs. Fixture provisioning still refuses
    // every non-loopback Supabase API target; this changes no production server
    // or hosted configuration.
    command: "npm run dev -- --host 0.0.0.0 --port 4173",
    url: "http://127.0.0.1:4173",
    reuseExistingServer: true,
  },
});
