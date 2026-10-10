#!/bin/bash
# Test this working tree's derive.sh on scratch template and target repos.
#   ./test/derive/run.sh
# One function per scenario; each runs on its own copy of the fixture.
# Scratch is a mktemp directory, removed on success and kept on failure.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SCRATCH=$(mktemp -d) || exit 1
FILL='PRUNE+=(! -path "./external/*")'
BLOCK='# scratch for sessions and tools
work/'
PASS=0
FAIL=0

# Note a value that is not the wanted one
want() {
  if [ "$2" != "$3" ]; then
    printf '%s: got\n%s\nwant\n%s\n' "$1" "$2" "$3"
    BAD=1
  fi
}

# Run the git commands a derive.sh output prints, inside a target
commands() {
  grep '^git ' <<<"$2" | (cd "$1" && bash -e) >/dev/null
}

# Commit the template's staged changes and the named paths
tcommit() {
  local msg=$1
  shift
  if [ $# -gt 0 ]; then
    git -C "$T" add -- "$@"
  fi
  git -C "$T" commit -q -m "$msg"
}

# Sync the target from the template, output and exit code kept
sync() {
  "$T/derive.sh" --sync "$G" 2>&1
}

# local, copy, and remove lines of a sync output, in printed order
listing() {
  grep -E '^(local |copy  |remove) ' <<<"$1"
}

# Derive a target with the given categories, slug demo, and a project tail
derived() {
  local target=$1 out
  shift
  git init -q "$target"
  out=$("$T/derive.sh" "$target" "$@")
  commands "$target" "$out"
  out=$("$T/derive.sh" --slug demo "$target")
  sed -i '1s/.*/# CLAUDE.md -- Demo rules/; 3s/.*/A demo project./' "$target/CLAUDE.md"
  echo 'Demo facts.' >>"$target/.claude/project.md"
  commands "$target" "$out"
  echo 'RUN echo demo-tail' >>"$target/docker/Dockerfile"
  git -C "$target" commit -q -am 'demo: add the project tail'
}

# Build the template clone and the drawio target the scenarios copy
fixture() {
  T=$SCRATCH/tpl
  git clone -q "$REPO" "$T"
  cp -p "$REPO/derive.sh" "$T/derive.sh"
  BASE=$(git -C "$T" rev-parse --short HEAD)
  derived "$SCRATCH/target" drawio
  sed -i "s|^PRUNE+=()\$|$FILL|" "$SCRATCH/target/format/format.sh"
  git -C "$SCRATCH/target" commit -q -am 'demo: fill the prune line'
}

# Set D, T, and G to a scenario's directory and its fixture copies
fresh() {
  D=$SCRATCH/$1
  T=$D/tpl
  G=$D/target
  mkdir "$D"
  cp -a "$SCRATCH/tpl" "$T"
  cp -a "$SCRATCH/target" "$G"
}

# No template change: nothing is touched
up_to_date() {
  local out
  out=$(sync)
  want 'last line' "$(tail -n 1 <<<"$out")" "$G is up to date with the template"
  want listing "$(listing "$out")" ""
  want status "$(git -C "$G" status --porcelain)" ""
}

# One changed rule file is copied; the filled prune line stays
unchanged_file_kept() {
  local out
  echo '- A new rule line.' >>"$T/.claude/engineering.md"
  tcommit 'engineering: add a rule' .claude/engineering.md
  out=$(sync)
  want listing "$(listing "$out")" "copy   .claude/engineering.md"
  want status "$(git -C "$G" status --porcelain)" " M .claude/engineering.md"
  want 'prune line' "$(grep -c -xF "$FILL" "$G/format/format.sh")" 1
  want 'commit command' "$(grep -c "^git commit -m 'template: sync from devansh-dvj/.claude@$(git -C "$T" rev-parse --short HEAD)' " <<<"$out")" 1
}

# A copy over a local change is noted on the line before
local_change_noted() {
  local out
  echo '# trailing template line' >>"$T/format/format.sh"
  tcommit 'format: add a line' format/format.sh
  out=$(sync)
  want listing "$(listing "$out")" "local  format/format.sh"$'\n'"copy   format/format.sh"
  want content "$(cmp "$T/format/format.sh" "$G/format/format.sh" 2>&1)" ""
}

# A local change equal to the template's gets no line
equal_change_silent() {
  local out
  echo '- Shared line.' >>"$G/.claude/session.md"
  git -C "$G" commit -q -am 'session: add a line'
  echo '- Shared line.' >>"$T/.claude/session.md"
  tcommit 'session: add a line' .claude/session.md
  out=$(sync)
  want 'last line' "$(tail -n 1 <<<"$out")" "$G is up to date with the template"
  want listing "$(listing "$out")" ""
}

# Template renames, deletes, and chmods: old paths removed, new ones copied
rename_delete_chmod() {
  local out skills=.claude/skills
  echo 'local licence note' >>"$G/$skills/drawio/LICENSE"
  git -C "$G" commit -q -am 'demo: note the licence'
  git -C "$T" mv "$skills/pdf-addon/scripts/render.py" "$skills/pdf-addon/scripts/draw.py"
  git -C "$T" rm -q "$skills/drawio/LICENSE"
  chmod -x "$T/$skills/drawio/scripts/export.sh"
  tcommit 'skills: rename, delete, chmod' "$skills/drawio/scripts/export.sh"
  out=$(sync)
  want listing "$(listing "$out")" "local  $skills/drawio/LICENSE
remove $skills/drawio/LICENSE
copy   $skills/drawio/scripts/export.sh
remove $skills/pdf-addon/scripts/render.py
copy   $skills/pdf-addon/scripts/draw.py"
  want 'exec bits' "$(stat -c %A "$G/$skills/drawio/scripts/export.sh" "$G/$skills/pdf-addon/scripts/draw.py" | cut -c4 | tr -d '\n')" "-x"
  want 'prune line' "$(grep -c -xF "$FILL" "$G/format/format.sh")" 1
}

# CLAUDE.md, the Dockerfile, and a docker script keep their project parts
project_parts_kept() {
  local out
  echo '> A new template footer.' >>"$T/CLAUDE.md"
  tcommit 'CLAUDE: add a footer' CLAUDE.md
  out=$(sync)
  want 'CLAUDE.md listing' "$(listing "$out")" "copy   CLAUDE.md"
  want heading "$(sed -n '1p;3p' "$G/CLAUDE.md")" "# CLAUDE.md -- Demo rules"$'\n'"A demo project."
  want footer "$(tail -n 1 "$G/CLAUDE.md")" "> A new template footer."
  commands "$G" "$out"

  sed -i '1a # a new shared comment' "$T/docker/Dockerfile"
  tcommit 'docker: comment the base block' docker/Dockerfile
  out=$(sync)
  want 'Dockerfile listing' "$(listing "$out")" "copy   docker/Dockerfile"
  want 'shared line' "$(sed -n 2p "$G/docker/Dockerfile")" "# a new shared comment"
  want 'project tail' "$(tail -n 1 "$G/docker/Dockerfile")" "RUN echo demo-tail"
  want blocks "$(grep '^# ==== ' "$G/docker/Dockerfile" | tr '\n' ' ')" "# ==== base ==== # ==== drawio ==== # ==== project ==== "
  commands "$G" "$out"

  echo '# a new run.sh line for myproject' >>"$T/docker/run.sh"
  tcommit 'docker: add a run.sh line' docker/run.sh
  out=$(sync)
  want 'run.sh listing' "$(listing "$out")" "copy   docker/run.sh"
  want 'slug line' "$(tail -n 1 "$G/docker/run.sh")" "# a new run.sh line for demo"
  want 'placeholders left' "$(grep -c myproject "$G"/docker/*.sh | grep -vc ':0$')" 0
}

# A shallow template lacks BASE: the full sync runs and says why
shallow_template() {
  local out
  echo '# a new run.sh line' >>"$T/docker/run.sh"
  tcommit 'docker: add a run.sh line' docker/run.sh
  git clone -q --depth 1 "file://$T" "$D/shallow"
  cp -p "$T/derive.sh" "$D/shallow/derive.sh"
  out=$("$D/shallow/derive.sh" --sync "$G" 2>&1)
  want 'first line' "$(head -n 1 <<<"$out")" "full sync: template commit $BASE is not in $D/shallow"
  want listing "$(listing "$out")" "copy   docker/run.sh"$'\n'"copy   format/format.sh"
  want 'commit command' "$(grep -c "^git commit -m 'template: sync from " <<<"$out")" 1
}

# A recorded commit the template lacks, or none recorded: the full sync
unknown_base() {
  local out
  git -C "$G" commit -q --allow-empty -m 'template: sync from devansh-dvj/.claude@deadbee'
  out=$(sync)
  want 'first line' "$(head -n 1 <<<"$out")" "full sync: template commit deadbee is not in $T"
  want listing "$(listing "$out")" "copy   format/format.sh"

  rm -rf "$G/.git"
  git init -q "$G"
  git -C "$G" add -A
  git -C "$G" commit -q -m 'demo: start without a template commit'
  out=$(sync)
  want 'no commit recorded' "$(head -n 1 <<<"$out")" "full sync: $G records no template commit"
}

# Dropped categories lose their paths, Dockerfile blocks, and settings keys
dropped_category() {
  local out skills=.claude/skills
  G=$D/slides
  derived "$G" slides
  want 'blocks before' "$(grep -c '^# ==== ' "$G/docker/Dockerfile")" 4
  want 'keys before' "$(grep -c -E 'extraKnownMarketplaces|enabledPlugins' "$G/.claude/settings.json")" 2
  git -C "$G" rm -r -q "$skills/pptx-addon" "$skills/drawio" "$skills/pdf-addon"
  git -C "$G" commit -q -m 'demo: drop slides and drawio'
  out=$(sync)
  want categories "$(head -n 1 <<<"$out")" "categories: core writing"
  want listing "$(listing "$out")" "remove docker/fonts
copy   .claude/settings.json
copy   docker/Dockerfile"
  want fonts "$(ls "$G/docker/fonts" 2>/dev/null)" ""
  want blocks "$(grep '^# ==== ' "$G/docker/Dockerfile" | tr '\n' ' ')" "# ==== base ==== # ==== project ==== "
  want 'project tail' "$(tail -n 1 "$G/docker/Dockerfile")" "RUN echo demo-tail"
  want 'settings keys' "$(grep -c -E 'extraKnownMarketplaces|enabledPlugins' "$G/.claude/settings.json")" 0
}

# --check reports drift by exit code and writes nothing
check_unchanged() {
  local out rc
  out=$("$T/derive.sh" --check "$G" 2>&1)
  rc=$?
  want 'exit on drift' "$rc" 1
  want 'head lines' "$(head -n 2 <<<"$out")" "categories: core drawio"$'\n'"slug: demo"
  want 'drift lines' "$(grep -E '^(differs|missing|extra) ' <<<"$out")" "differs   format"
  want status "$(git -C "$G" status --porcelain)" ""

  sed -i 's|^PRUNE+=.*|PRUNE+=()|' "$G/format/format.sh"
  out=$("$T/derive.sh" --check "$G" 2>&1)
  rc=$?
  want 'exit without drift' "$rc" 0
  want 'no drift lines' "$(grep -E '^(differs|missing|extra) ' <<<"$out")" ""
  want 'status after' "$(git -C "$G" status --porcelain)" " M format/format.sh"
}

# A broken hook stops the sync and the import before the commit commands
broken_hook_stops() {
  local out rc hook=.claude/hooks/protect.py
  echo 'def (' >>"$T/$hook"
  tcommit 'hooks: break the syntax' "$hook"
  out=$(sync)
  rc=$?
  want 'sync exit' "$rc" 1
  want listing "$(listing "$out")" "copy   $hook"
  want 'hook error' "$(grep -c -e "$G/$hook exits 1 on a Bash call, not 0:" -e '^SyntaxError' <<<"$out")" 2
  want 'commit commands' "$(grep -c '^git ' <<<"$out")" 0

  printf 'import sys\n\nsys.exit(0)\n' >"$T/$hook"
  tcommit 'hooks: block nothing' "$hook"
  git init -q "$D/new"
  out=$("$T/derive.sh" "$D/new" 2>&1)
  rc=$?
  want 'import exit' "$rc" 1
  want 'import error' "$(grep -c "$D/new/$hook exits 0 on an edit of .claude/session.md, not 2:" <<<"$out")" 1
  want 'import commit commands' "$(grep -c '^git ' <<<"$out")" 0
}

# A healthy hook lets the sync and the import print their commit commands
healthy_hook_passes() {
  local out rc hook=.claude/hooks/protect.py
  echo '# a new hook comment' >>"$T/$hook"
  tcommit 'hooks: add a comment' "$hook"
  out=$(sync)
  rc=$?
  want 'sync exit' "$rc" 0
  want listing "$(listing "$out")" "copy   $hook"
  want 'commit commands' "$(grep -c '^git ' <<<"$out")" 2

  git init -q "$D/new"
  out=$("$T/derive.sh" "$D/new" 2>&1)
  rc=$?
  want 'import exit' "$rc" 0
  want 'import commit commands' "$(grep -c '^git ' <<<"$out")" 2
}

# Import core into a new repo holding the given .gitignore text, committed
import_with() {
  git init -q "$D/new"
  if [ -n "$1" ]; then
    printf '%s' "$1" >"$D/new/.gitignore"
    git -C "$D/new" add .gitignore
    git -C "$D/new" commit -q -m 'demo: add the ignore file'
  fi
  "$T/derive.sh" "$D/new" 2>&1
}

# Import without a .gitignore: the block is created and committed
ignore_created() {
  local out
  out=$(import_with '')
  want 'append line' "$(grep -c -xF 'append .gitignore' <<<"$out")" 1
  want file "$(cat "$D/new/.gitignore" && echo .)" "$BLOCK"$'\n.'
  want 'commit commands' "$(grep -c '^git .* \.gitignore$' <<<"$out")" 2
}

# Import over a .gitignore without the block: appended, other lines intact
ignore_appended() {
  local out
  out=$(import_with $'build/\n*.log')
  want 'append line' "$(grep -c -xF 'append .gitignore' <<<"$out")" 1
  want file "$(cat "$D/new/.gitignore" && echo .)" $'build/\n*.log\n\n'"$BLOCK"$'\n.'
  want 'commit commands' "$(grep -c '^git .* \.gitignore$' <<<"$out")" 2
}

# A .gitignore ignoring work/ in its own words is left alone
ignore_own_words() {
  local out
  out=$(import_with $'build/\n/work/\n')
  want 'append line' "$(grep -c '^append ' <<<"$out")" 0
  want file "$(cat "$D/new/.gitignore")" $'build/\n/work/'
  want status "$(git -C "$D/new" status --porcelain -- .gitignore)" ""
  want 'commit commands' "$(grep -c '^git .* \.gitignore$' <<<"$out")" 0
}

# work/ ignored only by .git/info/exclude still gets the block
ignore_exclude_only() {
  local out
  git init -q "$D/new"
  echo 'work/' >>"$D/new/.git/info/exclude"
  out=$("$T/derive.sh" "$D/new" 2>&1)
  want 'append line' "$(grep -c -xF 'append .gitignore' <<<"$out")" 1
  want file "$(cat "$D/new/.gitignore")" "$BLOCK"
}

# Sync of a target without the block appends it, with no template change
ignore_synced() {
  local out
  git -C "$G" rm -q .gitignore
  git -C "$G" commit -q -m 'demo: drop the ignore file'
  out=$(sync)
  want listing "$(grep -E '^(local |copy  |remove|append) ' <<<"$out")" "append .gitignore"
  want file "$(cat "$G/.gitignore")" "$BLOCK"
  want 'synced line' "$(grep -c -xF "synced 1 changed file(s) into $G" <<<"$out")" 1
  want 'commit commands' "$(grep -c '^git .* \.gitignore$' <<<"$out")" 2
}

# A dirty .gitignore that needs the block stops the sync
ignore_dirty_dies() {
  local out rc
  echo 'build/' >"$G/.gitignore"
  out=$(sync)
  rc=$?
  want exit "$rc" 1
  want message "$out" "derive.sh: target has uncommitted changes in .gitignore; commit or stash them first"
  want file "$(cat "$G/.gitignore")" "build/"
  want status "$(git -C "$G" status --porcelain)" " M .gitignore"
}

# --replace with a dirty .gitignore that needs the block changes nothing
ignore_dirty_replace() {
  local out rc before
  echo 'build/' >"$G/.gitignore"
  before=$(git -C "$G" status --porcelain)
  out=$("$T/derive.sh" --replace "$G" drawio 2>&1)
  rc=$?
  want exit "$rc" 1
  want message "$out" "derive.sh: target has uncommitted changes in .gitignore; commit or stash them first"
  want status "$(git -C "$G" status --porcelain)" "$before"
  want 'status before' "$before" " M .gitignore"
}

# An import refused for differing files leaves no appended .gitignore
ignore_refused_import() {
  local out rc
  git -C "$G" rm -q .gitignore
  git -C "$G" commit -q -m 'demo: drop the ignore file'
  out=$("$T/derive.sh" "$G" drawio 2>&1)
  rc=$?
  want exit "$rc" 1
  want refusal "$(grep -c 'rerun with --force to overwrite$' <<<"$out")" 1
  want status "$(git -C "$G" status --porcelain)" ""
}

# A relative target reaches the hook check as an absolute path
relative_target() {
  local out rc hook=.claude/hooks/protect.py
  echo '# a new hook comment' >>"$T/$hook"
  tcommit 'hooks: add a comment' "$hook"
  out=$(cd "$D" && "$T/derive.sh" --sync ./target 2>&1)
  rc=$?
  want 'sync exit' "$rc" 0
  want listing "$(listing "$out")" "copy   $hook"
  want 'commit commands' "$(grep -c '^git ' <<<"$out")" 2
  commands "$G" "$out"

  git -C "$G" rm -q .gitignore
  git -C "$G" commit -q -m 'demo: drop the ignore file'
  out=$(cd "$G" && "$T/derive.sh" --replace . drawio 2>&1)
  rc=$?
  want 'replace exit' "$rc" 0
  want 'append line' "$(grep -c -xF 'append .gitignore' <<<"$out")" 1
  want 'replace commit commands' "$(grep -c '^git .* \.gitignore$' <<<"$out")" 2
}

# Run one scenario on fresh copies; print ok, or FAIL with its output
scenario() {
  local out
  if out=$(
    fresh "$1"
    BAD=0
    "$1" 2>&1
    exit "$BAD"
  ); then
    PASS=$((PASS + 1))
    echo "ok   $1"
    rm -rf "${SCRATCH:?}/$1"
  else
    FAIL=$((FAIL + 1))
    echo "FAIL $1"
    printf '%s\n' "$out"
  fi
}

fixture
for s in up_to_date unchanged_file_kept local_change_noted equal_change_silent rename_delete_chmod \
  project_parts_kept shallow_template unknown_base dropped_category check_unchanged \
  broken_hook_stops healthy_hook_passes ignore_created ignore_appended ignore_own_words \
  ignore_exclude_only ignore_synced ignore_dirty_dies ignore_dirty_replace ignore_refused_import \
  relative_target; do
  scenario "$s"
done

echo "derive.sh scenarios: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  echo "scratch kept in $SCRATCH"
  exit 1
fi
rm -rf "$SCRATCH"
