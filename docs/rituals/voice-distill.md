# voice-distill

wrap-session captures raw voice signal every time you close a session — day-logs of
before/after edits, style corrections, real writing samples. That corpus grows
without limit. voice-distill is the compression pass: it rewrites the small,
curated `voice.md` that's actually loaded into context every session, so growth in
the corpus never becomes growth in what gets read.

## What it accomplishes

- Reads every undistilled day-log plus any samples you hand it, and produces a
  revised `voice.md` — a rewrite, not an append. Weaker guidance gets replaced or
  fused, never just stacked on top.
- Weighs real evidence over inference: a logged before→after edit, or a pattern
  from an actual artifact (a PR body, a design doc), outranks anything guessed from
  chat. When they conflict, the real evidence wins.
- Enforces a hard cap of about 150 body lines. If a revision would exceed it, the
  skill compresses harder rather than letting the doc grow.
- Shows you the change before writing anything — a diff or tight summary of
  adds/rewrites/cuts, plus the projected line count against the cap.

## When you run it

Say "distill my voice", "update my voice doc", "compress the voice corpus",
"refresh my voice doc", or hand over writing samples to fold in, or run
`/voice-distill`. Run it on your own cadence — end of day or end of week — not
every session.

Optional arguments: file paths or pasted text of real artifacts you wrote. With no
arguments, it distills from the corpus alone. If the queue is empty and no samples
were given, it says so and stops.

## What it writes

| path | what changes |
|---|---|
| `people/{owner}/voice.md` | rewritten body, `updated:` bumped — loaded via the AGENTS.md `@` include every session |
| `people/{owner}/voice/<date>.<host>.md` | each folded day-log flips `status: needs-distillation` → `status: distilled` — never deleted or moved |

`owner` resolves from `[kb].owner`; the identity home is `{kb.root}/people/{owner}/`.

## How it runs

1. **Gather** — read `voice.md`, every day-log still `status: needs-distillation`,
   and any samples you passed.
2. **Distill** — rewrite `voice.md` in place: merge new signal into the right
   section, sharpen rather than stack, fuse near-duplicate rules, compress toward
   the cap.
3. **Review gate** — show the proposed change and wait for your approval before
   writing anything.
4. **Commit** — write `voice.md`, flip the folded day-logs to `distilled`, then run
   the KB landing pass: `mindmeld lint --changed` (a non-zero exit is a stop — fix
   the reported files and re-run), reindex with `mindmeld reindex` when
   `mindmeld` is present, then `git add` + `git commit` in the KB. The commit is
   what carries the new voice to your other machines.
5. **Report** — what moved in `voice.md`, how many day-logs folded, final line
   count vs. cap.

## Instance ring

voice-distill doesn't resolve anything from `{kb}/skills/voice-distill/` yet — no
override file exists today. An absent or empty ring there is the normal, healthy
state, not a gap. If a per-owner variant ever earns a home — a different line cap
than the ~150-line default, a house style for what counts as signal — it lands
there rather than in a fork of the skill.

## Related
- [../config.md](../config.md) — `[kb]` `owner` and `root`, and the KB landing pass
- [mine-review](mine-review.md) — the other review cycle on the same end-of-day/week cadence
- [wrap-session](wrap-session.md) — the ritual that feeds the corpus this skill reads
