#!/usr/bin/env bash
# fable-method advisory hook (PreToolUse on Bash).
# Best-effort, NON-BLOCKING: prints a reminder if a command looks like a push to a
# protected/prod main branch. It never blocks — the environment (branch protection)
# is the real guard; this is only a nudge toward PR-flow. Safe to delete.
#
# Reads the PreToolUse JSON payload on stdin; matches the raw text (no jq dependency).

payload="$(cat)"

if printf '%s' "$payload" | grep -Eiq 'git[^"]*push[^"]*(origin[^"]*main|main|HEAD:refs/for/main|:refs/heads/main)'; then
  # Emit an advisory note to stderr. Exit 0 so the tool call still proceeds.
  printf '%s\n' 'fable-method reminder: this looks like a push to main. main is usually protected AND production — prefer branch -> PR -> CI green -> merge. (advisory only; not blocking)' 1>&2
fi

exit 0
