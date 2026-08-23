import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { createClient } from "@supabase/supabase-js";
import { expect, test } from "@playwright/test";

const productionHostname = "lsuceoieqgbagxxwobxu.supabase.co";
const emailPrefix = "local-browser-network-";
const email = `${emailPrefix}${Date.now()}@fanatical.invalid`;

function parseEnvironment(output: string) {
  const values = new Map<string, string>();
  for (const line of output.split(/\r?\n/)) {
    const match = line.match(/^([A-Z0-9_]+)=(?:"([^"]*)"|'([^']*)'|(.*))$/);
    if (match) values.set(match[1], (match[2] ?? match[3] ?? match[4] ?? "").trim());
  }
  return values;
}

async function removeBrowserVerificationUsers() {
  const appDirectory = resolve(import.meta.dirname, "..");
  const repositoryDirectory = resolve(appDirectory, "..");
  const cliPath = resolve(appDirectory, "node_modules/supabase/dist/supabase.js");
  const result = spawnSync(process.execPath, [cliPath, "status", "-o", "env", "--workdir", repositoryDirectory], {
    cwd: appDirectory,
    encoding: "utf8",
    env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" },
  });
  if (result.status !== 0) throw new Error("Local Supabase must be running for the browser network verification.");
  const status = parseEnvironment(result.stdout);
  const apiUrl = status.get("API_URL");
  const serviceKey = status.get("SECRET_KEY") ?? status.get("SERVICE_ROLE_KEY");
  if (!apiUrl || !serviceKey) throw new Error("Local Supabase admin credentials were unavailable.");

  const admin = createClient(apiUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
  const users = await admin.auth.admin.listUsers({ page: 1, perPage: 1_000 });
  if (users.error) throw users.error;
  for (const user of users.data.users.filter((candidate) => candidate.email?.startsWith(emailPrefix))) {
    const removal = await admin.auth.admin.deleteUser(user.id);
    if (removal.error) throw removal.error;
  }
}

test.beforeAll(removeBrowserVerificationUsers);
test.afterAll(removeBrowserVerificationUsers);

test("localhost and LAN-safe development use only the same-origin local Supabase proxy", async ({ page }) => {
  const requests: string[] = [];
  const sockets: string[] = [];
  page.on("request", (request) => requests.push(request.url()));
  page.on("websocket", (socket) => sockets.push(socket.url()));

  await page.goto("/profile");
  await page.getByRole("button", { name: "Create Account", exact: true }).first().click();
  await page.getByLabel("Display name").fill("Local Browser Verification");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill("Local-browser-verification-2026!");
  await page.getByRole("button", { name: "Create Account", exact: true }).last().click();
  await expect(page.getByRole("region", { name: "Signed in" })).toContainText(email);
  await page.waitForTimeout(1_000);

  const hostedTraffic = [...requests, ...sockets].filter((url) => new URL(url).hostname === productionHostname);
  const browserBackendTraffic = [...requests, ...sockets].filter((url) => new URL(url).pathname.startsWith("/supabase/"));

  expect(hostedTraffic).toEqual([]);
  expect(browserBackendTraffic.length).toBeGreaterThan(0);
  expect(browserBackendTraffic.every((url) => {
    const parsed = new URL(url);
    return parsed.hostname === "127.0.0.1" && parsed.port === "4173";
  })).toBe(true);
});
