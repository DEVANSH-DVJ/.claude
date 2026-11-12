#!/bin/bash
# Copy the template's files for some categories into a repo, or check or sync a derived repo.
#   derive.sh [--force] <target-dir> [category...]   copy, then print the commit 1 commands
#   derive.sh --replace <target-dir> [category...]   same, over a clean repo's own template roots
#   derive.sh --check <target-dir> [category...]     one status line per path; exit 1 on drift
#   derive.sh --sync <target-dir> [category...]      copy the template's changes since the last sync, then print the commit commands
#   derive.sh --slug <name> <target-dir>             set the slug, then print the commit 2 commands
# Core is always included; implied categories are added. Copies tracked files only.
# --check and --sync take the named categories, else those the last template commit records.
# settings.json and docker/Dockerfile lose the parts of categories not taken.
set -euo pipefail

TEMPLATE="$(cd "$(dirname "$0")" && pwd)"
CATEGORIES=(core drawio writing slides-pptx paper-latex slides-latex)

# Categories each category pulls in; shfmt needs dashed keys quoted
declare -A IMPLIES=(
  ["slides-pptx"]="drawio writing"
  ["paper-latex"]="drawio writing"
  ["slides-latex"]="paper-latex"
)

# Template-owned paths, as category:path
MANIFEST=(
  # core: rules, hook, judgment skills, formatter, runner
  core:CLAUDE.md
  core:.claude/session.md
  core:.claude/engineering.md
  core:.claude/project.md
  core:.claude/settings.json
  core:.claude/.gitignore
  core:.claude/hooks
  core:.claude/skills/commit
  core:.claude/skills/delegate
  core:.claude/skills/format
  core:.claude/skills/plans
  core:.claude/skills/review-diff
  core:.claude/skills/comment-style
  core:format
  core:docker/build.sh
  core:docker/run.sh
  core:docker/exec.sh
  core:docker/chown.sh
  core:docker/cleanup.sh
  core:docker/Dockerfile
  core:docker/environment.yml
  core:docker/entrypoint.sh
  # drawio: diagram and pdf review skills, fonts
  drawio:.claude/skills/drawio
  drawio:.claude/skills/pdf-addon
  drawio:docker/fonts
  # writing: prose review loop
  writing:.claude/skills/writing
  # slides-pptx: deck skill; keeps the plugin keys in settings.json
  slides-pptx:.claude/skills/pptx-addon
  # paper-latex: paper and talk builds on the host
  paper-latex:.claude/skills/latex
  # slides-latex: beamer talk decks
  slides-latex:.claude/skills/beamer
)

# Dockerfile blocks of each category; a block runs from its marker to the next
declare -A BLOCKS=(
  [core]="base project"
  [drawio]="drawio"
  ["slides-pptx"]="pptx"
)

# Dockerfile marker of the project tail, never compared or synced
PROJECT_MARKER="# ==== project ===="

die() {
  echo "derive.sh: $*" >&2
  exit 1
}

usage() {
  cat <<USAGE
Usage: derive.sh [--force] [--replace] <target-dir> [category...]
       derive.sh --check <target-dir> [category...]
       derive.sh --sync <target-dir> [category...]
       derive.sh --slug <name> <target-dir>
Categories: ${CATEGORIES[*]} (core always; slides-pptx and paper-latex imply drawio and writing; slides-latex implies paper-latex)
USAGE
}

# Print a category and all it pulls in, space-terminated
implied() {
  local c
  printf '%s ' "$1"
  for c in ${IMPLIES[$1]:-}; do
    implied "$c"
  done
}

# Category is a current one
known() {
  [[ " ${CATEGORIES[*]} " == *" $1 "* ]]
}

# Set SELECTED to core, the given categories, and implied ones, in canonical order
resolve() {
  local want=" core " c
  for c in "$@"; do
    known "$c" || die "unknown category: $c (one of: ${CATEGORIES[*]})"
    want+=$(implied "$c")
  done
  SELECTED=()
  for c in "${CATEGORIES[@]}"; do
    if [[ $want == *" $c "* ]]; then
      SELECTED+=("$c")
    fi
  done
}

# SELECTED as the list a template commit records
category_list() {
  local s
  s=$(printf '%s, ' "${SELECTED[@]}")
  printf '%s' "${s%, }"
}

# Set LAST to the target's last template commit subject, matched on subjects alone; empty if none
read_last() {
  LAST=$(git -C "$1" log --format=%s | awk '/^template: (import|sync) .*@[0-9a-f]+$/ && !n++')
}

# Set RECORDED to the list LAST records, SELECTED from the named categories or it; die if none
select_categories() {
  local target=$1 re='^template: (import|sync) (.+) from [^ ]+$' c recorded=()
  local fix="name them: derive.sh --$MODE $target <category>..."
  shift
  RECORDED=
  if [[ $LAST =~ $re ]]; then
    RECORDED=${BASH_REMATCH[2]}
  fi
  if [ $# -eq 0 ] && [ -n "$RECORDED" ]; then
    read -r -a recorded <<<"${RECORDED//,/ }"
    for c in "${recorded[@]}"; do
      known "$c" || die "the last template commit of $target records unknown category $c; $fix"
    done
    set -- "${recorded[@]}"
  fi
  [ $# -gt 0 ] || die "the categories of $target are not recorded; $fix"
  resolve "$@"
}

# Category of an entry is selected
picked() {
  [[ " ${SELECTED[*]} " == *" ${1%%:*} "* ]]
}

# Set PATHS to the manifest paths of the SELECTED categories
select_paths() {
  local e
  PATHS=()
  for e in "${MANIFEST[@]}"; do
    if picked "$e"; then
      PATHS+=("${e#*:}")
    fi
  done
}

# Set FILES to the template-tracked files under one manifest path
tracked() {
  mapfile -t FILES < <(git -C "$TEMPLATE" ls-files -- "$1")
  [ "${#FILES[@]}" -gt 0 ] || die "nothing tracked under $1 in $TEMPLATE"
}

# Copies must equal HEAD, which the commit message names
template_clean() {
  local dirty
  dirty=$(git -C "$TEMPLATE" status --porcelain --untracked-files=no -- "${PATHS[@]}")
  [ -z "$dirty" ] || die "template has uncommitted changes under the selected paths; commit them first"
}

# Set ROOTS to the top-level paths of PATHS; die on target changes there
target_clean() {
  local dirty
  mapfile -t ROOTS < <(printf '%s\n' "${PATHS[@]%%/*}" | awk '!seen[$0]++')
  dirty=$(git -C "$1" status --porcelain -- "${ROOTS[@]}")
  [ -z "$dirty" ] || die "target has uncommitted changes under ${ROOTS[*]}; commit or stash them first:"$'\n'"$dirty"
}

# Set SLUG from the target's image name
read_slug() {
  SLUG=
  if [ -f "$1/docker/build.sh" ]; then
    SLUG=$(sed -n '/^ *IMAGE_NAME="/{s/^ *IMAGE_NAME="\([a-z0-9._-]*\):.*/\1/p;q;}' "$1/docker/build.sh")
  fi
}

# Set BASE to the template commit LAST names; empty means a full sync
read_base() {
  local kind
  BASE=${LAST##*@}
  if [ -z "$BASE" ]; then
    echo "full sync: $1 records no template commit"
    return
  fi
  # a commit the clone lacks prints missing, a git failure dies
  kind=$(git -C "$TEMPLATE" cat-file --batch-check='%(objecttype)' <<<"$BASE^{commit}")
  if [[ $kind != commit ]]; then
    echo "full sync: template commit $BASE is not in $TEMPLATE"
    BASE=
  fi
}

# Set CHANGED to the status of each template file changed since BASE under PATHS
template_diff() {
  local st f
  declare -gA CHANGED=()
  [ -n "$BASE" ] || return 0
  while IFS= read -r -d '' st && IFS= read -r -d '' f; do
    CHANGED[$f]=$st
  done < <(git -C "$TEMPLATE" diff --name-status --no-renames -z "$BASE" HEAD -- "${PATHS[@]}")
  wait $! || die "git diff of $BASE failed in $TEMPLATE"
}

# Print the add and commit commands for a message and paths
print_commit() {
  local msg=$1
  shift
  echo "git add -- $*"
  echo "git commit -m '$msg' -- $*"
}

# Print the empty commit command for a message, limited to paths
print_empty_commit() {
  local msg=$1
  shift
  echo "git commit --allow-empty -m '$msg' -- $*"
}

# Print the Dockerfile without the blocks of categories not SELECTED
dockerfile_blocks() {
  local c keep=" "
  for c in "${SELECTED[@]}"; do
    keep+="${BLOCKS[$c]:-} "
  done
  awk -v keep="$keep" -v all=" ${BLOCKS[*]} " 'BEGIN { on = 1 }
    /^# ==== [a-z]+ ====$/ {
      if (!index(all, " " $3 " ")) { print "derive.sh: no category for Dockerfile block " $3 > "/dev/stderr"; exit 1 }
      on = index(keep, " " $3 " ") > 0
    }
    on' "$TEMPLATE/docker/Dockerfile"
}

# Dockerfile text before the project marker
shared() {
  sed "/^$PROJECT_MARKER\$/,\$d"
}

# Print a path's template content; without slides-pptx, settings.json loses the plugin keys
expected() {
  if [[ $1 == .claude/settings.json && " ${SELECTED[*]} " != *" slides-pptx "* ]]; then
    python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); del d["extraKnownMarketplaces"], d["enabledPlugins"]; json.dump(d, sys.stdout, indent=2); print()' "$TEMPLATE/$1"
  elif [[ $1 == docker/Dockerfile ]]; then
    dockerfile_blocks
  else
    cat "$TEMPLATE/$1"
  fi
}

# Same exec bit
same_mode() {
  [[ -x $1 && -x $2 ]] || [[ ! -x $1 && ! -x $2 ]]
}

# Target file has the expected content and exec bit
same() {
  cmp -s <(expected "$2") "$1/$2" && same_mode "$TEMPLATE/$2" "$1/$2"
}

# CLAUDE.md minus its heading and description lines
claude_body() {
  awk 'NR == 1 { next } !seen && NF { seen = 1; next } { print }' "$1"
}

# Template CLAUDE.md under the target's heading and description lines
claude_merge() {
  awk 'NR == FNR { if (FNR == 1) head = $0; else if (!got && NF) { got = 1; desc = $0 }; next }
    FNR == 1 { print head; next }
    !seen && NF { seen = 1; print desc; next }
    { print }' "$1" "$TEMPLATE/CLAUDE.md"
}

# Project-owned once derived, never compared
owned() {
  case $1 in
    .claude/project.md | docker/environment.yml) return 0 ;;
    *) return 1 ;;
  esac
}

# Equal to the template once the commit 2 placeholders are filled
filled() {
  local t=$TEMPLATE/$2 g=$1/$2
  case $2 in
    CLAUDE.md) cmp -s <(claude_body "$t") <(claude_body "$g") ;;
    docker/*/*) return 1 ;;
    docker/*.sh) [ -n "$SLUG" ] && same_mode "$t" "$g" && cmp -s <(sed "s/myproject/$SLUG/g" "$t") "$g" ;;
    *) return 1 ;;
  esac
}

# Docker script, which carries the slug
slug_script() {
  [[ $1 == docker/*.sh && $1 != docker/*/* ]]
}

# Target file differs from the template's at BASE, the slug filled in
local_change() {
  local f=$2 old
  if owned "$f" || [[ $f == CLAUDE.md || $f == docker/Dockerfile || $f == .claude/settings.json ]]; then
    return 1
  fi
  [ -e "$1/$f" ] || return 1
  # a file added since BASE is a local one
  [[ ${CHANGED[$f]} != A ]] || return 0
  if slug_script "$f"; then
    old=$(git -C "$TEMPLATE" show "$BASE:$f" | sed "s/myproject/$SLUG/g" | git hash-object --stdin)
  else
    old=$(git -C "$TEMPLATE" show "$BASE:$f" | git hash-object --stdin)
  fi || die "cannot read $f at template commit $BASE"
  [ "$old" != "$(git hash-object --stdin <"$1/$f")" ]
}

# Die unless a target Dockerfile has the project marker
marked() {
  grep -qxF "$PROJECT_MARKER" "$1" ||
    die "no '$PROJECT_MARKER' line in $1; add it above the project's own lines first"
}

# Rewrite the target's shared Dockerfile blocks, its project tail byte for byte
sync_dockerfile() {
  local file=$1/docker/Dockerfile tail
  # trailing dot keeps the tail's final newlines
  tail=$(sed -n "/^$PROJECT_MARKER\$/,\$p" "$file" && echo .)
  { expected docker/Dockerfile | shared && printf '%s' "${tail%.}"; } >"$file"
}

# Target file matches where compared; the Dockerfile's project tail never is
matches() {
  if [[ $2 == docker/Dockerfile ]]; then
    marked "$1/$2"
    cmp -s <(expected "$2" | shared) <(shared <"$1/$2")
  else
    same "$1" "$2"
  fi
}

# Set STATUS for one manifest path of the target
status() {
  local target=$1 f hit=0 eq=0 fill=0 dropped
  tracked "$2"
  # target-tracked files the template dropped
  dropped=$(LC_ALL=C comm -23 <(git -C "$target" ls-files -- "$2" | LC_ALL=C sort) <(printf '%s\n' "${FILES[@]}" | LC_ALL=C sort))
  for f in "${FILES[@]}"; do
    if [ -e "$target/$f" ]; then
      hit=$((hit + 1))
      if owned "$f"; then
        fill=$((fill + 1))
      elif matches "$target" "$f"; then
        eq=$((eq + 1))
      elif filled "$target" "$f"; then
        fill=$((fill + 1))
      fi
    fi
  done
  if [ "$hit" -eq 0 ]; then
    STATUS=missing
  elif [ -n "$dropped" ]; then
    STATUS=differs
  elif [ "$eq" -eq "${#FILES[@]}" ]; then
    STATUS=identical
  elif [ $((eq + fill)) -eq "${#FILES[@]}" ]; then
    STATUS=filled
  else
    STATUS=differs
  fi
}

# Die unless each copied hook passes a Bash call and blocks an edit it guards
hook_check() {
  local pair hook path file err rc
  for pair in protect.py:.claude/session.md scratch.py:/tmp/derive-check; do
    hook=$1/.claude/hooks/${pair%%:*} path=${pair#*:} rc=0
    err=$(python3 "$hook" 2>&1 >/dev/null <<<"{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"true\"},\"cwd\":\"$1\"}") || rc=$?
    [ "$rc" -eq 0 ] || die "$hook exits $rc on a Bash call, not 0:"$'\n'"$err"
    [ -e "$1/.claude/.unlock" ] && continue
    # a relative path is in the target
    [[ $path == /* ]] && file=$path || file=$1/$path
    err=$(python3 "$hook" 2>&1 >/dev/null <<<"{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$file\"},\"cwd\":\"$1\"}") || rc=$?
    [ "$rc" -eq 2 ] || die "$hook exits $rc on an edit of $path, not 2:"$'\n'"$err"
  done
}

# Add work/ to the target's .git/info/exclude unless already ignored; set EXCLUDED
exclude_scratch() {
  local file
  EXCLUDED=0
  if git -C "$1" check-ignore -q work/x; then
    return 0
  fi
  file=$(git -C "$1" rev-parse --path-format=absolute --git-path info/exclude)
  mkdir -p "$(dirname "$file")"
  # end the last line first
  if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then
    echo >>"$file"
  fi
  echo 'work/' >>"$file"
  EXCLUDED=1
}

# Copy the selected categories, then print the commit 1 commands
derive() {
  local target=$1 p f sha cats files=() conflicts=()
  shift
  resolve "$@"
  select_paths
  for p in "${PATHS[@]}"; do
    tracked "$p"
    files+=("${FILES[@]}")
  done
  template_clean

  # replace: drop the target's tracked files under the roots
  if [ "$REPLACE" -eq 1 ]; then
    target_clean "$target"
    git -C "$target" rm -r -q --ignore-unmatch -- "${ROOTS[@]}"
  fi

  # refuse to overwrite a differing file unless forced
  for f in "${files[@]}"; do
    if [ -e "$target/$f" ] && ! same "$target" "$f"; then
      conflicts+=("$f")
    fi
  done
  if [ "${#conflicts[@]}" -gt 0 ] && [ "$FORCE" -eq 0 ]; then
    printf 'differs: %s\n' "${conflicts[@]}" >&2
    die "${#conflicts[@]} existing file(s) differ from the template; rerun with --force to overwrite"
  fi

  exclude_scratch "$target"
  (cd "$TEMPLATE" && rsync -a --relative "${files[@]}" "$target/")
  expected .claude/settings.json >"$target/.claude/settings.json"
  expected docker/Dockerfile >"$target/docker/Dockerfile"
  hook_check "$target"

  # replace: commit 1 stages the roots whole, removals included
  if [ "$REPLACE" -eq 1 ]; then
    PATHS=("${ROOTS[@]}")
  fi
  sha=$(git -C "$TEMPLATE" rev-parse --short HEAD)
  cats=$(category_list)
  if [ "$EXCLUDED" -eq 1 ]; then
    echo "exclude work/"
  fi
  echo "copied ${#files[@]} files ($cats) into $target"
  echo "commit 1, run from $target:"
  print_commit "template: import $cats from devansh-dvj/.claude@$sha" "${PATHS[@]}"
}

# Copy the template's changes since BASE into a derived target; every path without a BASE
sync_target() {
  local target=$1 e p f sha cats msg merged files=() gone=() line n=0
  local -A drift=()
  shift
  read_last "$target"
  select_categories "$target" "$@"
  read_slug "$target"
  [[ -n $SLUG && $SLUG != myproject ]] ||
    die "no slug in $target/docker/build.sh: want IMAGE_NAME=\"<slug>:...\" with the placeholder filled"
  select_paths
  template_clean
  target_clean "$target"
  # the Dockerfile merge needs the project marker
  if [ -e "$target/docker/Dockerfile" ]; then
    marked "$target/docker/Dockerfile"
  fi
  exclude_scratch "$target"
  read_base "$target"
  template_diff

  # note local changes before any overwrite; remove what the template dropped
  for f in "${!CHANGED[@]}"; do
    if local_change "$target" "$f"; then
      drift[$f]=1
    fi
    if [[ ${CHANGED[$f]} == D ]]; then
      git -C "$target" rm -q --ignore-unmatch -- "$f"
    fi
  done
  # keep owned paths, merge CLAUDE.md and Dockerfile, copy the rest
  for p in "${PATHS[@]}"; do
    tracked "$p"
    if [ -e "$target/$p" ] && { owned "$p" || [[ $p == CLAUDE.md || $p == docker/Dockerfile ]]; }; then
      continue
    fi
    # without a BASE or the path, every file is copied
    if [ -z "$BASE" ] || [ ! -e "$target/$p" ]; then
      git -C "$target" rm -r -q --ignore-unmatch -- "$p"
      files+=("${FILES[@]}")
      continue
    fi
    for f in "${FILES[@]}"; do
      if [ -n "${CHANGED[$f]:-}" ]; then
        files+=("$f")
      fi
    done
  done
  # paths of categories not taken are removed
  for e in "${MANIFEST[@]}"; do
    if ! picked "$e" && [ -e "$target/${e#*:}" ]; then
      git -C "$target" rm -r -q --ignore-unmatch -- "${e#*:}"
      gone+=("${e#*:}")
    fi
  done
  if [ -e "$target/CLAUDE.md" ] && { [ -z "$BASE" ] || [ -n "${CHANGED[CLAUDE.md]:-}" ]; }; then
    # trailing dot keeps the final newlines
    merged=$(claude_merge "$target/CLAUDE.md" && echo .)
    printf '%s' "${merged%.}" >"$target/CLAUDE.md"
  fi

  if [ -e "$target/docker/Dockerfile" ]; then
    sync_dockerfile "$target"
  fi

  if [ "${#files[@]}" -gt 0 ]; then
    (cd "$TEMPLATE" && rsync -a --relative "${files[@]}" "$target/")
  fi
  expected .claude/settings.json >"$target/.claude/settings.json"
  if [[ " ${files[*]} " == *" docker/Dockerfile "* ]]; then
    expected docker/Dockerfile >"$target/docker/Dockerfile"
  fi
  # the slug goes into the copied docker scripts
  for f in "${files[@]}"; do
    if slug_script "$f"; then
      sed -i "s/myproject/$SLUG/g" "$target/$f"
    fi
  done

  # index back to HEAD; every change under the roots is the sync's own
  git -C "$target" reset -q -- "${ROOTS[@]}"
  echo "categories: ${SELECTED[*]}"
  echo "slug: $SLUG"
  if [ "${#gone[@]}" -gt 0 ]; then
    printf 'remove %s\n' "${gone[@]}"
  fi
  while IFS= read -r -d '' line; do
    n=$((n + 1))
    f=${line:3}
    # files of removed paths are listed by their path
    for p in "${gone[@]}"; do
      if [[ $f == "$p" || $f == "$p"/* ]]; then
        continue 2
      fi
    done
    if [ -n "${drift[$f]:-}" ]; then
      echo "local  $f"
    fi
    if [[ ${line:0:2} == " D" ]]; then
      echo "remove $f"
    else
      echo "copy   $f"
    fi
  done < <(git -C "$target" status --porcelain -z --untracked-files=all -- "${ROOTS[@]}")
  wait $! || die "git status failed in $target"
  if [ "$EXCLUDED" -eq 1 ]; then
    echo "exclude work/"
  fi
  # up to date unless named categories differ from the recorded ones
  cats=$(category_list)
  if [ "$n" -eq 0 ] && { [ $# -eq 0 ] || [[ $cats == "$RECORDED" ]]; }; then
    echo "$target is up to date with the template"
    return
  fi
  hook_check "$target"
  sha=$(git -C "$TEMPLATE" rev-parse --short HEAD)
  msg="template: sync $cats from devansh-dvj/.claude@$sha"
  # nothing to copy: an empty commit records the categories
  if [ "$n" -eq 0 ]; then
    echo "nothing to copy into $target; the commit records its categories"
    echo "commit, run from $target:"
    print_empty_commit "$msg" "${ROOTS[@]}"
    return
  fi
  echo "synced $n changed file(s) into $target"
  echo "commit, run from $target:"
  print_commit "$msg" "${ROOTS[@]}"
}

# Put the slug into the target's docker scripts, then print the commit 2 commands
fill_slug() {
  local target=$1 name=$2
  [[ $name =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "slug must be lowercase letters, digits, dots, dashes, underscores: $name"
  grep -q myproject "$target"/docker/*.sh || die "no myproject placeholder left to replace in $target/docker/*.sh"
  sed -i "s/myproject/$name/g" "$target"/docker/*.sh
  echo "set the slug $name in $target/docker/*.sh"
  echo "commit 2, run from $target once .claude/project.md and the CLAUDE.md heading and description line are filled:"
  print_commit "$name: fill the template placeholders" 'docker/*.sh' .claude/project.md CLAUDE.md
}

# Print a status line per template-owned path in the target; return 1 on drift
check() {
  local target=$1 e p drift=0
  shift
  read_last "$target"
  select_categories "$target" "$@"
  read_slug "$target"
  select_paths
  # a template the comparisons cannot read dies here, not as differs
  expected .claude/settings.json >/dev/null
  expected docker/Dockerfile >/dev/null
  echo "categories: ${SELECTED[*]}"
  echo "slug: ${SLUG:-unknown}"

  # paths of other categories are only reported, as extra
  for e in "${MANIFEST[@]}"; do
    p=${e#*:}
    if picked "$e"; then
      status "$target" "$p"
    elif [ -e "$target/$p" ]; then
      STATUS=extra
    else
      continue
    fi
    printf '%-9s %s\n' "$STATUS" "$p"
    if [[ $STATUS == differs || $STATUS == missing ]]; then
      drift=1
    fi
  done
  return "$drift"
}

# Parse flags anywhere; the rest are positional
FORCE=0
REPLACE=0
MODE=derive
NAME=
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=1 ;;
    --replace) REPLACE=1 ;;
    --check | --sync | --slug)
      [ "$MODE" = derive ] || die "one mode flag at most, got --$MODE and $1"
      MODE=${1#--}
      if [ "$MODE" = slug ]; then
        [ -n "${2:-}" ] || die "--slug takes a name"
        NAME=$2
        shift
      fi
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*) die "unknown flag: $1" ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done
[ "$MODE" = derive ] || [ $((FORCE + REPLACE)) -eq 0 ] || die "--force and --replace go with an import only, not --$MODE"
[ "${#ARGS[@]}" -ge 1 ] || {
  usage >&2
  exit 1
}
[ -d "${ARGS[0]}" ] || die "no such directory: ${ARGS[0]}"
TARGET=$(cd "${ARGS[0]}" && pwd)
[ "$MODE" != slug ] || [ "${#ARGS[@]}" -eq 1 ] || die "--slug takes one target dir"

case $MODE in
  check) check "$TARGET" "${ARGS[@]:1}" ;;
  sync) sync_target "$TARGET" "${ARGS[@]:1}" ;;
  slug) fill_slug "$TARGET" "$NAME" ;;
  derive) derive "$TARGET" "${ARGS[@]:1}" ;;
esac
