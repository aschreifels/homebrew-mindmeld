# What the articles look like

Four entity types, each with its own required frontmatter and its own place in
recall. These examples are trimmed and annotated — copy the shape, not the
placeholder values.

## Pattern

```markdown
---
title: "Retry with jittered backoff"    # equals the H1
type: pattern
created: "2026-08-01"                    # required on every entity type
updated: "2026-08-18"
domain: general                          # contract | general | oss | personal | work
confidence: low                          # high | medium | low
tags: [go, reliability]
related: []
sources: ["projects/example-api/learnings.md"]
status: needs-review                     # until ratified — Patterns.base's Review queue reads this
maturity: candidate                      # candidate | proven — proven = seen in ≥2 shipped changesets
applies_to: [general]                    # the retrieval axes — never a project name
use_when: "a retried call can pile up against a struggling downstream"
avoid_when: "the call is already idempotent-safe and cheap to hammer"
context_tags: [reliability]              # situational, singular, reuse existing vocabulary
languages: [go]                          # first = canonical exemplar
source_exemplar: "internal/retry.go @ a1b2c3d"
---

# Retry with jittered backoff
{one paragraph: the recurring shape and why it recurs}

## Shape
{pseudo-code or the landed exemplar, trimmed}
```

**How recall uses it:** patterns land flat at `patterns/{slug}.md` — never under
a per-project directory, because a pattern is usually more than one thing at
once and a directory can only file it under one. `Patterns.base`'s Review queue
view filters on `status == "needs-review"` or `maturity == "candidate"`.
`use_when`/`avoid_when`/`context_tags` are the retrieval manifest that makes a
pattern findable mid-session over a fast BM25 search, and judgeable once found.

## Decision

```markdown
---
title: "Queue retries instead of blocking the request path"
type: decision
created: "2026-08-01"
updated: "2026-08-01"
domain: general
confidence: high
tags: [reliability]
related: []
sources: ["projects/example-api/decisions-log.md"]
status: decided                          # decided | reconsidering | superseded
date_decided: "2026-08-01"
---

# Queue retries instead of blocking the request path

## Context
{the constraint or tension that forced a call — no solution yet}

## Decision
{the call, in a sentence or two}
```

**How recall uses it:** decisions/ has no dedicated board — there's no
`Decisions.base` shipped today. They surface through ordinary `qmd` recall
(indexed under the KB-root collection) and through other articles' `related:`
wikilinks pointing back at them.

## Solution

There's no shipped `templates/solution.md` yet, unlike pattern, decision, and
ticket — the fields below come straight from the schema:

```markdown
---
title: "Debounce duplicate webhook deliveries"
type: solution
created: "2026-08-01"
updated: "2026-08-01"
domain: work
confidence: medium
tags: [webhooks]
related: []
sources: ["projects/example-api/learnings.md"]
problem: "a flaky upstream retries the same webhook and duplicates side effects"
applies_to: [webhooks]
---

# Debounce duplicate webhook deliveries
{the fix — what was tried, what worked, what to watch for next time}
```

**How recall uses it:** same as decisions — no dedicated board, found through
`qmd` recall over `solutions/` and through `related:` links from the articles
that cite it.

## Ticket

```markdown
---
title: "EK-3: retry queue drops jittered backoff on restart"
type: ticket
created: "2026-08-18"
updated: "2026-08-18"
domain: personal
confidence: high
tags: []
related: []
sources: []
ticket: "EK-3"                           # handle: repo-initials + sequence
project: "example-kb"                    # the repo's manifest slug
status: backlog                          # backlog | active | in-review | done | dropped
priority: p2                             # p1 | p2 | p3
---

# EK-3: retry queue drops jittered backoff on restart

{Problem — what's wrong or missing and why it matters.}

## Acceptance criteria
- [ ] {observable outcome, not implementation step}
```

**How recall uses it:** tickets live at `tickets/<project>/<HANDLE>_<slug>.md`.
The handle prefix is the initials of the repo's hyphenated segments
(`example-kb` → `EK`; a single short segment uppercases instead — `api` →
`API`); the sequence is the max existing number for that prefix, plus one. The
handle rides the branch name (`as/EK-3_retry-queue-fix`), and `Tickets.base`'s
Board view sorts on `status` then `priority`.

## Related

- [walkthroughs/first-mining-run.md](first-mining-run.md) — how a pattern candidate gets here
- [walkthroughs/first-sweep.md](first-sweep.md) — the changeset-driven path to a pattern
- [rituals/kb-ticket.md](../rituals/kb-ticket.md) — ticket handles, verbs, the landing pass
- [kb-layout.md](../kb-layout.md) — every directory these types live in
