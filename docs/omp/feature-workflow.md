# Feature workflow with omp

How to take a new feature from idea to a reviewed commit with oh-my-pi (omp 18.x) and the model routing in `config/omp/config.yml`.

Related: [hands-on-coding.md](hands-on-coding.md) when you write most of the code yourself, [pr-and-review.md](pr-and-review.md) for PRs and review.

## Who does what

| Phase | omp mechanism | Role -> model | Cost bucket |
|---|---|---|---|
| Plan | `/plan` mode, `scout` subagents | `plan` -> grok-4.7:high, `smol` -> mimo-v2.6-flash | Grok flat rate, Go (cheap) |
| Implement | main agent, `task` workers | `default` -> grok-4.7:high, `task` -> gpt-5.6-luna:high | Grok, Go (metered) |
| Hard problems | `ultrathink`, `slow` role | `slow` -> grok-4.7:xhigh | Grok |
| Review | `/review`, `reviewer` agent | `slow` -> grok-4.7:xhigh | Grok |
| Commit message | `omp commit` | `commit` -> glm-5.3-flash | Go (cheap) |

Limits that shape the flow: 2 parallel Grok requests, 4 parallel opencode-go requests, 4 concurrent subagents.

## One-time setup

### Per machine

1. Install gopls. omp's prompt requires LSP for definitions and references whenever a language server exists:
   ```
   go install golang.org/x/tools/gopls@latest
   ```
2. Log in once: `omp login xai-oauth`, then `omp login opencode-go`.
3. Optional: keep approved plans on disk. Add to `~/.omp/agent/config.yml`:
   ```yaml
   plan:
     autosave: true   # writes approved plans to <project>/.omp/plans/
   ```

### Per repository

1. Keep an `AGENTS.md` at the repo root with commands, architecture and conventions. omp loads it into every session. `demo-api/AGENTS.md` is the reference shape.
2. List the exact verification commands, for example:
   ```
   go test -race -shuffle=on -count=1 ./...
   go vet ./...
   golangci-lint run
   ```
3. Client repositories: code for clients such as T-Mobile CZ goes to xAI and OpenCode Go. Get PSA approval before using omp there.

## The flow

### 1. Branch

```
git switch -c feat/<short-name>
```

omp adapts to whatever branch you are on. For a second feature in parallel, use a worktree: `omp worktree add ../<repo>-<name> -b feat/<name>`, or `/wt` inside a running session.

### 2. Plan (read-only)

1. Start `omp` in the repo root and run `/plan`.
2. Describe the feature as outcome, constraints and acceptance:
   ```
   Add GET /v1/health/ready that returns 503 until config is loaded.
   Constraints: gin router in internal/api, slog only, no new deps.
   Done when: handler + table test, go test -race passes, curl shows 503 then 200.
   ```
3. The agent explores with `scout` subagents, asks 2-4 multiple-choice questions for real trade-offs, and writes `local://<slug>-plan.md`.
4. Answer the questions. Unanswered questions become recorded assumptions with the recommended default.

In plan mode the working tree is read-only: no edits, no `git commit`, no installs.

### 3. Review the plan

omp opens a plan review overlay. A good omp plan is decision-complete: a fresh agent could execute it with zero design choices left. Check:

- Every file, symbol and command it names exists (unconfirmed items are marked `unverified`).
- No open "either A or B" choices.
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

The main agent (Grok) works inline first and fans out only independent slices to `task` workers (gpt-5.6-luna, max 4 at once). Workers never run builds, linters or test suites mid-flight; the main agent verifies once after they land.

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

omp's system prompt refuses to finish non-trivial work without a smoke run ("Tests alone are not proof"). Expect it to run the AGENTS.md commands and exercise the changed path, for example start the server and `curl` the endpoint. If it reports done without showing that output, ask for it.

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

`omp commit` runs on the `commit` role (glm-5.3-flash). To stage hunks by hand, use `/git` or `omp git`.

### 9. PR

Continue with [pr-and-review.md](pr-and-review.md).

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
omp -p --plan-yolo --plan-yolo-into @default "Rename Config.Port to Config.HTTPPort everywhere" < /dev/null
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
