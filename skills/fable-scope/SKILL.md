---
name: fable-scope
description: Use at the start of a non-trivial task, or when the goal is fuzzy, the request is solution-shaped, or you cannot yet state in one sentence what "correct" will be checked against. Skip for trivial edits.
---

# fable-scope

Bound the task before building. Produce a short **scope block** and stop for the human only if a fork genuinely changes what you'd build.

**First, read `.fable/project.md` if it exists** — it holds this project's acceptance oracle, conventions, and known **gotchas**; scope on top of it (don't re-derive what's there, and don't re-step on a logged landmine). If it's missing, offer to create it (see the method skill's overlay protocol). Then:

1. **Define done as a named external CHECK.** In one sentence: what artifact exists at the end, and *what will "correct" be compared against*? Prefer a concrete oracle (a known-good output, a reference system, a test, a count). If no oracle can exist, name the weakest acceptable substitute (a specific human's sign-off) — and say so. **If you can't write the check, you don't understand the task yet.**
2. **Split known from assumed.** Two short columns: *Known (evidence)* vs *Assumed (inference)*. Anything in the second column that would change the solution if wrong is a candidate unknown.
3. **Name the 1–3 load-bearing unknowns** — the facts that, if wrong, change the whole shape — and the *cheapest probe* to retire each. Gate on them: don't build past an unretired load-bearing unknown.
4. **Fence it.** A short explicit "out of scope (recorded so nobody wonders)" list.
5. **Right-size.** Note which decisions are cheap to reverse (defer them) vs the one or two that are expensive/unpatchable (spend the thinking there).
6. **Ask only outcome-changing questions.** If a fork changes what you'd build, ask **one** question, with a recommendation and the rejected cost. Otherwise pick the sensible default, state it in one line, and proceed. Ask to change outcomes, not to feel safe.

Output the scope block, then continue. Re-open it if a later result invalidates an assumption.
