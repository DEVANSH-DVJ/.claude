#!/usr/bin/env bash
# Sanity-check the hook toolchain and git-guard decisions. Run after porting the template.
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
guard="$HOOK_DIR/git-guard.sh"
fail=0

command -v jq >/dev/null 2>&1 || { echo "FAIL: jq not on PATH (hooks fail open without it)"; fail=1; }
for f in lib.sh git-guard.sh; do
  [ -x "$HOOK_DIR/$f" ] || { echo "FAIL: $f is not executable"; fail=1; }
done
( . "$(dirname "$HOOK_DIR")/workflow.conf" ) 2>/dev/null || { echo "FAIL: workflow.conf does not source"; fail=1; }

# case <label> <json-in> <expect: pass|deny|ask>
check() {
  local label="$1" json="$2" expect="$3" out
  out="$(printf '%s' "$json" | "$guard" 2>/dev/null)"
  local got=pass
  printf '%s' "$out" | grep -q '"permissionDecision":"deny"' && got=deny
  printf '%s' "$out" | grep -q '"permissionDecision":"ask"' && got=ask
  if [ "$got" != "$expect" ]; then echo "FAIL: $label -> expected $expect, got $got"; fail=1; fi
}

check "read-only git status"      '{"tool_input":{"command":"git status"}}'                              pass
check "read-only git diff"        '{"tool_input":{"command":"git diff HEAD~1"}}'                          pass
check "subagent commit"           '{"agent_id":"a1","tool_input":{"command":"git commit -m x -- a.rs"}}'  deny
check "identity override"         '{"tool_input":{"command":"git -c user.email=x commit -m y -- a"}}'     deny
check "co-authored-by trailer"    '{"tool_input":{"command":"git commit -m \"x\\n\\nCo-Authored-By: z\""}}' deny
check "index-wide add"            '{"tool_input":{"command":"git add -A"}}'                               deny
check "commit -a sweep"           '{"tool_input":{"command":"git commit -am wip"}}'                       deny
check "clean pathspec commit"     '{"tool_input":{"command":"git commit -m ok -- a.rs"}}'                 ask
check "non-git bash"              '{"tool_input":{"command":"ls -la"}}'                                   pass

# --- docker-route (needs EXEC_WRAPPER; run against a scratch conf) ---
droute="$HOOK_DIR/docker-route.sh"
tmpconf="$(mktemp)"
printf '%s\n' 'DOCKER_ROUTING="block"' 'EXEC_WRAPPER="docker/exec.sh"' 'CONTAINER_BINS="cargo npm pytest"' > "$tmpconf"
dcheck() {
  local label="$1" json="$2" expect="$3" out got=pass
  out="$(printf '%s' "$json" | WORKFLOW_CONF="$tmpconf" "$droute" 2>/dev/null)"
  printf '%s' "$out" | grep -q '"permissionDecision":"deny"' && got=deny
  printf '%s' "$out" | grep -q '"permissionDecision":"ask"' && got=ask
  if [ "$got" != "$expect" ]; then echo "FAIL: $label -> expected $expect, got $got"; fail=1; fi
}
dcheck "bare cargo build"      '{"tool_input":{"command":"cargo build"}}'                    deny
dcheck "wrapped cargo build"   '{"tool_input":{"command":"docker/exec.sh \"cargo build\""}}' pass
dcheck "env-prefixed pytest"   '{"tool_input":{"command":"FOO=1 pytest -q"}}'                deny
dcheck "non-toolchain ls"      '{"tool_input":{"command":"ls -la"}}'                         pass
rm -f "$tmpconf"

[ "$fail" = 0 ] && echo "ok: hook selftests passed"
exit "$fail"
