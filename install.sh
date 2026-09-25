#!/usr/bin/env bash
# Install the omp config from this repo into the omp agent directory.
# Existing files that differ are backed up as <file>.bak.<timestamp> first.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install.sh [--link] [--no-lsp] [--dry-run]

Installs config/omp/config.yml, config/omp/tutor.md, config/omp/commands/*.md
and config/shell/omp-modes.sh into ${PI_CODING_AGENT_DIR:-~/.omp/agent}, then
installs the Python language servers basedpyright and ruff as uv tools when
they are not on PATH.
  --link     symlink instead of copy, so `git pull` updates the live config
  --no-lsp   skip the Python language servers
  --dry-run  print what would change, touch nothing
EOF
}

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
omp_dir="${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"
stamp="$(date +%Y%m%dT%H%M%S)"
mode=copy
dry=0
lsp=1

for arg in "$@"; do
  case "$arg" in
    --link) mode=link ;;
    --no-lsp) lsp=0 ;;
    --dry-run) dry=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

run() {
  if [ "$dry" -eq 1 ]; then echo "  would: $*"; else "$@"; fi
}

install_file() {
  local src="$repo/$1" dst="$2"
  if [ "$mode" = link ]; then
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
      echo "ok       $dst"; return
    fi
  elif [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$src" "$dst"; then
    echo "ok       $dst"; return
  fi
  run mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    echo "backup   $dst.bak.$stamp"
    run mv "$dst" "$dst.bak.$stamp"
  fi
  echo "$mode     $dst"
  if [ "$mode" = link ]; then run ln -s "$src" "$dst"; else run cp "$src" "$dst"; fi
}

# omp starts a language server from the project's .venv/bin first, then from
# PATH, so a uv tool covers Python projects that lack their own copy.
install_tool() {
  local pkg="$1" bin="$2" found
  if found="$(command -v "$bin")"; then
    echo "ok       $found"; return
  fi
  off_path=1
  if [ -x "$uv_bin/$bin" ]; then
    echo "ok       $uv_bin/$bin"; return
  fi
  echo "install  $pkg (uv tool)"
  run uv tool install "$pkg"
}

install_file config/omp/config.yml "$omp_dir/config.yml"
install_file config/omp/tutor.md "$omp_dir/tutor.md"
install_file config/shell/omp-modes.sh "$omp_dir/omp-modes.sh"
for f in "$repo"/config/omp/commands/*.md; do
  install_file "config/omp/commands/$(basename "$f")" "$omp_dir/commands/$(basename "$f")"
done

if [ "$lsp" -eq 1 ]; then
  if command -v uv >/dev/null; then
    uv_bin="$(uv tool dir --bin)"
    off_path=0
    install_tool basedpyright basedpyright-langserver
    install_tool ruff ruff
    if [ "$off_path" -eq 1 ] && [[ ":$PATH:" != *":$uv_bin:"* ]]; then
      echo
      echo "next     put $uv_bin on PATH so omp finds the language servers:"
      echo "         uv tool update-shell"
    fi
  else
    echo
    echo "next     install uv, then rerun ./install.sh for the Python language servers"
  fi
fi

if ! grep -qs omp-modes.sh "$HOME/.bashrc" "$HOME/.zshrc"; then
  echo
  echo "next     add the omp-learn and omp-do launchers to your shell rc:"
  echo "         source $omp_dir/omp-modes.sh"
fi
