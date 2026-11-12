# .claude template

A portable Claude Code workflow for R&D repos: agnostic rule docs, judgment skills, and formatter/container tooling.
Canonical source: `github.com/devansh-dvj/.claude`.

## What is in here

```
CLAUDE.md                 thin loader: @-includes the three rule files
derive.sh                 copies categories into a repo, checks or syncs a derived repo; stays here
test/                     checks for derive.sh and the protect hook; stays here
.claude/
  session.md              how I work in any session
  engineering.md          code/diff/comment/docs conventions
  project.md              the project's own context file
  settings.json           enables the document-skills plugin, wires the protect hook
  .gitignore              ignores .unlock and settings.local.json
  hooks/protect.py        blocks edits to template-owned files
  hooks/analysis.py       finds the paths a Bash command would write, for protect.py
  skills/                 the twelve skills of the table below
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

| Category     | Adds                                                                           | Implies         |
| ------------ | ------------------------------------------------------------------------------ | --------------- |
| core         | everything not listed below                                                    | always taken    |
| drawio       | skills `drawio`, `pdf-addon`; `docker/fonts/`; the Dockerfile's `drawio` block | --              |
| writing      | skill `writing`                                                                | --              |
| slides-pptx  | skill `pptx-addon`; the Dockerfile's `pptx` block                              | drawio, writing |
| paper-latex  | skill `latex`                                                                  | drawio, writing |
| slides-latex | skill `beamer`                                                                 | paper-latex     |

LaTeX builds run on the host; the image is for diagram export and PDF review.
A repo without slides-pptx gets `settings.json` without the plugin keys.
The exact paths and Dockerfile blocks per category are the `MANIFEST` and `BLOCKS` arrays in `derive.sh`.

## Images

`docker/Dockerfile` is one buildable file in blocks, each running from its marker line to the next.

- `# ==== base ====`, `# ==== drawio ====`, `# ==== pptx ====`: the shared blocks, never edited in a repo.
- `# ==== project ====`: the project tail, the repo's own, from that marker to the end.
- `docker/build.sh`: one `docker build` of the file as `<slug>:latest-<arch>`, passing `BASE_OS` as the `OS` build argument.

## Enforcement

`.claude/hooks/protect.py` keeps the template-owned files as the template shipped them.

- Blocked: any edit under `.claude/`, `docker/`, or `format/`, and to any `.gitignore` or `LICENSE`.
- Open: `.claude/project.md`, `.claude/settings.local.json`, `docker/Dockerfile`, `docker/environment.yml`, and anything under `work/`.
- A shell command is blocked only when what it writes, moves, or deletes is a blocked path; reading one or running its script is not.
- Inline code, such as `python3 -c`, that names a blocked path counts as a write.
- A write whose target is known only at run time is blocked, unless it starts inside the repo.
- A command the hook cannot read, such as one with an unclosed quote, is blocked.
- A hand-made, gitignored `.claude/.unlock` file lifts the block for the edit at hand: the owner creates it, and the session deletes it as soon as that edit is done.
- `.claude/skills/review-diff/mdcheck.py` lists every markdown paragraph or list item over 200 characters as a lead for `/review-diff`, not a failure.

## Skills

Every skill loads when its description matches the task, and every one but the comment doctrine can also be invoked by name.

| Skill           | Category     | Does                                                                   |
| --------------- | ------------ | ---------------------------------------------------------------------- |
| `/review-diff`  | core         | reviews the working diff against this project's rule files             |
| `/commit`       | core         | makes one pathspec-safe commit                                         |
| `/format`       | core         | formats files, folders, or globs with the project formatter            |
| `/delegate`     | core         | runs a session as the orchestrator of its subagents                    |
| `/plans`        | core         | writes, runs, and closes one prompt file per planned session           |
| `comment-style` | core         | sets the terse-comment doctrine                                        |
| `/drawio`       | drawio       | draws native `.drawio` diagrams, exported headlessly in the image      |
| `/pdf-addon`    | drawio       | reviews a PDF by contact sheet and page-by-page diff of two versions   |
| `/writing`      | writing      | drafts and reviews prose, one unit at a time, through the review loop  |
| `/pptx-addon`   | slides-pptx  | edits a few slides of a deck and proves the rest unchanged             |
| `/latex`        | paper-latex  | builds, reviews, and diffs LaTeX papers and talks with host `make`     |
| `/beamer`       | slides-latex | writes, builds, and reviews a beamer deck, one frame per file          |

Claude Code loads a personal `~/.claude/skills/<name>` over a project skill of the same name, so keep no personal copies of these.

## Adopting this template

A repo takes the template in two commits and later picks up template changes with `--sync`.

1. Commit 1 adds the chosen categories' files verbatim, minus the Dockerfile blocks and settings keys of categories not chosen.
2. Commit 2 fills the placeholders: the slug in `docker/*.sh`, `.claude/project.md`, and the heading and description line of `CLAUDE.md`.

`derive.sh` prints the `git add` and `git commit` commands rather than running them:

- `derive.sh <repo> <category>...` copies the files for commit 1.
- `derive.sh --replace <repo> <category>...` does the same for an existing repo, removing its tracked files under `CLAUDE.md`, `.claude/`, `docker/`, and `format/` first.
- `derive.sh --slug <slug> <repo>` writes the slug into `docker/*.sh` and prints the commit 2 commands.
- `derive.sh --check <repo> [<category>...]` prints one status per template path: `identical`, `filled` (a project-owned part), `differs`, `missing`, or `extra` (a category the repo did not take); exit 1 on `differs` or `missing`.
  - It checks the categories named after the repo, else those the repo's last `template:` commit records.
  - When that commit records none, or there is none, it stops and names the fix: `derive.sh --check <repo> <category>...`.
- `derive.sh --sync <repo> [<category>...]` copies what the template changed since the repo's last `template:` commit, removes what it dropped, leaves every other file as the repo has it, and keeps the project-owned parts.
  - It takes its categories as `--check` does and stops the same way, naming `derive.sh --sync <repo> <category>...`.
  - It prints the sync commit, which records the categories as the import commit does.
  - Naming the categories on an up-to-date repo prints an empty commit that records them, unless the last `template:` commit already records that list.
  - A `local` line names each file it overwrites that the repo had changed.
  - With categories named but no `template:` commit, or one the template clone lacks, it recopies every template path after a `full sync:` line.

- An import and a sync add `work/` to the repo's `.git/info/exclude` unless it is already ignored.
- Both stop without printing a commit when the copied hook does not run.
- `test/derive/run.sh` and `python3 test/hook/run_cases.py` check `derive.sh` and the hook. Run them before changing either.

The two prompts below drive this from a Claude Code session in the repo.

## Derivation prompt (new repo)

> Set up the Claude Code workflow from `github.com/devansh-dvj/.claude` in this repo, in two commits.
>
> 1. Clone the template: `git clone --depth 1 git@github.com:devansh-dvj/.claude.git work/template`.
> 2. Ask me, in one question, what this project's goal is.
> 3. Propose its categories from the Categories table in `work/template/README.md`, one line each on why it fits, plus a project name and a short lowercase slug.
>    Then wait for my confirmation.
> 4. Run `work/template/derive.sh . <categories>` and make commit 1 with exactly the commands it prints.
>    - If a `derive.sh` command fails, show me its output and wait.
> 5. Run `work/template/derive.sh --slug <slug> .`, fill `.claude/project.md` from my answer and the repo, and fill the two placeholders at the top of `CLAUDE.md`.
>    Make commit 2 with exactly the commands `--slug` printed.
> 6. Run `./docker/build.sh` in the background, tell me whether it built or found an existing image of that name, and remove `work/template`.

## Sync prompt (existing repo)

> Update the Claude Code workflow in this repo to the current `github.com/devansh-dvj/.claude`.
>
> 1. Clone the template with its history: `git clone --filter=blob:none git@github.com:devansh-dvj/.claude.git work/template`.
> 2. If no commit message in `git log` starts with `template:`, take the replace route:
>    - Show me what `--replace` would delete under `CLAUDE.md`, `.claude/`, `docker/`, and `format/`, and wait for my go-ahead.
>    - Then follow the derivation prompt in `work/template/README.md` from its "Ask me" step, with `--replace` on its first `derive.sh` command.
>    - Carry the old project facts and toolchain into `.claude/project.md` and the Dockerfile's project tail.
> 3. Otherwise run `work/template/derive.sh --sync .`:
>    - If it stops because the categories are not recorded, ask me, in one question, which categories this repo takes, and rerun with them.
>    - If it says the repo is up to date, remove `work/template` and you are done.
>    - If a `remove` line names something this repo still uses, tell me and wait.
> 4. On either route, before any commit, cross-check the whole diff under `CLAUDE.md`, `.claude/`, `docker/`, and `format/` for project-specific changes it drops:
>    - on the `--sync` route, each file a `local` line names, or after a `full sync:` line whatever this repo's own commits to those paths since its last `template:` commit added.
>    - on the `--replace` route, whatever the deleted files hold that the template does not, such as an extra formatter exclude.
> 5. Make the sync commit with exactly the commands it prints, touching no other copied file.
> 6. If the diff dropped project-specific changes, list them for me and ask me to create `.claude/.unlock`.
>    - Restore each one on top of the new files, delete `.claude/.unlock`, and make a second commit.
>    - They were approved when first committed, so never leave them dropped and never fold them into the sync commit.
> 7. If a commit touched `docker/`, run `./docker/build.sh --rebuild` in the background.
>    - If containers still use the old image, tell me instead of passing `--force`.
> 8. Remove `work/template`.
