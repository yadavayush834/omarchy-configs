import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "ayush.background-apps"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property string backend: Quickshell.env("HOME") + "/.config/omarchy/bar/scripts/background-apps"
  property var apps: []
  property int totalMemory: 0
  property string errorText: ""

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.6)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() { refresh(); root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.open() }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function")
      return bar.switchPanelFrom(barIdentity, direction)
    return false
  }
  function refresh() { if (!statusProc.running) statusProc.running = true }

  function applyState(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
      apps = data.apps || []
      totalMemory = Number(data.memory || 0)
      errorText = ""
    } catch (e) {
      errorText = "Could not inspect background apps"
    }
  }

  function invoke(args) {
    if (actionProc.running) return
    actionProc.command = [backend].concat(args)
    actionProc.running = true
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: content
    contentWidth: popup.fittedContentWidth(Style.space(500))
    contentHeight: popup.cappedContentHeight(Style.space(470))

    Item {
      id: content
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.close()

      Column {
        anchors.fill: parent
        spacing: Style.space(10)

        RowLayout {
          width: parent.width
          Text {
            text: "BACKGROUND APPS"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
            font.letterSpacing: 1
          }
          Item { Layout.fillWidth: true }
          Text {
            text: root.apps.length + " running"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Text {
          width: parent.width
          text: "Apps with no open Hyprland window. Memory includes all helper processes."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Rectangle {
          width: parent.width
          height: Style.space(330)
          radius: Math.max(Style.cornerRadius, Style.space(7))
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
          border.width: 1
          border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)

          Text {
            visible: root.apps.length === 0
            anchors.centerIn: parent
            text: "No background-only apps."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          ListView {
            id: appList
            visible: root.apps.length > 0
            anchors.fill: parent
            anchors.margins: Style.space(8)
            clip: true
            spacing: Style.space(5)
            model: root.apps

            delegate: Rectangle {
              required property var modelData
              width: appList.width
              height: Style.space(58)
              radius: Math.max(Style.cornerRadius, Style.space(5))
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.045)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(10)

                Text {
                  text: "󰣆"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.heading
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1
                  Text {
                    Layout.fillWidth: true
                    text: String(modelData.name || "Application")
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                  }
                  Text {
                    text: String(modelData.memoryText || "0 MiB")
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                }

                Button {
                  text: "Kill"
                  iconText: "󰅖"
                  foreground: root.foreground
                  accent: root.accent
                  bordered: true
                  onClicked: root.invoke(["kill", String(modelData.key)])
                }
              }
            }
          }
        }

        Text {
          visible: root.errorText !== ""
          width: parent.width
          text: root.errorText
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }

  Process {
    id: statusProc
    command: [root.backend, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyState(text)
    }
  }

  Process {
    id: actionProc
    onExited: function() {
      root.refresh()
      if (root.hostWidget && root.hostWidget.refresh) root.hostWidget.refresh()
    }
  }

  Timer {
    interval: 3000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }
}
