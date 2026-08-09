import { expect, test } from "@playwright/test";

const viewports = [
  { name: "phone", width: 390, height: 844 },
  { name: "tablet", width: 768, height: 1024 },
  { name: "laptop", width: 1280, height: 800 },
  { name: "desktop", width: 1920, height: 1080 },
] as const;

for (const viewport of viewports) {
  test.describe(`${viewport.name} shell`, () => {
    test.use({ viewport: { width: viewport.width, height: viewport.height } });

    test("renders, navigates, and stays inside the viewport", async ({ page }) => {
      await page.goto("/");

      await expect(page.getByRole("heading", { name: "Your home for fandom." })).toBeVisible();
      await expect(page.getByRole("navigation", { name: "Home navigation" })).toBeVisible();

      const overflow = await page.evaluate(
        () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
      );
      expect(overflow).toBeLessThanOrEqual(1);

      await page.getByRole("link", { name: "News" }).first().click();
      await expect(page).toHaveURL(/\/news$/);
      await expect(page.getByRole("heading", { name: "News" })).toBeVisible();

      const newsLink = page.getByRole("navigation", { name: "Application navigation" }).getByRole("link", {
        name: "News",
      });
      await expect(newsLink).toHaveAttribute("aria-current", "page");
      await expect(page.getByRole("navigation", { name: "Application navigation" })).toBeVisible();
    });
  });
}
