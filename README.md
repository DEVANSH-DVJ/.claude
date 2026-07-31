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

## Enforcement: rules and skills, not hooks

This template ships no hooks. Enforcement is the `.claude/*.md` rules the agent follows and the skills you invoke.
Commit hygiene (pathspec commits, no identity override, no `Co-Authored-By`) lives in `session.md` and the `/commit` skill.
Formatting is the `/format` skill; running the toolchain through the container wrapper is a preference in `engineering.md`.

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
