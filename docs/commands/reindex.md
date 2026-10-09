# mindmeld reindex

qmd's index is one sqlite file per machine, and every qmd invocation opens it as a
writer — two concurrent reindexes destroy each other, and a query started inside one
dies on `SQLITE_BUSY`. Before this command existed the "update then embed" sequence was
written three times: once inside the qmd similarity adapter's own reindex, once
unlocked inside `init`'s index step, and once more in prose in every ritual's landing
pass — and only one of the three ever took the lock at all. `reindex` is the one place
this now happens; every other caller becomes a caller of it instead of a reimplementer.
Both the sequence and its serialization live behind the index port
(`internal/index`) now: this command drives `Update` then `Embed`, and the qmd-backed
adapter behind that port is what actually resolves the machine-global lock and takes
it — this command never touches a lock file itself.

## Usage

```bash
mindmeld reindex [--collection NAME]... [--no-embed] [--timeout DURATION] [--no-wait] [--dry-run]
```

- `--collection NAME` — scope the embed pass to this qmd collection (repeatable); omitted
  runs one global `qmd embed` instead of zero — the two are different operations, not a
  default and an override
- `--no-embed` — run `qmd update` only, skip the embed pass entirely
- `--timeout DURATION` — ceiling for the whole reindex, including the wait for the
  exclusive lock and the work it protects — one shared budget, not two; default
  `[reindex].timeout`, else `10m`
- `--no-wait` — try the lock once and skip immediately if it's held, instead of waiting —
  the posture a session-start hook needs
- `--dry-run` — preview without acquiring the lock or running anything

## What it does

An unresolvable qmd lock identity (a `$HOME`/`$XDG_CACHE_HOME` that can't be
determined) fails this command outright — its whole job is an exclusive mutation of
the shared index, so there is no safe degraded mode to fall back to. Otherwise it runs
`qmd update`, then — unless `--no-embed` — one `qmd embed` per `--collection`, or one
global `qmd embed` when none were given, each serialized against every other mindmeld
process sharing the machine's index by the adapter behind the index port. `--no-wait`
asks for one non-blocking attempt per call rather than waiting; a missing `qmd`
dependency and lock contention both skip rather than fail. A failed `qmd update` does
not abort the embed pass: each command is independent, and each failure gets its own
report line.

A contended skip is not a failure — the command exits 0 either way, which is what lets
`hooks/kb-pulse.sh` call `reindex --no-wait --no-embed` on every session start without
risking a nonzero exit blocking anything.

## Output

```text
✓ [reindex] qmd index updated
✓ [reindex] qmd embed complete
✗ [reindex] qmd embed foo failed: index/qmd: embed -c foo: exit status 1 (SqliteError: database is locked)
− [reindex] reindex skipped: another mindmeld holds the qmd lock
− [reindex] qmd not found — nothing to reindex
```

`--dry-run` prints what it would have run under the `dry-run` step tag and touches
nothing, including the lock:

```text
✓ [dry-run] would run: qmd update
✓ [dry-run] would run: qmd embed
```

## Config it reads

`[reindex]` — see [config.md#reindex](../config.md#reindex).

## Related
- [Configuration](../config.md) — the `[reindex]` table's full contract
