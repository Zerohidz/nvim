#!/usr/bin/env bash
# IntelliJ'e "Nvim Format Bridge" plugin'ini derleyip kurar. IntelliJ güncellenince yeniden çalıştır, sonra IDE'yi yeniden başlat.
set -euo pipefail

cd "$(dirname "$0")"
app="/Applications/IntelliJ IDEA.app/Contents"
javac="$(/usr/libexec/java_home -v 21+ 2>/dev/null)/bin/javac"
config_dir="$(ls -d "$HOME/Library/Application Support/JetBrains/"IntelliJIdea* | sort | tail -1)"

rm -rf build
mkdir -p build/classes
"$javac" --release 21 -nowarn -cp "$app/lib/*:$app/lib/modules/*" -d build/classes src/nvimformat/*.java
cp -R resources/META-INF build/classes/
(cd build/classes && jar --create --file ../nvim-format.jar .)

target="$config_dir/plugins/nvim-format/lib"
mkdir -p "$target"
cp build/nvim-format.jar "$target/"
echo "Kuruldu: $target/nvim-format.jar — IntelliJ'i yeniden başlat."
