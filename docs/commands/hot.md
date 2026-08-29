# mindmeld hot

Recall shouldn't depend on remembering to ask — the pulse cache is what a new session
sees before you type anything. The hook this replaces used to compute half its own
payload and filter the other half back out, two writers in two languages for one pushed
block. `hot` is the single writer; the hook just reads what it wrote.

## Usage

```bash
mindmeld hot [--kb PATH] [--max-age DURATION]
```

- `--kb PATH` — override the KB root for this run
- `--max-age DURATION` — skip regeneration when the existing cache is younger than this

## What it does

Regenerates `{kb.root}/wiki/_hot.md`: resolves the KB root (`--kb`, else `[kb].root`),
and — unless `--max-age` says the existing cache is fresh enough — collects open work
(`status: active`, at most 6, newest-touched first), recent activity (git-recent within
a 7-day window, at most 5, minus anything already counted as open work), and any
patterns auto-promoted since the last pulse, then writes the rendered block. No KB
resolved degrades to a warn, never an error — a hook must never be able to fail a
session start.

`hooks/kb-pulse.sh` (the SessionStart hook) reads the cache verbatim into every new
session, then triggers `mindmeld hot --max-age 10m` in the background so the next
session sees fresh content without paying the regeneration cost inline. `init` offers
to seed the cache right after scaffolding the KB, so a fresh install has a pulse waiting
instead of generating one on the fly.

## Output

```text
## <kb-name> pulse
Open work (status: active):
- <title> — <path>
Hot threads:
- <title> — <path>
Auto-promoted:
- <path> — <n> changesets
Recall: `qmd query "<question>"` · board: <path> · map: wiki/_index.md
Generated: 2026-08-18 09:00 (mindmeld hot · regenerated at session start)
```

An empty section still renders — "nothing active.", "none in the last 7 days." — never
a placeholder bullet you'd have to filter back out; `Auto-promoted` is the one section
omitted entirely when nothing crossed the threshold. The report line is
`✓ [hot] cache written: N active, N recent (wiki/_hot.md)`, or a warn naming why it
skipped: `− [hot] no KB configured — nothing to do` /
`− [hot] cache is <age> old — skipped (--max-age <duration>)`.

## Config it reads

`[kb].root` — see [config.md#kb](../config.md#kb). Full read/write contract:
[The pulse cache](../config.md#the-pulse-cache-wiki_hotmd).

## Related
- [mindmeld init](init.md) — offers to seed the cache during setup
- [Configuration](../config.md) — the pulse cache's full contract
