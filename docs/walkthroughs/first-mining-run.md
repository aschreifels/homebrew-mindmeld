# Your first mining run

Mining turns past agent sessions into candidate knowledge-base drafts — markdown
files quarantined until you say yes. Nothing it writes touches your KB proper
without a promote. This walkthrough runs the flow once, end to end, and shows
what each step actually prints.

## Check what's mineable

```bash
mindmeld mine status
```

`--since 72h` narrows to recently-ended sessions, `--project` to one project,
`--json` for machine output. If any swept patterns are sitting below the review
threshold, status says so:

```text
− [mine] 2 pattern(s) below review threshold — mine review --all to see them
```

## Capture the session store

```bash
mindmeld mine archive
```

Sweeps the live session store into a local spool before it ages out of the
harness's own retention window. `--session <id>` archives exactly one. Output:

```text
✓ [mine] archive claudecode: 14 scanned, 3 archived (1.2 MB), 11 current
✓ [mine] archive: committed sweep receipt (mymachine, 3 sessions)
```

## Run the extractor

```bash
mindmeld mine run
```

`--session`, `--project`, `--limit N`, `--force` (re-mine sessions the ledger
already marks done), `--extractor auto|local|agent`. Which extractor runs
depends on config: `local` finishes in-process against an Ollama-compatible
endpoint; `agent` (or `auto` falling back to it) writes a bundle directory per
session and stops there — extraction isn't finished yet.

```text
✓ [mine] extractor local (gemma3:4b) at http://localhost:11434
✓ [mine] bundle a1b2c3d4 → mining/a1b2c3d4-… (23 turns)
✓ [mine] land 2026-08-18-retry-backoff-shape (5 anchors, local/gemma3:4b)
```

If the local endpoint isn't reachable:

```text
− [mine] extractor local unreachable at http://localhost:11434 — falling back to agent
✓ [mine] extractor agent — bundles written, run the review ritual to extract
```

## Finish agent-extracted bundles

Each bundle directory holds `transcript.md` and a generated `BRIEF.md` — but no
`candidates.json` yet. The `mine-review` skill fans out one sub-agent per
bundle, has it read `BRIEF.md` and `transcript.md`, write `candidates.json`
(a bare JSON array — empty is a complete, correct answer), then land it:

```bash
mindmeld mine land --bundle <dir>
# or, to sweep every pending bundle under the work root:
mindmeld mine land --all
```

## What "gated" and "empty" mean

Two outcomes a run can report besides landing something:

- **gated** — the draft failed the admission bar (not enough concrete anchors,
  or for a pattern candidate, an incomplete manifest) before it was ever
  written:
  ```text
  − [mine] gate a1b2c3d4: only 2 anchor(s) found, need at least 4
  ```
- **empty** — the extractor found nothing worth keeping in that session. A real
  outcome, not a failure:
  ```text
  − [mine] empty a1b2c3d4: no candidates
  ```

A second sighting of an already-landed finding doesn't gate or duplicate — it
corroborates:

```text
✓ [mine] recur 2026-08-18-retry-backoff-shape ×2 (qmd 0.81, local/gemma3:4b)
```

## Review the queue

```bash
mindmeld mine review
```

```text
2026-08-18-retry-backoff-shape  pattern/general  5 anchors  candidates/2026-08-18-retry-backoff-shape.md
3 pattern(s) below review threshold — mine review --all to see them
```

`--all` shows everything, including swept patterns still below
`[sweep.promotion].review_min`.

## What a candidate file looks like

An example, trimmed:

```markdown
---
title: "Retry with jittered backoff"
type: pattern
domain: general
confidence: low
status: needs-review
maturity: candidate
applies_to: [general]
use_when: "a retried call can pile up against a struggling downstream"
avoid_when: "the call is already idempotent-safe and cheap to hammer"
context_tags: [reliability]
languages: []
mined_from:
  session_id: a1b2c3d4-…
  source: claudecode
  extractor: local
  model: gemma3:4b
  anchors: 5
---

# Retry with jittered backoff
{body extracted from the session, with citations}
```

## Promote or reject

```bash
mindmeld mine promote 2026-08-18-retry-backoff-shape
mindmeld mine reject 2026-08-18-retry-backoff-shape --reason "duplicates an existing pattern"
```

```text
✓ [mine] promote 2026-08-18-retry-backoff-shape → patterns/2026-08-18-retry-backoff-shape.md
✓ [mine] reject 2026-08-18-retry-backoff-shape: duplicates an existing pattern
```

`--reason` is required on reject — it's the only record a rejected candidate
leaves behind. Both are decisions only you make; nothing in this flow promotes
unattended.

## If it didn't go that way

| Symptom | Look here |
|---|---|
| The full review flow, sub-agent fan-out included | [rituals/mine-review.md](../rituals/mine-review.md) |
| Flags, subcommands, config keys | [commands/mine.md](../commands/mine.md) |
| Something else looks broken | [troubleshooting.md](../troubleshooting.md) |

## Related

- [rituals/mine-review.md](../rituals/mine-review.md) — the human-in-the-loop review cycle
- [commands/mine.md](../commands/mine.md) — every subcommand and flag
- [walkthroughs/first-sweep.md](first-sweep.md) — the changeset-driven cousin of this flow
- [config.md](../config.md) — `[mining]` and `[mining.recurrence]` reference
