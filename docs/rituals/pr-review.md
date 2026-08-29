# pr-review

pr-review turns a diff — a GitHub pull request, or your own branch mid-flight — into
a structured set of findings you work through before anything reaches GitHub or your
working tree. It never posts a comment and never applies a fix without you saying so.

## What it accomplishes

- Two modes on one rubric: **PR mode** produces a polished review draft, optionally
  posted to GitHub as inline comments. **Self-review mode** produces a self-directed
  punch list for a branch you're actively working on, with fixes it can apply and a
  commit message it can draft.
- Routes the diff to domain rubric packs — security, correctness, performance,
  conventions, maintainability always run; tests, db, api, and ui load only when
  their own gate matches the diff.
- Applies any repo-specific overlay that matches, from either ring (see Instance
  ring below).
- Presents findings grouped by severity (Blocker / High / Medium / Low / Question)
  with a stable ID per finding, so `drop H3` always means the same thing across a
  session.
- Default posture is *do not post, do not apply* — both are explicit,
  confirmation-gated actions.

## When you run it

Say "review this PR", "review PR `<url>`", "review my branch", "self-review", "code
review this branch", or run `/pr-review`.

Mode is picked in order: an explicit `--pr` / `--self` flag wins; a PR reference
(URL, `owner/repo#N`, bare number) selects PR mode; self-review-shaped phrasing
("review my branch", "review what I've done") selects self-review; with no
reference, a branch that already has an open PR defaults to PR mode, otherwise
self-review.

## What it writes

| file | mode | contents |
|---|---|---|
| `.claude-review/PR-<num>.md` | PR | verdict, routing line, findings by severity |
| `.claude-review/branch-<branch-slug>.md` | self-review | status, scope, findings by severity |

Both are appended to `.gitignore` on first write — the file is a working draft for
your editor, not something you'd commit.

## How it runs

Phases: parse → mode-select → fetch → detect → route → analyze → present → iterate
⇄ refine → finish (mode-specific).

- **Fetch** — PR mode pulls the diff, file list, and existing comments via `gh`;
  self-review reads local git state (`git diff <base>...HEAD` by default;
  `--uncommitted`, `--staged`, `--all` widen the scope).
- **Detect & route** — computes which languages and stacks the diff touches, then
  loads packs accordingly: always-on `_core`, `conventions`, `maintainability`, plus
  language-split `security`, `correctness`, `performance`; gated-in `tests`
  (language-split), `db`, `api`, `ui` (stack-split), each loaded only when its own
  pack's gate matches.
- **Analyze** — one sub-agent per loaded pack, reading the diff plus that pack's
  rules and any matching overlay sections. Findings are deduped, filtered by
  confidence, and every Blocker is sanity-checked before presenting.
- **Present** — findings grouped Blocker/High/Medium/Low/Questions, each with a
  stable ID (`B1`, `H2`, …) that never renumbers for the life of the session.
- **Iterate** — natural-language commands: `drop B2`, `keep only blockers`,
  `edit H2: …`, `merge B2 into B1`, `add a finding: …`, `re-scan`.
- **Finish** — PR mode: `preview post` then `post`, a GitHub review with inline
  comments, always confirmed before the `gh api` call runs. Self-review: `fix B1` /
  `fix all B` (preview an Edit, confirm, apply) and `commit` (draft a message,
  confirm, commit — never pushes).

## Instance ring

Repo-specific review rules live at `{kb}/skills/pr-review/overlays/<name>.md` — the
instance ring, owner-owned and never touched by an update. Each overlay is a small
markdown file with `applies_when` frontmatter (`repo`, `repo_regex`, `file_exists` —
all set conditions AND together) and severity-prefixed rule sections that augment
the universal rubric packs rather than replace them. Both rings load; instance
overlays win on conflict — a fresh install with no overlays yet still reviews fine
on the shipped packs alone.

## Related
- [wrap-session](wrap-session.md) — the ritual that closes out the branch pr-review evaluated
- [../config.md](../config.md) — the KB instance and instance-ring resolution order
- [../kb-layout.md](../kb-layout.md) — where `{kb}/skills/` sits in the KB tree
