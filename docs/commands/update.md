# mindmeld update

`init` is the ritual for a machine that has nothing yet; `update` is the same repair,
scoped to a machine that already has everything and just needs it brought current. It
owns exactly what mindmeld owns — the checkout and the organs it installs — and says so
explicitly rather than pretending to be a general-purpose updater.

## Usage

```bash
mindmeld update [--dry-run] [--copy]
```

- `--dry-run` — preview the pull and reinstall without writing
- `--copy` — copy instead of symlink — pass this if the checkout was originally
  installed with `init --copy`, or `update` will re-link a copy install into a symlink
  one, which isn't drift, it's a different posture than the one you chose

## What it does

Four steps, in order:

1. **Pull.** For a managed (Homebrew) install — the common case — there's no checkout
   to pull, so this step reports `managed install — run 'brew upgrade mindmeld' to
   update the engine` and stops there: brew owns the version bump, `update` owns
   everything after it. For a source checkout, this step runs `git pull --ff-only`
   instead — no upstream configured, or the checkout has local changes, both degrade to
   a warn-and-skip; `update` never stashes, forces, or rebases over a stranded edit.
2. **Reinstall the adapter.** The exact step `init` runs — same link/copy/backup
   semantics, byte-identical report lines — so any skill or hook that drifted back to a
   real path or a foreign symlink gets repaired.
3. **Refresh the guide.** Restamps `{kb.root}/docs/mindmeld/` the same way
   `mindmeld docs install` does: new pages get stamped, changed ones refreshed, and a
   page you've edited out of the marker is left alone. See [mindmeld docs](docs.md).
4. **Sync bases.** Brings every shipped `.base` board current against your KB via the
   same seed-tracked three-way merge `init` runs on a fresh KB — an edited board is
   never destroyed, only replaced or merged when the seed proves your copy hasn't
   diverged from what was last stamped.

What it deliberately doesn't do: re-run the index step. `qmd collection add` and
`qmd embed` are `init`'s job alone — if `doctor` reports a qmd collection as missing or
unexcluded, the repair is `mindmeld init`, not `update`.

## Output

Step tag `update` (`dry-run` under `--dry-run`). Pull reports one of: checkout already
up to date, checkout updated to `<sha>`, no upstream configured — skipping pull, checkout
has local changes — skipping pull, or pull failed. The adapter reinstall and guide
refresh report the same lines `init` does for those steps. A closing line, printed
unconditionally, states the ownership boundary:

```text
Updated the mind (checkout + installed organs). Machine config is managed separately —
run your dotfile manager's update for that.
```

## Config it reads

`[kb].root`, as the sync-bases and docs-refresh target — see
[config.md#kb](../config.md#kb). `[mindmeld].checkout`, if the content ring needs an
explicit resolution — see [config.md#mindmeld](../config.md#mindmeld).

## Related
- [mindmeld init](init.md) — the same adapter-install and docs steps, run once on a
  fresh machine
- [mindmeld doctor](doctor.md) — run this after `update` to confirm the repair landed
- [Configuration](../config.md) — the full checkout-resolution reference
