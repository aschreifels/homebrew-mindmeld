# Your KB, directory by directory

`mindmeld init` stamps a minimal viable KB at `{kb.root}` — additive and
idempotent, so re-running it against an already-scaffolded KB is a no-op
walk. This page is the map: what each directory holds, who writes to it,
and whether an engine update ever touches it.

## The wiki layer

| Directory | What lives there | Who writes it | Engine updates touch it? |
| --- | --- | --- | --- |
| `raw/` | Immutable source material — imports, clippings. Never modified. | you | no |
| `wiki/` | LLM-compiled knowledge articles. | your agent | no |
| `wiki/_index.md` | Master index, every article listed with a one-line summary. Carries a `merge=ours` git attribute so a synced clone's local edits win on merge conflicts. | your agent | no |
| `wiki/_hot.md` | The pulse cache `mindmeld hot` regenerates — open work and recent activity, read verbatim by the `SessionStart` hook. Derived-local: gitignored, regenerated, never committed. Absent on a fresh clone until something regenerates it. | mindmeld (`mindmeld hot`) | no |
| `projects/` | Per-project extracted knowledge. | your agent | no |
| `research/` | Topic-based research deep dives. | your agent | no |
| `solutions/` | Reusable technical solutions. | your agent | no |
| `tools/` | Tools evaluated or used. | your agent | no |
| `decisions/` | Architectural decisions with reasoning and outcome. | your agent | no |
| `patterns/` | Recurring patterns, one flat file each. | your agent / `mindmeld sweep` | no |
| `ideas/` | Unrealized project ideas and exploration notes. | you | no |
| `people/{owner}/` | Your identity home — person doc, `voice.md`, and the `voice/` corpus. | you / your agent | no |
| `sessions/` | Extracted session insights (via the mining organ). | your agent | no |
| `output/` | Transient query results and reports. | mindmeld / your agent | no |

## The review queues

| Directory | What lives there | Who writes it | Engine updates touch it? |
| --- | --- | --- | --- |
| `tickets/` | KB-native tickets, one sub-dir per project (`tickets/<project>/<HANDLE>_<slug>.md`). Backs the spawn/wrap rituals when `project_management.provider = "kb"`. | [spawn-session](rituals/spawn-session.md) / [wrap-session](rituals/wrap-session.md) / [kb-ticket](rituals/kb-ticket.md) | no |
| `candidates/` | The mining review queue — quarantined drafts, empty until mining lands one. Scaffolded even when empty because `init` registers it as its own qmd collection on every run, so day-one recall already knows about it. | `mindmeld mine` | no |

## The instance and templates

| Directory | What lives there | Who writes it | Engine updates touch it? |
| --- | --- | --- | --- |
| `templates/` | `ticket.md`, `pattern.md`, `decision.md`, and `templates/dossier/` — seeded from the engine, then yours. Seed-tracked, the same three-way sync as `*.base` below: an edited template is never destroyed, only replaced or merged when the seed proves your copy hasn't diverged from what was last stamped. See "The seed: how ownership is tracked and handed off" below. | mindmeld seeds, then you | yes — three-way merged on `mindmeld update` against your edits, never overwritten in place |
| `skills/` | The instance ring — the sanctioned home for anything a shipped skill can't hold (a repo-specific rule, a personal convention). `init` creates it once and never touches it again. | you | no |
| `skills/README.md` | Explains the instance ring's resolution order. Copy-if-absent — unlike `templates/`, its content never gained a schema of its own, so there's nothing for a three-way sync to protect here yet. | mindmeld stamps once | no |
| `*.base` (six files) | The Obsidian boards, copied as-is from the engine. Machine-local: not committed, seeded once at install. | mindmeld seeds, then you | yes — three-way merged on `mindmeld update` against your edits, never overwritten in place |

### The seed: how ownership is tracked and handed off

Both rows above are seed-tracked: alongside the live file, mindmeld keeps a third,
machine-local copy — `.mindmeld/bases-seed/<name>` for a board, `.mindmeld/templates-seed/<name>`
for a template — recording exactly what was last stamped there. That third copy is what lets
`mindmeld update` tell your edit apart from a shipped release moving on, so it can bring
a file current without ever guessing which side changed.

The seed's presence is not itself a promise never to touch the file — a board or template
with no seed on record and no edit either (an install predating this mechanism, or a seed
you just deleted from an otherwise-untouched file) still gets tracked automatically the
next time `update` or `init` runs over it: live still matches shipped, so the legacy-
adoption rule re-stamps the seed right back. **Deleting the seed only hands off ownership
if the file has also diverged from shipped** — with the file edited, `update` finds no
seed and a live copy that doesn't match shipped, so it leaves the file alone from then on,
exactly like an adopter's edit predating the mechanism, because there is no longer a common
ancestor to compare against. Delete the seed on a file you haven't touched and the next
sync is a no-op that undoes it.

### The tombstone: handing a file off unconditionally

Deleting the seed only works as a hand-off when the file has already diverged from
shipped — if it still matches (you never touched it, or you edited it back to
identical), the very next sync re-adopts it, because "no seed, live matches shipped" is
indistinguishable from a KB that predates seed-tracking entirely. Absence in the seed
directory means two different things — *never tracked* and *deliberately released* — and
a two-way read of "is there a seed" can't tell them apart.

The tombstone records the intent absence can't express: an empty file named
`<the file>.mindmeld-unmanaged`, sitting right next to the live file it releases —
`templates/decision.md.mindmeld-unmanaged`, `Tickets.base.mindmeld-unmanaged` at the KB
root. Its content is never read; only its presence matters. Once it's there, `update`
leaves that file alone unconditionally — regardless of whether live matches shipped,
regardless of what the seed says, regardless of whether live exists at all — on every
run, on every machine, silently (no repeated warning), until you remove it. Create it by
hand (`touch templates/decision.md.mindmeld-unmanaged`); removing it is how you hand
management back, and the very next sync falls through to whatever the seed/live/shipped
comparison says at that point, exactly as if the tombstone had never existed.

It's committed KB content, not a sibling of the seed — and that placement is the whole
point, not an accident. Seeds are machine state: `.mindmeld/` is gitignored, so
`.mindmeld/templates-seed/<name>` is only ever *this machine's* record of what it last
stamped. A tombstone written there would hand a file off on one machine and silently
re-adopt it the next time a second machine — one whose own `.mindmeld/` has never heard
of the decision — runs `init` or `update`. Ownership is a decision, and a decision has to
travel with the KB the way the rest of `templates/` already does, so the tombstone lives
inside the committed tree instead, next to the file it releases.

This is also the forward path for a file you edited *before* you ever ran seed-tracked
`update` on it — a pre-existing customization with no seed on record reports as
`unmanaged — cannot merge without a seed` on every single run, forever, with nothing that
run alone can do to stop it (this is the honest, sanctioned "customized" state doctor
already rolls into its healthy count, not a bug). Create the tombstone next to it and
that warning stops for good: it's the same mechanism as handing a board or template off
outright, because from the engine's point of view they're the same fact — this file is
yours, stop asking.

### One asymmetry, stated: templates never prune

`docs/mindmeld/` (below) prunes a page `init` once stamped but no longer ships — `update`
removes it on its own. `templates/` deliberately does not: a live template (or board)
whose seed names it, but whose name no longer appears in what this checkout ships, is
left exactly where it is, forever. This is a decision, not a gap — "never delete" is this
project's default posture for anything KB-side, and a template you added yourself, or one
a past release retired, is exactly the kind of content that default protects; deleting a
file you might still be using because *the engine* stopped shipping a same-named one
would be a worse failure mode than leaving it be. `doctor` still names what it finds —
an informational line listing any orphaned template seeds, with no repair action
attached, because there's nothing to repair, only something worth knowing about.

## Root files

| Path | What lives there | Who writes it | Engine updates touch it? |
| --- | --- | --- | --- |
| `AGENTS.md` | The KB's harness-neutral instructions file — a short orientation paragraph plus two includes, `@OWNER.md` and `@docs/mindmeld/kb-schema.md`. Carries no schema content of its own. Left as-is if already present. A harness that hard-codes its own instructions filename (Claude Code's `CLAUDE.md`, for one) gets a generated shim from its adapter pointing here — see [Adapters](adapters.md). | mindmeld stamps once, then you | no |
| `OWNER.md` | Your Owner Context — the ~120-token slot loaded every session, via `AGENTS.md`'s include. Left as-is if already present. | mindmeld stamps once, then you | no |
| `docs/mindmeld/kb-schema.md` | The paradigm schema — the seven entity types, required fields, status enums, and ticket type-specifics every KB shares. One page of the guide (see the `docs/mindmeld/` row below), engine-owned rather than instance-owned, so it never goes stale the way a one-time stamped copy would. | mindmeld stamps at init | yes — refreshed by `mindmeld update` |
| `.gitignore` / `.gitattributes` | KB git config, including the `merge.ours.driver` registration `wiki/_index.md`'s merge attribute needs. | mindmeld stamps once | no |
| `.mindmeld/schema.toml` | An extended KB schema, only if you choose to fork one. Not scaffolded by `init` — created only by running `mindmeld lint --seed-schema`. See [mindmeld lint](commands/lint.md). | you, via `mindmeld lint --seed-schema` | no |
| `docs/mindmeld/` | This guide — stamped into your KB, mindmeld-managed. Machine-local: gitignored, regenerated by `init`/`update` from that machine's own binary, never committed. See [mindmeld docs](commands/docs.md). | mindmeld stamps at init | yes — refreshed by `mindmeld update` |
| `adapters/<adapter>/notes.md` | The active `[install]` adapter's notes.md, stamped so a spawn-session driver can actually open the path its `SKILL.md` points at (the durable-workers answer, among other harness facts). Only the active adapter's notes ever land here; a prior adapter's stale copy is pruned on the next `init`/`update`. Machine-local: gitignored, mindmeld-managed. See [Adapters](adapters.md). | mindmeld stamps at init | yes — refreshed by `mindmeld update` |
| `adapters/<adapter>/manifest.json` | The active adapter's declared chunk-execution capabilities, stamped beside `notes.md` the same marker-guarded way (JSON carries the marker as top-level `mindmeld_managed`/`mindmeld_version`/`mindmeld_source` members). `chunk.declare` reads it as the default manifest and its ceiling, and `doctor` diagnoses it against the routing policy. Only the active adapter's lands here; a stale copy is pruned on the next `init`/`update`. Machine-local: gitignored, mindmeld-managed. See [Adapters](adapters.md). | mindmeld stamps at init | yes — refreshed by `mindmeld update` |

## Related

- [Getting started](getting-started.md) — what `init` walks through to
  produce this layout.
- [Concepts](concepts.md) — the rings this layout implements, including
  the instance ring.
- [Configuration](config.md) — the KB instance spec and what `init` touches
  outside the KB itself.
