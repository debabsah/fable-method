#!/usr/bin/env bash
# fable-method — SessionStart hook (tiered loading, the ambient half).
# Surfaces one line each: the project overlay's pointer (.fable/project.md),
# any in-flight task files (.fable/tasks/*.md) with their next action and a
# mechanical staleness stamp, and the count of undischarged residuals. The
# FULL files are read only when the method triggers. Best-effort, non-blocking:
# nothing to surface -> prints nothing. Never fails the session.
set +e

# Resolve .fable/ from the git root when available (monorepo subdir sessions).
root="$(git rev-parse --show-toplevel 2>/dev/null)"; [ -n "$root" ] || root="."
d="$root/.fable"
[ -d "$d" ] || exit 0

f="$d/project.md"
if [ -f "$f" ]; then
  line="$(grep -m1 -oE '<!-- *pointer:.*-->' "$f" 2>/dev/null)"
  if [ -n "$line" ]; then
    msg="$(printf '%s' "$line" | sed -E 's/^<!-- *pointer: *//; s/ *-->$//')"
    printf 'fable-method: this workspace has a project overlay (.fable/project.md) — %s\n' "$msg"
  fi
fi

for t in "$d"/tasks/*.md; do
  [ -f "$t" ] || continue
  tline="$(grep -m1 -oE '<!-- *task:.*-->' "$t" 2>/dev/null)"
  if [ -n "$tline" ]; then
    tmsg="$(printf '%s' "$tline" | sed -E 's/^<!-- *task: *//; s/ *-->$//')"
  else
    tmsg="$(basename "$t" .md) — no pointer line; open the file"
  fi
  # Mechanical staleness: expiry lives in the deterministic half, not in hope.
  stale=""
  [ -n "$(find "$t" -mtime +7 -print 2>/dev/null)" ] && stale=" [untouched >7d — resume or retire it]"
  printf 'fable-method: in-flight task (%s) — %s%s\n' "$t" "$tmsg" "$stale"
done

r="$d/residuals.md"
if [ -f "$r" ]; then
  n="$(grep -cE 'Assumed:|PROVISIONAL' "$r" 2>/dev/null)"
  [ "${n:-0}" -gt 0 ] && printf 'fable-method: %s undischarged residual(s) — .fable/residuals.md\n' "$n"
fi
exit 0
