# FANatical Team Color Agent interface

This is the canonical production contract for autonomous Team Color research.
It extends the normalized catalog documented in `TEAM_REGISTRY.md`; it does not
replace the team registry, Trusted Source Registry, proposal/evidence system,
verification decisions, immutable fact versions, or catalog audit history.

The queue interface is introduced by
`202608210001_team_color_agent_interface.sql`; reusable publisher governance,
URL ownership/applicability, structured evidence, and empirical reliability are
introduced by `202608230001_trusted_source_publisher_reliability.sql`.
Decision-time governance revalidation and the reviewer duplicate-candidate view
are added by `202608230002_trusted_source_evaluation_hardening.sql`. Trust-tier
and target-applicability versioning are structurally separated by
`202608230003_trust_applicability_separation.sql`. Before enabling an agent,
verify all four migrations and all earlier catalog migrations in that
environment.

## Security boundary

A Team Color Agent:

- authenticates as its own ordinary Supabase Auth user;
- maps one-to-one to an active `catalog_actors` row with `actor_type = 'agent'`;
- receives only Team Color work, read, update, source-candidate, and proposal
  capabilities;
- writes through security-definer RPCs with capability and ownership checks;
- may add evidence only to proposals it owns;
- cannot approve sources, classify common ownership, assign trust or
  applicability, verify a proposal, write version tables directly, or use a
  service-role key.

The production capability set is:

1. `team_colors.work.claim`
2. `team_colors.work.read`
3. `team_colors.work.update`
4. `team_colors.source_candidates.submit`
5. `catalog.propose.team_colors`

`catalog.evidence.add` is intentionally not required. The Team Color-specific
`add_team_color_proposal_evidence(...)` RPC authorizes the proposal owner and
requires governed source versions plus a structured claim. The generic
evidence RPC rejects Team Color proposals.

Do not grant the agent `catalog.read_internal`, `catalog.propose`,
`catalog.verify`, `catalog.verify.team_colors`, `catalog.evidence.add`,
`source.registry.review`, `source.trust.assign`, or `*`.

Capabilities may be restricted to a sport, league, or team with the existing
`admin_grant_catalog_capability(...)` scope arguments. An unscoped grant still
remains limited to the named Team Color operation.

## Queue lifecycle

`team_color_work_items` is the durable queue. It always identifies teams by the
internal UUID linked to the immutable canonical public `catalog_teams.team_id`.
The agent-facing read result exposes the public ID; callers never invent team
IDs or select by fuzzy name.

Statuses are:

- `queued`: ready when `available_at` is reached;
- `claimed`: one actor owns an unexpired lease and lease token;
- `retry_wait`: released until a future retry time;
- `pending_verification`: research and evidence are complete; a separate
  verifier owns the next decision;
- `blocked`: an external dependency prevents progress;
- `needs_review`: ambiguity, conflict, stale assumptions, or a rejected
  proposal requires a human or reviewer;
- `completed`: no-change recheck or approved proposal;
- `failed`: terminal research failure pending administrative action;
- `cancelled`: administratively closed without changing team facts.

One partial unique index prevents more than one active work item for a team.
Another partial unique index prevents more than one pending `team_colors`
proposal for a team.

### Prioritization and claims

`claim_next_team_color_work(...)` selects eligible work deterministically by:

1. highest numeric priority;
2. earliest `available_at`;
3. earliest `created_at`;
4. work-item UUID.

It uses `FOR UPDATE SKIP LOCKED`, so multiple agents can claim concurrently
without sharing an item. It skips out-of-scope teams and teams with an active
pending color proposal.

Every claim creates a `team_color_work_attempts` row and a random lease token.
The token is required for all reads and mutations during that attempt. Lease
duration is clamped to 60–3,600 seconds. Expired leases become `retry_wait` and
the attempt is retained with the `lease_expired` outcome.

`team_color_work_events` is the append-only lifecycle ledger. Queue tables have
RLS enabled and do not grant authenticated clients direct mutation rights.

### Queue administration

- `enqueue_team_color_backlog(batch_size, priority)` deterministically queues
  teams with missing or `imported_unverified` colors, preferring existing
  unverified palettes before completely missing palettes.
- `enqueue_team_color_work(...)` creates one explicit item. If the current color
  version is verified, it requires a valid recheck trigger.
- `requeue_team_color_work(...)` resumes blocked, needs-review, or failed work
  after review.
- `cancel_team_color_work(...)` closes obsolete non-claimed work.

These administrative functions require authorized staff or
`team_colors.work.enqueue`. The Team Color Agent does not need that capability.

## Agent RPC sequence

### 1. Claim and read work

```text
claim_next_team_color_work(lease_seconds_value integer default 900) -> jsonb
```

The returned JSON is the complete narrow research context:

- work ID, kind, reason, priority, attempt, lease token, and expiry;
- canonical public team ID, names, sport, league, aliases, and compatibility
  identifiers;
- exact current color version and verification status;
- expected-current-version guard;
- this work item's current proposal and evidence;
- approved sources with one current `team_colors` trust tier and the
  applicability scopes valid for the target team;
- source candidates already submitted for this work;
- current immutable verification-policy requirements.

The same context can be refreshed while the lease is active:

```text
get_my_team_color_work(work_item_id uuid, lease_token uuid) -> jsonb
```

No broad internal catalog-read capability is required.

### 2. Renew or release

```text
renew_team_color_work_lease(work_item_id, lease_token, lease_seconds) -> timestamptz
release_team_color_work(work_item_id, lease_token, retry_at, category, reason)
```

Heartbeat before the lease expiry. Release without `retry_at` returns the item
to `queued`; a future `retry_at` creates `retry_wait` and retains the reason.

### 3. Resolve and reuse a publisher

Before creating a source candidate, resolve the exact evidence URL:

```text
resolve_team_color_source(work_item_id, lease_token, evidence_url) -> jsonb
```

The result is `resolved`, `none`, or `ambiguous`. Resolution uses reviewed
hostname aliases, explicit subdomain permission, path boundaries, and approved
CDN/document-host scopes. It reports the current Team Color trust-tier version
and the independently selected applicability version for the work item's team.
Use the returned canonical publisher for a resolved URL. Do not create another
publisher record for a team-specific page.

An `ambiguous` result is a governance issue: report `needs_review`; never guess.
Only `none` permits candidate submission.

### 4. Retain a newly discovered source

```text
submit_team_color_source_candidate(
  work_item_id,
  lease_token,
  source_registry_id,
  display_name,
  base_url,
  reference_url,
  evidence_url,
  discovery_summary,
  observed_at
) -> uuid
```

A new source is created only as `pending_review`, with a pending exact-URL scope,
no approved independence group, no trust tier, and no applicability. The
association and the resolver result are retained in
`team_color_source_candidates`. Candidate intake rejects URLs that already
resolve, ambiguous overlaps, existing source IDs, and likely duplicate
publisher names.

The agent cannot promote the source. A Source Reviewer uses
`review_trusted_source(...)`, `admin_set_source_trust_tier(...)`, and
`review_source_applicability(...)` as separate controlled actions. The narrow
`get_team_color_source_candidate_review_queue()` RPC shows reviewers the
candidate/team/work relationship without expanding the agent's permissions.

Pending candidates cannot be attached to proposals. If required evidence is
pending source review, finish the work as `needs_review` or `blocked`; requeue it
after source governance is complete.

### 5. Submit the controlled proposal

```text
submit_team_color_proposal(
  work_item_id,
  lease_token,
  payload,
  reason
) -> proposal_id
```

Use this wrapper instead of generic `submit_catalog_proposal(...)`. New pending
Team Color proposals cannot satisfy database constraints without the wrapper's
work item, expected version, change kind, and reason.

Payload fields are:

```json
{
  "primary": "#RRGGBB",
  "secondary": "#RRGGBB",
  "tertiary": "#RRGGBB",
  "quaternary": "#RRGGBB",
  "quinary": "#RRGGBB",
  "effective_from": "YYYY-MM-DD",
  "effective_from_precision": "day"
}
```

Primary and secondary are required. Optional colors may be omitted. All values
must be uppercase six-digit hex. Precision is `day`, `year`, or `unknown`.

The wrapper records one of:

- `fill_missing_or_unverified`; or
- `verified_replacement` with an approved recheck trigger.

A replacement that exactly matches the verified palette is rejected; finish
that recheck as `no_change` instead.

### 6. Attach structured evidence

Use the Team Color-specific owner-authorized RPC:

```text
add_team_color_proposal_evidence(
  proposal_id,
  source_registry_id,
  evidence_url,
  evidence_summary,
  observed_at,
  supports_proposal,
  structured_claim
) -> evidence_id
```

The claim preserves exact palette values and order:

```json
{
  "classification": "current_canonical",
  "palette": ["#RRGGBB", "#RRGGBB", "#RRGGBB"],
  "effective_from": "YYYY-MM-DD"
}
```

Classification is `current_canonical`, `historical`, `alternate`,
`special_treatment`, or `unresolved`. Supporting evidence must be
`current_canonical` and its palette must exactly equal the proposal. Record
opposing evidence with `supports_proposal = false`; it remains in the decision
snapshot but does not count toward approval.

The RPC resolves redirects to the canonical publisher, rejects a URL outside
its approved scope, rejects ambiguous ownership, selects the one current
publisher/data-type trust-tier version, independently selects the most-specific
valid global/sport/league/team applicability version, and records both exact
version IDs plus the URL-scope and ownership versions used. A worker cannot
bypass these checks or write evidence directly. Approval revalidates all exact
versions independently; governance suspension or reassignment therefore blocks
a stale proposal instead of silently using old authority.

### 7. Finish the research attempt

```text
finish_team_color_work(
  work_item_id,
  lease_token,
  outcome,
  category,
  reason,
  retry_at,
  summary
)
```

Outcomes are:

- `submitted_for_verification`
- `no_change` for an unchanged verified recheck
- `blocked`
- `needs_review`
- `retry` with a future retry timestamp
- `failed`

Submitting for verification ends the agent lease and moves the work item to
`pending_verification`. Approval automatically completes it. Rejection or
withdrawal automatically moves it to `needs_review`.

## Expected-current-version protection

The queue records the current `team_color_versions.id` before research. The
proposal copies that value. Submission and approval both lock and compare the
actual current version.

If another process changes the current version:

- an unclaimed queued item moves to `needs_review`;
- proposal submission fails if research is already in progress;
- approval fails if a proposal is already pending.

Verified replacement additionally requires the existing current row to remain
verified and the work to carry one of these triggers:

- `scheduled_review`
- `known_real_world_event`
- `detected_conflict_or_mismatch`
- `manual_request`

Verified values remain append-only. Approval supersedes the prior version and
inserts a verified successor through `review_catalog_proposal(...)`.

## Verification and source trust

Team Color policy `team-colors` version 2 requires:

- two supporting qualifying evidence rows;
- Tier 1, 2, or 3 sources;
- separate ownership/independence groups;
- at least one Tier 1 or Tier 2 source;
- a verifier actor different from the proposal builder;
- uppercase six-digit hex values.

Trust is assigned specifically for `team_colors`:

- **Tier 1:** first-party team, club, or controlling-owner brand standards that
  publish exact official values.
- **Tier 2:** official league, governing body, licensing authority, or
  authorized brand portal publishing exact values with authoritative
  provenance.
- **Tier 3:** reputable independent specialist or editorial reference with
  exact values and stable attribution/methodology; suitable for corroboration.
- **Tier 4:** discovery/research lead only; never qualifying evidence.
- **Tier 5:** blocked for team-color research.

Multiple domains, pages, or brands under common ownership count as one
independence group. An official source is the preferred evidence anchor but
does not bypass the two-independent-source requirement.

Each publisher has at most one current trust tier for `team_colors` regardless
of target. Applicability is a separate versioned set of global, sport, league,
or team scopes. The most-specific matching applicability may be selected, but
it cannot alter the publisher's tier. A team-controlled source normally uses a
team applicability; a league publisher may use league applicability; a
genuinely reusable publisher may be global. Hostname sharing alone never
establishes publisher identity, ownership, or applicability.

The immutable decision snapshot retains evidence summary and timestamps, source
review status, independence group, the trust-tier version ID/tier/effective
date, the independently selected applicability version ID/scope, and both
supporting and conflicting evidence.

## Empirical source reliability

Reliability is append-only evidence about later verification outcomes and is
strictly separate from governance trust. Workers can read it for research
prioritization but cannot write it or change trust.

For each structured evidence row, a resolved decision records `match`,
`contradiction`, `unresolved`, or `not_assessable`. A match or contradiction is
recorded only when the verified palette is corroborated by at least one other
ownership group; a source cannot earn credit from its own contribution.
Rejected proposals are unresolved, not contradictions. Historical, alternate,
and special-treatment claims are not assessable against the current palette.

`team_color_source_reliability_read_model` reports matches, contradictions,
unresolved and not-assessable counts, assessed sample size, raw match rate, a
Wilson conservative match rate, team/league/sport breadth, recency, and the
number of independently corroborated observations. It never promotes,
suspends, or changes a source trust tier.

## Failure categories and reporting

Failure categories are short machine-readable labels chosen by the operating
agent, for example:

- `source_not_found`
- `single_credible_source`
- `source_conflict`
- `palette_order_ambiguous`
- `more_than_five_colors`
- `source_pending_review`
- `rate_limited`
- `identity_ambiguous`
- `current_version_changed`

The reason must be plain language. `outcome_summary` should retain the candidate
palette, sources checked, supporting/opposing counts, unresolved questions, and
recommended next action. Never invent a second source, silently discard extra
colors, average conflicting values, or reject incomplete research merely to
clear the queue.

## Secure OpenClaw provisioning

Provision in the target environment only after hosted migration verification.

1. Create a dedicated non-human Supabase Auth user with a unique mailbox/alias
   and a generated high-entropy password. Do not reuse a developer or admin
   account.
2. Record the new Auth user UUID.
3. While authenticated as an authorized FANatical admin, map it to the catalog:

   ```sql
   select public.admin_upsert_catalog_actor(
     'openclaw-team-color-agent',
     'agent',
     '<AUTH_USER_UUID>'::uuid,
     'OpenClaw Team Color Agent',
     true
   );
   ```

4. Grant the five capabilities with
   `admin_grant_catalog_capability(...)`. Pass a sport, league, or team public ID
   when a narrower operating scope is desired; leave all scope arguments null
   only when the agent is approved for the full Team Color backlog.

   ```sql
   select public.admin_grant_catalog_capability('openclaw-team-color-agent', 'team_colors.work.claim');
   select public.admin_grant_catalog_capability('openclaw-team-color-agent', 'team_colors.work.read');
   select public.admin_grant_catalog_capability('openclaw-team-color-agent', 'team_colors.work.update');
   select public.admin_grant_catalog_capability('openclaw-team-color-agent', 'team_colors.source_candidates.submit');
   select public.admin_grant_catalog_capability('openclaw-team-color-agent', 'catalog.propose.team_colors');
   ```

5. Confirm that no prohibited capabilities are active for the actor.
6. Store credentials in Astro/OpenClaw's encrypted secret configuration, not in
   this repository, shell history, prompts, logs, or agent reports.
7. Sign in with Supabase password authentication, use the returned access token
   for RPC calls, persist the refresh token only in encrypted secret/session
   storage, and let the Supabase client refresh sessions normally.

Astro/OpenClaw requires exactly these environment values:

```text
FANATICAL_SUPABASE_URL
FANATICAL_SUPABASE_PUBLISHABLE_KEY
FANATICAL_TEAM_COLOR_AGENT_EMAIL
FANATICAL_TEAM_COLOR_AGENT_PASSWORD
```

The publishable key is the project's public client key. Never provide
`SUPABASE_SERVICE_ROLE_KEY`, a database password, a staff/admin session, or a
long-lived manually copied access token.

## Verification and tests

The transactional integration tests are:

```text
supabase/tests/team_color_agent_workflow.sql
supabase/tests/trusted_source_publisher_reliability.sql
```

It covers scoped/deterministic claims, lease expiry, attempt/retry history,
direct-write denial, candidate-source restrictions, invalid payloads, duplicate
pending proposals, ownership independence, Tier 1/2 minimum, agent verification
denial, independent verifier policy, conflicting evidence retention,
expected-current-version failure, and verified history supersession.

The publisher/reliability suite covers normalization, host aliases,
subdomains, paths, CDN scopes, ambiguity, global/sport/league/team
applicability, wrong-domain and wrong-target denial, candidate reuse and
duplicate prevention, redirects without history rewrite, ownership versioning,
structured claims, reliability outcomes, circularity protection, sample-size
behavior, RLS/capability denial, and transactional rollback.

Run it only against a disposable/local database or through an approved
transactional test connection. It starts a transaction and rolls back all
fixtures.
