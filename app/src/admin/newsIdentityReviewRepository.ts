import type { Database, Json } from "../lib/supabase/database.types";
import { requireSupabase } from "../lib/supabase/client";

type ReviewRow = Database["public"]["Views"]["news_identity_review_read_model"]["Row"];

export type NewsIdentityReviewAction =
  | "confirm_create"
  | "link_existing"
  | "keep_separate"
  | "establish_affiliation"
  | "correct_affiliation"
  | "merge"
  | "reverse_merge"
  | "not_identity"
  | "insufficient_evidence"
  | "reopen";

export type NewsIdentityReviewObject = Readonly<Record<string, Json | undefined>>;

export type NewsIdentityReviewCase = Readonly<{
  id: string;
  publicId: string;
  kind: string;
  proposedType: string | null;
  proposedName: string | null;
  rawByline: string | null;
  profileUrl: string | null;
  publisherName: string | null;
  publisherId: string | null;
  publisherSourceId: string | null;
  status: string;
  automaticResult: string | null;
  stopReason: string | null;
  question: string;
  subjectPersonId: string | null;
  subjectOrganizationId: string | null;
  subjectShowId: string | null;
  subjectProfileId: string | null;
  context: Json;
  possibleMatches: readonly NewsIdentityReviewObject[];
  evidence: readonly NewsIdentityReviewObject[];
  affiliations: readonly NewsIdentityReviewObject[];
  decisions: readonly NewsIdentityReviewObject[];
  createdAt: string | null;
  updatedAt: string | null;
}>;

export type SubmitNewsIdentityReview = Readonly<{
  caseId: string;
  action: NewsIdentityReviewAction;
  targetIdentityId?: string;
  payload?: Json;
  notes?: string;
}>;

function jsonObjectArray(value: Json | null): readonly NewsIdentityReviewObject[] {
  if (!Array.isArray(value)) return [];
  return value.filter(
    (entry): entry is Record<string, Json | undefined> => (
      typeof entry === "object" && entry !== null && !Array.isArray(entry)
    ),
  );
}

function mapReviewRow(row: ReviewRow): NewsIdentityReviewCase | null {
  if (!row.id || !row.case_id || !row.case_kind || !row.status || !row.unresolved_question) return null;
  return {
    id: row.id,
    publicId: row.case_id,
    kind: row.case_kind,
    proposedType: row.proposed_identity_type,
    proposedName: row.proposed_name,
    rawByline: row.raw_byline,
    profileUrl: row.profile_url,
    publisherName: row.publisher_name,
    publisherId: row.publisher_id,
    publisherSourceId: row.publisher_source_id,
    status: row.status,
    automaticResult: row.automatic_resolution_result,
    stopReason: row.resolution_stop_reason,
    question: row.unresolved_question,
    subjectPersonId: row.subject_person_id,
    subjectOrganizationId: row.subject_organizational_contributor_id,
    subjectShowId: row.subject_show_id,
    subjectProfileId: row.subject_contributor_profile_id,
    context: row.context ?? {},
    possibleMatches: jsonObjectArray(row.possible_matches),
    evidence: jsonObjectArray(row.public_evidence),
    affiliations: jsonObjectArray(row.affiliations),
    decisions: jsonObjectArray(row.decision_history),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function listNewsIdentityReviewCases(): Promise<readonly NewsIdentityReviewCase[]> {
  const { data, error } = await requireSupabase()
    .from("news_identity_review_read_model")
    .select("*")
    .order("created_at", { ascending: true });

  if (error) throw new Error(`FANatical could not load News identity review: ${error.message}`);
  return (data ?? []).flatMap((row) => {
    const mapped = mapReviewRow(row);
    return mapped ? [mapped] : [];
  });
}

export async function submitNewsIdentityReview(input: SubmitNewsIdentityReview): Promise<string> {
  const argumentsValue: Database["public"]["Functions"]["admin_review_news_identity_case"]["Args"] = {
    case_id_value: input.caseId,
    action_value: input.action,
  };
  if (input.targetIdentityId) argumentsValue.target_identity_id_value = input.targetIdentityId;
  if (input.payload !== undefined) argumentsValue.action_payload_value = input.payload;
  if (input.notes !== undefined) argumentsValue.notes_value = input.notes;

  const { data, error } = await requireSupabase().rpc(
    "admin_review_news_identity_case",
    argumentsValue,
  );
  if (error) throw new Error(`FANatical could not record the identity decision: ${error.message}`);
  return data;
}
