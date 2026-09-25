# local-agent

A lightweight, token-saving setup for **oh-my-pi (omp)**, the terminal coding agent: model routing, fallbacks, concurrency limits, GitLab commands and workflow guides.

Grok, on a flat-rate subscription, handles the main agent and the hard turns. Cheap models on a metered `opencode-go` allowance handle subagents, search and chores, and are the only fallback targets when Grok is rate limited.

## Contents

| Path | Installs to | Purpose |
|---|---|---|
| `config/omp/config.yml` | `~/.omp/agent/config.yml` | Model roles, fallbacks, concurrency, compaction |
| `config/omp/commands/gl-review.md` | `~/.omp/agent/commands/` | `/gl-review <mr-iid>`: review a GitLab MR with reviewer agents |
| `config/omp/commands/gl-green.md` | `~/.omp/agent/commands/` | `/gl-green`: fix GitLab CI until the pipeline for HEAD passes |
| `docs/omp/` | - | Workflow guides |
| `install.sh` | - | Installer |
| `experiments/omo-opencode/` | - | Earlier OpenCode + OMO experiment. Not installed, not maintained |

## Model routing

| omp role | Used for | Model |
|---|---|---|
| `default` | Main agent | `xai-oauth/grok-4.7` high |
| `plan` | Plan mode | `xai-oauth/grok-4.7` high |
| `slow` | Hard reasoning, `ultrathink`, `/review` reviewers | `xai-oauth/grok-4.7` xhigh |
| `task` | Subagent workers | `opencode-go/gpt-5.6-luna` high |
| `smol` | `scout` and `sonic` subagents, quick lookups | `opencode-go/mimo-v2.6-flash` |
| `vision` | Image input | `xai-oauth/grok-4.7` low |
| `commit` | `omp commit`, chores | `opencode-go/glm-5.3-flash` |
| `advisor` | Per-turn reviewer (off by default) | `xai-oauth/grok-4.7` medium |

Limits: 2 parallel Grok requests, 4 parallel opencode-go requests, 4 concurrent subagents.

## Prerequisites

- Linux, macOS or WSL with bash and git.
- bun 1.3.14 or newer.
- A Grok subscription that supports OAuth login (`xai-oauth`) and an `opencode-go` gateway key. With other providers, see [Adapt to your providers](#adapt-to-your-providers).
- For PR and MR work: `gh` for GitHub, `glab` for GitLab.
- For Python projects: uv, plus ruff, basedpyright and pytest as project dev dependencies (see [docs/omp/feature-workflow.md](docs/omp/feature-workflow.md)).

## Install

1. Install omp:
   ```
   curl -fsSL https://bun.sh/install | bash
   bun install -g @oh-my-pi/pi-coding-agent
   ```
2. Clone and install the config:
   ```
   git clone <this-repo-url> local-agent
   cd local-agent
   ./install.sh --dry-run    # preview
   ./install.sh
   ```
   Files that differ are backed up as `<file>.bak.<timestamp>` before they are replaced. `--link` symlinks instead of copying, so `git pull` updates your live config; `omp config set` and model-role changes made inside omp then edit the repo file. `PI_CODING_AGENT_DIR` moves the target directory.
3. Log in:
   ```
   omp login xai-oauth
   omp login opencode-go
   ```
4. Check:
   ```
   omp config get modelRoles
   omp models xai-oauth
   omp models opencode-go
   ```

## Adapt to your providers

`config/omp/config.yml` names models explicitly. Without the same subscriptions, change:

| Key | What to set |
|---|---|
| `enabledProviders` | The providers you are logged in to |
| `modelRoles` | One model per role; `provider/model:thinking` |
| `retry.fallbackChains` | Cheaper models to use while a primary is rate limited |
| `providers.maxInFlightRequests` | Parallel requests your plans allow per provider |

`omp models` lists the models your logins can reach. Keep your changes on a branch or in a fork so `git pull` stays clean.

## Update

```
git pull
./install.sh
```

## Guides

- [Feature workflow](docs/omp/feature-workflow.md): plan, implement, verify, review, commit.
- [Coding yourself with omp alongside](docs/omp/hands-on-coding.md): pairing without handing everything over.
- [PRs, MRs and code review](docs/omp/pr-and-review.md): GitHub and GitLab.

## Credentials

Never committed. omp keeps logins in `~/.omp/agent/agent.db`, outside the repo; `.gitignore` blocks `agent.db*` and `auth.json` in case they get copied in.
