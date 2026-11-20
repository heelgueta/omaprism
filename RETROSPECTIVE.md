# Architecture Retrospective: Per-Workspace Theming in Omarchy & Hyprland

This document details the architectural experiments, technical bottlenecks, and lessons learned while building per-workspace theme and wallpaper switching in Omarchy on Hyprland.

---

## 1. The Original Goal

The objective was to give each Hyprland workspace (`SUPER + 1` through `SUPER + 0`) its own theme, wallpaper, and colorway, providing an immediate visual cue for the active context (e.g., Code, Web, Chat, DevOps).

---

## 2. Technical Hurdles & Bottlenecks

### A. Wayland's Layer-Shell Protocol is Static
* **Architecture**: In Wayland, wallpapers are rendered via the `zwlr_layer_shell_v1` protocol on the `Background` layer. This is a single, global surface spanning the display.
* **Problem**: Workspaces in Hyprland are virtual coordinates sliding across a 3D coordinate space at 60–165Hz. The background surface behind them does not slide; it remains static. Forcing fullscreen texture swaps during a 60–165Hz workspace transition causes the GPU to rebind buffers while the compositor is actively interpolating window positions, resulting in dropped frames and visual hitching.

### B. Quickshell's Background Pipeline (`Background.qml`)
* **Architecture**: Omarchy uses Quickshell to render the background and status bar. `Background.qml` was designed for occasional theme changes (e.g., once a day or on manual theme selection), utilizing:
  - Shader reveal masks (`MultiEffect`, `revealProgress` animations of 420ms).
  - Asynchronous background worker threads for image decoding (`asynchronous: true`).
* **Problem**: When a user rapidly switches workspaces (e.g., `1 → 2 → 1`), Qt Quick receives multiple conflicting texture requests. Because decoding large images takes CPU time, worker threads queue or cancel out of order, leading to delayed background updates and visual desynchronization.

### C. Race Conditions During Rapid Navigation
* Rapid key navigation (e.g., jumping from `SUPER + 0` to `SUPER + 9` in under 100ms) generates socket events faster than asynchronous subprocesses can resolve. Even with serialization, IPC sockets can experience contention, occasionally leaving the display on the preceding workspace's background.

### D. Hyprland's Dynamic Workspace Lifecycle
* Hyprland dynamically creates workspaces when focused and destroys them when emptied.
* When switching to an empty workspace, Hyprland must construct the workspace in its scene graph. Bombarding the compositor with IPC queries (`hyprctl eval`) or triggering heavy layer-shell repaints while Hyprland is constructing or destroying workspaces induces noticeable stutter.

### E. Collision with Native Omarchy Keybindings (`SUPER + CTRL + SPACE`)
* Omarchy's background switcher relies on global symlinks in `~/.local/state/omarchy/current/` (`theme.name`, `current/theme`, `current/background`).
* Dynamically swapping these links on every workspace transition risks collision with user-directed background changes, and replacing symlinks to binary image files can bypass Qt's text-based `FileView` watchers.

---

## 3. The Stable Solution (Option B: Border Accents)

To deliver the intended visual cues without fighting the compositor's architecture, Omaprism pivots to **Active Window Border Colorways**:

* **Evaluation Speed**: Evaluated in ~1ms via `hyprctl eval`.
* **Zero Compositor Hitching**: Does not touch layer-shell surfaces or GPU texture buffers.
* **Instantaneous Empty Workspace Support**: Window borders reflect the workspace palette immediately when windows appear, without degrading workspace slide animations.
* **Full Compatibility**: Leaves Omarchy's native `SUPER + CTRL + SPACE` background switcher and global themes completely untouched.

---

## 4. Potential Future Directions for Native Per-Workspace Wallpapers

To achieve true zero-lag per-workspace wallpapers in the future, the following approaches would be required:

1. **Native Hyprland C++ Plugin**:
   Instead of an external layer-shell client, a C++ Hyprland plugin hook (`Hyprland::API`) could render wallpapers directly inside the compositor's workspace rendering loop, allowing wallpapers to slide synchronously with window coordinates.
2. **Multi-Surface Canvas Client**:
   A dedicated Wayland client that renders a wide strip containing all 10 wallpapers simultaneously and syncs horizontal scroll offsets with Hyprland's workspace position events.
