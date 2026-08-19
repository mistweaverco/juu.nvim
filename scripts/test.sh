#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

exec nvim --headless --noplugin -u tests/minimal_init.lua -c "luafile tests/cmdline_spec.lua"
