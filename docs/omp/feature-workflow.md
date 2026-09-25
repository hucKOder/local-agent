# Feature workflow with omp

How to take a new feature in a Python project from idea to a reviewed commit with oh-my-pi (omp 18.x) and the model routing in `config/omp/config.yml`.

Related: [hands-on-coding.md](hands-on-coding.md) when you write most of the code yourself, [pr-and-review.md](pr-and-review.md) for GitHub PRs, GitLab MRs and review.

## Who does what

| Phase | omp mechanism | Role -> model | Cost bucket |
|---|---|---|---|
| Plan | `/plan` mode, `scout` subagents | `plan` -> grok-4.7:high, `smol` -> mimo-v2.6-flash | Grok flat rate, opencode-go (cheap) |
| Implement | main agent, `task` workers | `default` -> grok-4.7:high, `task` -> gpt-5.6-luna:high | Grok, opencode-go (metered) |
| Hard problems | `ultrathink`, `slow` role | `slow` -> grok-4.7:xhigh | Grok |
| Review | `/review`, `reviewer` agent | `slow` -> grok-4.7:xhigh | Grok |
| Commit message | `omp commit` | `commit` -> glm-5.3-flash | opencode-go (cheap) |

Limits that shape the flow: 2 parallel Grok requests, 4 parallel opencode-go requests, 4 concurrent subagents.

## One-time setup

### Per machine

1. Install uv (the system Python has no pip by design):
   ```
   sudo apt install pipx
   pipx ensurepath
   pipx install uv
   ```
2. Log in once: `omp login xai-oauth`, then `omp login opencode-go`.
3. Optional: keep approved plans on disk. Add to `~/.omp/agent/config.yml`:
   ```yaml
   plan:
     autosave: true   # writes approved plans to <project>/.omp/plans/
   ```

### Per project

1. Add the dev tools to the project, so everyone uses the same versions:
   ```
   uv add --dev ruff basedpyright pytest
   uv sync
   ```
   omp looks for language servers in `.venv/bin`. With `basedpyright` there it gets go-to-definition, references and safe renames; with `ruff` it gets lint diagnostics after each write. omp's prompt requires LSP for code navigation whenever a server is available. omp also supports `pyright`, `pylsp` and `ty` as language servers.
2. Keep an `AGENTS.md` at the repo root. omp loads it into every session:
   ```markdown
   # AGENTS.md

   Python 3.13 service, src layout, managed with uv.

   ## Commands

   - `uv sync` - install
   - `uv run pytest -q` - tests
   - `uv run ruff check . && uv run ruff format --check .` - lint and format
   - `uv run basedpyright` - type check

   ## Architecture

   - `src/app/cli.py` - entry point
   - `src/app/client.py` - HTTP client
   - `tests/` - pytest, mirrors src/

   ## Conventions

   - Type hints on all public functions.
   - `logging` only, no `print`.
   - Raise specific exceptions; never bare `except:`.
   ```
3. Client code: sessions send code to the configured model providers (`xai-oauth`, `opencode-go`). Check the client's approval requirements before using omp on their repositories.

## The flow

### 1. Branch

```
git switch -c feat/<short-name>
```

omp adapts to whatever branch you are on. For a second feature in parallel, use a worktree: `omp worktree add ../<repo>-<name> -b feat/<name>`, or `/wt` inside a running session. A new worktree has no `.venv`; run `uv sync` in it first.

### 2. Plan (read-only)

1. Start `omp` in the repo root and run `/plan`.
2. Describe the feature as outcome, constraints and acceptance:
   ```
   Add retries with exponential backoff to ApiClient.get in src/app/client.py.
   Constraints: stdlib only, keep the sync API, log retries via logging at WARNING.
   Done when: pytest cases with a fake transport cover success after 2 retries and
   giving up after 3 attempts; uv run pytest, ruff and basedpyright are clean.
   ```
3. The agent explores with `scout` subagents, asks 2-4 multiple-choice questions for real trade-offs, and writes `local://<slug>-plan.md`.
4. Answer the questions. Unanswered questions become recorded assumptions with the recommended default.

In plan mode the working tree is read-only: no edits, no `git commit`, no `uv add`.

### 3. Review the plan

omp opens a plan review overlay. A good omp plan is decision-complete: a fresh agent could execute it with zero design choices left. Check:

- Every module, function and command it names exists (unconfirmed items are marked `unverified`).
- No open "either A or B" choices, for example sync vs async, or which exception type to raise.
- Verification steps are concrete commands with expected output.

Annotate sections or open the plan in your editor, then pick **Refine plan** until it is right.

### 4. Approve

| Choice | Use when |
|---|---|
| Approve and execute | Default for real features. Execution starts from the plan with a fresh context. |
| Approve and compact context | Planning found things worth keeping, but the context is large. |
| Approve and keep context | Small feature, short planning session. |
| Refine plan | Anything is still open. |
| Save and quit | Execute later or in another session. Prompts for a path and writes the plan there. |

### 5. Implement

The main agent (Grok) works inline first and fans out only independent slices to `task` workers (gpt-5.6-luna, max 4 at once). Workers never run the test suite, linters or formatters mid-flight; the main agent runs them once after they land.

While it runs:

- Type to steer it. `/queue <msg>` holds a message until it yields.
- `/todo` shows progress, `/usage` shows provider usage and limits, `/pause` freezes all agents.
- Say `parallel` or `parallelize` to force subagent fan-out.
- Say `orchestrate` for large multi-phase work: decompose, dispatch, verify each phase, no early stop.
- Say `ultrathink` for a hard design or debugging turn (maximum thinking; Grok caps at xhigh).

For long autonomous work use goal mode instead of a plain prompt:

- `/guided-goal`: the agent interviews you, then sets the goal.
- `/goal`: toggle goal mode. The agent keeps working until every deliverable is verified against current repo state. A token budget can cap it; running out of budget never counts as done.

Cheaper execution: prewalk switches models after the plan exists. `omp --prewalk --prewalk-into @task` plans on Grok and implements on gpt-5.6-luna.

### 6. Verify

omp's system prompt refuses to finish non-trivial work without a smoke run ("Tests alone are not proof"). Expect it to run the AGENTS.md commands and exercise the changed path directly: run the CLI, or import the module and call the function. omp's Python eval kernel uses the project `.venv` automatically, so it can import your package without extra setup. If it reports done without showing that output, ask for it.

Typical gate for a Python change:

```
uv run pytest -q
uv run ruff check . && uv run ruff format --check .
uv run basedpyright
```

### 7. Review

1. `/review` -> **2. Review uncommitted changes**.
2. Reviewer agents (Grok xhigh) report findings with priority P0-P3, confidence and line ranges, plus an overall verdict.
3. Fix P0/P1 before committing: "fix findings 1 and 3", or fix them yourself.

`/advisor` toggles a second model that reviews every agent turn while it works. It runs on Grok and uses one of the two Grok slots, so turn it on only for risky changes.

### 8. Commit

```
omp commit --dry-run     # preview message and changelog edits
omp commit               # commit
omp commit --no-changelog
```

`omp commit` runs on the `commit` role (glm-5.3-flash). To stage hunks by hand, use `/git` or `omp git`. Commit `uv.lock` together with `pyproject.toml` when dependencies change.

### 9. PR or MR

Continue with [pr-and-review.md](pr-and-review.md). It covers GitHub (native `github` tool, `/green`) and GitLab (`glab`, `/gl-review`, `/gl-green`).

## Session hygiene

| Situation | Command |
|---|---|
| New feature | `/new` (one session per feature) |
| Context getting long | `/handoff` (summary document, compacts in place) |
| Drop heavy tool output | `/shake` |
| Quick question, no tools | `/btw <question>` |
| Tangent while the agent keeps working | `/tan <request>` (background agent, same directory) |
| Resume yesterday's work | `omp -c` or `/resume` |
| Try another approach from an earlier message | `/branch`, `/fork`, `/tree` |

`/branch` and `/fork` rewind the conversation, not files. Use git to undo file changes.

## Headless one-shot

For small, well-specified changes without the TUI:

```
omp -p --plan-yolo --plan-yolo-into @default "Rename Settings.port to Settings.http_port everywhere, including tests" < /dev/null
```

`--plan-yolo` plans read-only, auto-approves, then implements. Without `--plan-yolo-into` it implements on the `smol` role (mimo-v2.6-flash). `< /dev/null` stops omp from waiting on stdin in scripts.

## Coming from the OMO workflow

| OMO (OpenCode) | omp |
|---|---|
| `plan this: <feature>`, Prometheus interview | `/plan`, questions via the ask tool; `/guided-goal` for a longer interview |
| Momus plan review | Plan review overlay (you), **Refine plan** |
| `/start-work <plan>`, Atlas | **Approve and execute**; `/goal` for autonomous runs |
| `review work` | `/review` |
| `/handoff` | `/handoff` |
| `/stop-continuation` | `/goal` (toggle off) or `/pause` |
