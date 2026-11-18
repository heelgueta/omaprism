import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string configFilePath: home + "/.config/omarchy/omaprism.json"
  readonly property string stateFilePath: home + "/.local/state/omarchy/omaprism/current.json"

  property bool opened: false
  property var configData: ({})
  property int activeWsId: 1
  property string activeThemeName: ""
  property color activeAccent: Color.accent

  readonly property color bg: Color.menu.background
  readonly property color fg: Color.menu.text
  readonly property color accent: Color.accent
  readonly property color scrimColor: Color.menu.scrim
  readonly property string fontFamily: Style.font.menuFamily

  function open(payloadJson) {
    root.opened = true
    configFileWatcher.reload()
    stateWatcher.reload()
    readConfig()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function") {
      root.shell.hide((root.manifest && root.manifest.id) || "heelgueta.omaprism")
    } else {
      close()
    }
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  FileView {
    id: configFileWatcher
    path: root.configFilePath
    watchChanges: true
    onLoaded: root.readConfig()
    onFileChanged: reload()
  }

  FileView {
    id: stateWatcher
    path: root.stateFilePath
    watchChanges: true
    onLoaded: root.readState()
    onFileChanged: reload()
  }

  function readConfig() {
    var raw = configFileWatcher.text()
    if (!raw) return
    try {
      root.configData = JSON.parse(raw)
    } catch (e) {}
  }

  function readState() {
    var raw = stateWatcher.text()
    if (!raw) return
    try {
      var data = JSON.parse(raw)
      root.activeWsId = data.workspace || 1
      root.activeThemeName = data.theme || ""
      if (data.accent) root.activeAccent = data.accent
    } catch (e) {}
  }

  PanelWindow {
    id: window
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omaprism"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: root.scrimColor

      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(Style.space(680), window.width - Style.gapsOut * 4)
      height: Math.min(Style.space(560), window.height - Style.gapsOut * 4)
      radius: Style.cornerRadius
      color: root.bg
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding

      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.dismiss()
            event.accepted = true
          }
        }

        ColumnLayout {
          anchors.fill: parent
          spacing: Style.space(4)

          // Header
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(3)

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(1)

              Text {
                text: "Omaprism"
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }

              Text {
                text: "Per-Workspace Themes & Visual Cues"
                color: Qt.darker(root.fg, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              width: Style.space(32)
              height: Style.space(32)
              radius: Style.space(16)
              color: closeHover.containsMouse ? Color.menu.selection : "transparent"

              Text {
                anchors.centerIn: parent
                text: "✕"
                color: root.fg
                font.pixelSize: Style.font.body
              }

              MouseArea {
                id: closeHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dismiss()
              }
            }
          }

          // Workspaces Grid
          GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: Style.space(2)
            columnSpacing: Style.space(3)

            Repeater {
              model: 10

              Rectangle {
                required property int index
                readonly property int wsId: index + 1
                readonly property var wsInfo: (root.configData.workspaces && root.configData.workspaces[String(wsId)]) || ({})
                readonly property string wsTheme: wsInfo.theme || "(none)"
                readonly property string wsLabel: wsInfo.name || ("WS " + wsId)
                readonly property color wsAccent: wsInfo.accent || root.accent
                readonly property bool isCurrent: root.activeWsId === wsId

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Style.space(6)
                color: isCurrent ? Color.menu.selection : (itemHover.containsMouse ? Qt.darker(Color.menu.selection, 1.2) : Qt.darker(root.bg, 1.15))
                border.width: isCurrent ? 2 : 1
                border.color: isCurrent ? wsAccent : Qt.darker(root.fg, 2.5)

                MouseArea {
                  id: itemHover
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    switchWsProc.command = ["bash", "-c", "hyprctl dispatch workspace " + wsId]
                    switchWsProc.running = true
                  }
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: Style.space(3)
                  spacing: Style.space(3)

                  Rectangle {
                    width: Style.space(16)
                    height: Style.space(16)
                    radius: width / 2
                    color: parent.parent.wsAccent
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                      text: parent.parent.parent.wsId + ": " + parent.parent.parent.wsLabel
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                    }

                    Text {
                      text: parent.parent.parent.wsTheme
                      color: Qt.darker(root.fg, 1.4)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }

                  Text {
                    text: parent.parent.isCurrent ? "ACTIVE" : ""
                    color: parent.parent.wsAccent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.small
                    font.bold: true
                    visible: parent.parent.isCurrent
                  }
                }
              }
            }
          }

          // Footer
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(2)

            Text {
              Layout.fillWidth: true
              text: "Click any workspace to switch. Run 'omaprism menu' in terminal to edit themes."
              color: Qt.darker(root.fg, 1.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Rectangle {
              height: Style.space(32)
              width: Style.space(110)
              radius: Style.space(4)
              color: btnHover.containsMouse ? root.accent : Color.menu.selection

              Text {
                anchors.centerIn: parent
                text: "Edit Config"
                color: btnHover.containsMouse ? Color.menu.background : root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              MouseArea {
                id: btnHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  openEditorProc.running = true
                  root.dismiss()
                }
              }
            }
          }
        }
      }
    }
  }

  Process {
    id: switchWsProc
  }

  Process {
    id: openEditorProc
    command: ["bash", "-c", "exec xdg-open '" + root.configFilePath + "'"]
  }

  Component.onCompleted: {
    readConfig()
    readState()
  }
}
