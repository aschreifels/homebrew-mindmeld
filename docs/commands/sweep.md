# mindmeld sweep

A session transcript isn't the only place a reusable pattern shows up — sometimes it's
sitting in the diff itself. `sweep` resolves a git changeset into a bundle a sweep agent
can read, then lands whatever it finds through the same gate and ledger `mine` uses.
It's a producer of pattern candidates, not a second review path: everything it lands
still goes through `mine review`.

## Usage

```bash
mindmeld sweep [--dry-run] <subcommand> [flags]

mindmeld sweep bundle [--base REF] [--head REF] [--repo DIR] [--json]
mindmeld sweep land --bundle DIR [--json]
```

`--dry-run` is persistent on `sweep` itself — the same zero-writes guarantee `mine`
takes, shared under one flag.

## sweep bundle

Resolves `--base...--head` (default: `[defaults].base_branch`, else `"main"`, through
`HEAD`) into a diff, filters it, and writes a bundle directory under
`{kb}/.mindmeld/work/` for a sweep agent to read: a `diff.md`, a generated `BRIEF.md`
scoped to `type: pattern`, and a `ref.json` recovery record. `--repo` targets a worktree
other than the current directory. A diff that's empty after filtering (nothing changed,
or everything changed was filtered) is reported and no bundle is written — that's a
valid, meaningful outcome, not a failure.

The diff is capped at `[sweep].max_diff_bytes` (default 256 KB, roughly 65k tokens) —
past that, a sweep agent skims rather than reads, so the bundle is truncated instead.
The built-in filter drops lockfiles, generated code, vendored trees, build output, and
test snapshots/goldens; `[sweep].ignore` extends that list, it never replaces it. If your
`testdata/` is inert fixtures rather than behavioral specs, add `"**/testdata/**"` to
`[sweep].ignore` locally — the shipped default deliberately doesn't assume that for you.

## sweep land

Reads `--bundle DIR`'s `ref.json` and `candidates.json`, then runs the same
gate → similarity → store → ledger walk `mine land` runs, tagged with extractor `agent`
and model `harness` so a swept candidate's provenance says where it came from.
`candidates.json` missing is reported and skipped, same as `mine land` — extraction
hasn't happened for this bundle yet.

## Output

Report lines are tagged `sweep`. `sweep bundle` reports the file count, how many were
filtered, and whether the diff was truncated (`bundle <sha>: <n> file(s) (<f> filtered)
[truncated], wrote <dir>`); a dry run reports what it would bundle without writing.
`sweep land`'s per-candidate outcomes (landed, gated, recurred, auto-promoted) come from
the shared landing tail and read identically to `mine land`'s.

## Config it reads

`[sweep]` (max_diff_bytes, ignore) and `[sweep.promotion]` (enabled, review_min,
auto_min) — see [config.md#sweep](../config.md#sweep). `[defaults].base_branch` for
`sweep bundle`'s default base ref — see
[config.md#defaults](../config.md#defaults).

## Related
- [mindmeld mine](mine.md) — the gate, store, and ledger every swept candidate lands
  through; `mine review` is where a swept pattern gets promoted or rejected
- [Configuration](../config.md) — the full `[sweep]` key reference, including the
  built-in ignore list
