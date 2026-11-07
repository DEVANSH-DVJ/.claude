#!/bin/bash
# Test this working tree's derive.sh on scratch template and target repos.
#   ./test/derive/run.sh
# One function per scenario; each runs on its own copy of the fixture.
# Scratch is a mktemp directory, removed on success and kept on failure.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SCRATCH=$(mktemp -d) || exit 1
FILL='PRUNE+=(! -path "./external/*")'
PASS=0
FAIL=0

# Note a value that is not the wanted one
want() {
  if [ "$2" != "$3" ]; then
    printf '%s: got\n%s\nwant\n%s\n' "$1" "$2" "$3"
    BAD=1
  fi
}

# Run the template's derive.sh, stderr into stdout
derive() {
  "$T/derive.sh" "$@" 2>&1
}

# Sync the target, with any categories named
sync() {
  derive --sync "$G" "$@"
}

# Check the target, with any categories named
check() {
  derive --check "$G" "$@"
}

# Local, copy, and remove lines of an output, in printed order
listing() {
  grep -E '^(local |copy  |remove) ' <<<"$1"
}

# Block markers of a target's Dockerfile, on one line
blocks() {
  grep '^# ==== ' "$1/docker/Dockerfile" | tr '\n' ' '
}

# File whose rule ignores a target's work/
ignore_source() {
  git -C "$1" check-ignore -v work/x | cut -d: -f1
}

# Run the git commands an output prints, inside a target
run_commands() {
  grep '^git ' <<<"$2" | (cd "$1" && bash -e) >/dev/null
}

# Commit the template's staged changes and the named paths
commit_template() {
  local msg=$1
  shift
  if [ $# -gt 0 ]; then
    git -C "$T" add -- "$@"
  fi
  git -C "$T" commit -q -m "$msg"
}

# Append a line to a template file, then commit it
append_template() {
  printf '%s\n' "$2" >>"$T/$1"
  commit_template "$3" "$1"
}

# Derive a target: categories, slug demo, project tail
derive_demo() {
  local target=$1 out
  shift
  git init -q "$target"
  out=$("$T/derive.sh" "$target" "$@")
  run_commands "$target" "$out"
  out=$("$T/derive.sh" --slug demo "$target")
  sed -i '1s/.*/# CLAUDE.md -- Demo rules/; 3s/.*/A demo project./' "$target/CLAUDE.md"
  echo 'Demo facts.' >>"$target/.claude/project.md"
  run_commands "$target" "$out"
  echo 'RUN echo demo-tail' >>"$target/docker/Dockerfile"
  git -C "$target" commit -q -am 'demo: add the project tail'
}

# Point G at a new slides-pptx demo target
derive_slides() {
  G=$D/slides
  derive_demo "$G" slides-pptx
}

# Commit the given .gitignore text into a target
commit_gitignore() {
  printf '%s' "$2" >"$1/.gitignore"
  git -C "$1" add .gitignore
  git -C "$1" commit -q -m 'demo: add the ignore file'
}

# Commit a build/ .gitignore into G, then dirty it
dirty_gitignore() {
  commit_gitignore "$G" $'build/\n'
  echo '*.log' >>"$G/.gitignore"
}

# Drop work/ from a target's .git/info/exclude
drop_exclude() {
  sed -i '/^work\/$/d' "$1/.git/info/exclude"
}

# Import core into N, after any given .gitignore
import_new() {
  git init -q "$N"
  if [ -n "${1:-}" ]; then
    commit_gitignore "$N" "$1"
  fi
  derive "$N"
}

# Build the template clone and drawio target to copy
build_fixture() {
  T=$SCRATCH/tpl
  git clone -q "$REPO" "$T"
  cp -p "$REPO/derive.sh" "$T/derive.sh"
  BASE=$(git -C "$T" rev-parse --short HEAD)
  derive_demo "$SCRATCH/target" drawio
  sed -i "s|^PRUNE+=()\$|$FILL|" "$SCRATCH/target/format/format.sh"
  git -C "$SCRATCH/target" commit -q -am 'demo: fill the prune line'
}

# Set a scenario's D, T, G, and N; copy the fixture
copy_fixture() {
  D=$SCRATCH/$1
  T=$D/tpl
  G=$D/target
  N=$D/new
  mkdir "$D"
  cp -a "$SCRATCH/tpl" "$T"
  cp -a "$SCRATCH/target" "$G"
}

# Run a scenario; print ok, or FAIL and its output
run_scenario() {
  local out
  if out=$(
    copy_fixture "$1"
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

# -- import --

# A healthy hook lets sync and import print commits
healthy_hook_accepted() {
  local out rc hook=.claude/hooks/protect.py
  append_template "$hook" '# a new hook comment' 'hooks: add a comment'
  out=$(sync)
  rc=$?
  want 'sync exit' "$rc" 0
  want listing "$(listing "$out")" "copy   $hook"
  want 'commit commands' "$(grep -c '^git ' <<<"$out")" 2

  out=$(import_new)
  rc=$?
  want 'import exit' "$rc" 0
  want 'import commit commands' "$(grep -c '^git ' <<<"$out")" 2
}

# A broken hook stops sync and import before commits
broken_hook_refused() {
  local out rc hook=.claude/hooks/protect.py
  append_template "$hook" 'def (' 'hooks: break the syntax'
  out=$(sync)
  rc=$?
  want 'sync exit' "$rc" 1
  want listing "$(listing "$out")" "copy   $hook"
  want 'hook error' "$(grep -c -e "$G/$hook exits 1 on a Bash call, not 0:" -e '^SyntaxError' <<<"$out")" 2
  want 'commit commands' "$(grep -c '^git ' <<<"$out")" 0

  printf 'import sys\n\nsys.exit(0)\n' >"$T/$hook"
  commit_template 'hooks: block nothing' "$hook"
  out=$(import_new)
  rc=$?
  want 'import exit' "$rc" 1
  want 'import error' "$(grep -c "$N/$hook exits 0 on an edit of .claude/session.md, not 2:" <<<"$out")" 1
  want 'import commit commands' "$(grep -c '^git ' <<<"$out")" 0
}

# A relative target reaches the hook as absolute
relative_target_resolved() {
  local out rc hook=.claude/hooks/protect.py
  append_template "$hook" '# a new hook comment' 'hooks: add a comment'
  out=$(cd "$D" && derive --sync ./target)
  rc=$?
  want 'sync exit' "$rc" 0
  want listing "$(listing "$out")" "copy   $hook"
  want 'commit commands' "$(grep -c '^git ' <<<"$out")" 2
  run_commands "$G" "$out"

  drop_exclude "$G"
  out=$(cd "$G" && derive --replace . drawio)
  rc=$?
  want 'replace exit' "$rc" 0
  want 'exclude line' "$(grep -c -xF 'exclude work/' <<<"$out")" 1
  want source "$(ignore_source "$G")" .git/info/exclude
  want 'replace commit commands' "$(grep -c '^git ' <<<"$out")" 2
}

# -- categories and blocks --

# slides-latex pulls in paper-latex, drawio, and writing
implied_categories_added() {
  local out
  git init -q "$N"
  out=$(derive "$N" slides-latex)
  want copied "$(grep -c "^copied [0-9]* files (core, drawio, writing, paper-latex, slides-latex) into $N\$" <<<"$out")" 1
  want skills "$(LC_ALL=C ls "$N/.claude/skills" | tr '\n' ' ')" "beamer comment-style commit delegate drawio format latex pdf-addon plans review-diff writing "
  want blocks "$(blocks "$N")" "# ==== base ==== # ==== drawio ==== # ==== project ==== "
}

# Unnamed categories lose paths, Dockerfile blocks, settings keys
unnamed_category_removed() {
  local out skills=.claude/skills
  derive_slides
  want 'blocks before' "$(blocks "$G")" "# ==== base ==== # ==== drawio ==== # ==== pptx ==== # ==== project ==== "
  want 'keys before' "$(grep -c -E 'extraKnownMarketplaces|enabledPlugins' "$G/.claude/settings.json")" 2
  out=$(sync writing)
  want categories "$(head -n 1 <<<"$out")" "categories: core writing"
  want listing "$(listing "$out")" "remove $skills/drawio
remove $skills/pdf-addon
remove docker/fonts
remove $skills/pptx-addon
copy   .claude/settings.json
copy   docker/Dockerfile"
  want 'commit command' "$(grep -c "^git commit -m 'template: sync core, writing from devansh-dvj/.claude@$BASE' " <<<"$out")" 1
  want fonts "$(ls "$G/docker/fonts" 2>/dev/null)" ""
  want blocks "$(blocks "$G")" "# ==== base ==== # ==== project ==== "
  want 'project tail' "$(tail -n 1 "$G/docker/Dockerfile")" "RUN echo demo-tail"
  want 'settings keys' "$(grep -c -E 'extraKnownMarketplaces|enabledPlugins' "$G/.claude/settings.json")" 0
}

# Sync records named categories; the next sync reuses them
named_categories_recorded() {
  local out
  out=$(sync drawio writing)
  want 'named categories' "$(head -n 1 <<<"$out")" "categories: core drawio writing"
  want 'named commit' "$(grep -c "^git commit -m 'template: sync core, drawio, writing from devansh-dvj/.claude@$BASE' " <<<"$out")" 1
  run_commands "$G" "$out"

  append_template .claude/engineering.md '- A new rule line.' 'engineering: add a rule'
  out=$(sync)
  want 'recorded categories' "$(head -n 1 <<<"$out")" "categories: core drawio writing"
  want listing "$(listing "$out")" "copy   .claude/engineering.md"
  want 'recorded commit' "$(grep -c "^git commit -m 'template: sync core, drawio, writing from devansh-dvj/.claude@$(git -C "$T" rev-parse --short HEAD)' " <<<"$out")" 1
}

# Nothing to copy: an empty commit records new categories
empty_commit_recorded() {
  local out m
  out=$(sync drawio)
  want 'recorded last line' "$(tail -n 1 <<<"$out")" "$G is up to date with the template"
  want 'recorded commands' "$(grep -c '^git ' <<<"$out")" 0

  for m in 'template: sync' 'template: sync core, draw'; do
    git -C "$G" commit -q --allow-empty -m "$m from devansh-dvj/.claude@$BASE"
    out=$(sync drawio)
    want "$m listing" "$(listing "$out")" ""
    want "$m commit" "$(grep '^git ' <<<"$out")" "git commit --allow-empty -m 'template: sync core, drawio from devansh-dvj/.claude@$BASE' -- CLAUDE.md .claude format docker"
    run_commands "$G" "$out"
    want "$m files" "$(git -C "$G" show --format= --name-only HEAD)" ""
    out=$(sync)
    want "$m next sync" "$(tail -n 1 <<<"$out")" "$G is up to date with the template"
  done
  want status "$(git -C "$G" status --porcelain)" ""
}

# Unrecorded categories stop --check and --sync until named
unrecorded_categories_refused() {
  local out rc m
  git -C "$G" commit -q --allow-empty -m "template: sync from devansh-dvj/.claude@$BASE"
  append_template .claude/engineering.md '- A new rule line.' 'engineering: add a rule'
  for m in check sync; do
    out=$(derive "--$m" "$G")
    rc=$?
    want "$m exit" "$rc" 1
    want "$m error" "$out" "derive.sh: the categories of $G are not recorded; name them: derive.sh --$m $G <category>..."
  done
  want status "$(git -C "$G" status --porcelain)" ""

  out=$(check drawio)
  want 'check head lines' "$(head -n 2 <<<"$out")" "categories: core drawio"$'\n'"slug: demo"
  out=$(sync drawio)
  want listing "$(listing "$out")" "copy   .claude/engineering.md"
  want 'named commit' "$(grep -c "^git commit -m 'template: sync core, drawio from devansh-dvj/.claude@$(git -C "$T" rev-parse --short HEAD)' " <<<"$out")" 1
}

# A commit body line is no template commit
commit_body_ignored() {
  local out
  git -C "$G" commit -q --allow-empty -m 'demo: quote a sync' -m 'template: sync core from devansh-dvj/.claude@deadbee'
  out=$(sync)
  want categories "$(head -n 1 <<<"$out")" "categories: core drawio"
  want 'last line' "$(tail -n 1 <<<"$out")" "$G is up to date with the template"
}

# Old categories refused, named or recorded; new names sync
old_category_refused() {
  local out rc c m
  git init -q "$N"
  for c in slides latex; do
    out=$(derive "$N" "$c")
    rc=$?
    want "$c exit" "$rc" 1
    want "$c error" "$out" "derive.sh: unknown category: $c (one of: core drawio writing slides-pptx paper-latex slides-latex)"
  done
  want 'nothing copied' "$(ls -A "$N")" .git

  derive_slides
  sed -i 's/^# ==== pptx ====$/# ==== slides ====/' "$G/docker/Dockerfile"
  git -C "$G" commit -q -am "template: import core, drawio, writing, slides from devansh-dvj/.claude@$BASE"
  for m in check sync; do
    out=$(derive "--$m" "$G")
    rc=$?
    want "recorded $m exit" "$rc" 1
    want "recorded $m error" "$out" "derive.sh: the last template commit of $G records unknown category slides; name them: derive.sh --$m $G <category>..."
    out=$(derive "--$m" "$G" slides)
    rc=$?
    want "named $m exit" "$rc" 1
    want "named $m error" "$out" "derive.sh: unknown category: slides (one of: core drawio writing slides-pptx paper-latex slides-latex)"
  done
  want status "$(git -C "$G" status --porcelain)" ""

  out=$(check slides-pptx)
  want 'check categories' "$(head -n 1 <<<"$out")" "categories: core drawio writing slides-pptx"
  want 'check drift' "$(grep -E '^(differs|missing|extra) ' <<<"$out")" "differs   docker/Dockerfile"
  out=$(sync slides-pptx)
  want 'sync categories' "$(head -n 1 <<<"$out")" "categories: core drawio writing slides-pptx"
  want listing "$(listing "$out")" "copy   docker/Dockerfile"
  want blocks "$(blocks "$G")" "# ==== base ==== # ==== drawio ==== # ==== pptx ==== # ==== project ==== "
}

# -- slug --

# --slug without a placeholder dies, changing nothing
slug_without_placeholder_refused() {
  local out rc
  out=$(derive --slug other "$G")
  rc=$?
  want exit "$rc" 1
  want error "$out" "derive.sh: no myproject placeholder left to replace in $G/docker/*.sh"
  want status "$(git -C "$G" status --porcelain)" ""
}

# -- check --

# --check reports drift by exit code, writes nothing
check_drift_reported() {
  local out rc
  out=$(check)
  rc=$?
  want 'exit on drift' "$rc" 1
  want 'head lines' "$(head -n 2 <<<"$out")" "categories: core drawio"$'\n'"slug: demo"
  want 'drift lines' "$(grep -E '^(differs|missing|extra) ' <<<"$out")" "differs   format"
  want status "$(git -C "$G" status --porcelain)" ""

  sed -i 's|^PRUNE+=.*|PRUNE+=()|' "$G/format/format.sh"
  out=$(check)
  rc=$?
  want 'exit without drift' "$rc" 0
  want 'no drift lines' "$(grep -E '^(differs|missing|extra) ' <<<"$out")" ""
  want 'status after' "$(git -C "$G" status --porcelain)" " M format/format.sh"
}

# A --check that cannot compare dies with the reason
check_failure_reported() {
  local out rc
  python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); del d["enabledPlugins"]; json.dump(d, open(sys.argv[1], "w"))' "$T/.claude/settings.json"
  out=$(check)
  rc=$?
  want 'settings exit' "$rc" 1
  want 'settings reason' "$(tail -n 1 <<<"$out")" "KeyError: 'enabledPlugins'"
  want 'settings statuses' "$(grep -c -E '^(identical|filled|differs|missing|extra) ' <<<"$out")" 0
  git -C "$T" checkout -q -- .claude/settings.json

  echo '# ==== extra ====' >>"$T/docker/Dockerfile"
  out=$(check)
  rc=$?
  want 'block exit' "$rc" 1
  want 'block reason' "$out" "derive.sh: no category for Dockerfile block extra"
  git -C "$T" checkout -q -- docker/Dockerfile

  sed -i '/^# ==== project ====$/d' "$G/docker/Dockerfile"
  out=$(check)
  rc=$?
  want 'marker exit' "$rc" 1
  want 'marker reason' "$(tail -n 1 <<<"$out")" "derive.sh: no '# ==== project ====' line in $G/docker/Dockerfile; add it above the project's own lines first"
  want 'marker status' "$(grep -c ' docker/Dockerfile$' <<<"$out")" 0
}

# -- sync --

# No template change: nothing is touched
up_to_date_target_untouched() {
  local out
  out=$(sync)
  want 'last line' "$(tail -n 1 <<<"$out")" "$G is up to date with the template"
  want listing "$(listing "$out")" ""
  want status "$(git -C "$G" status --porcelain)" ""
}

# A changed rule is copied; the filled prune line stays
changed_file_copied() {
  local out
  append_template .claude/engineering.md '- A new rule line.' 'engineering: add a rule'
  out=$(sync)
  want listing "$(listing "$out")" "copy   .claude/engineering.md"
  want status "$(git -C "$G" status --porcelain)" " M .claude/engineering.md"
  want 'prune line' "$(grep -c -xF "$FILL" "$G/format/format.sh")" 1
  want 'commit command' "$(grep -c "^git commit -m 'template: sync core, drawio from devansh-dvj/.claude@$(git -C "$T" rev-parse --short HEAD)' " <<<"$out")" 1
}

# A copy over a local change is noted first
local_change_noted() {
  local out
  append_template format/format.sh '# trailing template line' 'format: add a line'
  out=$(sync)
  want listing "$(listing "$out")" "local  format/format.sh"$'\n'"copy   format/format.sh"
  want content "$(cmp "$T/format/format.sh" "$G/format/format.sh" 2>&1)" ""
}

# A local change equal to the template's is not noted
equal_change_unnoted() {
  local out
  echo '- Shared line.' >>"$G/.claude/session.md"
  git -C "$G" commit -q -am 'session: add a line'
  append_template .claude/session.md '- Shared line.' 'session: add a line'
  out=$(sync)
  want 'last line' "$(tail -n 1 <<<"$out")" "$G is up to date with the template"
  want listing "$(listing "$out")" ""
}

# Template renames, deletes, and chmods reach the target
rename_delete_chmod_applied() {
  local out skills=.claude/skills
  echo 'local licence note' >>"$G/$skills/drawio/LICENSE"
  git -C "$G" commit -q -am 'demo: note the licence'
  git -C "$T" mv "$skills/pdf-addon/scripts/render.py" "$skills/pdf-addon/scripts/draw.py"
  git -C "$T" rm -q "$skills/drawio/LICENSE"
  chmod -x "$T/$skills/drawio/scripts/export.sh"
  commit_template 'skills: rename, delete, chmod' "$skills/drawio/scripts/export.sh"
  out=$(sync)
  want listing "$(listing "$out")" "local  $skills/drawio/LICENSE
remove $skills/drawio/LICENSE
copy   $skills/drawio/scripts/export.sh
remove $skills/pdf-addon/scripts/render.py
copy   $skills/pdf-addon/scripts/draw.py"
  want 'exec bits' "$(stat -c %A "$G/$skills/drawio/scripts/export.sh" "$G/$skills/pdf-addon/scripts/draw.py" | cut -c4 | tr -d '\n')" "-x"
  want 'prune line' "$(grep -c -xF "$FILL" "$G/format/format.sh")" 1
}

# CLAUDE.md, Dockerfile, and docker scripts keep project parts
project_parts_kept() {
  local out
  append_template CLAUDE.md '> A new template footer.' 'CLAUDE: add a footer'
  out=$(sync)
  want 'CLAUDE.md listing' "$(listing "$out")" "copy   CLAUDE.md"
  want heading "$(sed -n '1p;3p' "$G/CLAUDE.md")" "# CLAUDE.md -- Demo rules"$'\n'"A demo project."
  want footer "$(tail -n 1 "$G/CLAUDE.md")" "> A new template footer."
  run_commands "$G" "$out"

  sed -i '1a # a new shared comment' "$T/docker/Dockerfile"
  commit_template 'docker: comment the base block' docker/Dockerfile
  out=$(sync)
  want 'Dockerfile listing' "$(listing "$out")" "copy   docker/Dockerfile"
  want 'shared line' "$(sed -n 2p "$G/docker/Dockerfile")" "# a new shared comment"
  want 'project tail' "$(tail -n 1 "$G/docker/Dockerfile")" "RUN echo demo-tail"
  want blocks "$(blocks "$G")" "# ==== base ==== # ==== drawio ==== # ==== project ==== "
  run_commands "$G" "$out"

  append_template docker/run.sh '# a new run.sh line for myproject' 'docker: add a run.sh line'
  out=$(sync)
  want 'run.sh listing' "$(listing "$out")" "copy   docker/run.sh"
  want 'slug line' "$(tail -n 1 "$G/docker/run.sh")" "# a new run.sh line for demo"
  want 'placeholders left' "$(grep -c myproject "$G"/docker/*.sh | grep -vc ':0$')" 0
}

# A shallow template lacks BASE: full sync, saying why
shallow_template_fully_synced() {
  local out
  append_template docker/run.sh '# a new run.sh line' 'docker: add a run.sh line'
  git clone -q --depth 1 "file://$T" "$D/shallow"
  cp -p "$T/derive.sh" "$D/shallow/derive.sh"
  out=$("$D/shallow/derive.sh" --sync "$G" 2>&1)
  want 'first line' "$(head -n 1 <<<"$out")" "full sync: template commit $BASE is not in $D/shallow"
  want listing "$(listing "$out")" "copy   docker/run.sh"$'\n'"copy   format/format.sh"
  want 'commit command' "$(grep -c "^git commit -m 'template: sync core, drawio from " <<<"$out")" 1
}

# An unknown or missing base gets the full sync
unknown_base_fully_synced() {
  local out rc
  git -C "$G" commit -q --allow-empty -m 'template: sync core, drawio from devansh-dvj/.claude@deadbee'
  out=$(sync)
  want 'first line' "$(head -n 1 <<<"$out")" "full sync: template commit deadbee is not in $T"
  want listing "$(listing "$out")" "copy   format/format.sh"

  rm -rf "$G/.git"
  git init -q "$G"
  git -C "$G" add -A
  git -C "$G" commit -q -m 'demo: start without a template commit'
  out=$(sync)
  rc=$?
  want 'unnamed exit' "$rc" 1
  want 'unnamed error' "$out" "derive.sh: the categories of $G are not recorded; name them: derive.sh --sync $G <category>..."
  out=$(sync drawio)
  want 'no commit recorded' "$(head -n 1 <<<"$out")" "full sync: $G records no template commit"
}

# A sync without a filled slug dies, writing nothing
sync_without_slug_refused() {
  local out rc c err="derive.sh: no slug in $G/docker/build.sh: want IMAGE_NAME=\"<slug>:...\" with the placeholder filled"
  for c in unparsable placeholder missing; do
    case $c in
      unparsable) sed -i 's/^IMAGE_NAME="demo:/IMAGE_NAME="Demo:/' "$G/docker/build.sh" ;;
      placeholder) sed -i 's/^IMAGE_NAME="Demo:/IMAGE_NAME="myproject:/' "$G/docker/build.sh" ;;
      missing) git -C "$G" rm -q docker/build.sh ;;
    esac
    git -C "$G" commit -q -am "demo: make the slug $c"
    out=$(sync)
    rc=$?
    want "$c exit" "$rc" 1
    want "$c error" "$out" "$err"
    want "$c status" "$(git -C "$G" status --porcelain)" ""
  done
}

# -- exclude --

# Import without a .gitignore: work/ excluded, none made
exclude_created() {
  local out
  out=$(import_new)
  want 'exclude line' "$(grep -c -xF 'exclude work/' <<<"$out")" 1
  want source "$(ignore_source "$N")" .git/info/exclude
  want 'no .gitignore' "$(ls -A "$N" | grep -c -xF .gitignore)" 0
  want 'commit commands' "$(grep -c '^git ' <<<"$out")" 2
  want 'gitignore commands' "$(grep -c -E '^git .* \.gitignore( |$)' <<<"$out")" 0
}

# Import over a .gitignore: work/ excluded, file untouched
gitignore_untouched() {
  local out
  out=$(import_new $'build/\n*.log')
  want 'exclude line' "$(grep -c -xF 'exclude work/' <<<"$out")" 1
  want source "$(ignore_source "$N")" .git/info/exclude
  want file "$(cat "$N/.gitignore" && echo .)" $'build/\n*.log.'
  want status "$(git -C "$N" status --porcelain -- .gitignore)" ""
  want 'gitignore commands' "$(grep -c -E '^git .* \.gitignore( |$)' <<<"$out")" 0
}

# A .gitignore ignoring work/ itself: nothing excluded
own_ignore_respected() {
  local out
  out=$(import_new $'build/\n/work/\n')
  want 'exclude line' "$(grep -c '^exclude ' <<<"$out")" 0
  want source "$(ignore_source "$N")" .gitignore
  want excluded "$(grep -c -xF 'work/' "$N/.git/info/exclude")" 0
  want file "$(cat "$N/.gitignore")" $'build/\n/work/'
  want status "$(git -C "$N" status --porcelain -- .gitignore)" ""
}

# work/ already excluded: nothing added
existing_exclude_kept() {
  local out before
  git init -q "$N"
  echo 'work/' >>"$N/.git/info/exclude"
  before=$(cat "$N/.git/info/exclude")
  out=$(derive "$N")
  want 'exclude line' "$(grep -c '^exclude ' <<<"$out")" 0
  want exclude "$(cat "$N/.git/info/exclude")" "$before"
}

# An unended exclude file gets work/ on its own line
unended_exclude_appended() {
  git init -q "$N"
  printf '*.tmp' >"$N/.git/info/exclude"
  derive "$N" >/dev/null
  want exclude "$(cat "$N/.git/info/exclude" && echo .)" $'*.tmp\nwork/\n.'
}

# A missing .git/info is made, work/ excluded
exclude_info_made() {
  git init -q --template= "$N"
  derive "$N" >/dev/null
  want source "$(ignore_source "$N")" .git/info/exclude
}

# Sync adds a missing exclude with nothing to commit
exclude_synced() {
  local out
  commit_gitignore "$G" $'build/\n'
  drop_exclude "$G"
  out=$(sync)
  want listing "$(grep -E '^(local |copy  |remove|exclude) ' <<<"$out")" "exclude work/"
  want source "$(ignore_source "$G")" .git/info/exclude
  want 'last line' "$(tail -n 1 <<<"$out")" "$G is up to date with the template"
  want file "$(cat "$G/.gitignore")" "build/"
  want status "$(git -C "$G" status --porcelain)" ""
}

# A dirty .gitignore neither stops a sync nor changes
dirty_gitignore_kept_by_sync() {
  local out rc
  dirty_gitignore
  drop_exclude "$G"
  out=$(sync)
  rc=$?
  want exit "$rc" 0
  want 'exclude line' "$(grep -c -xF 'exclude work/' <<<"$out")" 1
  want file "$(cat "$G/.gitignore")" $'build/\n*.log'
  want status "$(git -C "$G" status --porcelain)" " M .gitignore"
}

# A dirty .gitignore neither stops --replace nor changes
dirty_gitignore_kept_by_replace() {
  local out rc
  dirty_gitignore
  out=$(derive --replace "$G" drawio)
  rc=$?
  want exit "$rc" 0
  want file "$(cat "$G/.gitignore")" $'build/\n*.log'
  want status "$(git -C "$G" status --porcelain -- .gitignore)" " M .gitignore"
  want 'gitignore commands' "$(grep -c -E '^git .* \.gitignore( |$)' <<<"$out")" 0
}

# A refused import leaves the exclude as it was
exclude_kept_on_refusal() {
  local out rc before
  drop_exclude "$G"
  before=$(cat "$G/.git/info/exclude")
  out=$(derive "$G" drawio)
  rc=$?
  want exit "$rc" 1
  want refusal "$(grep -c 'rerun with --force to overwrite$' <<<"$out")" 1
  want exclude "$(cat "$G/.git/info/exclude")" "$before"
  want status "$(git -C "$G" status --porcelain)" ""
}

# -- errors --

# A sync's failed git call dies with git's message
git_failure_reported() {
  local out rc p
  mkdir "$D/bin"
  printf '#!/bin/bash\nif [[ " $* " == *" $FAILGIT "* ]]; then\n  echo fatal: injected >&2\n  exit 128\nfi\nexec %s "$@"\n' "$(command -v git)" >"$D/bin/git"
  chmod +x "$D/bin/git"
  append_template .claude/engineering.md '- A new rule line.' 'engineering: add a rule'
  for p in --untracked-files=no cat-file --name-status show --untracked-files=all; do
    rm -rf "$G"
    cp -a "$SCRATCH/target" "$G"
    out=$(PATH=$D/bin:$PATH FAILGIT=$p sync)
    rc=$?
    want "$p failed" "$((rc != 0))" 1
    want "$p git message" "$(grep -c -xF 'fatal: injected' <<<"$out")" 1
    want "$p commands" "$(grep -c -e '^git ' -e ' up to date ' <<<"$out")" 0
  done
}

# Two mode flags, or a stray --force or --replace, die
conflicting_flags_refused() {
  local out rc args msg argv
  while IFS='|' read -r args msg; do
    read -r -a argv <<<"$args"
    out=$(derive "${argv[@]}" "$G" </dev/null)
    rc=$?
    want "$args exit" "$rc" 1
    want "$args error" "$out" "derive.sh: $msg"
  done <<'CASES'
--check --sync|one mode flag at most, got --check and --sync
--sync --slug demo|one mode flag at most, got --sync and --slug
--slug demo --check|one mode flag at most, got --slug and --check
--force --sync|--force and --replace go with an import only, not --sync
--check --replace|--force and --replace go with an import only, not --check
--slug demo --force|--force and --replace go with an import only, not --slug
CASES
  want status "$(git -C "$G" status --porcelain)" ""
}

build_fixture
for s in \
  healthy_hook_accepted broken_hook_refused relative_target_resolved \
  implied_categories_added unnamed_category_removed named_categories_recorded empty_commit_recorded \
  unrecorded_categories_refused commit_body_ignored old_category_refused \
  slug_without_placeholder_refused \
  check_drift_reported check_failure_reported \
  up_to_date_target_untouched changed_file_copied local_change_noted equal_change_unnoted \
  rename_delete_chmod_applied project_parts_kept shallow_template_fully_synced unknown_base_fully_synced \
  sync_without_slug_refused \
  exclude_created gitignore_untouched own_ignore_respected existing_exclude_kept unended_exclude_appended \
  exclude_info_made exclude_synced dirty_gitignore_kept_by_sync dirty_gitignore_kept_by_replace \
  exclude_kept_on_refusal \
  git_failure_reported conflicting_flags_refused; do
  run_scenario "$s"
done

echo "derive.sh scenarios: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  echo "scratch kept in $SCRATCH"
  exit 1
fi
rm -rf "$SCRATCH"
