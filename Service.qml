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
  readonly property string currentBgPath: home + "/.local/state/omarchy/current/background"

  property var workspaceCache: ({})
  property var wallpaperUrls: []
  property int currentWorkspaceId: -1
  property bool switchingInternal: false

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

      // Extract unique wallpaper URLs to warm into RAM texture cache
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

  // Preload and pin all workspace wallpapers directly into Qt Quick's in-RAM texture cache
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
    if (!wsId || wsId <= 0 || wsId > 10 || wsId === currentWorkspaceId) return
    currentWorkspaceId = wsId

    var cached = root.workspaceCache[String(wsId)]
    if (!cached) return

    root.switchingInternal = true

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

    // 4. Update Omarchy's ~/.local/state/omarchy/current symlinks in background
    // so SUPER+CTRL+SPACE immediately shows backgrounds for the active workspace's theme!
    Quickshell.execDetached(["omaprism", "sync-state", String(wsId)])

    switchGuardTimer.restart()
  }

  Timer {
    id: switchGuardTimer
    interval: 350
    repeat: false
    onTriggered: {
      root.switchingInternal = false
    }
  }

  // Watch for user background changes via SUPER + CTRL + SPACE (omarchy-theme-bg-switcher)
  FileView {
    id: userBgWatcher
    path: root.currentBgPath
    watchChanges: true
    onFileChanged: {
      if (!root.switchingInternal && root.currentWorkspaceId > 0) {
        bgSaveTimer.restart()
      }
    }
  }

  Timer {
    id: bgSaveTimer
    interval: 250
    repeat: false
    onTriggered: {
      Quickshell.execDetached(["omaprism", "set-wallpaper"])
    }
  }

  // 1. Raw event listener for INSTANT detection (handles empty/new workspaces with 0ms delay)
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = String(event && event.name ? event.name : "")
      if (name === "workspace" || name === "createworkspace") {
        var raw = String(event.data || "").trim()
        var parts = raw.split(",")
        var id = parseInt(parts[0])
        if (!isNaN(id) && id > 0 && id <= 10) {
          root.handleWorkspaceChanged(id)
        }
      } else if (name === "focusedmon") {
        var monParts = String(event.data || "").split(",")
        if (monParts.length >= 2) {
          var monId = parseInt(monParts[1].trim())
          if (!isNaN(monId) && monId > 0 && monId <= 10) {
            root.handleWorkspaceChanged(monId)
          }
        }
      }
    }
  }

  // 2. Secondary reactive listener on Quickshell's Hyprland focusedWorkspace property
  readonly property var focusedWs: Hyprland.focusedWorkspace
  onFocusedWsChanged: {
    if (focusedWs && focusedWs.id) {
      root.handleWorkspaceChanged(focusedWs.id)
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
