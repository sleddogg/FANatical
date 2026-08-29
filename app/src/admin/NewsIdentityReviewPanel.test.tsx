import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { NewsIdentityReviewPanel } from "./NewsIdentityReviewPanel";
import {
  listNewsIdentityReviewCases,
  submitNewsIdentityReview,
  type NewsIdentityReviewCase,
} from "./newsIdentityReviewRepository";

vi.mock("./newsIdentityReviewRepository", async (importOriginal) => {
  const original = await importOriginal<typeof import("./newsIdentityReviewRepository")>();
  return {
    ...original,
    listNewsIdentityReviewCases: vi.fn(),
    submitNewsIdentityReview: vi.fn(),
  };
});

const reviewCase: NewsIdentityReviewCase = {
  id: "case-uuid",
  publicId: "news-identity-case-synthetic",
  kind: "person_merge",
  proposedType: "human",
  proposedName: "Alex Rivers",
  rawByline: "By Alex Rivers",
  profileUrl: "https://publisher.example/authors/alex-rivers",
  publisherName: "Synthetic Publisher",
  publisherId: "synthetic-publisher",
  publisherSourceId: "publisher-uuid",
  status: "needs_review",
  automaticResult: "review_required",
  stopReason: "missing_identity_bridge",
  question: "Are these same-name people actually one person?",
  subjectPersonId: "subject-person-uuid",
  subjectOrganizationId: null,
  subjectShowId: null,
  subjectProfileId: null,
  context: {},
  possibleMatches: [{
    id: "candidate-uuid",
    display_name: "Alex Rivers",
    identity_type: "human",
    person_id: "candidate-person-uuid",
  }, {
    id: "candidate-profile-row-uuid",
    display_name: "Publisher profile candidate",
    identity_type: "publisher_profile",
    contributor_profile_id: "candidate-profile-uuid",
  }],
  evidence: [{
    id: "evidence-uuid",
    summary: "A matching name is only supporting evidence.",
    kind: "name_match",
    class: "supporting",
    visibility: "visible_public",
    is_conflicting: false,
    url: "https://publisher.example/authors/alex-rivers",
  }],
  affiliations: [{
    id: "relationship-uuid",
    publisher_name: "Previous Publisher",
    relationship_type: "unknown",
    effective_from: "2021-01-01T00:00:00Z",
    effective_to: "2023-01-01T00:00:00Z",
    is_current: false,
  }],
  decisions: [{
    id: "decision-uuid",
    action: "automatic_review_required",
    origin: "automatic",
    rule: "explicit_public_identity_bridge",
    stop_reason: "missing_identity_bridge",
  }],
  createdAt: "2026-08-28T00:00:00Z",
  updatedAt: "2026-08-28T00:00:00Z",
};

describe("News identity review panel", () => {
  beforeEach(() => {
    vi.mocked(listNewsIdentityReviewCases).mockReset();
    vi.mocked(submitNewsIdentityReview).mockReset();
    vi.mocked(listNewsIdentityReviewCases).mockResolvedValue([reviewCase]);
    vi.mocked(submitNewsIdentityReview).mockResolvedValue("decision-result-uuid");
  });

  it("shows the unresolved question, candidates, evidence, history, and every required review action", async () => {
    render(<NewsIdentityReviewPanel />);

    expect(await screen.findByRole("heading", { name: "Alex Rivers" })).toBeVisible();
    expect(screen.getByText("Are these same-name people actually one person?")).toBeVisible();
    expect(screen.getByText(/matching name is only supporting evidence/i)).toBeVisible();
    expect(screen.getByText(/previous publisher/i)).toBeVisible();
    expect(screen.getByText("relationship-uuid")).toBeVisible();
    expect(screen.getByText("candidate-profile-uuid")).toBeVisible();
    expect(screen.getByText("Relationship UUID:")).toBeVisible();
    expect(screen.getByText("Contributor profile UUID:")).toBeVisible();
    expect(screen.getAllByText(/missing identity bridge/i)).toHaveLength(2);
    expect(screen.getByRole("link", { name: "Open public profile" })).toHaveAttribute(
      "href",
      "https://publisher.example/authors/alex-rivers",
    );

    expect(screen.getByLabelText("Decision")).toBeVisible();
    for (const actionLabel of [
      "Confirm and create identity",
      "Link to existing identity",
      "Keep same-name people separate",
      "Establish affiliation",
      "Correct affiliation",
      "Merge duplicate people",
      "Reverse an incorrect merge",
      "Mark as not an identity",
      "Not enough evidence yet",
      "Reopen for review",
    ]) {
      expect(screen.getByRole("option", { name: actionLabel })).toBeInTheDocument();
    }
  });

  it("records a question-oriented answer and refreshes the queue", async () => {
    const user = userEvent.setup();
    render(<NewsIdentityReviewPanel />);

    await screen.findByRole("heading", { name: "Alex Rivers" });
    await user.selectOptions(screen.getByLabelText("Decision"), "not_identity");
    await user.type(screen.getByLabelText("Reason / operator note"), "This is a section label, not a contributor.");
    await user.click(screen.getByRole("button", { name: "Record answer" }));

    await waitFor(() => expect(submitNewsIdentityReview).toHaveBeenCalledWith({
      caseId: "case-uuid",
      action: "not_identity",
      payload: {
        identity_type: "human",
        display_name: "Alex Rivers",
        publisher_source_id: "publisher-uuid",
        relationship_type: "unknown",
      },
      notes: "This is a section label, not a contributor.",
    }));
    await waitFor(() => expect(listNewsIdentityReviewCases).toHaveBeenCalledTimes(2));
  });

  it("renders a useful empty queue state", async () => {
    vi.mocked(listNewsIdentityReviewCases).mockResolvedValue([]);
    render(<NewsIdentityReviewPanel />);
    expect(await screen.findByText("No identity cases need attention.")).toBeVisible();
  });
});
