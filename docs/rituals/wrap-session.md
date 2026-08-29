# wrap-session

Bookend to [spawn-session](spawn-session.md). It's not just teardown — it's the
point where the session's insight gets promoted into things future sessions
inherit (the ticket, the KB, your voice corpus) before the worktree disappears
and takes the dossier's live copy with it.

## What it accomplishes

- Runs safety checks for uncommitted or unpushed work before doing anything
  destructive.
- Finalizes the ticket: rewrites a drafted ticket to reflect what was
  actually built, or adds a completion comment to a pre-existing one.
- Harvests dossier ADRs marked for promotion into KB patterns or decisions,
  and closes out any KB brief that spawned the session.
- Sweeps the landed diff for reusable patterns nobody explicitly marked,
  queuing candidates for later review.
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
/wrap-session [feature-name-or-path] [--delete-branch | -D] [--force | -f]
```

- `[feature-name-or-path]` — optional; auto-detects the current worktree
  from `cwd` when omitted.
- `--delete-branch` / `-D` — also delete the git branch after removing the
  worktree.
- `--force` / `-f` — skip safety prompts and proceed despite uncommitted or
  unpushed changes.

## What it writes

| What | Where |
|---|---|
| Ticket update | finalized directly (MCP provider), or via [kb-ticket](kb-ticket.md)'s finalize verb when `provider = "kb"` |
| KB patterns/decisions | `{kb.root}/patterns/` or `{kb.root}/decisions/` — promoted ADRs, generalized |
| Swept pattern candidates | `{kb.root}/candidates/` — queued for review, not yet promoted |
| Voice capture | `{kb.root}/people/{kb.owner}/voice/<YYYY-MM-DD>.<host-id>.md` |
| Session archive | via `mindmeld mine archive` |
| Archived dossier | `{dossier_dir}/_archive/{repo}/{TICKET}_{feature-name}` |

## How it runs

1. **Identify the worktree** — from a given name or path, or auto-detected
   from `cwd`.
2. **Safety checks** — uncommitted or unpushed work stops here and asks what
   to do, unless `--force` was passed.
3. **Ticket finalization** — best effort; skipped if no ticket handle was
   parsed from the branch, the provider is `none`, or no connector is
   available.
4. **Dossier harvest** — ADRs marked `kb-pattern` or `kb-decision` get
   written into the KB, generalized; a KB brief that spawned the session gets
   closed out with an Outcome section.
5. **Pattern sweep** — bundles the diff, briefs a sub-agent to spot idioms
   nobody marked, lands candidates into the review queue. Arbitration happens
   later, via `mine review` — not in this phase.
6. **Skill edits land** — any mid-session skill edit is gated through the
   genericization check, then committed on the skills checkout's own branch.
7. **Voice capture** — a few high-signal corrections and vocabulary notes,
   appended to today's capture log. Never a transcript dump.
8. **KB landing pass** — lint, reindex, and commit everything the phases
   above wrote to the KB.
9. **Teardown** — stop any preview pointed at the worktree, archive the
   session transcript, sync the KB, remove the worktree, archive the dossier
   (never delete it), and delete the branch only if asked.

Steps 3 through 9 are all best-effort or fail-safe in the same spirit: a
missing MCP connector, an unreachable KB remote, or a refused sync gets
reported and the wrap keeps going — the worktree still has to come down
either way. The one hard stop is step 2; everything after it degrades rather
than blocks.

Config it reads: [`[kb]`](../config.md#kb) (root, owner),
[`[defaults]`](../config.md#defaults) (base_branch, dossier_dir),
[`[project_management]`](../config.md#project_management) (provider, the
finalize prompt).

## Related
- [spawn-session](spawn-session.md) — the ritual this one closes out
- [kb-ticket](kb-ticket.md) — finalize verb, called in the ticket phase
- [mine-review](mine-review.md) — where swept pattern candidates get judged
- [voice-distill](voice-distill.md) — compiles the captured voice corpus
- [commands/sweep](../commands/sweep.md) — the sweep this ritual drives
- [commands/sync](../commands/sync.md) — the KB sync this ritual runs
