# FANatical autonomous agent architecture

## Status and authority

This document is FANatical's canonical standard for designing, implementing,
verifying, launching, operating, recovering, and scaling autonomous OpenClaw
agents.

It governs operational FANatical agents, their durable backend interfaces, and
their relationship with Astro. It does not authorize an agent to change
FANatical application code, infrastructure, policy, permissions, or security
boundaries.

Brad is the ultimate human authority for FANatical architecture, policy,
security, and governance. Brad establishes the rules under which autonomous
work may proceed and decides genuine exceptions. Humans are not part of the
ordinary job-processing path.

The Team Color system documented in `supabase/TEAM_COLOR_AGENT.md` is
FANatical's current reference agent implementation. It provides proven patterns
to preserve, but reference status does not imply full compliance with every
standard in this document. The next agent implementation phase must audit Team
Color against this standard before treating its domain-specific implementation
as the generic template for other agents.

## Objective

FANatical agents should complete routine work autonomously with minimal human
intervention. Humans establish:

- architecture and domain policy;
- permissions and security boundaries;
- initial seed information;
- deterministic transition and exception rules; and
- decisions whose consequences require human authority.

Routine work proceeds through durable queues, Astro orchestration, specialist
agents, independent verifier agents, structured proposals, provenance, leases,
retries, recovery, verification, source learning, periodic revalidation, and
deterministic backend state transitions.

If ordinary work repeatedly waits for a person to choose the next routine step,
interpret a normal machine-readable state, requeue an expected transient
failure, or make a domain decision already covered by policy, the architecture
is incomplete. Human escalation is an explicit exception path, not a substitute
for missing workflow design.

## Architectural principles

1. **Durable state is authoritative.** Supabase, not an OpenClaw session, holds
   the job, attempt, proposal, evidence, decision, retry state, provenance, and
   authoritative fact history.
2. **Workers are disposable.** A worker or OpenClaw process may disappear at
   any point without losing accepted work or permanently stranding a job.
3. **The backend is deterministic.** Backend code authenticates, authorizes,
   validates, compares, schedules, transitions, promotes, audits, and recovers.
   It does not research or reason about real-world truth.
4. **Agents reason inside narrow contracts.** Agents research, interpret
   evidence, and return structured results through capability-controlled
   interfaces. They do not directly mutate authoritative version tables.
5. **Proposal precedes verification.** A specialist's result becomes durable
   backend state before a verifier is dispatched.
6. **Verification is independent and substantive.** A proposer cannot verify
   its own work, and verification determines truth rather than merely checking
   workflow compliance.
7. **Verified history is protected.** Replacement creates a new verified
   version and supersedes the former version; it never casually overwrites or
   destroys it.
8. **Provenance is first-class.** Evidence, source identity, ownership,
   applicability, trust, information lineage, observations, policies, and
   decisions remain attributable and auditable.
9. **Permissions are enforced.** Important boundaries belong in RLS,
   constraints, capabilities, security-definer RPC checks, immutable records,
   and runtime isolation where practical—not only in prompts.
10. **Reuse grows with each agent.** New agents should extend common queue,
    dispatch, capability, evidence, verification, reliability, revalidation,
    and recovery infrastructure rather than create parallel systems.
11. **Build for known requirements and failure modes.** Do not add speculative
    infrastructure without a concrete contract, policy need, scaling need, or
    identified failure mode.

## Numeric operating policy

This architecture currently contains these approved numeric operating
decisions:

- 10% of eligible source-research checks/slots are reserved for exploration;
- 10 independently adjudicated applicable shadow cases are required before a
  probationary source receives its first empirical reliability rating;
- Team Color specialist and determinate verifier leases are 15 minutes and may
  be renewed by healthy workers;
- transient specialist and verifier execution failures retry immediately, with
  at most two total execution attempts before `needs_review`;
- Team Color uses at most two blinded verifier rounds, with three independent
  information lineages normally and four for the escalated second round;
- the initial Team Color specialist and verifier pools each permit one worker,
  with two workers total across those pools;
- backend watchdog/recovery runs every 15 minutes; and
- verified Team Color data receives scheduled revalidation every six months,
  without age alone invalidating the verified value.

Existing deployed numbers may be documented as facts about that implementation,
but they do not automatically become canonical defaults for another agent. Any
other timing, retry, lease, watchdog, calibration, contradiction, inactivity,
review-cadence, concurrency, or similar numeric policy requires Brad's explicit
approval. If implementation needs an unapproved number, the implementation task
must ask Brad rather than silently inventing one.

## Roles and system boundaries

### Brad

Brad is the ultimate policy authority. Brad approves architecture, security
boundaries, high-consequence governance, and explicit risk exceptions. Brad is
not a routine queue worker, dispatcher, source reviewer, or retry handler.

### Astro

Astro is specifically the persistent OpenClaw `main` agent. Astro is the
supervisor and orchestrator.

Astro:

- monitors or is awakened by FANatical durable queues;
- maps registered job types to registered specialist and verifier contracts;
- launches the appropriate worker with only the job identifier and required
  runtime context;
- respects per-agent and global concurrency budgets;
- observes lease, retry, and terminal states;
- dispatches independent verifier agents when verification jobs become ready;
- dispatches retry work only when deterministic backend policy makes it
  eligible;
- coordinates exception escalation; and
- reports systemic failures without taking unsupported domain decisions.

Astro does not normally perform specialist research itself. Astro also does not
turn a worker's answer into authoritative data, bypass a backend state
transition, grant permissions, or silently improvise a new workflow.

### Agent

`Agent` is the generic OpenClaw worker model. A worker instance performs one
registered contract and role for one durable assignment at a time. Examples
include:

- Team Color Agent;
- Seat Resolver Agent;
- Quiz Writer Agent;
- Team Data Verifier;
- Seat Verifier;
- Quiz Verifier; and
- Source Verifier.

A verifier is not a different species of worker. It is an agent operating under
an independent verifier contract and capability set. Multiple specialist and
verifier agents may run concurrently when queue claiming, scopes, resource
budgets, and independence rules permit it.

### FANatical backend

The backend performs deterministic work, including:

- authentication and actor resolution;
- authorization and capability enforcement;
- durable job creation and deduplication;
- deterministic prioritization and claiming;
- lease, heartbeat, retry, and state-transition enforcement;
- structured payload and schema validation;
- proposal and evidence persistence;
- structured result comparison;
- verified-data promotion and supersession;
- provenance and immutable audit history;
- source identity, applicability, ownership, trust, lineage, and reliability
  calculations defined by policy;
- periodic review scheduling; and
- stalled-job recovery and Astro wake signalling.

The backend must not scrape, browse, infer, or decide real-world truth on its
own. When a transition needs research or judgment, it creates work for an
agent.

### Supabase

Supabase stores FANatical's durable operational and authoritative state. A
worker response is not accepted merely because OpenClaw produced it; it becomes
meaningful only after the corresponding authenticated backend interface
validates and stores it.

### Codex

Codex changes FANatical application code, migrations, infrastructure, and agent
implementation when Brad authorizes that work. Operational OpenClaw agents do
not modify FANatical application code or repository files.

## Canonical terminology

- **Job or work item:** Durable backend assignment. Team Color currently uses
  `team_color_work_items`.
- **Attempt:** One actor's time-bounded execution of a claimed job.
- **Lease:** Exclusive, expiring authority to act on a claimed job, normally
  proven by an unguessable token.
- **Specialist:** Agent independently researching and proposing an answer.
- **Proposal:** Durable structured candidate result; never authoritative merely
  because it was submitted.
- **Verifier:** Agent independently researching the same question under a
  verifier contract.
- **Verification result:** Durable structured verifier finding, retained before
  backend comparison or promotion.
- **Verified fact:** Current authoritative version created through an approved
  policy and decision. `Verified` already means filled/current; do not introduce
  a redundant `filled` status.
- **Publisher/source identity:** The reusable entity responsible for
  information or evidence.
- **Applicability:** Targets or domains for which a source can legitimately
  provide evidence.
- **Governance trust:** Policy judgment about a publisher for a data type.
- **Empirical reliability:** Observed performance derived from independently
  adjudicated outcomes; it does not itself grant trust.
- **Ownership/independence group:** Common organizational control.
- **Information lineage:** Common originating report, dataset, document, or
  factual chain, even when republished by separately owned publishers.
- **Gold-standard evidence:** Highly trusted calibration evidence, not an
  infallible oracle.

These concepts must remain separate in storage and APIs wherever they have
different meanings or lifecycles.

## Canonical workflow

The ordinary workflow is:

```text
backend creates durable job
-> Astro detects or is awakened by eligible work
-> Astro launches the registered specialist
-> specialist claims and performs the work
-> specialist submits a structured proposal and provenance
-> backend validates and durably stores the proposal
-> backend creates a separate verification job
-> Astro launches the registered verifier
-> verifier independently investigates and submits a structured result
-> backend compares the durable specialist and verifier results
-> backend deterministically promotes, rejects, retries, or escalates
```

Specialists must not directly hand authoritative state to verifiers. Astro must
not use transient chat content as the verification queue. The proposal and
verification assignment must exist durably before verifier work begins.

Workers do not scan FANatical and choose arbitrary work unless discovery is an
explicit part of their registered contract. Even discovery workers receive a
durable discovery assignment, budget, scope, and output contract.

## Durable queues and job lifecycle

### Required durable records

Every production agent workflow needs durable representations for:

- the job type, target, reason, priority, availability, and creator/trigger;
- deduplication or active-work uniqueness rules;
- status and deterministic transition history;
- current claim owner, lease token, lease expiry, and heartbeat;
- each attempt, its actor, timestamps, outcome, failure classification, and
  summary;
- the structured specialist proposal and expected-current-version guard;
- evidence and provenance;
- the verification job and independent verifier result;
- the policy/version used for the decision;
- the resulting authoritative version or unresolved outcome;
- retry count, next retry time, exhaustion state, and last failure; and
- append-only audit events.

Deletion cascades must not erase authoritative evidence, verification, or fact
history merely because an ephemeral operational job is retired. Retention and
FK behavior must match the value and sensitivity of each record.

### Generic lifecycle

Specific names may vary by domain, but the common meanings are:

- `queued`: eligible when `available_at` is reached;
- `claimed`: one active actor owns an unexpired lease;
- `retry_wait`: recoverable, waiting until a deterministic retry time;
- `pending_verification`: a durable proposal exists and verification work is
  outstanding;
- `blocked`: a known external dependency prevents progress;
- `needs_review`: ambiguity, policy conflict, exhausted automation, or a genuine
  exception requires an authorized reviewer or Brad;
- `completed`: the requested outcome was accepted, or a recheck confirmed no
  change;
- `failed`: terminal under the current contract and retry policy; and
- `cancelled`: administratively closed without changing authoritative facts.

Domain-specific states are permitted only when they add meaning rather than
rename an existing generic state.

### Claiming and concurrency

Claims must be atomic, deterministic, scope-aware, and safe under concurrent
workers. The Team Color use of priority ordering plus `FOR UPDATE SKIP LOCKED`
is the reference pattern.

An agent may mutate a claimed job only while all of the following remain true:

- the authenticated user maps to one active agent actor;
- the actor holds the exact required capability in the target scope;
- the job is in the expected state;
- the actor owns the active attempt;
- the lease token matches; and
- the lease has not expired.

Concurrency limits belong to Astro/runtime configuration and backend claims.
They must be explicit per contract and globally bounded so spawning many
workers cannot exhaust the OpenClaw host, source rate limits, or Supabase.

### Lease and retry responsibility

Team Color specialist and determinate verifier work use the approved renewable
900-second lease. Their approved execution policy allows at most two total
attempts with immediate retry for classified transient technical failures;
permanent/configuration failures do not retry blindly. These values do not
become defaults for another agent contract. Every contract must use explicitly
approved lease, heartbeat, retry, and exhaustion policy. If implementation
requires a numeric operating value that Brad has not approved, the
implementation task must ask Brad rather than silently inventing a default.

Deterministic backend policy owns:

- retry eligibility;
- transient/permanent failure classification rules;
- retry timing;
- retry limits;
- requeue transitions; and
- exhaustion state.

Astro owns dispatch. It launches retry work only after the backend presents it
as eligible and never invents, advances, delays, resets, or overrides retry
policy. Permanent authorization, validation, identity, or policy failures must
not be retried as if transient. Exhaustion retains the full attempt history and
enters the backend-defined exception state rather than looping forever.

## Astro dispatch and wake contract

Each queue type must have a registry entry describing:

- the eligible statuses and wake condition;
- specialist contract and verifier contract;
- OpenClaw agent identity/configuration;
- required backend capabilities;
- maximum concurrent workers;
- lease and heartbeat expectations;
- retry/exhaustion policy;
- verifier-independence constraints;
- terminal and exception states; and
- safe operator controls.

Queue creation and state transitions should emit a durable wake signal or
outbox event. A periodic Astro poll may be a fallback, but it must not be the
only recovery mechanism if events can be lost. Wake delivery is at-least-once;
claiming and transition APIs must therefore be idempotent or reject duplicates
safely.

Astro may launch only registered specialist/verifier types and may not grant a
worker broader tools or credentials to overcome a failed claim. Worker-spawning
permission must be explicit and concurrency-limited. Astro dispatches only work
the backend reports as eligible; it does not infer retry eligibility from a
worker's message or alter a job's retry schedule.

## Agent contract standard

Every autonomous agent must have a reviewed contract covering:

1. **Job type:** Stable identifier and domain purpose.
2. **Authoritative assignment source:** Queue and claim RPC; never an informal
   chat handoff.
3. **Permitted reads:** Exact RPCs, public resources, and external research
   scope.
4. **Permitted writes:** Exact proposal, evidence, heartbeat, release, and
   completion interfaces.
5. **Prohibited operations:** Direct tables, governance actions, verification,
   code access, admin/service credentials, or unrelated tools.
6. **Structured output:** Versioned schema, normalized identifiers, confidence
   or unresolved fields where appropriate, and provenance requirements.
7. **Success criteria:** What qualifies as a complete attempt and what the
   backend will validate.
8. **Unresolved behavior:** Conflict, ambiguity, insufficient evidence, and
   unknown values must be represented, not guessed away.
9. **Failure behavior:** Machine-readable category plus plain-language reason
   and retained partial research.
10. **Retry behavior:** Transient/permanent classification, backoff, maximum
    attempts, and exhaustion state.
11. **Lease behavior:** Duration, heartbeat, safe renewal, and ownership checks.
12. **Interruption recovery:** What is durable before each risky boundary and
    how another worker resumes.
13. **Verification relationship:** Independent verifier contract, blinded
    inputs, result schema, and backend comparison rule.
14. **Human escalation:** Exact conditions that policy cannot resolve.
15. **Resource limits:** Concurrency, external rate limits, time, token, and cost
    budgets.
16. **Observability:** Events, metrics, correlation IDs, and operator-visible
    health state.

Agent instructions should explain how to use the contract; they must not be the
only enforcement of it.

## Operational security and permissions

Operational OpenClaw agents:

- authenticate as dedicated ordinary Supabase Auth identities;
- map one-to-one to active `catalog_actors` with `actor_type = 'agent'`;
- receive only named, narrowly scoped capabilities;
- use the browser-safe project key plus their own credentials, never service
  role, database, staff, or administrator credentials;
- interact with FANatical through approved RPCs and read models;
- cannot directly write queue, proposal, evidence, governance, reliability,
  verification, or authoritative-version tables;
- cannot grant capabilities, review their own permissions, or change source
  governance unless that exact independent governance role is separately
  designed and authorized; and
- cannot modify the FANatical repository or application code.

Operational specialist and verifier agents do not need access to the FANatical
repository or this complete canonical architecture document. They receive only
their approved contract, instructions, capabilities, and required runtime
context.

Because Astro is the supervisor responsible for applying this architecture, it
may receive an approved read-only/reference copy of this document. That copy
does not grant Astro general repository read access, repository write access,
application-code access, or authority to change architecture or policy. Astro
must continue to dispatch narrowly scoped workers rather than pass them the
complete architecture document.

Specialist and verifier identities must be separate actors with disjoint
proposal and verification capabilities appropriate to their roles. A generic
wildcard capability is not an operational shortcut. Runtime filesystem, shell,
browser, network, spawning, and secret access should be denied by default and
enabled only where the contract requires them.

Security, authentication, authorization, and FANatical data-governance
boundaries outrank ordinary runtime instructions. Brad remains the ultimate
policy authority.

## Proposals and independent verification

### Specialist result

A specialist submits a versioned structured payload, evidence, provenance,
expected-current-version guard, and unresolved information. Submission ends
the specialist attempt and creates or enables a verification job. It does not
promote authoritative data.

### Verifier result

A proposing actor can never verify its own proposal. The verifier independently
determines the answer and submits its own structured result and provenance.
Verification is not a checklist that the proposer used the correct format.

For a determinate factual domain, the verifier must receive the target question,
domain policy, and necessary neutral context without receiving the proposing
agent's answer, selected evidence, reasoning/rationale, or confidence. The
verifier must complete and durably submit its own structured result and
provenance before any of those specialist materials are exposed to it.
Necessary target context, safety metadata, and previously verified public facts
that do not disclose the candidate answer are not answer leakage.

Independent verification does not require zero source overlap. A verifier that
independently researches the question may legitimately discover and use some of
the same sources as the specialist. FANatical records and evaluates that overlap
and the underlying information lineages, and prefers additional independent
lineages where available. Evidence sharing one originating lineage still counts
as one lineage regardless of how many URLs, domains, publishers, mirrors,
aggregators, syndicators, or rewritten copies contain it.

The backend then compares structured results according to the versioned domain
policy. It may:

- promote an exact or policy-compatible match;
- reject an invalid proposal;
- request another independent verifier where policy permits;
- requeue research for missing evidence;
- retain a contradiction as unresolved; or
- escalate a genuine exception.

The comparison rule must be deterministic. Agents may explain ambiguity, but
they do not decide how an unmodeled discrepancy changes authoritative state.

### Domain examples

- Team Color Agent proposes current canonical colors; Team Data Verifier
  independently determines the current palette and ordering.
- Seat Resolver proposes seat geometry; Seat Verifier independently determines
  the mapping.
- Quiz Writer or a user submits a question; Quiz Verifier independently checks
  the question, answer, facts, and ambiguity.
- Source discovery proposes identity, ownership, domains, and applicability;
  Source Verifier independently investigates those claims.

## Evidence independence and information lineage

Evidence independence is counted by information lineage, not by URL count,
domain count, page count, or publisher count alone.

Syndicated, aggregated, mirrored, scraped, copied, republished, or lightly
rewritten versions of one originating report or dataset count as one lineage
where FANatical can reasonably identify their common origin. Five websites
repeating the same originating source are not five independent sources.

Ownership and lineage are related but not interchangeable:

- two sites under common control normally fail ownership independence even when
  they publish separate pages;
- separately owned sites may still share one information lineage through a wire
  report, common dataset, press release, or copied source; and
- one publisher may produce multiple genuinely independent original reports,
  though domain policy may still cap how much one ownership group can count.

Evidence records should be able to reference a versioned lineage or explicitly
record `unknown` lineage with the discovery basis. Unknown lineage must not be
silently counted as independent when policy requires proof of independence.
Lineage determinations, redirects, and merges require provenance and audit
history; they must not rewrite immutable decisions.

## Source governance, discovery, and learning

Source identity, approved URL ownership, ownership/independence, applicability,
governance trust, empirical reliability, and information lineage are separate
concepts. FANatical's deployed Trusted Source architecture already separates
publisher identity, URL scopes, ownership groups, per-data-type trust tiers,
target applicability, redirects, and empirical Team Color reliability. Future
work must extend that architecture rather than create a second source registry.

### Established-source research

Normal factual work uses the number of established independent sources required
by the versioned domain verification policy. A probationary source never
replaces required established evidence and can never be the sole evidence for a
production factual conclusion.

### Discovery exploration

Ten percent of eligible source-research checks or source slots are reserved for
deliberate exploration beyond the established source pool. This is not 10% of
jobs. Required established-source evidence remains unchanged; exploration is
additional and never replaces evidence required by the applicable verification
policy.

The backend or assignment policy selects and records eligible checks/slots so
workers cannot manipulate the rate by labeling ordinary searches as
exploration. Selection must be measurable, auditable, and distributed across
applicable targets rather than repeatedly exploring one easy area.

The 10% rule controls discovery. It does not mean that production conclusions
may rely on unqualified sources.

### Probationary source qualification

When a legitimate candidate is discovered:

1. register the reusable publisher/source as probationary or unrated;
2. retain the discovery URL, identity claim, ownership/lineage clues,
   applicability claim, timestamp, and discovering actor;
3. prevent it from influencing production truth decisions;
4. create shadow qualification work for 10 independently verified applicable
   cases as quickly as practical;
5. record its structured claim for each case without exposing the authoritative
   answer to the shadow worker;
6. compare each claim with the independently verified FANatical outcome; and
7. after 10 adjudicated cases, calculate the first empirical reliability result
   and apply the predefined automated qualification policy.

Do not wait for nine later 10% exploration opportunities. Once discovered, the
10-case qualification program is a separate durable workflow. If 10 applicable
cases do not exist, the source remains probationary; missing sample opportunity
is not evidence of poor reliability.

Empirical reliability alone must never automatically grant governance trust.
A source may nevertheless be promoted or qualified automatically when a
predefined deterministic qualification policy is satisfied. That approved
policy may consider empirical reliability, verified identity, approved
applicability, ownership/independence, information lineage, and any other
explicitly approved requirements.

Automatic qualification is therefore a deterministic policy decision based on
all required conditions; it is not reliability alone silently assigning trust,
ownership, applicability, or URL authority. A source remains probationary when
evidence or sample size is insufficient. Human intervention is required only
when the predefined automated policy cannot resolve the state or a genuine
governance exception exists. Routine successful qualification does not require
manual review.

### Reliability and gold-standard calibration

Reliability is empirical, append-only at the observation level, and calculated
by deterministic backend code. It may be scoped by data type, claim type,
applicability, method, or information channel when a universal score would be
misleading. Agents do not calculate or award their own trust scores.

Calculations should account for:

- adjudicated sample size;
- matches, contradictions, unresolved, and not-assessable outcomes;
- breadth across targets, sports, leagues, and relevant claim types;
- recency and performance drift;
- corroboration outside the source's ownership and information lineage; and
- statistical uncertainty, using a conservative interval such as the Wilson
  lower bound already used by Team Color where appropriate.

Probationary and established sources should continue to be calibrated against
highly trusted reference sources, independently verified FANatical facts, and
strong independent evidence. A highly trusted source remains evidence, not an
oracle, and its empirical performance remains measurable.

Reliability should be recomputed after adjudicated applicable outcomes and
calibrated on a versioned domain schedule. No timing, sample alert,
contradiction, inactivity, or similar numeric operating threshold becomes a
canonical default unless Brad explicitly approves it. One incorrect case does
not erase a long history of strong performance, and one successful case does
not make a source authoritative.

## Verified-data lifecycle

A current verified fact is already filled/current. Do not create another
`filled` state.

Verified records leave ordinary missing-data queues and are protected from
unrestricted update or deletion. Replacement follows:

```text
current verified value
-> new durable candidate
-> independent verification
-> new verified value
-> former version superseded
```

Historical versions, evidence, policy snapshots, decisions, and provenance are
retained. Optimistic expected-current-version checks must prevent a stale worker
from replacing a fact that changed after its research began.

Age alone does not make a verified fact unverified. A due review creates work;
it does not strip the current value of its verified status.

## Periodic revalidation

Review cadence is configured by data type or domain, not individually on every
record. Individual records inherit the current versioned cadence unless an
audited exception is justified.

Relevant verified data should support:

- `last_verified_at`;
- `next_review_at`;
- review reason and trigger;
- cadence-policy version; and
- the last completed review outcome.

When a review becomes due, deterministic backend scheduling creates a recheck
job and wakes Astro. The backend does not research the answer.

```text
review due
-> backend queues recheck
-> Astro dispatches specialist
-> specialist independently researches current answer
-> backend stores result and queues verification
-> verifier independently researches
-> backend records the outcome
```

If unchanged, retain the verified value, record the revalidation decision,
update review timestamps, and schedule the next review. If changed, create and
verify a replacement, then supersede the former version. If unresolved, retain
the existing verified history and follow the exception path.

Every domain must have an explicitly approved cadence before scheduled
revalidation is implemented. The architecture does not supply an invented
timing default. Event-driven triggers may complement the cadence when defined by
versioned domain policy.

## Watchdogs, stalled work, and recovery

Autonomy requires a deterministic watchdog/recovery mechanism independent of
specialist reasoning.

It must detect:

- eligible queued jobs remaining unclaimed too long;
- expired leases and missing heartbeats;
- specialist attempts that fail to return;
- verification jobs that fail to return;
- Astro failing to process waiting work;
- retry exhaustion;
- proposals stranded without verification jobs;
- verifier results stranded without comparison; and
- state transitions that remain permanently incomplete.

Where safe, it expires the attempt, retains failure provenance, makes the job
recoverable, schedules the approved retry, and wakes Astro again. It must use
idempotent transitions and row locking so the watchdog, Astro, and a late worker
cannot complete the same transition twice.

Watchdog frequency, unclaimed-work thresholds, re-signal behavior, and other
numeric operating values require Brad's explicit approval or an already
approved domain policy. An implementation task must ask rather than inventing a
value.

Team Color's durable attempts, lease expiry transition, `retry_wait`, and event
ledger are the current reference patterns. A claim-time expiry sweep alone is
not sufficient for the canonical architecture because recovery must continue
even when no new worker is attempting a claim.

OpenClaw process availability is a separate failure domain. The host/service
layer must supervise the OpenClaw Gateway and persistent Astro process, restart
them when appropriate, and surface repeated restart failure. FANatical's durable
state must survive those restarts, and Astro must reconcile ready work after
startup rather than depend on lost in-memory notifications.

## Human escalation and exceptions

An agent may escalate when:

- required policy is absent or contradictory;
- source identity, ownership, applicability, or lineage cannot be resolved
  under existing rules;
- independently researched results conflict beyond the deterministic comparison
  policy;
- automation reaches approved retry or verifier limits;
- a requested transition would weaken verified history, permissions, or
  security boundaries;
- legal, privacy, financial, safety, or account-ownership authority is needed;
  or
- the launch gate explicitly reserves the decision for Brad.

Escalation must include the job ID, target, current state, attempts, evidence,
machine-readable category, plain-language ambiguity, and safe next options. It
must not destroy partial work or manufacture a result to clear the queue.

Repeated ordinary escalations are architecture feedback. They should produce a
policy/interface improvement proposal rather than permanent routine human work.

## Observability and operational controls

Each workflow should expose, without secrets:

- queue depth and age by status/job type;
- claim latency, completion latency, and verification latency;
- active leases and heartbeat freshness;
- attempts, retries, exhaustion, and failure categories;
- Astro wake/dispatch acknowledgements;
- specialist and verifier concurrency;
- proposal, verification, and promotion outcomes;
- source exploration and probationary-qualification progress;
- reliability sample size and drift alerts;
- revalidation due/overdue counts;
- watchdog actions and unresolved stalls; and
- correlation from job through proposal, verification, fact version, and audit
  events.

Administrative controls must be narrow, authenticated, authorized, audited, and
recoverable where possible. Pausing a queue, revoking an actor, cancelling work,
or requeueing an exception must not imply permission to edit verified facts.

## Agent Launch Gate

No production agent is launched until it passes all eight stages below.

### 1. Agent contract review

- Contract contains every field required by the Agent Contract Standard.
- Job/result schemas and unresolved/failure behavior are unambiguous.
- Routine decisions are deterministic or assigned to an explicit agent role.

### 2. Dependency review

- Required migrations, tables, RPCs, RLS, constraints, policies, queues,
  secrets, source interfaces, and runtime tools exist in the target environment.
- Hosted state is verified; a local migration alone is not completion.
- Dependencies have owners, failure behavior, and recovery paths.

### 3. Data-governance review

- Authoritative identity, versioning, provenance, supersession, and duplicate
  rules are defined.
- Trust, applicability, ownership, reliability, and information lineage remain
  separate.
- Verified data cannot be casually overwritten.
- Probationary sources cannot influence production truth.

### 4. Runtime review

- Astro dispatch/wake behavior and startup reconciliation are tested.
- Worker identity, credentials, capabilities, tools, filesystem/network access,
  spawning permissions, concurrency, rate limits, leases, retries, and watchdog
  behavior are explicit.
- OpenClaw process supervision and interruption recovery are tested.

### 5. Instruction review

- Steering files match the deployed APIs and policy terminology.
- Security/authentication/authorization/data-governance boundaries outrank
  ordinary runtime instructions.
- Untrusted external content is treated as evidence, never agent instruction.
- No application-code access or undocumented human dependency is implied.

### 6. Adversarial pre-launch audit

Test at minimum:

- capability escalation and direct-table writes;
- self-verification and verifier answer leakage;
- source overlap, source-lineage duplication, and common-ownership duplication,
  including valid independently discovered overlap that must not be rejected
  merely because URLs or publishers recur;
- probationary-source influence and shadow-qualification bypass;
- stale expected-version replacement;
- duplicate claims, late workers, lease expiry, retry exhaustion, and watchdog
  races;
- Astro wake loss, process restart, and interruption recovery;
- malformed structured output and prompt injection in sources;
- runaway worker spawning, concurrency, cost, and rate-limit handling;
- reliability manipulation, reliability-only trust escalation, and bypass of
  approved automatic-qualification requirements; and
- accidental routine dependence on Brad or another human.

Negative permission checks must be read-only. If denial cannot be demonstrated
without attempting a mutation, report the check as unverified instead of making
a destructive test merely to prove it fails.

### 7. Bootstrap and dry run

- Verify the dedicated actor mapping and exact capability set.
- Verify positive and negative access without real production mutations.
- Run local transactional integration tests and a shadow/dry-run assignment.
- Confirm logs, provenance, retry, lease, and recovery behavior contain no
  secrets and preserve correlation.

### 8. First controlled live production job

- Use one deliberately selected low-risk real job.
- Monitor specialist dispatch, durable proposal creation, independent verifier
  dispatch, deterministic comparison, final state, audit history, and recovery
  signals.
- Do not broaden permissions or batch-enqueue work until the controlled job is
  accepted against the contract.

Known structural weaknesses discovered before launch must be fixed unless Brad
explicitly accepts the stated risk. Passing a happy-path job does not waive a
failed security, independence, recovery, or governance gate.

## Team Color reference implementation

Team Color is the first production-grade reference for FANatical agent
infrastructure. Existing patterns that materially inform this standard include:

- scoped `catalog_actors` and `catalog_actor_capabilities`;
- dedicated ordinary Auth identity and narrow RPC access;
- durable `team_color_work_items`, attempts, and append-only events;
- deterministic concurrent claiming with `FOR UPDATE SKIP LOCKED`;
- lease tokens, heartbeat/renewal, expiry recovery, and `retry_wait`;
- active-work and pending-proposal deduplication;
- expected-current-version protection;
- durable structured proposals, governed evidence, immutable decisions, and
  verified-version supersession;
- separate publisher identity, URL ownership, independence group, per-data-type
  trust tier, and target applicability governance;
- exact provenance-version snapshots;
- append-only empirical reliability derived from later adjudication; and
- transactional integration coverage for permissions and workflow invariants.

The next implementation phase must audit Team Color against this document and
classify findings as:

1. behavior already satisfying the standard;
2. reusable patterns worth preserving and generalizing;
3. gaps requiring correction before the live agent runs; and
4. domain-specific implementation that should not be copied into the generic
   architecture.

Mandatory audit targets include:

- Astro queue wake, dispatch, concurrency, and startup reconciliation;
- a durable verifier queue and independent structured verifier result;
- verifier blinding and backend comparison rather than proposal approval alone;
- information-lineage modeling in addition to ownership independence;
- 10% source exploration and 10-case shadow qualification;
- generic reliability/calibration interfaces that prevent reliability alone
  from assigning trust while permitting approved deterministic automatic
  qualification when every required condition is satisfied;
- domain cadence, `last_verified_at`, `next_review_at`, and scheduled rechecks;
- continuously scheduled watchdog/recovery behavior rather than claim-time
  recovery alone; and
- a complete launch-gate audit with a controlled first production job.

No Team Color behavior should be changed merely because this document names an
audit target. Corrections require their own inspected, tested, migration-safe,
and explicitly authorized implementation pass.

## Reuse and scale

Reusable infrastructure should converge on common contracts for:

- job registration, queues, attempts, leases, retries, and events;
- Astro wake/outbox, dispatch registry, concurrency, and reconciliation;
- actor provisioning, capability scopes, and runtime permissions;
- proposal, evidence, provenance, and expected-version guards;
- independent verification assignments, blinded result capture, and
  deterministic comparison;
- publisher/source identity, URL ownership, applicability, ownership,
  information lineage, and redirects;
- source exploration, probationary shadow qualification, calibration, and
  empirical reliability;
- verified version promotion, supersession, and periodic revalidation;
- watchdog recovery, observability, and launch validation.

Domain-specific schemas and policies remain appropriate when truth structures
differ. Reuse means shared guarantees and interfaces, not forcing Quiz, Seat,
Team Color, and other determinate facts into an identical payload or
verification rule.

The long-term target is an autonomous multi-agent operating system in which
routine work progresses without human-in-the-loop intervention, each new
specialist or verifier needs less bespoke infrastructure than the previous one,
and Brad retains authority over architecture, policy, security-sensitive
decisions, and genuine exceptions.
