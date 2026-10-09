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
parses, any `mindmeld.toml` key a release has moved or removed is called out, the KB
root exists, required deps are present (`git`, `rg`, `yq`, `qmd`), which `[install]` adapter is active and the instruction-file layout at the KB root, every
adapter skill's and the pulse hook's ownership, the instance ring's presence, the
`settings.json` SessionStart hook is wired, the qmd collections are registered, the
guide copy in your KB is current, the active adapter's machine-readable capability
manifest is current and what it says about this host before a session starts, the
session archive is swept, how each portable executor class in `[execution.classes]`
resolves, build identity, checkout freshness, Obsidian presence (informational), and
the served MCP surface plus whether the configured adapter's harness is actually
registered against it. Several of these deserve their own explanation.

### Which command a repair names

A repair is the command that clears the line, and which command that is depends on
whether this machine already has an instance. `doctor` counts an instance as initialized
when the config loads and the KB root validates — not when a `mindmeld.toml` file exists,
since a legacy `spawn.toml` or a `MINDMELD_KB` override is an initialized instance too.

| Instance | Repair for anything `update` performs |
|---|---|
| initialized | `run 'mindmeld update'` |
| not yet | `run 'mindmeld init'` |

"Anything `update` performs" is most of the walk: the instruction-file shim, the skills
and the pulse hook, the `settings.json` hook, the qmd collections, the guide, the adapter
notes and manifest, the seed-tracked templates, and the MCP registration. Every line in
one walk quotes the same command, so the summary at the end collapses them to one repair.
What stays outside that rule is spelled out where it applies below: a skill or hook
installed as a real path, a hook the config says not to wire, an unsupported adapter, a
pre-split `CLAUDE.md`, and a missing config or KB root, which only `init` can create.

### Config

`✓ [doctor] config parses (<path>)` is the usual line. A machine that runs with no
`mindmeld.toml` at all but names its KB through `MINDMELD_KB` is a valid, initialized
instance — `update` works there, and `init` would only write a file — so it reads as
information rather than an error:

```text
✓ [doctor] no mindmeld.toml — running on MINDMELD_KB (<root>)
```

With neither a file nor `MINDMELD_KB`, or a file that doesn't parse, the line is the error
`config missing or does not parse (<path>)`, repaired by `mindmeld init`.

### Adapter and instruction-file layout

Two lines, both deferring to the same predicates `init` uses rather than re-deriving
either — a hand-kept second copy of "which adapters exist" is how this repo already lost
a skill from the health check once.

The first names the active `[install]` adapter and whether it's supported: `claude-code`
is the only one that is, today (see [Adapters](../adapters.md)), so anything else is an
error — a typo'd adapter name means the entire install step was skipped and nothing got
wired, which must not read as a clean walk.

The second, printed only once the KB root itself has validated, classifies the
instruction-file layout at that root — whether the KB's harness-neutral `AGENTS.md` and
its harness-specific `CLAUDE.md` shim are both present, one without the other, present
but hand-authored, or absent entirely. Five states, one line each:

| Line | Meaning | Repair |
|---|---|---|
| `✓ [doctor] AGENTS.md present, CLAUDE.md shim materialized` | the healthy state — the shim's body is exactly `@AGENTS.md` | — |
| `− [doctor] AGENTS.md present, CLAUDE.md shim missing — run 'mindmeld update'` | the neutral file exists but the adapter hasn't generated the shim on this machine yet | `mindmeld update` |
| `− [doctor] CLAUDE.md is not the generated shim — left alone` | `CLAUDE.md` exists with a body that isn't the generated shim — either you replaced it on purpose, or it couldn't be read; either way there's nothing to repair | none |
| `− [doctor] legacy CLAUDE.md at the KB root, no AGENTS.md — follow 'Migrating a pre-split KB' in <kb>/docs/mindmeld/troubleshooting.md` | a KB scaffolded before the neutral file existed — it still works under this harness, it's just lost portability | the written migration, a few manual edits — see [Troubleshooting](../troubleshooting.md#migrating-a-pre-split-kb) |
| `✗ [doctor] no instruction file at the KB root — run 'mindmeld update'` | neither file exists | `mindmeld update` |

The legacy line names the stamped copy of the troubleshooting page by absolute path when
it's on disk; a KB that predates the guide stamp gets `in the troubleshooting guide`
instead, since a path the reader can't open helps nobody. An unsupported adapter ends in
`set [install].adapter in mindmeld.toml to a supported adapter` rather than a command —
reinstalling can't fix a name that resolves to nothing.

Full symptom/cause/fix writeup, including the migration: [Troubleshooting](../troubleshooting.md).

### Skill and hook ownership

Each adapter skill (`spawn-session`, `wrap-session`, `kb-ticket`, `voice-distill`,
`pr-review`, `mine-review`) and the pulse hook get one of four states:

| State | Meaning | Severity |
|---|---|---|
| linked to checkout | a symlink resolving to `<repo>/skills/<name>` | OK |
| linked elsewhere | a symlink, but to a different target — another sync system got there first | warn, repair: `mindmeld update` |
| installed as a real path | a real file or directory, not a symlink — `--copy`'s normal shape, a supported posture | warn, repair: `mindmeld update` (or `mindmeld update --copy` for a copy install) |
| missing or dangling | nothing there, or a symlink whose target is gone | error, repair: `mindmeld update` |

The real-path repair carries the `--copy` alternative because a plain `update` re-links a
copy install into a symlink one — the repair for a foreign writer, not for a posture you
chose. The line reads `… installed as a real path, not linked to the checkout — run
'mindmeld update' (or 'mindmeld update --copy' for a copy install)`. Before the first
install every one of these says `mindmeld init` instead.

### Settings hook

Whether the `SessionStart` hook entry is in `~/.claude/settings.json` follows
`[install].hooks`, because the config decides whether mindmeld was ever going to write it:

| `[install].hooks` | Line | Severity | Repair |
|---|---|---|---|
| `auto` (or unset) | `✗ [doctor] settings.json SessionStart hook not wired — run 'mindmeld update'` | error | `mindmeld update` |
| `print` | `− [doctor] settings.json SessionStart hook not wired — wire the SessionStart hook by hand — 'mindmeld update' prints the snippet in print mode` | warn | paste the snippet |
| `off` | `− [doctor] settings.json SessionStart hook not wired` | warn | none — the configured state |

The same split as the MCP registration below: an opt-out you configured must not turn the
machine red.

Under `print` the snippet comes from `update` once the instance is initialized, and from
`init` before the first install, so the line reads `… 'mindmeld init' prints the snippet in
print mode` on a machine with no instance yet.

### Owner identity

`[kb] owner` gets a matching classification, not a bare stat of `people/{owner}/`: an
ambiguous KB (more than one identity home) warns and names all of them; an unset owner
sitting next to exactly one identity home warns and carries the edit that adopts it; a
configured owner that disagrees with the KB's real identity home warns and carries the
edit that points it at the right one; a missing identity home warns, informational only.
The two repairs are hand edits, because `mindmeld.toml` is yours and `init` won't reassign
an owner once stamped:

```text
− [doctor] owner unset — this KB's identity home is "<home>" — set [kb] owner = "<home>" in mindmeld.toml
− [doctor] configured owner "<slug>" is not this KB's identity home "<home>" — voice captures fork here — set [kb] owner = "<home>" in mindmeld.toml
```

### qmd collections

The KB-root collection is required — missing it is an error. Two more collections are
classified only once the KB-root one resolves: `candidates` and `patterns`, the mining
lane's scoped-recall targets. Each is one of registered-and-excluded (OK),
registered-but-not-excluded-from-default-queries (warn — every promoted article comes
back twice), or not-registered (error). Every one of these takes `mindmeld update` as its
repair: `update` registers the missing collections and excludes the scoped pair, and it
never embeds. A collection it just registered is reported as `qmd collection <name>
registered — run 'mindmeld reindex' to embed it`, because an empty collection answers
nothing until `reindex` fills it. Before the first install the repair is `mindmeld init`.

### Session archive

Reads the sweep stamp against the live session store's newest activity, never the
archive's own contents (reclamation can legitimately drain it to empty). Four states
(the third and fourth split on the grace described below): no
live sessions and no stamp (OK, nothing to archive); live sessions and no stamp (error —
this machine has never swept, real data loss in progress); stamp at or after the newest
live session (OK, swept, with totals); stamp behind the newest live session (warn, N
sessions newer). A spool configured outside `$HOME` is a separate error — the mining
ledger can't record a path it can't express `~`-relative. Any unreadable spooled entry
adds its own warn line.

A session newer than the stamp counts as missed only once it has been quiet for
`[mining].min_idle` (default `30m`). One still inside that window is presumed live — the
miner reads it the same way — and the next sweep takes it, so `mindmeld mine archive`
couldn't clear it anyway. Those ride the OK line as a suffix instead of a warning:

```text
✓ [doctor] session archive swept 2h ago (4 archived, 1 reclaimed) — 1 active session(s) since, taken by the next sweep
− [doctor] session archive last swept 2h ago, 3 sessions newer — run 'mindmeld mine archive'
```

The warn counts missed sessions only. `min_idle = "0"` turns the grace off: every newer
session is missed, as before the grace existed. See [config.md#mining](../config.md#mining).

### Guide freshness

`doctor` compares the guide copy stamped into your KB (`{kb.root}/docs/mindmeld/`)
against the shipped catalog the same way it treats a skill — by classifying, not by
testing that files exist. It runs right after the qmd collection checks and only once
the KB root resolves. Lines it can print:

| Line | Meaning | Repair |
|---|---|---|
| `✓ [doctor] docs current in <kb>/docs/mindmeld (N pages, <version>)` | every page carries the marker and matches this build byte-for-byte | — |
| `− [doctor] docs missing from <kb>/docs/mindmeld (N of M) — run 'mindmeld update'` | pages were never stamped (a KB that predates the guide) | `mindmeld update` |
| `− [doctor] docs stale in <kb>/docs/mindmeld (N page(s) stamped <old>, running <new>) — run 'mindmeld update'` | the stamped marker names an older version than the binary you're running | `mindmeld update` |
| `− [doctor] docs locally modified: N page(s) in <kb>/docs/mindmeld are not mindmeld-managed — delete them to receive the shipped pages` | a page lost its `mindmeld_managed` marker — it's yours now, and the engine won't overwrite it | delete the file |
| `− [doctor] docs orphaned: N page(s) in <kb>/docs/mindmeld are no longer shipped — run 'mindmeld update'` | a marked page whose topic no longer exists upstream; `update` prunes it | `mindmeld update` |
| `− [doctor] <kb>/.mindmeld/schema.toml does not exclude "docs" from [scope].exclude_dirs — mindmeld lint will gate the guide pages; add "docs" to that list` | your KB forked its lint schema before the shipped one excluded `docs` | one-line edit to your fork |
| `− [doctor] <kb>/docs/mindmeld is not gitignored — mindmeld sync refuses a dirty tree; add "docs/mindmeld/" to <kb>/.gitignore` | your KB's `.gitignore` predates the guide being made machine-local — the stamped copy lands untracked, and `mindmeld sync` refuses any dirty tree | add `docs/mindmeld/` to `<kb>/.gitignore` |
| `− [doctor] docs not shipped with this install (ring: <root>) — upgrade mindmeld` | a checkout or package that predates the guide — informational, never a failure | upgrade |

Before the first install the three `run 'mindmeld update'` repairs say `run 'mindmeld init'`.
Several can print in the same run (stale pages plus one orphan, say); missing is
reported on its own only when nothing is stale or modified. See
[mindmeld docs](docs.md) for the install step these lines describe.

### Config drift

Right after the config line, `doctor` reads `mindmeld.toml` against a small table of keys
releases have moved, removed or introduced. It never edits the file. A clean config
prints nothing, and so does one that is absent, unreadable or doesn't parse —
`config parses` already owns reporting those.

| Line | Meaning | Repair |
|---|---|---|
| `− [doctor] [mining.recurrence] reindex_timeout has moved to [reindex] timeout — the value here is ignored — edit mindmeld.toml by hand, or run 'mindmeld update --config'` | the file still sets a key at its old path; the release reads the new one, so the old value does nothing | edit the file, or `mindmeld update --config` |
| `− [doctor] [mining.recurrence] reindex_timeout has moved to [reindex] timeout — the value here is ignored ([reindex] timeout already set — old key is ignored) — edit mindmeld.toml by hand, or run 'mindmeld update --config'` | the same, with the new key already set too — the old line is dead weight | the same |
| `− [doctor] <key> is no longer read — remove it — edit mindmeld.toml by hand, or run 'mindmeld update --config'` | the file sets a key no release reads any more | the same |
| `− [doctor] [mining.recurrence] reindex_timeout has moved to [reindex] timeout — the value here is ignored — edit mindmeld.toml by hand` | the same move, written in a shape `update --config` declines to rewrite (anything but a single-line `key = value` under its own `[table]` header) | edit the file — the `--config` clause is dropped rather than promise a rewrite that would refuse |
| `✓ [doctor] config: 4 newer key(s) unset, defaults in force — [reindex] timeout (10m), [install] mcp (auto), [execution] record_executor (true), [defaults] dossier_archive_dir (<dossier_dir>-archive)` | informational, never a warning: keys added since v0.4.0 that the file doesn't set, each with the default in force | none — set one only to change it |

The repair names the file actually loaded, so a legacy `spawn.toml` reads `edit spawn.toml
by hand`. A `MINDMELD_KB` instance with no config file has nothing to read, so this check
prints nothing there.

The unset line lists only the keys the file really leaves out, so it shrinks as you set
them and disappears once none are left. `mindmeld update` reports the same moved and
removed keys, `mindmeld mine` and `mindmeld reindex` print the moved-key sentence when
they hit one, and `update --config` is the opt-in rewrite — see
[mindmeld update](update.md#config-drift).

### Dossier archive root

Right before the MCP lines below, `doctor` classifies the root `ritual.archive` (the
mcp plane) moves a wrapped dossier to — the same overlap precondition that verb itself
refuses on, checked here so a misconfiguration surfaces before a real wrap ever reaches
it. Read-only, like every other classification in this walk: it never creates the
archive root, resolving as much of the path as already exists on disk and leaving the
rest lexical. Nothing prints at all when `defaults.dossier_dir` isn't configured —
`ritual.archive` itself is unreachable without one.

| Line | Meaning | Repair |
|---|---|---|
| `✓ [doctor] dossier archive root: default sibling in use (<path>)` | `defaults.dossier_archive_dir` is unset; the engine's own default (a `<basename>-archive` sibling of `dossier_dir`) resolves cleanly | — |
| `✓ [doctor] dossier archive root: explicitly configured and valid (<path>)` | `defaults.dossier_archive_dir` is set and disjoint from `dossier_dir` | — |
| `✗ [doctor] dossier archive root <path> overlaps dossier_dir <path> — ritual.archive refuses to run until they're disjoint` | the configured or defaulted archive root is nested under (or nests) `dossier_dir`, symlinks resolved before the comparison | move `dossier_archive_dir` outside `dossier_dir` |

### Adapter manifest and host diagnostics

The active adapter ships a machine-readable capability manifest beside its notes —
`adapters/<adapter>/manifest.json`, stamped into `{kb.root}/adapters/<adapter>/` the
same marker-guarded way notes.md is (current, stale, missing, or locally modified —
the same four states [Adapter and instruction-file layout](#adapter-and-instruction-file-layout)
describes for notes.md, reported here for the manifest instead; a missing or stale one
takes the reinstall repair, `run 'mindmeld update'`). Once that file
classifies as readable, `doctor` goes further than presence: it parses the manifest and
diagnoses what it says about this host, before a session ever declares a chunk graph.

Three diagnostics, each reading the resolved KB routing policy
(`policy/chunk-routing.md`, or the engine defaults when nothing is configured) and
`[execution.classes]` alongside the manifest:

- **Policy class coverage.** For every class a routing rule targets (`class:`) or
  floors (`min:`), one line naming whether the manifest's own `classes` list actually
  offers it. A gap warns — never errors — but never predicts the alternative either:
  this check runs before any chunk is declared, so it cannot see what a given chunk's
  own `fallback` will actually offer once one is. That could be main-thread (an unset
  `fallback` defaults to `[main-thread]`, and `Manifest.Validate` requires main-thread
  true on every valid manifest, so it's always legal), another delegable class the
  manifest DOES list (a `class`+`min` range can name a delegated alternative just as
  legally), or — an explicit `fallback`, or a reroute's `class`-only and `class`+`min`
  shapes, which replace `fallback` outright, may leave both out — nothing at all, in
  which case the gap is refused outright at claim time rather than absorbed by
  anything this check could have named in advance. The line says only what it actually
  knows: `not offered by the adapter — this host cannot fill it; a chunk routed there
  needs an alternative in its own offer`. A rule naming `main-thread` itself is never
  reported on — that target is unconditionally available on every valid manifest.
- **The no-per-child collapse.** When the manifest declares `per_child_class: false`,
  every delegated chunk actually runs as the one class its `classes` list names,
  whatever class its own request preferred — `Manifest.Validate` requires exactly one
  class in this state, so there is no ambiguity about which. One warn line, naming that
  class and its `[execution.classes]` mapping when one exists — a cost decision, not a
  fault, the same severity the existing per-class collapse below already uses. Silent
  when the manifest can't delegate at all (`children: false`), or when it CAN select a
  class per child — there is nothing to collapse in either case.
- **What this cannot tell you.** No line, by design: a chunk's own required
  capabilities (`required_capabilities`) are declared per chunk at `chunk.declare` —
  nothing outside a chunk, not the routing policy's defaults and not an adapter's own
  notes, declares one as required in advance, so there is nothing for a pre-session
  check to compare against. A line saying so would report no state, so it is stated
  here instead; a quiet result above is not a clean bill of health on capabilities.

An absent or invalid manifest degrades rather than crashing: a manifest that isn't
shipped or installed yet reports nothing beyond the freshness line above (there is
nothing to diagnose); one that reads but fails to parse or validate as a capability
manifest — a stale stamp from a schema that has since changed, most likely — gets one
line naming the parse failure (the parse is strict, and it's the same one
`chunk.declare` uses, so a stamp `doctor` flags is exactly one a declare would refuse),
and every diagnostic above it is skipped rather than reasoning over a manifest known to
be wrong.

### Executor class mapping

One line per portable chunk class (`mechanical`, `balanced`, `deep`), classifying
`mindmeld.toml`'s `[execution.classes]` table itself — not merely tested for presence.
The state this check exists to catch is the one a presence test calls healthy: three
classes all pointing at the same executor resolves without a single error, every
request gets an assignment, and cheap work quietly runs at the expensive tier every
time.

| State | Meaning | Severity |
|---|---|---|
| mapped | a distinct entry in `[execution.classes]` for this class | OK |
| collapsed | mapped, but sharing its executor with another class — named in the line, alongside every class it shares with. A cost decision, not a fault. | warn, repair: `edit [execution.classes] in mindmeld.toml` |
| unmapped | no entry for this class — still runs delegated at that class on the host's default executor, recording a blank executor id | warn, repair: the entries to add |

A machine with no `[execution.classes]` table at all — the default, fresh off `mindmeld
init` — reads as every class unmapped, never as an error. Read-only, like every check
here: there is nothing this check writes, and the fix for either state is a hand-edit to
`mindmeld.toml`, never something `doctor` performs itself.

The unmapped repair is authored by the active adapter, because executor strings are
opaque to the engine and `doctor` never names a model itself. For `claude-code` a machine
with nothing mapped gets, on each of the three lines:

```text
− [doctor] executor class mechanical unmapped — runs delegated on the host's default executor, recording a blank executor — add to [execution.classes] in mindmeld.toml: mechanical = "haiku", balanced = "sonnet", deep = "opus"
```

A suggestion is left out when its executor is already mapped to a different class, since
adding it would collapse the two. The classes left without a usable suggestion are named
at the end — `add to [execution.classes] in mindmeld.toml: deep = "opus"; see your
adapter's notes.md for balanced` — and when none has one the repair is `map
[execution.classes] in mindmeld.toml — see your adapter's notes.md`. All the unmapped
lines of one walk share one repair, so the summary prints it once. The worked example
lives in [config.md#execution](../config.md#execution).

This check alone cannot tell you whether the active `[install]` adapter could actually
*fill* a mapped class — that's a question about the adapter's own declared
capabilities, not about `mindmeld.toml`'s opaque string table, so a mapped or collapsed
line here is silent on it. [Adapter manifest and host diagnostics](#adapter-manifest-and-host-diagnostics)
answers the part of that question the adapter's shipped manifest can answer BEFORE a
session starts: whether a class the routing policy targets or floors is one the
manifest's `classes` list actually offers. It still can't tell you whether a specific,
not-yet-declared chunk will be satisfiable — that remains a per-session fact only
`chunk.declare`'s real manifest and spec set can resolve.

### MCP surface and registration

The last two lines of the walk cover two independent facts about the control plane.

The first names the served `mindmeld mcp` surface from pure data — no server started, no
network:

```text
✓ [doctor] mcp: 21 tools, 12 resources, spawn-session v1 (deprecated, resume-only) + spawn-session v2 + wrap-session v1 (deprecated, resume-only) + wrap-session v2 (deprecated, resume-only) + wrap-session v3, protocol 2026-07-28…2024-11-05
```

Tool count, resource count (resources plus resource templates), every embedded ritual
`(kind, version)` pair, and the protocol versions the SDK negotiates against. v1 has no
warn or error branch here — there's nothing installed yet to classify a served surface
against, so this is always OK; that comparison lands once the thin MCP-adapter skills
ship, and this line is the seam it hangs off.

The second is registration: whether the configured adapter's harness actually points at
this plane, classified the same way skill ownership is — not just "does a file exist"
but "does what's there match what `init` would have written." `doctor` computes the same
`want` the install step does (`host.MCPRegistrationFor`, shared code, not two hand-kept
derivations) and reads the harness's own registration surface (`~/.claude.json` for
`claude-code`) to classify it into one of four states:

| State | Meaning | Severity under `auto` |
|---|---|---|
| current | the registered entry matches `want` exactly | OK |
| stale | an entry exists under our name, but its command/args don't match — usually a moved checkout | warn, repair: `mindmeld update` (by hand under `print`) |
| missing | nothing registered under our name | **error**, repair: `mindmeld update` (`mindmeld init` before the first install; by hand under `print`) |
| unreadable | the surface exists but can't be parsed as JSON, or its shape is wrong | **error**, repair: by hand — an unparseable harness config is never ours to overwrite |

The severity column above is the `auto` column; `[install].mcp` moves it, and the whole
matrix is:

| `[install].mcp` | current | stale | missing | unreadable | exit |
|---|---|---|---|---|---|
| `auto` | OK | warn | **error** | **error** | nonzero on either error |
| `print` | OK | warn | warn | warn | 0 |
| `off` | warn | warn | warn | warn | 0 |

Missing and unreadable are the two errors under `auto`, not warns, and either flips
`doctor`'s exit code the same way an unsupported adapter or a missing skill does.
`mindmeld mcp` is the declared integration edge — the plane every skill and ritual
ultimately reaches through — so a harness that isn't pointed at it is a harness that
can't use mindmeld at all, the same reasoning the adapter-supported check above already
applies to a typo'd `[install].adapter`. The repair is `mindmeld update`, not
`mindmeld init`, because registration is derived fresh from the checkout root on every
run rather than remembered — the same property that lets `update` re-point a moved
checkout without a destructive remove-then-add.

An unreadable surface is its own outcome, distinct from a missing one. If the
registration file can't be parsed — a second JSON document after the first, a trailing
tail of anything but whitespace, a top-level value that isn't an object, or an
`mcpServers` of the wrong shape — this check reports `could not read the mcp
registration at <surface>` with the parse cause, and the repair is by hand. It is never
`mindmeld update`: writing over a document mindmeld just failed to understand would
destroy whatever a reader put there, so the engine refuses the write rather than
rewriting a file it can only partly parse.

Two things degrade this table rather than replacing it. `[install].mcp = "off"` reports
one line carrying both the policy and what is actually on disk —
`mcp registration: off (per config) — not registered`, or `— registered with <adapter>`,
or the unreadable line above — and never fails the run: every observed state is a warn
under `off`, because an opt-out the adopter configured must not turn their machine red. Reporting the observed state alongside the
policy is the point, because "off and registered by hand" and "off and absent" are
different situations and a line that only echoed the policy couldn't tell them apart.
`[install].mcp = "print"` runs the same classification but degrades BOTH errors to warns:
mindmeld never promised to write the registration under `print`, so neither its absence
nor a surface it can't parse is a failed install. For the same reason the repair on a
stale or missing entry isn't `mindmeld update` — update never writes the entry under
`print`, so re-running it can't clear the line — but the hand edit, with the command to
copy coming from update's output:
`register by hand — 'mindmeld update' prints the command in print mode`. The unreadable
line keeps its own by-hand repair under `print`; only its severity moves. And when the configured adapter is unsupported, this check
emits nothing at all; the adapter check above already reported that with its own error,
and a second line repeating it would be noise, not a new fact.

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

`[kb]` (root, owner), `[install]` (skills_dir, hooks, mcp, adapter), `[execution.classes]`,
`[mining].archive_dir`, `[mining].min_idle` (the archive check's active-session grace),
`[mining.recurrence]` (the scoped-collection names) — see
[config.md#kb](../config.md#kb), [config.md#install](../config.md#install),
[config.md#execution](../config.md#execution),
[config.md#mining](../config.md#mining). Full writeup:
[doctor: ownership, not mere existence](../config.md#doctor-ownership-not-mere-existence).

## Related
- [mindmeld update](update.md) — the repair for most `doctor` findings on an initialized
  instance, and for a stale checkout
- [mindmeld init](init.md) — the first install, and the repair before an instance exists
- [Configuration](../config.md) — the full ownership-classification reference
- [Adapters](../adapters.md) — what the active adapter owns
- [Troubleshooting](../troubleshooting.md) — every line above, by symptom
