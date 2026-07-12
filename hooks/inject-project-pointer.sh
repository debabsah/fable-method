#!/usr/bin/env bash
# fable-method — SessionStart hook (tiered loading, the ambient half).
# Surfaces one line each: the project overlay's pointer (.fable/project.md) and
# any in-flight task files (.fable/tasks/*.md) with their next action. The FULL
# files are read only when the method triggers; this is just the always-on
# one-liners. Best-effort, non-blocking: nothing to surface -> prints nothing.
# Never fails the session.
set +e
d="./.fable"
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
  printf 'fable-method: in-flight task (%s) — %s\n' "$t" "$tmsg"
done
exit 0
