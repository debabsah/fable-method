#!/usr/bin/env bash
# fable-method — Stop-hook calibration gate (the deterministic half of the method).
# When the CURRENT TURN edited files and ends on a completion claim, require the
# claim to be calibrated: `Verified:` evidence, or an explicit `Assumed:`/
# `PROVISIONAL` label. It checks CALIBRATION, not truth — a grep cannot check
# truth; it can check that claim strength is labeled, and log enough to audit.
# Fail-open everywhere: any parsing doubt -> exit 0 (a missed bounce beats a
# trapped session). Loop-safe: continues from this gate always pass.
set +e

payload="$(cat)"

# Loop guard — whitespace-tolerant (a serializer change must not defeat the
# script's only fail-closed path).
printf '%s' "$payload" | grep -qE '"stop_hook_active" *: *true' && exit 0

# The claim is judged on the payload's last_assistant_message — the supported
# field carrying the turn's complete final message (the docs recommend it over
# transcript reads; reconstructing it from transcript flush order once caused
# a live false fire). Field absent (older Claude Code) -> fail open.
last="$(printf '%s' "$payload" | grep -oE '"last_assistant_message": *"([^"\\]|\\.)*"' | head -n 1)"
[ -n "$last" ] || exit 0

# Negated statements are not claims ("not done yet" must not bounce). Judge a
# lowercased copy — BSD sed has no case-insensitive flag — with negated claim
# phrases stripped; the apostrophe class covers ' and multibyte ’ per byte.
judge="$(printf '%s' "$last" | tr '[:upper:]' '[:lower:]')"
negre="(not|never|cannot|no longer|[a-z]+n['’]+t)( (yet|be|been|being|get|fully|actually|all)){0,2} (done|finished|implemented|completed?|fixed|resolved|passing|green|shipped|ready)"
judge="$(printf '%s' "$judge" | sed -E "s/$negre//g")"

# ponytail: word-list predicate; the two-sided log below is its tuning data.
claimre='\b(done|finished|implemented|complete|completed|fixed|resolved|passing|all (tests|checks) (pass(ed)?|green)|all green|good to go|works now|shipped|ready (to|for) (merge|ship|commit|deploy|push|review))\b'
phrase="$(printf '%s' "$judge" | grep -oE "$claimre" | head -n 1)"
[ -n "$phrase" ] || exit 0

# Arm only if THIS turn changed something: in the transcript window after the
# last real user message, look for built-in or MCP editing tools. Sidechain
# (subagent) edits count — the turn still changed files. Bash-side mutations
# are a known dark path; tune from gate-log data.
transcript="$(printf '%s' "$payload" | sed -n 's/.*"transcript_path": *"\([^"]*\)".*/\1/p')"
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0
window="$(tail -n 600 "$transcript")"
cut="$(printf '%s\n' "$window" | grep -n '"type": *"user"' | grep -v 'tool_use_id' | tail -n 1 | cut -d: -f1)"
if [ -n "$cut" ]; then
  seg="$(printf '%s\n' "$window" | tail -n +"$((cut + 1))")"
else
  seg="$window"
fi
printf '%s\n' "$seg" | grep -qE '"name" *: *"(Edit|Write|NotebookEdit|mcp__[A-Za-z0-9_]*(edit|replace|insert|write)[A-Za-z0-9_]*)"' || exit 0

# .fable/ resolves from the git root when available (monorepo subdir sessions).
root="$(git rev-parse --show-toplevel 2>/dev/null)"; [ -n "$root" ] || root="."
log="$root/.fable/gate-log"

# A ledger token vouches only with content attached — a bare "Verified:"
# claims evidence and provides none. Bare PROVISIONAL stays legal: it
# downgrades the result itself.
if printf '%s' "$last" | grep -qE '(Verified|Assumed): *[^ "]|PROVISIONAL'; then
  [ -d "$root/.fable" ] && printf '%s PASS phrase=%s\n' "$(date +%F)" "$phrase" >> "$log"
  exit 0
fi

snippet="$(printf '%s' "$last" | cut -c1-160)"
[ -d "$root/.fable" ] && printf '%s BOUNCE phrase=%s snippet=%s\n' "$(date +%F)" "$phrase" "$snippet" >> "$log"

cat >&2 <<'MSG'
fable-method calibration gate: this turn ends on a completion claim with no evidence attached. Do ONE of these, honestly:
- Run the single command that proves the claim NOW, read its output, then restate:
  Verified: <claim> — ran <command> -> saw <actual output>
  Never write Verified: from memory or an earlier session's run.
- If you cannot or should not run it now, downgrade: mark the result PROVISIONAL,
  or move it to Assumed: <what's unchecked> — why — how the user can check it.
- If this turn genuinely completed nothing, report the status plainly: what changed,
  what remains, the next check.
Do not reword a real completion claim to dodge the gate — a dodged gate is worse
than either honest option.
MSG
exit 2
