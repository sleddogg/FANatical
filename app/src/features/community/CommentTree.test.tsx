import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import { CommentTree } from "./CommentTree";
import type { CommunityAvatar, CommunityComment } from "./types";
import "./community.css";
import "../fanbase/fanbase.css";

vi.mock("./CommunityAvatar", () => ({
  CommunityAvatar: ({ avatar, fanaticalName }: { avatar: CommunityAvatar | null; fanaticalName: string | null }) => (
    <span>{fanaticalName ? `${fanaticalName} avatar${avatar ? " image" : ""}` : "Generic avatar"}</span>
  ),
}));

function comment(
  id: string,
  parentId: string | null,
  body: string,
  replyCount: number,
  overrides: Partial<CommunityComment> = {},
): CommunityComment {
  return {
    id,
    parentId,
    body,
    status: "active",
    authorHidden: false,
    fanaticalName: `Fan${id}`,
    avatar: null,
    createdAt: "2026-08-31T12:00:00.000Z",
    edited: false,
    replyCount,
    canReply: true,
    canEdit: false,
    canDelete: false,
    viewerHasReported: false,
    canReport: true,
    canHide: true,
    myHideIntentId: null,
    canUnhide: false,
    ...overrides,
  };
}

const handlers = {
  busy: false,
  onReply: vi.fn(),
  onEdit: vi.fn(),
  onDelete: vi.fn(),
  onHide: vi.fn(),
  onUnhide: vi.fn(),
  onReport: vi.fn(),
};

describe("CommentTree", () => {
  it("stacks sibling branches vertically and visually rebases deep replies without using root indentation", async () => {
    const user = userEvent.setup();
    render(
      <MemoryRouter>
        <CommentTree
          comments={[
            comment("root", null, "Root body", 7),
            comment("a", "root", "Reply A", 0),
            comment("b", "root", "Reply B", 4),
            comment("b-two", "b", "Reply to B", 3),
            comment("b-three", "b-two", "Third-level reply", 2),
            comment("b-four", "b-three", "First outward rebase", 1),
            comment("b-five", "b-four", "Second outward rebase", 0),
            comment("c", "root", "Reply C", 0),
          ]}
          {...handlers}
        />
      </MemoryRouter>,
    );

    expect(screen.getByText("Root body")).toBeInTheDocument();
    expect(screen.queryByText("Reply A")).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Show 7 replies" }));
    await user.click(screen.getByRole("button", { name: "Show 4 replies" }));
    await user.click(screen.getByRole("button", { name: "Show 3 replies" }));
    await user.click(screen.getByRole("button", { name: "Show 2 replies" }));
    await user.click(screen.getByRole("button", { name: "Show 1 reply" }));

    const root = screen.getByText("Root body").closest("li")!;
    const replyA = screen.getByText("Reply A").closest("li")!;
    const replyB = screen.getByText("Reply B").closest("li")!;
    const replyC = screen.getByText("Reply C").closest("li")!;
    const replyToB = screen.getByText("Reply to B").closest("li")!;
    const thirdLevel = screen.getByText("Third-level reply").closest("li")!;
    const firstRebase = screen.getByText("First outward rebase").closest("li")!;
    const secondRebase = screen.getByText("Second outward rebase").closest("li")!;

    expect(getComputedStyle(root).display).toBe("block");
    expect(getComputedStyle(root).width).toBe("100%");
    expect(replyA.parentElement).toBe(replyB.parentElement);
    expect(replyB.parentElement).toBe(replyC.parentElement);
    expect(getComputedStyle(replyA.parentElement!).display).toBe("block");
    expect(root).toHaveAttribute("data-visual-indent", "0");
    expect(replyA).toHaveAttribute("data-visual-indent", "1");
    expect(replyB).toHaveAttribute("data-visual-indent", "1");
    expect(replyC).toHaveAttribute("data-visual-indent", "1");
    expect(replyToB).toHaveAttribute("data-visual-indent", "2");
    expect(thirdLevel).toHaveAttribute("data-visual-indent", "3");
    expect(firstRebase).toHaveAttribute("data-visual-indent", "2");
    expect(secondRebase).toHaveAttribute("data-visual-indent", "1");
    expect(replyA.style.getPropertyValue("--community-branch-color")).not.toBe(replyB.style.getPropertyValue("--community-branch-color"));
    expect(replyB.style.getPropertyValue("--community-branch-color")).not.toBe(replyC.style.getPropertyValue("--community-branch-color"));
    expect(replyToB.style.getPropertyValue("--community-branch-color")).toBe(replyB.style.getPropertyValue("--community-branch-color"));
    expect(screen.getByText("Replying to Fanb-three")).toBeInTheDocument();
    expect(screen.getByLabelText(/Reply in thread: Fanroot then Fanb then Fanb-two then Fanb-three then Fanb-four then Fanb-five/)).toBeInTheDocument();
  });

  it("offers the independent reverse-Hide action on unavailable content", async () => {
    const user = userEvent.setup();
    const onHide = vi.fn();
    render(
      <MemoryRouter>
        <CommentTree
          comments={[comment("hidden", null, "Content unavailable", 0, {
            status: "unavailable",
            authorHidden: true,
            fanaticalName: null,
            canReply: false,
            canReport: false,
            canHide: true,
          })]}
          {...handlers}
          onHide={onHide}
        />
      </MemoryRouter>,
    );

    await user.click(screen.getByRole("button", { name: "Hide user" }));
    expect(onHide).toHaveBeenCalledWith(expect.objectContaining({ id: "hidden" }));
  });

  it("shows Hidden fan for a hidden tombstone and restores current attribution after unhide", () => {
    const restoredAvatar: CommunityAvatar = {
      displayPath: "opaque/restored.webp",
      width: 256,
      height: 256,
      focalX: 0.5,
      focalY: 0.5,
      zoom: 1,
    };
    const { rerender } = render(
      <MemoryRouter>
        <CommentTree
          comments={[comment("deleted", null, "Comment deleted", 0, {
            status: "deleted",
            authorHidden: true,
            fanaticalName: null,
            avatar: null,
            canReply: false,
            canReport: false,
            canHide: false,
            myHideIntentId: "hide-1",
            canUnhide: true,
          })]}
          {...handlers}
        />
      </MemoryRouter>,
    );

    expect(screen.getByText("Hidden fan")).toBeInTheDocument();
    expect(screen.getByText("Comment deleted")).toBeInTheDocument();
    expect(screen.queryByText("Unavailable author")).not.toBeInTheDocument();

    rerender(
      <MemoryRouter>
        <CommentTree
          comments={[comment("deleted", null, "Comment deleted", 0, {
            status: "deleted",
            authorHidden: false,
            fanaticalName: "RestoredFan",
            avatar: restoredAvatar,
            canReply: false,
            canReport: false,
            canHide: false,
          })]}
          {...handlers}
        />
      </MemoryRouter>,
    );

    expect(screen.getByRole("link", { name: "RestoredFan" })).toBeInTheDocument();
    expect(screen.getByText("RestoredFan avatar image")).toBeInTheDocument();
    expect(screen.getByText("Comment deleted")).toBeInTheDocument();
    expect(screen.queryByText("Hidden fan")).not.toBeInTheDocument();
    expect(screen.queryByText("Unavailable author")).not.toBeInTheDocument();
  });

  it("renders a completed report as Reported without another active Report action", () => {
    render(
      <MemoryRouter>
        <CommentTree
          comments={[comment("reported", null, "Reported body", 0, {
            canReport: false,
            viewerHasReported: true,
          })]}
          {...handlers}
        />
      </MemoryRouter>,
    );

    expect(screen.getByText("Reported")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Report" })).not.toBeInTheDocument();
  });

  it("hides participation controls from suspended capability data without removing safety actions", () => {
    render(
      <MemoryRouter>
        <CommentTree
          comments={[
            comment("owner", null, "Viewer-owned comment", 0, {
              canReply: false,
              canEdit: false,
              canDelete: false,
              canHide: false,
              canReport: false,
            }),
            comment("other", null, "Another fan comment", 0, {
              canReply: false,
              canEdit: false,
              canDelete: false,
              canHide: true,
              canReport: true,
            }),
          ]}
          {...handlers}
        />
      </MemoryRouter>,
    );

    expect(screen.queryByRole("button", { name: "Reply" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Edit" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Delete" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Hide user" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Report" })).toBeInTheDocument();
  });
});
