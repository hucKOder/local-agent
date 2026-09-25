# local-agent

A lightweight, token-saving setup for **oh-my-pi (omp)**, the terminal coding agent: model routing, fallbacks, concurrency limits, GitLab commands and workflow guides.

Two flat-rate subscriptions with separate usage pools. The `openai-codex` plan runs the interactive work: GPT-6 Astra for the main agent and plans, GPT-5.6 Luna for subagents, search and chores. The `xai-oauth` plan runs the roles that fan out or run in the background (`/review` reviewers, `ultrathink`, advisor), and each subscription is the other's fallback when its pool runs out.

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

| omp role | Used for | Model | Fallback |
|---|---|---|---|
| `default` | Main agent | `openai-codex/gpt-6-astra` medium | `xai-oauth/grok-4.7` high |
| `plan` | Plan mode | `openai-codex/gpt-6-astra` medium | `xai-oauth/grok-4.7` high |
| `slow` | Hard reasoning, `ultrathink`, `/review` reviewers | `xai-oauth/grok-4.7` xhigh | `openai-codex/gpt-6-astra` max |
| `task` | Subagent workers | `openai-codex/gpt-5.6-luna` high | `xai-oauth/grok-4.7` high |
| `smol` | `scout` and `sonic` subagents, quick lookups | `openai-codex/gpt-5.6-luna` low | `xai-oauth/grok-4.7` low |
| `vision` | Image input | `openai-codex/gpt-5.6-terra` low | `xai-oauth/grok-4.7` low |
| `commit` | `omp commit`, chores | `openai-codex/gpt-5.6-luna` low | `xai-oauth/grok-4.7` low |
| `advisor` | Per-turn reviewer (off by default) | `xai-oauth/grok-4.7` medium | `openai-codex/gpt-5.6-luna` high |

Why this split: in the [Rails AI feature-ticket benchmark](https://rubyonrails.org/ai) GPT-6 Astra medium scored 35.0% in a 9m median run, Grok 4.7 high 31.7% in 22m. The `openai-codex` plan caps Astra at roughly 5-45 messages per 5 hours, so roles that start several agents at once (`/review`) or run on every turn (advisor) go to the separate `xai-oauth` pool.

Limits: 4 parallel `openai-codex` requests, 2 parallel `xai-oauth` requests, 4 concurrent subagents.

## Prerequisites

- Linux, macOS or WSL with bash and git.
- bun 1.3.14 or newer.
- Subscriptions that support OAuth login for `openai-codex` and `xai-oauth`. With other providers, see [Adapt to your providers](#adapt-to-your-providers).
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
   omp login openai-codex
   omp login xai-oauth
   ```
4. Check:
   ```
   omp config get modelRoles
   omp models openai-codex
   omp models xai-oauth
   ```

## Adapt to your providers

`config/omp/config.yml` names models explicitly. Without the same subscriptions, change:

| Key | What to set |
|---|---|
| `enabledProviders` | The providers you are logged in to |
| `modelRoles` | One model per role; `provider/model:thinking` |
| `retry.fallbackChains` | Models to use while a primary is rate limited |
| `providers.maxInFlightRequests` | Parallel requests your plans allow per provider |

`omp models` lists the models your logins can reach. Keep your changes on a branch or in a fork so `git pull` stays clean.

## Update

```
git pull
./install.sh
```

## Guides

- [Feature workflow](docs/omp/feature-workflow.md): plan, implement, verify, review, commit. [Usage limits](docs/omp/feature-workflow.md#usage-limits) covers both usage pools and how to make the Astra window last.
- [Coding yourself with omp alongside](docs/omp/hands-on-coding.md): pairing without handing everything over.
- [PRs, MRs and code review](docs/omp/pr-and-review.md): GitHub and GitLab.

## Credentials

Never committed. omp keeps logins in `~/.omp/agent/agent.db`, outside the repo; `.gitignore` blocks `agent.db*` and `auth.json` in case they get copied in.
