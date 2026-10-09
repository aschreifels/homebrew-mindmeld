# Your first session

`spawn-session` opens a session; `wrap-session` closes it. Between them sits the
dossier — the plan you sign off on before any code gets written. This walkthrough
runs one session start to finish so you know what to expect: the commands, the
pause point, and the report lines.

## Spawn: kick off the work

```bash
/spawn-session my-cool-feature ENG-1234
```

The session runs through the engine's own ritual — **open → dossier → contracts
landing → execute → behavioral → self-review → integrate** — pausing at the dossier
gate for your plan signoff and again at self-review for findings arbitration. A
ticket handle is optional — `/spawn-session my-cool-feature` works without one.

The branch gets named from what you passed:

| Case | Branch name |
|---|---|
| With ticket | `{branch_prefix}/{TICKET}_{feature-name}` |
| Without ticket | `{branch_prefix}/{feature-name}` |

## The dossier: what gets written before any code

The session writes a planning dossier outside the repo, symlinked into the
worktree as `_plan/`. `MANIFEST.md` is the living index — its frontmatter tracks
session state (`state: open | dossier | contracts-landing | execute | behavioral
| self-review | integrate | wrapped` — the plane's own phase ids, not a
translated set), the live chunk map, and the open-question count:

```text
_plan/
  MANIFEST.md      # living index — session state, live chunk map, links
  plans/           # versioned plan snapshots — append-only, never edited in place
  adr/             # ADR-style pattern & architecture docs
  contracts/       # the typed seams — signatures, invariants, gen implications
  chunks/          # one dir per chunk — NN/{brief,questions,report}.md
  handoff/         # review notes, wrap handoff
```

## The pause ritual: what you see next

Once the first full draft is ready, the session stops and posts a digest to chat
instead of starting to code:

- One short paragraph on what's being built and the pivot worth flagging.
- The chunk map as a compact table (id, title, parallel group).
- ADRs and contracts, one line each, as clickable paths.
- Every open question inline, in full, with its code refs as clickable links.
- The dossier path, so you can open it in your own editor.

Then it waits:

> "The dossier is drafted at `_plan/` — plan, ADRs, and contracts are ready for
> review in your editor of choice. Answer the open questions here or directly in
> the files (just tell me to re-read the dossier). Give me the word to start
> execution."

Nothing gets coded until you answer.

## Execution, then self-review

Once you give the word, chunks run through the standard loop — brief, execute
(delegated to a sub-agent by default, or inline under `--solo` — the
session asked which at open, and that answer holds for the rest of the run),
review the diff, accept, commit — one chunk at a time or in parallel groups
where the file sets don't overlap. After every chunk lands, a behavioral pass
and a self-review follow.

Self-review runs `pr-review` in self-review mode against the branch. It writes a
punch list to `.mindmeld-review/branch-<branch>.md` — findings grouped by severity
with stable IDs (`B1`, `H2`, …) — and lets you steer it in plain language:
`drop B2`, `fix B1` (previews the edit, asks before applying), `fix all B`,
`commit` (drafts a commit message). It never pushes and never applies a fix
without your yes.

## Wrap: closing out

```bash
/wrap-session
```

or `/wrap-session my-cool-feature --delete-branch`. Wrap runs safety checks first —
any uncommitted or unpushed work stops it and hands the decision back to you, and no
flag skips that — then finalizes the ticket, harvests reusable docs to the KB, removes
the worktree, and reports a tight summary:

```text
- **Worktree:** removed at `<path>`
- **Dossier:** archived to `<dossier_archive_dir>/<repo>/<name>` (a sibling root outside `<dossier_dir>`)
- **Session archive:** captured / failed (reason) — never blocks
- **Branch:** deleted / kept (`<branch>`)
- **Ticket:** finalized / comment posted on `<TICKET>` / skipped (reason)
- **Harvest:** N doc(s) promoted to the KB / flagged as follow-ups / skipped (nothing to promote)
- **Patterns:** N candidate(s) swept to the review queue (arbitrate via `mine review`) / skipped (nothing to sweep)
- **Skill edits:** N file(s) landed on `<branch>` (`<sha>`) / none this session / skipped (not symlinked)
- **Voice:** captured N note(s) to the corpus / skipped (no signal)
- **KB landing pass:** committed `<sha>` (`<N>` file(s)) / nothing to land
- **Sync:** N commit(s) pushed / already up to date / refused (`<reason>`) / failed (`<reason>`)
- **Warnings:** anything left behind that the wrap did not own (e.g. files a peer session left dirty in the KB)
```

Before wrap ever runs, the session itself opens a draft PR as its own closing
step — the one push it's pre-authorized to make:

```bash
git push -u origin {branch_name}
gh pr create --draft --title "{title}" --body-file _plan/handoff/wrap.md --base {base_branch}
```

Draft, never ready-for-review — marking it ready is your call.

## What landed in the KB

By the time wrap finishes, the dossier has done its job: any ADR marked
`promotion: kb-pattern` or `kb-decision` was generalized and written into your
KB, a swept pattern candidate (if any) is quarantined in the review queue for
`mine review`, and a few voice-corpus notes may have been appended if you edited
any prose this session. The full dossier itself — chunk reports, review
findings, answered questions — moves to an archive directory, not deleted.

## If it didn't go that way

| Symptom | Look here |
|---|---|
| Config file missing, or `--init` needed | [commands/init.md](../commands/init.md) |
| Session or wrap behavior didn't match this page | [rituals/spawn-session.md](../rituals/spawn-session.md), [rituals/wrap-session.md](../rituals/wrap-session.md) |
| Something else looks broken | [troubleshooting.md](../troubleshooting.md) |

## Related

- [rituals/spawn-session.md](../rituals/spawn-session.md) — the full ritual reference
- [rituals/wrap-session.md](../rituals/wrap-session.md) — the full close-out reference
- [rituals/pr-review.md](../rituals/pr-review.md) — PR mode vs. self-review, rubric packs
- [walkthroughs/first-mining-run.md](first-mining-run.md) — what happens to a swept pattern next
- [concepts.md](../concepts.md) — the rings this session writes into
