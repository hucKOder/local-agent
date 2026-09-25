# Coding yourself with omp alongside

How to use omp as a pair programmer while you keep writing the code. The agent explains, scaffolds, writes tests and reviews; you own the design and the core logic.

Related: [feature-workflow.md](feature-workflow.md) for fully delegated features, [pr-and-review.md](pr-and-review.md) for PRs.

## Setup

### Run omp next to your editor

- Open a second terminal pane in the repo root (VS Code Remote-WSL terminal, tmux, or Windows Terminal split) and run `omp` there.
- Editors that speak the Agent Client Protocol (for example Zed) can run omp in the editor via `omp acp`.

### Make the agent ask before it acts

omp's default `tools.approvalMode` is `yolo`: every tool call runs without asking. When you share the working tree, lower it.

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

### Protect your work

- Commit or stash before you let the agent edit. `/branch`, `/fork` and the checkpoint tools rewind the conversation, never files.
- omp's system prompt treats unexpected repo changes as yours and adapts to them; it does not revert your edits. Still, tell it which files you are working in.

## Patterns

### Understand before you type

| Need | How |
|---|---|
| Where is X handled? | Ask in `/plan` mode (read-only), or run `omp find "<behavior>"` from the shell |
| Explain a function or package | Ask with a path: `explain @internal/api/router.go` |
| Quick fact, no tool calls | `/btw <question>` |
| See what a tool returns for a file or URL | `omp read <path-or-url>` |

`/plan` is the safest mode for pairing: the working tree is read-only and the agent cannot edit even if you ask.

### Split the work by file or layer

Give the agent scaffolding and tests, and keep the logic yourself:

```
In internal/api/ready.go create the handler signature, route registration and a
table test in ready_test.go with cases for 503 and 200. Leave the handler body as a
failing stub. Do not touch any other file. Do not run the test suite.
```

Then implement the body yourself and run the tests. The reverse also works: you write the tests, the agent implements until they pass.

Rules that keep the split clean:

- Name the files it may touch and the ones it must not.
- Say "do not run tests" when you are mid-edit, so it does not chase failures in your half-written code.
- One slice per prompt. Big mixed requests pull it into your files.

### Get feedback on your own code

| Need | How |
|---|---|
| Review what you just wrote | `/review` -> **2. Review uncommitted changes** |
| Review with a focus | `/review check error wrapping and context propagation` |
| Line-level notes on your diff | `/annotate code-review`, then pick local changes |
| Fix compiler/linter diagnostics you do not care to fix by hand | `/cleanse` (parallel subagents; it edits files) |

The reviewer reports only provable, patch-introduced bugs with P0-P3 priority. It skips style and pre-existing issues, so a clean review is not a design review.

### Let it take the boring parts

| Task | How |
|---|---|
| Rename across the codebase | Ask the agent; it uses LSP references (needs gopls) |
| Mechanical edits in files you are not in | Ask with explicit targets; it may route them to the cheap `sonic` agent |
| Commit message for your changes | `omp commit --dry-run`, then `omp commit` |
| Stage hunks by hand | `/git` or `omp git` |
| Side task while you keep coding | `/tan <request>`. It runs in the same directory; use `/wt` or `omp worktree add` if it must not touch your files |

### Switch between pairing and delegating

Nothing to reconfigure; switch per task:

1. Explore and design in `/plan`.
2. At plan review, pick **Save and quit** to keep the plan as your own checklist, or **Approve and execute** to hand it over.
3. Take over mid-way: `/pause`, edit, then tell the agent what changed: "I finished ready.go myself, continue with the test only."

## Models while pairing

| You ask for | Runs on |
|---|---|
| Questions, explanations, small edits | `default` -> grok-4.7:high (flat rate) |
| Fast lookups via scout | `smol` -> mimo-v2.6-flash (Go, cheap) |
| Commit messages | `commit` -> glm-5.3-flash (Go, cheap) |
| Reviews | `slow` -> grok-4.7:xhigh (flat rate) |

To answer faster on trivial questions, switch the session model with `/model @smol` (or alt+p), and back with `/model @default`.
