# Agent guidance

Read `README.md` for user-facing behavior, `CONTRIBUTING.md` for project
and organization rules and gates, `REVIEWING.md` for review expectations,
including launcher path and executable-bit criteria, `ASSURANCE_CASE.md`
for security claims, and `VERIFYING.md` for release verification.

Use a separate worktree for each concurrent task, based on `origin/main`.
Keep the primary checkout clean and on `main`; `CONTRIBUTING.md` gives the
worktree commands.

Choose the least capable model that can handle the task reliably. Increase
reasoning capacity when the change is ambiguous, security-sensitive, or
affects decisions shared across platforms. Apply this criterion regardless
of provider; do not select by product or version name.
