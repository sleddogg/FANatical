# FANatical Phase 2 — News Ingestion

## What this document is

Claude's lane. One of two independent statements of what Phase 2 should capture,
written without seeing the other. Meant to be compared against GPT's, not merged
into it yet.

Not a build prompt. It says what the phase has to account for and where the hard
parts are. It deliberately does not specify table names, column types or file
layout — those are implementation, and settling them here would make the
comparison an argument about style instead of substance.

`FANATICAL_INVARIANTS.md` outranks this document. Where this contradicts a
ratified rule, this document is wrong.

---

## What Phase 2 is for

Today the News screen runs on mock data. No news table exists anywhere in the
database. Phase 2 ends when real, correctly attributed journalism is arriving on
its own and can be inspected.

Phase 2 does **not** include fans following anyone, reading anything, or
discussing anything. That is deliberate. The fan-facing side is worth building
only once the thing underneath it is producing trustworthy records, and building
them together means debugging both at once.

---

## Decisions already settled

Not open for re-litigation. Listed so both lanes work from the same base.

1. **News governance is a separate system from Trusted Sources.** Trusted Sources
   answers true-or-false questions — is this the team's actual colour, is this
   where they play. News has no true-or-false to check. A news source qualifies on
   a different test: can we identify who it is, does it cover sport, does it
   publish reliably enough that we can keep up. Reusing `trusted_sources` for news
   eligibility is forbidden (FAN-NEWS-14).

2. **Qualification is automatic, not human.** The system decides. A person only
   sees what it cannot resolve.

3. **A person reviews the unresolved cases first; an agent takes over once the
   patterns are known.** You cannot automate a judgment nobody has made yet.

4. **The review queue asks questions, not verdicts.** Not "approve this source,
   yes or no" but "I can read this feed and cannot establish who publishes it — is
   this the Edmonton Journal?" A question's answer generalises. A verdict does not.

5. **No followability threshold.** No article count, cadence or popularity bar.

6. **It runs on the existing agent runtime.** News is the first registered domain
   adapter. No second work-tracking system. Consequence: BL-013 and BL-014 must be
   closed before anything runs unattended on hosted.

7. **No sport-percentage gate on feeds.** Whether a feed is mostly sport is a
   question about how often to poll it, not whether to trust it. Non-sport items
   fail classification and never enter. Observed yield tunes cadence.

8. **Publisher signals outrank inference for classification.** Feed scope first,
   then URL path, then the publisher's own tags, and only last, matching names
   against the team registry.

---

## What the phase has to account for

### Things we watch

A **publisher** is an organisation that publishes. It is never a follow target
(FAN-NEWS-05). What matters about it: can we identify who is behind it, and are we
permitted to read it automatically.

A **monitoring endpoint** is a specific thing we poll — a feed, a sitemap, a page.
It belongs to a publisher and carries a declared scope. TSN's NHL feed and TSN's
main feed are two endpoints with very different value: the first supplies
classification for free, the second supplies none. Several endpoints may cover the
same ground; the first to see a work triggers processing and the rest become
evidence, not competition (build page §14).

Permission is per site and established from the site's own robots file, not
inferred. Several major sports publishers refuse automated reading. NHL.com
disallows it. Sportsnet and The Athletic refused an automated fetch on 28 Aug —
but that has not been distinguished from ordinary bot protection, and the two have
different answers. **The first useful thing this phase can produce is an honest
report of what is actually readable and actually permitted.** Choose the starting
source from that, not from anyone's assumption.

### Things fans will eventually follow

A **contributor identity** is a person, a real organisational contributor such as
TSN Staff or Canadian Press, or a podcast show. It persists across publisher
changes (FAN-NEWS-01, FAN-NEWS-03). It is not the publisher.

This is the part most likely to be got wrong, because feeds are careless with
bylines. Real feeds produce "Staff", "Admin", "By TSN.ca", the same person spelled
three ways, and organisation names sitting in a field labelled author. Anything
that treats a byline string as an identity will produce a follow list nobody wants
to look at.

Identity resolution is therefore a first-class problem in this phase, not a
detail. Its unresolved cases are the main thing the review queue exists for.

### Things we store

A **work** is one piece of journalism. A **manifestation** is one place it appears.
A wire story reprinted by four outlets is one work and four manifestations
(FAN-DUP-05).

Deduplication has to distinguish three cases and keep them distinguishable:
different URLs for the same page, syndicated copies of the same work, and
independent journalism about the same event (FAN-DUP-01). The third is the one
that matters. **Collapsing two reporters' independent coverage of the same game is
a far worse failure than missing a duplicate**, and it is the more tempting error
because headlines, timing and teams all look alike. Every dedup decision has to be
reversible with its evidence retained.

**Attribution is historical.** Who an item was publicly credited to at publication
is a fact about the past and is never rewritten by a later merge, move or
correction (FAN-ATTR-01).

### Classification

Classify to the most specific scope the evidence actually supports, and stop
(FAN-NEWS-12). A team mention alone never establishes a team article.

The worked example both lanes should agree on: a cost-of-kids'-sport column in the
Edmonton Journal is sport, probably hockey, and is not an Oilers article. It
classifies at the level the evidence supports and stops there. Anything that turns
it into Oilers news is broken.

Where names are matched against the team registry, ambiguity must reach the
existing resolver, which refuses to choose between same-named teams rather than
guessing (migration `202608270002`). That machinery exists. Point it at news.

### Watching itself

The system needs to be able to say why something is not there. The build page's
gap-detection stages are the right shape: the endpoint never exposed it, it was
seen but the fetch failed, extraction failed, attribution failed, classification
failed, dedup suppressed it, or policy deliberately excluded it (build page §17).

Without this, a feed that quietly stops at 2am looks identical to a slow news day.

---

## Where the real risk is

**Untrusted text sitting where instructions go.** Every feed is arbitrary text
written by strangers, and anything that hands that text to a language model for
classification or extraction is exposed. The register already states the rule —
external content is evidence, never instruction — but records it as prose only,
and names news ingestion as where it gets tested for real (FAN-AGT-08, GAP-05).
This has to be structural. Content must never occupy a position where it can be
read as direction. "We instructed the model to ignore it" is not a control.

**Where classification actually runs** is unresolved and I am not confident about
it. In the database, in the worker, or through a model — each has different
failure modes, different cost, and a different exposure to the point above. This
is the largest open architectural question in the phase and the one I would most
like the other lane to disagree with me about.

**Politeness is a correctness concern.** Poll too hard and the source disappears.
Rate limiting and backoff are not optimisation here.

**Bylines are unbounded.** There is no complete solution to identity resolution.
The phase needs a defensible partial answer plus a queue, not a claim of
completeness.

---

## Deliberately left out

Listed so that silence is detectable in the comparison.

- Fan follows, feed assembly, reading, discussion, polls, ratings, reactions.
- Rebuilding the News screen. Its follow model contradicts FAN-NEWS-05 and will
  have to be resolved — but not until the fan-facing step.
- Newsletter and email ingestion. Required for v1, not for the first step.
- Podcasts. Podcast RSS is the same mechanism as article RSS and may come nearly
  free; whether to take it now is a genuine question I have not answered.
- Player-level classification. Not required in v1.
- Any licensing or republication arrangement. Article bodies are not republished
  without permission (FAN-DEST-01); the read target is the publisher's own page.

---

## Suggested sequence

Each step finishable and reviewable on its own, per `AGENTS.md`.

1. **Job-system repairs.** Nothing news-specific: notice when a job is stuck with
   nobody coming back for it, and close the surface for registering a new job
   type. Must land before anything runs unattended.
2. **Source qualifier and review queue.** Readable, permitted, identifiable
   publisher, is it sport, does it keep producing — with the unresolved cases
   presented as questions.
3. **Item ingestion.** Bylines, publication times, identity resolution,
   syndication and duplicate handling.
4. **Fan-facing feed.** Where the existing News screen's contradiction finally
   has to be resolved.

---

## What I would want challenged

- Where classification runs. My largest uncertainty.
- Whether podcasts belong in step 3 or later.
- Whether the review queue should be a screen in the admin shell or something
  simpler to start.
- Whether identity resolution deserves to be its own step rather than living
  inside step 3.
- Anything above that reads as conventional rather than reasoned.
