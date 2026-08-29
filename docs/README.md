# mindmeld guide

mindmeld installs a continuity paradigm — a knowledge base you own, plus the rituals
that keep it fed — into your agent harness. This guide starts with what to run first,
walks a few things end to end, then documents every ritual, command, and config key you'll
actually reach for.

## Start here

- [Getting started](getting-started.md) — Install mindmeld, run init, and open your first session
- [Concepts](concepts.md) — The rings, checkout-as-source-of-truth, and how recall works
- [A day with mindmeld](a-day-with-mindmeld.md) — A narrative walk through a working day, ritual by ritual
- [Your KB, directory by directory](kb-layout.md) — What init scaffolds, who writes each piece, and what update touches

## Walkthroughs

- [Your first session](walkthroughs/first-session.md) — A full spawn → dossier → work → review → wrap cycle, with what you'll actually see at each step.
- [Your first mining run](walkthroughs/first-mining-run.md) — mine status → archive → run → land → review → promote, with the report lines and what a candidate looks like.
- [Your first sweep](walkthroughs/first-sweep.md) — sweep bundle → sweep land over a real changeset, and the review_min/auto_min thresholds that gate promotion.
- [What the articles look like](walkthroughs/example-articles.md) — Annotated pattern, decision, solution, and ticket examples — every field explained, and how recall finds each one.

## The rituals

- [spawn-session](rituals/spawn-session.md) — Opens a coding session: worktree, branch, ticket context, and a plan dossier you sign off on before code exists.
- [wrap-session](rituals/wrap-session.md) — Closes a coding session: safety checks, ticket finalize, KB harvest, voice capture, worktree teardown.
- [kb-ticket](rituals/kb-ticket.md) — Manages tickets as markdown files in your KB — no tracker, no MCP connector, just git.
- [pr-review](rituals/pr-review.md) — Human-in-the-loop code review — PR or self-review mode, findings by severity, nothing posted or applied without confirmation.
- [voice-distill](rituals/voice-distill.md) — Compress the day-log voice corpus into the curated voice.md loaded every session.
- [mine-review](rituals/mine-review.md) — Drive mindmeld mine end to end — survey, mine, then walk the review queue and decide.

## Commands

- [mindmeld init](commands/init.md) — Set up mindmeld for this KB and checkout — config, KB scaffold, index, host wiring, one pass
- [mindmeld doctor](commands/doctor.md) — Check that mindmeld is correctly installed — ownership, not mere existence
- [mindmeld update](commands/update.md) — Bring the mind current: pull the checkout, reinstall organs, refresh the guide
- [mindmeld hot](commands/hot.md) — Regenerate the session-start pulse cache
- [mindmeld lint](commands/lint.md) — Validate the KB's frontmatter against a schema, and reconcile the index
- [mindmeld mine](commands/mine.md) — Turn agent sessions into candidate KB drafts, gated on specificity
- [mindmeld sweep](commands/sweep.md) — Turn a git changeset into pattern candidates for review
- [mindmeld sync](commands/sync.md) — Pull, reconcile, and push your KB against its git remote
- [mindmeld host](commands/host.md) — Print this machine's stable identity
- [mindmeld docs](commands/docs.md) — Read the mindmeld guide from your terminal or your KB

## Reference

- [Configuration](config.md) — Every mindmeld.toml key — what it does, who reads it, and its default
- [Troubleshooting](troubleshooting.md) — Symptom, cause, and fix for every warn or fail mindmeld doctor reports

## Reading this in the terminal

Everything above also renders without leaving your terminal: `mindmeld docs` prints the
table of contents, `mindmeld docs <topic>` renders one page (`mindmeld docs
rituals/spawn-session`, or just `mindmeld docs spawn-session` when the basename is
unique). The same pages live in your KB at `docs/mindmeld/`, once `mindmeld init` or
`mindmeld docs install` has stamped them there — that copy is what makes the guide
qmd-recallable and Obsidian-browsable alongside the rest of your KB.
