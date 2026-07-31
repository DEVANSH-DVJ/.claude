# .claude/rules/

Path-scoped instruction files. A rule with `paths:` frontmatter loads only when
Claude touches a matching file, so the always-on memory (CLAUDE.md and the
`@`-included rule files) stays lean.

Use these for LANGUAGE- or DIRECTORY-specific conventions that would otherwise
bloat `engineering.md`. Example `rust.md`:

    ---
    paths: ["**/*.rs"]
    ---
    # Rust
    - rustfmt via format/format.sh; 2-space indent, max_width 100.
    - Docstrings on public items, 5 lines max: contract, not history.

A rule with no `paths:` loads every session at the same weight as CLAUDE.md, so
prefer path-scoping unless the rule is truly global.
