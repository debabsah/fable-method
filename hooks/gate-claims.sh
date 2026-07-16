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
# Accepted, priced, and disclosed in the docs (0.6.1 review): this makes the
# gate a first-offence reminder, not a wall — the flag is true *because* this
# gate just blocked, so any second message passes however uncalibrated. A
# trapped session is the worse harm, so the trade stands. Deliberately NOT
# logging a YIELD line here: this is the one fail-closed path in the script and
# it stays minimal — observability is not worth work before this exit.
printf '%s' "$payload" | grep -qE '"stop_hook_active" *: *true' && exit 0

# The claim is judged on the payload's last_assistant_message — the supported
# field carrying the turn's complete final message (the docs recommend it over
# transcript reads; reconstructing it from transcript flush order once caused
# a live false fire). Field absent (older Claude Code) -> fail open.
last="$(printf '%s' "$payload" | grep -oE '"last_assistant_message": *"([^"\\]|\\.)*"' | head -n 1)"
[ -n "$last" ] || exit 0
# grep -oE returns the WHOLE match, field name included. Strip to the message so
# the gate-log snippet spends its budget on the claim rather than on a constant
# (0.6.1; a live log showed: snippet="last_assistant_message":"All done."). Only
# the log reads worse for it — the claim/negation/ledger greps below are
# unaffected either way, since the prefix carries none of their tokens.
last="$(printf '%s' "$last" | sed -E 's/^"last_assistant_message": *"//; s/"$//')"

# Negated statements are not claims ("not done yet" must not bounce). Judge a
# lowercased copy — BSD sed has no case-insensitive flag — with negated claim
# phrases stripped; the apostrophe class covers ' and multibyte ’ per byte.
#
# INVARIANT: every stem `claimre` recognises must appear in this terminal group.
# Widen one without the other and the gate bounces honest failure reports — it
# starts punishing the exact candour it exists to buy, which is worse than the
# miss it was closing. 0.6.1 shipped that regression for one commit: `succeeded`
# / `successfully` went into claimre alone, so "The deployment has not
# succeeded." bounced. Pinned now by the three "does not fire" checks.
judge="$(printf '%s' "$last" | tr '[:upper:]' '[:lower:]')"
negre="(not|never|cannot|no longer|far from|[a-z]+n['’]+t)( (yet|be|been|being|get|fully|actually|all|completely|entirely|quite|nearly|even|close to)){0,2} (done|finished|implemented|completed?|fixed|resolved|passing|green|shipped|ready|succeeded|successful(ly)?)"
judge="$(printf '%s' "$judge" | sed -E "s/$negre//g")"

# Maintained phrase list, not an exhaustive one — the two-sided log below is its
# tuning data, and the docs say so rather than implying full recall. 0.6.1 added
# the classes a blind review proved were escaping: bare "tests pass" (the old
# pattern required a literal "all"), "suite is green", "succeeded",
# "successfully <verb>". "Successfully deployed" escaping meant a T3 action
# escaped the backstop entirely. ("checks out" was tried and removed: unlike
# every other stem its negation keeps the literal words — "not everything checks
# out" — so it false-bounced honest failure reports; see negre invariant.)
# Known accepted misses, priced deliberately: bare `works` is NOT a stem ("It
# works." is missed) because it false-fires on ordinary prose ("how it works by
# hashing"), and a conditional "whether the tests pass" DOES arm — at worst one
# spurious bounce demand, which the design law prices as acceptable.
claimre='\b(done|finished|implemented|complete|completed|fixed|resolved|passing|shipped|succeeded|good to go|works now|all green|(tests?|checks?|suite|build) (pass(es|ed)?|(are |is )?green)|successfully (ran|deployed|merged|pushed|applied|installed|migrated|completed|built|created|updated|fixed)|ready (to|for) (merge|ship|commit|deploy|push|review))\b'
phrase="$(printf '%s' "$judge" | grep -oE "$claimre" | head -n 1)"
[ -n "$phrase" ] || exit 0

# Arm only if THIS turn changed something: after the last real user message,
# look for editing tools or a subagent dispatch (Task/Agent) — a subagent's own
# tool calls live in separate transcript files this gate never reads, so the
# dispatch is delegated work's only trace here, and its report is a claim
# (provenance rule). Sidechain lines never mark the turn boundary.
#
# The turn cut is computed over the WHOLE transcript. Until 0.6.1 this read
# `tail -n 600` and cut inside it; a turn longer than the window pushed its own
# edits out of view, no user line remained to cut on, and the gate failed open —
# silently, on exactly the long tool-heavy turns that edit early and claim at the
# end. The escape was correlated with the risk, and every fixture was 2-3 lines,
# so nothing caught it. Pinned now by "long turn still arms".
# Measured, not assumed: on a real 10MB transcript this runs ~0.315s vs ~0.687s
# for the 0.6.0 window version — the full scan is *faster*, because grep streams
# where `tail -n 600` seeks and then hands 600 multi-KB lines to a shell variable.
# A two-path fast/slow variant measured no better and was deleted. Don't
# reintroduce a window here without a benchmark.
transcript="$(printf '%s' "$payload" | sed -n 's/.*"transcript_path": *"\([^"]*\)".*/\1/p')"
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0
cut="$(grep -an '"type": *"user"' "$transcript" 2>/dev/null | grep -v 'tool_use_id' | grep -v '"isSidechain" *: *true' | tail -n 1 | cut -d: -f1)"
if [ -n "$cut" ]; then
  seg="$(tail -n +"$((cut + 1))" "$transcript")"
else
  seg="$(tail -n 600 "$transcript")"   # no real user line anywhere -> bounded fallback
fi
if ! printf '%s\n' "$seg" | grep -qE '"name" *: *"(Edit|Write|NotebookEdit|Task|Agent|mcp__[A-Za-z0-9_]*(edit|replace|insert|write|rename|delete|create|move)[A-Za-z0-9_]*)"'; then
  # Bash-side mutations arm too (0.6.0). Judged ONLY on the "command" values
  # of Bash tool_use lines — text blocks and model-authored "description"
  # fields can't arm. /dev/null redirects are stripped before matching.
  # Signatures: sed -i/--in-place, tee, git state ops (incl. -C <path>),
  # mv/cp/rm (word-anchored, also after a literal \n; never a --flag), and
  # redirects to file-ish targets (>, >>, N>, &>) — excludes 2>&1, "->",
  # "=>", and numeric comparisons (awk '$3 > 100'). Known accepted cost: a
  # quoted '>' aimed at a word ("foo > bar") still false-arms — at worst one
  # spurious bounce demand, since a bare claim must also be present.
  # Fail-open bias kept; tune from gate-log.
  cmds="$(printf '%s\n' "$seg" | grep '"name" *: *"Bash"' | grep -oE '"command": *"([^"\\]|\\.)*"' | sed -E 's/[0-9&]?>{1,2} *\/dev\/null//g')"
  [ -n "$cmds" ] || exit 0
  # 0.6.1 added write paths that leave no >, no sed -i and no git: curl -o/-O,
  # wget, dd, truncate, chmod/chown, ln -s, and a write-mode open() (the model's
  # usual way to write a file from a one-liner). Selective on purpose — bare
  # `python -c` is NOT a signature: it is overwhelmingly a read-only one-liner,
  # so only `open(..., 'w'|'a')` arms. Pinned both ways by "python write-mode
  # open() arms" / "read-only python -c does not arm".
  bashmut='(^|\\n|[^-A-Za-z0-9_])(sed +-[a-zA-Z]*i|tee |git +(-C +[^ ]+ +)?(add|commit|push|merge|apply|rm|mv|reset|restore|clean|stash|checkout)($|[^-A-Za-z0-9_])|(mv|cp|rm|dd|truncate|chmod|wget) )|--in-place|curl [^|]*(-[oO]\b|--output|--remote-name)|ln +-[a-zA-Z]*s|open\([^)]*,.{0,2}[wa][b+]?.{0,2}\)|[^<>&=-]>{1,2} *[A-Za-z_./~$\\]|&>{1,2} *[A-Za-z_./~$\\]'
  printf '%s' "$cmds" | grep -qE "$bashmut" || exit 0
fi

# .fable/ resolves from the git root when available (monorepo subdir sessions).
root="$(git rev-parse --show-toplevel 2>/dev/null)"; [ -n "$root" ] || root="."
log="$root/.fable/gate-log"

# The writer owns the bound (0.6.1). This hook appends on every armed turn, so
# leaving rotation to a model habit at ship time meant a session that never
# ships grew the log forever — and it put the audited party in charge of its own
# audit log. Same rule the SessionStart hook already states: expiry lives in the
# deterministic half, not in hope. 200 lines is the tuning window fable-status
# reads; older lines have already served their purpose.
logline() {
  [ -d "$root/.fable" ] || return 0
  printf '%s\n' "$1" >> "$log"
  if [ "$(wc -l < "$log" 2>/dev/null || echo 0)" -gt 200 ]; then
    tmpl="$(mktemp "$log.XXXXXX" 2>/dev/null)" || return 0
    tail -n 200 "$log" > "$tmpl" 2>/dev/null && mv "$tmpl" "$log" || rm -f "$tmpl"
  fi
}

# A ledger token vouches only with content attached — a bare "Verified:"
# claims evidence and provides none. Bare PROVISIONAL stays legal: it
# downgrades the result itself.
if printf '%s' "$last" | grep -qE '(Verified|Assumed): *[^ "]|PROVISIONAL'; then
  logline "$(date +%F) PASS phrase=$phrase"
  exit 0
fi

snippet="$(printf '%s' "$last" | cut -c1-160)"
logline "$(date +%F) BOUNCE phrase=$phrase snippet=$snippet"

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
