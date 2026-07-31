#!/usr/bin/env bash
# PreToolUse(Bash): route toolchain commands through the project exec wrapper.
# Dormant until EXEC_WRAPPER is set in workflow.conf. Fails open.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${DOCKER_ROUTING:-off}" = off ] && exit 0
[ -n "${EXEC_WRAPPER:-}" ] || exit 0

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
[ -n "$cmd" ] || exit 0

# Already routed through the wrapper, or an explicit docker call -> pass.
printf '%s' "$cmd" | grep -qF "$EXEC_WRAPPER" && exit 0
printf '%s' "$cmd" | grep -qE '\bdocker[[:space:]]+(exec|run)\b' && exit 0

bins="$(printf '%s' "${CONTAINER_BINS:-}" | tr ' ' '|')"
[ -n "$bins" ] || exit 0

# Toolchain binary at a command position: start, or after ; & |, past env/VAR= prefixes.
if printf '%s' "$cmd" | grep -qE "(^|[;&|])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*((env|time)[[:space:]]+)*($bins)\b"; then
  recipe="$EXEC_WRAPPER \"$cmd\""
  case "${DOCKER_ROUTING:-off}" in
    warn) hook_ask "Toolchain command should run via the wrapper. Approve a host run, or use: $recipe" ;;
    *)    hook_deny "Run toolchain commands via the wrapper, not the host: $recipe" ;;
  esac
fi
exit 0
