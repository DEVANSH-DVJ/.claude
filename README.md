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
  settings.json           registers the anthropic-agent-skills marketplace and enables its document-skills plugin
  skills/                 review-diff, commit, delegate, format, comment-style, pptx-addon, pdf-addon, drawio
format/                   one formatter dispatcher + per-language configs
docker/                   build, run, cleanup, exec, chown, entrypoint scripts + Dockerfile.amd64 + environment.yml
```

## Enforcement: rules and skills, not hooks

This template ships no hooks. Enforcement is the `.claude/*.md` rules the agent follows and the skills you invoke.
Commit hygiene (pathspec commits, no identity override, no `Co-Authored-By`) lives in `session.md` and the `/commit` skill.
Formatting is the `/format` skill; running the toolchain through the container wrapper is a preference in `engineering.md`.

## Skills

| Skill           | What it does                                                                                                      |
| --------------- | ----------------------------------------------------------------------------------------------------------------- |
| `/review-diff`  | review the working diff against this project's own rule files                                                     |
| `/commit`       | guided, pathspec-safe commit                                                                                      |
| `/format`       | format files, folders, or globs with the project formatter                                                        |
| `/delegate`     | subagent orchestration playbook                                                                                   |
| `comment-style` | terse-comment doctrine, auto-loads when editing source files                                                      |
| `pptx-addon`    | slide decks: render, edit only the requested slides, prove the rest unchanged; image requirements in its SKILL.md |
| `pdf-addon`     | PDF review: render pages with a contact sheet, diff two versions page by page by text and pixels                  |
| `drawio`        | native `.drawio` diagrams; export needs the draw.io desktop CLI                                                   |

Claude Code loads a personal `~/.claude/skills/<name>` over a project skill of the same name, so keep no personal copies of these.
Anthropic's document skills (`/document-skills:pptx` and friends) are source-available, not open source, so they are not copied here; `settings.json` installs them as a plugin on each machine instead.

## Adopting this template

In the target repo, either follow the manual steps or hand them to an agent.

**Agent-driven (recommended):** launch an Opus session in the target repo and ask:

> Set up the Claude Code workflow from `github.com/devansh-dvj/.claude`: copy `.claude/`, `format/`, and `docker/` in; fill `.claude/project.md` for this repo; set the project name in the docker scripts (`sed -i 's/myproject/<slug>/g' docker/*.sh`); then edit `docker/Dockerfile.amd64` for the toolchain.

**Manual:**

1. Copy `.claude/`, `format/`, and `docker/` into the repo root.
2. Fill in `.claude/project.md` (what the project is, vocab, layout, commands, docs map).
3. Set the project name in the docker scripts: `sed -i 's/myproject/<your-slug>/g' docker/*.sh`. Then edit `docker/Dockerfile.amd64` for the toolchain.
4. Use the skills: `/format` before commits, `/review-diff` before finishing, `/commit` to commit.
