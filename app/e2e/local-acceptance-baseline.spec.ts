import { networkInterfaces } from "node:os";
import { expect, test } from "@playwright/test";

const credentials = Object.freeze({
  email: "dummy@fanatical.invalid",
  password: "dummy123",
});

const expectedHeadlines = [
  "Demo Desk: Oilers set their opening-night focus",
  "Demo Desk: NHL notebook tracks the week ahead",
  "Local Demo Podcast: Morning skate briefing",
] as const;
const acceptancePort = process.env.FANATICAL_ACCEPTANCE_PORT ?? "4173";

function lanAddress() {
  for (const addresses of Object.values(networkInterfaces())) {
    const address = addresses?.find((candidate) => candidate.family === "IPv4" && !candidate.internal);
    if (address) return address.address;
  }
  throw new Error("A LAN IPv4 address is required for the local acceptance browser proof.");
}

const origins = [
  { name: "desktop", origin: () => `http://127.0.0.1:${acceptancePort}`, viewport: { width: 1440, height: 900 } },
  { name: "phone/LAN", origin: () => `http://${lanAddress()}:${acceptancePort}`, viewport: { width: 390, height: 844 } },
] as const;

test.describe.configure({ mode: "serial" });

for (const target of origins) {
  test(`${target.name} signed-out Demo and visible Dummy Fan sign-in use only the local proxy`, async ({ browser }) => {
    const origin = target.origin();
    const context = await browser.newContext({ viewport: target.viewport });
    const page = await context.newPage();
    const backendRequests: string[] = [];
    const directExternalRequests: string[] = [];
    const authResponses: number[] = [];
    let submittedEmail = "";

    page.on("request", (request) => {
      const url = new URL(request.url());
      if (url.pathname.startsWith("/supabase/")) {
        backendRequests.push(request.url());
        if (url.pathname === "/supabase/auth/v1/token") {
          try {
            const body = request.postDataJSON() as { email?: string };
            submittedEmail = body.email ?? "";
          } catch {
            submittedEmail = "";
          }
        }
      } else if (url.origin !== origin) {
        directExternalRequests.push(request.url());
      }
    });
    page.on("response", (response) => {
      if (new URL(response.url()).pathname === "/supabase/auth/v1/token") authResponses.push(response.status());
    });

    await page.goto(`${origin}/news`);
    await expect(page.locator(".news-header__title p")).toHaveText("All Demo News");
    await expect(page.getByText("Demo mode — sign in to save your feed.")).toBeVisible();
    await expect(page.getByRole("heading", { name: "Demo Mode is not configured yet" })).toHaveCount(0);
    await expect(page.locator(".news-card")).toHaveCount(3);
    for (const headline of expectedHeadlines) await expect(page.getByRole("heading", { name: headline })).toBeVisible();
    await expect(page.locator(".news-card__image--fallback")).toHaveCount(3);
    await expect(page.locator(".news-card__image img")).toHaveCount(0);
    await expect(page.locator('.news-card__headline[href^="https://local-demo.fanatical.invalid/"]')).toHaveCount(3);

    await page.goto(`${origin}/profile`);
    await page.getByRole("button", { name: "Sign In", exact: true }).first().click();
    await page.getByLabel("Email").fill(credentials.email);
    await page.getByLabel("Password").fill(credentials.password);
    await page.getByRole("button", { name: "Sign In", exact: true }).last().click();
    await expect(page.getByRole("region", { name: "Signed in" })).toContainText(credentials.email);
    await expect.poll(() => authResponses).toContain(200);

    expect(submittedEmail).toBe(credentials.email);
    expect(backendRequests.length).toBeGreaterThan(0);
    expect(backendRequests.every((requestUrl) => new URL(requestUrl).origin === origin)).toBe(true);
    expect(directExternalRequests).toEqual([]);
    expect([...backendRequests, ...directExternalRequests].some((requestUrl) => new URL(requestUrl).hostname.endsWith(".supabase.co"))).toBe(false);
    await context.close();
  });
}
