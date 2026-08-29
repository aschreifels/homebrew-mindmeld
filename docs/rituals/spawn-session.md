# spawn-session

mindmeld's session-opening ritual. It turns "let's build X" into a reviewable plan
before a line of production code exists, then hands the actual typing to sub-agents
so your attention goes to review, not typing.

## What it accomplishes

- Checks out a correctly-named feature branch inside your already-open worktree.
- Optionally pulls context from an existing ticket, drafts a new one, or seeds
  context from a KB article.
- Builds a plan dossier — versioned plans, ADR-style pattern docs, typed
  contracts — that you sign off on before any code is written.
- Runs execution in orchestrator mode: delegates chunks of work to Sonnet
  sub-agents and reviews each diff before it lands.
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
- `--solo` — skips sub-agent delegation; you execute chunks inline. The
  dossier and review phases still run.
- `--init` — first run, or `mindmeld.toml` missing: walks you through the
  config file interactively instead of starting a session.

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

Nine phases, in order: parse & load, ticket integration, branch, dossier,
contracts first, orchestrated execution, behavioral pass, self-review & fix
dispatch, integration pass & close-out.

Phase 4 — the dossier — is the one to slow down for. **Nothing is coded
until you sign off.** Once the first full draft is ready, you get a digest in
chat: what's being built, a chunk-map table, links to every ADR and contract,
and every open question inline with clickable code refs. Answer in chat or
edit the dossier files directly — either way, execution waits for your word.

From Phase 5 on: the hardened contract types land as real, committed code
before any other chunk is briefed, so every executor codes against actual
types instead of promises.

Orchestrator mode (Phase 6 onward): the session that drafted the plan stays
in charge of it — it never switches models mid-session. It writes the
briefs, spawns Sonnet sub-agents to do the actual typing, and reviews the
real diff for each chunk rather than trusting the sub-agent's own account of
what it did.

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
- [first-session walkthrough](../walkthroughs/first-session.md) — a worked example
