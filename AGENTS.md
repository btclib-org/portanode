# Agent guidance

Follow `CONTRIBUTING.md` for project and organization rules, local
gates, and worktree commands. Read `README.md` for user-facing behavior,
`REPOSITORY.md` before changing workflows or settings,
`ASSURANCE_CASE.md` for security claims, and `VERIFYING.md` for release
verification.

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

## Code Review Rules

Review against [REVIEWING.md](./REVIEWING.md). Its *The verdict* says
which review opens with a verdict line and what every other review
posts.

The heading is the one Codex's GitHub review asks for
([Customize what Codex reviews](https://learn.chatgpt.com/docs/third-party/github#customize-what-codex-reviews)).
