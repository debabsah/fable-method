# Project overlay template — `.fable/project.md`

Copy this shape into `<workspace>/.fable/project.md` (git-ignored). It is the method's durable memory *for one project*: keep it **thin and pointer-first** (point to the project's own canonical docs for facts they own; never snapshot volatile values), and let it **evolve** — auto-add confirmed durable facts and gotchas, announce changes, and compact at `fable-ship`.

**The first line MUST be a one-line HTML-comment pointer** (the SessionStart hook injects it as ambient context):

```
<!-- pointer: <project> — oracle: <how "correct" is checked here>. Canonical docs: <where truth lives>. Full profile: .fable/project.md -->
```

Then only the sections you actually have (drop the rest):

```
# <Project> — fable-method project overlay
> ⚠️ Snapshot of an evolving project; the docs pointed to here are canonical — verify against them. Git-ignored, per-machine, auto-curated.

## Canonical docs (point, don't copy)   — where the real truth lives (CLAUDE.md, etc.)
## Acceptance oracle(s)                  — how "correct" is checked here (the single highest-value fact)
## Conventions & guardrails              — project-specific method notes (point to CLAUDE.md for what it owns)
## Gotchas (open — log every trap)       — `<trap> → Cause → Rule` (+ optional date); free-form types; log liberally
## Record shapes                         — how this project logs decisions / incidents
## Working assumptions (unverified)       — inferred-but-unchecked; promote up when confirmed
```

Rules of thumb:
- If a fact is already in the project's `CLAUDE.md` or another canonical doc, **point to it — don't copy it.**
- A **gotcha** = a surprise/trap you hit and diagnosed that has a learnable rule. Log it the moment you confirm it; don't wait to see whether it recurs, and if one fits no category you've seen, log it anyway.
- Keep it to roughly a page. When it sprawls, that's the signal to compact (dedup, retire stale, point instead of inline).
