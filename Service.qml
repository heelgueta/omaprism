import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string cacheFilePath: home + "/.local/state/omarchy/omaprism/cache.json"

  property var workspaceCache: ({})
  property var wallpaperUrls: []
  property int currentWorkspaceId: -1

  // Watch fast in-memory cache compiled by omaprism
  FileView {
    id: cacheFileWatcher
    path: root.cacheFilePath
    watchChanges: true
    onLoaded: root.loadCache()
    onFileChanged: reload()
  }

  function loadCache() {
    var raw = cacheFileWatcher.text()
    if (!raw) return
    try {
      var data = JSON.parse(raw)
      root.workspaceCache = data

      // Extract unique wallpaper URLs to warm into RAM
      var urls = []
      for (var ws in data) {
        if (data[ws].wallpaperUrl && urls.indexOf(data[ws].wallpaperUrl) === -1) {
          urls.push(data[ws].wallpaperUrl)
        }
      }
      root.wallpaperUrls = urls
    } catch (e) {
      console.warn("omaprism: failed loading RAM cache:", e)
    }
  }

  // Preload and pin all workspace wallpapers directly into Qt Quick's in-memory image cache
  Repeater {
    model: root.wallpaperUrls
    Item {
      required property string modelData
      Image {
        source: modelData
        cache: true
        asynchronous: false
        visible: false
        width: 1
        height: 1
      }
    }
  }

  function handleWorkspaceChanged(wsId) {
    if (!wsId || wsId <= 0 || wsId === currentWorkspaceId) return
    currentWorkspaceId = wsId

    var cached = root.workspaceCache[String(wsId)]
    if (!cached) return

    // 1. Instant palette application in RAM (0ms latency)
    if (cached.colorsRaw) {
      Color.loadColors(cached.colorsRaw)
      Style.scheduleRefresh()
    }

    // 2. Instant wallpaper display directly from Qt's in-RAM texture cache
    if (cached.wallpaper) {
      Quickshell.execDetached(["omarchy-shell", "-q", "background", "setInstant", cached.wallpaper])
    }

    // 3. Instant Hyprland active border color evaluation (<2ms latency)
    if (cached.accent) {
      var luaCmd = "hl.config({ general = { col = { active_border = '" + cached.accent + "' } }, group = { col = { border_active = '" + cached.accent + "' } } })"
      Quickshell.execDetached(["hyprctl", "eval", luaCmd])
    }

    // 4. Background state sync (terminal OSC recolor, state persistence)
    Quickshell.execDetached(["omaprism", "apply", String(wsId), "--instant"])
  }

  // Reactive listener on Hyprland focused workspace property
  readonly property var focusedWs: Hyprland.focusedWorkspace
  onFocusedWsChanged: {
    if (focusedWs && focusedWs.id) {
      handleWorkspaceChanged(focusedWs.id)
    }
  }

  // Fallback listener for raw workspace switch events
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = String(event && event.name ? event.name : "")
      if (name === "workspace" || name === "focusedmon") {
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id) {
          handleWorkspaceChanged(Hyprland.focusedWorkspace.id)
        }
      }
    }
  }

  IpcHandler {
    target: "omaprism"

    function apply(wsId: string): void {
      var id = parseInt(wsId)
      if (!isNaN(id)) root.handleWorkspaceChanged(id)
    }

    function togglePanel(): void {
      if (root.shell) {
        root.shell.toggle("heelgueta.omaprism")
      }
    }

    function reloadCache(): void {
      cacheFileWatcher.reload()
    }
  }

  Component.onCompleted: {
    loadCache()
    if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id) {
      handleWorkspaceChanged(Hyprland.focusedWorkspace.id)
    }
  }
}
