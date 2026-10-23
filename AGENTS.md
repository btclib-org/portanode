# Agent guidance

Follow `CONTRIBUTING.md` for project and organization rules, local
gates, and worktree commands. Read `README.md` for user-facing behavior,
`REVIEWING.md` for review expectations, including launcher path and
executable-bit criteria, `REPOSITORY.md` before changing workflows or
settings, `ASSURANCE_CASE.md` for security claims, and `VERIFYING.md` for
release verification.

Keep the primary checkout clean and on `main`; use a separate worktree
for each task, following the setup and cleanup commands in
`CONTRIBUTING.md`.

Choose the least capable model that can reliably complete the task: use
a fast model for straightforward execution, a reasoning-focused model
for multi-step work, and the most capable available model for difficult
or ambiguous problems. Increase capability if progress stalls. Use the
most capable model for a change to what a launcher decides: a
verification path, a rollback, or a choice two platforms must make the
same way.
