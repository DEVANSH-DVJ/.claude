# .claude template

A portable Claude Code workflow for R&D repos: agnostic rule docs, judgment skills, and formatter/container tooling.
Canonical source: `github.com/devansh-dvj/.claude`.

## What is in here

```
CLAUDE.md                 thin loader: @-includes the three rule files
.claude/
  session.md              how I work in any session (agnostic)
  engineering.md          code/diff/comment/docs conventions (agnostic)
  project.md              the ONE file you fill in per project
  skills/                 review-diff, commit, delegate, format, comment-style
format/                   one formatter dispatcher + per-language configs
docker/                   exec wrapper, build, chown, entrypoint, Dockerfile
```

## No hooks, by choice

Enforcement is through rules the agent applies with judgment (the `.claude/*.md` docs) and skills you invoke, not blocking hooks.
We tried deterministic hooks (format-on-edit, docker-routing, a commit guard) and dropped them.
A research workflow has too many legitimate exceptions: running a toolchain on the host, skipping a trivial format, rebasing to consolidate history.
Commit permission is per-session (your in-conversation grant, not a repo flag), so a repo-level commit gate either nags the session you authorized or blocks it.
And a hook that mutates files or blocks commands gets in the way more than it helps.
Commit hygiene (pathspec commits, no identity override, no `Co-Authored-By`) lives in `session.md` and the `/commit` skill.

## Skills

| Skill | What it does |
|---|---|
| `/review-diff` | review the working diff against this project's own rule files |
| `/commit` | guided, pathspec-safe commit |
| `/format` | format files, folders, or globs with the project formatter |
| `/delegate` | subagent orchestration playbook |
| `comment-style` | terse-comment doctrine, auto-loads when editing source files |

## Adopting this template

In the target repo, either follow the manual steps or hand them to an agent.

**Agent-driven (recommended):** launch an Opus session in the target repo and ask:
> Set up the Claude Code workflow from `github.com/devansh-dvj/.claude`: copy `.claude/`, `format/`, and `docker/` in; fill `.claude/project.md` for this repo; then edit `docker/config.sh` and `docker/Dockerfile` for the toolchain.

**Manual:**
1. Copy `.claude/`, `format/`, and `docker/` into the repo root.
2. Fill in `.claude/project.md` (what the project is, vocab, layout, commands, docs map).
3. Edit `docker/config.sh` (`PROJECT_SLUG`) and `docker/Dockerfile` for the project's toolchain.
4. Use the skills: `/format` before commits, `/review-diff` before finishing, `/commit` to commit.

## House rules carried by these docs

- One sentence per line, no character limit, in markdown (README and docs) and LaTeX.
- No em-dashes or en-dashes anywhere; use `--` or `---`.
- Say "upstream" or "external", never "vendor".
