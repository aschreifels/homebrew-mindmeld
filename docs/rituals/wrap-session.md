# wrap-session

Bookend to [spawn-session](spawn-session.md). It's not just teardown — it's the
point where the session's insight gets promoted into things future sessions
inherit (the ticket, the KB, your voice corpus) before the worktree disappears
and takes the dossier's live copy with it.

## What it accomplishes

- Runs safety checks for uncommitted or unpushed work before doing anything
  destructive. There's no way to skip this — a dirty tree stops the wrap
  until you commit, push, or stash.
- Finalizes the ticket: rewrites a drafted ticket to reflect what was
  actually built, adds a completion comment to a pre-existing one, or — when
  no ticket is in play — asks whether to proceed without one or create one
  now to capture the session.
- Harvests dossier ADRs marked for promotion into KB patterns or decisions,
  and closes out any KB brief that spawned the session.
- Sweeps the landed diff for reusable patterns nobody explicitly marked,
  queuing candidates for later review — asking at open whether that sweep
  may run as a delegated sub-agent or must stay on the main thread.
- Lands any skill edits made mid-session back onto the skills checkout.
- Captures voice signal — corrections, vocabulary, framing — into your voice
  corpus.
- Removes the worktree, archives the dossier, and optionally deletes the
  branch.

## When you run it

Trigger: `/wrap-session` — or in plain words, "wrap up this session", "clean
up the worktree for X", "close out this feature", "remove the worktree".
Runs from inside the worktree (auto-detected) or from anywhere given a
feature name:

```
/wrap-session [feature-name-or-path] [--delete-branch | -D]
```

- `[feature-name-or-path]` — optional; auto-detects the current worktree
  from `cwd` when omitted. If given, resolved as either a worktree path or a
  feature name to match against `git worktree list`.
- `--delete-branch` / `-D` — also delete the git branch after removing the
  worktree.

There's no force flag. A dirty tree or unpushed commits always stop the wrap
for you to resolve — there's no path through a bad safety result other than
fixing it.

## What it writes

| What | Where |
|---|---|
| Ticket update | finalized directly (MCP provider), or via [kb-ticket](kb-ticket.md)'s finalize verb when `provider = "kb"` |
| KB patterns/decisions | `{kb.root}/patterns/` or `{kb.root}/decisions/` — promoted ADRs, generalized |
| Swept pattern candidates | `{kb.root}/candidates/` — queued for review, not yet promoted |
| Voice capture | `{kb.root}/people/{kb.owner}/voice/<YYYY-MM-DD>.<host-id>.md` |
| Session archive | via `mindmeld mine archive` |
| Archived dossier | `{dossier_archive_dir}/{project}/{branch}/{run_id}` — a sibling root outside `dossier_dir`, never a subdirectory of it |

## How it runs

- The engine owns the ritual — phase order, gates, evidence, and required
  artifacts — and serves it over the control plane. The skill drives that
  plane and conducts the conversation around it; it never decides what
  happens next on its own.
- A run is durable: it can be resumed in a fresh session, by a different
  agent, with no chat context, because the phase, the artifacts, the
  answered questions, and the approvals are all journaled rather than
  remembered.
- The safety phase is the one hard stop. Everything after it degrades
  rather than blocks: a missing project-management connector, an
  unreachable KB remote, or a refused sync gets reported and the wrap keeps
  going — the worktree still has to come down either way.
- Wrapping a branch a second time doesn't start a new run or resume the old
  one — a wrapped run accepts no commands. It reports what the first wrap
  did: the ticket outcome from finalize, the handoff artifact from harvest,
  and whether teardown actually removed the worktree.
- Wrapping a branch whose prior run already finished archiving doesn't start
  a new run either: the engine keeps a durable receipt of a completed
  archive, so a session discovering the coordinate cold reports what that
  archive did — the run id, when, and where it landed relative to the
  archive root — instead of opening a second run over an already-closed
  one. A retried archive call after a lost response is safe on its own too;
  it returns the same receipt rather than moving anything twice.

### Delegation, asked at open

Before the run opens, the session asks whether the harvest phase's
librarian sweep — which fans a sub-agent out over the changeset to catch
patterns nobody marked — may run as a delegated sub-agent or must stay on
the main thread. Asked every session, the same as spawn-session's
execution question, because the ritual has no way to see a harness's own
standing instruction about spawning sub-agents. Declining delegation
doesn't remove the human from harvest — the sweep still runs, just on the
main thread instead — and the ceiling can't be raised mid-run: restarting
under a different answer reads as a conflict with the run already in
flight.

### The arc

Named here as a description of the shape, not a rule the skill enforces —
the engine is what actually holds a run to this order:

1. **Safety** — identifies the worktree, from a given name or path or
   auto-detected from `cwd`, then audits it for uncommitted changes and
   commits that haven't reached the remote. Either one raises a blocker for
   you to resolve before anything else runs.
2. **Finalize** — best effort against whichever project-management provider
   is configured. With a ticket handle in play, it's rewritten or commented
   to reflect what was actually built. Without one, you're asked whether to
   proceed as a ticketless wrap or create a ticket now and finalize into it
   instead.
3. **Harvest** — the promotion walk (ADRs marked `kb-pattern` or
   `kb-decision` written into the KB, generalized; anything marked
   `repo-docs` folded into this repo's own `docs/`; a KB brief that spawned
   the session closed out with an outcome), the librarian sweep (bundles
   the diff, briefs a sub-agent or runs inline per the delegation answer,
   lands candidates into the review queue for later arbitration via
   `mine review`), landing any mid-session skill edits back onto the skills
   checkout, voice capture, and the KB landing pass that lints, reindexes,
   and commits everything the phase wrote. The gate here is a human
   approval over the harvest's handoff summary, not automatic evidence.
4. **Teardown** — stops any preview pointed at the worktree, archives the
   session transcript, syncs the KB, removes the worktree, archives the
   dossier (never deletes it), and deletes the branch only if you asked for
   that.

Config it reads: [`[kb]`](../config.md#kb) (root, owner),
[`[defaults]`](../config.md#defaults) (base_branch, dossier_dir, dossier_archive_dir),
[`[project_management]`](../config.md#project_management) (provider, the
finalize prompt).

## Instance ring

Every reference this ritual's craft resolves through the instance ring
first: `{kb.root}/skills/wrap-session/<asset>` overrides the packaged copy.
A miss there — no override, or no `{kb.root}/skills/wrap-session/`
directory at all — is the normal, healthy state for a fresh install and
isn't reported as an error.

## Related
- [spawn-session](spawn-session.md) — the ritual this one closes out
- [kb-ticket](kb-ticket.md) — finalize verb, called in the finalize phase
- [mine-review](mine-review.md) — where swept pattern candidates get judged
- [voice-distill](voice-distill.md) — compiles the captured voice corpus
- [commands/sweep](../commands/sweep.md) — the sweep the harvest phase drives
- [commands/sync](../commands/sync.md) — the KB sync the teardown phase runs
