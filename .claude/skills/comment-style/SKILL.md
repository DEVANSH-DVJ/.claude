---
name: comment-style
description: How to write code comments in this repo -- terse one-liners, small headers, and where the "why" belongs. Auto-loads when editing source files.
user-invocable: false
paths: ["**/*.rs", "**/*.py", "**/*.sh", "**/*.cc", "**/*.cpp", "**/*.h", "**/*.hpp", "**/*.js", "**/*.ts", "**/*.go"]
---

Comment doctrine for source files:

- One-liners: 4-5 words ideal, 8-10 if needed, always to the point. Multi-line comments are a rare exception.
- Write for the flow of the code: frequent enough that a top-to-bottom reader never hits a gap, sparse enough not to force scrolling.
- Reuse vocabulary and phrasing so `grep` lands on related spots, and keep the tone consistent.
- Comment what the code does, or a non-obvious invariant, never the conversation. No "added for X", no "fixes Y", no "tried Z", no `// previously:`.
- File header: 0 lines when the name makes the purpose obvious; 4-5 for a normal header; 8-10 only for a long or central file. If it wants more, split the file.
- Public-API docstrings: 5 lines max, state the contract not the history.
- The "why the code is the way it is" goes in the living docs (status / plan / README), never in code.
