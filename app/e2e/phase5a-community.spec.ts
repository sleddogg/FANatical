import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { createClient } from "@supabase/supabase-js";
import { expect, test, type Page } from "@playwright/test";

const accounts = Object.freeze({
  brad: { email: "brad@fanatical.invalid", password: "BradPhase5A!2026" },
  testFan: { email: "testfan@fanatical.invalid", password: "TestFanPhase5A!2026" },
});
const runMarker = `Phase 5A browser ${Date.now()}`;
const temporaryEmail = "phase5a-no-name@fanatical.invalid";
const temporaryPassword = "Phase5ANoName!2026";
const temporaryName = "Phase5NoName";

const contexts = [
  {
    panel: "Team",
    option: "Edmonton Oilers",
    headline: "Demo Desk: Oilers set their opening-night focus",
    query: /context=team&target=hockey-000027/,
  },
  {
    panel: "League",
    option: "National Hockey League",
    headline: "Demo Desk: NHL notebook tracks the week ahead",
    query: /context=competition&target=hockey-nhl/,
  },
  {
    panel: "Sport",
    option: "Hockey",
    headline: "Local Demo Podcast: Morning skate briefing",
    query: /context=sport&target=hockey/,
  },
] as const;

function parseEnvironment(output: string) {
  const values = new Map<string, string>();
  for (const line of output.split(/\r?\n/)) {
    const match = line.match(/^([A-Z0-9_]+)=(?:"([^"]*)"|'([^']*)'|(.*))$/);
    if (match) values.set(match[1], (match[2] ?? match[3] ?? match[4] ?? "").trim());
  }
  return values;
}

async function localAdmin() {
  const appDirectory = resolve(import.meta.dirname, "..");
  const repositoryDirectory = resolve(appDirectory, "..");
  const cliPath = resolve(appDirectory, "node_modules/supabase/dist/supabase.js");
  const result = spawnSync(process.execPath, [
    cliPath,
    "status",
    "-o",
    "env",
    "--workdir",
    repositoryDirectory,
  ], {
    cwd: appDirectory,
    encoding: "utf8",
    env: { ...process.env, SUPABASE_TELEMETRY_DISABLED: "1" },
  });
  if (result.status !== 0) throw new Error("Local Supabase must be running for the Phase 5A browser proof.");
  const status = parseEnvironment(result.stdout);
  const apiUrl = status.get("API_URL");
  const serviceKey = status.get("SECRET_KEY") ?? status.get("SERVICE_ROLE_KEY");
  if (!apiUrl || new URL(apiUrl).hostname !== "127.0.0.1" || !serviceKey) {
    throw new Error("The Phase 5A browser proof refuses a non-loopback backend.");
  }
  return createClient(apiUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
}

async function removeTemporaryFan() {
  const admin = await localAdmin();
  const users = await admin.auth.admin.listUsers({ page: 1, perPage: 1_000 });
  if (users.error) throw users.error;
  for (const user of users.data.users.filter((candidate) => candidate.email === temporaryEmail)) {
    const removed = await admin.auth.admin.deleteUser(user.id);
    if (removed.error) throw removed.error;
  }
}

async function signIn(page: Page, account: { email: string; password: string }) {
  await page.goto("/profile");
  await page.locator(".profile-page--signed-out").getByRole("button", { name: "Sign In" }).click();
  await page.getByLabel("Email").fill(account.email);
  await page.getByLabel("Password").fill(account.password);
  await page.getByRole("button", { name: "Sign In", exact: true }).last().click();
  await expect(page.getByRole("region", { name: "Signed in" })).toContainText(account.email);
}

async function selectNewsContext(page: Page, panel: string, option: string) {
  await page.getByRole("button", { name: /Filter News\. Current context:/ }).click();
  const dialog = page.getByRole("dialog", { name: "Choose News context" });
  await dialog.getByRole("button", { name: new RegExp(`^${panel}`) }).click();
  const contextDialog = page.getByRole("dialog", { name: panel });
  if (panel === "Team") await contextDialog.getByLabel("Find a Team").fill(option);
  await contextDialog.getByRole("button", { name: new RegExp(`^${option}`) }).click();
  await expect(page.locator(".news-header__title p")).toHaveText(option);
}

function cardFor(page: Page, headline: string) {
  return page.locator(".news-card").filter({ has: page.getByRole("heading", { name: headline }) });
}

test.describe.configure({ mode: "serial" });
test.setTimeout(90_000);

test.beforeAll(async () => {
  await removeTemporaryFan();
  const admin = await localAdmin();
  const created = await admin.auth.admin.createUser({
    email: temporaryEmail,
    password: temporaryPassword,
    email_confirm: true,
    user_metadata: { display_name: "Phase 5A No-name Fan" },
  });
  if (created.error) throw created.error;
});

test.afterAll(removeTemporaryFan);

test("Brad reaches the Team, Competition, and Sport discussions from their active News filters", async ({ page }) => {
  await page.goto("/news");
  await expect(page.locator(".local-build-marker")).toHaveText("Phase 5A local acceptance · 2026-08-31");
  await signIn(page, accounts.brad);

  await page.goto("/news");
  const defaultTeamCard = cardFor(page, "Demo Desk: Oilers set their opening-night focus");
  await defaultTeamCard.getByRole("link", { name: /Open Edmonton Oilers Discussion/ }).click();
  await expect(page).toHaveURL(/context=team&target=hockey-nhl-edmonton-oilers/);
  await expect(page.getByRole("heading", { name: "Edmonton Oilers", level: 1 })).toBeVisible();
  const articleReference = page.locator(".community-article-reference");
  await expect(articleReference).toContainText("Demo Desk: Oilers set their opening-night focus");
  await expect(articleReference.getByRole("link", { name: /^Open/ })).toBeVisible();
  await page.getByLabel("Add a comment").fill(`${runMarker} Team FANbase`);
  await page.getByRole("button", { name: "Post" }).click();
  await expect(page.getByText(`${runMarker} Team FANbase`)).toBeVisible();

  for (const context of contexts) {
    await page.goto("/news");
    await selectNewsContext(page, context.panel, context.option);
    const card = cardFor(page, context.headline);
    const discussion = card.getByRole("link", { name: new RegExp(`Open ${context.option} Discussion`) });
    await expect(discussion).toBeVisible();
    await discussion.click();
    await expect(page).toHaveURL(context.query);
    await expect(page.getByRole("heading", { name: context.option, level: 1 })).toBeVisible();
  }

  await page.goto("/news");
  await selectNewsContext(page, "Sport", "Hockey");
  for (const headline of [
    "Demo Desk: Oilers set their opening-night focus",
    "Demo Desk: NHL notebook tracks the week ahead",
    "Local Demo Podcast: Morning skate briefing",
  ]) {
    await expect(cardFor(page, headline).getByRole("link", { name: /Open Hockey Discussion/ })).toBeVisible();
  }

  await page.goto("/fanbase");
  await page.getByRole("button", { name: /Article Discussions/ }).click();
  const teamDiscussion = page.getByRole("link", { name: /Demo Desk: Oilers set their opening-night focus/ });
  await expect(teamDiscussion).toContainText(/\d+ comments?/);
  await teamDiscussion.click();
  await expect(page).toHaveURL(/context=team&target=hockey-000027/);
  await expect(page.getByText(`${runMarker} Team FANbase`)).toBeVisible();
});

test("post, reply, inbox, signed-out teaser, and no-name claim use the real Community boundary", async ({ browser }) => {
  const bradContext = await browser.newContext();
  const bradPage = await bradContext.newPage();
  await signIn(bradPage, accounts.brad);
  await bradPage.goto("/news");
  await expect(bradPage.getByRole("link", { name: "Profile" })).toBeVisible();
  const bradInbox = bradPage.getByRole("button", { name: /^Inbox/ });
  await bradInbox.click();
  const initialInbox = bradPage.getByRole("dialog", { name: "Inbox" });
  await expect(initialInbox).toBeVisible();
  await initialInbox.getByRole("button", { name: "Close Inbox" }).click();
  await expect(bradPage.getByRole("button", { name: "Inbox", exact: true })).toBeVisible();
  await bradPage.goto("/news");
  await expect(bradPage.locator(".local-build-marker")).toHaveText("Phase 5A local acceptance · 2026-08-31");
  await selectNewsContext(bradPage, "League", "National Hockey League");
  const leagueCard = cardFor(bradPage, "Demo Desk: NHL notebook tracks the week ahead");
  const initialCountText = await leagueCard.getByText(/^Discussion \d+$/).textContent();
  const initialCount = Number.parseInt(initialCountText?.match(/\d+/)?.[0] ?? "", 10);
  expect(Number.isFinite(initialCount)).toBe(true);
  await leagueCard.getByRole("link", { name: /Open National Hockey League Discussion/ }).click();
  const discussionUrl = bradPage.url();
  await bradPage.getByLabel("Add a comment").fill(`${runMarker} root`);
  await bradPage.getByRole("button", { name: "Post" }).click();
  await expect(bradPage.getByText(`${runMarker} root`)).toBeVisible();

  const testContext = await browser.newContext();
  const testPage = await testContext.newPage();
  await signIn(testPage, accounts.testFan);
  await expect(testPage.getByRole("heading", { name: "Test Fan", level: 1 })).toBeVisible();
  await expect(testPage.locator("body")).not.toContainText("NorthStarFan");
  await testPage.goto(discussionUrl);
  const root = testPage.locator(".community-comment").filter({ hasText: `${runMarker} root` });
  await root.getByRole("button", { name: "Reply" }).click();
  await testPage.getByLabel("Reply to Brad").fill(`${runMarker} reply`);
  await testPage.getByRole("button", { name: "Post" }).click();
  await root.getByRole("button", { name: "Show 1 reply" }).click();
  await expect(testPage.getByText(`${runMarker} reply`)).toBeVisible();

  await bradPage.bringToFront();
  await bradPage.goto("/news");
  await expect(bradPage.getByRole("button", { name: "Inbox, 1 unread" })).toBeVisible({ timeout: 10_000 });
  await bradPage.getByRole("button", { name: "Inbox, 1 unread" }).click();
  await expect(bradPage.getByRole("dialog", { name: "Inbox" })).toContainText("TestFan replied to your comment.");

  const anonymousContext = await browser.newContext();
  const anonymousPage = await anonymousContext.newPage();
  await anonymousPage.goto("/news");
  const anonymousCard = cardFor(anonymousPage, "Demo Desk: NHL notebook tracks the week ahead");
  await expect(anonymousCard.getByText(`Discussion ${initialCount + 2}`)).toBeVisible();
  await anonymousCard.getByRole("link", { name: /Open National Hockey League Discussion/ }).click();
  await expect(anonymousPage.getByRole("heading", { name: `${initialCount + 2} comments` })).toBeVisible();
  await expect(anonymousPage.getByText(`${runMarker} root`)).toHaveCount(0);
  await expect(anonymousPage.getByText(`${runMarker} reply`)).toHaveCount(0);
  await expect(anonymousPage.getByText("Sign in to read comments and participate. Comment bodies are not available anonymously.")).toBeVisible();
  await anonymousPage.getByRole("link", { name: "Sign in", exact: true }).click();
  await expect(anonymousPage).toHaveURL(/\/profile$/);
  await expect(anonymousPage.locator(".profile-page--signed-out").getByRole("button", { name: "Sign In" })).toBeVisible();

  const noNameContext = await browser.newContext();
  const noNamePage = await noNameContext.newPage();
  await signIn(noNamePage, { email: temporaryEmail, password: temporaryPassword });
  await noNamePage.goto(discussionUrl);
  await expect(noNamePage.getByText(`${runMarker} root`)).toBeVisible();
  await expect(noNamePage.getByRole("heading", { name: "Claim a Fanatical Name to participate" })).toBeVisible();
  await expect(noNamePage.getByLabel("Add a comment")).toHaveCount(0);
  await noNamePage.getByLabel("Fanatical Name").fill(temporaryName);
  await noNamePage.getByRole("button", { name: "Claim name" }).click();
  await expect(noNamePage.getByLabel("Add a comment")).toBeVisible();

  await Promise.all([
    noNameContext.close(),
    anonymousContext.close(),
    testContext.close(),
    bradContext.close(),
  ]);
});
