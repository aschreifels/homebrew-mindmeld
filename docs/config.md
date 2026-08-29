# Configuration

mindmeld's repo is laid out as one top-level directory per engine organ —
`bin/`, `skills/`, `hooks/`, `templates/`, `bases/`, `kb-scaffold/`, `docs/` —
so the tree itself documents what the engine ships. This doc is the schema
authority for the one piece of that layout every organ reads before it does
anything else: `mindmeld.toml`. If a key exists in `mindmeld.toml.example`,
it's documented here; if it's documented here, it exists in the example.
Neither file is allowed to drift ahead of the other.

## Resolution order

mindmeld resolves configuration in this order, highest precedence first:

1. **Environment variables**, set per-key by the consumer reading them (for
   example `MINDMELD_KB`, the override for `[kb].root`).
2. **`mindmeld.toml`**, found at `$XDG_CONFIG_HOME/ai/mindmeld.toml`, falling
   back to `~/.config/ai/mindmeld.toml` when `$XDG_CONFIG_HOME` is unset.
3. **Legacy `spawn.toml`**, read from the same directory when no
   `mindmeld.toml` exists yet — the pre-rename config file name.
4. **Nothing.** There is no hardcoded fallback path. A key nobody set
   degrades silently: the consumer that needed it declines gracefully rather
   than guessing a location.

`~` expansion is the *consumer's* job, not the file's — `mindmeld.toml`
stores tildes verbatim, and whatever reads a path expands it at the point of
use.

## Config vs KB — the delineation

mindmeld splits state across two places, and one question decides which one
any given piece of state belongs in — **would this be true on your other
machine?** If yes, it's KB. If no, it's config.

| | `mindmeld.toml` | the KB (`{kb.root}`) |
| --- | --- | --- |
| **Holds** | where things are and how this box behaves | what you think and how you work |
| **Scope** | one machine | one person, every machine |
| **Synced** | no — deliberately machine-local | yes — git-committed with the mind |
| **Shape** | scalars and paths | markdown and structure |
| **Examples** | `kb.root`, `install.adapter`, `install.skills_dir`, `install.hooks`, `review.command`, `defaults.worktree_dir` | `templates/`, `skills/<skill>/overlays/`, tickets, patterns, voice |
| **Reader** | the Go organs (`internal/config`) | the skills, at resolution time |

Three corollaries settle the cases people actually hit:

1. **`[kb] root` is the bridge, and the only one.** Config says *where* the
   mind lives; everything downstream of that path is the KB's business. A
   second config key pointing into the KB (`instance_dir`, `overlays_dir`, …)
   would reopen the same fork this rule closes — don't add one.
2. **A path is config; a policy is KB.** `worktree_dir` is config — this
   box's disk layout. "In these repos, migrations need a rollback note" is
   KB — true wherever you work.
3. **The portability test.** If a machine can't be recreated from
   `dotfile-manager apply` + `git clone <kb>` + `mindmeld init`, something is
   in the wrong place. That triple is why the instance ring (below) can't
   live beside the config: config is the one thing not synced.

Per-*repo* policy is deliberately not the instance ring's job — a repo's own
`AGENTS.md` already carries it, and a person-owned overlay's `applies_when:`
frontmatter is how it targets a repo. There's no third ring for repos.

## `[kb]`

The knowledge base itself — the one thing every other table exists to serve.

| key | type | required | default | who reads it |
| --- | --- | --- | --- | --- |
| `root` | path | **required** | none | every skill, hook, and script that touches the KB (spawn-session, wrap-session, kb-ticket, voice-distill, the pulse hook, qmd) |
| `owner` | string | **required** | none | anything resolving the identity home, `{kb.root}/people/{owner}/` — voice.md and the voice/ corpus |
| `remote_url` | string (git URL) | optional | none — unset means "not configured" | `init`, read on the ACQUIRE path only: clones from it when `root` is absent, falling back to `git init` exactly as today when unset. mindmeld never pushes to it — pushing is `mindmeld sync`'s job, against whatever `[sync].remote` resolves to |

`root` is the vault/store root: `tickets/`, `templates/`, and everything else
in "The KB instance" below live under it. It's the one value with its own
environment override (`MINDMELD_KB`) per the resolution order above.

`owner` is different in kind from every other key in this file — it isn't a
fact about the machine, it's a pointer into shared KB content. It has to
resolve to the same `people/{owner}/` directory on every machine that clones
this KB, or the identity splits: voice captures land in two places,
`voice.md` stops resolving from the one a session actually reads, and
nothing errors, because a directory existing was never the question.

`init` resolves it in this order: the config value, then the KB's own
identity home, then the OS username. A machine cloning a KB that already has
an identity adopts that identity rather than scaffolding a second one under
whatever this machine's username happens to be. An identity home is a
*non-empty* directory under `people/` — an empty one is exactly what a
mis-slugged `init` run leaves behind, so it doesn't count as an identity,
and a later run can still adopt the real one instead of reporting a
collision it caused itself.

`remote_url` is deliberately not named `remote`: `[sync].remote` one table
away is a remote *name* defaulting to `"origin"`, and two identically spelled
keys meaning different kinds of thing — a URL here, a name there — is a
footgun. `remote_url` is only ever read, never written: `init` clones from it
when `root` doesn't exist yet, and nothing in mindmeld pushes to it.

## `[defaults]`

Shared conventions for session-opening tooling (spawn-session and friends).

| key | type | required | default | who reads it |
| --- | --- | --- | --- | --- |
| `branch_prefix` | string | **required** | none | spawn-session, for every branch name it cuts |
| `base_branch` | string | optional | `"main"` | spawn-session (branch point), wrap-session (merge-back check) |
| `worktree_dir` | path | optional | none | spawn-session, when creating a new worktree |
| `dossier_dir` | path | optional | none | spawn-session, when creating a session's plan dossier |
| `projects_dir` | path | optional | none | spawn-session, to target the durable main checkout (e.g. editor-open links in dossier docs) |

The three `_dir` keys have no engine-level fallback — when omitted, the skill
that needs one applies its own built-in convention rather than assuming a
path.

## `[project_management]`

Which ticket backend a session's spawn/wrap ritual talks to.

| key | type | required | default | who reads it |
| --- | --- | --- | --- | --- |
| `provider` | enum: `kb` \| `linear` \| `notion` \| `jira` \| `none` | optional | `"kb"` | spawn-session and wrap-session, to pick the ticket backend; the `kb` default needs no MCP connector |
| `default_project` | string | optional | `""` | spawn-session's `--draft` flow, only when `provider` is an MCP provider (`linear`/`notion`/`jira`) |

Every key in this table is optional — an omitted `[project_management]`
table means `provider` defaults to `"kb"`, the zero-config, batteries-included
path: KB-native tickets, no MCP connector required.

### `[project_management.prompts]`

An optional sub-table overriding the skills' default ritual prompts. Omit any
key (or the whole table) to use the skill's built-in prompt.

| key | type | required | default | who reads it |
| --- | --- | --- | --- | --- |
| `fetch` | string (template) | optional | the skill's built-in prompt | spawn-session, how it reads a passed ticket |
| `create` | string (template) | optional | the skill's built-in prompt | spawn-session, how it drafts a `--draft` ticket |
| `finalize` | string (template) | optional | the skill's built-in prompt | wrap-session, how it closes the ticket out |

## `[review]`

Optional review hand-off during the pause ritual — how spawn-session offers
to open the plan or dossier for a human look before execution starts, and
renders code-ref links in the right flavor while planning.

| key | type | required | default | who reads it |
| --- | --- | --- | --- | --- |
| `command` | string (template) | optional | `""` | spawn-session, e.g. `open 'obsidian://open?path={plan}'` or `zed {dossier}` |
| `flavor` | enum: `"obsidian"` \| unset | optional | `""` | spawn-session, to pick which template variables `command` can use |
| `vault` | string | optional | `""` | spawn-session, when `flavor = "obsidian"` |
| `editor` | string | optional | `""` | spawn-session, as the editor-open command template (e.g. `zed {file}:{line}`) used to make dossier code-refs clickable into the main checkout — mirrored as an Obsidian Shell Commands command whose generated id goes in `editor_open_command_id` |
| `editor_open_command_id` | string | optional | `""` | spawn-session, to drive code-ref links during planning |

Every key in this table is optional — an empty `[review]` table (or the
whole section omitted) just means spawn-session skips the hand-off step.

## `[install]`

The adapter seam: which host tooling `mindmeld init` and `mindmeld doctor`
wire up, and how. `claude-code` is the only adapter v0 ships; the keys below
override its auto-detection.

| key | type | required | default | who reads it |
| --- | --- | --- | --- | --- |
| `adapter` | string | optional | `"claude-code"` | `bin/mindmeld init`/`doctor`, auto-detected from `~/.claude` when omitted |
| `skills_dir` | path | optional | `""` | the adapter, to override where it installs skill symlinks |
| `hooks` | enum: `auto` \| `print` \| `off` | optional | `"auto"` | the adapter's hook-wiring step — `auto` merges and backs up, `print` only shows the snippet, `off` skips it |

Every key in this table is optional too — omitting `[install]` entirely just
means the adapter auto-detects everything.

## `[mining]`

Tuning knobs for the session-mining organ (`mindmeld mine`) — which sessions
are worth mining, how strict the specificity bar is, and which extractor
turns a session into candidate drafts.

| key | type | required | default | who reads it |
| --- | --- | --- | --- | --- |
| `min_turns` | int | optional | `12` | `mine run`/`status`, to skip sessions shorter than this |
| `min_idle` | duration string | optional | `"30m"` | `mine run`/`status`, how long a session's last message must have sat untouched before the session is eligible — parsed with `time.ParseDuration`, `"0"` disables the floor. Bypassed by `mine run --force` and by `mine run --session`, which is an explicit pin; `mine status` has no `--force` and always applies the floor, reporting each held-back session on its own line |
| `min_anchors` | int | optional | `4` | the gate, the specificity bar a draft must clear before it lands |
| `skip_projects` | array of strings | optional | `[]` | `mine run`/`status`, project basenames never mined — an empty list mines everything |
| `extractor` | enum: `auto` \| `local` \| `agent` | optional | `"auto"` | `mine run`, which extractor turns a bundle into candidate drafts, unless `--extractor` overrides it for one call |
| `local_model` | string | optional | `""` | the local extractor, e.g. `"gemma3:4b"` — unset is the switch, not a placeholder: it means the local extractor is never used and the binary makes no outbound HTTP call |
| `local_endpoint` | string | optional | `"http://localhost:11434"` | the local extractor, the Ollama-compatible endpoint it calls when `local_model` is set |
| `local_num_ctx` | int | optional | `32768` | the local extractor, the context window (tokens) declared to Ollama as `options.num_ctx`; `0` means "server decides" and skips both the declaration and the pre-flight size check |
| `archive_dir` | path | optional | `${XDG_DATA_HOME:-~/.local/share}/mindmeld/archive` | the archiver, where swept sessions are spooled before mining and reclamation |
| `archive_subagents` | bool | optional | `true` | the archiver, whether sub-agent transcripts are captured alongside their parent session — and, because a session is mined as parent **plus** sub-agents, whether they are mined at all. Turning it off means mining less, not merely storing less, and degrades extraction quality |
| `archive_keep_mined` | bool | optional | `false` | the pruner, `true` disables reclamation entirely and the spool becomes a permanent vault |
| `recurrence.enabled` | bool | optional | `true` | `mine run`'s recurrence lane switch — `false` disables the qmd subprocess and hands the candidates-tree duplicate-title check back to the gate |
| `recurrence.threshold` | float | optional | `0.70` | the qmd similarity adapter, the score (0..1) a match must clear to count as the same finding |
| `recurrence.collection` | string | optional | `""` | the qmd similarity adapter, the qmd collection to search for candidates/ sightings — `""` resolves to `{kb-basename}-candidates`. `init` registers whichever name resolves here, so an override is registered too |
| `recurrence.patterns_collection` | string | optional | `""` | the qmd similarity adapter, the qmd collection to search for sightings of an already-PROMOTED pattern — `""` resolves to `{kb-basename}-patterns`. Without this second collection a promoted pattern is searchable but never searched: its recurrence count would restart at 1 the moment it left `candidates/`. `init` registers it alongside the candidates one, honoring an override the same way |
| `recurrence.refresh` | bool | optional | `true` | the qmd similarity adapter, whether to reindex once per invocation before that invocation's first search (`mine run`, `mine land`, and `sweep land` alike) — note `qmd update` is global, so this touches every registered collection, not only the candidates one |
| `recurrence.timeout` | duration string | optional | `"60s"` | the qmd similarity adapter, the ceiling for one `qmd query` — the wait for the shared lock included, capped at a quarter of the budget so a contended wait still leaves time to run the query, parsed with `time.ParseDuration` |
| `recurrence.reindex_timeout` | duration string | optional | `"10m"` | the qmd similarity adapter, the ceiling for the whole reindex (`qmd update` plus one `qmd embed` per collection), exclusive-lock wait included on the same quarter-budget rule. Separate from `timeout` because an embed runs a local model over every new document — minutes on a first pass — where a query is seconds; one number for both meant a reindex could be killed by a ceiling chosen for a query |

`min_idle` exists because a session store has no "session closed" record. A
session's `ended` is only the timestamp of its last message at read time, so
an idle session and a finished one are the same bytes — mine one mid-flight
and the verdict retires every turn it writes afterward. The floor is a churn
control, not a guarantee: it stops the pipeline chasing a session that is
plainly still running, and it cannot tell a long pause from an ending.

What makes a wrong guess recoverable is that a verdict settles only the
material it was rendered on. Every terminal ledger row records the session's
extent at capture time (`captured`), and selection re-opens a session whose
source has since grown past it. Reclamation refuses material newer than its
own authorizing verdict for the same reason, though it measures a different
mark — `mine prune` compares spooled file mtimes against when the verdict was
written, not against the extent it read. A row written before this record
existed carries no extent; absence reads as no evidence, so those sessions
stay settled and `mine run --force` is how you re-open one by hand.

Re-opening re-mines the **whole** session, not just the tail, so the extractor
re-produces findings that already landed. Recurrence is what absorbs that: a
repeat finding is recorded as another sighting rather than a second article,
and a re-mine that turns up nothing new closes the session out with a
`reconfirmed` ledger row carrying the new extent. Two gaps are worth knowing
about — a re-extraction phrased differently enough to fall under
`recurrence.threshold`, and a prior candidate promoted somewhere neither
`recurrence.collection` nor `recurrence.patterns_collection` covers — either
of which lands a near-duplicate under a fresh slug for the review queue to
catch.

`extractor = "auto"` probes `local_endpoint` only when `local_model` is set —
an unconfigured install never dials out. With nothing configured, or the
local endpoint unreachable, `auto` (and an explicit `local`) fall back to the
agent extractor: sessions still get bundled, and the review ritual finishes
extraction out of process.

Ollama applies its own default context length regardless of what the model
itself reports it can handle — a server can load `gemma3:4b` at 32768 despite
the model's own `gemma3.context_length` reporting 131072 — and it truncates
an over-long prompt to fit that window silently: no error, no signal
anywhere in the response. That is why `local_num_ctx` is declared here rather
than inherited from the server, and why a session the local extractor
estimates above it is deferred to the agent extractor instead of being mined
against a fraction of itself. Raising this key costs memory on the serving
machine, so it is a per-machine value, not one to copy blindly between
machines with different specs.

`archive_dir` should resolve to a path under `$HOME`. The mining ledger at
`state/mining.jsonl` is committed and synced across machines, and it stores
every session and archive path `~`-relative so a row written on one machine
still means something on another; a path outside `$HOME` can't be expressed
that way, so `FileLedger.Append` refuses it. A spool configured outside
`$HOME` therefore breaks two things at once: every archive/reclaim row for
it is silently refused, and `mine prune` refuses to reclaim anything from it
at all.

That is enforced at the two verbs that write to the spool, not at config
load. `mine archive` fails loudly before it sweeps, naming the key, the
value, and why — a value like `/var/spool/mindmeld` is legal-looking but not
legal — and `mine prune` reports the same condition as a check line and
reclaims nothing. Everything else keeps working: `status`, `review`,
`ledger`, `promote`, `reject`, and `land` never touch the spool, and
`doctor`'s job is to *report* a broken config rather than die on it. The
default is derived from `XDG_DATA_HOME`, which an adopter may have pointed
outside `$HOME` for reasons that have nothing to do with mining, so a
refusal at resolution time would brick the whole organ over a value nobody
set.
A second sighting of the same finding is recorded on the already-landed
candidate instead of being refused — `mine review` sorts the queue by
recurrence count, strongest corroboration first. `recurrence.enabled =
false` restores pre-recurrence behavior exactly: no qmd subprocess runs, and
the gate takes the candidates-tree duplicate-title check back over from the
miner. The semantic tier degrades to a no-op when `qmd` isn't on `PATH` or
the candidates collection isn't registered — a run still lands candidates,
it just stops noticing duplicates, never fails one. `recurrence.threshold`
is a starting point, not a tuned constant: every `recurred` ledger row
carries the observed similarity score, so tuning it is a query over the
ledger rather than a guess.

`recurrence.refresh` exists because nothing else reindexes a landed
candidate — `init` embeds once and never again, so without it the search
cannot see anything mined since installation. The cost is that `qmd update`
has no per-collection scope: it re-indexes every collection registered on
the machine. Turn it off if something else already keeps the index fresh on
a schedule; recurrence then still catches same-day duplicates through the
slug path, which needs no index at all.

Leaving it on is safe under parallel landings, and that took work: qmd's
index is one sqlite file per machine, and *every* qmd invocation opens it as
a writer — `query` included, because qmd's store initializer runs DDL before
it reads a row. Two concurrent `qmd update` processes therefore kill each
other on a primary-key conflict, and a query that starts while one holds the
write lock dies on `SQLITE_BUSY`. Since the mine-review ritual mandates one
sub-agent per bundle in parallel, each running its own `mine land`, that was
the documented path — and the damage was invisible, because a failed
similarity check is non-fatal by design: candidates still landed, just
without recurrence weighting or duplicate detection.

mindmeld serializes it with an advisory lock at
`${XDG_CACHE_HOME:-~/.cache}/mindmeld/qmd.lock` — beside qmd's own index,
because the index is machine-global and a lock narrower than the thing it
protects is not a lock. Exclusive while reindexing, shared while querying,
so landings still query concurrently and only a reindex excludes everyone.
A reindex that cannot take the lock, or that fails once it has, is skipped
rather than forced, and reports a `[mine]` warn line instead of degrading
silently.

The claim is scoped to **mindmeld-issued** qmd invocations, and that scope
is worth stating because mindmeld ships others that fall outside it. The
session-start pulse hook (`hooks/kb-pulse.sh`) reindexes after a merge; the
landing pass in `mine-review`, `wrap-session`, `voice-distill`, and
`kb-ticket` tells the agent to run `qmd update` from its own shell; `init`
shells `qmd embed`. None of those go through the lock, so a session opening
in the middle of a mining fan-out can still collide. Closing that gap means
routing every reindex through the binary, which is a larger change than
this seam — until then, a `SQLITE_BUSY` during a fan-out is not evidence
the lock is broken.

## `[sync]`

Config for `mindmeld sync` (`internal/sync`) — the pull → merge →
regenerate → commit → push organ that replaces four copies of the same git
sequence in prose across spawn-session, wrap-session, voice-distill, and
mine-review.

| key | type | required | default | who reads it |
| --- | --- | --- | --- | --- |
| `enabled` | bool | optional | `true` | `mindmeld sync`, whether the organ runs at all — `false` is a preflight-level refusal, no git command runs |
| `remote` | string | optional | `"origin"` | `mindmeld sync`, the remote every pull/push invocation targets |
| `branch` | string | optional | `"main"` | `mindmeld sync`, the branch HEAD must already be on — a mismatch refuses rather than switching branches for you |
| `timeout` | string (duration) | optional | `"15s"` | `mindmeld sync`, the whole-sequence deadline every `git` call runs under — an empty or unparseable value falls back to the default rather than refusing to sync |

## `[machine]`

Per-machine identity — deliberately outside the KB, per the Config vs KB
delineation above: a machine's own identity is not true of the person on
their other machine.

| key | type | required | default | who reads it |
| --- | --- | --- | --- | --- |
| `id` | string | optional | the slugified hostname | `Config.HostID()` — durable, user-controlled, and survives a hostname rename; when unset, `HostID()` falls back to a slugified `os.Hostname()`, then to `"unknown"` if that fails |

## `[sweep]`

Tuning for `mindmeld sweep` — the diff filter it hands to the pattern-sweep
agent, and the two-tier threshold that governs auto-promotion.

| key | type | required | default | who reads it |
| --- | --- | --- | --- | --- |
| `max_diff_bytes` | int | optional | `262144` | `sweep bundle`, the context-budget cap on the (post-filter) diff text — 256 KB is roughly 65k tokens, past which a sweep agent skims a diff rather than reading it |
| `ignore` | array of strings | optional | `[]` | `sweep bundle`, extra glob patterns matched against changed file paths and EXTENDING — never replacing — the built-in ignore list below |
| `promotion.enabled` | bool | optional | `true` | auto-promotion, `false` disables it entirely — the review queue stays human-only, nothing is ever promoted unattended |
| `promotion.review_min` | int | optional | `3` | `mine review`, the recurrence count a swept (`type: pattern`) candidate needs before it's surfaced by default — `mine review --all` shows everything regardless |
| `promotion.auto_min` | int | optional | `5` | auto-promotion, the recurrence count that promotes a swept pattern unattended — must be `>= promotion.review_min`, and config load refuses the inversion |

The built-in ignore list — lockfiles (churn, never a pattern), generated
code (the generator's pattern, not the author's), vendored code (someone
else's), build output, and test fixtures/goldens:

```
**/go.sum **/package-lock.json **/pnpm-lock.yaml **/yarn.lock **/Cargo.lock **/poetry.lock
**/*.pb.go **/*_generated.go **/*.gen.ts **/generated/** **/__generated__/**
**/vendor/** **/node_modules/**
**/dist/** **/build/** **/*.min.js **/*.map
**/__snapshots__/** **/*.golden
```

`**/testdata/**` is deliberately NOT in that list. In *this* repo
`tests/integration/testdata/*.txtar` holds the behavioral specs and is among
the most pattern-dense material in the tree — filtering it would blind the
sweep to exactly what the project cares about. A repo where testdata really
is inert fixtures adds `"**/testdata/**"` to `ignore` locally; that's exactly
what makes it a config key rather than a constant baked into the binary.

`ignore` is additive, not a replacement, on purpose: a config that could
silently drop the built-in lockfile/vendor/generated-code protections would
be a footgun every adopter re-discovers the hard way. There is no key that
replaces the built-in list outright — extend it, or ignore nothing beyond
it.

`promotion.review_min` and `promotion.auto_min` encode a volume argument:
under agentic coding a sweep can run every session, so the
candidate population is larger than a bar tuned for a handful of sessions a
week. `review_min` gates *surfacing*, never *landing* — a pattern below it
still lands in `candidates/` with full provenance and still accumulates
recurrence, it's simply left out of `mine review`'s default listing (and
`mine status` reports the held-back count, so "invisible" never becomes
"lost"). The inversion `review_min > auto_min` is refused at config
resolution: a machine promoting something a human was never offered for
review is the one ordering this feature must never produce.

## `[mindmeld]`

mindmeld's own identity, distinct from the KB it manages — today this table
holds exactly one key.

| key | type | required | default | who reads it |
| --- | --- | --- | --- | --- |
| `checkout` | path | optional | none — unset means "not configured" | `assets.Resolve`, as a DECLARED candidate for the content-ring root (`skills/`, `templates/`, `bases/`, `kb-scaffold/`, `mindmeld.toml.example`) |

A Homebrew install never sets this key: the formula does `bin.install` and
`libexec.install` and writes no config at all, so a brew install finds its
ring through the probed `libexec` candidate, never through `checkout`. This
key exists for two real cases instead — an owner whose checkout lives
somewhere the executable-relative probe won't find (running a built binary
from outside the checkout entirely, say), and an explicit override for when
the probed chain would otherwise guess wrong.

Being a declared candidate rather than a probed one, a value here that fails
the marker test is a loud, run-global error naming the key — never a silent
fall-through to guessing.

## The KB instance

`mindmeld init` stamps a minimal viable KB at `{kb.root}` — the directory
`[kb].root` points at. This is the spec every KB-reading organ (skills, the
pulse hook, qmd, Bases) can assume without checking:

```
{kb.root}/
  CLAUDE.md            # from kb-scaffold/CLAUDE.md, with the owner-context slot filled
  .gitignore           # from kb-scaffold/gitignore (output/, conflict artifacts)
  raw/  wiki/  projects/  research/  solutions/  tools/  decisions/
  patterns/  ideas/  people/{owner}/  sessions/  tickets/  output/
  candidates/          # the review queue — empty until mining lands a draft,
                       # scaffolded anyway because init registers it as a qmd collection
  wiki/_hot.md         # derived-local: gitignored, regenerated, never committed
  templates/           # copied from the engine's templates/ — user-editable from then on
    ticket.md  pattern.md  decision.md
    dossier/{MANIFEST,plan,adr,contract,chunk-brief,chunk-report,spec-brief,wrap}.md
  skills/              # the instance ring — see below
    README.md          # from kb-scaffold/skills-README.md, copy-if-absent
    <skill-name>/overlays/*.md    # owner-authored, init never touches these
  *.base               # the six faces, copied from the engine's bases/
```

### The instance ring — `{kb.root}/skills/`

The sanctioned home for the things a shipped skill can't hold — an overlay
that names a specific employer or repo is the proving case, and per the
delineation above it's KB-shaped (true of the person, not the machine), so it
lives here rather than in the checkout.

Every skill that resolves an overridable asset checks two places, in order:

1. `{kb}/skills/<skill-name>/<asset>` — the instance ring. Owner-owned, never
   clobbered by `init` or an engine update.
2. `<shipped-skill-dir>/<asset>` — the engine's own copy.

Both sets load; the instance ring wins on conflict. A miss at step 1 is not
an error — an empty or absent instance ring is the adopter's normal state,
not a gap to fix. `init` scaffolds `{kb}/skills/` and stamps a `README.md`
into it, copy-if-absent, the same posture as `templates/`; it never creates
per-skill subdirectories — those appear only when the owner (or a synced KB)
adds one. `doctor` reports the ring's presence and an override count as an
informational check, never a failure (see "What init touches" below).

### The pulse cache (`wiki/_hot.md`)

`mindmeld hot` regenerates this file — open work and recent activity, rendered as a
compact block. The SessionStart hook (`hooks/kb-pulse.sh`) reads it verbatim into every
new session and then triggers a background refresh, so the file a session sees trails
reality by one session at most. `init` offers to seed it right after scaffolding the KB, so
a fresh install has a pulse before the first session rather than after it; declining the
offer just means the first session's hook run generates it instead. Being derived-local,
it's absent on a fresh clone of an existing KB until something regenerates it — that
absence is expected, not an error.

After the files land, `init` runs `git init` plus an initial commit, then
`qmd collection add` and `qmd embed` — but only when `qmd` is present on the
machine; its absence degrades to "note printed, everything else lands."

A few things hold regardless of instance:

- **`kb-scaffold/CLAUDE.md` carries the full frontmatter schema unchanged** —
  the seven entity types, their required fields, and ticket type-specifics
  are the paradigm contract every KB shares. Only the Owner Context section
  is a per-instance slot. Status enums (`backlog | active | in-review | done
  | dropped`, etc.) never vary per instance either.
- **Bases are copied as-is.** They filter on schema fields only, never on any
  particular owner's values, so they work identically across instances.
- **Templates ride the content ring after init.** Once `{kb}/templates/` is
  stamped, engine updates never overwrite it — drift from the shipped
  defaults is the owner's right.
- **Scaffolding is additive-idempotent.** Existing directories and files are
  left untouched; only what's missing gets filled in. Re-running `init`
  against an already-scaffolded KB is a no-op walk.

## What init touches (claude-code adapter)

This is the complete set of host paths `mindmeld init` may write under the
`claude-code` adapter — nothing outside this list, ever:

```
~/.config/ai/mindmeld.toml            # stamped; confirms before overwriting an existing file
~/.claude/skills/{spawn-session,wrap-session,kb-ticket,voice-distill,pr-review,mine-review}
                                       # symlinks → the repo (falls back to --copy if needed)
~/.claude/hooks/kb-pulse.sh            # symlink → the repo
~/.claude/settings.json                # SessionStart hook entry, merged in
~/.claude/mindmeld-backups/<surface>/  # anything init displaced lands here — see below
{kb.root}/**                           # per "The KB instance" above
```

The `settings.json` merge is a small, specific operation:

1. Back up first: `settings.json` → `~/.claude/mindmeld-backups/settings/settings.json.pre-mindmeld-{YYYYMMDD-HHMMSS}`.
2. Append `{type: "command", command: "~/.claude/hooks/kb-pulse.sh"}` to
   `hooks.SessionStart[0].hooks`, creating that chain if it doesn't exist.
3. Skip the write entirely (idempotent) when any existing `SessionStart`
   command already ends in `/kb-pulse.sh`.
4. With `--no-hook`, print the JSON snippet instead of writing it.

### Where backups go

A collision — something already sitting at a path `init` needs — is never
overwritten in place. It's moved to
`~/.claude/mindmeld-backups/<surface>/<name>.pre-mindmeld-<YYYYMMDD-HHMMSS>`,
`<surface>` one of `skills`, `hooks`, `settings`, and *that* root is never a
sibling of the thing it displaced.

The reason is `~/.claude/skills/` specifically: it's a discovery root — the
harness treats anything sitting in it as an installed skill. An in-place
backup (the old behavior) becomes a stale, discovered twin of the skill it
was supposed to replace, with a near-identical description competing for
routing against the real one. Ejecting backups to a dedicated root outside
every discovery surface — not just skills, so there's one answer to "where
did my old copy go" rather than a per-surface rule — closes that off
entirely.

A machine that already ran an older `init` and picked up in-place backups
isn't stuck: the next `init` sweeps any `*.pre-mindmeld-*` entry it finds
inside a managed surface into the new root before it links anything, and
reports each one it moved. When something is actually displaced — a fresh
collision or a swept stray — `init`'s closing block names it and where it
went; a clean install stays quiet.

Nothing under `~/.claude/mindmeld-backups/` is ever deleted or pruned
automatically. That's the user's call, same posture as the dossier
`_archive/` — an install tool that deletes data on a schedule is a
different and worse tool.

Invariants that hold across the whole surface:

- **Additive only.** `init` never removes or rewrites an existing settings
  key, skill, or hook — collisions get backed up to
  `~/.claude/mindmeld-backups/<surface>/`, never deleted.
- Every write is preceded by an existence check, so re-running `init` is a
  no-op walk when nothing's missing.
- No `sudo`, and no writes outside the five host paths above plus
  `{kb.root}`.
- **`doctor` is read-only against this same surface.** It reports on drift or
  missing pieces; it never repairs anything itself — repair means re-running
  `init`, or `mindmeld update` (below).

## `doctor`: ownership, not mere existence

`doctor` classifies each installed skill rather than just testing that
something is there. Per skill, it reports one of four states:

- **linked to checkout** — a symlink resolving to `<repo>/skills/<name>`. The
  healthy state.
- **linked elsewhere** — a symlink, but to a different target (another sync
  system got there first). Warn — run `mindmeld init`.
- **installed as a real path** — a real file or directory, not a symlink.
  This is `--copy`'s normal shape (a supported install posture), so it's a
  warn, not a failure — but it's also what a foreign writer clobbering the
  link looks like, so the fix is the same either way: run `mindmeld init`.
- **missing or dangling** — nothing there, or a symlink whose target is gone.
  The one state that's an actual error.

`[kb] owner` gets the same treatment. `doctor` doesn't just stat
`people/{owner}/` and stop — it separately checks whether that directory is
the KB's own identity home, and warns when the KB carries more than one
identity home, an ambiguity it won't guess through. "The configured owner's
home exists" and "the configured owner matches the KB's identity home" are
different questions; only the second one catches a machine that quietly
scaffolded a sibling identity instead of adopting the one already there.

`doctor` also reports, informationally: whether `{kb}/skills/` (the instance
ring) is present and how many skill overrides it holds, and how many commits
the checkout is behind its upstream — read from refs already on disk, never
a `git fetch`. A doctor that touches the network is a doctor that hangs on a
plane.

## `mindmeld update`

`mindmeld update [--dry-run] [--copy]` brings the mind current: fast-forward
the checkout (`git pull --ff-only`, skipped with a warning if there's no
upstream or the tree has local changes — it never stashes, forces, or
rebases over a stranded edit), then re-run the same adapter install `init`
uses, which repairs any skill that drifted back to a real path or a foreign
symlink. If the checkout was originally installed with `init --copy`, pass
`--copy` to `update` too — otherwise it re-links a copy install into a
symlink one, which isn't drift, it's a different posture than the one you
chose.

`update` is deliberately scoped to what mindmeld owns — the checkout and the
organs it installs. It does not wrap or invoke a dotfile manager: the
machine's own config is a separate system with no opinion about mindmeld's
organs post-install, and the closing line says so explicitly rather than
pretending otherwise.
