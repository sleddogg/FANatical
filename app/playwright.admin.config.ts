import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { defineConfig } from "@playwright/test";

function localPublicKey() {
  const appDirectory = import.meta.dirname;
  const repositoryDirectory = resolve(appDirectory, "..");
  const cliPath = resolve(appDirectory, "node_modules/supabase/dist/supabase.js");
  const result = spawnSync(
    process.execPath,
    [cliPath, "status", "-o", "env", "--workdir", repositoryDirectory],
    {
      cwd: appDirectory,
      encoding: "utf8",
      env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" },
    },
  );
  if (result.status !== 0) throw new Error("Local Supabase must be running for the Admin smoke test.");
  const keyLine = result.stdout.split(/\r?\n/).find((line) => line.startsWith("PUBLISHABLE_KEY=") || line.startsWith("ANON_KEY="));
  const key = keyLine?.slice(keyLine.indexOf("=") + 1).replace(/^['"]|['"]$/g, "");
  if (!key) throw new Error("Local Supabase did not report a browser-safe public key.");
  return key;
}

export default defineConfig({
  testDir: "./e2e",
  testMatch: "admin-news-identity-review.spec.ts",
  fullyParallel: false,
  workers: 1,
  reporter: "list",
  use: {
    baseURL: "http://127.0.0.1:4174",
    viewport: { width: 1280, height: 900 },
    trace: "on-first-retry",
  },
  webServer: {
    command: "./node_modules/.bin/vite --mode development --host 127.0.0.1 --port 4174",
    url: "http://127.0.0.1:4174",
    reuseExistingServer: false,
    env: {
      ...process.env,
      VITE_FANATICAL_SURFACE: "admin",
      VITE_SUPABASE_URL: "/supabase",
      VITE_SUPABASE_PUBLISHABLE_KEY: localPublicKey(),
      VITE_SUPABASE_BACKEND: "local",
      VITE_ALLOW_HOSTED_SUPABASE_DEV: "false",
    },
  },
});
