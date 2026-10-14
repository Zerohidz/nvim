#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
NVIM_TEST_ROOT="$root" nvim --headless -u NONE -l "$root/tests/open_folder_session.lua"
