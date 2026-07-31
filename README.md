# .claude template

A portable Claude Code workflow for R&D repos: agnostic rule docs, deterministic enforcement hooks, judgment skills, and formatter/container tooling.
Canonical source: `github.com/devansh-dvj/.claude`.

## What is in here

```
CLAUDE.md                 thin loader: @-includes the three rule files
.claude/
  session.md              how I work in any session (agnostic)
  engineering.md          code/diff/comment/docs conventions (agnostic)
  project.md              the ONE file you fill in per project
  rules/                  path-scoped rules (per-language), auto-loaded on matching edits
  settings.json           wires the hooks
  workflow.conf           the per-project knob file the hooks read
  hooks/                  deterministic enforcement (git-guard, docker-route, format, comment-lint, stop-gate)
  skills/                 judgment playbooks (review-diff, commit, delegate, comment-style)
format/                   one formatter dispatcher + per-language configs
docker/                   exec wrapper, build, chown, entrypoint, Dockerfile
```

## The model: hooks are the tripwire, skills are the playbook

- **Hooks** (deterministic, host-side) enforce what must always happen: block unsafe git, route toolchain commands through the container, format edited files. All fail open, all honor `WORKFLOW_HOOKS_DISABLE=1`.
- **Skills** (judgment, on-demand) carry the rules a human must apply: review a diff, make a safe commit, delegate to subagents. They surface at the right moment via `paths:` auto-load or explicit invocation.

Only `git-guard` is active by default. `docker-route`, `format-dispatch`, `comment-lint`, and `stop-gate` are dormant until you opt in through `.claude/workflow.conf`.

## Adopting this template

In the target repo, either follow the manual steps or hand them to an agent.

**Agent-driven (recommended):** launch an Opus session in the target repo and ask:
> Set up the Claude Code workflow from `github.com/devansh-dvj/.claude`: copy `.claude/`, `format/`, and `docker/` in; fill `.claude/project.md` and `.claude/workflow.conf` for this repo; then run `.claude/hooks/selftest.sh`.

**Manual:**
1. Copy `.claude/`, `format/`, and `docker/` into the repo root.
2. Fill in `.claude/project.md` (what the project is, vocab, layout, commands, docs map).
3. Edit `.claude/workflow.conf`: set `COMMIT_POLICY`, and opt in to `EXEC_WRAPPER` / `FORMAT_CMD` / `COMMENT_LINT` / `STOP_GATE` as wanted.
4. Edit `docker/config.sh` (`PROJECT_SLUG`) and `docker/Dockerfile` for the project's toolchain.
5. Add per-language rules under `.claude/rules/` if the defaults need extending.
6. Run `.claude/hooks/selftest.sh` and confirm it prints `ok`.

## workflow.conf knobs

| Knob | Default | Effect |
|---|---|---|
| `COMMIT_POLICY` | `ask` | `deny` (never commit) / `ask` (user approves each) / `allow` |
| `SUBAGENT_GIT_WRITE` | `deny` | subagents never run git writes |
| `DENY_INDEX_WIDE_ADD` | `1` | block `git add -A` / `.` |
| `EXEC_WRAPPER` | `` | set to `docker/exec.sh` to route toolchain commands |
| `FORMAT_MODE` / `FORMAT_CMD` | `off` / `` | auto-format edited files |
| `COMMENT_LINT` | `off` | warn on change-log comments |
| `STOP_GATE` | `off` | non-blocking end-of-turn reminder |

House rule carried by these docs: no em-dashes or en-dashes anywhere; use `--` or `---`.
