#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
command -v yazi >/dev/null || { echo "yazi bulunamadı, test atlandı"; exit 0; }
NVIM_TEST_ROOT="$root" nvim --headless -u NONE -c "lua dofile(vim.env.NVIM_TEST_ROOT .. '/tests/yazi_passthrough.lua')"
