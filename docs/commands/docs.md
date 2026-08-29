# mindmeld docs

This guide is written to be read three ways: on GitHub, in Obsidian once it's copied
into your KB, and without leaving your terminal. `docs` is the terminal path — the same
pages, rendered styled or raw depending on where they're going, plus the command that
stamps them into your KB so your agent can recall them mid-session.

## Usage

```bash
mindmeld docs [<topic>] [--width N]
mindmeld docs list
mindmeld docs path [<topic>]
mindmeld docs install [--dry-run] [--kb PATH]
```

On a terminal — `--plain` not set, stdout is a TTY, `NO_COLOR` unset — a page renders
styled through glamour, picking a dark or light style to match your terminal's
background unless `GLAMOUR_STYLE` overrides it. Piped output, `--plain`, or `NO_COLOR`
all fall back to raw markdown, byte-for-byte, frontmatter stripped. `--width N` caps the
wrap width for styled rendering (default: min(terminal width, 100)); it's accepted and
ignored on the raw path. Page longer than your terminal? `mindmeld docs concepts | less`
pages it, though piping switches you to the raw-markdown path.

## What it does

With no topic, `mindmeld docs` renders the table of contents. With a topic
(`mindmeld docs rituals/spawn-session`, or just `spawn-session` when the basename is
unique), it renders that page's body with its authoring frontmatter stripped. An unknown
or ambiguous topic exits 1 with a message naming the candidates
(`docs: "x" is ambiguous — did you mean: rituals/x, commands/x`). Reading the guide never
requires a KB or a valid config — only `docs install` does. The same pages render on
GitHub and in Obsidian too, mermaid diagrams included; in a terminal a diagram renders as
its fenced source, with a one-line caption above it saying what it shows.

## docs list

Prints one line per page — `<topic>\t<title>` — in catalog order (Start here,
Walkthroughs, The rituals, Commands, Reference). Output is plain and stable regardless
of TTY, meant to be piped or grepped: `mindmeld docs list | grep sweep`.

## docs path

Prints where the guide lives on disk: the guide's directory in the mindmeld install with
no topic, or one page's resolved path with a topic — useful for opening a page in
`$EDITOR` directly (`$EDITOR "$(mindmeld docs path config)"`).

## docs install

Stamps every page into `{kb}/docs/mindmeld/` — the same step `mindmeld init` and
`mindmeld update` already run, available on demand. This is the mechanism that makes the
guide qmd-recallable and Obsidian-browsable in your KB, not just readable in a terminal.
The destination is fixed at `docs/mindmeld/` under your KB root; it isn't a config key
today. The directory is gitignored by the shipped scaffold — it's machine-local, and each
machine's `init`/`update` stamps its own copy — so if your KB's `.gitignore` predates this,
add `docs/mindmeld/` to it (`mindmeld doctor` tells you when it's missing).

Each installed file carries a frontmatter marker — `mindmeld_managed: true`,
`mindmeld_version`, `mindmeld_source` — ahead of the page's own frontmatter. Per file:

| state | what happens |
|---|---|
| absent | written |
| marker present, content differs | refreshed |
| marker present, content identical | left alone (folded into the closing count) |
| **no marker** (you edited it) | left alone — reported as locally modified |
| marker present, topic no longer shipped | pruned |

A file with no marker is yours: `install` never overwrites it, on this run or any later
one. Delete the file and the next `install` (or `update`) writes the shipped page back
in its place. A page whose topic no longer exists upstream — a command that was removed
— gets pruned automatically as long as it still carries the marker; this is the one place
this command deletes anything, and the marker is what licenses it.

If your KB has forked its lint schema (`mindmeld lint --seed-schema` wrote
`.mindmeld/schema.toml`), that fork won't inherit the shipped schema's `docs` exclusion
automatically — add `"docs"` to `[scope].exclude_dirs` in your fork, or `mindmeld lint`
schema-gates the installed guide pages as if they were KB articles.

## Output

Report lines are tagged `docs` (`dry-run` under `--dry-run`). Per file:
`stamped docs/mindmeld/<rel>`, `refreshed docs/mindmeld/<rel>`,
`pruned docs/mindmeld/<rel> — no longer shipped`, or
`left as-is docs/mindmeld/<rel> — not mindmeld-managed; delete it to receive the shipped
page`. Current pages aren't listed individually — one closing line covers them:
`<n> page(s) current, <n> stamped, <n> refreshed, <n> pruned, <n> left as-is`. A build
that doesn't ship the guide at all warns
`docs not shipped with this install (ring: <root>) — upgrade mindmeld` and, for
`list`/`path`, degrades to an empty listing at exit 0 rather than failing.

## Config it reads

`[kb].root`, for `docs install`'s destination — see
[config.md#kb](../config.md#kb). Reading the guide (`docs`, `docs list`, `docs path`)
needs no KB configuration at all.

## Related
- [mindmeld init](init.md) — runs this same install step once, when your KB is first
  scaffolded
- [mindmeld update](update.md) — re-runs it on every upgrade, keeping the KB copy current
- [mindmeld lint](lint.md) — the schema gate a forked `.mindmeld/schema.toml` needs the
  `docs` exclusion for
