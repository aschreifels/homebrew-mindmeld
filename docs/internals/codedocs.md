# internal/codedocs

## What it is

`internal/codedocs` is the engine behind `mindmeld codedocs check` — the drift
gate that keeps a repo's `docs/internals/` explanation honest against the code
it describes — and the small, pure policy seam two other organs read to know
how a repo wants its source documented: `internal/hot` renders the resolved
policy into the session-start pulse, and a resource server will eventually
expose it too. The package name deliberately isn't `docs`: that slot belongs
to the adopter-guide organ (catalog, install, status) shipped in
`internal/docs`. `codedocs` names the narrower subject — source
documentation, not the guide adopters read. `internal/hot` holds the pointer
back — its `Doc.Policy` field is a `*Policy` from this package, threaded
through to `Doc.Render` so the directive rides the pulse without either
package importing the other's gate machinery.

## Design

### Two halves, one import edge

The package splits along the line its two files draw. `policy.go` is pure — a
KB root and a resolution `Scope` in, a resolved `Policy` out, no subprocess,
no clock, no other organ imported — which is what keeps `internal/hot`'s
render byte-assertable. `codedocs.go` is the gate half: the `CheckID`,
`Finding`, and `Report` vocabulary, and `Run`, which `cmd/mindmeld/codedocs.go`
drives. The import edge runs one way only — `codedocs` must never import
`hot`, `initrun`, or `mcp` — so this module stays a leaf the higher organs
depend on, never the reverse.

### Two closed vocabularies, independent of each other

`Placement` (`inline` | `repo-docs` | `split`) answers where reasoning goes.
`Verbosity` (`terse` | `regular` | `verbose`) answers how much gets written,
and derives the gate's comment-length ceiling: `terse` is 4 lines, `regular`
is 8, `verbose` is off — a long block is exactly what that setting is asking
for. A third axis, `Policy.DocsVerbosity`, governs prose written into `docs/` itself;
no check ever reads it, so it only ever reaches an agent through `Policy.Directive`.
A misspelled value on any of the three, or an `applies_when` override that is
empty or keyed outside `repo`/`file_exists`, is always a parse error — never a
silent fall-back to `Defaults`.

### Two policies, not one — and the gate reads its own

There are two different `placement` values in play, from two different
sources, and conflating them was a real defect caught before it shipped:
`Policy.Placement`, resolved from `{kbRoot}/policy/code-docs.md`, answers "how
should the agent write new code?" A repo's own `docs/internals/_index.md`
`placement:` key answers a different question — "what does this repo's gate
enforce?" `Run` reads the second, and only the second: it never calls
`ResolvePolicy`, so a contributor with no KB checked out still gets the gate
their maintainer configured in `_index.md`, rather than a silent `Defaults`
that would leave D5 on for the maintainer and off for everyone else.

### The default is opinionated, and the directive says so

`Defaults` returns `split` / `regular` / `regular` — not the harness's
native `inline` / `verbose` behavior. `Policy.Directive` renders every resolved
policy except the one combination that exactly matches harness-native
(`inline` placement, `verbose` symbol verbosity): the one state where telling
an agent about the policy would just be asking it to keep doing what it
already does. Every other combination renders, defaults included, which is
what lets an opinionated default actually reach the agent instead of hiding
behind an "unconfigured, say nothing" check.

## Invariants

- `Run` never calls `ResolvePolicy` and never reads a KB-sourced policy — D5's
  applicability is keyed off the repo's own `docs/internals/_index.md`
  `placement`/`verbosity`, never the maintainer's.
- `policy.go` imports nothing from `hot`, `initrun`, or `mcp` — the edge runs
  one direction, into `codedocs`, never out.
- A misspelled `placement`/`verbosity`/`docs_verbosity` value, or an
  `applies_when` that is empty or carries an unknown key, is a parse error
  returned to the caller — never a silent `Defaults` substitution.
- `Policy.Directive` is a pure function of `Policy`: no filesystem read, no clock —
  the property `internal/hot`'s byte-assertable render depends on.
- `Run` is read-only this session. `Opts.Fix` is declared but returns
  "not implemented."
