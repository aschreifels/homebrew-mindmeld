# Troubleshooting

`mindmeld doctor` is the diagnostic entry point — every row below is a line it can print,
paired with what caused it and the command that clears it. Run `mindmeld doctor --plain`,
find the line, jump to the row.

## Symptom → cause → fix

| Symptom | Cause | Fix |
| --- | --- | --- |
| `✗ [doctor] config missing or does not parse (<path>) — run 'mindmeld init'` | No `mindmeld.toml` (or legacy `spawn.toml`) at `$XDG_CONFIG_HOME/ai` or `~/.config/ai`, or the file fails to parse | `mindmeld init` |
| `✗ [doctor] kb root missing or unset — run 'mindmeld init'` | `[kb].root` is unset, or the directory it points at doesn't exist | `mindmeld init` |
| `✗ [doctor] qmd missing — npm i -g @tobilu/qmd`, or `✗ [doctor] qmd collection check skipped (qmd missing)` | `qmd` isn't on `PATH` — `init`'s index step fails outright without it rather than degrading | `npm i -g @tobilu/qmd`, then `mindmeld init` |
| `− [doctor] skill <name> linked outside the checkout (<target>) — run 'mindmeld init'` | Another sync system's symlink got to `~/.claude/skills/<name>` first | `mindmeld init` |
| `− [doctor] skill <name> installed as a real path, not linked to the checkout — run 'mindmeld init'` | A `--copy` install (a supported posture), or a foreign writer clobbered the symlink | `mindmeld init` — or `mindmeld update --copy` if you installed with `--copy` originally, see [mindmeld update](commands/update.md) |
| `✗ [doctor] skill <name> missing or dangling — run 'mindmeld init'` | Nothing installed at that path, or the symlink's target is gone | `mindmeld init` |
| `− [doctor] hook kb-pulse.sh linked outside the checkout (<target>)`, `− [doctor] hook kb-pulse.sh installed as a real path, not linked to the checkout`, or `✗ [doctor] hook kb-pulse.sh missing or dangling` | Same ownership drift as a skill, but for the SessionStart hook script | `mindmeld init` |
| `✗ [doctor] settings.json SessionStart hook not wired — run 'mindmeld init'` | The hook entry is missing from `~/.claude/settings.json` — often because `[install].hooks` is set to `print` or `off` (see [Configuration](config.md#install)) | Set `[install].hooks = "auto"` (or omit the key), then `mindmeld init` |
| `✗ [doctor] adapter "<name>" is not supported — no organs installed — run 'mindmeld init'` | `[install].adapter` names something other than `claude-code` — usually a typo. Only one adapter ships today (see [Adapters](adapters.md)), so this always means the whole install step was skipped and nothing got wired | Fix or remove the `[install].adapter` key in `mindmeld.toml`, then `mindmeld init` |
| `− [doctor] AGENTS.md present, CLAUDE.md shim missing — run 'mindmeld init'` | The KB has its harness-neutral instructions file, but the adapter hasn't generated the `CLAUDE.md` bridge on this machine yet — typically a KB cloned here before `init` ran | `mindmeld init` |
| `− [doctor] CLAUDE.md is not the generated shim — left alone` | `CLAUDE.md` exists but its body isn't the two-line `@AGENTS.md` shim the adapter would generate — either you replaced it with real content, or it couldn't be read. No repair, on purpose: an adopter who takes over a generated file is exercising a right, not causing drift | none — informational only |
| `− [doctor] legacy CLAUDE.md at the KB root, no AGENTS.md — follow 'Migrating a pre-split KB' in the troubleshooting guide` | A KB scaffolded before the neutral instructions file existed — its instructions still live at the harness-branded `CLAUDE.md`, and nothing has moved them since. The KB still works under this harness; it's lost portability, not function. `init` leaves it alone rather than stamping a second, inert instruction file beside it | [Migrating a pre-split KB](#migrating-a-pre-split-kb) below — a manual step, since `init` never rewrites instance content on your behalf |
| `✗ [doctor] no instruction file at the KB root — run 'mindmeld init'` | Neither `AGENTS.md` nor `CLAUDE.md` exists at `{kb.root}` — a KB `init` hasn't scaffolded yet, or one whose instructions file was deleted | `mindmeld init` |
| Pulse cache looks stale, or a new session opens with no context | `wiki/_hot.md` is derived-local — absent on a fresh clone, or stale because nothing has regenerated it since the last close | `mindmeld hot` |
| `− [doctor] <kb>/.mindmeld/schema.toml does not exclude "docs" from [scope].exclude_dirs — mindmeld lint will gate the guide pages; add "docs" to that list` | Your KB forked its schema (`{kb}/.mindmeld/schema.toml` exists) before the shipped schema excluded `docs` | Add `"docs"` to `[scope].exclude_dirs` in `{kb}/.mindmeld/schema.toml` |
| `− [doctor] docs missing from <dir> (N of M) — run mindmeld docs install` | Catalog pages were never stamped into `{kb}/docs/mindmeld/` | `mindmeld docs install` |
| `− [doctor] docs stale in <dir> (N page(s) stamped <old>, running <new>) — run mindmeld update` | Stamped pages carry an older `mindmeld_version` marker than the build you're running | `mindmeld update` (or `mindmeld docs install` — same step) |
| `− [doctor] docs locally modified: N page(s) in <dir> are not mindmeld-managed — delete them to receive the shipped pages` | You (or something else) edited a stamped page and removed its `mindmeld_managed` marker | Delete the file — the next `docs install` or `update` writes the shipped page back |
| `− [doctor] docs orphaned: N page(s) in <dir> are no longer shipped — run mindmeld update` | A page you have locally was removed from the catalog upstream | `mindmeld update` |
| `− [doctor] <kb>/docs/mindmeld is not gitignored — mindmeld sync refuses a dirty tree; add "docs/mindmeld/" to <kb>/.gitignore` | The guide copy is machine-local (each machine's `init`/`update` stamps its own); a `.gitignore` written before that lands the copy untracked, which `mindmeld sync`'s dirty-tree preflight then refuses | Add `docs/mindmeld/` to `<kb>/.gitignore` |
| `− [doctor] docs not shipped with this install (ring: <root>) — upgrade mindmeld` | A managed install, or a checkout, that predates the docs organ — the guide isn't in this build at all | `brew upgrade mindmeld` then `mindmeld update` |
| `− [doctor] mcp registration points at <old-command> — stale — run 'mindmeld update'`, or `✗ [doctor] mcp not registered with <adapter> — run 'mindmeld update'` | The harness's registration surface (`~/.claude.json` for `claude-code`) either has an entry under `mindmeld` pointing at the wrong command — typically a moved checkout, since the command is derived from the checkout root, never remembered — or has no entry at all. Missing is an error, not a warn: `mindmeld mcp` is the declared integration edge, so a harness that can't reach it can't use mindmeld at all | `mindmeld update` — it re-derives the command from the checkout's current location and re-registers |
| `✗ [doctor] could not read the mcp registration at <surface>: <cause> — fix the registration surface by hand` | The harness's registration surface exists but can't be parsed — a second JSON document after the first, a trailing tail of anything but whitespace, a top-level value that isn't an object, or a malformed `mcpServers`. The repair is deliberately manual: mindmeld refuses to rewrite a file it only partly understood, because re-marshalling the part it parsed would silently delete the rest | Open the surface (`~/.claude.json` for `claude-code`) and fix the JSON by hand, then re-run `mindmeld doctor`. Under `[install].mcp = "off"` the same condition is reported but does not fail the run |

## Migrating a pre-split KB

`mindmeld init` reports `legacy CLAUDE.md at the KB root, no AGENTS.md` and leaves the
KB untouched rather than stamping anything beside it. This is a KB that predates the
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
4. Re-run `mindmeld init` — it stamps `OWNER.md` if it's still absent, and the adapter
   writes the `CLAUDE.md` shim (`@AGENTS.md`) that lets this harness keep reading your
   instructions under the new layout.

## Still stuck

Run `mindmeld doctor --plain` and share the output — every check it runs, in order, with
the exact symbol and message this table matches against.

## Related
- [mindmeld doctor](commands/doctor.md) — what each check does, and the order it runs in
- [Configuration](config.md) — every key referenced above, including `[install].hooks`
- [Adapters](adapters.md) — what the one shipped adapter owns, and the instruction-file
  bridge behind the `CLAUDE.md`/`AGENTS.md` rows above
- [mindmeld docs](commands/docs.md) — `docs install`'s per-file states in full
