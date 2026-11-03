#!/bin/sh
# Türkçe katman farklılık testi: aynı senaryolar referans ve aday Neovim'de, durumlar karşılaştırılır.
# Kullanım: run.sh "<referans nvim komutu>" "<aday nvim komutu>"   (pynvim gerekir: PYTHON_BIN)
set -eu
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
py=${PYTHON_BIN:-python3}
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT HUP INT TERM
"$py" "$dir/harness.py" --nvim "$1" --out "$out/ref.json" &
"$py" "$dir/harness.py" --nvim "$2" --out "$out/cand.json" &
wait
exec "$py" "$dir/harness.py" --compare "$out/ref.json" "$out/cand.json"
