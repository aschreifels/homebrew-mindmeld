# mindmeld host

Some state is true of a machine, not of you — `[machine].id` is that identity, and
`host` is how a script captures it. It exists mainly to be captured in a shell
substitution (`wrap-session` uses it this way), so its output is exactly one thing.

## Usage

```bash
mindmeld host
```

## What it does

Resolves `[machine].id` — the configured value, or a slugified hostname when unset, or
`"unknown"` if even that fails — and prints it to stdout with a trailing newline. No step
tag, no color, no decoration: any extra output would break the one caller this command
exists for.

## Output

One line: the resolved host id.

## Config it reads

`[machine].id` — see [config.md#machine](../config.md#machine).

## Related
- [mindmeld sync](sync.md) — the other per-machine-identity-aware command
