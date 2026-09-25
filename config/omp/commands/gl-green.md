---
description: Iterate on GitLab CI failures until the pipeline for HEAD passes
---
<critical>
MUST continue until the latest GitLab pipeline for the current branch HEAD succeeds. NEVER stop after one fix attempt.
</critical>

Use `glab` for pipelines and job logs. The pipeline for the current HEAD commit is the only source of truth.

1. Record `git branch --show-current` and `git rev-parse HEAD`.
2. `glab ci status` shows the latest pipeline for the branch. Confirm its commit matches HEAD; if the pipeline is still running, wait and re-check (`glab ci status --live` streams until it finishes).
3. Pipeline failed: list the failed jobs and read each log with `glab ci trace <job-id>`.
4. Find the root cause and make the minimal correct fix. Before pushing, run the matching local check when it lowers the chance of another failed pipeline, for example `uv run pytest -q`, `uv run ruff check .`, `uv run ruff format --check .`, `uv run basedpyright`.
5. Commit with a focused message and `git push`.
6. A push starts a new pipeline: go back to step 1 for the new HEAD.

<caution>
- A job that fails without a code-related cause (runner, network, timeout): `glab ci retry <job-id>` once. If it fails again, treat it as a real failure.
- NEVER skip, disable, or loosen jobs, tests, or lint rules to get green. Edit `.gitlab-ci.yml` only when the pipeline definition itself is the bug.
- NEVER force-push.
</caution>

<critical>
Complete only when the latest pipeline for the latest HEAD commit succeeds. Report the pipeline ID and every fix commit.
</critical>
