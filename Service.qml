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
      root.workspaceCache = JSON.parse(raw)
    } catch (e) {
      console.warn("omaprism: failed loading RAM cache:", e)
    }
  }

  function handleWorkspaceChanged(wsId) {
    if (!wsId || wsId <= 0 || wsId > 10 || wsId === currentWorkspaceId) return
    currentWorkspaceId = wsId

    var cached = root.workspaceCache[String(wsId)]
    if (!cached || !cached.accent) return

    // Option B: Instant active window border evaluation (<1ms latency, 0 compositor hitching)
    var luaCmd = "hl.config({ general = { col = { active_border = '" + cached.accent + "' } }, group = { col = { border_active = '" + cached.accent + "' } } })"
    Quickshell.execDetached(["hyprctl", "eval", luaCmd])
  }

  // 1. Raw event listener: captures empty and occupied workspace switches at 0ms
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
