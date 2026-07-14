#!/usr/bin/env bash
# Self-checks for the plugin's scripts (the gate + the status doctor).
# Run: bash hooks/test-gate.sh  (exit 0 = all pass)
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
dispatch='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Task","input":{"prompt":"fix the flaky test"}}]}}'
scuser='{"type":"user","isSidechain":true,"message":{"role":"user","content":[{"type":"text","text":"You are a reviewer subagent"}]}}'
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
mcprename='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"mcp__serena__rename_symbol","input":{}}]}}'
mk "$user" "$mcprename";         check "MCP rename/delete/create tools arm the gate"    2 "$(run false "$claim")"
# Subagent work: the dispatch (Task/Agent) is the only trace in the main
# transcript — subagents' own tool calls live in separate files the gate
# never reads. Arming on the dispatch makes delegated work need its ledger.
mk "$user" "$dispatch";          check "subagent dispatch arms (delegated work counts)" 2 "$(run false "$claim")"
mk "$user" "$edit" "$scuser";    check "sidechain user line does not reset the turn cut" 2 "$(run false "$claim")"

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

# Bash-side mutations arm the gate (0.6.0) — high-precision signatures only,
# judged only on Bash tool_use lines; a false arm costs at most one spurious
# bounce demand (still needs a claim + no ledger), tuned from gate-log.
bashsedi='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"sed -i s/a/b/ config.txt"}}]}}'
bashredir='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"echo result > out.txt"}}]}}'
bashgit='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git add -A && git commit -m msg && git push"}}]}}'
bashro='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"grep -rn pattern src/ | head -20"}}]}}'
basharrow='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"echo \"a -> b\" mapping"}}]}}'
bashdevnull='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"claude plugin list 2>/dev/null | head"}}]}}'
textmention='{"type":"assistant","message":{"id":"msg_tm","content":[{"type":"text","text":"Next I could run sed -i or echo > file but have not."}]}}'

bashdesc='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git log --oneline -3","description":"Show recent git commit history"}}]}}'
bashdevout='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git rev-parse --git-dir > /dev/null 2>&1 && command -v rg >/dev/null"}}]}}'
bashawk='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"awk $3 > 100 data.csv | head"}}]}}'
bashgitc='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git -C /repo commit -am wip"}}]}}'
bashreset='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git reset --hard HEAD~1"}}]}}'
bashboth='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"pytest -q &> results.txt"}}]}}'
bashfd1='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"echo hi 1> out.txt"}}]}}'
bashinplace='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"sed --in-place s/a/b/ conf.ini"}}]}}'
bashnl='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"cd /tmp\\nrm -rf build"}}]}}'
bashdockerrm='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"docker run --rm alpine cat /etc/os-release"}}]}}'

mk "$user" "$bashsedi";   check "bash sed -i arms the gate"                    2 "$(run false "$claim")"
mk "$user" "$bashredir";  check "bash redirect arms the gate"                  2 "$(run false "$claim")"
mk "$user" "$bashgit";    check "git commit/push turn arms the gate"           2 "$(run false "Shipped. All done.")"
mk "$user" "$bashgitc";   check "git -C <path> commit arms the gate"           2 "$(run false "$claim")"
mk "$user" "$bashreset";  check "git reset --hard arms the gate"               2 "$(run false "$claim")"
mk "$user" "$bashboth";   check "&> both-streams redirect arms the gate"       2 "$(run false "$claim")"
mk "$user" "$bashfd1";    check "1> explicit-fd redirect arms the gate"        2 "$(run false "$claim")"
mk "$user" "$bashinplace"; check "sed --in-place long flag arms the gate"      2 "$(run false "$claim")"
mk "$user" "$bashnl";     check "rm after a newline in a multiline command arms" 2 "$(run false "$claim")"
mk "$user" "$bashro";     check "read-only bash does not arm"                  0 "$(run false "$claim")"
mk "$user" "$basharrow";  check "quoted arrow (->) is not a redirect"          0 "$(run false "$claim")"
mk "$user" "$bashdevnull"; check "stderr-to-devnull does not arm"              0 "$(run false "$claim")"
mk "$user" "$bashdevout"; check "stdout-to-devnull does not arm"               0 "$(run false "$claim")"
mk "$user" "$bashawk";    check "awk/jq numeric comparison is not a redirect"  0 "$(run false "$claim")"
mk "$user" "$bashdockerrm"; check "--rm flag is not an rm command"             0 "$(run false "$claim")"
mk "$user" "$bashdesc";   check "mutation words in the description field do not arm" 0 "$(run false "$claim")"
mk "$user" "$textmention"; check "text mentioning mutations does not arm"      0 "$(run false "$claim")"

# negation hedges (honest not-done statuses must not bounce)
mk "$user" "$edit" "$claimtxt"
check "hedged negation (not completely done) does not fire" 0 "$(run false "This is not completely done. I still need to wire the parser.")"
check "far-from-done does not fire"                         0 "$(run false "This is far from done.")"

# two-sided gate-log (needs .fable/ in cwd; also exercises non-git-root fallback)
mkdir -p "$tmp/.fable"
mk "$user" "$edit" "$claimtxt"
run false "$claim"      >/dev/null
run false "$calibrated" >/dev/null
grep -q "BOUNCE phrase=" "$tmp/.fable/gate-log" 2>/dev/null; check "gate-log records bounce with phrase" 0 "$?"
grep -q "PASS phrase="   "$tmp/.fable/gate-log" 2>/dev/null; check "gate-log records armed pass"         0 "$?"

# the status doctor (read-only; reads the fixture record built above)
printf 'Assumed: staging matches prod - could not check - diff the configs\n' > "$tmp/.fable/residuals.md"
printf '%s\n' '<!--pointer: tight-proj - oracle: make test. Full: .fable/project.md -->' > "$tmp/.fable/project.md"
printf '%s\n' '2026-01-01 BOUNCE phrase=passing snippet=Done. 42 tests PASSED and all green' >> "$tmp/.fable/gate-log"
out="$(cd "$tmp" && bash "$here/../scripts/fable-status.sh" 2>&1)"
check "fable-status exits clean on a live record" 0 "$?"
printf '%s' "$out" | grep -qi "bounce"; check "fable-status reports gate tallies" 0 "$?"
printf '%s' "$out" | grep -q "residuals: 1"; check "fable-status counts open residuals" 0 "$?"
printf '%s' "$out" | grep -q "overlay: tight-proj"; check "fable-status reads the tight pointer form the hook accepts" 0 "$?"
printf '%s' "$out" | grep -q "2 bounces / 1 armed passes"; check "fable-status tallies anchor on the log grammar, not substrings" 0 "$?"

if [ "$fails" -eq 0 ]; then echo "all checks pass"; else echo "$fails check(s) FAILED"; fi
exit "$fails"
