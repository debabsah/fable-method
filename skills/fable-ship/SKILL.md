---
name: fable-ship
description: Use when finishing a task — writing the final report or status, shipping a change, or handing off — to produce a calibrated done-claim and the docs that make the work reproducible by someone else.
---

# fable-ship

The report is part of the work, not an afterthought. Ship a **calibrated** claim and the docs that let a stranger redo it.

## The report

- **Answer first**, then the support. Lead with the verdict (done / not done / exact / blocked) in the first line; put evidence underneath, never above.
- **Separate verified from assumed, out loud — as the ledger.** `Verified: <claim> — ran <command> -> saw <result>` vs `Assumed: <thing> — why — how to check it`. Same tokens every report (the Stop-hook gate greps for them); never let a line from the second bucket read like the first.
- **Cite specifics:** paths, counts, `file:line`, the command you ran, the number you saw, before→after deltas.
- **Report what you observed, not what you intended.** If a step was skipped or a test failed, say so with the output.
- **Calibrate "done" with a use-boundary.** Stamp unproven results **PROVISIONAL** ("do not quote these yet") and lift it explicitly only when the check passed. Scope the claim to exactly what you measured; put the rest in a visible residual list.
- **Never soften a real problem — including your own.** Flag anything the human must decide (⚠️), state it plainly with the evidence, and repeat the flag into every downstream artifact (PR body, log, memory), not just the chat.
- **End with what the reader still owns.** Even a perfect report leaves a short list: every `Assumed:` line, plus any T3 (outward/production) action gated to the human. Say it explicitly — worry-less means a short, honest residual list, not an empty one.

## Docs-as-done

A change isn't done until **someone else could redo it from the docs alone**. In the same change that ships the work, update the record it affects (implementation log / runbook / topology or config doc). Convert relative references to absolute (dates, versions). Keep one canonical source for a fact; have other docs point to it rather than restating.

## Curate the project overlay

If `.fable/project.md` exists, **compact it as part of shipping**: fold in the durable facts and **gotchas** you confirmed this task (`Gotcha: <trap> → Cause → Rule`), dedup, retire entries that went obsolete, promote recurring ones, keep it to ~a page, and announce what changed. Log gotchas liberally — over-capture beats missing one. Check `.fable/gate-log` too: each line is a turn the calibration gate had to bounce; a recurring bounce is a gotcha about working habits — log it like any other trap.

**Retire finished task files** (`.fable/tasks/<slug>.md`): promote surviving decisions and durable facts into the overlay or the project's own docs, then delete the file — an in-flight pointer that outlives the work is a lie the next session inherits.

## Before you call it shipped

Run **fable-verify** on the central claim. Don't state as fact anything you haven't verified this session.
