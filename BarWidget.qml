import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "heelgueta.omaprism"

  readonly property int activeWsId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
  readonly property string home: Quickshell.env("HOME")
  readonly property string stateFilePath: home + "/.local/state/omarchy/omaprism/current.json"

  property string currentTheme: ""
  property string currentLabel: ""
  property color currentAccent: Color.accent

  FileView {
    id: stateWatcher
    path: root.stateFilePath
    watchChanges: true
    onLoaded: root.readCurrentState()
    onFileChanged: reload()
  }

  function readCurrentState() {
    var txt = stateWatcher.text()
    if (!txt) return
    try {
      var data = JSON.parse(txt)
      root.currentTheme = data.theme || ""
      root.currentLabel = data.name || ""
      if (data.accent) root.currentAccent = data.accent
    } catch (e) {}
  }

  WidgetButton {
    bar: root.bar
    horizontalMargin: 4
    verticalPadding: 4
    fixedHeight: root.barSize

    onPressed: function() {
      if (root.bar && root.bar.shell && typeof root.bar.shell.toggle === "function") {
        root.bar.shell.toggle("heelgueta.omaprism")
      } else {
        toggleProc.running = true
      }
    }

    RowLayout {
      anchors.centerIn: parent
      spacing: Style.space(3)

      Rectangle {
        width: Style.space(8)
        height: Style.space(8)
        radius: width / 2
        color: root.currentAccent
      }

      Text {
        text: root.currentLabel ? (root.activeWsId + ": " + root.currentLabel) : ("WS " + root.activeWsId)
        color: root.bar ? root.bar.foreground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : ""
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }

  Process {
    id: toggleProc
    command: ["omaprism", "gui"]
  }

  Component.onCompleted: readCurrentState()
}
