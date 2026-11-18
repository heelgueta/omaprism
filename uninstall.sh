#!/usr/bin/env bash
# Uninstall Omaprism from the Omarchy shell and system.
set -euo pipefail

id="heelgueta.omaprism"
plugin_dest="$HOME/.config/omarchy/plugins/$id"
bin_dest="$HOME/.local/bin/omaprism"
desktop_dest="$HOME/.local/share/applications/omaprism.desktop"

# Disable plugin in shell
omarchy plugin disable "$id" >/dev/null 2>&1 || true

# Remove symlinks
if [[ -L $plugin_dest ]]; then
  rm -f "$plugin_dest"
  echo "✔ Removed plugin symlink: $plugin_dest"
fi

if [[ -L $bin_dest ]]; then
  rm -f "$bin_dest"
  echo "✔ Removed binary symlink: $bin_dest"
fi

if [[ -f $desktop_dest ]]; then
  rm -f "$desktop_dest"
  echo "✔ Removed desktop entry: $desktop_dest"
fi

if [[ -f "$HOME/.config/omarchy/hooks/theme-set.d/omaprism" ]]; then
  rm -f "$HOME/.config/omarchy/hooks/theme-set.d/omaprism"
  echo "✔ Removed theme-set hook"
fi

if pgrep -f "quickshell.*omarchy/shell" >/dev/null; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi

echo "✔ Omaprism uninstalled."
echo "Note: Configuration at ~/.config/omarchy/omaprism.json was preserved."
