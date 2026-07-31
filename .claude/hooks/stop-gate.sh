#!/usr/bin/env bash
# Stop: gentle end-of-turn reminder. Opt-in via STOP_GATE=on.
# Never blocks (always exit 0), so it cannot cause a Stop-hook loop. Fails open.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${STOP_GATE:-off}" = on ] || exit 0

input="$(cat)"
# If this Stop is already a hook-driven continuation, stay silent.
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = true ] && exit 0

# Only nudge when the working tree has uncommitted changes.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[ -n "$(git status --porcelain 2>/dev/null)" ] || exit 0

jq -cn '{systemMessage:"Uncommitted changes present. /review-diff checks them against the project rules; commit only when explicitly asked."}'
exit 0
