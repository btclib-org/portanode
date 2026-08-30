# Repository configuration

Read this before changing a branch rule, a repository setting or a
workflow; editing a launcher does not need it. `CLAUDE.md` points here
rather than carrying it, so that a session fixing a script does not hold
it in context.

The branch rules and the repository settings live *outside* the
repository, so this file is the whole of them: nothing here can be
recovered by reading the tree. Every claim below is read back from an
endpoint, and the command that reads it is beside it — a setting somebody
changed in the browser is a line here that has gone stale, and the
command is what says so.

**The repository is public, and that is a prerequisite rather than a
preference.** Rulesets are a paid feature for a private repository on the
free plan, and everything below depends on them; the workflows depend on
it too, Actions being unmetered only here.

```shell
gh api repos/btclib-org/portanode --jq '{visibility, has_issues}'
```

## What gates a merge

**`lint.yml` runs on every pull request, and a red run of it stops the
merge:**

```shell
gh api repos/btclib-org/portanode/branches/main/protection \
  --jq '.required_status_checks | {checks, contexts, strict}'
```

```json
{"checks":[{"app_id":15368,"context":"Lint"}],"contexts":["Lint"],"strict":true}
```

names the context `Lint` — the job's name, `lint.yml` saying why that name
is the context and why renaming it cannot be done in a pull request
afterwards — as a required status check.

**The requirement lives in classic branch protection, not in a ruleset
rule.** None of the rulesets below carries a `required_status_checks`
rule:

```shell
gh api repos/btclib-org/portanode/rules/branches/main \
  --jq '[.[] | {type, ruleset_id}]'
```

lists only `main-integrity`'s four rules and `main-self-merge`'s one;
`Lint` is required through the older `branches/main/protection` endpoint,
which this repository keeps active alongside the rulesets rather than
folding into one of them.

**`strict` is on**, so a pull request also has to be up to date with
`main` before GitHub will merge it — a rebase before every landing, not
only a green `Lint`.

`links.yml` and `claude-review.yml` are not part of the required check:
the first reports the internet's weather and the second an opinion, and
neither is a thing to hold a merge on.

What holds a pull request is the review and `Lint`; what holds every
commit that reaches `main` is `main-integrity`.

## Rulesets

Every one of them is `active`, and this is the whole of the branch and
tag rules:

```shell
gh api repos/btclib-org/portanode/rulesets --jq '.[].id' | xargs -I{} \
  gh api repos/btclib-org/portanode/rulesets/{} --jq '{name, target,
    rules: [.rules[].type], bypass: [.bypass_actors[]?.bypass_mode]}'
```

- `main-integrity`, on `refs/heads/main`: required signatures, required
  linear history, no force push, no deletion. No bypass actor.
- `main-self-merge`, on `refs/heads/main`: one `pull_request` rule.
  `fametrano` bypasses it in `pull_request` mode.
- `tag-integrity`, on `refs/tags/v*`: required signatures. No bypass
  actor.

**`main-integrity` has no bypass actor and is meant not to have one.** A
commit that is unsigned, or that rewrites what is already on `main`, is
refused before it is something to review — the maintainer's own push
included. It costs nothing in practice for the reason the next section
gives: the only thing writing to `main` is a merge GitHub performs
itself, and GitHub signs those with its web-flow key. A valid signature
is what the rule asks for, not a particular signer's.

**`main-self-merge` is in `pull_request` mode, which is a review
exception and not a signature one.** GitHub does not allow an author to
approve their own pull request, so on a solo-maintainer repository the
rule as written stops every one the maintainer opens; the bypass is what
lets one merge at all. The other mode, `always`, would permit a direct push to
`main` as well, and is not used here — what it would buy is a landing
commit carrying the maintainer's own signature, which is worth nothing
once the rule is read as asking for a valid signature rather than for
that one.

The rule's own parameters carry more than the approval count, and each is
a decision:

```shell
gh api repos/btclib-org/portanode/rulesets/20736361 \
  --jq '.rules[] | select(.type=="pull_request") | .parameters'
```

`allowed_merge_methods` is `["squash"]`, stating the constraint where the
rule is and not only in the setting below. `dismiss_stale_reviews_on_push`
is on, so a push after an approval asks for the approval again.
`required_review_thread_resolution` is on, so a thread a reviewer opened
holds the merge until somebody resolves it.
`require_extra_approval_for_unattributed_changes` is on, which is what
asks again when a commit's author is not a recognised account.

**`tag-integrity` carries no `deletion` or `non_fast_forward` rule**, and
that is deliberate rather than an omission: a release that failed
half-way is recovered by deleting the tag and re-cutting it, which either
rule would block. What it does refuse is an unsigned `v*` tag.

A *lightweight* tag — a ref pointing straight at a commit — has no tag
object for a signature to sit on, which is why `RELEASING.md` tags with
`git tag -s` and reads the ref's `.object.type` back afterwards.

Which tags exist is not recorded here: a tag is a ref in the repository,
where everything else in this file is a setting outside it, so a tag
named here is a line that goes stale the day somebody deletes it.

```shell
gh api repos/btclib-org/portanode/tags --jq '.[].name'
```

Empty output means nothing matches the pattern yet.

## Merge methods

**Squash is the only method GitHub can be asked for**, so it is a setting
and not only the convention `CONTRIBUTING.md` states:

```shell
gh api repos/btclib-org/portanode --jq '{allow_squash_merge,
  allow_merge_commit, allow_rebase_merge}'
```

answers `true` for the first and `false` for the other two. The merge
commit was refused by the linear-history rule already, so turning it off
takes away a button that could not have worked. The rebase merge could
have, and that is the one this removes: it replays a branch's commits
onto `main`, where the rule is one commit per landed change.

What a single method buys is not the button on a pull request somebody is
looking at. GitHub preselects whichever method was used last, and the
dialog that switches auto-merge on carries the same dropdown — so the
answer can be given hours before anything merges, by whoever switched it
on, with nothing asking again. One method is one entry: there is no wrong
one to preselect, and nothing to read before pressing.

Two fields shape the commit it writes:

```shell
gh api repos/btclib-org/portanode --jq '{squash_merge_commit_title,
  squash_merge_commit_message}'
```

`COMMIT_OR_PR_TITLE` is the subject — the pull request title with its
number, or the subject of the single commit where a branch has one, which
the convention of writing the two alike keeps the same text.
`COMMIT_MESSAGES` is the body, and `BLANK` is what would cost something:
a `Co-Authored-By` trailer written in the commits of the branch survives
only there.

**`gh pr merge` cannot invoke the bypass**, refusing client-side before it
asks GitHub anything:

```text
Pull request is not mergeable: the base branch policy prohibits the merge
```

The merge endpoint applies it server-side, and it is the same endpoint
the merge button asks.

## Head branches after a merge

```shell
gh api repos/btclib-org/portanode --jq '.delete_branch_on_merge'
```

is `true`. GitHub deletes the head branch of a pull request when it is
merged, which is what keeps the branch list a list of live work rather
than a history of every change ever made. The case it does not cover is
deliberate: a pull request **closed without merging** keeps its head
branch, GitHub not being able to know whether that work was abandoned or
is waiting, so those are the ones worth looking at now and then.

## Secrets

`claude-review.yml` is the only workflow here that reads one, and this
repository holds none of its own:

```shell
gh api repos/btclib-org/portanode/actions/secrets --jq '[.secrets[].name]'
gh api orgs/btclib-org/actions/secrets/CLAUDE_CODE_OAUTH_TOKEN \
  --jq '.visibility'
gh api orgs/btclib-org/dependabot/secrets/CLAUDE_CODE_OAUTH_TOKEN \
  --jq '.visibility'
```

answer with an empty list and `all` twice. **The two organization
commands are not one asked twice.** A `pull_request` run whose actor is
`dependabot[bot]` is handed the Dependabot secrets rather than the
Actions secrets, so a token registered only in the second resolves to the
empty string on exactly the pull requests `.github/dependabot.yml` opens
— and `claude-review.yml`'s credential step turns that into a red job
saying which secret is missing, rather than a review that silently
reviewed nothing.

## Token permissions

```shell
gh api repos/btclib-org/portanode/actions/permissions/workflow \
  --jq '{default_workflow_permissions, can_approve_pull_request_reviews}'
```

answers `read` and `false`, and that is the floor every workflow here
starts from. `claude-review.yml` is the only one whose jobs elevate it —
`pull-requests: write` to post a comment and `id-token: write` for the
OIDC token the action mints at startup — where the lint hooks fix a
checkout that is thrown away and lychee only reads one. The value is a
repository setting that stops following the organization default once it
is set, so lowering the default here would not lower what those two jobs
declare.

```shell
gh api repos/btclib-org/portanode/actions/permissions \
  --jq '{enabled, allowed_actions, sha_pinning_required}'
```

answers `true`, `all` and `false`. `sha_pinning_required` being off means
the forge does not enforce what the standard asks for, so an action
pinned to a tag rather than to forty hex digits would be accepted here.
The pins are kept by the convention instead, and this is what reads them
back:

```shell
grep -h 'uses:' .github/workflows/*.yml | grep -v '@[0-9a-f]\{40\} #'
```

answers with nothing — every `uses:` is forty hex digits with its tag in
a trailing comment. Turning the setting on is one `PATCH` and would move
that from a convention to a refusal.

## Security settings

All of these are repository settings and none of them is in the tree, so
this list is the whole of them:

```shell
gh api repos/btclib-org/portanode --jq '.security_and_analysis'
# the alerts themselves are not in that object: the endpoint that
# answers for them has no body, and says so with its status -- 204 for
# enabled, 404 for not
gh api -i repos/btclib-org/portanode/vulnerability-alerts | head -1
gh api repos/btclib-org/portanode/private-vulnerability-reporting
gh api repos/btclib-org/portanode/code-scanning/default-setup --jq '.state'
```

| Setting | State |
| --- | --- |
| Dependabot alerts | enabled |
| Dependabot security updates | enabled |
| Secret scanning | enabled |
| Secret scanning push protection | enabled |
| Secret scanning non-provider patterns | disabled (plan-gated) |
| Secret scanning validity checks | disabled (plan-gated) |
| Private vulnerability reporting | enabled |
| Code scanning default setup (CodeQL) | not configured |

The table carries every key `.security_and_analysis` answers with, not
only the ones a request here can turn on — the two marked plan-gated are
the next section's subject.

**Private vulnerability reporting is what puts the door in the interface
rather than in a paragraph.** The endpoint answers `{"enabled": true}`,
and [the documentation][pvr] is what says the *Report a vulnerability*
button appears only where it is on. So
`.github/ISSUE_TEMPLATE/config.yml` links `/security/advisories/new`, and
the policy the Security tab shows — `btclib-org/.github`'s, this
repository carrying none of its own, section 2 of the standard leaving
the file to the repositories that publish — names the button first, with
the email address kept beside it: a reporter who would rather not use a
GitHub account still has somewhere to write, and an address needs no
setting to keep working.

Whether the advisory form 404s for somebody without write access was not
checked — doing so needs a second account — so the email address is not
only a preference but the fallback if it does.

[pvr]: https://docs.github.com/en/code-security/security-advisories/working-with-repository-security-advisories/configuring-private-vulnerability-reporting-for-a-repository

Code scanning is not configured and nothing here asks for it: there is no
language CodeQL analyses in this tree — `code-quality/setup` answers with
an empty `languages` list, which is the same finding said twice — and
what reads the launchers instead is `shellcheck`, in
`.pre-commit-config.yaml`'s own hooks.

## Plan-gated settings

Some settings cannot be enabled and fail silently: secret scanning's
non-provider patterns and validity checks need paid Secret Protection,
and the API answers a PATCH with 200 while leaving them disabled — the
table above is what that state is read from. Do not read that 200 as
success. The `detect-secrets` hook is the compensating control.

The other plan-gated number is not a setting at all: how many jobs the
organization may run at once. Section 10 of the organization standard
makes this section its one home per tree, beside the command that
re-derives it:

```shell
gh api orgs/btclib-org --jq .plan.name    # free
```

[GitHub's own table](https://docs.github.com/en/actions/reference/limits)
turns that answer into a number, twenty concurrent jobs on the free plan,
shared across every repository of the organization. `lint.yml` and
`claude-review.yml` are what a pull request here starts, with `links.yml`
added where the path its trigger names is touched. `CONTRIBUTING.md`'s
*The landing queue* is what points here for the figure.

## Topics

```shell
gh api repos/btclib-org/portanode --jq '.topics'
```

```json
["bitcoin","bitcoin-core","cross-platform","electrum","full-node","portable"]
```

The standard asks that a repository's topics and its package keywords
name the same things; there is no package here and so no keyword list to
agree with, which makes the topics a discoverability question rather than
an alignment one, and the six above are what answer it.
