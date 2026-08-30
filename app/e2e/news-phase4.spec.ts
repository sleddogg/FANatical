import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { createClient } from "@supabase/supabase-js";
import {
  expect,
  test,
  type BrowserContext,
  type Page,
  type Route,
} from "@playwright/test";

const browserUserPrefix = `phase4-browser-${Date.now()}-`;
const browserPassword = "Phase4-browser-proof-2026!";

const viewports = [
  { name: "phone", width: 390, height: 844 },
  { name: "desktop", width: 1440, height: 900 },
] as const;

const navigationRows = [
  {
    filter_type: "sport",
    target_id: "hockey",
    display_name: "Hockey",
    sport_id: "hockey",
  },
  {
    filter_type: "competition",
    target_id: "hockey-nhl",
    display_name: "NHL",
    sport_id: "hockey",
  },
  {
    filter_type: "team",
    target_id: "hockey-000027",
    display_name: "Edmonton Oilers",
    sport_id: "hockey",
  },
] as const;

const demoTargets = [
  {
    target_type: "author",
    target_id: "author-phase4-browser",
    display_name: "Phase 4 Browser Author",
    ordinal: 1,
  },
  {
    target_type: "show",
    target_id: "show-phase4-browser",
    display_name: "Phase 4 Hockey Show",
    ordinal: 2,
  },
] as const;

const writtenHeadline = "Phase 4 browser proof opens the publisher directly";
const podcastHeadline = "Phase 4 Hockey Show checks the morning lineup";

const writtenItem = {
  news_item_id: "news-item-phase4-browser-written",
  item_kind: "written",
  headline: writtenHeadline,
  summary: "A stable browser fixture for the fan-safe written News card.",
  publication_time: "2026-08-29T16:00:00.000Z",
  server_time: "2026-08-29T17:00:00.000Z",
  destination_url: "https://publisher.example/phase4-written",
  publisher_id: "phase4-publisher",
  publisher_name: "Phase 4 Publisher",
  show_id: null,
  show_name: null,
  preview_url: null,
  preview_kind: null,
  preview_alt_text: null,
  bylines: [{
    raw_attribution: "Phase 4 Browser Author",
    target_type: "author",
    target_id: "author-phase4-browser",
  }],
  classifications: [
    {
      target_type: "sport",
      target_public_id: "hockey",
      target_display_name: "Hockey",
    },
    {
      target_type: "team",
      target_public_id: "hockey-000027",
      target_display_name: "Edmonton Oilers",
    },
  ],
};

const podcastItem = {
  news_item_id: "news-item-phase4-browser-podcast",
  item_kind: "podcast_episode",
  headline: podcastHeadline,
  summary: "A stable browser fixture for the fan-safe podcast News card.",
  publication_time: "2026-08-29T15:00:00.000Z",
  server_time: "2026-08-29T17:00:00.000Z",
  destination_url: "https://publisher.example/phase4-podcast",
  publisher_id: "phase4-publisher",
  publisher_name: "Phase 4 Publisher",
  show_id: "show-phase4-browser",
  show_name: "Phase 4 Hockey Show",
  preview_url: null,
  preview_kind: null,
  preview_alt_text: null,
  bylines: [],
  classifications: [
    {
      target_type: "sport",
      target_public_id: "hockey",
      target_display_name: "Hockey",
    },
    {
      target_type: "competition",
      target_public_id: "hockey-nhl",
      target_display_name: "NHL",
    },
  ],
};

type Phase4MockState = {
  following: Set<string>;
  dismissed: Set<string>;
  followCalls: string[];
  outboundStarted: boolean;
  releaseOutbound: (() => void) | null;
};

function parseEnvironment(output: string) {
  const values = new Map<string, string>();
  for (const line of output.split(/\r?\n/)) {
    const match = line.match(/^([A-Z0-9_]+)=(?:"([^"]*)"|'([^']*)'|(.*))$/);
    if (match) values.set(match[1], (match[2] ?? match[3] ?? match[4] ?? "").trim());
  }
  return values;
}

async function removePhase4BrowserUsers() {
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
  if (result.status !== 0) {
    throw new Error("Local Supabase must be running for the Phase 4 browser proof.");
  }
  const status = parseEnvironment(result.stdout);
  const apiUrl = status.get("API_URL");
  const serviceKey = status.get("SECRET_KEY") ?? status.get("SERVICE_ROLE_KEY");
  if (!apiUrl || !serviceKey) {
    throw new Error("Local Supabase admin credentials were unavailable.");
  }

  const admin = createClient(apiUrl, serviceKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
  const users = await admin.auth.admin.listUsers({ page: 1, perPage: 1_000 });
  if (users.error) throw users.error;
  for (const user of users.data.users.filter((candidate) => (
    candidate.email?.startsWith(browserUserPrefix)
  ))) {
    const removal = await admin.auth.admin.deleteUser(user.id);
    if (removal.error) throw removal.error;
  }
}

function rpcName(route: Route) {
  return new URL(route.request().url()).pathname.split("/").at(-1) ?? "";
}

function rpcArguments(route: Route): Record<string, unknown> {
  try {
    return route.request().postDataJSON() as Record<string, unknown>;
  } catch {
    return {};
  }
}

function rpcResponse(route: Route, data: unknown) {
  return route.fulfill({
    status: 200,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "content-range": "0-999/*",
    },
    body: JSON.stringify(data),
  });
}

function followingRows(state: Phase4MockState) {
  const rows = [];
  if (state.following.has("author-phase4-browser")) {
    rows.push({
      target_type: "author",
      target_id: "author-phase4-browser",
      display_name: "Phase 4 Browser Author",
      follow_ids: ["10000000-0000-0000-0000-000000000001"],
      muted_until: null,
      needs_reselection: false,
      sport_scope_ids: [],
      team_scope_ids: [],
    });
  }
  if (state.following.has("show-phase4-browser")) {
    rows.push({
      target_type: "show",
      target_id: "show-phase4-browser",
      display_name: "Phase 4 Hockey Show",
      follow_ids: ["10000000-0000-0000-0000-000000000002"],
      muted_until: null,
      needs_reselection: false,
      sport_scope_ids: [],
      team_scope_ids: [],
    });
  }
  return rows;
}

function filteredItems(
  state: Phase4MockState,
  arguments_: Record<string, unknown>,
) {
  const filterKind = arguments_.filter_kind_value;
  const target = arguments_.filter_target_public_id_value;
  const available = filterKind === "competition" && target === "hockey-nhl"
    ? [podcastItem]
    : filterKind === "team" && target === "hockey-000027"
      ? [writtenItem]
      : [writtenItem, podcastItem];
  return available.filter((item) => !state.dismissed.has(item.news_item_id));
}

async function installNewsMocks(
  page: Page,
  context: BrowserContext,
  state: Phase4MockState,
) {
  await context.route("https://publisher.example/**", (route) => route.fulfill({
    status: 200,
    contentType: "text/html",
    body: "<!doctype html><title>Publisher proof</title><h1>Publisher destination</h1>",
  }));

  await page.route("**/supabase/rest/v1/rpc/**", async (route) => {
    const name = rpcName(route);
    const arguments_ = rpcArguments(route);
    if (name === "get_news_navigation") return rpcResponse(route, navigationRows);
    if (name === "get_news_demo_universe") return rpcResponse(route, demoTargets);
    if (name === "get_news_demo_feed") {
      const selections = Array.isArray(arguments_.selected_targets_value)
        ? arguments_.selected_targets_value as Array<Record<string, unknown>>
        : [];
      const selectedIds = new Set(selections.map((selection) => selection.target_id));
      const rows = [
        ...(selectedIds.has("author-phase4-browser") ? [writtenItem] : []),
        ...(selectedIds.has("show-phase4-browser") ? [podcastItem] : []),
      ];
      return rpcResponse(route, rows);
    }
    if (name === "get_my_news_following") {
      return rpcResponse(route, followingRows(state));
    }
    if (name === "get_my_news_feed") {
      return rpcResponse(route, filteredItems(state, arguments_));
    }
    if (name === "get_my_news_zero_follow_example") return rpcResponse(route, []);
    if (name === "search_news_follow_targets") return rpcResponse(route, demoTargets);
    if (name === "follow_news_identity") {
      const targetId = String(arguments_.target_public_id_value ?? "");
      state.following.add(targetId);
      state.followCalls.push(targetId);
      return rpcResponse(route, "10000000-0000-0000-0000-000000000099");
    }
    if (name === "dismiss_news_item") {
      state.dismissed.add(String(arguments_.news_item_public_id_value ?? ""));
      return rpcResponse(route, null);
    }
    if (name === "undo_news_item_dismissal") {
      state.dismissed.delete(String(arguments_.news_item_public_id_value ?? ""));
      return rpcResponse(route, null);
    }
    if (name === "record_news_outbound_open") {
      state.outboundStarted = true;
      await new Promise<void>((resolvePending) => {
        const timeout = setTimeout(resolvePending, 5_000);
        state.releaseOutbound = () => {
          clearTimeout(timeout);
          resolvePending();
        };
      });
      state.releaseOutbound = null;
      return rpcResponse(route, "10000000-0000-0000-0000-000000000098");
    }
    return route.fallback();
  });
}

async function expectNoHorizontalOverflow(page: Page) {
  const overflow = await page.evaluate(
    () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
  );
  expect(overflow).toBeLessThanOrEqual(1);
}

async function createSignedInFan(page: Page, viewportName: string) {
  const email = `${browserUserPrefix}${viewportName}@fanatical.invalid`;
  await page.addInitScript(() => {
    window.localStorage.setItem("fanatical.selected-team-id", "edmonton-oilers");
  });
  await page.goto("/profile");
  await page.getByRole("button", { name: "Create Account", exact: true }).first().click();
  await page.getByLabel("Display name").fill(`Phase 4 ${viewportName} Fan`);
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(browserPassword);
  await page.getByRole("button", { name: "Create Account", exact: true }).last().click();
  await expect(page.getByRole("region", { name: "Signed in" })).toContainText(email);
}

test.describe.configure({ mode: "serial" });
test.beforeAll(removePhase4BrowserUsers);
test.afterAll(removePhase4BrowserUsers);

for (const viewport of viewports) {
  test.describe(`${viewport.name} Phase 4 News`, () => {
    test.use({ viewport: { width: viewport.width, height: viewport.height } });

    test("runs signed-out Demo Mode through Add to Feed and feed rendering", async ({
      context,
      page,
    }) => {
      const state: Phase4MockState = {
        following: new Set(["author-phase4-browser"]),
        dismissed: new Set(),
        followCalls: [],
        outboundStarted: false,
        releaseOutbound: null,
      };
      await installNewsMocks(page, context, state);
      await page.goto("/news");

      await expect(page.getByText("Demo mode — sign in to save your feed.")).toBeVisible();
      await expect(page.getByRole("heading", { name: writtenHeadline })).toBeVisible();
      await expect(page.getByRole("heading", { name: podcastHeadline })).toBeVisible();
      await expect(page.getByRole("button", { name: /Dismiss / })).toHaveCount(0);

      await page.getByRole("button", { name: "Add to Feed" }).first().click();
      const dialog = page.getByRole("dialog", { name: "Add to Feed" });
      const authorCard = dialog.locator(".source-card").filter({
        hasText: "Phase 4 Browser Author",
      });
      await authorCard.getByRole("button", { name: "Following" }).click();
      await expect(authorCard.getByRole("button", { name: "Follow" })).toBeVisible();
      await authorCard.getByRole("button", { name: "Follow" }).click();
      await expect(authorCard.getByRole("button", { name: "Following" })).toBeVisible();
      await dialog.getByRole("button", { name: "Close Add to Feed" }).click();

      await expect(page.getByRole("heading", { name: writtenHeadline })).toBeVisible();
      await expectNoHorizontalOverflow(page);
    });

    test("runs the signed-in personal feed without mutating global Team state", async ({
      context,
      page,
    }) => {
      const state: Phase4MockState = {
        following: new Set(["author-phase4-browser"]),
        dismissed: new Set(),
        followCalls: [],
        outboundStarted: false,
        releaseOutbound: null,
      };
      await installNewsMocks(page, context, state);
      await createSignedInFan(page, viewport.name);
      await page.goto("/news");

      await expect(page.getByRole("heading", { name: writtenHeadline })).toBeVisible();
      await expect(page.getByText("Demo mode — sign in to save your feed.")).toHaveCount(0);

      await page.getByRole("button", { name: "Add to Feed" }).first().click();
      const addDialog = page.getByRole("dialog", { name: "Add to Feed" });
      const showCard = addDialog.locator(".source-card").filter({
        hasText: "Phase 4 Hockey Show",
      });
      await showCard.getByRole("button", { name: "Add" }).click();
      await expect.poll(() => state.followCalls).toContain("show-phase4-browser");
      await addDialog.getByRole("button", { name: "Close Add to Feed" }).click();

      const selectedTeamBefore = await page.evaluate(
        () => window.localStorage.getItem("fanatical.selected-team-id"),
      );
      await page.getByRole("button", { name: /Filter News/ }).click();
      await page.getByRole("dialog", { name: "Choose News context" })
        .getByRole("button", { name: /Competition/ })
        .click();
      await page.getByRole("dialog", { name: "Competition" })
        .getByRole("button", { name: "NHL" })
        .click();
      await expect(page.locator(".news-header__title p")).toHaveText("NHL");
      expect(await page.evaluate(
        () => window.localStorage.getItem("fanatical.selected-team-id"),
      )).toBe(selectedTeamBefore);

      await expect(page.getByRole("heading", { name: podcastHeadline })).toBeVisible();
      await page.getByRole("button", { name: `Dismiss ${podcastHeadline}` }).click();
      await expect(page.getByRole("heading", { name: podcastHeadline })).toHaveCount(0);
      await page.getByRole("button", { name: "Undo" }).click();
      await expect(page.getByRole("heading", { name: podcastHeadline })).toBeVisible();

      const popupPromise = page.waitForEvent("popup");
      await page.getByRole("link", {
        name: `Open ${podcastHeadline} at Phase 4 Publisher`,
        exact: true,
      }).click();
      const publisherPage = await popupPromise;
      await expect(publisherPage.getByRole("heading", { name: "Publisher destination" }))
        .toBeVisible();
      await expect.poll(() => state.outboundStarted).toBe(true);
      state.releaseOutbound?.();
      await publisherPage.close();

      await expectNoHorizontalOverflow(page);
    });
  });
}
