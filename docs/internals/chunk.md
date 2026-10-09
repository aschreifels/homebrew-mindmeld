# internal/chunk

## What it is

`internal/chunk` is the domain behind durable chunk scheduling — pure, in-memory logic
with no I/O and no harness, model, or vendor vocabulary anywhere in it. It is a leaf
package: `internal/ritual` imports it, never the reverse, and everywhere this package
would otherwise need something the ritual vocabulary owns — checking a run's capability
ceiling is the one real case — the caller supplies it as a predicate (`CapabilityCheck`)
instead of a type this package would have to import.

A chunk's declared identity, its execution request, the host's capability manifest, and
the append-only ledger a fold replays into a `State` all live here. `internal/ritual`
folds this domain's events from the same run journal and revision counter every other
piece of run state uses — there is no second journal, no sidecar file, and no chunk
dispatcher that runs outside the durable run. `Run.Chunks` holds three recorded things:
the manifest and spec set the most recent `chunk.declare` recorded, and the ledger — the
append-only history every `chunk.claim`/`chunk.report`/`chunk.reroute` call has produced.
(`Run.Chunks` also carries the derived stale marks described below.)
Its zero value is a valid, empty state: a run that never declared a chunk graph reads
back an empty manifest, no specs, and an empty ledger, not an error.

Five verbs move this state — `chunk.declare`, `chunk.claim`, `chunk.report`,
`chunk.reroute`, `chunk.affirm` — served over the control plane; see [mindmeld mcp](../commands/mcp.md)
for their wire shape. This page covers what the domain underneath them guarantees.

## Design

### Identity composes, and is derived, never parsed

A `Spec.ID` is one path segment — letters, digits, `_`/`-` only, no `/` or `#` — so a
`ChunkPath` (a parent's path joined with a chunk's own id) and an `AttemptID`
(`<path>#<seq>`) can never be misread as something to split apart for structure.
`Spec.Parent` is the field a reader uses for ancestry; a path is only ever derived from it at
declaration, never parsed to recover it. `Spec.Parent` sits empty at top level, and `Validate`
refuses any non-empty value outright, naming the chunk — nesting is not supported in this
protocol version, so the field exists today only so composite identity does not require
rewriting an append-only ledger once nested delegation lands.

### Complexity describes the work; a request describes the executor

Two independent fields on a `Spec`. `Spec.Complexity` (`trivial`/`standard`/`complex`)
describes how big an edit is and selects nothing. `Spec.Execution` (a `Request`) describes who
should run it: a `Request.Preferred` class, an optional `Request.Minimum` floor, an ordered `Request.Fallback`
list, and a `Request.Routing` table from trigger to `RoutingTarget` — a `RoutingTarget.Class`,
a `RoutingTarget.Min` floor, or both — for when an orchestrator needs to raise, floor, or
redirect a chunk's caliber mid-run.
`Request.Risk`, `Request.Judgment`, and `Request.Context` round out the
request as signals a routing policy reads, independent of `Spec.Complexity`.

The class vocabulary is closed and semantic: `mechanical`, `balanced`, `deep` — ranked in
that order — and `main-thread`, which is not a caliber at all. It names *who* executes,
sits outside the ranked comparison, is never a legal `Request.Minimum`, and is the one class every
fallback chain can terminate on. `Request.Preferred` must always be a known class,
`main-thread` included: it is the terminal rung, and routing a chunk there — the
orchestrator absorbing the work itself rather than delegating it — is the point, not a
degraded case of a rule that expects a delegable answer. `Request.Minimum`, when set, must
be delegable and rank no higher than `Request.Preferred`; every `Request.Fallback` entry
must resolve to a known class and, when ranked, rank no lower than the effective minimum
(`Request.Minimum`, or `Request.Preferred` when none is stated) — an entry below it could
never be claimed, so declaring one is refused, and every `Request.Routing` entry must satisfy
`RoutingTarget.Validate` (at least one of `RoutingTarget.Class`/`RoutingTarget.Min` set,
each a known class, `RoutingTarget.Min` delegable and ranking at or below
`RoutingTarget.Class` when both are set, and `main-thread` taking no
`RoutingTarget.Min`). See
[Concepts](../concepts.md#executor-classes-and-routing) for how a routing policy actually
fills these fields.

### Barriers and serialized operations are graph properties, not routing

`Spec.Barrier` and `Spec.Serialized` live on the `Spec`, not the `Request` — they gate
*when* a chunk may be claimed, the same axis `Spec.DependsOn` already occupies, never
*who* fills it. A barrier chunk holds every other non-barrier chunk in the same declared
set back until its own latest attempt closes accepted; the contracts-first chunk that
opens a session is the canonical example, and the hold applies without any dependent
needing its own edge naming the barrier — one accept lifts it for everyone in a single
step. A barrier never holds back another barrier, and it never holds back its own
transitive `Spec.DependsOn` closure either — those chunks must run before the barrier by
definition, so exempting them is what lets the barrier ever become acceptable at all
(`Validate`'s drain simulation is the structural guard that catches a graph shaped so no
exemption could save it). `Spec.Serialized` is mutual exclusion in
both directions: it holds every other chunk back while its own attempt is open, and is
itself held back while any other chunk anywhere has an open attempt — codegen, dependency
changes, and migrations are the shape of work this exists for, anything that mutates
state shared across chunks rather than within one chunk's own scope. Both flags default
false, and both are frozen once a chunk has a recorded attempt, the same freeze
`Redeclarable` already applies to scope, dependencies, and parallel group.

### Tool and context negotiation is checked before the proposed class or mode

`Request.RequiredContext` and `Request.RequiredTools` name what a chunk needs beyond a
class's baseline — plain, open strings this package never interprets, the same
open-vocabulary shape `Request.RequiredCapabilities` already uses. `Manifest.ProvidedContext`
and `Manifest.ProvidedTools` are the host's answer: absence means the host provides none,
not "unknown," the same no-tri-state rule every other `Manifest` field follows. `Resolve`
checks both sets before it ever looks at the proposed class or mode — a chunk whose
requirement the manifest doesn't list is refused regardless of what's being proposed,
because the question "can this host meet the chunk's requirements at all" is independent
of any one proposal on the table.

### Routing policy applies once, at declare — and a floor is engine-owned

Before a proposed spec set ever reaches this package's own `Validate`, `chunk.declare`
resolves the person's routing policy and applies it against every spec's declared traits
(`Spec.Complexity`, and `Request.Risk`/`Request.Judgment`/`Request.Context` when set). A
rule setting a class is a *default* — it fills `Request.Preferred` only when a spec leaves
it unset, and never overrides one a spec states, clamped up (never down) when the result
would otherwise land below a composed floor. A rule setting a minimum composes a *floor*
onto `Request.Floor` — a field only the routing policy ever writes. A spec that states a
`Request.Floor` other than the one the policy composes for it is refused outright at
declare, naming the chunk, since it is not the caller's to state; a floor equal to the
composed one is the engine's own output coming back (a declare response, or the chunks
resource, re-declared verbatim) and is accepted, which is what lets a driver re-declare
exactly what it was served and keep a reroute's request. Unlike `Request.Minimum`, which stays exactly what the spec
itself claims, `Request.Floor` binds regardless: `Validate` refuses declaring a
`Request.Routing` entry that could ever land the chunk below it, `Reroute` never leaves
`Request.Minimum` below it once set — a route may lower a chunk's caliber, but only down
to the floor — and `Resolve` never accepts a delegated class below it, even one a
`Request.Minimum` or `Request.Fallback` written on purpose would otherwise allow. The
floor survives every reroute for exactly that reason: it is a property of the chunk's own
declared risk, not of whichever routing target happens to be active. An absent policy file
resolves to this engine's own built-in defaults, same as a file with no rules configured; a
policy file that exists but fails to parse refuses the declare outright, naming the file
and the parse error, rather than falling back to defaults the way an absent file does. A
`contract-question` rule that is anything but `class: main-thread` with no `min` is one of
those parse failures, naming the rule's position in the list: a contract question always
returns to the main thread, so no other rule could ever apply.

### A host manifest is validated on its own terms, then against the run's ceiling

A `Manifest` declares what a host can actually do this session — whether it can delegate
at all, run children in parallel (and at what concurrency), pick a class per child, steer
a running child live, and which classes it can fill. Every field is explicitly present: a
host that cannot answer a question declares the false or zero value rather than leaving it
unset, so there is no "unknown" a failed spawn could later be misread as. `Validate`
checks the manifest's own internal consistency — parallel implies children and a positive
concurrency, at least one class when children is set, `main_thread` must be true because a
host with no main thread cannot run this ritual at all. A host that cannot select a class
per child (`Manifest.PerChildClass` false) must commit to exactly the one class it actually
fills every child with — `Manifest.Classes` lists one entry, never several it would only
ever collapse onto one of; advertising more than one while unable to choose among them is
not an honest declaration. `WithinCeiling` is a separate, later check against the run's
own declared capability set — `Manifest.Children` needs the `delegation` capability,
`Manifest.Durable` needs `durable-workers` — because a manifest may be narrower than the
ceiling a run started with, never wider.

`Request.RequiredCapabilities` is checked against the host at three separate moments, for
three different questions. At declare, `internal/ritual` checks it against both the run's
own capability ceiling (can this host EVER do this) and the proposed `Manifest` itself
(does THIS run's declared manifest actually offer it) — `durable-workers` requires
`Manifest.Durable`, `delegation` requires `Manifest.Children` — because a chunk requiring
durable workers can never be claimed in delegated-durable mode against a manifest that
never turns `Manifest.Durable` on, however wide the run's ceiling is. At claim, a chunk
requiring `durable-workers` must actually be claimed in `delegated-durable` mode —
proposing the same class in ordinary `delegated` mode is refused, even though the class
itself resolves cleanly. After a claim, on every subsequent `chunk.declare`, the SAME
capability-to-manifest mapping is checked a third time against whatever attempts are
currently open — a re-declared `Manifest` cannot stop satisfying a capability an open
attempt's own chunk required when it claimed (see "A re-declared `Manifest` is checked the
same way" below), and this third check runs against every open attempt's mode, not just
delegated ones.

### The engine resolves an assignment; it never picks one

A host proposes a class and a mode; `Resolve` either accepts the pairing or refuses it,
and never invents an assignment of its own. The checks run in order: the class must be
known and the mode must be one the manifest actually supports; class and mode must agree
on who executes (a delegable class needs a delegated mode, `main-thread` needs
`main-thread` mode — an incoherent pairing is refused before either field is checked
against the request, because once it's in the ledger nothing downstream can tell it apart
from a real one); a delegable class must be one the manifest lists; it must rank at or
above the request's effective minimum (its stated `Request.Minimum`, or `Request.Preferred`
when none is stated) — a bar that binds in both directions: a ranked `Request.Fallback`
entry below the minimum never rescues a class the minimum already refuses, and declaring one
is refused up front rather than left to fail at every claim,
while `main-thread` sits outside the ranked order entirely, so it is never compared against
the minimum and is always legal whenever it is `Request.Preferred` itself or appears in
`Request.Fallback`; it must also rank at or above `Request.Floor` when one is set — the
same rule, except `Request.Floor` binds even when `Request.Minimum` or `Request.Fallback`
would otherwise allow a cheaper class, since it is engine-owned rather than a choice this
negotiation can be talked below; a delegable class other than `Request.Preferred` must
still appear in `Request.Fallback` (or the default `[main-thread]` when unset) — clearing
the minimum and the floor is not by itself an offer; and a downgrade reason must be present
exactly when the resolved class differs from what was requested.
`Assignment.Requested` itself is always overwritten with the request's own `Request.Preferred` — a host-sent
value is never trusted.

### Readiness and topological order are pure derivations over the ledger

`ReadySet` walks the declared graph in topological order (a Kahn walk over `Spec.DependsOn`,
ties broken by path so the same declaration draws the same order on any machine). The same
walk is the cycle check — `Validate` rejects a malformed graph, self-dependency included,
before any readiness question is ever asked of it — so a rendered graph and a dispatch
decision come from one walk, never two that could disagree. A parallel group's members are
also checked pairwise for scope overlap at declare time: two chunks in the same group writing
the same file is refused at declaration, before either one ever runs. `Validate` additionally
simulates a full drain — accepting every ready chunk repeatedly until nothing more can accept
— and refuses any graph whose ready set empties before every chunk is accepted, a structural
guard against any combination of barriers and dependencies that could deadlock the whole run,
not just the one shape a hand-written test happened to check.

**There is exactly one readiness definition, and it is worth stating plainly because it is
the rule a future contributor is most likely to break by adding a check at a call site
instead of here.** `NotReadyReason` is that definition: given a spec, the full declared set,
and the ledger, it reports whether the spec is dispatchable right now and, when it isn't,
why — an unaccepted dependency (`WaitingOn` names which), an attempt already open against
it, an attempt already accepted against it, another chunk's open attempt whose scope
overlaps this one's (checked regardless of parallel group — declare-time disjointness only
ever compares siblings in the SAME group, so this is the one place two chunks from different
groups, or no group at all, are stopped from writing the same file concurrently), an
unaccepted `Spec.Barrier` chunk elsewhere in the set (except when the barrier is itself
somewhere in this chunk's own transitive `Spec.DependsOn` closure — a barrier's own
prerequisites must be free to run before it by definition, or nothing could ever accept it),
or `Spec.Serialized`'s mutual exclusion in either direction. Three call sites ask this exact
function, never a reimplementation of it: `ReadySet` filters the topological walk through it
to build the ready set; `internal/ritual`'s `chunk.claim` gate calls it to decide claim
legality and, on refusal, to explain why; and `internal/mcp`'s status projection
(`deriveChunkState`, below) calls it to decide whether a chunk not yet claimed or accepted
reports `blocked` versus `pending`. A readiness condition added to only one of these three —
a new dependency-like rule bolted onto the claim gate alone, say — would let a driver see a
chunk in the ready set that claim then refuses, or claim accept one `ReadySet` never offered.
Add a readiness rule to `NotReadyReason` once, and all three inherit it for free; adding it
anywhere else is the drift this design exists to rule out by construction.

`chunk.claim` additionally enforces manifest capacity — `Manifest.Parallel ?
Manifest.MaxConcurrency : 1` currently open attempts, delegated OR main-thread (a childless
host holding several main-thread claims open is bound by the same ceiling, not exempt from
it just because none of those claims delegate), and, when `Manifest.PerChildClass` is
false, that every concurrently open DELEGATED attempt already shares the one class the
manifest can run — an open main-thread attempt has no class to collapse onto anyone else's,
so it never participates in that second check — as a claim-time check (`CapacityReason`), not a
`NotReadyReason` readiness rule: capacity is about how many attempts may be open at once
across the whole manifest, not whether any one chunk's own dependencies are satisfied, so a
chunk can appear in the ready set and still be refused at the moment of claim once the
manifest's concurrency ceiling is already spent.

While the manifest cannot select per child, its delegated attempts share one class and one
worker, and `chunk.claim` enforces both beyond `CapacityReason`. The class is derived state
(`ChunkState.SharedClass`) that `Fold` maintains in journal order, never inferred from
timestamps: when `Manifest.PerChildClass` is false, the first delegated attempt opened pins the
class (and the chunk that opened it), and every later delegated claim must resolve to it,
whatever manifest is current and whether or not executors are recorded; a main-thread attempt
never pins. A `chunk-declared` that stays `per_child_class` false keeps the pin; one with
`per_child_class` true clears it, ending the stretch, and the first `per_child_class`-false
declare after that begins a new, unpinned one — so a run that used several classes under a
per-child host can be resumed by a host that cannot select per child, at any one class. The
refusal names the pinned class and the chunk that pinned it. `chunk.declare` refuses the same thing earlier: while a class is pinned, a manifest with
`per_child_class` false whose sole class differs from it is a `chunk_conflict`, while
turning `per_child_class` on stays legal. Beyond the class, a claim's resolved
`Assignment.Executor`, when non-empty, must match every earlier delegated attempt's own
non-empty `Assignment.Executor` recorded anywhere in the run's ledger — closed attempts included, not just the currently
open ones, since the guarantee covers the shared class's one worker for the run's whole
lifetime. This runs against the executor AFTER `[execution.classes]`'s own fill and after
`record_executor`'s own blanking have both already applied — with `record_executor` off,
neither side of the comparison is ever non-empty, so nothing is recorded and nothing
contradicts; the guarantee covers what is recorded, never what a class mapping merely
would have filled in.

### The attempt ledger is append-only; a re-declare respects what already ran

`State` never rewrites a recorded attempt. Appending adds a new entry; closing sets an
attempt's outcome and report exactly once, on the ledger's own last, still-open entry, and
refuses outright against a path with no attempts, a sequence number that isn't the last
entry, or an entry that's already closed. Only `accepted` unblocks a dependent;
`rerouted` is never a driver-reported outcome — it belongs to `chunk.reroute` alone,
against whatever attempt is open at the moment it fires.

Re-declaring the same chunk id is unrestricted until it has a recorded attempt. Once one
exists, its scope, dependencies, parallel group, and spec version are frozen — dispatch
already happened against them, and changing one retroactively would invalidate the
disjointness and readiness answers that dispatch relied on. A re-declare that would drop a
chunk with recorded attempts entirely is refused for the same reason: history in the
ledger is never orphaned by a later declaration.

A re-declared `Manifest` is checked the same way: `chunk.declare` refuses one that pulls
capability out from under an attempt the run already has open, rather than letting a host
narrow its own future capacity from under attempts already claimed under the wider one —
a `max_concurrency` below the number of attempts already open (delegated or main-thread,
the same accounting `CapacityReason` uses), `per_child_class` turned false while open
delegated attempts already carry more than one class between them, `children` turned false
while any delegated attempt is still open, a `Manifest.Classes` list that simply omits the
class an open delegated attempt is currently running, `durable` turned false while a
delegated-durable attempt is still open, a `per_child_class`-false manifest whose sole class
differs from the class the current per_child_class-false stretch pinned (closed attempts
included; a per-child manifest clears the pin), a `Manifest.ProvidedTools`/`Manifest.ProvidedContext` entry dropped that an open
attempt's own chunk requires (the same set `Resolve` checks a `Request` against at claim
time, re-checked here for what is already running rather than what a new claim proposes),
or the manifest no longer satisfying a capability (`Request.RequiredCapabilities`) an open
attempt's own chunk required when it claimed — checked against EVERY open attempt
regardless of mode, not only delegated ones, since a capability like `delegation` is
checked against the manifest at declare time no matter what mode a chunk eventually
claims under. Re-declaring cannot drop a class, a mode, a tool/context entry, or a
required capability work is already dispatched under, even when every other field stays
exactly as it was.

"What an open attempt's own chunk requires" is read off that attempt's OWN
`Attempt.Provenance.RequiredTools`/`Attempt.Provenance.RequiredContext`/`Attempt.Provenance.RequiredCapabilities`
— the snapshot taken at the moment it claimed (see "An attempt snapshots the
characteristics in force when it opened" below) — never off the chunk's CURRENT spec,
and never with any fallback to it either. A spec's own requirements stay legally editable
while its attempt is open, the same re-declare freedom every other `Request` field has,
but that freedom doesn't extend to the manifest: narrowing `provided_tools`/`provided_context`,
or a capability the manifest itself backs, under the requirement an open attempt actually
claimed against is refused whether the spec's own requirement was edited away first, in an
earlier `chunk.declare` call, or in the very same call as the manifest narrowing — so a
chunk claimed main-thread under a manifest that satisfied its `delegation` requirement at
declare time still binds a later manifest re-declare to keep `children: true` for as long
as that attempt stays open, even though a main-thread attempt itself never touches
`Manifest.Children`. The capability check runs a claimed attempt's `Provenance.RequiredCapabilities`
through the SAME capability-to-manifest-field mapping the declare-time check uses
(`delegation` → `Manifest.Children`, `durable-workers` → `Manifest.Durable`), never a
second copy of it. A journal recorded before `Attempt.Provenance` existed, or under an
older snapshot version that never recorded `Provenance.RequiredContext` or
`Provenance.RequiredCapabilities`, is no exception: Fold completes every such snapshot
from the spec as it stood in the journal when that attempt opened, before it is ever
stored — see "An attempt snapshots the characteristics in force when it opened" below.
Each refusal names the open chunk(s) responsible, and the capability check additionally
names the capability itself. A manifest that contradicts none of these re-declares
freely, first declare included — an empty ledger has nothing open to contradict.

A recorded attempt freezes what the chunk *means* alongside what it's structured like:
`Spec.Objective`, `Spec.Verification`, and `Spec.ReportRequirements` are frozen
too, the same moment scope and dependencies are — a re-declare that rewrites any of them
against a chunk with a recorded attempt is refused, naming the field, because an accepted
attempt was reviewed against the original wording and a rewrite afterward would let that
review silently stop meaning what it meant. A chunk that genuinely needs a different
objective is a different chunk; that is what a re-carve is. The rest of the execution
request — `Request.Preferred`, `Request.Minimum`, `Request.Fallback`, `Request.Routing` — stays editable throughout,
because reassignment is exactly what the spec/request split exists to allow.

### All five verbs share one phase window

`chunk.declare`, `chunk.claim`, `chunk.report`, `chunk.reroute`, and `chunk.affirm` are checked against
the same window, and the window is definition data: a phase admits chunk work when its
`PhaseDef.AdmitsChunkWork` is set, and the gates never read a phase name. The shipped
spawn-session definition marks contracts-landing, execute, behavioral, and self-review; a
definition that renames or inserts a phase carries its own window with it, and one that
marks no phase (wrap-session) refuses chunk work everywhere. Under the shipped definition
that means refused before contracts-landing (the
graph is a product of plan signoff — nothing before it has a plan to carve chunks from)
and refused once a run reaches integrate (the work is finished by definition, so a declare
or dispatch there would create or target work nothing can ever execute). Leaving the last
admitting phase additionally requires every declared chunk to be accepted. The window
including self-review is what makes a review-fix chunk dispatchable through the ordinary
verbs during the self-review pass, rather than needing a separate mechanism. All five
additionally refuse against a run carrying an open, unanswered blocker — chunk work never
proceeds while the run itself is stuck on a question nobody has answered.

### `chunk.claim` refuses off the ledger, not off a driver's own reading

Claiming a chunk is refused, never silently mis-dispatched, whenever `NotReadyReason`
(above) reports it not ready — an open attempt, an already-accepted one, an unaccepted
dependency, an open barrier, or serialized exclusion — and the refusal names the same
reason that function reports, not a second wording of it. A driver should read the ready
set (`ChunkOut.Ready`, or `mindmeld://run/{run_id}/chunks`) rather than deriving readiness
itself from the declared graph; either way, a stale read is caught here rather than
trusted.

### A chunk's reported status names its own blocked reason

`internal/mcp`'s status projection (`ChunkStatus`, part of `ChunkOut`) derives each
chunk's `State` — `pending`/`claimed`/`accepted`/`needs-retry`/`blocked` — from the same
ledger `ReadySet` and `chunk.claim` already read: accepted or an open attempt short-circuit
first, and everything else asks `NotReadyReason` the identical question those two ask.
A `blocked` state always carries `ChunkStatus.BlockedReason`, the exact string
`NotReadyReason` returned — the same words a claim attempted right now would be refused
with — so a driver reading the graph never has to re-derive why a node isn't dispatchable
by tracing dependency edges or barrier flags itself.

### `chunk.report` and `chunk.reroute` are scoped to one attempt

`chunk.report`'s `Attempt.Seq` names the attempt it closes and is required, not defaulted to
"whichever attempt is open": a delayed report from an attempt the run has since moved past
— a reroute closed it, a re-claim opened a new one — has to name the attempt it was
actually written against, or the call is refused, naming the mismatch. An optional field
that silently closed whatever's currently open would let that stale report land against
the wrong attempt's work. `chunk.reroute` carries the same protection whenever a chunk
does have an open attempt, but its `Attempt.Seq` is legitimately zero when none has ever been
claimed — a routing policy may redirect a chunk's caliber before anyone has claimed it, and
there is nothing to scope against yet. Every reroute's stated reason is kept: it appends
onto `Attempt.RerouteReasons` rather than overwriting it, so an attempt rerouted more than
once — closed by the first reroute, then named again by a later one after it already
closed — carries every reason it was ever named for, oldest first. Recording it on the
ledger entry itself, rather than reconstructing it later from the event stream, is
deliberate: a second reader re-deriving which attempt a given reroute closed is a second
definition of that rule, and the two would drift. A trigger's `RoutingTarget` is applied
by shape: `RoutingTarget.Class` alone is an EXACT target — `Request.Preferred` and
`Request.Minimum` are both assigned to it outright, which may lower the request, since a
target someone wrote down (spec or policy) is honored rather than merely raised toward;
`RoutingTarget.Class` and `RoutingTarget.Min` together assigns `Request.Preferred` to
`RoutingTarget.Class` and `Request.Minimum` to `RoutingTarget.Min`, both exactly;
`RoutingTarget.Min` alone is a FLOOR — `Request.Preferred` and `Request.Minimum` each
become whichever of `RoutingTarget.Min` and their own current value ranks higher, never
lowering either. A `RoutingTarget.Class` of `main-thread` always wins outright,
unconditionally — main-thread is a stronger posture than any ranked class, never a
cheaper one, so no comparison applies to it at all, and `Validate` refuses pairing it
with a `RoutingTarget.Min`. `TriggerContractQuestion` is a further exception, ahead of
all of this: contract or product judgment always returns to the main thread, so
`Reroute` sends it there unconditionally whether or not the chunk carries a
`Request.Routing` entry for it at all, and `Validate` refuses declaring one — from the
spec or from policy — that names anything but `main-thread` with no `RoutingTarget.Min`,
since any other value could never actually apply.

A reroute defines the WHOLE offer, not just `Request.Preferred`: `Request.Fallback` is
replaced by each shape, never merely extended, so nothing from before survives except
`main-thread`, and only when it was already offered ("offered" reads the previous
EFFECTIVE fallback — an unset `Request.Fallback` offers `main-thread` by default, the same
default `Resolve` applies). `main-thread` targets (a class-only entry naming `main-thread`,
and `TriggerContractQuestion` always) set `Request.Fallback` to exactly `[main-thread]` —
no delegated class is claimable afterward, whatever was offered before. A class-only exact
target sets it to exactly `[RoutingTarget.Class]`, plus `main-thread` when it was offered
before — stating the class explicitly keeps the list non-empty, so `Resolve`'s own
empty-means-main-thread default can never quietly widen it back out. A class-and-min
target sets it to every ranked class from `RoutingTarget.Class` down to and including
`RoutingTarget.Min`, plus `main-thread` under the same condition. A min-only floor keeps
the previous effective fallback with every ranked entry below the new `Request.Minimum`
removed; `main-thread` survives that filter untouched, since it carries no rank to
compare.

### Evidence is required to accept; disposition is required to follow a revision

A report's prose (`Attempt.Report`) has always been where an attempt's proof lives;
`Attempt.Evidence` is a typed companion — `Evidence.Schema`, an optional `Evidence.Command`,
`Evidence.Passed`, and a short `Evidence.Detail` — for a driver that wants to record what was
actually verified as structured data rather than only as a sentence. Unlike the prose report,
`Evidence` is not optional on the path that matters most: `chunk.report` refuses an `accepted`
outcome unless `Attempt.Evidence` is present with `Evidence.Passed` true — a report is prose,
and `accepted` asserts the chunk is actually done, so it is backed by the same typed proof a
reader (or an automated check) can act on without re-reading the prose, not just the driver's
own say-so. Every other outcome leaves `Evidence` optional, same as before.
`Attempt.Disposition` records what an attempt did about the revision request the *previous*
attempt in the same chunk's ledger left outstanding — `applied`, `declined`, or
`superseded` — with `Attempt.DispositionReason` required exactly when `Attempt.Disposition` is
`declined`, the same required-iff shape `Assignment.Downgrade` already uses for a class
that differs from what was requested. `Attempt.Disposition` itself becomes required, not
merely optional, the moment the attempt immediately before it in the same chunk's ledger
closed with outcome `revision`: whichever call actually closes the next attempt — a
`chunk.report`, or a `chunk.reroute` that closes it instead — must state SOME resolution of
that outstanding request before the ledger is allowed to move on. The obligation belongs to
the attempt, not to whichever verb happens to close it, so `chunk.reroute` never invents
`superseded` on the author's behalf; a reroute against an attempt that is already closed has
nothing left to close and carries no such obligation. On any attempt not answering a prior
`revision` outcome, both fields stay legitimately zero-value.

`Spec.ReportRequirements` is a further, mcp-layer-only check on top of both: `internal/chunk`
and `internal/ritual` never read a report's resolved body (neither package does I/O), so
`internal/mcp`'s `chunk.report` handler is the one layer that can. When the outcome is
`accepted` and a chunk's `Spec.ReportRequirements` is non-empty, it resolves the report ref
and refuses unless every requirement appears as its own markdown ATX heading (any level,
`#`-prefixed only — a setext heading never counts) whose text matches the requirement
case-insensitively after trimming, with at least one *content* line in its section: content
means a line that is non-blank, not itself a heading (a nested child heading never counts,
even though only a same-or-higher-level heading ends the section), not an HTML comment
(single- or multi-line alike), and not a fence delimiter line — text strictly inside a
non-empty fenced block does count. A closing fence must be bare; a line like `` ```go ``
opens a block and never closes one, so it cannot expose a heading that is really still
quoted example text inside it. When a requirement matches more than one heading, any one of
them carrying content satisfies it, and a requirement named more than once is checked once,
not refused twice. An empty section is refused as "empty", a missing heading as "missing".
`revision` and `blocked` outcomes are never checked against `Spec.ReportRequirements`.

### A reroute after acceptance reopens the chunk

`State.Accepted` reads true only while a chunk's latest attempt both closed `accepted` AND
has never since been named by a reroute — `Attempt.Outcome` itself never changes once
closed (the ledger is append-only), but a non-empty `Attempt.RerouteReasons` means that
first-pass disposition has been superseded. Every reader of `Accepted` — `ReadySet`,
`WaitingOn`, `NotReadyReason`, and the wrap gate below — treats a chunk that reads false
this way as claimable again, not as permanently done: a failed integration discovered only
after a chunk was already marked accepted is the real case this exists for. `chunk.claim`
opens a fresh attempt against it under whatever request the reroute pointed at, the earlier
accepted attempt untouched on the ledger, and any dependent that was waiting on it waits
again until the new attempt closes accepted in turn.

### A reroute that reopens an accepted chunk leaves its dependents stale

Reopening a chunk after it was accepted is the user's call, and so is everything built on
it. When a `chunk-rerouted` event reopens a chunk whose latest attempt was accepted,
Fold marks every *transitive* dependent whose own latest attempt is accepted as **stale**,
recording the chunk that reopened (`chunk.TransitiveDependents` is the one function that
computes the set). A dependent that is not yet accepted is not marked: it simply waits on
the upstream, as it always has. A reroute of a chunk that was not accepted — an open
attempt, or one a reroute already reopened — reopens nothing and marks nothing.

The mark is derived, never stored on an event: a journal that predates it folds to exactly
the same state it always did, and replaying any prefix of a journal yields that prefix's
marks. A stale chunk is still accepted — its ledger is untouched — but it is waiting on
the user, who answers one of two ways. Rerouting it reopens it, clears its own mark, and
marks *its* dependents in turn, so the cascade is a sequence of explicit decisions, never
an automatic one. Or `chunk.affirm {chunk_id, reason}` records that it stays accepted: the
`chunk-affirmed` event clears the mark and changes nothing else. The reason is required, the
chunk must currently be stale, and the verb is legal in the same phase window as the rest.
The engine never affirms and never reopens on its own; there is no cap on how many times a
chunk can be reopened, because each reopening is somebody's call.

The graph check below refuses while any chunk is stale, naming each with its upstream, and
`ChunkStatus` carries `stale` and `stale_upstream` so a resuming host sees the same thing.

### An unfillable reroute is refused, and the user picks the way out

A reroute produces a new offer — a preferred class and the fallback it may degrade to — and
the host that has to fill it may not be able to. `chunk.reroute` therefore computes the offer
it would produce and refuses with `chunk_unassignable` when nothing on the *current*
manifest can fill it, leaving the journal untouched. "Can fill" is not restated: it is
`chunk.Fillable`, which asks `chunk.Resolve` — the rule a claim answers to — about every
class, so the manifest's classes and modes, the chunk's required tools and context, the
effective minimum, the floor, and whether the class was offered at all all count, and cannot
drift from what a later claim would allow. A `contract-question` with no explicit target is
never refused this way; it returns to the main thread unconditionally.

The refusal lists every class the host can fill for that chunk (`chunk.FillableTargets`, which
leaves out a class below the chunk's floor), each with the executor `[execution.classes]` maps
it to — the mcp layer knows the mapping and the domain does not — so the user picks a model
that exists. The reroute is then re-issued with `target`, an explicit `RoutingTarget` that
replaces the routing-table entry for that one reroute (`chunk.RerouteTo`, the same code the
table path runs). It is validated exactly like an entry in the table (`chunk.CheckRerouteTarget`:
`RoutingTarget.Validate`, never below the floor, a contract question only to main-thread), and the
event records it, so the ledger shows a person chose it.

A target is also held to a stricter fillability bar than a table-driven reroute, because the point
of the pick is naming a model the user knows is available (`chunk.TargetFillable`, which still asks
`Fillable`). A class-only target needs that exact class fillable — on the manifest, at or above
the floor, requirements met; class and min need at least one class in `[min, class]`; a
main-thread target needs the manifest to offer the main thread; a min-only target needs a
delegated class at or above it. A main-thread rung that merely rides along in the chunk's
fallback does not rescue a delegated pick: `{class: deep}` on a mechanical-only host is refused
even when the fallback includes main-thread, with the same list of what the host can fill. The
table path keeps the offer-level check, since a main-thread fallback there is a rung the spec's
author chose.

### Leaving the chunk window, and wrap, verify a declared graph closed

Chunk work is legal only from `contracts-landing` through `self-review`, and one function,
`chunkWorkLegalIn` (`internal/ritual`), says so for both the chunk verbs and the gate that
guards the window's exit. Approving or submitting past the last phase inside it refuses
while any declared chunk lacks an accepted attempt or is stale — otherwise a chunk reopened by a late
reroute would be stranded where nothing can claim it, and the run could never wrap.

`ritual.wrap` checks the same thing again at the end: every chunk the run's
latest declare names must have a latest attempt that closed accepted — reopened by a
reroute since, and it counts as not closed again — or wrap refuses, listing every chunk
still pending, and every chunk that is stale (above). A run that never declared a graph has
nothing to check here and always passes.

### Every mutating chunk verb carries an optional caller identity

`chunk.declare`, `chunk.claim`, `chunk.report`, `chunk.reroute`, and `chunk.affirm` each take optional
agent and harness fields, the same shape the `ritual.*` mutating verbs already take. When a
call states either, the resulting event is attributed to that caller rather than to
whichever actor originally started the run — useful once a chunk is claimed and reported
by different processes over a run's lifetime. Neither field is required; an omitted pair
falls back to the run's own starting actor, exactly as it did before these fields existed.

### The execute gate trusts an undeclared run and verifies a declared one

The evidence a run submits to clear its execute-phase gate names the chunk ids it claims
are done. A run that never called `chunk.declare` is held to exactly what this gate always
asked for: a non-empty list, taken on the driver's word — the same behavior every
definition had before chunk verbs existed, so a run that started under rules with no way
to declare a graph keeps resuming under those rules.

A run that *did* declare a graph is checked for real, against its own ledger: every
submitted id must name a currently declared chunk whose latest attempt closed accepted,
and every currently declared chunk must be named — nothing declared may go unmentioned.
The two ways a submission can fall short — a named chunk that isn't actually accepted, and
a declared chunk that was silently left off the list — are reported as separate reasons,
every offending id listed, so a refusal never leaves the caller guessing which one
happened. Declaring is the one thing this gate can hold a run to; it's what buys the
stronger check.

### An attempt snapshots the characteristics in force when it opened

`chunk.claim` records `Attempt.Provenance` — `Spec.Complexity` and the routing-relevant
`Request.Risk`, `Request.Judgment`, `Request.Context`, `Request.RequiredTools`,
`Request.RequiredContext`, `Request.RequiredCapabilities`, and `Request.Preferred` exactly
as they stood at the moment the attempt opened — rather than leaving a reader to
re-derive them from the chunk's CURRENT `Spec`/`Request`. A human may legitimately
re-declare a chunk's characteristics between attempts (the user earlier chose that a
human's re-declaration is honored, not frozen out), so without a snapshot, rates
attribution for an attempt closed under one set of traits would silently shift to whatever
the chunk's traits happen to read as by the time someone queries rates — snapshot, not
freeze, is what keeps "how did `balanced` work actually land" answerable after a chunk's
own routing was later revised. The same snapshot is what a manifest re-declare is held to
(see "A re-declared `Manifest` is checked the same way" above):
`Request.RequiredTools`/`Request.RequiredContext`/`Request.RequiredCapabilities` bind
through a spec edit exactly as `Request.Risk`/`Request.Judgment` bind through one for
rates.

The snapshot also carries its own version, so a reader never infers completeness from
which fields happen to be set. Fold is the only place a snapshot is interpreted, and at
the moment a `chunk-attempt-opened` event is folded it reads the version three ways:

- **Current:** kept exactly as recorded.
- **Older, absent included:** the whole snapshot is derived from the spec exactly as it
  stood in the journal at that point, and any partial fields the event carried are
  ignored. That is always correct, because a claim takes its snapshot from that same spec;
  an older version only ever recorded less of it. It is never today's spec, which a
  re-declare may have edited since.
- **Newer than this binary:** refused. Fold fails the whole run load, naming the run, chunk
  path, attempt sequence and version, because a binary can't know what a version it has
  never heard of still lacks.

Every reader downstream, rates attribution and the manifest re-declare check alike, trusts
a folded `Attempt.Provenance` outright and never falls back to the chunk's current
`Spec`/`Request`.

A Fold error — an unrecognized future snapshot version among them — surfaces exactly like
a corrupt journal does, because it comes back from the identical `Load` → `Fold` sequence
every `ritual.*`/`chunk.*` verb and every `mindmeld://run/...` resource read shares. A
resource read maps it to the same not-found response an unknown run gets. A `ritual.*` or
`chunk.*` verb call maps it to an unstructured internal-error string with no machine paths
in it — the full detail, including the run id, chunk path, attempt sequence and offending
version, is still logged operator-side, but the caller sees only that something internal
went wrong, never a structured, in-band refusal the way an ordinary gate or conflict is
reported.

### Cross-run outcome rates are a read-only query, aggregated outside this package

`chunk.Outcomes` (and its `*Rate` methods — `FirstPassRate`, `AcceptedRate`,
`RevisionRate`, `BlockedRate`, `VerificationFailedRate`, `ReroutedRate`) tallies how one
run's attempts landed, grouped by the class an attempt was actually assigned and by a
chunk's own snapshotted traits (`Attempt.Provenance`, read directly — Fold has already
completed whatever an older snapshot version left incomplete by the time this query ever
sees it, so there is nothing left to fall back to) — pure, derived from `Spec` and `State`
alone, and scoped to one run. An attempt whose
`Attempt.RerouteReasons` is non-empty counts as rerouted in these tallies regardless of its
own `Attempt.Outcome` — a reroute against an attempt that was still open closes it
`OutcomeRerouted` with the first reason appended together, while a reroute against an
attempt already closed some other way (typically `accepted`) leaves that `Attempt.Outcome`
exactly as recorded and only appends to `Attempt.RerouteReasons` — so the reasons list, not
the outcome, is the one signal both paths agree on. The same signal is why an attempt that
closed `accepted` but was later named by a reroute does not count as first-pass accepted:
`Attempt.Outcome` stays `accepted` forever, append-only, but a non-empty
`Attempt.RerouteReasons` means a reroute superseded that first-pass disposition the moment
it landed. `internal/mcp`'s
`RitualEngine.RoutingRates` is the layer above it: it walks every run this machine's
journal can discover, folds each one, and aggregates their per-run `chunk.Outcomes` into
one answer, optionally narrowed to runs whose project matches. That aggregate is served
read-only at `mindmeld://routing-rates{?project}` — a resource, never a verb, because it
mutates nothing — and never 404s: a machine that has never declared a chunk graph, or a
project filter matching nothing, is a legitimate empty aggregate, not a not-found.

## Invariants

- No harness, model, or vendor vocabulary anywhere in this package — an assignment's
  executor is an opaque string this package stores and never interprets.
- There is no separate "claimed" event or state: `chunk.claim` resolves an assignment and
  opens an attempt in the same act, and an attempt's ledger entry always carries a
  complete, resolved assignment.
- The attempt ledger never rewrites a recorded attempt — closing only ever completes the
  ledger's own open last entry, and every earlier field of it — sequence number and
  assignment above all — is immutable from the moment it's appended.
- The `rerouted` outcome is never a value `chunk.report` accepts from a driver — only
  `chunk.reroute` produces it.
- Class validity and rank both resolve through one shared vocabulary value, never a
  hardcoded switch beside a hardcoded map — the seam a future configurable vocabulary
  replaces without touching a call site.
- `main-thread` is reserved across the whole package: unranked, never a legal minimum, and
  always a legal terminal rung for a fallback chain.

## Related
- [mindmeld mcp](../commands/mcp.md) — the five chunk verbs' wire shape and refusal kinds
- [Concepts](../concepts.md#executor-classes-and-routing) — the portable vocabulary and
  where routing policy lives
- [Configuration](../config.md#execution) — the machine-local `[execution.classes]` table
