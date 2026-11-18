import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string omaprismBin: home + "/.local/bin/omaprism"

  property int currentWorkspaceId: -1
  property int pendingWorkspaceId: -1

  function handleWorkspaceChanged(wsId) {
    if (!wsId || wsId <= 0 || wsId === currentWorkspaceId) return
    currentWorkspaceId = wsId

    if (applyProc.running) {
      pendingWorkspaceId = wsId
      return
    }

    applyProc.command = ["bash", "-c", "exec '" + (shell ? (home + "/.local/bin/omaprism") : "omaprism") + "' apply " + wsId]
    applyProc.running = true
  }

  // Reactive listener to Hyprland focused workspace property
  readonly property var focusedWs: Hyprland.focusedWorkspace
  onFocusedWsChanged: {
    if (focusedWs && focusedWs.id) {
      handleWorkspaceChanged(focusedWs.id)
    }
  }

  // Fallback raw event listener for workspace switch events
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

  Process {
    id: applyProc
    running: false
    onExited: function(exitCode, exitStatus) {
      if (root.pendingWorkspaceId > 0) {
        var nextId = root.pendingWorkspaceId
        root.pendingWorkspaceId = -1
        root.handleWorkspaceChanged(nextId)
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
  }

  Component.onCompleted: {
    if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id) {
      handleWorkspaceChanged(Hyprland.focusedWorkspace.id)
    }
  }
}
