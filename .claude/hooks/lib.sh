#!/usr/bin/env bash
# Shared hook helpers: kill-switch, config load, PreToolUse decision emitters.
# Everything here fails OPEN -- a broken hook must never brick a session.

[ "${WORKFLOW_HOOKS_DISABLE:-0}" = 1 ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$(dirname "$HOOK_DIR")"

# Committed defaults, then optional gitignored per-machine overrides.
# WORKFLOW_CONF (if set) replaces both -- used by selftest to run against a scratch config.
if [ -n "${WORKFLOW_CONF:-}" ]; then
  [ -f "$WORKFLOW_CONF" ] && . "$WORKFLOW_CONF"
else
  [ -f "$CLAUDE_DIR/workflow.conf" ] && . "$CLAUDE_DIR/workflow.conf"
  [ -f "$CLAUDE_DIR/workflow.local.conf" ] && . "$CLAUDE_DIR/workflow.local.conf"
fi

# PreToolUse verdicts: exit 0 with a JSON decision on stdout.
hook_deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}
hook_ask() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  exit 0
}
