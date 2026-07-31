#!/usr/bin/env bash
# Format source files. Silently skips any formatter not on PATH.
# Whole tree:   ./format/format.sh
# Single file:  ./format/format.sh --file <path>   (used by the format-dispatch hook)
set -euo pipefail

FORMAT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLANGFMT="${CLANGFMT:-clang-format}"
has() { command -v "$1" >/dev/null 2>&1; }

# Single-file mode: dispatch by extension, no clean-tree guard.
if [ "${1:-}" = "--file" ]; then
  f="${2:?usage: format.sh --file <path>}"
  case "${f##*.}" in
    rs) has rustfmt && rustfmt --config-path "$FORMAT_DIR" --config skip_children=true "$f" ;;
    py) has ruff && ruff format -q --config "$FORMAT_DIR/pyproject.toml" "$f" ;;
    sh) has shfmt && shfmt -w -i 2 -ci "$f" ;;
    cc | cpp | h | hpp) has "$CLANGFMT" && "$CLANGFMT" --style="file:$FORMAT_DIR/.clang-format" -i "$f" ;;
    md | json | yaml | yml | js | ts) has prettier && prettier --write --log-level warn --config "$FORMAT_DIR/.prettierrc.json" "$f" ;;
  esac
  exit 0
fi

REPO_ROOT="$(cd "$FORMAT_DIR/.." && pwd)"
cd "$REPO_ROOT"

if [ -z "${FORMAT_SKIP_CLEAN_CHECK:-}" ]; then
  unstaged="$(git status --porcelain | grep '^.[^ ]' || true)"
  if [ -n "$unstaged" ]; then
    echo "${0##*/}: unstaged changes present (stage or stash first, or set FORMAT_SKIP_CLEAN_CHECK=1):" >&2
    echo "$unstaged" >&2
    exit 1
  fi
fi

# Paths every tree walk skips: VCS, build output, caches, deps, logs.
PRUNE=(! -path "./.git/*" ! -path "*/target/*" ! -path "./.cache/*" ! -path "*/node_modules/*" ! -path "./log*")

if has rustfmt; then
  echo "[format] rust"
  find . -name "*.rs" "${PRUNE[@]}" -print0 |
    xargs -0 -r rustfmt --config-path "$FORMAT_DIR" --config skip_children=true
fi
if has ruff; then
  echo "[format] python"
  find . -name "*.py" "${PRUNE[@]}" -print0 |
    xargs -0 -r ruff format -q --config "$FORMAT_DIR/pyproject.toml"
fi
if has shfmt; then
  echo "[format] bash"
  find . -name "*.sh" "${PRUNE[@]}" -print0 | xargs -0 -r shfmt -w -i 2 -ci
fi
if has prettier; then
  echo "[format] markdown/web"
  find . \( -name "*.md" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" \) "${PRUNE[@]}" -print0 |
    xargs -0 -r prettier --write --log-level warn --config "$FORMAT_DIR/.prettierrc.json"
fi
if has "$CLANGFMT"; then
  mapfile -t cpp_files < <(find . \( -name "*.cpp" -o -name "*.cc" -o -name "*.h" -o -name "*.hpp" \) "${PRUNE[@]}")
  if [ "${#cpp_files[@]}" -gt 0 ]; then
    echo "[format] c++"
    "$CLANGFMT" --style="file:$FORMAT_DIR/.clang-format" -i "${cpp_files[@]}"
  fi
fi
