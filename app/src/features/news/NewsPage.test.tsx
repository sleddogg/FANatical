import { act, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { User } from "@supabase/supabase-js";
import type {
  FanSafeNewsItem,
  NewsFollowingEntry,
  NewsFollowTarget,
  NewsNavigationEntry,
} from "./types";

const mocks = vi.hoisted(() => ({
  auth: {
    configured: true,
    loading: false,
    user: { id: "fan-1" } as User | null,
  },
  selectTeam: vi.fn(),
  dismissNewsItem: vi.fn(),
  followNewsTarget: vi.fn(),
  loadMyNewsFollowing: vi.fn(),
  loadMyNewsZeroFollowExample: vi.fn(),
  loadNewsDemoFeed: vi.fn(),
  loadNewsDemoUniverse: vi.fn(),
  loadNewsIdentityItems: vi.fn(),
  loadNewsIdentityProfile: vi.fn(),
  loadNewsNavigation: vi.fn(),
  loadPersonalNewsFeed: vi.fn(),
  muteNewsFollow: vi.fn(),
  recordNewsOutboundOpen: vi.fn(),
  searchNewsFollowTargets: vi.fn(),
  setNewsFollowScopes: vi.fn(),
  undoNewsItemDismissal: vi.fn(),
  unfollowNewsTarget: vi.fn(),
  unmuteNewsFollow: vi.fn(),
}));

vi.mock("../account/AuthContext", () => ({
  useAuth: () => mocks.auth,
}));

vi.mock("../../state/TeamContext", () => ({
  useTeamContext: () => ({
    selectedTeam: {
      id: "edmonton-oilers",
      officialTeamId: "hockey-nhl-edmonton-oilers",
      name: "Edmonton Oilers",
      shortName: "Oilers",
      sport: "Hockey",
      league: "NHL",
      colors: { primary: "#00205B", secondary: "#D14520", tertiary: null, quaternary: null, quinary: null },
    },
    selectedTeamId: "edmonton-oilers",
    followedTeams: [],
    selectTeam: mocks.selectTeam,
  }),
}));

vi.mock("../../state/ThemeContext", () => ({
  useAppTheme: () => ({ active: true, source: "current-team" }),
}));

vi.mock("./newsRepository", () => ({
  dismissNewsItem: mocks.dismissNewsItem,
  followNewsTarget: mocks.followNewsTarget,
  loadMyNewsFollowing: mocks.loadMyNewsFollowing,
  loadMyNewsZeroFollowExample: mocks.loadMyNewsZeroFollowExample,
  loadNewsDemoFeed: mocks.loadNewsDemoFeed,
  loadNewsDemoUniverse: mocks.loadNewsDemoUniverse,
  loadNewsIdentityItems: mocks.loadNewsIdentityItems,
  loadNewsIdentityProfile: mocks.loadNewsIdentityProfile,
  loadNewsNavigation: mocks.loadNewsNavigation,
  loadPersonalNewsFeed: mocks.loadPersonalNewsFeed,
  muteNewsFollow: mocks.muteNewsFollow,
  recordNewsOutboundOpen: mocks.recordNewsOutboundOpen,
  searchNewsFollowTargets: mocks.searchNewsFollowTargets,
  setNewsFollowScopes: mocks.setNewsFollowScopes,
  undoNewsItemDismissal: mocks.undoNewsItemDismissal,
  unfollowNewsTarget: mocks.unfollowNewsTarget,
  unmuteNewsFollow: mocks.unmuteNewsFollow,
}));

import { NewsIdentityProfilePage } from "./NewsIdentityProfilePage";
import { NewsPage } from "./NewsPage";

const navigation: readonly NewsNavigationEntry[] = [
  { filterType: "sport", targetId: "hockey", displayName: "Hockey", sportId: "hockey" },
  { filterType: "competition", targetId: "hockey-nhl", displayName: "NHL", sportId: "hockey" },
  { filterType: "team", targetId: "hockey-000027", displayName: "Edmonton Oilers", sportId: "hockey" },
  { filterType: "team", targetId: "hockey-000028", displayName: "Calgary Flames", sportId: "hockey" },
];

const authorTarget: NewsFollowTarget = {
  targetType: "author",
  targetId: "author-alex",
  displayName: "Alex Reporter",
};

const following: readonly NewsFollowingEntry[] = [{
  ...authorTarget,
  followIds: ["follow-alex"],
  mutedUntil: null,
  needsReselection: false,
  sportScopeIds: [],
  teamScopeIds: [],
}];

const writtenItem: FanSafeNewsItem = {
  id: "news-written",
  itemKind: "written",
  headline: "Oilers prepare for a faster transition game",
  summary: "A governed summary of the published report.",
  publishedAt: "2026-08-29T16:00:00.000Z",
  serverTime: "2026-08-29T17:00:00.000Z",
  destinationUrl: "https://publisher.example/oilers-transition",
  publisher: { id: "publisher-one", name: "Prairie Sports" },
  show: null,
  preview: { url: "https://publisher.example/preview.jpg", kind: "image", alt: "Oilers skating at practice." },
  bylines: [{ rawAttribution: "Alex Original", targetType: "author", targetId: "author-alex" }],
  classifications: [
    { targetType: "sport", targetId: "hockey", displayName: "Hockey" },
    { targetType: "team", targetId: "hockey-000027", displayName: "Edmonton Oilers" },
  ],
};

const podcastItem: FanSafeNewsItem = {
  id: "news-podcast",
  itemKind: "podcast_episode",
  headline: "Podcast: Reading Edmonton's new forecheck",
  summary: "A real podcast episode summary.",
  publishedAt: "2026-08-29T15:00:00.000Z",
  serverTime: "2026-08-29T17:00:00.000Z",
  destinationUrl: "https://publisher.example/podcast/forecheck",
  publisher: { id: "publisher-two", name: "Northern Audio" },
  show: { id: "show-northern", name: "Northern Hockey Hour" },
  preview: null,
  bylines: [{ rawAttribution: "Host Name", targetType: null, targetId: null }],
  classifications: [{ targetType: "sport", targetId: "hockey", displayName: "Hockey" }],
};

function renderNews() {
  return render(<MemoryRouter initialEntries={["/news"]}><Routes><Route path="/news" element={<NewsPage />} /><Route path="/profile" element={<h1>Account</h1>} /></Routes></MemoryRouter>);
}

describe("Phase 4 News frontend", () => {
  beforeEach(() => {
    mocks.auth.configured = true;
    mocks.auth.loading = false;
    mocks.auth.user = { id: "fan-1" } as User;
    mocks.selectTeam.mockReset();
    for (const mock of [
      mocks.dismissNewsItem,
      mocks.followNewsTarget,
      mocks.loadMyNewsFollowing,
      mocks.loadMyNewsZeroFollowExample,
      mocks.loadNewsDemoFeed,
      mocks.loadNewsDemoUniverse,
      mocks.loadNewsIdentityItems,
      mocks.loadNewsIdentityProfile,
      mocks.loadNewsNavigation,
      mocks.loadPersonalNewsFeed,
      mocks.muteNewsFollow,
      mocks.recordNewsOutboundOpen,
      mocks.searchNewsFollowTargets,
      mocks.setNewsFollowScopes,
      mocks.undoNewsItemDismissal,
      mocks.unfollowNewsTarget,
      mocks.unmuteNewsFollow,
    ]) mock.mockReset();
    mocks.loadNewsNavigation.mockResolvedValue(navigation);
    mocks.loadMyNewsFollowing.mockResolvedValue(following);
    mocks.loadMyNewsZeroFollowExample.mockResolvedValue(null);
    mocks.loadPersonalNewsFeed.mockResolvedValue([writtenItem, podcastItem]);
    mocks.loadNewsDemoUniverse.mockResolvedValue([]);
    mocks.loadNewsDemoFeed.mockResolvedValue([]);
    mocks.searchNewsFollowTargets.mockResolvedValue([authorTarget]);
    mocks.dismissNewsItem.mockResolvedValue(undefined);
    mocks.undoNewsItemDismissal.mockResolvedValue(undefined);
    mocks.followNewsTarget.mockResolvedValue(undefined);
    mocks.setNewsFollowScopes.mockResolvedValue(undefined);
    mocks.muteNewsFollow.mockResolvedValue(undefined);
    mocks.unmuteNewsFollow.mockResolvedValue(undefined);
    mocks.unfollowNewsTarget.mockResolvedValue(undefined);
    mocks.recordNewsOutboundOpen.mockResolvedValue(undefined);
  });

  it("renders real written and podcast cards with governed previews, fallback, bylines, and no prototype engagement", async () => {
    renderNews();

    expect(await screen.findByRole("heading", { name: writtenItem.headline })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: podcastItem.headline })).toBeInTheDocument();
    const preview = screen.getByRole("img", { name: "Oilers skating at practice." });
    expect(preview).toHaveAttribute("src", writtenItem.preview?.url);
    expect(preview).toHaveAttribute("referrerpolicy", "no-referrer");
    expect(screen.getByRole("link", { name: /Open Hockey News: Podcast: Reading Edmonton's new forecheck/i })).toBeInTheDocument();
    fireEvent.error(preview);
    expect(screen.getByRole("link", { name: /Open Hockey News: Oilers prepare for a faster transition game/i })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Alex Original" })).toHaveAttribute("href", "/news/authors/author-alex");
    expect(screen.getByRole("link", { name: "Northern Hockey Hour" })).toHaveAttribute("href", "/news/shows/show-northern");
    expect(screen.getAllByText("Written")).toHaveLength(1);
    expect(screen.getAllByText("Podcast")).toHaveLength(1);
    expect(screen.queryByRole("button", { name: /React/i })).not.toBeInTheDocument();
    expect(screen.queryByText(/views/i)).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Discussion/i })).not.toBeInTheDocument();
    expect(screen.queryByText(/New England moved through/i)).not.toBeInTheDocument();
  });

  it("opens the representative publisher destination directly and starts outbound recording without awaiting it", async () => {
    mocks.recordNewsOutboundOpen.mockReturnValue(new Promise(() => undefined));
    renderNews();
    const link = await screen.findByRole("link", { name: `Open ${writtenItem.headline} at ${writtenItem.publisher.name}` });
    expect(link).toHaveAttribute("href", writtenItem.destinationUrl);
    expect(link).toHaveAttribute("target", "_blank");
    expect(link).toHaveAttribute("rel", "noopener noreferrer");
    link.addEventListener("click", (event) => event.preventDefault());
    fireEvent.click(link);
    expect(mocks.recordNewsOutboundOpen).toHaveBeenCalledWith(writtenItem.id, writtenItem.destinationUrl);
  });

  it("shares the representative publisher destination through the clipboard fallback", async () => {
    const writeText = vi.fn().mockResolvedValue(undefined);
    const user = userEvent.setup();
    Object.defineProperty(navigator, "share", { configurable: true, value: undefined });
    Object.defineProperty(navigator, "clipboard", { configurable: true, value: { writeText } });
    renderNews();
    await screen.findByRole("heading", { name: writtenItem.headline });
    await user.click(screen.getByRole("button", { name: `Share ${writtenItem.headline}` }));
    await waitFor(() => expect(writeText).toHaveBeenCalledWith(writtenItem.destinationUrl));
    expect(await screen.findByText("Publisher link copied.")).toBeInTheDocument();
  });

  it("applies a real temporary Competition filter without mutating global Team state", async () => {
    const user = userEvent.setup();
    renderNews();
    const trigger = await screen.findByRole("button", { name: /Filter News/ });
    await waitFor(() => expect(trigger).toBeEnabled());
    await user.click(trigger);
    await user.click(screen.getByRole("button", { name: /^Competition/ }));
    await user.click(screen.getByRole("button", { name: "NHL" }));

    await waitFor(() => expect(mocks.loadPersonalNewsFeed).toHaveBeenLastCalledWith({
      kind: "competition",
      targetId: "hockey-nhl",
      displayName: "NHL",
    }));
    expect(screen.getByText("NHL", { selector: ".news-header__title p" })).toBeInTheDocument();
    expect(mocks.selectTeam).not.toHaveBeenCalled();
  });

  it("contains filter keyboard focus and restores the trigger on Escape", async () => {
    const user = userEvent.setup();
    renderNews();
    const trigger = await screen.findByRole("button", { name: /Filter News/ });
    await waitFor(() => expect(trigger).toBeEnabled());
    await user.click(trigger);
    const dialog = screen.getByRole("dialog", { name: "Choose News context" });
    expect(dialog).toHaveFocus();
    await user.keyboard("{Escape}");
    await waitFor(() => expect(trigger).toHaveFocus());
  });

  it("Dismisses one Item and Undo restores it at its original chronological position", async () => {
    const user = userEvent.setup();
    renderNews();
    await screen.findByRole("heading", { name: writtenItem.headline });
    await user.click(screen.getByRole("button", { name: `Dismiss ${writtenItem.headline}` }));
    expect(screen.queryByRole("heading", { name: writtenItem.headline })).not.toBeInTheDocument();
    expect(mocks.dismissNewsItem).toHaveBeenCalledWith(writtenItem.id);

    await user.click(screen.getByRole("button", { name: "Undo" }));
    expect(mocks.undoNewsItemDismissal).toHaveBeenCalledWith(writtenItem.id);
    const headlines = screen.getAllByRole("heading", { level: 2 }).map((heading) => heading.textContent);
    expect(headlines.slice(0, 2)).toEqual([writtenItem.headline, podcastItem.headline]);
  });

  it("sequences immediate Undo after an in-flight Dismiss so the durable delete wins", async () => {
    let finishDismiss!: () => void;
    const pendingDismiss = new Promise<void>((resolve) => { finishDismiss = resolve; });
    mocks.dismissNewsItem.mockReturnValue(pendingDismiss);
    const user = userEvent.setup();
    renderNews();
    await screen.findByRole("heading", { name: writtenItem.headline });

    await user.click(screen.getByRole("button", { name: `Dismiss ${writtenItem.headline}` }));
    await user.click(screen.getByRole("button", { name: "Undo" }));
    expect(screen.getByRole("heading", { name: writtenItem.headline })).toBeInTheDocument();
    expect(mocks.undoNewsItemDismissal).not.toHaveBeenCalled();

    await act(async () => {
      finishDismiss();
      await pendingDismiss;
    });
    await waitFor(() => expect(mocks.undoNewsItemDismissal).toHaveBeenCalledWith(writtenItem.id));
    expect(screen.getByRole("heading", { name: writtenItem.headline })).toBeInTheDocument();
  });

  it("keeps zero-follow EXAMPLE and filter-zero as distinct signed-in states", async () => {
    mocks.loadMyNewsFollowing.mockResolvedValue([]);
    const first = renderNews();
    expect(await screen.findByText("EXAMPLE")).toBeInTheDocument();
    expect(screen.getByText(/creates no follow or eligibility/i)).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Dismiss/i })).not.toBeInTheDocument();
    first.unmount();

    mocks.loadMyNewsFollowing.mockResolvedValue(following);
    mocks.loadPersonalNewsFeed.mockResolvedValue([]);
    renderNews();
    expect(await screen.findByRole("heading", { name: "No News matches this filter" })).toBeInTheDocument();
    expect(screen.queryByText("EXAMPLE")).not.toBeInTheDocument();
  });

  it("uses only the configured Demo universe in memory and exposes no durable account actions", async () => {
    mocks.auth.user = null;
    const demoTargets: readonly NewsFollowTarget[] = [authorTarget, {
      targetType: "show",
      targetId: "show-northern",
      displayName: "Northern Hockey Hour",
    }];
    mocks.loadNewsDemoUniverse.mockResolvedValue(demoTargets);
    mocks.loadNewsDemoFeed.mockResolvedValue([writtenItem]);
    const user = userEvent.setup();
    renderNews();

    expect(await screen.findByText("Demo mode — sign in to save your feed.")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Dismiss/i })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /Add to Feed/i }));
    const dialog = screen.getByRole("dialog", { name: "Add to Feed" });
    expect(within(dialog).getByRole("heading", { name: "Alex Reporter" })).toBeInTheDocument();
    expect(within(dialog).queryByRole("searchbox")).not.toBeInTheDocument();
    expect(within(dialog).queryByText(/Request/i)).not.toBeInTheDocument();
    expect(mocks.searchNewsFollowTargets).not.toHaveBeenCalled();
    expect(mocks.followNewsTarget).not.toHaveBeenCalled();
  });

  it("supports individual Add to Feed, scopes, mute, and unfollow with no Follow All", async () => {
    const organizationTarget: NewsFollowTarget = {
      targetType: "organization",
      targetId: "organization-wire",
      displayName: "Prairie Wire Desk",
    };
    mocks.searchNewsFollowTargets.mockResolvedValue([organizationTarget]);
    const user = userEvent.setup();
    renderNews();
    await screen.findByRole("heading", { name: writtenItem.headline });
    await user.click(screen.getByRole("button", { name: /Add to Feed/i }));
    const dialog = screen.getByRole("dialog", { name: "Add to Feed" });
    await waitFor(() => expect(mocks.searchNewsFollowTargets).toHaveBeenCalledWith("", null));
    expect(within(dialog).queryByText(/Follow All/i)).not.toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: "Add" }));
    expect(mocks.followNewsTarget).toHaveBeenCalledWith(organizationTarget);
    await user.click(within(dialog).getByRole("tab", { name: "Following" }));

    await user.selectOptions(within(dialog).getByLabelText("Add Sport scope"), "hockey");
    await user.click(within(dialog).getByRole("button", { name: "Save scopes" }));
    expect(mocks.setNewsFollowScopes).toHaveBeenCalledWith(["follow-alex"], ["hockey"], []);

    await user.click(within(dialog).getByRole("button", { name: "Mute 7 days" }));
    expect(mocks.muteNewsFollow).toHaveBeenCalledWith("follow-alex", "7_days");
    await user.click(within(dialog).getByRole("button", { name: "Mute 30 days" }));
    expect(mocks.muteNewsFollow).toHaveBeenCalledWith("follow-alex", "30_days");
    await user.click(within(dialog).getByRole("button", { name: "Unfollow" }));
    expect(mocks.unfollowNewsTarget).toHaveBeenCalledWith("follow-alex");
  });

  it("renders database-derived mute status without a frontend clock and offers Unmute now", async () => {
    mocks.loadMyNewsFollowing.mockResolvedValue([{
      ...following[0]!,
      mutedUntil: "2026-09-05T17:00:00.000Z",
    }]);
    const user = userEvent.setup();
    renderNews();
    await screen.findByRole("heading", { name: writtenItem.headline });
    await user.click(screen.getByRole("button", { name: /Add to Feed/i }));
    const dialog = screen.getByRole("dialog", { name: "Add to Feed" });
    await user.click(within(dialog).getByRole("tab", { name: "Following" }));
    expect(within(dialog).getByText(/Muted through Sep 5, 2026/)).toBeInTheDocument();
    expect(within(dialog).queryByRole("button", { name: "Mute 7 days" })).not.toBeInTheDocument();
    await user.click(within(dialog).getByRole("button", { name: "Unmute now" }));
    expect(mocks.unmuteNewsFollow).toHaveBeenCalledWith("follow-alex");
  });

  it("shows the real official-Team Item as EXAMPLE when the zero-follow contract returns one", async () => {
    mocks.loadMyNewsFollowing.mockResolvedValue([]);
    mocks.loadMyNewsZeroFollowExample.mockResolvedValue(writtenItem);
    renderNews();
    expect(await screen.findByLabelText("Zero-follow News example")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: writtenItem.headline })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: `Dismiss ${writtenItem.headline}` })).not.toBeInTheDocument();
  });

  it("renders canonical contributor profiles and keeps profile Items outside per-feed Dismiss", async () => {
    mocks.loadNewsIdentityProfile.mockResolvedValue(authorTarget);
    mocks.loadNewsIdentityItems.mockResolvedValue([writtenItem]);
    render(
      <MemoryRouter initialEntries={["/news/authors/author-alex"]}>
        <Routes>
          <Route path="/news/authors/:identityId" element={<NewsIdentityProfilePage targetType="author" />} />
          <Route path="/news" element={<h1>News</h1>} />
        </Routes>
      </MemoryRouter>,
    );
    expect(await screen.findByRole("heading", { level: 1, name: "Alex Reporter" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: writtenItem.headline })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /Dismiss/i })).not.toBeInTheDocument();
  });
});
