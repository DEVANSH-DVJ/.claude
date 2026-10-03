# .claude template

A portable Claude Code workflow for R&D repos: agnostic rule docs, judgment skills, and formatter/container tooling.
Canonical source: `github.com/devansh-dvj/.claude`.

## What is in here

```
CLAUDE.md                 thin loader: @-includes the three rule files
derive.sh                 copies categories into a repo, checks or syncs a derived repo; stays here, never copied
.claude/
  session.md              how I work in any session (agnostic)
  engineering.md          code/diff/comment/docs conventions (agnostic)
  project.md              the ONE file you fill in per project
  settings.json           registers the anthropic-agent-skills marketplace, enables its document-skills plugin, wires the protect hook
  .gitignore              keeps .unlock and settings.local.json out of git
  hooks/protect.py        blocks edits to template-owned files (see Enforcement)
  skills/                 review-diff, commit, delegate, format, comment-style, drawio, pdf-addon, writing, pptx-addon, latex
format/                   format.sh dispatcher + per-language configs
docker/
  build.sh                builds the image from Dockerfile in one docker build
  run.sh                  interactive shell in an ephemeral or --persistent container
  exec.sh                 one command in a throwaway container: ./docker/exec.sh "<cmd>"
  chown.sh                hands the repo's files back to the host user
  cleanup.sh              removes, on confirmation, each container of the project image
  Dockerfile              the image, in marked blocks: base, drawio, slides, then the project's own
  environment.yml         the conda env the project image installs
  entrypoint.sh           the image's interactive entrypoint
  fonts/                  licensed fonts for the drawio block
```

## Categories

A repo takes core plus the categories its work needs, and each category brings the ones it implies.

| Category | Adds                                                                                                                                                                                                                                                                               | Implies         |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- |
| core     | `CLAUDE.md`; `.claude/` rule files, `settings.json`, `.gitignore`, `hooks/`; skills `commit`, `delegate`, `format`, `review-diff`, `comment-style`; `format/`; the `docker/` scripts, `entrypoint.sh`, `environment.yml`; `docker/Dockerfile` with its `base` and `project` blocks | always taken    |
| drawio   | skills `drawio`, `pdf-addon`; `docker/fonts/`; the Dockerfile's `drawio` block                                                                                                                                                                                                     | --              |
| writing  | skill `writing`                                                                                                                                                                                                                                                                    | --              |
| slides   | skill `pptx-addon`; the Dockerfile's `slides` block                                                                                                                                                                                                                                | drawio, writing |
| latex    | skill `latex`                                                                                                                                                                                                                                                                      | drawio, writing |

LaTeX builds run on the host; in a latex repo the image is for diagram export and PDF review.
A repo without slides gets `settings.json` with the document-skills plugin keys removed, and every repo gets `docker/Dockerfile` without the blocks of categories it did not take.
The exact path list per category is the `MANIFEST` array in `derive.sh`.

## Images

`docker/Dockerfile` is one buildable file for all categories, split by marker lines into blocks: `# ==== base ====`, `# ==== drawio ====`, `# ==== slides ====`, and `# ==== project ====`.
A block runs from its marker to the next; `derive.sh` copies the file without the blocks of categories a repo did not take, so a repo has one Dockerfile and one image.
Everything from the `# ==== project ====` line on is the project tail: the conda env from `environment.yml`, then the repo's own toolchain below the `# ---- project toolchain` comment, then the workspace and entrypoint.
The blocks above the tail are shared and never edited in a repo; `--check` compares them, and `--sync` rewrites them from the template while keeping the tail byte for byte.
`docker/build.sh` builds the file in one `docker build` with `docker/` as the context, as `<slug>:latest-<arch>` for the host's amd64 or arm64, passing `BASE_OS` as the `OS` build argument.
Repos with identical leading blocks share layers through the build cache; no image is shared across repos.

## Enforcement: rules, skills, and one hook

Enforcement is the `.claude/*.md` rules the agent follows, the skills you invoke, and one PreToolUse hook.
`.claude/hooks/protect.py` blocks any edit under `.claude/` other than `project.md` and `settings.local.json`, and any edit to a `.gitignore` or `LICENSE` file, so shared files change only in this repo and reach other repos by sync.
A hand-made, gitignored `.claude/.unlock` file lifts the block; keep one in this repo only.
`derive.sh --check <repo>` infers a repo's categories from its skills, prints one status line per template path, and exits 1 on `differs` or `missing`:

- `identical`: equal to the template, exec bit included; `docker/Dockerfile` is compared by its shared blocks alone, never its project tail.
- `filled`: differs only where project-owned: `CLAUDE.md`'s heading and description line, the slug in `docker/*.sh`, and `.claude/project.md` and `docker/environment.yml`, which are never compared.
- `differs`: any other difference, including a shared block of `docker/Dockerfile` that differs, is missing, or is extra; that file is never `filled`.
- `missing`: absent from the repo.
- `extra`: a path of a category the repo did not take.

Commit hygiene (pathspec commits, no identity override, no `Co-Authored-By`) lives in `session.md` and the `/commit` skill.
Formatting is the `/format` skill; running the toolchain through the container wrapper is a rule in `engineering.md`.

## Skills

| Skill           | Category | What it does                                                                                                                                                             |
| --------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `/review-diff`  | core     | review the working diff against this project's own rule files; reports, changes nothing                                                                                  |
| `/commit`       | core     | guided, pathspec-safe commit                                                                                                                                             |
| `/format`       | core     | format files, folders, or globs with the project formatter                                                                                                               |
| `/delegate`     | core     | subagent orchestration playbook                                                                                                                                          |
| `comment-style` | core     | terse-comment doctrine, auto-loads when editing source files                                                                                                             |
| `drawio`        | drawio   | native `.drawio` diagrams; the image exports them headlessly through `.claude/skills/drawio/scripts/export.sh`                                                           |
| `pdf-addon`     | drawio   | PDF review: render pages with a contact sheet, diff two versions page by page by text and pixels                                                                         |
| `/writing`      | writing  | prose deliverables (paper, slides, poster, notes, docs) one unit at a time: plan, draft, two-reader voice review, fidelity check, adjudication, second round, final read |
| `pptx-addon`    | slides   | slide decks: render, edit only the requested slides, prove the rest unchanged; image requirements in its SKILL.md                                                        |
| `/latex`        | latex    | LaTeX papers and beamer talks: host `latexmk` builds, log and font checks, page renders with a page-count gate, `latexdiff` against the submission, draw.io figures      |

Day to day: `/format` before commits, `/review-diff` before finishing, `/commit` to commit.
Claude Code loads a personal `~/.claude/skills/<name>` over a project skill of the same name, so keep no personal copies of these.
Anthropic's document skills (`/document-skills:pptx` and friends) are source-available, not open source, so they are not copied here; a slides repo's `settings.json` installs them as a plugin on each machine instead.

## Adopting this template

A new repo is derived in two commits, and its shared files are never edited afterwards; template changes reach it by `--sync`.

1. Commit 1 is a copy of the category files, verbatim except that `docker/Dockerfile` and `settings.json` are trimmed to the categories, with the message `template: import <categories> from devansh-dvj/.claude@<short sha>`.
2. Commit 2 fills the placeholders only: the slug in `docker/*.sh`, `.claude/project.md`, and the `<PROJECT>` and one-line placeholders at the top of `CLAUDE.md`.

`<template>/derive.sh [--force] <repo> <category>...` makes commit 1 mechanical.
It copies the tracked files of the given categories and the ones they imply, refuses to overwrite a file that differs unless `--force`, and prints the `git add` and `git commit` commands for commit 1 without running them.
An existing repo adopting the template uses `--replace`: with nothing uncommitted under `CLAUDE.md`, `.claude`, `docker`, and `format`, it `git rm`s the tracked files there, keeping untracked and ignored ones such as `.claude/settings.local.json`, copies the categories, and prints a commit 1 that stages those roots whole, removals included.
`<template>/derive.sh --slug <slug> <repo>` sets the slug in the repo's `docker/*.sh` and prints the commit 2 commands, to run once `.claude/project.md` and the top of `CLAUDE.md` are filled by hand.
`<template>/derive.sh --sync <repo>` mirrors the template's HEAD into a derived repo: with nothing uncommitted under its roots, it re-copies every template-owned path of its categories, removes the files the template dropped and the paths of categories the repo did not take, keeps `.claude/project.md`, `docker/environment.yml`, the top of `CLAUDE.md`, the slug, and the project tail of `docker/Dockerfile`, and prints each change and a commit `template: sync from devansh-dvj/.claude@<short sha>` that stages the roots whole, removals included.

Both flows run from a pasted prompt in a Claude Code session in the repo: the derivation prompt for a new repo, the sync prompt for a derived repo picking up template changes or an existing repo adopting the template.
Set `<template>` in either to a local checkout of this repo.

## Derivation prompt (new repo)

> Set up this repo from the Claude Code template checked out at `<template>` (github.com/devansh-dvj/.claude), in two commits, and stop once the image builds.
> First ask me, in one question, what this project's goal is.
> Then propose its categories from core (always), drawio, writing, slides, and latex (slides and latex bring drawio and writing), with a line on why each fits, plus a short lowercase slug, and wait for me to confirm them.
> Run `<template>/derive.sh . <categories>` from this repo's root; if it refuses because a file differs, stop and show me.
> Make commit 1 by running exactly the `git add` and `git commit` commands it prints, adding nothing to the message.
> For commit 2, change only the placeholders: run `<template>/derive.sh --slug <slug> .`, fill `.claude/project.md` from my answer and the repo (for latex, record under Overrides that LaTeX builds run on the host), and replace the `<PROJECT>` and one-line placeholders at the top of `CLAUDE.md`.
> Make commit 2 by running exactly the `git add` and `git commit` commands `--slug` printed, and never edit any other file derive.sh copied.
> Then run `./docker/build.sh`, tell me whether it built, and stop.

## Sync prompt (existing repo)

> Bring this repo in line with the Claude Code template checked out at `<template>` (github.com/devansh-dvj/.claude), in one commit, and stop.
> First run `<template>/derive.sh --check .` from this repo's root and show me its report.
> If the history has no `template:` commit, the repo was never derived: stop, propose its categories from core (always), drawio, writing, slides, and latex, and once I confirm run `<template>/derive.sh --replace . <categories>` and make the two commits exactly as the derivation prompt describes.
> Otherwise run `<template>/derive.sh --sync .`, read every `remove` and `copy` line it prints, and tell me about anything removed that this repo still relies on before going on.
> Make the sync commit by running exactly the `git add` and `git commit` commands it prints, adding nothing to the message.
> Never edit a copied file by hand; anything that needs changing changes in the template and arrives with the next sync.
> Then run `./docker/build.sh`, tell me whether it built, and stop.
