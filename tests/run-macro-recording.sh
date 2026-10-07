#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"${PYTHON_BIN:-python3}" "$script_dir/macro_recording.py" "$@"
exec "${PYTHON_BIN:-python3}" "$script_dir/macro_replay_ui.py"
