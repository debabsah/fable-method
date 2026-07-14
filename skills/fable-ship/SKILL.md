---
name: fable-ship
description: Use when finishing a task — writing the final report or status, shipping a change, or handing off — to produce a calibrated done-claim and the docs that make the work reproducible by someone else.
---

# fable-ship

The report is part of the work, not an afterthought. Ship a **calibrated** claim and the docs that let a stranger redo it.

## The report

- **Answer first**, then the support. Lead with the verdict (done / not done / exact / blocked) in the first line; put evidence underneath, never above.
- **Scale the report to the tier.** T1 = the verdict, its `Verified:` line(s), and the tier line — a few lines, not a document. The full shape here is for T2+.
- **Separate verified from assumed, out loud — as the method's ledger** (canonical shapes: the method skill's ledger section; same tokens every report, and the Stop-hook gate greps for them). Never let an `Assumed:` line read like a `Verified:` one.
- **Cite specifics:** paths, counts, `file:line`, the command you ran, the number you saw, before→after deltas.
- **Report what you observed, not what you intended.** If a step was skipped or a test failed, say so with the output.
- **Calibrate "done" with a use-boundary.** Stamp unproven results **PROVISIONAL** ("do not quote these yet") and lift it explicitly only when the check passed. Scope the claim to exactly what you measured; put the rest in a visible residual list.
- **State the tier and its gates.** One line: `Tier: Tn — gates run: <verify / review lenses / human gate>`. A skipped gate that leaves no trace is invisible exactly when it matters.
- **Never soften a real problem — including your own.** Flag anything the human must decide (⚠️), state it plainly with the evidence, and repeat the flag into every downstream artifact (PR body, log, memory), not just the chat.
- **End with what the reader still owns.** Even a perfect report leaves a short list: every `Assumed:` line, plus any T3 (outward/production) action gated to the human. Say it explicitly — worry-less means a short, honest residual list, not an empty one.

## Docs-as-done

A change isn't done until **someone else could redo it from the record it leaves**. In the same change that ships the work, update the record it affects — runbook, config/topology doc, implementation log. **Scope it to impact:** when a change is fully self-evident in code + tests + commit message, that *is* the record — never write prose that restates a diff (point-don't-copy applies to your own work too). Convert relative references to absolute (dates, versions). Keep one canonical source for a fact; have other docs point to it rather than restating.

## Curate the project overlay

If `.fable/project.md` exists, **fold in what this task confirmed** — durable facts and **gotchas** (`Gotcha: <trap> → Cause → Rule`) — and announce what changed. Log gotchas liberally — over-capture beats missing one. **Compact on trigger, not ritual:** when the overlay is pushing past ~a page or entries are visibly stale, dedup, retire the obsolete, promote the recurring; skip the pass when it isn't needed. Check `.fable/gate-log` too: each line is a turn the calibration gate had to bounce; a recurring bounce is a gotcha about working habits — log it like any other trap.

**Retire finished task files** (`.fable/tasks/<slug>.md`): promote surviving decisions and durable facts into the overlay or the project's own docs, then delete the file — an in-flight pointer that outlives the work is a lie the next session inherits.

**Keep the calibration record.** Append every `Verified:` line from the final report to `.fable/claims-log` (`date · claim · command`) — this is what `fable-debug` falsifies against when a vouched-for behavior later breaks. Route undischarged `Assumed:`/`PROVISIONAL` lines to `.fable/residuals.md` (the SessionStart hook surfaces the open count until they're discharged). Trim gate-log, claims-log, and residuals when they pass ~200 lines.

## Before you call it shipped

Run **fable-verify** on the central claim. Don't state as fact anything you haven't verified this session.
