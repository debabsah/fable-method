#!/usr/bin/env bash
# fable-method — the status doctor. READ-ONLY: reports the health of this
# workspace's .fable/ record (overlay, tasks, residuals, calibration logs)
# so the model-followed habits are checkable at a glance. Writes nothing.
# Run from anywhere in the project: bash scripts/fable-status.sh
set +e

# .fable/ resolves from the git root. With no git root at all the record binds to
# the cwd, so two sessions started in different directories quietly keep two
# half-records that each read as complete. Can't fix that here without changing
# where the hooks look — but a fallback that announces itself beats one that
# doesn't, so report the absolute path and name the risk (0.6.1).
root="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$root" ]; then nogit=""; else root="$(pwd)"; nogit="  [no git root — this record is bound to this cwd; a session started elsewhere reads a different .fable/]"; fi
f="$root/.fable"

if [ ! -d "$f" ]; then
  echo "fable-status: no .fable/ here ($root) — the overlay bootstraps on first real work."
  exit 0
fi

echo "fable-status — $root/.fable$nogit"

# Overlay: pointer, oracle rows, stale rows (last-confirmed date > ~90 days old).
if [ -f "$f/project.md" ]; then
  pointer="$(sed -n 's/.*<!-- *pointer: *\(.*\) -->.*/\1/p' "$f/project.md" | head -n 1)"
  [ -n "$pointer" ] && echo "overlay: $pointer" || echo "overlay: present (no pointer line — add one; SessionStart surfaces it)"
  rows=$(grep -c '^|' "$f/project.md" 2>/dev/null)
  cutoff="$(date -v-90d +%F 2>/dev/null || date -d '90 days ago' +%F 2>/dev/null)"
  if [ -n "$cutoff" ]; then
    stale=$(grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' "$f/project.md" | awk -v c="$cutoff" '$0 < c' | wc -l | tr -d ' ')
    echo "overlay rows (incl. table headers): $rows; dates older than 90d: $stale (expiry rule: demote to working assumptions)"
  else
    echo "overlay rows (incl. table headers): $rows"
  fi
else
  echo "overlay: MISSING (dir exists, project.md does not)"
fi

# In-flight tasks and their staleness (same 7-day rule the SessionStart hook stamps).
tasks=0; stale_tasks=0
if [ -d "$f/tasks" ]; then
  for t in "$f/tasks"/*.md; do
    [ -f "$t" ] || continue
    tasks=$((tasks + 1))
    [ -n "$(find "$t" -mtime +7 2>/dev/null)" ] && stale_tasks=$((stale_tasks + 1))
  done
fi
echo "in-flight tasks: $tasks (untouched >7d: $stale_tasks)"

# Residuals: undischarged obligations. Count POSITIVELY against the residual
# grammar (project-template.md: one `- ` bullet per obligation) — not "any line
# with the words", which counted the file's own header (+1 forever, 0.6.1) and
# any prose mentioning a token. Same rule the gate-log tallies below follow.
# Keep this identical to hooks/inject-project-pointer.sh (R2: both callers).
if [ -f "$f/residuals.md" ]; then
  res=$(grep -cE '^[[:space:]]*[-*][[:space:]].*(Assumed:|PROVISIONAL)' "$f/residuals.md" 2>/dev/null)
else
  res=0
fi
echo "open residuals: $res"

# Gate log: both failure directions, so over- and under-firing are visible.
if [ -f "$f/gate-log" ]; then
  # Anchor on the log grammar (date + marker + phrase=), not bare substrings:
  # a snippet quoting "PASSED" must not count as an armed pass.
  bounces=$(grep -c ' BOUNCE phrase=' "$f/gate-log" 2>/dev/null)
  passes=$(grep -c ' PASS phrase=' "$f/gate-log" 2>/dev/null)
  lastb="$(grep ' BOUNCE phrase=' "$f/gate-log" | tail -n 1 | cut -c1-100)"
  echo "gate: $bounces bounces / $passes armed passes (the log self-rotates at 200 lines, so this is the recent window once it matures — not a lifetime total)"
  [ -n "$lastb" ] && echo "  last bounce: $lastb"
else
  echo "gate: no log yet (appears on the first armed pass or bounce in an overlay project)"
fi

# Claims log: the trust record fable-debug falsifies against. Read the archives
# too (`claims-log.<year>`, per fable-ship) — a record that silently answers for
# this year only would read as "we have barely vouched for anything" every
# January, which is the trust question inverted. R2: every caller of the archive
# rule must know the archive exists.
set -- "$f"/claims-log "$f"/claims-log.*
logs=""; for c in "$@"; do [ -f "$c" ] && logs="$logs $c"; done
if [ -n "$logs" ]; then
  # A FALSIFIED line quotes its original Verified: text — count it once, as falsified.
  # shellcheck disable=SC2086
  claims=$(cat $logs 2>/dev/null | grep 'Verified:' | grep -vc 'FALSIFIED')
  # shellcheck disable=SC2086
  falsified=$(cat $logs 2>/dev/null | grep -c 'FALSIFIED')
  echo "claims: $claims shipped Verified: lines, $falsified falsified"
else
  echo "claims: no log yet (fable-ship appends shipped Verified: lines)"
fi
exit 0
