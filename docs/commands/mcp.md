# mindmeld mcp

Every other command in this binary is something a human or a hook runs directly.
`mcp` is different: it's the control plane a harness talks to instead — the ritual
protocol (ADR 003) that turns spawn-session and wrap-session into typed tool calls and
gated protocol states, plus the `ticket.*` and `recall.*` mechanics those rituals lean
on, all served over the Model Context Protocol (the official Go SDK, ADR 004).

## Usage

```bash
mindmeld mcp [--kb PATH]
```

- `--kb PATH` — override the KB root for this run (flag beats `[kb].root`, same
  resolution every other organ's `--kb` flag uses)

There are no subcommands. Once started, `mcp` serves stdio until the client disconnects
or the process is signaled — the same shape any MCP host expects from a stdio server.

## The tool surface

Nine ritual verbs, five chunk verbs, plus the ticket and recall mechanics
families — 21 tools in all:

- `ritual.start` — begin a run (`kind`, `project`, `branch`, optional `ticket`,
  `drafted_run`, `capabilities`, `def_version`, `idempotency_key`, `agent`, `harness`).
  `drafted_run` is `true` when THIS run's own `ticket.create` minted `ticket`, as
  opposed to an already-existing ticket the run was merely pointed at — journaled
  verbatim onto the run so a later `ritual.status`/`ritual.resume`, with no chat
  context at all, can read the same answer back instead of guessing which mutation
  `ticket.finalize`'s own `drafted_run` argument needs. Omitted, it defaults to
  `false`.
  `capabilities` is **required-present**, not optional: a host must declare it either
  way, either the capabilities it has or an explicit `[]` for none. An omitted (or
  explicit JSON `null`) `capabilities`, or one carrying an unrecognized member, is
  refused as `unsupported_capability` — the former names no offending values, the
  latter carries them in `unknown` — so a host that never considers the question
  cannot silently start a run on the inline path. An unknown `(kind, def_version)`
  pair, or an explicit request for a deprecated version, is refused as
  `unsupported_definition` with the supported (non-deprecated) list; omitting
  `def_version` (or passing `0`) resolves to the latest shipped non-deprecated version
  for `kind`. Retrying `ritual.start` against a `(project, branch)` that already has a
  matching run is idempotent — it returns that run's real current status instead of
  refusing, and a retry carrying an already-seen `idempotency_key` returns that
  original call's result unchanged, even when the retry's own capability declaration
  would be refused on its own merits. That guarantee covers a *present* capability
  declaration only: a retry that omits `capabilities` entirely is refused as
  `unsupported_capability` by schema validation before any handler runs, so it never
  reaches the replay path. A
  `(project, branch)` that already has a *different* run — a mismatched kind, version,
  ticket, or capability set — comes back `run_conflict`, naming the mismatched fields
  and the existing run's id, with that run's own current status attached so a caller
  can decide to resume it, restart elsewhere, or escalate without a second round trip.
  `project` or `branch` must each be a single path segment (no `.`, `..`, or path
  separator) — the run-coordinate contract's own floor: the engine refuses a
  malformed coordinate rather than slugifying it on the caller's behalf, so an
  unstripped branch like `as/MIN-61_feature` comes back `invalid_coordinate`, naming
  the offending field in `fields` and the value in `message`, before anything is
  written. The value is redacted like any other machine path on the wire when it
  looks like one (an absolute path sent where the slug belongs, the likeliest way to
  hit this refusal) — a slug-shaped value survives untouched, since it's the case a
  caller can actually act on.
- `ritual.status` — fold a run's journal and return its current state, addressed
  EITHER by `run_id` OR by the full `(project, branch)` pair — a fresh host with no
  chat context and no run id can still ask "what's running on this branch." Neither,
  or only half the pair, is refused as `run_unknown`, never guessed; coordinates
  matching no run return the same refusal shape as an unknown id.
- `ritual.list` — discover runs with no run id at all: every run under the configured
  dossier root, optionally filtered by `project`/`branch`, wrapped runs excluded
  unless `include_wrapped` is set. This is the fresh-host discovery path
  `ritual.status` still needs a coordinate for — a new terminal, a restarted server, a
  different machine's agent has nothing else to key on. A journal entry that can't be
  folded (a corrupt or partial write) is still surfaced, flagged `corrupt` with a
  reason and no run id, rather than silently omitted — "nothing running here" must
  never stand in for "something's running here and it's broken." An unrecognized
  `kind` filter refuses the same way `ritual.status` does — a structured `error` on
  the response, naming the offending value — rather than the bare, unstructured call
  failure it used to be, so both discovery verbs are consistent in when they refuse
  and what they say.
- `ritual.resume` — identical to `ritual.status` by `run_id`, except it also emits a
  report line.
- `ritual.submit` — the one mutation channel for satisfying an action (`evidence`),
  answering a question (`answer`), clearing a blocker (`unblock`), or recording a
  produced artifact (`artifact`).
- `ritual.approve` — record a human gate approval, naming the gate being approved.
- `ritual.block` — record a blocker, with an optional `question`. When `question` is
  set, the server generates a question ID and journals the new question and the
  blocker atomically, in one batch — a blocker can never exist half-linked to a
  question that failed to land.
- `ritual.wrap` — finalize a run once its terminal phase's gate is genuinely
  satisfied (`run_id`, `expected_revision`, `idempotency_key` — the same shape as
  `submit`/`approve`/`block`, no payload beyond that). Reaching the terminal phase is
  never enough on its own: a `GateApproval` terminal needs a recorded approval, a
  `GateEvidence` terminal needs submitted evidence: `ritual.wrap` against either
  without it comes back `gate_unsatisfied`.
- `ritual.archive` — relocate a wrapped run's dossier directory to the archive root
  and release its `(project, branch)` coordinate for reuse (`run_id`,
  `expected_revision`, `idempotency_key`, same shape as `ritual.wrap`). Callable only
  once `ritual.wrap` has returned `wrapped: true` for this run — archival is terminal,
  never a mid-run step, and unlike every other mutating verb it appends nothing to the
  run's own journal, because that journal is what's about to move. Refuses rather than
  partially acting: a run that isn't wrapped yet, or a sibling run at the same
  coordinate that isn't (naming that sibling's kind and id), both come back
  `gate_unsatisfied`; an archive root that overlaps the dossier root — in either
  direction, symlinks resolved before the comparison, or a real directory from
  inside the dossier tree found renamed into the destination chain mid-walk — comes
  back `archive_root_overlap`, naming the two config keys, never a resolved path;
  a segment of the archive destination the engine cannot open without following a
  link (a symlink, or anything else a no-follow open refuses) comes back
  `archive_path_unsafe` instead — deliberately never `archive_root_overlap`, since
  the engine never learns where such a link actually points and won't report a
  confirmed dossier-root overlap it hasn't confirmed; a
  destination that already exists comes back `archive_destination_exists` rather than
  nesting or merging — except one case the engine finishes itself: a cross-device move
  that promoted its verified copy and died before removing the source leaves both
  copies and a `pending` receipt naming the destination. A retry (by the archived
  run's id or a sibling's) proves the destination a faithful copy of the source (same
  entries, kinds, sizes, and hashes) and its journals the receipts' runs, then removes
  the source, completes the receipts, and replays; anything that doesn't verify is
  still `archive_destination_exists`, with nothing removed. On success the run is
  gone from the plane exactly as terminally as a wrap makes it done: every later
  `ritual.status`/`ritual.resume`/run-id lookup/artifact resolution for it returns
  `run_unknown`, in the process that archived it and a freshly started one alike, and
  a new run may open at the released coordinate immediately.

  Archival writes a durable receipt before it ever moves anything, and rewrites it
  once the move and the coordinate's cache-drop have both actually succeeded — the
  recoverable half of a call whose own response can still be lost after the work is
  done. `idempotency_key` IS consulted here, but per `run_id`, not per key the way
  `ritual.start`/`ritual.submit` compare it: a retry naming the SAME `run_id` — with
  the original key, a different one, or none at all — replays the same receipt rather
  than attempting a second move or refusing `run_unknown`, and a response carries
  `replay: true` whenever it describes work this call didn't perform (the receipt was
  already complete, a resume found the move already done and only needed to record
  that, or the engine finished a promoted copy as above). A replay carries what the
  receipt can vouch for — `run_id`, `kind`, `def_version`, `project`, `branch`,
  `ticket`, `revision`, `phase` (the definition's last phase), `wrapped: true`,
  `archived: true` — and omits what it doesn't record (`capabilities`, artifacts,
  evidence, approvals). A replay checks `expected_revision` against the revision in
  the receipt, since the run itself is gone: a retry of the same call carries it
  unchanged, and any other value is `revision_conflict` reporting the archived
  revision, never a replayed success. `receipt` — `run_id`, `subject_run_id`, `kind`,
  `def_version`, `project`, `branch`, `ticket`, `revision`, `archived_at`,
  `destination` (relative to the archive root, never an absolute path),
  `idempotency_key`, `state` — rides every successful `archived` response, fresh
  completion and replay alike.

  The move carries the whole `{project}/{branch}` directory, so every wrapped sibling
  journal in it leaves the plane with the archived run, and each one gets a receipt of
  its own: its own `run_id`, `kind`, `def_version`, `ticket`, and `revision`, all
  naming the one directory the move produced. `subject_run_id` is the run whose
  archive call caused the move and `destination` is
  `{project}/{branch}/{subject_run_id}`; the two ids are equal on the archived run's
  receipt and differ on a sibling's. Every receipt is written `pending` before the
  move and `complete` after it (siblings first, the archived run's last), and each is
  independently finishable: a retried `ritual.archive` for a sibling's `run_id` — or
  `ritual.status` for it, by id or by `(project, branch, kind)` — answers exactly as it
  does for the archived run.

  A `run_unknown` refusal — from `ritual.archive` itself when neither a live run nor
  any receipt exists for the given `run_id`, or from ANY other verb addressing a run
  that turns out to be archived — carries that same receipt shape under `archived`
  when one exists: by `run_id` for `ritual.status`/`ritual.resume`/`ritual.submit`/
  `ritual.approve`/`ritual.block`/`ritual.wrap`, and by `(project, branch, kind)` for
  `ritual.status`'s coordinate lookup (the most recent COMPLETE receipt only — never a
  receipt still `pending`, and never attached at all without a `kind` to disambiguate,
  since one coordinate can have hosted more than one ritual kind over its lifetime).
  The run itself stays exactly as unreachable as `run_unknown` always meant; `archived`
  only answers WHY nothing is there instead of leaving a caller to guess between
  "never existed" and "already archived" — and a live run that has since claimed the
  released coordinate is returned normally, with no receipt involved at all.
- `ticket.create` / `ticket.fetch` / `ticket.update` / `ticket.finalize` / `ticket.list`
  — the KB-ticket mechanics, engine-owned (no MCP ticket connector needed for the
  `kb` project-management provider). `ticket.create` takes an optional
  `idempotency_key`: the same key with the same `project` returns the ticket already
  on disk instead of minting a second one, regardless of `title`, and the same key
  with a different `project` is refused rather than silently answered from the wrong
  ticket — and, since a keyed create's whole job is proving that key's uniqueness, an
  unreadable ticket file in the request's own project refuses the call outright rather
  than silently being treated as "not a match" (see the refusal list below). A replay
  re-runs the landing pass against the existing file, so its warnings reflect the
  ticket's CURRENT landing state rather than whatever the original call happened to
  report. Every ticket response carries a `revision`; `ticket.finalize` takes an
  `expected_revision` that compares against it under the same lock the write itself
  takes — required whenever `drafted_run` is true, since that branch rewrites the
  whole body — and refuses (nothing written) on a mismatch. `ticket.update` takes an
  optional `reason`: required (8 characters minimum) whenever `status` moves to
  `"dropped"`, refused before any file is touched otherwise; persisted as frontmatter
  `dropped_reason` and returned on every ticket response as `dropped_reason`, cleared
  by a later move out of `"dropped"`. See [rituals/kb-ticket](../rituals/kb-ticket.md)
  for the full contract.
- `recall.query` / `recall.pattern` — semantic KB recall and manifest-aware pattern
  recall, the same ranking/narrowing internal/recall runs for every other organ.
- `chunk.declare` / `chunk.claim` / `chunk.report` / `chunk.reroute` / `chunk.affirm` —
  the durable chunk-scheduling verbs a `spawn-session` run's `execute` phase dispatches through:
  declare (or re-declare) a chunk DAG and its capability manifest, claim a chunk with
  a proposed `assignment`, report how an open attempt closed, or reroute a chunk's
  execution request after a trigger fires, or record the user's decision that a stale
  chunk stays accepted. `chunk.declare`'s `manifest` is optional: omit it (or pass
  `null`) and the engine declares the active adapter's stamped manifest
  (`adapters/<adapter>/manifest.json` in the KB), clamped to the run's capability
  ceiling — a run started without `delegation` gets a childless manifest. An explicit
  `manifest` must be a full manifest that only narrows the stamp; one that claims more
  (a flag the stamp lacks, a higher `max_concurrency`, a class or `provided_*` entry it
  doesn't list) is refused `manifest_exceeds_host`, naming the field, and is never
  clamped — past that check, a manifest wider than the run's ceiling is refused
  `gate_unsatisfied` as always. The stamp is read on every non-replayed declare; one that
  is missing, symlinked, unreadable, or fails a strict parse (an unknown key, trailing
  data, an invalid manifest) is refused `manifest_unavailable`, naming the KB-relative
  path and the cause — run `mindmeld update`, or, for a hand-edited copy that lost its
  marker, fix the copy (`update` won't overwrite it). The declare event journals where
  the manifest came from (`adapter` or `explicit`, the adapter name, the stamp's
  version). `chunk.report` additionally takes an
  `evidence` object (typed proof — schema, the command run, whether it passed, a
  short detail — alongside the freeform `report` prose) and a `disposition`
  (`applied` | `declined` | `superseded`, with a required `disposition_reason` when
  it's `declined`) recording what this attempt did about the revision request the
  previous attempt on the same chunk left outstanding. Neither is unconditionally
  optional: an `accepted` outcome is refused unless `evidence` is present with
  `passed` true, and `disposition` is required on the attempt that follows one closed
  `revision` — both are optional on any other report. `chunk.reroute` carries the
  same `disposition`/`disposition_reason` pair and is refused without one on the same
  terms, whenever it is the call that actually closes that attempt — the obligation
  belongs to whichever attempt is following a revision, not to `chunk.report`
  specifically, so a driver cannot route around it by closing with `chunk.reroute`
  instead; a reroute against an attempt already closed some other way has nothing
  left to close and carries no such obligation. When the chunk's own
  `report_requirements` is non-empty, an `accepted` outcome is additionally refused
  unless the resolved `report` carries each requirement as its own markdown heading
  with real content beneath it, naming whichever requirement is missing or empty.
  `chunk.reroute` also takes an optional `target` (`{class?, min?}`, a routing target) and
  an optional `idempotency_key`. A reroute whose offer nothing on the current manifest can
  fill — no delegated class it lists at or above the offer's minimum and floor, and no
  main-thread rung the offer carries — is refused as `chunk_unassignable` before anything
  is journaled. The refusal names the class it would have pointed at and lists every class
  the host can fill for that chunk, each with the executor `[execution.classes]` maps it
  to (left off when unmapped), so the user picks a model that exists; the reroute is then
  re-issued with the pick as `target`. A `target` replaces the chunk's routing entry for
  that trigger for this reroute only. It is held to what an entry in the routing table is
  (`RoutingTarget` validity, never below the chunk's `floor`, a `contract-question`
  returning only to `main-thread`), and the `chunk-rerouted` event records it as the
  explicit target. Unlike a table-driven reroute, the named class must itself be fillable
  on the current manifest: a class-only `target` needs that exact class, `class` plus `min`
  needs at least one class in `[min, class]`, `main-thread` needs the manifest to offer it,
  and a `min`-only `target` needs a delegated class at or above it. A main-thread rung in
  the chunk's fallback does not make `{class: deep}` acceptable on a host that lacks deep;
  it is refused as `chunk_unassignable` with the same list of fillable classes. A `contract-question`
  reroute with no `target` is never refused for fillability. `target` is part of the
  idempotency fingerprint.
  Rerouting a chunk that was accepted reopens it, and marks **stale** every transitive
  dependent whose latest attempt is accepted: `ChunkStatus` gains `stale` and
  `stale_upstream` (the chunk whose reopening did it). A stale chunk is still accepted; it
  is waiting on the user. Each is decided one of two ways: `chunk.reroute` reopens it (and
  marks its own dependents in turn), or `chunk.affirm {run_id, expected_revision, chunk_id,
  reason, idempotency_key?, agent?, harness?}` records that it stays accepted and clears the
  mark. `reason` is required, the chunk must currently be stale, and `chunk.affirm` is legal
  in the same phase window as the other chunk verbs. `ritual.wrap`, the approval or
  evidence that leaves the last chunk-work phase, and the `wrap-run` action `next` serves
  all refuse while any chunk is stale, naming each with its upstream. Neither verb is ever
  called on the user's behalf.
  All five share `ritual.*`'s `run_id` + `expected_revision` contract and return one
  shape, `ChunkOut` — manifest, every declared chunk's spec/attempt ledger/derived
  state in topological order, and the ready set. Each chunk's derived state carries a
  `blocked_reason` whenever `state` is `blocked` — the same wording `chunk.claim`
  would refuse with if that chunk were claimed right now, since both read the one
  readiness definition ([internals/chunk.md](../internals/chunk.md)). Three refusal
  kinds are scoped to this surface: `chunk_unknown` (the id isn't in the declared
  DAG), `chunk_unassignable` (the proposed assignment doesn't satisfy the chunk's
  request — including a chunk requiring `durable-workers` proposed in anything but
  `delegated-durable` mode, or a `chunk.reroute` whose offer the host cannot fill), and
  `chunk_conflict` (a `chunk.affirm` against a chunk that is not stale, or the chunk isn't ready right now —
  an open or already-accepted attempt against it, another chunk's open attempt with
  an overlapping scope, an open barrier or serialized hold — a re-declare that would
  edit a frozen field, orphan recorded history, or propose a manifest that pulls
  capability out from under attempts already open (a `max_concurrency` below the
  number already open, `per_child_class` turned false while open delegated attempts
  already carry different classes, `children` turned false while one is still open,
  `classes` simply omitting a class an open delegated attempt is currently running,
  `durable` turned false while a delegated-durable attempt is open, a
  `per_child_class`-false manifest whose one class differs from the class pinned under
  the current `per_child_class`-false manifest, `main_thread`
  turned false while a main-thread attempt is open, or `provided_tools`/
  `provided_context` dropping an entry an open attempt's own chunk requires), a claim
  that would exceed the manifest's `max_concurrency` — every open attempt counts
  toward that ceiling, main-thread included — or its inability to select a class per
  child, or, when `per_child_class` is false, a claim whose class differs from the one
  the first delegated attempt under that manifest pinned (declaring a per-child manifest
  ends the pin), or whose recorded `executor` disagrees with an earlier delegated
  attempt's own — one class and one recorded worker while the host cannot select per
  child, and an empty `executor` on either side (recording off, or a host
  that never named one) contradicts nothing) — alongside the existing
  `revision_conflict`/`gate_unsatisfied`/`run_unknown`/`internal`. `gate_unsatisfied`
  also covers `chunk.declare`-specific refusals the routing policy and the domain
  decide before a spec set is ever journaled: a `required_capabilities` name the
  proposed manifest itself doesn't back (`durable-workers` needs `manifest.durable`,
  `delegation` needs `manifest.children`, on top of the run's own declared
  ceiling), a spec that states a `floor` other than the one the routing policy
  composes for it (engine-owned — the policy composes it from `risk` and the chunk's
  other declared properties; a floor equal to the composed one is the server's own
  output and is accepted, so the specs from `mindmeld://run/{run_id}/chunks` can be
  re-declared verbatim), a routing entry that could ever land a chunk below its
  composed floor, a `contract-question` routing entry on a spec naming anything but
  `main-thread`, or a policy file that does not parse — including a `contract-question`
  rule that is anything but `class: main-thread` with no `min` — since a contract
  question always returns to the main thread regardless of what is declared. See [internals/chunk.md](../internals/chunk.md)
  for the full floor/reopen/capability rules these refusals enforce.

Every `ritual.*` call returns the complete envelope: identity (`run_id`, `kind`,
`def_version`, `project`, `branch`, `ticket`, `drafted_run`, `capabilities`), state
(`revision`, `phase`, `wrapped`), history (`artifacts`, `evidence`), decisions (`questions` — open
AND answered, each carrying its `answer` and an `answered` flag, so a resuming host
inherits what was already decided instead of re-asking it), open `blockers`, and
recorded `approvals`. `next` lists typed next actions — id/type/params/requires/
fallbacks/resource URIs. A refusal a client can recognize and recover from (a stale
`expected_revision`, a gate that isn't satisfied yet, an unsupported or deprecated
ritual version, an unrecognized `run_id`, a `(project, branch)` conflict) comes back as
this same shape with an `error` field naming the kind — `revision_conflict |
gate_unsatisfied | run_unknown | run_conflict | ambiguous_run |
unsupported_definition | unsupported_capability | invalid_coordinate |
archive_root_overlap | archive_destination_exists | archive_path_unsafe |
idempotency_conflict | manifest_unavailable | manifest_exceeds_host | internal` —
never a bare failed call that throws away the run's current state. A version
refusal carries the supported list; a `run_conflict` carries the mismatched field
names and the existing run's id; an `ambiguous_run` refusal comes from a
coordinate lookup that matched more than one run because two ritual kinds share a
branch — every match is named, by kind and run id, in `message`, AND structurally in
`candidates` (one `{kind, run_id}` entry per match, in the same deterministic order
`message` lists them in), so a driver doesn't have to parse English to act on the
refusal; it carries **no** run id of its own in `existing_run_id`, since there is no
single one to carry; pass `kind` to narrow the lookup, or address the run directly
by `run_id`; an `unsupported_capability` refusal over an unrecognized member carries the
offending values in `unknown`; an `invalid_coordinate` refusal carries the one
offending field name (`project` or `branch`) in `fields`, with the exact value
named in `message`; `archive_root_overlap`, `archive_path_unsafe`, and
`archive_destination_exists` are `ritual.archive`'s own three shapes, carrying no
structured extras beyond `message` — the first names the two config keys involved,
never a resolved path either side of the comparison; the second names only the
config key context, since it never learns (and so never claims) where the unsafe
segment resolves; the third says only that the destination is taken, since
which run got there first isn't this refusal's business to disclose.

An `idempotency_key` replays only the request it was first used for. On `ritual.submit`,
`approve`, `block`, `wrap` and `chunk.declare`, the server records a fingerprint of the
caller's request and the `expected_revision` it carried alongside the key; a retry with
the same key, the same request, and the same `expected_revision` returns the original
result and writes nothing, while the same key with a different request — or the same
request at a different `expected_revision` — comes back `idempotency_conflict` with the
run's current state, and writes nothing. Pick a fresh key for a new request. The
fingerprint covers what the caller sent, not what the server built from it, so a retry of
`ritual.block` (which mints ids) or of a `chunk.declare` the routing policy rewrote still
replays. A key recorded before fingerprints existed replays by key alone. `ritual.start`
keeps its own rule: a replay is decided by the identity of the run it started.

Each entry in `next[].params.produces` carries `kind` plus `required`, so a caller
knows what it owes before hitting a `gate_unsatisfied` refusal over a missing
artifact. A `GateEvidence` action's `params.evidence` carries the phase's real schema
— `schema`, and per field `name`/`kind`/`optional` plus whichever constraint applies
(`min_len`, `must_be`, `one_of`, `required_when` — the sibling field name and the
values that make the field mandatory, when its presence is conditional rather than
flat — and for the two field kinds whose shape isn't a bare length or enum:
`max_len`/`pattern` for `commit-sha` — a 7-64 character value matching `pattern` —
and `requires_scheme_and_host` for `url`) — everything needed to construct a
satisfying `ritual.submit` body without guessing from a refusal first.
`params.evidence` is absent on a `GateApproval` action (that gate takes no evidence at
all); it is never absent on a `GateEvidence` action, including a deprecated `v1`
phase, whose schema carries `legacy: true` instead of a real `schema`/`fields` —
`v1`'s rule is "any non-empty body," stated explicitly rather than left to omission.

`next` also carries a `wrap-run` action once a run's terminal phase has its own gate
already satisfied and the run isn't yet wrapped — the only signal that tells a caller
it's time for `ritual.wrap` rather than another `submit`/`approve`. `wrapped` itself
is set BY `ritual.wrap`, so a caller waiting on it directly would wait forever; `next`
carrying `wrap-run` is what actually says "call `ritual.wrap` now."

`ticket.create`/`update`/`finalize` fold a landing-pass failure into the response the
same way: the write already landed (the KB file exists), so the result carries the
populated ticket plus `unlanded: true` and a `repair` field instead of discarding it —
retrying would allocate a duplicate handle.

Every other `ticket.*` refusal is typed too, and none of them carry a salvageable
ticket — unlike `ErrUnlanded`, nothing landed, so there's no populated result to
fold in and no repair-then-retry story. They follow the `ritual.*` envelope: a
**failed call** (`isError: true`) whose structured content carries an `error` object,
`{kind, message, handle?, current_revision?, status?}`, rather than a bare Go error
with English in the content text. A driver branches on `error.kind` and never on
`message`. The ticket fields are zero on a refusal. The ticket `error.kind`
vocabulary — `idempotency_key_conflict | idempotency_unverifiable | revision_conflict |
expected_revision_required | terminal_status | dropped_reason_required | not_found |
invalid_status | invalid_request | ambiguous_handle | identity_mismatch |
handle_contention | lock_unavailable | internal` — is closed; `internal` is any
failure the engine does not recognize, with its message stripped of machine paths
(the full error goes to stderr). `handle` names the ticket the refusal is about;
`current_revision` (`revision_conflict`) is the ticket's revision now, to re-fetch
against; `status` is the status that blocked a finalize (`terminal_status`) or the
rejected value (`invalid_status`). No kind ever carries an absolute path:
`idempotency_unverifiable`'s `handle` is the unreadable file's handle, or its
KB-relative key when the name carries none.

- **idempotency_key_conflict** — a keyed `ticket.create` reused a key that already
  names a ticket in a different `project`. Nothing is written; `handle` is the
  ticket the key already claims.
- **idempotency_unverifiable** — a keyed `ticket.create`'s scan for
  `idempotency_key` hit a ticket file that could be this request's own (under its
  project's directory, or claiming its handle prefix) and couldn't read or parse
  it, so it could not rule the key out. Failing closed here beats the alternative:
  that file might be exactly the original ticket the key already names, and
  silently treating it as "not a match" would mint a second ticket for a request
  that already succeeded once. The fix is repairing the named file —
  `mindmeld lint` surfaces exactly what's wrong with it — never retrying without a
  key. An unreadable file in a different project is skipped: a replay needs the
  same `project`, so that file can't be this request's ticket (a readable ticket
  there holding the same key still refuses as `idempotency_key_conflict`). A
  keyless `ticket.create` never scans for a key at all.
- **revision_conflict** — `ticket.finalize`'s `expected_revision` no longer matches
  the ticket's current revision. Nothing is written; `current_revision` says what
  to re-fetch against.
- **expected_revision_required** — `ticket.finalize` with `drafted_run: true` and no
  `expected_revision`. That branch rewrites the whole body, so there is nothing to
  compare a blind overwrite against. Refused before any file is touched.
- **terminal_status** — `ticket.finalize` refuses when the ticket's current status
  isn't one it has any business mutating: `backlog`/`active`/`in-review` are the
  only statuses it moves — `done` (its own prior output), `dropped` (a human's own
  terminal call), and anything else all refuse. Checked right after the revision
  compare-and-swap above, so a stale `expected_revision` is reported first and a
  terminal status only once the revision itself checks out. Nothing written either
  way; the status is either `finalize`'s own past output or a human's own call, and
  neither is `finalize`'s to overwrite.
- **dropped_reason_required** — `ticket.update` refuses to move `status` to
  `"dropped"` without a `reason` of at least 8 characters. Nothing is written; the
  fix is resubmitting the same call with a real explanation. Every other status move
  leaves `reason` optional.
- **not_found** — no ticket has `handle`. Never a guess at a neighbor.
- **invalid_status** — `ticket.finalize`'s `status` is outside what it may write
  (`done`, `in-review`). Refused before any file is touched.
- **invalid_request** — a malformed `project` or `handle`: not a single safe path
  segment, or not `PREFIX-N`. Nothing was resolved or written.
- **ambiguous_handle** — `ticket.fetch`/`update`/`finalize` refuse when two files on
  disk claim the same handle, rather than picking a walk order. The fix is on
  disk: remove or re-handle all but one of the claiming files, then retry.
- **identity_mismatch** — one file's filename handle and frontmatter `ticket:`
  disagree. Neither is picked; the fix is on disk too.
- **handle_contention** — `ticket.create`'s scan-and-publish loop retried past its
  bound without landing a file. Never a duplicate handle, never an overwrite —
  the prefix was just contended past what the loop will absorb. Retry is safe.
- **lock_unavailable** — `ticket.create`/`update`/`finalize` couldn't acquire the
  per-prefix ticket lock (or, for a keyed `ticket.create`, the key-scoped
  idempotency lock it acquires first) inside its budget. This is a hard failure
  of the write path: nothing landed, and retry is safe. Don't confuse it with the
  qmd lock the landing pass takes for its reindex step — that one is a *warning*,
  not a failure: the write already landed, and only the reindex was skipped
  (folded into `Ticket.Warnings`, same as any other landing-pass warning). A
  reader who conflates the two will misdiagnose both: one means retry later, the
  other means the reindex needs a manual repair, and the write is already fine.

One more thing worth knowing if you've called `ticket.fetch` before: it can now
fail on a KB where it used to return something. It was returning the first
filesystem-walk hit for a handle — a guess — and two files claiming one handle
is a data problem for the caller to fix, not something to guess through.

## Ritual definition versions

`spawn-session` ships two versions; `wrap-session` ships three. `v2` (both kinds)
adds a typed evidence schema per phase and a required/optional split on the
artifacts a phase must produce before its gate opens — the fix for the hole where a
bare `"done"` satisfied a destructive teardown phase as convincingly as a real
transcript. `wrap-session`'s `v3` changes only `finalize`'s evidence schema again:
`ticket-final/v2` adds a required `outcome` of `finalized`, `no-ticket`, or
`dropped`, with `handle` mandatory when `outcome` is `finalized` OR `dropped`,
`status` mandatory only when `outcome` is `finalized` (a `dropped` outcome submits no
status — the engine never wrote one, since a dropped ticket was never finalized by
this run), and `reason` mandatory when `outcome` is `no-ticket` OR `dropped` — one
gate, three legitimate shapes, instead of a bare `{"handle": "", "status": "done"}`
clearing a gate whose entire job is confirming a ticket was actually finalized (or
genuinely skipped, or already ended by a human — never silently resurrected).
`v1` (both kinds) and `wrap-session`'s `v2` all
stay registered but are marked deprecated: an in-flight run under any of them keeps
resuming and finishing under the rules it started with — every verb still works
against it — but `ritual.start` refuses an explicit deprecated `def_version` and
never resolves to one when `def_version` is omitted, so a fresh run always lands on
the current, hardened gates (`spawn-session` v2, `wrap-session` v3). `mindmeld
doctor` reports every version of every kind it ships, marking the deprecated ones
`(deprecated, resume-only)` rather than listing them as though a host could still
start one.

## Approval provenance

An `Approval` names two parties and verifies neither: `approver` is the human the
calling agent CLAIMED gave the go-ahead, and `actor` is the process that RELAYED that
claim (`kind`, `id`, `harness` — `id`/`harness` come from `ritual.start`'s optional
`agent`/`harness` fields, and `harness` is purely informational, never branched on by
the engine). `trust` discloses what backs the claim; in this build its only value is
`self-reported`, because a local stdio adapter has exactly one honest thing to say —
an agent process told it a human said yes. No field here implies stronger identity
verification than that actually happened. A hosted adapter with a real identity
provider is where a stronger trust value would get defined, by the code that can
actually justify it — nothing in this build produces one.

## Resources

Read-only identities, never a copy where the server can return the real thing:

- `mindmeld://kb/pulse` — the session-start pulse cache
- `mindmeld://kb/ticket/{handle}` — a ticket by handle
- `mindmeld://kb/article/{+slug}` — a KB file by its KB-relative path (e.g.
  `wiki/some-article.md`), resolved under the resolved KB root; the path is cleaned and
  confined before it ever reaches the filesystem — no `..`, no absolute path in, no
  escaping the KB root out

Five more templates cover a ritual run's own state, all served by one handler that
dispatches on the URI tail — they share the same load-and-fold sequence and only
diverge on what a caller wants out of the result:

- `mindmeld://run/{run_id}/artifacts` — the whole artifact ledger, in record order
- `mindmeld://run/{run_id}/{artifact_kind}` — just that kind's recorded entries, in
  record order (a run that produced the same kind twice — a revised plan, say — no
  longer collapses to whichever entry was recorded last)
- `mindmeld://run/{run_id}/artifact/{artifact_id}` — one artifact's real content when
  it can be resolved, or its ref plus why it couldn't
- `mindmeld://run/{run_id}/evidence/{seq}` — one submitted-evidence record, body
  included. `ritual.status`'s own `evidence` list deliberately omits the body — a gate
  transcript can run to kilobytes and status is polled — so this is where a host reads
  it.
- `mindmeld://run/{run_id}/dossier/{+path}` — a file under that run's own dossier
  directory, path cleaned and confined the same way `kb/article/{+slug}` is

One more template, served by its own handler rather than folded into the five above
(it reads a different part of the run — `chunk.declare`'s own state, not artifacts or
evidence):

- `mindmeld://run/{run_id}/chunks` — the same `ChunkOut` body every `chunk.*` verb
  returns: the declared chunk DAG, the capability manifest it was declared under, every
  attempt, and the ready set — a resuming host reads the whole graph without a
  mutating call. 404s until the run's first `chunk.declare`, same as any other
  not-yet-populated run state.

The last template answers a cross-run question rather than a single run's state, so it
is never folded into the run-scoped handlers above either:

- `mindmeld://routing-rates{?project}` — routing outcomes aggregated across every run
  this machine's journal can discover, broken down by assigned class and by each
  chunk's declared traits (complexity, risk, judgment): how many chunks landed first-try,
  how many needed revision, how many were blocked or verification-failed, how many were
  rerouted — each as a count plus its own rate. The optional `project` query parameter
  narrows the walk to runs under one project. Never 404s: a machine that has never
  declared a chunk graph, or a `project` filter matching nothing, reads back as a real,
  empty aggregate.

No resource or `ritual.*` response ever surfaces a machine filesystem path — only
these opaque URIs.

## The stdout/stderr split

stdout belongs to the SDK's JSON-RPC transport, full stop — no report line, no styled
output, ever reaches it while serving. Every report line (the one-time "serving stdio:
N tools, N resources, N resource templates" line, `ritual.resume`'s own line) goes to
**stderr** instead, in the plain (uncolored) face, regardless of `--plain` or TTY
detection: this is the one command in the binary whose sink isn't a TTY decision, since
a byte on the wrong stream corrupts every host's framing.

## What it needs to run

`ticket.*` and `recall.*` verbs need only `[kb].root` (or `--kb`) — same as `mindmeld
lint`/`mindmeld hot`. Ritual verbs additionally need `[defaults].dossier_dir`, since a
run's journal lives at `{dossier_dir}/{project}/{branch}/{kind}.journal.jsonl` — kind
is part of the leaf's own filename, never an inserted path segment, so a
spawn-session run and a wrap-session run can coexist at the same `(project, branch)`
as two files in one directory. A run written before that scheme still uses the bare
`journal.jsonl` name, and is still read where it lies — its kind is recovered from
the journal's own seq-1 payload rather than the filename. This requirement surfaces
at the first `ritual.*` call, not at server start, so a host can still fetch tickets
and recall KB content even in a checkout that hasn't set a dossier directory yet.

## Config it reads

`[kb].root`, `[defaults].dossier_dir`, `[defaults].dossier_archive_dir` — see
[config.md#kb](../config.md#kb) and [config.md#defaults](../config.md#defaults).
`dossier_archive_dir` is read only by `ritual.archive`, and only at the moment a
wrapped run is actually archived — an unset value there is not a missing-config
failure the way an unset `dossier_dir` is for every other ritual verb; `ritual.archive`
applies the documented sibling-of-`dossier_dir` default itself. `[mcp]` is reserved and
read by nothing yet — see [config.md#mcp](../config.md#mcp).

## Related
- [Configuration](../config.md) — the full config reference, including `[mcp]`
- [mindmeld lint](lint.md) — the landing pass `ticket.create`/`update`/`finalize`
  run after every write
