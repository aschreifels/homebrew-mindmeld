# mindmeld sync

Your KB moves between machines the same way any git repo does, but four different
rituals — spawn-session, wrap-session, voice-distill, mine-review — used to carry their
own copy of the pull-merge-push sequence in prose. `sync` is that sequence, once, so
every ritual (and you, directly) gets the same pull → reconcile → push behavior instead
of four chances to drift.

## Usage

```bash
mindmeld sync [--dry-run] [--pull-only] [--kb-root PATH] [--remote NAME] [--branch NAME]
```

## What it does

1. Checks `[sync].enabled` — `false` is a preflight refusal (a warn, exit 0), and no git
   command runs at all.
2. Resolves the KB root (`--kb-root`, else `[kb].root`), remote (`--remote`, else
   `[sync].remote`, else `"origin"`), and branch (`--branch`, else `[sync].branch`, else
   `"main"`).
3. Pulls, merges, and reconciles — reconcile runs between merge and push on every path
   that merges, using the same reconcile step `mindmeld lint` exposes, so a merge that
   needs the derived index regenerated gets it before anything pushes.
4. Pushes, unless `--pull-only` (pull and reconcile only, never push).

The whole sequence runs under `[sync].timeout` and holds a fixed set of invariants
regardless of what it hits along the way: it never rebases, never widens the git stage
beyond what it needs, a refusal mutates nothing, a conflict leaves the tree exactly as
found, push retries at most once, the run is idempotent, and `--dry-run` writes nothing.

## Output

Report lines are tagged `sync`. A disabled run prints
`sync disabled ([sync].enabled = false) — skipping` and stops. Failures accumulated
during the run exit 1 with a bare (unstyled) exit — the same posture `mine` and `lint`
take for an accumulated-failure sentinel.

## Config it reads

`[sync]` (enabled, remote, branch, timeout) — see
[config.md#sync](../config.md#sync). `[kb].root` for the default KB root — see
[config.md#kb](../config.md#kb).

## Related
- [mindmeld host](host.md) — prints this machine's identity, the other per-machine
  primitive `sync` sits alongside
- [Configuration](../config.md) — the full `[sync]` key reference
