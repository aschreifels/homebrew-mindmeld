# internal/hot

## What it is

`internal/hot` is the engine behind `mindmeld hot`, the single writer of
`{kb.root}/wiki/_hot.md` — the session-start pulse cache `hooks/kb-pulse.sh`
pushes into every new session. It replaces a hook that used to compute half
its own payload (an `rg` sweep of the whole KB for `status: active`) and
filter the other half's placeholder bullets — two writers in two languages
for one pushed block. This package is now the one writer; the hook degrades
to a reader that cats the cache and triggers a refresh for next time.

## Design

### Three independent sources, one Doc

`scanActive` walks the KB's content directories for frontmatter
`status: active`, becoming Open work. `gitRecency` runs one
`git log --since=7.days --name-only` pass for Hot threads, deduped and
filtered to paths that still exist on disk (`--name-only` reports deletions
too, and a pulse pointing at a dead link is a broken link in every session
it's pushed into). `collectAutoPromoted` reads the mining ledger for
candidates the auto-promotion threshold moved with no human in the loop — a
third source, since an unattended promotion is neither a frontmatter status
nor a git touch worth conflating with either.

None of the three folds into another's failure path: a missing `git` binary,
a KB that isn't a repository, or an unreadable ledger each warn once and
contribute an empty section, never abort the run. A hook must never be able
to fail a session start over a missing dependency.

### One writer, one cache, one place the caps are enforced

`collect` owns both invariants `Doc.Render` depends on without re-checking: the
caps (`maxOpenWork` = 6, `maxRecent` = 5) and disjointness — a path lives in
at most one section, with Recent excluding everything already claimed by
Open work. `Doc.Render` renders faithfully whatever `Doc` it is handed; the caps
are spent exactly once, at collection, so there is exactly one place a cap
can be enforced, or forgotten.

### The policy directive rides along, not bolted on

`Doc.Policy` is a `*codedocs.Policy` — a pointer, not a value, specifically so
a `nil` policy renders nothing at all: no label, no blank line, no whitespace
change. That is what keeps every pre-policy `Doc` literal in this package's
render tests byte-identical, since appending a `nil` slice is a no-op.
`Doc.Render` calls `Policy.Directive` immediately after the pulse header, before Open
work — an instruction to the agent, not an item in the pulse, so it leads.

## Invariants

- `Doc.Render` never truncates `Doc.OpenWork`/`Doc.Recent` itself — the caps are enforced
  exactly once, inside `collect`.
- A content path appears in at most one of `Doc.OpenWork` or `Doc.Recent`.
- `gitRecency`, the active-status walk, and `collectAutoPromoted` each
  degrade to an empty result plus one warn-level report line rather than
  propagate an error — only a genuine write-path I/O failure fails `Run`.
- A `nil` `Doc.Policy` renders nothing. A non-`nil` `Policy` whose own
  `Policy.Directive` returns `nil` (the harness-native case) is equally inert —
  both are a no-op append, not two different code paths.
- `isContent` is the one predicate gating both the recency scan and the
  active-status scan — there is no second "counts as content" definition
  that could drift from it.
