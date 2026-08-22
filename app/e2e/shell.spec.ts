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

      if (viewport.name === "phone") {
        const titleWidth = await page.locator(".news-header__title").evaluate((title) => title.getBoundingClientRect().width);
        expect(titleWidth).toBeGreaterThanOrEqual(220);
      }

      const newsLink = page.getByRole("navigation", { name: "Application navigation" }).getByRole("link", {
        name: "News",
      });
      await expect(newsLink).toHaveAttribute("aria-current", "page");
      await expect(page.getByRole("navigation", { name: "Application navigation" })).toBeVisible();
    });
  });
}

test.describe("themed News navigation", () => {
  test.use({ viewport: { width: 1280, height: 800 } });

  test("matches the shared Home bar treatment", async ({ page }) => {
    await page.addInitScript(() => {
      window.localStorage.setItem("fanatical.theme-preference.v1", JSON.stringify({
        source: "custom",
        order: "normal",
        customColor1: "#00205B",
        customColor2: "#D14520",
      }));
    });
    await page.goto("/news");
    await expect(page.getByRole("heading", { name: "News" })).toBeVisible();
    await expect(page.getByRole("navigation", { name: "Application navigation" })).toBeVisible();

    const styles = await page.evaluate(() => {
      const header = document.querySelector<HTMLElement>(".news-header")!;
      const feed = document.querySelector<HTMLElement>(".news-feed-field")!;
      const navigation = document.querySelector<HTMLElement>(".bottom-navigation--inner")!;
      const featurePill = navigation.querySelector<HTMLElement>(".bottom-navigation__feature-links")!;
      const brand = navigation.querySelector<HTMLElement>(".brand-mark")!;
      const profile = navigation.querySelector<HTMLElement>(".profile-avatar-media")!;
      return {
        headerPaddingTop: Number.parseFloat(getComputedStyle(header).paddingTop),
        headerPaddingBottom: Number.parseFloat(getComputedStyle(header).paddingBottom),
        headingLineHeight: Number.parseFloat(getComputedStyle(header.querySelector("h1")!).lineHeight),
        subtitleMarginTop: Number.parseFloat(getComputedStyle(header.querySelector("p")!).marginTop),
        feedBackground: getComputedStyle(feed).backgroundColor,
        navigationBackground: getComputedStyle(navigation).backgroundColor,
        navigationBorderTop: getComputedStyle(navigation).borderTopWidth,
        navigationBorderLeft: getComputedStyle(navigation).borderLeftWidth,
        navigationBorderRight: getComputedStyle(navigation).borderRightWidth,
        featurePillBackground: getComputedStyle(featurePill).backgroundColor,
        featurePillShadow: getComputedStyle(featurePill).boxShadow,
        brandShadow: getComputedStyle(brand).boxShadow,
        profileShadow: getComputedStyle(profile).boxShadow,
      };
    });

    expect(styles.headerPaddingTop).toBeCloseTo(11.56, 1);
    expect(styles.headerPaddingBottom).toBeCloseTo(17.34, 1);
    expect(styles.headingLineHeight).toBeGreaterThanOrEqual(44);
    expect(styles.headingLineHeight).toBeLessThanOrEqual(46);
    expect(styles.subtitleMarginTop).toBe(6);
    expect(styles.navigationBackground).toBe(styles.feedBackground);
    expect(styles.navigationBorderTop).toBe("3px");
    expect(styles.navigationBorderLeft).toBe("0px");
    expect(styles.navigationBorderRight).toBe("0px");
    expect(styles.featurePillBackground).toBe("rgb(255, 255, 255)");
    expect(styles.featurePillShadow).toContain("3px");
    expect(styles.brandShadow).toContain("3px");
    expect(styles.profileShadow).toContain("3px");
  });
});
