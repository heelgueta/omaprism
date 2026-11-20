# Omaprism

**Omaprism** brings per-workspace visual cues to Omarchy on Hyprland with zero lag.

Switching between workspaces (`SUPER+1` through `SUPER+0`) dynamically transitions your active window borders to designated colorways and themes, giving you an immediate visual cue for what context you are currently in (e.g. Code, Browser, Messaging, Media, DevOps) without stuttering or interfering with Omarchy's background switching.

> **Note on Architecture**: For a detailed analysis of our experiments with full Wayland layer-shell wallpaper swapping, dynamic workspace lifecycles, and why border colorways provide the smoothest experience, see [RETROSPECTIVE.md](RETROSPECTIVE.md).

## Features

- **Ultra-Fast Visual Cues (<1ms)**: Immediate active border updates across all 10 workspaces via direct compositor evaluation (`hyprctl eval`).
- **Compositor Friendly**: Zero GPU texture swapping or layer-shell hitching during workspace slide animations.
- **Empty & Non-Empty Workspace Support**: Responds to raw compositor socket events (`workspace>>ID`, `createworkspace>>ID`), ensuring even empty workspaces colorize instantly as soon as you focus or spawn windows in them.
- **Native Keybinding Preservation**: Leaves Omarchy's native `SUPER + CTRL + SPACE` background switcher and theme engine untouched and 100% functional.
- **Spectrum Presets**: Defaults to an orderly ROYGBIV/spectrum palette across workspaces 1–10.

## Architecture

1. **Omarchy Shell Plugin (`Service.qml`, `BarWidget.qml`)**:
   - Subscribes to Hyprland raw socket events in Quickshell.
   - Evaluates active window border colors in under 1ms.
   - Optionally displays the active workspace indicator on the Omarchy bar.

2. **CLI (`bin/omaprism`)**:
   - `omaprism apply <id>`: Manually applies visual settings for the target workspace.
   - `omaprism list`: Displays current workspace mapping and active state.
   - `omaprism set <id> <theme>`: Reassigns a workspace's theme and custom label.
   - `omaprism menu`: Interactive terminal selection menu powered by `gum`.
   - `omaprism cache`: Compiles colors and palettes into fast-load JSON.

## Installation

Run the installer inside the repository:

```bash
cd ~/repos/omaprism
./install.sh
```

To also place the Omaprism status widget onto your Omarchy bar:

```bash
./install.sh --with-bar
```

## Configuration

Configuration is stored in `~/.config/omarchy/omaprism.json`.

Default assignments (Rainbow / Spectrum):
- Workspace 1: `ristretto` (Red / Coral)
- Workspace 2: `gruvbox` (Orange / Ochre)
- Workspace 3: `cyberpunk` (Yellow / Gold)
- Workspace 4: `everforest` (Green)
- Workspace 5: `osaka-jade` (Teal / Jade)
- Workspace 6: `nord` (Cyan / Ice Blue)
- Workspace 7: `tokyo-night` (Blue)
- Workspace 8: `catppuccin` (Indigo / Lavender)
- Workspace 9: `rose-pine` (Violet / Purple)
- Workspace 10: `matte-black` (Monochrome / Zen)

You can customize workspaces via:
```bash
omaprism set 1 tokyo-night --name "Coding"
omaprism set 2 gruvbox --name "Web"
```
Or interactively using:
```bash
omaprism menu
```
