# mindmeld init

A first-time install needs six different things wired together before anything works —
config, a KB scaffold, a search index, host skills — and doing that by hand is exactly
the friction that makes an idea not worth adopting. `init` is that whole ritual in one
pass, and every step is additive-idempotent: re-running it against an already-set-up
machine is a no-op walk, never a second copy of anything.

`init` is the first-install command. Once an instance exists — a config that loads and a
KB root that validates — [`mindmeld update`](update.md) is how it stays current, and it's
what [`doctor`](doctor.md) names as the repair for everything `update` performs. `init`
is still the command `doctor` points at before any instance exists: a missing config, a
missing KB root. Re-running it on an existing machine is safe, but it asks the first-run
questions again; `update` doesn't.

## Usage

```bash
mindmeld init [--defaults] [--copy] [--no-hook] [--no-mcp] [--dry-run] [--kb PATH] [--kb-remote URL]
```

- `--defaults` — accept every default without prompting
- `--copy` — copy instead of symlink
- `--no-hook` — skip wiring the SessionStart hook
- `--no-mcp` — skip registering the mcp control plane; mirrors `--no-hook`, and forces
  `[install].mcp` to `print` for this run regardless of what's configured
- `--dry-run` — report what would happen without writing
- `--kb PATH` — override the KB root for this run
- `--kb-remote URL` — clone the KB from this git URL if the KB root is empty (flag beats
  `[kb] remote_url`)

## What it does

Nine steps, in order, each reported as its own `✓`/`−`/`✗ [step] message` lines:

| Step | What it writes | Idempotent how |
|---|---|---|
| preflight | nothing on its own — offers to install missing `git`/`rg`/`yq`/`qmd`/Obsidian via brew | re-checks presence; already-installed deps just report OK |
| identity | nothing directly — resolves KB root, owner, branch prefix, base branch for the steps below | existing config always outranks the built-in default |
| config | `~/.config/ai/mindmeld.toml` | no-op if the stamp already matches; previews a diff and asks before overwriting one that differs |
| kb-fetch | clones the KB when the root is empty and a remote is known | an existing git work tree is left alone — only its origin is checked |
| kb-scaffold | `{kb.root}/**` — see [The KB instance](../config.md#the-kb-instance) | existing files and directories are left untouched; only what's missing is filled in |
| docs | `{kb.root}/docs/mindmeld/*.md` — the guide, stamped into your KB | re-stamps only pages that changed; a page you edited (no marker) is never touched — see [mindmeld docs](docs.md) |
| hot | `{kb.root}/wiki/_hot.md` | regenerates in place; declining the prompt just defers to the first session's hook run |
| index | registers the KB-root qmd collection plus the `candidates`/`patterns` scoped collections | `qmd collection add` treats "already exists" as OK, not an error |
| install | symlinks (or copies, with `--copy`) the six session skills and the pulse hook into `~/.claude/`, wires the `SessionStart` hook, and — only when `{kb.root}/AGENTS.md` already exists — generates `{kb.root}/CLAUDE.md` as a two-line shim (`@AGENTS.md`), since this harness hard-codes that filename. Last inside this step: registers the `mindmeld mcp` control plane with the harness (see below) | every write is preceded by an existence check; a collision is backed up, never overwritten; the shim is skipped, never forced, when its target is missing |

Registering the control plane rewrites `~/.claude.json`, a file `init` doesn't own — so
under `[install].mcp = "auto"` (the default) it asks first, whenever a human is at the
keyboard: `--defaults` never constructs a prompter at all, the same as every other
prompt this command asks, so a scripted `init --defaults` registers without a pause.
`--no-mcp` and `[install].mcp = "print"` skip the prompt entirely and print the command
to run by hand instead; `[install].mcp = "off"` skips registration altogether.

Full host-path surface, every path `init` may touch and nothing outside it:
[What init touches](../config.md#what-init-touches-claude-code-adapter).

## Output

A collision — something already sitting at a path `init` needs — is never overwritten in
place. It's relocated to `~/.claude/mindmeld-backups/<surface>/` and reported as a `−`
line; when anything was actually displaced, the closing block names it and where it went,
and a clean install stays quiet instead.

The closing summary line is one of:

```text
== init complete: N landed, N degraded/skipped, N failed ==
== dry-run complete: N previewed, N degraded/skipped, N would-fail — zero writes made ==
```

`--dry-run` previews the whole plan even past a point a real run would stop at (required
deps missing), so one pass shows you everything that would happen. The closing block also
names two next steps: `mindmeld doctor`, then `mindmeld docs getting-started`.

## Config it reads

`[kb]` (root, owner, remote_url), `[defaults]` (branch_prefix, base_branch), `[install]`
(adapter, skills_dir, hooks, mcp), `[mining.recurrence]` (the scoped-collection names) — see
[config.md#kb](../config.md#kb), [config.md#defaults](../config.md#defaults),
[config.md#install](../config.md#install), [config.md#mining](../config.md#mining).

## Related
- [mindmeld doctor](doctor.md) — run this next; checks everything `init` just wired
- [mindmeld update](update.md) — where an existing instance goes from here: the same
  adapter, scaffold, guide and index steps, converged without prompting
- [mindmeld docs](docs.md) — the guide `init`'s docs step stamps into your KB
- [Configuration](../config.md) — the full host-path and KB-instance reference
- [Adapters](../adapters.md) — what the install step's adapter half actually owns
