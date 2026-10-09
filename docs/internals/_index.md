# Module docs

This is the map `internal/codedocs`'s D1/D3 checks read: every module under
`internal/` and `cmd/` is either documented here (with its own page, or rolled up
into a covering one) or declared exempt, with a reason. A module in neither table
is what D1 exists to catch.

The frontmatter above is this repo's own gate configuration, not a person's
writing preference — `internal/codedocs`'s `Run` reads `roots`, `placement`, and
`verbosity` from here directly, never from a KB, so a contributor with no KB
checked out still gets the gate their maintainer configured. `placement: inline`
and `verbosity: verbose` describe this repo's actual, current state: reasoning
still lives at the symbol, and D5 is off under both conditions independently
(inline placement, and verbose verbosity) — restating both is deliberate, not
redundant, since either one flips before the other.

`enforce: false` is temporary, not a default this repo endorses: see the
frontmatter comment above. Until the migration chunk that flips it lands, running
`mindmeld codedocs check` here reports findings without failing the build.

## Documented

| Module | Doc | Also covers |
|---|---|---|
| `internal/chunk` | `chunk.md` | |
| `internal/codedocs` | `codedocs.md` | |
| `internal/hot` | `hot.md` | |
| `internal/ritual` | `ritual.md` | |

## Exempt

| Module | Why |
|---|---|
| `cmd/mindmeld` | not yet migrated — MIN-38 migration |
| `internal/assets` | not yet migrated — MIN-38 migration |
| `internal/buildinfo` | not yet migrated — MIN-38 migration |
| `internal/config` | not yet migrated — MIN-38 migration |
| `internal/docs` | not yet migrated — MIN-38 migration |
| `internal/doctor` | not yet migrated — MIN-38 migration |
| `internal/dossiermove` | not yet migrated — new leaf package (MIN-62), landed after this table |
| `internal/dossierroot` | not yet migrated — new leaf package (MIN-62), landed after this table |
| `internal/flock` | not yet migrated — new leaf package (MIN-65), landed after this table |
| `internal/frontmatter` | not yet migrated — MIN-38 migration |
| `internal/host` | not yet migrated — MIN-38 migration |
| `internal/index` | not yet migrated — new organ slot (MIN-58), landed after this table |
| `internal/index/qmd` | not yet migrated — new organ slot (MIN-58), landed after this table |
| `internal/initrun` | not yet migrated — MIN-38 migration |
| `internal/kbpath` | not yet migrated — new leaf package (MIN-65), landed after this table |
| `internal/lint` | not yet migrated — MIN-38 migration |
| `internal/mcp` | not yet migrated — MIN-38 migration |
| `internal/mining` | not yet migrated — MIN-38 migration |
| `internal/mining/extract/agent` | not yet migrated — MIN-38 migration |
| `internal/mining/extract/local` | not yet migrated — MIN-38 migration |
| `internal/mining/similar/qmd` | not yet migrated — MIN-38 migration |
| `internal/mining/source/archive` | not yet migrated — MIN-38 migration |
| `internal/mining/source/claudecode` | not yet migrated — MIN-38 migration |
| `internal/mining/sweep` | not yet migrated — MIN-38 migration |
| `internal/qmdlock` | not yet migrated — MIN-38 migration |
| `internal/recall` | not yet migrated — MIN-38 migration |
| `internal/reindex` | not yet migrated — MIN-38 migration |
| `internal/report` | not yet migrated — MIN-38 migration |
| `internal/store` | not yet migrated — new organ slot (MIN-58), landed after this table |
| `internal/store/fs` | not yet migrated — new organ slot (MIN-58), landed after this table |
| `internal/sync` | not yet migrated — MIN-38 migration |
| `internal/ticket` | not yet migrated — MIN-38 migration |
| `internal/tui` | not yet migrated — MIN-38 migration |
| `internal/update` | not yet migrated — MIN-38 migration |
