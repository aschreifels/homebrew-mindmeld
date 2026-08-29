# mindmeld lint

A schema nobody enforces is a suggestion. `lint` is the gate: every entity's frontmatter
checked against a declared schema (data, never a hardcoded Go enum), title/slug
collisions flagged, and `wiki/_index.md` regenerated from what's actually on disk. It's
also what `mindmeld sync` runs between merge and push, so a merge that needs the index
reconciled gets it before anything ships.

## Usage

```bash
mindmeld lint [--changed] [--dry-run] [--kb PATH] [--seed-schema] [paths...]
```

- `--changed` — gate only files git reports as modified, staged, or untracked
- `--dry-run` — compute and report; write nothing
- `--kb PATH` — override the KB root for this run
- `--seed-schema` — write the embedded default schema to `.mindmeld/schema.toml` and exit
- `paths...` — explicit files instead of the full scope walk

`--seed-schema` cannot combine with `--changed` or explicit paths; `--changed` cannot
combine with explicit paths — each is its own scope, not a filter stack you compose.

## What it does

1. Resolves the KB root (`--kb`, else `[kb].root`) — none configured is a hard error, a
   gate with no KB to gate.
2. `--seed-schema` short-circuits here: writes the embedded schema's bytes to
   `.mindmeld/schema.toml` and returns, never combined with a walk.
3. Loads the schema — `{kb.root}/.mindmeld/schema.toml` if present, else the embedded
   default.
4. Walks the KB (minus `[scope].exclude_dirs`/`exclude_names`/`exclude_prefix`) and
   resolves the run's scope: explicit paths win, else `--changed`'s git-reported set,
   else everything. `--changed` outside a git repository falls back to the full KB with
   a warn, rather than silently validating nothing.
5. Validates every in-scope file's frontmatter against the resolved schema.
6. Flags title/slug duplicates across the full walk — never just the changed subset,
   even when the run itself is scoped.
7. Reconciles `wiki/_index.md` by full regeneration, also from the full walk.

## The schema, as data

`.mindmeld/schema.toml` ships embedded in the binary and is what `lint` validates
against until you seed your own copy. The shipped default declares:

- `[types]` — the 8 values `type:` may take: `decision`, `pattern`, `person`, `project`,
  `research`, `solution`, `tool`, `ticket`.
- `[required]` — fields every entity needs regardless of type: `title`, `type`,
  `created`, `updated`, `domain`, `confidence`, `tags`, `related`, `sources`.
- `[enums]` — cross-type allowed values: `domain`, `confidence`, `authority`.
- `[type.<name>]` — per-type extra required fields and enums (`project` needs
  `status`/`stack`, `tool` needs `url`/`verdict`, and so on).
- `[[discriminator]]` — a variant selected by a field *value* rather than by `type:` — a
  voice-corpus day-log is `type: person` plus `voice: corpus`, and relaxes most of the
  article shape it can't supply yet.
- `[scope]` — `exclude_dirs`, `exclude_names`, `exclude_prefix`, `index_exclude_dirs`:
  which files the gate reads, and which of those the index carries — two different
  questions. `docs` (the guide `mindmeld docs install` stamps in) sits in `exclude_dirs`
  alongside `raw`, `output`, `templates`, and `skills` — engine-placed content, not a
  KB article.

Run `mindmeld lint --seed-schema` to write this file to `{kb.root}/.mindmeld/schema.toml`.
The moment it exists, your KB has forked its schema off the shipped default — you own it
from there, and a future mindmeld release that changes the shipped file won't reach a KB
that has seeded its own copy. A fork doesn't inherit new exclusions automatically either:
if `docs` is ever added to the shipped `[scope].exclude_dirs` after you've forked, your
copy needs the same line by hand, or `lint` schema-gates the installed guide pages as if
they were KB articles.

## Output

| Line | Meaning |
|---|---|
| `✓ [lint] N files in scope (N changed)` | the run's scope, restricted by `--changed`/paths |
| `✓ [lint] N files in scope` | a full-KB run, no restriction |
| `− [lint] not a git repository — linting the full KB instead of --changed` | `--changed` fell back to a full run rather than silently validating nothing |
| `✗ [schema] path: invalid type: 'x'` | `type:` isn't one of `[types].enum` |
| `✗ [schema] path: missing required fields: a, b` | the union of `[required].all` and the matched type/discriminator rule |
| `✗ [schema] path: frontmatter missing or malformed` | one finding, not N |
| `✗ [dupes] duplicate title 'X': path-a, path-b` | two files claim the same title |
| `✓ [index] wiki/_index.md regenerated (N entries)` / `... already current` | the index write outcome |
| `✓ [schema] seeded .mindmeld/schema.toml` / `− ... already exists — left untouched` | `--seed-schema`'s outcome |

## Config it reads

`[kb].root` — see [config.md#kb](../config.md#kb). Everything else the gate reads lives
in `.mindmeld/schema.toml`, not `mindmeld.toml` — it's KB-shaped (true of the person, not
the machine), not config-shaped.

## Related
- [mindmeld init](init.md) — scaffolds the KB `lint` validates
- [mindmeld sync](sync.md) — runs this same reconcile step between merge and push
- [mindmeld docs](docs.md) — the organ whose `exclude_dirs` entry a forked schema needs
  to keep
- [Configuration](../config.md) — the config-vs-KB delineation this schema file follows
