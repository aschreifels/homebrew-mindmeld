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
| Pulse cache looks stale, or a new session opens with no context | `wiki/_hot.md` is derived-local — absent on a fresh clone, or stale because nothing has regenerated it since the last close | `mindmeld hot` |
| `− [doctor] <kb>/.mindmeld/schema.toml does not exclude "docs" from [scope].exclude_dirs — mindmeld lint will gate the guide pages; add "docs" to that list` | Your KB forked its schema (`{kb}/.mindmeld/schema.toml` exists) before the shipped schema excluded `docs` | Add `"docs"` to `[scope].exclude_dirs` in `{kb}/.mindmeld/schema.toml` |
| `− [doctor] docs missing from <dir> (N of M) — run mindmeld docs install` | Catalog pages were never stamped into `{kb}/docs/mindmeld/` | `mindmeld docs install` |
| `− [doctor] docs stale in <dir> (N page(s) stamped <old>, running <new>) — run mindmeld update` | Stamped pages carry an older `mindmeld_version` marker than the build you're running | `mindmeld update` (or `mindmeld docs install` — same step) |
| `− [doctor] docs locally modified: N page(s) in <dir> are not mindmeld-managed — delete them to receive the shipped pages` | You (or something else) edited a stamped page and removed its `mindmeld_managed` marker | Delete the file — the next `docs install` or `update` writes the shipped page back |
| `− [doctor] docs orphaned: N page(s) in <dir> are no longer shipped — run mindmeld update` | A page you have locally was removed from the catalog upstream | `mindmeld update` |
| `− [doctor] <kb>/docs/mindmeld is not gitignored — mindmeld sync refuses a dirty tree; add "docs/mindmeld/" to <kb>/.gitignore` | The guide copy is machine-local (each machine's `init`/`update` stamps its own); a `.gitignore` written before that lands the copy untracked, which `mindmeld sync`'s dirty-tree preflight then refuses | Add `docs/mindmeld/` to `<kb>/.gitignore` |
| `− [doctor] docs not shipped with this install (ring: <root>) — upgrade mindmeld` | A managed install, or a checkout, that predates the docs organ — the guide isn't in this build at all | `brew upgrade mindmeld` then `mindmeld update` |

## Still stuck

Run `mindmeld doctor --plain` and share the output — every check it runs, in order, with
the exact symbol and message this table matches against.

## Related
- [mindmeld doctor](commands/doctor.md) — what each check does, and the order it runs in
- [Configuration](config.md) — every key referenced above, including `[install].hooks`
- [mindmeld docs](commands/docs.md) — `docs install`'s per-file states in full
