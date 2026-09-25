# PRs and code review with omp

How to review your own changes, open PRs, get CI green and review other people's PRs in Python projects with omp.

Related: [feature-workflow.md](feature-workflow.md), [hands-on-coding.md](hands-on-coding.md).

## Setup

omp's `github` tool wraps the `gh` CLI. Without `gh`, PR review by URL, PR creation, PR checkout and CI watching do not work.

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

## How omp reviews

`/review` builds a review request from a diff and dispatches `reviewer` subagents on the `slow` role (grok-4.7:xhigh).

### Targets

| Invocation | Reviews |
|---|---|
| `/review` -> **1. Review against a base branch (PR Style)** | Branch vs base, what a PR would show |
| `/review` -> **2. Review uncommitted changes** | Working tree |
| `/review` -> **3. Review a specific commit** | One commit |
| `/review` -> **4. Custom review instructions** | Free-form instructions |
| `/review https://github.com/<owner>/<repo>/pull/<N>` | A remote PR, read via `pr://` (no checkout) |
| `/review pr://<owner>/<repo>/<N>` | Same, short form |

Any extra words after the command become review instructions. Useful focuses for Python:

```
/review https://github.com/o/r/pull/12 focus on async cancellation and exception handling
/review check for mutable default arguments, unclosed resources and blocking calls in async code
```

### Reviewer count

Scales with diff size. Every reviewer runs on Grok, and Grok takes 2 parallel requests, so large diffs queue.

| Changed lines | Reviewers |
|---|---|
| < 100, or 2 files or fewer | 1 |
| < 500 | up to 2 |
| < 2000 | up to 4 |
| < 5000 | up to 8 |
| 5000+ | up to 16 |

`uv.lock` churn counts as changed lines. Review lockfile-only updates separately, or tell the reviewer to skip `uv.lock`.

### What you get

- Findings: title, one-paragraph body (bug, trigger, impact), priority, confidence 0.0-1.0, file and line range inside the diff.
- Verdict: `correct` or `incorrect`, a 1-3 sentence explanation, confidence.

| Priority | Meaning | Action |
|---|---|---|
| P0 | Blocks release: data corruption, auth bypass | Fix before merge |
| P1 | Fix next cycle: race under load | Fix before merge unless agreed otherwise |
| P2 | Edge case mishandling | Fix or file an issue |
| P3 | Suboptimal but correct | Optional |

### What it does not do

The reviewer reports only issues that are provable, actionable, unintentional and introduced by the patch. It ignores style, docs, nits and pre-existing bugs; leave style to ruff. It also traces every new type or message across module boundaries to the receiving code, which catches silently dropped events. A clean verdict is not a design or architecture review; that part stays with you.

For security-sensitive changes also run `/security`, which uses the read-only `security-reviewer` agent (CWE-tagged findings with evidence).

## Your own PR

1. **Self-review against main.** `/review` -> **1. Review against a base branch**, base `main`. Fix P0/P1: "fix findings 1 and 2", or by hand.
2. **Run the gate.** `uv run pytest -q`, `uv run ruff check .`, `uv run ruff format --check .`, `uv run basedpyright`.
3. **Commit.** `omp commit --dry-run`, then `omp commit`. Add `--no-changelog` if the repo keeps no changelog. Commit `uv.lock` with `pyproject.toml`.
4. **Push and open the PR.** Ask: "push this branch and open a PR against main with a summary, the reason, and the test commands you ran". omp uses `github` `pr_create` (head defaults to the current branch). Read the title and body before confirming. Manual equivalent:
   ```
   git push -u origin HEAD
   gh pr create --fill --base main
   ```
5. **Get CI green.** `/green` watches the CI workflow runs for HEAD, reads failing job logs, makes a minimal fix, pushes, and repeats until the latest HEAD is green. Typical Python failures it handles: a test failing on another Python version in the matrix, ruff format drift, a missing dependency in `pyproject.toml`. It pushes commits on its own; use it only on your own branch.
6. **Address review comments.** "Read `pr://<N>` and address the review comments; list what you changed and what you disagree with." Review the diff, commit, push.

## Someone else's PR

1. **Remote review, no checkout.** `/review https://github.com/<owner>/<repo>/pull/<N>` plus any focus. omp reads the diff through `pr://<owner>/<repo>/<N>/diff`.
2. **Run it locally when the diff is not enough.** Ask: "check out PR <N>, run uv sync and the test suite". `github` `pr_checkout` creates a dedicated worktree and never touches your working tree or your `.venv`. Clean up later with `omp worktree list` and `omp worktree clear`.
3. **Add your own judgement.** Design, naming, API shape, new dependencies and scope are not covered by the reviewer.
4. **Post the review yourself.** omp's findings stay local. Ask it to draft the comment text, edit it, then post:
   ```
   gh pr review <N> --comment --body-file review.md
   gh pr review <N> --request-changes --body-file review.md
   gh pr review <N> --approve
   ```
   Anything public goes out under your name, so you send it, not the agent.

## Division of labour

| Step | omp | You |
|---|---|---|
| Find provable bugs in the diff | Yes | Spot-check P0/P1 |
| Style and formatting | No (ruff) | Keep ruff in CI |
| Design, scope, naming, new dependencies | No | Yes |
| Security scan | `/security` | Decide what ships |
| PR text | Drafts | Approve and edit |
| CI fixes | `/green` on your branch | Watch pushes |
| Comments on others' PRs | Drafts | Post |
| Merge | No | Yes |

## Client repositories

Reviews send the diff to the `xai-oauth` provider (Grok). Check the client's approval requirements before reviewing client code with omp.
