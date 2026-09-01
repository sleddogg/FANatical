import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ArticleReferenceCard, CommunitySuspensionNotice } from "./CommunityDiscussionPage";
import type { CommunityArticleReference } from "./types";

const article: CommunityArticleReference = {
  newsItemId: "news-item-one",
  itemKind: "written",
  headline: "A contextual News article",
  publishedAt: "2026-09-01T12:00:00.000Z",
  destinationUrl: "https://publisher.example/article",
  publisherName: "Publisher Example",
  showName: null,
  preview: {
    url: "https://publisher.example/preview.jpg",
    kind: "image",
    alt: "Publisher-provided preview",
  },
  bylines: ["Reporter One"],
};

describe("ArticleReferenceCard", () => {
  it("does not send a referrer when loading a publisher-hosted preview image", () => {
    render(<ArticleReferenceCard article={article} />);

    expect(screen.getByRole("img", { name: "Publisher-provided preview" }))
      .toHaveAttribute("referrerpolicy", "no-referrer");
  });
});

describe("CommunitySuspensionNotice", () => {
  it("states that Community is read-only while participation is suspended", () => {
    render(<CommunitySuspensionNotice suspendedUntil="2026-09-08T12:00:00.000Z" />);

    const notice = screen.getByRole("status");
    expect(notice).toHaveTextContent("You may continue reading Community content");
    expect(notice).toHaveTextContent("cannot post, reply, edit, or delete comments while suspended");
  });
});
