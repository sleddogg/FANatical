import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { expect, test } from "@playwright/test";

const email = `phase2-admin-smoke-${Date.now()}@fanatical.invalid`;
const password = "Phase2-admin-smoke-2026!";
let serviceClient: SupabaseClient;
let staffUserId: string;

function parseEnvironment(output: string) {
  const values = new Map<string, string>();
  for (const line of output.split(/\r?\n/)) {
    const match = line.match(/^([A-Z0-9_]+)=(?:"([^"]*)"|'([^']*)'|(.*))$/);
    if (match) values.set(match[1], (match[2] ?? match[3] ?? match[4] ?? "").trim());
  }
  return values;
}

function assignLocalStaffRole(userId: string) {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(userId)) {
    throw new Error("Admin smoke user ID was not a valid UUID.");
  }
  const result = spawnSync(
    "docker",
    [
      "exec", "supabase_db_fanatical-local",
      "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1",
      "-c",
      `insert into public.staff_roles(user_id, role, permissions, is_active) values ('${userId}'::uuid, 'content_admin', array[]::text[], true)`,
    ],
    { encoding: "utf8" },
  );
  if (result.status !== 0) throw new Error("Local Admin smoke staff fixture could not be created.");
}

test.beforeAll(async () => {
  const appDirectory = resolve(import.meta.dirname, "..");
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
  const status = parseEnvironment(result.stdout);
  const apiUrl = status.get("API_URL");
  const serviceKey = status.get("SECRET_KEY") ?? status.get("SERVICE_ROLE_KEY");
  if (!apiUrl || !serviceKey) throw new Error("Local Supabase service credentials were unavailable.");

  serviceClient = createClient(apiUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
  const created = await serviceClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { display_name: "Phase 2 Admin Smoke" },
  });
  if (created.error || !created.data.user) throw created.error ?? new Error("Admin smoke user was not created.");
  staffUserId = created.data.user.id;
  assignLocalStaffRole(staffUserId);
});

test.afterAll(async () => {
  if (staffUserId) await serviceClient.auth.admin.deleteUser(staffUserId);
});

test("authorized staff can open and refresh the News identity review workspace", async ({ page }) => {
  await page.goto("/");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(password);
  await page.getByRole("button", { name: "Sign In" }).click();

  await expect(page.getByRole("heading", { name: "News identity review" })).toBeVisible();
  await expect(page.getByText("No identity cases need attention.")).toBeVisible();
  await page.getByRole("button", { name: "Refresh" }).click();
  await expect(page.getByText("No identity cases need attention.")).toBeVisible();

  const overflow = await page.evaluate(
    () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
  );
  expect(overflow).toBeLessThanOrEqual(1);
});
