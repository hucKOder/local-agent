# Learn or delegate

Two ways to work with omp. Pick one per task, and never run both in the same working tree.

| | Learn mode | Delegate mode |
|---|---|---|
| Who writes the code | You | An omp agent |
| Goal | Build skill | Get it done |
| Launcher | `omp-learn` | `omp-do <branch> ["<task>"]` |
| Where | Your working tree | Its own worktree, `../<repo>-<branch>` |
| Approvals | Every edit and command (`always-ask`) | None (`yolo`), only inside that worktree |
| Models | Astra explains; `/switch @smol` for quick facts | Astra plans, Luna (`@task`) implements |
| How-to | [hands-on-coding.md](hands-on-coding.md) | [feature-workflow.md](feature-workflow.md) |

## Pick the mode

Delegate only if all four are true. Otherwise, or when unsure, stay in learn mode.

1. You have written this kind of change yourself a few times, so there is nothing left to learn from it.
2. A command proves it is done: `uv run pytest -q`, ruff, basedpyright, or a CLI run with known output.
3. It fits in one prompt: outcome, constraints, files in scope, "done when".
4. It decides nothing: no design choice, public API, data model, security or client-specific logic.

| Usually delegate | Usually learn |
|---|---|
| Renames and moves across the codebase | A library, framework or language feature that is new to you |
| Type hints and docstrings for code you understand | Core domain logic |
| Tests for behaviour that already exists and works | An API, data model or module boundary |
| Lint, format and type-error cleanup | A bug you cannot explain yet |
| Dependency bumps where the tests stay green | Performance or concurrency work |
| CI fixes on your own branch (`/green`, `/gl-green`) | The first instance of a new pattern |
| Repeating a pattern you already wrote once | Anything you will have to defend in review |

Two rules for the grey zone:

- **First by hand, the rest by agent.** Write the first instance yourself, then delegate the others with a pointer to yours: "do the same for the other three clients, following `src/app/clients/github.py`".
- **Two strikes.** If a delegated task fails its gate twice, it was not mundane. Take it back into learn mode.

## Learn mode

`omp-learn` starts omp with `always-ask` and the tutor prompt (`config/omp/tutor.md`). The agent explains and gives hints instead of solutions, and asks before any edit or command.

1. **Try first.** Write a first version, or at least the plan as comments, before you ask. Ask when you have been stuck for 20-30 minutes.
2. **Ask for the smallest help.** Concept, then hint, then pseudocode, then a snippet for a similar case. Ask for the full solution only on purpose.
3. **You type what ships.** Do not paste agent code. If you cannot explain a line, it does not go in.
4. **You write the test cases.** They are where you decide the behaviour. Ask the agent which cases you missed.
5. **Explain it back.** When it works, explain your solution to the agent and ask what you missed.
6. **Review, then ask why.** `/review` -> **2. Review uncommitted changes**. For each finding, ask why before you fix it.
7. **Hand over only the chores around your code:** fixtures, boilerplate, the commit message, in files you name. See [Split the work by file or layer](hands-on-coding.md#split-the-work-by-file-or-layer).

## Delegate mode

`omp-do <branch> "<task>"` creates the worktree `../<repo>-<branch>` (or reuses it), runs `uv sync`, and runs omp headless with no approvals and a 20-minute limit: it plans, implements on `@task` (Luna) and verifies. `omp-do <branch>` without a task opens an interactive omp in the same worktree, for work that needs a plan you check first.

1. **Its own worktree, always.** No approvals only there, never in the tree you are typing in.
2. **One task, one prompt, a "done when".** Outcome, constraints, files in scope, and the commands that prove it is done. If you cannot write the "done when", it is not a delegate task.
3. **Pick the lightest path.**

   | Task | How |
   |---|---|
   | Mechanical, fits one prompt | `omp-do <branch> "<task>"` |
   | Several files, needs a plan you check | `omp-do <branch>`, then `/plan`, approve, `/review` |
   | CI red on your own branch | `/green` or `/gl-green` |

4. **Check the evidence, not every line.** The gate output, `git diff --stat` against the files you expected, and the `/review` verdict. Read the full diff when it touches a public API, security, or files outside the scope.
5. **You commit, push and merge.** Run `omp commit` in the worktree, then merge the branch yourself. Never delegate on a shared branch.
6. **Clean up after the merge:** `git worktree remove ../<repo>-<branch>` and `git branch -d <branch>`.

Example:

```
omp-do chore/http-port "Rename Settings.port to Settings.http_port everywhere, including tests and docs.
Do not change behaviour. Done when: uv run pytest -q, uv run ruff check . and uv run basedpyright pass."
```

`OMP_DO_ROLE=default omp-do ...` implements on Astra instead of Luna, for a task that is mechanical but large. `OMP_DO_TIME=40m` raises the time limit.

## Usage pools

| Work | Model | Why |
|---|---|---|
| Designing, planning, explaining | Astra (`default`, `plan`) | Best accuracy per minute |
| Mechanical implementation, lookups, commits | Luna (`task`, `smol`, `commit`) | A small fraction of an Astra message |
| Reviews | Grok (`slow`) | Separate pool; one review starts several agents |
| The hardest single turn | `/switch openai-codex/gpt-6-astra:max`, then `/switch @default` | Uses a large share of the window; pick it by hand |

Run `omp usage` before a large review or a long delegated run.

## Setup

1. `./install.sh` installs `tutor.md` and `omp-modes.sh` into `~/.omp/agent/`.
2. Add this line to `~/.bashrc`, then open a new shell:
   ```
   source ~/.omp/agent/omp-modes.sh
   ```
