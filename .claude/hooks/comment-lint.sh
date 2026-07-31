#!/usr/bin/env bash
# PostToolUse(Edit|Write): warn on banned change-log comments in edited source.
# Dormant unless COMMENT_LINT=warn. Fails open. Exit 2 feeds a fix-forward note to Claude.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${COMMENT_LINT:-off}" = warn ] || exit 0
[ -n "${COMMENT_BANNED_REGEX:-}" ] || exit 0

input="$(cat)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
content="$(printf '%s' "$input" | jq -r '.tool_input.new_string // .tool_input.content // empty')"
[ -n "$content" ] || exit 0

ext="${file##*.}"
case " ${COMMENT_LINT_EXTENSIONS:-} " in
  *" $ext "*) ;;
  *) exit 0 ;;
esac

hit="$(printf '%s' "$content" | grep -niE "$COMMENT_BANNED_REGEX" | head -3)"
if [ -n "$hit" ]; then
  echo "comment-lint: banned change-log comment in $file. Comments state invariants, not edit history:" >&2
  printf '%s\n' "$hit" >&2
  exit 2
fi
exit 0
