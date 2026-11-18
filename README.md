# Omaprism

**Omaprism** brings per-workspace theming and distinct visual cues to Omarchy on Hyprland.

Switching between workspaces (`SUPER+1` through `SUPER+0`) dynamically transitions your environment to designated colorways and themes, giving you an immediate visual cue for what context you are currently in (e.g. Code, Browser, Messaging, Media, DevOps).

## Architecture

Omaprism integrates with Omarchy through two components:

1. **Omarchy Shell Plugin (`Service.qml`, `Panel.qml`, `BarWidget.qml`)**:
   - Hooks reactively into Hyprland's `focusedWorkspace` in Quickshell.
   - Updates status bar palette and wallpaper with near-zero latency (~50ms) using internal shell IPC (`applyTheme` and `themeTransition` / `setInstant`).
   - Dynamically recolors Hyprland active window borders using `hyprctl eval`.
   - Optionally reflects the workspace theme name and accent dot on the status bar.
   - Provides a GUI panel (`Panel.qml`) summoned from the launcher or bar.

2. **CLI & Daemon (`bin/omaprism`)**:
   - `omaprism apply <id>`: Applies visual settings for the target workspace.
   - `omaprism list`: Displays current workspace mapping and active state.
   - `omaprism set <id> <theme>`: Reassigns a workspace's theme and custom label.
   - `omaprism menu`: Interactive terminal selection menu powered by `gum`.
   - `omaprism daemon`: Standalone background listener for Hyprland `socket2.sock` if run independently of the shell plugin.

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

Default assignments:
- Workspace 1: `osaka-jade` (Code)
- Workspace 2: `tokyo-night` (Web)
- Workspace 3: `catppuccin` (Chat)
- Workspace 4: `gruvbox` (DevOps)
- Workspace 5: `nord` (Notes)
- Workspace 6: `rose-pine` (Media)
- Workspace 7: `kanagawa` (Design)
- Workspace 8: `everforest` (Docs)
- Workspace 9: `hackerman` (Terminal)
- Workspace 10: `matte-black` (Zen)

You can customize workspaces via:
```bash
omaprism set 1 tokyo-night --name "Coding"
omaprism set 2 gruvbox --name "Web"
```
Or interactively using:
```bash
omaprism menu
```
