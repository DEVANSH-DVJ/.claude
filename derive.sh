#!/bin/bash
# Copy the template's files for some categories into a repo, or check or sync a derived repo.
#   derive.sh [--force] <target-dir> [category...]   copy, then print the commit 1 commands
#   derive.sh --replace <target-dir> [category...]   same, over a clean repo's own template roots
#   derive.sh --check <target-dir>                   one status line per path; exit 1 on drift
#   derive.sh --sync <target-dir>                    mirror the template, then print the commit commands
#   derive.sh --slug <name> <target-dir>             set the slug, then print the commit 2 commands
# Core is always included; implied categories are added. Copies tracked files only.
# settings.json and docker/Dockerfile lose the parts of categories not taken.
set -euo pipefail

TEMPLATE="$(cd "$(dirname "$0")" && pwd)"
CATEGORIES=(core drawio writing slides latex)

# Categories each category pulls in
declare -A IMPLIES=(
  [slides]="drawio writing"
  [latex]="drawio writing"
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
  # slides: deck skill; keeps the plugin keys in settings.json
  slides:.claude/skills/pptx-addon
  # latex: paper and talk builds on the host
  latex:.claude/skills/latex
)

# Category of each Dockerfile block; a block runs from its marker to the next
declare -A BLOCKS=(
  [base]=core
  [drawio]=drawio
  [slides]=slides
  [project]=core
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
       derive.sh --check <target-dir>
       derive.sh --sync <target-dir>
       derive.sh --slug <name> <target-dir>
Categories: ${CATEGORIES[*]} (core always; slides and latex imply drawio and writing)
USAGE
}

# Set SELECTED to core, the given categories, and implied ones, in canonical order
resolve() {
  local want=" core " c
  for c in "$@"; do
    [[ " ${CATEGORIES[*]} " == *" $c "* ]] || die "unknown category: $c (one of: ${CATEGORIES[*]})"
    want+="$c ${IMPLIES[$c]:-} "
  done
  SELECTED=()
  for c in "${CATEGORIES[@]}"; do
    if [[ $want == *" $c "* ]]; then
      SELECTED+=("$c")
    fi
  done
}

# Set SELECTED from the target's skills, core always
infer() {
  local e p found=()
  for e in "${MANIFEST[@]}"; do
    p=${e#*:}
    if [[ $p == .claude/skills/* && -e $1/$p ]]; then
      found+=("${e%%:*}")
    fi
  done
  resolve "${found[@]}"
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
  [ -z "$(git -C "$TEMPLATE" status --porcelain --untracked-files=no -- "${PATHS[@]}")" ] ||
    die "template has uncommitted changes under the selected paths; commit them first"
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

# Print the add and commit commands for a message and paths
print_commit() {
  local msg=$1
  shift
  echo "git add -- $*"
  echo "git commit -m '$msg' -- $*"
}

# Print the Dockerfile without the blocks of categories not SELECTED
dockerfile_blocks() {
  local b keep=" "
  for b in "${!BLOCKS[@]}"; do
    if picked "${BLOCKS[$b]}"; then
      keep+="$b "
    fi
  done
  awk -v keep="$keep" -v all=" ${!BLOCKS[*]} " 'BEGIN { on = 1 }
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

# Print a path's template content; without slides, settings.json loses the plugin keys
expected() {
  if [[ $1 == .claude/settings.json && " ${SELECTED[*]} " != *" slides "* ]]; then
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
    grep -qxF "$PROJECT_MARKER" "$1/$2" && cmp -s <(expected "$2" | shared) <(shared <"$1/$2")
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

  (cd "$TEMPLATE" && rsync -a --relative "${files[@]}" "$target/")
  expected .claude/settings.json >"$target/.claude/settings.json"
  expected docker/Dockerfile >"$target/docker/Dockerfile"

  # replace: commit 1 stages the roots whole, removals included
  if [ "$REPLACE" -eq 1 ]; then
    PATHS=("${ROOTS[@]}")
  fi
  sha=$(git -C "$TEMPLATE" rev-parse --short HEAD)
  cats=$(printf '%s, ' "${SELECTED[@]}")
  cats=${cats%, }
  echo "copied ${#files[@]} files ($cats) into $target"
  echo "commit 1, run from $target:"
  print_commit "template: import $cats from devansh-dvj/.claude@$sha" "${PATHS[@]}"
}

# Mirror the template into a derived target, keeping its project-owned parts
sync_target() {
  local target=$1 e p f sha merged files=() gone=() line n=0
  infer "$target"
  read_slug "$target"
  select_paths
  template_clean
  target_clean "$target"
  # the Dockerfile merge needs the project marker
  if [ -e "$target/docker/Dockerfile" ]; then
    grep -qxF "$PROJECT_MARKER" "$target/docker/Dockerfile" ||
      die "no '$PROJECT_MARKER' line in $target/docker/Dockerfile; add it above the project's own lines first"
  fi

  # keep owned paths, merge CLAUDE.md and Dockerfile, mirror the rest
  for p in "${PATHS[@]}"; do
    tracked "$p"
    if [ -e "$target/$p" ] && { owned "$p" || [[ $p == CLAUDE.md || $p == docker/Dockerfile ]]; }; then
      continue
    fi
    git -C "$target" rm -r -q --ignore-unmatch -- "$p"
    files+=("${FILES[@]}")
  done
  # paths of categories not taken are removed
  for e in "${MANIFEST[@]}"; do
    if ! picked "$e" && [ -e "$target/${e#*:}" ]; then
      git -C "$target" rm -r -q --ignore-unmatch -- "${e#*:}"
      gone+=("${e#*:}")
    fi
  done
  if [ -e "$target/CLAUDE.md" ]; then
    # trailing dot keeps the final newlines
    merged=$(claude_merge "$target/CLAUDE.md" && echo .)
    printf '%s' "${merged%.}" >"$target/CLAUDE.md"
  fi

  if [ -e "$target/docker/Dockerfile" ]; then
    sync_dockerfile "$target"
  fi

  (cd "$TEMPLATE" && rsync -a --relative "${files[@]}" "$target/")
  expected .claude/settings.json >"$target/.claude/settings.json"
  if [[ " ${files[*]} " == *" docker/Dockerfile "* ]]; then
    expected docker/Dockerfile >"$target/docker/Dockerfile"
  fi
  if [ -n "$SLUG" ]; then
    sed -i "s/myproject/$SLUG/g" "$target"/docker/*.sh
  fi

  # index back to HEAD; every change under the roots is the sync's own
  git -C "$target" reset -q -- "${ROOTS[@]}"
  echo "categories: ${SELECTED[*]}"
  echo "slug: ${SLUG:-unknown}"
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
    if [[ ${line:0:2} == " D" ]]; then
      echo "remove $f"
    else
      echo "copy   $f"
    fi
  done < <(git -C "$target" status --porcelain -z --untracked-files=all -- "${ROOTS[@]}")
  if [ "$n" -eq 0 ]; then
    echo "$target already matches the template"
    return
  fi
  sha=$(git -C "$TEMPLATE" rev-parse --short HEAD)
  echo "synced $n changed file(s) into $target"
  echo "commit, run from $target:"
  print_commit "template: sync from devansh-dvj/.claude@$sha" "${ROOTS[@]}"
}

# Put the slug into the target's docker scripts, then print the commit 2 commands
fill_slug() {
  local target=$1 name=$2
  [[ $name =~ ^[a-z0-9][a-z0-9._-]*$ ]] || die "slug must be lowercase letters, digits, dots, dashes, underscores: $name"
  sed -i "s/myproject/$name/g" "$target"/docker/*.sh
  echo "set the slug $name in $target/docker/*.sh"
  echo "commit 2, run from $target once .claude/project.md and the CLAUDE.md heading and description line are filled:"
  print_commit "$name: fill the template placeholders" 'docker/*.sh' .claude/project.md CLAUDE.md
}

# Print a status line per template-owned path in the target; return 1 on drift
check() {
  local target=$1 e p drift=0
  infer "$target"
  read_slug "$target"
  select_paths
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
    --check) MODE=check ;;
    --sync) MODE=sync ;;
    --slug)
      [ -n "${2:-}" ] || die "--slug takes a name"
      MODE=slug
      NAME=$2
      shift
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
[ "${#ARGS[@]}" -ge 1 ] || {
  usage >&2
  exit 1
}
[ -d "${ARGS[0]}" ] || die "no such directory: ${ARGS[0]}"
TARGET=$(cd "${ARGS[0]}" && pwd)
[ "$MODE" = derive ] || [ "${#ARGS[@]}" -eq 1 ] || die "--$MODE takes one target dir"

case $MODE in
  check) check "$TARGET" ;;
  sync) sync_target "$TARGET" ;;
  slug) fill_slug "$TARGET" "$NAME" ;;
  derive) derive "$TARGET" "${ARGS[@]:1}" ;;
esac
