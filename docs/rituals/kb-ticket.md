# kb-ticket

A ticket doesn't have to live in an external tracker. kb-ticket makes a ticket a
plain markdown file in your KB — git-audited, qmd-searchable, wikilinked to the
rest of your notes — so spawn-session and wrap-session can run the full ticket
ritual with no network call and no MCP connector.

## What it accomplishes

- Turns a ticket into a markdown file under
  `{kb.root}/tickets/<project>/<HANDLE>_<slug>.md`.
- Allocates handles deterministically from the project name and the existing
  tickets on disk, so two sessions never collide on a handle.
- Exposes create/fetch/update/finalize/list verbs that spawn-session and
  wrap-session call directly when `project_management.provider = "kb"`.
- Runs the same lint → reindex → commit landing pass after every write, so
  the board and search stay current with what's on disk.

## When you run it

Trigger phrases: "create a ticket", "file a ticket for X", "ticket
`<PREFIX>-3`"-style handle lookups, "show the backlog", "what's on the
board", "move `<PREFIX>-2` to active" — or automatically, whenever
spawn-session or wrap-session delegate ticket operations under the `kb`
provider.

```
kb-ticket create <project> <title> [--priority p1|p2|p3] [--status <status>]
kb-ticket fetch <HANDLE>
kb-ticket update <HANDLE>
kb-ticket finalize <HANDLE>
kb-ticket list [project] [--status <status>]
```

## What it writes

| Verb | Writes |
|---|---|
| `create` | a new ticket file, frontmatter seeded from `{kb.root}/templates/ticket.md` (or the built-in shape); handle allocated and reported |
| `fetch` | nothing — reads the matching file, follows wikilinks one hop |
| `update` | appends progress to the body, checks off completed sub-items, bumps `updated:`; status moves update frontmatter |
| `finalize` | rewrites the description to what was built (drafted ticket) or appends an Outcome section (pre-existing ticket); checks off done sub-items; flips `status: done` (or `in-review` if a PR is still open) |
| `list` | nothing — reads frontmatter across `tickets/` and renders a table |

Every write above ends with the landing pass, unconditionally.

## How it runs

**Path shape:** `{kb.root}/tickets/<project>/<HANDLE>_<slug>.md`. Frontmatter
carries `type: ticket`, `ticket: <HANDLE>`, `project`, `status`
(`backlog | active | in-review | done | dropped`), `priority`
(`p1 | p2 | p3`), plus the fields every KB article requires. The body is a
problem statement, acceptance criteria, and `- [ ]` sub-items.

**Handle allocation** — the single source of truth for the whole engine:
- Prefix: initials of the project's hyphenated segments (`invoice-service` →
  `IS`); a single segment ≤4 chars uppercases whole (`api` → `API`); a
  single long segment takes its first 3 letters uppercased (`dashboard` →
  `DAS`).
- Sequence: the max existing number for that prefix across the *whole*
  `tickets/` tree — including `done/` and any other status subdirectories —
  plus one. Read from filenames (unambiguous), cross-checked against
  frontmatter; the higher of the two wins.
- A handle is spent the moment it's issued. Finishing or dropping a ticket
  never returns it to the pool.

**Landing pass**, run after every write, from `kb.root`:
1. `mindmeld lint --changed` — the schema/index/duplicate gate. A non-zero
   exit stops here; nothing lands past it.
2. `qmd update` (when `qmd` is present) — reindex, so the ticket is
   searchable.
3. `git add` + `git commit`.

**The board:** `Tickets.base` is the visual view over the same frontmatter
`list` reads — status, priority, project, one board for everything
kb-ticket touches.

**Composition with spawn/wrap:**
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
