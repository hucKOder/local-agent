# Coding yourself with omp alongside

How to use omp as a pair programmer on a Python project while you keep writing the code. This is learn mode from [learn-or-delegate.md](learn-or-delegate.md): the agent explains, scaffolds and reviews; you own the design, the core logic and the test cases.

Related: [learn-or-delegate.md](learn-or-delegate.md) for when to code yourself and when to delegate, [feature-workflow.md](feature-workflow.md) for fully delegated features and project setup, [pr-and-review.md](pr-and-review.md) for GitHub PRs and GitLab MRs.

## Setup

### Run omp next to your editor

- Open a second terminal pane in the repo root (your editor's terminal or tmux) and run `omp-learn` there ([setup](learn-or-delegate.md#setup)). It starts omp with `always-ask` and the tutor prompt.
- Editors that support the Agent Client Protocol can run omp inside the editor via `omp acp`.
- Have `basedpyright` and `ruff` in the project `.venv` (see [feature-workflow.md](feature-workflow.md#per-project)). Without a language server omp falls back to text search for renames and references.

### Make the agent ask before it acts

omp's own default `tools.approvalMode` is `yolo`: every tool call runs without asking. This config sets `write` globally, `omp-learn` uses `always-ask`, and `omp-do` uses `yolo` only inside its own worktree.

| Mode | Auto-approved | Asks for | Use when |
|---|---|---|---|
| `always-ask` | read-only tools | every edit and command | You type the code; omp only suggests |
| `write` | reads and workspace edits | shell commands and anything else | omp may edit files you assigned to it |
| `yolo` | everything | nothing | Fully delegated work only |

Per session:

```
omp --approval-mode always-ask
```

Per repository, in `<repo>/.omp/config.yml`:

```yaml
tools:
  approvalMode: write
  approval:
    bash: prompt
```

With `write`, the agent still asks before `uv add`, `pip install` or any other command that changes the environment.

### Protect your work

- Commit or stash before you let the agent edit. `/branch`, `/fork` and the checkpoint tools rewind the conversation, never files.
- omp's system prompt treats unexpected repo changes as yours and adapts to them; it does not revert your edits. Still, tell it which files you are working in.

## Patterns

### Understand before you type

| Need | How |
|---|---|
| Where is X handled? | Ask in `omp-learn`, or run `omp find "<behavior>"` from the shell |
| Explain a module or function | Ask with a path: `explain @src/app/client.py` |
| Quick fact, no tool calls | `/btw <question>`. It sends the whole session context to the session model, so on Astra it costs about as much as a normal prompt |
| Try a snippet against your code | Ask it to run it in its Python eval kernel; the kernel uses the project `.venv`, so `import app` works |
| See what a tool returns for a file or URL | `omp read <path-or-url>` |

`/plan` blocks file writes and edits, but not shell commands, and it keeps steering the agent toward a plan. Use it to design a change, not to ask questions; `omp-learn` is the safe mode for questions.

### Split the work by file or layer

Give the agent the scaffolding; keep the logic and the test cases yourself:

```
In src/app/client.py add a `retries: int = 3` parameter to ApiClient.get and a
_backoff_delays(retries) helper whose body raises NotImplementedError. In
tests/conftest.py add a fake transport fixture that fails a configurable number
of times before it succeeds. Do not touch any other file. Do not run the test suite.
```

Then write the test cases in `tests/test_client.py`, implement the bodies yourself and run `uv run pytest -q`. The reverse, where you write the tests and the agent implements until they pass, is delegate mode: use it only for code you already know how to write.

Rules that keep the split clean:

- Name the files it may touch and the ones it must not.
- Say "do not run tests" when you are mid-edit, so it does not chase failures in your half-written code.
- Say whether it may add dependencies. Otherwise it may reach for a library you do not want in `pyproject.toml`.
- One slice per prompt. Big mixed requests pull it into your files.

### Get feedback on your own code

| Need | How |
|---|---|
| Review what you just wrote | `/review` -> **2. Review uncommitted changes** |
| Review with a focus | `/review check exception handling and async cancellation` |
| Go through changes line by line, including the agent's | `/annotate code-review`, then pick local changes. You mark lines with your own notes and questions, then send them to a reviewer or paste them into the prompt |
| Fix lint and type errors you do not care to fix by hand | `/cleanse`. It runs ruff, basedpyright only when the repo has a `pyrightconfig.json`, and pytest only with `--tests`, then fixes findings with parallel subagents on the `smol` model; it edits files |

The reviewer reports only provable, patch-introduced bugs with P0-P3 priority. It skips style and pre-existing issues, so a clean review is not a design review.

### Let it take the chores

| Task | How |
|---|---|
| Rename across the codebase | Ask the agent; it uses LSP references from basedpyright |
| Add type hints to a module you understand | Ask with the module path, then run `uv run basedpyright` |
| Mechanical edits in files you are not in | Ask with explicit targets; it may route them to the cheap `sonic` agent |
| Commit message for your changes | Stage first, then `omp commit --dry-run` and `omp commit`. With nothing staged, even `--dry-run` stages all changes |
| Stage hunks by hand | `/git` or `omp git` |
| Side task while you keep coding | `omp-do <branch> "<task>"` in another pane. `/tan <request>` is only for questions or files you are not in: it runs with no approvals, on the session model, in your working tree |

### Switch between pairing and delegating

Nothing to reconfigure; switch per task. For a whole task, use `omp-do` instead (see [learn-or-delegate.md](learn-or-delegate.md#delegate-mode)).

1. Explore and design in `/plan`.
2. At plan review, pick **Save and quit** to keep the plan as your own checklist, or **Approve and execute** to hand it over.
3. Take over mid-way: `/pause`, edit, then tell the agent what changed: "I finished client.py myself, continue with the tests only."

## Models while pairing

| You ask for | Runs on |
|---|---|
| Questions, explanations, small edits | `default` -> gpt-6-astra:medium (`openai-codex`) |
| Fast lookups via scout | `smol` -> gpt-5.6-luna:low (`openai-codex`, cheap) |
| Commit messages | `commit` -> gpt-5.6-luna:low (`openai-codex`, cheap) |
| Reviews | `slow` -> grok-4.7:xhigh (`xai-oauth`) |

Pairing means many short prompts, and each one counts against the Astra window (roughly 5-45 messages per 5 hours, see [feature-workflow.md](feature-workflow.md#usage-limits)). For trivial questions switch the session model with `/switch @smol` (or alt+p), and back with `/switch @default`. It answers faster too. `/model` takes no argument: `/model @smol` is sent to the model as a normal prompt.
