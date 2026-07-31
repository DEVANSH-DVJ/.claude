---
name: format
description: Format code with the project formatter. Use before committing or when asked to format; format only the files you touched. Fine to skip for trivial edits.
user-invocable: true
argument-hint: "[paths...]"
allowed-tools: Bash(format/format.sh *), Bash(./format/format.sh *), Bash(docker/exec.sh *), Bash(./docker/exec.sh *)
---

Format with the project formatter (`format/format.sh`), which skips any formatter not on PATH.

- Specific paths (preferred): `./format/format.sh <paths or globs>` -- format only what you changed.
- Whole tree: `./format/format.sh` (needs a clean tree, or prefix `FORMAT_SKIP_CLEAN_CHECK=1`).
- If the formatters live only in the container, wrap it: `./docker/exec.sh "./format/format.sh <paths>"`.

Formatting rewrites files in place, so run it when you choose -- usually before a commit -- and never while a process is reading those files. It is fine to skip for a trivial edit.
