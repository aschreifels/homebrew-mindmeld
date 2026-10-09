# mine-review

Session mining turns agent transcripts into candidate knowledge-base drafts —
quarantined at `{kb}/candidates/`, never touching the KB proper until you say so.
mine-review is the human-in-the-loop pass that drives that whole surface: survey
what's unmined, run the miner, then walk every candidate and decide whether it's
worth keeping. It's the only place a candidate is ever promoted.

## What it accomplishes

- Surveys unmined sessions and the pending-review count before doing anything, so
  you know what you're deciding on before the mining step even runs.
- Runs `mindmeld mine run`, and for any session whose extraction deferred to the
  agent path, fans out one sub-agent per bundle in parallel to finish it — each
  sub-agent follows the bundle's own generated `BRIEF.md`, not the skill's prose.
- Walks the `mindmeld mine review` queue with you: presents each candidate's type,
  domain, confidence, tags, sources, and anchor count, gives its own read, and
  waits for your word before promoting or rejecting.
- Ends with the same reindex-then-commit landing pass every KB-writing ritual uses.

## When you run it

Run `/mine-review`, or say "review the mining queue", "what's pending in mine
review", "run the miner", "mine my sessions", "check mining status". Run it on your
own cadence — end of day or end of week — not every session: the mining
counterpart to voice-distill's.

## What it writes

| path | when |
|---|---|
| `{kb}/candidates/<slug>.md` | a bundle's `candidates.json` lands via `mine land` |
| `patterns/{slug}.md` (or the candidate's own type directory) | on `mine promote <slug>` — always flat, never under a per-project subdirectory |
| `state/mining.jsonl` | one ledger row per outcome — mined, landed, gated, promoted, rejected |

A rejected candidate is removed from `candidates/`; the ledger row plus the
deleted file's git history is the only trail it leaves, which is why `mine reject`
always requires `--reason`.

## How it runs

1. **Survey** — `mine status --json`: unmined-session and pending-review counts,
   reported plainly before anything else runs.
2. **Mine** — `mine run`, scoped by whatever you asked for (`--project`,
   `--limit`, `--session`). The local extractor finishes in-process; the agent
   extractor writes one bundle directory per session and stops. For every bundle
   left pending, fan out one sub-agent per bundle in parallel — each reads
   `BRIEF.md` and `transcript.md`, writes `candidates.json` (an empty array is a
   complete, correct answer), and runs `mine land --bundle <dir>` for its own
   bundle only.
3. **Review** — `mine review --json`: every candidate gated in but not yet
   promoted or rejected. You arbitrate every promotion; the skill only presents
   its own read, it never calls `promote` unattended.
4. **Landing pass** — `mindmeld reindex` (when `mindmeld` is present) to make a
   promotion recallable, then `git add` + `git commit` in the KB. A promoted
   candidate isn't really in the KB until this runs.
5. **Report** — sessions surveyed, how many mined and by which extractor, bundles
   deferred to sub-agents and what each wrote, candidates promoted vs. rejected
   with reasons, and the final queue state. An empty queue or an all-empty mining
   run are both fine things to report plainly.

Full flag reference for `mine`'s subcommands (`status`, `run`, `land`, `review`,
`promote`, `reject`, `ledger`, `archive`, `prune`) lives on
[../commands/mine.md](../commands/mine.md) — this page is the review ritual built
on top of that surface.

## Related
- [../commands/mine.md](../commands/mine.md) — full flag reference for every `mine` subcommand
- [voice-distill](voice-distill.md) — the other end-of-day/week review cycle
- [../config.md](../config.md) — `[mining]`, `[mining.recurrence]`, `[sweep.promotion]`
