---
name: fable-method
description: Use when a task carries real uncertainty — multi-step builds, debugging where the first theory may be wrong, research or analysis with claims to verify, anything touching data/APIs/files not yet opened, or work that will be handed off. Also when work keeps failing or stalling, before declaring anything done, or when the user says "think like Fable", "fable method", "work like Fable", "slow down and do this right", or "be rigorous". Skip for trivial one-line edits or simple lookups.
---

# The Fable Method

## Overview

A working discipline for tasks where the first idea might be wrong. It was distilled from a forensic study of the Fable model; it is **self-contained** (depends only on built-in tools — the Agent/Task tool, Bash, Read/Grep/Write — never on other plugins or skills).

**Core principle: nothing is true until an independent check you did not author says so.** Your training memory, your prior rulings, a green build, and your own summaries are all *hypotheses*. The method's whole job is to make you *do the effortful check* — spawn the adversary, diff against the oracle, verify at the claim — instead of skipping it under momentum.

For a one-line edit or a simple lookup, skip this and just do the work.

## The seven reflexes

**R1 — Nothing is true until an independent check says so.** Name what "correct" will be checked *against* before you build (→ **fable-scope**). Where the truth is hidden, build an **oracle** and diff your candidate over the *whole* population, not a sample. Verify at the layer of the *claim*, not the layer below it — "it ran / deploy healthy" only earns the next probe (→ **fable-verify**). Label numbers **PROVISIONAL** until proven; never let a provisional number leave as fact.

**R2 — Work the invariant, not the instance.** Fix the shared cause and grep every caller; patching only the site in front of you leaves the siblings broken ("fix-by-section": thorough against the checklist, thin against the file). Write checks *categorically* — a property over all cases, not the three you happened to think of.

**R3 — Externalize the adversary.** Don't self-vibe-check. **Spawn blind reviewers** — fresh context, none of your rationale — and have them attack the files, not your claims (→ **fable-review**). Turn the same blade on your own prior conclusions — downgrade a verdict out loud when the evidence contradicts it. Steelman the thing before attacking it; **finding nothing wrong is a legitimate result** — never manufacture a problem to look thorough. When critique lands on your work, fold it in and credit it; don't defend.

**R4 — Every decision is durable, revisable, and never silent.** Record each real decision with its rejected alternative and a revisit trigger; version the plan with stamped changes; put deferrals in explicit buckets/registers (even record the *absence* of a decision). This is what lets you re-decide cleanly after every result instead of riding momentum.

**R5 — The report is part of the work; calibrated honesty gates action.** Lead with the answer, then a support ledger that keeps **"verified by running X"** structurally apart from **"assuming Y, couldn't check."** Cite specifics (paths, counts, `file:line`, before→after deltas). Never soften a real problem — including your own. The certainty *level* controls what action is allowed (→ **fable-ship** for done/handoff).

**R6 — The human owns authority; you own labor.** Interview one decomposed question at a time, each with a recommendation and its rejected cost on the record. Gate the irreversible and the genuinely ambiguous to the human. Parse the instruction's shape: "you decide / proceed" ⇒ act now and record why; a named gate or a one-way door ⇒ stop and confirm. Once the human rules, record it as binding and don't relitigate.

**R7 — Match effort to reversibility; reproduce reality.** Spend where reversal is expensive (grain, schemas, one-way doors); defer the cheap-to-change with a written trigger ("you're arranging folders, not carving stone"). Prove one **thin end-to-end slice** before scaling. Iterate in a *faithful copy of the real environment*, not a simulation. Every incident mints a runnable rule — then arrange the next run to exercise it.

## The loop

`scope (R1,R6) → ground the unknowns cheapest-first (R1) → build one thin slice in the real env (R7) → verify at the claim (R1) → adversarial pass (R3) → re-decide on the result (R1,R4) → report calibrated (R5) → docs/handoff`. Reach for the runner at each effortful step; don't narrate it, run it. When a check comes back red or reality contradicts the plan — the dashed edges of the loop — go to **fable-debug** before re-building.

## The ledger — one shape for every claim

Every completion claim ships with a ledger the reader can scan in seconds — the same tokens every time (they are load-bearing: the plugin's Stop-hook gate greps for them and bounces a done-claim that has none):

```
Verified: <claim> — ran <command/observation> -> saw <result>
Assumed: <what you couldn't check> — why — how the user can check it
PROVISIONAL: <number/result not yet safe to quote>
```

Claim strength tracks evidence strength — never let an `Assumed:` line read like a `Verified:` one (R5). **Provenance rule:** a report from any agent — *including your own subagents* — is a claim, not evidence; observe it yourself (open the file, run the command) or ledger it as secondhand. Uniformity is the point: the reader learns one shape and reads it for years.

## Risk tiers — the minimum gate

| Tier | The change is… | Minimum gate before "done" |
|---|---|---|
| **T1** | reversible, local — code on a branch, a doc, a scratch analysis | fable-verify |
| **T2** | hard to reverse — schema/grain, deletions, wide refactors, published artifacts | fable-verify + one blind adversary (fable-review, one lens) |
| **T3** | outward or production — deploy, send, money, credentials, data-destructive | fable-verify + fable-review panel + an explicit human gate (R6) |

Unsure → tier up. Effort level never lowers a tier's minimum: a medium-effort session skips optional work, not gates.

## The plan shape

Scope produces the check; the plan gets you there. Its shape:

1. **Resolution decays with distance.** The next 1–2 steps are concrete — commands, files, expected output; everything past the next verification point stays a coarse bucket, refined only when the frontier reaches it. Detail written before evidence arrives is fiction that anchors you against re-deciding.
2. **Every step ends at a checkpoint, not an activity.** The boundary is an observable — "after this, `X` prints `Y`" — never "implement Z." A step without a check attached is a hope, not a step; execution moves from verified state to verified state.
3. **Sequence by information, not deliverable order.** Front-load the steps that retire load-bearing unknowns — cheapest-probe-first at plan level — and prove the thin slice before building breadth (R7).
4. **The plan is a versioned hypothesis, not a contract.** When evidence contradicts it, re-planning is the success path: stamp the revision, log the decision and its why in the task file (R4). Serving the document instead of the goal is momentum wearing a plan's clothes.
5. **Decompose to the tier, not to a template.** T1 needs a next-action line; T3 earns the full task file. Uniform ceremony on every task is where imposed planning pipelines rot.
6. **Anchors don't move with the route.** The acceptance oracle, the out-of-scope fence, explicit human rulings, and tier minimums are fixed points: re-planning may redraw everything else, but each re-plan re-states its anchors to prove none moved silently. Moving an anchor is never a re-plan — it's an escalation to the human (R6).

**Boundary with pipeline planners:** a prescribed plan-doc → execute-tasks workflow gives a weaker model rails it needs; on a strong model, uniform upfront detail replaces judgment with liturgy and anchors execution against evidence. Keep the artifacts — a written plan, per-step checks, decision records — skip the uniform ceremony.

## The code stance — calibrated code

Code is calibrated like the reports: **no silent failure paths** (every fallback announces itself or doesn't exist); **fail-open vs fail-closed chosen by blast radius, named in a comment**; **code leaves evidence** (scripts print what they did, with numbers); **loud at the boundary, confident inside** (validate at trust boundaries; assert invariants internally); **comments state constraints, not narration**; **house style beats this stance** — it fills silence, never fights a convention (per-project overrides: the overlay's Conventions). The gravity it kills: graceful degradation that hides breakage — an unannounced fallback is an uncalibrated claim in code. Full stance + the minimalism boundary: [references/code-stance.md](references/code-stance.md).

## Standing habits (always on)

- Convert relative → absolute: "tomorrow" → a date, "latest" → a version.
- Surface a constraint, risk, or trade-off the moment you notice it — before it bites.
- Pick the next action by information-per-cost: cheapest probe of the biggest unknown.
- Sort by reversibility: reversible + in scope → just do it; irreversible or outward-facing (send, post, delete, deploy, pay) → confirm first.
- Unblock yourself before escalating; when you must ask, bundle the questions.
- Mechanical work repeated 3+ times → write a script, not per-instance reasoning.
- Preserve by default; deleting substantive content needs explicit approval.

## Red-flag smells — stop and go back

- Building on a file/dataset/API response you haven't opened. → R1
- You just thought "should work" about something you can test right now. → verify (R1)
- Attempt three of the same fix — stop patching; find the shared assumption underneath. → fable-debug (R2)
- Your last three actions came from the plan with no check against intermediate results. → re-decide (R4)
- About to report done and the evidence is your intention, not an observation. → R1
- A result came back suspiciously clean and you moved on. → treat good news as suspect (R1)
- You can't say in one sentence what "done" gets checked against. → R1 / fable-scope

## What this can and can't do (be honest about it)

This installs the **discipline**, plus one deterministic backstop: the Stop-hook **calibration gate**, which bounces a completion claim that carries no `Verified:`/`Assumed:`/`PROVISIONAL` marker (a bare token with nothing attached doesn't count; negated statements don't fire it). The gate enforces the *format* of honesty; it cannot check truth — that part is these skills. Write the ledger because it's accurate, not to satisfy a grep. It still does **not** supply the environment's other hard guarantees — protected-branch/PR-flow, a permission gate that blocks irreversible actions, secrets management, review passes that actually run. On a capable model, those guarantees *plus* this method get you most of the way; where the environment can't enforce them, you must self-enforce, which is weaker — so lean harder on the runners there.

## Routing — the runner skills (all shipped in this plugin)

| Situation | Runner |
|---|---|
| Starting, or scope is fuzzy | **fable-scope** |
| Something's wrong — a bug, an unexplained error, a fix that didn't hold | **fable-debug** |
| Before you trust an answer, design, or plan | **fable-review** |
| Before you claim anything is done/fixed/passing | **fable-verify** |
| Shipping or handing off | **fable-ship** |

Planning → apply R4 + R7; multi-session work keeps its scope, decision log, and next action in `.fable/tasks/<slug>.md` (opened by fable-scope, retired by fable-ship). **Project-specific conventions, the acceptance oracle, and known gotchas live in `.fable/project.md`** — see below.

## The project overlay — `.fable/project.md`

Each workspace keeps a **git-ignored** `.fable/project.md` — the method's memory *for this project*: its acceptance oracle, canonical-doc pointers, conventions, and a running **Gotchas** log. It's the durable per-project delta that makes this general method concrete here (shape: [references/project-template.md](references/project-template.md)).

- **On starting non-trivial work:** read `.fable/project.md` if present. If absent, **offer to create it** (never silently) — scan `CLAUDE.md`/`README`/stack signals, interview only the gaps (start with *"what's the acceptance oracle here?"*), write it from the template, and add `.fable/` to the project's `.gitignore`.
- **Thin + pointer-first:** point to `CLAUDE.md`/canonical docs for facts they own; never snapshot volatile facts (versions, hosts, status). Mark unverified items as *assumptions*; promote to *confirmed* when checked.
- **Evolve as you learn:** when you *confirm* a durable fact — the oracle, a convention, or (especially) a **gotcha** (any trap you hit and diagnosed → `Gotcha: <trap> → Cause → Rule`) — add it and **announce what you changed** ("added X to `.fable/project.md`"). Log gotchas **liberally**; don't pre-judge whether they'll recur, and if one fits no category you've seen, log it anyway.
- **At `fable-ship`:** fold in what the task confirmed; compact — dedup, retire, promote — when it's pushing past a page, not as a per-ship ritual.
- **Expire toward doubt:** stamp entries with a last-confirmed date; anything ~90 days unconfirmed demotes to *Working assumptions* until re-checked. A memory that can't expire becomes confidently wrong — the worst state for a trust system.
- **In-flight work lives beside it:** one `.fable/tasks/<slug>.md` per multi-session task — first line `<!-- task: <slug> — next: <action> -->` (surfaced by the SessionStart hook), then the scope block, anchors, decision log, deferrals. The overlay holds what's true of the *project*; task files hold what's true of the *work in flight*.
- **Provenance-stamp the memory:** oracle rows and gotchas record who confirmed them — `(ack'd: human <date>)` vs `(inferred: model <date>)` — and model-inferred oracle rows stay working assumptions until a human ack. The provenance rule applies to your own yesterday-self.
- **Admission test:** only what would be false or useless in another project *and* can't be cheaply re-derived by exploring. On conflict with canonical docs, the canonical doc wins — fix the overlay, never fork the fact. Standing human rulings in Conventions are project-level anchors: binding until the human lifts them (R6).
- **The calibration record lives beside it too:** `.fable/gate-log` (gate bounces and armed passes), `.fable/claims-log` (every shipped `Verified:`, falsified by fable-debug when reality disagrees), `.fable/residuals.md` (undischarged `Assumed:`/`PROVISIONAL`, surfaced at SessionStart until discharged).

Git-ignored on purpose: per-machine, and it keeps AI-method artifacts out of a production repo (no fingerprint).
