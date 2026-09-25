# local-agent

Shared configs for two terminal coding agents with one model routing:

- **OpenCode** with the **oh-my-openagent (OMO)** plugin
- **oh-my-pi (omp)**

Grok, on a flat-rate subscription, handles the main agent and the hard turns. Cheap models on a metered opencode-go allowance handle fan-out, subagents and chores, and are the only fallback targets when Grok is rate limited.

## Contents

| Path | Installs to | Purpose |
|---|---|---|
| `config/opencode/opencode.jsonc` | `~/.config/opencode/opencode.jsonc` | OpenCode: plugin, default models, providers, compaction |
| `config/opencode/tui.json` | `~/.config/opencode/tui.json` | OpenCode TUI |
| `config/omo/omo.jsonc` | `~/.omo/omo.jsonc` | OMO agents, categories, fallbacks, concurrency |
| `config/omp/config.yml` | `~/.omp/agent/config.yml` | omp model roles, fallbacks, concurrency |
| `config/omp/commands/*.md` | `~/.omp/agent/commands/` | omp slash commands `/gl-review`, `/gl-green` for GitLab |
| `docs/omp/` | - | Workflow guides for omp |
| `install.sh` | - | Installer |

## Model routing

| Work | OMO agent | omp role | Model |
|---|---|---|---|
| Main agent | sisyphus, atlas | `default` | `grok-4.7` high |
| Planning | prometheus | `plan` | `grok-4.7` high |
| Hard reasoning, review | oracle | `slow` | `grok-4.7` xhigh |
| Subagent workers | sisyphus-junior | `task` | `opencode-go/gpt-5.6-luna` high |
| Search, quick tasks | explore, librarian | `smol` | `opencode-go/mimo-v2.6-flash` |
| Images | multimodal-looker | `vision` | `grok-4.7` low |
| Commit messages, writing | writing category | `commit` | `opencode-go/glm-5.3-flash` |

Limits: 2 parallel Grok requests, 4 parallel opencode-go requests, 4 concurrent omp subagents.

## Prerequisites

- Linux, macOS or WSL with bash and git.
- A Grok subscription that supports OAuth login, and an OpenCode Go key. With other providers, see [Adapt to your providers](#adapt-to-your-providers).
- For omp: bun 1.3.14 or newer.
- For PR and MR work: `gh` for GitHub, `glab` for GitLab.
- For Python projects: uv, plus ruff, basedpyright and pytest as project dev dependencies (see [docs/omp/feature-workflow.md](docs/omp/feature-workflow.md)).

## Install

1. Install the agents you want:
   ```
   curl -fsSL https://bun.sh/install | bash
   bun install -g @oh-my-pi/pi-coding-agent      # omp
   curl -fsSL https://opencode.ai/install | bash  # OpenCode; OMO loads as a plugin from the config
   ```
2. Clone and install the configs:
   ```
   git clone <this-repo-url> local-agent
   cd local-agent
   ./install.sh --dry-run    # preview
   ./install.sh              # or: ./install.sh omp
   ```
   Files that differ are backed up as `<file>.bak.<timestamp>` before they are replaced. `--link` symlinks instead of copying, so `git pull` updates your live config; tools that write their own config (for example `omp config set`) then edit the repo file.
3. Log in:
   ```
   omp login xai-oauth
   omp login opencode-go
   opencode auth login        # pick the Grok and OpenCode Go providers
   ```
4. Check:
   ```
   omp config get modelRoles
   bunx oh-my-opencode doctor
   ```

## Adapt to your providers

The configs name models explicitly. Without the same subscriptions, change:

| Tool | File | Keys |
|---|---|---|
| omp | `config/omp/config.yml` | `enabledProviders`, `modelRoles`, `retry.fallbackChains`, `providers.maxInFlightRequests` |
| OMO | `config/omo/omo.jsonc` | `agents.*.model`, `agents.*.fallback_models`, `categories.*.model`, `background_task` |
| OpenCode | `config/opencode/opencode.jsonc` | `model`, `small_model`, `enabled_providers` |

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

Never committed. Logins live outside the repo: `~/.local/share/opencode/auth.json` (OpenCode) and `~/.omp/agent/agent.db` (omp). `.gitignore` blocks both names in case they get copied in.
