---
name: fable-review
description: Use before trusting or shipping an answer, design, plan, analysis, or risky code change — when you are about to commit to it. Also when the user asks for a review, a red-team, a second opinion, or to check work adversarially. For pure code diffs, prefer a dedicated code-review command when the environment has one; this runner covers every other artifact and needs nothing installed.
---

# fable-review

Don't self-vibe-check. **Manufacture blind adversaries** — fresh context, none of your rationale — and let them attack the actual work. Uses only the built-in Agent/Task tool — no other plugin required. (For a pure code diff, a dedicated code-review command in your environment may be sharper for that narrow case; this runner needs nothing installed and covers every artifact — designs, plans, analyses, schemas, configs, prose.)

## Run it

1. **Pick 2–5 independent lenses** for what's under review — e.g. correctness/logic, security, data/edge-cases, architecture, requirements-fit, ops. One concern per lens; no overlap.
2. **Dispatch one general-purpose subagent per lens, all in a single message** (multiple Agent/Task calls in one turn = they run in parallel). Use plain **general-purpose** subagents — do not rely on any custom agent type. Give each the blind-adversary prompt (below; full template in [../fable-method/references/adversary-prompt.md](../fable-method/references/adversary-prompt.md)):

   > You are an adversarial **<LENS>** reviewer. Your only job: find real defects in the actual artifact, not in the author's claims about it. Read the real files/output first; verify every assertion against the source. Be skeptical — do **not** rubber-stamp. **Steelman it first** (state what is genuinely sound), then confine your attack to what actually breaks. **Finding nothing wrong is a legitimate result — never invent a problem to look thorough.** READ-ONLY: do not edit files or change any state. Return findings as `severity (Critical/Important/Minor) · file:line · what's wrong · why it matters · how to fix`, plus a one-line verdict.

   Fill `<LENS>` and paste the exact scope (files, diff range, or artifact + the plan/requirements it's judged against).
3. **Collect, dedup, and *verify each finding against the source* before it earns a place on the fix list** — a plausible-sounding finding that isn't in the actual artifact is dropped. Watch for reviewers converging because they shared context rather than because the defect is real. (This is the method's general **provenance rule**: any agent's report — reviewer, subagent, or you — is a claim until checked against the source; a subagent's "success" on delegated work gets the same treatment.)
4. **Triage** what survives: fix-now / defer-with-a-record / accept-with-a-written-note. Report the verdict answer-first.

## When critique lands on *your own* work

Fold it in and credit it; don't defend. Re-derive from the invariant the critique implies ("no line here may contradict X"), not just the lines it cited. Downgrade your own earlier verdict out loud if the evidence contradicts it.
