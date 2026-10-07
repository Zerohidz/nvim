#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
cc -Wall -Wextra -o "$fixture/codex" "$root/tests/terminal-agent-fixture.c"
cp "$fixture/codex" "$fixture/claude"
cp "$fixture/codex" "$fixture/shell"
NVIM_TEST_ROOT="$root" NVIM_TEST_FIXTURE="$fixture" nvim --headless -u NONE -l "$root/tests/terminal_agent.lua"
NVIM_TEST_ROOT="$root" NVIM_TEST_FIXTURE="$fixture" nvim --headless -u NONE -c "lua dofile(vim.env.NVIM_TEST_ROOT .. '/tests/terminal_search_mode.lua')"
