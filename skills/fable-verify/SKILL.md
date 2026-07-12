---
name: fable-verify
description: Use when about to claim work is complete, fixed, passing, correct, or done — before committing, opening a PR, or moving to the next task. Also when a result looks good and you're tempted to move on, or a green signal came back suspiciously clean.
---

# fable-verify

"It ran" is not verification. **Evidence before claims, always.** Verify at the layer of the *claim*, not the layer below it.

## The gate

Before any success/completion claim or expression of satisfaction:

1. **Identify** the command or observation that would *prove* this specific claim.
2. **Run it fresh, in full** (not a remembered earlier run; not a partial check).
3. **Read** the whole output — exit code, counts, the actual values.
4. **Verify at the layer of the claim.** Exit 0 / "deploy healthy" / "containers up" only proves the layer *below* the claim. If the claim is "the output is correct," look at the output. If it's "the page renders," look at the page. If it's "the definitions load," import them in the built artifact and count them.
5. **Only then** state the claim — as ledger lines: `Verified: <claim> — ran <command> -> saw <result>`, with anything unchecked under `Assumed:` or `PROVISIONAL`. If it fails, state the actual status with the output.

## Sharpen it

- **Know what pass looks like before you run it:** pull the oracle from `.fable/project.md` — the command *and* what green literally prints. Exit 0 with `3 skipped` is not the pass you meant.
- **Categorical over enumerated:** assert a property over *all* items of a class, so the check inspects cases you didn't think to list. When it over-fires, diagnose *scope vs. substance* before loosening it.
- **Oracle over the whole population:** when reconstructing hidden logic, diff your candidate against a readable known-good output over *every* row, not a sample; state plainly which parts are transcribed vs. inferred.
- **Sample the tails:** first item, last item, weirdest item — not just the middle.
- **Use evidence you didn't generate:** re-open the file you wrote, re-run, screenshot and read it, diff before/after, count what you claimed to count.
- **Treat good news as suspect:** a pass that came too easily is unverified until you can say *why* it's real. Distinguish "the build succeeded" (rehearsal) from "the thing loaded and ran" (reality).
- **Re-check against the original request** and any standing rules from scoping.

## Red flags — you have NOT verified

"should", "probably", "seems to", "Great/Perfect/Done!" before running anything, trusting a subagent's "success" without checking its diff, relying on a partial check, "just this once." Any of these → run the command, read the output, *then* claim.

The plugin's Stop-hook gate bounces done-claims that carry no ledger marker — it checks the format; the truth is this skill's job.
