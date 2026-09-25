# Feature workflow with omp

How to take a new feature in a Python project from idea to a reviewed commit with oh-my-pi (omp 18.x) and the model routing in `config/omp/config.yml`.

Related: [hands-on-coding.md](hands-on-coding.md) when you write most of the code yourself, [pr-and-review.md](pr-and-review.md) for GitHub PRs, GitLab MRs and review.

## Who does what

| Phase | omp mechanism | Role -> model | Usage pool |
|---|---|---|---|
| Plan | `/plan` mode, `scout` subagents | `plan` -> gpt-6-astra:medium, `smol` -> gpt-5.6-luna:low | `openai-codex` |
| Implement | main agent, `task` workers | `default` -> gpt-6-astra:medium, `task` -> gpt-5.6-luna:high | `openai-codex` |
| Hard problems | `ultrathink`, `slow` role | `slow` -> grok-4.7:xhigh | `xai-oauth` |
| Review | `/review`, `reviewer` agent | `slow` -> grok-4.7:xhigh | `xai-oauth` |
| Commit message | `omp commit` | `commit` -> gpt-5.6-luna:low | `openai-codex` |

## Usage limits

The two subscriptions have separate usage pools, and each is the other's fallback.

| Pool | Limit | Roles |
|---|---|---|
| `openai-codex` | A 5-hour window and a weekly cap, shared by all its models. GPT-6 Astra: roughly 5-45 messages per 5 hours. GPT-5.6 Luna: roughly 250-2,000 | `default`, `plan`, `task`, `smol`, `vision`, `commit` |
| `xai-oauth` | One weekly pool, no published numbers | `slow` (`/review` reviewers, `ultrathink`), `advisor` |

- A message is one prompt you send. Large context, long tool output and high effort use more of the window, which is why the range is wide.
- When a pool runs out, omp moves the affected roles to their fallback model and moves them back after the cooldown.
- `omp usage` (or `/usage` in a session) shows how much of each pool is left and when it resets. `omp usage --history --days 7` shows hourly snapshots, which tells you how fast a normal week drains each pool.
- Parallel requests: 4 on `openai-codex`, 2 on `xai-oauth`. At most 4 subagents run at once.

To make the Astra window last:

| Do | Why |
|---|---|
| Keep effort at medium; use `max` only for a single hard turn | Higher effort uses much more of the window |
| `/new` for each feature, `/handoff` when the context grows, `/shake` after heavy tool output | Every prompt resends the context |
| `/model @smol` for trivial questions, `/model @default` to go back | A Luna prompt costs a small fraction of an Astra prompt |
| `omp --prewalk --prewalk-into @task` for mechanical plans | Plans on Astra, implements on Luna |

## One-time setup

### Per machine

1. Install uv (the system Python has no pip by design):
   ```
   sudo apt install pipx
   pipx ensurepath
   pipx install uv
   ```
2. Log in once: `omp login openai-codex`, then `omp login xai-oauth`.
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
   - Prefer stdlib and framework built-ins over hand-rolled helpers; check the installed version's API before writing a utility.
   ```
3. Client code: sessions send code to the configured model providers (`openai-codex`, `xai-oauth`). Check the client's approval requirements before using omp on their repositories.

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

The main agent (GPT-6 Astra) works inline first and fans out only independent slices to `task` workers (gpt-5.6-luna, max 4 at once). Workers never run the test suite, linters or formatters mid-flight; the main agent runs them once after they land.

While it runs:

- Type to steer it. `/queue <msg>` holds a message until it yields.
- `/todo` shows progress, `/usage` shows provider usage and limits, `/pause` freezes all agents.
- Say `parallel` or `parallelize` to force subagent fan-out.
- Say `orchestrate` for large multi-phase work: decompose, dispatch, verify each phase, no early stop.
- Say `ultrathink` for a hard design or debugging turn (runs on the `slow` role, Grok xhigh). For the hardest turns switch to the strongest model with `/model openai-codex/gpt-6-astra:max`; it takes a large share of the `openai-codex` window.

For long autonomous work use goal mode instead of a plain prompt:

- `/guided-goal`: the agent interviews you, then sets the goal.
- `/goal`: toggle goal mode. The agent keeps working until every deliverable is verified against current repo state. A token budget can cap it; running out of budget never counts as done.

Saving the Astra window: prewalk switches models after the plan exists. `omp --prewalk --prewalk-into @task` plans on GPT-6 Astra and implements on gpt-5.6-luna. Use it for mechanical plans (renames, boilerplate, test scaffolding); Luna is much weaker than Astra on feature-sized work.

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

`/advisor` toggles a second model that reviews every agent turn while it works. It runs on Grok, off the `openai-codex` window, but uses one of the two Grok slots, so turn it on only for risky changes.

### 8. Commit

```
omp commit --dry-run     # preview message and changelog edits
omp commit               # commit
omp commit --no-changelog
```

`omp commit` runs on the `commit` role (gpt-5.6-luna:low). To stage hunks by hand, use `/git` or `omp git`. Commit `uv.lock` together with `pyproject.toml` when dependencies change.

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

`--plan-yolo` plans read-only, auto-approves, then implements. Without `--plan-yolo-into` it implements on the `smol` role (gpt-5.6-luna:low), which is too weak for anything but trivial edits. `< /dev/null` stops omp from waiting on stdin in scripts.
