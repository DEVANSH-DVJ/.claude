---
name: delegate
description: How to split work across subagents -- choose the model and effort per task, set them explicitly, and avoid the resume/model footgun. Use when planning multi-step, parallel, or exploration-heavy work.
user-invocable: true
---

Orchestration playbook. The main session owns reasoning, planning, verdicts, and decisions; subagents do the legwork.

- Delegate: exploration, long or complicated analysis, summarization, and mechanical dev/test work. Skip agents when delegation would cost more than doing it inline.
- Keep in the main session: the plan, the verdict, statistics, and anything that must hold the whole picture.
- Set model and effort explicitly on every launch -- inheritance is silent and usually wrong. Match the tier to the task: cheaper models for mechanical dev/test, stronger models for hard analysis and judgment.
- Prefer a fresh launch over resuming for substantial follow-ups: a resumed subagent can silently continue on the parent model.
- Launch long runs in the background and rely on the completion notification; do not poll status or logs from the main session.
- Run independent subagents in parallel (one message, multiple launches); keep dependent work sequential.
- In every subagent prompt, tell it not to run git writes or commit and to report changes back instead: subagents don't reliably read the repo rules, so it must be stated inline.

See `session.md` for the standing rules; this skill is the how-to.
