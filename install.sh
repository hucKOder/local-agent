#!/usr/bin/env bash
# Install the omp config from this repo into the omp agent directory.
# Existing files that differ are backed up as <file>.bak.<timestamp> first.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install.sh [--link] [--dry-run]

Installs config/omp/config.yml and config/omp/commands/*.md into
${PI_CODING_AGENT_DIR:-~/.omp/agent}.
  --link     symlink instead of copy, so `git pull` updates the live config
  --dry-run  print what would change, touch nothing
EOF
}

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
omp_dir="${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"
stamp="$(date +%Y%m%dT%H%M%S)"
mode=copy
dry=0

for arg in "$@"; do
  case "$arg" in
    --link) mode=link ;;
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

install_file config/omp/config.yml "$omp_dir/config.yml"
for f in "$repo"/config/omp/commands/*.md; do
  install_file "config/omp/commands/$(basename "$f")" "$omp_dir/commands/$(basename "$f")"
done
