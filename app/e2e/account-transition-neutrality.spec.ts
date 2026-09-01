import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { createClient } from "@supabase/supabase-js";
import { expect, test, type Page } from "@playwright/test";

const runPrefix = `account-transition-${Date.now()}-`;
const password = "Account-transition-proof-2026!";
const profileVisualFixture = resolve(import.meta.dirname, "../../images/logos/main-image.jpg");

const viewports = [
  { name: "phone", width: 390, height: 844 },
  { name: "desktop", width: 1440, height: 900 },
] as const;

function parseEnvironment(output: string) {
  const values = new Map<string, string>();
  for (const line of output.split(/\r?\n/)) {
    const match = line.match(/^([A-Z0-9_]+)=(?:"([^"]*)"|'([^']*)'|(.*))$/);
    if (match) values.set(match[1], (match[2] ?? match[3] ?? match[4] ?? "").trim());
  }
  return values;
}

async function removeTransitionUsers() {
  const appDirectory = resolve(import.meta.dirname, "..");
  const repositoryDirectory = resolve(appDirectory, "..");
  const cliPath = resolve(appDirectory, "node_modules/supabase/dist/supabase.js");
  const result = spawnSync(process.execPath, [cliPath, "status", "-o", "env", "--workdir", repositoryDirectory], {
    cwd: appDirectory,
    encoding: "utf8",
    env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" },
  });
  if (result.status !== 0) throw new Error("Local Supabase must be running for the account-transition browser proof.");
  const status = parseEnvironment(result.stdout);
  const apiUrl = status.get("API_URL");
  const serviceKey = status.get("SECRET_KEY") ?? status.get("SERVICE_ROLE_KEY");
  if (!apiUrl || !serviceKey) throw new Error("Local Supabase admin credentials were unavailable.");
  const admin = createClient(apiUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } });
  const users = await admin.auth.admin.listUsers({ page: 1, perPage: 1_000 });
  if (users.error) throw users.error;
  for (const user of users.data.users.filter((candidate) => candidate.email?.startsWith(runPrefix))) {
    const removal = await admin.auth.admin.deleteUser(user.id);
    if (removal.error) throw removal.error;
  }
}

async function expectNeutralHome(page: Page, accountMarkers: readonly string[] = []) {
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByRole("heading", { name: "Your home for fandom." })).toBeVisible();
  await expect(page.locator(".home-hero")).toHaveAttribute("data-has-custom-image", "false");
  await expect(page.getByRole("navigation", { name: "Feature shortcuts" })).toHaveClass(/home-hero__shortcuts--left/);
  await expect(page.getByRole("button", { name: "Select New England Patriots" })).toHaveAttribute("aria-pressed", "true");
  await expect(page.getByRole("button", { name: "Select Edmonton Oilers" })).toHaveCount(0);
  await expect(page.locator(".application-shell")).toHaveAttribute("data-theme-active", "false");
  await expect(page.locator(".bottom-navigation .profile-avatar-media img")).toHaveCount(0);
  for (const marker of ["North Star", "Alex Mercer", "Sleddogg", "Fan Score", "Fan Coins", "Founding Fan", ...accountMarkers]) {
    await expect(page.getByText(marker, { exact: false })).toHaveCount(0);
  }
}

async function expectBlankProfile(page: Page) {
  await page.goto("/profile");
  const profile = page.locator(".profile-page--signed-out");
  await expect(profile).toBeVisible();
  await expect(profile.getByRole("button", { name: "Sign In" })).toBeVisible();
  await expect(profile.getByRole("button", { name: "Create Account" })).toBeVisible();
  await expect(profile).toHaveText("Sign InCreate Account");
  await expect(profile.getByText(/NorthStarFan|North Star|Alex Mercer|Sleddogg|Fan Score|Fan Coins|Founding Fan/)).toHaveCount(0);
}

async function createAccount(page: Page, email: string, displayName: string) {
  await expectBlankProfile(page);
  await page.locator(".profile-page--signed-out").getByRole("button", { name: "Create Account" }).click();
  await page.getByLabel("Display name").fill(displayName);
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(password);
  await page.getByRole("button", { name: "Create Account", exact: true }).last().click();
  await expect(page.getByRole("region", { name: "Signed in" })).toContainText(email);
  await expect(page.getByRole("heading", { name: displayName, level: 1 })).toBeVisible();
}

async function signIn(page: Page, email: string) {
  await expectBlankProfile(page);
  await page.locator(".profile-page--signed-out").getByRole("button", { name: "Sign In" }).click();
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(password);
  await page.getByRole("button", { name: "Sign In", exact: true }).last().click();
  await expect(page.getByRole("region", { name: "Signed in" })).toContainText(email);
}

async function customizeAccountA(page: Page, markers: { displayName: string; tagline: string; home: string }) {
  await page.getByRole("button", { name: "Edit profile" }).click();
  const dialog = page.getByRole("dialog", { name: "Edit Profile" });
  await dialog.getByLabel("Display name").fill(markers.displayName);
  await dialog.getByLabel("Tagline").fill(markers.tagline);
  await dialog.getByRole("radio", { name: "Right", exact: true }).click();
  await dialog.getByRole("radio", { name: /^Custom/ }).click();
  await dialog.getByLabel("Choose Custom Color 1").fill("#123456");
  await dialog.getByLabel("Choose Custom Color 2").fill("#654321");
  await dialog.getByLabel("Big text").fill(markers.home);
  await dialog.getByRole("button", { name: "Add Mobile image" }).click();
  const mobile = page.getByRole("region", { name: "Mobile Visual" });
  await mobile.getByLabel("Choose Mobile Visual").setInputFiles(profileVisualFixture);
  await expect(mobile.getByRole("button", { name: "Save image" })).toBeEnabled();
  await mobile.getByRole("button", { name: "Save image" }).click();
  await expect(mobile.getByRole("button", { name: "Save image" })).toBeDisabled();
  await page.getByRole("button", { name: /Back to Profile settings/ }).click();
  await page.getByRole("dialog", { name: "Edit Profile" }).getByRole("button", { name: "Save profile" }).click();
  await expect(page.getByRole("heading", { name: markers.displayName, level: 1 })).toBeVisible();

  await page.getByRole("tab", { name: "Fan Identity" }).click();
  await page.getByRole("button", { name: "Add Team" }).click();
  await page.getByRole("button", { name: /^Hockey/ }).click();
  await page.getByRole("button", { name: /^NHL/ }).click();
  await page.getByRole("button", { name: "Select Edmonton Oilers" }).click();
  await page.getByRole("button", { name: "Confirm Add Team" }).click();
  await expect(page.getByLabel("Profile followed teams").getByText("Edmonton Oilers")).toBeVisible();
}

async function expectAccountAHome(page: Page, markers: { home: string }) {
  await page.getByRole("link", { name: "FANatical home" }).click();
  await expect(page.getByRole("heading", { name: markers.home })).toBeVisible();
  await expect(page.locator(".home-hero")).toHaveAttribute("data-has-custom-image", "true");
  await expect(page.getByRole("navigation", { name: "Feature shortcuts" })).toHaveClass(/home-hero__shortcuts--right/);
  await expect(page.getByRole("button", { name: "Select Edmonton Oilers" })).toHaveAttribute("aria-pressed", "true");
  await expect(page.locator(".application-shell")).toHaveAttribute("data-theme-source", "custom");
  await expect(page.locator(".application-shell")).toHaveAttribute("data-theme-active", "true");
}

async function logoutFromProfile(page: Page) {
  await page.goto("/profile");
  await page.getByRole("region", { name: "Signed in" }).getByRole("button", { name: "Sign Out" }).click();
  await expect(page).toHaveURL(/\/$/);
}

test.describe.configure({ mode: "serial" });
test.setTimeout(90_000);
test.beforeAll(removeTransitionUsers);
test.afterAll(removeTransitionUsers);

for (const viewport of viewports) {
  test(`${viewport.name} keeps account presentation neutral across logout, history, refresh, A re-entry, and A-to-B`, async ({ browser }) => {
    const context = await browser.newContext({ viewport: { width: viewport.width, height: viewport.height } });
    const page = await context.newPage();
    const emailA = `${runPrefix}${viewport.name}-a@fanatical.invalid`;
    const emailB = `${runPrefix}${viewport.name}-b@fanatical.invalid`;
    const markers = {
      displayName: `Transition A ${viewport.name}`,
      tagline: `Only account A ${viewport.name}`,
      home: `Private A ${viewport.name}`,
    };

    await page.goto("/");
    await expectNeutralHome(page);
    await expectBlankProfile(page);
    await createAccount(page, emailA, `Initial A ${viewport.name}`);
    await customizeAccountA(page, markers);
    await expectAccountAHome(page, markers);

    await logoutFromProfile(page);
    await expectNeutralHome(page, Object.values(markers));
    await page.reload();
    await expectNeutralHome(page, Object.values(markers));
    await page.goBack();
    await expectNeutralHome(page, Object.values(markers));
    await page.goForward();
    await expectNeutralHome(page, Object.values(markers));
    await expectBlankProfile(page);

    await signIn(page, emailA);
    await expect(page.getByRole("heading", { name: markers.displayName, level: 1 })).toBeVisible();
    await expectAccountAHome(page, markers);
    await logoutFromProfile(page);
    await expectNeutralHome(page, Object.values(markers));

    await createAccount(page, emailB, `Transition B ${viewport.name}`);
    await expect(page.getByRole("heading", { name: `Transition B ${viewport.name}`, level: 1 })).toBeVisible();
    await page.getByRole("link", { name: "FANatical home" }).click();
    await expect(page.getByRole("heading", { name: "Your home for fandom." })).toBeVisible();
    await expect(page.locator(".home-hero")).toHaveAttribute("data-has-custom-image", "false");
    await expect(page.locator(".application-shell")).toHaveAttribute("data-theme-active", "false");
    for (const marker of Object.values(markers)) await expect(page.getByText(marker, { exact: false })).toHaveCount(0);
    await context.close();
  });
}

test("logout in one desktop tab clears the authenticated Home in the other tab", async ({ browser }) => {
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const first = await context.newPage();
  const second = await context.newPage();
  const email = `${runPrefix}desktop-a@fanatical.invalid`;

  await signIn(first, email);
  await expectAccountAHome(first, { home: "Private A desktop" });
  await second.goto("/");
  await expect(second.getByRole("heading", { name: "Private A desktop" })).toBeVisible();

  await logoutFromProfile(first);
  await expectNeutralHome(first, ["Private A desktop", "Transition A desktop"]);
  await expect(second.getByRole("heading", { name: "Your home for fandom." })).toBeVisible();
  await expect(second.locator(".home-hero")).toHaveAttribute("data-has-custom-image", "false");
  await expect(second.getByText("Transition A desktop", { exact: false })).toHaveCount(0);
  await context.close();
});
