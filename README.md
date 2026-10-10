# .claude template

A portable Claude Code workflow for R&D repos: agnostic rule docs, judgment skills, and formatter/container tooling.
Canonical source: `github.com/devansh-dvj/.claude`.

## What is in here

```
CLAUDE.md                 thin loader: @-includes the three rule files
derive.sh                 copies categories into a repo, checks or syncs a derived repo; stays here
.claude/
  session.md              how I work in any session
  engineering.md          code/diff/comment/docs conventions
  project.md              the project's own context file
  settings.json           enables the document-skills plugin, wires the protect hook
  .gitignore              ignores .unlock and settings.local.json
  hooks/protect.py        blocks edits to template-owned files
  skills/                 the ten skills of the table below
format/                   format.sh dispatcher + per-language configs
docker/
  build.sh                builds the image
  run.sh                  interactive shell in an ephemeral or --persistent container
  exec.sh                 one command in a throwaway container: ./docker/exec.sh "<cmd>"
  chown.sh                hands the repo's files back to the host user
  cleanup.sh              removes, on confirmation, each container of the project image
  Dockerfile              the image, in marked blocks
  environment.yml         the conda env the project image installs
  entrypoint.sh           the image's interactive entrypoint
  fonts/                  licensed fonts for the drawio block
```

## Categories

| Category | Adds                                                                           | Implies         |
| -------- | ------------------------------------------------------------------------------ | --------------- |
| core     | everything not listed below                                                    | always taken    |
| drawio   | skills `drawio`, `pdf-addon`; `docker/fonts/`; the Dockerfile's `drawio` block | --              |
| writing  | skill `writing`                                                                | --              |
| slides   | skill `pptx-addon`; the Dockerfile's `slides` block                            | drawio, writing |
| latex    | skill `latex`                                                                  | drawio, writing |

LaTeX builds run on the host; the image is for diagram export and PDF review.
A repo without slides gets `settings.json` without the plugin keys.
The exact path list per category is the `MANIFEST` array in `derive.sh`.

## Images

`docker/Dockerfile` is one buildable file, split by the marker lines `# ==== base ====`, `# ==== drawio ====`, `# ==== slides ====`, and `# ==== project ====` into blocks that run to the next marker.
Everything from `# ==== project ====` on is the project tail, the repo's own; the blocks above it are shared and never edited in a repo.
`docker/build.sh` builds it in one `docker build` as `<slug>:latest-<arch>`, passing `BASE_OS` as the `OS` build argument.

## Enforcement

`.claude/hooks/protect.py` blocks any edit under `.claude/`, `docker/`, or `format/` and to any `.gitignore` or `LICENSE`, except `.claude/project.md`, `.claude/settings.local.json`, `docker/Dockerfile`, and `docker/environment.yml`.
A hand-made, gitignored `.claude/.unlock` file lifts the block.
It lasts only for the edit at hand: the owner creates it, and the session deletes it as soon as that edit is done.

## Skills

| Skill           | What it does                                                           |
| --------------- | ---------------------------------------------------------------------- |
| `/review-diff`  | review the working diff against this project's own rule files          |
| `/commit`       | guided, pathspec-safe commit                                           |
| `/format`       | format files, folders, or globs with the project formatter             |
| `/delegate`     | subagent orchestration playbook                                        |
| `comment-style` | terse-comment doctrine                                                 |
| `drawio`        | native `.drawio` diagrams, exported headlessly in the image            |
| `pdf-addon`     | PDF review: contact sheets and page-by-page diffs of two versions      |
| `/writing`      | prose deliverables, one unit at a time, through the review loop        |
| `pptx-addon`    | edit a few slides of a deck and prove the rest unchanged               |
| `/latex`        | build, review, and diff LaTeX papers and beamer talks with host `make` |

Claude Code loads a personal `~/.claude/skills/<name>` over a project skill of the same name, so keep no personal copies of these.

## Adopting this template

A repo takes the template in two commits and later picks up template changes with `--sync`.

1. Commit 1 adds the chosen categories' files verbatim, minus the Dockerfile blocks and settings keys of categories not chosen.
2. Commit 2 fills the placeholders: the slug in `docker/*.sh`, `.claude/project.md`, and the heading and description line of `CLAUDE.md`.

`derive.sh` prints the `git add` and `git commit` commands rather than running them:

- `derive.sh <repo> <category>...` copies the files for commit 1.
- `derive.sh --replace <repo> <category>...` does the same for an existing repo, removing its tracked files under `CLAUDE.md`, `.claude/`, `docker/`, and `format/` first.
- `derive.sh --slug <slug> <repo>` writes the slug into `docker/*.sh` and prints the commit 2 commands.
- `derive.sh --check <repo>` prints one status per template path: `identical`, `filled` (a project-owned part), `differs`, `missing`, or `extra` (a category the repo did not take); exit 1 on `differs` or `missing`.
- `derive.sh --sync <repo>` recopies the template paths, removes what the template dropped, keeps the project-owned parts, and prints the sync commit.

The two prompts below drive this from a Claude Code session in the repo.

## Derivation prompt (new repo)

> Set up the Claude Code workflow from `github.com/devansh-dvj/.claude` in this repo, in two commits.
> Clone the template: `git clone --depth 1 git@github.com:devansh-dvj/.claude.git work/template`, and add `work/` to `.git/info/exclude` if it is not ignored yet.
> Ask me, in one question, what this project's goal is.
> Propose its categories from the Categories table in `work/template/README.md`, one line each on why it fits, plus a project name and a short lowercase slug, then wait for my confirmation.
> Run `work/template/derive.sh . <categories>` and make commit 1 with exactly the commands it prints; if a `derive.sh` command fails, show me its output and wait.
> Run `work/template/derive.sh --slug <slug> .`, fill `.claude/project.md` from my answer and the repo, fill the two placeholders at the top of `CLAUDE.md`, and make commit 2 with exactly the commands `--slug` printed.
> Run `./docker/build.sh` in the background, tell me whether it built or found an existing image of that name, and remove `work/template`.

## Sync prompt (existing repo)

> Update the Claude Code workflow in this repo to the current `github.com/devansh-dvj/.claude`.
> Clone the template: `git clone --depth 1 git@github.com:devansh-dvj/.claude.git work/template`, and add `work/` to `.git/info/exclude` if it is not ignored yet.
> If no commit message in `git log` starts with `template:`, show me what `--replace` would delete under `CLAUDE.md`, `.claude/`, `docker/`, and `format/`, wait for my go-ahead, then follow the derivation prompt in `work/template/README.md` from its "Ask me" step with `--replace` on its first `derive.sh` command, carrying the old project facts and toolchain into `.claude/project.md` and the Dockerfile's project tail.
> Otherwise run `work/template/derive.sh --sync .`; if it says the repo already matches, remove `work/template` and you are done; if a `remove` line names something this repo still uses, tell me and wait.
> On either route, before any commit, cross-check the whole diff under `CLAUDE.md`, `.claude/`, `docker/`, and `format/` for project-specific changes it drops: on the `--sync` route, whatever this repo's own commits to those paths since its last `template:` commit added; on the `--replace` route, whatever the deleted files hold that the template does not, such as an extra formatter exclude.
> Make the sync commit with exactly the commands it prints, touching no other copied file.
> If the diff dropped project-specific changes, list them for me, ask me to create `.claude/.unlock`, restore each one on top of the new files, delete `.claude/.unlock`, and make a second commit; they were approved when first committed, so never leave them dropped and never fold them into the sync commit.
> Run `./docker/build.sh --rebuild` in the background; if containers still use the old image, tell me instead of passing `--force`.
> Remove `work/template`.
