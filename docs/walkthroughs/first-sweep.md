# Your first sweep

`sweep` looks at a git changeset — not a chat session — for the idioms a reviewer
would say "we always do it this way" about. It's scoped to `type: pattern`
candidates only, and it lands them through the same gate/store/ledger tail
`mine land` uses, so the two flows read identically once a candidate is written.

## Bundle the changeset

```bash
mindmeld sweep bundle --repo <path> --base main
```

`--base` (default: your configured base branch, else `main`), `--head` (default
`HEAD`), `--repo` (default: cwd), `--json`. A diff with nothing left after
filtering is a valid, meaningful outcome, not an error:

```text
− [sweep] nothing to sweep: main...HEAD is empty
```

Otherwise:

```text
✓ [sweep] bundle a1b2c3d4e5f6: 7 file(s) (2 filtered), wrote <kb>/.mindmeld/work/sweep/a1b2c3d4e5f6
```

`(N filtered)` appears when the built-in ignore list caught something —
lockfiles, generated code, vendored code, build output, test fixtures/goldens.
One thing that list deliberately leaves alone: `**/testdata/**` is not in it,
because in this repo `tests/integration/testdata/*.txtar` holds the behavioral
specs and is among the most pattern-dense material in the tree. Whether that
holds for your repo is a local call — add `"**/testdata/**"` to `[sweep]
ignore` if your testdata really is inert fixtures.

## Extract via a sub-agent

The bundle directory holds `diff.md`, a generated `BRIEF.md`, and `ref.json`.
`BRIEF.md` is generated from the same manifest checklist `PatternGate`
enforces — the sub-agent that reads it writes `candidates.json` (a bare array;
empty is a complete, correct answer when nothing in the diff is a pattern).

## Land the bundle

```bash
mindmeld sweep land --bundle <kb>/.mindmeld/work/sweep/a1b2c3d4e5f6
```

`--bundle` is required, plus `--json`. Landing reuses `mine land`'s own tail, so
the lines you see carry the `[mine]` tag, not `[sweep]`:

```text
✓ [mine] land 2026-08-18-retry-with-context-cancel (6 anchors, agent/harness)
```

If the manifest is incomplete, it gates the same way an anchor-short session
draft does:

```text
− [mine] gate a1b2c3d4: manifest use_when is blank
```

If `candidates.json` isn't there yet — the sub-agent step above hasn't run:

```text
− [mine] a1b2c3d4: candidates.json not found — still pending extraction
```

## Promotion thresholds in action

A repeat sighting of the same pattern across changesets corroborates rather
than duplicates:

```text
✓ [mine] recur 2026-08-18-retry-with-context-cancel ×3 (qmd 0.77, agent/harness)
```

`[sweep.promotion]` governs what happens next: `review_min` (default `3`) is
the recurrence count before `mine review` surfaces the pattern by default —
below it, the pattern is still landed with full provenance, just left off the
default listing (`mine status` reports the held-back count, so it's never
lost, only quieter). `auto_min` (default `5`) is the count that promotes a
swept pattern unattended, with `promotion.enabled` as the human-only override
— `false` disables auto-promotion entirely, and the review queue stays
human-only. `review_min > auto_min` is refused at config load; a machine
promoting something a human was never offered for review is the one ordering
this feature must never produce.

At the auto threshold:

```text
✓ [mine] auto-promoted 2026-08-18-retry-with-context-cancel — 5 changesets
```

Only a `type: pattern` candidate landed from a changeset (never a mined
session) is eligible for auto-promotion — a recurring finding mined from chat
history still waits for you at `mine review`.

## What a swept pattern candidate looks like

An example, trimmed — the manifest fields `PatternGate` requires:

```markdown
---
title: "Context-cancel on retry"
type: pattern
domain: general
confidence: low
status: needs-review
maturity: candidate
applies_to: [go]
use_when: "a retry loop wraps a call that accepts a context"
avoid_when: "the call has no cancellation path"
context_tags: [reliability]
languages: [go]
source_exemplar: "internal/mining/miner_run.go @ a1b2c3d"
mined_from:
  source: harness
  extractor: agent
  anchors: 6
---

# Context-cancel on retry
{body extracted from the diff, with citations}
```

## If it didn't go that way

| Symptom | Look here |
|---|---|
| Bundle/land flags, `[sweep]` config keys | [commands/sweep.md](../commands/sweep.md) |
| Wrap-session's own pattern sweep (Phase 4b) | [rituals/wrap-session.md](../rituals/wrap-session.md) |
| Landed but not surfacing in review | [walkthroughs/first-mining-run.md](first-mining-run.md) |
| Something else looks broken | [troubleshooting.md](../troubleshooting.md) |

## Related

- [commands/sweep.md](../commands/sweep.md) — every subcommand and flag
- [walkthroughs/first-mining-run.md](first-mining-run.md) — the session-driven cousin of this flow
- [config.md](../config.md) — `[sweep]` and `[sweep.promotion]` reference
- [rituals/wrap-session.md](../rituals/wrap-session.md) — where a sweep usually gets triggered
