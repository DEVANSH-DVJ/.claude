#!/usr/bin/env bash
# PreToolUse(Bash): deny or ask on unsafe git writes. Read-only git always passes.
# Verdicts are the only blocking output; any crash exits non-zero and fails open.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
[ -n "$cmd" ] || exit 0

# Scope: only commands that invoke git.
printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git([[:space:]]|$)' || exit 0

agent_id="$(printf '%s' "$input" | jq -r '.agent_id // empty')"

# Read-only git (no write verb reachable from a git token) passes for everyone.
writes='commit|push|checkout|switch|reset|rebase|merge|rm|mv|add|tag|stash|clean|apply|restore|cherry-pick|revert|fetch|pull|clone|init|gc|prune|worktree'
printf '%s' "$cmd" | grep -qE "\bgit\b[^;&|]*\b($writes)\b" || exit 0

# Subagents never run git writes: the shared index means a concurrent stage gets swept in.
if [ -n "$agent_id" ] && [ "${SUBAGENT_GIT_WRITE:-deny}" = deny ]; then
  hook_deny "Subagents never run git write commands. Report the change; the main session or user handles git."
fi

# Always wrong, regardless of COMMIT_POLICY.
if [ "${FORBID_IDENTITY_OVERRIDE:-1}" = 1 ] && \
   printf '%s' "$cmd" | grep -qE '(-c[[:space:]]+user\.(email|name)|--author=|GIT_AUTHOR_|GIT_COMMITTER_)'; then
  hook_deny "Never override git author/committer identity."
fi
if [ "${FORBID_COAUTHOR:-1}" = 1 ] && printf '%s' "$cmd" | grep -qiE 'co-authored-by'; then
  hook_deny "Co-Authored-By trailers are forbidden in this repo."
fi
if [ "${DENY_INDEX_WIDE_ADD:-1}" = 1 ] && \
   printf '%s' "$cmd" | grep -qE '\bgit[[:space:]]+add[[:space:]]+(-A\b|--all\b|\.([[:space:]]|$|[;&|]))'; then
  hook_deny "Index-wide 'git add' sweeps concurrently-staged files. Add by explicit pathspec: git add -- <paths>."
fi
if printf '%s' "$cmd" | grep -qE '\bgit[[:space:]]+commit\b[^;&|]*(-a\b|-am\b|--all\b)'; then
  hook_deny "'git commit -a/--all' sweeps unstaged files. Stage explicit paths, then: git commit -m msg -- <paths>."
fi

# Opt-in: commits must name paths (message-only amend and --only are exempt).
if [ "${REQUIRE_COMMIT_PATHSPEC:-0}" = 1 ] && printf '%s' "$cmd" | grep -qE '\bgit[[:space:]]+commit\b'; then
  if ! printf '%s' "$cmd" | grep -qE '(--amend|--only|[[:space:]]--[[:space:]]+\S)'; then
    hook_deny "Commit by explicit pathspec: git commit -m msg -- <paths>."
  fi
fi

# Quoting the guard cannot parse -> ask, never deny.
if printf '%s' "$cmd" | grep -qE '(<<[-]?[A-Za-z_"'\'']|(sh|bash)[[:space:]]+-c)'; then
  hook_ask "git appears inside quoting the guard cannot parse. Approve if intended: $cmd"
fi

# Policy gate for the remaining git writes.
case "${COMMIT_POLICY:-ask}" in
  deny)  hook_deny "This repo: Claude generates changes; the user runs git. (COMMIT_POLICY=deny)" ;;
  allow) exit 0 ;;
  *)     hook_ask "Authorize git write: $cmd" ;;
esac
