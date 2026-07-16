#!/usr/bin/env bash
# Self-checks for the plugin's scripts (the gate + the status doctor).
# Run: bash hooks/test-gate.sh  (exit 0 = all pass)
set -u
here="$(cd "$(dirname "$0")" && pwd)"
gate="$here/gate-claims.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fails=0; checks=0

mk() { printf '%s\n' "$@" > "$tmp/t.jsonl"; }
mk_long() { # $1 = filler lines after the edit; builds a turn longer than the gate's read window
  { printf '%s\n' "$user" "$edit"
    i=0; while [ "$i" -lt "$1" ]; do printf '%s\n' "$filler"; i=$((i+1)); done
  } > "$tmp/t.jsonl"
}
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
  checks=$((checks + 1))
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
filler='{"type":"assistant","message":{"content":[{"type":"text","text":"working on it"}]}}'

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

# more write paths that leave no >, no sed -i and no git (0.6.1). Selective on
# purpose: bare `python -c` is NOT a signature (it is overwhelmingly used for
# read-only one-liners), so only a write-mode open() arms.
bashcurlo='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"curl -sL https://x/y.tar.gz -o dist.tgz"}}]}}'
bashwget='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"wget https://example.com/pkg.deb"}}]}}'
bashdd='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"dd if=/dev/zero of=disk.img bs=1M count=10"}}]}}'
bashtrunc='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"truncate -s 0 app.log"}}]}}'
bashchmod='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"chmod +x hooks/run.sh"}}]}}'
bashln='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"ln -sf ../real.conf link.conf"}}]}}'
bashpywrite='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"python3 -c \"open('out.txt','w').write(data)\""}}]}}'
bashpyread='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"python3 -c \"import time; print(time.time())\""}}]}}'
bashcurlro='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"curl -s https://api.example.com/health | head -5"}}]}}'

mk "$user" "$bashcurlo";  check "curl -o writes a file and arms"               2 "$(run false "$claim")"
mk "$user" "$bashwget";   check "wget arms the gate"                           2 "$(run false "$claim")"
mk "$user" "$bashdd";     check "dd arms the gate"                             2 "$(run false "$claim")"
mk "$user" "$bashtrunc";  check "truncate arms the gate"                       2 "$(run false "$claim")"
mk "$user" "$bashchmod";  check "chmod arms the gate"                          2 "$(run false "$claim")"
mk "$user" "$bashln";     check "ln -s arms the gate"                          2 "$(run false "$claim")"
mk "$user" "$bashpywrite"; check "python write-mode open() arms the gate"      2 "$(run false "$claim")"
mk "$user" "$bashpyread"; check "read-only python -c does not arm"             0 "$(run false "$claim")"
mk "$user" "$bashcurlro"; check "curl piped to head does not arm"              0 "$(run false "$claim")"
# the same class spelled the other ways: JSON-escaped double quotes put TWO
# chars either side of the mode, and 'wb'/'w+' add one. A test name that claims
# a class while pinning one spelling would stay green through the real miss.
bashpydq='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"python3 -c '"'"'open(\"out.txt\",\"w\").write(x)'"'"'"}}]}}'
bashpywb='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"python3 -c \"open('"'"'f.bin'"'"','"'"'wb'"'"').write(b)\""}}]}}'
bashcurllong='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"curl -sL https://x/y.tgz --output dist.tgz"}}]}}'
bashpyopenread='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"python3 -c \"print(open('"'"'cfg.json'"'"').read())\""}}]}}'
mk "$user" "$bashpydq";   check "open() with JSON-escaped double quotes arms"  2 "$(run false "$claim")"
mk "$user" "$bashpywb";   check "open() with mode 'wb' arms"                   2 "$(run false "$claim")"
mk "$user" "$bashcurllong"; check "curl --output long form arms"               2 "$(run false "$claim")"
mk "$user" "$bashpyopenread"; check "read-mode open() does not arm"            0 "$(run false "$claim")"

# negation hedges (honest not-done statuses must not bounce)
mk "$user" "$edit" "$claimtxt"
check "hedged negation (not completely done) does not fire" 0 "$(run false "This is not completely done. I still need to wire the parser.")"
check "far-from-done does not fire"                         0 "$(run false "This is far from done.")"
# negre must cover every stem claimre carries, or widening the claim list turns
# honest failure reports into bounces — the gate punishing the exact honesty it
# exists to buy. 0.6.1 added `succeeded`/`successfully <verb>` to claimre; these
# pin the matching negation (regression: they exit 0 on 0.6.0, and exit 2 on the
# widened claimre until negre is widened too).
check "'has not succeeded' does not fire"                   0 "$(run false "The deployment has not succeeded.")"
check "'not successfully deployed' does not fire"           0 "$(run false "The change was not successfully deployed.")"
check "'has not succeeded yet' does not fire"               0 "$(run false "The migration has not succeeded yet.")"
check "negation does not shield a real success claim"       2 "$(run false "The first attempt had not succeeded; the migration succeeded on the retry.")"
# same class again: 'checks out' is a claimre stem, so an honest partial-failure
# that keeps the literal "checks out" ("not everything checks out") false-bounces
# (0.6.1 review, MECH lens). Note "do not check out" is grammatically "check out",
# never matches claimre, so it was never the failing case.
check "'not everything checks out' does not fire"           0 "$(run false "Not everything checks out.")"
check "'nothing checks out yet' does not fire"              0 "$(run false "Nothing checks out yet.")"

# claim-detection recall (0.6.1) — real completion phrasings the 14-stem list
# missed. Every one of these exited 0 against the shipped 0.6.0 gate; the
# "successfully deployed" case is a T3 action escaping the backstop entirely.
mk "$user" "$edit" "$claimtxt"
check "bare 'Tests pass.' gates"                   2 "$(run false "Tests pass.")"
check "'The suite is green.' gates"                2 "$(run false "The suite is green.")"
check "'Successfully deployed to staging.' gates"  2 "$(run false "Successfully deployed to staging.")"
check "'The migration succeeded.' gates"           2 "$(run false "The migration succeeded.")"
# 'checks out' was dropped from claimre (0.6.1 review): unlike every other stem,
# its negation keeps the literal words ("not everything checks out"), so it
# false-bounced honest partial-failure reports and could not be suppressed
# without adding noun-fillers to negre. Removal beats that. Accepted recall miss:
check "bare 'Everything checks out.' is a documented recall miss" 0 "$(run false "Everything checks out.")"
# ...and the guards that keep the widened list soft. Bare `works` is deliberately
# NOT a stem: it false-fires on ordinary prose ("how it works"), so "It works."
# stays a known, documented miss — the phrase list is maintained, not exhaustive.
check "explaining how it works does not fire"      0 "$(run false "Here is how it works by hashing the key before the lookup.")"
check "'successfully handles' prose does not fire" 0 "$(run false "The parser successfully handles nested quotes, which is why I chose it.")"
check "conditional 'succeeds' does not fire"       0 "$(run false "This approach succeeds where the regex one fails, so I am using it.")"

# the arming window must cover the whole turn, not just its last 600 lines
# (0.6.1). The escape was correlated with the risk: long tool-heavy turns that
# edit early and claim at the end were the only ones silently skipping the gate.
mk_long 700
check "long turn still arms (edit outside the 600-line window)" 2 "$(run false "$claim")"
mk_long 10
check "short turn arms (window control)"                        2 "$(run false "$claim")"

# two-sided gate-log (needs .fable/ in cwd; also exercises non-git-root fallback)
mkdir -p "$tmp/.fable"
mk "$user" "$edit" "$claimtxt"
run false "$claim"      >/dev/null
run false "$calibrated" >/dev/null
grep -q "BOUNCE phrase=" "$tmp/.fable/gate-log" 2>/dev/null; check "gate-log records bounce with phrase" 0 "$?"
grep -q "PASS phrase="   "$tmp/.fable/gate-log" 2>/dev/null; check "gate-log records armed pass"         0 "$?"
# the snippet is the message, not the JSON field name that carried it (0.6.1;
# observed in a live log as: snippet="last_assistant_message":"All done.")
grep -q 'snippet=All fixed' "$tmp/.fable/gate-log" 2>/dev/null; check "gate-log snippet starts at the message, not the JSON key" 0 "$?"
grep -q 'snippet="last_assistant_message"' "$tmp/.fable/gate-log" 2>/dev/null; check "gate-log snippet carries no JSON key prefix" 1 "$?"

# the log rotates itself: the writer is a deterministic hook firing every armed
# turn, so its bound cannot live in a discretionary model habit at ship time
# (0.6.1 — "expiry lives in the deterministic half, not in hope").
: > "$tmp/.fable/gate-log"
i=0; while [ "$i" -lt 260 ]; do printf '2026-01-01 PASS phrase=filler\n' >> "$tmp/.fable/gate-log"; i=$((i+1)); done
run false "$claim" >/dev/null
lines="$(wc -l < "$tmp/.fable/gate-log" | tr -d ' ')"
[ "$lines" -le 200 ]; check "gate-log self-rotates at its cap (was $lines)" 0 "$?"
grep -q "BOUNCE phrase=" "$tmp/.fable/gate-log" 2>/dev/null; check "rotation keeps the newest line, drops the oldest" 0 "$?"
# restore the 1-bounce/1-pass base the fable-status tallies below assert on
: > "$tmp/.fable/gate-log"
run false "$claim"      >/dev/null
run false "$calibrated" >/dev/null

# the status doctor (read-only; reads the fixture record built above)
# Fixture uses the real grammar (project-template.md: one `- ` bullet per open
# obligation) and the real header, which itself names both tokens. A fixture
# without the header was green fiction — both counters reported +1 forever
# (0.6.1). The prose line pins the other half: mentioning a token is not owing one.
printf '%s\n' '# Residuals — undischarged Assumed:/PROVISIONAL (fable-verify discharges; SessionStart surfaces the count)' > "$tmp/.fable/residuals.md"
printf '%s\n' '- 2026-01-01 (0.1.0) Assumed: staging matches prod - could not check - discharge: diff the configs' >> "$tmp/.fable/residuals.md"
printf '%s\n' 'Prose about how an Assumed: line gets discharged should not be counted as one.' >> "$tmp/.fable/residuals.md"
printf '%s\n' '<!--pointer: tight-proj - oracle: make test. Full: .fable/project.md -->' > "$tmp/.fable/project.md"
printf '%s\n' '2026-01-01 BOUNCE phrase=passing snippet=Done. 42 tests PASSED and all green' >> "$tmp/.fable/gate-log"
out="$(cd "$tmp" && bash "$here/../scripts/fable-status.sh" 2>&1)"
check "fable-status exits clean on a live record" 0 "$?"
printf '%s' "$out" | grep -qi "bounce"; check "fable-status reports gate tallies" 0 "$?"
printf '%s' "$out" | grep -q "residuals: 1"; check "fable-status counts open residuals" 0 "$?"
printf '%s' "$out" | grep -q "overlay: tight-proj"; check "fable-status reads the tight pointer form the hook accepts" 0 "$?"
printf '%s' "$out" | grep -q "2 bounces / 1 armed passes"; check "fable-status tallies anchor on the log grammar, not substrings" 0 "$?"

# the SessionStart injector (0.6.1) — it promotes file text into the session
# preamble, so its inputs are bounded and its git-ignored claim is detected.
inj="$here/inject-project-pointer.sh"
ijt="$(mktemp -d)"; mkdir -p "$ijt/.fable/tasks"
printf '%s\n' '<!-- pointer: p — oracle: make test. Full: .fable/project.md -->' > "$ijt/.fable/project.md"
iout="$(cd "$ijt" && bash "$inj" 2>&1)"
printf '%s' "$iout" | grep -q "overlay"; check "injector surfaces the overlay pointer" 0 "$?"

# control characters in the overlay must be stripped. Assert on CONTENT, not on
# a line count: a tab never forged a line, so a line-count assertion passed
# identically with and without clean() — it pinned nothing it named (0.6.1).
printf '<!-- pointer: A\033B\tC -->\n' > "$ijt/.fable/project.md"
iout="$(cd "$ijt" && bash "$inj" 2>&1)"
printf '%s' "$iout" | LC_ALL=C grep -q '[[:cntrl:]]'; check "injector strips control chars from the pointer" 1 "$?"
printf '%s' "$iout" | grep -q 'ABC'; check "injector keeps the pointer's real text"                         0 "$?"

# an over-long pointer must not flood the preamble
{ printf '<!-- pointer: '; i=0; while [ "$i" -lt 400 ]; do printf 'A'; i=$((i+1)); done; printf ' -->\n'; } > "$ijt/.fable/project.md"
iout="$(cd "$ijt" && bash "$inj" 2>&1)"
[ "${#iout}" -lt 400 ]; check "injector caps pointer length (was ${#iout} chars)" 0 "$?"

# the task list is capped, and says what it withheld
printf '%s\n' '<!-- pointer: p — oracle: make test -->' > "$ijt/.fable/project.md"
i=0; while [ "$i" -lt 14 ]; do printf '<!-- task: t%s — next: wire the parser -->\n' "$i" > "$ijt/.fable/tasks/t$i.md"; i=$((i+1)); done
iout="$(cd "$ijt" && bash "$inj" 2>&1)"
[ "$(printf '%s' "$iout" | grep -c 'in-flight task (')" -le 10 ]; check "injector caps the task list at 10" 0 "$?"
printf '%s' "$iout" | grep -q '+4 more'; check "injector announces the tasks it withheld" 0 "$?"
printf '%s' "$iout" | grep -q 'wire the parser'; check "injector surfaces the task pointer's next: action" 0 "$?"

# the residual counter anchors on the line grammar too — the file's own header
# names both tokens, so a substring count reports +1 forever (0.6.1)
rm -f "$ijt"/.fable/tasks/*.md
printf '%s\n' '# Residuals — undischarged Assumed:/PROVISIONAL (fable-verify discharges; SessionStart surfaces the count)' > "$ijt/.fable/residuals.md"
printf '%s\n' '- 2026-01-01 (0.1.0) Assumed: staging matches prod — could not check — discharge: diff the configs' >> "$ijt/.fable/residuals.md"
printf '%s\n' 'Prose about how an Assumed: line gets discharged should not be counted as one.' >> "$ijt/.fable/residuals.md"
iout="$(cd "$ijt" && bash "$inj" 2>&1)"
printf '%s' "$iout" | grep -q '1 undischarged residual'; check "injector counts residual bullets, not the header or prose" 0 "$?"

# the tracked-repo warning: it must fire on the property it names (TRACKED), not
# on "not ignored" — untracked-and-unignored is the ordinary state of a fresh
# .fable/, and a false alarm there tells the model to distrust its own overlay
# on every session. Needs a real git repo: the block is skipped under mktemp.
gt="$(mktemp -d)"; ( cd "$gt" && git init -q . && git config user.email t@t && git config user.name t )
mkdir -p "$gt/.fable"; printf '%s\n' '<!-- pointer: p — oracle: make test -->' > "$gt/.fable/project.md"
gout="$(cd "$gt" && bash "$inj" 2>&1)"
printf '%s' "$gout" | grep -q "WARNING"; check "untracked+unignored .fable/ does NOT warn" 1 "$?"
( cd "$gt" && git add -f .fable/project.md >/dev/null 2>&1 && git commit -qm t >/dev/null 2>&1 )
gout="$(cd "$gt" && bash "$inj" 2>&1)"
printf '%s' "$gout" | grep -q "WARNING"; check "tracked .fable/ DOES warn"              0 "$?"
rm -rf "$gt"
rm -rf "$ijt"

if [ "$fails" -eq 0 ]; then echo "all checks pass ($checks)"; else echo "$fails check(s) FAILED of $checks"; fi
exit "$fails"
