# OMO + OpenCode experiment

Not installed by `install.sh` and not maintained.

This is the OpenCode + oh-my-openagent (OMO) setup used to try out multi-agent orchestration concepts: named specialist agents, category routing, plan-review-execute pipelines. The lessons went into the lighter omp setup in `config/omp/`, which uses much smaller prompts (fewer tokens per turn) and is easier to customize.

| File | Was installed to |
|---|---|
| `opencode/opencode.jsonc` | `~/.config/opencode/opencode.jsonc` |
| `opencode/tui.json` | `~/.config/opencode/tui.json` |
| `omo/omo.jsonc` | `~/.omo/omo.jsonc` |

The model routing matches `config/omp/config.yml`: OMO sisyphus/atlas map to the omp `default` role, prometheus to `plan`, oracle to `slow`, sisyphus-junior to `task`, explore/librarian to `smol`, multimodal-looker to `vision`.
