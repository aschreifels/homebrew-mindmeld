# mindmeld codedocs

A doc that stops matching the code it describes is worse than no doc — it's a wrong
answer with the confidence of a right one. `codedocs check` is the gate: it walks a
repo's own `docs/internals/` tree against its source and flags six kinds of drift, from
"this module has no doc" to "this doc cites a symbol that no longer exists."

Unlike `mindmeld lint`, this gate has nothing to do with your KB. It reads its whole
configuration from the repo it's checking — `docs/internals/_index.md`'s frontmatter —
so a contributor who clones a repo with no KB and no `mindmeld.toml` runs exactly the
gate its maintainer configured.

## Usage

```bash
mindmeld codedocs check [--root DIR] [--enforce | --no-enforce] [--fix] [paths...]
```

## codedocs check

Walks `--root` (default: resolved from the current directory via `git rev-parse
--show-toplevel`) and runs D1-D6 against it.

- `--root DIR` — repo root to check
- `--enforce` / `--no-enforce` — override `_index.md`'s own `enforce` key for this run;
  mutually exclusive
- `--fix` — reserved for a future session; currently returns an error rather than
  silently doing nothing
- `paths...` — restrict the per-module checks (D1, D6) to these modules or their
  subtrees; the whole-tree checks (D2, D3, D4, D5) always run in full regardless, the
  same way `mindmeld lint --changed` still reconciles the full index

## What it checks

| id | check | severity |
|---|---|---|
| D1 | every module under `roots` has a doc, or a declared exemption | fail |
| D2 | every `docs/internals/*.md` names a module (and cites modules) that exist | fail |
| D3 | `_index.md` and the actual file set agree — neither may lead the other | fail |
| D4 | every backticked symbol a doc cites exists in the module it declares | fail |
| D5 | no source comment block exceeds the derived ceiling | fail (off when the ceiling is off) |
| D6 | every documented (or covered) module's entry point carries its `// Docs:` pointer | fail |

A "module" is a directory under one of `roots` holding at least one recognized source
file directly in it — not in a child. A directory whose source lives only in its
children (a namespace, not a module) is invisible to D1 and D6; its children carry the
rows.

## `_index.md` is the only config source

Everything this gate needs lives in `docs/internals/_index.md`'s frontmatter, never in
`mindmeld.toml`:

```yaml
---
roots: [internal, cmd]
placement: split       # inline | repo-docs | split
verbosity: regular     # terse | regular | verbose
max_comment_lines: 8   # optional — overrides the derived D5 ceiling
enforce: true           # absent ⇒ true
---
```

`docs/internals/_index.md` **absent** means the gate is off entirely for this repo — one
info line, a clean exit, never a failed build for a repo that hasn't adopted this yet.
`placement`/`verbosity` here answer "what does this repo's own gate enforce" — a
different question from the KB-sourced person policy (`mindmeld hot`'s pulse) that
answers "how should the agent write new code." They share a vocabulary; they are read
from different files, on purpose, so a contributor with no KB still gets the gate their
maintainer actually configured.

D5's ceiling derives from `verbosity` — `terse` 4 lines, `regular` 8, `verbose` off —
with `max_comment_lines` as an optional explicit override. `placement: inline` turns D5
off unconditionally: a long comment block is exactly what that placement is asking for.
D5 inspects source comments only; it never reads a file under `docs/`.

The frontmatter also carries roll-up declarations as two required tables in
the body — `## Documented` (`Module | Doc | Also covers`) and `## Exempt`
(`Module | Why`) — even when a table has no rows yet (header and separator only). A
changed column header is a parse failure, not a skipped row.

## Output

Every finding renders as `✗ [D<n>] path[:line]: message`, sorted by check id, then path,
then line — deterministic, because scripts and CI grep this output. `--enforce`/
`--no-enforce` and `_index.md`'s own `enforce` key change only whether a run with
findings exits non-zero; they never change what gets reported.

## Related

- [mindmeld lint](lint.md) — the sibling gate, for the KB rather than a repo's own
  source tree
- [mindmeld hot](hot.md) — renders the KB-sourced person policy this gate deliberately
  does not read
