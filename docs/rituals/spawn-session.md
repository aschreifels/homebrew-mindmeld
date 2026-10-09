# spawn-session

mindmeld's session-opening ritual. It turns "let's build X" into a reviewable plan
before a line of production code exists, then runs execution under whichever mode
you answer at open — sub-agent delegation, or the main thread with `--solo` — so
your attention goes to review, not typing.

## What it accomplishes

- Checks out a correctly-named feature branch inside your already-open worktree.
- Optionally pulls context from an existing ticket, drafts a new one, or seeds
  context from a KB article.
- Builds a plan dossier — versioned plans, ADR-style pattern docs, typed
  contracts — that you sign off on before any code is written.
- Runs execution in orchestrator mode: asks at open whether chunks may be
  delegated to sub-agents or must run on the main thread, then reviews
  each diff before it lands either way.
- Opens a draft PR at the end so the finished changeset is ready for review.

## When you run it

Trigger: `/spawn-session` — or in plain words, "let's start work on X",
"spawn a session for X", "new feature X", "kick off TICKET-123". Full
invocation:

```
/spawn-session <feature-name> [TICKET-HANDLE] [--draft] [--team <TEAM>] [--kb <ref>] [--solo]
```

- `<feature-name>` — required, kebab-case.
- `TICKET-HANDLE` — an existing ticket handle; pulls its title, description, comments.
- `--draft` — creates a new ticket in the configured default project instead.
- `--team <TEAM>` — overrides the default project for a drafted ticket.
- `--kb <ref>` — seeds session context from a knowledge-base article (slug,
  title fragment, or natural-language query).
- `--solo` — the delegation "no," answered up front instead of asked: chunks
  execute on the main thread instead of via sub-agents. First-class, not a
  fallback — the dossier and review phases still run exactly the same.
- `--init` — first run, or `mindmeld.toml` missing: delegates to `mindmeld init`,
  the engine's own setup path, instead of starting a session. The skill defines no
  configuration of its own; `mindmeld doctor` shows what an existing instance
  already looks like.

## What it writes

| What | Where |
|---|---|
| Feature branch | renamed to `{branch_prefix}/{TICKET}_{feature-name}` (or `{branch_prefix}/{feature-name}` without a ticket) |
| Dossier | `_plan/` — symlinked into the worktree from `{dossier_dir}/{repo}/{TICKET}_{feature-name}` |
| Drafted ticket | when `--draft` is passed — see [kb-ticket](kb-ticket.md) for the KB-native path |
| Draft PR | opened at close-out; title under 70 chars, body derived from the dossier's wrap handoff |

The dossier is a directory, not a single file:

- `MANIFEST.md` — the only file edited in place: live chunk map, links to the
  current plan/ADRs/contracts, open-question count.
- `plans/` — versioned snapshots (`001-initial.md`, `002-post-review.md`, …),
  never edited after the fact — a revision is a new file.
- `adr/` — one pattern or structural decision per doc, each with a Shape
  section (pseudo-code) sub-agents are held to.
- `contracts/` — the typed seams between chunks: signatures, invariants, and
  a table of who writes and reads each field.
- `chunks/` — one directory per chunk of work.
- `handoff/` — the close-out summary that seeds wrap-session's harvest.

## How it runs

- The engine owns the ritual — phase order, gates, evidence, and required
  artifacts — and serves it over the control plane. The skill drives that
  plane and conducts the conversation around it; it never decides what
  happens next on its own.
- A run is durable: it can be resumed in a fresh session, by a different
  agent, with no chat context, because the phase, the artifacts, the
  answered questions, and the approvals are all journaled rather than
  remembered.
- The human gates are still human gates: plan signoff at the dossier pause,
  and findings arbitration at self-review.
- The dossier is unchanged as a thing you read and edit — what changed is
  that its documents are also recorded on the run, so the plane can resolve
  them instead of trusting that they exist.

### Delegation, asked at open

Before the run opens, the session asks whether execution chunks may be
delegated to sub-agents or must run on the main thread — every session, not
a one-time setup question. On the Claude Code harness, a standing
instruction blocks calling the Agent tool unless you asked for it, and the
ritual has no way to see that instruction, so the question gets asked
instead of assumed. See [Adapters](../adapters.md) for what an adapter is
responsible for translating in general.

The answer travels as a capability declaration on `ritual.start`, and it's a
ceiling, not a promise: a run that may delegate can still execute any chunk
inline, but the ceiling can't be raised mid-run — restarting under a
different declaration reads as a conflict with the run already in flight,
not a change of terms. `--solo` is the flag form of "no," answered without
asking, and it's a first-class path: every phase runs exactly the same either
way, in the same order and under the same gates — only who types the code
changes.

### Declaring a chunk graph

Once the dossier is signed off, a run can declare its chunk map as durable state rather
than leaving it as a table only the dossier remembers — a chunk's id, its dependencies,
and the executor class it wants, journaled alongside everything else on the run. That
buys three things a plain "done" list can't: a resuming session — new chat, a different
agent, a different machine — reads the whole dependency graph and attempt history back
instead of re-deriving it from the dossier; the execute phase's gate is held to the
declared graph for real, checking that every declared chunk actually closed accepted
rather than trusting whichever ids a submission happens to list; and each chunk's
executor is negotiated against what the session actually declared it can do this run, with
a recorded reason whenever the class a chunk gets isn't the one it asked for. Declaring a
graph is optional — a run that never declares one is held to exactly what it always was,
a non-empty list of what got done, taken on the driver's word.

### The arc

Named here as a description of the shape, not a rule the skill enforces —
the engine is what actually holds a run to this order:

1. **Open** — branch cut, ticket resolved or drafted, worktree confirmed.
2. **Dossier** — the plan, ADRs, and contracts get drafted. This phase's
   gate is a human approval, not evidence: nothing is coded until you sign
   off. Once the first full draft is ready you get a digest in chat — what's
   being built, a chunk-map table, links to every ADR and contract, and
   every open question inline with clickable code refs. Answer in chat or
   edit the dossier files directly — either way, execution waits for your
   word.
3. **Contracts landing** — the hardened contract types land as real,
   committed code, gated on a passing gate-command output, before any other
   chunk is briefed — so every executor codes against actual types instead
   of promises.
4. **Execute** — chunks run through the brief/review loop, delegated to
   sub-agents or run inline depending on what you declared at open.
   The session that drafted the plan stays in charge of it — it never
   switches models mid-session — and reviews the real diff for each chunk
   rather than trusting an executor's own account of what it did.
5. **Behavioral** — the behavioral spec run, gated on its own passing
   output.
6. **Self-review** — `pr-review` runs in self-review mode against the
   branch; findings arbitration is the second human gate.
7. **Integrate** — the draft PR opens and the run's close-out artifacts
   land.

Config it reads: [`[kb]`](../config.md#kb) (root, owner),
[`[defaults]`](../config.md#defaults) (branch_prefix, base_branch,
worktree_dir, dossier_dir, projects_dir),
[`[project_management]`](../config.md#project_management) (provider,
default_project, prompts), and [`[review]`](../config.md#review) (the tool
spawn-session offers to open the dossier in at the pause).

## Instance ring

Every dossier template and prompt resolves through the instance ring first:
`{kb.root}/skills/spawn-session/<asset>` overrides the packaged copy. A miss
there — the common case on a fresh install — isn't an error; it just means
you haven't customized anything yet.

## Related
- [wrap-session](wrap-session.md) — closes the session this ritual opens
- [kb-ticket](kb-ticket.md) — the ticket backend when `provider = "kb"`
- [concepts](../concepts.md) — what a dossier, chunk, and orchestrator mean
- [config](../config.md) — the full `mindmeld.toml` schema
- [adapters](../adapters.md) — what a harness adapter translates, including the
  standing instruction behind the delegation question
- [first-session walkthrough](../walkthroughs/first-session.md) — a worked example
