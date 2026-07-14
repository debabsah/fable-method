# Maintaining fable-method

For whoever edits this plugin next — human or model. The method was distilled with the
original author's intent in context; this file is what keeps edits safe after that
context is gone.

## Where each piece of doctrine is canonical

One source per rule; every other appearance is a display copy or an operational
reminder that must be updated to match, never the other way around.

| Doctrine | Canonical source | Display / reminder copies |
|---|---|---|
| The ledger (three token shapes) | `skills/fable-method/SKILL.md` — "The ledger" | README ledger section; one-line reminders in `fable-verify` step 5 and `fable-ship` |
| Risk tiers + minimum gates | `skills/fable-method/SKILL.md` — tiers table | Runners *echo* the table (e.g. `fable-review` panel sizing) and add only their delta — never restate policy independently |
| The seven reflexes | `skills/fable-method/SKILL.md` | README reflexes table |
| Plan shape, code stance | `skills/fable-method/SKILL.md` (+ `references/code-stance.md` full text) | README sections |
| Overlay shape + admission test | `skills/fable-method/references/project-template.md` | Overlay *protocol* (when to read/write/expire) lives in the method skill, not the template |
| Task-file threshold | Session-boundary or T3 — `fable-scope` | Plan-shape rule 5, README |
| What's enforced vs instructed | README — "What's enforced, and by what" | — |

## Design laws (violating one is a redesign, not an edit)

- **Skills teach, hooks fire.** Anything that must happen every time belongs in a hook;
  skills are discretionary. An advisory hook that prints to nobody is a no-op — v0.1
  shipped one; don't ship another.
- **Fail-open, always.** Any parsing doubt in a hook exits 0. A missed bounce beats a
  trapped session. The only fail-closed path is the Stop-hook loop guard.
- **Text-matching hooks judge strings, not actions.** Keep pattern blast radius soft:
  the gate's patterns may only ever cause one extra bounce demand, never block work.
  Prefer state checks over substrings when one exists.
- **The gate checks calibration, not truth.** It greps for ledger tokens (with content
  attached). Do not add machinery that writes ledger lines for the model — a
  machine-authored `Verified:` is the exact uncalibrated claim the gate exists to kill.
- **Taxonomy:** recurring work *moments* get runner skills; *topics* get review lenses
  or oracle rows; *rules* get single lines in the method; *stances* get reference files.
  New doctrine needs a consuming moment or it doesn't ship.
- **The overlay holds only the non-derivable project delta** (admission test in the
  template). Canonical docs win on conflict.
- **Calibration is the spine.** "Nothing is true until an independent check you did not
  author says so" — organize around it; don't re-spine the doctrine.

## Release flow

1. **Clean room:** `claude plugin disable fable-method@fable-method` before editing
   skills or hooks (no gate firing mid-edit, no installed-vs-repo skew).
2. Edit. For any gate change, **red first**: add the failing check to
   `hooks/test-gate.sh`, watch it fail, then change `hooks/gate-claims.sh`.
3. Oracles: `bash hooks/test-gate.sh` → `all checks pass`, exit 0;
   `claude plugin validate .` → `Validation passed`.
4. Bump the version in **both** `.claude-plugin/plugin.json` and
   `.claude-plugin/marketplace.json`, plus the README badge — `plugin update` sees
   nothing otherwise.
5. Commit and push. Then re-enable, `claude plugin marketplace update fable-method`,
   `claude plugin update fable-method@fable-method` (the bare name fails), and
   `/reload-plugins`. Verify the installed cache: run *its* copy of `test-gate.sh`.

## Tuning the gate from its log

`.fable/gate-log` is two-sided by design: `BOUNCE phrase=… snippet=…` lines show what
fired (over-firing reads as recurring bounces on honest work); `PASS phrase=…` lines
show armed turns that carried a ledger. Silence during real done-claims on edited files
is the under-firing smell. Tune the word-list (`claimre`), the negation strip
(`negre`), and the Bash-mutation signatures (`bashmut`) in `hooks/gate-claims.sh` —
red-first, one pattern at a time, keeping every existing check green. The claim side
reads the Stop payload's `last_assistant_message` (documented, recommended over
transcript parsing); the transcript is read only to decide whether the turn changed
anything.

## The test suite

`hooks/test-gate.sh` builds synthetic transcript fixtures (one JSON entry per line,
matching the real one-entry-per-content-block format) and feeds the gate synthetic Stop
payloads. It covers: loop guard (incl. spaced serialization), turn scoping (sidechain
lines never mark the boundary), arming (built-in / MCP / subagent-dispatch /
Bash-mutation signatures and their false-positive guards, incl. the `description`
field), ledger-token content requirements, negation (incl. hedges and typographic
apostrophes under C locale), fail-open paths, the two-sided log, and the status doctor.
Every live false-fire so far became a permanent regression case — keep that rule.

Two behaviors that look like bugs but are design: a subagent's own tool calls live in
separate transcript files the gate never reads — the Task/Agent *dispatch* is what
arms (delegated work still needs its ledger); and `.fable/` resolves at the nearest
enclosing git root (monorepo subdir sessions), so a non-git directory under a
git-tracked ancestor reads the ancestor's record — all three scripts agree on this.
