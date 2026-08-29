import { useCallback, useEffect, useState, type FormEvent } from "react";
import type { Json } from "../lib/supabase/database.types";
import {
  listNewsIdentityReviewCases,
  submitNewsIdentityReview,
  type NewsIdentityReviewAction,
  type NewsIdentityReviewCase,
  type NewsIdentityReviewObject,
} from "./newsIdentityReviewRepository";

const reviewActions: readonly Readonly<{ value: NewsIdentityReviewAction; label: string }>[] = [
  { value: "confirm_create", label: "Confirm and create identity" },
  { value: "link_existing", label: "Link to existing identity" },
  { value: "keep_separate", label: "Keep same-name people separate" },
  { value: "establish_affiliation", label: "Establish affiliation" },
  { value: "correct_affiliation", label: "Correct affiliation" },
  { value: "merge", label: "Merge duplicate people" },
  { value: "reverse_merge", label: "Reverse an incorrect merge" },
  { value: "not_identity", label: "Mark as not an identity" },
  { value: "insufficient_evidence", label: "Not enough evidence yet" },
  { value: "reopen", label: "Reopen for review" },
] as const;

type LoadState =
  | Readonly<{ status: "loading" }>
  | Readonly<{ status: "ready"; cases: readonly NewsIdentityReviewCase[] }>
  | Readonly<{ status: "error"; message: string }>;

async function resolveReviewLoadState(): Promise<LoadState> {
  try {
    return { status: "ready", cases: await listNewsIdentityReviewCases() };
  } catch (reason) {
    return {
      status: "error",
      message: reason instanceof Error ? reason.message : "News identity review could not be loaded.",
    };
  }
}

function objectText(value: NewsIdentityReviewObject, key: string) {
  const field = value[key];
  if (field === null || field === undefined) return null;
  if (typeof field === "string" || typeof field === "number" || typeof field === "boolean") return String(field);
  return JSON.stringify(field);
}

function formatCode(value: string | null) {
  return value ? value.replaceAll("_", " ") : "—";
}

function ReviewObjectList({
  emptyLabel,
  items,
  fields,
}: Readonly<{
  emptyLabel: string;
  items: readonly NewsIdentityReviewObject[];
  fields: readonly Readonly<{ key: string; label: string }>[];
}>) {
  if (items.length === 0) return <p className="admin-review-empty">{emptyLabel}</p>;
  return (
    <ul className="admin-review-records">
      {items.map((item, index) => (
        <li key={objectText(item, "id") ?? `${emptyLabel}-${index}`}>
          {fields.map(({ key, label }) => {
            const value = objectText(item, key);
            if (!value) return null;
            if (key === "url") {
              return (
                <span key={key}>
                  <strong>{label}:</strong>{" "}
                  <a href={value} target="_blank" rel="noreferrer">public evidence</a>
                </span>
              );
            }
            return <span key={key}><strong>{label}:</strong> {formatCode(value)}</span>;
          })}
        </li>
      ))}
    </ul>
  );
}

function ReviewAnswerForm({
  reviewCase,
  onRecorded,
}: Readonly<{
  reviewCase: NewsIdentityReviewCase;
  onRecorded: () => Promise<void>;
}>) {
  const [action, setAction] = useState<NewsIdentityReviewAction>("insufficient_evidence");
  const [identityType, setIdentityType] = useState("human");
  const [targetIdentityId, setTargetIdentityId] = useState("");
  const [publisherSourceId, setPublisherSourceId] = useState(reviewCase.publisherSourceId ?? "");
  const [relationshipType, setRelationshipType] = useState("unknown");
  const [relationshipId, setRelationshipId] = useState("");
  const [effectiveFrom, setEffectiveFrom] = useState("");
  const [effectiveTo, setEffectiveTo] = useState("");
  const [notes, setNotes] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setMessage(null);

    const payload: Record<string, Json | undefined> = {
      identity_type: identityType,
      display_name: reviewCase.proposedName ?? undefined,
    };
    if (publisherSourceId.trim()) payload.publisher_source_id = publisherSourceId.trim();
    if (relationshipType) payload.relationship_type = relationshipType;
    if (relationshipId.trim()) payload.relationship_id = relationshipId.trim();
    if (effectiveFrom) payload.effective_from = effectiveFrom;
    if (effectiveTo) payload.effective_to = effectiveTo;

    try {
      await submitNewsIdentityReview({
        caseId: reviewCase.id,
        action,
        ...(targetIdentityId.trim() ? { targetIdentityId: targetIdentityId.trim() } : {}),
        payload,
        notes: notes.trim(),
      });
      setMessage("Decision recorded.");
      await onRecorded();
    } catch (reason) {
      setMessage(reason instanceof Error ? reason.message : "The identity decision could not be recorded.");
    } finally {
      setSubmitting(false);
    }
  }

  const affiliationAction = action === "establish_affiliation" || action === "correct_affiliation";

  return (
    <form className="admin-review-answer" onSubmit={(event) => void handleSubmit(event)}>
      <h4>Answer the unresolved question</h4>
      <div className="admin-review-answer__grid">
        <label>
          Decision
          <select value={action} onChange={(event) => setAction(event.target.value as NewsIdentityReviewAction)}>
            {reviewActions.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
          </select>
        </label>
        <label>
          Identity type
          <select value={identityType} onChange={(event) => setIdentityType(event.target.value)}>
            <option value="human">Human Author</option>
            <option value="organization">Organization / Staff / Wire</option>
            <option value="show">Podcast Show</option>
            <option value="publisher_profile">Publisher contributor profile</option>
          </select>
        </label>
        <label>
          Target identity UUID
          <input value={targetIdentityId} onChange={(event) => setTargetIdentityId(event.target.value)} placeholder="Required for link, separate, merge, or reverse" />
        </label>
        {affiliationAction ? (
          <>
            <label>
              Publisher UUID
              <input value={publisherSourceId} onChange={(event) => setPublisherSourceId(event.target.value)} />
            </label>
            <label>
              Relationship
              <select value={relationshipType} onChange={(event) => setRelationshipType(event.target.value)}>
                <option value="employee">Employee</option>
                <option value="freelance">Freelance</option>
                <option value="contract">Contract</option>
                <option value="guest">Guest</option>
                <option value="columnist">Columnist</option>
                <option value="contributor">Contributor</option>
                <option value="unknown">Unknown</option>
              </select>
            </label>
            {action === "correct_affiliation" ? (
              <label>
                Current relationship UUID
                <input value={relationshipId} onChange={(event) => setRelationshipId(event.target.value)} />
              </label>
            ) : null}
            <label>
              Effective from
              <input type="datetime-local" value={effectiveFrom} onChange={(event) => setEffectiveFrom(event.target.value)} />
            </label>
            <label>
              Effective to
              <input type="datetime-local" value={effectiveTo} onChange={(event) => setEffectiveTo(event.target.value)} />
            </label>
          </>
        ) : null}
      </div>
      <label>
        Reason / operator note
        <textarea value={notes} onChange={(event) => setNotes(event.target.value)} rows={3} />
      </label>
      {message ? <p className="admin-message" role="status">{message}</p> : null}
      <button className="admin-button" type="submit" disabled={submitting}>
        {submitting ? "Recording…" : "Record answer"}
      </button>
    </form>
  );
}

function IdentityReviewCaseCard({
  reviewCase,
  onRecorded,
}: Readonly<{
  reviewCase: NewsIdentityReviewCase;
  onRecorded: () => Promise<void>;
}>) {
  return (
    <article className="admin-review-case" aria-labelledby={`review-case-${reviewCase.id}`}>
      <header className="admin-review-case__header">
        <div>
          <p className="admin-kicker">{formatCode(reviewCase.kind)} · {formatCode(reviewCase.proposedType)}</p>
          <h3 id={`review-case-${reviewCase.id}`}>{reviewCase.proposedName ?? reviewCase.rawByline ?? "Unnamed identity clue"}</h3>
          <p className="admin-review-question">{reviewCase.question}</p>
        </div>
        <div className="admin-review-status">
          <span>{formatCode(reviewCase.status)}</span>
          <small>{reviewCase.publicId}</small>
        </div>
      </header>

      <dl className="admin-review-facts">
        <div><dt>Publisher</dt><dd>{reviewCase.publisherName ?? "Unknown"}{reviewCase.publisherId ? ` (${reviewCase.publisherId})` : ""}</dd></div>
        <div><dt>Raw byline</dt><dd>{reviewCase.rawByline ?? "—"}</dd></div>
        <div><dt>Profile</dt><dd>{reviewCase.profileUrl ? <a href={reviewCase.profileUrl} target="_blank" rel="noreferrer">Open public profile</a> : "—"}</dd></div>
        <div><dt>Automatic result</dt><dd>{formatCode(reviewCase.automaticResult)}</dd></div>
        <div><dt>Why it stopped</dt><dd>{formatCode(reviewCase.stopReason)}</dd></div>
        <div><dt>Subject UUID</dt><dd>{reviewCase.subjectPersonId ?? reviewCase.subjectOrganizationId ?? reviewCase.subjectShowId ?? reviewCase.subjectProfileId ?? "—"}</dd></div>
        <div><dt>Subject contributor profile UUID</dt><dd>{reviewCase.subjectProfileId ?? "—"}</dd></div>
      </dl>

      <div className="admin-review-columns">
        <section>
          <h4>Possible matches</h4>
          <ReviewObjectList
            emptyLabel="No possible matches recorded."
            items={reviewCase.possibleMatches}
            fields={[
              { key: "display_name", label: "Name" },
              { key: "identity_type", label: "Type" },
              { key: "person_id", label: "Person UUID" },
              { key: "organizational_contributor_id", label: "Organization UUID" },
              { key: "show_id", label: "Show UUID" },
              { key: "contributor_profile_id", label: "Contributor profile UUID" },
            ]}
          />
        </section>
        <section>
          <h4>Public evidence</h4>
          <ReviewObjectList
            emptyLabel="No evidence recorded."
            items={reviewCase.evidence}
            fields={[
              { key: "summary", label: "Evidence" },
              { key: "kind", label: "Kind" },
              { key: "class", label: "Class" },
              { key: "visibility", label: "Visibility" },
              { key: "is_conflicting", label: "Conflicting" },
              { key: "url", label: "URL" },
            ]}
          />
        </section>
        <section>
          <h4>Affiliations</h4>
          <ReviewObjectList
            emptyLabel="No current or historical affiliations recorded."
            items={reviewCase.affiliations}
            fields={[
              { key: "id", label: "Relationship UUID" },
              { key: "publisher_name", label: "Publisher" },
              { key: "relationship_type", label: "Relationship" },
              { key: "effective_from", label: "From" },
              { key: "effective_to", label: "To" },
              { key: "is_current", label: "Current" },
            ]}
          />
        </section>
        <section>
          <h4>Decision history</h4>
          <ReviewObjectList
            emptyLabel="No decisions recorded."
            items={reviewCase.decisions}
            fields={[
              { key: "action", label: "Action" },
              { key: "origin", label: "Origin" },
              { key: "rule", label: "Rule" },
              { key: "stop_reason", label: "Stop reason" },
              { key: "notes", label: "Notes" },
              { key: "decided_at", label: "At" },
            ]}
          />
        </section>
      </div>

      <ReviewAnswerForm reviewCase={reviewCase} onRecorded={onRecorded} />
    </article>
  );
}

export function NewsIdentityReviewPanel() {
  const [loadState, setLoadState] = useState<LoadState>({ status: "loading" });

  const loadCases = useCallback(async () => {
    setLoadState({ status: "loading" });
    setLoadState(await resolveReviewLoadState());
  }, []);

  useEffect(() => {
    let current = true;
    void resolveReviewLoadState().then((nextState) => {
      if (current) setLoadState(nextState);
    });
    return () => { current = false; };
  }, []);

  return (
    <section className="admin-review" aria-labelledby="news-identity-review-title">
      <header className="admin-review__heading">
        <div>
          <p className="admin-kicker">News Catalog / Resolution</p>
          <h2 id="news-identity-review-title">News identity review</h2>
          <p>Resolve concrete identity questions. Names alone never merge people, and News status is independent of publisher factual-governance status.</p>
        </div>
        <button className="admin-button admin-button--secondary" type="button" onClick={() => void loadCases()} disabled={loadState.status === "loading"}>
          Refresh
        </button>
      </header>

      {loadState.status === "loading" ? <p className="admin-review-empty">Loading identity cases…</p> : null}
      {loadState.status === "error" ? <p className="admin-message admin-message--error" role="alert">{loadState.message}</p> : null}
      {loadState.status === "ready" && loadState.cases.length === 0 ? (
        <p className="admin-review-empty">No identity cases need attention.</p>
      ) : null}
      {loadState.status === "ready" ? (
        <div className="admin-review-list">
          {loadState.cases.map((reviewCase) => (
            <IdentityReviewCaseCard key={reviewCase.id} reviewCase={reviewCase} onRecorded={loadCases} />
          ))}
        </div>
      ) : null}
    </section>
  );
}
