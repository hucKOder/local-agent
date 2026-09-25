# Shell launchers for the two ways of working with omp.
# Source from ~/.bashrc:  source ~/.omp/agent/omp-modes.sh
# Principles: docs/omp/learn-or-delegate.md

# Learn mode: you write the code. The agent explains and gives hints, and
# asks before every edit and command.
omp-learn() {
  omp --approval-mode always-ask \
    --append-system-prompt "${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}/tutor.md" "$@"
}

# Delegate mode: an agent does one task in its own worktree, without asking.
#   omp-do <branch> "<task>"   headless: plan, implement, verify, stop
#   omp-do <branch>            interactive omp in the worktree
# The worktree is ../<repo>-<branch>, with "/" in the branch name as "-".
# OMP_DO_ROLE: role that implements a headless run (default: task).
# OMP_DO_TIME: time limit for a headless run (default: 20m).
omp-do() {
  if [ $# -lt 1 ]; then
    echo 'usage: omp-do <branch> ["<task>"]' >&2
    return 2
  fi
  local branch=$1
  shift
  local repo dir
  repo=$(git rev-parse --show-toplevel) || return 1
  dir="$(dirname "$repo")/$(basename "$repo")-${branch//\//-}"
  if [ ! -d "$dir" ]; then
    if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
      git -C "$repo" worktree add "$dir" "$branch" || return 1
    else
      git -C "$repo" worktree add "$dir" -b "$branch" || return 1
    fi
  fi
  if [ -f "$dir/pyproject.toml" ]; then
    (cd "$dir" && uv sync -q) || return 1
  fi
  if [ $# -eq 0 ]; then
    (cd "$dir" && omp --approval-mode yolo)
    return
  fi
  (cd "$dir" && omp -p --approval-mode yolo --max-time "${OMP_DO_TIME:-20m}" \
    --plan-yolo --plan-yolo-into "@${OMP_DO_ROLE:-task}" "$*" </dev/null)
  echo
  echo "Worktree: $dir"
  git -C "$dir" status --short
}
