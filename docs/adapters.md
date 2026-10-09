# Adapters

The content ring — `skills/`, `templates/`, `bases/`, `kb-scaffold/` — is not allowed to
say the name of the harness you run it in. That's what makes a skill portable: it states
a rule that holds everywhere, not one welded to a specific tool's paths and lifecycle
events. But something still has to speak the harness's actual language — install skills
where it looks for them, wire whatever hook mechanism it has, bridge its instruction-file
conventions if it hard-codes one. That's the adapter ring's job, and it's the one place
naming a harness is correct instead of a leak.

## What an adapter owns

`adapters/<adapter-name>/` is a real, shipped, versioned directory — not a declaration in
a doc, a directory the engine ships and the release tarball stages. Inside it:

- **`notes.md`** — harness facts a skill needs but must not carry itself. A skill states a
  rule that has to hold under any harness; where the *reason* for that rule is true of
  exactly one harness, the reason lives here instead, pointed to from the skill rather
  than welded into it. Each fact in the file is followed by the question it poses to
  whoever writes the next adapter — the file is a template as much as a record. A skill
  points at it by a KB path, not a checkout-relative one: `init`/`update` stamp the
  *active* adapter's `notes.md` to `{kb.root}/adapters/<adapter>/notes.md` (marker-guarded,
  the same posture as the guide — see [Your KB, directory by
  directory](kb-layout.md#root-files)), so a driver reading the skill can
  actually open the file the pointer names instead of reaching into a checkout it may not
  have.
- **`manifest.json`** — the host's declared chunk-execution capabilities, a plain
  `chunk.Manifest`: whether it has children, runs them in parallel, at what
  `max_concurrency`, whether it can pick a class per child, what `classes` it can fill,
  whether it can steer a live child or keep one durable, and what context and tools it
  provides. `chunk.declare` reads the stamped copy as both the default manifest and its
  ceiling, and `mindmeld doctor` reads the same file to diagnose the host against the
  resolved KB routing policy before a session starts. It is a fact about the harness, so
  it ships with the adapter rather than being composed by hand from `notes.md` prose.
- **A worked `[execution.classes]` mapping, in `notes.md`.** The engine treats the
  `mechanical`/`balanced`/`deep` values in `mindmeld.toml` as opaque strings — it copies
  them onto assignments and never interprets them — so what to put there for this
  harness's real model roster is the adapter's answer, written down in its `notes.md`.
  The table itself is machine-local config, not adapter content; see
  [Configuration](config.md#execution).
- **`slash-command.md`** (or whatever install-time content the harness needs) — instructions
  for wiring a harness-specific affordance, like installing a slash command at that
  harness's own commands path. This is adapter content, not skill content: a skill
  describes what to do, an adapter describes where this particular harness expects to
  find it.
- **The install step** — the actual code in `internal/initrun` and `internal/host` that
  places skills, wires hooks, and bridges instruction files for that harness. See
  [Configuration](config.md#what-init-touches-claude-code-adapter) for the exact host-path
  surface the shipped adapter writes to.
- **Registration** — pointing the harness at the `mindmeld mcp` control plane. Unlike the
  three items above, this one is expressed as a code contract, `host.Adapter`, rather than
  a directory convention: `Name`, `RegistrationSurface`, `RegistrationHint`,
  `ReadRegistration`, `WriteRegistration`. `internal/host` states what registration *is*
  (the same command, `{command} mcp`, addressable as a stdio server under every harness);
  the adapter states *where and how* one harness stores it. `initrun` and `doctor` both
  derive `want` through the one shared `host.MCPRegistrationFor`, so a doctor computing it
  differently from the installer — and reporting drift that isn't real — can't happen by
  construction. See [Configuration](config.md#what-init-touches-claude-code-adapter) for
  the `~/.claude.json` surface the shipped adapter registers against, and
  `adapters/claude-code/notes.md` for why that surface, not `settings.json` or the harness
  CLI, is the one the adapter writes to.

**The KB stamp.** `init` and `update` stamp the *active* adapter's `notes.md` and
`manifest.json` into `{kb.root}/adapters/<adapter>/`, marker-guarded: engine-owned and
refreshed in place while the marker survives, left alone once a reader strips it, and
pruned when a different adapter becomes the active one. `manifest.json` carries the
marker as top-level `mindmeld_managed`, `mindmeld_version`, and `mindmeld_source` members,
since JSON has no frontmatter. Skills and `doctor` read the stamped copies, never the
checkout.

The gate that keeps harness names out of the content ring never scans `adapters/` — by
construction, naming a harness there is the job, not a defect.

## Only one ships

Be plain about it: `claude-code` is the only adapter mindmeld ships today. This page's
job isn't to pretend at a generality the code doesn't have — it's to make the boundary
between "harness-neutral core" and "harness-specific adapter" something you can point at
and check, so that adding a second adapter is a contributor path rather than a refactor
of the whole engine.

## What adding a second adapter takes

Six concrete things:

1. **A directory.** `adapters/<adapter-name>/`, following the shape above.
2. **An entry in the adapter registry.** `host`'s `adapterConstructors` table is the one
   place "is this adapter supported" gets decided — `host.ResolveAdapter` is a lookup in
   it, and both `init`'s install step and `doctor`'s health check read that, on purpose,
   so there's exactly one answer to the question instead of two hand-kept copies that
   can drift. A new adapter name has to be registered there or it stays invisible to
   both.
3. **An install branch.** `initrun`'s adapter step resolves the name through
   `host.ResolveAdapter` and then always runs `installClaudeCodeAdapter`; a name that
   doesn't resolve is not skipped but fails the run
   (`initrun: unsupported [install] adapter`), with a repair line listing the supported
   names. A second adapter needs its own installer, selected by name at that call instead of the unconditional one.
4. **A `host.Adapter` implementation, registered as that entry's constructor.** This is
   registration only — the fourth thing an adapter owns, above — and it's deliberately
   scoped narrower than item 3: skills, hooks, and the instruction shim stay
   harness-hardcoded inside `installClaudeCodeAdapter` until MIN-66 generalizes the rest
   of the install step. A second adapter gets a working `mindmeld mcp` registration
   without waiting on that generalization, but nothing else for free.
5. **A `manifest.json`, stamped like `notes.md`.** The shipped `adapters/<name>/manifest.json`
   is what the engine and `doctor` read after the stamp step copies it into the KB.
   `chunk.declare` parses the stamped copy strictly (an unknown key is refused) and uses
   it as both the default manifest and the ceiling an explicit one may only narrow. An
   adapter without one can't run chunks — `chunk.declare` refuses `manifest_unavailable`
   — and a missing file is a warning at install time. Fill in its `classes` truthfully —
   they are what routing refuses or accepts against — and document the
   `[execution.classes]` mapping for your roster in `notes.md`.
6. **Answers to the questions `adapters/claude-code/notes.md` poses.** Each fact in that
   file — how this harness's worktree-leasing and diff panel behave, how it resolves an
   installed skill back to its source checkout, whether it reads a neutral instructions
   filename or hard-codes its own, and where it stores an MCP registration — is followed
   by the question a second adapter has to answer for its own harness. Some answers will
   be "same as claude-code"; some won't be, and the file is written so that difference
   gets recorded rather than silently inherited.

## The open question this doesn't solve

The KB's own instruction file, `AGENTS.md`, is a short file of includes — `@OWNER.md` and
`@docs/mindmeld/kb-schema.md` — resolved by whatever `@`-include mechanism the harness
supports. Claude Code has one, so the claude-code adapter never has to do anything beyond
generate the `CLAUDE.md` shim that points at it.

A harness with no `@`-include mechanism doesn't have that option — its adapter would need
to inline the include targets into a single file instead. That's deliberately left as a
question for whoever writes the second adapter, not designed here against a harness that
doesn't exist yet. Designing it now, with only one real harness to check assumptions
against, is how the first harness's quirks end up baked into something wearing a neutral
name.

## Related

- [Concepts](concepts.md#harness-adapters) — where the adapter ring sits among the
  others, and why the install is the source of truth.
- [Configuration](config.md#install) — the `[install]` table an adapter reads, and the
  full host-path surface the shipped adapter writes to.
- [Troubleshooting](troubleshooting.md) — the doctor lines that report adapter and
  instruction-file drift.
