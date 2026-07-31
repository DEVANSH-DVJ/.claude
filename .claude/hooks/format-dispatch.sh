#!/usr/bin/env bash
# PostToolUse(Edit|Write|NotebookEdit): format the edited file via the project formatter.
# Dormant until FORMAT_CMD is set. Fails open. Exit 2 tells Claude the file changed on disk.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${FORMAT_MODE:-off}" = off ] && exit 0
[ -n "${FORMAT_CMD:-}" ] || exit 0

input="$(cat)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
[ -n "$file" ] && [ -f "$file" ] || exit 0

ext="${file##*.}"
case " ${FORMAT_EXTENSIONS:-} " in
  *" $ext "*) ;;
  *) exit 0 ;;
esac

before="$(cksum "$file" 2>/dev/null)"
cmd="${FORMAT_CMD//\{FILE\}/$file}"
sh -c "$cmd" >/dev/null 2>&1 || exit 0   # broken formatter must not punish the edit
after="$(cksum "$file" 2>/dev/null)"

if [ "$before" != "$after" ]; then
  echo "$file was auto-formatted; its content changed on disk -- re-read it before further edits." >&2
  exit 2
fi
exit 0
