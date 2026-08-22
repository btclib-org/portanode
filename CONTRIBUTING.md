# Contributing to PortaNode

Thank you for your interest in contributing to PortaNode!

## How to Contribute

1. **Fork the Repository**: Create a fork on GitHub.
2. **Create a Branch**: Use a descriptive name (e.g., `feature/add-checksums`).
3. **Make Changes**: Follow the guidelines below.
4. **Test**: Run scripts on both macOS and Windows.
5. **Submit a Pull Request**: Include a clear description and reference any
   issues.

## Guidelines

- **Code Style**: Use consistent naming (e.g., `ROOTDIR` for paths) and
  paths relative to it, never absolute ones — the folder's mount point
  changes with the machine it is plugged into. Add comments for complex
  logic.
- **Error Handling**: Include checks for paths, binaries, and user
  confirmations.
- **Documentation**: Update READMEs for any changes. Add examples.
- **Security**: Never commit sensitive data. Verify binaries with checksums.
- **Compatibility**: Test on macOS 10.15+ and Windows 10+.
- **Versioning**: This project uses Calendar Versioning (CalVer) with YYYY.MM.DD
  format.

## Reporting Issues

The issue tracker is where unfinished work lives — a bug, a missing
feature, a paragraph of documentation that describes something the scripts
do not do. Nothing is tracked in a file in the tree, because a file cannot
be searched, assigned, or closed by the pull request that fixes it.

Open a bug through
[the form](https://github.com/btclib-org/portanode/issues/new/choose). It
asks for what a reproduction needs, the volume and filesystem the folder
lives on included: on a portable node that is the difference between most
reports and the ones that reproduce.

Anything that is not a bug goes in a blank issue.

## Review and Merging

Every change starts with an open issue. A pull request needs an approving
review from somebody other than its author before it can merge — GitHub does
not allow a self-approval. Use `Closes #N` in the pull request's description:
that is what closes the issue once the reviewed pull request merges.

`main` also enforces four things on every commit that reaches it, not only
on review: a verified signature, linear history, no force pushes, no branch
deletion. This is a GitHub ruleset with no bypass actor, not a rule trusted
to hold on its own — a commit that is unsigned or that rewrites history is
rejected before it is something to review. Commits need a verified signature
(GPG, SSH or S/MIME):
https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification

## License

By contributing, you agree to the MIT License.
