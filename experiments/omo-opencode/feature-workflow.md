# How to work on a new feature

Open OpenCode in the git repository that owns the feature. Plans are written to `.omo/plans/` in that repo.

Do not start feature code in `/home/huckoder/go-projects` unless the code lives there. This folder is not a git repository. Do not run `git init` here.

Use `xai/grok-4.7`. If a remembered in-app model overrides the session default, reselect it. Restart OpenCode only after a config edit.

## Path

1. Say `plan this: <feature>`. `make a plan` is the same request.
2. Answer only the questions the planner cannot settle from the code. Skipping a question accepts the recommended option.
3. Say okay when the brief matches what you want. Okay writes the plan. It does not start coding. The planner may still ask whether to start the work or review the plan first.
4. In a new session, say `/start-work <plan-name>`. That switches the session to Atlas and keeps going until the plan is finished.
5. Before you call the feature done, say `review work`.
6. If the session is getting long, say `/handoff`.
7. To stop a plan that is still running, say `/stop-continuation`. That also clears the plan's saved progress for this project.

`/start-work` is not a substitute for step 1. If no plan exists, it tells you to plan first.

## Flags

Add these to `/start-work` only when you want that effect.

| Flag | Effect |
| --- | --- |
| `--make-pr` | Open a pull request. Does not merge unless you ask. |
| `--ship` | Stay until that pull request is merged. Implies `--make-pr`. |
| `--worktree <path>` | Work in that worktree. Used alone, merges that branch into the current branch when the plan finishes. |

Use `--make-pr` when you do not want the automatic merge.

## Already decided

Say `ulw <feature>` or `ultrawork <feature>` when you already know the outcome and want this session to build it without stopping.

Do not use `ulw` in a planner session. Those agents strip it.

## Wrong spellings

| Do not type | Type instead | Why |
| --- | --- | --- |
| `/ulw` | `ulw` | A leading slash does not turn the mode on. |
| `$start-work` | `/start-work` | Does not switch the session to Atlas. |
| `/ulw-loop` | `/start-work` | Not a command on this install. `omo ulw-loop` is a Codex command. |
| `/goal` | `/start-work` | Does not keep this session going. Idle continuation for goals is off. |

## Who codes

| Work | Who |
| --- | --- |
| Coding and review | Sisyphus on `xai/grok-4.7` |
| A `/start-work` session | Atlas orchestrates. Sisyphus still writes the code. |
| Search, titles, writing | `opencode-go/glm-5.3-flash` |

Do not pick Hephaestus. He runs only on GPT, and no GPT provider is enabled. Selecting him shows an error and switches to Sisyphus without running his prompt.

One Grok coding agent runs at a time. Search can run in parallel.

Go, Python, Rust, and TypeScript work already follows tests first, strict types, and a 250-line file ceiling.

## Leave alone

- Do not edit routing files, add a provider, or pin another model as part of a feature.
- Do not rename this file to `AGENTS.md`.
- Do not run `/init-deep` unless you want `AGENTS.md` files in the feature repo.
