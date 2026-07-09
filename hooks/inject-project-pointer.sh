#!/usr/bin/env bash
# fable-method — SessionStart hook (tiered loading, the ambient half).
# If the current workspace has a .fable/project.md, surface its one-line pointer as
# ambient context every session. The FULL overlay is read by the fable-method skill
# when it triggers; this is just the always-on 1-liner. Best-effort, non-blocking.
# No overlay -> prints nothing. Never fails the session.
set +e
f="./.fable/project.md"
[ -f "$f" ] || exit 0
line="$(grep -m1 -oE '<!-- *pointer:.*-->' "$f" 2>/dev/null)"
[ -n "$line" ] || exit 0
msg="$(printf '%s' "$line" | sed -E 's/^<!-- *pointer: *//; s/ *-->$//')"
printf 'fable-method: this workspace has a project overlay (.fable/project.md) — %s\n' "$msg"
exit 0
