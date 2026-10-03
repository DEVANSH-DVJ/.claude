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
`.claude/hooks/protect.py` blocks any edit under `.claude/`, `docker/`, or `format/` and to any `.gitignore` or `LICENSE`, except `.claude/project.md`, `.claude/settings.local.json`, `docker/Dockerfile`, and `docker/environment.yml`, so the copied files change only in this repo and reach other repos by sync.
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
| `/latex`        | latex    | LaTeX papers and beamer talks: host `make` builds, log and font checks, page renders with a page-count gate, `latexdiff` against the submission, draw.io figures         |

Day to day: `/format` before commits, `/review-diff` before finishing, `/commit` to commit.
Claude Code loads a personal `~/.claude/skills/<name>` over a project skill of the same name, so keep no personal copies of these.
Anthropic's document skills (`/document-skills:pptx` and friends) are source-available, not open source, so they are not copied here; a slides repo's `settings.json` installs them as a plugin on each machine instead.

## Adopting this template

A repo takes the template in two commits; afterwards it edits only its project-owned parts, and template changes arrive through `--sync`.

1. Commit 1 adds the chosen categories' files verbatim, except that `docker/Dockerfile` drops the blocks of categories not chosen and, without slides, `.claude/settings.json` drops the plugin keys.
   Its message is `template: import <categories> from devansh-dvj/.claude@<short sha>`.
2. Commit 2 fills the placeholders: the slug in `docker/*.sh`, `.claude/project.md`, and the heading and description line of `CLAUDE.md`.

`derive.sh` does the mechanical part and prints the `git add` and `git commit` commands rather than running them:

- `derive.sh <repo> <category>...` copies the files for commit 1, and refuses if a file already there differs from the template.
- `derive.sh --replace <repo> <category>...` does the same for an existing repo: it removes the tracked files under `CLAUDE.md`, `.claude/`, `docker/`, and `format/` first, so commit 1 replaces them.
- `derive.sh --slug <slug> <repo>` writes the slug into `docker/*.sh` and prints the commit 2 commands; `.claude/project.md` and the heading and description line of `CLAUDE.md` are filled before that commit, outside the script.
- `derive.sh --check <repo>` prints one status per template path (the statuses are listed under Enforcement).
- `derive.sh --sync <repo>` brings a derived repo up to the template's current commit: it recopies the template paths, removes what the template dropped, keeps the project-owned parts (`.claude/project.md`, `docker/environment.yml`, the slug, the heading and description line of `CLAUDE.md`, the project tail of `docker/Dockerfile`), and prints a commit `template: sync from devansh-dvj/.claude@<short sha>`.

Both `--replace` and `--sync` refuse a repo with uncommitted or untracked files under `CLAUDE.md`, `.claude/`, `docker/`, or `format/`.
The two prompts below drive all of this from a Claude Code session in the repo; each clones this template into `work/template`, kept out of git through `.git/info/exclude`, and runs `derive.sh` from there.

## Derivation prompt (new repo)

> Set up the Claude Code workflow from `github.com/devansh-dvj/.claude` in this repo, in two commits, ending with a built image.
> Clone the template first: `git clone --depth 1 git@github.com:devansh-dvj/.claude.git work/template`, and add `work/` to `.git/info/exclude` if it is not ignored yet.
> Ask me, in one question, what this project's goal is.
> Propose its categories, one line each on why it fits (core always; drawio, writing, slides, latex as needed; slides and latex bring drawio and writing), and a short lowercase slug, then wait for my confirmation.
> Run `work/template/derive.sh . <categories>` from this repo's root; if it refuses, show me its output and wait.
> Make commit 1 with exactly the commands it prints.
> Run `work/template/derive.sh --slug <slug> .`, fill `.claude/project.md` from my answer and the repo, deleting any section with nothing true to state, and in `CLAUDE.md` put the project name in place of `<PROJECT>` and one line in place of the description placeholder.
> Make commit 2 with exactly the commands `--slug` printed, touching no other copied file.
> Run `./docker/build.sh` and tell me whether it built or found an existing image of that name, then remove `work/template` so this repo does not keep a second copy of the template.

## Sync prompt (existing repo)

> Update the Claude Code workflow in this repo to the current `github.com/devansh-dvj/.claude`.
> Clone the template first: `git clone --depth 1 git@github.com:devansh-dvj/.claude.git work/template`, or `git -C work/template pull` if it is already there, and add `work/` to `.git/info/exclude` if it is not ignored yet.
> If no commit message in `git log` starts with `template:`, this repo never took the template: list the tracked files that `--replace` would delete under `CLAUDE.md`, `.claude/`, `docker/`, and `format/`, wait for my go-ahead, then follow the derivation prompt in `work/template/README.md` from its "Ask me" step with `--replace` added to its first `derive.sh` command, and skip the rest of this prompt.
> Otherwise run `work/template/derive.sh --check .` from this repo's root and show me its report, then run `work/template/derive.sh --sync .`; if it prints `already matches the template`, tell me; if a `remove` line names something this repo still uses, tell me and wait for my go-ahead.
> Make the sync commit with exactly the commands it prints, touching no other copied file.
> Run `./docker/build.sh --rebuild` and tell me whether it built; if containers still use the old image, tell me instead of passing `--force`.
> Remove `work/template` so this repo does not keep a second copy of the template.
