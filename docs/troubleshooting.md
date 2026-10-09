# Troubleshooting

`mindmeld doctor` is the diagnostic entry point — every row below is a line it can print,
paired with what caused it and the command that clears it. Run `mindmeld doctor --plain`,
find the line, jump to the row.

Repairs read `mindmeld update` throughout because that's what `doctor` names once an
instance exists (a config that loads and a KB root that validates). Before then the same
lines say `mindmeld init` — the one command that can create the instance in the first place.

## Symptom → cause → fix

| Symptom | Cause | Fix |
| --- | --- | --- |
| `✗ [doctor] config missing or does not parse (<path>) — run 'mindmeld init'` | No `mindmeld.toml` (or legacy `spawn.toml`) at `$XDG_CONFIG_HOME/ai` or `~/.config/ai`, or the file fails to parse | `mindmeld init` |
| `✓ [doctor] no mindmeld.toml — running on MINDMELD_KB (<root>)` | Not a problem: no config file, but `MINDMELD_KB` names the KB root, which is a valid way to run. `update` works on it; only `init` would write a `mindmeld.toml` | none — informational |
| `✗ [doctor] kb root missing or unset — run 'mindmeld init'` | `[kb].root` is unset, or the directory it points at doesn't exist. `mindmeld update` reports the same condition as `− [update] kb root <path> does not exist — skipped the KB steps; run 'mindmeld init'` and skips every KB step, so it never stands up a fresh KB that `init` would then refuse to clone over | `mindmeld init` |
| `✗ [doctor] qmd missing — npm i -g @tobilu/qmd`, or `✗ [doctor] qmd collection check skipped (qmd missing)` | `qmd` isn't on `PATH` — `init`'s index step fails outright without it, and `update` warns and skips collection registration | `npm i -g @tobilu/qmd`, then `mindmeld update` (`mindmeld init` on a machine with no instance yet) |
| `− [doctor] skill <name> linked outside the checkout (<target>) — run 'mindmeld update'` | Another sync system's symlink got to `~/.claude/skills/<name>` first | `mindmeld update` |
| `− [doctor] skill <name> installed as a real path, not linked to the checkout — run 'mindmeld update' (or 'mindmeld update --copy' for a copy install)` | A `--copy` install (a supported posture), or a foreign writer clobbered the symlink | `mindmeld update` — or `mindmeld update --copy` if you installed with `--copy` originally, see [mindmeld update](commands/update.md) |
| `✗ [doctor] skill <name> missing or dangling — run 'mindmeld update'` | Nothing installed at that path, or the symlink's target is gone | `mindmeld update` |
| `− [doctor] hook kb-pulse.sh linked outside the checkout (<target>) — run 'mindmeld update'`, `− [doctor] hook kb-pulse.sh installed as a real path, not linked to the checkout — run 'mindmeld update' (or 'mindmeld update --copy' for a copy install)`, or `✗ [doctor] hook kb-pulse.sh missing or dangling — run 'mindmeld update'` | Same ownership drift as a skill, but for the SessionStart hook script | `mindmeld update` (or `update --copy`, as for a skill) |
| `✗ [doctor] settings.json SessionStart hook not wired — run 'mindmeld update'` | The hook entry is missing from `~/.claude/settings.json`, and `[install].hooks` is `auto` (or unset), so mindmeld was meant to write it | `mindmeld update` |
| `− [doctor] settings.json SessionStart hook not wired — wire the SessionStart hook by hand — 'mindmeld update' prints the snippet in print mode` | `[install].hooks = "print"`: mindmeld never writes `settings.json` in this mode, so the warn is the configured state until you paste the snippet (see [Configuration](config.md#install)) | Run `mindmeld update` (`mindmeld init` before the first install, and the line says so), copy the snippet it prints into `~/.claude/settings.json` |
| `− [doctor] settings.json SessionStart hook not wired` | `[install].hooks = "off"`: you opted out of the write. A warn with no repair, on purpose | none — or set `[install].hooks = "auto"` and run `mindmeld update` |
| `✗ [doctor] adapter "<name>" is not supported — no organs installed — set [install].adapter in mindmeld.toml to a supported adapter` | `[install].adapter` names something other than `claude-code` — usually a typo. Only one adapter ships today (see [Adapters](adapters.md)), so this always means the whole install step was skipped and nothing got wired. Reinstalling can't fix a name that resolves to nothing | Fix or remove the `[install].adapter` key in `mindmeld.toml`, then `mindmeld update` |
| `− [doctor] AGENTS.md present, CLAUDE.md shim missing — run 'mindmeld update'` | The KB has its harness-neutral instructions file, but the adapter hasn't generated the `CLAUDE.md` bridge on this machine yet — typically a KB cloned here before the adapter install ran | `mindmeld update` |
| `− [doctor] CLAUDE.md is not the generated shim — left alone` | `CLAUDE.md` exists but its body isn't the two-line `@AGENTS.md` shim the adapter would generate — either you replaced it with real content, or it couldn't be read. No repair, on purpose: an adopter who takes over a generated file is exercising a right, not causing drift | none — informational only |
| `− [doctor] legacy CLAUDE.md at the KB root, no AGENTS.md — follow 'Migrating a pre-split KB' in <kb>/docs/mindmeld/troubleshooting.md` | A KB scaffolded before the neutral instructions file existed — its instructions still live at the harness-branded `CLAUDE.md`, and nothing has moved them since. The KB still works under this harness; it's lost portability, not function. `init` and `update` leave it alone rather than stamping a second, inert instruction file beside it. The path is the stamped copy of this page; a KB with no guide stamped yet reads `in the troubleshooting guide` instead | [Migrating a pre-split KB](#migrating-a-pre-split-kb) below — a manual step, since neither command rewrites instance content on your behalf |
| `✗ [doctor] no instruction file at the KB root — run 'mindmeld update'` | Neither `AGENTS.md` nor `CLAUDE.md` exists at `{kb.root}` — a file the scaffold hasn't written yet, or one whose instructions file was deleted | `mindmeld update` |
| Pulse cache looks stale, or a new session opens with no context | `wiki/_hot.md` is derived-local — absent on a fresh clone, or stale because nothing has regenerated it since the last close | `mindmeld hot` |
| `− [doctor] <kb>/.mindmeld/schema.toml does not exclude "docs" from [scope].exclude_dirs — mindmeld lint will gate the guide pages; add "docs" to that list` | Your KB forked its schema (`{kb}/.mindmeld/schema.toml` exists) before the shipped schema excluded `docs` | Add `"docs"` to `[scope].exclude_dirs` in `{kb}/.mindmeld/schema.toml` |
| `− [doctor] docs missing from <dir> (N of M) — run 'mindmeld update'` | Catalog pages were never stamped into `{kb}/docs/mindmeld/` | `mindmeld update` (or `mindmeld docs install` — same step) |
| `− [doctor] docs stale in <dir> (N page(s) stamped <old>, running <new>) — run 'mindmeld update'` | Stamped pages carry an older `mindmeld_version` marker than the build you're running | `mindmeld update` (or `mindmeld docs install` — same step) |
| `− [doctor] docs locally modified: N page(s) in <dir> are not mindmeld-managed — delete them to receive the shipped pages` | You (or something else) edited a stamped page and removed its `mindmeld_managed` marker | Delete the file — the next `docs install` or `update` writes the shipped page back |
| `− [doctor] docs orphaned: N page(s) in <dir> are no longer shipped — run 'mindmeld update'` | A page you have locally was removed from the catalog upstream | `mindmeld update` |
| `− [doctor] <kb>/docs/mindmeld is not gitignored — mindmeld sync refuses a dirty tree; add "docs/mindmeld/" to <kb>/.gitignore` | The guide copy is machine-local (each machine's `update` stamps its own); a `.gitignore` written before that lands the copy untracked, which `mindmeld sync`'s dirty-tree preflight then refuses | Add `docs/mindmeld/` to `<kb>/.gitignore` |
| `− [doctor] docs not shipped with this install (ring: <root>) — upgrade mindmeld` | A managed install, or a checkout, that predates the docs organ — the guide isn't in this build at all | `brew upgrade mindmeld` then `mindmeld update` |
| `✗ [doctor] qmd collection not registered — run 'mindmeld update'`, or `✗ [doctor] qmd <candidates\|patterns> collection '<name>' not registered — run 'mindmeld update'` | The KB-root collection, or one of the two scoped collections the mining lane searches, was never registered with qmd (or was removed) | `mindmeld update` registers it, then `mindmeld reindex` to fill it — `update` never embeds, and says so: `qmd collection <name> registered — run 'mindmeld reindex' to embed it` |
| `− [doctor] qmd <candidates\|patterns> collection '<name>' registered but not excluded from default queries — run 'mindmeld update'` | The scoped collection exists but still answers default queries, so every promoted article comes back twice | `mindmeld update` excludes it |
| `− [doctor] adapter notes\|manifest missing: <path> — run 'mindmeld update'`, `… stale in <path> — run 'mindmeld update'`, or `− [doctor] templates stale in <dir> (N of M) — a shipped correction hasn't reached this KB — run 'mindmeld update'` | The engine-stamped adapter files, or the seed-tracked templates, are behind this build | `mindmeld update` |
| `− [doctor] executor class <class> unmapped — runs delegated on the host's default executor, recording a blank executor — add to [execution.classes] in mindmeld.toml: mechanical = "haiku", balanced = "sonnet", deep = "opus"` | No `[execution.classes]` entry for that class. The suggested values come from your adapter; a class with no usable suggestion reads `map [execution.classes] in mindmeld.toml — see your adapter's notes.md` | Add the entries to `mindmeld.toml` (or leave it: unmapped classes still run, on the host's default executor) |
| `✗ [doctor] session archive never run, N live sessions at risk — run 'mindmeld mine archive'`, or `− [doctor] session archive last swept <age>, N sessions newer — run 'mindmeld mine archive'` | This machine has never swept, or the sweep is behind by N sessions that have been quiet for at least `[mining].min_idle`. Sessions newer than that window are still live, and show on the OK line as `— N active session(s) since, taken by the next sweep` | `mindmeld mine archive` |
| `− [doctor] owner unset — this KB's identity home is "<home>" — set [kb] owner = "<home>" in mindmeld.toml` | `[kb].owner` isn't set, and the KB already carries exactly one identity home at `people/<home>/` | Add `owner = "<home>"` under `[kb]` in `mindmeld.toml`, so this machine adopts the KB's identity instead of scaffolding a second one |
| `− [doctor] configured owner "<slug>" is not this KB's identity home "<home>" — voice captures fork here — set [kb] owner = "<home>" in mindmeld.toml` | `[kb].owner` names a different person than the KB's identity home, so voice captures land in two places | Set `[kb].owner` to the identity home. `init` won't reassign an owner once stamped |
| `− [doctor] [<table>] <key> has moved to [<table>] <key> — the value here is ignored — edit mindmeld.toml by hand, or run 'mindmeld update --config'` (or `<key> is no longer read — remove it`; the line ends at `by hand` when `update --config` would decline that shape) | `mindmeld.toml` still sets a key a release moved or removed, so the value does nothing. The `✓ [doctor] config: N newer key(s) unset, defaults in force — …` line beside it is informational | Edit the file, or `mindmeld update --config` — it backs the file up, rewrites only those lines, and keeps your comments. It refuses a read-only file (`— edit by hand: mindmeld.toml is read-only`). See [Config drift](commands/update.md#config-drift) |
| `− [doctor] mcp registration points at <old-command> — stale — run 'mindmeld update'`, or `✗ [doctor] mcp not registered with <adapter> — run 'mindmeld update'` | The harness's registration surface (`~/.claude.json` for `claude-code`) either has an entry under `mindmeld` pointing at the wrong command — typically a moved checkout, since the command is derived from the checkout root, never remembered — or has no entry at all. Missing is an error, not a warn: `mindmeld mcp` is the declared integration edge, so a harness that can't reach it can't use mindmeld at all | `mindmeld update` — it re-derives the command from the checkout's current location and re-registers |
| `− [doctor] mcp registration points at <old-command> — stale — register by hand — 'mindmeld update' prints the command in print mode`, or `− [doctor] mcp not registered with <adapter> — register by hand — 'mindmeld update' prints the command in print mode` | `[install].mcp = "print"`: mindmeld never writes the registration in this mode, so re-running `update` can't clear the line — it only prints the command | Run `mindmeld update`, run the command it prints |
| `✗ [doctor] could not read the mcp registration at <surface>: <cause> — fix the registration surface by hand` | The harness's registration surface exists but can't be parsed — a second JSON document after the first, a trailing tail of anything but whitespace, a top-level value that isn't an object, or a malformed `mcpServers`. The repair is deliberately manual: mindmeld refuses to rewrite a file it only partly understood, because re-marshalling the part it parsed would silently delete the rest | Open the surface (`~/.claude.json` for `claude-code`) and fix the JSON by hand, then re-run `mindmeld doctor`. Under `[install].mcp = "off"` the same condition is reported but does not fail the run |

## Migrating a pre-split KB

`mindmeld doctor` reports `legacy CLAUDE.md at the KB root, no AGENTS.md`, and `init` and
`update` leave the KB untouched rather than stamping anything beside it. This is a KB that predates the
harness-neutral `AGENTS.md`/`OWNER.md` split — its schema and owner context still live
inline in a single, harness-branded `CLAUDE.md`. `init` won't move that content for
you: a second instruction file this harness never reads would sit there inert, and an
`OWNER.md` stamped alongside it would be a divergent copy of context `CLAUDE.md`
already carries. The migration is a few manual edits, done once:

1. `git mv CLAUDE.md AGENTS.md`
2. In that file, replace the schema sections — Directory Structure, Frontmatter
   Conventions, Operations, Customizing the boards, Core Rules — with the two include
   lines `@OWNER.md` and `@docs/mindmeld/kb-schema.md`. Keep the orientation intro.
   This is the step that matters: the schema was inline because nothing else owned it,
   which means it never received an engine update. `docs/mindmeld/kb-schema.md` is
   re-stamped by `mindmeld update` on every upgrade — leaving the sections inline
   instead of switching to the include re-creates the exact staleness the split was
   built to end.
3. Move the `## Owner Context` section's body into `OWNER.md`.
4. Run `mindmeld update` — it stamps `OWNER.md` if it's still absent (with a placeholder
   owner-context line to fill in), and the adapter writes the `CLAUDE.md` shim
   (`@AGENTS.md`) that lets this harness keep reading your instructions under the new
   layout.

## Still stuck

Run `mindmeld doctor --plain` and share the output — every check it runs, in order, with
the exact symbol and message this table matches against.

## Related
- [mindmeld doctor](commands/doctor.md) — what each check does, and the order it runs in
- [Configuration](config.md) — every key referenced above, including `[install].hooks`
- [Adapters](adapters.md) — what the one shipped adapter owns, and the instruction-file
  bridge behind the `CLAUDE.md`/`AGENTS.md` rows above
- [mindmeld docs](commands/docs.md) — `docs install`'s per-file states in full
