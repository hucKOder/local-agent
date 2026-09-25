# local-agent

A lightweight, token-saving setup for **oh-my-pi (omp)**, the terminal coding agent: model routing, fallbacks, concurrency limits, GitLab commands and workflow guides.

Two flat-rate subscriptions with separate usage pools. The `openai-codex` plan runs the interactive work: GPT-6 Astra for the main agent and plans, GPT-5.6 Luna for subagents, search and chores. The `xai-oauth` plan runs the roles that fan out or run in the background (`/review` reviewers, hard turns, advisor), and each subscription is the other's fallback when its pool runs out.

- **Humans:** start at [For humans](#for-humans).
- **Coding agents** asked to install this: follow [For agents](#for-agents).

## For humans

### Contents

| Path | Installs to | Purpose |
|---|---|---|
| `config/omp/config.yml` | `~/.omp/agent/config.yml` | Model roles, fallbacks, concurrency, compaction |
| `config/omp/commands/gl-review.md` | `~/.omp/agent/commands/` | `/gl-review <mr-iid>`: review a GitLab MR with reviewer agents |
| `config/omp/commands/gl-green.md` | `~/.omp/agent/commands/` | `/gl-green`: fix GitLab CI until the pipeline for HEAD passes |
| `config/omp/tutor.md` | `~/.omp/agent/tutor.md` | Tutor prompt for `omp-learn` |
| `config/shell/omp-modes.sh` | `~/.omp/agent/omp-modes.sh` | `omp-learn` and `omp-do` shell launchers; source it from `~/.bashrc` |
| `docs/omp/` | - | Workflow guides |
| `install.sh` | - | Installer for the config and the Python language servers |
| `experiments/omo-opencode/` | - | Earlier OpenCode + OMO experiment. Not installed, not maintained |

### Model routing

| omp role | Used for | Model | Fallback |
|---|---|---|---|
| `default` | Main agent | `openai-codex/gpt-6-astra` medium | `xai-oauth/grok-4.7` high |
| `plan` | Plan mode | `openai-codex/gpt-6-astra` medium | `xai-oauth/grok-4.7` high |
| `slow` | Hard turns (`/switch @slow`), `/review` reviewers | `xai-oauth/grok-4.7` xhigh | `openai-codex/gpt-5.6-luna` xhigh |
| `task` | Subagent workers | `openai-codex/gpt-5.6-luna` high | `xai-oauth/grok-4.7` high |
| `smol` | `scout` and `sonic` subagents, quick lookups | `openai-codex/gpt-5.6-luna` low | `xai-oauth/grok-4.7` low |
| `vision` | Image input | `openai-codex/gpt-5.6-terra` low | `xai-oauth/grok-4.7` low |
| `commit` | `omp commit`, chores | `openai-codex/gpt-5.6-luna` low | `xai-oauth/grok-4.7` low |
| `advisor` | Per-turn reviewer (off by default) | `xai-oauth/grok-4.7` medium | `openai-codex/gpt-5.6-luna` high |

Why this split: in the [Rails AI feature-ticket benchmark](https://rubyonrails.org/ai) GPT-6 Astra medium scored 35.0% in a 9m median run, Grok 4.7 high 31.7% in 22m. The `openai-codex` plan caps Astra at roughly 5-45 messages per 5 hours, so roles that start several agents at once (`/review`) or run on every turn (advisor) go to the separate `xai-oauth` pool.

Limits: 4 parallel `openai-codex` requests, 2 parallel `xai-oauth` requests, 4 concurrent subagents.

Approvals: `write` by default, so omp asks before shell commands. `omp-learn` uses `always-ask`; `omp-do` uses `yolo`, only inside its own worktree.

### Prerequisites

- Linux, macOS or WSL with bash and git.
- bun 1.3.14 or newer.
- omp: tested with 18.3.1 (`omp --version`). The launchers use `--approval-mode`, `--append-system-prompt` and `--max-time`.
- Subscriptions that support OAuth login for `openai-codex` and `xai-oauth`. With other providers, see [Adapt to your providers](#adapt-to-your-providers).
- For PR and MR work: `gh` for GitHub, `glab` for GitLab.
- For Python projects: uv. `install.sh` uses it to install the basedpyright and ruff language servers; pin ruff, basedpyright and pytest per project as dev dependencies (see [docs/omp/feature-workflow.md](docs/omp/feature-workflow.md#per-project)).

### Install

To let your coding agent do it, paste this prompt into it:

```
Install local-agent on this machine: clone <this-repo-url> and follow the
"For agents" section of its README.md.
```

It asks before it installs software, uses sudo, edits your shell rc or replaces your omp config, and it leaves the provider logins to you.

By hand:

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
   Files that differ are backed up as `<file>.bak.<timestamp>` before they are replaced. The installer also installs basedpyright and ruff with `uv tool install` when they are not on PATH, so omp has a Python language server even in projects without their own copy in `.venv`; `--no-lsp` skips this. `--link` symlinks instead of copying, so `git pull` updates your live config; `omp config set` and model-role changes made inside omp then edit the repo file. `PI_CODING_AGENT_DIR` moves the target directory.
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
   command -v basedpyright-langserver ruff
   ```
   If the last command does not print both paths, put uv's tool directory on PATH with `uv tool update-shell` and open a new shell.
5. Add the `omp-learn` and `omp-do` launchers to your shell (use `~/.zshrc` for zsh), then open a new shell:
   ```
   grep -qs omp-modes.sh ~/.bashrc || echo 'source ~/.omp/agent/omp-modes.sh' >> ~/.bashrc
   ```
   `install.sh` prints this reminder until the line is there. With `PI_CODING_AGENT_DIR` set, source `omp-modes.sh` from that directory instead.

### Adapt to your providers

`config/omp/config.yml` names models explicitly. Without the same subscriptions, change:

| Key | What to set |
|---|---|
| `enabledProviders` | The providers you are logged in to |
| `modelRoles` | One model per role; `provider/model:thinking` |
| `retry.fallbackChains` | Models to use while a primary is rate limited |
| `providers.maxInFlightRequests` | Parallel requests your plans allow per provider |

`omp models` lists the models your logins can reach. Keep your changes on a branch or in a fork so `git pull` stays clean.

### Update

```
git pull
./install.sh
```

### Guides

- [Learn or delegate](docs/omp/learn-or-delegate.md): when to write the code yourself and when to hand it to an agent, with the principles for each.
- [Feature workflow](docs/omp/feature-workflow.md): plan, implement, verify, review, commit. [Usage limits](docs/omp/feature-workflow.md#usage-limits) covers both usage pools and how to make the Astra window last.
- [Coding yourself with omp alongside](docs/omp/hands-on-coding.md): pairing without handing everything over.
- [PRs, MRs and code review](docs/omp/pr-and-review.md): GitHub and GitLab.

### Credentials

Never committed. omp keeps logins in `~/.omp/agent/agent.db`, outside the repo; `.gitignore` blocks `agent.db*` and `auth.json` in case they get copied in.

## For agents

You are a coding agent, and the person you work for wants local-agent installed on this machine: omp, this repo's omp config, the Python language servers and the `omp-learn` / `omp-do` shell launchers. Work through the steps below in order. Run the commands yourself, except where a step says the user runs them. The [For humans](#for-humans) section has the background, if you need it.

### Rules

- Ask the user before you install software, run anything with sudo, edit a shell rc file, or replace an omp config that holds settings of theirs.
- Provider logins are interactive OAuth in a browser, so the user runs `omp login` themselves. Tell them the exact command and wait until they confirm.
- Never read, print, copy or commit `~/.omp/agent/agent.db*` or `auth.json`. They hold the user's logins.
- Run `./install.sh --dry-run` before every real run, and show the user what it will change.
- Do not delete the `*.bak.<timestamp>` files the installer makes. They are the user's way back.
- Put config changes for other providers on a git branch, not on `main`.
- If a command fails, stop and report its output. Do not work around it.

### 1. Check the machine

```
uname -a; echo "$SHELL"
command -v git bash bun omp uv gh glab
bun --version; omp --version
ls -la "${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"
```

Note what is missing, what is older than the [prerequisites](#prerequisites), and whether `config.yml` already exists in the omp agent directory. That directory is `~/.omp/agent`, or `$PI_CODING_AGENT_DIR` when it is set; the commands below spell it out, because your shell may not keep variables between commands.

### 2. Install omp

Skip this step if `bun --version` prints 1.3.14 or newer and `omp --version` prints `omp/18.x`. Otherwise, with the user's OK:

```
curl -fsSL https://bun.sh/install | bash
export PATH="$HOME/.bun/bin:$PATH"
bun install -g @oh-my-pi/pi-coding-agent
omp --version
```

If omp is not 18.x, say so in your report: the config is tested with 18.3.1.

### 3. Get the repo

If the current directory has `install.sh` and `config/omp/config.yml`, use it. Otherwise ask the user for the repo URL and a target directory (default `~/local-agent`), then:

```
git clone <repo-url> ~/local-agent
cd ~/local-agent
```

### 4. Agree the plan with the user

Ask these in one message:

1. Do you have `openai-codex` and `xai-oauth` subscriptions? If not, which providers do you use? (Step 7 adapts the config.)
2. Copy the config (default), or symlink it with `--link` so `git pull` updates it?
3. Install the Python language servers basedpyright and ruff (default yes)? This needs uv. If uv is missing, the user installs it: see [feature-workflow.md, Per machine](docs/omp/feature-workflow.md#per-machine), which uses sudo.
4. May I add the `omp-learn` / `omp-do` launchers to your shell rc?

### 5. Install the config

```
./install.sh --dry-run [--link] [--no-lsp]
```

If the dry run shows `backup ... config.yml`, compare the two files before you go on:

```
diff "${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}/config.yml" config/omp/config.yml | grep '^<'
```

This prints the lines that are only in the live file, or have a different value there. The installed file replaces the live one completely. Keys that exist only in the live file (the user's own settings, or UI settings omp writes on first run, such as `theme` or `symbolPreset`) are then only in the backup. List those keys for the user and offer to add them back to the installed file afterwards.

Then run the same command without `--dry-run`. Output lines: `ok` means already in place, `backup` means the old file was moved aside, `copy` / `link` means installed, `install` means a uv tool was installed, and `next` is an action still to do.

### 6. Logins (the user runs these)

Ask the user to run these in their own terminal and to tell you when they are done:

```
omp login openai-codex
omp login xai-oauth
```

For other providers: `omp login <provider>`, or `omp login` to pick one from a list.

### 7. Adapt to other providers

Skip this step if the user has both `openai-codex` and `xai-oauth`. Otherwise:

```
git switch -c my-providers
omp models <provider>
```

Edit the keys listed in [Adapt to your providers](#adapt-to-your-providers) in `config/omp/config.yml`. Use only models that `omp models` lists. Where the user has two providers, keep each role's fallback on the other provider. Then rerun `./install.sh`. With `--link` the edit is already live.

### 8. Shell launchers

With the user's OK, for bash:

```
grep -qs omp-modes.sh ~/.bashrc || echo "source ${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}/omp-modes.sh" >> ~/.bashrc
```

For zsh, use `~/.zshrc` instead.

### 9. Verify

| Check | Command | Expected |
|---|---|---|
| omp | `omp --version` | `omp/18.x` |
| Roles | `omp config get modelRoles` | The roles from `config/omp/config.yml` |
| Models | `omp models <provider>`, once per provider | Every model named in `modelRoles` is listed |
| Language servers | `command -v basedpyright-langserver ruff` | Two paths |
| Launchers | `bash -ic 'type -t omp-learn omp-do'` (zsh: `zsh -ic`) | `function` twice |

If the language servers are installed but not on PATH, run `uv tool update-shell` and check again in a new shell.

### 10. Report

Tell the user:

- What you installed, with versions.
- Which files were installed, and the path of each backup.
- What is still open: logins, a new shell, PATH changes, and any checks that failed (with their output).
- How to start: `omp` in a project root, `omp-learn` to write the code yourself with hints, and `omp-do <branch> "<task>"` to delegate a task to its own worktree. Point them to [Guides](#guides).

### Troubleshooting

- **omp says "No language servers configured".** omp starts a language server only when the folder it was started in holds one of that server's marker files. It does not look in subfolders. It then looks for the server binary in the project first (`.venv/bin` for Python, `bin/` for Go), then on PATH.

  | Server | Marker files | Binary |
  |---|---|---|
  | basedpyright | `pyproject.toml`, `requirements.txt`, `setup.py`, `pyrightconfig.json` | `basedpyright-langserver` |
  | ruff | `pyproject.toml`, `ruff.toml`, `.ruff.toml` | `ruff` |
  | gopls | `go.mod`, `go.work`, `go.sum` | `gopls`: `go install golang.org/x/tools/gopls@latest` |

  omp detects servers once per session, so restart it after you add a marker file or install a server.
- **`bun` or `omp` not found after the install:** run `export PATH="$HOME/.bun/bin:$PATH"`, or open a new shell.
