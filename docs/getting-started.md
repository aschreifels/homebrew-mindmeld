# Getting started

You're adopting a continuity paradigm: a knowledge base you own, plus the
rituals that keep it fed. mindmeld is the engine half of that pairing — it
installs the rituals into your agent harness and does the jobs the KB needs
done, so the KB itself stays a plain-markdown git repo you could read with
`cat` if every tool you own vanished tomorrow. This page gets you from
install to your first session.

## Prerequisites

`mindmeld init` needs these on your machine — and it guides you through
installing any that are missing, stopping if you decline:

- `git` — the KB's history lives here; there's no version of this without it.
- `rg` (ripgrep) — the session skills grep the KB through it.
- `yq` — `init` and `doctor` read and stamp `mindmeld.toml` with it.
- `qmd` — recall (the pulse digest and on-demand search) has no engine
  without it.

Obsidian is recommended, not required — the `.base` boards and wikilink
exploration are built for it, but skip it and the KB is still a working git
repo you can read with any markdown tool.

## Install

```bash
brew tap aschreifels/mindmeld     # your invite names the tap owner
brew install mindmeld
mindmeld init
```

The installed engine (a Homebrew keg's `libexec`) is the source of truth:
skills install as symlinks back into it, not copies, so there's no separate
updater to install. To upgrade: `brew upgrade mindmeld` bumps the engine,
then `mindmeld update` reinstalls the adapter, re-stamps this guide into
your KB, and syncs the seed-tracked boards and templates — skills are
symlinks into the install, so `update` is what brings the guide, boards,
and templates current, not the brew step alone. If you're working from a
source checkout instead, `init` wires it up the same way, just without the
tap.

## What `init` just did

`init` is one pass, and every step is idempotent — re-running it on an
already-set-up machine is a no-op walk:

- stamped `mindmeld.toml` at `~/.config/ai/` (never overwrites one that
  already exists without asking)
- scaffolded your KB at the configured root — filling in only what's
  missing, including an empty instance ring at `{kb}/skills/`
- stamped this guide into your KB at `docs/mindmeld/` — engine-managed,
  refreshed by `mindmeld update`
- offered to seed the session-start pulse cache, so your first session has
  one waiting instead of generating it on the fly
- built the search index (`qmd collection add` + `qmd embed`), plus the two
  scoped collections the mining lane queries — `candidates/` and
  `patterns/` — both excluded from default recall so they don't duplicate
  hits the KB-root collection already returns
- symlinked the session skills and the pulse hook into your harness's
  skills/hooks dirs, and added one `SessionStart` hook entry to its settings
  (backing the file up first)

The closing block ends with `Next: mindmeld doctor`, then `Then: mindmeld
docs getting-started` — which is how you got here if you followed it. `doctor`
is a read-only health check that classifies your install rather than just
testing that files exist:

```bash
mindmeld doctor
```

See [mindmeld init](commands/init.md) for every flag and
[mindmeld doctor](commands/doctor.md) for what each check means.

## Reading the guide

You're reading it right now, and there are three ways back to it. In your
terminal, `mindmeld docs` prints the table of contents and `mindmeld docs
<topic>` prints one page (`mindmeld docs getting-started` is this one). The
copy `init` just stamped into your KB at `docs/mindmeld/` is engine-managed
and kept current by `mindmeld update` — open it in Obsidian, or let your
agent recall it like any other KB content. Or read it straight from this
checkout's `docs/`. See [mindmeld docs](commands/docs.md) for the full
command.

## Your first session

When the session opens, the pulse hook has already injected your KB's
digest — open work and recent activity — before you type anything. Run
`/spawn-session <feature> [TICKET] [--draft] …` (or in plain words, "spawn
a session for <thing>"). You'll see a feature branch cut, a ticket resolved
or drafted, and a plan dossier built under `_plan/`. Then it pauses: chat
gets a digest of what's being built, a chunk map table, and any open
questions for you to answer before execution starts — the dossier itself
is canonical, chat is just the summary. Work through the session as
normal, then run `/wrap-session` to close it down: safety checks, ticket
finalization, and worktree cleanup.

See [spawn-session](rituals/spawn-session.md) and
[wrap-session](rituals/wrap-session.md) for the full shape of each.

## Related

- [Your first session](walkthroughs/first-session.md) — see a whole session
  end to end before you run one.
- [Concepts](concepts.md) — the rings, the install as source of truth, and
  how recall works.
- [A day with mindmeld](a-day-with-mindmeld.md) — a narrative walk through
  a full day.
- [Your KB, directory by directory](kb-layout.md) — what every directory in
  your KB is for.
- [Configuration](config.md) — the full `mindmeld.toml` schema.
