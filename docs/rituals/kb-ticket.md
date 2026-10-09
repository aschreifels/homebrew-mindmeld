# kb-ticket

A ticket doesn't have to live in an external tracker. kb-ticket makes a ticket a
plain markdown file in your KB — git-audited, qmd-searchable, wikilinked to the
rest of your notes — so spawn-session and wrap-session can run the full ticket
ritual against mindmeld's own MCP plane: no external tracker, no third-party
connector, and no network call — the plane is a local stdio server.

## What it accomplishes

kb-ticket is a thin driver over the engine's `ticket.*` verbs — the mechanics
below (handle allocation, landing pass) live in `internal/ticket`, not in the
skill. Explaining them is this page's job; the skill only drives the verbs.

- Turns a ticket into a markdown file under
  `{kb.root}/tickets/<project>/<HANDLE>_<slug>.md`.
- Allocates handles deterministically from the project name and the existing
  tickets on disk. The MCP `ticket.*` surface *is* this allocator — there's
  no separate unlocked path; it locks per handle prefix, so concurrent
  sessions serialize on allocation instead of racing into a collision.
- Exposes create/fetch/update/finalize/list verbs. spawn-session and
  wrap-session delegate to kb-ticket, which drives these verbs, when
  `project_management.provider = "kb"`.
- Runs the same lint → reindex → commit landing pass after every write —
  `create`, `update`, `finalize` — so the board and search stay current with
  what's on disk. `fetch` and `list` are read-only and skip it.

## When you run it

Trigger phrases: "create a ticket", "file a ticket for X", "ticket
`<PREFIX>-3`"-style handle lookups, "show the backlog", "what's on the
board", "move `<PREFIX>-2` to active" — or automatically, whenever
spawn-session or wrap-session delegate ticket operations under the `kb`
provider.

kb-ticket is conversational, not a command you type — there is no
`kb-ticket` binary. What actually exists is five `ticket.*` verbs a host
exposes as tools; match on the verb name, not on any spelling below.

| Verb | Arguments |
|---|---|
| `create` | `project`, `title`, `priority` (optional), `status` (optional), `body` (optional), `idempotency_key` (optional) |
| `fetch` | `handle` |
| `update` | `handle`, `progress` (optional), `checklist_done` (optional), `status` (optional), `reason` (required when `status` moves to `dropped`, at least 8 characters; optional otherwise) |
| `finalize` | `handle`, `outcome` (optional), `drafted_run` (optional), `branch` (optional), `pr` (optional), `successors` (optional), `status` (optional), `expected_revision` (required when `drafted_run` is true, optional otherwise) |
| `list` | `project` (optional), `status` (optional) |

## What it writes

| Verb | Writes |
|---|---|
| `create` | a new ticket file, frontmatter seeded from `{kb.root}/templates/ticket.md` (or the built-in shape); handle allocated and reported |
| `fetch` | nothing — reads and returns the matching file; the driver follows wikilinks one hop |
| `update` | appends progress to the body, checks off completed sub-items, bumps `updated:`; status moves update frontmatter; moving to `dropped` also writes `dropped_reason:` from `reason`, moving off it clears `dropped_reason:` |
| `finalize` | rewrites the description to what was built (drafted ticket) or appends an Outcome section (pre-existing ticket); checks off done sub-items; flips `status: done` (or `in-review` if a PR is still open) |
| `list` | nothing — reads frontmatter across `tickets/` and renders a table |

Every write above ends with the landing pass, unconditionally.

## How it runs

**Path shape:** `{kb.root}/tickets/<project>/<HANDLE>_<slug>.md`. Frontmatter
carries `type: ticket`, `ticket: <HANDLE>`, `project`, `status`
(`backlog | active | in-review | done | dropped`), `priority`
(`p1 | p2 | p3`), plus the fields every KB article requires. The body is a
problem statement, acceptance criteria, and `- [ ]` sub-items.

**Handle allocation** — the single source of truth for the whole engine,
implemented in `internal/ticket` (`handlePrefix`/`splitSegments`), not the
skill:
- Prefix: split the project name on `-` **and** `_`. For a multi-segment
  name, each segment contributes its whole self uppercased when the segment
  is 4 characters or fewer, otherwise just its first letter. A single,
  unsegmented name uppercases whole when ≤4 characters, otherwise takes its
  first 3 letters.

  | Project | Handle prefix | Branch exercised |
  |---|---|---|
  | `nickel-kb` | `NKB` | multi-segment, long + short |
  | `mercury_web` | `MWEB` | underscore split, long + short |
  | `cab` | `CAB` | single segment ≤4, whole |
  | `mindmeld` | `MIN` | single long segment, first 3 |

  These four rows are literal cases from `tests/unit/ticket/ticket_test.go`,
  which pins five in total (the fifth, `moonbeam` → `MOO`, exercises the same
  branch as `mindmeld` a second time). Nothing ties this table to the test
  mechanically, so treat both as accurate as of this reading rather than as
  guaranteed to move together.
- Sequence: the max existing number for that prefix across the *whole*
  `tickets/` tree — including `done/` and any other status subdirectories —
  plus one. Read from filenames (unambiguous), cross-checked against
  frontmatter; the higher of the two wins.
- A handle is spent the moment it's issued. Finishing or dropping a ticket
  never returns it to the pool.

**Idempotent create.** `create`'s `idempotency_key` (optional) makes a
retried call safe. The check runs under its own key-scoped lock, acquired
BEFORE the per-prefix lock handle allocation above uses — a scan for the
key outside a lock would be a race by construction, the same way an
unlocked handle scan would be, and a lock scoped to the handle prefix alone
isn't enough on its own: the scan for a key covers every project, so two
callers racing the SAME key against two DIFFERENT projects need to
contend against each other directly, not merely against other callers
allocating from the same prefix. The key is written onto the ticket's own
frontmatter (`idempotency_key:`), so any later call carrying it can be
answered from disk alone, with nothing held in a driver's own memory:
- The same key, with the same `project`, returns the ticket already on
  disk — no new handle, no new write — regardless of what `title` the
  replay sends. The landing pass DOES re-run against the existing file, so
  its warnings reflect the ticket's CURRENT landing state rather than
  whatever the original call happened to report: a replay of a Create whose
  git commit failed the first time reports that same warning again, never
  silently clean, until it actually lands. Re-running lint/reindex/commit
  against an already-landed file is cheap and safe — the commit step checks
  `git status` first and makes no new commit when nothing has changed.
- The same key with a genuinely different `project` is refused outright, so
  a key collision can never answer with the wrong ticket — including when
  two callers race the SAME key against two different projects at the same
  time: the key-scoped lock above serializes them, so exactly one creates
  the ticket and the other is refused, never both. `title` is never
  compared: the caller most likely to replay a `create` call is a resumed
  host recovering from a crash, and the title it would recompute is
  model-written prose it has no durable record of — requiring an exact
  match would make the recovery case the one most likely to spuriously
  conflict. `priority`/`status`/`body` are excluded for a related reason:
  `priority`/`status` are the ticket's own mutable state (`update`/
  `finalize` move them after creation, so comparing a replay against
  whatever they currently are would make a perfectly legitimate replay
  conflict with itself the moment anything else touched the ticket first),
  and `body` is either template-resolved boilerplate or content, neither of
  which defines "the same ticket."
- No key (the default) is the pre-existing behavior: every call allocates a
  fresh handle.

**A keyed create fails closed on a ticket of its own project it can't read.**
The scan for `idempotency_key` exists to prove the key's uniqueness, so a
ticket file it can't read or parse — corrupted frontmatter, a zero-byte
file, a permissions problem — refuses the create outright rather than
treating the unreadable file as "not a match." The one file the scan can't
read might be exactly the original ticket that key already names; silently
skipping it would mint a second ticket for a request that already
succeeded once. The fix is repairing the named file (`mindmeld lint`
surfaces exactly what's wrong), never retrying without a key.

That refusal is scoped to files that could be this request's ticket: the
ones under the request's own `tickets/<project>/` directory, or whose
filename claims its handle prefix. Replay identity is the project, so a
ticket in any other project can never be this request's replay — its being
unreadable says nothing about this key, and the scan skips it exactly as a
keyless create does. One mangled file in an unrelated project therefore
can't stall every keyed create (and so every wrap finalize) in every other
project. The cross-project guarantee holds: a READABLE ticket in another
project that holds the same key still refuses the reuse as
`idempotency_key_conflict`. A keyless `create` never scans for a key at
all.

**Dropping a ticket requires a reason.** `update` refuses to move `status` to
`dropped` without a `reason` of at least 8 characters — before any file is
touched. The reason is persisted verbatim as frontmatter `dropped_reason`
and returned on every ticket response; moving the status back OUT of
`dropped` clears it. `reason` is optional for every other status move. A
ticket dropped before this existed, or hand-edited straight to
`status: dropped`, simply carries no `dropped_reason` — never an error, just
something a recovering driver has to ask a human about instead of reading
out of the ticket's body (see [wrap-session](wrap-session.md)'s own
recovery procedure).

**Compare-and-swap finalize.** Every verb's response carries a `revision` —
a content hash of the ticket file's current bytes. `finalize`'s
`expected_revision` feeds that value back in: pass it and the call compares
it, under the same lock, against the ticket's revision at the moment of the
write. A mismatch refuses before anything is touched — the ticket changed
since whatever read handed you `expected_revision`, so the caller should
re-fetch rather than overwrite a change it never saw. `expected_revision` is
**required** when `drafted_run` is true — that branch rewrites the whole
body, so there is nothing non-destructive to fall back to — and optional
when appending.

**Finalize only mutates a mutable ticket.** `finalize` checks the ticket's
CURRENT on-disk `status` before writing anything, inside the same lock:
`backlog`, `active`, and `in-review` are the only statuses it will move —
`done` (`finalize`'s own prior output) and `dropped` (a human's own
terminal call) both refuse outright, as does any value outside the
documented lifecycle. This runs *after* the revision compare-and-swap
above, so a stale `expected_revision` is reported as a revision conflict
first and a terminal status only once the revision itself checks out — the
more useful diagnosis either way, since a caller with a genuinely stale
read learns that first, and a caller whose revision is already current
still gets the terminal refusal right behind it. A `dropped` ticket in
particular carries a person's own explanation for stopping; `finalize`
refusing to touch it is what keeps a resumed or retried caller from
silently overwriting that call.

**Refusals are structured.** A refused verb comes back as a failed call
(`isError: true`) whose structured content carries
`error: {kind, message, handle?, current_revision?, status?}` — the same
envelope shape `ritual.*` refusals use. A driver branches on `error.kind`,
never on `message`. The kinds, one per typed ticket error:

| Kind | Raised by | Extra fields |
|---|---|---|
| `idempotency_key_conflict` | `create`: the key already names a ticket in a different `project` | `handle` (the ticket the key claims) |
| `idempotency_unverifiable` | `create`: an unreadable ticket file in the request's own project (see above) | `handle` (the unreadable file's handle, never a path) |
| `revision_conflict` | `finalize`: `expected_revision` is stale | `handle`, `current_revision` |
| `expected_revision_required` | `finalize`: `drafted_run` without `expected_revision` | `handle` |
| `terminal_status` | `finalize`: the ticket is `done`, `dropped`, or unrecognized | `handle`, `status` |
| `dropped_reason_required` | `update`: moving to `dropped` without a real `reason` | `handle` |
| `not_found` | `fetch`/`update`/`finalize`: no such handle | `handle` |
| `invalid_status` | `finalize`: `status` isn't `done` or `in-review` | `handle`, `status` (the rejected value) |
| `invalid_request` | any: malformed `project` or `handle` | — |
| `ambiguous_handle` | `fetch`/`update`/`finalize`: two files claim one handle | `handle` |
| `identity_mismatch` | `fetch`/`update`/`finalize`: one file's filename and frontmatter handles disagree | — |
| `handle_contention` | `create`: allocation retried past its bound | — |
| `lock_unavailable` | `create`/`update`/`finalize`: the ticket lock wasn't acquired in time | — |
| `internal` | anything else; the message carries no machine path | — |

A landing-pass failure is not a refusal: the write stands, so the result is
the populated ticket with `unlanded: true` and a `repair` string. Full wire
detail is in [mcp](../commands/mcp.md).

**Landing pass**, run by the engine after every write (`create`, `update`,
`finalize` — never `fetch` or `list`), from `kb.root`:
1. Lints the file it just wrote — in-process, scoped to that one path, not
   a `--changed` git diff, since the verb already knows exactly which file
   it wrote. A failure means the write **stands but is unlanded**: the
   ticket file exists on disk and the handle is spent, but nothing past
   this step ran. The repair is to fix the reported issues and re-run the
   lint, then re-land — never re-create the ticket, which would burn a
   second handle on the same content.
2. Reindexes, in-process, so the ticket is searchable — best-effort; a
   failure surfaces as a warning on the response, not a failed write.
3. Commits, scoped to exactly that one file (`git add` / `git commit` on
   the single path, never a blanket add) — also best-effort, with its own
   warning and repair text on failure.
4. Commits `wiki/_index.md`, if step 1 left it dirty, in its **own** commit
   after the ticket's. Step 1's lint reconciles the index across the whole
   KB, not just the path it was given, so a ticket write routinely
   regenerates it; without this step it would sit dirty in your working
   tree. Also best-effort.

   Because the index is built from the whole tree, that commit can include
   entries for articles you haven't committed yet — its commit message says
   so. They're derived, the next reconcile corrects them, and `sync`
   registers a `merge=ours` driver for this file so the cross-machine case
   resolves to "keep ours" rather than a conflict.

**The board:** `Tickets.base` is the visual view over the same frontmatter
`list` reads — status, priority, project, one board for everything
kb-ticket touches.

**Composition with spawn/wrap:** the skill drives the verbs below; the
engine owns the mechanics documented above.
- spawn-session calls **fetch** (handle passed) or **create**
  (`--draft`, `status: active`, project defaults to the current repo) — the
  returned handle rides the branch name.
- wrap-session calls **finalize**.
- Mid-session progress updates call **update** as chunks land.

Config it reads: [`[kb]`](../config.md#kb) (root, owner) and
[`[project_management]`](../config.md#project_management) — `provider =
"kb"` is what makes the rituals default here; "available" just means
`[kb].root` exists, and you can ask for a KB ticket explicitly under any
provider.

## Instance ring

Every asset resolves through two places, instance ring first:
`{kb}/skills/kb-ticket/<asset>`, falling back to the packaged copy. Nothing
in kb-ticket resolves an override from there today — an absent
`{kb}/skills/kb-ticket/` directory is the normal, healthy state, not a gap.
If a house rule earns a home later (a stricter handle scheme, a different
acceptance-criteria shape), it lands there rather than in a fork of this
skill.

## Related
- [spawn-session](spawn-session.md) — calls fetch/create when opening a session
- [wrap-session](wrap-session.md) — calls finalize when closing one
- [config](../config.md) — the `[kb]` and `[project_management]` schema
- [commands/lint](../commands/lint.md) — the gate the landing pass runs
