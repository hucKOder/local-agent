# PRs, MRs and code review with omp

How to review your own changes, open GitHub PRs or GitLab MRs, get CI green and review other people's changes in Python projects with omp.

Related: [feature-workflow.md](feature-workflow.md), [hands-on-coding.md](hands-on-coding.md).

## Platform support

omp has a native `github` tool. GitLab has no native tool; omp drives it through the `glab` CLI (omp already sets `GLAB_PAGER=cat` for non-interactive shells) and two custom commands in this repo: `/gl-review` and `/gl-green`.

| Task | GitHub | GitLab |
|---|---|---|
| Self-review against the base branch | `/review` -> **1** | `/review` -> **1** (local git, same flow) |
| Review a teammate's change | `/review <PR URL>` | `/gl-review <mr-iid> [focus]` |
| Open PR / MR | `github` `pr_create`, or `gh pr create` | `glab mr create`, or git push options |
| Check out into a worktree | `github` `pr_checkout` | done by `/gl-review`, or `refs/merge-requests/<iid>/head` |
| CI until green | `/green` | `/gl-green` |
| Read discussion | `pr://<N>` | `glab mr view <iid> --comments` |
| Post review | `gh pr review` | `glab mr note`, `glab mr approve` |

omp's web reader also opens public gitlab.com MR pages (description, status, comments). It does not reach self-managed instances or private projects; use `glab` for those.

## Setup

### GitHub

omp's `github` tool wraps the `gh` CLI. Without `gh`, PR review by URL, PR creation, PR checkout and `/green` do not work.

1. Install gh. Ubuntu 26.04 ships 2.46; the project's own apt repo (see the gh docs) has the latest. Switch to it if a `github` op fails on the older version:
   ```
   sudo apt install gh
   ```
2. Log in. The browser step opens on the host:
   ```
   gh auth login
   ```
3. Optional: let git push with the same login instead of a separate credential helper:
   ```
   gh auth setup-git
   ```

### GitLab

1. Install glab (1.53 on Ubuntu 26.04):
   ```
   sudo apt install glab
   ```
2. Log in. For a self-managed instance pass its hostname:
   ```
   glab auth login
   glab auth login --hostname gitlab.example.internal
   ```
   Accept the offer to set up git credentials, or keep your existing credential helper.
3. Install the GitLab commands from this repo:
   ```
   mkdir -p ~/.omp/agent/commands
   cp config/omp/commands/gl-*.md ~/.omp/agent/commands/
   ```
   For one project only, copy them to `<repo>/.omp/commands/` instead.

## How omp reviews

`/review` and `/gl-review` both dispatch the bundled `reviewer` subagents on the `slow` role (grok-4.7:xhigh).

### Targets

| Invocation | Reviews |
|---|---|
| `/review` -> **1. Review against a base branch (PR Style)** | Branch vs base, on any git host |
| `/review` -> **2. Review uncommitted changes** | Working tree |
| `/review` -> **3. Review a specific commit** | One commit |
| `/review` -> **4. Custom review instructions** | Free-form instructions |
| `/review https://github.com/<owner>/<repo>/pull/<N>` | A GitHub PR, read remotely via `pr://` (no checkout) |
| `/review pr://<owner>/<repo>/<N>` | Same, short form |
| `/gl-review <mr-iid> [focus]` | A GitLab MR in the current project: fetched into `../<repo>-mr-<iid>` as a worktree, diffed against its target branch |

`/review` accepts only github.com PR URLs; a GitLab MR URL is not recognised. Use `/gl-review` with the MR number (IID) instead.

Any extra words after the command become review instructions. Useful focuses for Python:

```
/review https://github.com/o/r/pull/12 focus on async cancellation and exception handling
/gl-review 87 check for mutable default arguments, unclosed resources and blocking calls in async code
```

### Reviewer count

`/review` scales reviewers with diff size. Every reviewer runs on Grok, and Grok takes 2 parallel requests, so large diffs queue. `/gl-review` caps itself at 4.

| Changed lines | Reviewers (`/review`) |
|---|---|
| < 100, or 2 files or fewer | 1 |
| < 500 | up to 2 |
| < 2000 | up to 4 |
| < 5000 | up to 8 |
| 5000+ | up to 16 |

`uv.lock` churn counts as changed lines. Review lockfile-only updates separately, or tell the reviewer to skip `uv.lock`. `/gl-review` skips lockfile hunks by default.

### What you get

- Findings: title, one-paragraph body (bug, trigger, impact), priority, confidence 0.0-1.0, file and line range inside the diff.
- Verdict: `correct` or `incorrect`, a 1-3 sentence explanation, confidence.
- `/gl-review` also lists which existing MR discussion threads the findings overlap.

| Priority | Meaning | Action |
|---|---|---|
| P0 | Blocks release: data corruption, auth bypass | Fix before merge |
| P1 | Fix next cycle: race under load | Fix before merge unless agreed otherwise |
| P2 | Edge case mishandling | Fix or file an issue |
| P3 | Suboptimal but correct | Optional |

### What it does not do

The reviewer reports only issues that are provable, actionable, unintentional and introduced by the patch. It ignores style, docs, nits and pre-existing bugs; leave style to ruff. It also traces every new type or message across module boundaries to the receiving code, which catches silently dropped events. A clean verdict is not a design or architecture review; that part stays with you.

For security-sensitive changes also run `/security`, which uses the read-only `security-reviewer` agent (CWE-tagged findings with evidence).

## Your own PR or MR

1. **Self-review against the target branch.** `/review` -> **1. Review against a base branch**, base `main`. Works the same on GitHub and GitLab. Fix P0/P1: "fix findings 1 and 2", or by hand.
2. **Run the gate.** `uv run pytest -q`, `uv run ruff check .`, `uv run ruff format --check .`, `uv run basedpyright`.
3. **Commit.** `omp commit --dry-run`, then `omp commit`. Add `--no-changelog` if the repo keeps no changelog. Commit `uv.lock` with `pyproject.toml`.
4. **Push and open it.** Ask omp: "push this branch and open a PR (or MR) against main with a summary, the reason, and the test commands you ran". Read the title and body before confirming. On GitHub omp uses `github` `pr_create`; on GitLab it runs `glab mr create`. Manual equivalents:
   ```
   # GitHub
   git push -u origin HEAD
   gh pr create --fill --base main

   # GitLab
   git push -u origin HEAD
   glab mr create --fill --target-branch main

   # GitLab, push and open the MR in one step (no glab needed)
   git push -u origin HEAD -o merge_request.create -o merge_request.target=main
   ```
5. **Get CI green.** `/green` on GitHub, `/gl-green` on GitLab. Both watch the pipeline for HEAD, read failing job logs, make a minimal fix, push, and repeat until the latest HEAD is green. Typical Python failures they handle: a test failing on another Python version in the matrix, ruff format drift, a missing dependency in `pyproject.toml`. They push commits on their own; use them only on your own branch. `/gl-green` retries a flaky job once and never loosens jobs or lint rules to get green.
6. **Address review comments.** GitHub: "Read `pr://<N>` and address the review comments". GitLab: "Run `glab mr view <iid> --comments` and address the open threads". Add "list what you changed and what you disagree with". Review the diff, commit, push.

## Someone else's PR or MR

1. **Review.**
   - GitHub: `/review https://github.com/<owner>/<repo>/pull/<N>` plus any focus. omp reads the diff through `pr://<owner>/<repo>/<N>/diff`, no checkout.
   - GitLab: `/gl-review <mr-iid>` plus any focus, run from your clone of the project. It fetches `refs/merge-requests/<iid>/head` into a separate worktree; your working tree and `.venv` stay untouched.
2. **Run it locally when the diff is not enough.**
   - GitHub: "check out PR <N>, run uv sync and the test suite". `github` `pr_checkout` creates a dedicated worktree.
   - GitLab: the `/gl-review` worktree is already there: `cd ../<repo>-mr-<iid> && uv sync && uv run pytest -q`.
   - Clean up: `omp worktree list` / `omp worktree clear` for GitHub checkouts, `git worktree remove ../<repo>-mr-<iid>` and `git branch -D mr-<iid>` for GitLab.
3. **Add your own judgement.** Design, naming, API shape, new dependencies and scope are not covered by the reviewer.
4. **Post the review yourself.** omp's findings stay local, and `/gl-review` never posts. Ask omp to draft the comment text, edit it, then post:
   ```
   # GitHub
   gh pr review <N> --comment --body-file review.md
   gh pr review <N> --request-changes --body-file review.md
   gh pr review <N> --approve

   # GitLab
   glab mr note <iid> -m "$(cat review.md)"
   glab mr approve <iid>
   ```
   Anything public goes out under your name, so you send it, not the agent. Line-anchored GitLab comments are easiest in the web UI; use the `file:line` references from the findings.

## Division of labour

| Step | omp | You |
|---|---|---|
| Find provable bugs in the diff | Yes | Spot-check P0/P1 |
| Style and formatting | No (ruff) | Keep ruff in CI |
| Design, scope, naming, new dependencies | No | Yes |
| Security scan | `/security` | Decide what ships |
| PR / MR text | Drafts | Approve and edit |
| CI fixes | `/green`, `/gl-green` on your branch | Watch pushes |
| Comments on others' changes | Drafts | Post |
| Merge | No | Yes |

## Client repositories

Reviews send the diff to the `xai-oauth` provider (Grok). Check the client's approval requirements before reviewing client code with omp.
