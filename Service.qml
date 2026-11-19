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
  property int targetWorkspaceId: -1

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

      // Extract unique wallpaper URLs to warm into Qt texture cache
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

  // Pre-decode all workspace wallpapers into Qt's in-RAM pixmap cache at full screen scale
  Repeater {
    model: root.wallpaperUrls
    Item {
      required property string modelData
      Image {
        source: modelData
        cache: true
        asynchronous: true
        visible: false
      }
    }
  }

  function handleWorkspaceChanged(wsId) {
    if (!wsId || wsId <= 0 || wsId > 10 || wsId === currentWorkspaceId) return
    currentWorkspaceId = wsId
    root.targetWorkspaceId = wsId

    var cached = root.workspaceCache[String(wsId)]
    if (!cached) return

    // 1. Instant palette application in RAM (0ms latency)
    if (cached.colorsRaw) {
      Color.loadColors(cached.colorsRaw)
      Style.scheduleRefresh()
    }

    // 2. Instant Hyprland active border evaluation (<1ms latency)
    if (cached.accent) {
      var luaCmd = "hl.config({ general = { col = { active_border = '" + cached.accent + "' } }, group = { col = { border_active = '" + cached.accent + "' } } })"
      Quickshell.execDetached(["hyprctl", "eval", luaCmd])
    }

    // 3. Atomically queue serialized wallpaper & state switch (eliminates race conditions)
    switchWorker.trigger(wsId)
  }

  // Serialized worker: strictly ensures the latest target workspace wins during fast switching
  Process {
    id: switchWorker
    running: false
    property int inFlightId: -1

    function trigger(id) {
      if (running) {
        // A switch is already in flight; targetWorkspaceId will be processed on exit
        return
      }
      inFlightId = id
      command = ["omaprism", "fast-switch", String(id)]
      running = true
    }

    onExited: {
      if (root.targetWorkspaceId > 0 && root.targetWorkspaceId !== inFlightId) {
        var nextId = root.targetWorkspaceId
        trigger(nextId)
      }
    }
  }

  // 1. Instant raw event listener (catches empty workspaces at 0ms without waiting for compositor model sync)
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

  // 2. Secondary listener on Quickshell's Hyprland focusedWorkspace property
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
      root.loadCache()
    }
  }

  Component.onCompleted: {
    loadCache()
    if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id) {
      handleWorkspaceChanged(Hyprland.focusedWorkspace.id)
    }
  }
}
