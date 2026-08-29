# mindmeld doctor

"Does this path exist" is the wrong question for a symlink-based install: a stale copy
some other sync tool wrote passes that check exactly as well as a healthy link into the
checkout. `doctor` classifies instead of merely checking, so drift is a reported state
you can act on rather than a silent gap you find later.

## Usage

```bash
mindmeld doctor
```

No flags beyond the global `--plain`. On a real terminal (no `--plain`, `NO_COLOR`
unset) `doctor` runs as an interactive TUI; anywhere else — a pipe, CI, `--plain` — it
prints the same lines as plain text, one per check.

## What it does

Walks a fixed sequence of checks, each reported as `✓`/`−`/`✗ [doctor] message`: config
parses, the KB root exists, required deps are present (`git`, `rg`, `yq`, `qmd`), every
adapter skill's and the pulse hook's ownership, the instance ring's presence, the
`settings.json` SessionStart hook is wired, the qmd collections are registered, the
guide copy in your KB is current, the session archive is swept, build identity,
checkout freshness, and Obsidian/`scribe` presence (informational). Five of these
deserve their own explanation.

### Skill and hook ownership

Each adapter skill (`spawn-session`, `wrap-session`, `kb-ticket`, `voice-distill`,
`pr-review`, `mine-review`) and the pulse hook get one of four states:

| State | Meaning | Severity |
|---|---|---|
| linked to checkout | a symlink resolving to `<repo>/skills/<name>` | OK |
| linked elsewhere | a symlink, but to a different target — another sync system got there first | warn, repair: `mindmeld init` |
| installed as a real path | a real file or directory, not a symlink — `--copy`'s normal shape, a supported posture | warn, repair: `mindmeld init` |
| missing or dangling | nothing there, or a symlink whose target is gone | error, repair: `mindmeld init` |

### Owner identity

`[kb] owner` gets a matching classification, not a bare stat of `people/{owner}/`: an
ambiguous KB (more than one identity home) warns and names all of them; an unset owner
sitting next to exactly one identity home warns and points at `mindmeld init` to adopt
it; a configured owner that disagrees with the KB's real identity home warns and names
the fix (hand-edit `mindmeld.toml`); a missing identity home warns, informational only.

### qmd collections

The KB-root collection is required — missing it is an error. Two more collections are
classified only once the KB-root one resolves: `candidates` and `patterns`, the mining
lane's scoped-recall targets. Each is one of registered-and-excluded (OK),
registered-but-not-excluded-from-default-queries (warn — every promoted article comes
back twice), or not-registered (error). Both point at `mindmeld init`, not `update` —
`update` deliberately never re-runs the index step, so re-running `init` is the repair.

### Session archive

Reads the sweep stamp against the live session store's newest activity, never the
archive's own contents (reclamation can legitimately drain it to empty). Four states: no
live sessions and no stamp (OK, nothing to archive); live sessions and no stamp (error —
this machine has never swept, real data loss in progress); stamp at or after the newest
live session (OK, swept, with totals); stamp behind the newest live session (warn, N
sessions newer). A spool configured outside `$HOME` is a separate error — the mining
ledger can't record a path it can't express `~`-relative. Any unreadable spooled entry
adds its own warn line.

### Guide freshness

`doctor` compares the guide copy stamped into your KB (`{kb.root}/docs/mindmeld/`)
against the shipped catalog the same way it treats a skill — by classifying, not by
testing that files exist. It runs right after the qmd collection checks and only once
the KB root resolves. Lines it can print:

| Line | Meaning | Repair |
|---|---|---|
| `✓ [doctor] docs current in <kb>/docs/mindmeld (N pages, <version>)` | every page carries the marker and matches this build byte-for-byte | — |
| `− [doctor] docs missing from <kb>/docs/mindmeld (N of M) — run mindmeld docs install` | pages were never stamped (a KB that predates the guide) | `mindmeld docs install` |
| `− [doctor] docs stale in <kb>/docs/mindmeld (N page(s) stamped <old>, running <new>) — run mindmeld update` | the stamped marker names an older version than the binary you're running | `mindmeld update` |
| `− [doctor] docs locally modified: N page(s) in <kb>/docs/mindmeld are not mindmeld-managed — delete them to receive the shipped pages` | a page lost its `mindmeld_managed` marker — it's yours now, and the engine won't overwrite it | delete the file |
| `− [doctor] docs orphaned: N page(s) in <kb>/docs/mindmeld are no longer shipped — run mindmeld update` | a marked page whose topic no longer exists upstream; `update` prunes it | `mindmeld update` |
| `− [doctor] <kb>/.mindmeld/schema.toml does not exclude "docs" from [scope].exclude_dirs — mindmeld lint will gate the guide pages; add "docs" to that list` | your KB forked its lint schema before the shipped one excluded `docs` | one-line edit to your fork |
| `− [doctor] <kb>/docs/mindmeld is not gitignored — mindmeld sync refuses a dirty tree; add "docs/mindmeld/" to <kb>/.gitignore` | your KB's `.gitignore` predates the guide being made machine-local — the stamped copy lands untracked, and `mindmeld sync` refuses any dirty tree | add `docs/mindmeld/` to `<kb>/.gitignore` |
| `− [doctor] docs not shipped with this install (ring: <root>) — upgrade mindmeld` | a checkout or package that predates the guide — informational, never a failure | upgrade |

Several can print in the same run (stale pages plus one orphan, say); missing is
reported on its own only when nothing is stale or modified. See
[mindmeld docs](docs.md) for the install step these lines describe.

## Output

Ends in a summary block:

```text
== doctor: all required organs present ==
== doctor: all required organs present, N warnings ==
   <repair>
== doctor: N check failed — <repair> to repair ==
== doctor: N checks failed, N repairs ==
   <repair>
   <repair>
```

One distinct repair reads as a sentence; more than one lists every distinct fix a
failing or warning line named, deduplicated. Quitting the TUI with ctrl+c/`q` before the
walk finishes exits 130 and prints nothing — the walk never completed, so there's
nothing to summarize.

## Config it reads

`[kb]` (root, owner), `[install].skills_dir`, `[mining].archive_dir`,
`[mining.recurrence]` (the scoped-collection names) — see
[config.md#kb](../config.md#kb), [config.md#install](../config.md#install),
[config.md#mining](../config.md#mining). Full writeup:
[doctor: ownership, not mere existence](../config.md#doctor-ownership-not-mere-existence).

## Related
- [mindmeld init](init.md) — the repair for most `doctor` findings
- [mindmeld update](update.md) — the repair for a stale checkout
- [Configuration](../config.md) — the full ownership-classification reference
