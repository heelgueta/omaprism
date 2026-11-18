#!/usr/bin/env bash
# Install Omaprism into the Omarchy shell and system.
# Usage:
#   ./install.sh             link + enable as shell service & CLI
#   ./install.sh --with-bar  also place the Omaprism widget on the bar
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
id="heelgueta.omaprism"
plugin_dest="$HOME/.config/omarchy/plugins/$id"
bin_dest="$HOME/.local/bin/omaprism"
desktop_dest="$HOME/.local/share/applications/omaprism.desktop"
cfg="$HOME/.config/omarchy/shell.json"

mkdir -p "$HOME/.config/omarchy/plugins" "$HOME/.local/bin" "$HOME/.local/share/applications"

# 1. Safety check
if [[ -e $plugin_dest && ! -L $plugin_dest ]]; then
  echo "Error: $plugin_dest exists and is not a symlink; refusing to overwrite" >&2
  exit 1
fi

# 2. Symlink plugin
ln -sfn "$repo" "$plugin_dest"
echo "✔ Linked plugin: $plugin_dest -> $repo"

# 3. Symlink binary
chmod +x "$repo/bin/omaprism"
ln -sfn "$repo/bin/omaprism" "$bin_dest"
echo "✔ Linked CLI: $bin_dest -> $repo/bin/omaprism"

# 4. Install desktop entry
cat <<EOF > "$desktop_dest"
[Desktop Entry]
Name=Omaprism
Comment=Per-Workspace Themes & Visual Cues
Exec=omaprism gui
Icon=preferences-desktop-theme
Terminal=false
Type=Application
Categories=Settings;DesktopSettings;
Keywords=theme;workspace;omarchy;hyprland;palette;
EOF
echo "✔ Installed desktop entry: $desktop_dest"

# 5. Initialize default config
"$bin_dest" init >/dev/null
echo "✔ Configuration verified at ~/.config/omarchy/omaprism.json"

# 6. Install theme-set automation hook
mkdir -p "$HOME/.config/omarchy/hooks/theme-set.d"
cp -f "$repo/hooks/theme-set" "$HOME/.config/omarchy/hooks/theme-set.d/omaprism"
chmod +x "$HOME/.config/omarchy/hooks/theme-set.d/omaprism"
echo "✔ Installed theme-set hook: ~/.config/omarchy/hooks/theme-set.d/omaprism"

# 7. Rescan plugins in shell
if pgrep -f "quickshell.*omarchy/shell" >/dev/null; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi

# 7. Enable plugin in shell
omarchy plugin enable "$id" >/dev/null 2>&1 || true
echo "✔ Enabled shell plugin: $id"

if [[ "${1:-}" == "--with-bar" ]]; then
  omarchy plugin enable "$id" --section left --after omarchy.workspaces >/dev/null 2>&1 || true
  echo "✔ Added Omaprism widget to status bar"
fi

echo ""
echo "🎉 Omaprism successfully installed!"
echo "Switch workspaces (SUPER+1..0) to see per-workspace themes and colors."
echo "Run 'omaprism list' or 'omaprism menu' to view and configure workspaces."
