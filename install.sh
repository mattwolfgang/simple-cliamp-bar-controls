#!/usr/bin/env bash
# Copy the plugin into the Omarchy shell's plugin folder and enable it.
# Re-run after editing to update the installed copy; the shell hot-reloads it.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
id="io.github.mattwolfgang.simple-cliamp-bar-controls"
dest="$HOME/.config/omarchy/plugins/$id"

omarchy plugin validate "$src"

mkdir -p "$dest"
cp "$src/manifest.json" "$src/BarWidget.qml" "$src/LICENSE" "$dest/"
mkdir -p "$dest/i18n"
cp "$src"/i18n/*.json "$dest/i18n/"

# A first install is a new folder the shell may not have scanned yet.
omarchy-shell shell rescanPlugins >/dev/null

enabled="$(omarchy plugin list --json | python3 -I -c '
import json, sys
print(any(p.get("id") == sys.argv[1] and p.get("enabled") for p in json.load(sys.stdin)))
' "$id")"

if [[ $enabled != True ]]; then
  omarchy plugin enable "$id" --section "${1:-centerBegin}"
fi

echo "Installed $id to $dest"
