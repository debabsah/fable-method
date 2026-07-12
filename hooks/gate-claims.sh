#!/usr/bin/env bash
# fable-method — Stop-hook calibration gate (the deterministic half of the method).
# When a turn that edited files ends on a completion claim, require the claim to
# be calibrated: `Verified:` evidence, or an explicit `Assumed:`/`PROVISIONAL` label.
# It checks CALIBRATION, not truth — a grep cannot check truth; it can check that
# claim strength is labeled. Fail-open everywhere: any parsing doubt -> exit 0.
# Loop-safe: continues triggered by this gate (stop_hook_active) always pass.
set +e

payload="$(cat)"

case "$payload" in
  *'"stop_hook_active":true'*) exit 0 ;;
esac

transcript="$(printf '%s' "$payload" | sed -n 's/.*"transcript_path": *"\([^"]*\)".*/\1/p')"
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

# Only gate turns that changed something; Q&A and read-only sessions pass free.
grep -m1 -qE '"name" *: *"(Edit|Write|NotebookEdit)"' "$transcript" || exit 0

# Final assistant message of the turn (raw JSONL line; token presence is enough).
last="$(tail -n 200 "$transcript" | grep '"type": *"assistant"' | tail -n 1)"
[ -n "$last" ] || exit 0

# No completion claim -> nothing to gate.
printf '%s' "$last" | grep -qiE '\b(done|complete|completed|fixed|resolved|passing|all (tests|checks) pass(ed)?|works now|shipped|ready (to|for) (merge|ship|commit))\b' || exit 0

# Claim carries its ledger -> calibrated, pass.
printf '%s' "$last" | grep -qE 'Verified:|PROVISIONAL|Assumed:' && exit 0

# ponytail: word-list predicate; tune against .fable/gate-log data, not in advance.
[ -d ./.fable ] && printf '%s gate: completion claim without evidence marker\n' "$(date +%F)" >> ./.fable/gate-log

cat >&2 <<'MSG'
fable-method calibration gate: this turn ends on a completion claim with no evidence attached.
Recalibrate the claim to the evidence you already have — do not redo work:
- Verified: <claim> — ran <command/observation> -> saw <result>
- Assumed: <what you could not check> — why — how the user can check it
- If the central claim is unproven, label it PROVISIONAL instead of done.
If nothing was actually completed this turn, restate the status without done-language.
MSG
exit 2
