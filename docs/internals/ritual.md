# internal/ritual

## What it is

`internal/ritual` is the domain organ behind the ritual protocol: spawn-session and
wrap-session modeled as event-sourced runs rather than choreography trapped in skill
prose. A run's state is a pure fold (`Fold`) over an append-only event log; mutating
it is a pure, deterministic `Apply` that refuses an invalid or out-of-order command
with a typed error, never a panic and never a partial write. Everything I/O-shaped —
persistence, subprocesses, output — lives outside this package: it declares the
`Journal` interface it needs (`MemoryJournal`, the shared test fake, and
`FileJournal`, the file-backed implementation `internal/mcp` runs in production) and
otherwise touches nothing but memory. `internal/mcp` is this package's only caller —
it resolves a version, drives `Apply` and `Next`, and translates the result onto the
wire — so this package carries no harness, model, or vendor vocabulary anywhere, not
even in a comment describing behavior.

## Design

### Versions are law, and a run finishes under the one it started with

`Definitions` returns every version this build ships, across both spawn-session and
wrap-session; `DefinitionFor` looks one up by kind and version. Phase order within a
`Definition` is total — no toggling, no reordering — so any structural change (a new
gate, a changed evidence schema, a different required/optional artifact split) bumps
`Definition.Version` and lands as a NEW value rather than an edit to an old one. Prior
versions are never dropped from `Definitions`' return, which is what
`Definition.Deprecated` actually buys: a deprecated version keeps resuming and
advancing exactly as it always did — an in-flight run's own version resolution treats
it the same as any current one — but a fresh `ritual.start` that names or resolves to
it is refused as `unsupported_definition`. Resumable, not startable: an in-flight run
finishes under the rules it actually started with, while a fresh run always lands on
the current shape.

Three versions have shipped so far. v1 is the bare rule: any non-empty, non-null
evidence body satisfies a gate regardless of shape, and no artifact is required — a v1
run has to keep behaving exactly as it always did, since resuming it is the entire
point of keeping it around. v2 replaced that with real, typed evidence schemas and a
required/optional split on each phase's artifacts, closing the hole where a bare
string `"done"` satisfied even the destructive teardown phase. v3 (wrap-session
only — spawn-session has no v3) changed only finalize's evidence schema again, adding
`EvidenceField.RequiredWhen` — see below — so `{"handle": "", "status": "done"}` can no
longer clear a gate whose entire job is confirming a ticket was finalized, while still
giving a legitimately ticketless wrap a real door through rather than a stricter wall
with no ticketless path at all.

### The coordinate: kind lives in the filename, not a path segment

A run's journal lives at `{root}/{project}/{branch}/{kind}.journal.jsonl` — kind is
part of the leaf's own name, never an inserted path segment, so a spawn-session run
and a wrap-session run can coexist at the same `(project, branch)` as two files in one
directory instead of contending for one `journal.jsonl` (which a run written before
this scheme still uses, its kind recovered from the payload rather than the name).

That placement is load-bearing, not cosmetic. Two functions — `projectBranchFromPath`
in this package and `dossierRoot` in `internal/mcp` — derive `(project, branch)` by
walking a fixed number of directory levels up from a journal path, never by reading
the leaf's own name. Inserting kind as its own path segment would silently break
both: `projectBranchFromPath` would start reporting kind itself as the branch, and
`dossierRoot` would resolve a run's dossier one level too deep — and neither failure
is a compile error, since both are just `filepath.Dir` walks over a string. Keeping
kind in the filename instead means the directory depth never changes between the
legacy bare shape and the current kind-qualified one, so neither function ever has
to.

### The reference implementation must not go blind to what the real one catches

`FileJournal.Create` derives a run's journal location from `(kind, project, branch)`,
with kind part of the filename (see above), so its occupancy check has to key on all
three — two different kinds at one `(project, branch)` are distinct, independent
occupants, not a collision. `MemoryJournal.Create`, the session's shared test fake,
has to key its own collision check on the identical `(Project, Branch, Kind)` triple
for the same reason: most tests run against `MemoryJournal`, not the filesystem, and
a fake that goes blind to a defect the real implementation catches makes every test
built on it a false positive. `MemoryJournal.Create` used to key collision on
`head.ID` alone — two distinct, organ-generated run IDs could land at the same
`(project, branch)` undetected in the reference implementation, so `ritual.start`'s
`ErrRunExists` idempotent-restart agreement was only ever exercised against the real
`FileJournal` in tests, never against the fake most tests actually use.

### The evidence model, and RequiredWhen's conditional presence

An `EvidenceSpec` is a phase's schema: a schema name plus a list of `EvidenceField`
entries, each with a `FieldKind` (string, bool, string-list, commit-sha, or url) and,
depending on kind, a length floor or an exact-match constraint. `EvidenceSpec.IsZero`
is the legacy v1 rule: any non-empty, non-null body, any shape.

`EvidenceField.RequiredWhen` makes a field's optional flag conditional instead of
fixed: it names a sibling field (`FieldCondition.Field`) and the values
(`FieldCondition.OneOf`) that make the condition fire. When it fires, the field is
mandatory regardless of its own optional flag; when the sibling is absent or holds a
value outside that set, the field falls back to its own flag as if RequiredWhen
weren't set. This is resolved exactly once, inside `EvidenceSpec.Validate`, before
`EvidenceField.validate` ever runs — presence is `Validate`'s decision, and a
conditional presence rule belongs at the level that decides presence, not the level
that already assumes it.

`wrapSessionV3`'s finalize phase is the concrete case this exists for: its schema
carries a required `outcome` of `finalized`, `no-ticket`, or `dropped`, and
RequiredWhen makes `handle` mandatory when `outcome` is `finalized` OR `dropped`,
`status` mandatory only when `outcome` is `finalized`, and `reason` mandatory when
`outcome` is `no-ticket` OR `dropped` — one gate, three legitimate shapes, instead of
either demanding fields a ticketless (or already-dropped) wrap can never honestly
supply, or accepting a value that isn't actually evidence of anything. `dropped` is a
third *outcome*, not a fourth `status` value: a ticket a human moved to `dropped` was
never finalized by this run — the engine itself refuses to write a status over a
human's drop — so there is no finalize result for `status` to carry back; `outcome`
says so directly instead of folding it into a field that would otherwise imply a real
finalize call happened.

### `Create`'s lock covers check-through-publish, and only that

`FileJournal.Create` used to check for a legacy `journal.jsonl` at a coordinate and
then publish the kind-prefixed journal as two separate, unlocked steps — a real
window in which another writer could publish a same-kind legacy journal in between,
leaving both names occupying the same `(project, branch)` at once. `lockRunDir`
already existed, guarding only the zero-byte-reclaim retry further down; it's now
held from before the legacy check through the end of `Create`'s own publish
attempt(s), so the whole check-then-publish sequence is one atomic unit against
every other writer that goes through this same `Create`.

What that proves is narrower than "two same-kind journals can never coexist": a lock
only synchronizes a writer that takes it. A mixed-version writer that never heard of
the kind-prefixed name isn't coordinated by any lock on this side — it can still
publish a legacy `journal.jsonl` unlocked, exactly as before.

### The one-active-run-per-kind guarantee has a quiescent upgrade boundary

The lock proven above serializes writers that take it — it says nothing about a
writer that doesn't. A pre-existing Mindmeld MCP process running an older build never
heard of the kind-qualified journal name and never takes this lock, so the
one-active-run-per-kind guarantee cannot be enforced across that boundary: two
independent reviews reproduced a legacy and a current journal landing concurrently for
one kind, exactly the gap the paragraph above already concedes.

> Before using the kind-qualified journal format, stop or restart every older
> Mindmeld MCP process with access to the same active dossier root. The
> one-active-run-per-kind guarantee applies only after that cutover; old and new
> writers are not coordinated across it.

That is a stated boundary, not an enforced invariant — the code makes no attempt to
detect a live legacy writer and refuses nothing on its account. The operator-facing
procedure lives where upgrades are documented, in
[`mindmeld update`](../commands/update.md#upgrading-across-the-journal-format-change). An overstated
guarantee is worse than a named limitation, which is why this is written down here
rather than left to be discovered. The sibling archive root (see
`skills/wrap-session/references/teardown.md`'s "Dossier archival" section) keeps this
wording simple on the other side of a run's life: an archived journal has left
`dossier_dir` entirely, so it never re-enters this lock's domain and never needs a
boundary statement of its own — occupancy, and the guarantee above, apply only to
what's still live.

### Archive receipts live in the active dossier root, not the archive root

This organ's runs live under three distinct roots: the active dossier root
(`dossier_dir` — every live journal `Runs()` discovers), the archive root
(`dossier_archive_dir`, or its default sibling — where `ritual.archive` relocates a
wrapped run's ENTIRE coordinate directory, journal and dossier content alike), and
the KB root (a separate concern this package never touches directly). A run's
archive receipt — `ritual.ArchiveReceipt`, the durable record `RitualEngine.Archive`
writes so a lost response or a crash mid-move is recoverable — lives in a fourth
place that belongs to neither: a flat, hidden directory directly under the ACTIVE
dossier root, `{dossier_dir}/.archived/{run_id}.json`, never inside the archive root
and never inside the coordinate directory that just got moved out from under it.

That placement is deliberate, not incidental, and it is the one exception to
"archives never come back into discovery" this package makes: a receipt is an
operational record ABOUT a run, not the run itself, so the ONE structure that still
needs to answer "what happened to this run" — the plane serving `ritual.archive`
retries and every other verb's `run_unknown` refusal — has to keep looking in the
place it already discovers everything else, the active root, rather than reaching
into the archive root on every lookup. Reaching into the archive root would also put
this package back in the business of walking archived content to answer a live
question, exactly the coupling the sibling-root split exists to avoid — see
`skills/wrap-session/references/teardown.md`'s own "Archived material is not gone,
only off the plane" paragraph for why an archive reader, if one is ever built, reads
the archive root directly rather than asking `dossier_dir`'s discovery walk to widen
back into scanning it.

Putting receipts under the active root does NOT put archived runs back into
discovery. `.archived` is a name `Runs()`'s own walk (`journal_walk.go`,
`isJournalName`) never matches — it filters by basename shape
(`{kind}.journal.jsonl` or the legacy bare `journal.jsonl`), and a receipt's
`{run_id}.json` matches neither — so an archived run is exactly as unreachable
through `Runs()`, `ritual.status`, or `ritual.resume` as it always was; the receipt
only ever surfaces through the specific, narrow paths built for it
(`Journal.ArchiveReceipt`/`ArchiveReceipts`, consulted by `RitualEngine.Archive`
itself and by every other verb's own `run_unknown` construction). `.archived` sits at
the SAME directory depth as every `{project}` directory `Runs()` walks, as a
sibling, never inside one — so relocating a `(project, branch)` coordinate to the
archive root never carries a receipt away with it, and archiving a second run at a
reused slug never collides with the first run's own still-active receipt.

### Directory creation goes through the confined primitive, not a raw `os.MkdirAll`

The coordinate's directory has to exist before `lockRunDir` can open (and, on a
first writer, create) its own lock file inside it. That step goes through
`kbpath.EnsureDir` — the same segment-by-segment confine-then-create walk
`internal/store/fs`'s own writer uses — never a raw `os.MkdirAll`. A raw
`os.MkdirAll` traverses a symlinked intermediate segment (a project directory
planted as a symlink escaping the dossier root, say) exactly like a real directory,
and creates everything "under" it outside `root` — reopening the confinement hole
an existing escape-refusal test already pins, since this step runs before
`store.Create`'s own confined path-writing chain ever gets a chance to refuse.

### Drafted-run provenance is journaled at start

`RunStartedPayload.DraftedRun` (mirrored onto `Run.DraftedRun` by the fold) is set
at `ritual.start` and folded from seq 1 the same way `RunStartedPayload.DefVersion`,
`RunStartedPayload.Scope`, and `RunStartedPayload.Ticket` are. It records whether
THIS run's own `ticket.create` minted the ticket it's pointed at, as opposed to an
already-existing ticket the run was merely pointed at. `ticket.finalize`'s own
drafted-run argument picks between rewriting a ticket's description
(drafted-this-run) and appending an `## Outcome` section (pre-existing) —
journaling the answer durably, rather than leaving it to be inferred later or
carried only in chat context, means a host resuming a run with no prior
conversation doesn't have to guess at that destructive-if-wrong choice.

### Served resources answer "what has this phase's gate recorded"

`Action.Resources` (built by `resourcesFor`, threaded unchanged onto every fallback
rung) lists what the current phase's gate already covers. For each kind the phase
produces it serves the ledger entries recorded since the phase was entered — the same
`Seq >= PhaseEnteredSeq` cut `HasArtifactSince` makes for the gate — minus anything
superseded, deduped by artifact ID and then by URI within the kind (the last recording
wins, and sits at its later `Artifact.Seq`). The URI pass matters because the engine mints
a fresh ID per `ritual.submit`: a driver reads the list as the set of things the gate
covers, and a file recorded twice is one thing. Order is the phase's `PhaseDef.Produces` order, then `Artifact.Seq` within a kind. Nothing
recorded yet is `nil`, never a slice of empty refs.

How many of a kind survive is declared per kind, not inferred from `supersedes`:

| Kind | Cardinality | Why |
|---|---|---|
| `manifest`, `plan`, `review-findings`, `handoff` | singular — latest only | each new one revises the one before |
| `adr`, `contract`, `chunk-brief`, `chunk-report`, `spec` | plural — every entry | each is a distinct seam, decision, chunk, or spec |

`ArtifactKind.Plural` is a closed switch; every other kind, including any string
`ritual.submit` let through, is singular, so the conservative answer never fans out.
It's declared because a plural kind's entries don't point at each other — two contracts
for two seams never supersede anything — so `supersedes` alone can't tell "revision" from
"sibling." Plural kinds are uncapped: in `execute` that's a brief and a report per
recorded chunk, and a revision attempt's report that should replace an earlier one is
the driver's to mark with `supersedes`.

Supersession is still ledger-wide and cross-kind, as `Run.LatestArtifact` computes it.
If it would hide every in-phase entry of a kind (a cycle), that kind is served with
supersession ignored — a kind the phase holds is never reported empty.

This replaced one-ref-per-kind via `LatestArtifact`, which was run-wide rather than
phase-scoped and right only for singular kinds. It collapsed a dossier's several
contracts and `execute`'s several briefs and reports to one each, and it leaked a
dossier's contract into `contracts-landing` while that phase's gate still refused for
lack of a landing one. The behavior change to expect: **`contracts-landing` serves
nothing until a landing contract is recorded.** The dossier's contracts stay reachable
through the run's artifacts resource, which is still the whole ledger.

## Invariants

- Phase order is total within a `Definition`; a structural change of any kind bumps
  `Definition.Version` rather than editing a shipped one, and every version
  `Definitions` has ever returned stays in that return forever.
- A `Definition.Deprecated` version resumes and advances exactly like any other; only
  a fresh `ritual.start` naming or resolving to it is refused, as
  `unsupported_definition`.
- `EvidenceField.RequiredWhen` is resolved exactly once, in `EvidenceSpec.Validate`,
  before `EvidenceField.validate` assumes the field is present.
- A journal's kind lives in its filename (`{kind}.journal.jsonl`), never an added path
  segment — `projectBranchFromPath` and `internal/mcp`'s `dossierRoot` both assume a
  fixed directory depth above the leaf, and neither recompiles nor fails loudly if
  that depth changes.
- `Journal.Create`'s collision key is a run's `(Project, Branch, Kind)`, never its ID
  alone, in both `MemoryJournal` and `FileJournal` — an ID collision alone must never
  silently clobber a different run's history.
- `FileJournal.Create` holds `lockRunDir`'s lock across its entire legacy-check +
  publish sequence, never as two separate, unlocked steps — proving only that a
  writer taking the lock is coordinated with every other writer that also takes it.
- Directory creation ahead of that lock goes through `kbpath.EnsureDir`, never a raw
  `os.MkdirAll` — the confined, symlink-safe primitive `internal/store/fs` already
  uses, so a symlinked intermediate segment can't route a create outside the
  dossier root.
- `RunStartedPayload.DraftedRun` is journaled at `ritual.start`, never inferred
  later — a resumed host must be able to answer "did this run mint its own ticket"
  without guessing at `ticket.finalize`'s rewrite-vs-append choice.
- `Run.LatestArtifact` never reports "not found" for an `ArtifactKind` the ledger
  actually holds: a genuine `Artifact.Supersedes` cycle falls back to the
  last-recorded entry of that kind rather than filtering every entry away.
- `Action.Resources` never lists an artifact recorded before `Run.PhaseEnteredSeq` — the
  gate's own cut — and a singular kind serves at most one ref while a plural kind
  (`ArtifactKind.Plural`) serves every surviving entry; fallback rungs carry the
  identical slice.
- Evidence bodies live in `Run.Evidence` in full; what a caller renders from them (for
  example, omitting bodies from a polled status view) is that caller's own wire-shape
  choice, not a rule this package enforces.
- An `ArchiveReceipt` lives under the ACTIVE dossier root (`{dossier_dir}/.archived/`),
  never the archive root and never inside a coordinate directory — see "Archive
  receipts live in the active dossier root, not the archive root" above.
- `RitualEngine.Archive` writes a receipt twice — `ArchivePending` before the move,
  `ArchiveComplete` after the move AND `Journal.Forget` have both succeeded — never
  once; a crash between those two writes is exactly what a retry's own
  destination-existence check (never a guess) resolves.
- The move carries the whole coordinate directory, so one archive writes one receipt per
  journal it carries, each in its own `{run_id}.json` with that run's own kind,
  definition version, ticket, and revision. `subject_run_id` is the run whose archive
  call caused the move (equal to `run_id` on the subject's receipt) and names the
  destination, `{project}/{branch}/{subject_run_id}`; `Validate` pins `destination` to
  exactly that, with the subject held to the same single-segment floor as every other
  path component. The field is required: a receipt without it is invalid, never an
  implied "this run is its own subject".
- A retry resumes the first attempt's destination, whichever run's id it comes in
  through. When a pending receipt exists, `RitualEngine.Archive` takes the move's
  destination name (and so its `.tmp-<subject>` staging name) from the receipt's
  subject, which is what lets a retry through a sibling clear the same stale staging
  copy a crashed cross-device attempt left behind.
- Sibling recovery is per receipt, not per archive. Recovery for any one receipt reads
  that run's own journal (`{kind}.journal.jsonl`) inside the destination and validates
  it against that receipt alone (`ValidateArchivedJournal`); no recovery path completes
  a receipt on the strength of a journal chosen by directory listing or of another
  receipt's say-so, which keeps the trust surface to what the receipt itself names.
  Completes
  are written siblings first and the subject last, stopping at the first failure, so a
  crash leaves the subject's receipt, whose driver holds the retry, as the last pending
  one.
- A destination that exists is a refusal unless a pending receipt of the run being
  archived names it. That is the authority to finish a cross-device move that promoted
  its copy and died before removing the source (the finish-promoted repair in
  `internal/dossiermove`), and it still
  has to prove itself first: a pending, agreeing receipt for every run at the
  coordinate, every destination journal validating against its receipt, and the
  destination a faithful copy of the source. Failing any of those is the same refusal,
  with nothing removed.
