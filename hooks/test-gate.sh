#!/usr/bin/env bash
# Self-check for gate-claims.sh. Run: bash hooks/test-gate.sh  (exit 0 = all pass)
set -u
here="$(cd "$(dirname "$0")" && pwd)"
gate="$here/gate-claims.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fails=0

mk() { printf '%s\n' "$@" > "$tmp/t.jsonl"; }
run() { # $1 = stop_hook_active; $2 = last_assistant_message (pre-escaped); echoes gate exit code
  printf '{"session_id":"t","transcript_path":"%s","stop_hook_active":%s,"last_assistant_message":"%s"}' "$tmp/t.jsonl" "$1" "$2" \
    | (cd "$tmp" && bash "$gate") >/dev/null 2>&1
  echo $?
}
run_c() { # same, forced C locale (multibyte apostrophe handled as bytes)
  printf '{"session_id":"t","transcript_path":"%s","stop_hook_active":%s,"last_assistant_message":"%s"}' "$tmp/t.jsonl" "$1" "$2" \
    | (cd "$tmp" && LC_ALL=C bash "$gate") >/dev/null 2>&1
  echo $?
}
run_nofield() { # payload without last_assistant_message (older Claude Code)
  printf '{"session_id":"t","transcript_path":"%s","stop_hook_active":false}' "$tmp/t.jsonl" \
    | (cd "$tmp" && bash "$gate") >/dev/null 2>&1
  echo $?
}
run_spaced() { # spaced JSON serialization of the loop guard
  printf '{"session_id":"t","transcript_path":"%s","stop_hook_active" : true,"last_assistant_message":"%s"}' "$tmp/t.jsonl" "$1" \
    | (cd "$tmp" && bash "$gate") >/dev/null 2>&1
  echo $?
}
check() { # name expected got
  if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 (expected exit $2, got $3)"; fails=$((fails+1)); fi
}

# Transcript fixtures carry the ARMING evidence (turn structure + tool names).
# The claim itself arrives in the payload's last_assistant_message; text
# entries below only mirror what real transcripts contain.
user='{"type":"user","message":{"role":"user","content":[{"type":"text","text":"please fix it"}]}}'
edit='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{}}]}}'
mcpedit='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"mcp__serena__replace_content","input":{}}]}}'
scedit='{"type":"assistant","isSidechain":true,"message":{"id":"msg_sce","content":[{"type":"tool_use","name":"Edit","input":{}}]}}'
claimtxt='{"type":"assistant","message":{"id":"msg_c1","content":[{"type":"text","text":"All fixed and tests passing. Ship it."}]}}'

claim="All fixed and tests passing. Ship it."
calibrated="Done. Verified: pytest -> 42 passed, 0 failed. Assumed: staging matches prod."
noclaim="Here is the analysis you asked for."
idiom="Finished. Everything is implemented and all green."

# core behavior
mk "$user" "$edit" "$claimtxt"
check "uncalibrated claim blocks"            2 "$(run false "$claim")"
check "claim with ledger passes"             0 "$(run false "$calibrated")"
check "stop_hook_active passes (loop guard)" 0 "$(run true "$claim")"
check "spaced stop_hook_active still loop-guards" 0 "$(run_spaced "$claim")"
check "no done-claim -> no gate"             0 "$(run false "$noclaim")"
check "finished/implemented/all-green idioms gate" 2 "$(run false "$idiom")"
mk "$user" "$claimtxt"
check "no file mutation -> no gate"          0 "$(run false "$claim")"
printf '{"session_id":"t","transcript_path":"%s/absent.jsonl","stop_hook_active":false,"last_assistant_message":"%s"}' "$tmp" "$claim" \
  | (cd "$tmp" && bash "$gate") >/dev/null 2>&1
check "missing transcript fails open (cannot arm)" 0 "$?"

# turn scoping and arming (design-review regressions, 0.5.0)
mk "$edit" "$user" "$claimtxt";  check "stale edit before user msg: Q&A turn not gated" 0 "$(run false "$claim")"
mk "$user" "$edit" "$claimtxt";  check "edit within current turn still gates"           2 "$(run false "$claim")"
mk "$user" "$mcpedit";           check "MCP edit tool arms the gate"                    2 "$(run false "$claim")"
mk "$user" "$scedit";            check "sidechain edit arms (subagent work counts)"     2 "$(run false "$claim")"

# claim side reads the supported payload field (0.5.2) — the transcript can
# neither supply the claim (old Claude Code: fail open) nor vouch for it.
# Obsoleted by this move: the chunked-message and tool_use-flush cases (Claude
# Code assembles the complete final message) and sidechain text vouching.
mk "$user" "$edit" "$claimtxt"
check "payload without last_assistant_message fails open" 0 "$(run_nofield)"

# ledger tokens vouch only with content attached (0.5.2)
check "bare Verified: token no longer vouches"  2 "$(run false "Done. Verified:")"
check "bare Assumed: token no longer vouches"   2 "$(run false "Everything is complete. Assumed:")"
check "bare PROVISIONAL is a legal self-downgrade" 0 "$(run false "Done. PROVISIONAL")"

# negated statements are not claims (0.5.2)
check "negated claim does not fire"  0 "$(run false "This is not done yet. The tests are not passing either. Next I will wire the parser.")"
check "negation does not shield a real claim" 2 "$(run false "Tests were not passing before this change; now everything is fixed and all green.")"
check "typographic-apostrophe negation passes" 0 "$(run false "The parser isn’t finished.")"
check "typographic negation under C locale"    0 "$(run_c false "The parser isn’t finished.")"

# two-sided gate-log (needs .fable/ in cwd; also exercises non-git-root fallback)
mkdir -p "$tmp/.fable"
mk "$user" "$edit" "$claimtxt"
run false "$claim"      >/dev/null
run false "$calibrated" >/dev/null
grep -q "BOUNCE phrase=" "$tmp/.fable/gate-log" 2>/dev/null; check "gate-log records bounce with phrase" 0 "$?"
grep -q "PASS phrase="   "$tmp/.fable/gate-log" 2>/dev/null; check "gate-log records armed pass"         0 "$?"

if [ "$fails" -eq 0 ]; then echo "all checks pass"; else echo "$fails check(s) FAILED"; fi
exit "$fails"
