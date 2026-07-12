#!/usr/bin/env bash
# Self-check for gate-claims.sh. Run: bash hooks/test-gate.sh  (exit 0 = all pass)
set -u
here="$(cd "$(dirname "$0")" && pwd)"
gate="$here/gate-claims.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fails=0

mk() { printf '%s\n' "$@" > "$tmp/t.jsonl"; }
run() { # $1 = stop_hook_active value; echoes gate exit code
  printf '{"session_id":"t","transcript_path":"%s","stop_hook_active":%s}' "$tmp/t.jsonl" "$1" \
    | (cd "$tmp" && bash "$gate") >/dev/null 2>&1
  echo $?
}
check() { # name expected got
  if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 (expected exit $2, got $3)"; fails=$((fails+1)); fi
}

edit='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{}}]}}'
claim='{"type":"assistant","message":{"content":[{"type":"text","text":"All fixed and tests passing. Ship it."}]}}'
calibrated='{"type":"assistant","message":{"content":[{"type":"text","text":"Done. Verified: pytest -> 42 passed, 0 failed. Assumed: staging matches prod."}]}}'
noclaim='{"type":"assistant","message":{"content":[{"type":"text","text":"Here is the analysis you asked for."}]}}'

split1='{"type":"assistant","message":{"id":"msg_s1","content":[{"type":"text","text":"Done. Verified: pytest -> 42 passed, 0 failed."}]}}'
split2='{"type":"assistant","message":{"id":"msg_s1","content":[{"type":"text","text":"Left to you: end a turn with a bare \"done\" and watch it bounce."}]}}'
ledgertext='{"type":"assistant","message":{"id":"msg_t8","content":[{"type":"text","text":"Shipped. Verified: push succeeded -> main updated."}]}}'
tooluse='{"type":"assistant","message":{"id":"msg_t9","content":[{"type":"tool_use","name":"Bash","input":{"command":"gh repo edit x --description \"done-claims must carry their ledger\""}}]}}'
splitbad1='{"type":"assistant","message":{"id":"msg_s2","content":[{"type":"text","text":"All work is complete now."}]}}'
splitbad2='{"type":"assistant","message":{"id":"msg_s2","content":[{"type":"text","text":"Everything is done."}]}}'

mk "$edit" "$claim";      check "uncalibrated claim blocks"            2 "$(run false)"
mk "$edit" "$calibrated"; check "claim with ledger passes"             0 "$(run false)"
mk "$edit" "$claim";      check "stop_hook_active passes (loop guard)" 0 "$(run true)"
mk "$claim";              check "no file mutation -> no gate"          0 "$(run false)"
mk "$edit" "$noclaim";    check "no done-claim -> no gate"             0 "$(run false)"
mk "$edit" "$split1" "$split2";       check "chunked message: ledger in earlier chunk passes"   0 "$(run false)"
mk "$edit" "$ledgertext" "$tooluse";  check "tool_use tail (partial flush) fails open"          0 "$(run false)"
mk "$edit" "$splitbad1" "$splitbad2"; check "chunked uncalibrated claim still blocks"           2 "$(run false)"
printf '{"transcript_path":"%s/absent.jsonl","stop_hook_active":false}' "$tmp" \
  | (cd "$tmp" && bash "$gate") >/dev/null 2>&1
check "missing transcript fails open" 0 "$?"

if [ "$fails" -eq 0 ]; then echo "all checks pass"; else echo "$fails check(s) FAILED"; fi
exit "$fails"
