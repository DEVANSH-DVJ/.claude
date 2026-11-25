---
name: format
description: Format code with the project formatter. Use before committing or when asked to format; format only the files you touched.
user-invocable: true
argument-hint: "[paths...]"
allowed-tools: Bash(format/format.sh *), Bash(./format/format.sh *), Bash(docker/exec.sh *), Bash(./docker/exec.sh *)
---

Format with the project formatter (`format/format.sh`), which skips any formatter not on PATH.

Run each command below from the repo root, with paths relative to it: the container mounts the repo at `/workspace`, so a host absolute path does not exist there.

- Specific paths (preferred): `./docker/exec.sh "./format/format.sh <paths or globs>"` -- format only what you changed.
- Whole tree: `./docker/exec.sh "./format/format.sh"`.
  It refuses while any unstaged or untracked change exists, unless run as `./docker/exec.sh "FORMAT_SKIP_CLEAN_CHECK=1 ./format/format.sh"`.
- Run it on the host only where `project.md` says the host has the formatters.

Formatting rewrites files in place, so run it before a commit and never while a process is reading those files.
