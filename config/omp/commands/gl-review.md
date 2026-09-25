---
description: Review a GitLab merge request in a separate worktree with reviewer agents
argument-hint: <mr-iid> [focus]
---
Review GitLab merge request !$1 in the current project, the same way `/review` reviews a branch.

1. Read the MR: `glab mr view $1 --comments`. Note the source branch, the target branch and open discussion threads.
2. Fetch it without touching the working tree. `refs/mr/$1` is force-updated and is not a branch, so a re-run after new pushes works:
   - `git fetch origin <target-branch>`
   - `git fetch origin "+refs/merge-requests/$1/head:refs/mr/$1"`
   - Worktree path `../$(basename "$PWD")-mr-$1`: if it exists, `git -C <path> checkout --detach refs/mr/$1`; otherwise `git worktree add --detach <path> refs/mr/$1`.
3. Changed files and diff come from the merge base: `git diff --stat origin/<target-branch>...refs/mr/$1` and `git diff origin/<target-branch>...refs/mr/$1`.
4. Dispatch `reviewer` agents with `task`. One reviewer under 100 changed lines or 2 files, otherwise up to 4, grouped by package or module with tests next to their implementation. Each reviewer gets its file list, the worktree path, and the diff command for its files.
5. Skip lockfile-only hunks (`uv.lock`, `poetry.lock`) unless the dependency change itself is the point of the MR.
6. When a finding needs proof, run the narrowest relevant test in the worktree after `uv sync`.
7. Report findings sorted by priority (P0 first) with `file:line`, then the overall verdict (correct or incorrect) with confidence, then which existing discussion threads the findings overlap.

Extra focus from the user (may be empty): $@[2]

Read-only toward GitLab: never commit, push, approve, or post notes on the MR. Leave the worktree in place; the user removes it with `git worktree remove <path>` and `git update-ref -d refs/mr/$1`.
