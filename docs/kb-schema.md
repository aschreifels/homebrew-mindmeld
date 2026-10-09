# The KB schema

This is the paradigm contract every KB shares — the directory layout, the seven
entity types and their frontmatter, and the operations available on top of them.
`mindmeld update` re-stamps this page from the checkout, so it always matches the
mindmeld version you have installed; your own context belongs in `{kb.root}/OWNER.md`
instead, which no update ever touches.

## Directory Structure

```
raw/                    Immutable source material — NEVER modify
  articles/             Captured articles from pipeline or web clipper
  assets/               Downloaded images referenced by articles
  imports/              Bulk imports from projects or external sources

wiki/                   LLM-compiled knowledge articles
  _index.md             Master index — every article listed with one-line summary
  _backlinks.json       Reverse link index {target: [sources]}
  _sessions_log.json    Tracks processed Claude Code session IDs

projects/               Per-project extracted knowledge (projects/{name}/overview.md + subtopics)
  {name}/.repo.yaml     Links KB dir back to source repo
  {name}/learnings.md   Rolling memory: insights and lessons (rolling: true, append-only)
  {name}/decisions-log.md  Rolling memory: decisions with context (rolling: true, append-only)
research/               Topic-based research deep dives
solutions/              Reusable technical solutions
tools/                  Tools evaluated or used — capabilities, setup, verdict
decisions/              Architectural decisions with reasoning and outcome
patterns/               Recurring patterns — one flat file each, never a per-project subdir
ideas/                  Unrealized project ideas and exploration notes
people/                 Contacts, collaborators, context
  {owner}/              The owner's own identity home — person doc, voice.md, voice/
sessions/               Extracted Claude Code session insights (optional — via a session-mining tool, when present)
output/                 Transient query results and reports (gitignored)

tickets/                KB-native tickets, one sub-dir per project ({project}/{HANDLE}_{slug}.md)
docs/                   Engine-stamped guide (mindmeld docs install); mindmeld-managed, not articles (machine-local, gitignored)
adapters/{name}/notes.md  Active adapter's stamped notes.md; mindmeld-managed, not an article (machine-local, gitignored)
templates/              User-editable output templates the skills resolve FIRST
  ticket.md             (kb-ticket create) — packaged skill references are the fallback
  pattern.md            (wrap-session pattern sweep)
  dossier/              (spawn/wrap rituals — the complete dossier output surface)
    MANIFEST.md  plan.md  adr.md  contract.md      (the planning set)
    chunk-brief.md  chunk-report.md  spec-brief.md  (the execution set)
    wrap.md                                         (the handoff)
```

---

## Frontmatter Conventions

Every wiki article requires YAML frontmatter. Seven entity types:

### Required fields (all types)

```yaml
---
title: "Article Title"
type: project | tool | person | decision | pattern | solution | research
created: YYYY-MM-DD
updated: YYYY-MM-DD
domain: contract | general | oss | personal | work
confidence: high | medium | low
tags: [tag1, tag2]
related: ["[[Other Article]]"]
sources: ["raw/imports/filename.md", "https://url"]
---
```

### Type-specific fields

**project**: `status` (active | paused | completed | idea | needs-review), `stack`
**tool**: `url`, `verdict` (use | evaluate | skip), `alternatives`
**person**: `role`, `context`
**decision**: `status` (decided | reconsidering | superseded | needs-review), `date_decided`
**pattern**: `applies_to` (the reusable axes a pattern is retrieved by — a language,
a framework, a use-case, or "general" when it is none of those; never a project name,
because a pattern filed under the project it was found in is sequestered from every
other project that could have reused it), plus the retrieval
manifest — `use_when` (one-line trigger condition), `avoid_when` (the counter-signal),
`context_tags` (situational not technological; singular; check existing vocabulary
before minting new values), `languages` (flavors present; first = canonical exemplar),
`maturity` (candidate | proven — proven means seen in ≥2 shipped changesets),
`source_exemplar` ("repo-rel path @ sha"). The manifest is what makes patterns
findable mid-session (BM25 fast path) and judgeable at recall time.
**solution**: `problem`, `applies_to`
**research**: `status` (active | backlog | completed | stale | needs-review), `depth` (shallow | moderate | deep)
**voice docs** (the type enum is fixed, so these carry `type: person` + a `voice:`
discriminator): `voice` (compiled | corpus), `status` (needs-distillation | distilled),
`captured` (capture date, corpus day-logs only). The two variants are validated against
different required sets, because they're different kinds of thing. `voice: compiled` is
an article and keeps the whole all-set above (it drops only person's `role`/`context`).
`voice: corpus` is a capture log, and its required set is exactly what wrap-session
writes when it opens a day-log: `type`, `voice`, `status`, `captured`. Title, domain,
tags, dates, related, and sources are all optional on a day-log — a richer one that
carries them is fine, but a minimal one is not malformed. The owner's identity home is a folder —
`people/{owner}/` holds the person doc (same basename), `voice.md` (`voice: compiled` —
the voice reference loaded into every session through the KB's `AGENTS.md` include), and
`voice/` (day-log captures from wrap-session, `voice: corpus`,
`status: needs-distillation` until `/voice-distill` folds them and flips the status —
never deleted, per no-deletion). `Voice.base` filters on the `voice` field. (Same enum
constraint is why `type: ticket` works only because lint doesn't scan `tickets/` —
extensible types are an upstream tooling ask, when a lint tool is present.)
**ticket**: `ticket` (handle, `PREFIX-N`), `project` (manifest slug), `status`
(backlog | active | in-review | done | dropped), `priority` (p1 | p2 | p3). Tickets live
in `tickets/<project>/<HANDLE>_<slug>.md`. Handle prefix: initials of the repo's
hyphenated segments (`example-kb` → `EK`), or the uppercased name when it's a single
short segment (`api` → `API`); sequence = max existing for that prefix + 1. Body =
problem, acceptance criteria, `- [ ]` sub-items (Tasks plugin). The handle rides the
branch name (`as/EK-3_feature`). `Tickets.base` is the board; `provider = "kb"` in
`mindmeld.toml` (legacy fallback: `spawn.toml`) wires the spawn/wrap rituals to these files.
Optional `dropped_reason`: the human's own explanation for a move to `status:
"dropped"`, written by `ticket.update`'s own `reason` field — required (8 characters
minimum) whenever that move happens, absent otherwise. Moving a ticket back OUT of
`dropped` clears it. A ticket dropped before this field existed, or hand-edited
straight to `status: "dropped"`, simply carries none — never an error, just something
a recovering driver asks a human about instead of guessing.
Optional `idempotency_key`: the caller-supplied key a keyed `ticket.create` carried,
written once at creation and never updated. It is what lets a retried create be
answered from disk alone — the same key with the same `project` returns this
ticket, the same key with a different `project` is refused. Absent on a ticket
created without a key (including every ticket that predates the field); an absent
key never matches a request.

**candidates** (not a `type:` value — a mined draft keeps whatever `type` the extractor
assigned): quarantined by living in `candidates/` plus `status: needs-review`; the pair
together is the quarantine marker. A candidate whose type carries a `status` of its own
also carries `promoted_status:` — the status the article takes on admission, supplied by
the extracting model — because top-level `status:` is occupied by the quarantine marker
for as long as the draft is quarantined. Promotion resolves the pair rather than
stripping it: `needs-review` is dropped and `promoted_status` is renamed to `status`.
Carries a Go-owned `mined_from` block a
model never supplies: `session_id` (which session cited it — also prepended to `sources`),
`source` (which harness, e.g. `claudecode`), `project` (repo basename), `branch` (when known),
`mined_at` (extraction time, RFC3339), `mined_on` (hostname — machine-state discipline),
`extractor` (`local` | `agent`), `model` (`gemma3:4b` | `harness`), `anchors` (how many
specificity anchors it scored against the gate). A repeated sighting adds
`mined_from.recurrence`: `count` (independent sightings, derived as `len(sessions)`, never
hand-trusted), `sessions` (which sessions corroborated it, first sighting first), `projects` /
`extractors` (which repos and extractors corroborated it, each deduped and insertion-ordered),
`first_seen` / `last_seen` (`YYYY-MM-DD` span across sightings). Absent block means seen once —
count is never written as a literal `1`. The whole `mined_from` block, `recurrence` included, is
Go-owned and survives promotion untouched.

Patterns under review additionally carry `status: needs-review` + `review:` (a one-line
who/when note) until ratified — `Patterns.base`'s Review queue filters on these; flip
`maturity: candidate → proven` and drop `needs-review` on ratification.

**authority** (optional, cross-cutting — any type): `contextual` | `opinion` | `canonical` |
`manual` (hand-authored/curated — automated writers must never destructively rewrite;
append/union or propose-as-candidate only). Gates automated rewrites when a
KB-maintenance tool is present.

`active` means in flight *now* — it's what the KB-open helper, the KB-pulse hook (when
wired), and the Open Work board surface. `backlog` means known and queued deliberately:
visible on the board's Backlog view, silent everywhere else. Flip backlog → active when
work actually starts.

### Domain values

Configured under `domains:` in the KB's config (e.g. `scribe.yaml`, when that tooling
is present). A typical KB uses:

- `contract`
- `general`
- `oss`
- `personal`
- `work`

The `personal` and `general` domains are always accepted for cross-cutting content.

---

## Operations

If a KB-maintenance tool (e.g. `scribe`) is present on the machine, it typically exposes
operations along these lines — detected-if-present, never assumed:

- sync — discover projects, extract changed repos, absorb raw articles, reindex qmd.
- sync --sessions — mine Claude Code sessions via a session-mining connector.
- capture — capture and fetch queued external content.
- dream — periodic memory consolidation.
- lint --changed — validate frontmatter on uncommitted changes.
- triage — score sessions by knowledge density.
- doctor — health check over deps, config, cron, state, freshness, errors.

None of this is required for the KB to function — the schema and directory layout above
are the contract; automation on top of them is optional.

---

## Customizing the boards

The `*.base` files are Obsidian Bases, shipped as **starting templates** and owned by this
KB from then on. They are machine-local: not committed, seeded once at install, and kept
current by `mindmeld update`, which records the version it last gave you and three-way
merges a new release against your edits rather than overwriting either.

That machinery has a happy path, and it is worth staying on it:

**Add views. Don't edit the ones that shipped.**

A base is a top-level filter, a property list, and a list of named views. Adding a view of
your own leaves every shipped view byte-identical, so when a release changes one, the two
edits are in different places and the merge is clean. Editing a shipped view in place puts
your change and the release's change on the same lines — the one case a textual merge
handles badly — so it conflicts, and `update` leaves the board untouched and says so. Safe,
but that board stops receiving improvements until you resolve it by hand.

So to see only one project's tickets, add a view:

```yaml
  - type: cards
    name: my-project
    filters:
      and:
        - project == "my-project"
        - status != "done"
```

rather than adding those filters to `Board`. Same result in Obsidian; a diff that merges
instead of fighting.

Two corollaries:

- **A board you invent yourself never conflicts at all.** It isn't in the shipped set, so
  nothing ever tries to update it. Wholly local boards are free.
- **A change that isn't specific to you probably belongs upstream.** A better default sort
  or a missing column helps every adopter, and sending it to the template removes your
  local delta entirely — the cheapest edit to maintain is the one you no longer have.

---

## Core Rules

1. **Every task produces two outputs** — the answer AND updates to relevant wiki articles.
2. **Cross-domain tags from day one** — the `domain:` field is required.
3. **Source citation** — every claim traces back to a raw entry, URL, or session.
4. **Raw is immutable** — never modify files in `raw/`.
5. **Directories emerge from data** — don't pre-create empty category subdirectories.
6. **Anti-cramming** — if adding a third paragraph about a sub-topic, that sub-topic deserves its own page.
7. **Anti-thinning** — a stub with 3 vague sentences is a failure. Enrich or don't create.
8. **Canonical project paths** — `projects/{lowercase-name}/overview.md`.
9. **Post-write size check** — split articles over 150 lines.
10. **Rolling memory files** use `rolling: true` frontmatter and append-newest-first.
11. **Reality wins** — fix contradicted articles in place, don't carry both versions.
12. **No knowledge deletion** — the KB is append-only; mark superseded, never delete.
