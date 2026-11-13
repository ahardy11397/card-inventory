#!/usr/bin/env bash
set -euo pipefail

ORIG_PWD="$PWD"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p build
uv run --project /mnt/ssd/projects/meme meme compile main.meme --provider heuristic --target python --lockfile main.meme.lock -o build/cards.py

cd "$ORIG_PWD"
exec python3 "$SCRIPT_DIR/build/cards.py" "$@"
